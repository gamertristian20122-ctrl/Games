class_name FloorDB
## The three floors of a run, top of the lighthouse to the bottom of the caves.
##
## HOW TO EDIT
##  - "rooms" is how many fights come before the boss.
##  - "enemies" lists who can appear and how common each is (bigger = more).
##  - "budget_start" is the danger budget of the first room; every later
##    room adds "budget_step". See "cost" in enemy_db.gd.
##  - "wave_cap" is the most danger allowed on screen at once. A room whose
##    budget is bigger arrives in several waves.
##  - "hp_scale" multiplies enemy health on this floor.
##  - "danger" speeds up enemy shots and how often they fire (1.0 = normal).

const FLOORS := [
	{
		"name": "The Lamp Tower",
		"blurb": "Something from the sea has put out the light.",
		"accent": Color("e3b04b"),
		"wall_tiles": [Vector2i(0, 13), Vector2i(6, 13)],
		"obstacles": [Vector2i(13, 18), Vector2i(13, 13), Vector2i(14, 13)],
		"rooms": 5,
		"enemies": {"clawling": 6, "bat": 4, "spitter": 3, "gull": 2},
		"budget_start": 8.0, "budget_step": 3.0, "wave_cap": 10.0,
		"hp_scale": 1.0, "danger": 1.0,
		"boss": "clatterclaw",
	},
	{
		"name": "The Cliff Cellars",
		"blurb": "Barrels, brine, and things that should not have come up the stairs.",
		"accent": Color("58c7a6"),
		"wall_tiles": [Vector2i(0, 13), Vector2i(6, 15)],
		"obstacles": [Vector2i(13, 13), Vector2i(14, 13), Vector2i(13, 18)],
		"rooms": 5,
		"enemies": {"crab": 4, "blob": 4, "wisp": 4, "urchin": 2, "spitter": 3, "clawling": 4, "bat": 3},
		"budget_start": 17.0, "budget_step": 3.5, "wave_cap": 14.0,
		"hp_scale": 1.8, "danger": 1.18,
		"boss": "diver",
	},
	{
		"name": "The Tide Caves",
		"blurb": "The stolen flame glows somewhere below the waterline.",
		"accent": Color("6f8dff"),
		"wall_tiles": [Vector2i(6, 0), Vector2i(7, 0)],
		"obstacles": [Vector2i(20, 5), Vector2i(19, 6), Vector2i(20, 6)],
		"rooms": 5,
		"enemies": {"eel": 4, "inkling": 4, "puffer": 3, "lurker": 3, "wisp": 2, "urchin": 2},
		"budget_start": 24.0, "budget_step": 4.5, "wave_cap": 18.0,
		"hp_scale": 3.0, "danger": 1.25,
		"boss": "undertow",
	},
]


static func count() -> int:
	return FLOORS.size()


static func get_floor(index: int) -> Dictionary:
	return FLOORS[clampi(index, 0, FLOORS.size() - 1)]


## Total number of rooms in a whole run, bosses included.
static func total_rooms() -> int:
	var n := 0
	for f: Dictionary in FLOORS:
		n += int(f["rooms"]) + 1
	return n
