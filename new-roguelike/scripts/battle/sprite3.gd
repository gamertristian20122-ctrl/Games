extends MeshInstance3D
## A pixel sprite standing in the 3D battle stage (the "pixel people in a lit 3D world" look).
## It is a flat picture that faces the camera, takes the colour of every light near it, lies in
## the shadow of things and throws a shadow of its own shape. The art is the same pack art as
## everywhere else (Art.frames / Art.tex by id); nothing is drawn here.
##   Sprite3.make("pc_knight")                    stands on its feet at the node's position
##   Sprite3.make("hub_patch_0", "idle", true)    lies flat on the ground (trodden earth, flowers)
## One world unit is 16 art pixels (one floor tile).

const Hd = preload("res://scripts/fx/hd.gd")
const PX := 1.0 / 16.0

## PATCHES OF SUN (the owner's reference picture, 12 Nov 2026: golden light falling through
## leaves, deep warm shade between). Every lit shader of the 3D look includes this: the sky
## light is not even, it comes in soft patches that drift slowly, with one pool of light round
## the spot the camera looks at. Lamps and fires are not touched by it. The settings are the
## same for every shader (global shader uniforms, set with set_sun() below):
##   hh_dapple      a soft cloud picture (made by code: light, not art)
##   hh_dapple_set  x = how big the patches are (1 / world units), y = how strong (0 = even light),
##                  z, w = how far the patches have drifted
##   hh_pool        x, y = the middle of the pool of light (world x, z), z = its radius, w = strength
const SUN_PART := "
global uniform sampler2D hh_dapple : filter_linear, repeat_enable;
global uniform vec4 hh_dapple_set;
global uniform vec4 hh_pool;
varying float sun_share;
float sun_at(vec2 where) {
	float n = texture(hh_dapple, where * hh_dapple_set.x + hh_dapple_set.zw).r;
	float patch = smoothstep(0.2, 0.7, n);
	float pool = (1.0 - smoothstep(hh_pool.z * 0.35, hh_pool.z, distance(where, hh_pool.xy))) * hh_pool.w;
	return mix(1.0, mix(0.62, 1.14, clamp(max(patch * 0.9, pool), 0.0, 1.0)), hh_dapple_set.y);
}
"

const CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + SUN_PART + "
varying vec3 world_at;
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform float flip = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform vec3 flash_col : source_color = vec3(1.0);   // the colour of a hit flash (white; gold on a crit, red on a wind-up)
uniform float flash_glow = 0.0;                 // how much the flash shines by itself (reads in the dark)
uniform float dissolve = 0.0;                   // 0 = whole .. 1 = gone: the picture burns away pixel by pixel
uniform vec3 dissolve_col : source_color = vec3(1.0, 0.55, 0.2);
uniform float shine = 0.0;
uniform float sway = 0.0;
uniform float rim = 0.0;                        // a thin edge of light on the side the key light comes from
uniform vec3 rim_col : source_color = vec3(1.0, 0.85, 0.6);
uniform float rim_side = -1.0;                  // -1 = the light is on the screen's left, 1 = right
varying float top;
void vertex() {
	top = 1.0 - UV.y;
	// leaves move a little in the wind: only the top of the picture, never the feet
	VERTEX.x += sin(TIME * 0.9 + MODEL_MATRIX[3].x * 1.7) * sway * top * top;
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) { uv.x = 1.0 - uv.x; }
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) { discard; }
	float burn_edge = 0.0;
	if (dissolve > 0.0) {
		// one random number per ART pixel (the burn keeps the pixel grid), the top a little first
		vec2 texel = floor(uv * vec2(textureSize(tex, 0)));
		float h = fract(sin(dot(texel, vec2(12.9898, 78.233))) * 43758.5453);
		float d = h * 0.7 + uv.y * 0.3;
		if (d < dissolve * 1.08) { discard; }
		burn_edge = 1.0 - smoothstep(0.0, 0.09, d - dissolve * 1.08);
	}
	ALBEDO = mix(c.rgb * tint, vec3(1.0), flash);
	ALBEDO *= mix(vec3(1.0), flash_col, flash);
	EMISSION = c.rgb * shine;
	EMISSION += flash_col * flash * flash_glow + dissolve_col * burn_edge * 2.5;
	if (rim > 0.0) {
		// RIM LIGHT: the pack draws a dark one-pixel outline, so the lit edge is the first pixel
		// INSIDE it: its neighbour towards the light (above, or the light's side) is outline and the
		// one past that is empty air. Code light only: the art is not changed.
		vec2 tx = 1.0 / vec2(textureSize(tex, 0));
		float sx = flip > 0.5 ? -rim_side : rim_side;
		vec2 dx = vec2(sx * tx.x, 0.0);
		vec2 dy = vec2(0.0, -tx.y);
		float side = step(0.5, texture(tex, uv + dx).a) * (1.0 - step(0.5, texture(tex, uv + dx * 2.0).a));
		float up = step(0.5, texture(tex, uv + dy).a) * (1.0 - step(0.5, texture(tex, uv + dy * 2.0).a));
		float edge = clamp(side + up * 0.6, 0.0, 1.0);
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		EMISSION += rim_col * rim * edge * smoothstep(0.08, 0.3, lum) * (0.6 + 0.6 * lum);
	}
	ROUGHNESS = 1.0;
	sun_share = sun_at(world_at.xz);
}
void light() {
	// a flat picture has no round sides: every light simply colours it by how near it is.
	// Lamps are turned down for pictures: the ground only catches them at a slant.
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 0.35);
}
"

