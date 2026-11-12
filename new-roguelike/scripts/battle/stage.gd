extends Node3D
## The battle stage: a small lit 3D clearing that pixel sprites stand in. This is the new look the
## owner asked for on 12 Nov 2026 ("pixel people in a lit 3D world, soft blur near and far, glow").
## Everything on it is the pack art already in the game (ids hub_* and pc_*), stood up as flat
## pictures; the code only adds LIGHT and EFFECTS: a sky light with real shadows, fire and rune
## lights, mist, drifting sparks, light beams, the blur away from the fighters, a dark rim.
##   var stage := Stage.new();  add_child(stage);  stage.build("forest")
##   stage.stand("pc_knight", Vector3(-3, 0, 0))          a fighter on his feet, facing right
##   stage.stand("pc_elf_base", Vector3(3, 0, 0), true)   facing left
## One world unit is 16 art pixels. x = left / right, z = towards the camera, y = up.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const PX := 1.0 / 16.0
## What the camera looks at. Low, so the fighters stand in the upper half of the screen and the
## menus along the bottom never cover them.
const AIM := Vector3(0.0, -0.9, 0.6)

## One row per place a fight can happen in. Colours are the mood; pieces are pack ids.
const LOOKS := {
	# the woods late in the day: low golden sun, long soft shadows, dust in the light
	"forest": {
		"ground": "hub_grass", "ground_tile": Rect2(0, 0, 48, 48), "ground_tint": Color(1.0, 1.0, 1.0), "grey": 0.18,
		"sky": Color("8a6a34"), "mist": Color("9a7a40"), "mist_density": 0.0045,
		"ambient": Color("a89a9c"), "ambient_energy": 0.42,
		"sun": Color("ffd08a"), "sun_energy": 2.1, "sun_angle": Vector3(-36.0, 138.0, 0.0), "shadow_dark": 0.6, "shadow_rows": 1,
		"glow_bloom": 0.10, "glow_from": 0.95, "lift": 0.0, "haze": Color("ffd9a0"), "beam": 0.10,
		"patches": 1.0, "rim": 0.64,
		"grade": [Vector3(1.11, 1.02, 0.84), Vector3(1.04, 0.90, 0.76), 1.14, 1.08],
		"cool": Color("9ff0d8"),
		"big_trees": ["hub_tree_green_0", "hub_tree_green_1", "hub_tree_teal_0", "hub_tree_teal_1", "hub_tree_green_1", "hub_tree_pink_1"],
		"trees": ["hub_tree_green_2", "hub_tree_teal_2", "hub_tree_green_2", "hub_tree_pink_2"],
		"small_trees": ["hub_tree_green_3", "hub_tree_teal_3", "hub_tree_green_4", "hub_tree_pink_3", "hub_tree_teal_4"],
		"bushes": ["hub_bush_green_0", "hub_bush_deep_0", "hub_bush_green_1", "hub_bush_deep_1", "hub_bush_green_2", "hub_bush_orange_1"],
		"rocks": ["hub_rock_moss_0", "hub_rock_moss_1", "hub_stone_1", "hub_rock_moss_2", "hub_stump_0"],
		"small": ["hub_tuft_0", "hub_tuft_2", "hub_tuft_4", "hub_tuft_6", "hub_tuft_14", "hub_flower_13", "hub_flower_15", "hub_flower_1"],
		"tall": ["hub_plant_0", "hub_plant_2", "hub_plant_3", "hub_plant_5", "hub_plant_1"],
		"flat": ["hub_patch_0", "hub_patch_1"],
		"features": [["hub_rune_0", Vector3(-7.0, 0.0, -4.3), false, 0.3], ["hub_statue_1", Vector3(4.6, 0.0, -4.4), true, 0.0], ["hub_stump_0", Vector3(0.4, 0.0, -3.6), false, 0.0]],
		"spark": Color(1.0, 0.9, 0.6), "spark_power": 0.9,
	},
	# the woods at night: a fire in the old ring, glowing mushrooms, fireflies
	"forest_night": {
		"ground": "hub_grass", "ground_tile": Rect2(0, 0, 48, 48), "ground_tint": Color(1.0, 1.0, 1.0), "grey": 0.3,
		"sky": Color("0a1322"), "mist": Color("1a2c44"), "mist_density": 0.022,
		"ambient": Color("6f86c4"), "ambient_energy": 0.5,
		"sun": Color("b9c8ff"), "sun_energy": 1.1, "sun_angle": Vector3(-50.0, 132.0, 0.0), "shadow_dark": 0.5, "shadow_rows": 2,
		"glow_bloom": 0.12, "glow_from": 0.95, "lift": 0.0, "haze": Color("203050"), "beam": 0.06,
		"fire": Color("ff9440"), "fire_energy": 14.0, "cool": Color("58e8d0"),
		"big_trees": ["hub_tree_green_0", "hub_tree_green_1", "hub_tree_teal_0", "hub_tree_teal_1", "hub_tree_green_1", "hub_tree_pink_1"],
		"trees": ["hub_tree_green_2", "hub_tree_teal_2", "hub_tree_green_2", "hub_tree_pink_2"],
		"small_trees": ["hub_tree_green_3", "hub_tree_teal_3", "hub_tree_green_4", "hub_tree_pink_3", "hub_tree_teal_4"],
		"bushes": ["hub_bush_green_0", "hub_bush_deep_0", "hub_bush_green_1", "hub_bush_deep_1", "hub_bush_green_2", "hub_bush_orange_1"],
		"rocks": ["hub_rock_moss_0", "hub_rock_moss_1", "hub_stone_1", "hub_rock_moss_2", "hub_stump_0"],
		"small": ["hub_tuft_0", "hub_tuft_2", "hub_tuft_4", "hub_tuft_6", "hub_tuft_14", "hub_flower_13", "hub_flower_15", "hub_flower_1"],
		"tall": ["hub_plant_0", "hub_plant_2", "hub_plant_3", "hub_plant_5", "hub_plant_1"],
		"flat": ["hub_patch_0", "hub_patch_1"],
		"features": [["hub_rune_0", Vector3(-7.0, 0.0, -4.3), false, 0.4, Color("58e8d0"), 2.2], ["hub_statue_1", Vector3(4.6, 0.0, -4.4), true, 0.0]],
		"glowers": ["hub_shroom_0", "hub_shroom_1", "hub_shroom_2"],
		"spark": Color(0.85, 1.0, 0.45), "spark_power": 1.6,
	},
	# the sands: a wide warm sky, old stones and thorn
	"desert": {
		"ground": "hub_sand", "ground_tint": Color(1.0, 0.98, 0.94), "grey": 0.05,
		"sky": Color("e0bd8c"), "mist": Color("ddb98a"), "mist_density": 0.004,
		"ambient": Color("b9b4c4"), "ambient_energy": 0.5,
		"sun": Color("ffdca8"), "sun_energy": 1.0, "sun_angle": Vector3(-38.0, 140.0, 0.0), "shadow_dark": 0.62, "shadow_rows": 2,
		"glow_bloom": 0.04, "glow_from": 1.15, "lift": 0.0, "haze": Color("ffd9a0"), "beam": 0.0,
		"patches": 0.45, "rim": 0.66,
		"grade": [Vector3(1.12, 1.02, 0.82), Vector3(1.04, 0.90, 0.76), 1.12, 1.1],
		"cool": Color("ffd28a"),
		"big_trees": ["hub_dstone_0", "hub_obelisk_0", "hub_dtree_0", "hub_dstone_1", "hub_obelisk_1", "hub_dboulder_0"],
		"trees": ["hub_dtree_0", "hub_dstone_0", "hub_cactus_4", "hub_obelisk_2"],
		"small_trees": ["hub_cactus_3", "hub_dtree_1", "hub_cactus_4", "hub_dstone_2", "hub_cactus_2"],
		"bushes": ["hub_dbush_0", "hub_dbush_1", "hub_dbush_2", "hub_dshrub", "hub_cactus_0", "hub_cactus_1"],
		"rocks": ["hub_dboulder_1", "hub_dstone_2", "hub_dstone_1", "hub_dpot_0"],
		"small": ["hub_dgrass_0", "hub_dgrass_1", "hub_dgrass_2", "hub_dgrass_3", "hub_dpebble_0", "hub_dpebble_1", "hub_dblock_2"],
		"tall": ["hub_cactus_5", "hub_dgrass_0", "hub_dbush_2"],
		"flat": [],
		"features": [["hub_tusk_0", Vector3(-6.6, 0.0, -4.2), false, 0.0], ["hub_tusk_1", Vector3(5.4, 0.0, -4.6), true, 0.0], ["hub_dpillar_0", Vector3(0.6, 0.0, -4.4), false, 0.0]],
		"spark": Color(1.0, 0.9, 0.7), "spark_power": 0.6,
	},
	# bare rock under the cinder mountains: dim, with pools of fire
	"rock": {
		"ground": "hub_drock", "ground_tint": Color(0.86, 0.80, 0.80), "grey": 0.2,
		"sky": Color("1c1016"), "mist": Color("3a1c1a"), "mist_density": 0.02,
		"ambient": Color("a08a98"), "ambient_energy": 0.5,
		"sun": Color("ffc8a0"), "sun_energy": 0.7, "sun_angle": Vector3(-48.0, 136.0, 0.0), "shadow_dark": 0.5, "shadow_rows": 2,
		"glow_bloom": 0.12, "glow_from": 0.95, "lift": 0.02, "haze": Color("5a2a1a"), "beam": 0.0,
		"fire": Color("ff7a30"), "fire_energy": 10.0, "cool": Color("ff8840"),
		"big_trees": ["hub_dspire_0", "hub_dspire_1", "hub_dboulder_0", "hub_dspire_1", "hub_dboulder_0"],
		"trees": ["hub_dspire_0", "hub_dboulder_0", "hub_dspire_1"],
		"small_trees": ["hub_dboulder_1", "hub_dspire_0", "hub_dtree_1", "hub_dboulder_0"],
		"bushes": ["hub_dboulder_1", "hub_dbush_1", "hub_dstone_2", "hub_dbush_2"],
		"rocks": ["hub_dboulder_1", "hub_dstone_2"],
		"small": ["hub_dpebble_0", "hub_dpebble_1", "hub_dblock_2", "hub_dblock_3", "hub_dgrass_2"],
		"tall": ["hub_dbush_2", "hub_dtree_1"],
		"flat": [],
		"features": [["hub_fbust", Vector3(-6.4, 0.0, -4.4), false, 0.0], ["hub_fbroken", Vector3(5.2, 0.0, -4.6), true, 0.0]],
		"spark": Color(1.0, 0.55, 0.25), "spark_power": 1.6,
	},
}

