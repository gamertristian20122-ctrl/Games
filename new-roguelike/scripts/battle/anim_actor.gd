extends Node
## ONE FIGHTER'S BODY IN MOTION (battles; scripts/battle/anim_moves.gd moves it).
## Every move of a fighter's picture goes through these few numbers, so two moves can never fight
## over one property (a tween on `offset` and a knock-back on `kick` simply add up):
##   offset   where it stands now, relative to its home spot (a dash, a hop back)
##   kick     a short shove on top of that (knock-back, recoil)
##   lift     how high above the ground (a jump, a hop)
##   squash   x = width, y = height (1, 1 = as drawn): crouch, stretch, squash on landing
##   lean     tilt in radians round the feet (+ = leans to the screen's left)
## Every frame the picture is put at home + offset + kick + lift and scaled by squash times a slow
## BREATH (idle fighters never look frozen). Nothing here touches the fight's rules.

const SQUASH_CAP := 0.06          ## at most this much wider / taller than drawn
var body: Node3D
var home := Vector3.ZERO
var offset := Vector3.ZERO
var kick := Vector3.ZERO
var lift := 0.0
var squash := Vector2.ONE
var lean := 0.0
var breath := 0.022               ## how deep the idle breath is (0 = none: the fallen)
var bob := 0.0                    ## flyers: how far they bob up and down while they hover
var spin := 0.0                   ## extra turn round the up axis is faked by flipping (see anim_moves.gd)
var _phase := 0.0
var _rate := 2.2
var _t := 0.0


func setup(node: Node3D, at: Vector3, seed_value: int) -> void:
	body = node
	home = at
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	_phase = r.randf() * TAU
	_rate = r.randf_range(1.9, 2.6)


func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	_t += delta
	var b := sin(_t * _rate + _phase)
	var hover := bob * sin(_t * 3.1 + _phase) if bob > 0.0 else 0.0
	body.position = home + offset + kick + Vector3(0.0, lift + hover, 0.0)
	# (squash is capped at 6% and snapped to whole art pixels: a pixel picture resampled 17% wide
	# and 17% short read as a squat tin can, and no pixel-sprite game deforms its art. The motion
	# comes from lean, steps, lift and the sword; the squash only nudges a pixel or two)
	var sx := 1.0 + clampf(squash.x - 1.0, -SQUASH_CAP, SQUASH_CAP) - b * breath * 0.45
	var sy := 1.0 + clampf(squash.y - 1.0, -SQUASH_CAP, SQUASH_CAP) + b * breath
	var px: Variant = body.get("_size")
	if px is Vector2 and (px as Vector2).x > 0.0:
		var sz := px as Vector2
		sx = maxf(roundf(sz.x * sx), 1.0) / sz.x
		sy = maxf(roundf(sz.y * sy), 1.0) / sz.y
	body.scale = Vector3(sx, sy, 1.0)
	body.rotation.z = lean


## Where its feet are now.
func at() -> Vector3:
	return home + offset + kick + Vector3(0.0, lift, 0.0)


## Where the picture's middle is now (for sparks, numbers and the camera).
func centre(height: float) -> Vector3:
	return home + offset + kick + Vector3(0.0, lift + height * 0.5, 0.0)
