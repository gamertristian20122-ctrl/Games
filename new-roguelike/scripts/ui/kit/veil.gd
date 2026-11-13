extends ColorRect
## Veil: the full-screen backdrop of full menus over the world (knight, pause, settings, customize,
## credits): the picture behind is softened (5 x 5 taps at mip level 2.5), desaturated 45%, darkened,
## cooled and vignetted. Proved in Forward+ and gl_compatibility. Add it as the screen's first child
## (Screen.veil() does that). The title menu does NOT use it (the 3D title scene is the show).

const BLUR_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;
void fragment() {
	vec3 c = vec3(0.0);
	float n = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 6.0, 2.5).rgb;
			n += 1.0;
		}
	}
	c /= n;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(l), c, 0.55) * 0.42 + vec3(0.008, 0.012, 0.03);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(c, strength);
}
"""

static var _shader: Shader


func _init() -> void:
	color = Color(0.02, 0.025, 0.045, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BLUR_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	material = mat


## 0..1: how much of the veil shows (fade it in / out with this).
func set_strength(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("strength", v)
