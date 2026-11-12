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
##   dot      a bright dot drawn on the head (the "bright core" of an enemy shot)
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
	# the Fire Bolt skill (scripts/entities/hero_skills.gd): a warm, code-drawn bolt with a long trail
	"firebolt": {"color": Color(1.0, 0.92, 0.55), "edge": Color(0.95, 0.35, 0.10), "radius": 3.6, "trail": 4, "sprite": ""},
	# --- familiars and item effects
	"wisp": {"color": Color(0.80, 1.0, 0.95), "edge": Color(0.15, 0.60, 0.55), "radius": 2.0, "trail": 2, "sprite": ""},
	"shard": {"color": Color(1.0, 1.0, 0.92), "edge": Color(0.45, 0.42, 0.36), "radius": 2.0, "trail": 1, "gap": 3.0,
		"sprite": "pc_weapon_bone_1", "points": "up", "anchor": Vector2(3, 2), "tint": Color(1.15, 1.1, 1.05, 0.95)},   # a thin bone splinter (Bone Thistle)
	# a hero shot that flew through the Hungry Curse (Eclipse Shard): a dark orb with a violet heart
	"eclipse": {"color": Color(0.80, 0.50, 1.0), "edge": Color(0.10, 0.02, 0.16), "radius": 3.0, "trail": 3, "sprite": ""},
	# an enemy shot the Curse spat back (Sour Gullet)
	"spit": {"color": Color(0.88, 1.0, 0.55), "edge": Color(0.25, 0.50, 0.10), "radius": 2.4, "trail": 2, "sprite": ""},
	# --- enemies
	"enemy": {"color": Color(1.0, 0.86, 0.40), "edge": Color(0.85, 0.16, 0.10), "radius": 3.0, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.16, 0.01, 0.03, 1.0), "dot": Color(1.0, 0.97, 0.74), "fps": 12.0,
		"tint": Color(1.2, 1.2, 1.0)},
	"enemy_small": {"color": Color(1.0, 0.80, 0.50), "edge": Color(0.80, 0.20, 0.10), "radius": 2.3, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.16, 0.01, 0.03, 1.0), "dot": Color(1.0, 0.97, 0.74), "fps": 12.0,
		"tint": Color(1.2, 1.25, 0.8)},
	"enemy_big": {"color": Color(1.0, 0.70, 0.30), "edge": Color(0.75, 0.10, 0.10), "radius": 4.5, "trail": 0,
		"sprite": "fx_firebomb", "points": "right", "anchor": Vector2(12, 9), "under": Color(0.16, 0.01, 0.03, 1.0), "dot": Color(1.0, 0.97, 0.74), "fps": 12.0,
		"tint": Color(1.2, 1.2, 1.0)},
	"hex_enemy": {"color": Color(1.0, 0.70, 0.95), "edge": Color(0.75, 0.10, 0.55), "radius": 3.0, "trail": 0,
		"sprite": "fx_fireball", "points": "right", "anchor": Vector2(12, 8), "under": Color(0.14, 0.0, 0.10, 1.0), "dot": Color(1.0, 0.88, 0.98), "fps": 12.0,
		"tint": Color(1.2, 0.62, 1.9)},
	"frost": {"color": Color(0.95, 1.0, 1.0), "edge": Color(0.85, 0.25, 0.45), "radius": 3.0, "trail": 0,
		"sprite": "fx_star", "points": "up", "under": Color(0.20, 0.02, 0.10, 1.0), "spin": 0.6, "fps": 10.0},
	"rock": {"color": Color(0.74, 0.70, 0.66), "edge": Color(0.22, 0.18, 0.18), "radius": 5.0, "trail": 0,
		"sprite": "fx_rock", "points": "up", "spin": 0.8, "tint": Color(1.5, 1.4, 1.35)},
	# the Red Sexton's thrown knives (the dagger of the same ansimuz pack, CC0)
	"sexton_blade": {"color": Color(1.0, 0.86, 0.80), "edge": Color(0.80, 0.12, 0.10), "radius": 3.0, "trail": 0,
		"sprite": "boss_fx_terrible_knight_dagger", "points": "right", "anchor": Vector2(20, 4), "under": Color(0.16, 0.01, 0.03, 1.0),
		"dot": Color(1.0, 0.92, 0.80), "tint": Color(1.6, 0.6, 0.5)},
	# the Gutter King's slime: green and slow, with a dark rim (never pale gold: that is the Curse)
	"slime": {"color": Color(0.72, 1.0, 0.36), "edge": Color(0.06, 0.26, 0.05), "radius": 3.3, "trail": 1, "sprite": ""},
}

const FALLBACK := "enemy"


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL[FALLBACK])
