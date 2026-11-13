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
## HD (Forward+ on PC, `Hd.on()`): the same place lit for real: a sun with soft shadow maps
## (everything standing throws its shadow, houses and trees shade people), warm lamps whose nearest
## few throw shadows too, AgX tone, SSAO and SSIL, wide bloom over a hot threshold so flames BLAZE,
## thin volumetric fog that the sun's beams and the lamps' halos really cut through, and the
## camera's own depth of field: blur far behind the people and in front of them, never ON them
## (the band in focus is stretched every frame to hold every person in view, `_focus_band`).
## Without HD (the phone, `--nohd`) everything stays as it was: flat shadows and the blur pass.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")
const Hd = preload("res://scripts/fx/hd.gd")

const PX := 1.0 / 16.0
const LEAN := Vector2(-0.55, 0.5)   ## which way the sun throws shadows on the ground, per unit of height
const LAMP_ENERGY := 9.0            ## a 2D lamp of energy 1 is this strong here
const LAMP_REACH := 1.5             ## and reaches this many times as far as its 2D picture
## HD: the sun is LOW (late afternoon): long raking shadows, so it leans further than the flat look's
const HD_LEAN := Vector2(-0.82, 0.76)
## HD numbers (all in one place to tune by eye)
const HD_SHADOW_LAMPS := 4          ## this many lamps nearest the knight throw real shadows
const HD_SUN_DAY := 4.2             ## the sun by day (it is the key light: warm and hard)
const HD_SUN_COLOUR := Color(1.0, 0.66, 0.36)   ## deep amber: the sun low over the land at dusk
const HD_SUN_COLOUR_DAY := Color(1.0, 0.86, 0.64)   ## and in the full afternoon: golden, so a day reads as DAY
const HD_SUN_NIGHT := 0.35          ## the moon
const HD_AMBIENT_DAY := 0.19        ## the shade by day: deep, so the sun reads (but faces in shade still read)
const HD_AMBIENT_NIGHT := 0.16
const HD_LAMP := 1.0                ## lamps are this much stronger than in the flat look (2.8 burned the ground white)
const HD_LAMP_DECAY := 1.9          ## HD: how fast a lamp's light falls off (2 = as real light: a hot pool, deep shade round it)
const HD_LAMP_AMBER := Color(1.0, 0.56, 0.24)   ## HD: warm lamps and fires are pulled this far towards amber (40%)
const HD_LAMP_REACH := 2.5          ## HD: a lamp's light reaches this many times as far as its 2D picture
const HD_POOL_REACH := 1.0          ## HD: its warm pool on the ground (the flat look: 0.62)
const HD_FOG_DAY := 0.0016          ## volumetric fog: very thin by day (no milky veil; beams only far off), ...
const HD_FOG_NIGHT := 0.009         ## ... a little thicker at night (halos round every lamp)
const HD_HAZE_DAY := 0.09           ## the sunlit air behind the play by day (times the grade's "shafts")
const HD_HAZE_NIGHT := 0.012        ## ... and at night
const HD_FOG_LENGTH := 40.0         ## the volumetric fog ends this far from the camera (else a wide view is a sheet of fog)
const HD_DAPPLE := 1.6             ## how far apart sun and shade patches are (times the grade's "dapple": 0 on open sand)
const HD_EXPOSURE_DAY := 0.95
const HD_EXPOSURE_NIGHT := 1.3
const HD_DOF := 0.22                ## how strong the depth of field is (0 = none)
const HD_ROOM_DOF := 0.06

static var _dot_tex: GradientTexture2D
static var _exposure_ready := false

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
var haze_mat: FogMaterial          ## HD: the band of sunlit air behind the play (`_build_haze`)
var grade := {}
var lift := 0.0                    ## how much the darks are lifted towards a warm haze (soft light)
var day := 0.0                     ## 1 = out of doors by day (patches of golden sun), 0 = night or a room
var attrs: CameraAttributesPractical  ## HD: the camera's depth of field
var _band := Vector2.ZERO          ## HD: the distances in focus now (eased towards the wanted band)
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
	if Hd.on():
		_setup_hd(mat)


