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
const FxKit = preload("res://scripts/battle/fx_kit.gd")

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
##   pool               [colour, strength]: a broad soft light from high above on the clearing where
##                      they fight, so the stage is lit and the wood round it falls into deep shade
##                      (the moonlit ground of the night-battle picture, the golden clearing by day)
##   earth / earth_gain / earth_tint   how much of the clearing is trodden earth and gravel (the
##                      pack's dirt tile, made paler by `earth_gain`; pebbles picked out per art
##                      pixel), so the moon makes it pale and the spells light it like the reference
##   gold / punch       the last pass: greens turned towards olive gold, and contrast (deeper shade)
const LOOK := {
	"forest": {"sun": Color("ffbe68"), "sun_energy": 2.5, "ambient": Color("6e5034"), "ambient_energy": 0.17,
		"fog": Color("ffc488"), "fog_density": 0.0016, "fog_sun": 0.5, "fog_aniso": 0.2, "exposure": 1.42,
		"sky_top": Color("3a4a78"), "sky_low": Color("ffa848"), "clouds": Color("b07040"), "stars": 0.0,
		"wet": 0.0, "top_rim": [0.35, Color("fff0c8")], "fire_boost": 1.0, "spell": 0.72, "tame": 0.8, "beam": 0.07,
		"pool": [Color("ffb860"), 2.6], "earth": 1.0, "earth_gain": 3.0, "earth_tint": Color(1.0, 0.86, 0.66),
		"gold": 0.55, "punch": 1.16},
	"forest_night": {"sun": Color("9fb6ff"), "sun_energy": 1.25, "ambient": Color("38487a"), "ambient_energy": 0.30,
		"fog": Color("6a84c0"), "fog_density": 0.012, "fog_sun": 0.4, "exposure": 1.35,
		"sky_top": Color("03060f"), "sky_low": Color("0f1a33"), "clouds": Color("1b2440"), "stars": 1.0, "sky_glow": Vector3(0.28, 0.14, -0.95),
		"wet": 0.3, "top_rim": [0.55, Color("a8c4ff")], "fire_boost": 2.6, "spell": 1.0, "tame": 0.0, "beam": 0.0,
		"pool": [Color("a8bcff"), 3.6], "earth": 1.0, "earth_gain": 4.6, "earth_tint": Color(0.86, 0.9, 1.0),
		"gold": 0.0, "punch": 1.08},
	"desert": {"sun": Color("ffe0b0"), "sun_energy": 1.7, "ambient": Color("a89cb4"), "ambient_energy": 0.26,
		"fog": Color("ffe4c0"), "fog_density": 0.006, "fog_sun": 0.6, "fog_aniso": 0.2, "exposure": 1.45,
		"sky_top": Color("6a8ac4"), "sky_low": Color("ffd8a0"), "clouds": Color("fff0dc"), "stars": 0.0,
		"wet": 0.0, "top_rim": [0.3, Color("fff4dc")], "fire_boost": 1.0, "spell": 0.5, "tame": 0.6, "beam": 0.0,
		"earth": 0.0, "gold": 0.0, "punch": 1.1},
	"rock": {"sun": Color("ffb890"), "sun_energy": 1.2, "ambient": Color("6a4a5a"), "ambient_energy": 0.30,
		"fog": Color("a04a2a"), "fog_density": 0.026, "fog_sun": 0.6, "exposure": 1.3,
		"sky_top": Color("10070a"), "sky_low": Color("4a1a12"), "clouds": Color("3a1a16"), "stars": 0.3,
		"wet": 0.0, "top_rim": [0.45, Color("ffb080")], "fire_boost": 2.4, "spell": 1.0, "tame": 0.0, "beam": 0.0,
		"earth": 0.0, "gold": 0.0},
}
const SPELL_ENERGY := 6.0          ## a spell light at power 1 (the flat look's is 5 + 6 x power, without fog)
const SPELL_FOG := 0.9             ## how much a spell light glows in the air
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
	float lit_side = pow(max(dot(d, normalize(moon_dir)), 0.0), 8.0);
	vec3 cloud = cloud_col * (0.5 + 1.3 * lit_side);
	// the moon (or the sun behind the haze) and its halo
	float m = dot(d, normalize(moon_dir));
	float disc = smoothstep(0.9993, 0.9996, m);
	float halo = pow(max(m, 0.0), 60.0) * 0.5 + pow(max(m, 0.0), 6.0) * 0.18;
	// stars: one in a few cells, twinkling, hidden by the clouds and fading near the horizon
	vec2 sp = d.xz / (h + 1.0) * 220.0;
	vec2 cell = floor(sp);
	float r = hash(cell);
	float star = step(0.978, r) * smoothstep(0.35, 0.0, length(fract(sp) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5));
	star *= (0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0)) * smoothstep(0.0, 0.08, h) * stars * (1.0 - c);
	col += moon_col * (disc * 6.0 + halo) * (1.0 - c * 0.7);
	col = mix(col, cloud, c * smoothstep(-0.02, 0.12, h));
	col += vec3(0.85, 0.9, 1.0) * star * 3.2;
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
uniform sampler2D earth_tex : source_color, filter_nearest, repeat_enable;
uniform float earth = 0.0;
uniform float earth_gain = 3.0;
uniform vec3 earth_tint : source_color = vec3(1.0);
uniform vec4 earth_area = vec4(0.4, -0.2, 12.5, 5.4);    // the trodden clearing: centre x, z and its half sizes
varying float puddle;
float ehash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
// trodden earth and gravel: the pack's dirt tile, each 2-unit cell turned at random, greyed and made
// paler; single art pixels picked out as pebbles (lit on top, shaded on the pixel under them)
vec3 earth_colour(vec2 where) {
	vec2 g = where / 2.0;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = ehash(id);
	if (h > 0.5) { f.x = 1.0 - f.x; }
	if (fract(h * 7.0) > 0.5) { f.y = 1.0 - f.y; }
	vec3 c = texture(earth_tex, f).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.45) * earth_tint * earth_gain;
	vec2 ap = floor(where * 16.0);
	float stone = step(0.9, ehash(ap));
	float under = step(0.9, ehash(ap + vec2(0.0, -1.0))) * (1.0 - stone);
	float grit = ehash(ap * 0.5 + 3.0);
	return c * (1.0 + stone * 0.6 - under * 0.35 + (grit - 0.5) * 0.12);
}
float earth_mask(vec2 where) {
	vec2 wq = floor(where * 16.0) / 16.0;
	vec2 q = (wq - earth_area.xy) / earth_area.zw;
	float n = texture(hh_dapple, wq * 0.13 + vec2(0.2, 0.6)).r;
	float edge = 1.0 - smoothstep(0.55, 1.0, length(q) + (n - 0.5) * 0.6);
	return step(ehash(wq * 16.0 + 7.0) * 0.8 + 0.1, edge) * earth;
}
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec3 c = ground_colour(at);
	if (earth > 0.0) { c = mix(c, earth_colour(at), earth_mask(at)); }
	float n = texture(hh_dapple, at * 0.09 + vec2(0.31, 0.17)).r;
	float m = texture(hh_dapple, at * 0.21 + vec2(0.7, 0.2)).r;
	puddle = smoothstep(0.78 - wet * 0.1, 0.80 - wet * 0.1, n * 0.85 + m * 0.15) * step(0.01, wet);
	float damp = smoothstep(0.45 - wet * 0.25, 0.62 - wet * 0.22, n) * wet;
	ALBEDO = c * (1.0 - 0.25 * damp) * (1.0 - 0.3 * puddle);       // (darker read as holes in the ground)
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
## THE BLOOM HELD OFF THE ONE HIT: a small picture of the screen that the bloom is multiplied by
## (Environment.glow_map). It is white, except a soft dark patch over every fighter a spell is
## landing on, so the blazing column glows all round him but never spreads a pale veil over him.
const GLOW_MAP := Vector2i(96, 48)
var _glow_img: Image
var _glow_tex: ImageTexture
var _held: Array = []              ## {"who": the fighter, "left": seconds, "life": seconds}
var _glow_clear := true
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
		e.set_glow_level(i, [0.0, 0.35, 0.8, 1.0, 0.85, 0.5, 0.3][i])     # (the widest levels low: a veil over everything hides the fighters)
	e.glow_intensity = 0.5
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.0 if num("stars") > 0.5 or num("fire_boost") > 1.5 else 2.2    # (by day only real fire blooms, not white robes in the sun)
	e.glow_hdr_scale = 2.4
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# the air: thin fog that the key light and every spell light really scatter in
	e.fog_enabled = true                    # (plus a little plain distance fog, so the far wood melts)
	e.fog_density = float(s.look.get("mist_density", 0.01)) * 0.25     # (low: far silhouettes stay dark against the sky)
	e.fog_sky_affect = 0.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = num("fog_density")
	e.volumetric_fog_albedo = look["fog"]
	e.volumetric_fog_anisotropy = float(look.get("fog_aniso", 0.6))     # (by day low: looking into a low sun, strong forward scatter is a wall of haze)
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_detail_spread = 1.4
	e.volumetric_fog_ambient_inject = 0.08
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
	# (the moon's glow, or the evening sun's, low in the open sky behind the fighters, left of the
	# middle: the camera looks nearly level and sees only the sky's lowest band)
	mat.set_shader_parameter("moon_dir", (look.get("sky_glow", Vector3(-0.36, 0.13, -0.92)) as Vector3).normalized())
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
	# the pool of light on the fighting ground (see "pool")
	var pool: Array = look.get("pool", [])
	if not pool.is_empty():
		var sp := SpotLight3D.new()
		sp.light_color = pool[0]
		sp.light_energy = float(pool[1])
		sp.spot_range = 17.0
		sp.spot_angle = 36.0
		sp.spot_angle_attenuation = 2.2
		sp.spot_attenuation = 0.0
		sp.light_volumetric_fog_energy = 0.0         # (no lit air between the camera and the fighters)
		sp.shadow_enabled = false
		sp.light_specular = 0.2
		sp.position = Vector3(0.5, 9.5, 3.0)
		s.add_child(sp)
		sp.look_at(Vector3(0.5, 0.0, -0.2), Vector3(0.0, 0.0, -1.0))
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	# the bloom's map (see GLOW_MAP)
	_glow_img = Image.create(GLOW_MAP.x, GLOW_MAP.y, false, Image.FORMAT_L8)
	_glow_img.fill(Color.WHITE)
	_glow_tex = ImageTexture.create_from_image(_glow_img)
	e.glow_map = _glow_tex
	e.glow_map_strength = 1.0
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
	if num("earth") > 0.0:
		mat.set_shader_parameter("earth_tex", Art.tex("hub_dirt"))
		mat.set_shader_parameter("earth", num("earth"))
		mat.set_shader_parameter("earth_gain", num("earth_gain"))
		var et: Color = look.get("earth_tint", Color.WHITE)
		mat.set_shader_parameter("earth_tint", et)
	return mat


