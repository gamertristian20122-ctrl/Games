extends RefCounted
## Bosses: one row per boss. Use with:  const Bosses = preload("res://scripts/data/bosses.gd")
## To add a boss: add a row here and a file scripts/entities/bosses/<script>.gd with its attacks.
##   name     shown on the boss bar
##   sprite   an Art id. The Pixel Crawler pack has no boss sprites, so a boss is one of the floor's
##            creatures drawn at double size:  "scale": 2.0  (whole numbers only: it is pixel art)
##   hp       hit points on floor 1 (grows 45% per floor)
##   floors   which floors it guards (1 = first). If two bosses share a floor the run picks one.
##   script   file name in scripts/entities/bosses/ (without .gd)
##   speed, touch   like enemies.gd
##   radius   body circle in px          hit_up   how far above the feet the middle of the hit circle is (px)
##            (both measured from the sprite at its scale when left out; "radius" is kept here because
##            the boss files use it for charges and slams, "hit_up" is left to the measurement)
##   params   numbers the boss file understands

const ALL := {
	"gravekeeper": {"name": "The Gravekeeper", "sprite": "pc_zombie_muscle", "scale": 2.0, "hp": 150.0, "floors": [1, 3],
		"script": "gravekeeper", "speed": 26.0, "radius": 12.0, "touch": 1, "shot": "enemy",
		"params": {"charge_speed": 170.0, "slam_radius": 40.0}},
	"stonejaw": {"name": "Stonejaw", "sprite": "pc_orc_warrior", "scale": 2.0, "hp": 150.0, "floors": [2, 4],
		"script": "stonejaw", "speed": 30.0, "radius": 13.0, "touch": 1, "shot": "enemy",
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
