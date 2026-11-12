extends RefCounted
## THE LIGHT of the places you walk in (used by scripts/hub/view3d.gd): the environment (tone,
## glow, mist), the sun, every lamp, fire and window light, the last pass (blur, grade, haze),
## fireflies, sun beams and dust. The colours of each land are WalkLight.GRADES
## (scripts/fx/walk_light.gd, which also makes the pools, halos and beams).
## Made by view3d.gd (`light = HdLight.new(self)`); `v` is the view.
##   setup()            the environment, the sun and the last pass (once)
##   reset()            forget the last place's lights (their nodes go with v._world)
##   build_lamps(place) / build_air(place)   the place's lights; fireflies, beams and dust
##   sync_light()       every frame: the colour of the day, flicker, windows, beams
##   sync_view(...)     every frame, after the camera moved: the last pass and the patches of sun

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")

const PX := 1.0 / 16.0
const LEAN := Vector2(-0.55, 0.5)   ## which way the sun throws shadows on the ground, per unit of height
const LAMP_ENERGY := 9.0            ## a 2D lamp of energy 1 is this strong here
const LAMP_REACH := 1.5             ## and reaches this many times as far as its 2D picture

static var _dot_tex: GradientTexture2D

var v                              ## the view (scripts/hub/view3d.gd; untyped: its members are read by name)
var env: Environment
var sun: DirectionalLight3D
var post: MeshInstance3D
var lamps: Array = []              ## [PointLight2D, OmniLight3D]
var glows: Array = []              ## per lamp: [PointLight2D, pool material, halo material, warm?, seed]
var windows: Array = []            ## [pool material, halo material]: window light that falls on the street at night
var flies: CPUParticles3D
var sky_fx: Node3D                 ## beams of sun and dust: follows the camera's spot
var shaft_mats: Array = []
var motes: CPUParticles3D
var grade := {}
var lift := 0.0                    ## how much the darks are lifted towards a warm haze (soft light)
var day := 0.0                     ## 1 = out of doors by day (patches of golden sun), 0 = night or a room
var _drift := 0.0
var _stats_t := 0.0


func _init(view) -> void:
	v = view


## A soft round speck (made by code), for smoke, fireflies and dust.
static func dot() -> GradientTexture2D:
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


func setup() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR       # the pack's colours as they were painted
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.05
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2            # fires and glowing stones bloom, bright sand only a breath
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	v.add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false        # shadows are flat pictures (see scripts/battle/stage.gd)
	# the light comes from behind and to the right, the way the shadows lean
	sun.look_at_from_position(Vector3.ZERO, Vector3(LEAN.x, -1.0, LEAN.y), Vector3.UP)
	v.add_child(sun)
	# the last pass: blur away from the knight, warm lights, cool shade, dark corners
	var sh := Shader.new()
	sh.code = WalkLight.POST_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	post = MeshInstance3D.new()
	post.mesh = q
	post.material_override = mat
	post.extra_cull_margin = 16000.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.cam.add_child(post)
	post.position = Vector3(0.0, 0.0, -1.0)


func reset() -> void:
	lamps.clear()
	glows.clear()
	windows.clear()
	shaft_mats.clear()
	motes = null
	sky_fx = null
	flies = null


## Every lamp of the place is a real light, a pool of light on the ground and a soft glow.
func build_lamps(place: Dictionary) -> void:
	var hub: Node2D = v.hub
	for pair: Array in hub._lamps:
		var two: PointLight2D = pair[0]
		var three := OmniLight3D.new()
		three.position = Vector3(two.position.x * PX, 1.1 + v.build.height(two.position), two.position.y * PX + 0.4)
		var flame := three.position + Vector3(0.0, 0.1, 0.0)
		var base := two.position
		# the flat look draws a lamp post's light round its glass, 40 px up the picture; here the
		# light belongs AT the glass, on top of the post that stands on the ground below it
		for spot: Vector2 in place.get("torches", []):
			if absf(spot.x - two.position.x) < 6.0 and spot.y - two.position.y > 20.0 and spot.y - two.position.y < 60.0:
				base = spot
				flame = v._where_at(spot) + v._up * (50.0 * PX) + Vector3(0.0, 0.0, 0.05)
				three.position = flame + Vector3(0.0, -0.4, 0.5)
				break
		three.light_color = two.color
		three.omni_range = 64.0 * two.texture_scale * PX * LAMP_REACH
		three.omni_attenuation = 1.4
		three.shadow_enabled = false
		v._world.add_child(three)
		lamps.append([two, three])
		var warm := two.color.r > two.color.b
		var reach := 64.0 * two.texture_scale * PX * 0.62
		var ground := Vector3(base.x * PX, v.build.height(base), base.y * PX + (0.3 if base == two.position else 0.15))
		var pool := WalkLight.pool(ground, reach, two.color)
		v._world.add_child(pool)
		var halo := WalkLight.halo(flame, clampf(reach * 0.55, 0.9, 2.4), two.color)
		v._world.add_child(halo)
		glows.append([two, pool.material_override, halo.material_override, warm, float(glows.size()) * 2.7])


