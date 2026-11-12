extends RefCounted
## WATER in the places you walk in (used by scripts/hub/view3d.gd): ponds from a place's "water"
## rows [{"at", "radius", "lilies"}]. All light and movement, no art (WATER_CODE). `v` is the view.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const CardShader = preload("res://scripts/fx/card_shader.gd")

const PX := 1.0 / 16.0

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

var v                              ## the view (scripts/hub/view3d.gd; untyped: its members are read by name)
var mats: Array = []
var _shader: Shader


func _init(view) -> void:
	v = view
	_shader = Shader.new()
	_shader.code = WATER_CODE


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