## How much of the clearing is trodden earth (0 = none; stage.gd then lays its dark patches).
func earth() -> float:
	return num("earth")


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
## `air` scales how much it glows in the fog (0 for a light in front of a fighter: lit air between him
## and the camera is a veil over him).
func spell_light(at: Vector3, colour: Color, power: float, life: float, air: float = 1.0) -> void:
	var peak := SPELL_ENERGY * (0.6 + 0.5 * power) * num("spell") * 1.15
	# (the ground and the scenery: the full flood; the fighters are left out of this one)
	_one_light(at, colour, power, life, peak * 1.25, air * 0.5, false, ~int(s.FIGHTER_LAYER) & 0xFFFFF)
	# (everybody: a gentler share, so the one hit is lit but keeps his own colours and reads dark
	# against the blaze; the big ones throw shadows)
	_one_light(at, colour, power, life, peak * 0.3, 0.0, power >= 2.0, 0xFFFFF)


func _one_light(at: Vector3, colour: Color, power: float, life: float, peak: float, air: float, shadows: bool, mask: int) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = FxKit.deep(colour, 1.2).linear_to_srgb()
	l.light_energy = 0.0
	l.light_cull_mask = mask
	l.omni_range = 12.0 + 4.0 * power             # (the ground and the whole party are lit by it)
	l.omni_attenuation = 1.2
	l.light_size = 0.4
	l.light_volumetric_fog_energy = SPELL_FOG * (0.6 + 0.4 * power) * num("spell") * air
	l.shadow_enabled = shadows
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.0
	l.shadow_blur = 1.4
	s.add_child(l)
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
	# (deep colour round a small hot heart: a core mixed half with white read cream)
	var hot := FxKit.deep(colour, 1.2).linear_to_srgb().lerp(Color.WHITE, 0.15)
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


