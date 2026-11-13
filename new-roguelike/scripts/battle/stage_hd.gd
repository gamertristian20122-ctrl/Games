extends RefCounted
## THE BATTLE STAGE ON A PC (Forward+, `Hd.on()`, scripts/fx/hd.gd): the same clearing as
## stage.gd builds, lit for real, in the look of the "pixel sprites in a lit 3D diorama" pictures
## the owner sent (a night battle with a big glowing spell above all). Made by stage.gd
## (`hd = StageHd.new(self)`); `s` is the stage. Without HD (the phone, `--nohd`) none of this
## exists and the stage looks as it always did.
##   env(env, sun)   AgX tone, SSAO, SSIL, wide bloom over a hot threshold, volumetric fog that the
##                   moon / sun and every spell light scatter in, a sky with clouds (and stars and
##                   a moon by night), screen-space reflections on the wet ground
##   sky light       the sun or the moon throws soft real shadows (PCSS): every fighter, tree and
##                   stone throws its own; the flat shadow pictures are not drawn
##   spell_light()   a real OmniLight3D that flares up and fades: lights ground, fighters and
##                   scenery, glows in the fog; the big ones throw shadows too
##   core() / swirl() a blazing core of light and a column of sparks for the big spells
##   focus()         every frame: the camera's own depth of field. The band in focus holds EVERY
##                   fighter (feet to head) with room to spare; only the wood behind them and the
##                   things between the camera and them are blurred (the owner: "the blurriness is
##                   so strong that I can't see the characters")
## All numbers to tune by eye are in LOOK (per stage look) and the constants below.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")

## Per stage look (stage.gd LOOKS): how the PC light differs. Missing keys fall back to "forest".
##   sun / sun_energy   the key light (the moon at night)      ambient / ambient_energy   the shade
##   fog / fog_density  the air (volumetric fog; fog_aniso how much it scatters forwards)             fog_sun   how much the key light lights the air
##   exposure           tone exposure                          sky_top / sky_low / clouds   the sky
##   stars              0 = day sky, 1 = night sky with stars and a moon
##   wet                how much of the ground is wet (puddles that mirror the lights; 0 = dry)
##   top_rim            the cool edge of light along the top of every fighter, and its colour
##   fire_boost         fires and glowing stones burn this much hotter than in the flat look
##   tame               by day: pale fighters (white robes, pale hair) are drawn a little less bright,
##                      so in the full sun they do not burn white and bloom
##   spell              how strong spell light is here (by day less: the sun already fills the picture)
const LOOK := {
	"forest": {"sun": Color("ffcf8a"), "sun_energy": 2.1, "ambient": Color("b09878"), "ambient_energy": 0.34,
		"fog": Color("ffe2b8"), "fog_density": 0.005, "fog_sun": 0.8, "fog_aniso": 0.2, "exposure": 1.55,
		"sky_top": Color("4a5a86"), "sky_low": Color("ffc27a"), "clouds": Color("c8906a"), "stars": 0.0,
		"wet": 0.0, "top_rim": [0.35, Color("fff0c8")], "fire_boost": 1.0, "spell": 0.7, "tame": 0.8},
	"forest_night": {"sun": Color("9fb6ff"), "sun_energy": 1.25, "ambient": Color("38487a"), "ambient_energy": 0.30,
		"fog": Color("6a84c0"), "fog_density": 0.024, "fog_sun": 0.55, "exposure": 1.35,
		"sky_top": Color("050a18"), "sky_low": Color("16264a"), "clouds": Color("2a3654"), "stars": 1.0,
		"wet": 0.3, "top_rim": [0.55, Color("a8c4ff")], "fire_boost": 2.6, "spell": 1.0, "tame": 0.0},
	"desert": {"sun": Color("ffe0b0"), "sun_energy": 1.7, "ambient": Color("a89cb4"), "ambient_energy": 0.26,
		"fog": Color("ffe4c0"), "fog_density": 0.006, "fog_sun": 0.6, "fog_aniso": 0.2, "exposure": 1.45,
		"sky_top": Color("6a8ac4"), "sky_low": Color("ffd8a0"), "clouds": Color("fff0dc"), "stars": 0.0,
		"wet": 0.0, "top_rim": [0.3, Color("fff4dc")], "fire_boost": 1.0, "spell": 0.5, "tame": 0.6},
	"rock": {"sun": Color("ffb890"), "sun_energy": 1.2, "ambient": Color("6a4a5a"), "ambient_energy": 0.30,
		"fog": Color("a04a2a"), "fog_density": 0.026, "fog_sun": 0.6, "exposure": 1.3,
		"sky_top": Color("10070a"), "sky_low": Color("4a1a12"), "clouds": Color("3a1a16"), "stars": 0.3,
		"wet": 0.25, "top_rim": [0.45, Color("ffb080")], "fire_boost": 2.4, "spell": 1.0, "tame": 0.0},
}
const SPELL_ENERGY := 6.0          ## a spell light at power 1 (the flat look's is 5 + 6 x power, without fog)
const SPELL_FOG := 1.6             ## how much a spell light glows in the air
const DOF_AMOUNT := 0.09           ## how strong the blur is far behind and right in front of the fighters
const FOCUS_ROOM := 2.6            ## world units of sharp ground kept in front of and behind the fighters