## HD (Forward+ on PC, scripts/fx/hd.gd): the same picture, built from the same parts, but
##  - it THROWS a real shadow (sun / moon and spell lights' shadow maps; the flat copy is not drawn)
##    and lies in the real shadows of trees and fighters. In the shadow pass it is pushed a little
##    away from the light (`shadow_push`), so a picture never shades its own face;
##  - FIGHTER pictures (everything made with make(): fighters, hands, the sword, the fire) are
##    never in the fog, get a little more contrast and light, and a second, COOL rim along the top
##    edge (the moon / sky behind them) besides the warm key rim. So a fighter at the back of the
##    line "comes forward" and reads at a glance (the owner: "bring the characters forward");
##  - the sun counts `sun_face` (0.72) on a standing picture: the ground catches it at a slant, a
##    picture facing the camera would otherwise burn brighter than the sand it stands on;
##  - on a FIGHTER a lamp's or a spell's light is soft-clipped, so a spell that lands right on
##    somebody lights them up hot but never burns them into a white shape.
static func hd_code(fighter: bool) -> String:
	var c := CODE
	c = c.replace("render_mode cull_disabled, specular_disabled;", "render_mode cull_disabled, specular_disabled" + (", fog_disabled" if fighter else "") + ";" + ("\n#define FIGHTER" if fighter else ""))
	c = c.replace("varying float top;", "varying float top;\nuniform float shadow_push = 0.15;\nuniform float pop = 1.12;\nuniform float boost = 1.14;\nuniform float sun_face = 0.72;\nuniform float tame = 0.0;\nuniform float top_rim = 0.0;\nuniform vec3 top_rim_col : source_color = vec3(0.6, 0.75, 1.0);\nuniform float hold = 0.0;\nuniform float spell_rim = 0.0;\nuniform vec3 spell_rim_col : source_color = vec3(0.6, 0.8, 1.0);")
	c = c.replace("\tworld_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n}", "\tif (IN_SHADOW_PASS) {\n\t\tvec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\t\tvec3 away = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(w - INV_VIEW_MATRIX[3].xyz);\n\t\tw += normalize(away) * shadow_push * (1.0 - UV.y);\n\t\tVERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;\n\t}\n\tworld_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n}")
	c = c.replace("\tALBEDO = mix(c.rgb * tint, vec3(1.0), flash);", "#ifdef FIGHTER\n\tc.rgb = max((c.rgb - 0.16) * pop + 0.16, vec3(0.0));\n\tc.rgb *= 1.0 / (1.0 + tame * max(dot(c.rgb, vec3(0.333)) - 0.6, 0.0) * 1.5);\n\tc.rgb = pow(c.rgb, vec3(1.0 + 0.7 * hold)) * (1.0 - 0.15 * hold);\n#endif\n\tALBEDO = mix(c.rgb * tint, vec3(1.0), flash);")
	c = c.replace("\tROUGHNESS = 1.0;\n\tsun_share", "#ifdef FIGHTER\n\tif (top_rim > 0.0) {\n\t\tvec2 ty = vec2(0.0, 1.0 / float(textureSize(tex, 0).y));\n\t\tfloat open_up = 1.0 - step(0.5, texture(tex, uv - ty).a);\n\t\tfloat open_up2 = 1.0 - step(0.5, texture(tex, uv - ty * 2.0).a);\n\t\tEMISSION += top_rim_col * top_rim * (1.0 - open_up) * open_up2 * smoothstep(0.25, 0.6, top);\n\t}\n\tif (spell_rim > 0.0) {\n\t\tvec2 tq = 1.0 / vec2(textureSize(tex, 0));\n\t\tfloat o1 = step(0.5, texture(tex, uv + vec2(tq.x, 0.0)).a) * step(0.5, texture(tex, uv - vec2(tq.x, 0.0)).a) * step(0.5, texture(tex, uv + vec2(0.0, tq.y)).a) * step(0.5, texture(tex, uv - vec2(0.0, tq.y)).a);\n\t\tvec2 t2 = tq * 2.0;\n\t\tfloat o2 = step(0.5, texture(tex, uv + vec2(t2.x, 0.0)).a) * step(0.5, texture(tex, uv - vec2(t2.x, 0.0)).a) * step(0.5, texture(tex, uv - vec2(0.0, t2.y)).a);\n\t\tfloat ink = clamp(spell_rim * o1 * (1.0 - o2) * 0.5, 0.0, 0.9);\n\t\tALBEDO = mix(ALBEDO, vec3(0.05, 0.04, 0.08), ink);\n\t\tEMISSION *= 1.0 - ink;\n\t}\n#endif\n\tROUGHNESS = 1.0;\n\tsun_share")
	c = c.replace("\tDIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 0.35);", "\tvec3 add = ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share * sun_face : 0.35);\n#ifdef FIGHTER\n\tadd *= boost;\n\tif (!LIGHT_IS_DIRECTIONAL) { add = add / (1.0 + dot(add, vec3(0.333)) * (1.3 + hold * 2.5)); add = mix(add, vec3(dot(add, vec3(0.333))), 0.25); }\n#endif\n\tDIFFUSE_LIGHT += add;")
	return c


