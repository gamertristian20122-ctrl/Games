extends RefCounted
## THE REST OF A PLACE'S ARCHITECTURE (after its houses): built by scripts/hub/view3d_build.gd
## build_houses() with the mesh kit (scripts/hub/arch/kit.gd). Only the 3D look shows it.
##   kerbs        every paved rectangle of a place's "floor" gets a raised stone kerb where it meets
##                bare ground, so a street reads as a step down from its edge (all places)
##   Wickmere     garden walls with piers between the north houses, steps up to the sealed gate,
##                a stone edge round the mere, an arched stone footbridge over it, and a stone
##                balustrade along the front edge (it stands between the camera and the town)
##   Dustwatch    the town wall of the Sands with merlons, two towers either side of the cistern
##                stair, stairs up to the wall walk, flat-roofed sandstone houses behind the wall,
##                and a low wall along the near edge
##   stalls       any place's "stalls": market stalls (four posts, a sloping roof with a fringe, a
##                plank counter); the goods on the counter are ordinary props of the place
##   bunting      any place's "bunting": a rope of little pennants strung between two posts
##   terraces     any place's "terraces": a raised pavement of flagstones with a coping along its
##                edge and flights of steps down to the street (people walk up onto it: see
##                scripts/hub/view3d_build.gd terrace_px)
##   bridges      any place's "bridges": {"x", "z0", "z1", "wide", "wood"} an arched footbridge
##                (stone, or planks on posts with a timber rail) over water, front to back
##   near         any place's "near": {"z", "runs": [[x0, x1], ...], "piers": [[x, tall], ...]}: a
##                stone balustrade between the camera and the play, tall gate piers with a ball on
##                top (it frames the view; the near blur and shade of the HD look melt it)
## NOTHING HERE BLOCKS WALKING: walking is hub.gd's flat 2D, so everything stands where nobody
## walks (behind a place's "walk" top, on water, past its near edge) or is low (kerbs, the gate steps).
## Positions are art pixels of the flat picture (x, y) as in scripts/data/; heights are px too.

const Kit = preload("res://scripts/hub/arch/kit.gd")

const PX := 1.0 / 16.0
const KERB := 2.5                  ## px: how high a kerb stands
const KERB_W := 3.0                ## px: how wide

var kit: Kit
var b                              ## scripts/hub/view3d_build.gd (height(), _cast(), _smoke())
var vs := 1.0
var stone: Texture2D
var shade: SurfaceTool


func _init(the_kit: Kit, build) -> void:
	kit = the_kit
	b = build
	vs = kit.vs
	stone = Art.tex("hub_bstone")


func p(x: float, up: float, z: float) -> Vector3:
	return Vector3(x * PX, up * PX * vs, z * PX)


func blk(tex: Texture2D, a: Vector3, c: Vector3, skip := Kit.BOTTOM, top_tex: Texture2D = null) -> void:
	kit.box(tex, p(minf(a.x, c.x), minf(a.y, c.y), minf(a.z, c.z)), p(maxf(a.x, c.x), maxf(a.y, c.y), maxf(a.z, c.z)), skip, top_tex)


## Throws the flat shadow (no HD) of everything made since the last call, as one outline.
func _shadow() -> void:
	var c := kit.take_corners()
	if shade != null and c.size() >= 3:
		b._cast(c, shade)


func build(place_id: String, place: Dictionary, the_shade: SurfaceTool) -> void:
	shade = the_shade
	_kerbs(place)
	kit.take_corners()                                  # (kerbs are too low to throw a shadow)
	for row: Dictionary in place.get("stalls", []):
		_stall(row)
	for row: Array in place.get("bunting", []):
		_bunting(row[0], row[1], float(row[2]), float(row[3]) if row.size() > 3 else 8.0)
	for row: Dictionary in place.get("terraces", []):
		_terrace(row)
	for row: Dictionary in place.get("bridges", []):
		_bridge(float(row["x"]), float(row["z0"]), float(row["z1"]), float(row.get("wide", 22.0)), bool(row.get("wood", false)))
	for row: Dictionary in place.get("near", []):
		_balustrade(float(row["z"]), row.get("runs", []))
		for pier: Array in row.get("piers", []):
			_pier(float(pier[0]), float(row["z"]) + 2.0, float(pier[1]))
	match place_id:
		"village":
			_wickmere(place)
		"dustwatch":
			_dustwatch(place)


