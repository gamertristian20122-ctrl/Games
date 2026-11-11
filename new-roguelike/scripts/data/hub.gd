extends RefCounted
## The camp (the hub between runs): its map and the people in it. scripts/hub/hub.gd builds it.
## All art is the owner's purchased Pixel Crawler packs: Fairy Forest (ground, trees, plants, rune
## stones), Cemetery (the crypt gate, graves, statues), Free Pack Exterior (fires, anvil, bench,
## scarecrow) and the pack's characters. Pieces are cut by tools/import_hub.py (ids hub_*).
## Positions are in game pixels on a MAP-sized field; a thing stands on its (x, y) with its base.

const MAP := Vector2(720, 464)
const WALK := Rect2(40, 112, 640, 312)      ## where the hero may walk
const SPAWN := Vector2(360, 322)
const TALK_REACH := 30.0

## Things that stand up (drawn in front of or behind people by their y).
##   [piece id, x, y, solid radius (0 = walk through), px of the picture below its base]
const PROPS := [
	# the crypt gate in the rocks, north
	["hub_rock_2", 318, 104, 0, 2], ["hub_rock_moss_2", 404, 105, 0, 2], ["hub_rock_moss_1", 288, 108, 0, 2], ["hub_rock_1", 434, 108, 0, 2],
	["hub_gate_0", 360, 108, 0, 0],
	["hub_statue_1", 316, 134, 9, 2], ["hub_statue_0", 406, 134, 7, 2],
	["hub_tomb_7", 262, 128, 10, 2], ["hub_tomb_8", 458, 128, 10, 2], ["hub_tomb_1", 222, 136, 9, 2], ["hub_tomb_2", 498, 134, 9, 2],
	["hub_cross_2", 240, 160, 5, 1], ["hub_cross_3", 482, 162, 5, 1], ["hub_statue_2", 528, 146, 8, 2], ["hub_cross_1", 196, 152, 6, 1],
	# the fire in the middle of the open ground
	["hub_stump_1", 322, 278, 7, 3], ["hub_stump_2", 400, 280, 6, 3],
	# the rune ring, west
	["hub_rune_1", 146, 228, 12, 3], ["hub_rune_0", 106, 264, 9, 3], ["hub_rune_2", 186, 212, 5, 2], ["hub_rune_0", 194, 272, 9, 3],
	["hub_bloom_0", 92, 226, 0, 2], ["hub_bloom_5", 166, 296, 0, 2], ["hub_bloom_1", 214, 238, 0, 2], ["hub_vine_1", 122, 202, 0, 2],
	["hub_bloom_6", 66, 252, 0, 2], ["hub_shroom_0", 84, 292, 0, 1], ["hub_shroom_1", 216, 294, 0, 1], ["hub_shroom_2", 134, 302, 0, 1],
	# the smithy, east
	["hub_anvil_0", 590, 246, 16, 4], ["hub_bench_1", 624, 216, 12, 3], ["hub_stone_1", 644, 266, 12, 3], ["hub_stone_0", 552, 218, 8, 2],
	# the kitchen, south-east
	["hub_farm_2", 590, 370, 5, 1], ["hub_stump_0", 540, 402, 12, 4], ["hub_rock_moss_0", 636, 388, 12, 3],
	# the chronicler's corner, south-west
	["hub_tomb_9", 148, 374, 10, 2], ["hub_plant_3", 126, 380, 0, 1], ["hub_plant_4", 172, 384, 0, 1], ["hub_rock_0", 88, 372, 12, 3],
	# a few bushes and young trees at the edges; the middle stays open
	["hub_bush_green_1", 262, 372, 12, 5], ["hub_bush_orange_2", 462, 334, 9, 4], ["hub_bush_deep_1", 252, 214, 10, 4],
	["hub_bush_rust_2", 478, 222, 9, 4], ["hub_tree_pink_4", 276, 418, 4, 5], ["hub_tree_teal_4", 440, 420, 4, 5],
	["hub_tree_green_4", 58, 156, 4, 5], ["hub_tree_pink_3", 664, 168, 6, 6], ["hub_tree_green_3", 56, 344, 6, 6], ["hub_tree_teal_3", 668, 326, 6, 6],
]

