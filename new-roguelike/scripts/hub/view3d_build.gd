extends RefCounted
## THE ARCHITECTURE of the places you walk in (used by scripts/hub/view3d.gd): the ground and its
## height, real 3D houses (walls, roofs, chimneys, doors, windows) and the flat shadows they throw.
## Made by view3d.gd (`build = View3DBuild.new(self)`); `v` is the view, so `v._world` is where
## everything of the current place goes. One world unit is 16 art pixels.
##   paint_ground(stage, ysort, place)  the floor (and the far ground round it)
##   height(at) / slope(at)             the ground under a spot of the flat picture (px in, units out)
##   shadow_ok(at, tall)                may a thing standing here throw its flat shadow?
##   build_houses(place)                every row of the place's "houses"

const Stage = preload("res://scripts/battle/stage.gd")
const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const CardShader = preload("res://scripts/fx/card_shader.gd")
const HdLight = preload("res://scripts/fx/hd_light.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")
const Hd = preload("res://scripts/fx/hd.gd")

const PX := 1.0 / 16.0
const MARGIN := Vector2(336, 208)   ## how far past the edges of a place the ground is painted, px
const LEAN := HdLight.LEAN          ## which way a shadow falls on the ground, per unit of height

const FLOOR_CODE := "
shader_type spatial;
render_mode specular_disabled;
" + Sprite3.SUN_PART + CardShader.FLOOR_PART + "
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = ground_colour(at);
	ROUGHNESS = 1.0;
	sun_share = sun_at(at);
}
" + CardShader.SUN_LIGHT
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

var v                              ## the view (scripts/hub/view3d.gd; untyped: its members are read by name)
var port: SubViewport              ## paints the flat ground once
var ground_params := {}            ## the floor's shader settings (flat shadows need them too)
var rise_row := {}                 ## the place's "rise" (the ground climbs behind it), or {}
var hills: Array = []              ## the place's "hills"
var has_height := false
var window_mats: Array = []        ## window materials: they glow at night
var _surf := {}                    ## texture id -> [Texture2D, SurfaceTool]: the houses being built
var _floor_shader: Shader
var _solid_shader: Shader


func _init(view) -> void:
	v = view
	_floor_shader = Shader.new()
	_floor_shader.code = FLOOR_CODE
	_solid_shader = Shader.new()
	_solid_shader.code = SOLID_CODE


## Forgets the last place (its nodes are freed with v._world) and reads the new one's depth.
func reset(place: Dictionary) -> void:
	if is_instance_valid(port):
		port.free()
	rise_row = place.get("rise", {})
	hills = place.get("hills", [])
	has_height = not rise_row.is_empty() or not hills.is_empty()
	window_mats.clear()


