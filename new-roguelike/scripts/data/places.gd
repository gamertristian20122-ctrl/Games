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
## THE WIDE WORLD (v0.10.0): "world" is one giant map shown ZOOMED OUT. The knight is drawn big on it and
## covers ground fast. Camps and fight areas are spots on it. Extra keys a place may have:
##   "zoom"        0.5 = the camera shows twice as much        "hero_scale", "speed"  the knight's size and pace
##   "ground"      the tile laid under everything (default the forest grass)
##   "regions"     [[tile id, [corner points]]] other ground laid over it in big ragged patches
##   "floor"       [[tile id, Rect2]] a paved rectangle        "decals"  [[piece, x, y]] flat things on the ground
##   "shades"      [Rect2] flat dark rectangles (a doorway)
##   "groves"      [{"rect", "ids", "n", "solid"}] pieces scattered at random (the same every time), kept
##                 off the paths and away from the signs
##   "signs"       [{"text", "pos", "sites" or "need"}] a name floating over a spot on the map: gold = open
##                 with work to do, grey = still shut, green = done
##   "camp"        0, 1, 2: walking in makes this the camp the game opens in next time
##   an exit may have "need" (a level id that must be cleared) and "why" (said while it is not)
##   a "gate" person lists "sites": the sites of scripts/data/story.gd whose levels are entered there
##   "as": "smith"  a person who sells what the village smith sells (upgrades, weapons)
##   "forest" may give its own "big", "side", "low", "young" lists (the edge of a desert camp is not trees)
## Interiors are cut from the pack's own tavern picture (tools/import_hub.py, HALVED), so their
## numbers below are pixels of those pictures.

const Hub = preload("res://scripts/data/hub.gd")
const Tale = preload("res://scripts/data/tale.gd")

const START := "room"            ## where Play puts you


## The place with this id. While the story of scripts/data/tale.gd is on, the village is the
## town of Wickmere, the Deepwood and the beacon's hill exist, and the Elfwood's two old places
## are fitted to the story (who stands there, where the roads lead, how light it is).
static func get_place(id: String) -> Dictionary:
	if not Tale.on():
		return _base_place(id)
	match id:
		"village":
			return Tale.town()
		"deepwood":
			return Tale.deepwood()
		"beacon":
			return Tale.beacon()
	var place := _base_place(id)
	# DEPTH (scripts/hub/view3d.gd): where the ground climbs, the hills, the water of each place
	match id:
		"elfwood":
			place["rise"] = {"from": 100.0, "over": 84.0, "height": 44.0}
			place["hills"] = [{"at": Vector2(486, 300), "radius": 120.0, "height": 16.0, "top": 24.0}, {"at": Vector2(120, 150), "radius": 100.0, "height": 14.0}]
			place["water"] = [{"at": Vector2(252, 312), "radius": Vector2(58, 17)}]
			(place["forest"] as Dictionary)["open"] = ((place["forest"] as Dictionary)["open"] as Array) + [Rect2(180, 330, 150, 60)]
		"glade":
			place["rise"] = {"from": 100.0, "over": 84.0, "height": 48.0}
			place["hills"] = [{"at": Vector2(300, 208), "radius": 128.0, "height": 13.0, "top": 74.0}]      # the rune ring stands on a low rise
		"world":
			# Hollow Hill over its gate, the Cinder Mountains in the north-east, dunes in the sands, low wooded hills
			place["hills"] = [{"at": Vector2(300, 462), "radius": 180.0, "height": 76.0}, {"at": Vector2(1700, 150), "radius": 430.0, "height": 112.0},
				{"at": Vector2(1440, 110), "radius": 270.0, "height": 70.0}, {"at": Vector2(1960, 210), "radius": 260.0, "height": 84.0},
				{"at": Vector2(1250, 940), "radius": 210.0, "height": 26.0}, {"at": Vector2(1040, 380), "radius": 190.0, "height": 22.0},
				{"at": Vector2(1500, 730), "radius": 220.0, "height": 22.0}, {"at": Vector2(150, 240), "radius": 270.0, "height": 52.0},
				{"at": Vector2(600, 960), "radius": 250.0, "height": 40.0}]
			place["water"] = [{"at": Vector2(430, 812), "radius": Vector2(92, 40)}, {"at": Vector2(1424, 664), "radius": Vector2(58, 26)}]
			(place["exits"] as Array)[0]["at"] = Vector2(480, 500)          # Wickmere's south gate
	if id == "elfwood" or id == "glade":
		place["tint"] = Color(0.98, 0.93, 0.80) if Tale.lit("elfwood") else place["tint"]
		if id == "elfwood":
			(place["exits"] as Array)[0]["at"] = Vector2(896, 280)        # back to Wickmere's east gate
		else:
			(place["exits"] as Array).append({"rect": Rect2(444, 168, 10, 60), "to": "deepwood", "at": Vector2(50, 230), "tale": 3,
				"why": "Thessaly holds the stones alone. Speak with her."})
			(place["forest"] as Dictionary)["open"] = [Rect2(-30, 140, 70, 120), Rect2(440, 140, 80, 120)]
			(place["paths"] as Array).append([Vector2(300, 206), Vector2(490, 198)])
			for row: Dictionary in place["people"]:
				if String(row["id"]) == "thessaly":
					row["role"] = "chat"
					row["tale_to"] = 2                                    # after that she walks with the knight
	return place


