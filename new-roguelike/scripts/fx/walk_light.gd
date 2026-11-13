extends RefCounted
## LIGHT AND AIR for the places you walk in (used by scripts/hub/view3d.gd). Code only, no art:
## every effect here is light, a soft gradient or a speck.
##   GRADES      the colour of each land, by day and by night, and once its beacon is lit
##   POST_CODE   the last pass: blur near and far, the grade, a haze that thickens with distance
##   pool()      a soft circle of lamp light laid on the ground (flat, additive: costs almost nothing)
##   halo()      the soft glow round a flame or a lit window, standing in the air
##   shafts()    slanting beams of sun by day
##   motes()     dust in the sun by day
## One world unit is 16 art pixels. Things drawn with blending use render_priority above 0 so the
## last pass does not hide them (scripts/battle/stage.gd, lesson 3).

## The look of each land. Keys:
##   warm / shade   what bright / dark parts are tinted by     punch  contrast (1 = as painted)
##   rich           colour strength (1 = as painted)            haze   the colour of distance
##   far            how much distance fades into the haze       rim    how dark the corners get
##   shafts         beams of sun (0 none, 1 full)               motes  dust in the sun (0 to 1)
##   dapple         HD: soft patches of leaf shade on the ground (0 = none: open sand, a square;
##                  the real shadow maps do the shade there; 1 = under thick leaves)
##   exposure       HD: how much more the camera opens up here (the dark woods: more, so the
##                  clearing glows and only the woods round it stay near black)
## Rows: "<place>" (by day), "<place>:night", "<place>:lit" (after its land's beacon is lit),
## "default", "default:night", "indoors". A missing key is taken from "default" / "default:night".
const GRADES := {
	"default": {"warm": Vector3(1.06, 1.01, 0.90), "shade": Vector3(1.0, 0.93, 0.88), "punch": 1.07, "rich": 0.97,
		"haze": Color(1.0, 0.86, 0.62), "far": 0.30, "rim": 0.46, "shafts": 0.8, "motes": 0.8, "dapple": 0.5, "exposure": 1.0},
	"default:night": {"warm": Vector3(1.10, 1.0, 0.86), "shade": Vector3(0.84, 0.94, 1.16), "punch": 1.06, "rich": 0.95,
		"haze": Color(0.20, 0.26, 0.42), "far": 0.34, "rim": 0.52, "shafts": 0.0, "motes": 0.0, "dapple": 0.0, "exposure": 1.0},
	# Wickmere at dusk: honey light on the stones, plum shade
	"village": {"warm": Vector3(1.08, 1.0, 0.88), "shade": Vector3(1.0, 0.90, 0.94), "haze": Color(1.0, 0.80, 0.60), "far": 0.26, "dapple": 0.25},
	# the dark road (before the beacon): greener, cooler shade, thicker air, few beams
	"elfwood": {"warm": Vector3(1.03, 1.02, 0.92), "shade": Vector3(0.88, 0.97, 1.04), "punch": 1.09, "rich": 0.94,
		"haze": Color(0.82, 0.76, 0.52), "far": 0.38, "rim": 0.52, "shafts": 0.45, "motes": 0.5, "dapple": 0.7, "exposure": 1.7},
	"deepwood": {"warm": Vector3(1.0, 1.02, 0.94), "shade": Vector3(0.84, 0.96, 1.06), "punch": 1.10, "rich": 0.92,
		"haze": Color(0.62, 0.66, 0.50), "far": 0.44, "rim": 0.56, "shafts": 0.35, "motes": 0.4, "dapple": 0.8, "exposure": 1.75},
	"glade": {"warm": Vector3(1.03, 1.02, 0.94), "shade": Vector3(0.88, 0.96, 1.08), "haze": Color(0.66, 0.80, 0.82), "far": 0.34, "shafts": 0.6, "dapple": 0.7, "exposure": 1.3},
	"beacon": {"warm": Vector3(1.05, 1.0, 0.92), "shade": Vector3(0.90, 0.92, 1.06), "haze": Color(0.80, 0.78, 0.76), "far": 0.36, "shafts": 0.5, "dapple": 0.4, "exposure": 1.2},
	# golden dawn: the land after its beacon is lit
	"elfwood:lit": {"warm": Vector3(1.10, 1.01, 0.84), "shade": Vector3(1.02, 0.93, 0.86), "punch": 1.05, "rich": 1.0,
		"haze": Color(1.0, 0.82, 0.55), "far": 0.30, "rim": 0.42, "shafts": 1.0, "motes": 1.0},
	"deepwood:lit": {"warm": Vector3(1.09, 1.01, 0.86), "shade": Vector3(0.98, 0.94, 0.90), "haze": Color(0.96, 0.82, 0.58), "far": 0.32, "shafts": 1.0, "motes": 1.0},
	"glade:lit": {"warm": Vector3(1.10, 1.01, 0.85), "haze": Color(1.0, 0.84, 0.58), "shafts": 1.0, "motes": 1.0},
	"beacon:lit": {"warm": Vector3(1.11, 1.0, 0.83), "haze": Color(1.0, 0.80, 0.52), "shafts": 1.0, "motes": 1.0},
	# the Sands: hot pale dust before the beacon, deep amber after it
	"dustwatch": {"warm": Vector3(1.07, 1.0, 0.88), "shade": Vector3(0.96, 0.90, 0.96), "haze": Color(0.96, 0.82, 0.62), "far": 0.34, "shafts": 0.6, "dapple": 0.0},
	"suncourt": {"warm": Vector3(1.04, 0.99, 0.90), "shade": Vector3(0.90, 0.90, 1.04), "haze": Color(0.78, 0.70, 0.62), "far": 0.38, "shafts": 0.4, "dapple": 0.0},
	"dustwatch:lit": {"warm": Vector3(1.12, 1.0, 0.82), "haze": Color(1.0, 0.78, 0.50), "shafts": 1.0, "motes": 1.0},
	"suncourt:lit": {"warm": Vector3(1.11, 1.0, 0.83), "haze": Color(1.0, 0.80, 0.52), "shafts": 1.0, "motes": 1.0},
	# the world map: a wide view, so the distance matters most
	"world": {"haze": Color(0.92, 0.84, 0.70), "far": 0.42, "rim": 0.40, "shafts": 0.55, "motes": 0.3, "dapple": 0.0},
	"world:night": {"haze": Color(0.16, 0.22, 0.38), "far": 0.45},
	# rooms: candle warmth, soft brown shade
	"indoors": {"warm": Vector3(1.09, 0.99, 0.84), "shade": Vector3(0.96, 0.88, 0.90), "punch": 1.05, "rich": 0.98,
		"haze": Color(0.32, 0.20, 0.14), "far": 0.0, "rim": 0.50, "shafts": 0.0, "motes": 0.0, "dapple": 0.0},
}

