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
## Every asset in the game must have a row. Licence evidence for each one is kept in assets_raw/.

## Short lines shown at the top of the Credits screen. Edit freely.
const NOTES := [
	"No AI-made art or audio. Code written with AI assistance.",
]

const LIST := [
	# ---- bought by the owner (Nov 2026). The licence allows commercial games; the art itself may not
	#      be resold or shared. Each pack's Terms.txt is kept in assets_raw/paid_pixel_crawler/.
	{
		"what": "Pixel Crawler - Complete Collection (heroes, monsters, bosses, weapons, the shopkeeper, dungeon rooms)",
		"author": "Anokolisa",
		"licence": "Purchased licence (commercial use allowed)",
		"url": "https://anokolisa.itch.io/",
	},
	{
		"what": "DungeonTileset II (items, pickups and other small pixel art)",
		"author": "0x72",
		"licence": "CC0",
		"url": "https://0x72.itch.io/dungeontileset-ii",
	},
	# ---- add-on art and effects (cut out of assets_raw/ by tools/import_assets.py)
	{
		"what": "Dungeon Tileset II Extended (torches, keys, doors, rugs, signs)",
		"author": "Niji (nijikokun)",
		"licence": "CC0",
		"url": "https://nijikokun.itch.io/dungeontileset-ii-extended",
	},
	{
		"what": "16x16 Enchanted Forest Characters (extra creatures)",
		"author": "Superdark",
		"licence": "Free for commercial use, no credit required (author's statement on the page)",
		"url": "https://superdark.itch.io/enchanted-forest-characters",
	},
	{
		"what": "Pixel Art Spells (shots and sparkles)",
		"author": "DevWizard",
		"licence": "CC0",
		"url": "https://opengameart.org/content/pixel-art-spells",
	},
	{
		"what": "Warped Shooting Fx (hit sparks)",
		"author": "ansimuz (Luis Zuno)",
		"licence": "CC0",
		"url": "https://opengameart.org/content/warped-shooting-fx",
	},
	{
		"what": "Explosion Animations Pack (the bomb blast)",
		"author": "ansimuz (Luis Zuno)",
		"licence": "CC0",
		"url": "https://ansimuz.itch.io/explosion-animations-pack",
	},
	{
		"what": "Smoke Puff (dust and death puffs)",
		"author": "Aidan_Walker",
		"licence": "CC0",
		"url": "https://opengameart.org/content/smoke-puff",
	},
	{
		"what": "Godot Engine",
		"author": "Juan Linietsky, Ariel Manzur and the Godot contributors",
		"licence": "MIT",
		"url": "https://godotengine.org",
	},
	# ---- sound effects
	{
		"what": "Sound effects: 80 CC0 RPG SFX",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/80-cc0-rpg-sfx",
	},
	{
		"what": "Sound effects: 80 CC0 creature SFX",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/80-cc0-creature-sfx",
	},
	{
		"what": "Sound effects: 80 CC0 creture SFX #2",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/80-cc0-creture-sfx-2",
	},
	{
		"what": "Sound effects: 75 CC0 breaking / falling / hit sfx",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx",
	},
	{
		"what": "Sound effects: 25 CC0 bang / firework SFX",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/25-cc0-bang-firework-sfx",
	},
	{
		"what": "Sound effects: 100 CC0 SFX",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/100-cc0-sfx",
	},
	{
		"what": "Sound effects: 100 CC0 metal and wood SFX",
		"author": "rubberduck",
		"licence": "CC0",
		"url": "https://opengameart.org/content/100-cc0-metal-and-wood-sfx",
	},
	{
		"what": "Sound effects: RPG Sound Pack",
		"author": "artisticdude",
		"licence": "CC0",
		"url": "https://opengameart.org/content/rpg-sound-pack",
	},
	{
		"what": "Sound effects: 50 RPG sound effects (Kenney RPG Audio)",
		"author": "Kenney",
		"licence": "CC0",
		"url": "https://opengameart.org/content/50-rpg-sound-effects",
	},
	{
		"what": "Sound effects: 85 Short music jingles (Kenney Music Jingles)",
		"author": "Kenney",
		"licence": "CC0",
		"url": "https://opengameart.org/content/85-short-music-jingles",
	},
	{
		"what": "Sound effects: 512 Sound Effects (8-bit style)",
		"author": "Juhani Junkala",
		"licence": "CC0",
		"url": "https://opengameart.org/content/512-sound-effects-8-bit-style",
	},
	{
		"what": "Sound effects: Big scary troll sounds",
		"author": "Darsycho",
		"licence": "CC0",
		"url": "https://opengameart.org/content/big-scary-troll-sounds",
	},
	{
		"what": "Sound effects: Fire Crackling",
		"author": "AntumDeluge",
		"licence": "CC0",
		"url": "https://opengameart.org/content/fire-crackling",
	},
	{
		"what": "Sound effects: Ghost breath",
		"author": "qubodup",
		"licence": "CC0",
		"url": "https://opengameart.org/content/ghost-breath",
	},
	{
		"what": "Sound effects: Win Jingle",
		"author": "Fupi",
		"licence": "CC0",
		"url": "https://opengameart.org/content/win-jingle",
	},
	# ---- music
	{
		"what": "Music: JRPG Pack 3 Evil (title, floor1, floor2, floor3, spare floor loop)",
		"author": "Juhani Junkala",
		"licence": "CC0",
		"url": "https://opengameart.org/content/jrpg-pack-3-evil",
	},
	{
		"what": "Music: JRPG Pack 2 Towns (shop)",
		"author": "Juhani Junkala",
		"licence": "CC0",
		"url": "https://opengameart.org/content/jrpg-pack-2-towns",
	},
	{
		"what": "Music: JRPG Pack 5 Action (boss, spare boss loop)",
		"author": "Juhani Junkala",
		"licence": "CC0",
		"url": "https://opengameart.org/content/jrpg-pack-5-action",
	},
	{
		"what": "Music: Boss Battle Music: Epic Boss Battle (final_boss)",
		"author": "Juhani Junkala",
		"licence": "CC0",
		"url": "https://opengameart.org/content/boss-battle-music",
	},
	{
		"what": "Music: Victory Fanfare Short (victory)",
		"author": "cynicmusic / The Cynic Project",
		"licence": "CC0",
		"url": "https://opengameart.org/content/victory-fanfare-short",
	},
	{
		"what": "Music: Game Over Theme: No Hope (gameover)",
		"author": "Cleyton Kauffman",
		"licence": "CC0",
		"url": "https://opengameart.org/content/game-over-theme",
	},
	# ---- fonts
	{
		"what": "Font: Alkhemikal (titles)",
		"author": "jeti (Font End Dev)",
		"licence": "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
		"url": "https://fontenddev.com/fonts/alkhemikal/",
	},
	{
		"what": "Font: m5x7 (text)",
		"author": "Daniel Linssen",
		"licence": "CC0",
		"url": "https://managore.itch.io/m5x7",
	},
]