const SKY_CODE := "
shader_type sky;
uniform vec3 top_col : source_color = vec3(0.02, 0.04, 0.1);
uniform vec3 low_col : source_color = vec3(0.1, 0.15, 0.3);
uniform vec3 cloud_col : source_color = vec3(0.2, 0.25, 0.35);
uniform float stars = 1.0;
uniform vec3 moon_dir = vec3(0.3, 0.45, -0.85);
uniform vec3 moon_col : source_color = vec3(0.8, 0.88, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += noise(p) * a; p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(low_col, top_col, smoothstep(-0.05, 0.55, h));
	// clouds: soft drifting banks, lit from the moon's (or the low sun's) side
	vec2 cp = d.xz / (max(h, 0.02) + 0.25) * 1.6 + vec2(TIME * 0.004, 0.0);
	float c = smoothstep(0.42, 0.78, fbm(cp));
	float lit_side = pow(max(dot(d, normalize(moon_dir)), 0.0), 3.0);
	vec3 cloud = cloud_col * (0.55 + 0.9 * lit_side);
	// the moon (or the sun behind the haze) and its halo
	float m = dot(d, normalize(moon_dir));
	float disc = smoothstep(0.9993, 0.9996, m);
	float halo = pow(max(m, 0.0), 60.0) * 0.5 + pow(max(m, 0.0), 6.0) * 0.18;
	// stars: one in a few cells, twinkling, hidden by the clouds and fading near the horizon
	vec2 sp = d.xz / (h + 1.0) * 220.0;
	vec2 cell = floor(sp);
	float r = hash(cell);
	float star = step(0.985, r) * smoothstep(0.35, 0.0, length(fract(sp) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5));
	star *= (0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0)) * smoothstep(0.05, 0.3, h) * stars * (1.0 - c);
	col += moon_col * (disc * 6.0 + halo) * (1.0 - c * 0.7);
	col = mix(col, cloud, c * smoothstep(-0.02, 0.12, h));
	col += vec3(0.85, 0.9, 1.0) * star * 2.2;
	COLOR = col;
}
"

## THE HD GROUND: the same tile as stage.gd GROUND_CODE, but WET where `wet` says so (by night):
## puddles darker and smooth, which mirror the scene (screen-space reflections) and catch every
## lamp and spell as a hot glint. Dry ground stays matt.
const GROUND_CODE := "
shader_type spatial;
render_mode cull_back;
global uniform sampler2D hh_dapple : filter_linear, repeat_enable;
global uniform vec4 hh_dapple_set;
global uniform vec4 hh_pool;
varying float sun_share;
float sun_at(vec2 where) {
	float n = texture(hh_dapple, where * hh_dapple_set.x + hh_dapple_set.zw).r;
	float patch = smoothstep(0.32, 0.56, n);
	float pool = (1.0 - smoothstep(hh_pool.z * 0.35, hh_pool.z, distance(where, hh_pool.xy))) * hh_pool.w;
	return mix(1.0, mix(0.62, 1.14, clamp(max(patch * 0.9, pool), 0.0, 1.0)), hh_dapple_set.y);
}
GROUND_PART
uniform float wet = 0.0;
varying float puddle;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec3 c = ground_colour(at);
	float n = texture(hh_dapple, at * 0.09 + vec2(0.31, 0.17)).r;
	float m = texture(hh_dapple, at * 0.21 + vec2(0.7, 0.2)).r;
	puddle = smoothstep(0.78 - wet * 0.1, 0.80 - wet * 0.1, n * 0.85 + m * 0.15) * step(0.01, wet);
	float damp = smoothstep(0.45 - wet * 0.25, 0.62 - wet * 0.22, n) * wet;
	ALBEDO = c * (1.0 - 0.4 * damp) * (1.0 - 0.55 * puddle);
	ROUGHNESS = mix(1.0, 0.06, puddle) * (1.0 - 0.25 * damp);
	SPECULAR = mix(0.2, 0.5, puddle);
	sun_share = sun_at(at);
}
void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
	// a glint on the wet ground: tight and hot on the puddles, a faint sheen on damp earth
	vec3 hv = normalize(LIGHT + VIEW);
	float shin = mix(18.0, 600.0, puddle);
	float spec = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), shin) * mix(0.25, 6.0, puddle) * wet;
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * (LIGHT_IS_DIRECTIONAL ? 0.5 : 1.0);
}
"

