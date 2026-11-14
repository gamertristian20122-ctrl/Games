extends RefCounted
## THE TWO INTERIORS (your room, the Hollow Flagon) as REAL 3D ROOMS (14 Nov 2026). The owner's photos
## showed them as one flat painted picture lying on the ground: chandeliers on the floor, the knight
## walking over them, the room floating in a black void. Now (3D look only; the flat look and `--flat`
## still show the old picture) a place's `"inside"` row is built here from the Free Pack's own interior
## pieces (tools/import_hub.py, ids `hub_i*`) and code-made geometry and light:
##   walls      a back wall and two side walls with height (plaster over a dark wainscot, a beam band,
##              timber posts, a top beam), a LOW near wall (so you see in) with gaps for a way out
##   frame      dark timber masses round the room at the walls' height: nothing outside is a black void
##   floor      a repeating plank or herringbone floor, rugs laid on it
##   furniture  "slab": a three-quarter-view piece (table, bed, bench) whose top rows lie flat as its top
##              and whose bottom rows stand up as its front, so it has real height and people stand
##              behind it; "box": a block (the bar counter); "stand": an upright piece (chairs, barrels,
##              plants, a mirror, things on a counter with "lift"); "wall": a piece hung on the back wall;
##              "hang": a chandelier on a chain ABOVE head height
##   light      "light", "sconce" (a wall candle), "fire" (in the hearth), chandeliers: warm lights that
##              flicker, with a glow; the biggest throw real shadows in HD
## Rows of `"inside"["items"]` (positions in px of the place; "at" = x and the FRONT edge's y):
##   {"k": "slab", "p": piece, "at": Vector2, "front": px of the piece's bottom rows that stand up}
##   {"k": "box", "at": Vector2, "size": Vector3(wide, high, deep), "tex": front piece, "top": top piece}
##   {"k": "stand", "p": piece, "at": Vector2, "lift": px, "flip": bool, "block": Vector2(wide, deep)}
##   {"k": "wall", "p": piece, "x": px, "up": px}       {"k": "rug", "p": piece, "at": Vector2 (centre)}
##   {"k": "hang", "p": piece, "at": Vector2, "up": px, "light": energy}
##   {"k": "sconce", "x": px, "up": px, "light": energy (0 = glow only)}
##   {"k": "fire", "at": Vector2, "up": px, "light": energy}    {"k": "light", "at": Vector2, "up": px, "light": energy}
## `blocks(place)` gives hub.gd the walls-and-furniture rectangles from the same rows (slabs, boxes and
## stands with "block"), plus `"inside"["blocks"]`: walking always matches what is built.
## Heights are px of the camera's slant (kit `vs`), as everywhere in scripts/hub/arch/.

const Kit = preload("res://scripts/hub/arch/kit.gd")
const CardShader = preload("res://scripts/fx/card_shader.gd")
const HdLight = preload("res://scripts/fx/hd_light.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")
const Hd = preload("res://scripts/fx/hd.gd")

const PX := 1.0 / 16.0
const PITCH := 50.0                ## the camera's pitch in a room (scripts/hub/view3d.gd PITCH_INDOORS)
const AMBER := Color(1.0, 0.58, 0.28)
const FAR := 420.0                 ## how far the dark frame reaches past the room, px

var kit: Kit
var b                              ## scripts/hub/view3d_build.gd (b.v is the view)
var v
var vs := 1.0
var _ticker: Ticker
var _lights := 0


func _init(the_kit: Kit, build) -> void:
	kit = the_kit
	b = build
	v = build.v
	vs = kit.vs


static func _tex(id: String) -> Texture2D:
	return Art.tex(id)


## How deep a three-quarter-view piece's top is on the floor: its top rows, seen at the room's pitch.
static func slab_depth(tex_h: float, front: float) -> float:
	return roundf((tex_h - front) / sin(deg_to_rad(PITCH)))


