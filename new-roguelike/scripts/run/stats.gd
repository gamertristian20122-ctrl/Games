extends RefCounted
## Stats: all the numbers of the player (speed, damage, fire rate ...) in one place.
## The hero gives the BASE numbers. Every item adds a LAYER on top. recompute() adds them up:
##
##     final = (base + all "flat" values) x (1 + all "pct" values) x every "mult" value
##
## and then keeps the result inside LIMITS. Flags are simple counters ("pierce": 1 + 1 = 2).
## A layer is a Dictionary shaped like the "mods" field of an item:
##     {"flat": {"damage": 1.0}, "pct": {"speed": 0.15}, "mult": {"damage": 2.0}, "flags": {"pierce": 1}}
## Read results with  stats.v("damage")  and  stats.flag("pierce").
## Use with:  const Stats = preload("res://scripts/run/stats.gd")

## Every stat and its starting value when the hero row does not mention it.
const DEFAULTS := {
	"speed": 90.0,        # walking speed, px/s
	"damage": 3.0,        # per shot
	"rate": 2.0,          # shots per second
	"range": 110.0,       # how far a shot flies, px
	"shot_speed": 160.0,  # px/s
	"shot_size": 1.0,     # multiplier on the shot type's radius
	"knockback": 1.0,     # multiplier on how far a hit pushes an enemy
	"shots": 1.0,         # shots per trigger pull (rounded down)
	"spread": 0.0,        # random aim error in radians (0 = perfectly straight)
	"homing": 0.0,        # how hard shots curve toward enemies, radians/s
	"hurt_mult": 1.0,     # damage taken multiplier (2 = double damage)
	"coin_mult": 1.0,     # coins found multiplier
	"luck": 0.0,          # raises drop chances a little
	"invuln": 1.0,        # seconds of blinking safety after a hit
	"bomb_damage": 40.0,
	# ---- the Hungry Curse (scripts/entities/curse.gd)
	"call_cooldown": 4.0, # seconds before CALL works again
	"curse_creep": 1.0,   # multiplier on how fast the Curse creeps toward the hero
	"belly_mult": 1.0,    # multiplier on the coins a bombed Curse coughs up
}

## Lowest and highest value each stat may reach, whatever the items say.
const LIMITS := {
	"speed": [40.0, 170.0], "damage": [0.5, 999.0], "rate": [0.5, 9.0], "range": [40.0, 300.0],
	"shot_speed": [60.0, 360.0], "shot_size": [0.5, 3.0], "knockback": [0.0, 4.0], "shots": [1.0, 7.0],
	"spread": [0.0, 1.2], "homing": [0.0, 8.0], "hurt_mult": [0.5, 4.0], "coin_mult": [0.25, 5.0],
	"luck": [-5.0, 10.0], "invuln": [0.3, 3.0], "bomb_damage": [10.0, 400.0],
	"call_cooldown": [1.0, 10.0], "curse_creep": [0.3, 2.0], "belly_mult": [0.5, 4.0],
}

var base := {}
## Layers in the order they were added: [{"id": String, "mods": Dictionary}, ...]
var layers: Array = []
var _final := {}
var _flags := {}
signal changed


func _init(hero_row: Dictionary = {}) -> void:
	for key in DEFAULTS:
		base[key] = float(hero_row.get(key, DEFAULTS[key]))
	recompute()


## Adds a layer (or replaces the layer with the same id) and recomputes.
func set_layer(id: String, mods: Dictionary) -> void:
	for layer in layers:
		if layer["id"] == id:
			layer["mods"] = mods
			recompute()
			return
	layers.append({"id": id, "mods": mods})
	recompute()


func remove_layer(id: String) -> void:
	for i in layers.size():
		if layers[i]["id"] == id:
			layers.remove_at(i)
			recompute()
			return


func has_layer(id: String) -> bool:
	for layer in layers:
		if layer["id"] == id:
			return true
	return false


## The one place where the final numbers are worked out. Call after changing `base` by hand.
func recompute() -> void:
	var flat := {}
	var pct := {}
	var mult := {}
	_flags = {}
	for layer in layers:
		var mods: Dictionary = layer["mods"]
		var f: Dictionary = mods.get("flat", {})
		for key in f:
			flat[key] = float(flat.get(key, 0.0)) + float(f[key])
		var p: Dictionary = mods.get("pct", {})
		for key in p:
			pct[key] = float(pct.get(key, 0.0)) + float(p[key])
		var m: Dictionary = mods.get("mult", {})
		for key in m:
			mult[key] = float(mult.get(key, 1.0)) * float(m[key])
		var fl: Dictionary = mods.get("flags", {})
		for key in fl:
			_flags[key] = float(_flags.get(key, 0.0)) + float(fl[key])
	for key in base:
		var value: float = (float(base[key]) + float(flat.get(key, 0.0))) * (1.0 + float(pct.get(key, 0.0))) * float(mult.get(key, 1.0))
		if LIMITS.has(key):
			value = clampf(value, LIMITS[key][0], LIMITS[key][1])
		_final[key] = value
	changed.emit()


## The final value of a stat.
func v(key: String) -> float:
	return float(_final.get(key, 0.0))


## A flag counter (0 when no item sets it).
func flag(key: String) -> float:
	return float(_flags.get(key, 0.0))


func has_flag(key: String) -> bool:
	return float(_flags.get(key, 0.0)) > 0.0