var cam: Camera3D
var look := {}
var rng := RandomNumberGenerator.new()
var post: MeshInstance3D
var _fire: OmniLight3D
var _fire_energy := 0.0
var _beams: Array[MeshInstance3D] = []
var _t := 0.0
var _batches := {}
var _beam_alpha := 0.06
var _sun: DirectionalLight3D
var _lean := Vector2.ZERO
var _ground_params := {}
var _shadow_shader: Shader

const POST_CODE := "
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float focus = 18.0;      // how far from the camera the fighters stand
uniform float sharp = 2.2;       // this far either side of them stays crisp
uniform float falloff = 10.0;    // and over this distance the blur grows to full
uniform float blur_px = 8.0;     // full blur, in pixels on a 720-high screen
uniform float rim = 0.55;        // how dark the corners get
uniform vec3 warm = vec3(1.07, 1.0, 0.90);     // what bright things are tinted by
uniform vec3 shade = vec3(0.88, 0.96, 1.12);   // what dark things are tinted by
uniform float punch = 1.0;       // above 1: deeper darks (more contrast)
uniform float rich = 1.0;        // above 1: stronger colours
uniform float lift = 0.0;        // soft light: the darks are lifted a little towards the haze
uniform vec3 haze : source_color = vec3(1.0, 0.85, 0.6);
uniform float show_depth = 0.0;
const int TAPS = 22;

