extends RefCounted
## THE MESH KIT of the architecture (scripts/hub/view3d_build.gd and scripts/hub/arch/*): boxes,
## wall panels, slopes and arches, every face textured with a piece of the purchased packs laid at
## its true pixel size (one art pixel across is 1/16 of a world unit; one art pixel up is that much
## times `vs`, the camera's slant, so the art keeps the shape it was drawn with on the screen).
## Faces are gathered per texture and become ONE mesh each (`commit`), so a whole town of houses
## costs a handful of draw calls. Every face knows which way it faces: the light depends on it.
##   box(tex, lo, hi, skip)            a solid block (corners in world units); `skip` = faces left out
##   panel(tex, a, b, y0, y1, normal)  an upright rectangle from a to b (xz), between heights y0 and y1
##   poly(tex, pts, normal)            any flat shape (3 or 4 corners) with the texture laid on it
##   corners                           every corner made since the last take_corners() (for flat shadows)

const PX := 1.0 / 16.0
const TOP := 1
const BOTTOM := 2
const FRONT := 4                  ## +z (towards the camera)
const BACK := 8
const LEFT := 16
const RIGHT := 32

var vs := 1.0                     ## how much taller than wide an art pixel is drawn (the camera's slant)
var corners: Array = []           ## corners of everything solid made so far (world units)
var tint := Color.WHITE           ## (round three) every face made from now on wears this tint (a house's own
                                  ## shade of the pack's plaster or timber; set back to white after)
var _surf := {}                   ## "<texture id>|<kind>" -> [Texture2D, SurfaceTool, kind]


## The SurfaceTool that gathers the faces of one texture (and kind: "solid", "glass", "cut").
func _st(tex: Texture2D, kind: String) -> SurfaceTool:
	var key := "%d|%s" % [tex.get_rid().get_id(), kind]
	if not _surf.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surf[key] = [tex, st, kind]
	return _surf[key][1]


## One triangle, turned so that its front faces `n` (Godot draws clockwise faces as the front;
## with both sides drawn the light still needs to know which side is which).
func _tri(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var order := [0, 1, 2]
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(n) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		st.set_color(tint)
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


## Any flat face of 3 or 4 corners with its own texture places.
func face(tex: Texture2D, pts: Array, uvs: Array, n: Vector3, kind := "solid") -> void:
	var st := _st(tex, kind)
	_tri(st, [pts[0], pts[1], pts[2]], [uvs[0], uvs[1], uvs[2]], n)
	if pts.size() == 4:
		_tri(st, [pts[0], pts[2], pts[3]], [uvs[0], uvs[2], uvs[3]], n)


## The texture place of a world spot on a face: across the face along `u_dir`, down from `top`.
func _uv(tex: Texture2D, p: Vector3, u_dir: Vector3, n: Vector3, top: float) -> Vector2:
	var s := tex.get_size() * PX
	if absf(n.y) > 0.7:
		return Vector2(p.x / s.x, p.z / s.y)                     # lying flat: laid along x and z
	return Vector2(p.dot(u_dir) / s.x, (top - p.y) / (s.y * vs))


## A flat shape of 3 or 4 corners, the texture laid at its true size (on an upright or sloped face
## it reads across from the face's own left, downwards from its highest corner).
func poly(tex: Texture2D, pts: Array, n: Vector3, kind := "solid", u_dir := Vector3.ZERO) -> void:
	n = n.normalized()
	if u_dir == Vector3.ZERO:
		u_dir = Vector3.UP.cross(n).normalized() * -1.0 if absf(n.y) < 0.99 else Vector3.RIGHT
		if u_dir.length() < 0.5:
			u_dir = Vector3.RIGHT
	var top := -INF
	for p: Vector3 in pts:
		top = maxf(top, p.y)
	var uvs: Array = []
	for p: Vector3 in pts:
		uvs.append(_uv(tex, p, u_dir, n, top))
	face(tex, pts, uvs, n, kind)
	corners.append_array(pts)


## An upright rectangle from a to b (only their x and z count) between heights y0 and y1, facing n.
## The texture's top row lies along y1 (so a wall's art keeps its top trim at the top).
func panel(tex: Texture2D, a: Vector3, b: Vector3, y0: float, y1: float, n: Vector3, kind := "solid", stretch := false) -> void:
	var s := tex.get_size() * PX
	var along := Vector2(b.x - a.x, b.z - a.z).length()
	var u0 := 0.0                                                  # the art starts at the panel's own left edge
	var u1 := along / s.x
	var v1 := 1.0 if stretch else (y1 - y0) / (s.y * vs)
	if stretch:
		u0 = 0.0
		u1 = 1.0
	var pts := [Vector3(a.x, y1, a.z), Vector3(b.x, y1, b.z), Vector3(b.x, y0, b.z), Vector3(a.x, y0, a.z)]
	face(tex, pts, [Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, v1), Vector2(u0, v1)], n, kind)
	corners.append_array(pts)


## A solid block between two corners (world units). The texture is laid at its true size on every
## face; `skip` leaves faces out (TOP, BOTTOM, FRONT, BACK, LEFT, RIGHT: faces nobody sees).
func box(tex: Texture2D, lo: Vector3, hi: Vector3, skip := BOTTOM, top_tex: Texture2D = null) -> void:
	if skip & FRONT == 0:
		panel(tex, Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), lo.y, hi.y, Vector3(0, 0, 1))
	if skip & BACK == 0:
		panel(tex, Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, lo.z), lo.y, hi.y, Vector3(0, 0, -1))
	if skip & LEFT == 0:
		panel(tex, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), lo.y, hi.y, Vector3(-1, 0, 0))
	if skip & RIGHT == 0:
		panel(tex, Vector3(hi.x, 0, hi.z), Vector3(hi.x, 0, lo.z), lo.y, hi.y, Vector3(1, 0, 0))
	var t := top_tex if top_tex != null else tex
	if skip & TOP == 0:
		poly(t, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP)
	if skip & BOTTOM == 0:
		poly(tex, [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)], Vector3.DOWN)
	for x: float in [lo.x, hi.x]:
		for z: float in [lo.z, hi.z]:
			corners.append(Vector3(x, hi.y, z))
			corners.append(Vector3(x, lo.y, z))


## A block in art pixels round a foot spot: `at` (x, z of the flat picture, px), `size` (wide,
## tall, deep, px), `lift` (px above the ground). The front face is at at.y, the block goes back.
func block_px(tex: Texture2D, at: Vector2, size: Vector3, lift := 0.0, skip := BOTTOM, top_tex: Texture2D = null) -> void:
	box(tex, Vector3((at.x - size.x * 0.5) * PX, lift * PX * vs, (at.y - size.z) * PX),
		Vector3((at.x + size.x * 0.5) * PX, (lift + size.y) * PX * vs, at.y * PX), skip, top_tex)


## Hands over the corners gathered since the last call (for a flat shadow) and forgets them.
func take_corners() -> Array:
	var out := corners
	corners = []
	return out


## Every mesh made: [[ArrayMesh, Texture2D, kind], ...]. The kit is empty again afterwards.
func commit() -> Array:
	var out: Array = []
	for key: String in _surf:
		var row: Array = _surf[key]
		out.append([(row[1] as SurfaceTool).commit(), row[0], row[2]])
	_surf.clear()
	return out
