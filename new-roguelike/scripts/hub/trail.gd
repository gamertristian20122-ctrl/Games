extends Node3D
## THE FAIRY DUST (v0.28.0): glittering dust on the ground that leads the knight to where the story
## wants him next (scripts/data/tale.gd TRAIL), through doors and across the world map.
## It is code-made light (small soft stars), no picture. Settings > Fairy dust turns it off.
## HOW IT WORKS
##   where()   the goal of the story now: the place and the spot. In another place, the spot is the
##             door that leads towards it (found by walking the places' exits, nearest door first).
##   a grid    the place is cut into 12 px cells; cells under walls, furniture, trees and water are
##             shut (the same things hub.gd stops the knight with), so the dust goes AROUND them.
##   the dust  about 30 specks laid along the first stretch of that way, drifting towards the goal,
##             fading out with distance, twinkling. Seen only when the knight walks or stands free.
## view3d.gd makes one of these per place (it is freed with the place) and it follows every frame.

const Places = preload("res://scripts/data/places.gd")
const Tale = preload("res://scripts/data/tale.gd")

const CELL := 12.0
const COUNT := 44
const SPACING := 11.0            ## art pixels between two specks
const REACH := 330.0             ## how far ahead of the knight the dust is seen
const GAP := 20.0                ## nothing within this of the knight's feet
const DRIFT := 15.0              ## art pixels a second the dust slides towards the goal

var hub: Node2D
var view: Node3D
var _mm: MultiMesh
var _grid: AStarGrid2D
var _goal := {}                  ## {"to": Vector2, "stop": float} from where(), {} = no dust
var _path := PackedVector2Array()
var _cum := PackedFloat32Array()  ## the path's length up to each point
var _total := 0.0
var _from := Vector2.INF         ## where the knight stood when the path was last made
var _redo := 0.0
var _t := 0.0
var _show := 0.0                 ## 0..1: fades in and out
var _k := 1.0


## The spot the dust leads to from this place, for the story's step now. {} = none. "to" is a point
## of this place; "stop" is how near the knight may come before the dust is no longer needed.
static func where(from: String, step: int) -> Dictionary:
	var row: Array = Tale.TRAIL.get(step, [])
	if row.is_empty():
		return {}
	var goal := String(row[0])
	var who := String(row[1])
	var cache := {}
	if from == goal:
		if who == "":
			return {}
		for p: Dictionary in _place(goal, cache).get("people", []):
			if String(p["id"]) == who and p.has("pos"):
				return {"to": p["pos"], "stop": 34.0}
		return {}
	# the door that leads towards the goal: a walk through the exits, nearest first
	var first := {}                                     # place id -> the door of `from` that starts the way there
	var queue: Array = [from]
	var seen := {from: true}
	var at := 0
	while at < queue.size():
		var id := String(queue[at])
		at += 1
		for e: Dictionary in _place(id, cache).get("exits", []):
			var to := String(e["to"])
			# shut roads are no way (the old story's roads, and roads of a later step)
			if seen.has(to) or String(e.get("need", "")) != "" or int(e.get("tale", 0)) > step:
				continue
			seen[to] = true
			first[to] = e if id == from else first[id]
			if to == goal:
				var rect: Rect2 = (first[to] as Dictionary)["rect"]
				return {"to": rect.get_center(), "stop": 8.0}
			queue.append(to)
	return {}


static func _place(id: String, cache: Dictionary) -> Dictionary:
	if not cache.has(id):
		cache[id] = Places.get_place(id)
	return cache[id]


func setup(the_hub: Node2D, the_view: Node3D) -> void:
	hub = the_hub
	view = the_view
	_k = float(hub.place.get("hero_scale", 1.0))
	_goal = where(hub.place_id, Tale.step()) if Tale.on() else {}
	_make_grid()
	# the specks: one soft star each, added together so they glow
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _star()
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	mat.render_priority = 10          # the last pass erases see-through things below 1 (see v0.25.1)
	quad.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = COUNT
	_mm.visible_instance_count = 0
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = _mm
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)


## A soft four-point star, made in code: a bright core, a glow round it, a faint cross.
static func _star() -> ImageTexture:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var d := sqrt(dx * dx + dy * dy)
			var core := exp(-d * d * 14.0)
			var glow := exp(-d * d * 5.0) * 0.35
			var cross := exp(-absf(dx) * 26.0) * exp(-absf(dy) * 2.6) + exp(-absf(dy) * 26.0) * exp(-absf(dx) * 2.6)
			var a := clampf(core + glow + cross * 0.55 * clampf(1.0 - d, 0.0, 1.0), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## The map as cells the dust may cross. Shut: outside the walk rectangle, in furniture and walls,
## under trees and water (what hub.gd stops the knight with, kept a little wider).
func _make_grid() -> void:
	var walk: Rect2 = hub.place["walk"]
	var size: Vector2 = hub.place["size"]
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, int(ceil(size.x / CELL)), int(ceil(size.y / CELL)))
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var body := 5.0 * _k + 2.0
	var rim := walk.grow(-body * 0.5)
	for cy in _grid.region.size.y:
		for cx in _grid.region.size.x:
			if not rim.has_point(Vector2(cx + 0.5, cy + 0.5) * CELL):
				_grid.set_point_solid(Vector2i(cx, cy))
	for b: Rect2 in hub._blocks:
		_shut_rect(b.grow(body))
	for s: Array in hub._solids:
		var r := float(s[1]) + body
		_shut_rect(Rect2((s[0] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), s[0], r)


func _shut_rect(rect: Rect2, centre := Vector2.INF, radius := 0.0) -> void:
	var a := Vector2i((rect.position / CELL).floor())
	var b := Vector2i((rect.end / CELL).floor())
	for cy in range(maxi(a.y, 0), mini(b.y, _grid.region.size.y - 1) + 1):
		for cx in range(maxi(a.x, 0), mini(b.x, _grid.region.size.x - 1) + 1):
			if centre != Vector2.INF and (Vector2(cx + 0.5, cy + 0.5) * CELL).distance_to(centre) > radius:
				continue
			_grid.set_point_solid(Vector2i(cx, cy))


## The nearest open cell to a spot (a person may stand where the cells are shut).
func _open_cell(at: Vector2) -> Vector2i:
	var c := Vector2i((at / CELL).floor())
	c = c.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)
	if not _grid.is_point_solid(c):
		return c
	for ring in range(1, 12):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var n := c + Vector2i(dx, dy)
				if _grid.is_in_boundsv(n) and not _grid.is_point_solid(n):
					return n
	return c