float dist(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
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
	for (int i = 1; i <= TAPS; i++) {
		float r = sqrt(float(i) / float(TAPS));
		float a = float(i) * 2.39996;
		vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * r * r_max * px;
		float zt = dist(uv, INV_PROJECTION_MATRIX);
		float ct = soft(zt);
		if (zt > zc) { ct = min(ct, cc); }      // what is behind never smears over crisp things in front
		float w = smoothstep(r - 0.2, r + 0.05, ct);
		sum += texture(screen_tex, uv).rgb * w;
		n += w;
	}
	vec3 col = sum / n;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = pow(max(col, vec3(0.0)), vec3(punch));
	l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, rich);
	col = mix(col, col * warm, smoothstep(0.25, 0.9, l));          // the tint of the light
	col = mix(col, col * shade, 1.0 - smoothstep(0.0, 0.3, l));    // the tint of the shade
	col = mix(col, haze, lift * (1.0 - l));                                         // soft, hazy shade
	vec2 q = SCREEN_UV - 0.5;
	col *= 1.0 - smoothstep(0.18, 0.62, dot(q, q) * 1.9) * rim;
	if (show_depth > 0.5) { col = vec3(cc); }
	ALBEDO = col;
}
"


## The ground is ONE tile of the pack's ground sheet laid like floor tiles, each turned at random so
## the eye finds no rows. It is drawn a little less green than the art so a fire can warm it.
const GROUND_PART := "
uniform sampler2D ground_tex : source_color, filter_nearest, repeat_disable;
uniform vec3 ground_tint : source_color = vec3(1.0);
uniform vec2 cell = vec2(3.0, 3.0);
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 texel = vec2(0.01, 0.01);
uniform float grey = 0.3;
varying vec2 at;
vec3 ground_colour(vec2 where) {
	vec2 g = where / cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
	if (h > 0.5) { f.x = 1.0 - f.x; }
	if (fract(h * 7.0) > 0.5) { f.y = 1.0 - f.y; }
	vec3 c = texture(ground_tex, region.xy + clamp(f, texel, 1.0 - texel) * region.zw).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(c, vec3(l) * 1.25, grey) * ground_tint;
}
"
const GROUND_CODE := "
shader_type spatial;
render_mode specular_disabled;
" + Sprite3.SUN_PART + GROUND_PART + "
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = ground_colour(at);
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
}
"
## A shadow is the same picture laid flat on the ground, leaning away from the sky light, and
## painted as the ground itself but darker. No shadow maps: a phone draws this for almost
## nothing, and it stays a crisp pixel shape. Two shadows on top of each other do not get darker.
const SHADOW_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + Sprite3.SUN_PART + GROUND_PART + "
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform float flip = 0.0;
uniform float dark = 0.5;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) { uv.x = 1.0 - uv.x; }
	if (texture(tex, uv).a < 0.5) { discard; }
	ALBEDO = ground_colour(at) * dark;
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
}
"


