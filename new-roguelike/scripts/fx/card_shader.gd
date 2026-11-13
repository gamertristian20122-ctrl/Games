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
const Hd = preload("res://scripts/fx/hd.gd")

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
## THE HD CARD (Forward+ on PC, scripts/fx/hd.gd): the same picture, but it also THROWS a real
## shadow (the sun's and the nearest lamps' shadow maps; the flat "shade" copy is not drawn then)
## and lies in the real shadows of houses and trees. In the shadow pass the picture is pushed a
## little away from the light (`shadow_push`), so a card never shades its own face.
## The HERO variant is for every person, monster and the knight: never in the fog, a little more
## light and contrast, and a thin rim of warm light along its top and sides (from the picture's own
## alpha, so the pixel art is untouched), so people far from the camera still read at a glance.
## SPRITES IN THE LIGHT (HD): each pixel gets a normal worked out by the shader from the picture's
## own pixels (alpha edges over three pixels = a rounded bevel, its light and dark = relief, the
## card bowed like a drum; constant over an art pixel, so the light steps stay crisp and no art is
## drawn or smoothed). Lamps light the side that faces them and leave the far side in shade, edges
## turned to the sun or a lamp catch a hard rim, bright grey pixels (steel) glint, and the bottom
## edge of every shape and the feet sit in a little ambient shade (AO). People get a softer wrap so
## they never go dark on their far side.
## PEOPLE COME FIRST (HD): every person's card is drawn a second time on top of everything
## (`next_pass`, the XRAY copy), but only where something nearer the camera hides them: there they
## show through as a see-through copy of themselves. The scenery in front stays whole and solid
## (blurred and shaded like everything else), so nothing has holes cut in it.
static func card_code(hero: bool, xray := false) -> String:
	return "shader_type spatial;\nrender_mode cull_disabled, specular_disabled" + (", fog_disabled" if hero else "") \
		+ (", depth_draw_never, depth_test_disabled, blend_mix, shadows_disabled" if xray else "") + ";\n" \
		+ ("#define HERO\n" if hero else "") + ("#define XRAY\n" if xray else "") + Sprite3.SUN_PART + HD_CARD_BODY


const HD_CARD_BODY := "
const float XRAY_SHOW = 0.55;                                       // how much of a hidden person shows through what hides them
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float shine = 0.0;
uniform float sway = 0.0;
uniform float shadow_push = 0.15;
uniform float rim = 0.0;                                        // HERO: how bright the rim is
uniform vec3 rim_col : source_color = vec3(1.0, 0.85, 0.62);
uniform float pop = 1.12;                                       // HERO: contrast
uniform float boost = 1.18;                                     // HERO: a little more light than the scenery
uniform float bevel = 1.25;                                     // how round a picture's edges are (from its alpha)
uniform float relief = 0.55;                                    // how much its own light and dark raise and sink it
uniform float round_body = 0.32;                                // the whole picture bowed like a drum
// BLAZE (things that glow): a hot glow keeps its colour (gold, orange), only its brightest pixels
// stay a pale core, so the tone curve does not turn a lamp into a cold white tube
uniform vec3 hot_col = vec3(1.0, 0.22, 0.04);                  // (linear light, not a picked colour)
uniform float hot = 0.0;                                        // how far the glow is pushed to hot_col
uniform float by_night = 0.0;                                   // 1 = a lamp: dim by day, full at dusk and night
uniform float lamp_take = 1.0;                                  // how much lamplight it takes (a lantern's own cage: little, so it stays dark iron round the glow)
global uniform float hh_lamp_on;                                // (set every frame by scripts/fx/hd_light.gd)
global uniform float hh_exposure;                               // the camera's exposure now (scripts/fx/hd_light.gd)
#ifdef XRAY
global uniform vec4 hh_grade;                                   // the last pass: x = dark corners, y = where the foreground begins
global uniform vec4 hh_tint;                                    // the last pass: its middle tint
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
#endif
varying float shadow_pass;
varying vec2 foot;
varying vec3 card_r;                                            // view space: the picture's right (UV.x)
varying vec3 card_u;                                            // view space: the picture's up
varying float tilt;                                             // 0 = this pixel faces the camera, 1 = a steep edge
varying float metal;                                            // bright grey pixels (steel, silver): glints
#ifdef HERO
varying float rim_w;                                            // how much of a rim this pixel is (0 = none)
varying vec3 rim_n;                                             // which way that rim faces (view space)
#endif
void vertex() {
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 0.9 + MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 0.9) * sway * top * top;
	if (IN_SHADOW_PASS) {
		// away from the light that is drawing its shadow map: no shadow of a card on its own face
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 away = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(w - INV_VIEW_MATRIX[3].xyz);
		w += normalize(away) * shadow_push * (1.0 - UV.y);      // (the feet stay where they meet the ground)
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	}
	shadow_pass = IN_SHADOW_PASS ? 1.0 : 0.0;
	foot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	card_r = (MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	card_u = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}