static var _shader: Shader
static var _hd_shaders := {}          ## HD: false = scenery, true = fighter (see hd_code)
## The camera looks DOWN at the stage, which makes anything standing look shorter than it was
## drawn ("the characters look squished", the owner, 12 Nov 2026). Standing pictures are drawn
## this much taller so that on the screen they keep the shape the artist gave them
## (1 / cosine of the camera's slant; stage.gd sets it when it places the camera).
static var tall := 1.0
static var _sun_ready := false
static var _dapple: ImageTexture
## HD walking places: where the people are on the screen (see set_people)
const MAX_PEOPLE := 16
static var _people_img: Image
static var _people_tex: ImageTexture

var frames: SpriteFrames
var anim := "idle"
var sprite_id := ""
var flat := false
var _i := 0
var _t := 0.0
var _mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
var _offset := Vector2.ZERO
var _size := Vector2.ZERO


## Makes the global settings of SUN_PART exist (once, before any shader that uses them).
static func ensure_sun() -> void:
	if _sun_ready:
		return
	_sun_ready = true
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 2
	noise.seed = 20261112
	_dapple = ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	RenderingServer.global_shader_parameter_add(&"hh_dapple", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, _dapple)
	RenderingServer.global_shader_parameter_add(&"hh_dapple_set", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.03, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_add(&"hh_pool", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 10.0, 0.0))
	# how lit the lamps of a walking place are (HD lamp glass: dim by day, full after dusk)
	RenderingServer.global_shader_parameter_add(&"hh_lamp_on", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	_people_img = Image.create(MAX_PEOPLE, 2, false, Image.FORMAT_RGBAF)
	_people_tex = ImageTexture.create_from_image(_people_img)
	RenderingServer.global_shader_parameter_add(&"hh_people", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, _people_tex)
	RenderingServer.global_shader_parameter_add(&"hh_people_n", RenderingServer.GLOBAL_VAR_TYPE_INT, 0)


## PEOPLE COME FIRST (HD walking places, scripts/fx/card_shader.gd): `rows` = one per person in
## view, [Rect2 on the screen (0..1), view distance of the feet, view distance of the head]. A
## standing picture that is nearer the camera than somebody and covers them there is drawn thinned
## out (screen-door), so nobody is ever hidden behind a flower, a stall or a lamp.
static func set_people(rows: Array) -> void:
	ensure_sun()
	var n := mini(rows.size(), MAX_PEOPLE)
	for i in n:
		var r: Rect2 = rows[i][0]
		_people_img.set_pixel(i, 0, Color(r.position.x, r.position.y, r.end.x, r.end.y))
		_people_img.set_pixel(i, 1, Color(float(rows[i][1]), float(rows[i][2]), 0.0, 0.0))
	_people_tex.update(_people_img)
	RenderingServer.global_shader_parameter_set(&"hh_people_n", n)


## Sets the patches of sun for everything on screen. strength 0 = even light (night, indoors).
##   patch   how big one patch is, in world units        drift   how far they have moved (grows slowly)
##   pool_at the spot the camera looks at (world x, z)   pool_radius, pool_strength   the pool of light there
static func set_sun(strength: float, patch: float, drift: Vector2, pool_at: Vector2, pool_radius: float, pool_strength: float) -> void:
	ensure_sun()
	RenderingServer.global_shader_parameter_set(&"hh_dapple_set", Vector4(1.0 / maxf(patch, 0.1) / 2.0, strength, drift.x, drift.y))
	RenderingServer.global_shader_parameter_set(&"hh_pool", Vector4(pool_at.x, pool_at.y, pool_radius, pool_strength))


static func shader(fighter: bool = false) -> Shader:
	ensure_sun()
	if Hd.on():
		if not _hd_shaders.has(fighter):
			var sh := Shader.new()
			sh.code = hd_code(fighter)
			_hd_shaders[fighter] = sh
		return _hd_shaders[fighter]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	return _shader


static func make(id: String, play_anim: String = "idle", lie_flat: bool = false) -> MeshInstance3D:
	var s: MeshInstance3D = load("res://scripts/battle/sprite3.gd").new()
	s.setup(id, play_anim, lie_flat)
	return s


func setup(id: String, play_anim: String, lie_flat: bool) -> void:
	sprite_id = id
	flat = lie_flat
	_mat = ShaderMaterial.new()
	_mat.shader = shader(true)
	mesh = QuadMesh.new()
	material_override = _mat
	_offset = Art.feet_offset(id)
	frames = Art.frames(id)
	anim = play_anim
	if frames != null and not frames.has_animation(anim):
		anim = "idle"
	if flat:
		rotation.x = -PI / 2.0
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show(frames.get_frame_texture(anim, 0) if frames != null else Art.tex(id))
	set_process(frames != null and frames.get_frame_count(anim) > 1)


func play(name: String) -> void:
	if frames == null or not frames.has_animation(name):
		return
	anim = name
	_i = 0
	_t = 0.0
	_show(frames.get_frame_texture(anim, 0))
	set_process(frames.get_frame_count(anim) > 1)


func set_flip(on: bool) -> void:
	_mat.set_shader_parameter("flip", 1.0 if on else 0.0)
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("flip", 1.0 if on else 0.0)
	_place(on)


## Gives the picture a shadow on the ground that follows its animation (the stage hands over
## the material and the lean, see stage.gd).
func add_shadow(mat: ShaderMaterial, lean: Basis) -> void:
	if Hd.on():
		return                    # HD: the picture throws a real shadow instead (cast_shadow)
	_shadow_mat = mat
	_shadow_mat.set_shader_parameter("tex", _mat.get_shader_parameter("tex"))
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.transform = Transform3D(lean, Vector3(0.0, 0.02, 0.0))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func set_tint(c: Color) -> void:
	_mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))


