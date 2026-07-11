#!/usr/bin/env bash
# build_dmg.sh — Build ElonWatch.app then wrap in a styled DMG
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ElonWatch"
APP="$DIR/build/Build/Products/Release/${APP_NAME}.app"
DMG_FINAL="$DIR/dist/${APP_NAME}.dmg"
DMG_TEMP="$DIR/dist/${APP_NAME}_tmp.dmg"
STAGING="$DIR/dist/dmg_staging"
BG="$DIR/../elonwatch/dmg_background.png"

echo "╔══════════════════════════════════════════════╗"
echo "║   ELONWATCH // FUTURE SYNC  —  DMG BUILDER  ║"
echo "╚══════════════════════════════════════════════╝"

# ── 1. Build the Swift app ────────────────────────────────────────────────────
echo ">> Building ElonWatch.app ..."
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" 2>&1 | grep -E "SUCCEEDED|FAILED|error:" | head -5

# ── 2. Inject resources (xcodegen doesn't copy binary/media automatically) ───
echo ">> Injecting scraper binary + intro video ..."
RSRC="$APP/Contents/Resources"
cp "$DIR/Sources/ElonWatch/Resources/elonwatch_scraper" "$RSRC/"
cp "$DIR/Sources/ElonWatch/Resources/intro.mp4"         "$RSRC/"
chmod +x "$RSRC/elonwatch_scraper"

# ── 3. Stage DMG contents ─────────────────────────────────────────────────────
echo ">> Staging DMG ..."
rm -rf "$STAGING" "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$STAGING/.background"
cp -r "$APP"  "$STAGING/"
ln -sf /Applications "$STAGING/Applications"
cp "$BG" "$STAGING/.background/background.png"

cat > "$STAGING/README.txt" << 'EOF'
ELONWATCH // FUTURE SYNC  v2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Drag ElonWatch.app → Applications, then double-click.

No Python, no Terminal, no install script.
Everything is bundled inside the app.

macOS security warning: right-click → Open → Open.
EOF

# ── 4. Create temp RW DMG, style with AppleScript ────────────────────────────
echo ">> Building temp RW DMG ..."
hdiutil create \
  -volname "${APP_NAME} - Future Sync" \
  -srcfolder "$STAGING" \
  -ov -format UDRW -size 120m \
  "$DMG_TEMP"

MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$DMG_TEMP" -mountpoint "$MOUNT_DIR" -noautoopen -quiet

echo ">> Styling DMG window ..."
osascript << APPLESCRIPT || true
tell application "Finder"
  tell disk "${APP_NAME} - Future Sync"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 760, 500}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 100
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "${APP_NAME}.app" of container window to {170, 200}
    set position of item "Applications" of container window to {490, 200}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force || true

# ── 5. Compress to final DMG ──────────────────────────────────────────────────
mkdir -p "$DIR/dist"
echo ">> Compressing final DMG ..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TEMP"

echo ""
echo "  DMG: $DMG_FINAL"
echo "  SIZE: $(du -sh "$DMG_FINAL" | cut -f1)"
echo ""
echo "  open $DMG_FINAL"