## Which land a place belongs to, for "lit" (Tale.lit(land)).
const LAND := {"elfwood": "elfwood", "deepwood": "elfwood", "glade": "elfwood", "beacon": "elfwood",
	"dustwatch": "sands", "suncourt": "sands"}


## The grade for a place: `day` 1 = full day, 0 = night (rows are blended by it).
static func grade(place_id: String, outdoor: bool, day: float, lit: bool) -> Dictionary:
	if not outdoor:
		return _fill(GRADES["indoors"], GRADES["default"])
	var by_day: Dictionary = _fill(GRADES.get(place_id, {}), GRADES["default"])
	if lit and GRADES.has(place_id + ":lit"):
		by_day = _fill(GRADES[place_id + ":lit"], by_day)
	var by_night: Dictionary = _fill(GRADES.get(place_id + ":night", {}), GRADES["default:night"])
	var out := {}
	for k: String in by_day:
		var a: Variant = by_night[k]
		var b: Variant = by_day[k]
		if b is float:
			out[k] = lerpf(a, b, day)
		elif b is Vector3:
			out[k] = (a as Vector3).lerp(b, day)
		elif b is Color:
			out[k] = (a as Color).lerp(b, day)
	return out


static func _fill(row: Dictionary, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k: String in row:
		out[k] = row[k]
	return out


## The last pass (the battle stage's, scripts/battle/stage.gd POST_CODE, plus a haze that thickens
## with distance, a soft glow of the light into the shade, and a gentle golden sky at the top).
const POST_CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float focus = 18.0;
uniform float sharp = 2.2;
uniform float falloff = 10.0;
uniform float blur_px = 8.0;
uniform float rim = 0.55;
uniform vec3 warm = vec3(1.07, 1.0, 0.90);
uniform vec3 shade = vec3(0.88, 0.96, 1.12);
uniform float punch = 1.0;
uniform float rich = 1.0;
uniform float lift = 0.0;
uniform vec3 haze : source_color = vec3(1.0, 0.85, 0.6);
uniform float far = 0.3;          // how much the distance fades into the haze
uniform float sky_glow = 0.0;     // a soft bright band at the top of the picture (the low sun)
uniform float blur_on = 1.0;      // 0 = no blur here (HD: the camera's own depth of field does it)
uniform float linear_in = 0.0;    // 1 = the picture is linear light (HD, Forward+): grade it as seen
uniform float fore_z = 0.0;       // HD: things nearer than this (view distance) are the dark foreground (0 = none)
const int TAPS = 22;

float dist(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).r;
	// (GL keeps depth in -1..1; Vulkan, Forward+ on PC, in 0..1: read the wrong way, everything
	// seemed out of focus and the whole picture was blurred)
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d, 1.0);
#endif
	return -v.z / v.w;
}
float soft(float z) {
	float f = z < focus ? falloff * 0.45 : falloff;
	return clamp((abs(z - focus) - sharp) / f, 0.0, 1.0);
}
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float r_max = blur_px * VIEWPORT_SIZE.y / 720.0;
	float zc = dist(SCREEN_UV, INV_PROJECTION_MATRIX);
	float cc = soft(zc);
	vec3 sum = texture(screen_tex, SCREEN_UV).rgb;
	float n = 1.0;
	vec3 bright = vec3(0.0);
	for (int i = 1; i <= TAPS && blur_on > 0.5; i++) {
		float r = sqrt(float(i) / float(TAPS));
		float a = float(i) * 2.39996;
		vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * r * r_max * px;
		float zt = dist(uv, INV_PROJECTION_MATRIX);
		float ct = soft(zt);
		if (zt > zc) { ct = min(ct, cc); }
		float w = smoothstep(r - 0.2, r + 0.05, ct);
		vec3 s = texture(screen_tex, uv).rgb;
		sum += s * w;
		n += w;
		bright += max(s - vec3(0.8), vec3(0.0));      // light that spills a little into what is round it
	}
	vec3 col = sum / n;
	col += bright * (0.9 / float(TAPS));
	if (linear_in > 0.5) { col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)); }
	col = pow(max(col, vec3(0.0)), vec3(punch));
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, rich);
	col = mix(col, col * warm, smoothstep(0.25, 0.9, l));
	col = mix(col, col * shade, 1.0 - smoothstep(0.0, 0.3, l));
	col = mix(col, haze, lift * (1.0 - l));
	// distance: the far part of the picture melts into the air
	float deep = smoothstep(focus + sharp, focus + falloff * 3.2, zc);
	col = mix(col, haze * (0.75 + 0.25 * l), deep * far);
	// the foreground (between the camera and the play): in shade, cooler, less colour
	float fore = fore_z > 0.0 ? 1.0 - smoothstep(fore_z - 2.5, fore_z - 0.2, zc) : 0.0;
	col = mix(col, mix(vec3(l), col, 0.55) * vec3(0.40, 0.42, 0.47), fore);
	// the low sun just over the top of the picture
	col += haze * sky_glow * pow(1.0 - SCREEN_UV.y, 3.0) * 0.35;
	vec2 q = SCREEN_UV - 0.5;
	col *= 1.0 - smoothstep(0.18, 0.62, dot(q, q) * 1.9) * rim;
	if (linear_in > 0.5) { col = pow(max(col, vec3(0.0)), vec3(2.2)); }
	ALBEDO = col;
}
"