func set_shine(v: float) -> void:
	_mat.set_shader_parameter("shine", v)


func set_sway(v: float) -> void:
	_mat.set_shader_parameter("sway", v)


## A thin edge of coloured light on the side `side` (-1 left, 1 right of the screen).
func set_rim(strength: float, colour: Color, side: float = -1.0) -> void:
	_mat.set_shader_parameter("rim", strength)
	_mat.set_shader_parameter("rim_col", Vector3(colour.r, colour.g, colour.b))
	_mat.set_shader_parameter("rim_side", side)


## HD: a second, cool edge of light along the top of the picture (the sky behind the fighter).
func set_top_rim(strength: float, colour: Color) -> void:
	if Hd.on():
		_mat.set_shader_parameter("top_rim", strength)
		_mat.set_shader_parameter("top_rim_col", Vector3(colour.r, colour.g, colour.b))


## HD: while a spell lands on this fighter: `hold` keeps the spell's light on him under the bloom
## (he is lit, never burnt white), and a thin edge of the spell's colour runs just inside his dark
## outline, so he reads as a crisp shape in front of the blazing column.
func spell_hold(colour: Color, strength: float, seconds: float) -> void:
	if not Hd.on():
		return
	_mat.set_shader_parameter("spell_rim_col", Vector3(colour.r, colour.g, colour.b))
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("hold", v)
		_mat.set_shader_parameter("spell_rim", v * strength), 1.0, 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func set_flash(v: float, colour: Color = Color.WHITE, glow: float = -1.0) -> void:
	_mat.set_shader_parameter("flash", v)
	_mat.set_shader_parameter("flash_col", Vector3(colour.r, colour.g, colour.b))
	# (a flash shines by itself a little, so a hit reads even in deep night shade)
	_mat.set_shader_parameter("flash_glow", glow if glow >= 0.0 else (0.9 if Hd.on() else 0.35))


