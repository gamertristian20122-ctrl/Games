extends RefCounted
## Credits: everything in the game that somebody else made, and the licence it is used under.
## Use with:  const Credits = preload("res://scripts/data/credits.gd")
## The Credits screen (scripts/ui/credits.gd) is built from this list, top to bottom.
##
## To add a credit: add one row to LIST with these four fields.
##   what     what it is and what the game uses it for
##   author   who made it
##   licence  the licence name (CC0, MIT, OFL ...)
##   url      where it came from
##
## SOUND, MUSIC AND FONT CREDITS ARE APPENDED HERE LATER, when those files are added to
## assets/audio and assets/fonts. Every asset in the game must have a row.

## Short lines shown at the top of the Credits screen. Edit freely.
const NOTES := [
	"No AI-made art or audio. Code written with AI assistance.",
]

const LIST := [
	{
		"what": "DungeonTileset II (all pixel art)",
		"author": "0x72",
		"licence": "CC0",
		"url": "https://0x72.itch.io/dungeontileset-ii",
	},
	{
		"what": "Godot Engine",
		"author": "Juan Linietsky, Ariel Manzur and the Godot contributors",
		"licence": "MIT",
		"url": "https://godotengine.org",
	},
	# ---- sound effects: add rows here
	# ---- music: add rows here
	# ---- fonts: add rows here
]