func _plan(from: Vector2) -> void:
	_from = from
	_path = PackedVector2Array()
	_cum = PackedFloat32Array()
	_total = 0.0
	var goal: Vector2 = _goal["to"]
	var ids := _grid.get_id_path(_open_cell(from), _open_cell(goal), true)
	var pts: Array = [from]
	for i in range(1, ids.size()):
		pts.append((Vector2(ids[i]) + Vector2(0.5, 0.5)) * CELL)
	pts.append(goal)
	# smooth the corners once, so the dust curves round a house instead of turning on a grid
	var smooth: Array = [pts[0]]
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		smooth.append(a.lerp(b, 0.75) if i > 1 else b)
		smooth.append(b.lerp(c, 0.25))
	smooth.append(pts[pts.size() - 1])
	for p: Vector2 in smooth:
		if _path.size() > 0 and _path[_path.size() - 1].distance_to(p) < 0.5:
			continue
		_total += _path[_path.size() - 1].distance_to(p) if _path.size() > 0 else 0.0
		_path.append(p)
		_cum.append(_total)


func _spot(d: float) -> Vector2:
	var i := 1
	while i < _path.size() - 1 and _cum[i] < d:
		i += 1
	var span := maxf(_cum[i] - _cum[i - 1], 0.001)
	return _path[i - 1].lerp(_path[i], clampf((d - _cum[i - 1]) / span, 0.0, 1.0))


func _process(delta: float) -> void:
	if hub == null or not is_instance_valid(hub._hero) or _goal.is_empty():
		_mm.visible_instance_count = 0
		return
	_t += delta
	var hero: Vector2 = hub._hero.position
	# only while it is wanted: the setting is on, no window is open, no door is being walked through
	var wanted: bool = bool(Save.setting("fairy_dust")) and not bool(hub.frozen) and not bool(hub._changing)
	var goal: Vector2 = _goal["to"]
	if hero.distance_to(goal) < float(_goal["stop"]) * _k + 14.0:
		wanted = false                                   # he has got there
	_show = move_toward(_show, 1.0 if wanted else 0.0, delta * 2.0)
	if _show <= 0.0:
		_mm.visible_instance_count = 0
		return
	_redo -= delta
	if _from == Vector2.INF or (_redo <= 0.0 and hero.distance_to(_from) > 6.0):
		_plan(hero)
		_redo = 0.3
	if _path.size() < 2:
		_mm.visible_instance_count = 0
		return
	var step := SPACING * _k
	var reach := REACH * _k
	var slide := fmod(_t * DRIFT * _k, step)
	# the path is cut from the knight's feet, so the part he has walked is not shown
	var shown := 0
	for i in COUNT:
		var d := GAP * _k + float(i) * step + slide
		if d > reach or d > _total - 6.0:
			break
		var spot := _spot(d)
		# a little to the side and up and down: dust, not a row of lamps
		var ahead := _spot(minf(d + 4.0, _total)) - spot
		var side := Vector2(-ahead.y, ahead.x).normalized() if ahead.length() > 0.01 else Vector2.ZERO
		var seed_a := float(i) * 1.7 + floorf(_t * DRIFT * _k / step) * 0.31
		spot += side * sin(_t * 1.6 + seed_a) * 3.2 * _k
		var pos3: Vector3 = view.call("_where_at", spot)
		pos3.y += (0.07 + 0.10 * (0.5 + 0.5 * sin(_t * 2.3 + seed_a * 1.3))) * _k + 0.04
		var fade_in := smoothstep(GAP * _k, GAP * _k + step * 2.5, d)
		var fade_out := pow(clampf(1.0 - d / reach, 0.0, 1.0), 0.8)
		var twinkle := 0.7 + 0.3 * sin(_t * 6.0 + seed_a * 2.1)
		var a := fade_in * fade_out * twinkle * _show
		var s := (0.85 + 0.30 * sin(seed_a * 3.7 + _t * 1.9)) * _k
		var basis := Basis.IDENTITY.scaled(Vector3(s, s, s))
		_mm.set_instance_transform(shown, Transform3D(basis, pos3))
		# warm gold with a few pink and pale-blue ones; above 1 so the glow of the HD look picks it up
		var hue := fmod(seed_a * 0.37, 1.0)
		var tint := Color(1.0, 0.86, 0.45) if hue < 0.55 else (Color(1.0, 0.62, 0.86) if hue < 0.8 else Color(0.62, 0.86, 1.0))
		_mm.set_instance_color(shown, Color(tint.r * 2.2, tint.g * 2.2, tint.b * 2.2, a))
		shown += 1
	_mm.visible_instance_count = shown