## The forest wall round the clearing is planted by hub.gd from these (it fits itself to MAP):
## big trees along the top (not in front of the gate), middle ones down the sides, bushes and
## young trees along the bottom.
const FOREST_BIG := ["hub_tree_teal_1", "hub_tree_green_1", "hub_tree_pink_1", "hub_tree_green_2", "hub_tree_teal_2", "hub_tree_pink_2"]
const FOREST_SIDE := ["hub_tree_green_2", "hub_tree_pink_2", "hub_tree_teal_2"]
const FOREST_LOW := ["hub_bush_green_0", "hub_bush_deep_0", "hub_bush_orange_0", "hub_bush_rust_0", "hub_bush_green_1", "hub_bush_orange_1"]
const FOREST_YOUNG := ["hub_tree_green_3", "hub_tree_teal_3", "hub_tree_pink_3"]
const GATE_GAP := [296.0, 424.0]            ## no big tree in front of the crypt gate (x from, x to)
const BEHIND_GATE := [["hub_tree_pink_2", 360, 60], ["hub_tree_green_2", 296, 80], ["hub_tree_teal_2", 426, 80]]

## Trodden earth: each list is a path; hub.gd lays the pack's 48 px earth patches along it.
const PATHS := [
	[Vector2(360, 130), Vector2(360, 236)], [Vector2(360, 270), Vector2(360, 336)],
	[Vector2(338, 262), Vector2(196, 252)], [Vector2(384, 262), Vector2(548, 252)],
	[Vector2(372, 322), Vector2(512, 380)], [Vector2(346, 322), Vector2(204, 392)],
]

## How many small flat things are scattered on the grass (seeded, the same every time).
const SCATTER := {"hub_tuft": [24, 110], "hub_flower": [26, 54], "hub_pebble": [20, 20], "hub_twig": [10, 12]}   # id: [variants, how many]

const FIRE := Vector2(360, 256)
const GRILL := Vector2(516, 376)            ## the cook's fire
const STROLL := 12.0                        ## how far a person wanders from their post (those the pack drew walking)

## The people. "role" decides what talking does (hub.gd): gate, quests, collection, pack, chat.
## What they SAY is in scripts/data/story.gd (TALK, by chapter); "text" here is only a fallback.
## Names and lines are placeholders the owner may rewrite.
const NPCS := [
	{"id": "warden", "name": "Warden Hale", "title": "Keeper of the Gate", "sprite": "pc_royal_knight", "hands": "pc_hand_castle_17",
		"pos": Vector2(398, 148), "face": -1, "role": "gate",
		"text": "Pick your stair. A stage you have reached stays open, and I hand you gear for the floors you skip."},
	{"id": "druid", "name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "hands": "pc_hand_elf_23",
		"pos": Vector2(160, 254), "face": 1, "role": "quests",
		"text": "The stones ask for work. Do it, and your pack will be heavier when you next go down."},
	{"id": "chronicler", "name": "Brother Odo", "title": "Chronicler", "sprite": "pc_scholar_researcher", "hands": "pc_hand_library_6",
		"pos": Vector2(178, 398), "face": 1, "role": "collection",
		"text": "Everything you have carried out of the dark is written here."},
	{"id": "cook", "name": "Marta", "title": "Camp Cook", "sprite": "pc_npc_tavern_a", "hands": "pc_hand_base_2",
		"pos": Vector2(556, 392), "face": -1, "role": "pack",
		"text": "I keep your pack by the fire. Whatever the Druid pays you goes in it, and you take it all on your next run."},
	{"id": "smith", "name": "Tam", "title": "Smith", "sprite": "pc_npc_peasant_a", "hands": "pc_hand_base_2",
		"pos": Vector2(562, 254), "face": 1, "role": "chat",        # he also sells sword upgrades (scripts/data/upgrades.gd, "at": "smith")
		"text": ""},
	{"id": "hunter", "name": "Fen", "title": "Forest Elf", "sprite": "pc_elf_base", "hands": "pc_hand_elf_23",
		"pos": Vector2(636, 332), "face": -1, "role": "chat",
		"text": ""},
	{"id": "ranger", "name": "Ilse", "title": "Elf Ranger", "sprite": "pc_elf_ranger", "hands": "pc_hand_elf_23",
		"pos": Vector2(94, 152), "face": 1, "role": "chat",
		"text": ""},
]