## HD: the real light of a PC (see the top of this file).
func _setup_hd(post_mat: ShaderMaterial) -> void:
	if not _exposure_ready:
		# the exposure, for the people's shader (scripts/fx/card_shader.gd keeps them from burning white)
		_exposure_ready = true
		RenderingServer.global_shader_parameter_add(&"hh_exposure", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = HD_EXPOSURE_DAY
	env.tonemap_agx_contrast = 1.35
	env.tonemap_agx_white = 14.0            # a hot core keeps its hue (gold), it does not go to white at once
	# ACES: hot lamps and fires keep their amber and orange far up the curve (AgX greys them to
	# white), and the shade sinks deep: the blazing look of the reference pictures
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	if G.arg("tone") == "agx":              # test: the round-one tone curve, to compare
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_light_affect = 0.1
	env.ssil_enabled = true
	env.ssil_radius = 3.5
	env.ssil_intensity = 0.5                # bounce light, but the shade stays dark
	# bloom: the cores of flames and lamps burn white and spill a wide soft glow, like a lens
	env.glow_enabled = true
	env.glow_normalized = false
	for i in 7:
		env.set_glow_level(i, [0.0, 0.25, 0.6, 0.9, 1.0, 0.9, 0.6][i])
	env.glow_intensity = 0.42
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# the air: light that scatters forwards, so the low sun behind the place glows through it
	env.fog_enabled = false
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = HD_FOG_DAY
	env.volumetric_fog_anisotropy = 0.4         # (the sun comes from behind and to the side: some light must scatter sideways to the eye)
	env.volumetric_fog_length = HD_FOG_LENGTH
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_ambient_inject = 0.02    # the shade does not glow: only the sun and the lamps light the air
	env.volumetric_fog_sky_affect = 0.0
	# the ponds mirror what stands round them (screen-space reflections: only the water is smooth
	# enough to show them, scripts/hub/view3d_water.gd)
	env.ssr_enabled = true
	env.ssr_max_steps = 72
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 1.6
	env.ssr_depth_tolerance = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.look_at_from_position(Vector3.ZERO, Vector3(HD_LEAN.x, -1.0, HD_LEAN.y), Vector3.UP)
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.2               # (0.6 lifted a figure's shadow off its feet)
	sun.shadow_blur = 0.9
	sun.light_angular_distance = 1.6            # soft edges that widen away from the thing that throws them
	sun.light_volumetric_fog_energy = 0.7
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	# (the soft edges are a disc of samples turned at random per pixel: few samples = grain; a PC
	# affords the most, so the penumbras are smooth gradients, not sand)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_amount = HD_DOF
	v.cam.attributes = attrs
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
	post_mat.set_shader_parameter("blur_on", 0.0)
	post_mat.set_shader_parameter("linear_in", 1.0)


func reset() -> void:
	lamps.clear()
	glows.clear()
	windows.clear()
	shaft_mats.clear()
	motes = null
	haze_mat = null
	sky_fx = null
	flies = null
	_band = Vector2.ZERO


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
		# the pack's lantern on an arm (hub_slantern): its light hangs 15 px to the side, 33 px up
		var ground_at := Vector2.INF
		for row: Array in place.get("props", []):
			if String(row[0]) != "hub_slantern":
				continue
			var foot := Vector2(row[1], row[2])
			var side := -15.0 if (row.size() > 5 and bool(row[5])) else 15.0
			if absf(foot.x + side - two.position.x) < 8.0 and foot.y - two.position.y > 20.0 and foot.y - two.position.y < 45.0:
				base = foot
				ground_at = foot + Vector2(side, 0.0)
				flame = v._where_at(foot) + v._stood(Vector2(side, -27.0)) + Vector3(0.0, 0.0, 0.08)
				three.position = flame + Vector3(0.0, -0.15, 0.45)
				break
		var warm := two.color.r > two.color.b
		# (HD: a warm lamp is AMBER, not a pale cream that the tone curve turns white)
		var colour := two.color.lerp(HD_LAMP_AMBER, 0.4) if warm and Hd.on() else two.color
		three.light_color = colour
		three.omni_range = 64.0 * two.texture_scale * PX * (HD_LAMP_REACH if Hd.on() else LAMP_REACH)
		three.omni_attenuation = HD_LAMP_DECAY if Hd.on() else 1.4
		three.shadow_enabled = false
		if Hd.on():
			three.light_volumetric_fog_energy = 0.8      # a halo of lit air round every lamp (more turns the air white)
			three.light_size = 0.08
			three.shadow_blur = 1.2
			three.shadow_bias = 0.08
			three.shadow_normal_bias = 1.0
		v._world.add_child(three)
		lamps.append([two, three])
		var reach := 64.0 * two.texture_scale * PX * (HD_POOL_REACH if Hd.on() else 0.62)
		var ground := Vector3(base.x * PX, v.build.height(base), base.y * PX + (0.3 if base == two.position else 0.15))
		if ground_at != Vector2.INF:
			ground = Vector3(ground_at.x * PX, v.build.height(ground_at), ground_at.y * PX + 0.2)
		var pool := WalkLight.pool(ground, reach, colour)
		v._world.add_child(pool)
		var halo := WalkLight.halo(flame, clampf(reach * 0.55, 0.9, 2.4), colour)
		v._world.add_child(halo)
		glows.append([two, pool.material_override, halo.material_override, warm, float(glows.size()) * 2.7])


## Out of doors: fireflies, and beams of sun and dust by day.
func build_air(place: Dictionary) -> void:
	_build_flies(place)
	_build_sky_fx(place)
	if Hd.on():
		_build_haze(place)


## HD: a band of thicker air BEHIND the play area (over the north row of houses and the wood at the
## back), never between the camera and the people. The low sun shines through it from behind, and
## the shadows of the roofs and trees cut real beams out of it (volumetric fog keeps the shadow
## maps); at night it is a faint blue-grey mist that the lamps light amber.
func _build_haze(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	var walk: Rect2 = place.get("walk", Rect2(Vector2.ZERO, size))
	if float(place.get("zoom", 1.0)) < 0.9:
		return                                     # the world map: seen from high up, no band behind
	var back := -8.0                               # (world units: past the north edge of the place)
	var front := (walk.position.y + walk.size.y * 0.18) * PX
	var vol := FogVolume.new()
	vol.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	vol.size = Vector3(size.x * PX + 24.0, 9.0, front - back)
	vol.position = Vector3(size.x * PX * 0.5, 3.5, (front + back) * 0.5)
	haze_mat = FogMaterial.new()
	haze_mat.density = 0.0
	haze_mat.albedo = Color(1.0, 0.92, 0.80)
	haze_mat.height_falloff = 0.18                 # thick near the ground, thin up high
	haze_mat.edge_fade = 0.35                      # no hard face where the band ends
	vol.material = haze_mat
	v._world.add_child(vol)


func _build_flies(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	flies = CPUParticles3D.new()
	flies.amount = clampi(int(size.x * size.y / 5000.0), 30, 160)
	if Hd.on():
		flies.amount = maxi(flies.amount / 3, 16)           # (HD: a few fine sparks, not dirt on the lens)
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
	q.size = Vector2(0.16, 0.16) if not Hd.on() else Vector2(0.07, 0.07)
	q.material = m
	flies.mesh = q
	v._world.add_child(flies)


## Beams of sun and dust in the air, by day (they follow the spot the camera looks at).
func _build_sky_fx(place: Dictionary) -> void:
	var g := WalkLight.grade(v.hub.place_id, true, 1.0, lit())
	sky_fx = Node3D.new()
	v._world.add_child(sky_fx)
	if float(g["shafts"]) > 0.0:
		var lean := HD_LEAN if Hd.on() else LEAN
		var light_dir := Vector3(lean.x, -1.0, lean.y)
		var many := 6 if (place["size"] as Vector2).x < 1200.0 else 8
		shaft_mats = WalkLight.shafts(sky_fx, light_dir, many, 11.0, 9.0) if not Hd.on() \
			else WalkLight.shafts(sky_fx, light_dir, 4, 12.0, 12.0, true)
	if float(g["motes"]) > 0.0:
		motes = WalkLight.motes(Vector3(9.0, 1.4, 6.0), dot())
		if Hd.on():
			motes.amount = 30
			(motes.mesh as QuadMesh).size = Vector2(0.05, 0.05)
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
	if Hd.on():
		_sync_hd(sky, outdoor)
	for mat: ShaderMaterial in v.build.window_mats:
		mat.set_shader_parameter("shine", lerpf(1.25, 0.1, day) * (2.2 if Hd.on() else 1.0))       # windows glow when it is dark
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
		(pair[1] as OmniLight3D).light_energy = two.energy * LAMP_ENERGY * f * (HD_LAMP * lerpf(0.55, 1.0, night) if Hd.on() else 1.0)
		# by day a lamp barely shows on sunny ground; after dark it makes a warm circle
		# (HD: a big hot golden puddle after dusk, against the deep shade round it)
		(g[1] as ShaderMaterial).set_shader_parameter("strength", two.energy * (lerpf(0.02, 0.22, night) if Hd.on() else lerpf(0.10, 0.55, night)) * f)
		# (HD: the bloom and the lit fog make most of the glow; the painted halo only adds a little)
		(g[2] as ShaderMaterial).set_shader_parameter("strength", two.energy * lerpf(0.10, 0.42, night) * f * (0.3 if Hd.on() else 1.0))
	RenderingServer.global_shader_parameter_set(&"hh_lamp_on", clampf(0.3 + 1.2 * night, 0.3, 1.0) if outdoor else 1.0)
	var dark_k := night if outdoor else 0.0
	for i in windows.size():
		var w: Array = windows[i]
		var f2 := WalkLight.flicker(t * 0.5, float(i) * 1.9, true)
		(w[0] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2)
		(w[1] as ShaderMaterial).set_shader_parameter("strength", 0.30 * dark_k * f2 * (0.4 if Hd.on() else 1.0))
	var beams := float(grade.get("shafts", 0.0)) * day
	if haze_mat != null:
		haze_mat.density = HD_HAZE_DAY * beams + HD_HAZE_NIGHT * night * (1.0 if outdoor else 0.0)
		haze_mat.albedo = Color(1.0, 0.92, 0.80).lerp(Color(0.80, 0.78, 0.80), night)
	for mat: ShaderMaterial in shaft_mats:
		mat.set_shader_parameter("strength", (0.07 if Hd.on() else 0.17) * beams)
		# (HD: warm sunlight, not the grey of the distance)
		mat.set_shader_parameter("colour", _vec((grade["haze"] as Color).lerp(Color(1.0, 0.78, 0.45), 0.6) if Hd.on() else grade["haze"]))
	if is_instance_valid(sky_fx):
		sky_fx.visible = day > 0.05
	if is_instance_valid(motes):
		motes.emitting = day > 0.3
	if is_instance_valid(flies) and is_instance_valid(hub._flies):
		flies.emitting = (hub._flies as CPUParticles2D).emitting


## After the camera has moved: the last pass (blur round `dist`, the grade), the patches of sun
## round `pool_at`, the beams over `target`. `centre` is the flat camera's spot (px).
func sync_view(delta: float, dist: float, target: Vector3, centre: Vector2, pool_at: Vector2, people: Array = []) -> void:
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
		mat.set_shader_parameter("rim", float(grade["rim"]) * (1.2 if Hd.on() else 1.0))
		# HD: the camera's blur melts the distance; the haze only tints it (else a milky veil)
		mat.set_shader_parameter("far", float(grade["far"]) * (0.32 if Hd.on() else 1.0))
		mat.set_shader_parameter("sky_glow", day * float(grade["shafts"]) * (0.4 if Hd.on() else 1.0))
	if is_instance_valid(sky_fx):
		sky_fx.position = Vector3(target.x, v.build.height(centre), target.z)
	_drift += delta * 0.004
	# HD: the patches are pushed further apart (deep shade between pools of blazing sun); the pool
	# round the knight keeps him in the light
	if Hd.on():
		# only where something could cast it (leaves): none on open sand or a town square, where the
		# real shadow maps do the shade (GRADES "dapple")
		var dap := float(grade.get("dapple", 0.5)) if not grade.is_empty() else 0.0
		Sprite3.set_sun(day * HD_DAPPLE * dap, 6.0, Vector2(_drift, _drift * 0.6), pool_at, dist * 0.34, 0.9)
	else:
		Sprite3.set_sun(day, 7.0, Vector2(_drift, _drift * 0.6), pool_at, dist * 0.8, 0.95)
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("haze", _vec(grade["haze"]) if not grade.is_empty() else Vector3(1.0, 0.85, 0.63))
	if Hd.on():
		_focus_band(delta, dist, target, people, mat)
	if G.flag("lightstats"):
		# test: what the 3D look costs (draw calls are what a phone feels most)
		_stats_t += delta
		if _stats_t > 2.0:
			_stats_t = 0.0
			print("[light] %s day=%.2f hd=%s draws=%d objects=%d prims=%d fps=%d" % [v.hub.place_id, day, Hd.on(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				Engine.get_frames_per_second()])


func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


# ------------------------------------------------------------------ HD
## HD, every frame: the sun, the shade, the air and which lamps throw shadows.
func _sync_hd(sky: Color, outdoor: bool) -> void:
	var night := 1.0 - day
	if outdoor:
		sun.light_energy = lerpf(HD_SUN_NIGHT, HD_SUN_DAY, day)
		# full day: a golden afternoon sun; towards dusk it sinks to deep amber; the moon is blue
		var amber := HD_SUN_COLOUR_DAY.lerp(HD_SUN_COLOUR, clampf(night * 1.8, 0.0, 1.0))
		sun.light_color = sky.lerp(amber, 0.7).lerp(Color(0.62, 0.72, 1.0), smoothstep(0.55, 1.0, night))
		env.ambient_light_energy = lerpf(HD_AMBIENT_NIGHT, HD_AMBIENT_DAY, day) * float(grade.get("ambient", 1.0))
		env.ambient_light_color = Color(0.62, 0.56, 0.62).lerp(Color(0.42, 0.50, 0.78), night)
		var haze: Color = grade.get("haze", Color(1.0, 0.86, 0.62)) if not grade.is_empty() else Color(1.0, 0.86, 0.62)
		env.volumetric_fog_density = lerpf(HD_FOG_NIGHT, HD_FOG_DAY, day)
		# (at night the air is a warm grey: the moon makes it blue, a lamp makes it amber, never white)
		env.volumetric_fog_albedo = haze.lerp(Color(0.78, 0.74, 0.70), night)
		sun.light_volumetric_fog_energy = lerpf(0.25, 1.6, day)      # (the air is thin except in the band behind the play)
		env.tonemap_exposure = lerpf(HD_EXPOSURE_NIGHT, HD_EXPOSURE_DAY, day) * float(grade.get("exposure", 1.0))
	else:
		sun.light_energy = 0.9
		env.ambient_light_energy = 0.42
		env.volumetric_fog_density = 0.004
		env.volumetric_fog_albedo = Color(0.9, 0.75, 0.6)
		sun.light_volumetric_fog_energy = 0.2
		env.tonemap_exposure = 1.2
	# NO MILKY VEIL: sync_light() sets the flat look's bloom and depth mist each frame; in HD the
	# bloom is only for what burns over the threshold (no blurred copy of the whole picture added on
	# top) and the volumetric fog is the only air (the depth mist would wash out the shade again)
	RenderingServer.global_shader_parameter_set(&"hh_exposure", env.tonemap_exposure)
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = false
	env.volumetric_fog_ambient_inject = 0.02
	# the nearest lamps throw real shadows (a shadow map each costs, so only a few)
	var at: Vector3 = v.cam.global_position
	var order: Array = []
	for i in lamps.size():
		var three: OmniLight3D = lamps[i][1]
		if is_instance_valid(three):
			order.append([three.global_position.distance_squared_to(at), three])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in order.size():
		(order[i][1] as OmniLight3D).shadow_enabled = i < HD_SHADOW_LAMPS


## HD: the depth of field. Everything between the nearest and the farthest person in view (and a
## band round the knight) stays sharp; scenery further back melts away, and so does anything
## standing between the camera and the people (the near blur). Eased, so it never jumps.
func _focus_band(delta: float, dist: float, target: Vector3, people: Array, mat: ShaderMaterial) -> void:
	var cam: Camera3D = v.cam
	var to_view := cam.global_transform.affine_inverse()
	var near := dist * 0.80
	var far := dist * 1.22
	# the near edge of the band is the SOUTH edge of the walking area (whatever stands past it, a
	# fence or a bush between the camera and the play, melts away); never the nearest person, which
	# would pull the band almost to the camera whenever somebody walks at the bottom of the picture
	var walk: Rect2 = v.hub.place.get("walk", Rect2())
	var fore_z := 0.0
	if walk.size.y > 0.0 and v._outdoor:
		var edge := Vector3(target.x, target.y - 0.6, (walk.end.y + 6.0) * PX)
		near = -(to_view * edge).z - 0.4
		fore_z = near
	for p: Vector3 in people:
		for h: float in [0.0, 1.8]:
			var q := p + Vector3(0.0, h, 0.0)
			if not cam.is_position_in_frustum(q):
				continue
			var z := -(to_view * q).z
			near = minf(near, z - 0.6)
			far = maxf(far, z + 2.5)
	var aim := -(to_view * target).z
	near = minf(near, aim - dist * 0.2)
	far = maxf(far, aim + dist * 0.2)
	var want := Vector2(maxf(near, 1.0), far)
	_band = want if _band == Vector2.ZERO else _band.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	attrs.dof_blur_near_distance = _band.x
	attrs.dof_blur_near_transition = dist * 0.06
	attrs.dof_blur_far_distance = _band.y
	attrs.dof_blur_far_transition = dist * 0.25
	attrs.dof_blur_amount = HD_DOF if v._outdoor else HD_ROOM_DOF
	# whatever stands nearer than the walking area (between the camera and the play) is put in shade,
	# cooler and greyer: a dark blurred frame round the lit middle, as in a real photograph
	mat.set_shader_parameter("fore_z", minf(fore_z, _band.x + 0.4) if fore_z > 0.0 else 0.0)
	# the haze of the last pass begins where the blur begins
	var mid := (_band.x + _band.y) * 0.5
	mat.set_shader_parameter("focus", mid)
	mat.set_shader_parameter("sharp", (_band.y - _band.x) * 0.5)
	mat.set_shader_parameter("falloff", dist * 0.5)
	env.volumetric_fog_length = minf(maxf(_band.y + dist * 0.5, 24.0), HD_FOG_LENGTH)