## The walls-and-furniture rectangles of a place's "inside" (hub.gd `_blocks` in the 3D look).
static func blocks(place: Dictionary) -> Array:
	var inside: Dictionary = place.get("inside", {})
	var out: Array = (inside.get("blocks", []) as Array).duplicate()
	for row: Dictionary in inside.get("items", []):
		var at: Vector2 = row.get("at", Vector2.ZERO)
		match String(row["k"]):
			"slab":
				var sz := _tex(String(row["p"])).get_size()
				var deep := slab_depth(sz.y, float(row["front"]))
				out.append(Rect2(at.x - sz.x * 0.5 + 1.0, at.y - deep, sz.x - 2.0, deep))
			"box":
				var s: Vector3 = row["size"]
				out.append(Rect2(at.x - s.x * 0.5, at.y - s.z, s.x, s.z))
			"stand":
				if row.has("block"):
					var w: Vector2 = row["block"]
					out.append(Rect2(at.x - w.x * 0.5, at.y - w.y, w.x, w.y))
	return out


func build(place: Dictionary) -> void:
	var inside: Dictionary = place["inside"]
	_ticker = Ticker.new()
	v._world.add_child(_ticker)
	_shell(inside, place["size"])
	var i := 0
	for row: Dictionary in inside.get("items", []):
		i += 1
		match String(row["k"]):
			"slab":
				_slab(_tex(String(row["p"])), row["at"], float(row["front"]))
			"box":
				_box(row)
			"stand":
				_stand(_tex(String(row["p"])), row["at"], float(row.get("lift", 0.0)), bool(row.get("flip", false)))
			"wall":
				var t := _tex(String(row["p"]))
				_stand(t, Vector2(float(row["x"]), float(inside["back"]) + 0.6 + i * 0.03), float(row.get("up", 0.0)), bool(row.get("flip", false)))
			"rug":
				_rug(_tex(String(row["p"])), row["at"], i)
			"hang":
				_hang(row, inside)
			"sconce":
				_sconce(row, inside)
			"fire":
				_fire(row)
			"light":
				_light(_spot(row["at"], float(row.get("up", 20.0))), float(row.get("light", 1.0)), float(row.get("reach", 90.0)), false)