static func _base_place(id: String) -> Dictionary:
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
						"pos": Vector2(300, 206), "face": -1, "role": "gate", "sites": ["forest"],
						"text": "These stones open the deep wood. Two groves lie beyond, and a champion in each. Free them and the wood will remember you, knight."},
				],
				"lights": [[Vector2(300, 150), Color(0.45, 0.85, 1.0), 1.8, 0.7], [Vector2(250, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4],
					[Vector2(352, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4]],
			}
	if id == "world":
		return _world()
	if id == "dustwatch":
		return _dustwatch()
	if id == "emberfall":
		return _emberfall()
	return {
		"name": "The Village", "camp": 0, "size": Hub.MAP, "outdoor": true, "walk": Hub.WALK, "spawn": Hub.SPAWN,
		"props": Hub.PROPS, "paths": Hub.PATHS, "scatter": Hub.SCATTER, "fire": Hub.FIRE, "grill": Hub.GRILL,
		"forest": {"top_gaps": [Hub.GATE_GAP, Hub.TAVERN_GAP], "behind": Hub.BEHIND_GATE, "open": Hub.OPEN},
		"blocks": Hub.BLOCKS, "exits": Hub.EXITS, "people": Hub.NPCS,
		"lights": [[Hub.FIRE - Vector2(0, 10), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Hub.GRILL - Vector2(0, 10), Color(1.0, 0.7, 0.45), 1.1, 0.5],
			[Vector2(146, 216), Color(0.45, 0.85, 1.0), 1.3, 0.5], [Vector2(360, 88), Color(0.75, 0.6, 1.0), 1.1, 0.4],
			[Vector2(590, 236), Color(1.0, 0.75, 0.5), 0.9, 0.35], [Vector2(124, 140), Color(1.0, 0.8, 0.5), 0.9, 0.45]],
	}


## Where Play puts you: your room at the Hollow Flagon, or by the fire of the camp you last walked into.
static func start() -> Array:
	if Tale.on():
		return [START, Vector2.INF]            # the story: always your room at the Hollow Flagon
	match Save.hub_get("camp"):
		1:
			return ["dustwatch", Vector2(320, 300)]
		2:
			return ["emberfall", Vector2(300, 292)]
	return [START, Vector2.INF]


## The giant map. West: the woods round Hollow Hill. Middle and south-east: the sands. North-east: the
## Cinder Mountains. Everything is in map pixels; the camera shows it at half size.
static func _world() -> Dictionary:
	var trees := ["hub_tree_green_1", "hub_tree_green_2", "hub_tree_teal_2", "hub_tree_green_3", "hub_tree_pink_2", "hub_tree_teal_3", "hub_bush_green_1", "hub_tree_green_2"]
	var elf := ["hub_tree_teal_1", "hub_tree_pink_1", "hub_tree_teal_2", "hub_tree_pink_2", "hub_bloom_0", "hub_tree_teal_3", "hub_rune_2"]
	var dry := ["hub_cactus_4", "hub_cactus_3", "hub_dbush_0", "hub_dbush_1", "hub_dstone_1", "hub_cactus_2", "hub_dtree_1", "hub_dstone_2", "hub_dshrub", "hub_tusk_2", "hub_cactus_0", "hub_dtree_0"]
	var crag := ["hub_rock_2", "hub_rock_1", "hub_dtree_0", "hub_rock_0", "hub_rock_3", "hub_dtree_1", "hub_stone_2", "hub_rock_2"]
	return {
		"name": "The Wide World", "size": Vector2(2000, 1120), "outdoor": true, "walk": Rect2(40, 70, 1920, 1010), "spawn": Vector2(300, 650),
		"zoom": 0.5, "hero_scale": 2.0, "speed": 2.5, "tint": Color(0.86, 0.90, 0.94),
		"regions": [
			["hub_sand", [Vector2(880, -80), Vector2(920, 140), Vector2(850, 320), Vector2(910, 480), Vector2(840, 660), Vector2(890, 840), Vector2(830, 1010), Vector2(870, 1200),
				Vector2(2080, 1200), Vector2(2080, -80)]],
			["hub_drock", [Vector2(1330, -80), Vector2(1310, 110), Vector2(1390, 240), Vector2(1400, 380), Vector2(1500, 450), Vector2(1640, 410), Vector2(1770, 460),
				Vector2(1900, 420), Vector2(2080, 460), Vector2(2080, -80)]],
		],
		"paths": [
			[Vector2(300, 610), Vector2(310, 660), Vector2(480, 676), Vector2(720, 668), Vector2(860, 660)],
		],
		"trails": [      # on sand and rock a road is a line of small stones
			[Vector2(900, 660), Vector2(1120, 660)], [Vector2(1140, 680), Vector2(1190, 800), Vector2(1250, 930)],
			[Vector2(1150, 640), Vector2(1340, 580), Vector2(1570, 540)], [Vector2(1590, 480), Vector2(1650, 370), Vector2(1780, 300)],
			[Vector2(1150, 670), Vector2(1400, 770), Vector2(1650, 890)],
		],
		"scatter": {"hub_tuft": [24, 150], "hub_flower": [26, 90], "hub_pebble": [20, 26], "hub_twig": [10, 20]},
		"scatter_rect": Rect2(20, 60, 800, 1040),
		"groves": [
			{"rect": Rect2(40, 70, 760, 420), "ids": trees, "n": 46, "solid": 7.0},
			{"rect": Rect2(420, 110, 360, 330), "ids": elf, "n": 30, "solid": 7.0},
			{"rect": Rect2(40, 740, 760, 330), "ids": trees, "n": 42, "solid": 7.0},
			{"rect": Rect2(940, 70, 340, 440), "ids": dry, "n": 26, "solid": 6.0},
			{"rect": Rect2(940, 720, 1000, 350), "ids": dry, "n": 54, "solid": 6.0},
			{"rect": Rect2(1300, 480, 640, 220), "ids": dry, "n": 22, "solid": 6.0},
			{"rect": Rect2(940, 70, 1000, 1000), "ids": ["hub_dgrass_0", "hub_dgrass_1", "hub_dgrass_2", "hub_dgrass_3", "hub_dblock_2", "hub_dblock_3"], "n": 150, "solid": 0.0, "poly": 0},
			{"rect": Rect2(1420, 70, 520, 300), "ids": crag, "n": 34, "solid": 7.0},
		],
		"props": [
			# Hollow Hill: the crypt gate in its rocks, the tavern below it
			["hub_rock_2", 258, 548, 0, 2], ["hub_rock_moss_2", 344, 549, 0, 2], ["hub_gate_0", 300, 552, 0, 0],
			["hub_wall_plaster", 196, 620, 0, 0], ["hub_roof_wood", 196, 621, 0, -50], ["hub_doorway", 196, 622, 0, 0],
			["hub_rune_1", 400, 612, 10, 3], ["hub_rune_0", 428, 632, 8, 3],
			# the Robber Road: a barricade of stumps and a scarecrow in stolen mail
			["hub_farm_2", 700, 640, 5, 1], ["hub_stump_0", 742, 650, 10, 4], ["hub_stump_1", 690, 690, 7, 3], ["hub_bench_long", 752, 694, 10, 2],
			# Dustwatch: two obelisks either side of the dig
			["hub_obelisk_0", 1076, 634, 12, 2], ["hub_obelisk_1", 1166, 634, 12, 2], ["hub_dstairs", 1120, 628, 0, 0], ["hub_dpot_0", 1090, 650, 0, 1], ["hub_dchest", 1152, 652, 0, 1],
			# the Bone Dunes
			["hub_tusk_0", 1206, 912, 10, 3], ["hub_tusk_1", 1296, 904, 8, 3], ["hub_tusk_2", 1262, 880, 6, 2], ["hub_tusk_1", 1180, 950, 8, 3],
			# the Cinder Pass: a cave mouth where the sand meets the rock
			["hub_dcave", 1570, 520, 0, 0], ["hub_dboulder_0", 1516, 524, 14, 2], ["hub_dboulder_1", 1622, 522, 10, 2],
			# Emberfall: the forge arch and its makers in stone
			["hub_farch", 1780, 268, 0, 0], ["hub_fbust", 1736, 274, 9, 2], ["hub_fbroken", 1824, 274, 9, 2], ["hub_fbarrel_1", 1716, 290, 0, 1], ["hub_fcrate_1", 1846, 292, 0, 1],
			# the Sunken Archive
			["hub_ddoor", 1650, 862, 0, 0], ["hub_dpillar_0", 1606, 868, 6, 2], ["hub_dpillar_2", 1694, 868, 6, 2], ["hub_dpillar_3", 1590, 884, 5, 2], ["hub_dpillar_1", 1716, 890, 6, 2],
			["hub_dstone_0", 1740, 850, 9, 2],
		],
		"decals": [["hub_flava", 1690, 330], ["hub_flava", 1870, 330], ["hub_drockbed", 1570, 470], ["hub_drockbed", 1500, 500], ["hub_drockbed", 1640, 490]],
		"shades": [Rect2(1764, 206, 32, 60)],
		"blocks": [Rect2(268, 500, 64, 50), Rect2(132, 566, 128, 54), Rect2(1088, 580, 64, 48), Rect2(1540, 462, 60, 56), Rect2(1756, 196, 48, 70), Rect2(1618, 816, 64, 44),
			Rect2(1666, 306, 48, 48), Rect2(1846, 306, 48, 48)],
		"exits": [
			{"rect": Rect2(270, 552, 60, 40), "to": "village", "at": Vector2(360, 400)},
			{"rect": Rect2(1094, 628, 52, 18), "to": "dustwatch", "at": Vector2(320, 366), "need": "road",
				"why": "Robbers hold the road east. Clear the Robber Road first."},
			{"rect": Rect2(1756, 266, 48, 18), "to": "emberfall", "at": Vector2(300, 350), "need": "pass",
				"why": "Nobody gets through the Cinder Pass alive. Clear it first."},
		],
		"signs": [
			{"text": "Hollow Hill", "pos": Vector2(300, 470), "sites": ["hill", "deep"]},
			{"text": "The Elfwood", "pos": Vector2(600, 130)},
			{"text": "The Robber Road", "pos": Vector2(720, 590), "sites": ["road"]},
			{"text": "Dustwatch", "pos": Vector2(1120, 490), "need": "road", "sites": ["dust"]},
			{"text": "The Bone Dunes", "pos": Vector2(1250, 826), "sites": ["dunes"]},
			{"text": "The Cinder Pass", "pos": Vector2(1570, 436), "sites": ["pass"]},
			{"text": "Emberfall", "pos": Vector2(1780, 170), "need": "pass", "sites": ["ember"]},
			{"text": "The Sunken Archive", "pos": Vector2(1650, 790), "sites": ["archive"]},
		],
		"people": [
			{"id": "site_road", "name": "The Robber Road", "title": "A barricade across the east road", "ghost": true, "pos": Vector2(720, 668), "top": 30, "role": "gate", "sites": ["road"],
				"text": "A barricade of stumps across the east road. Beyond it the woods are full of robbers, and somewhere among them the one they call the Road King."},
			{"id": "site_dunes", "name": "The Bone Dunes", "title": "Tusks in the sand", "ghost": true, "pos": Vector2(1250, 934), "top": 30, "role": "gate", "sites": ["dunes"],
				"text": "Great tusks stand out of the sand, and between them shapes that were people once. Whatever made them is still in there."},
			{"id": "site_pass", "name": "The Cinder Pass", "title": "A way under the mountain", "ghost": true, "pos": Vector2(1570, 544), "top": 30, "role": "gate", "sites": ["pass"],
				"text": "The old mine road runs under the mountain here. Warm air comes out of it, and the slow sound of something heavy walking."},
			{"id": "site_archive", "name": "The Sunken Archive", "title": "A door half under the sand", "ghost": true, "pos": Vector2(1650, 884), "top": 30, "role": "gate", "sites": ["archive"],
				"text": "A sandstone door, half buried. The orders kept their writings here. Something inside is still keeping them."},
			{"id": "site_elfwood", "name": "The Elfwood", "title": "", "ghost": true, "pos": Vector2(600, 470), "top": 30, "role": "chat",
				"text": "The Elfwood. The road into it leaves the village by its east side."},
		],
		"lights": [[Vector2(300, 600), Color(1.0, 0.8, 0.5), 2.2, 0.5], [Vector2(1120, 640), Color(1.0, 0.8, 0.5), 2.2, 0.5], [Vector2(1780, 280), Color(1.0, 0.55, 0.3), 2.6, 0.7],
			[Vector2(1690, 330), Color(1.0, 0.5, 0.2), 1.6, 0.8], [Vector2(1870, 330), Color(1.0, 0.5, 0.2), 1.6, 0.8], [Vector2(414, 610), Color(0.45, 0.85, 1.0), 1.4, 0.5]],
	}


## Dustwatch: the diggers' camp in the eastern sands, over the stair down to the Warrens.
static func _dustwatch() -> Dictionary:
	return {
		"name": "Dustwatch", "camp": 1, "size": Vector2(640, 430), "outdoor": true, "walk": Rect2(30, 104, 580, 290), "spawn": Vector2(320, 366),
		"ground": "hub_sand", "tint": Color(0.96, 0.88, 0.78), "fire": Vector2(320, 286),
		"floor": [["hub_paving", Rect2(224, 208, 192, 128)]],
		"props": [
			["hub_ddoor", 320, 152, 0, 0], ["hub_dstairs", 320, 200, 0, 0],
			["hub_obelisk_0", 150, 190, 12, 2], ["hub_obelisk_1", 492, 190, 12, 2], ["hub_obelisk_2", 548, 318, 12, 2],
			["hub_dpillar_0", 262, 204, 6, 2], ["hub_dpillar_1", 378, 204, 6, 2],
			["hub_dchest", 470, 262, 10, 2], ["hub_dpot_0", 494, 270, 5, 1], ["hub_dpot_1", 452, 274, 4, 1], ["hub_dpot_1", 118, 312, 4, 1], ["hub_dpot_0", 102, 318, 5, 1],
			["hub_anvil_0", 160, 300, 16, 4], ["hub_dstone_2", 124, 262, 10, 2],
			["hub_cactus_4", 76, 206, 8, 2], ["hub_cactus_3", 574, 236, 6, 2], ["hub_dbush_1", 566, 366, 8, 3], ["hub_dtree_1", 84, 370, 5, 2], ["hub_tusk_2", 236, 160, 6, 2],
			["hub_dblock_0", 410, 350, 0, 1], ["hub_dblock_1", 230, 356, 0, 1],
		],
		"scatter": {"hub_dgrass": [4, 46], "hub_dblock": [4, 10]},
		"forest": {"top_gaps": [[250.0, 390.0]], "behind": [], "open": [Rect2(250, 390, 140, 90)],
			"big": ["hub_dstone_0", "hub_dtree_0", "hub_dstone_1", "hub_tusk_1", "hub_obelisk_2", "hub_dbush_0"],
			"side": ["hub_cactus_4", "hub_dbush_0", "hub_cactus_3", "hub_dstone_1"],
			"low": ["hub_dshrub", "hub_dbush_2", "hub_cactus_1", "hub_cactus_0", "hub_dstone_2", "hub_dbush_2"],
			"young": ["hub_dtree_1", "hub_cactus_2", "hub_dbush_1"]},
		"blocks": [Rect2(288, 104, 64, 96)],
		"exits": [{"rect": Rect2(270, 386, 100, 10), "to": "world", "at": Vector2(1120, 690)}],
		"people": [
			{"id": "sefa", "name": "Captain Sefa", "title": "Keeper of the Cistern Stair", "sprite": "pc_royal_archer", "hands": "pc_hand_castle_17",
				"pos": Vector2(374, 214), "face": -1, "role": "gate", "sites": ["dust"],
				"text": "The cistern stair goes down into the Warrens. When the dunes are quiet, it is yours."},
			{"id": "grukk", "name": "Grukk", "title": "Smith, late of the Warrens", "sprite": "pc_orc_warrior", "hands": "pc_hand_base_9",
				"pos": Vector2(196, 306), "face": 1, "role": "chat", "as": "smith", "text": ""},
			{"id": "nib", "name": "Nib", "title": "Sand Trader", "sprite": "pc_npc_tavern_b", "hands": "pc_hand_base_2",
				"pos": Vector2(430, 276), "face": -1, "role": "shop", "text": "Pots, charms, things the sand gave up. All honest. Mostly honest."},
			{"id": "imre", "name": "Sister Imre", "title": "Reader of Walls", "sprite": "pc_scholar_cataloguer", "hands": "pc_hand_library_6",
				"pos": Vector2(226, 214), "face": 1, "role": "quests", "text": "I keep the camp's list of work. Do it, and your pack will be heavier."},
			{"id": "dustfire", "name": "The camp fire", "title": "A place to rest", "ghost": true, "pos": Vector2(320, 300), "top": 22, "role": "bed", "text": ""},
		],
		"lights": [[Vector2(320, 276), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Vector2(320, 150), Color(0.45, 0.75, 1.0), 1.2, 0.4]],
	}


## Emberfall: what is left of the smiths' town in the Cinder Mountains, at the door of the forge.
static func _emberfall() -> Dictionary:
	return {
		"name": "Emberfall", "camp": 2, "size": Vector2(600, 420), "outdoor": true, "walk": Rect2(30, 104, 540, 280), "spawn": Vector2(300, 350),
		"ground": "hub_drock", "tint": Color(0.80, 0.74, 0.80), "fire": Vector2(300, 276),
		"floor": [["hub_fflag", Rect2(204, 150, 192, 192)]],
		"decals": [["hub_flava", 110, 200], ["hub_flava", 490, 200]],
		"shades": [Rect2(284, 92, 32, 58)],
		"props": [
			["hub_farch", 300, 152, 0, 0], ["hub_fbust", 246, 158, 9, 2], ["hub_fbust", 354, 158, 9, 2], ["hub_fbroken", 430, 176, 9, 2],
			["hub_fbarrel_0", 160, 262, 5, 1], ["hub_fbarrel_1", 176, 268, 5, 1], ["hub_fbarrel_2", 128, 330, 5, 1],
			["hub_fcrate_1", 452, 286, 10, 2], ["hub_fcrate_0", 480, 294, 6, 2], ["hub_fchest", 428, 316, 10, 2],
			["hub_anvil_0", 190, 318, 16, 4], ["hub_bench_1", 150, 300, 12, 3],
			["hub_dtree_1", 70, 360, 5, 2], ["hub_rock_1", 540, 350, 12, 3], ["hub_rock_3", 70, 250, 8, 2],
		],
		"scatter": {"hub_pebble": [20, 30], "hub_dblock": [4, 8]},
		"forest": {"top_gaps": [[236.0, 364.0]], "behind": [], "open": [Rect2(230, 380, 140, 90)],
			"big": ["hub_rock_2", "hub_dtree_0", "hub_rock_1", "hub_fbroken", "hub_rock_moss_2", "hub_dtree_0"],
			"side": ["hub_dtree_1", "hub_rock_0", "hub_rock_2"],
			"low": ["hub_rock_3", "hub_stone_2", "hub_fbarrel_1", "hub_rock_0", "hub_fcrate_0", "hub_stone_1"],
			"young": ["hub_dtree_1"]},
		"blocks": [Rect2(272, 96, 56, 54), Rect2(86, 176, 48, 48), Rect2(466, 176, 48, 48)],
		"exits": [{"rect": Rect2(250, 376, 100, 10), "to": "world", "at": Vector2(1780, 318)}],
		"people": [
			{"id": "bryn", "name": "Forgemaster Bryn", "title": "Keeper of the Forge Door", "sprite": "pc_royal_soldier", "hands": "pc_hand_castle_17",
				"pos": Vector2(346, 196), "face": -1, "role": "gate", "sites": ["ember"],
				"text": "The Iron seal was forged behind this arch. Its makers are still in there."},
			{"id": "kessa", "name": "Old Kessa", "title": "Farrier", "sprite": "pc_npc_tavern_a", "hands": "pc_hand_base_2",
				"pos": Vector2(226, 322), "face": -1, "role": "chat", "as": "smith", "text": ""},
			{"id": "aurel", "name": "Brother Aurel", "title": "Pilgrim", "sprite": "pc_royal_priest", "hands": "pc_hand_castle_17",
				"pos": Vector2(394, 232), "face": -1, "role": "quests", "text": "I keep a list of what needs doing. It is long."},
			{"id": "pell", "name": "Pell", "title": "Scavenger", "sprite": "pc_npc_peasant_a", "hands": "pc_hand_base_2",
				"pos": Vector2(404, 312), "face": 1, "role": "shop", "text": "I sell what the miners left when they ran."},
			{"id": "emberfire", "name": "The brazier", "title": "A place to rest", "ghost": true, "pos": Vector2(300, 290), "top": 22, "role": "bed", "text": ""},
		],
		"lights": [[Vector2(300, 266), Color(1.0, 0.6, 0.35), 2.1, 0.8], [Vector2(110, 200), Color(1.0, 0.5, 0.2), 1.6, 0.9], [Vector2(490, 200), Color(1.0, 0.5, 0.2), 1.6, 0.9],
			[Vector2(300, 130), Color(1.0, 0.45, 0.25), 1.2, 0.6]],
	}