var s                              ## the stage (scripts/battle/stage.gd; untyped: its members are read by name)
var look := {}
var attrs: CameraAttributesPractical
var _band := Vector2.ZERO
static var _dot: GradientTexture2D


func _init(stage) -> void:
	s = stage


## The PC numbers of this look (LOOK, falling back to "forest").
func setup(look_name: String) -> void:
	look = (LOOK["forest"] as Dictionary).duplicate()
	if LOOK.has(look_name):
		look.merge(LOOK[look_name], true)


func num(key: String) -> float:
	return float(look.get(key, 0.0))


## The environment and the key light, lit for real.
func env(e: Environment, sun: DirectionalLight3D) -> void:
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = num("exposure")
	e.tonemap_agx_contrast = 1.4
	e.tonemap_agx_white = 10.0
	e.ambient_light_color = look["ambient"]
	e.ambient_light_energy = num("ambient_energy")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# (no sky in the puddles: they stay dark mirrors that only show what is lit: the fire, a spell)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.ssao_enabled = true
	e.ssao_radius = 1.0
	e.ssao_intensity = 2.0
	e.ssao_power = 1.6
	e.ssao_light_affect = 0.15
	e.ssil_enabled = true
	e.ssil_radius = 4.0
	e.ssil_intensity = 1.1
	# wet ground mirrors what stands on it
	e.ssr_enabled = num("wet") > 0.0
	e.ssr_max_steps = 48
	e.ssr_fade_in = 0.1
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.4
	# bloom: hot cores of flame and spell burn white and spill a wide soft glow, like a lens
	e.glow_enabled = true
	e.glow_normalized = false
	for i in 7:
		e.set_glow_level(i, [0.0, 0.3, 0.7, 1.0, 1.0, 0.85, 0.6][i])
	e.glow_intensity = 0.5
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.0 if num("stars") > 0.5 or num("fire_boost") > 1.5 else 2.2    # (by day only real fire blooms, not white robes in the sun)
	e.glow_hdr_scale = 2.4
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# the air: thin fog that the key light and every spell light really scatter in
	e.fog_enabled = true                    # (plus a little plain distance fog, so the far wood melts)
	e.fog_density = float(s.look.get("mist_density", 0.01)) * 0.5
	e.fog_sky_affect = 0.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = num("fog_density")
	e.volumetric_fog_albedo = look["fog"]
	e.volumetric_fog_anisotropy = float(look.get("fog_aniso", 0.6))     # (by day low: looking into a low sun, strong forward scatter is a wall of haze)
	e.volumetric_fog_length = 70.0
	e.volumetric_fog_detail_spread = 1.4
	e.volumetric_fog_ambient_inject = 0.25
	e.volumetric_fog_sky_affect = 0.15
	e.volumetric_fog_temporal_reprojection_amount = 0.6   # (a spell's flash must not smear for long)
	# the sky (seen as the battle opens, and mirrored in the wet ground)
	var sh := Shader.new()
	sh.code = SKY_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("top_col", look["sky_top"])
	mat.set_shader_parameter("low_col", look["sky_low"])
	mat.set_shader_parameter("cloud_col", look["clouds"])
	mat.set_shader_parameter("stars", num("stars"))
	var to_light := sun.global_transform.basis.z
	mat.set_shader_parameter("moon_dir", Vector3(to_light.x, maxf(to_light.y, 0.25), to_light.z).normalized())
	mat.set_shader_parameter("moon_col", Vector3(1.0, 0.95, 0.85) if num("stars") < 0.5 else Vector3(0.8, 0.88, 1.0))
	var sky := Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	# the key light: the low sun, or the moon; soft real shadows that widen with distance
	sun.light_color = look["sun"]
	sun.light_energy = num("sun_energy")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.6
	sun.shadow_blur = 1.3
	sun.light_angular_distance = 1.4
	sun.light_volumetric_fog_energy = num("fog_sun")
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	# the camera's own depth of field (focus() sets the band every frame)
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_amount = DOF_AMOUNT
	s.cam.attributes = attrs
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)


## The ground's material (see GROUND_CODE).
func ground_material(params: Dictionary) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GROUND_CODE.replace("GROUND_PART", s.GROUND_PART)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	mat.set_shader_parameter("wet", num("wet"))
	return mat


