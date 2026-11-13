extends RefCounted
## THE BATTLE EFFECTS' KIT (used by stage.gd, stage_hd.gd and fx_impact.gd): the colour rule for
## spells, and STREAK SPARKS. All of it is light made by code: no art.
##   FxKit.deep(colour)        a spell colour as LINEAR light, deeper and more saturated than the
##                             colour in the data table (battles.gd FX keeps plain sRGB colours).
##                             Shader uniforms given a Vector3 are NOT turned from sRGB to linear by
##                             Godot, so a plain sRGB orange (1, 0.5, 0.15) became a pale gold there:
##                             that was the "firebolt reads gold" fault of round two.
##   FxKit.Streaks             a handful of sparks flown by code, each drawn as a crisp streak along
##                             the way it flies: a white-hot head and a coloured tail that tapers away.
##                             Sparks can spiral round an upright, fall, bounce on the ground, flicker
##                             and cool (yellow-white to deep red, like embers).

## A spell colour as deep, saturated LINEAR light (see the top). `sat` above 1 pushes the weaker
## channels further down (orange stays orange, never cream).
static func deep(c: Color, sat: float = 1.25) -> Color:
	var l := c.srgb_to_linear()
	var m := maxf(l.r, maxf(l.g, l.b))
	if m <= 0.0001:
		return Color(0, 0, 0, c.a)
	return Color(m * pow(l.r / m, sat), m * pow(l.g / m, sat), m * pow(l.b / m, sat), c.a)


static func vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## The streak: the particle's own Y axis (scaled) is the way it flies, its X axis scale its width.
## The quad is turned flat to the camera round that axis. The head sits ON the particle, the tail
## trails behind it. COLOR.rgb is the spark's own colour (linear), COLOR.a how much of it shows.
const STREAK_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float heat = 4.0;
uniform vec3 core_col = vec3(1.0, 0.9, 0.7);
uniform float core_k = 0.7;
uniform vec4 hold = vec4(-1.0);          // the one hit, on the screen (0..1): sparks in front of him are thinned
uniform float hold_z = -1000.0;          // ... and his feet's world z (only sparks nearer the camera are thinned)
uniform vec4 hold2 = vec4(-1.0);         // a neighbour inside the blaze (kept clear the same way)
uniform float hold2_z = -1000.0;
varying float fade;
varying float near_z;
varying vec3 tint;
void vertex() {
	vec3 mid = MODEL_MATRIX[3].xyz;
	near_z = mid.z;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = length(axis);
	fade = COLOR.a;
	tint = COLOR.rgb;
	axis = axis / max(len, 1e-4);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - mid);
	vec3 side = cross(axis, to_cam);
	side = length(side) < 1e-3 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	float wide = length(MODEL_MATRIX[0].xyz);
	vec3 w = mid + side * VERTEX.x * wide + axis * (VERTEX.y - 0.5) * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	if (len < 1e-4 || !(fade > 0.002)) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
}
void fragment() {
	float across = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float along = clamp(1.0 - UV.y, 0.0, 1.0);                  // 1 at the head, 0 at the end of the tail
	float body = pow(across, 1.7) * pow(along, 1.4) * (1.0 - smoothstep(0.9, 1.0, along) * 0.6);
	float hot = pow(across, 5.0) * smoothstep(0.55, 0.95, along);
	vec2 sc = SCREEN_UV;
	float inside = step(hold.x, sc.x) * step(sc.x, hold.z) * step(hold.y, sc.y) * step(sc.y, hold.w);
	float inside2 = step(hold2.x, sc.x) * step(sc.x, hold2.z) * step(hold2.y, sc.y) * step(sc.y, hold2.w);
	float k = (1.0 - 0.98 * inside * step(hold_z + 0.02, near_z)) * (1.0 - 0.9 * inside2 * step(hold2_z + 0.02, near_z));
	float m = max(max(tint.r, tint.g), tint.b);
	ALBEDO = mix(tint, core_col * max(m, 0.4), clamp(hot * core_k, 0.0, 1.0)) * heat;
	ALPHA = clamp((body + hot * 0.8) * fade * k, 0.0, 1.0);
}
"

static var _streak_shader: Shader


static func streak_material(heat: float, core: Color = Color(1.0, 0.9, 0.7), core_k: float = 0.7, priority: int = 12) -> ShaderMaterial:
	if _streak_shader == null:
		_streak_shader = Shader.new()
		_streak_shader.code = STREAK_CODE
	var m := ShaderMaterial.new()
	m.shader = _streak_shader
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("core_col", vec(core))
	m.set_shader_parameter("core_k", core_k)
	m.render_priority = priority
	return m


