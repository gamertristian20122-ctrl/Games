extends RefCounted
## Bosses: one row per boss. Use with:  const Bosses = preload("res://scripts/data/bosses.gd")
## To add a boss: add a row here and a file scripts/entities/bosses/<script>.gd with its attacks.
##   name     shown on the boss bar          sprite   an Art id (the 32x36 giants look best)
##   hp       hit points on floor 1 (grows 45% per floor)
##   floors   which floors it guards (1 = first). If two bosses share a floor the run picks one.
##   script   file name in scripts/entities/bosses/ (without .gd)
##   speed, radius, touch   like enemies.gd      hit_up   how far above the feet shots still hit (px)
##   params   numbers the boss file understands

const ALL := {
	"gravekeeper": {"name": "The Gravekeeper", "sprite": "big_zombie", "hp": 150.0, "floors": [1, 3],
		"script": "gravekeeper", "speed": 26.0, "radius": 9.0, "hit_up": 6.0, "touch": 1, "shot": "enemy",
		"params": {"charge_speed": 170.0, "slam_radius": 40.0}},
	"stonejaw": {"name": "Stonejaw", "sprite": "ogre", "hp": 150.0, "floors": [2, 4],
		"script": "stonejaw", "speed": 30.0, "radius": 9.0, "hit_up": 6.0, "touch": 1, "shot": "enemy",
		"params": {"leap_time": 0.9, "shock_radius": 34.0}},
}

const HP_PER_FLOOR := 0.45


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL["gravekeeper"])


## Boss ids that guard a floor (floor_number 1 = first floor). Never empty.
static func for_floor(floor_number: int) -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		if (ALL[id]["floors"] as Array).has(floor_number):
			out.append(id)
	if out.is_empty():
		out.append(ALL.keys()[0])
	return out
