extends RefCounted
## The camp (the hub between runs): its map and the people in it. scripts/hub/hub.gd builds it.
## All art is the owner's purchased Pixel Crawler packs: Fairy Forest (ground, trees, plants, rune
## stones), Cemetery (the crypt gate, graves, statues), Free Pack Exterior (fires, anvil, bench,
## scarecrow) and the pack's characters. Pieces are cut by tools/import_hub.py (ids hub_*).
## Positions are in game pixels on a MAP-sized field; a thing stands on its (x, y) with its base.

const MAP := Vector2(576, 368)
const WALK := Rect2(34, 104, 508, 232)      ## where the hero may walk
const SPAWN := Vector2(288, 256)
const TALK_REACH := 30.0

## Things that stand up (drawn in front of or behind people by their y).
##   [piece id, x, y, solid radius (0 = walk through), px of the picture below its base]
const PROPS := [
	# the crypt gate in the rocks, north
	["hub_rock_2", 246, 96, 0, 2], ["hub_rock_moss_2", 332, 97, 0, 2], ["hub_rock_moss_1", 216, 100, 0, 2], ["hub_rock_1", 362, 100, 0, 2],
	["hub_gate_0", 288, 100, 0, 0],
	["hub_statue_1", 244, 124, 9, 2], ["hub_statue_0", 334, 124, 7, 2],
	["hub_tomb_7", 196, 120, 10, 2], ["hub_tomb_8", 382, 120, 10, 2], ["hub_tomb_1", 160, 128, 9, 2], ["hub_tomb_2", 416, 126, 9, 2],
	["hub_cross_2", 176, 150, 5, 1], ["hub_cross_3", 404, 152, 5, 1], ["hub_statue_2", 440, 136, 8, 2],
	# the fire in the middle
	["hub_stump_1", 256, 232, 7, 3], ["hub_stump_2", 322, 234, 6, 3],
	# the rune ring, west
	["hub_rune_1", 104, 192, 12, 3], ["hub_rune_0", 72, 226, 9, 3], ["hub_rune_2", 140, 176, 5, 2], ["hub_rune_0", 150, 232, 9, 3],
	["hub_bloom_0", 60, 190, 0, 2], ["hub_bloom_5", 128, 250, 0, 2], ["hub_bloom_1", 164, 200, 0, 2], ["hub_vine_1", 88, 168, 0, 2],
	["hub_shroom_0", 52, 250, 0, 1], ["hub_shroom_1", 170, 252, 0, 1], ["hub_shroom_2", 96, 258, 0, 1],
	# the smith, east
	["hub_anvil_0", 474, 204, 16, 4], ["hub_bench_1", 506, 176, 12, 3], ["hub_stone_1", 520, 222, 12, 3], ["hub_stone_0", 440, 180, 8, 2],
	# the cook, south-east
	["hub_farm_2", 452, 300, 5, 1], ["hub_stump_0", 404, 318, 12, 4], ["hub_rock_moss_0", 500, 310, 12, 3],
	# the chronicler, south-west
	["hub_tomb_9", 124, 300, 10, 2], ["hub_plant_3", 104, 306, 0, 1], ["hub_plant_4", 146, 310, 0, 1], ["hub_rock_0", 70, 300, 12, 3],
	# bushes and small trees that break up the clearing
	["hub_bush_green_1", 210, 290, 12, 5], ["hub_bush_orange_2", 360, 268, 9, 4], ["hub_bush_deep_1", 200, 184, 10, 4],
	["hub_bush_rust_2", 388, 196, 9, 4], ["hub_tree_pink_4", 220, 330, 4, 5], ["hub_tree_teal_4", 318, 334, 4, 5],
	["hub_tree_green_4", 46, 140, 4, 5], ["hub_tree_pink_3", 528, 150, 6, 6],
]

