extends Node3D
## The LIT 3D LOOK for every place you walk in (camps, the world map, the tavern rooms).
## The owner asked for it on 12 Nov 2026: "that needs to be for the entire game".
##
## hub.gd still does everything as before, in flat 2D: where things stand, who walks where, what
## you can talk to. This file only SHOWS it differently. After hub.gd has built a place it calls
## rebuild(); from then on, every frame, this file copies what the flat picture holds:
##   the ground       everything painted flat (grass, sand, paths, decals, a room's picture) is
##                    drawn once into one big texture and laid on the floor of a 3D world
##   standing things  every picture under hub.gd's `_ysort` (trees, people, the knight, monsters)
##                    becomes an upright card on that floor, on the same spot. Things that never
##                    move are drawn in batches; people, fires and the knight are followed live
##   light            the day's colour becomes a sky light, every lamp of the place a small light
##   words            labels ("!", names, signs) are shown over the 3D picture on the same spots
## REAL DEPTH (v0.20.0, the owner: "depth first and graphics and quality"). Three things in a
## place's data are built here as true 3D instead of flat cards:
##   "houses"  [{"at", "wide", "deep", "wall", "roof", "rise", "gable", "door", "windows", ...}]
##             a box of walls with a sloped roof, a chimney that smokes, a door and windows on
##             the front, and a shadow of its true shape (_build_house)
##   "rise"    {"from", "over", "height", "mound"}  the ground climbs behind the place, and
##   "hills"   [{"at", "radius", "height", "top"}]  hills you walk on: the floor is a mesh with
##             height and everything standing on it stands that high (_height)
##   "water"   [{"at", "radius"}]  a pond: ripples, the sky in it, glints of sun (WATER_CODE)
## Plants sway in the wind. (hub.gd shows houses as flat pieces and water as a flat shape when
## the 3D look is off.)
## On top: flat shadows, mist, glow, fireflies and the blur away from the knight (as in
## scripts/battle/stage.gd, whose lessons apply here too).
## The flat 2D picture is hidden, not removed: `--flat` on the command line shows the old look.
## One world unit is 16 art pixels: 2D (x, y) is 3D (x / 16, 0, y / 16).

const Stage = preload("res://scripts/battle/stage.gd")
const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")

const PX := 1.0 / 16.0
const PITCH := 35.0                 ## how steeply the camera looks down out of doors, in degrees (low, like a stage)
const PITCH_INDOORS := 62.0         ## a room is one painted picture: looked at more from above, it keeps its shape
const TILT := 8.0                   ## how far standing things lean back towards the camera, out of doors ...
const TILT_INDOORS := 45.0          ## ... and in a room (so people are not squashed by the steep view)
const FOV := 30.0
const WIDE := 1.3                   ## out of doors the camera stands this much further back than the flat one: whole houses fit, people are smaller
const MARGIN := Vector2(336, 208)   ## how far past the edges of a place the ground is painted, px
const LEAN := Vector2(-0.55, 0.5)   ## which way a shadow falls on the ground, per unit of height
const LAMP_ENERGY := 9.0            ## a 2D lamp of energy 1 is this strong here
const LAMP_REACH := 1.5             ## and reaches this many times as far as its 2D picture

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
const FLOOR_CODE := "
shader_type spatial;
render_mode specular_disabled;
" + Sprite3.SUN_PART + FLOOR_PART + "
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = ground_colour(at);
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
" + SUN_LIGHT
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

## Walls and roofs: real surfaces. Each is lit by how it faces (the front brightest, the sides
## darker, a roof by its slope), so a house reads as a solid thing.
const SOLID_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + Sprite3.SUN_PART + "
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float shine = 0.0;
varying vec3 wn;
varying vec2 foot;
varying float facing;
void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	foot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) { discard; }
	float f = clamp(dot(normalize(wn), normalize(vec3(0.25, 0.75, 0.6))), 0.0, 1.0);
	ALBEDO = c.rgb * (0.78 + 0.22 * f);
	EMISSION = c.rgb * shine;
	ROUGHNESS = 1.0;
	sun_share = sun_at(foot);
	facing = 0.55 + 0.45 * f;
}
void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? sun_share * facing : 0.6);
}
"
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
" + SUN_LIGHT

var hub: Node2D
var cam: Camera3D
var _world: Node3D                 ## everything of the current place; freed and rebuilt on rebuild()
var _port: SubViewport             ## paints the flat ground once
var _env: Environment
var _sun: DirectionalLight3D
var _post: MeshInstance3D
var _words: Control                ## the labels shown over the 3D picture
var _card_shader: Shader
var _shade_shader: Shader
var _floor_shader: Shader
var _unit := QuadMesh.new()
var _ground_params := {}
var _live := {}                    ## holder id -> {"node": Node2D, "cards": {sprite id -> card}}
var _known := 0                    ## how many children `_ysort` had when last looked at
var _still := {}                   ## holder id -> true: things already drawn in a batch
var _twins: Array = []             ## [Label in the flat picture, its copy here, holder or null]
var _lamps: Array = []             ## [PointLight2D, OmniLight3D]
var _flies: CPUParticles3D
var _outdoor := false
var _dist := 21.0
var _pitch := PITCH
var _lift := 0.0                   ## how much the darks are lifted towards a warm haze (soft light)
var _day := 0.0                    ## 1 = out of doors by day (patches of golden sun), 0 = night or a room
var _drift := 0.0
var _up := Vector3.UP              ## "up" for a standing card: straight up, leaned back by the tilt
var _rise := {}                    ## the place's "rise" (the ground climbs behind it), or {}
var _hills: Array = []              ## the place's "hills"
var _has_height := false
var _surf := {}                    ## texture id -> [Texture2D, SurfaceTool]: the houses being built
var _window_mats: Array = []       ## window materials: they glow at night
var _water_mats: Array = []
var _solid_shader: Shader
var _water_shader: Shader
var _dot_tex: GradientTexture2D
var _glows: Array = []             ## per lamp: [PointLight2D, pool material, halo material, warm?, seed]
var _windows: Array = []           ## [pool material, halo material]: window light that falls on the street at night
var _sky_fx: Node3D                ## beams of sun and dust: follows the camera's spot
var _shaft_mats: Array = []
var _motes: CPUParticles3D
var _grade := {}
var _stats_t := 0.0


