extends RefCounted
## Places: every screen the knight can WALK around in outside the hill. scripts/hub/hub.gd shows
## one at a time and moves between them through their exits (a short fade).
##   village   the camp grown into a small village (its things are in scripts/data/hub.gd)
##   elfwood   east of the village: the road through the Elfwood (walk off the village's east edge)
##   glade     east again: the rune glade, where the Warden of the Wood opens the Elfwood's levels
##   hall      the tavern's hall: the barkeep sells items, the stairs lead out to the village
##   room      your room upstairs: the game starts here (bed, looking glass)
## A place is a Dictionary:
##   "name"      shown when you arrive            "size"   Vector2, the whole picture
##   "outdoor"   true = grass, forest wall, lights, fireflies (built from "props", "paths" ...)
##   "art"       indoor: one picture (an Art id) laid down as the whole place
##   "walk"      Rect2 the hero may walk in       "blocks" [Rect2] furniture and walls inside it
##   "spawn"     Vector2 where he stands when nothing else says where
##   "people"    rows like scripts/data/hub.gd NPCS. "ghost": true = someone already painted into
##               the picture: no sprite of ours, only a spot to talk to ("top" = how high the name floats)
##   "exits"     [{"rect": Rect2, "to": place id, "at": Vector2}] walk into the rectangle to go there
## Interiors are cut from the pack's own tavern picture (tools/import_hub.py, HALVED), so their
## numbers below are pixels of those pictures.

const Hub = preload("res://scripts/data/hub.gd")

const START := "room"            ## where Play puts you