float alpha_at(vec2 uv) {
	if (uv.x < uv_rect.x || uv.y < uv_rect.y || uv.x > uv_rect.x + uv_rect.z || uv.y > uv_rect.y + uv_rect.w) { return 0.0; }
	return step(0.5, texture(tex, uv).a);
}
vec4 px_at(vec2 uv) {
	if (uv.x < uv_rect.x || uv.y < uv_rect.y || uv.x > uv_rect.x + uv_rect.z || uv.y > uv_rect.y + uv_rect.w) { return vec4(0.0); }
	return texture(tex, uv);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 uv = uv_rect.xy + UV * uv_rect.zw;
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) { discard; }
#ifdef XRAY
	// the see-through copy of a person: only where something nearer the camera hides them
	float d = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	if (-sv.z / sv.w > -VERTEX.z - 0.3) { discard; }
#endif
	vec3 col = c.rgb * tint;
	vec2 tx = 1.0 / vec2(textureSize(tex, 0));
	// THE PICTURE'S OWN NORMAL, worked out from its pixels (nothing is drawn): every pixel is
	// tilted towards the nearest edge of the figure (its alpha, over three pixels), a little up or
	// down by its own light and dark (bright = raised), and the whole card is bowed like a drum.
	// It is the same over a whole art pixel, so the light falls on it in crisp pixel steps.
	vec4 l1 = px_at(uv - vec2(tx.x, 0.0));
	vec4 r1 = px_at(uv + vec2(tx.x, 0.0));
	vec4 u1 = px_at(uv - vec2(0.0, tx.y));
	vec4 d1 = px_at(uv + vec2(0.0, tx.y));
	vec4 a1 = step(0.5, vec4(l1.a, r1.a, u1.a, d1.a));
	vec4 a2 = vec4(alpha_at(uv - vec2(tx.x * 2.0, 0.0)), alpha_at(uv + vec2(tx.x * 2.0, 0.0)), alpha_at(uv - vec2(0.0, tx.y * 2.0)), alpha_at(uv + vec2(0.0, tx.y * 2.0)));
	vec4 a3 = vec4(alpha_at(uv - vec2(tx.x * 3.0, 0.0)), alpha_at(uv + vec2(tx.x * 3.0, 0.0)), alpha_at(uv - vec2(0.0, tx.y * 3.0)), alpha_at(uv + vec2(0.0, tx.y * 3.0)));
	vec4 a = a1 * 0.45 + a2 * 0.35 + a3 * 0.2;                  // left, right, up, down: how solid each way
	vec2 g = vec2(a.x - a.y, a.w - a.z) * bevel;
	float me = lum(c.rgb);
	vec4 h = mix(vec4(me), vec4(lum(l1.rgb), lum(r1.rgb), lum(u1.rgb), lum(d1.rgb)), a1);
	g += vec2(h.x - h.y, h.w - h.z) * relief;
	g.x += (UV.x * 2.0 - 1.0) * round_body;
	vec3 n = normalize(vec3(g, 1.0));
	tilt = 1.0 - n.z;
	vec3 f = NORMAL;
	if (dot(f, VIEW) < 0.0) { f = -f; }
	vec3 r = normalize(card_r - f * dot(card_r, f));
	vec3 up = card_u - f * dot(card_u, f) - r * dot(card_u, r);
	up = dot(up, up) > 1e-4 ? normalize(up) : cross(f, r);
	NORMAL = normalize(r * n.x + up * n.y + f * n.z);
	// steel and silver (bright, grey) catch hard little glints of every light
	float sat = max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
	metal = smoothstep(0.42, 0.62, me) * (1.0 - smoothstep(0.10, 0.22, sat));
	// a little shade under every shape and at the feet (ambient only; the lights decide the rest)
	float under = 1.0 - a1.w;
	AO = clamp(1.0 - 0.32 * under - 0.22 * (1.0 - smoothstep(0.0, 0.22, 1.0 - UV.y)), 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.2;
#ifdef HERO
	col = max((col - 0.16) * pop + 0.16, vec3(0.0));
	// pale robes, faces and bandages are held under the bloom's threshold (never a white ghost)
	col *= 1.0 / (1.0 + max(lum(col) - 0.62, 0.0) * 1.2);
	// THE RIM (a light, see light()): the pack draws a dark one-pixel outline, so the lit edge is the
	// first pixel INSIDE it: its neighbour that way is outline and the one past that is open air.
	// The outline itself stays dark (no pale sticker border). Top and both sides each get their own
	// direction, and light() lights only the edges that face a light, in that light's own colour
	// and shadow (none in the shade, none from a moon that is not there).
	vec4 inner = a1 * (vec4(1.0) - a2);                          // left, right, up, down
	bool to_right = card_r.x >= 0.0;
	float e_right = to_right ? inner.y : inner.x;
	float e_left = to_right ? inner.x : inner.y;
	float top_k = smoothstep(0.15, 0.55, 1.0 - UV.y);
	vec2 e2 = vec2(e_right - e_left, inner.z) * top_k;
	rim_w = clamp(length(e2), 0.0, 1.0) * smoothstep(0.06, 0.25, me);
	rim_n = rim_w > 0.0 ? normalize(r * e2.x + up * e2.y + f * 0.35) : f;
	// (and a little light of its own, so a person in deep shade still reads: bring them forward)
	EMISSION = col * shine + col * 0.12;
#else
	vec3 glow_c = col;
	float glow_k = 1.0;
	if (hot > 0.0) {
		// how hot each pixel burns comes from the artist's own light and dark: dark red at the
		// edges, orange in the body, a gold-white core only in the brightest pixels (so a flame
		// reads as a FLAME, not a white blob, after the tone curve and the bloom)
		// The fire colour is SATURATED at every brightness (green and blue stay a small share of
		// red), because the tone curve turns any light whose three colours all run hot into white;
		// only the one or two palest pixels (a lamp's wick, a flame's heart) burn towards pale gold.
		float heat = smoothstep(0.25, 0.85, max(max(col.r, col.g), col.b) * 0.5 + me * 0.5);
		vec3 fire = hot_col * (0.3 + 0.7 * heat);
		float core = smoothstep(0.86, 1.0, heat) * mix(0.3, 1.0, smoothstep(0.6, 0.88, me));
		fire = mix(fire, vec3(1.0, 0.72, 0.40) * 1.6, core);
		glow_c = mix(col, fire, hot);
		// only warm or bright pixels burn (embers, flame, glass), never the grey stones of a fire pit
		glow_k = max(smoothstep(0.12, 0.35, col.r - col.b), smoothstep(0.72, 0.88, me));
		// (what glows is lit by its own fire, not by the light falling on it: a pale glass lit by
		// its own lamp would add a white sheen over the amber)
		col *= 1.0 - 0.8 * hot * glow_k;
	}
	EMISSION = glow_c * glow_k * shine * mix(1.0, hh_lamp_on, by_night);
#endif
	ALBEDO = col;
	ROUGHNESS = 1.0;
	sun_share = sun_at(foot);
#ifdef XRAY
	ALPHA = XRAY_SHOW;
	// the copy is drawn after the last pass (which only sees solid things), so it copies the last
	// pass's grade itself: its tint and its dark corners (in linear light)
	vec2 q = SCREEN_UV - 0.5;
	float vig = 1.0 - smoothstep(0.18, 0.62, dot(q, q) * 1.9) * hh_grade.x;
	vec3 graded = pow(max(hh_tint.rgb * vig, vec3(0.0)), vec3(2.2));
	ALBEDO *= graded;
	EMISSION *= graded;
#endif
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit;
	if (LIGHT_IS_DIRECTIONAL) {
		// the sun lights the whole face (a card is never in its own shade), and the edges that
		// turn towards it catch it hard: the rim of light round everything when the sun is behind
		lit = sun_share * (0.8 + 0.25 * clamp(ndl * 0.5 + 0.5, 0.0, 1.0) + tilt * max(ndl, 0.0) * 1.1);
	} else {
		// a lamp lights the side of a figure that faces it, and leaves the far side in shade
#ifdef HERO
		float wrap = clamp((ndl + 0.9) / 1.9, 0.0, 1.0);
#else
		// (things that glow themselves, flames and lamp glass, take their own light from all sides)
		float w = shine > 0.0 ? 6.0 : 0.75;
		float wrap = clamp((ndl + w) / (1.0 + w), 0.0, 1.0);
#endif
		lit = 0.62 * wrap * (1.15 - 0.3 * (1.0 - UV.y)) + tilt * max(ndl, 0.0) * 0.9;
#ifndef HERO
		// a flame or a lamp's glass makes its own light: the lamp inside it would wash it white
		lit *= shine > 0.0 ? 0.2 : lamp_take;
#endif
	}
	vec3 add = ATTENUATION * LIGHT_COLOR / PI * lit;
	// glints on steel: a hard little highlight where the light bounces into the eye
	add += ATTENUATION * LIGHT_COLOR * metal * pow(max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0), 14.0) * (LIGHT_IS_DIRECTIONAL ? 0.9 : 1.6);