## Everything flat in the place is moved into a small picture of its own and painted once;
## that picture is the floor of the 3D world.
func paint_ground(stage: Node2D, ysort: Node2D, place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	var margin := MARGIN if v._outdoor else Vector2.ZERO
	port = SubViewport.new()
	port.size = Vector2i(size + margin * 2.0)
	port.transparent_bg = true
	port.disable_3d = true
	port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	v.add_child(port)
	port.canvas_transform = Transform2D(0.0, margin)
	for c in stage.get_children():
		if c == ysort or c is Label or c is CanvasModulate or c is PointLight2D or c is CPUParticles2D:
			continue
		c.reparent(port, false)
	# the ground tile under the painted picture (out of doors; a room is all picture)
	var base_id := String(place.get("ground", "hub_grass"))
	var base_img := Art.tex(base_id).get_image()
	if base_img.is_compressed():
		base_img.decompress()
	var whole := Vector2(base_img.get_width(), base_img.get_height())
	var tile := Rect2(0, 0, 48, 48) if base_id == "hub_grass" else Rect2(Vector2.ZERO, whole)      # (the grass sheet holds more than one tile)
	ground_params = {
		"base_tex": ImageTexture.create_from_image(base_img),
		"base_cell": tile.size * PX,
		"base_region": Vector4(tile.position.x / whole.x, tile.position.y / whole.y, tile.size.x / whole.x, tile.size.y / whole.y),
		"base_texel": Vector2(0.5 / tile.size.x, 0.5 / tile.size.y),
		"ground_tex": port.get_texture(),
		"ground_rect": Vector4(-margin.x * PX, -margin.y * PX, (size.x + margin.x * 2.0) * PX, (size.y + margin.y * 2.0) * PX),
		"grey": 0.12 if v._outdoor else 0.0,
	}
	var mat := ShaderMaterial.new()
	mat.shader = _floor_shader
	for k: String in ground_params:
		mat.set_shader_parameter(k, ground_params[k])
	var floor_mesh := MeshInstance3D.new()
	if not has_height:
		var plane := PlaneMesh.new()
		plane.size = (size + margin * 2.0) * PX
		floor_mesh.mesh = plane
		floor_mesh.position = Vector3(size.x * 0.5 * PX, 0.0, size.y * 0.5 * PX)
	else:
		floor_mesh.mesh = grid(Rect2(-margin, size + margin * 2.0), 16.0, 0.0)      # the ground has height
	floor_mesh.material_override = mat
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v._world.add_child(floor_mesh)
	if v._outdoor:
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
		far_mat.set_shader_parameter("region", ground_params["base_region"])
		far_mat.set_shader_parameter("texel", ground_params["base_texel"])
		far_mat.set_shader_parameter("grey", 0.12)
		var far := MeshInstance3D.new()
		if rise_row.is_empty():
			var far_plane := PlaneMesh.new()
			far_plane.size = Vector2(size.x * PX + 400.0, size.y * PX + 400.0)
			far.mesh = far_plane
			far.position = Vector3(size.x * 0.5 * PX, -0.03, size.y * 0.5 * PX)
		else:
			far.mesh = grid(Rect2(Vector2(-1200, -1200), size + Vector2(2400, 2400)), 24.0, -0.3)
		far.material_override = far_mat
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v._world.add_child(far)

# ------------------------------------------------------------------ ground with height
## How high the ground is at a spot of the flat picture (px in, world units out). 0 everywhere
## unless the place has:
##   "rise"   north of "from" the ground climbs to "height" over "over" px, and a "mound"
##            {"at", "radius", "height"} swells out of that slope (Hollow Hill itself)
##   "hills"  [{"at", "radius", "height", "top"}]: a hill with a flat top of radius "top" (0 = a
##            round top) that falls away to nothing at "radius". People WALK on hills: they are
##            drawn as high as the ground they stand on (walking itself is still flat).
func height(at: Vector2) -> float:
	if not has_height:
		return 0.0
	var h := 0.0
	if not rise_row.is_empty():
		var from := float(rise_row.get("from", 100.0))
		var t := clampf((from - at.y) / maxf(float(rise_row.get("over", 90.0)), 1.0), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		h = float(rise_row.get("height", 48.0)) * t
		if rise_row.has("mound"):
			var m: Dictionary = rise_row["mound"]
			var d := at.distance_to(m["at"]) / float(m["radius"])
			h += float(m["height"]) * exp(-d * d) * t
	for hill: Dictionary in hills:
		var top := float(hill.get("top", 0.0))
		var k := clampf((at.distance_to(hill["at"]) - top) / maxf(float(hill["radius"]) - top, 1.0), 0.0, 1.0)
		h += float(hill["height"]) * (1.0 - k * k * (3.0 - 2.0 * k))
	return h * PX


## How steep the ground is at a spot (0 = level; 0.3 = it climbs 3 for every 10 across).
func slope(at: Vector2) -> float:
	if not has_height:
		return 0.0
	var h := height(at)
	return maxf(absf(height(at + Vector2(8, 0)) - h), absf(height(at + Vector2(0, 8)) - h)) * 2.0


## May a thing standing here throw its flat shadow? On level ground always; on a slope the flat
## shadow would hang in the air or sink into the hill, so only small things on gentle slopes do.
func shadow_ok(at: Vector2, tall: float) -> bool:
	var steep := slope(at)
	return steep < 0.1 or (tall < 2.6 and steep < 0.45)


## A floor of square cells that follows height(). `rect` in px of the flat picture.
func grid(rect: Rect2, cell: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(ceil(rect.size.x / cell))
	var ny := int(ceil(rect.size.y / cell))
	var rows: Array = []
	for j in ny + 1:
		var row := PackedVector3Array()
		for i in nx + 1:
			var p := rect.position + Vector2(i, j) * cell
			row.append(Vector3(p.x * PX, height(p) + lift, p.y * PX))
		rows.append(row)
	st.set_normal(Vector3.UP)
	for j in ny:
		var near_row: PackedVector3Array = rows[j]
		var far_row: PackedVector3Array = rows[j + 1]
		for i in nx:
			for q: Vector3 in [near_row[i], near_row[i + 1], far_row[i + 1], near_row[i], far_row[i + 1], far_row[i]]:
				st.add_vertex(q)
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


func build_houses(place: Dictionary) -> void:
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
			window_mats.append(mat)
		var node := MeshInstance3D.new()
		node.mesh = (_surf[key][1] as SurfaceTool).commit()
		node.material_override = mat
		node.cast_shadow = CardShader.casts()            # HD: houses throw real shadows (on people too)
		v._world.add_child(node)
	_surf.clear()
	if Hd.on():
		return                                           # (no flat shadow copies then)
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var shadows := MeshInstance3D.new()
	shadows.mesh = shade.commit()
	shadows.material_override = CardShader.shade(ground_params, ImageTexture.create_from_image(white), Vector4(0, 0, 1, 1))
	shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v._world.add_child(shadows)


## A house: walls on three sides (the back is never seen), a roof with two slopes, a chimney,
## a door and two windows. Heights are stretched by the camera's slant, like the cards, so the
## wall art keeps the shape it was drawn with.
func _build_house(h: Dictionary, shade: SurfaceTool) -> void:
	var vs := 1.0 / cos(deg_to_rad(v._pitch))
	var at: Vector2 = h["at"]
	var wide := float(h.get("wide", 96.0))
	var deep := float(h.get("deep", 56.0))
	var wall := Art.tex(String(h["wall"]))
	var ws := wall.get_size()
	var cx := at.x * PX
	var cz := at.y * PX
	var w := wide * 0.5 * PX
	var d := deep * PX
	var top := ws.y * PX * vs                              # where the walls end
	var rise := float(h.get("rise", 30.0)) * PX * vs       # how far the ridge stands above that
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
	_face(door, [Vector3(cx - ds.x * 0.5 * PX, ds.y * PX * vs, zd), Vector3(cx + ds.x * 0.5 * PX, ds.y * PX * vs, zd),
		Vector3(cx + ds.x * 0.5 * PX, 0, zd), Vector3(cx - ds.x * 0.5 * PX, 0, zd)], full, front)
	if String(h.get("windows", "")) != "":
		var win := Art.tex(String(h["windows"]))
		var wz := win.get_size()
		var y0 := float(h.get("win_up", 12.0)) * PX * vs
		for side: float in [-1.0, 1.0]:
			var wx := cx + side * float(h.get("win_dx", 30.0)) * PX
			_face(win, [Vector3(wx - wz.x * 0.5 * PX, y0 + wz.y * PX * vs, zd), Vector3(wx + wz.x * 0.5 * PX, y0 + wz.y * PX * vs, zd),
				Vector3(wx + wz.x * 0.5 * PX, y0, zd), Vector3(wx - wz.x * 0.5 * PX, y0, zd)], full, front)
			# at night the window's light falls on the street in front of it, and glows in the air
			var lamp_colour := Color(1.0, 0.72, 0.40)
			var spill := WalkLight.pool(Vector3(wx, 0.0, cz + 0.9), 1.5, lamp_colour)
			v._world.add_child(spill)
			var glow := WalkLight.halo(Vector3(wx, y0 + wz.y * PX * vs * 0.5, zd + 0.05), 1.3, lamp_colour)
			v._world.add_child(glow)
			v.light.windows.append([spill.material_override, glow.material_override])
	# the shadow: the outline of the whole house as the sky light throws it on the ground
	var low := [Vector3(cx - w, 0, cz), Vector3(cx + w, 0, cz), Vector3(cx + w, 0, cz - d), Vector3(cx - w, 0, cz - d)]
	_cast(low + high, shade)
	if bool(h.get("chimney", false)):
		var stack := Art.tex("hub_chimney")
		var cs := stack.get_size()
		var bx := cx + w * 0.5
		var bz := cz - d * 0.5 - 0.3
		var hw := cs.x * 0.5 * PX
		var tip := top + rise + 10.0 * PX * vs
		var foot := tip - cs.y * PX * vs
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
	m.albedo_texture = HdLight.dot()
	m.albedo_color = Color(0.78, 0.74, 0.70)
	m.vertex_color_use_as_albedo = true
	m.render_priority = 10             # after the blur pass
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = m
	p.mesh = q
	v._world.add_child(p)
