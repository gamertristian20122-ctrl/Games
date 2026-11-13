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

## HD WATER (Forward+ on PC, scripts/fx/hd.gd), like a harbour at dusk: deep blue-green water whose
## colour is in its reflections, not its paint. The surface is a moving field of pixel ripples (a
## normal per art pixel from three drifting layers of noise) on a slow swell that rolls towards the
## near bank, and every light shows in it:
##   the sun or the moon   a glittering path of single pixels that sparkle and blaze into the bloom
##   every lamp near it    a long clean COLUMN of light straight down the water from its true mirror
##                         image (worked out here from the lamp's position, `lamp_pos`, so it moves
##                         as you walk), its rows shaken and broken into dancing dashes by the
##                         ripples, hottest at the mirror point (screen-space reflections alone
##                         showed only a faint smear)
##   the sky               at the far, grazing side (Fresnel), with glitter winking on the crests
## Soft broken foam laps in and out at the bank. The open water is also a MIRROR (screen-space
## reflections, scripts/fx/hd_light.gd: the houses, people and lamps of the far bank, broken by the
## ripples; `mirror` is how strong). `square` turns the oval pond into a squared basin or harbour
## edge (a place's water row "square": 0..1). Still no art: light and movement only.
const HD_WATER_CODE := "
shader_type spatial;
render_mode cull_back;
" + Sprite3.SUN_PART + "
uniform vec3 sky : source_color = vec3(0.6, 0.75, 0.9);
uniform float day = 1.0;
uniform vec3 deep : source_color = vec3(0.010, 0.050, 0.075);
uniform vec3 shallow : source_color = vec3(0.030, 0.150, 0.170);
uniform float chop = 0.013;              // how steep the ripples are
uniform float swell = 0.05;              // how much the long slow swell tilts the water
uniform float glitter = 2.2;            // how bright the sparkles of the sun and the moon are
uniform float streak = 0.35;            // how bright the lamps' own (real-light) sheen is: low, a round soft blob; the columns carry them
uniform float mirror = 0.75;            // how much the water mirrors what stands round it (screen-space reflections)
uniform float square = 0.0;             // 0 = an oval pond, 1 = a squared basin or quay edge
uniform float columns = 1.0;            // how bright the lamps' columns of light are
uniform int lamp_n = 0;
uniform vec4 lamp_pos[8];               // the lamps near this water: xyz = the flame (world), w = how bright now
uniform vec4 lamp_col[8];               // ... and their colour
varying vec2 at;
varying float wy;
varying float spark;                    // this art pixel is one that sparkles just now
varying float foam;
float nz(vec2 p) { return texture(hh_dapple, p).r; }
float waves(vec2 p) {
	return nz(p * 0.13 + vec2(TIME * 0.011, TIME * 0.006))
		+ nz(p * 0.29 - vec2(TIME * 0.014, -TIME * 0.009)) * 0.7
		+ nz(p * 0.83 + vec2(-TIME * 0.035, TIME * 0.027)) * 0.35;
}
// 0 in the middle, 1 at the bank (an oval, or with `square` a box with rounded corners)
float shape(vec2 uv) {
	vec2 p = abs(uv * 2.0 - 1.0) * 1.1;
	float e = mix(2.0, 10.0, square);
	return pow(pow(p.x, e) + pow(p.y, e), 1.0 / e);
}
// where a point of the world is on the screen, in pixels (the same way round as SCREEN_UV)
vec2 on_screen(vec3 p, mat4 view, mat4 proj, vec2 vp) {
	vec4 c = proj * (view * vec4(p, 1.0));
	return (c.xy / max(c.w, 1e-4) * 0.5 + 0.5) * vp;
}
void vertex() {
	vec4 w4 = MODEL_MATRIX * vec4(VERTEX, 1.0);
	at = w4.xz;
	wy = w4.y;
}
void fragment() {
	vec2 cell = floor(at * 16.0);
	vec2 w = (cell + 0.5) / 16.0;                                  // the middle of this art pixel
	float wob = nz(w * 0.19) - 0.5;
	float edge = shape(UV) + wob * mix(0.16, 0.05, square);
	if (edge > 1.0) { discard; }
	// the ripples' slope, one art pixel at a time
	// (the mirror's normal is the SMOOTH waves: a normal stepped per art pixel mirrored a random grey
	// in every square, a mosaic of static; only the sparkles keep the art pixel's steps)
	float e = 1.0 / 16.0;
	float h0 = waves(w);
	float hs = waves(at);
	vec2 slope = vec2(waves(at + vec2(e, 0.0)) - hs, waves(at + vec2(0.0, e)) - hs) / e;
	// the swell: long low waves rolling in towards the near bank (they tilt the glitter in bands)
	float roll = at.y * 1.15 + at.x * 0.18 - TIME * 0.55;
	slope.y += cos(roll) * swell * 9.0 + cos(roll * 2.3 + 1.7) * swell * 3.0;
	// steeper towards and away from the camera than across: highlights draw out into long streaks
	vec3 nw = normalize(vec3(-slope.x * chop * 0.55, 1.0, -slope.y * chop * 1.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// deep in the middle, a little lighter near the bank, then foam, then the wet bank itself
	vec3 c = mix(deep, shallow, smoothstep(0.45, 0.97, edge));
	// SOFT FOAM: a broken frothy line that laps in and out with the swell, in pixel steps
	float lap = 0.5 + 0.5 * sin(TIME * 0.8 + nz(w * 0.35) * 6.0 + at.x * 0.4);
	float shore = smoothstep(0.85 + 0.04 * lap, 0.93 + 0.02 * lap, edge) * (1.0 - smoothstep(0.955, 0.99, edge));
	float froth = nz(w * 1.7 + vec2(TIME * 0.03, -TIME * 0.02)) * 0.7 + nz(w * 4.1 - vec2(TIME * 0.05, 0.0)) * 0.5;
	foam = floor(clamp(shore * smoothstep(0.30, 0.80, froth + shore * 0.35), 0.0, 1.0) * 4.0 + 0.5) / 4.0;
	c = mix(c, vec3(0.34, 0.40, 0.42), foam * 0.4);
	c = mix(c, vec3(0.13, 0.11, 0.08), smoothstep(0.96, 1.0, edge));
	// a MIRROR (the screen-space reflections of the PC look): smooth open water reflects the houses,
	// people and lamps on the far bank, broken up by the ripples' normals; foam and mud do not.
	// (A mirror has no colour of its own in the light: the water's own deep colour is in EMISSION.)
	float open_w = (1.0 - foam) * (1.0 - smoothstep(0.92, 0.98, edge));
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
	vec3 seen = mix(sky, vec3(0.26, 0.50, 0.62) * dot(sky, vec3(0.333)) * 1.6, 0.5);     // the sky, bluer and greener in the water
	vec3 glow = (seen * (0.05 + 0.6 * fres + 0.14 * crest) * (0.45 + 0.55 * day) + c * mix(1.3, 0.9, day)) * (1.0 - foam) * (1.0 - smoothstep(0.96, 1.0, edge));
	// GLITTER that dances on the far water: crest pixels that wink in the sky's light
	float wink = step(0.985, fract(seed * 13.7 + TIME * (0.6 + seed * 0.9))) * step(1.05, h0 + cos(roll) * 0.25);
	glow += mix(seen * 2.2, vec3(1.0, 0.9, 0.7), day * 0.5) * wink * smoothstep(0.15, 0.6, fres + 0.2) * open_w * 0.9;
	// THE LAMPS' COLUMNS: each lamp's mirror image (the flame flipped under the water's surface) is
	// found on the screen, and a column of its light runs straight down the water from it towards
	// the eye (and a little up past it), its rows shaken sideways and broken into dashes by the
	// ripples. Worked out once per art pixel, so the column steps with the pixel art.
	vec2 vp = VIEWPORT_SIZE;
	vec2 me = on_screen(vec3(w.x, wy, w.y), VIEW_MATRIX, PROJECTION_MATRIX, vp);
	vec3 cols = vec3(0.0);
	float row = floor(at.y * 16.0);
	for (int i = 0; i < lamp_n; i++) {
		vec4 L = lamp_pos[i];
		vec3 m = vec3(L.x, 2.0 * wy - L.y, L.z);
		vec2 img = on_screen(m, VIEW_MATRIX, PROJECTION_MATRIX, vp);
		float ppu = max(length(on_screen(m + vec3(1.0, 0.0, 0.0), VIEW_MATRIX, PROJECTION_MATRIX, vp) - img), 1.0);
		vec2 d = (me - img) / ppu;                                   // in world units: across, and down the screen
		float shake = (nz(vec2(row * 0.173 + float(i) * 0.37, TIME * 0.11)) - 0.5) * 0.55
			+ sin(roll * 2.0 + float(i)) * 0.06;
		float down = d.y;                                            // (+ = lower on the screen: towards the eye)
		float x = (d.x - shake) / (0.20 + 0.05 * abs(down));
		float along = down > 0.0 ? exp(-down / 3.2) : exp(down / 0.6);
		float dash = smoothstep(0.30, 0.62, nz(vec2(at.x * 0.7 + float(i) * 0.9, at.y * 3.3) + vec2(TIME * 0.025, -TIME * 0.12)));
		float body = exp(-x * x) * along * mix(0.25, 1.0, dash);
		float core = exp(-x * x * 3.0) * exp(-abs(down) / 0.55);
		cols += lamp_col[i].rgb * L.w * (body + core * 1.4);
	}
	glow += cols * columns * open_w;
	EMISSION = glow;
	sun_share = sun_at(at);
}
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share : 1.0);
	float m = max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0);
	float open = 1.0 - foam;
	if (LIGHT_IS_DIRECTIONAL) {
		// the sun's (or the moon's) path: a soft sheen, and in it single pixels that blaze
		SPECULAR_LIGHT += ATTENUATION * LIGHT_COLOR * open * (pow(m, 80.0) * 0.3 + smoothstep(0.86, 0.97, m) * spark * glitter * (0.25 + 0.75 * day));
	} else {
		// a lamp: a faint sheen, its brightest pixels sparkling (sparkles only inside it, never spread
		// over the whole pond); the clean column under it is worked out in fragment()
		SPECULAR_LIGHT += ATTENUATION * LIGHT_COLOR * open * streak * (pow(m, 60.0) * 0.6 + smoothstep(0.9, 0.98, m) * spark * 6.0);
	}
}
"

