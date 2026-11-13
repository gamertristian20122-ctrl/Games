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
const Hd = preload("res://scripts/fx/hd.gd")

var life := 0.17                  ## how long a piece of the arc stays lit (seconds of game time)
var whiten := 0.55               ## how white the hot edge is (a sword: white-hot; a fire bolt: its own colour)
var _source: Callable
var _until := 0.0
var _t := 0.0
var _last := {}
var _samples: Array = []          ## [time, base, tip]
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
	var hot := 2.6 if Hd.on() else 1.4
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
		_samples.append([now, pts[0], pts[1]])
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
		for i in range(1, STEPS + 1):
			var k := float(i) / float(STEPS)
			var m := {"p": (_last["p"] as Vector3).lerp(s["p"], k), "a": lerpf(a0, a1, k),
				"r0": lerpf(float(_last["r0"]), float(s["r0"]), k), "r1": lerpf(float(_last["r1"]), float(s["r1"]), k)}
			var pts := _point(m)
			_samples.append([lerpf(t0, now, k), pts[0], pts[1]])
	_last = s


func _process(delta: float) -> void:
	_t += delta
	if _t <= _until:
		_sample(_t, false)
	# forget what has faded
	while not _samples.is_empty() and _t - float(_samples[0][0]) > life:
		_samples.pop_front()
	if _samples.is_empty() and _t > _until:
		queue_free()
		return
	_draw()


func _draw() -> void:
	_im.clear_surfaces()
	if _samples.size() < 2:
		return
	var white := _colour.lerp(Color.WHITE, whiten)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for s: Array in _samples:
		var age := clampf((_t - float(s[0])) / life, 0.0, 1.0)
		var k := pow(1.0 - age, 1.6)
		# the outer edge is the hottest (the blade's tip moves fastest), the inner edge fades out
		var base: Vector3 = s[1]
		var tip: Vector3 = s[2]
		var inner := base.lerp(tip, 0.35 * age)
		_im.surface_set_color(Color(_colour.r, _colour.g, _colour.b, 0.0))
		_im.surface_add_vertex(inner)
		_im.surface_set_color(Color(white.r, white.g, white.b, k * 0.95))
		_im.surface_add_vertex(tip)
	_im.surface_end()