#ifdef HERO
	// people are lit as if the camera were not opened up for a dark place (the woods open it to 1.7:
	// a pale elf in the sun went white), and the brightest light on them rolls off softly, so a
	// face or a white robe keeps its pixels instead of burning into the bloom
	add *= boost * clamp(1.3 / max(hh_exposure, 0.01), 0.62, 1.0);
	if (LIGHT_IS_DIRECTIONAL) {
		add /= 1.0 + max(dot(add, vec3(0.333)) - 0.45, 0.0) * 0.9;
	} else {
		// a fire or a lamp right beside somebody: each light rolls off on its own, so a face one
		// tile from a camp fire stays a mid-tone and keeps its colour
		add /= 1.0 + lum(add) * 1.5;
	}
	// the rim: the edges that face this light catch it (a light from behind, as in the sun)
	add += ATTENUATION * LIGHT_COLOR / PI * rim * rim_w * max(dot(rim_n, LIGHT), 0.0) * (LIGHT_IS_DIRECTIONAL ? 2.2 * sun_share : 1.2);
#endif
	DIFFUSE_LIGHT += add;
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

const HERO_RIM := 0.3                 ## HD: how bright the rim light on people is (0 = none)
## HD: do standing pictures throw real shadows? (The flat "shade" copies are drawn only when not.)
static func casts() -> GeometryInstance3D.ShadowCastingSetting:
	return GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Hd.on() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _card_shader: Shader
