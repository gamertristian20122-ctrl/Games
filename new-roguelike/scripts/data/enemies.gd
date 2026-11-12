extends RefCounted
## Enemies: one row per enemy type. Use with:  const Enemies = preload("res://scripts/data/enemies.gd")
## To add an enemy: add a row. To give it a new way of moving, add a file in scripts/entities/ai/
## and put its file name (without .gd) in "ai".
##   name     shown on the death screen ("Killed by a ...") and in the logs
##   sprite   an Art id: a Pixel Crawler creature (pc_*; the list with sizes is assets/art/pc/pc_cast.json)
##   hp       hit points on floor 1 (grows 35% per floor, so a floor-3 row is really 1.7 times its number)
##   speed    px/s
##   ai       file name in scripts/entities/ai/          params   numbers that AI file understands
##   touch    half hearts lost when it touches the player (0 = harmless to touch)
##   flying   true = crosses pits
##   floors   which floors it appears on (1 = first floor)
##   cost     how much of a room's spawn budget it uses (bigger = rarer, stronger)
##   coin / heart   chance to drop a coin / half a heart when it dies
## Optional: "tint" (Color), "shot" (a shot type from shot_types.gd), "minion": true (no drops)
##   "big": true   too big for the Hungry Curse to swallow whole: it loses half its health per bite instead
##                 (elites count as big too; see scripts/entities/curse.gd)
##   "idle": "run" which animation it shows while it is not moving (bats hang upside down in their own
##                 idle, so they use the flying loop)          "hover"   px it floats above its shadow
##   "hands"              the pack's hand piece for this creature (pc_hand_*, in its own colours): the bodies are
##                        drawn without arms, scripts/entities/hands.gd puts one at each side. Leave out for none.
##   "radius", "hit_up"   body circle and shot hit height in px. Leave them out: enemy.gd takes them
##                 from the sprite's measurements. "scale" must be a whole number (pixel art).
## The pack draws a hit animation for some creatures (zombies, the Pit's keepers, bats), an attack
## animation for bats only and a death animation for all of them; enemy.gd plays whatever exists.
##
## Row keys are ids used by code and tests (curse tests, the first-run lesson, summoners), so four old
## keys were kept when the art changed: bone_archer is the Bone Mage, lantern_head is the Ember Husk.