## Lamp light on the ground: brightest in the middle, gone at the edge; flat on the floor.
const POOL_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.4);
uniform float strength = 1.0;
void fragment() {
	vec2 p = floor(UV * 48.0) / 48.0 - 0.5;          // in steps, so it sits with the pixel art
	float d = length(p) * 2.0;
	float f = 1.0 - smoothstep(0.0, 1.0, d);
	f = f * f * (0.55 + 0.45 * f);
	ALBEDO = colour * f * strength * 2.5;
}
"
## The soft glow round a flame, standing in the air and always facing the camera.
const HALO_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.4);
uniform float strength = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float f = exp(-d * d * 4.5) * (1.0 - smoothstep(0.8, 1.0, d));
	ALBEDO = colour * f * strength * 3.4;
}
"
## A beam of sun: soft at both sides, fading out at the ground and in the sky, with dust in it.
const SHAFT_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(1.0, 0.85, 0.55);
uniform float strength = 0.1;
uniform float seed = 0.0;
uniform float soft = 0.0;          // 1 = a wide soft beam: a bell across, no streaks (HD)
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = mix(smoothstep(0.0, 0.9, across), across * across * (3.0 - 2.0 * across), soft);
	float along = smoothstep(1.0, 0.72, UV.y) * smoothstep(0.0, 0.5, UV.y);
	float breathe = 0.75 + 0.25 * sin(TIME * 0.35 + seed * 6.1);
	float streak = mix(0.75 + 0.25 * sin(UV.x * 17.0 + seed * 3.0 + TIME * 0.2), 1.0, soft);
	ALBEDO = colour * across * along * breathe * streak * strength;
}
"