const MAX_LAMPS := 8                   ## HD: how many lamps' columns one pond shows (the nearest)
const LAMP_NEAR := 9.0                 ## HD: a lamp further than this (world units) past a pond's edge shows no column
const COLUMN := 0.2                   ## HD: how bright a lamp's column is, per unit of the lamp's energy

var v                              ## the view (scripts/hub/view3d.gd; untyped: its members are read by name)
var mats: Array = []
var ponds: Array = []                  ## HD, per pond: [material, centre (world xz), reach (world units)]
var _shader: Shader


func _init(view) -> void:
	v = view
	_shader = Shader.new()
	_shader.code = HD_WATER_CODE if Hd.on() else WATER_CODE


func reset() -> void:
	mats.clear()
	ponds.clear()


## Every frame: how light the day is (1 = day) and the colour of the sky in the water. `lamps` (HD):
## [flame (world), colour, energy now] for every lamp of the place (scripts/fx/hd_light.gd).
func sync(day: float, sky: Color, lamps: Array = []) -> void:
	for mat: ShaderMaterial in mats:
		mat.set_shader_parameter("day", day)
		mat.set_shader_parameter("sky", Vector3(sky.r, sky.g, sky.b) * Vector3(0.62, 0.78, 0.95))
	if not Hd.on():
		return
	# each pond shows the columns of the lamps nearest it (they come up as the day goes)
	var night := clampf(1.15 - day * 1.3, 0.0, 1.0)
	for pond: Array in ponds:
		var centre: Vector2 = pond[1]
		var near: Array = []
		for l: Array in lamps:
			var f: Vector3 = l[0]
			var d := Vector2(f.x, f.z).distance_to(centre) - float(pond[2])
			if d < LAMP_NEAR:
				near.append([d, l])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var pos := PackedVector4Array()
		var col := PackedVector4Array()
		for i in MAX_LAMPS:
			if i < near.size():
				var l: Array = near[i][1]
				var f: Vector3 = l[0]
				var c: Color = l[1]
				# (the further past the bank, the fainter: its light has further to fall)
				var k := float(l[2]) * COLUMN * night * (1.0 - smoothstep(LAMP_NEAR * 0.4, LAMP_NEAR, float(near[i][0])))
				pos.append(Vector4(f.x, f.y, f.z, k))
				col.append(Vector4(c.r, c.g * 0.82, c.b * 0.6, 1.0))         # (a deeper amber in the water)
			else:
				pos.append(Vector4.ZERO)
				col.append(Vector4.ZERO)
		var mat: ShaderMaterial = pond[0]
		mat.set_shader_parameter("lamp_n", mini(near.size(), MAX_LAMPS))
		mat.set_shader_parameter("lamp_pos", pos)
		mat.set_shader_parameter("lamp_col", col)


func build(place: Dictionary) -> void:
	for pond: Dictionary in place.get("water", []):
		var c: Vector2 = pond["at"]
		var r: Vector2 = pond["radius"]
		var plane := PlaneMesh.new()
		plane.size = r * 2.2 * PX
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		if Hd.on():
			mat.set_shader_parameter("square", float(pond.get("square", 0.0)))
			ponds.append([mat, c * PX, maxf(r.x, r.y) * PX])
		var node := MeshInstance3D.new()
		node.mesh = plane
		node.material_override = mat
		# (HD: a little higher than the lamps' painted pools of light on the ground, so a pool that
		# reaches the bank is hidden under the water: water shows a lamp as a column, not a disc)
		node.position = Vector3(c.x * PX, (0.05 if Hd.on() else 0.03) + v.build.height(c) + float(pond.get("lift", 0.0)) * PX / cos(deg_to_rad(v._pitch)), c.y * PX)
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
			pad.position = Vector3(float(lily[1]) * PX, 0.065 + v.build.height(c), float(lily[2]) * PX)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			v._world.add_child(pad)