# ------------------------------------------------------------------ the blazing spells
## A WHIRL OF LIGHT, sculpted by code: an open cylinder (or funnel) of light, drawn with thin
## torn FILAMENTS that wind round it and climb (ridged noise followed along a spiral, so every strand
## is a long curl, never a net of crossing stripes), over a soft body of light that is hottest at its
## foot, and brightest where the eye looks along its side (like a glass tube of light).
## Its far half stands behind the one hit (that one's own picture hides it); its near half is only
## a thin veil, and where the one hit stands on the screen (`hold`) it is thinned further, so he
## always reads in front of the blaze.
const VORTEX_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 col = vec3(0.4, 0.7, 1.0);          // LINEAR (FxKit.deep): a Vector3 is never turned from sRGB
uniform vec3 hot_col = vec3(1.0, 0.8, 0.5);      // the hottest strands and the foot lean to this
uniform float heat = 3.0;
uniform float alpha = 0.0;
uniform float height = 8.0;
uniform float grow = 1.0;
uniform float twist = 1.4;
uniform float spin = 1.0;
uniform float bands = 6.0;
uniform float sharp = 5.0;
uniform float front = 0.3;
uniform float body_k = 1.0;
uniform vec4 hold = vec4(-1.0);
uniform vec4 hold2 = vec4(-1.0);        // somebody else standing inside the whirl (also kept clear)
uniform vec4 hold3 = vec4(-1.0);        // and a second one
uniform float seed = 0.0;
varying float hy0;
varying vec2 ring;
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
float ridged(vec3 p) {
	float v = 0.0;
	float a = 0.62;
	for (int i = 0; i < 3; i++) {
		float n = 1.0 - abs(noise3(p) * 2.0 - 1.0);
		v += pow(n, sharp) * a;
		p = p * vec3(2.1, 2.1, 1.7) + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	return v;
}
void vertex() {
	hy0 = VERTEX.y / height + 0.5;
	ring = normalize(VERTEX.xz + vec2(1e-5));
}
void fragment() {
	float hy = clamp(hy0, 0.0, 1.0);
	float t = TIME * spin + seed;
	// the spiral: along one strand the angle a stays the same while it climbs
	float a = atan(ring.y, ring.x) + hy * twist * 6.2831853 - t * 2.4;
	float r = bands * 0.3;
	vec3 p = vec3(cos(a) * r, sin(a) * r, hy * 4.2 - TIME * 2.6 + seed);
	float strand = ridged(p);
	// torn into shreds along their length
	float tear = noise3(vec3(cos(a) * r * 0.8, sin(a) * r * 0.8, hy * 11.0 - TIME * 6.0 + seed * 2.0));
	strand *= smoothstep(0.3, 0.6, tear + 0.1);
	float fade = smoothstep(0.0, 0.05, hy) * (1.0 - smoothstep(grow * 0.62, grow * 0.62 + 0.38 * grow + 0.001, hy));
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	edge = 0.35 + 0.65 * edge * edge;
	float k = 1.0;
	if (FRONT_FACING) {
		k = front;
		vec2 sc = SCREEN_UV;
		float inside = smoothstep(hold.x - 0.012, hold.x + 0.006, sc.x) * (1.0 - smoothstep(hold.z - 0.006, hold.z + 0.012, sc.x))
			* smoothstep(hold.y - 0.02, hold.y + 0.01, sc.y) * (1.0 - smoothstep(hold.w - 0.01, hold.w + 0.02, sc.y));
		float inside2 = smoothstep(hold2.x - 0.012, hold2.x + 0.006, sc.x) * (1.0 - smoothstep(hold2.z - 0.006, hold2.z + 0.012, sc.x))
			* smoothstep(hold2.y - 0.02, hold2.y + 0.01, sc.y) * (1.0 - smoothstep(hold2.w - 0.01, hold2.w + 0.02, sc.y));
		float inside3 = smoothstep(hold3.x - 0.012, hold3.x + 0.006, sc.x) * (1.0 - smoothstep(hold3.z - 0.006, hold3.z + 0.012, sc.x))
			* smoothstep(hold3.y - 0.02, hold3.y + 0.01, sc.y) * (1.0 - smoothstep(hold3.w - 0.01, hold3.w + 0.02, sc.y));
		k *= 1.0 - 0.92 * max(inside, max(inside2, inside3));
	}
	// a body of light under the strands, hottest at the foot, so it reads as a volume
	float body = (0.05 + 0.42 * pow(1.0 - hy, 2.6)) * body_k;
	float v = (strand * mix(1.6, 0.7, hy) + body) * edge * fade * k * alpha;
	// (a deep saturated colour: mixed towards white the tone curve made the whole column cream; only
	// the hottest strands and the foot lean to a warm pale)
	vec3 c = mix(col, hot_col, clamp(smoothstep(0.7, 1.1, strand) * 0.3 + pow(1.0 - hy, 7.0) * 0.25, 0.0, 1.0));
	ALBEDO = c * heat;
	ALPHA = clamp(v, 0.0, 1.0);
}
"

## A BOLT of lightning (or a shard of a spell): a jagged line of light built once by code as a
## flat ribbon turned to the camera; hot white along its middle, coloured at its edge. `flick`
## makes it stutter on and off like real lightning.
const BOLT_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(0.5, 0.8, 1.0);
uniform float heat = 4.0;
uniform float alpha = 0.0;
uniform float core_mix = 0.85;          // how white its middle burns (lightning: nearly white; shards less)
void fragment() {
	float across = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float core = pow(across, 5.0);
	float v = (pow(across, 1.6) * 0.75 + core) * alpha * (1.0 - smoothstep(0.75, 1.0, UV.y) * 0.8);
	ALBEDO = mix(col, vec3(1.0), core * core_mix) * heat;
	ALPHA = clamp(v, 0.0, 1.0);
}
"

## A SPARK that is a crisp streak of light along the way it flies (the particle's Y axis follows its
## speed: CPUParticles3D `particle_flag_align_y`), turned flat to the camera. Hot white middle,
## coloured edge, a tapering tail.
const STREAK_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(0.5, 0.8, 1.0);
uniform float heat = 4.0;
uniform vec4 hold = vec4(-1.0);         // the one hit, on the screen (0..1): no spark crosses in front of him
uniform float hold_z = -1000.0;         // ... and how far from the camera his feet are (world z)
varying float fade;
varying float near_z;
void vertex() {
	vec3 mid = MODEL_MATRIX[3].xyz;
	near_z = mid.z;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = length(axis);
	fade = COLOR.a;
	axis = axis / max(len, 1e-4);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - mid);
	vec3 side = cross(axis, to_cam);
	side = length(side) < 1e-3 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	float wide = length(MODEL_MATRIX[0].xyz);
	vec3 w = mid + side * VERTEX.x * wide + axis * VERTEX.y * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	if (len < 1e-4 || !(fade > 0.0)) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);       // (asleep: drawn nowhere)
	}
}
void fragment() {
	float across = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float along = clamp(1.0 - UV.y, 0.0, 1.0);                 // 1 at the head (the way it flies), 0 at the tail
	float v = pow(across, 2.5) * smoothstep(0.0, 0.7, along) * (1.0 - smoothstep(0.85, 1.0, along)) * fade;
	vec2 sc = SCREEN_UV;
	float inside = step(hold.x, sc.x) * step(sc.x, hold.z) * step(hold.y, sc.y) * step(sc.y, hold.w);
	v *= 1.0 - 0.85 * inside * step(hold_z + 0.15, near_z);
	ALBEDO = mix(col, vec3(1.0, 0.8, 0.55), pow(across, 6.0) * 0.5) * heat;
	ALPHA = clamp(v, 0.0, 1.0);
}
"

