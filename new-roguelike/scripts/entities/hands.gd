extends RefCounted
## Hands: the Pixel Crawler bodies are drawn WITHOUT arms; the pack ships the hands as separate
## small pieces (ids pc_hand_*, in each creature family's own colours) to be placed by the game.
## This puts one hand at each side of a body, at the pack's hand height, and swings them a little
## while it walks. Nothing is drawn or recoloured: the pieces are the pack's, only placed by code.
##
##   var hands := Hands.new()
##   hands.build(owner, body_sprite, "pc_hand_base_7", body_width, body_height)   # after add_child(body)
##   hands.update(delta, moving, face, y_shift, visible, material, modulate)      # every frame
##
## `off_only = true` makes only the far hand (heroes: the near hand already holds the weapon).
## Monsters name their piece in enemies.gd ("hands": "<id>"); heroes use their "hand" piece.

const UP := 0.33            ## hand height above the feet, as a share of the body height (the pack's grip height)
const SWING := 2.0          ## px a hand swings forward and back while walking
const SWING_RATE := 11.0    ## how fast (matches the 6-frame run loops at 10 fps)
const FAR_SHADE := Color(0.78, 0.78, 0.82)   ## the far hand is a little darker, like a far leg

var near: Sprite2D
var far: Sprite2D
var _half := 6.0
var _up := 9.0
var _t := 0.0


func build(owner: Node, body: Node, hand_id: String, body_w: float, body_h: float, off_only: bool = false) -> void:
	var tex := Art.tex(hand_id)
	if tex == null:
		return
	_half = clampf(body_w * 0.5 - 1.0, 4.0, 11.0)
	_up = clampf(body_h * UP, 5.0, 12.0)
	far = Sprite2D.new()
	far.texture = tex
	owner.add_child(far)
	owner.move_child(far, body.get_index())          # just behind the body
	if not off_only:
		near = Sprite2D.new()
		near.texture = tex
		owner.add_child(near)
		owner.move_child(near, body.get_index() + 1) # just in front of it
	_t = randf() * TAU


func update(delta: float, moving: bool, face: float, y_shift: float = 0.0, shown: bool = true,
		material: Material = null, tint: Color = Color(1, 1, 1)) -> void:
	if far == null:
		return
	_t += delta * (SWING_RATE if moving else 2.5)
	var s := sin(_t)
	var swing := s * SWING if moving else 0.0
	var bob := 0.0 if moving else roundf(s * 0.6)
	var y := 2.0 - _up + y_shift + bob
	far.position = Vector2(roundf(-face * (_half - 1.0) - swing * face), y - 1.0)
	far.flip_h = face < 0.0
	far.visible = shown
	far.material = material
	far.modulate = tint * FAR_SHADE
	if near != null:
		near.position = Vector2(roundf(face * _half + swing * face), y)
		near.flip_h = face < 0.0
		near.visible = shown
		near.material = material
		near.modulate = tint


func hide() -> void:
	if far != null:
		far.visible = false
	if near != null:
		near.visible = false