## Burns the picture away pixel by pixel (0 = whole, 1 = gone) with a glowing edge of `colour`
## (a fallen monster; scripts/battle/anim_death.gd).
func set_dissolve(v: float, colour: Color = Color(1.0, 0.55, 0.2)) -> void:
	_mat.set_shader_parameter("dissolve", v)
	_mat.set_shader_parameter("dissolve_col", Vector3(colour.r, colour.g, colour.b))


## The frame on show now (the picture the death's pixels are taken from).
func texture_now() -> Texture2D:
	return _mat.get_shader_parameter("tex") as Texture2D


func is_flipped() -> bool:
	var f: Variant = _mat.get_shader_parameter("flip")
	return f != null and float(f) > 0.5


## Seconds one play of `name` takes as this picture plays it (0 when it has no such animation).
func anim_length(name: String) -> float:
	if frames == null or not frames.has_animation(name):
		return 0.0
	return float(frames.get_frame_count(name)) / maxf(frames.get_animation_speed(name), 0.01)


## How many frames `name` has, and its frame rate (to time a blow to the pack's own hit frame).
func anim_fps(name: String) -> float:
	if frames == null or not frames.has_animation(name):
		return 10.0
	return frames.get_animation_speed(name)


func height() -> float:
	return _size.y * PX * (1.0 if flat else tall)


func _show(t: Texture2D) -> void:
	_mat.set_shader_parameter("tex", t)
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("tex", t)
	var sz := t.get_size()
	if sz != _size:
		_size = sz
		(mesh as QuadMesh).size = Vector2(sz.x, sz.y * (1.0 if flat else tall)) * PX
		_place(float(_mat.get_shader_parameter("flip") if _mat.get_shader_parameter("flip") != null else 0.0) > 0.5)


## Puts the picture so that the feet point of the art is the node's own position.
func _place(flipped: bool) -> void:
	var cx := (_offset.x + _size.x * 0.5) * PX
	var cy := -(_offset.y + _size.y * 0.5) * PX
	if flipped:
		cx = -cx
	if flat:
		(mesh as QuadMesh).center_offset = Vector3(cx, 0.0, 0.0)
	else:
		(mesh as QuadMesh).center_offset = Vector3(cx, cy * tall, 0.0)


func _ready() -> void:
	set_process(frames != null and frames.get_frame_count(anim) > 1)


func _process(delta: float) -> void:
	var fps := frames.get_animation_speed(anim)
	if fps <= 0.0:
		return
	_t += delta
	var step := 1.0 / fps
	while _t >= step:
		_t -= step
		var n := frames.get_frame_count(anim)
		if _i + 1 >= n and not frames.get_animation_loop(anim):
			set_process(false)
			return
		_i = (_i + 1) % n
		_show(frames.get_frame_texture(anim, _i))
