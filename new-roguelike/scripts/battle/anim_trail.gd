extends MeshInstance3D
## A WEAPON ARC (code-drawn light, no art): the bright smear a blade leaves as it swings, in the
## colour of the one who swings it. It is a ribbon swept between an inner and an outer point that
## turn round a pivot; it is drawn every frame from the last fraction of a second of the swing and
## fades towards its tail. A swing is far quicker than a frame, so between two frames the angle is
## filled in (`STEPS`), and the arc stays round even at a low frame rate.
##   var t = Trail.new(); stage.add_child(t); t.start(colour, source, seconds)
## `source` is a Callable that returns {"p": pivot (world), "a": angle (radians, in the picture's
## plane: 0 = right, PI/2 = up), "r0": inner reach, "r1": outer reach}. A thrust keeps the angle and
## moves the pivot; a spin turns the angle round and round. The trail frees itself when it has faded.

const STEPS := 8                  ## samples added between two frames
const MAX_SWEEP := 1.6            ## radians of swing kept behind the blade (about one cut)
const Hd = preload("res://scripts/fx/hd.gd")

var life := 0.17                  ## how long a piece of the arc stays lit (seconds of game time)
var edge := true                  ## a blade's arc (a thin edge ribbon in HD); false: a bolt's streak, full width
var whiten := 0.55               ## how white the hot edge is (a sword: white-hot; a fire bolt: its own colour)
var _source: Callable
var _until := 0.0
var _t := 0.0                     ## the fading clock (real time during a hit-stop)
var _gt := 0.0                    ## game time since the start
var _acc := 0.0                   ## the blade's angle, unwrapped (to keep only one cut's worth)
var _held := false                ## a hit-stop holds the game still
var _last := {}
var _samples: Array = []          ## [time, base, tip, unwrapped angle]
var _im: ImmediateMesh
var _colour := Color.WHITE
var _mat: StandardMaterial3D


func start(colour: Color, source: Callable, seconds: float, fade: float = 0.17) -> void:
	_colour = colour
	_source = source
	_until = seconds
	life = fade
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_mat.no_depth_test = false
	_mat.render_priority = 12             # (over the last pass: see-through things need it)
	# (vertex colours are kept in 0..1; the material lifts them over the bloom's threshold in HD)
	# (HD: 2.6 made a 200-degree swing, held still by the hit-stop, bloom into a white dome round
	# the hand that hid both fighters at night; a little over the bloom threshold is enough)
	var hot := 1.3 if Hd.on() else 1.4
	_mat.albedo_color = Color(hot, hot, hot, 1.0)
	material_override = _mat
	top_level = true
	global_transform = Transform3D.IDENTITY
	_sample(0.0, true)


func _point(s: Dictionary) -> Array:
	var p: Vector3 = s["p"]
	var a := float(s["a"])
	var d := Vector3(cos(a), sin(a), 0.0)
	return [p + d * float(s["r0"]), p + d * float(s["r1"])]


func _sample(now: float, first: bool) -> void:
	if not _source.is_valid():
		return
	var s: Dictionary = _source.call()
	if first or _last.is_empty():
		var pts := _point(s)
		_samples.append([now, pts[0], pts[1], _acc])
	else:
		# fill in between the last frame's pose and this one (the swing is quicker than a frame)
		var t0 := float(_samples[-1][0]) if not _samples.is_empty() else now
		# (a sword's angle comes from atan2 and wraps at +-PI: a swing across that line must go the
		# short way round, or the fill-in swept almost a full turn and drew a white-hot disc the
		# sword's length round the hand, which the bloom spread into a dome over both fighters.
		# A spin's source gives unwrapped angles beyond +-PI and keeps its long way.)
		var a0 := float(_last["a"])
		var a1 := float(s["a"])
		if absf(a1 - a0) > PI and absf(a0) <= PI and absf(a1) <= PI:
			a1 = a0 + wrapf(a1 - a0, -PI, PI)
		var acc0 := _acc
		_acc += a1 - a0
		for i in range(1, STEPS + 1):
			var k := float(i) / float(STEPS)
			var m := {"p": (_last["p"] as Vector3).lerp(s["p"], k), "a": lerpf(a0, a1, k),
				"r0": lerpf(float(_last["r0"]), float(s["r0"]), k), "r1": lerpf(float(_last["r1"]), float(s["r1"]), k)}
			var pts := _point(m)
			_samples.append([lerpf(t0, now, k), pts[0], pts[1], lerpf(acc0, _acc, k)])
	_last = s


## Ends the trail now: no more samples, and what is left fades within `fade` seconds (a bolt's
## streak once it has struck: it hung across half the screen after the impact).
func cut(fade: float = 0.05) -> void:
	_until = 0.0
	_gt = maxf(_gt, 0.001)
	if not _samples.is_empty():
		var newest := float(_samples[-1][0])
		while not _samples.is_empty() and newest - float(_samples[0][0]) > fade:
			_samples.pop_front()
	life = minf(life, fade)


func _process(delta: float) -> void:
	# Two clocks. Game time says how long the swing is followed. The fading runs on REAL time while
	# the game is frozen by a hit-stop (time scale 0.04): on game time the whole swing stayed lit
	# through the freeze and read as a solid dome over both fighters.
	_gt += delta
	var slow := Engine.time_scale < 0.5
	_t += delta / maxf(Engine.time_scale, 0.0001) if slow else delta
	_held = slow
	if _gt <= _until:
		_sample(_t, false)
	# forget what has faded, and anything further round than one cut behind the blade
	while not _samples.is_empty() and (_t - float(_samples[0][0]) > life or (edge and absf(_acc - float(_samples[0][3])) > MAX_SWEEP)):
		_samples.pop_front()
	if _samples.is_empty() and _gt > _until:
		queue_free()
		return
	_draw()


func _draw() -> void:
	_im.clear_surfaces()
	if _samples.size() < 2:
		return
	var white := _colour.lerp(Color.WHITE, whiten)
	var hd := Hd.on()
	# (HD: a thin ribbon along the blade's outer edge; at most half lit, less while a hit-stop holds
	# it still)
	var top := ((0.5 if hd else 0.8) if edge else 0.95) * (0.6 if _held else 1.0)
	var inner0 := (0.72 if hd else 0.35) if edge else 0.0
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for s: Array in _samples:
		var age := clampf((_t - float(s[0])) / life, 0.0, 1.0)
		# how far round behind the blade this piece is (0 = at the blade, 1 = a whole cut behind)
		var behind := clampf(absf(_acc - float(s[3])) / MAX_SWEEP, 0.0, 1.0) if edge else 0.0
		var tail := maxf(age, behind)
		var k := pow(1.0 - tail, 1.6)
		# the outer edge is the hottest (the blade's tip moves fastest); the ribbon tapers to
		# nothing at its tail
		var base: Vector3 = s[1]
		var tip: Vector3 = s[2]
		var inner := base.lerp(tip, inner0 + (1.0 - inner0) * tail)
		_im.surface_set_color(Color(_colour.r, _colour.g, _colour.b, 0.0))
		_im.surface_add_vertex(inner)
		_im.surface_set_color(Color(white.r, white.g, white.b, k * top))
		_im.surface_add_vertex(tip)
	_im.surface_end()
