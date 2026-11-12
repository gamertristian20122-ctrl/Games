extends RefCounted
## HOW PICTURES ARE DRAWN AND LIT in the places you walk in (scripts/hub/view3d.gd).
## A "card" is one flat pack picture standing upright in the 3D place (a tree, a person, the
## knight's sword); a "shade" is the same picture laid flat on the ground as its shadow, painted as
## darker ground. This file holds their shaders and makes their materials. Static: nothing to set up.
##   CardShader.card(tex, uv, tint)            a standing picture
##   CardShader.shade(ground_params, tex, uv)  its flat shadow (needs the floor's settings)
##   CardShader.shine_of(tex) / sway_of(tex)   which pictures glow, which sway in the wind
## FLOOR_PART (the ground's colour at a spot) and SUN_LIGHT (the sky light in patches) are shared
## with the floor and the walls (scripts/hub/view3d_build.gd).

const Sprite3 = preload("res://scripts/battle/sprite3.gd")

const CARD_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + Sprite3.SUN_PART + "
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float shine = 0.0;
uniform float sway = 0.0;
varying vec2 foot;
varying vec3 card_side;
void vertex() {
	// plants move a little in the wind: the top of the picture, never the foot
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 0.9 + MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 0.9) * sway * top * top;
	// the patch of sun or shade a thing stands in is the one under it
	foot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec4 c = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (c.a < 0.5) { discard; }
	ALBEDO = c.rgb * tint;
	EMISSION = c.rgb * shine;
	ROUGHNESS = 1.0;
	sun_share = sun_at(foot);
	card_side = TANGENT;
}
void light() {
	// a flat picture is lit as if it were a little round: the side that faces a light is brighter,
	// the other side darker (on average as bright as before). Lamps light the foot more than the top.
	float side = (UV.x * 2.0 - 1.0) * dot(normalize(card_side), LIGHT);
	float lamp = 0.35 * (1.0 + 0.55 * side) * (1.15 - 0.3 * (1.0 - UV.y));
	float sun = sun_share * (1.0 + 0.22 * side);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun : max(lamp, 0.0));
}
"
## The ground: the place's ground tile laid cell by cell, each turned at random so that no rows
## show, and OVER it whatever hub.gd painted flat (paths, paving, sand, decals).
const FLOOR_PART := "
uniform sampler2D ground_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D base_tex : source_color, filter_nearest, repeat_disable;
uniform vec2 base_cell = vec2(3.0, 3.0);
uniform vec4 base_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 base_texel = vec2(0.01, 0.01);
uniform float grey = 0.22;
varying vec2 at;
vec3 ground_colour(vec2 where) {
	vec2 g = where / base_cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
	if (h > 0.5) { f.x = 1.0 - f.x; }
	if (fract(h * 7.0) > 0.5) { f.y = 1.0 - f.y; }
	vec3 c = texture(base_tex, base_region.xy + clamp(f, base_texel, 1.0 - base_texel) * base_region.zw).rgb;
	vec4 over = texture(ground_tex, (where - ground_rect.xy) / ground_rect.zw);
	c = mix(c, over.rgb, over.a);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(c, vec3(l) * 1.15, grey);
}
"
const SUN_LIGHT := "
void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
}
"
const SHADE_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + Sprite3.SUN_PART + FLOOR_PART + "
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float dark = 0.6;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	if (texture(tex, uv_rect.xy + UV * uv_rect.zw).a < 0.5) { discard; }
	ALBEDO = ground_colour(at) * dark;
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
" + SUN_LIGHT

static var _card_shader: Shader
static var _shade_shader: Shader


static func card_shader() -> Shader:
	if _card_shader == null:
		_card_shader = Shader.new()
		_card_shader.code = CARD_CODE
	return _card_shader


static func shade_shader() -> Shader:
	if _shade_shader == null:
		_shade_shader = Shader.new()
		_shade_shader.code = SHADE_CODE
	return _shade_shader


## A standing picture's material.
static func card(tex: Texture2D, uv: Vector4, tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = card_shader()
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("shine", shine_of(tex))
	return mat


## A flat shadow's material: the ground under it, darker (`ground_params` = the floor's settings).
static func shade(ground_params: Dictionary, tex: Texture2D, uv: Vector4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shade_shader()
	for k: String in ground_params:
		mat.set_shader_parameter(k, ground_params[k])
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	return mat


## How much a picture glows by itself (flames, lamp glass, rune stones, lit windows).
static func shine_of(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var path := tex.resource_path
	if path.contains("hub_flame"):
		return 2.4
	if tex.resource_name == "hub_lampglass":
		return 2.6               # the glass of a lamp post
	if path.contains("hub_fire") or path.contains("hub_flava") or path.contains("hub_rune"):
		return 0.5
	if path.contains("hub_win"):
		return 0.45              # lit windows
	return 0.0


## How much a still picture sways in the wind (plants do, stone and wood do not).
static func sway_of(tex: Texture2D) -> float:
	var path := tex.resource_path
	for word: String in ["hub_tree", "hub_bush", "hub_bloom", "hub_vine", "hub_plant", "hub_dtree", "hub_dbush", "hub_planter"]:
		if path.contains(word):
			return 0.035
	return 0.0