## The ring of forest around the clearing: [piece id, x, y]. Bases are outside WALK.
const FOREST := [
	["hub_tree_teal_1", 60, 92], ["hub_tree_green_0", 150, 84], ["hub_tree_pink_1", 420, 86], ["hub_tree_green_1", 520, 94],
	["hub_tree_green_2", 226, 70], ["hub_tree_teal_2", 350, 70], ["hub_tree_pink_2", 288, 52],
	["hub_tree_green_2", 4, 170], ["hub_tree_pink_2", 10, 262], ["hub_tree_teal_2", 0, 340],
	["hub_tree_teal_2", 572, 200], ["hub_tree_green_2", 566, 290], ["hub_tree_pink_3", 560, 352],
	["hub_tree_green_3", 70, 392], ["hub_tree_teal_3", 150, 398], ["hub_tree_green_3", 288, 400], ["hub_tree_pink_3", 430, 396], ["hub_tree_teal_3", 510, 394],
	["hub_bush_green_0", 30, 352], ["hub_bush_deep_0", 110, 362], ["hub_bush_orange_0", 190, 366], ["hub_bush_green_0", 262, 366],
	["hub_bush_rust_0", 330, 364], ["hub_bush_deep_0", 400, 366], ["hub_bush_green_0", 470, 362], ["hub_bush_orange_1", 540, 350],
	["hub_bush_deep_1", 24, 210], ["hub_bush_green_2", 22, 300], ["hub_bush_rust_1", 552, 250], ["hub_bush_green_2", 552, 318],
]

## Bare earth under the paths: the centres of the pack's 48 px earth patches.
const PATCHES := [
	[288, 128, 0], [280, 164, 1], [292, 200, 0], [288, 236, 1], [250, 252, 0], [326, 250, 1],
	[214, 232, 1], [176, 214, 0], [140, 206, 1], [364, 228, 0], [404, 212, 1], [440, 208, 0],
	[300, 280, 0], [340, 296, 1], [380, 300, 0], [240, 286, 1], [196, 300, 0], [160, 300, 1],
]

## How many small flat things are scattered on the grass (seeded, the same every time).
const SCATTER := {"hub_tuft": [24, 70], "hub_flower": [26, 36], "hub_pebble": [20, 14], "hub_twig": [10, 8]}   # id: [variants, how many]

const FIRE := Vector2(288, 214)

## The people. "role" decides what talking does (hub.gd): gate, quests, collection, pack, chat.
## Names and lines are placeholders the owner may rewrite.
const NPCS := [
	{"id": "warden", "name": "Warden Hale", "title": "Keeper of the Gate", "sprite": "pc_royal_knight", "hands": "pc_hand_castle_17",
		"pos": Vector2(322, 136), "face": -1, "role": "gate",
		"text": "Pick your stair. A stage you have reached stays open, and I hand you gear for the floors you skip."},
	{"id": "druid", "name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "hands": "pc_hand_elf_23",
		"pos": Vector2(122, 214), "face": 1, "role": "quests",
		"text": "The stones ask for work. Do it, and your pack will be heavier when you next go down."},
	{"id": "chronicler", "name": "Brother Odo", "title": "Chronicler", "sprite": "pc_scholar_researcher", "hands": "pc_hand_library_6",
		"pos": Vector2(150, 312), "face": 1, "role": "collection",
		"text": "Everything you have carried out of the dark is written here."},
	{"id": "cook", "name": "Marta", "title": "Camp Cook", "sprite": "pc_npc_tavern_a", "hands": "pc_hand_base_2",
		"pos": Vector2(424, 312), "face": -1, "role": "pack",
		"text": "I keep your pack by the fire. Whatever the Druid pays you goes in it, and you take it all on your next run."},
	{"id": "smith", "name": "Tam", "title": "Smith", "sprite": "pc_npc_peasant_a", "hands": "pc_hand_base_2",
		"pos": Vector2(452, 212), "face": 1, "role": "chat",
		"text": "Bombs crack the Curse open. Stand close when it bursts and the coins are yours."},
	{"id": "hunter", "name": "Fen", "title": "Forest Elf", "sprite": "pc_elf_base", "hands": "pc_hand_elf_23",
		"pos": Vector2(504, 268), "face": -1, "role": "chat",
		"text": "The black disc runs in a straight line. Put a monster between you and it, then call it."},
	{"id": "ranger", "name": "Ilse", "title": "Elf Ranger", "sprite": "pc_elf_ranger", "hands": "pc_hand_elf_23",
		"pos": Vector2(76, 132), "face": 1, "role": "chat",
		"text": "Cursed things make you strong and the Curse fat. The shop below can starve it, for a price."},
]
## Where the heroes you are NOT playing stand (by the fire).
const HERO_SPOTS := [Vector2(256, 214), Vector2(322, 216)]