static var _vortex_shader: Shader
static var _streak_shader: Shader


func _vortex_mat() -> ShaderMaterial:
	if _vortex_shader == null:
		_vortex_shader = Shader.new()
		_vortex_shader.code = VORTEX_CODE
	var m := ShaderMaterial.new()
	m.shader = _vortex_shader
	m.render_priority = 11
	return m


func _streak_mat(colour: Color, heat: float) -> ShaderMaterial:
	if _streak_shader == null:
		_streak_shader = Shader.new()
		_streak_shader.code = STREAK_CODE
	var m := ShaderMaterial.new()
	m.shader = _streak_shader
	m.set_shader_parameter("col", Vector3(colour.r, colour.g, colour.b))
	m.set_shader_parameter("heat", heat)
	m.render_priority = 12
	return m


## Where a fighter stands on the screen, 0..1 (for a vortex's `hold`). {} = nobody.
func screen_box(fighter: Node3D) -> Vector4:
	if fighter == null or not is_instance_valid(fighter):
		return Vector4(-1.0, -1.0, -1.0, -1.0)
	var cam: Camera3D = s.cam
	var vp: Vector2 = s.get_viewport().get_visible_rect().size
	var h := float(fighter.call("height"))
	var feet := cam.unproject_position(fighter.global_position) / vp
	var head := cam.unproject_position(fighter.global_position + Vector3(0.0, h, 0.0)) / vp
	var half := (feet.y - head.y) * 0.42 * (vp.y / vp.x)
	var mesh := (fighter as MeshInstance3D).mesh as QuadMesh
	if mesh != null:
		half = maxf(half, (cam.unproject_position(fighter.global_position + Vector3(mesh.size.x * 0.5, 0.0, 0.0)) / vp - feet).x)
	return Vector4(feet.x - half, head.y - 0.01, feet.x + half, feet.y + 0.01)