const ALL := {
	# ---- floor 1, the Crypt: the restless dead
	# the training yard's straw dummy: never dies, never hurts (run.gd training)
	"training_dummy": {"name": "Straw Dummy", "sprite": "hub_dummy", "hp": 99999.0, "speed": 0.0,
		"ai": "dummy", "params": {}, "touch": 0, "flying": false, "floors": [], "cost": 99.0, "coin": 0.0, "heart": 0.0, "minion": true,
		"radius": 6.0, "hit_up": 8.0},
	"shambler": {"name": "Shambler", "sprite": "pc_zombie_base", "hands": "pc_hand_cemetery_30", "hp": 9.0, "speed": 30.0,
		"ai": "chaser", "params": {}, "touch": 1, "flying": false, "floors": [1], "cost": 1.0, "coin": 0.20, "heart": 0.04},
	"bone_walker": {"name": "Bone Walker", "sprite": "pc_skeleton_base", "hands": "pc_hand_base_7", "hp": 6.0, "speed": 46.0,
		"ai": "chaser", "params": {"weave": 0.7, "lunge": 1.7}, "touch": 1, "flying": false, "floors": [1], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"bone_guard": {"name": "Bone Guard", "sprite": "pc_skeleton_warrior", "hands": "pc_hand_base_7", "hp": 16.0, "speed": 27.0,
		"ai": "chaser", "params": {"lunge": 1.5}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 2.0, "coin": 0.25, "heart": 0.04},
	"crypt_bat": {"name": "Crypt Bat", "sprite": "pc_bat_small", "hp": 5.0, "speed": 46.0, "idle": "run", "hover": 8.0,
		"ai": "flyer", "params": {"orbit": 44.0, "dive_every": 3.0}, "touch": 1, "flying": true, "floors": [1, 2], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"bone_archer": {"name": "Bone Mage", "sprite": "pc_skeleton_mage", "hands": "pc_hand_base_7", "hp": 8.0, "speed": 34.0,
		"ai": "shooter", "params": {"keep": 70.0, "cooldown": 2.2, "shot_speed": 72.0}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 2.0, "coin": 0.20, "heart": 0.04, "shot": "enemy"},
	"grave_lunger": {"name": "Grave Lunger", "sprite": "pc_skeleton_rogue", "hands": "pc_hand_base_7", "hp": 9.0, "speed": 32.0,
		"ai": "charger", "params": {"windup": 0.75, "dash_speed": 165.0, "cooldown": 1.9}, "touch": 1, "flying": false, "floors": [1], "cost": 2.5, "coin": 0.25, "heart": 0.04},
	"rot_hulk": {"name": "Rot Hulk", "sprite": "pc_zombie_overweight", "hands": "pc_hand_cemetery_28", "hp": 30.0, "speed": 20.0,
		"ai": "brute", "params": {"slam_range": 30.0, "slam_radius": 26.0}, "touch": 1, "flying": false, "floors": [1], "cost": 3.0, "coin": 0.35, "heart": 0.06, "big": true},
	"wailer": {"name": "Wailer", "sprite": "pc_zombie_banshee", "hands": "pc_hand_cemetery_30", "hp": 14.0, "speed": 30.0,
		"ai": "summoner", "params": {"minion": "shambler", "count": 1, "cooldown": 6.5, "max_minions": 2, "keep": 80.0}, "touch": 1, "flying": false, "floors": [1, 2], "cost": 4.0, "coin": 0.40, "heart": 0.06},
	# ---- floor 2, the Warrens: rats, orcs and what grows in the damp
	"sewer_rat": {"name": "Sewer Rat", "sprite": "pc_rat_base", "hands": "pc_hand_sewer_22", "hp": 7.0, "speed": 54.0,
		"ai": "chaser", "params": {"weave": 0.8, "lunge": 1.6}, "touch": 1, "flying": false, "floors": [2], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"orc_grunt": {"name": "Orc Grunt", "sprite": "pc_orc_base", "hands": "pc_hand_base_9", "hp": 13.0, "speed": 40.0,
		"ai": "chaser", "params": {"lunge": 1.5}, "touch": 1, "flying": false, "floors": [2, 3], "cost": 1.5, "coin": 0.20, "heart": 0.04},
	"orc_skulker": {"name": "Orc Skulker", "sprite": "pc_orc_rogue", "hands": "pc_hand_base_9", "hp": 12.0, "speed": 76.0,
		"ai": "hopper", "params": {"rest": 0.8, "hop": 0.45, "land_shots": 4}, "touch": 1, "flying": false, "floors": [2], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy_small"},
	"rat_cutter": {"name": "Rat Cutter", "sprite": "pc_rat_rogue", "hands": "pc_hand_sewer_22", "hp": 13.0, "speed": 34.0,
		"ai": "charger", "params": {"windup": 0.65, "dash_speed": 190.0, "cooldown": 1.6}, "touch": 1, "flying": false, "floors": [2], "cost": 3.0, "coin": 0.25, "heart": 0.04},
	"rat_hexer": {"name": "Rat Hexer", "sprite": "pc_rat_mage", "hands": "pc_hand_sewer_22", "hp": 12.0, "speed": 30.0,
		"ai": "spreader", "params": {"cooldown": 2.6, "shots": 3, "arc": 0.5, "shot_speed": 66.0}, "touch": 1, "flying": false, "floors": [2], "cost": 3.0, "coin": 0.25, "heart": 0.04, "shot": "hex_enemy"},
	"spore_cap": {"name": "Spore Cap", "sprite": "pc_fungus_heavy", "hp": 12.0, "speed": 50.0,
		"ai": "exploder", "params": {"fuse": 0.65, "trigger": 28.0, "shots": 8, "shot_speed": 70.0}, "touch": 1, "flying": false, "floors": [2, 3], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy_small", "big": true},
	"rat_bulwark": {"name": "Rat Bulwark", "sprite": "pc_rat_warrior", "hands": "pc_hand_sewer_22", "hp": 34.0, "speed": 22.0,
		"ai": "brute", "params": {"slam_range": 32.0, "slam_radius": 27.0, "slam_shots": 6}, "touch": 1, "flying": false, "floors": [2], "cost": 3.5, "coin": 0.35, "heart": 0.06, "shot": "enemy_small", "big": true},
	"orc_shaman": {"name": "Orc Shaman", "sprite": "pc_orc_shaman", "hands": "pc_hand_base_11", "hp": 18.0, "speed": 34.0,
		"ai": "summoner", "params": {"minion": "sewer_rat", "count": 2, "cooldown": 6.0, "max_minions": 3, "keep": 75.0}, "touch": 1, "flying": false, "floors": [2, 3], "cost": 4.5, "coin": 0.40, "heart": 0.06},
	# ---- floor 3, the Ashen Halls: living stone, lava and the dried dead. Faster shots, shorter rests.
	"dust_mummy": {"name": "Dust Mummy", "sprite": "pc_mummy_base", "hands": "pc_hand_desert_13", "hp": 12.0, "speed": 52.0,
		"ai": "chaser", "params": {"weave": 0.35, "lunge": 1.6}, "touch": 1, "flying": false, "floors": [3], "cost": 2.0, "coin": 0.20, "heart": 0.04},
	"ash_bat": {"name": "Ash Bat", "sprite": "pc_bat_fur", "hp": 11.0, "speed": 60.0, "idle": "run", "hover": 10.0,
		"ai": "flyer", "params": {"orbit": 50.0, "dive_every": 2.1}, "touch": 1, "flying": true, "floors": [3, 4], "cost": 2.0, "coin": 0.20, "heart": 0.04},
	"lantern_head": {"name": "Ember Husk", "sprite": "pc_stone_broken", "hands": "pc_hand_forge_9", "hp": 10.0, "speed": 60.0,
		"ai": "exploder", "params": {"fuse": 0.55, "trigger": 26.0, "shots": 10, "shot_speed": 80.0}, "touch": 1, "flying": false, "floors": [3, 4], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy"},
	"tomb_seer": {"name": "Tomb Seer", "sprite": "pc_mummy_mage", "hands": "pc_hand_desert_13", "hp": 12.0, "speed": 36.0,
		"ai": "shooter", "params": {"keep": 80.0, "cooldown": 1.6, "shot_speed": 92.0}, "touch": 1, "flying": false, "floors": [3], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "hex_enemy"},
	"wrap_leaper": {"name": "Wrap Leaper", "sprite": "pc_mummy_rogue", "hands": "pc_hand_desert_13", "hp": 13.0, "speed": 84.0,
		"ai": "hopper", "params": {"rest": 0.65, "hop": 0.42, "land_shots": 5}, "touch": 1, "flying": false, "floors": [3], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy_small"},
	"tomb_blade": {"name": "Tomb Blade", "sprite": "pc_mummy_warrior", "hands": "pc_hand_desert_13", "hp": 16.0, "speed": 36.0,
		"ai": "charger", "params": {"windup": 0.5, "dash_speed": 215.0, "cooldown": 1.3}, "touch": 1, "flying": false, "floors": [3], "cost": 3.0, "coin": 0.25, "heart": 0.04},
	"magma_heart": {"name": "Magma Heart", "sprite": "pc_stone_lava", "hands": "pc_hand_forge_9", "hp": 15.0, "speed": 30.0,
		"ai": "spreader", "params": {"cooldown": 2.2, "shots": 5, "arc": 0.9, "shot_speed": 74.0}, "touch": 1, "flying": false, "floors": [3], "cost": 3.5, "coin": 0.25, "heart": 0.04, "shot": "enemy"},
	"rubble_walker": {"name": "Rubble Walker", "sprite": "pc_stone_base", "hands": "pc_hand_forge_9", "hp": 38.0, "speed": 22.0,
		"ai": "brute", "params": {"slam_range": 34.0, "slam_radius": 28.0, "slam_shots": 8}, "touch": 1, "flying": false, "floors": [3], "cost": 4.0, "coin": 0.35, "heart": 0.06, "shot": "rock", "big": true},
	# ---- floor 4, the Pit: the keepers of the dungeon. Quick aimed shots, long rushes, guards called in pairs.
	"pit_guard": {"name": "Pit Guard", "sprite": "pc_royal_soldier", "hands": "pc_hand_castle_17", "hp": 14.0, "speed": 56.0,
		"ai": "chaser", "params": {"weave": 0.4, "lunge": 1.7}, "touch": 1, "flying": false, "floors": [4], "cost": 2.0, "coin": 0.20, "heart": 0.04},
	"cataloguer": {"name": "Cataloguer", "sprite": "pc_scholar_cataloguer", "hands": "pc_hand_library_6", "hp": 11.0, "speed": 38.0,
		"ai": "shooter", "params": {"keep": 95.0, "cooldown": 0.95, "shot_speed": 70.0}, "touch": 1, "flying": false, "floors": [4], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy_small"},
	"pit_marksman": {"name": "Pit Marksman", "sprite": "pc_royal_archer", "hands": "pc_hand_castle_17", "hp": 12.0, "speed": 40.0,
		"ai": "shooter", "params": {"keep": 85.0, "cooldown": 1.5, "shot_speed": 108.0}, "touch": 1, "flying": false, "floors": [4], "cost": 2.5, "coin": 0.20, "heart": 0.04, "shot": "enemy"},
	"waking_statue": {"name": "Waking Statue", "sprite": "pc_statue_masculine", "hands": "pc_hand_garden_72", "hp": 20.0, "speed": 30.0,
		"ai": "charger", "params": {"windup": 0.45, "dash_speed": 235.0, "cooldown": 1.1}, "touch": 1, "flying": false, "floors": [4], "cost": 3.0, "coin": 0.25, "heart": 0.04},
	"censor": {"name": "Censor", "sprite": "pc_scholar_censor", "hands": "pc_hand_library_6", "hp": 15.0, "speed": 32.0,
		"ai": "spreader", "params": {"cooldown": 2.0, "shots": 5, "arc": 0.8, "shot_speed": 78.0}, "touch": 1, "flying": false, "floors": [4], "cost": 3.5, "coin": 0.25, "heart": 0.04, "shot": "hex_enemy"},
	"pit_warden": {"name": "Pit Warden", "sprite": "pc_royal_knight", "hands": "pc_hand_castle_17", "hp": 40.0, "speed": 26.0,
		"ai": "brute", "params": {"slam_range": 36.0, "slam_radius": 30.0, "slam_shots": 10}, "touch": 1, "flying": false, "floors": [4], "cost": 4.0, "coin": 0.35, "heart": 0.06, "shot": "enemy", "big": true},
	"pit_chaplain": {"name": "Pit Chaplain", "sprite": "pc_royal_priest", "hands": "pc_hand_castle_17", "hp": 20.0, "speed": 36.0,
		"ai": "summoner", "params": {"minion": "pit_guard", "count": 2, "cooldown": 5.5, "max_minions": 3, "keep": 80.0}, "touch": 1, "flying": false, "floors": [4], "cost": 4.5, "coin": 0.40, "heart": 0.06},
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
