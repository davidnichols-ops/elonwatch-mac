#!/usr/bin/env bash
# build_dmg.sh — Build ElonWatch.app then wrap in a styled DMG
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ElonWatch"
APP="$DIR/build/Build/Products/Release/${APP_NAME}.app"
DMG_FINAL="$DIR/dist/${APP_NAME}.dmg"
VENV_DMGBUILD="/Users/david/elonwatch/venv/bin/dmgbuild"

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

# ── 2. Inject resources ───────────────────────────────────────────────────────
echo ">> Injecting scraper binary + intro video ..."
RSRC="$APP/Contents/Resources"
cp "$DIR/Sources/ElonWatch/Resources/elonwatch_scraper" "$RSRC/"
cp "$DIR/Sources/ElonWatch/Resources/intro.mp4"         "$RSRC/"
chmod +x "$RSRC/elonwatch_scraper"

echo ">> Resources in bundle:"
ls -lh "$RSRC/" | grep -E "scraper|intro|icns"

# ── 3. Build styled DMG via dmgbuild ─────────────────────────────────────────
echo ">> Building styled DMG ..."
mkdir -p "$DIR/dist"
rm -f "$DMG_FINAL"

"$VENV_DMGBUILD" \
  -s "$DIR/dmg_settings.py" \
  "ElonWatch - Future Sync" \
  "$DMG_FINAL"

echo ""
echo "  DMG : $DMG_FINAL"
echo "  SIZE: $(du -sh "$DMG_FINAL" | cut -f1)"
echo ""
echo "  open $DMG_FINAL"