# ------------------------------------------------------------------ kerbs
## A raised kerb along every edge of a paved rectangle that meets unpaved ground.
func _kerbs(place: Dictionary) -> void:
	var rects: Array = []
	var tex := stone
	for f: Array in place.get("floor", []):
		var id := String(f[0])
		if id.contains("cobble") or id.contains("paving") or id.contains("flag"):
			rects.append(f[1])
			if id.contains("paving"):
				tex = Art.tex("hub_bsandcap")
	var houses: Array = []
	for h: Dictionary in place.get("houses", []):
		var at: Vector2 = h["at"]
		houses.append(Rect2(at.x - float(h.get("wide", 96.0)) * 0.5 - 4.0, at.y - float(h.get("deep", 56.0)), float(h.get("wide", 96.0)) + 8.0, float(h.get("deep", 56.0)) + 12.0))
	for r: Rect2 in rects:
		# the four edges: [start, end, the way out of the rectangle]
		var edges := [[r.position, Vector2(r.end.x, r.position.y), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), r.end, Vector2(0, 1)],
			[r.position, Vector2(r.position.x, r.end.y), Vector2(-1, 0)], [Vector2(r.end.x, r.position.y), r.end, Vector2(1, 0)]]
		for e: Array in edges:
			var a: Vector2 = e[0]
			var c: Vector2 = e[1]
			var out: Vector2 = e[2]
			var along := (c - a).normalized()
			var n := int(ceil((c - a).length() / 4.0))
			var run_from := -1
			for i in n + 1:
				var t := minf(float(i) * 4.0, (c - a).length())
				var q := a + along * (t + 2.0 if i < n else t - 2.0) + out * 3.0
				var open := i < n and not _paved(q, rects) and not _in_rects(q, houses)
				if open and run_from < 0:
					run_from = i
				elif not open and run_from >= 0:
					_kerb(a + along * (run_from * 4.0), a + along * minf(float(i) * 4.0, (c - a).length()), out, tex)
					run_from = -1


func _paved(q: Vector2, rects: Array) -> bool:
	for r: Rect2 in rects:
		if r.grow(0.5).has_point(q):
			return true
	return false


func _in_rects(q: Vector2, rects: Array) -> bool:
	for r: Rect2 in rects:
		if r.has_point(q):
			return true
	return false


## One straight kerb from s to e on the inside of the edge (`out` points away from the paving).
func _kerb(s: Vector2, e: Vector2, out: Vector2, tex: Texture2D) -> void:
	if s.distance_to(e) < 3.0:
		return
	var inner := -out * KERB_W
	var lo := Vector2(minf(s.x, e.x + inner.x), minf(s.y, e.y + inner.y))
	var hi := Vector2(maxf(s.x, e.x + inner.x), maxf(s.y, e.y + inner.y))
	var lift: float = b.height((s + e) * 0.5) / (PX * vs)
	blk(tex, Vector3(lo.x, lift, lo.y), Vector3(hi.x, lift + KERB, hi.y))


# ------------------------------------------------------------------ Wickmere
func _wickmere(place: Dictionary) -> void:
	# (round two: the gaps between the north houses are houses now, so the garden walls are gone)
	for seg: Array in place.get("garden_walls", []):
		_garden_wall(seg[0], seg[1], seg[2])
	# steps up to the sealed gate of Hollow Hill
	for i in 3:
		var z := 131.0 - i * 4.5
		blk(stone, Vector3(450, 0, 112), Vector3(510, 3.0 * (i + 1), z), Kit.BOTTOM | Kit.BACK)
	for side: float in [-1.0, 1.0]:
		var x := 480.0 + side * 34.0
		blk(stone, Vector3(x - 4, 0, 112), Vector3(x + 4, 14, 133))
		blk(stone, Vector3(x - 5, 14, 111), Vector3(x + 5, 16.5, 134), 0)
	_shadow()
	# the mere: a stone edge round it (open under the bridge), the bridge, the balustrade in front
	for pond: Dictionary in place.get("water", []):
		_mere_edge(pond["at"], pond["radius"], 262.0, 18.0)
	_shadow()
	_bridge(262.0, 434.0, 540.0, 26.0)