## THE BIG SPELL: a whirl of light that climbs round the one hit and blazes: an inner column and a
## wider funnel of winding streaks (VORTEX_CODE), crisp sparks spiralling up it and spraying from its
## foot (STREAK_CODE), a real light, and a pool of light on the ground. `at` = the feet of the one
## hit, `radius` about his half width, `fighter` his picture (held under the bloom, rimmed).
## `style`: "storm" = bolts of lightning out of the sky into it; "" = shards of light flung up round it.
func vortex(at: Vector3, colour: Color, power: float, height: float, radius: float, fighter: Node3D = null, life: float = 1.15, style: String = "") -> void:
	var hold := screen_box(fighter)
	# (the two nearest others inside the whirl's reach keep their shapes too)
	var others: Array = []
	for p: Node3D in s._people:
		if is_instance_valid(p) and p != fighter and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < maxf(radius * 4.6, 4.2):
			others.append(p)
	others.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	var hold2 := screen_box(others[0]) if others.size() > 0 else Vector4(-1.0, -1.0, -1.0, -1.0)
	var hold3 := screen_box(others[1]) if others.size() > 1 else Vector4(-1.0, -1.0, -1.0, -1.0)
	# (deep, saturated LINEAR colour (FxKit.deep): the tone curve turns hot light pale by itself; an
	# sRGB colour given as a Vector3 made the firebolt a cream-gold column)
	var hot := FxKit.deep(colour, 1.25)
	var hot_tip := FxKit.deep(colour.lerp(Color.WHITE, 0.55), 1.0)
	var layers := [
		# [bottom radius, top radius, height share, strands round, turns, spin, thinness, heat, near half, body]
		[radius * 0.45, radius * 0.6, 1.0, 5.0, 0.6, 0.7, 2.0, 3.4, 0.2, 0.8],
		[radius * 0.8, radius * 1.2, 1.0, 7.0, 1.3, 0.9, 4.0, 2.9, 0.25, 0.45],
		[radius * 1.05, radius * 2.2, 0.9, 11.0, -0.8, -1.3, 8.0, 2.5, 0.1, 0.25],
		[radius * 1.4, radius * 3.0, 0.62, 15.0, 0.5, 1.8, 11.0, 2.0, 0.06, 0.1],
		# (a wide low skirt of torn light: the blaze fills the frame round the one hit)
		[radius * 1.9, radius * 4.2, 0.34, 18.0, -0.4, -2.2, 12.0, 1.6, 0.03, 0.06],
	]
	for i in layers.size():
		var row: Array = layers[i]
		var hgt := height * float(row[2])
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = float(row[0])
		cyl.top_radius = float(row[1])
		cyl.height = hgt
		cyl.radial_segments = 40
		cyl.rings = 8
		cyl.cap_top = false
		cyl.cap_bottom = false
		var m := _vortex_mat()
		m.set_shader_parameter("col", FxKit.vec(hot))
		m.set_shader_parameter("hot_col", FxKit.vec(hot_tip))
		m.set_shader_parameter("height", hgt)
		m.set_shader_parameter("bands", float(row[3]))
		m.set_shader_parameter("twist", float(row[4]))
		m.set_shader_parameter("spin", float(row[5]))
		m.set_shader_parameter("sharp", float(row[6]))
		m.set_shader_parameter("heat", float(row[7]) * (0.42 + 0.09 * power) * num("spell"))
		m.set_shader_parameter("front", float(row[8]))
		m.set_shader_parameter("body_k", float(row[9]))
		m.set_shader_parameter("hold", hold)
		m.set_shader_parameter("hold2", hold2)
		m.set_shader_parameter("hold3", hold3)
		m.set_shader_parameter("seed", randf() * 10.0)
		m.set_shader_parameter("grow", 0.0)
		var node := MeshInstance3D.new()
		node.mesh = cyl
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = at + Vector3(0.0, hgt * 0.5 + 0.02, 0.0)
		s.add_child(node)
		var tw: Tween = s.create_tween()
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("grow", v), 0.0, 1.0, 0.22 + 0.06 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 0.0, 1.0, 0.08)
		tw.tween_interval(life * 0.3)
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 1.0, 0.0, life * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	# sparks that wind up the whirl, and a spray of them from its foot
	var near: Node3D = others[0] if others.size() > 0 else null
	_streaks(at + Vector3(0.0, 0.2, 0.0), colour, power, height, radius, true, hold, near)
	_streaks(at + Vector3(0.0, 0.3, 0.0), colour, power, height, radius, false, hold, near)
	motes(at, colour, power, height, radius, hold, near)
	motes(at, colour, power * 0.9, height * 1.3, radius * 1.8, hold, near)       # (a second, wider cloud: the glitter all round the blaze)
	if style == "storm":
		# lightning out of the sky into the column, forking as it comes
		for i in 3:
			var top := at + Vector3(randf_range(-3.5, 3.5), height * 1.6, randf_range(-4.0, -2.5))     # (behind: a tall one leans back by the stand-up tilt)
			bolt(top, at + Vector3(randf_range(-0.3, 0.3), 0.05, -1.5), colour.lerp(Color.WHITE, 0.3), randf_range(0.16, 0.26), life * 0.55, i * life * 0.12, 3, 6.0)
	shards(at, colour, height, radius, int(12 + 4 * power), life)
	if fighter != null and is_instance_valid(fighter) and fighter.has_method("spell_hold"):
		fighter.call("spell_hold", colour.lerp(Color.WHITE, 0.4), 1.6, life)
		hold_glow(fighter, life + 0.25)
	# (anybody else standing inside the whirl keeps his own shape too)
	for p: Node3D in s._people:
		if is_instance_valid(p) and p != fighter and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < radius * 4.5:
			hold_glow(p, life + 0.25)


