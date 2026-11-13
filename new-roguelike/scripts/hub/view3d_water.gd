extends RefCounted
## WATER in the places you walk in (used by scripts/hub/view3d.gd): ponds from a place's "water"
## rows [{"at", "radius", "lilies"}]. All light and movement, no art (WATER_CODE). `v` is the view.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const CardShader = preload("res://scripts/fx/card_shader.gd")
const Hd = preload("res://scripts/fx/hd.gd")

const PX := 1.0 / 16.0
const WATER_LAYER := 2                  ## the render layer ponds are on (scripts/fx/hd_light.gd: the key light leaves it out)

## Water: all light and movement, no art. Two layers of soft noise slide over each other; where
## they agree the sky shows in the water, and where they peak the sun glints. It is drawn in
## steps of one art pixel so it sits with the pixel art.
const WATER_CODE := "
shader_type spatial;
render_mode specular_disabled;
" + Sprite3.SUN_PART + "
uniform vec3 sky : source_color = vec3(0.6, 0.75, 0.9);
uniform float day = 1.0;
varying vec2 at;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 w = floor(at * 16.0) / 16.0;
	float wob = texture(hh_dapple, w * 0.19).r - 0.5;
	float edge = length(UV * 2.0 - 1.0) * 1.1 + wob * 0.16;
	if (edge > 1.0) { discard; }
	float n1 = texture(hh_dapple, w * 0.13 + vec2(TIME * 0.011, TIME * 0.006)).r;
	float n2 = texture(hh_dapple, w * 0.29 - vec2(TIME * 0.014, -TIME * 0.009)).r;
	float ripple = n1 * n2 * 4.0;
	vec3 c = mix(vec3(0.03, 0.13, 0.17), vec3(0.10, 0.32, 0.33), smoothstep(0.35, 0.95, edge));
	c = mix(c, sky, smoothstep(0.85, 1.35, ripple) * 0.5);
	c = mix(c, vec3(0.22, 0.17, 0.10), smoothstep(0.93, 1.0, edge));
	ALBEDO = c;
	// glints: single art pixels that twinkle where the ripples run highest
	float twinkle = step(0.955, fract(sin(dot(floor(at * 16.0), vec2(12.9898, 78.233))) * 43758.5453 + TIME * 0.3));
	EMISSION = vec3(1.0, 0.92, 0.7) * smoothstep(1.3, 1.6, ripple) * twinkle * (0.2 + day) * 1.6 * (1.0 - smoothstep(0.85, 0.95, edge));
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
" + CardShader.SUN_LIGHT