# ------------------------------------------------------------------ the room's shell
## Floor, walls, posts, beams and the dark frame round it all.
func _shell(inside: Dictionary, size: Vector2) -> void:
	var x0 := float(inside["x0"])
	var x1 := float(inside["x1"])
	var back := float(inside["back"])
	var near := float(inside["near"])
	var high := float(inside.get("high", 76.0))
	var low := float(inside.get("near_high", 10.0))
	var gaps: Array = inside.get("gaps", [])
	var floor_tex := _tex(String(inside.get("floor", "hub_ifloor_plank")))
	var wall := _tex(String(inside.get("wall", "hub_iwall")))
	var plaster := _tex("hub_iplaster")
	var beam := _tex("hub_bbeam")
	var post := _tex("hub_ipost")
	var plank := _tex("hub_bplank")
	var yh := high * PX * vs
	var yl := low * PX * vs
	var yw := minf(48.0, high) * PX * vs         # the wainscot piece's own height
	var band := yw + 6.0 * PX * vs
	# the floor (a little over the painted ground under it), into the gaps of the near wall too
	var fy := 0.004
	kit.poly(floor_tex, [Vector3(x0 * PX, fy, back * PX), Vector3(x1 * PX, fy, back * PX), Vector3(x1 * PX, fy, (near + 6.0) * PX), Vector3(x0 * PX, fy, (near + 6.0) * PX)], Vector3.UP)
	for g: Array in gaps:
		kit.poly(floor_tex, [Vector3(float(g[0]) * PX, fy, (near + 6.0) * PX), Vector3(float(g[1]) * PX, fy, (near + 6.0) * PX),
			Vector3(float(g[1]) * PX, fy, (near + 40.0) * PX), Vector3(float(g[0]) * PX, fy, (near + 40.0) * PX)], Vector3.UP)
	# the back wall: wainscot and plaster panels, a beam band, plaster, a top beam; posts every panel
	var a := Vector3(x0 * PX, 0.0, back * PX)
	var c := Vector3(x1 * PX, 0.0, back * PX)
	kit.panel(wall, a, c, 0.0, yw, Vector3(0, 0, 1))
	kit.panel(beam, a, c, yw, band, Vector3(0, 0, 1))
	kit.panel(plaster, a, c, band, yh - 6.0 * PX * vs, Vector3(0, 0, 1))
	kit.panel(beam, a, c, yh - 6.0 * PX * vs, yh, Vector3(0, 0, 1))
	var x := x0
	var skip: Array = inside.get("no_posts", [])
	while x <= x1 + 0.5:
		var free := true
		for s: Array in skip:
			if x > float(s[0]) and x < float(s[1]):
				free = false
		if free:
			kit.box(post, Vector3((x - 3.0) * PX, 0.0, back * PX), Vector3((x + 3.0) * PX, yh, (back + 3.0) * PX), Kit.BOTTOM | Kit.BACK)
		x += float(wall.get_width())
	# the side walls (their inner faces), the same way up
	for side: Array in [[x0, Vector3(1, 0, 0)], [x1, Vector3(-1, 0, 0)]]:
		var sx := float(side[0]) * PX
		var n: Vector3 = side[1]
		var p := Vector3(sx, 0.0, back * PX)
		var q := Vector3(sx, 0.0, (near + 6.0) * PX)
		kit.panel(wall, p, q, 0.0, yw, n)
		kit.panel(beam, p, q, yw, band, n)
		kit.panel(plaster, p, q, band, yh - 6.0 * PX * vs, n)
		kit.panel(beam, p, q, yh - 6.0 * PX * vs, yh, n)
		# past the near wall the side masses stand on at full height: their faces towards the low frame
		kit.tint = Color(1.0, 0.86, 0.76)
		kit.panel(plank, Vector3(sx, 0.0, (near + 6.0) * PX), Vector3(sx, 0.0, (size.y + FAR) * PX), yl, yh, n)
		kit.tint = Color.WHITE
	# the near wall: low, dark planks with a beam on top, open where "gaps" say
	var runs: Array = []
	var from := x0
	for g: Array in gaps:
		runs.append([from, float(g[0])])
		from = float(g[1])
	runs.append([from, x1])
	for r: Array in runs:
		if float(r[1]) - float(r[0]) < 1.0:
			continue
		kit.box(plank, Vector3(float(r[0]) * PX, 0.0, near * PX), Vector3(float(r[1]) * PX, yl, (near + 6.0) * PX), Kit.BOTTOM | Kit.BACK, beam)
	# THE FRAME: dark timber at the walls' height all round (old roof beams seen from above), so the room
	# never floats in a void
	kit.tint = Color(0.85, 0.70, 0.60)
	var big := Vector2(size.x + FAR, size.y + FAR)
	_flat(plank, -FAR, -FAR, big.x, back, yh + 0.002)                          # behind the back wall
	_flat(plank, -FAR, back, x0, big.y, yh + 0.002)                            # left of the room
	_flat(plank, x1, back, big.x, big.y, yh + 0.002)                           # right of the room
	kit.tint = Color(0.80, 0.66, 0.56)
	var at := x0
	for g: Array in gaps:
		_flat(plank, at, near + 6.0, float(g[0]), big.y, yl + 0.002)
		at = float(g[1])
		# the way out: the floor runs on into the dark
		kit.tint = Color(0.12, 0.10, 0.09)
		_flat(plank, float(g[0]), near + 40.0, float(g[1]), big.y, 0.006)
		kit.tint = Color(0.80, 0.66, 0.56)
		for gx: float in [float(g[0]), float(g[1])]:
			var nx := 1.0 if gx == float(g[0]) else -1.0
			kit.panel(plank, Vector3(gx * PX, 0.0, (near + 6.0) * PX), Vector3(gx * PX, 0.0, (near + 40.0) * PX), 0.0, yl, Vector3(nx, 0, 0))
	_flat(plank, at, near + 6.0, x1, big.y, yl + 0.002)
	# the mass's front edges over the side walls and the beams that cap every wall
	kit.tint = Color(0.62, 0.50, 0.42)
	kit.box(beam, Vector3((x0 - 8.0) * PX, yh - 0.02, (back - 8.0) * PX), Vector3((x1 + 8.0) * PX, yh + 0.03, back * PX), Kit.BOTTOM | Kit.BACK)
	kit.box(beam, Vector3((x0 - 8.0) * PX, yh - 0.02, back * PX), Vector3(x0 * PX, yh + 0.03, (near + 6.0) * PX), Kit.BOTTOM | Kit.LEFT)
	kit.box(beam, Vector3(x1 * PX, yh - 0.02, back * PX), Vector3((x1 + 8.0) * PX, yh + 0.03, (near + 6.0) * PX), Kit.BOTTOM | Kit.RIGHT)
	kit.tint = Color.WHITE


