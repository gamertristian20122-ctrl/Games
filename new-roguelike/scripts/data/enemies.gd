extends RefCounted
## Enemies: one row per enemy type. Use with:  const Enemies = preload("res://scripts/data/enemies.gd")
## To add an enemy: add a row. To give it a new way of moving, add a file in scripts/entities/ai/
## and put its file name (without .gd) in "ai".
##   name     shown nowhere yet; for you and the logs
##   sprite   an Art id (pack sprite)
##   hp       hit points on floor 1 (grows 35% per floor)
##   speed    px/s            radius   size of its body circle in px
##   ai       file name in scripts/entities/ai/          params   numbers that AI file understands
##   touch    half hearts lost when it touches the player (0 = harmless to touch)
##   flying   true = crosses pits
##   floors   which floors it appears on (1 = first floor)
##   cost     how much of a room's spawn budget it uses (bigger = rarer, stronger)
##   coin / heart   chance to drop a coin / half a heart when it dies
## Optional: "tint" (Color), "scale" (float), "shot" (a shot type from shot_types.gd), "minion": true (no drops)

const ALL := {
	# ---- floor 1 and up
	"shambler": {"name": "Shambler", "sprite": "tiny_zombie", "hp": 9.0, "speed": 30.0, "radius": 4.5,
		"ai": "chaser", "params": {}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 1.0, "coin": 0.20, "heart": 0.04},
	"gnasher": {"name": "Gnasher", "sprite": "goblin", "hp": 6.0, "speed": 46.0, "radius": 4.5,
		"ai": "chaser", "params": {"weave": 0.7, "lunge": 1.7}, "touch": 1, "flying": false, "floors": [1, 2, 3], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"mudling": {"name": "Mudling", "sprite": "muddy", "hp": 11.0, "speed": 70.0, "radius": 6.0,
		"ai": "hopper", "params": {"rest": 0.9, "hop": 0.45}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"bone_archer": {"name": "Bone Archer", "sprite": "skelet", "hp": 8.0, "speed": 34.0, "radius": 4.5,
		"ai": "shooter", "params": {"keep": 70.0, "cooldown": 2.2, "shot_speed": 72.0}, "touch": 1, "flying": false, "floors": [1, 2, 3], "cost": 2.0, "coin": 0.20, "heart": 0.04, "shot": "enemy"},
	"rot_hulk": {"name": "Rot Hulk", "sprite": "zombie", "hp": 30.0, "speed": 20.0, "radius": 5.5, "scale": 1.25,
		"ai": "brute", "params": {"slam_range": 30.0, "slam_radius": 26.0}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 3.0, "coin": 0.35, "heart": 0.06},
	# ---- floor 2 and up
	"bogling": {"name": "Bogling", "sprite": "swampy", "hp": 14.0, "speed": 78.0, "radius": 6.0,
		"ai": "hopper", "params": {"rest": 0.8, "hop": 0.45, "land_shots": 4}, "touch": 1, "flying": false, "floors": [2, 3, 4], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy_small"},
	"masked_brute": {"name": "Masked Brute", "sprite": "masked_orc", "hp": 16.0, "speed": 30.0, "radius": 5.5,
		"ai": "charger", "params": {"windup": 0.65, "dash_speed": 190.0, "cooldown": 1.6}, "touch": 1, "flying": false, "floors": [2, 3, 4], "cost": 3.0, "coin": 0.25, "heart": 0.04},
	"hex_spitter": {"name": "Hex Spitter", "sprite": "wogol", "hp": 13.0, "speed": 30.0, "radius": 5.0,
		"ai": "spreader", "params": {"cooldown": 2.6, "shots": 3, "arc": 0.5, "shot_speed": 66.0}, "touch": 1, "flying": false, "floors": [2, 3, 4], "cost": 3.0, "coin": 0.25, "heart": 0.04, "shot": "hex_enemy"},
	"cinder_imp": {"name": "Cinder Imp", "sprite": "imp", "hp": 7.0, "speed": 52.0, "radius": 4.5,
		"ai": "flyer", "params": {"orbit": 46.0, "dive_every": 2.6}, "touch": 1, "flying": true, "floors": [2, 3, 4], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	# ---- floor 3 and up
	"pit_fiend": {"name": "Pit Fiend", "sprite": "chort", "hp": 13.0, "speed": 50.0, "radius": 5.0,
		"ai": "chaser", "params": {"weave": 0.35, "lunge": 1.5}, "touch": 1, "flying": false, "floors": [3, 4], "cost": 2.0, "coin": 0.20, "heart": 0.04},
	"bone_caller": {"name": "Bone Caller", "sprite": "necromancer", "hp": 20.0, "speed": 34.0, "radius": 5.0,
		"ai": "summoner", "params": {"minion": "shambler", "count": 2, "cooldown": 6.0, "max_minions": 3, "keep": 75.0}, "touch": 1, "flying": false, "floors": [3, 4], "cost": 4.5, "coin": 0.40, "heart": 0.06},
	"lantern_head": {"name": "Lantern Head", "sprite": "pumpkin_dude", "hp": 11.0, "speed": 58.0, "radius": 5.0,
		"ai": "exploder", "params": {"fuse": 0.6, "trigger": 26.0, "shots": 10, "shot_speed": 78.0}, "touch": 1, "flying": false, "floors": [3, 4], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy"},
	"frost_hulk": {"name": "Frost Hulk", "sprite": "ice_zombie", "hp": 40.0, "speed": 22.0, "radius": 5.5, "scale": 1.25,
		"ai": "brute", "params": {"slam_range": 34.0, "slam_radius": 28.0, "slam_shots": 8}, "touch": 1, "flying": false, "floors": [3, 4], "cost": 4.0, "coin": 0.35, "heart": 0.06, "shot": "frost"},
}

## How much stronger enemies get per floor (hp x (1 + this x floor_index)).
const HP_PER_FLOOR := 0.35
## Summoned minions are weaker than the real thing (hp x this).
const MINION_HP := 0.6
## Elite enemies: tinted aura, more hp, faster, always drop coins. They start on this floor (1 = first).
const ELITE_FROM_FLOOR := 2
const ELITE_HP := 2.0
const ELITE_SPEED := 1.2
const ELITE_COLOR := Color(1.0, 0.82, 0.25)


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL["shambler"])


## Ids of every enemy that may appear on a floor (floor_number 1 = first floor).
static func pool_for_floor(floor_number: int) -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		if (ALL[id]["floors"] as Array).has(floor_number) and not ALL[id].get("minion", false):
			out.append(id)
	return out