func setup(the_hub: Node2D) -> void:
	hub = the_hub
	process_priority = 100             # after hub.gd has moved everybody
	Sprite3.ensure_sun()
	_unit.size = Vector2.ONE
	_card_shader = Shader.new()
	_card_shader.code = CARD_CODE
	_shade_shader = Shader.new()
	_shade_shader.code = SHADE_CODE
	_floor_shader = Shader.new()
	_floor_shader.code = FLOOR_CODE
	_solid_shader = Shader.new()
	_solid_shader.code = SOLID_CODE
	_water_shader = Shader.new()
	_water_shader.code = WATER_CODE
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 260.0
	add_child(cam)
	cam.current = true
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR       # the pack's colours as they were painted
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_strength = 1.05
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.2            # fires and glowing stones bloom, bright sand only a breath
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false        # shadows are flat pictures (see scripts/battle/stage.gd)
	# the light comes from behind and to the right, the way the shadows lean
	_sun.look_at_from_position(Vector3.ZERO, Vector3(LEAN.x, -1.0, LEAN.y), Vector3.UP)
	add_child(_sun)
	# the last pass: blur away from the knight, warm lights, cool shade, dark corners
	var sh := Shader.new()
	sh.code = WalkLight.POST_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_post = MeshInstance3D.new()
	_post.mesh = q
	_post.material_override = mat
	_post.extra_cull_margin = 16000.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(_post)
	_post.position = Vector3(0.0, 0.0, -1.0)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_words = Control.new()
	_words.theme = UI.theme()
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_words)


# ------------------------------------------------------------------ building a place
## Called by hub.gd at the end of enter(): shows the place it has just built.
func rebuild() -> void:
	if is_instance_valid(_world):
		_world.free()
	if is_instance_valid(_port):
		_port.free()
	for pair: Array in _twins:
		if is_instance_valid(pair[1]):
			(pair[1] as Node).free()
	_twins.clear()
	_live.clear()
	_still.clear()
	_lamps.clear()
	_glows.clear()
	_windows.clear()
	_shaft_mats.clear()
	_motes = null
	_sky_fx = null
	_known = 0
	_flies = null
	_world = Node3D.new()
	add_child(_world)
	var place: Dictionary = hub.place
	var stage: Node2D = hub._stage
	var ysort: Node2D = hub._ysort
	_outdoor = bool(place.get("outdoor", false))
	_rise = place.get("rise", {})
	_hills = place.get("hills", [])
	_has_height = not _rise.is_empty() or not _hills.is_empty()
	_window_mats.clear()
	_water_mats.clear()
	_pitch = PITCH if _outdoor else PITCH_INDOORS
	var tilt := deg_to_rad(TILT if _outdoor else TILT_INDOORS)
	# Standing things are drawn taller by exactly what the camera's slant takes away, so on the
	# screen they keep the shape the artist gave them (they looked squashed before: the owner).
	_up = Vector3(0.0, cos(tilt), -sin(tilt)) / cos(deg_to_rad(_pitch) - tilt)
	_paint_ground(stage, ysort, place)
	stage.visible = false
	hub._prompt.modulate.a = 0.0
	# standing things: the ones that never move go into batches, the rest are followed live
	var moving := {}
	if is_instance_valid(hub._hero):
		moving[hub._hero.get_instance_id()] = true
	for p: Dictionary in hub._people:
		moving[(p["node"] as Node).get_instance_id()] = true
	for r: Dictionary in hub._roamers:
		moving[(r["node"] as Node).get_instance_id()] = true
	var batches := {}
	for holder in ysort.get_children():
		if not (holder is Node2D):
			continue
		if moving.has(holder.get_instance_id()) or _has_animation(holder):
			_live[holder.get_instance_id()] = {"node": holder, "cards": {}}
		else:
			_still[holder.get_instance_id()] = true
			_batch_holder(holder, ysort, batches)
	_known = ysort.get_child_count()
	_flush(batches)
	_build_houses(place)
	_build_water(place)
	# words: signs on the ground, the "!" over people, the name of whoever is in reach
	for l in _labels_under(stage):
		_twin(l, _holder_of(l, ysort))
	_twin(hub._prompt, null)
	# light: every lamp of the place is a real light, a pool of light on the ground and a soft glow
	for pair: Array in hub._lamps:
		var two: PointLight2D = pair[0]
		var three := OmniLight3D.new()
		three.position = Vector3(two.position.x * PX, 1.1 + _height(two.position), two.position.y * PX + 0.4)
		var flame := three.position + Vector3(0.0, 0.1, 0.0)
		var base := two.position
		# the flat look draws a lamp post's light round its glass, 40 px up the picture; here the
		# light belongs AT the glass, on top of the post that stands on the ground below it
		for spot: Vector2 in place.get("torches", []):
			if absf(spot.x - two.position.x) < 6.0 and spot.y - two.position.y > 20.0 and spot.y - two.position.y < 60.0:
				base = spot
				flame = _where_at(spot) + _up * (50.0 * PX) + Vector3(0.0, 0.0, 0.05)
				three.position = flame + Vector3(0.0, -0.4, 0.5)
				break
		three.light_color = two.color
		three.omni_range = 64.0 * two.texture_scale * PX * LAMP_REACH
		three.omni_attenuation = 1.4
		three.shadow_enabled = false
		_world.add_child(three)
		_lamps.append([two, three])
		var warm := two.color.r > two.color.b
		var reach := 64.0 * two.texture_scale * PX * 0.62
		var ground := Vector3(base.x * PX, _height(base), base.y * PX + (0.3 if base == two.position else 0.15))
		var pool := WalkLight.pool(ground, reach, two.color)
		_world.add_child(pool)
		var halo := WalkLight.halo(flame, clampf(reach * 0.55, 0.9, 2.4), two.color)
		_world.add_child(halo)
		_glows.append([two, pool.material_override, halo.material_override, warm, float(_glows.size()) * 2.7])
	if _outdoor:
		_build_flies(place)
		_build_sky_fx(place)
	_sync_light()
	_sync(0.0)


