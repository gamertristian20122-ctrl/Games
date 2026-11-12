extends MeshInstance3D
## A pixel sprite standing in the 3D battle stage (the "pixel people in a lit 3D world" look).
## It is a flat picture that faces the camera, takes the colour of every light near it, lies in
## the shadow of things and throws a shadow of its own shape. The art is the same pack art as
## everywhere else (Art.frames / Art.tex by id); nothing is drawn here.
##   Sprite3.make("pc_knight")                    stands on its feet at the node's position
##   Sprite3.make("hub_patch_0", "idle", true)    lies flat on the ground (trodden earth, flowers)
## One world unit is 16 art pixels (one floor tile).

const PX := 1.0 / 16.0

const CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform float flip = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform float shine = 0.0;
uniform float sway = 0.0;
varying float top;
void vertex() {
	top = 1.0 - UV.y;
	// leaves move a little in the wind: only the top of the picture, never the feet
	VERTEX.x += sin(TIME * 0.9 + MODEL_MATRIX[3].x * 1.7) * sway * top * top;
}
void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) { uv.x = 1.0 - uv.x; }
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) { discard; }
	ALBEDO = mix(c.rgb * tint, vec3(1.0), flash);
	EMISSION = c.rgb * shine;
	ROUGHNESS = 1.0;
}
void light() {
	// a flat picture has no round sides: every light simply colours it by how near it is.
	// Lamps are turned down for pictures: the ground only catches them at a slant.
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.35);
}
"

static var _shader: Shader

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


static func shader() -> Shader:
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
	_mat.shader = shader()
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


func set_flash(v: float) -> void:
	_mat.set_shader_parameter("flash", v)


func height() -> float:
	return _size.y * PX


func _show(t: Texture2D) -> void:
	_mat.set_shader_parameter("tex", t)
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("tex", t)
	var sz := t.get_size()
	if sz != _size:
		_size = sz
		(mesh as QuadMesh).size = sz * PX
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
		(mesh as QuadMesh).center_offset = Vector3(cx, cy, 0.0)


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