## A small light of the place (the fire, a glowing stone): it glows in the air and, if `shadows`,
## throws soft shadows (the fire: every fighter's shadow leans away from it).
func lamp(l: OmniLight3D, shadows: bool) -> void:
	l.light_volumetric_fog_energy = 2.2
	l.light_size = 0.25
	l.shadow_enabled = shadows
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.0
	l.shadow_blur = 1.5


## A fighter on his feet: a real shadow, never fogged, a cool edge of sky light along the top.
func fighter(sprite: MeshInstance3D) -> void:
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var r: Array = look["top_rim"]
	sprite.call("set_top_rim", float(r[0]), r[1])
	(sprite.material_override as ShaderMaterial).set_shader_parameter("tame", num("tame"))


## SPELL LIGHT: a real light that flares up on a spot and fades, lighting the ground, the fighters
## and the trees round it and glowing in the air. Big ones (power 2 and over) throw shadows.
func spell_light(at: Vector3, colour: Color, power: float, life: float) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = colour
	l.light_energy = 0.0
	l.omni_range = 7.0 + 3.0 * power
	l.omni_attenuation = 1.2
	l.light_size = 0.4
	l.light_volumetric_fog_energy = SPELL_FOG * (0.6 + 0.4 * power) * num("spell")
	l.shadow_enabled = power >= 2.0
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.0
	l.shadow_blur = 1.4
	s.add_child(l)
	var peak := SPELL_ENERGY * (0.6 + 0.5 * power) * num("spell")
	var tw: Tween = s.create_tween()
	tw.tween_property(l, "light_energy", peak, 0.05)
	tw.tween_property(l, "light_energy", peak * 0.55, life * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 0.0, life * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


static func dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


## THE BLAZING CORE of a spell: a hot white-hot ball of light that the bloom spreads like a lens.
func core(at: Vector3, colour: Color, size: float, life: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot()
	var hot := colour.lerp(Color.WHITE, 0.45)
	var k := 3.0 * num("spell")
	m.albedo_color = Color(hot.r * k, hot.g * k, hot.b * k, 1.0)
	m.disable_fog = true
	m.no_depth_test = false
	m.render_priority = 13
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var b := MeshInstance3D.new()
	b.mesh = q
	b.material_override = m
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.position = at
	b.scale = Vector3(0.3, 0.3, 0.3)
	s.add_child(b)
	var tw: Tween = s.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "scale", Vector3(1.5, 1.5, 1.5), life)
	tw.tween_callback(b.queue_free)


## A COLUMN OF SPARKS that whirl up round a spot (the big spells): hundreds of hot specks.
func swirl(at: Vector3, colour: Color, power: float, height: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.55
	p.amount = int(clampf(70.0 * power, 60.0, 240.0))
	p.lifetime = 0.9
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9 + 0.2 * power
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.4
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 12.0
	p.gravity = Vector3(0.0, 2.0, 0.0)
	p.initial_velocity_min = height * 0.35
	p.initial_velocity_max = height * 0.9
	p.tangential_accel_min = 9.0
	p.tangential_accel_max = 16.0
	p.radial_accel_min = -2.5
	p.radial_accel_max = -0.5
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot()
	var hot := colour.lerp(Color.WHITE, 0.3)
	m.albedo_color = Color(hot.r * 4.0, hot.g * 4.0, hot.b * 4.0, 1.0)
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 12
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	q.material = m
	p.mesh = q
	s.add_child(p)
	p.emitting = true
	s.get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


## Every frame: the depth of field. Sharp from a little in front of the nearest fighter to a little
## behind the farthest (feet and head of every one on screen); blur grows only past that.
func focus(delta: float, people: Array) -> void:
	var cam: Camera3D = s.cam
	var to_view := cam.global_transform.affine_inverse()
	var near := 1.0e9
	var far := -1.0e9
	for p: Node3D in people:
		if not is_instance_valid(p) or not p.is_visible_in_tree():
			continue
		for h: float in [0.0, float(p.call("height"))]:
			var z := -(to_view * (p.global_position + Vector3(0.0, h, 0.0))).z
			near = minf(near, z)
			far = maxf(far, z)
	if near > far:
		var mid := cam.global_position.distance_to(Vector3(0.0, 1.0, 0.0))
		near = mid - 2.0
		far = mid + 2.0
	var want := Vector2(maxf(near - FOCUS_ROOM, 1.0), far + FOCUS_ROOM)
	_band = want if _band == Vector2.ZERO else _band.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	attrs.dof_blur_near_distance = _band.x
	attrs.dof_blur_near_transition = 3.0
	attrs.dof_blur_far_distance = _band.y
	attrs.dof_blur_far_transition = 16.0