## Everything flat in the place is moved into a small picture of its own and painted once;
## that picture is the floor of the 3D world.
func _paint_ground(stage: Node2D, ysort: Node2D, place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	var margin := MARGIN if _outdoor else Vector2.ZERO
	_port = SubViewport.new()
	_port.size = Vector2i(size + margin * 2.0)
	_port.transparent_bg = true
	_port.disable_3d = true
	_port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_port.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_port)
	_port.canvas_transform = Transform2D(0.0, margin)
	for c in stage.get_children():
		if c == ysort or c is Label or c is CanvasModulate or c is PointLight2D or c is CPUParticles2D:
			continue
		c.reparent(_port, false)
	# the ground tile under the painted picture (out of doors; a room is all picture)
	var base_id := String(place.get("ground", "hub_grass"))
	var base_img := Art.tex(base_id).get_image()
	if base_img.is_compressed():
		base_img.decompress()
	var whole := Vector2(base_img.get_width(), base_img.get_height())
	var tile := Rect2(0, 0, 48, 48) if base_id == "hub_grass" else Rect2(Vector2.ZERO, whole)      # (the grass sheet holds more than one tile)
	_ground_params = {
		"base_tex": ImageTexture.create_from_image(base_img),
		"base_cell": tile.size * PX,
		"base_region": Vector4(tile.position.x / whole.x, tile.position.y / whole.y, tile.size.x / whole.x, tile.size.y / whole.y),
		"base_texel": Vector2(0.5 / tile.size.x, 0.5 / tile.size.y),
		"ground_tex": _port.get_texture(),
		"ground_rect": Vector4(-margin.x * PX, -margin.y * PX, (size.x + margin.x * 2.0) * PX, (size.y + margin.y * 2.0) * PX),
		"grey": 0.12 if _outdoor else 0.0,
	}
	var mat := ShaderMaterial.new()
	mat.shader = _floor_shader
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	var floor_mesh := MeshInstance3D.new()
	if not _has_height:
		var plane := PlaneMesh.new()
		plane.size = (size + margin * 2.0) * PX
		floor_mesh.mesh = plane
		floor_mesh.position = Vector3(size.x * 0.5 * PX, 0.0, size.y * 0.5 * PX)
	else:
		floor_mesh.mesh = _grid(Rect2(-margin, size + margin * 2.0), 16.0, 0.0)      # the ground has height
	floor_mesh.material_override = mat
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(floor_mesh)
	if _outdoor:
		# the same ground far beyond the painted part, so no edge of the world shows
		var far_mat := ShaderMaterial.new()
		var far_shader := Shader.new()
		far_shader.code = Stage.GROUND_CODE
		far_mat.shader = far_shader
		var img := Art.tex(String(place.get("ground", "hub_grass"))).get_image()
		if img.is_compressed():
			img.decompress()
		far_mat.set_shader_parameter("ground_tex", ImageTexture.create_from_image(img))
		far_mat.set_shader_parameter("cell", tile.size * PX)
		far_mat.set_shader_parameter("region", _ground_params["base_region"])
		far_mat.set_shader_parameter("texel", _ground_params["base_texel"])
		far_mat.set_shader_parameter("grey", 0.12)
		var far := MeshInstance3D.new()
		if _rise.is_empty():
			var far_plane := PlaneMesh.new()
			far_plane.size = Vector2(size.x * PX + 400.0, size.y * PX + 400.0)
			far.mesh = far_plane
			far.position = Vector3(size.x * 0.5 * PX, -0.03, size.y * 0.5 * PX)
		else:
			far.mesh = _grid(Rect2(Vector2(-1200, -1200), size + Vector2(2400, 2400)), 24.0, -0.3)
		far.material_override = far_mat
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(far)


