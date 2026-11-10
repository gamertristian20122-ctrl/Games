class_name PlayerStats
extends RefCounted
## The keeper's numbers after every held item has been counted.
##
## The starting values below are the keeper with no items at all. Items in
## scripts/data/item_db.gd change them by name, so a name used in an item's
## "mods" list must match a name here exactly.

# --- Shooting ---
var damage := 10.0          # damage of one shot
var fire_rate := 3.0        # shots per second
var shot_speed := 230.0     # pixels per second
var shot_life := 0.85       # seconds a shot flies before fading
var shot_size := 1.0
var shot_count := 1         # shots fired at once
var pierce := 0             # extra enemies a shot passes through
var bounce := 0             # wall bounces
var chain := 0              # jumps to other enemies
var split := 0              # Prism level
var homing := 0.0           # how hard shots curve toward enemies
var crit_chance := 0.0
var crit_mult := 2.0
var knockback := 50.0

# --- Things shots do to enemies ---
var burn_dps := 0.0         # fire damage per second
var brine := 0.0            # extra damage soaked enemies take (0.2 = +20%)
var chill := 0.0            # how much chilled enemies slow down (0.2 = 20%)
var shock := 0              # Storm Glass level
var flare := 0              # Signal Flare level

# --- Body ---
var max_hp_bonus := 0
var move_speed := 95.0
var dash_charges := 1
var dash_cooldown := 0.9
var room_shields := 0       # Oilskin Coat
var foghorn := 0
var kettle := 0
var logbook := 0            # Keeper's Log
var tide := 0               # Tide Table
var moths := 0
var beacon := 0

# --- Echo ---
var echo_damage := 0.5      # echo shots deal this share of your damage
var echo_count := 1
var unison_fire_rate := 0.20
var unison_damage := 0.0
var unison_radius := 24.0
var echo_taunt := 0.0
var echo_blocks := 0
var echo_autoaim := 0
var resonance := 0          # Afterglow level

# --- Combos (0 = off, 1 = on) ---
var salt_fire := 0
var black_ice := 0
var trotline := 0
var hall_of_mirrors := 0
var kaleidoscope := 0
var powder_keg := 0
var two_tone := 0
var standing_wave := 0
var choir := 0
var true_north := 0
var moths_to_flame := 0
var squall := 0
var slingstone := 0
var twin_lights := 0

## Names of the combos that are switched on.
var combos: Array[String] = []


## Works out the keeper's numbers from the items they hold.
## "held" maps an item id to how many copies are held.
static func build(held: Dictionary) -> PlayerStats:
	var s := PlayerStats.new()
	for id: String in held:
		var stacks := int(held[id])
		if stacks <= 0 or not ItemDB.ITEMS.has(id):
			continue
		s._apply(ItemDB.ITEMS[id]["mods"], stacks)
	s.combos = ItemDB.active_combos(held)
	for combo_id: String in s.combos:
		s._apply(ItemDB.COMBOS[combo_id]["mods"], 1)
	s._tidy()
	return s


func _apply(mods: Array, stacks: int) -> void:
	for mod: Array in mods:
		var stat: String = mod[0]
		var how: String = mod[1]
		var amount: float = mod[2]
		var current: Variant = get(stat)
		if current == null:
			push_error("Unknown stat name in item_db.gd: " + stat)
			continue
		if how == "add":
			if current is int:
				set(stat, int(current) + int(round(amount * stacks)))
			else:
				set(stat, float(current) + amount * stacks)
		elif how == "mul":
			set(stat, float(current) * (1.0 + amount * stacks))
		else:
			push_error("Unknown mod type in item_db.gd: " + how)


## Keeps numbers inside sensible limits so no build can break the game.
func _tidy() -> void:
	damage = maxf(damage, 1.0)
	fire_rate = clampf(fire_rate, 0.5, 14.0)
	shot_speed = clampf(shot_speed, 80.0, 520.0)
	shot_life = clampf(shot_life, 0.3, 2.5)
	shot_size = clampf(shot_size, 0.6, 2.6)
	shot_count = clampi(shot_count, 1, 6)
	crit_chance = clampf(crit_chance, 0.0, 0.75)
	chill = clampf(chill, 0.0, 0.6)
	move_speed = clampf(move_speed, 60.0, 170.0)
	echo_damage = clampf(echo_damage, 0.0, 1.5)
	echo_count = clampi(echo_count, 0, 3)
	echo_taunt = clampf(echo_taunt, 0.0, 0.7)


## Signal Flare: every Nth shot is a flare (0 = never).
func flare_every() -> int:
	return 0 if flare <= 0 else maxi(3, 7 - flare)


## Storm Glass: lightning on every Nth hit (0 = never).
func shock_every() -> int:
	return 0 if shock <= 0 else maxi(4, 9 - shock)


func shock_damage() -> float:
	return 18.0 + 10.0 * shock


## Tide Table: heal every N rooms (0 = never).
func tide_every() -> int:
	return 0 if tide <= 0 else maxi(2, 4 - tide)