## Crisp streaks of light: `up` = climbing the whirl in a spiral; else a spray out of its foot.
func _streaks(at: Vector3, colour: Color, power: float, height: float, radius: float, up: bool, hold := Vector4(-1.0, -1.0, -1.0, -1.0), near: Node3D = null) -> void:
	var sp := FxKit.Streaks.new()
	var n := int(clampf((120.0 if up else 90.0) * power, 60.0, 380.0))
	sp.centre = at
	if up:
		sp.spin = 15.0
		sp.pull = -1.5
		sp.grav = Vector3(0.0, 2.0, 0.0)
		sp.drag = 0.6
		sp.trail = 0.06
	else:
		sp.spin = 3.0
		sp.pull = 4.0
		sp.grav = Vector3(0.0, -9.0, 0.0)
		sp.drag = 1.4
		sp.trail = 0.05
		sp.floor_y = at.y - 0.25
		sp.bounce = 0.3
	sp.width = 0.075
	sp.max_len = 1.4
	var sm := FxKit.streak_material(5.0 * num("spell") + 1.5, Color(1.0, 0.97, 0.9), 0.9)
	sm.set_shader_parameter("hold", hold)
	sm.set_shader_parameter("hold_z", at.z)
	_hold_near(sm, near)
	sp.start(n, sm)
	var tip := colour.lerp(Color.WHITE, 0.45)
	for i in n:
		var a := randf() * TAU
		var r := radius * (randf_range(0.6, 1.2) if up else randf_range(0.1, 0.6))
		var p := at + Vector3(cos(a) * r, randf() * (0.6 if up else 0.2), sin(a) * r)
		var out := Vector3(cos(a), 0.0, sin(a))
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		var v: Vector3
		if up:
			v = Vector3(0.0, height * randf_range(0.6, 1.3), 0.0) + tangent * randf_range(2.0, 4.0)
		else:
			v = (out * randf_range(0.6, 1.0) + Vector3(0.0, randf_range(0.5, 1.4), 0.0)).normalized() * randf_range(5.0, 11.0 + 2.0 * power)
		sp.add(i, p, v, randf() * (0.5 if up else 0.25), randf_range(0.5, 0.95) if up else randf_range(0.45, 0.9), colour.lerp(tip, randf() * 0.6))
	s.add_child(sp)


static var _bolt_shader: Shader


## A JAGGED BOLT of light from `from` to `to` (lightning out of the sky; a shard of a spell): the
## line is broken by midpoint displacement, built once as a ribbon turned to the camera, and
## flickers on and off for `life` seconds after `delay`. `forks` thinner side bolts branch off it.
func bolt(from: Vector3, to: Vector3, colour: Color, width: float, life: float, delay: float = 0.0, forks: int = 0, heat: float = 5.0, core_mix: float = 0.85) -> void:
	var pts: Array[Vector3] = [from, to]
	var jag := from.distance_to(to) * 0.16
	for level in 5:
		var next: Array[Vector3] = []
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var d := (b - a)
			var side := d.cross(Vector3(0.0, 0.0, 1.0)).normalized()
			if side.length() < 0.5:
				side = Vector3(1.0, 0.0, 0.0)
			next.append(a)
			next.append((a + b) * 0.5 + side * randf_range(-jag, jag) + Vector3(0.0, 0.0, randf_range(-jag, jag) * 0.3))
		next.append(pts[pts.size() - 1])
		pts = next
		jag *= 0.52
	if _bolt_shader == null:
		_bolt_shader = Shader.new()
		_bolt_shader.code = BOLT_CODE
	var m := ShaderMaterial.new()
	m.shader = _bolt_shader
	m.set_shader_parameter("col", Vector3(colour.r, colour.g, colour.b))
	m.set_shader_parameter("heat", heat * num("spell"))
	m.set_shader_parameter("core_mix", core_mix)
	m.set_shader_parameter("alpha", 0.0)
	m.render_priority = 12
	var node := MeshInstance3D.new()
	node.mesh = _ribbon(pts, width)
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(node)
	# lightning stutters: on, nearly off, on again, then dies away
	var tw: Tween = s.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	for v: float in [1.0, 0.25, 1.0, 0.55, 0.9]:
		tw.tween_callback(func() -> void: m.set_shader_parameter("alpha", v))
		tw.tween_interval(life * 0.09)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 0.9, 0.0, life * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
	for f in forks:
		var i0 := randi_range(pts.size() / 5, pts.size() * 3 / 5)
		var start: Vector3 = pts[i0]
		var dir := (to - from).normalized()
		var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-0.3, 0.3)).normalized()
		var reach := from.distance_to(to) * randf_range(0.18, 0.35)
		bolt(start, start + (dir * 0.7 + out * 0.6).normalized() * reach, colour, width * 0.45, life * 0.8, delay + life * 0.05, 0, heat * 0.8)