## A flat dark piece of the frame between two corners (px), at height y (world units).
func _flat(tex: Texture2D, ax: float, az: float, bx: float, bz: float, y: float) -> void:
	if bx - ax < 0.5 or bz - az < 0.5:
		return
	kit.poly(tex, [Vector3(ax * PX, y, az * PX), Vector3(bx * PX, y, az * PX), Vector3(bx * PX, y, bz * PX), Vector3(ax * PX, y, bz * PX)], Vector3.UP)


# ------------------------------------------------------------------ furniture
## A three-quarter-view piece with real height: its top rows lie flat, its bottom `front` rows stand up
## as its front (legs and all: the gaps between them are see-through). A soft dark patch lies under it.
func _slab(tex: Texture2D, at: Vector2, front: float) -> void:
	var sz := tex.get_size()
	var deep := slab_depth(sz.y, front)
	var x0 := (at.x - sz.x * 0.5) * PX
	var x1 := (at.x + sz.x * 0.5) * PX
	var zf := at.y * PX
	var zb := (at.y - deep) * PX
	var yt := front * PX * vs
	var cut := (sz.y - front) / sz.y
	kit.face(tex, [Vector3(x0, yt, zb), Vector3(x1, yt, zb), Vector3(x1, yt, zf), Vector3(x0, yt, zf)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, cut), Vector2(0, cut)], Vector3.UP)
	kit.face(tex, [Vector3(x0, yt, zf), Vector3(x1, yt, zf), Vector3(x1, 0.0, zf), Vector3(x0, 0.0, zf)],
		[Vector2(0, cut), Vector2(1, cut), Vector2(1, 1), Vector2(0, 1)], Vector3(0, 0, 1))
	# its back edge (seen past a person standing behind it): the front rows again, darker by the light
	kit.face(tex, [Vector3(x1, yt, zb), Vector3(x0, yt, zb), Vector3(x0, 0.0, zb), Vector3(x1, 0.0, zb)],
		[Vector2(0, cut), Vector2(1, cut), Vector2(1, 1), Vector2(0, 1)], Vector3(0, 0, -1))
	kit.corners.append_array([Vector3(x0, yt, zb), Vector3(x1, 0.0, zf)])
	_under(Vector2(at.x, at.y - deep * 0.5), Vector2(sz.x + 6.0, deep + 4.0))


## A block: the bar counter (front and sides from one piece, its top from another).
func _box(row: Dictionary) -> void:
	var at: Vector2 = row["at"]
	var s: Vector3 = row["size"]
	var front := _tex(String(row["tex"]))
	var top := _tex(String(row.get("top", row["tex"])))
	kit.box(front, Vector3((at.x - s.x * 0.5) * PX, 0.0, (at.y - s.z) * PX), Vector3((at.x + s.x * 0.5) * PX, s.y * PX * vs, at.y * PX), Kit.BOTTOM, top)
	_under(Vector2(at.x, at.y - s.z * 0.5), Vector2(s.x + 6.0, s.z + 6.0))