## Out of doors: fireflies, and beams of sun and dust by day.
func build_air(place: Dictionary) -> void:
	_build_flies(place)
	_build_sky_fx(place)


func _build_flies(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	flies = CPUParticles3D.new()
	flies.amount = clampi(int(size.x * size.y / 5000.0), 30, 160)
	flies.lifetime = 7.0
	flies.preprocess = 7.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(size.x * 0.5 * PX, 1.2, size.y * 0.5 * PX)
	flies.position = Vector3(size.x * 0.5 * PX, 1.6, size.y * 0.5 * PX)
	flies.gravity = Vector3(0.0, 0.03, 0.0)
	flies.direction = Vector3(1.0, 0.2, 0.0)
	flies.spread = 180.0
	flies.initial_velocity_min = 0.08
	flies.initial_velocity_max = 0.3
	flies.scale_amount_min = 0.5
	flies.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	flies.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot()
	m.albedo_color = Color(0.85, 1.0, 0.45) * 1.6
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 10             # after the blur pass (see stage.gd, lesson 3)
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = m
	flies.mesh = q
	v._world.add_child(flies)


## Beams of sun and dust in the air, by day (they follow the spot the camera looks at).
func _build_sky_fx(place: Dictionary) -> void:
	var g := WalkLight.grade(v.hub.place_id, true, 1.0, lit())
	sky_fx = Node3D.new()
	v._world.add_child(sky_fx)
	if float(g["shafts"]) > 0.0:
		var light_dir := Vector3(LEAN.x, -1.0, LEAN.y)
		var many := 6 if (place["size"] as Vector2).x < 1200.0 else 8
		shaft_mats = WalkLight.shafts(sky_fx, light_dir, many, 11.0, 9.0)
	if float(g["motes"]) > 0.0:
		motes = WalkLight.motes(Vector3(9.0, 1.4, 6.0), dot())
		motes.position = Vector3(0.0, 1.5, 0.0)
		sky_fx.add_child(motes)


## Has this land's beacon been lit (the golden dawn)?
func lit() -> bool:
	var land := String(WalkLight.LAND.get(v.hub.place_id, ""))
	return land != "" and Save.hub_get("tale:lit:" + land) > 0


## The colour of the day (hub.gd's CanvasModulate) becomes the sky light, the dark and the mist.
func sync_light() -> void:
	var hub: Node2D = v.hub
	var outdoor: bool = v._outdoor
	var sky := Color.WHITE
	if outdoor and is_instance_valid(hub._sky_node):
		sky = (hub._sky_node as CanvasModulate).color
	var bright := clampf((sky.g - 0.55) / 0.45, 0.0, 1.0)           # 1 by day, 0 in the middle of the night
	if outdoor:
		# By day (the owner's reference picture): a low golden sun that falls in patches, deep warm
		# shade between them, a pool of light where the knight stands. By night: even, cool, dark.
		sun.light_color = (sky * Color(1.0, 0.90, 0.72)).lerp(sky, 1.0 - bright)
		sun.light_energy = lerpf(0.30, 1.15, bright)
		env.ambient_light_color = (sky * Color(0.78, 0.72, 0.80)).lerp(sky.lerp(Color(0.55, 0.65, 1.0), 0.35), 1.0 - bright)
		env.ambient_light_energy = lerpf(0.36, 0.42, bright)
		var mist := Color(0.06, 0.10, 0.18).lerp(Color(0.62, 0.50, 0.30), bright) * sky
		env.background_color = mist
		env.fog_enabled = true
		env.fog_light_color = mist
		env.fog_density = 0.003
		env.fog_sky_affect = 1.0
		env.glow_bloom = lerpf(0.03, 0.10, bright)
		env.glow_hdr_threshold = lerpf(1.2, 0.95, bright)
		lift = 0.0
		day = bright
	else:
		sun.light_color = Color(1.0, 0.96, 0.9)
		sun.light_energy = 0.6
		env.ambient_light_color = Color(1.0, 0.95, 0.88)
		env.ambient_light_energy = 0.55
		env.background_color = Color("07060a")
		env.fog_enabled = false
		lift = 0.02
		day = 0.0
	for mat: ShaderMaterial in v.build.window_mats:
		mat.set_shader_parameter("shine", lerpf(1.25, 0.1, day))       # windows glow when it is dark
	v.water.sync(day, sky)
	grade = WalkLight.grade(hub.place_id, outdoor, day, lit())
	var t := Time.get_ticks_msec() / 1000.0
	var night := 1.0 - day
	for i in lamps.size():
		var pair: Array = lamps[i]
		if not (is_instance_valid(pair[0]) and is_instance_valid(pair[1])):
			continue
		var two := pair[0] as PointLight2D
		var g: Array = glows[i]
		var f := WalkLight.flicker(t, float(g[4]), bool(g[3]))
		(pair[1] as OmniLight3D).light_energy = two.energy * LAMP_ENERGY * f
		# by day a lamp barely shows on sunny ground; after dark it makes a warm circle
		(g[1] as ShaderMaterial).set_shader_parameter("strength", two.energy * lerpf(0.10, 0.55, night) * f)
		(g[2] as ShaderMaterial).set_shader_parameter("strength", two.energy * lerpf(0.10, 0.42, night) * f)
	var dark_k := night if outdoor else 0.0
	for i in windows.size():
		var w: Array = windows[i]
		var f2 := WalkLight.flicker(t * 0.5, float(i) * 1.9, true)
		(w[0] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2)
		(w[1] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2)
	var beams := float(grade.get("shafts", 0.0)) * day
	for mat: ShaderMaterial in shaft_mats:
		mat.set_shader_parameter("strength", 0.17 * beams)
		mat.set_shader_parameter("colour", _vec(grade["haze"]))
	if is_instance_valid(sky_fx):
		sky_fx.visible = day > 0.05
	if is_instance_valid(motes):
		motes.emitting = day > 0.3
	if is_instance_valid(flies) and is_instance_valid(hub._flies):
		flies.emitting = (hub._flies as CPUParticles2D).emitting


## After the camera has moved: the last pass (blur round `dist`, the grade), the patches of sun
## round `pool_at`, the beams over `target`. `centre` is the flat camera's spot (px).
func sync_view(delta: float, dist: float, target: Vector3, centre: Vector2, pool_at: Vector2) -> void:
	var mat: ShaderMaterial = post.material_override
	mat.set_shader_parameter("focus", dist)
	mat.set_shader_parameter("sharp", dist * lerpf(0.24, 0.17, day))
	mat.set_shader_parameter("falloff", dist * lerpf(0.9, 0.62, day))
	mat.set_shader_parameter("blur_px", lerpf(5.0, 7.0, day))
	mat.set_shader_parameter("rim", lerpf(0.38, 0.48, day))
	# the colours of the picture: amber light and brown shade by day, the old cool night otherwise
	mat.set_shader_parameter("warm", Vector3(1.07, 1.0, 0.90).lerp(Vector3(1.06, 1.01, 0.91), day))
	mat.set_shader_parameter("shade", Vector3(0.88, 0.96, 1.12).lerp(Vector3(1.0, 0.94, 0.88), day))
	mat.set_shader_parameter("punch", lerpf(1.0, 1.07, day))
	mat.set_shader_parameter("rich", lerpf(1.0, 0.96, day))
	if not grade.is_empty():
		# the colour of this land at this time of day (scripts/fx/walk_light.gd GRADES)
		mat.set_shader_parameter("warm", grade["warm"])
		mat.set_shader_parameter("shade", grade["shade"])
		mat.set_shader_parameter("punch", grade["punch"])
		mat.set_shader_parameter("rich", grade["rich"])
		mat.set_shader_parameter("rim", grade["rim"])
		mat.set_shader_parameter("far", grade["far"])
		mat.set_shader_parameter("sky_glow", day * float(grade["shafts"]))
	if is_instance_valid(sky_fx):
		sky_fx.position = Vector3(target.x, v.build.height(centre), target.z)
	_drift += delta * 0.004
	Sprite3.set_sun(day, 7.0, Vector2(_drift, _drift * 0.6), pool_at, dist * 0.8, 0.95)
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("haze", _vec(grade["haze"]) if not grade.is_empty() else Vector3(1.0, 0.85, 0.63))
	if G.flag("lightstats"):
		# test: what the 3D look costs (draw calls are what a phone feels most)
		_stats_t += delta
		if _stats_t > 2.0:
			_stats_t = 0.0
			print("[light] %s draws=%d objects=%d prims=%d fps=%d" % [v.hub.place_id,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				Engine.get_frames_per_second()])


func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
