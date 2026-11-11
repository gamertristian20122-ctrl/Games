extends RefCounted
## Bosses: one row per boss. Use with:  const Bosses = preload("res://scripts/data/bosses.gd")
## To add a boss: add a row here and a file scripts/entities/bosses/<script>.gd with its fight
## (the toolkit a fight file uses is listed at the top of scripts/entities/boss.gd).
##   name     shown on the boss bar (free to rename; the row KEY is what saves and unlocks remember)
##   sprite   a boss id from assets/art/boss/boss_cast.json. Drawn at its real size, never scaled.
##            Feet point, hover height, body size, hit frames and shot spawn points come from that file.
##   floors   which floor it guards (1 = first). If two bosses share a floor the run picks one (seeded).
##   hp       hit points (its real number: bosses no longer grow per floor, each has one floor).
##            Tuned for a fight of 45 to 90 s (the final boss 90 to 150 s) with that floor's usual items.
##   script   file name in scripts/entities/bosses/ (default: the row key)
##   speed, touch, shot   like enemies.gd
## Optional:
##   radius   body circle in px (default: the "radius" measured in boss_cast.json)
##   hit_r, hit_up   the circle shots test: its radius and how far above the feet its middle is
##   flying   true = it crosses pits            hover   extra px of air under it (floaters the pack drew on the ground)
##   bob      px it sways up and down while it hovers (default 1 for floaters)
##   no_facing   true = never mirrored (the Pyre Saint tumbles, it has no front)
##   idle, run   the loops it stands and walks in (default "idle" / "run")
##   enter    an animation it arrives with; enter_reverse = play that one backwards
##   phases   health shares where the next phase starts (default [0.5]; [0.5, 0.2] gives a phase 3)
##   hit_frames   {animation: [frames]} to overrule boss_cast.json     muzzle   {animation: [x, y]} from the feet
##   stagger_dmg  how much harder shots hit while it is staggered (default 1.0)
##   north    px of floor it keeps between its feet and the back wall (default: from its height, 0 to 40,
##            so the head of a very tall boss stays on the screen)
##   layout   the boss room layout it needs (scripts/data/room_layouts.gd), for bodies too big for pillars
##   final    true = killing it wins the run; its death is longer (death_time overrules the seconds)
##   params   numbers its fight file understands (explained at the top of that file)

const ALL := {
	# ---- floor 1, the Crypt
	"pyre_saint": {"name": "The Pyre Saint", "sprite": "boss_fire_skull", "floors": [1], "hp": 680.0,
		"speed": 30.0, "touch": 1, "shot": "enemy", "flying": true, "hover": 10.0, "no_facing": true, "stagger_dmg": 2.0, "layout": "boss_arena",
		"params": {"warn": 0.8, "flare_radius": 30.0, "ring_shots": 16, "ring_gap": 0.7, "ring_speed": 48.0,
			"swoop_warn": 0.9, "rebound_warn": 0.65, "swoop_speed": 185.0, "candles": 5, "candles2": 7, "candle_radius": 15.0,
			"candle_warn": 1.0, "candle_gap": 0.4, "gutter_seconds": 3.0, "sink": 20.0, "helper": "bone_walker", "helpers": 2}},
	"red_sexton": {"name": "The Red Sexton", "sprite": "boss_death", "floors": [1], "hp": 270.0,
		"speed": 46.0, "touch": 1, "shot": "enemy", "idle": "run", "enter": "spawn", "hit_frames": {"spawn": [2]},
		"params": {"step_warn": 0.8, "step2_warn": 0.6, "blade_radius": 16.0, "step_far": 28.0, "fan_warn": 0.7, "fan_blades": 5,
			"fan_angle": 0.42, "fan_speed": 105.0, "helper": "shambler", "helpers": 2, "helpers2": 3, "near": 46.0, "far": 85.0, "lamp_burn": 3.5}},
	# ---- floor 2, the Warrens
	"stonejaw": {"name": "Stonejaw", "sprite": "boss_ogre", "floors": [2], "hp": 420.0,
		"speed": 30.0, "touch": 1, "shot": "enemy", "stagger_dmg": 1.25,
		"params": {"leap_time": 0.9, "shock_radius": 34.0, "smash_warn": 0.9, "smash_reach": 50.0, "smash_radius": 26.0,
			"wave_inner": 30.0, "wave_outer": 58.0, "club_speed": 230.0, "club_warn": 0.8}},
	"gutter_king": {"name": "The Gutter King", "sprite": "boss_mutant_toad", "floors": [2], "hp": 400.0,
		"speed": 34.0, "touch": 1, "shot": "enemy",
		"params": {}},
	# ---- floor 3, the Ashen Halls
	"forge_warden": {"name": "The Forge Warden", "sprite": "boss_mecha_golem", "floors": [3], "hp": 480.0,
		"speed": 30.0, "touch": 1, "shot": "enemy_big", "flying": true, "enter": "death", "enter_reverse": true,
		"params": {}},
	# art by chierit, CC-BY 4.0: needs its credit row in credits.gd (it is a spare; remove both together)
	"cinder_tyrant": {"name": "The Cinder Tyrant", "sprite": "boss_demon_slime", "floors": [3], "hp": 480.0,
		"speed": 26.0, "touch": 1, "shot": "enemy", "radius": 18.0, "layout": "boss_embers", "stagger_dmg": 1.25,
		"params": {"charge_speed": 175.0, "charge_warn": 0.75, "cleave_warn": 0.9, "cleave_reach": 122.0, "cleave_angle": 0.5,
			"slam_radius": 44.0, "slam_warn": 0.8, "burn_seconds": 3.5}},
	# ---- floor 4, the Pit: the final boss
	"starved_king": {"name": "The Starved King", "sprite": "boss_demon", "floors": [4], "hp": 1100.0,
		"speed": 24.0, "touch": 1, "shot": "enemy", "radius": 20.0, "flying": true, "final": true, "layout": "boss_arena",
		"params": {}},
}

## Boss ids from older versions of the game and the boss that took their place, so an old save's
## "boss_killed:<id>" counters and any unlock rule written for them still name a real boss.
const RENAMED := {"gravekeeper": "cinder_tyrant"}


## The row key a boss id stands for today (follows RENAMED; unknown ids give the first row's key).
static func real_id(id: String) -> String:
	if ALL.has(id):
		return id
	if RENAMED.has(id):
		return String(RENAMED[id])
	return String(ALL.keys()[0])


static func info(id: String) -> Dictionary:
	return ALL[real_id(id)]


## True for an id of a boss that exists now or existed once (unlock rules may name either).
static func known(id: String) -> bool:
	return ALL.has(id) or RENAMED.has(id)


## Boss ids that guard a floor (floor_number 1 = first floor). Never empty.
static func for_floor(floor_number: int) -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		if (ALL[id]["floors"] as Array).has(floor_number):
			out.append(id)
	if out.is_empty():
		out.append(ALL.keys()[0])
	return out