## An upright piece standing on its foot line `at` (or lifted `lift` px: on a counter, on a wall).
func _stand(tex: Texture2D, at: Vector2, lift: float, flip: bool) -> void:
	var sz := tex.get_size()
	var x0 := (at.x - sz.x * 0.5) * PX
	var x1 := (at.x + sz.x * 0.5) * PX
	var z := at.y * PX
	var y0 := lift * PX * vs
	var y1 := (lift + sz.y) * PX * vs
	var u := [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)] if flip else [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	kit.face(tex, [Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), Vector3(x0, y0, z)], u, Vector3(0, 0, 1))


## A rug laid on the floor, centred on `at`.
func _rug(tex: Texture2D, at: Vector2, i: int) -> void:
	var sz := tex.get_size()
	var y := 0.008 + i * 0.0004
	var a := (at - sz * 0.5) * PX
	var c := (at + sz * 0.5) * PX
	kit.face(tex, [Vector3(a.x, y, a.y), Vector3(c.x, y, a.y), Vector3(c.x, y, c.y), Vector3(a.x, y, c.y)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Vector3.UP)


## A chandelier on a chain from the beams, its foot `up` px over the floor (above every head), and its light.
func _hang(row: Dictionary, inside: Dictionary) -> void:
	var tex := _tex(String(row["p"]))
	var at: Vector2 = row["at"]
	var up := float(row.get("up", 48.0))
	_stand(tex, at, up, false)
	# a thin dark iron rod up to the roof beams (the pack's chain read as a thick ladder at this size)
	var top := up + tex.get_height() - 4.0
	var hi := float(inside.get("high", 76.0)) + 30.0
	kit.tint = Color(0.16, 0.13, 0.12)
	kit.box(_tex("hub_bpost"), Vector3((at.x - 0.8) * PX, top * PX * vs, at.y * PX - 0.03), Vector3((at.x + 0.8) * PX, hi * PX * vs, at.y * PX - 0.01), Kit.BOTTOM | Kit.TOP)
	kit.tint = Color.WHITE
	var flame := _spot(at, up + tex.get_height() * 0.6)
	if float(row.get("light", 1.0)) > 0.0:
		# (the light hangs just under the ring, so it lights the room and not its own iron white)
		_light(_spot(at, up - 8.0) + Vector3(0.0, 0.0, -0.15), float(row.get("light", 1.0)), float(row.get("reach", 110.0)), true, at)
	_glow(flame, 1.1, 0.45)


## A wall candle (the Castle pack's sconce) on the back wall, with a small flame and (maybe) a light.
func _sconce(row: Dictionary, inside: Dictionary) -> void:
	var tex := _tex(String(row.get("p", "hub_ccandle_0")))
	var x := float(row["x"])
	var up := float(row.get("up", 38.0))
	var z := float(inside["back"]) + 1.5
	_stand(tex, Vector2(x, z), up, false)
	var tip := _spot(Vector2(x, z + 0.3), up + tex.get_height() - 1.0)
	_flame(tip, 0.32)
	if float(row.get("light", 0.0)) > 0.0:
		_light(tip + Vector3(0.0, -0.1, 0.45), float(row["light"]), float(row.get("reach", 80.0)), false, Vector2(x, z + 10.0))
	_glow(tip, 0.9, 0.7)


## The hearth's fire: flames, a big warm light that throws shadows.
func _fire(row: Dictionary) -> void:
	var at: Vector2 = row["at"]
	var up := float(row.get("up", 2.0))
	var base := _spot(at, up)
	_flame(base + Vector3(-0.2, 0.0, 0.0), 0.55)
	_flame(base + Vector3(0.18, 0.0, 0.02), 0.68)
	_light(base + Vector3(0.0, 0.6, 0.8), float(row.get("light", 2.0)), float(row.get("reach", 150.0)), true, at + Vector2(0, 14))
	_glow(base + Vector3(0.0, 0.5, 0.1), 2.2, 1.0)


## A soft dark patch on the floor under a piece of furniture (the shade it stands in: it never floats).
static var _under_mat: StandardMaterial3D
func _under(centre: Vector2, size: Vector2) -> void:
	if _under_mat == null:
		_under_mat = StandardMaterial3D.new()
		_under_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_under_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_under_mat.albedo_texture = HdLight.dot()
		_under_mat.albedo_color = Color(0.03, 0.02, 0.02, 0.5)
		_under_mat.disable_fog = true
		_under_mat.render_priority = 2
	var plane := PlaneMesh.new()
	plane.size = size * PX * 1.15
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = _under_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(centre.x * PX, 0.012, centre.y * PX)
	v._world.add_child(m)


## A spot of the place (px) `up` px of slant over the floor, in world units.
func _spot(at: Vector2, up: float) -> Vector3:
	return Vector3(at.x * PX, up * PX * vs, at.y * PX)


# ------------------------------------------------------------------ light
func _light(at: Vector3, energy: float, reach: float, big: bool, pool_at := Vector2.INF) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = AMBER if not Hd.on() else AMBER.lerp(HdLight.HD_LAMP_AMBER, 0.4)
	l.omni_range = reach * PX
	l.omni_attenuation = 1.6 if Hd.on() else 1.2
	var e := energy * (5.0 if Hd.on() else 3.2)
	l.light_energy = e
	l.shadow_enabled = Hd.on() and big
	if Hd.on():
		l.light_volumetric_fog_energy = 0.25
		l.light_size = 0.1
		l.shadow_blur = 1.5
		l.shadow_bias = 0.06
		l.shadow_normal_bias = 1.0
	v._world.add_child(l)
	var pool: MeshInstance3D = null
	if pool_at != Vector2.INF:
		pool = WalkLight.pool(Vector3(pool_at.x * PX, 0.0, pool_at.y * PX), reach * PX * 0.45, AMBER)
		v._world.add_child(pool)
	_ticker.lights.append([l, e, float(_lights) * 2.3, pool])
	_lights += 1


## A soft painted halo round a flame (it carries the glow on the phone too).
func _glow(at: Vector3, size: float, strength: float) -> void:
	var h := WalkLight.halo(at + Vector3(0.0, 0.0, 0.05), size, AMBER)
	v._world.add_child(h)
	_ticker.halos.append([h.material_override, strength * (0.55 if Hd.on() else 0.8), float(_ticker.halos.size()) * 1.7])


## A burning flame (the Free Pack's fire strip, animated), standing on `at`, `k` times its size.
func _flame(at: Vector3, k: float) -> void:
	var frames: Array = []
	var i := 0
	while Art.has("hub_flame_f%d" % i):
		frames.append(Art.tex("hub_flame_f%d" % i))
		i += 1
	if frames.is_empty():
		return
	var tex: Texture2D = frames[0]
	var mat := CardShader.card(tex, Vector4(0, 0, 1, 1), Color.WHITE)
	CardShader.set_glow(mat, tex)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := tex.get_width() * PX * k
	var h := tex.get_height() * PX * vs * k
	# (the strip's flame sits low in its 48 px frame: its foot is about 6 px over the frame's bottom)
	m.transform = Transform3D(Basis(Vector3(w, 0, 0), Vector3(0, h, 0), Vector3(0, 0, 1)), at + Vector3(0.0, h * 0.5 - 6.0 * PX * vs * k, 0.0))
	v._world.add_child(m)
	_ticker.flames.append([mat, frames, randf() * 4.0])


## Flicker and flame frames, every frame (freed with the place).
class Ticker extends Node3D:
	var lights: Array = []          ## [OmniLight3D, energy, seed, pool or null]
	var halos: Array = []           ## [material, strength, seed]
	var flames: Array = []          ## [material, frames, phase]

	func _process(_delta: float) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for row: Array in lights:
			var f := WalkLight.flicker(t, float(row[2]), true)
			(row[0] as OmniLight3D).light_energy = float(row[1]) * f
			if row[3] != null:
				((row[3] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("strength", 0.22 * f)
		for row: Array in halos:
			(row[0] as ShaderMaterial).set_shader_parameter("strength", float(row[1]) * WalkLight.flicker(t, float(row[2]), true))
		for row: Array in flames:
			var frames: Array = row[1]
			var i := int((t + float(row[2])) * 9.0) % frames.size()
			CardShader.param(row[0] as ShaderMaterial, "tex", frames[i])