func build(look_name: String = "forest", seed_value: int = 11) -> void:
	look = LOOKS.get(look_name, LOOKS["forest"])
	rng.seed = seed_value
	Sprite3.ensure_sun()
	# patches of sun on the day stages (see sprite3.gd SUN_PART), a pool of light on the fighters
	Sprite3.set_sun(float(look.get("patches", 0.0)), 6.0, Vector2(seed_value * 0.37, seed_value * 0.11), Vector2(0.0, 0.0), 13.0, 1.0)
	_camera()
	_sky_and_light()
	_ground()
	_scenery()
	_flush()
	_sparks()
	_beams_of_light()
	_post()


func _camera() -> void:
	cam = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.3
	cam.far = 140.0
	add_child(cam)
	cam.position = Vector3(0.0, 7.5, 17.0)
	cam.look_at(AIM, Vector3.UP)
	cam.current = true


func _sky_and_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = look["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look["ambient"]
	env.ambient_light_energy = float(look["ambient_energy"])
	env.fog_enabled = true
	env.fog_light_color = look["mist"]
	env.fog_density = float(look["mist_density"])
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = float(look.get("glow_bloom", 0.12))
	env.glow_hdr_threshold = float(look.get("glow_from", 0.95))
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# The sky light. It draws no shadow maps (they cost a second drawing of everything, and on this
	# renderer they went missing as the scene grew): shadows are flat pictures, see SHADOW_CODE.
	_sun = DirectionalLight3D.new()
	_sun.light_color = look["sun"]
	_sun.light_energy = float(look["sun_energy"])
	_sun.rotation_degrees = look["sun_angle"]
	_sun.shadow_enabled = false
	add_child(_sun)


func _ground() -> void:
	var img := Art.tex(String(look["ground"])).get_image()
	if img.is_compressed():
		img.decompress()
	var tile: Rect2 = look.get("ground_tile", Rect2(0, 0, img.get_width(), img.get_height()))
	var c: Color = look["ground_tint"]
	_ground_params = {
		"ground_tex": ImageTexture.create_from_image(img), "ground_tint": Vector3(c.r, c.g, c.b),
		"cell": Vector2(tile.size.x * PX, tile.size.y * PX),
		"region": Vector4(tile.position.x / img.get_width(), tile.position.y / img.get_height(), tile.size.x / img.get_width(), tile.size.y / img.get_height()),
		"texel": Vector2(0.5 / tile.size.x, 0.5 / tile.size.y),
		"grey": float(look.get("grey", 0.3)),
	}
	var sh := Shader.new()
	sh.code = GROUND_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 150.0)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = mat
	m.position = Vector3(0.0, 0.0, -50.0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	# which way a shadow leans on the ground, for every unit of height
	var d := -_sun.global_transform.basis.z
	_lean = (Vector2(d.x, d.z) / maxf(-d.y, 0.2)).limit_length(1.15)
	_shadow_shader = Shader.new()
	_shadow_shader.code = SHADOW_CODE


## The material that paints a picture's shadow (see SHADOW_CODE).
func shadow_material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shadow_shader
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("dark", float(look.get("shadow_dark", 0.5)))
	return mat


## Lays a standing picture down along the shadow's lean.
func shadow_basis() -> Basis:
	return Basis(Vector3(1.0, 0.0, 0.0), Vector3(_lean.x, 0.0, _lean.y), Vector3(0.0, 1.0, 0.0))


## Stands a pack picture on the ground (scenery that never changes). Pictures of the same piece
## are gathered and drawn together in one go (see _flush): a phone cannot afford hundreds of
## separate things, and past a certain count the shadows stop being drawn at all.
##   sway    how much the top moves in the wind       shadow   does it throw one
##   tint    darker or coloured                        shine    how much it glows by itself
func prop(id: String, at: Vector3, flip: bool = false, sway: float = 0.0, shadow: bool = true,
		tint: Color = Color.WHITE, shine: float = 0.0, lie_flat: bool = false, turn: float = 0.0) -> void:
	var key := "%s|%.3f|%s|%s|%.2f|%s" % [id, sway, shadow, tint.to_html(false), shine, lie_flat]
	if not _batches.has(key):
		_batches[key] = {"id": id, "sway": sway, "shadow": shadow, "tint": tint, "shine": shine, "flat": lie_flat, "at": []}
	var basis := Basis.IDENTITY
	if lie_flat:
		basis = Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -PI / 2.0)
	if flip:
		basis = basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	(_batches[key]["at"] as Array).append(Transform3D(basis, at))