## A flat strip of triangles along `pts`, `width` wide, turned to face the camera (UV.x across, UV.y
## along; the far end tapers to a point).
func _ribbon(pts: Array[Vector3], width: float) -> ArrayMesh:
	var eye: Vector3 = s.cam.global_position
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in n:
		var p: Vector3 = pts[i]
		var d: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := d.cross((eye - p).normalized()).normalized()
		var w := width * 0.5 * (1.0 - 0.6 * float(i) / float(n - 1))
		left.append(p - side * w)
		right.append(p + side * w)
	for i in n - 1:
		var v0 := float(i) / float(n - 1)
		var v1 := float(i + 1) / float(n - 1)
		for q: Array in [[left[i], 0.0, v0], [right[i], 1.0, v0], [right[i + 1], 1.0, v1], [left[i], 0.0, v0], [right[i + 1], 1.0, v1], [left[i + 1], 0.0, v1]]:
			st.set_uv(Vector2(float(q[1]), float(q[2])))
			st.add_vertex(q[0])
	return st.commit()


## SHARDS: short jagged slivers of light flung up round a column as it blazes (the torn edges of
## the spell in the night-battle picture), each lit for a moment, one after another.
func shards(at: Vector3, colour: Color, height: float, radius: float, count: int, life: float) -> void:
	for i in count:
		var a := randf() * TAU
		var r := radius * randf_range(0.9, 1.8)
		var base := at + Vector3(cos(a) * r, randf_range(0.3, height * 0.45), -absf(sin(a)) * r * 0.6 - 0.5)     # (behind him: never across his face)
		var len := randf_range(0.9, 2.2)
		var tip := base + Vector3(randf_range(-0.5, 0.5) + cos(a) * 0.4, len, 0.0)
		bolt(base, tip, FxKit.deep(colour, 1.1).linear_to_srgb(), randf_range(0.07, 0.13), life * randf_range(0.35, 0.6), randf() * life * 0.45, 0, 2.6, 0.3)


## MOTES: a cloud of small hot specks that hang round a spell and drift up slowly after it has
## blazed (the glittering dots all round the column in the night-battle picture).
## A neighbour kept clear of a spark system's streaks (see FxKit STREAK_CODE hold2).
func _hold_near(sm: ShaderMaterial, near: Node3D) -> void:
	if near != null and is_instance_valid(near):
		sm.set_shader_parameter("hold2", screen_box(near))
		sm.set_shader_parameter("hold2_z", near.global_position.z)


func motes(at: Vector3, colour: Color, power: float, height: float, radius: float, hold := Vector4(-1.0, -1.0, -1.0, -1.0), near: Node3D = null) -> void:
	var sp := FxKit.Streaks.new()
	var n := int(clampf(120.0 * power, 80.0, 340.0))
	sp.centre = at
	sp.grav = Vector3(0.0, 0.5, 0.0)
	sp.drag = 1.1
	sp.trail = 0.05
	sp.width = 0.065
	sp.min_len = 0.08
	sp.max_len = 0.45
	sp.wobble = 1.2
	sp.flicker = 0.35
	var sm := FxKit.streak_material(5.0 * num("spell") + 1.5, Color(1.0, 0.97, 0.9), 0.9)
	sm.set_shader_parameter("hold", hold)
	sm.set_shader_parameter("hold_z", at.z)
	_hold_near(sm, near)
	sp.start(n, sm)
	var tip := colour.lerp(Color.WHITE, 0.5)
	var mid := at + Vector3(0.0, height * 0.3, 0.0)
	for i in n:
		var d := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if d.length() > 1.0:
			d = d.normalized() * randf()
		var p := mid + Vector3(d.x * radius * 3.4, d.y * height * 0.45, d.z * radius * 1.8)
		var v := Vector3(randf_range(-0.6, 0.6), randf_range(0.4, 2.6), randf_range(-0.4, 0.4))
		sp.add(i, p, v, randf() * 0.25, randf_range(0.9, 1.9), colour.lerp(tip, randf()))
	s.add_child(sp)


