extends RefCounted
## Places: every screen the knight can WALK around in outside the hill. scripts/hub/hub.gd shows
## one at a time and moves between them through their exits (a short fade).
##   village   the camp grown into a small village (its things are in scripts/data/hub.gd)
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
	return {
		"name": "The Village", "size": Hub.MAP, "outdoor": true, "walk": Hub.WALK, "spawn": Hub.SPAWN,
		"props": Hub.PROPS, "paths": Hub.PATHS, "scatter": Hub.SCATTER, "fire": Hub.FIRE, "grill": Hub.GRILL,
		"forest": {"top_gaps": [Hub.GATE_GAP, Hub.TAVERN_GAP], "behind": Hub.BEHIND_GATE},
		"blocks": Hub.BLOCKS, "exits": Hub.EXITS, "people": Hub.NPCS,
		"lights": [[Hub.FIRE - Vector2(0, 10), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Hub.GRILL - Vector2(0, 10), Color(1.0, 0.7, 0.45), 1.1, 0.5],
			[Vector2(146, 216), Color(0.45, 0.85, 1.0), 1.3, 0.5], [Vector2(360, 88), Color(0.75, 0.6, 1.0), 1.1, 0.4],
			[Vector2(590, 236), Color(1.0, 0.75, 0.5), 0.9, 0.35], [Vector2(124, 140), Color(1.0, 0.8, 0.5), 0.9, 0.45]],
	}
