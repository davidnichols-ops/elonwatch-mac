# dmgbuild settings for ElonWatch // Future Sync
# NOTE: all paths must be absolute — __file__ is not available in this context

MAC_DIR  = "/Users/david/elonwatch-mac"
PROJ_DIR = "/Users/david/elonwatch"

volume_name       = "ElonWatch - Future Sync"
format            = "UDZO"
compression_level = 9
window_rect       = ((100, 100), (660, 400))
background        = PROJ_DIR + "/dmg_background.png"
icon_size         = 100
text_size         = 12

icon_locations = {
    "ElonWatch.app": (170, 185),
    "Applications":  (490, 185),
}

files = [
    MAC_DIR + "/build/Build/Products/Release/ElonWatch.app",
]

symlinks = {
    "Applications": "/Applications",
}