## A garden wall from x0 to x1 with its face at z, a pier at each end.
func _garden_wall(x0: float, x1: float, z: float) -> void:
	var lift: float = b.height(Vector2((x0 + x1) * 0.5, z)) / (PX * vs)
	blk(stone, Vector3(x0, lift, z - 8), Vector3(x1, lift + 15, z), Kit.BOTTOM)
	blk(stone, Vector3(x0 - 1, lift + 15, z - 9), Vector3(x1 + 1, lift + 18, z + 1), 0)
	for x: float in [x0, x1]:
		blk(stone, Vector3(x - 5, lift, z - 10), Vector3(x + 5, lift + 22, z + 2))
		blk(stone, Vector3(x - 6, lift + 22, z - 11), Vector3(x + 6, lift + 25, z + 3), 0)
	_shadow()


## A ring of edging stones round an oval pond, 3 px high; open for `gap` px either side of x = `gap_x`.
func _mere_edge(c: Vector2, r: Vector2, gap_x: float, gap: float) -> void:
	var n := 56
	var ring := 3.5
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var mid := c + Vector2(cos((a0 + a1) * 0.5) * r.x, sin((a0 + a1) * 0.5) * r.y)
		if absf(mid.x - gap_x) < gap:
			continue
		var pts: Array = []
		for a: float in [a0, a1]:
			var d := Vector2(cos(a), sin(a))
			pts.append([c + Vector2(d.x * (r.x + 1.0), d.y * (r.y + 1.0)), c + Vector2(d.x * (r.x + 1.0 + ring), d.y * (r.y + 1.0 + ring))])
		var i0: Vector2 = pts[0][0]
		var o0: Vector2 = pts[0][1]
		var i1: Vector2 = pts[1][0]
		var o1: Vector2 = pts[1][1]
		var h := 3.0
		kit.poly(stone, [p(i0.x, h, i0.y), p(i1.x, h, i1.y), p(o1.x, h, o1.y), p(o0.x, h, o0.y)], Vector3.UP)
		var out_n := Vector3(o0.x + o1.x - i0.x - i1.x, 0, o0.y + o1.y - i0.y - i1.y).normalized()
		kit.poly(stone, [p(o0.x, h, o0.y), p(o1.x, h, o1.y), p(o1.x, 0, o1.y), p(o0.x, 0, o0.y)], out_n)
		kit.poly(stone, [p(i0.x, h, i0.y), p(i1.x, h, i1.y), p(i1.x, -1, i1.y), p(i0.x, -1, i0.y)], -out_n)