## HD WATER (Forward+ on PC, scripts/fx/hd.gd), like a harbour at dusk: deep dark water whose
## colour is in its reflections, not its paint. The surface is a moving field of pixel ripples (a
## normal per art pixel from three drifting layers of noise), and every real light bounces off it:
## the sun or the moon as a glittering path of single pixels that sparkle and blaze into the bloom,
## each lamp as a broken bright streak on the water between it and the camera (its true mirror
## point, so it moves as you walk), and the sky at the far, grazing side (Fresnel). Soft broken
## foam laps at the bank. The open water is a MIRROR (metallic, smooth: the screen-space reflections
## that scripts/fx/hd_light.gd turns on show the houses, people and lamps of the far bank in it,
## broken by the ripples; `mirror` is how strong). Still no art: light and movement only.
const HD_WATER_CODE := "
shader_type spatial;
render_mode cull_back;
" + Sprite3.SUN_PART + "
uniform vec3 sky : source_color = vec3(0.6, 0.75, 0.9);
uniform float day = 1.0;
uniform vec3 deep : source_color = vec3(0.006, 0.026, 0.042);
uniform vec3 shallow : source_color = vec3(0.030, 0.140, 0.175);
uniform float chop = 0.013;              // how steep the ripples are
uniform float glitter = 2.2;            // how bright the sparkles of the sun and the moon are
uniform float streak = 3.0;             // how bright the lamps' streaks are
uniform float mirror = 0.75;            // how much the water mirrors what stands round it (screen-space reflections)
varying vec2 at;
varying float spark;                    // this art pixel is one that sparkles just now
varying float foam;
float nz(vec2 p) { return texture(hh_dapple, p).r; }
float waves(vec2 p) {
	return nz(p * 0.13 + vec2(TIME * 0.011, TIME * 0.006))
		+ nz(p * 0.29 - vec2(TIME * 0.014, -TIME * 0.009)) * 0.7
		+ nz(p * 0.83 + vec2(-TIME * 0.035, TIME * 0.027)) * 0.35;
}
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 cell = floor(at * 16.0);
	vec2 w = (cell + 0.5) / 16.0;                                  // the middle of this art pixel
	float wob = nz(w * 0.19) - 0.5;
	float edge = length(UV * 2.0 - 1.0) * 1.1 + wob * 0.16;
	if (edge > 1.0) { discard; }
	// the ripples' slope, one art pixel at a time
	// (the mirror's normal is the SMOOTH waves: a normal stepped per art pixel mirrored a random grey
	// in every square, a mosaic of static; only the sparkles keep the art pixel's steps)
	float e = 1.0 / 16.0;
	float h0 = waves(w);
	float hs = waves(at);
	vec2 slope = vec2(waves(at + vec2(e, 0.0)) - hs, waves(at + vec2(0.0, e)) - hs) / e;
	// steeper towards and away from the camera than across: highlights draw out into long streaks
	vec3 nw = normalize(vec3(-slope.x * chop * 0.55, 1.0, -slope.y * chop * 1.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// deep in the middle, a little lighter near the bank, then foam, then the muddy bank itself
	vec3 c = mix(deep, shallow, smoothstep(0.45, 0.95, edge));
	float lap = nz(w * 0.9 + vec2(TIME * 0.02, -TIME * 0.015)) + 0.5 * sin(TIME * 1.3 + edge * 18.0);
	foam = smoothstep(0.86, 0.92, edge) * (1.0 - smoothstep(0.95, 0.98, edge)) * step(0.95, lap + (edge - 0.9) * 3.0);
	c = mix(c, vec3(0.42, 0.48, 0.48), foam * 0.6);
	c = mix(c, vec3(0.20, 0.15, 0.09), smoothstep(0.95, 1.0, edge));
	// a MIRROR (the screen-space reflections of the PC look): smooth open water reflects the houses,
	// people and lamps on the far bank, broken up by the ripples' normals; foam and mud do not.
	// (A mirror has no colour of its own in the light: the water's own deep colour is in EMISSION.)
	float open_w = (1.0 - foam) * (1.0 - smoothstep(0.9, 0.97, edge));
	// (Fresnel makes the mirror: strong at the far, grazing side, dark water close under the camera)
	ALBEDO = mix(c, deep, open_w);
	METALLIC = open_w * 0.2;
	ROUGHNESS = mix(1.0, 0.05, open_w);
	SPECULAR = 0.5;
	// a handful of art pixels sparkle at any moment, each for a blink
	float seed = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	spark = step(0.9965, fract(seed * 7.13 + TIME * (0.35 + seed * 0.5))) * (1.0 - smoothstep(0.88, 0.95, edge));
	// the sky in the water, strongest where we look across it
	float fres = 0.06 + 0.94 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	// moving crests: thin lines of art pixels where the ripples run highest catch the sky
	float crest = step(1.20, h0) * (1.0 - step(1.235, h0)) + step(0.80, h0) * (1.0 - step(0.82, h0)) * 0.5;
	vec3 seen = mix(sky, vec3(0.30, 0.52, 0.62) * dot(sky, vec3(0.333)) * 1.6, 0.45);     // the sky, bluer in the water
	EMISSION = (seen * (0.05 + 0.6 * fres + 0.12 * crest) * (0.35 + 0.65 * day) + c * mix(0.25, 0.9, day)) * (1.0 - foam) * (1.0 - smoothstep(0.95, 1.0, edge));
	sun_share = sun_at(at);
}
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
	float m = max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0);
	float open = 1.0 - foam;
	if (LIGHT_IS_DIRECTIONAL) {
		// the sun's (or the moon's) path: a soft sheen, and in it single pixels that blaze
		SPECULAR_LIGHT += ATTENUATION * LIGHT_COLOR * open * (pow(m, 80.0) * 0.3 + smoothstep(0.86, 0.97, m) * spark * glitter * (0.12 + 0.88 * day));
	} else {
		// a lamp: a long broken streak towards the camera, its brightest pixels sparkling
		// (sparkles only inside the streak itself, never spread over the whole pond)
		SPECULAR_LIGHT += ATTENUATION * LIGHT_COLOR * open * streak * (pow(m, 28.0) * 0.6 + smoothstep(0.9, 0.98, m) * spark * 2.0);
	}
}
"

var v                              ## the view (scripts/hub/view3d.gd; untyped: its members are read by name)
var mats: Array = []
var _shader: Shader


func _init(view) -> void:
	v = view
	_shader = Shader.new()
	_shader.code = HD_WATER_CODE if Hd.on() else WATER_CODE


func reset() -> void:
	mats.clear()


## Every frame: how light the day is (1 = day) and the colour of the sky in the water.
func sync(day: float, sky: Color) -> void:
	for mat: ShaderMaterial in mats:
		mat.set_shader_parameter("day", day)
		mat.set_shader_parameter("sky", Vector3(sky.r, sky.g, sky.b) * Vector3(0.62, 0.78, 0.95))


func build(place: Dictionary) -> void:
	for pond: Dictionary in place.get("water", []):
		var c: Vector2 = pond["at"]
		var r: Vector2 = pond["radius"]
		var plane := PlaneMesh.new()
		plane.size = r * 2.2 * PX
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		var node := MeshInstance3D.new()
		node.mesh = plane
		node.material_override = mat
		node.position = Vector3(c.x * PX, 0.03 + v.build.height(c), c.y * PX)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = WATER_LAYER               # (the HD key pool of light does not mirror in it: a white blaze)
		v._world.add_child(node)
		mats.append(mat)
		for lily: Array in pond.get("lilies", []):         # flat pieces floating on it: [id, x, y]
			var tex := Art.tex(String(lily[0]))
			var leaf := PlaneMesh.new()
			leaf.size = tex.get_size() * PX
			var pad := MeshInstance3D.new()
			pad.mesh = leaf
			pad.material_override = CardShader.card(tex, Vector4(0, 0, 1, 1), Color.WHITE)
			pad.position = Vector3(float(lily[1]) * PX, 0.05 + v.build.height(c), float(lily[2]) * PX)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			v._world.add_child(pad)