static var _shade_shader: Shader
static var _hd_shaders := {}          ## false = scenery, true = HERO, "xray" = a person's see-through copy


static func card_shader(hero := false) -> Shader:
	if Hd.on():
		if not _hd_shaders.has(hero):
			var sh := Shader.new()
			sh.code = card_code(hero)
			_hd_shaders[hero] = sh
		return _hd_shaders[hero]
	if _card_shader == null:
		_card_shader = Shader.new()
		_card_shader.code = CARD_CODE
	return _card_shader


static func shade_shader() -> Shader:
	if _shade_shader == null:
		_shade_shader = Shader.new()
		_shade_shader.code = SHADE_CODE
	return _shade_shader


## A standing picture's material. `hero` = a person, a monster or the knight (HD: kept readable).
static func card(tex: Texture2D, uv: Vector4, tint: Color, hero := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = card_shader(hero)
	if hero and Hd.on():
		mat.set_shader_parameter("rim", HERO_RIM)
		# the person's see-through copy where something hides them (drawn after the last pass, which
		# only sees solid things and would paint over it: render_priority above the last pass's 0)
		var xray := ShaderMaterial.new()
		if not _hd_shaders.has("xray"):
			var sh := Shader.new()
			sh.code = card_code(true, true)
			_hd_shaders["xray"] = sh
		xray.shader = _hd_shaders["xray"]
		xray.render_priority = 1
		xray.set_shader_parameter("rim", HERO_RIM)
		mat.next_pass = xray
	param(mat, "tex", tex)
	param(mat, "uv_rect", uv)
	param(mat, "tint", Vector3(tint.r, tint.g, tint.b))
	set_glow(mat, tex, hero)
	return mat


## Sets a setting of a card's material (and of its see-through copy, if it has one).
static func param(mat: ShaderMaterial, key: StringName, value: Variant) -> void:
	mat.set_shader_parameter(key, value)
	if mat.next_pass is ShaderMaterial:
		(mat.next_pass as ShaderMaterial).set_shader_parameter(key, value)


## How a picture glows (its shine; HD: gold and orange, not white; lamps dim by day). Called again
## whenever a moving card changes its picture (scripts/hub/view3d.gd).
static func set_glow(mat: ShaderMaterial, tex: Texture2D, hero := false) -> void:
	param(mat, "shine", shine_of(tex))
	if not Hd.on() or hero or tex == null:
		return
	var path := tex.resource_path
	var hot := 0.0
	var by_night := 0.0
	var hot_col := Vector3(1.0, 0.22, 0.04)
	if tex.resource_name == "hub_lampglass":
		hot = 1.0
		by_night = 1.0
	elif path.contains("hub_flame"):
		hot = 0.92
	elif path.contains("hub_fire"):
		hot = 0.7
	elif path.contains("hub_flava"):
		hot = 0.85              # (molten rock burns orange-red, never a pale pink sheet)
	param(mat, "hot", hot)
	param(mat, "by_night", by_night)
	param(mat, "lamp_take", 0.25 if path.contains("hub_slantern") else 1.0)
	param(mat, "hot_col", hot_col)


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
	# (HD: over the bloom's threshold, so flames BLAZE, but no further: past it the tone curve turns
	# every colour white; the heat is in the saturated colour, see set_glow "hot")
	if path.contains("hub_flame"):
		return 2.4 * (0.7 if Hd.on() else 1.0)
	if tex.resource_name == "hub_lampglass":
		return 2.6 * (0.75 if Hd.on() else 1.0)      # the glass of a lamp post (HD: amber, see set_glow "hot")
	if path.contains("hub_fire") or path.contains("hub_flava") or path.contains("hub_rune"):
		return 0.5 * (2.4 if Hd.on() else 1.0)
	if path.contains("hub_win"):
		return 0.45 * (1.8 if Hd.on() else 1.0)              # lit windows
	return 0.0


## How much a still picture sways in the wind (plants do, stone and wood do not).
static func sway_of(tex: Texture2D) -> float:
	var path := tex.resource_path
	for word: String in ["hub_tree", "hub_bush", "hub_bloom", "hub_vine", "hub_plant", "hub_dtree", "hub_dbush", "hub_planter", "hub_vbush", "hub_vbig", "hub_vplant"]:
		if path.contains(word):
			return 0.035
	return 0.0