# ------------------------------------------------------------------ ground with height
## How high the ground is at a spot of the flat picture (px in, world units out). 0 everywhere
## unless the place has:
##   "rise"   north of "from" the ground climbs to "height" over "over" px, and a "mound"
##            {"at", "radius", "height"} swells out of that slope (Hollow Hill itself)
##   "hills"  [{"at", "radius", "height", "top"}]: a hill with a flat top of radius "top" (0 = a
##            round top) that falls away to nothing at "radius". People WALK on hills: they are
##            drawn as high as the ground they stand on (walking itself is still flat).
func _height(at: Vector2) -> float:
	if not _has_height:
		return 0.0
	var h := 0.0
	if not _rise.is_empty():
		var from := float(_rise.get("from", 100.0))
		var t := clampf((from - at.y) / maxf(float(_rise.get("over", 90.0)), 1.0), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		h = float(_rise.get("height", 48.0)) * t
		if _rise.has("mound"):
			var m: Dictionary = _rise["mound"]
			var d := at.distance_to(m["at"]) / float(m["radius"])
			h += float(m["height"]) * exp(-d * d) * t
	for hill: Dictionary in _hills:
		var top := float(hill.get("top", 0.0))
		var k := clampf((at.distance_to(hill["at"]) - top) / maxf(float(hill["radius"]) - top, 1.0), 0.0, 1.0)
		h += float(hill["height"]) * (1.0 - k * k * (3.0 - 2.0 * k))
	return h * PX


## How steep the ground is at a spot (0 = level; 0.3 = it climbs 3 for every 10 across).
func _slope(at: Vector2) -> float:
	if not _has_height:
		return 0.0
	var h := _height(at)
	return maxf(absf(_height(at + Vector2(8, 0)) - h), absf(_height(at + Vector2(0, 8)) - h)) * 2.0


## May a thing standing here throw its flat shadow? On level ground always; on a slope the flat
## shadow would hang in the air or sink into the hill, so only small things on gentle slopes do.
func _shadow_ok(at: Vector2, tall: float) -> bool:
	var steep := _slope(at)
	return steep < 0.1 or (tall < 2.6 and steep < 0.45)


## A floor of square cells that follows _height(). `rect` in px of the flat picture.
func _grid(rect: Rect2, cell: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(ceil(rect.size.x / cell))
	var ny := int(ceil(rect.size.y / cell))
	var rows: Array = []
	for j in ny + 1:
		var row := PackedVector3Array()
		for i in nx + 1:
			var p := rect.position + Vector2(i, j) * cell
			row.append(Vector3(p.x * PX, _height(p) + lift, p.y * PX))
		rows.append(row)
	st.set_normal(Vector3.UP)
	for j in ny:
		var near_row: PackedVector3Array = rows[j]
		var far_row: PackedVector3Array = rows[j + 1]
		for i in nx:
			for v: Vector3 in [near_row[i], near_row[i + 1], far_row[i + 1], near_row[i], far_row[i + 1], far_row[i]]:
				st.add_vertex(v)
	return st.commit()


# ------------------------------------------------------------------ houses
func _st(tex: Texture2D) -> SurfaceTool:
	var key := tex.get_rid().get_id()
	if not _surf.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surf[key] = [tex, st]
	return _surf[key][1]


## One flat face of a house: four corners (or three), their places on the texture, the way it faces.
func _face(tex: Texture2D, pts: Array, uvs: Array, normal: Vector3) -> void:
	var st := _st(tex)
	for i: int in ([0, 1, 2, 0, 2, 3] if pts.size() == 4 else [0, 1, 2]):
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


func _build_houses(place: Dictionary) -> void:
	var houses: Array = place.get("houses", [])
	if houses.is_empty():
		return
	_surf.clear()
	var shade := SurfaceTool.new()
	shade.begin(Mesh.PRIMITIVE_TRIANGLES)
	shade.set_normal(Vector3.UP)
	shade.set_uv(Vector2(0.5, 0.5))
	for h: Dictionary in houses:
		_build_house(h, shade)
	for key: int in _surf:
		var tex: Texture2D = _surf[key][0]
		var mat := ShaderMaterial.new()
		mat.shader = _solid_shader
		mat.set_shader_parameter("tex", tex)
		if tex.resource_path.contains("hub_win") or tex.resource_path.contains("hub_window"):
			_window_mats.append(mat)
		var node := MeshInstance3D.new()
		node.mesh = (_surf[key][1] as SurfaceTool).commit()
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(node)
	_surf.clear()
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var shadows := MeshInstance3D.new()
	shadows.mesh = shade.commit()
	shadows.material_override = _shade_material(ImageTexture.create_from_image(white), Vector4(0, 0, 1, 1))
	shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(shadows)


## A house: walls on three sides (the back is never seen), a roof with two slopes, a chimney,
## a door and two windows. Heights are stretched by the camera's slant, like the cards, so the
## wall art keeps the shape it was drawn with.
func _build_house(h: Dictionary, shade: SurfaceTool) -> void:
	var v := 1.0 / cos(deg_to_rad(_pitch))
	var at: Vector2 = h["at"]
	var wide := float(h.get("wide", 96.0))
	var deep := float(h.get("deep", 56.0))
	var wall := Art.tex(String(h["wall"]))
	var ws := wall.get_size()
	var cx := at.x * PX
	var cz := at.y * PX
	var w := wide * 0.5 * PX
	var d := deep * PX
	var top := ws.y * PX * v                              # where the walls end
	var rise := float(h.get("rise", 30.0)) * PX * v       # how far the ridge stands above that
	var o := 5.0 * PX                                     # the roof sticks out this far
	var u := wide / ws.x
	var us := deep / ws.x
	var front := Vector3(0, 0, 1)
	_face(wall, [Vector3(cx - w, top, cz), Vector3(cx + w, top, cz), Vector3(cx + w, 0, cz), Vector3(cx - w, 0, cz)],
		[Vector2(0, 0), Vector2(u, 0), Vector2(u, 1), Vector2(0, 1)], front)
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w
		_face(wall, [Vector3(x, top, cz), Vector3(x, top, cz - d), Vector3(x, 0, cz - d), Vector3(x, 0, cz)],
			[Vector2(0, 0), Vector2(us, 0), Vector2(us, 1), Vector2(0, 1)], Vector3(side, 0, 0))
	var roof := Art.tex(String(h.get("roof", "hub_roof_planks")))
	var rs := roof.get_size()
	var high: Array = []                                  # the roof's corners, for the shadow
	if bool(h.get("gable", false)):
		# the ridge runs from front to back: a pointed front, a slope to either side
		var eave := top - o * rise / w
		var zf := cz + o
		var zb := cz - d - o
		var ur := (deep + 10.0) / rs.x
		for side: float in [-1.0, 1.0]:
			_face(roof, [Vector3(cx, top + rise, zf), Vector3(cx, top + rise, zb), Vector3(cx + side * (w + o), eave, zb), Vector3(cx + side * (w + o), eave, zf)],
				[Vector2(0, 0), Vector2(ur, 0), Vector2(ur, 1), Vector2(0, 1)], Vector3(side * rise, w, 0).normalized())
			high.append(Vector3(cx + side * (w + o), eave, zf))
			high.append(Vector3(cx + side * (w + o), eave, zb))
		_face(wall, [Vector3(cx - w, top, cz), Vector3(cx + w, top, cz), Vector3(cx, top + rise, cz)],
			[Vector2(0, 0.72), Vector2(u, 0.72), Vector2(u * 0.5, 0.12)], front)
		high.append(Vector3(cx, top + rise, zf))
		high.append(Vector3(cx, top + rise, zb))
	else:
		# the ridge runs from side to side: one long slope faces the street
		var zr := cz - d * 0.5
		var eave := top - o * rise / (d * 0.5)
		var ur := (wide + 10.0) / rs.x
		_face(roof, [Vector3(cx - w - o, top + rise, zr), Vector3(cx + w + o, top + rise, zr), Vector3(cx + w + o, eave, cz + o), Vector3(cx - w - o, eave, cz + o)],
			[Vector2(0, 0), Vector2(ur, 0), Vector2(ur, 1), Vector2(0, 1)], Vector3(0, d * 0.5, rise).normalized())
		for side: float in [-1.0, 1.0]:
			var x := cx + side * w
			_face(wall, [Vector3(x, top, cz), Vector3(x, top, cz - d), Vector3(x, top + rise, zr)],
				[Vector2(0, 0.72), Vector2(us, 0.72), Vector2(us * 0.5, 0.12)], Vector3(side, 0, 0))
			high.append(Vector3(cx + side * (w + o), eave, cz + o))
			high.append(Vector3(cx + side * (w + o), eave, cz - d - o))
			high.append(Vector3(cx + side * (w + o), top + rise, zr))
	# the door and a window either side of it, a hair in front of the wall
	var zd := cz + 0.03
	var door := Art.tex(String(h.get("door", "hub_door_wood")))
	var ds := door.get_size()
	var full := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	_face(door, [Vector3(cx - ds.x * 0.5 * PX, ds.y * PX * v, zd), Vector3(cx + ds.x * 0.5 * PX, ds.y * PX * v, zd),
		Vector3(cx + ds.x * 0.5 * PX, 0, zd), Vector3(cx - ds.x * 0.5 * PX, 0, zd)], full, front)
	if String(h.get("windows", "")) != "":
		var win := Art.tex(String(h["windows"]))
		var wz := win.get_size()
		var y0 := float(h.get("win_up", 12.0)) * PX * v
		for side: float in [-1.0, 1.0]:
			var wx := cx + side * float(h.get("win_dx", 30.0)) * PX
			_face(win, [Vector3(wx - wz.x * 0.5 * PX, y0 + wz.y * PX * v, zd), Vector3(wx + wz.x * 0.5 * PX, y0 + wz.y * PX * v, zd),
				Vector3(wx + wz.x * 0.5 * PX, y0, zd), Vector3(wx - wz.x * 0.5 * PX, y0, zd)], full, front)
			# at night the window's light falls on the street in front of it, and glows in the air
			var lamp_colour := Color(1.0, 0.72, 0.40)
			var spill := WalkLight.pool(Vector3(wx, 0.0, cz + 0.9), 1.5, lamp_colour)
			_world.add_child(spill)
			var glow := WalkLight.halo(Vector3(wx, y0 + wz.y * PX * v * 0.5, zd + 0.05), 1.3, lamp_colour)
			_world.add_child(glow)
			_windows.append([spill.material_override, glow.material_override])
	# the shadow: the outline of the whole house as the sky light throws it on the ground
	var low := [Vector3(cx - w, 0, cz), Vector3(cx + w, 0, cz), Vector3(cx + w, 0, cz - d), Vector3(cx - w, 0, cz - d)]
	_cast(low + high, shade)
	if bool(h.get("chimney", false)):
		var stack := Art.tex("hub_chimney")
		var cs := stack.get_size()
		var bx := cx + w * 0.5
		var bz := cz - d * 0.5 - 0.3
		var hw := cs.x * 0.5 * PX
		var tip := top + rise + 10.0 * PX * v
		var foot := tip - cs.y * PX * v
		_face(stack, [Vector3(bx - hw, tip, bz + hw), Vector3(bx + hw, tip, bz + hw), Vector3(bx + hw, foot, bz + hw), Vector3(bx - hw, foot, bz + hw)], full, front)
		for side: float in [-1.0, 1.0]:
			var x := bx + side * hw * 0.8
			_face(stack, [Vector3(x, tip, bz + hw), Vector3(x, tip, bz - hw), Vector3(x, foot, bz - hw), Vector3(x, foot, bz + hw)], full, Vector3(side, 0, 0))
		_cast([Vector3(bx - hw, top, bz - hw), Vector3(bx + hw, top, bz + hw), Vector3(bx - hw, tip, bz - hw), Vector3(bx + hw, tip, bz + hw),
			Vector3(bx + hw, tip, bz - hw), Vector3(bx - hw, tip, bz + hw)], shade)
		_smoke(Vector3(bx, tip, bz))


## Adds the shadow of a solid thing to `shade`: the outline of its corners as they fall on the ground.
func _cast(corners: Array, shade: SurfaceTool) -> void:
	var flat := PackedVector2Array()
	for p: Vector3 in corners:
		flat.append(Vector2(p.x + LEAN.x * p.y, p.z + LEAN.y * p.y))
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 4:
		return
	hull.remove_at(hull.size() - 1)                # (the last point repeats the first)
	var area := 0.0
	for i in hull.size():
		var a := hull[i]
		var b := hull[(i + 1) % hull.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		hull.reverse()                             # so that the shadow faces up
	for i in range(1, hull.size() - 1):
		for q: Vector2 in [hull[0], hull[i], hull[i + 1]]:
			shade.add_vertex(Vector3(q.x, 0.022, q.y))


func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex


## Slow grey smoke from a chimney.
func _smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 9
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = at
	p.direction = Vector3(0.25, 1.0, 0.0)
	p.spread = 10.0
	p.gravity = Vector3(0.10, 0.05, 0.0)
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _dot()
	m.albedo_color = Color(0.78, 0.74, 0.70)
	m.vertex_color_use_as_albedo = true
	m.render_priority = 10             # after the blur pass
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = m
	p.mesh = q
	_world.add_child(p)


# ------------------------------------------------------------------ water
func _build_water(place: Dictionary) -> void:
	for pond: Dictionary in place.get("water", []):
		var c: Vector2 = pond["at"]
		var r: Vector2 = pond["radius"]
		var plane := PlaneMesh.new()
		plane.size = r * 2.2 * PX
		var mat := ShaderMaterial.new()
		mat.shader = _water_shader
		var node := MeshInstance3D.new()
		node.mesh = plane
		node.material_override = mat
		node.position = Vector3(c.x * PX, 0.03 + _height(c), c.y * PX)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(node)
		_water_mats.append(mat)
		for lily: Array in pond.get("lilies", []):         # flat pieces floating on it: [id, x, y]
			var tex := Art.tex(String(lily[0]))
			var leaf := PlaneMesh.new()
			leaf.size = tex.get_size() * PX
			var pad := MeshInstance3D.new()
			pad.mesh = leaf
			pad.material_override = _material(tex, Vector4(0, 0, 1, 1), Color.WHITE)
			pad.position = Vector3(float(lily[1]) * PX, 0.05 + _height(c), float(lily[2]) * PX)
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(pad)


func _has_animation(node: Node) -> bool:
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.get_frame_count(a.animation) > 1:
			return true
	for c in node.get_children():
		if _has_animation(c):
			return true
	return false


func _labels_under(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels_under(c))
	return out


func _holder_of(node: Node, ysort: Node) -> Node2D:
	var n := node
	while n != null and n.get_parent() != ysort:
		n = n.get_parent()
	return n as Node2D


# ------------------------------------------------------------------ one picture -> one card
## What a flat sprite looks like as an upright card: its texture, the part of it shown, and where
## its four corners go, measured from the foot point of the thing it belongs to (its holder).
## Returns {} for things that are not pictures (or are the round 2D shadow, which is not needed).
func _card_of(sprite: Node, holder: Node2D, ysort: Node2D) -> Dictionary:
	var tex: Texture2D = null
	var rect := Rect2()
	var flip_h := false
	var flip_v := false
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		tex = s.texture
		if tex == null or tex == EnemyScript.shadow_texture():
			return {}
		rect = s.get_rect()
		flip_h = s.flip_h
		flip_v = s.flip_v
	elif sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return {}
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return {}
		var sz := tex.get_size()
		rect = Rect2(a.offset - (sz * 0.5 if a.centered else Vector2.ZERO), sz)
		flip_h = a.flip_h
		flip_v = a.flip_v
	else:
		return {}
	var uv := Vector4(0.0, 0.0, 1.0, 1.0)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var whole := at.atlas.get_size()
		uv = Vector4(at.region.position.x / whole.x, at.region.position.y / whole.y, at.region.size.x / whole.x, at.region.size.y / whole.y)
		tex = at.atlas
	elif sprite is Sprite2D and (sprite as Sprite2D).region_enabled:
		var rr := (sprite as Sprite2D).region_rect
		var whole2 := tex.get_size()
		uv = Vector4(rr.position.x / whole2.x, rr.position.y / whole2.y, rr.size.x / whole2.x, rr.size.y / whole2.y)
	# where the sprite is, seen from its holder's foot point (the holder's own size counts too)
	var rel: Transform2D = ysort.global_transform.affine_inverse() * (sprite as Node2D).global_transform
	rel.origin -= holder.position
	var across := rel.x * rect.size.x
	var down := rel.y * rect.size.y
	if flip_h:
		across = -across
	if flip_v:
		down = -down
	var centre := rel * rect.get_center()
	var low := centre.y + absf(rel.y.y * rect.size.y) * 0.5 + absf(rel.x.y * rect.size.x) * 0.5      # the lowest point, px below the foot
	return {"tex": tex, "uv": uv, "x": _stood(across), "y": _stood(-down), "at": _stood(centre), "low": low,
		"tint": _tint_of(sprite, holder), "seen": _seen(sprite, holder)}


## A step on the flat picture (px; y down) as a step on a standing card (y up, leaned back).
func _stood(v: Vector2) -> Vector3:
	return (Vector3(v.x, 0.0, 0.0) + _up * -v.y) * PX


## Colour and see-through-ness handed down from the holder to this sprite.
func _tint_of(node: Node, holder: Node) -> Color:
	var c := Color.WHITE
	var n := node
	while n != null:
		if n is CanvasItem:
			c *= (n as CanvasItem).modulate
			if n == node:
				c *= (n as CanvasItem).self_modulate
		if n == holder:
			break
		n = n.get_parent()
	return c


## Is this sprite shown? (The whole flat picture is hidden, so each step is asked by hand.)
func _seen(node: Node, holder: Node) -> bool:
	var n := node
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		if n == holder:
			break
		n = n.get_parent()
	return true


func _sprites_under(node: Node, out: Array) -> void:
	if node is Sprite2D or node is AnimatedSprite2D:
		out.append(node)
	for c in node.get_children():
		_sprites_under(c, out)


func _shine_of(tex: Texture2D) -> float:
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


func _where(holder: Node2D) -> Vector3:
	return Vector3(holder.position.x * PX, _height(holder.position), holder.position.y * PX)


func _where_at(at: Vector2) -> Vector3:
	return Vector3(at.x * PX, _height(at), at.y * PX)


## How much a still picture sways in the wind (plants do, stone and wood do not).
func _sway_of(tex: Texture2D) -> float:
	var path := tex.resource_path
	for word: String in ["hub_tree", "hub_bush", "hub_bloom", "hub_vine", "hub_plant", "hub_dtree", "hub_dbush", "hub_planter"]:
		if path.contains(word):
			return 0.035
	return 0.0


# ------------------------------------------------------------------ things that never move
func _batch_holder(holder: Node2D, ysort: Node2D, batches: Dictionary) -> void:
	var sprites: Array = []
	_sprites_under(holder, sprites)
	var cards: Array = []
	var lift := 0.0
	for s: Node in sprites:
		var card := _card_of(s, holder, ysort)
		if card.is_empty() or not bool(card["seen"]) or (card["tint"] as Color).a < 0.4:
			continue
		cards.append(card)
		lift = maxf(lift, float(card["low"]))
	var foot := _where(holder)
	for i in cards.size():
		var card: Dictionary = cards[i]
		var tex: Texture2D = card["tex"]
		var key := "%d|%s|%s" % [tex.get_rid().get_id(), card["uv"], (card["tint"] as Color).to_html(false)]
		if not batches.has(key):
			batches[key] = {"tex": tex, "uv": card["uv"], "tint": card["tint"], "at": [], "shade": []}
		var origin := foot + (card["at"] as Vector3) + _up * (lift * PX) + Vector3(0.0, 0.0, i * 0.004)
		(batches[key]["at"] as Array).append(Transform3D(Basis(card["x"], card["y"], Vector3(0, 0, 1)), origin))
		var ok := _shadow_ok(holder.position, (card["y"] as Vector3).length())
		(batches[key]["shade"] as Array).append(_shade_transform(card, foot if ok else foot + Vector3(0, -50, 0), lift))


## A card laid down on the ground along the shadow's lean.
func _shade_transform(card: Dictionary, foot: Vector3, lift: float) -> Transform3D:
	var x: Vector3 = card["x"]
	var y: Vector3 = card["y"]
	var c: Vector3 = (card["at"] as Vector3) + _up * (lift * PX)
	return Transform3D(Basis(_laid(x), _laid(y), Vector3(0, 1, 0)), foot + _laid(c) + Vector3(0.0, 0.02, 0.0))


func _laid(v: Vector3) -> Vector3:
	return Vector3(v.x + LEAN.x * v.y, 0.0, v.z + LEAN.y * v.y)


func _material(tex: Texture2D, uv: Vector4, tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _card_shader
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("shine", _shine_of(tex))
	return mat


func _shade_material(tex: Texture2D, uv: Vector4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shade_shader
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	return mat


func _flush(batches: Dictionary) -> void:
	for key: String in batches:
		var b: Dictionary = batches[key]
		for pass_name: String in ["at", "shade"]:
			var list: Array = b[pass_name]
			var quad := _unit.duplicate() as QuadMesh
			quad.material = _material(b["tex"], b["uv"], b["tint"]) if pass_name == "at" else _shade_material(b["tex"], b["uv"])
			if pass_name == "at":
				(quad.material as ShaderMaterial).set_shader_parameter("sway", _sway_of(b["tex"]))
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(node)


# ------------------------------------------------------------------ things that move
func _new_card() -> Dictionary:
	var body := MeshInstance3D.new()
	body.mesh = _unit
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.material_override = _material(null, Vector4(0, 0, 1, 1), Color.WHITE)
	_world.add_child(body)
	var shade := MeshInstance3D.new()
	shade.mesh = _unit
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.material_override = _shade_material(null, Vector4(0, 0, 1, 1))
	_world.add_child(shade)
	return {"body": body, "shade": shade, "tex": null, "stamp": 0}


func _sync_holder(entry: Dictionary, ysort: Node2D, stamp: int) -> void:
	var holder: Node2D = entry["node"]
	var cards: Dictionary = entry["cards"]
	var sprites: Array = []
	_sprites_under(holder, sprites)
	var found: Array = []
	var lift := 0.0
	for s: Node in sprites:
		if s.is_queued_for_deletion():
			continue
		var card := _card_of(s, holder, ysort)
		if card.is_empty():
			continue
		card["id"] = s.get_instance_id()
		found.append(card)
		if bool(card["seen"]):
			lift = maxf(lift, float(card["low"]))
	var foot := _where(holder)
	for i in found.size():
		var card: Dictionary = found[i]
		var id: int = card["id"]
		if not cards.has(id):
			cards[id] = _new_card()
		var mine: Dictionary = cards[id]
		mine["stamp"] = stamp
		var body: MeshInstance3D = mine["body"]
		var shade: MeshInstance3D = mine["shade"]
		var tint: Color = card["tint"]
		var show := bool(card["seen"]) and tint.a >= 0.4
		body.visible = show
		shade.visible = show
		if not show:
			continue
		var tex: Texture2D = card["tex"]
		var bm: ShaderMaterial = body.material_override
		var sm: ShaderMaterial = shade.material_override
		if mine["tex"] != tex:
			mine["tex"] = tex
			bm.set_shader_parameter("tex", tex)
			bm.set_shader_parameter("shine", _shine_of(tex))
			sm.set_shader_parameter("tex", tex)
		bm.set_shader_parameter("uv_rect", card["uv"])
		sm.set_shader_parameter("uv_rect", card["uv"])
		bm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		body.transform = Transform3D(Basis(card["x"], card["y"], Vector3(0, 0, 1)), foot + (card["at"] as Vector3) + _up * (lift * PX) + Vector3(0.0, 0.0, i * 0.004))
		shade.transform = _shade_transform(card, foot, lift)
		if _has_height and not _shadow_ok(holder.position, (card["y"] as Vector3).length()):
			shade.visible = false
	for id: int in cards.keys():
		if int(cards[id]["stamp"]) != stamp:
			(cards[id]["body"] as Node).queue_free()
			(cards[id]["shade"] as Node).queue_free()
			cards.erase(id)


# ------------------------------------------------------------------ words
func _twin(label: Label, holder: Node2D) -> void:
	var copy := label.duplicate() as Label
	copy.visible = false
	copy.modulate = Color.WHITE
	copy.material = null
	copy.z_index = 0
	_words.add_child(copy)
	_twins.append([label, copy, holder])


func _sync_words(zoom: float) -> void:
	var ysort: Node2D = hub._ysort
	for trio: Array in _twins:
		var label: Label = trio[0]
		var copy: Label = trio[1]
		if not is_instance_valid(label) or not is_instance_valid(copy):
			continue
		var holder: Node2D = trio[2]
		var shown := label.visible and label.text != "" and (holder == null or _seen(label, holder))
		copy.visible = shown
		if not shown:
			continue
		copy.text = label.text
		var rel: Transform2D = ysort.global_transform.affine_inverse() * label.get_global_transform()
		var foot2 := rel * Vector2(label.size.x * 0.5, label.size.y)       # the middle of its bottom edge
		var p := Vector3(foot2.x * PX, 0.0, foot2.y * PX)
		if holder != null and is_instance_valid(holder):
			p = _where(holder) + _stood(foot2 - holder.position)
		copy.scale = rel.get_scale() * zoom
		copy.visible = not cam.is_position_behind(p)
		var at := cam.unproject_position(p)
		copy.position = (at - Vector2(copy.size.x * 0.5, copy.size.y) * copy.scale).round()


# ------------------------------------------------------------------ light and air
func _build_flies(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	_flies = CPUParticles3D.new()
	_flies.amount = clampi(int(size.x * size.y / 5000.0), 30, 160)
	_flies.lifetime = 7.0
	_flies.preprocess = 7.0
	_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flies.emission_box_extents = Vector3(size.x * 0.5 * PX, 1.2, size.y * 0.5 * PX)
	_flies.position = Vector3(size.x * 0.5 * PX, 1.6, size.y * 0.5 * PX)
	_flies.gravity = Vector3(0.0, 0.03, 0.0)
	_flies.direction = Vector3(1.0, 0.2, 0.0)
	_flies.spread = 180.0
	_flies.initial_velocity_min = 0.08
	_flies.initial_velocity_max = 0.3
	_flies.scale_amount_min = 0.5
	_flies.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	_flies.color_ramp = ramp
	var dot := _dot()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot
	m.albedo_color = Color(0.85, 1.0, 0.45) * 1.6
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 10             # after the blur pass (see stage.gd, lesson 3)
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = m
	_flies.mesh = q
	_world.add_child(_flies)


## Beams of sun and dust in the air, by day (they follow the spot the camera looks at).
func _build_sky_fx(place: Dictionary) -> void:
	var g := WalkLight.grade(hub.place_id, true, 1.0, _lit())
	_sky_fx = Node3D.new()
	_world.add_child(_sky_fx)
	if float(g["shafts"]) > 0.0:
		var light_dir := Vector3(LEAN.x, -1.0, LEAN.y)
		var many := 6 if (place["size"] as Vector2).x < 1200.0 else 8
		_shaft_mats = WalkLight.shafts(_sky_fx, light_dir, many, 11.0, 9.0)
	if float(g["motes"]) > 0.0:
		_motes = WalkLight.motes(Vector3(9.0, 1.4, 6.0), _dot())
		_motes.position = Vector3(0.0, 1.5, 0.0)
		_sky_fx.add_child(_motes)


## Has this land's beacon been lit (the golden dawn)?
func _lit() -> bool:
	var land := String(WalkLight.LAND.get(hub.place_id, ""))
	return land != "" and Save.hub_get("tale:lit:" + land) > 0


## The colour of the day (hub.gd's CanvasModulate) becomes the sky light, the dark and the mist.
func _sync_light() -> void:
	var sky := Color.WHITE
	if _outdoor and is_instance_valid(hub._sky_node):
		sky = (hub._sky_node as CanvasModulate).color
	var bright := clampf((sky.g - 0.55) / 0.45, 0.0, 1.0)           # 1 by day, 0 in the middle of the night
	if _outdoor:
		# By day (the owner's reference picture): a low golden sun that falls in patches, deep warm
		# shade between them, a pool of light where the knight stands. By night: even, cool, dark.
		_sun.light_color = (sky * Color(1.0, 0.90, 0.72)).lerp(sky, 1.0 - bright)
		_sun.light_energy = lerpf(0.30, 1.15, bright)
		_env.ambient_light_color = (sky * Color(0.78, 0.72, 0.80)).lerp(sky.lerp(Color(0.55, 0.65, 1.0), 0.35), 1.0 - bright)
		_env.ambient_light_energy = lerpf(0.36, 0.42, bright)
		var mist := Color(0.06, 0.10, 0.18).lerp(Color(0.62, 0.50, 0.30), bright) * sky
		_env.background_color = mist
		_env.fog_enabled = true
		_env.fog_light_color = mist
		_env.fog_density = 0.003
		_env.fog_sky_affect = 1.0
		_env.glow_bloom = lerpf(0.03, 0.10, bright)
		_env.glow_hdr_threshold = lerpf(1.2, 0.95, bright)
		_lift = 0.0
		_day = bright
	else:
		_sun.light_color = Color(1.0, 0.96, 0.9)
		_sun.light_energy = 0.6
		_env.ambient_light_color = Color(1.0, 0.95, 0.88)
		_env.ambient_light_energy = 0.55
		_env.background_color = Color("07060a")
		_env.fog_enabled = false
		_lift = 0.02
		_day = 0.0
	for mat: ShaderMaterial in _window_mats:
		mat.set_shader_parameter("shine", lerpf(1.25, 0.1, _day))       # windows glow when it is dark
	for mat: ShaderMaterial in _water_mats:
		mat.set_shader_parameter("day", _day)
		mat.set_shader_parameter("sky", Vector3(sky.r, sky.g, sky.b) * Vector3(0.62, 0.78, 0.95))
	_grade = WalkLight.grade(hub.place_id, _outdoor, _day, _lit())
	var t := Time.get_ticks_msec() / 1000.0
	var night := 1.0 - _day
	for i in _lamps.size():
		var pair: Array = _lamps[i]
		if not (is_instance_valid(pair[0]) and is_instance_valid(pair[1])):
			continue
		var two := pair[0] as PointLight2D
		var g: Array = _glows[i]
		var f := WalkLight.flicker(t, float(g[4]), bool(g[3]))
		(pair[1] as OmniLight3D).light_energy = two.energy * LAMP_ENERGY * f
		# by day a lamp barely shows on sunny ground; after dark it makes a warm circle
		(g[1] as ShaderMaterial).set_shader_parameter("strength", two.energy * lerpf(0.10, 0.55, night) * f)
		(g[2] as ShaderMaterial).set_shader_parameter("strength", two.energy * lerpf(0.10, 0.42, night) * f)
	var dark_k := night if _outdoor else 0.0
	for i in _windows.size():
		var w: Array = _windows[i]
		var f2 := WalkLight.flicker(t * 0.5, float(i) * 1.9, true)
		(w[0] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2)
		(w[1] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2)
	var beams := float(_grade.get("shafts", 0.0)) * _day
	for mat: ShaderMaterial in _shaft_mats:
		mat.set_shader_parameter("strength", 0.17 * beams)
		mat.set_shader_parameter("colour", _vec(_grade["haze"]))
	if is_instance_valid(_sky_fx):
		_sky_fx.visible = _day > 0.05
	if is_instance_valid(_motes):
		_motes.emitting = _day > 0.3
	if is_instance_valid(_flies) and is_instance_valid(hub._flies):
		_flies.emitting = (hub._flies as CPUParticles2D).emitting


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if hub == null or not is_instance_valid(hub._stage) or not is_instance_valid(_world):
		return
	_sync(delta)


func _sync(_delta: float) -> void:
	var ysort: Node2D = hub._ysort
	# somebody new has walked in since the place was built
	if ysort.get_child_count() != _known:
		_known = ysort.get_child_count()
		for holder in ysort.get_children():
			if holder is Node2D and not _live.has(holder.get_instance_id()) and not _still.has(holder.get_instance_id()):
				_live[holder.get_instance_id()] = {"node": holder, "cards": {}}
	var stamp := Engine.get_process_frames() + 1
	for id: int in _live.keys():
		var entry: Dictionary = _live[id]
		if not is_instance_valid(entry["node"]):
			for card: Dictionary in (entry["cards"] as Dictionary).values():
				(card["body"] as Node).queue_free()
				(card["shade"] as Node).queue_free()
			_live.erase(id)
			continue
		_sync_holder(entry, ysort, stamp)
	_sync_light()
	# the camera stands where the flat one does, looking down at the same spot
	var flat_cam: Camera2D = hub._cam
	var zoom := maxf(flat_cam.zoom.x, 0.05)
	var centre := flat_cam.get_screen_center_position()
	var view_h := UI.screen_size(hub).y / zoom * PX
	_dist = view_h / (2.0 * tan(deg_to_rad(FOV * 0.5))) * (WIDE if _outdoor else 1.0)
	var target := Vector3(centre.x * PX, 0.6 + _height(centre), centre.y * PX)
	var pool_at := Vector2(target.x, target.z)
	if _outdoor:
		target.z -= view_h * 0.14          # look a little past the knight: more of the distance, where the depth is
	var pitch := deg_to_rad(_pitch)
	cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * _dist
	cam.look_at(target, Vector3.UP)
	var mat: ShaderMaterial = _post.material_override
	mat.set_shader_parameter("focus", _dist)
	mat.set_shader_parameter("sharp", _dist * lerpf(0.24, 0.17, _day))
	mat.set_shader_parameter("falloff", _dist * lerpf(0.9, 0.62, _day))
	mat.set_shader_parameter("blur_px", lerpf(5.0, 7.0, _day))
	mat.set_shader_parameter("rim", lerpf(0.38, 0.48, _day))
	# the colours of the picture: amber light and brown shade by day, the old cool night otherwise
	mat.set_shader_parameter("warm", Vector3(1.07, 1.0, 0.90).lerp(Vector3(1.06, 1.01, 0.91), _day))
	mat.set_shader_parameter("shade", Vector3(0.88, 0.96, 1.12).lerp(Vector3(1.0, 0.94, 0.88), _day))
	mat.set_shader_parameter("punch", lerpf(1.0, 1.07, _day))
	mat.set_shader_parameter("rich", lerpf(1.0, 0.96, _day))
	if not _grade.is_empty():
		# the colour of this land at this time of day (scripts/fx/walk_light.gd GRADES)
		mat.set_shader_parameter("warm", _grade["warm"])
		mat.set_shader_parameter("shade", _grade["shade"])
		mat.set_shader_parameter("punch", _grade["punch"])
		mat.set_shader_parameter("rich", _grade["rich"])
		mat.set_shader_parameter("rim", _grade["rim"])
		mat.set_shader_parameter("far", _grade["far"])
		mat.set_shader_parameter("sky_glow", _day * float(_grade["shafts"]))
	if is_instance_valid(_sky_fx):
		_sky_fx.position = Vector3(target.x, _height(centre), target.z)
	_drift += _delta * 0.004
	Sprite3.set_sun(_day, 7.0, Vector2(_drift, _drift * 0.6), pool_at, _dist * 0.8, 0.95)
	mat.set_shader_parameter("lift", _lift)
	mat.set_shader_parameter("haze", _vec(_grade["haze"]) if not _grade.is_empty() else Vector3(1.0, 0.85, 0.63))
	_sync_words(zoom)
	if G.flag("lightstats"):
		# test: what the 3D look costs (draw calls are what a phone feels most)
		_stats_t += _delta
		if _stats_t > 2.0:
			_stats_t = 0.0
			print("[light] %s draws=%d objects=%d prims=%d fps=%d" % [hub.place_id,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				Engine.get_frames_per_second()])


func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
