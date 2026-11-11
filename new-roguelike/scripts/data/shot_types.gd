extends RefCounted
## Shot types: how each kind of shot LOOKS (and how big it is). Use with:
##   const ShotTypes = preload("res://scripts/data/shot_types.gd")
## The shot manager (scripts/run/shots.gd) draws every shot from these rows, so this file plus
## shots.gd's _draw_shots() is the ONE place to change when real projectile art arrives.
##   color    bright centre            edge    darker outline
##   radius   size in pixels (also the hit size)
##   trail    how many fading copies follow the shot (0 = none)
##   sprite   optional Art id; when set (and the art exists) the sprite is drawn instead of the
##            circle, turned to face the way the shot flies (art drawn pointing UP, like the weapons)
## Player shots use cool colours, enemy shots warm ones, so they never get mixed up.

const ALL := {
	# --- the heroes
	"blade": {"color": Color(0.90, 0.97, 1.0), "edge": Color(0.20, 0.42, 0.80), "radius": 3.0, "trail": 2, "sprite": ""},
	"hex": {"color": Color(0.98, 0.85, 1.0), "edge": Color(0.58, 0.22, 0.85), "radius": 2.6, "trail": 3, "sprite": ""},
	"knife": {"color": Color(1.0, 0.98, 0.80), "edge": Color(0.55, 0.50, 0.25), "radius": 2.4, "trail": 2, "sprite": ""},
	# --- familiars and item effects
	"wisp": {"color": Color(0.80, 1.0, 0.95), "edge": Color(0.15, 0.60, 0.55), "radius": 2.0, "trail": 1, "sprite": ""},
	"shard": {"color": Color(1.0, 1.0, 0.92), "edge": Color(0.45, 0.42, 0.36), "radius": 2.0, "trail": 1, "sprite": ""},
	# --- enemies
	"enemy": {"color": Color(1.0, 0.86, 0.40), "edge": Color(0.85, 0.16, 0.10), "radius": 3.0, "trail": 0, "sprite": ""},
	"enemy_small": {"color": Color(1.0, 0.80, 0.50), "edge": Color(0.80, 0.20, 0.10), "radius": 2.3, "trail": 0, "sprite": ""},
	"enemy_big": {"color": Color(1.0, 0.70, 0.30), "edge": Color(0.75, 0.10, 0.10), "radius": 4.5, "trail": 0, "sprite": ""},
	"hex_enemy": {"color": Color(1.0, 0.70, 0.95), "edge": Color(0.75, 0.10, 0.55), "radius": 3.0, "trail": 0, "sprite": ""},
	"frost": {"color": Color(0.95, 1.0, 1.0), "edge": Color(0.85, 0.25, 0.45), "radius": 3.0, "trail": 0, "sprite": ""},
	"rock": {"color": Color(0.74, 0.70, 0.66), "edge": Color(0.22, 0.18, 0.18), "radius": 5.0, "trail": 0, "sprite": ""},
}

const FALLBACK := "enemy"


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL[FALLBACK])