static func get_place(id: String) -> Dictionary:
	match id:
		"room":
			return {
				"name": "Your room", "size": Vector2(144, 164), "art": "hub_in_room",
				"walk": Rect2(10, 64, 124, 90), "spawn": Vector2(72, 100),
				"blocks": [Rect2(8, 50, 48, 86), Rect2(8, 122, 44, 40), Rect2(90, 118, 46, 40), Rect2(62, 42, 24, 26)],
				"exits": [{"rect": Rect2(100, 56, 24, 12), "to": "hall", "at": Vector2(192, 80)}],
				"people": [
					{"id": "bed", "name": "Your bed", "title": "", "ghost": true, "pos": Vector2(62, 96), "top": 4, "role": "bed", "text": ""},
					{"id": "mirror", "name": "Looking glass", "title": "", "ghost": true, "pos": Vector2(76, 72), "top": 22, "role": "mirror", "text": ""},
				],
			}
		"hall":
			return {
				"name": "The Hollow Flagon", "size": Vector2(464, 262), "art": "hub_in_hall",
				"walk": Rect2(10, 64, 440, 182), "spawn": Vector2(192, 80),
				"blocks": [Rect2(0, 56, 62, 92), Rect2(88, 62, 80, 76), Rect2(56, 102, 32, 20), Rect2(210, 72, 74, 40),
					Rect2(210, 134, 74, 40), Rect2(320, 88, 74, 130), Rect2(98, 198, 74, 36), Rect2(210, 198, 74, 36),
					Rect2(74, 202, 12, 14), Rect2(186, 202, 12, 14), Rect2(298, 202, 12, 14), Rect2(410, 202, 12, 14)],
				"exits": [{"rect": Rect2(180, 56, 24, 12), "to": "room", "at": Vector2(112, 76)},
					{"rect": Rect2(8, 240, 50, 10), "to": "village", "at": Vector2(124, 172)}],
				"people": [
					{"id": "barkeep", "name": "Oswin", "title": "Barkeep", "ghost": true, "pos": Vector2(130, 146), "top": 62, "role": "shop",
						"text": "The Hollow Flagon. Beds upstairs, stew in the pot, and a few things from the hill under the counter, if you have coin."},
					{"id": "patron", "name": "Old Wenna", "title": "Regular", "ghost": true, "solid": 7.0, "pos": Vector2(160, 192), "top": 30, "role": "chat",
						"text": "I was a girl when the hill last shook. We left bread at the gate, then. Nobody does now."},
				],
			}
		"elfwood":
			# the road through the Elfwood: quiet, a few elves who have not gone thorn-sick
			return {
				"name": "The Elfwood Road", "size": Vector2(640, 368), "outdoor": true, "walk": Rect2(30, 108, 580, 226), "spawn": Vector2(52, 204),
				"tint": Color(0.72, 0.84, 0.92),
				"props": [["hub_tree_teal_1", 320, 196, 8, 8], ["hub_rune_0", 214, 250, 9, 3], ["hub_rune_2", 250, 270, 5, 2], ["hub_bloom_0", 196, 160, 0, 2],
					["hub_bloom_5", 430, 290, 0, 2], ["hub_bloom_6", 470, 170, 0, 2], ["hub_shroom_0", 150, 292, 0, 1], ["hub_shroom_1", 520, 250, 0, 1],
					["hub_stump_0", 420, 232, 12, 4], ["hub_rock_moss_2", 110, 300, 14, 3], ["hub_bush_deep_1", 360, 300, 10, 4],
					["hub_bush_green_1", 150, 150, 12, 5], ["hub_vine_0", 560, 300, 0, 2], ["hub_tree_pink_4", 500, 140, 4, 5]],
				"paths": [[Vector2(-10, 204), Vector2(250, 210), Vector2(400, 190), Vector2(650, 196)]],
				"scatter": {"hub_tuft": [24, 90], "hub_flower": [26, 60], "hub_pebble": [20, 10], "hub_twig": [10, 14]},
				"forest": {"top_gaps": [], "behind": [], "open": [Rect2(-30, 150, 70, 120), Rect2(600, 140, 80, 120)]},
				"exits": [{"rect": Rect2(26, 176, 10, 60), "to": "village", "at": Vector2(660, 204)},
					{"rect": Rect2(604, 168, 10, 60), "to": "glade", "at": Vector2(50, 196)}],
				"people": [
					{"id": "aelin", "name": "Aelin", "title": "Elf of the Road", "sprite": "pc_elf_base", "hands": "pc_hand_elf_23",
						"pos": Vector2(270, 180), "face": -1, "role": "chat",
						"text": "Turn back, tin man. Past the glade our own kin wait with thorns in their eyes. The hunger under your hill is in the roots now."},
					{"id": "wicker", "name": "Wicker", "title": "Elf Child", "sprite": "pc_elf_druid", "hands": "pc_hand_elf_23",
						"pos": Vector2(440, 258), "face": 1, "role": "chat",
						"text": "The mushrooms walk at night. I counted nine. Mother says do not count them, they count back."},
				],
				"lights": [[Vector2(214, 236), Color(0.45, 0.85, 1.0), 1.2, 0.5], [Vector2(320, 150), Color(0.6, 1.0, 0.7), 1.6, 0.35],
					[Vector2(520, 236), Color(0.5, 1.0, 0.85), 0.9, 0.5]],
			}
		"glade":
			return {
				"name": "The Rune Glade", "size": Vector2(480, 330), "outdoor": true, "walk": Rect2(30, 108, 420, 190), "spawn": Vector2(50, 196),
				"tint": Color(0.66, 0.80, 0.92),
				"props": [["hub_rune_1", 300, 170, 12, 3], ["hub_rune_0", 250, 214, 9, 3], ["hub_rune_0", 352, 214, 9, 3], ["hub_rune_2", 276, 244, 5, 2],
					["hub_rune_2", 328, 244, 5, 2], ["hub_bloom_0", 210, 176, 0, 2], ["hub_bloom_5", 392, 180, 0, 2], ["hub_bloom_1", 300, 270, 0, 2],
					["hub_shroom_0", 400, 262, 0, 1], ["hub_shroom_2", 190, 258, 0, 1], ["hub_rock_moss_1", 420, 150, 14, 3], ["hub_vine_1", 150, 150, 0, 2]],
				"paths": [[Vector2(-10, 196), Vector2(160, 200), Vector2(270, 206)]],
				"scatter": {"hub_tuft": [24, 60], "hub_flower": [26, 50], "hub_pebble": [20, 8], "hub_twig": [10, 8]},
				"forest": {"top_gaps": [], "behind": [], "open": [Rect2(-30, 140, 70, 120)]},
				"exits": [{"rect": Rect2(26, 168, 10, 60), "to": "elfwood", "at": Vector2(588, 198)}],
				"people": [
					{"id": "thessaly", "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "hands": "pc_hand_elf_23",
						"pos": Vector2(300, 206), "face": -1, "role": "gate", "area": "forest",
						"text": "These stones open the deep wood. Two groves lie beyond, and a champion in each. Free them and the wood will remember you, knight."},
				],
				"lights": [[Vector2(300, 150), Color(0.45, 0.85, 1.0), 1.8, 0.7], [Vector2(250, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4],
					[Vector2(352, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4]],
			}
	return {
		"name": "The Village", "size": Hub.MAP, "outdoor": true, "walk": Hub.WALK, "spawn": Hub.SPAWN,
		"props": Hub.PROPS, "paths": Hub.PATHS, "scatter": Hub.SCATTER, "fire": Hub.FIRE, "grill": Hub.GRILL,
		"forest": {"top_gaps": [Hub.GATE_GAP, Hub.TAVERN_GAP], "behind": Hub.BEHIND_GATE, "open": Hub.OPEN},
		"blocks": Hub.BLOCKS, "exits": Hub.EXITS, "people": Hub.NPCS,
		"lights": [[Hub.FIRE - Vector2(0, 10), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Hub.GRILL - Vector2(0, 10), Color(1.0, 0.7, 0.45), 1.1, 0.5],
			[Vector2(146, 216), Color(0.45, 0.85, 1.0), 1.3, 0.5], [Vector2(360, 88), Color(0.75, 0.6, 1.0), 1.1, 0.4],
			[Vector2(590, 236), Color(1.0, 0.75, 0.5), 0.9, 0.35], [Vector2(124, 140), Color(1.0, 0.8, 0.5), 0.9, 0.45]],
	}