## Sparks flown by code (see the top). Fill with add(), then add_child() it; it frees itself when
## the last spark is out.
class Streaks extends MultiMeshInstance3D:
	var centre := Vector3.ZERO
	var spin := 0.0                  ## sideways push round the upright through `centre` (a spiral)
	var pull := 0.0                  ## push away from that upright (negative: towards it)
	var grav := Vector3.ZERO
	var drag := 0.0
	var trail := 0.05                ## a streak is as long as the way it flies in this many seconds
	var min_len := 0.08
	var max_len := 1.4
	var width := 0.06
	var floor_y := -1000.0           ## sparks bounce here (the ground), losing `bounce` of their speed
	var bounce := 0.0
	var flicker := 0.0               ## 0..1: embers flicker as they fly
	var wobble := 0.0                ## a drifting push this strong (smoke, embers in hot air)
	var cool := Color(-1, 0, 0)      ## if set: each spark's colour fades to this as it ages
	var srgb := true                 ## colours given to add() and `cool` are sRGB (as in the data): deepened to linear
	var _p := PackedVector3Array()
	var _v := PackedVector3Array()
	var _age := PackedFloat32Array()
	var _life := PackedFloat32Array()
	var _col := PackedColorArray()
	var _t := 0.0

	func start(n: int, mat: Material) -> void:
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.material = mat
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = q
		multimesh.instance_count = n
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 40.0
		_p.resize(n)
		_v.resize(n)
		_age.resize(n)
		_life.resize(n)
		_col.resize(n)
		if srgb and cool.r >= 0.0:
			cool = _deep(cool)
		for i in n:
			_life[i] = 0.0
			_age[i] = 1.0
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			multimesh.set_instance_color(i, Color(1, 1, 1, 0))

	## One spark: where, how fast, after how long it starts, how long it lives, its colour (linear).
	func add(i: int, at: Vector3, vel: Vector3, delay: float, life: float, colour: Color = Color(1, 1, 1)) -> void:
		_p[i] = at
		_v[i] = vel
		_age[i] = -delay
		_life[i] = life
		_col[i] = _deep(colour) if srgb else colour

	static func _deep(c: Color) -> Color:
		var l := c.srgb_to_linear()
		var m := maxf(l.r, maxf(l.g, l.b))
		if m <= 0.0001:
			return Color(0, 0, 0)
		return Color(m * pow(l.r / m, 1.15), m * pow(l.g / m, 1.15), m * pow(l.b / m, 1.15))

	func _process(delta: float) -> void:
		_t += delta
		var alive := false
		var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		for i in _p.size():
			var age := _age[i] + delta
			_age[i] = age
			if age < 0.0 or age > _life[i]:
				if age <= _life[i]:
					alive = true
				multimesh.set_instance_color(i, Color(1, 1, 1, 0))
				multimesh.set_instance_transform(i, hidden)
				continue
			alive = true
			var v := _v[i]
			var p := _p[i]
			if spin != 0.0 or pull != 0.0:
				var flat := Vector3(p.x - centre.x, 0.0, p.z - centre.z)
				if flat.length_squared() > 0.0001:
					var out := flat.normalized()
					v += (Vector3(-out.z, 0.0, out.x) * spin + out * pull) * delta
			if wobble > 0.0:
				v += Vector3(sin(_t * 3.1 + i * 1.7), cos(_t * 2.3 + i * 0.9) * 0.4, cos(_t * 2.7 + i * 2.3)) * wobble * delta
			v += grav * delta
			v *= maxf(1.0 - drag * delta, 0.0)
			p += v * delta
			if p.y < floor_y and v.y < 0.0:
				p.y = floor_y
				v = Vector3(v.x * 0.6, -v.y * bounce, v.z * 0.6)
			_v[i] = v
			_p[i] = p
			var speed := v.length()
			var t := age / _life[i]
			var fade := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.5, 1.0, t))
			if flicker > 0.0:
				fade *= 1.0 - flicker * (0.5 + 0.5 * sin(_t * 31.0 + i * 3.7))
			var dir := v / speed if speed > 0.001 else Vector3.UP
			var length := clampf(speed * trail, maxf(min_len, width * 1.2), max_len)
			multimesh.set_instance_transform(i, Transform3D(Basis(Vector3(width, 0.0, 0.0), dir * length, Vector3(0.0, 0.0, 1.0)), p))
			var c := _col[i]
			if cool.r >= 0.0:
				c = c.lerp(cool, smoothstep(0.1, 0.8, t))
			multimesh.set_instance_color(i, Color(c.r, c.g, c.b, fade))
		if not alive:
			queue_free()