## An arched footbridge running from z0 to z1 (front to back) at x, `wide` px across: stone with a
## balustrade, or (`wood`) a plank deck with timber sides, posts and a rail.
func _bridge(x: float, z0: float, z1: float, wide: float, wood := false) -> void:
	if wood:
		_footbridge(x, z0, z1, wide)
		return
	var rail := Art.tex("hub_brail")
	var rh := rail.get_size().y
	var xl := x - wide * 0.5
	var xr := x + wide * 0.5
	var steps := 12
	var span := z1 - z0
	var deck := func(z: float) -> float: return 3.0 + 9.0 * sin(PI * clampf((z - z0) / span, 0.0, 1.0))
	var arch := func(z: float) -> float: return maxf(0.0, 8.0 * sin(PI * clampf((z - z0 - 14.0) / (span - 28.0), 0.0, 1.0)))
	for i in steps:
		var za := z0 + span * i / steps
		var zb := z0 + span * (i + 1) / steps
		var ya: float = deck.call(za)
		var yb: float = deck.call(zb)
		var ua: float = arch.call(za)
		var ub: float = arch.call(zb)
		var n_top := Vector3(0, zb - za, (ya - yb) * vs).normalized()
		kit.poly(stone, [p(xl, ya, za), p(xr, ya, za), p(xr, yb, zb), p(xl, yb, zb)], n_top, "solid", Vector3(1, 0, 0))
		for side: float in [-1.0, 1.0]:
			var sx := x + side * wide * 0.5
			kit.poly(stone, [p(sx, ya + 1.5, za), p(sx, yb + 1.5, zb), p(sx, ub - 1.0, zb), p(sx, ua - 1.0, za)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
			# the balustrade along this side, following the slope of the deck
			var rx := x + side * (wide * 0.5 - 1.5)
			var ra := p(rx, ya + 1.5, za)
			var rb := p(rx, yb + 1.5, zb)
			var lift := Vector3(0, rh * PX * vs, 0)
			var ulen := (zb - za) / rail.get_size().x
			var u0 := float(i) * ulen
			kit.face(rail, [ra + lift, rb + lift, rb, ra], [Vector2(u0, 0), Vector2(u0 + ulen, 0), Vector2(u0 + ulen, 1), Vector2(u0, 1)], Vector3(side, 0, 0))
		if ub > 0.05 or ua > 0.05:
			kit.poly(stone, [p(xl, ua - 1.0, za), p(xr, ua - 1.0, za), p(xr, ub - 1.0, zb), p(xl, ub - 1.0, zb)], Vector3.DOWN, "solid", Vector3(1, 0, 0))
	# a stone pier at each corner
	for z: float in [z0 + 2.0, z1 - 2.0]:
		for side: float in [-1.0, 1.0]:
			var px_ := x + side * (wide * 0.5 - 1.0)
			var y: float = deck.call(z)
			blk(stone, Vector3(px_ - 3, 0, z - 3), Vector3(px_ + 3, y + rh + 4, z + 3))
			blk(stone, Vector3(px_ - 4, y + rh + 4, z - 4), Vector3(px_ + 4, y + rh + 6, z + 4), 0)
	_shadow()


func _footbridge(x: float, z0: float, z1: float, wide: float) -> void:
	var plank := Art.tex("hub_bplank")
	var beam := Art.tex("hub_bbeam")
	var post := Art.tex("hub_bpost")
	var xl := x - wide * 0.5
	var xr := x + wide * 0.5
	var steps := 12
	var span := z1 - z0
	var deck := func(z: float) -> float: return 2.0 + 10.0 * sin(PI * clampf((z - z0) / span, 0.0, 1.0))
	for i in steps:
		var za := z0 + span * i / steps
		var zb := z0 + span * (i + 1) / steps
		var ya: float = deck.call(za)
		var yb: float = deck.call(zb)
		var n_top := Vector3(0, zb - za, (ya - yb) * vs).normalized()
		kit.poly(plank, [p(xl, ya, za), p(xr, ya, za), p(xr, yb, zb), p(xl, yb, zb)], n_top, "solid", Vector3(1, 0, 0))
		kit.poly(plank, [p(xl, ya - 1.5, za), p(xr, ya - 1.5, za), p(xr, yb - 1.5, zb), p(xl, yb - 1.5, zb)], -n_top, "solid", Vector3(1, 0, 0))
		for side: float in [-1.0, 1.0]:
			var sx := x + side * wide * 0.5
			kit.poly(beam, [p(sx, ya + 0.5, za), p(sx, yb + 0.5, zb), p(sx, yb - 2.5, zb), p(sx, ya - 2.5, za)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
			# the hand rail, 9 px over the deck
			var rx := sx - side * 1.0
			kit.poly(beam, [p(rx, ya + 10.0, za), p(rx, yb + 10.0, zb), p(rx, yb + 8.5, zb), p(rx, ya + 8.5, za)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
			kit.poly(beam, [p(rx - 0.8, ya + 10.0, za), p(rx + 0.8, ya + 10.0, za), p(rx + 0.8, yb + 10.0, zb), p(rx - 0.8, yb + 10.0, zb)], Vector3.UP, "solid", Vector3(0, 0, 1))
	# posts along both sides, the end ones down into the water and the bank
	var k := 0
	while k <= 4:
		var z := z0 + 2.0 + (span - 4.0) * k / 4.0
		var y: float = deck.call(z)
		for side: float in [-1.0, 1.0]:
			var px_ := x + side * (wide * 0.5 - 1.0)
			blk(post, Vector3(px_ - 1.3, (-2.0 if k == 0 or k == 4 else y - 3.0), z - 1.3), Vector3(px_ + 1.3, y + 11.5, z + 1.3))
		k += 1
	_shadow()


## Tall gate piers at the near edge, stone with a cap and a ball on top (the post tops that frame
## the reference street's view).
func _pier(x: float, z: float, tall: float) -> void:
	blk(stone, Vector3(x - 6, 0, z - 12), Vector3(x + 6, tall, z))
	blk(stone, Vector3(x - 7.5, tall, z - 13.5), Vector3(x + 7.5, tall + 3, z + 1.5), 0)
	blk(stone, Vector3(x - 4, tall + 3, z - 10), Vector3(x + 4, tall + 5, z - 2), 0)
	blk(stone, Vector3(x - 3, tall + 5, z - 9), Vector3(x + 3, tall + 11, z - 3), 0)
	_shadow()


## A raised terrace of flagstones (see the header): the block, a coping along its open edges that
## stands a little proud, and flights of steps down to the street.
func _terrace(t: Dictionary) -> void:
	var r: Rect2 = t["rect"]
	var high := float(t.get("high", 7.0))
	var face := Art.tex(String(t.get("face", "hub_bstone")))
	var top := Art.tex(String(t.get("top", "hub_bstone")))
	var x0 := r.position.x
	var x1 := r.end.x
	var zb := r.position.y
	var zf := r.end.y
	blk(face, Vector3(x0, -1.0, zb), Vector3(x1, high - 0.5, zf), Kit.BOTTOM | Kit.BACK, top)
	blk(face, Vector3(x0 - 0.5, high - 2.0, zf - 2.5), Vector3(x1 + 0.5, high + 0.4, zf + 1.0), Kit.BOTTOM | Kit.BACK)     # the coping
	for xs: float in [x0, x1]:
		blk(face, Vector3(xs - 1.0, high - 2.0, zb), Vector3(xs + 1.0, high + 0.4, zf), Kit.BOTTOM | Kit.BACK)
	for st: Array in t.get("steps", []):
		var sx := float(st[0])
		var w := float(st[1]) * 0.5
		var n := int(ceil(high / 3.5))
		for i in n:
			blk(face, Vector3(sx - w, -1.0, zf - 2.0), Vector3(sx + w, high * float(n - i) / n - 0.3, zf + 4.0 * (i + 1)), Kit.BOTTOM | Kit.BACK, top)
		# a low cheek wall either side of the flight
		for side: float in [-1.0, 1.0]:
			var cx := sx + side * (w + 1.5)
			blk(face, Vector3(cx - 1.5, -1.0, zf - 2.0), Vector3(cx + 1.5, high + 1.5, zf + 4.0 * n), Kit.BOTTOM | Kit.BACK)
	kit.take_corners()                                  # (too low for a flat shadow)


## A stone balustrade on a low plinth along the near edge (z), in the given [x0, x1] runs.
func _balustrade(z: float, runs: Array) -> void:
	var rail := Art.tex("hub_brail")
	var rh := rail.get_size().y
	for r: Array in runs:
		var x0 := float(r[0])
		var x1 := float(r[1])
		blk(stone, Vector3(x0, 0, z - 6), Vector3(x1, 3, z))
		kit.panel(rail, p(x0, 0, z - 3), p(x1, 0, z - 3), 3.0 * PX * vs, (3.0 + rh) * PX * vs, Vector3(0, 0, 1))
		blk(stone, Vector3(x0, 3 + rh, z - 6), Vector3(x1, 6 + rh, z), 0)
		var x := x0
		while x <= x1 + 0.5:
			blk(stone, Vector3(x - 3, 0, z - 7), Vector3(x + 3, 8 + rh, z + 1))
			x += maxf(24.0, (x1 - x0) / maxf(1.0, round((x1 - x0) / 44.0)))
		_shadow()


# ------------------------------------------------------------------ Dustwatch
func _dustwatch(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	var wall := Art.tex("hub_bsandwall")
	var cap := Art.tex("hub_bsandcap")
	var face := 84.0                                     # the front of the town wall (people walk from y 104)
	var high := 46.0
	var towers := [258.0, 382.0]
	# houses behind the wall first (their tops show over it): [x, wide, tall, front]
	for row: Array in [[-30.0, 70.0, 82.0, 58.0], [52.0, 56.0, 66.0, 66.0], [126.0, 64.0, 92.0, 52.0], [196.0, 48.0, 72.0, 62.0],
			[446.0, 52.0, 74.0, 62.0], [516.0, 66.0, 94.0, 50.0], [590.0, 54.0, 68.0, 66.0], [664.0, 70.0, 84.0, 56.0]]:
		_sand_house(row[0], row[1], row[2], row[3], wall, cap)
	# the wall, broken by the two towers
	var runs := [[-90.0, towers[0] - 22.0], [towers[0] + 22.0, towers[1] - 22.0], [towers[1] + 22.0, size.x + 90.0]]
	for r: Array in runs:
		var x0 := float(r[0])
		var x1 := float(r[1])
		blk(wall, Vector3(x0, 0, face - 18), Vector3(x1, high, face), Kit.BOTTOM, cap)
		blk(cap, Vector3(x0, high - 3, face - 1), Vector3(x1, high, face + 1.5), Kit.BOTTOM)       # the coping
		var x := x0 + 4.0
		while x + 8.0 <= x1:
			blk(cap, Vector3(x, high, face - 4), Vector3(x + 8, high + 8, face + 1), Kit.BOTTOM)  # merlons
			x += 15.0
		_shadow()
	for tx: float in towers:
		_tower(tx, face + 6.0, 44.0, 40.0, 78.0, wall, cap)
	# stairs up the inner face of the wall to the walk, beside each tower
	_wall_stair(towers[0] - 22.0, -1.0, face, high, cap, wall)
	_wall_stair(towers[1] + 22.0, 1.0, face, high, cap, wall)
	# a low wall along the near edge, open where the road leaves
	for r: Array in [[-90.0, 262.0], [378.0, size.x + 90.0]]:
		blk(wall, Vector3(r[0], 0, size.y - 6), Vector3(r[1], 16, size.y + 6), Kit.BOTTOM, cap)
		blk(cap, Vector3(r[0], 16, size.y - 7), Vector3(r[1], 19, size.y + 7), 0)
		_shadow()


## A flat-roofed sandstone house behind the wall: walls, a roof slab with a low parapet, two shuttered
## windows high up (the part that shows over the wall), a cloth awning's frame.
func _sand_house(x: float, wide: float, tall: float, front: float, wall: Texture2D, cap: Texture2D) -> void:
	var deep := 40.0
	blk(wall, Vector3(x - wide * 0.5, 0, front - deep), Vector3(x + wide * 0.5, tall, front), Kit.BOTTOM, cap)
	for e: Array in [[x - wide * 0.5, x + wide * 0.5, front - 3.0, front + 1.0], [x - wide * 0.5, x + wide * 0.5, front - deep - 1.0, front - deep + 3.0],
			[x - wide * 0.5 - 1.0, x - wide * 0.5 + 3.0, front - deep, front], [x + wide * 0.5 - 3.0, x + wide * 0.5 + 1.0, front - deep, front]]:
		blk(cap, Vector3(e[0], tall, e[2]), Vector3(e[1], tall + 5, e[3]), Kit.BOTTOM)
	var win := Art.tex("hub_win_closed")
	var wz := win.get_size()
	for dx: float in ([-wide * 0.22, wide * 0.22] if wide >= 56.0 else [0.0]):
		var y0 := tall - wz.y - 8.0
		kit.panel(win, p(x + dx - wz.x * 0.5, 0, front + 0.4), p(x + dx + wz.x * 0.5, 0, front + 0.4), y0 * PX * vs, (y0 + wz.y) * PX * vs, Vector3(0, 0, 1), "glass", true)
		blk(cap, Vector3(x + dx - wz.x * 0.5 - 2, y0 - 3, front), Vector3(x + dx + wz.x * 0.5 + 2, y0, front + 4), 0)
	# poles that carry a sun cloth over the roof
	for dx: float in [-wide * 0.3, wide * 0.3]:
		blk(Art.tex("hub_bpost"), Vector3(x + dx - 1, tall + 5, front - 6), Vector3(x + dx + 1, tall + 20, front - 4), Kit.BOTTOM)
	_shadow()


## A square tower with merlons round its top and a banner on its face.
func _tower(x: float, front: float, wide: float, deep: float, tall: float, wall: Texture2D, cap: Texture2D) -> void:
	var w := wide * 0.5
	blk(wall, Vector3(x - w, 0, front - deep), Vector3(x + w, tall, front), Kit.BOTTOM, cap)
	blk(cap, Vector3(x - w - 1.5, tall - 3, front - deep - 1.5), Vector3(x + w + 1.5, tall + 1, front + 1.5), Kit.BOTTOM)
	var mx := x - w
	while mx + 7.0 <= x + w + 0.5:
		blk(cap, Vector3(mx, tall + 1, front - 4), Vector3(mx + 7, tall + 10, front + 1), Kit.BOTTOM)
		blk(cap, Vector3(mx, tall + 1, front - deep - 1), Vector3(mx + 7, tall + 10, front - deep + 3), Kit.BOTTOM)
		mx += 12.3
	for side: float in [-1.0, 1.0]:
		var sx := x + side * w
		var mz := front - deep
		while mz + 7.0 <= front:
			blk(cap, Vector3(sx - 2.5, tall + 1, mz), Vector3(sx + 2.5, tall + 10, mz + 7), Kit.BOTTOM)
			mz += 12.0
	var banner := Art.tex("hub_cbanner_0")
	var bs := banner.get_size()
	kit.panel(banner, p(x - bs.x * 0.5, 0, front + 0.5), p(x + bs.x * 0.5, 0, front + 0.5), (tall - 14.0 - bs.y) * PX * vs, (tall - 14.0) * PX * vs, Vector3(0, 0, 1), "solid", true)
	_shadow()


## A flight of steps against the wall's face from the ground up to the wall walk. `x_top` is where
## it reaches the top; `dir` is the way it comes down (-1 = to the west, 1 = to the east).
func _wall_stair(x_top: float, dir: float, face: float, high: float, cap: Texture2D, wall: Texture2D) -> void:
	var n := 11
	var run := 5.0
	var deep := 13.0
	for i in n:
		var xa := x_top + dir * i * run
		var xb := x_top + dir * (i + 1) * run
		var up := high * float(n - i) / n
		blk(wall, Vector3(minf(xa, xb), 0, face), Vector3(maxf(xa, xb), up, face + deep), Kit.BOTTOM, cap)
	_shadow()


# ------------------------------------------------------------------ market stalls and bunting
## A market stall. Row keys: "at" Vector2 (middle of the counter's front, px), "wide" 52, "deep" 22,
## "tall" 28 (the front edge of the roof), "deep" 18, "roof" (an Art id: hub_roof_tiles, hub_roof_planks).
## Only the stall is built here: its goods are props, and the place's "blocks" keep people off it
## and out of the shade behind it (it is as tall as a man).
func _stall(row: Dictionary) -> void:
	var at: Vector2 = row["at"]
	var wide := float(row.get("wide", 52.0))
	var deep := float(row.get("deep", 18.0))
	var tall := float(row.get("tall", 28.0))
	var roof := Art.tex(String(row.get("roof", "hub_roof_tiles")))
	var post := Art.tex("hub_bpost")
	var plank := Art.tex("hub_bplank")
	var beam := Art.tex("hub_bbeam")
	var lift: float = b.height(at) / (PX * vs)
	var w := wide * 0.5
	var back := at.y - deep
	var rise := 6.0                                     # the roof slopes down to the front
	# four posts, the back ones taller
	for c: Array in [[at.x - w + 2, at.y - 1, tall], [at.x + w - 2, at.y - 1, tall], [at.x - w + 2, back + 2, tall + rise], [at.x + w - 2, back + 2, tall + rise]]:
		blk(post, Vector3(c[0] - 1.2, lift, c[1] - 1.2), Vector3(c[0] + 1.2, lift + c[2], c[1] + 1.2), Kit.BOTTOM | Kit.TOP)
	# the counter: a plank box along the front, a shelf top
	blk(plank, Vector3(at.x - w + 3, lift, at.y - 8), Vector3(at.x + w - 3, lift + 13, at.y - 1), Kit.BOTTOM, plank)
	blk(beam, Vector3(at.x - w + 2, lift + 13, at.y - 9), Vector3(at.x + w - 2, lift + 14.5, at.y), Kit.BOTTOM)
	# a back board, so the stall reads as a little booth
	blk(plank, Vector3(at.x - w + 2, lift, back + 1), Vector3(at.x + w - 2, lift + tall * 0.55, back + 3), Kit.BOTTOM)
	_shadow()
	# the roof: from above the back posts down over the front, a little past every side
	var over := 3.0
	var y_back := lift + tall + rise + 1.0
	var y_front := lift + tall - 1.0
	var zb := back - 2.0
	var zf := at.y + 2.0
	var n := Vector3(0, zf - zb, (y_back - y_front) * vs).normalized()
	kit.poly(roof, [p(at.x - w - over, y_back, zb), p(at.x + w + over, y_back, zb), p(at.x + w + over, y_front, zf), p(at.x - w - over, y_front, zf)], n)
	kit.poly(plank, [p(at.x - w - over, y_back - 1.5, zb), p(at.x + w + over, y_back - 1.5, zb), p(at.x + w + over, y_front - 1.5, zf), p(at.x - w - over, y_front - 1.5, zf)], -n)
	# the fringe along the low edge (its scallops hang down) and the beam it hangs from
	var fringe := Art.tex("hub_bfringe")
	var fh := fringe.get_size().y
	kit.panel(fringe, p(at.x - w - over, 0, zf + 0.3), p(at.x + w + over, 0, zf + 0.3), (y_front - fh) * PX * vs, y_front * PX * vs, Vector3(0, 0, 1), "solid")
	_shadow()


## A rope from a to b (px of the flat picture) tied `high` px up at both ends, sagging `sag` px in
## the middle, with a little pennant every few px in turn of three colours.
func _bunting(a: Vector2, c: Vector2, high: float, sag: float) -> void:
	var rope := Art.tex("hub_bbeam")
	var flags := [Art.tex("hub_sbanner_0"), Art.tex("hub_sbanner_1"), Art.tex("hub_sbanner_2")]
	var span := a.distance_to(c)
	var steps := maxi(4, int(span / 10.0))
	var along := (c - a).normalized()
	var n := Vector3(-along.y, 0.0, along.x)
	if n.z < 0.0:
		n = -n                                           # the pennants face the camera's side
	var la: float = b.height(a) / (PX * vs)
	var lc: float = b.height(c) / (PX * vs)
	var pts: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var q := a.lerp(c, t)
		pts.append(Vector3(q.x, lerpf(la, lc, t) + high - sag * 4.0 * t * (1.0 - t), q.y))
	for i in steps:
		var s0: Vector3 = pts[i]
		var s1: Vector3 = pts[i + 1]
		kit.poly(rope, [p(s0.x, s0.y + 0.6, s0.z), p(s1.x, s1.y + 0.6, s1.z), p(s1.x, s1.y - 0.6, s1.z), p(s0.x, s0.y - 0.6, s0.z)], n)
		# a pennant hangs from the middle of every piece of rope but the ends
		if i == 0 or i == steps - 1:
			continue
		var m := (s0 + s1) * 0.5
		var fw := 5.0
		var fl := 9.0
		var l := Vector2(m.x, m.z) - along * fw * 0.5
		var r := Vector2(m.x, m.z) + along * fw * 0.5
		kit.panel(flags[i % 3], p(l.x, 0, l.y), p(r.x, 0, r.y), (m.y - fl) * PX * vs, m.y * PX * vs, n, "solid", true)
	kit.take_corners()                                   # (too thin for a flat shadow)