static var _pool_shader: Shader
static var _halo_shader: Shader
static var _shaft_shader: Shader


static func _shader(which: String) -> Shader:
	match which:
		"pool":
			if _pool_shader == null:
				_pool_shader = Shader.new()
				_pool_shader.code = POOL_CODE
			return _pool_shader
		"halo":
			if _halo_shader == null:
				_halo_shader = Shader.new()
				_halo_shader.code = HALO_CODE
			return _halo_shader
	if _shaft_shader == null:
		_shaft_shader = Shader.new()
		_shaft_shader.code = SHAFT_CODE
	return _shaft_shader


## A circle of light `radius` units wide on the ground at `at` (world units).
static func pool(at: Vector3, radius: float, colour: Color) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _shader("pool")
	mat.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	mat.render_priority = 4
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = mat
	m.position = at + Vector3(0.0, 0.035, 0.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## A soft glow `size` units across round a light at `at`.
static func halo(at: Vector3, size: float, colour: Color) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _shader("halo")
	mat.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	mat.render_priority = 6
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = mat
	m.position = at
	m.scale = Vector3.ONE * size
	m.extra_cull_margin = size
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## `count` beams of sun falling along `light_dir` (the way the sun's light travels), spread over a
## patch `spread` units wide round the parent's origin. The parent follows the camera.
## `wide_back` (HD): fewer, wide, very soft beams, only in the band BEHIND the play (never between
## the camera and the people), with no streaks.
static func shafts(parent: Node3D, light_dir: Vector3, count: int, spread: float, length: float, wide_back := false) -> Array:
	var up := -light_dir.normalized()
	var side := Vector3(1.0, 0.0, 0.0)
	side = (side - up * side.dot(up)).normalized()
	var face := side.cross(up).normalized()
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in count:
		var mat := ShaderMaterial.new()
		mat.shader = _shader("shaft")
		mat.set_shader_parameter("seed", float(i) * 1.37)
		mat.render_priority = 5
		var q := QuadMesh.new()
		var wide := rng.randf_range(4.0, 7.0) if wide_back else rng.randf_range(0.9, 2.4)
		q.size = Vector2(wide, length)
		var m := MeshInstance3D.new()
		m.mesh = q
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = length
		var foot := Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread * 0.6, spread * 0.4))
		if wide_back:
			foot = Vector3((float(i) / maxf(count - 1, 1) - 0.5) * spread * 1.6 + rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-spread * 0.9, -spread * 0.45))
			mat.set_shader_parameter("soft", 1.0)
		m.transform = Transform3D(Basis(side, up, face), foot + up * (length * 0.5))
		parent.add_child(m)
		out.append(mat)
	return out


## Golden dust that hangs in the sunlight, in a box `extent` round the parent.
static func motes(extent: Vector3, dot: Texture2D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.gravity = Vector3(0.02, -0.004, 0.0)
	p.direction = Vector3(1.0, 0.3, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot
	m.albedo_color = Color(1.0, 0.86, 0.55) * 0.9
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 10
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = m
	p.mesh = q
	return p


## A lamp's flicker: about 1, wavering a little (`warm` fire wavers more than a cool rune light).
static func flicker(t: float, seed: float, warm: bool) -> float:
	if not warm:
		return 1.0 + 0.06 * sin(t * 1.3 + seed)
	return 1.0 + 0.07 * sin(t * 7.3 + seed) + 0.05 * sin(t * 13.7 + seed * 2.3) + 0.03 * sin(t * 23.1 + seed * 0.7)
