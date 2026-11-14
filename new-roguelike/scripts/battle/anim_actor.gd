extends Node
## ONE FIGHTER'S BODY IN MOTION (battles; scripts/battle/anim_moves.gd moves it).
## Every move of a fighter's picture goes through these few numbers, so two moves can never fight
## over one property (a tween on `offset` and a knock-back on `kick` simply add up):
##   offset   where it stands now, relative to its home spot (a dash, a hop back)
##   kick     a short shove on top of that (knock-back, recoil)
##   lift     how high above the ground (a jump, a hop)
##   squash   x = width, y = height (1, 1 = as drawn): crouch, stretch, squash on landing
##   lean     tilt in radians round the feet (+ = leans to the screen's left). (v0.41.0) Half of a small
##            lean is shown as a BEND instead: the upper body slides by whole pixels (sprite3.gd set_bend),
##            so the art keeps its square pixels; a big lean (a fall) still turns the whole picture
##   bend     art pixels the upper body is slid on top of that (a pose); and by itself the upper body
##            LAGS behind a dash and swings past when it stops (a spring: follow-through)
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
var bend := 0.0
var _lag := 0.0
var _lag_v := 0.0
var _last_x := 0.0
var _bend_shown := 0.0
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
	# (v0.41.0) the upper body: a small lean is half turned, half bent; it lags behind a dash and
	# swings past when the dash stops (a spring), and a pose (`bend`) adds to it
	var x := (offset + kick).x
	var vx := (x - _last_x) / maxf(delta, 0.001)
	_last_x = x
	var lag_target := clampf(-vx * 0.35, -2.5, 2.5)
	_lag_v += ((lag_target - _lag) * 160.0 - _lag_v * 16.0) * delta
	_lag += _lag_v * delta
	var small := absf(lean) < 0.6
	body.rotation.z = lean * 0.5 if small else lean
	var total := clampf(bend + _lag - (lean * 10.0 if small else 0.0), -4.0, 4.0)
	var stepped := roundf(total)
	if stepped != _bend_shown and body.has_method("set_bend"):
		_bend_shown = stepped
		body.call("set_bend", stepped)


## Where its feet are now.
func at() -> Vector3:
	return home + offset + kick + Vector3(0.0, lift, 0.0)


## Where the picture's middle is now (for sparks, numbers and the camera).
func centre(height: float) -> Vector3:
	return home + offset + kick + Vector3(0.0, lift + height * 0.5, 0.0)