## THE HD SCENERY. The camera looks nearly level, so the picture reads in bands, front to back,
## like the night-battle picture the owner sent: the lit clearing; a foot of bushes and stones;
## tall wood on both WINGS that frames the stage; lone trees and stones on the open ground in the
## middle distance; a low dark treeline far off; and over it all the SKY (clouds, stars and the moon's
## glow by night, a warm evening sky by day). The middle stays open, so a spell's column of light
## stands against the sky. All pieces are the place's own pack art (stage.gd LOOKS lists).
func scenery(rng: RandomNumberGenerator) -> void:
	# 1. the foot of the clearing: bushes and stones, the middle left open (the fire stands there)
	for i in 30:
		var bx := rng.randf_range(-18.0, 18.0)
		var bz := rng.randf_range(-8.5, -4.8)
		if absf(bx - 0.5) < 3.4:
			continue
		s.prop(s._pick("bushes" if rng.randf() < 0.65 else "rocks"), Vector3(bx, 0.0, bz), rng.randf() < 0.5, 0.012)
	for side: float in [-1.0, 1.0]:
		for i in 6:
			s.prop(s._pick("bushes" if i % 3 != 2 else "rocks"), Vector3(side * rng.randf_range(10.5, 16.0), 0.0, rng.randf_range(-4.0, 3.0)), rng.randf() < 0.5, 0.012)
	# 2. ledges: stones heaped at both sides of the middle distance (a rock shelf, as in the picture)
	for side: float in [-1.0, 1.0]:
		var cx := side * rng.randf_range(8.0, 10.5)
		var cz := rng.randf_range(-11.0, -9.0)
		for k in 5:
			s.prop(s._pick("rocks"), Vector3(cx + rng.randf_range(-2.2, 2.2), 0.0, cz + rng.randf_range(-0.8, 0.8)), rng.randf() < 0.5, 0.0, k < 2)
	# 3. the wings: tall wood left and right, nearest first; the near ones throw their shadows
	for side: float in [-1.0, 1.0]:
		var z := -7.5
		while z > -30.0:
			var x := side * (rng.randf_range(11.5, 14.0) + (-z - 7.5) * 0.35)
			var kind := "trees" if z > -11.0 else "big_trees"
			s.prop(s._pick(kind), Vector3(x, 0.0, z), rng.randf() < 0.5, 0.05, z > -12.0)
			# a second, deeper tree further out, so the wing is a wood and not a fence
			s.prop(s._pick("big_trees"), Vector3(x + side * rng.randf_range(4.0, 8.0), 0.0, z - rng.randf_range(1.0, 3.0)), rng.randf() < 0.5, 0.06, false)
			z -= rng.randf_range(2.6, 4.2)
	# 4. the middle distance: a few lone small trees, bushes and stones; low, so the sky shows over them
	for i in 12:
		var x := rng.randf_range(-11.0, 11.0)
		var z := rng.randf_range(-13.0, -26.0)
		var pick := "small_trees" if rng.randf() < 0.35 else ("bushes" if rng.randf() < 0.6 else "rocks")
		s.prop(s._pick(pick), Vector3(x, 0.0, z), rng.randf() < 0.5, 0.03, false)
	# 5. the far treeline: a dense band of the small trees on the low rise, all the way across, low
	# enough that the sky stays open over it
	var fx := -75.0
	while fx < 75.0:
		s.prop(s._pick("small_trees"), Vector3(fx, 0.0, rng.randf_range(-40.0, -52.0)), rng.randf() < 0.5, 0.02, false)
		fx += rng.randf_range(1.8, 3.4)


## Keep the bloom off `fighter` for `seconds` (it comes back over the last third).
func hold_glow(fighter: Node3D, seconds: float) -> void:
	if fighter == null or _glow_img == null:
		return
	for h: Dictionary in _held:
		if h["who"] == fighter:
			h["left"] = maxf(float(h["left"]), seconds)
			h["life"] = maxf(float(h["life"]), seconds)
			return
	_held.append({"who": fighter, "left": seconds, "life": seconds})
	_sync_glow(0.0)              # (at once: a frame of bloom over him is a white flash)


## Every frame: redraw the bloom's map round every fighter it is held off.
func _sync_glow(delta: float) -> void:
	if _glow_img == null or (_held.is_empty() and _glow_clear):
		return
	_glow_img.fill(Color.WHITE)
	var keep: Array = []
	for h: Dictionary in _held:
		h["left"] = float(h["left"]) - delta
		var who: Node3D = h["who"]
		if float(h["left"]) <= 0.0 or not is_instance_valid(who) or not who.is_visible_in_tree():
			continue
		keep.append(h)
		var k := clampf(float(h["left"]) / (float(h["life"]) * 0.35), 0.0, 1.0)     # (how much is held now)
		var box := screen_box(who)
		if box.x < 0.0:
			continue
		# a soft rounded patch a little bigger than the fighter: nearly no bloom inside
		var cx := (box.x + box.z) * 0.5 * GLOW_MAP.x
		var cy := (box.y + box.w) * 0.5 * GLOW_MAP.y
		var rx := maxf((box.z - box.x) * 0.5 * GLOW_MAP.x, 1.0) + 1.5
		var ry := maxf((box.w - box.y) * 0.5 * GLOW_MAP.y, 1.0) + 1.5
		for y in range(maxi(int(cy - ry - 2.0), 0), mini(int(cy + ry + 3.0), GLOW_MAP.y)):
			for x in range(maxi(int(cx - rx - 2.0), 0), mini(int(cx + rx + 3.0), GLOW_MAP.x)):
				var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length()
				var dark := (1.0 - smoothstep(0.75, 1.25, d)) * 0.9 * k
				var was := _glow_img.get_pixel(x, y).r
				_glow_img.set_pixel(x, y, Color(minf(was, 1.0 - dark), 0.0, 0.0))
	_held = keep
	_glow_clear = keep.is_empty()
	_glow_tex.update(_glow_img)


## Every frame: the depth of field. Sharp from a little in front of the nearest fighter to a little
## behind the farthest (feet and head of every one on screen); blur grows only past that.
func focus(delta: float, people: Array) -> void:
	_sync_glow(delta)
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