## Turns everything prop() gathered into one drawn thing per kind of piece.
func _flush() -> void:
	for key: String in _batches:
		var b: Dictionary = _batches[key]
		var id := String(b["id"])
		var tex := Art.tex(id)
		var size := tex.get_size()
		var off := Art.feet_offset(id)
		var quad := QuadMesh.new()
		quad.size = size * PX
		if bool(b["flat"]):
			quad.center_offset = Vector3((off.x + size.x * 0.5) * PX, 0.0, 0.0)
		else:
			quad.center_offset = Vector3((off.x + size.x * 0.5) * PX, -(off.y + size.y * 0.5) * PX, 0.0)
		var mat := ShaderMaterial.new()
		mat.shader = Sprite3.shader()
		mat.set_shader_parameter("tex", tex)
		var c: Color = b["tint"]
		mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter("shine", float(b["shine"]))
		mat.set_shader_parameter("sway", float(b["sway"]))
		quad.material = mat
		var list: Array = b["at"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		if bool(b["shadow"]) and not bool(b["flat"]):
			var lean := shadow_basis()
			var sq := quad.duplicate() as QuadMesh
			sq.material = shadow_material(tex)
			var sm := MultiMesh.new()
			sm.transform_format = MultiMesh.TRANSFORM_3D
			sm.mesh = sq
			sm.instance_count = list.size()
			for i in list.size():
				var t: Transform3D = list[i]
				sm.set_instance_transform(i, Transform3D(lean * t.basis, t.origin + Vector3(0.0, 0.02, 0.0)))
			var shade := MultiMeshInstance3D.new()
			shade.multimesh = sm
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(shade)
	_batches.clear()


## A fighter on his feet. `faces_left` turns him round. Returns the body picture.
func stand(id: String, at: Vector3, faces_left: bool = false, anim: String = "idle", shadow: bool = true) -> MeshInstance3D:
	var s := Sprite3.make(id, anim)
	s.position = at
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	if shadow:
		s.add_shadow(shadow_material(null), shadow_basis())
	s.set_flip(faces_left)
	return s


## A small light of its own (a fire, a glowing stone). No shadows: they cost too much on a phone.
func lamp(at: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	add_child(l)
	return l


func _pick(key: String) -> String:
	var list: Array = look[key]
	return String(list[rng.randi() % list.size()])


func _scenery() -> void:
	var dim := Color(0.5, 0.56, 0.62)
	var shadow_rows := int(look.get("shadow_rows", 2))
	# what stands behind: small things nearest, the giants further back, thinning into the mist.
	# Only the nearest rows throw shadows: the giants' would cover the whole fighting ground.
	var rows := [[-6.2, "small_trees", 3.4, 0.03], [-9.5, "trees", 5.2, 0.05], [-14.0, "big_trees", 7.0, 0.07],
		[-20.0, "big_trees", 7.5, 0.07], [-27.0, "big_trees", 8.0, 0.07], [-36.0, "big_trees", 9.0, 0.07]]
	for n in rows.size():
		var row: Array = rows[n]
		var z: float = row[0]
		var gap: float = row[2]
		var x := -34.0 + rng.randf() * gap
		while x < 34.0:
			var open := absf(x - 0.5) < 4.2 and z > -8.0          # leave the middle of the first row open
			if not open:
				prop(_pick(String(row[1])), Vector3(x, 0.0, z + rng.randf_range(-0.9, 0.9)), rng.randf() < 0.5, float(row[3]), n < shadow_rows)
			x += gap * rng.randf_range(0.75, 1.3)
	# bushes and stones along the foot of them and down both sides
	for i in 26:
		var bx := rng.randf_range(-17.0, 17.0)
		var bz := rng.randf_range(-7.6, -4.6)
		if absf(bx - 0.5) < 3.2:
			continue
		prop(_pick("bushes" if rng.randf() < 0.7 else "rocks"), Vector3(bx, 0.0, bz), rng.randf() < 0.5, 0.012)
	for side: float in [-1.0, 1.0]:
		for i in 7:
			prop(_pick("bushes" if i % 3 != 2 else "rocks"), Vector3(side * rng.randf_range(10.0, 15.0), 0.0, rng.randf_range(-4.0, 3.5)), rng.randf() < 0.5, 0.012)
	# trodden earth where the fighters stand
	if not (look.get("flat", []) as Array).is_empty():
		for i in 7:
			prop(_pick("flat"), Vector3(rng.randf_range(-7.5, 7.5), 0.012 + i * 0.002, rng.randf_range(-2.6, 2.4)), false, 0.0, false, Color.WHITE, 0.0, true, rng.randf() * TAU)
	# low things anywhere; the tall ones only round the edge, never in front of a fighter
	for i in 110:
		var at := Vector3(rng.randf_range(-15.0, 15.0), 0.0, rng.randf_range(-8.0, 5.0))
		var edge := absf(at.x) > 9.0 or at.z < -3.8
		if edge:
			prop(_pick("small" if rng.randf() < 0.5 else "tall"), at, rng.randf() < 0.5, 0.01, false)
		elif rng.randf() < 0.55:
			prop(_pick("small"), at, rng.randf() < 0.5, 0.01, false)
	# a fire, where the place has one: the old ring in the middle of the back
	if look.has("fire"):
		var fire_at := Vector3(0.6, 0.0, -3.4)
		stand("hub_fire_a", fire_at, false, "idle", false)
		var flame := stand("hub_flame", fire_at + Vector3(0.0, 0.35, 0.03), false, "idle", false)
		flame.set_shine(2.6)
		_fire_energy = float(look["fire_energy"])
		_fire = lamp(fire_at + Vector3(0.0, 1.3, 0.7), look["fire"], _fire_energy, 14.0)
		_embers(fire_at + Vector3(0.0, 1.1, 0.05))
	# the place's own pieces: [id, where, turned round, glow, (light colour, light strength)]
	for f: Array in look.get("features", []):
		prop(String(f[0]), f[1], bool(f[2]), 0.0, true, Color.WHITE, float(f[3]))
		if f.size() > 5:
			lamp((f[1] as Vector3) + Vector3(0.0, 1.0, 0.7), f[4], float(f[5]), 5.0)
	# things that glow in the shade
	if look.has("glowers"):
		for at: Vector3 in [Vector3(-8.6, 0, -3.0), Vector3(7.8, 0, -2.6), Vector3(10.2, 0, 1.6), Vector3(-10.8, 0, 1.0)]:
			prop(_pick("glowers"), at, rng.randf() < 0.5, 0.0, false, Color.WHITE, 0.9)
			lamp(at + Vector3(0.0, 0.7, 0.5), look["cool"], 0.9, 3.4)
	# close to the camera: something tall either side and low things along the bottom, all out of focus
	prop(_pick("big_trees"), Vector3(-12.6, 0.0, 6.2), false, 0.05, false, dim)
	prop(_pick("big_trees"), Vector3(13.4, 0.0, 7.4), true, 0.05, false, dim)
	for bx: float in [-8.8, -5.2, 6.4, 9.6]:
		prop(_pick("bushes"), Vector3(bx, -0.5, 8.4 + rng.randf() * 0.8), rng.randf() < 0.5, 0.02, false, dim)


func _dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _spark_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _dot_texture()
	m.albedo_color = colour
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 10                 # after the blur pass, so the sparks stay bright dots
	return m


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	return g


## Slow sparks of light drifting through the clearing.
func _sparks() -> void:
	var p := CPUParticles3D.new()
	p.amount = 46
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12.0, 1.5, 6.0)
	p.position = Vector3(0.0, 1.9, -1.5)
	p.gravity = Vector3(0.0, 0.03, 0.0)
	p.direction = Vector3(1.0, 0.2, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color_ramp = _fade_ramp()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _spark_material(Color(look["spark"]) * float(look.get("spark_power", 1.6)))
	p.mesh = q
	add_child(p)


func _embers(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0.1, 1.0, 0.0)
	p.spread = 22.0
	p.gravity = Vector3(0.15, 0.25, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	p.color_ramp = _fade_ramp()
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11)
	q.material = _spark_material(Color(1.0, 0.55, 0.2) * 2.2)
	p.mesh = q
	add_child(p)


## Pale beams of sky light slanting down between the trees.
func _beams_of_light() -> void:
	_beam_alpha = float(look.get("beam", 0.06))
	if _beam_alpha <= 0.0:
		return
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var across := GradientTexture2D.new()
	across.gradient = g
	across.width = 64
	across.height = 4
	for i in 5:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = across
		var c: Color = look["sun"]
		m.albedo_color = Color(c.r, c.g, c.b, 0.05 + rng.randf() * 0.04)
		m.disable_fog = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 9
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(1.6, 3.4), 22.0)
		var b := MeshInstance3D.new()
		b.mesh = q
		b.material_override = m
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = Vector3(-11.0 + i * 5.6 + rng.randf_range(-1.2, 1.2), 7.0, -5.0 - rng.randf() * 4.0)
		b.rotation_degrees = Vector3(0.0, 0.0, 26.0)
		add_child(b)
		_beams.append(b)


## The last pass over the whole picture: blur away from the fighters, warm lights and cool shade,
## dark corners.
func _post() -> void:
	var sh := Shader.new()
	sh.code = POST_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("focus", cam.position.distance_to(Vector3(0.0, 1.0, 0.0)))
	mat.set_shader_parameter("sharp", 2.6)
	mat.set_shader_parameter("lift", float(look.get("lift", 0.0)))
	if look.has("grade"):
		# [tint of the light, tint of the shade, contrast, colour]
		var g: Array = look["grade"]
		mat.set_shader_parameter("warm", g[0])
		mat.set_shader_parameter("shade", g[1])
		mat.set_shader_parameter("punch", float(g[2]))
		mat.set_shader_parameter("rich", float(g[3]))
		mat.set_shader_parameter("rim", float(look.get("rim", 0.55)))
	var haze: Color = look.get("haze", Color(1.0, 0.85, 0.6))
	mat.set_shader_parameter("haze", Vector3(haze.r, haze.g, haze.b))
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	post = MeshInstance3D.new()
	post.mesh = q
	post.material_override = mat
	post.extra_cull_margin = 16000.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(post)
	post.position = Vector3(0.0, 0.0, -1.0)


func _process(delta: float) -> void:
	_t += delta
	if _fire != null:
		# a fire never burns evenly
		_fire.light_energy = _fire_energy * (0.9 + 0.07 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0 + 1.3))
	for i in _beams.size():
		var m: StandardMaterial3D = _beams[i].material_override
		m.albedo_color.a = _beam_alpha * (1.0 + 0.4 * sin(_t * 0.4 + i * 1.9))
