extends RefCounted
## HeroLook: how a hero holds a weapon. Use with:
##   const HeroLook = preload("res://scripts/entities/hero_look.gd")
## The hero sprites of the Pixel Crawler pack carry nothing in their hands; the weapon is a
## separate still picture that points UP, drawn on top and turned toward the aim.
## The player, the menus and the test line-up all pose it through this file, so it looks the
## same everywhere. Per hero (scripts/data/heroes.gd): "weapon" = the sprite id,
## "grip" = how many pixels above the bottom of the weapon picture the hand holds it.

const HAND_UP := 9.0        ## the hand is this far above the feet (the pack's own grip height)
const REACH := 4.0          ## how far the hand is pushed toward the aim (px)
const RECOIL := 3.5         ## how far a shot kicks the weapon back (px)
const REST_TILT := 0.5      ## how far the weapon leans forward while nothing is aimed at (radians)
const REST_SIDE := 5.0      ## where the resting hand is, to the side of the body (px)
const BEHIND_ABOVE := -0.35 ## aiming higher than this (aim.y) puts the weapon behind the body


static func make_weapon(hero: Dictionary) -> Sprite2D:
	var w := Sprite2D.new()
	set_weapon(w, hero)
	return w


## Gives the sprite a hero's weapon, with its turning point on the grip.
static func set_weapon(w: Sprite2D, hero: Dictionary) -> void:
	w.texture = Art.tex(String(hero.get("weapon", "")))
	w.centered = false
	var sz := w.texture.get_size()
	w.offset = Vector2(-floorf(sz.x * 0.5), -sz.y + float(hero.get("grip", 4.0)))


## Points the weapon along `dir` (a unit vector). `kick` is 1 right after a shot and falls to 0.
## Returns true when the weapon belongs IN FRONT of the body (false = behind: the hero aims up).
static func aim(w: Sprite2D, dir: Vector2, kick: float = 0.0) -> bool:
	w.rotation = dir.angle() + PI * 0.5
	w.position = Vector2(0.0, -HAND_UP) + dir * (REACH - RECOIL * kick)
	return dir.y > BEHIND_ABOVE


## Carries the weapon at the side, leaning forward. `face` is 1 (looking right) or -1.
static func rest(w: Sprite2D, face: float, delta: float = 1.0) -> void:
	w.rotation = lerp_angle(w.rotation, REST_TILT * face, minf(1.0, delta * 14.0))
	w.position = Vector2(REST_SIDE * face, -HAND_UP)


## Keeps the weapon just behind or just in front of the body among the same parent's children.
static func layer(w: Sprite2D, body: Node, in_front: bool) -> void:
	if (w.get_index() > body.get_index()) != in_front:
		w.get_parent().move_child(w, body.get_index())
