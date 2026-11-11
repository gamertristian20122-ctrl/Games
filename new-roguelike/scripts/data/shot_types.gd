extends RefCounted
## Shot types: how each kind of shot LOOKS (and how big it is). Use with:
##   const ShotTypes = preload("res://scripts/data/shot_types.gd")
## The shot manager (scripts/run/shots.gd) keeps the shots; scripts/run/shot_look.gd draws them
## from these rows, so this file is the ONE place to change what a shot looks like.
##   color    bright centre            edge    darker outline   (also the colours of its sparks)
##   radius   size in pixels (also the hit size)
##   trail    how many fading copies follow the shot (0 = none)
##   sprite   an Art id (a still or an animation). Leave "" for a plain round shot.
## Only for shots with a sprite (all optional):
##   points   which way the art points: "up" (like the weapon sprites) or "right"
##   anchor   the pixel of the art that sits exactly on the shot (default: the middle).
##            Put it on the tip or the bright head so the shot does not seem to sink into walls.
##   tint     a colour wash over the art              gap     pixels between the trail copies
##   under    a dark disc drawn under the head: every ENEMY shot has one, so it reads on any floor
##   spin     turns per second (a thrown, tumbling thing) instead of pointing where it flies
##   fps      animation speed
## Rules of thumb: hero shots are long, thin and cool-coloured with a trail; enemy shots are fat,
## warm and bright with a dark rim. Never give an enemy shot a pale-gold ring (that is the Curse).

const ALL := {
	# --- the heroes: each one throws its own weapon
	"blade": {"color": Color(0.90, 0.97, 1.0), "edge": Color(0.20, 0.42, 0.80), "radius": 3.0, "trail": 3, "gap": 5.0,
		"sprite": "weapon_regular_sword", "points": "up", "anchor": Vector2(5, 7), "tint": Color(0.85, 1.0, 1.25, 0.95)},
	"hex": {"color": Color(0.98, 0.85, 1.0), "edge": Color(0.58, 0.22, 0.85), "radius": 2.6, "trail": 2, "gap": 5.0,
		"sprite": "fx_bolt_hex", "points": "right", "anchor": Vector2(12, 7), "tint": Color(1.25, 1.1, 1.35), "fps": 14.0},
	"knife": {"color": Color(1.0, 0.98, 0.80), "edge": Color(0.55, 0.50, 0.25), "radius": 2.4, "trail": 2, "gap": 4.0,
		"sprite": "weapon_knife", "points": "up", "anchor": Vector2(3, 5)},
	# --- familiars and item effects
	"wisp": {"color": Color(0.80, 1.0, 0.95), "edge": Color(0.15, 0.60, 0.55), "radius": 2.0, "trail": 2, "sprite": ""},
	"shard": {"color": Color(1.0, 1.0, 0.92), "edge": Color(0.45, 0.42, 0.36), "radius": 2.0, "trail": 1, "gap": 3.0,
		"sprite": "weapon_cleaver", "points": "up", "spin": 2.5, "tint": Color(1.0, 1.0, 1.0, 0.9)},
	# --- enemies
	"enemy": {"color": Color(1.0, 0.86, 0.40), "edge": Color(0.85, 0.16, 0.10), "radius": 3.0, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.30, 0.03, 0.05, 0.9), "fps": 12.0,
		"tint": Color(1.15, 1.1, 1.0)},
	"enemy_small": {"color": Color(1.0, 0.80, 0.50), "edge": Color(0.80, 0.20, 0.10), "radius": 2.3, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.30, 0.03, 0.05, 0.9), "fps": 12.0,
		"tint": Color(1.2, 1.2, 0.8)},
	"enemy_big": {"color": Color(1.0, 0.70, 0.30), "edge": Color(0.75, 0.10, 0.10), "radius": 4.5, "trail": 0,
		"sprite": "fx_firebomb", "points": "right", "anchor": Vector2(12, 9), "under": Color(0.30, 0.03, 0.05, 0.9), "fps": 12.0,
		"tint": Color(1.15, 1.1, 1.0)},
	"hex_enemy": {"color": Color(1.0, 0.70, 0.95), "edge": Color(0.75, 0.10, 0.55), "radius": 3.0, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.26, 0.02, 0.16, 0.9), "fps": 12.0,
		"tint": Color(1.2, 0.62, 1.9)},
	"frost": {"color": Color(0.95, 1.0, 1.0), "edge": Color(0.85, 0.25, 0.45), "radius": 3.0, "trail": 0,
		"sprite": "fx_star", "points": "up", "under": Color(0.32, 0.04, 0.14, 0.9), "spin": 0.6, "fps": 10.0},
	"rock": {"color": Color(0.74, 0.70, 0.66), "edge": Color(0.22, 0.18, 0.18), "radius": 5.0, "trail": 0,
		"sprite": "fx_rock", "points": "up", "spin": 0.8, "tint": Color(1.5, 1.4, 1.35)},
}

const FALLBACK := "enemy"


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL[FALLBACK])
