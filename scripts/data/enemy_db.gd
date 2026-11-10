class_name EnemyDB
## Every enemy and boss, with its numbers.
##
## HOW TO EDIT
##  - "hp" is health, "speed" is pixels per second.
##  - "cost" is how much of a room's danger budget one of them uses up.
##    Cheap enemies come in crowds, costly ones come alone.
##  - "ai" picks the behaviour (see scripts/enemy.gd):
##        chase    walks at you
##        flit     flies at you in swoops
##        shoot    keeps its distance and fires aimed shots
##        charge   stops, shakes, then rushes in a straight line
##        split    slow walker that breaks into smaller ones
##        orbit    circles you and fires
##        turret   sits still and fires rings of shots
##        bomb     runs at you and bursts
##        burrow   digs under the floor and pops up near you
##  - "frames" are the pictures it flips between (column, row on the sheet).

const ENEMIES := {
	# ---------------- Floor 1: the Lamp Tower ----------------
	"clawling": {
		"name": "Clawling", "ai": "chase",
		"frames": [Vector2i(18, 7), Vector2i(19, 7)],
		"hp": 24.0, "speed": 44.0, "radius": 6.0, "cost": 1,
		"color": Color("ff8f7a"),
	},
	"bat": {
		"name": "Belfry Bat", "ai": "flit", "flying": true,
		"frames": [Vector2i(26, 8)],
		"hp": 14.0, "speed": 78.0, "radius": 5.0, "cost": 1,
		"color": Color("c9a2ff"),
	},
	"spitter": {
		"name": "Spitter", "ai": "shoot",
		"frames": [Vector2i(18, 8), Vector2i(19, 8)],
		"hp": 20.0, "speed": 30.0, "radius": 6.0, "cost": 2,
		"shot_speed": 80.0, "shot_every": 2.2, "keep_min": 60.0, "keep_max": 110.0,
		"color": Color("ffb86b"),
	},
	"gull": {
		"name": "Storm Gull", "ai": "charge", "flying": true,
		"frames": [Vector2i(25, 7)],
		"hp": 26.0, "speed": 42.0, "radius": 6.0, "cost": 2,
		"charge_speed": 190.0, "charge_range": 100.0, "windup": 0.55, "charge_time": 0.65, "rest": 0.9,
		"color": Color("e8f1ff"),
	},

	# ---------------- Floor 2: the Cliff Cellars ----------------
	"crab": {
		"name": "Cellar Crab", "ai": "charge",
		"frames": [Vector2i(25, 5)],
		"hp": 44.0, "speed": 36.0, "radius": 7.0, "cost": 3,
		"charge_speed": 175.0, "charge_range": 90.0, "windup": 0.6, "charge_time": 0.7, "rest": 1.0,
		"color": Color("ff7a6b"),
	},
	"blob": {
		"name": "Bilge Blob", "ai": "split",
		"frames": [Vector2i(27, 8)],
		"hp": 40.0, "speed": 28.0, "radius": 7.0, "cost": 3,
		"split_into": "droplet", "split_count": 2,
		"color": Color("8fe3a0"),
	},
	"droplet": {
		"name": "Droplet", "ai": "chase",
		"frames": [Vector2i(27, 8)],
		"hp": 12.0, "speed": 62.0, "radius": 4.0, "cost": 1, "scale": 0.65,
		"color": Color("b8f5c2"),
	},
	"wisp": {
		"name": "Drowned Wisp", "ai": "orbit", "flying": true,
		"frames": [Vector2i(26, 6)],
		"hp": 22.0, "speed": 54.0, "radius": 6.0, "cost": 2,
		"shot_speed": 78.0, "shot_every": 2.6, "orbit_radius": 78.0,
		"color": Color("9fd0ff"),
	},
	"urchin": {
		"name": "Wall Urchin", "ai": "turret",
		"frames": [Vector2i(27, 11)],
		"hp": 50.0, "speed": 0.0, "radius": 7.0, "cost": 3,
		"shot_speed": 62.0, "shot_every": 2.8, "ring": 8,
		"color": Color("d59bff"),
	},

	# ---------------- Floor 3: the Tide Caves ----------------
	"eel": {
		"name": "Cave Eel", "ai": "charge",
		"frames": [Vector2i(28, 8)],
		"hp": 34.0, "speed": 50.0, "radius": 6.0, "cost": 3,
		"charge_speed": 240.0, "charge_range": 120.0, "windup": 0.45, "charge_time": 0.55, "rest": 0.8,
		"color": Color("7fe0d0"),
	},
	"inkling": {
		"name": "Inkling", "ai": "shoot",
		"frames": [Vector2i(25, 8)],
		"hp": 36.0, "speed": 32.0, "radius": 6.0, "cost": 3,
		"shot_speed": 86.0, "shot_every": 2.1, "keep_min": 70.0, "keep_max": 120.0, "spread": 3,
		"color": Color("ff9bd2"),
	},
	"puffer": {
		"name": "Puffer", "ai": "bomb",
		"frames": [Vector2i(29, 5)],
		"hp": 30.0, "speed": 48.0, "radius": 6.0, "cost": 2,
		"shot_speed": 75.0, "ring": 10, "fuse": 0.75,
		"color": Color("ffd27a"),
	},
	"lurker": {
		"name": "Sand Lurker", "ai": "burrow",
		"frames": [Vector2i(18, 9), Vector2i(19, 9)],
		"buried_frame": Vector2i(23, 9),
		"hp": 40.0, "speed": 58.0, "radius": 6.0, "cost": 3,
		"shot_speed": 82.0, "spread": 5,
		"color": Color("ffa07a"),
	},

	# ---------------- Bosses ----------------
	"clatterclaw": {
		"name": "Old Clatterclaw", "ai": "boss_clatterclaw", "boss": true,
		"frames": [Vector2i(25, 5)],
		"hp": 900.0, "speed": 60.0, "radius": 17.0, "cost": 0, "scale": 3.0,
		"color": Color("ff7a6b"),
	},
	"diver": {
		"name": "The Diver", "ai": "boss_diver", "boss": true,
		"frames": [Vector2i(30, 6)],
		"hp": 1700.0, "speed": 34.0, "radius": 18.0, "cost": 0, "scale": 3.0,
		"color": Color("9fe8c8"),
	},
	"undertow": {
		"name": "The Undertow", "ai": "boss_undertow", "boss": true,
		"frames": [Vector2i(25, 8)],
		"hp": 3000.0, "speed": 26.0, "radius": 22.0, "cost": 0, "scale": 4.0,
		"color": Color("ff8fd6"),
	},
}


static func get_enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, {})
