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
		if String(row.get("style", "")) == "sand":
			_sand_parapet(float(row["z"]), row.get("runs", []), row.get("piers", []))
			continue
		_balustrade(float(row["z"]), row.get("runs", []))
		for pier: Array in row.get("piers", []):
			_pier(float(pier[0]), float(row["z"]) + 2.0, float(pier[1]))
	if place.has("portico"):
		_portico(place["portico"])
	# (round three) a harbour: the sunk basin's quay, a jetty, a moored boat, coils of rope
	for pond: Dictionary in place.get("water", []):
		if bool(pond.get("quay", false)):
			_quay(pond)
	if place.has("jetty"):
		_jetty(place["jetty"])
	if place.has("boat"):
		_boat(place["boat"], place)
	for at: Vector2 in place.get("coils", []):
		_coil(at)
	if bool(place.get("iron_lamps", false)):
		for row: Array in place.get("props", []):
			if String(row[0]) == "hub_slantern":
				_iron_lamp(Vector2(row[1], row[2]), row.size() > 5 and bool(row[5]))
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
		if not bool(pond.get("basin", false)) and not bool(pond.get("quay", false)):
			_mere_edge(pond["at"], pond["radius"], 262.0, 18.0)
			_shadow()
			_bridge(262.0, 434.0, 540.0, 26.0)
	if place.has("fountain"):
		_fountain(place["fountain"])


## AN IRON STREET LAMP (round two's fixer: the pack's lantern hangs from a timber arm, and fourteen
## of them round a town square read as gallows): a slim dark iron post on a stone foot, straight
## under the lantern's glass (hub.gd lays the glowing pane where the pack's lantern hung, 15 px to
## the side and about 27 to 32 px up; the light is there too), a four-barred cage round the pane
## and a peaked cap with a finial. `foot` is the pack lantern's foot spot, `flip` its mirroring.
## Plain dark iron (one flat colour made by code) and the pack's stone.
static var _iron: ImageTexture
static func iron_tex() -> ImageTexture:
	if _iron == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color("26242a"))
		img.set_pixel(0, 0, Color("34313a"))
		_iron = ImageTexture.create_from_image(img)
	return _iron


func _iron_lamp(foot: Vector2, flip: bool) -> void:
	iron_tex()
	var x := foot.x + (-15.0 if flip else 15.0)
	var z := foot.y
	var L := _deck_px(Vector2(x, z))                    # (round three: a lamp on a jetty stands on its deck)
	blk(stone, Vector3(x - 2.5, L, z - 2.5), Vector3(x + 2.5, L + 3, z + 0.5))              # the stone foot
	blk(_iron, Vector3(x - 1.0, L + 3, z - 1.5), Vector3(x + 1.0, L + 25, z - 0.5))             # the post
	blk(_iron, Vector3(x - 3.5, L + 25, z - 3.0), Vector3(x + 3.5, L + 26.5, z + 1.0))          # the cage's floor
	for dx: float in [-3.5, 2.5]:
		blk(_iron, Vector3(x + dx, L + 26.5, z - 0.6), Vector3(x + dx + 1.0, L + 33, z + 0.4), 0)   # its bars, either side of the pane
	blk(_iron, Vector3(x - 4.0, L + 33, z - 3.5), Vector3(x + 4.0, L + 34.5, z + 1.5), 0)       # the cap
	blk(_iron, Vector3(x - 2.5, L + 34.5, z - 2.5), Vector3(x + 2.5, L + 36, z + 0.5), 0)
	blk(_iron, Vector3(x - 0.5, L + 36, z - 1.5), Vector3(x + 0.5, L + 38.5, z - 0.5), 0)       # the finial
	_shadow()


## THE FOUNTAIN of the square (round two's fixer: the pack draws it from above, and stood up as a
## card it was a pale tower three heroes tall): a low eight-sided stone kerb round a basin of water
## (the place's "water" row with "basin": true, raised to the kerb's lip), a short column in the
## middle with a stone bowl and a spout on top, about one hero tall.
func _fountain(spec: Dictionary) -> void:
	var c: Vector2 = spec["at"]
	var rx := float(spec.get("rx", 34.0))
	var rz := float(spec.get("rz", 24.0))
	var high := float(spec.get("high", 7.0))
	var t := 4.0                                         # the kerb's thickness
	var ch := 10.0                                       # how much the corners are cut off
	# the four sides
	blk(stone, Vector3(c.x - rx + ch, 0, c.y - rz), Vector3(c.x + rx - ch, high, c.y - rz + t))
	blk(stone, Vector3(c.x - rx + ch, 0, c.y + rz - t), Vector3(c.x + rx - ch, high, c.y + rz))
	blk(stone, Vector3(c.x - rx, 0, c.y - rz + ch), Vector3(c.x - rx + t, high, c.y + rz - ch))
	blk(stone, Vector3(c.x + rx - t, 0, c.y - rz + ch), Vector3(c.x + rx, high, c.y + rz - ch))
	# the cut corners, in two steps each (an eight-sided kerb in blocks)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var x0 := c.x + sx * (rx - ch)
			var z0 := c.y + sz * (rz - ch)
			for k in 2:
				var a := ch * (0.5 * k)
				var bx := x0 + sx * a
				var bz := z0 + sz * (ch - a - t)
				blk(stone, Vector3(minf(bx, bx + sx * (ch * 0.5 + 0.5)), 0, minf(bz, bz + sz * t)), Vector3(maxf(bx, bx + sx * (ch * 0.5 + 0.5)), high, maxf(bz, bz + sz * t)))
	# the coping: a lip a little proud of the kerb along the front
	blk(stone, Vector3(c.x - rx + ch - 1, high, c.y + rz - t - 0.5), Vector3(c.x + rx - ch + 1, high + 1.5, c.y + rz + 0.5), 0)
	# the column, its bowl and the spout
	blk(stone, Vector3(c.x - 4, 0, c.y - 4), Vector3(c.x + 4, 16, c.y + 4))
	blk(stone, Vector3(c.x - 12, 16, c.y - 9), Vector3(c.x + 12, 20, c.y + 9), 0)
	blk(stone, Vector3(c.x - 9, 14, c.y - 6), Vector3(c.x + 9, 16, c.y + 6), 0)
	blk(stone, Vector3(c.x - 2.5, 20, c.y - 2.5), Vector3(c.x + 2.5, 27, c.y + 2.5), 0)
	blk(stone, Vector3(c.x - 3.5, 27, c.y - 3.5), Vector3(c.x + 3.5, 29, c.y + 3.5), 0)
	_shadow()


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


# ------------------------------------------------------------------ the harbour (round three)
## A harbour like the harbour picture: everything here stands over a basin of water sunk below the
## ground (scripts/hub/view3d_build.gd quay_dip; data in scripts/data/places.gd _harbour). None of it
## throws a flat shadow (the flat look's shadow lies at ground level, which here is in the air over
## the water); in HD it all throws real shadows.
const QUAY_IN := 0.93              ## as view3d_build.gd QUAY_IN: the quay wall's share of the water's radius
const QUAY_COPING := 9.0           ## as view3d_build.gd QUAY_COPING
const QUAY_TOP := 1.5              ## px: the coping stands this high over the quay's paving
const ROPE := Color(0.86, 0.74, 0.52)
const PAINT := Color(0.42, 0.62, 0.66)       ## the boat's painted wale (the pack's timber, washed teal)
const DAMP := Color(0.50, 0.58, 0.48)        ## the quay wall's green-dark band at the water line
static var _pane: ImageTexture
## A lantern's pane: one plain colour made by code, laid as "glass" (it glows warm at night like a window).
static func pane_tex() -> ImageTexture:
	if _pane == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.46, 0.60, 0.76))
		_pane = ImageTexture.create_from_image(img)
	return _pane


## px a deck lifts a spot (0 when it is on none: see view3d_build.gd decks).
func _deck_px(at: Vector2) -> float:
	for d: Dictionary in b.decks:
		if (d["rect"] as Rect2).has_point(at):
			return float(d.get("up", 0.0))
	return 0.0


## The water's surface in a place's harbour basin (px; below 0 = below the quay).
func _water_px(place: Dictionary) -> float:
	for pond: Dictionary in place.get("water", []):
		if bool(pond.get("quay", false)):
			return float(pond.get("lift", 0.0)) - float(pond.get("depth", 20.0))
	return 0.0


## The north face of the quay wall at x (px of the flat picture), for a basin row.
func _wall_z(pond: Dictionary, x: float) -> float:
	var c: Vector2 = pond["at"]
	var rw: Vector2 = (pond["radius"] as Vector2) * QUAY_IN
	var k := clampf((x - c.x) / rw.x, -1.0, 1.0)
	return c.y - rw.y * sqrt(1.0 - k * k)


## THE QUAY: a stone wall round the whole basin, standing from below the water up to a coping a
## little over the paving; the coping overhangs the water by a pixel (a dark line under it), the wall
## is stained green-dark where the water laps it. Iron bollards stand on the coping ("bollards": x of
## each on the north side) and a flight of steps runs down the wall's face to the water ("steps").
func _quay(pond: Dictionary) -> void:
	var c: Vector2 = pond["at"]
	var rw: Vector2 = (pond["radius"] as Vector2) * QUAY_IN
	var water := float(pond.get("lift", 0.0)) - float(pond.get("depth", 20.0))
	var n := 128
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p0 := c + Vector2(rw.x * cos(a0), rw.y * sin(a0))
		var p1 := c + Vector2(rw.x * cos(a1), rw.y * sin(a1))
		var n0 := Vector2(cos(a0) / rw.x, sin(a0) / rw.y).normalized()
		var n1 := Vector2(cos(a1) / rw.x, sin(a1) / rw.y).normalized()
		var nm := (n0 + n1).normalized()
		var inward := Vector3(-nm.x, 0.0, -nm.y)
		var i0 := p0 - n0 * 1.2                           # the coping's nose, out over the water
		var i1 := p1 - n1 * 1.2
		var o0 := p0 + n0 * QUAY_COPING
		var o1 := p1 + n1 * QUAY_COPING
		# the wall's face: dressed stone above, a damp band where the water laps, down under the water
		kit.poly(stone, [p(p0.x, QUAY_TOP - 2.0, p0.y), p(p1.x, QUAY_TOP - 2.0, p1.y), p(p1.x, water + 3.0, p1.y), p(p0.x, water + 3.0, p0.y)], inward)
		kit.tint = DAMP
		kit.poly(stone, [p(p0.x, water + 3.0, p0.y), p(p1.x, water + 3.0, p1.y), p(p1.x, water - 3.0, p1.y), p(p0.x, water - 3.0, p0.y)], inward)
		kit.tint = Color.WHITE
		# the coping: its top, its nose over the water, its back edge down to the paving
		kit.poly(stone, [p(i0.x, QUAY_TOP, i0.y), p(i1.x, QUAY_TOP, i1.y), p(o1.x, QUAY_TOP, o1.y), p(o0.x, QUAY_TOP, o0.y)], Vector3.UP)
		kit.poly(stone, [p(i0.x, QUAY_TOP, i0.y), p(i1.x, QUAY_TOP, i1.y), p(i1.x, QUAY_TOP - 2.0, i1.y), p(i0.x, QUAY_TOP - 2.0, i0.y)], inward)
		kit.poly(stone, [p(i0.x, QUAY_TOP - 2.0, i0.y), p(i1.x, QUAY_TOP - 2.0, i1.y), p(p1.x, QUAY_TOP - 2.0, p1.y), p(p0.x, QUAY_TOP - 2.0, p0.y)], Vector3.DOWN)
		kit.poly(stone, [p(o0.x, QUAY_TOP, o0.y), p(o1.x, QUAY_TOP, o1.y), p(o1.x, -0.5, o1.y), p(o0.x, -0.5, o0.y)], Vector3(nm.x, 0.0, nm.y))
	# iron bollards on the coping
	var iron := iron_tex()
	for x: float in pond.get("bollards", []):
		var z := _wall_z(pond, x) - 4.5
		blk(iron, Vector3(x - 2.2, QUAY_TOP, z - 2.2), Vector3(x + 2.2, QUAY_TOP + 5.0, z + 2.2))
		blk(iron, Vector3(x - 3.0, QUAY_TOP + 5.0, z - 3.0), Vector3(x + 3.0, QUAY_TOP + 6.5, z + 3.0), 0)
		blk(iron, Vector3(x - 1.5, QUAY_TOP + 6.5, z - 1.5), Vector3(x + 1.5, QUAY_TOP + 7.5, z + 1.5), 0)
	# steps down the wall's face to the water, eastwards from x
	for x0: float in pond.get("steps", []):
		var count := 5
		var run := 6.0
		var rise := (QUAY_TOP - water) / float(count + 1)
		for i in count:
			var xa := x0 + i * run
			var xb := xa + run
			var zw := maxf(_wall_z(pond, xa), _wall_z(pond, xb))
			var up := QUAY_TOP - rise * float(i + 1)
			blk(stone, Vector3(xa, water - 2.0, zw - 1.0), Vector3(xb, up, zw + 8.0), Kit.BOTTOM | Kit.BACK)
		# a low cheek wall on the open side of the flight
		var xe := x0 + count * run
		var ze := _wall_z(pond, xe)
		blk(stone, Vector3(xe, water - 2.0, ze - 1.0), Vector3(xe + 2.5, QUAY_TOP - rise * 0.5, ze + 8.0), Kit.BOTTOM | Kit.BACK)
	kit.take_corners()


## A plank JETTY on posts from the quay out over the water: {"x", "z0", "z1", "wide", "up"} (its deck
## stands "up" px over the quay's paving; people walk on it: view3d_build.gd decks).
func _jetty(j: Dictionary) -> void:
	var plank := Art.tex("hub_bplank")
	var beam := Art.tex("hub_bbeam")
	var post := Art.tex("hub_bpost")
	var x := float(j["x"])
	var z0 := float(j["z0"])
	var z1 := float(j["z1"])
	var w := float(j.get("wide", 22.0)) * 0.5
	var up := float(j.get("up", 2.0))
	var water := float(j.get("water", -11.0))
	blk(plank, Vector3(x - w, up - 1.5, z0), Vector3(x + w, up, z1), Kit.BOTTOM, plank)              # the deck
	for side: float in [-1.0, 1.0]:
		var sx := x + side * w
		blk(beam, Vector3(sx - 1.0, up - 4.5, z0 + 6.0), Vector3(sx + 1.0, up - 1.5, z1 - 0.5), Kit.BOTTOM)      # a stringer under its edge
	# posts in pairs down into the water; the last pair stands up past the deck (to moor to)
	var z := z0 + 12.0
	var last := false
	while not last:
		if z >= z1 - 3.0:
			z = z1 - 2.0
			last = true
		for side: float in [-1.0, 1.0]:
			var px_ := x + side * (w + 0.6)
			blk(post, Vector3(px_ - 1.4, water - 3.0, z - 1.4), Vector3(px_ + 1.4, up + (6.0 if last else 0.5), z + 1.4))
		# a cross brace between the pair, under the deck, seen from the front
		blk(beam, Vector3(x - w, water + 2.0, z - 0.6), Vector3(x + w, water + 3.5, z + 0.6), Kit.BOTTOM)
		z += 17.0
	kit.take_corners()


## A BOAT moored in the basin, lying side-on to the camera: {"at" (middle of the keel, px), "long",
## "beam"}. A hull of the packs' planks laid lengthways (the boards of hub_bplank turned on their
## side), a pointed bow to the west and a flat stern, a gunwale rail, a painted wale, a deck that
## follows the sheer, a mast with a sail furled on its boom (the Hideout pack's canvas), stays and
## shrouds, mooring lines to the jetty and the quay, and a lantern on a post at the stern whose pane
## glows at night (its light is a "lights" row of the place).
func _boat(bt: Dictionary, place: Dictionary) -> void:
	var plank := Art.tex("hub_bplank")
	var beam := Art.tex("hub_bbeam")
	var post := Art.tex("hub_bpost")
	var cloth := Art.tex("hub_bcloth")
	var at: Vector2 = bt["at"]
	var long := float(bt.get("long", 90.0))
	var half_b := float(bt.get("beam", 26.0)) * 0.5
	var wl := _water_px(place)
	var x0 := at.x - long * 0.5                         # the bow
	var x1 := at.x + long * 0.5                         # the stern
	var zc := at.y
	var bot := wl - 3.0
	var hb := func(t: float) -> float:
		if t < 0.36:
			return half_b * pow(sin(t / 0.36 * PI * 0.5), 0.8)
		return half_b * (1.0 - 0.16 * smoothstep(0.78, 1.0, t))
	var gw := func(t: float) -> float: return wl + 8.0 + 7.0 * pow(1.0 - t, 3.0) + 2.5 * pow(t, 4.0)
	var steps := 14
	var xs: Array = []
	var hbs: Array = []
	var gws: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		xs.append(lerpf(x0, x1, t))
		hbs.append(hb.call(t))
		gws.append(gw.call(t))
	for i in steps:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		var ha: float = hbs[i]
		var hbb: float = hbs[i + 1]
		var ga: float = gws[i]
		var gb: float = gws[i + 1]
		for s: float in [-1.0, 1.0]:
			var dz := s * (hbb - ha)
			var nh := Vector2(-dz, xb - xa).normalized() * s
			var nrm := Vector3(nh.x, 0.25, nh.y).normalized()
			# the planked side (the boards run lengthways: u goes up the side, v along it)
			var pts := [p(xa, ga, zc + s * ha), p(xb, gb, zc + s * hbb), p(xb, bot, zc + s * hbb * 0.72), p(xa, bot, zc + s * ha * 0.72)]
			var uvs := [Vector2((ga - bot) / 48.0, xa / 48.0), Vector2((gb - bot) / 48.0, xb / 48.0), Vector2(0.0, xb / 48.0), Vector2(0.0, xa / 48.0)]
			kit.face(plank, pts, uvs, nrm)
			kit.corners.append_array(pts)
			# the painted wale, a little proud of the planks
			var off := Vector3(nh.x, 0.0, nh.y) * 0.3 * PX
			kit.tint = PAINT
			kit.poly(beam, [p(xa, ga - 3.0, zc + s * ha) + off, p(xb, gb - 3.0, zc + s * hbb) + off, p(xb, gb - 5.0, zc + s * hbb * 0.98) + off, p(xa, ga - 5.0, zc + s * ha * 0.98) + off], nrm, "solid", Vector3(1, 0, 0))
			kit.tint = Color.WHITE
			# the gunwale rail: its outer face and its top
			kit.poly(beam, [p(xa, ga + 1.0, zc + s * ha) + off, p(xb, gb + 1.0, zc + s * hbb) + off, p(xb, gb - 1.0, zc + s * hbb) + off, p(xa, ga - 1.0, zc + s * ha) + off], nrm, "solid", Vector3(1, 0, 0))
			kit.poly(beam, [p(xa, ga + 1.0, zc + s * ha), p(xb, gb + 1.0, zc + s * hbb), p(xb, gb + 1.0, zc + s * maxf(hbb - 2.0, 0.0)), p(xa, ga + 1.0, zc + s * maxf(ha - 2.0, 0.0))], Vector3.UP, "solid", Vector3(1, 0, 0))
			# the inside of the bulwark, down to the deck
			kit.poly(plank, [p(xa, ga + 1.0, zc + s * maxf(ha - 2.0, 0.0)), p(xb, gb + 1.0, zc + s * maxf(hbb - 2.0, 0.0)), p(xb, gb - 2.5, zc + s * maxf(hbb - 2.0, 0.0)), p(xa, ga - 2.5, zc + s * maxf(ha - 2.0, 0.0))], Vector3(-nh.x, 0.0, -nh.y))
		# the deck, following the sheer
		kit.poly(plank, [p(xa, ga - 2.5, zc - maxf(ha - 2.0, 0.0)), p(xb, gb - 2.5, zc - maxf(hbb - 2.0, 0.0)), p(xb, gb - 2.5, zc + maxf(hbb - 2.0, 0.0)), p(xa, ga - 2.5, zc + maxf(ha - 2.0, 0.0))], Vector3.UP)
	# the flat stern (transom) and the stem post at the bow
	var hs: float = hbs[steps]
	var gs: float = gws[steps]
	kit.poly(plank, [p(x1, gs + 1.0, zc - hs), p(x1, gs + 1.0, zc + hs), p(x1, bot, zc + hs * 0.72), p(x1, bot, zc - hs * 0.72)], Vector3(1, 0, 0))
	kit.tint = PAINT
	kit.poly(beam, [p(x1 + 0.3, gs - 3.0, zc - hs), p(x1 + 0.3, gs - 3.0, zc + hs), p(x1 + 0.3, gs - 5.0, zc + hs), p(x1 + 0.3, gs - 5.0, zc - hs)], Vector3(1, 0, 0))
	kit.tint = Color.WHITE
	var g0: float = gws[0]
	blk(post, Vector3(x0 - 1.6, bot, zc - 1.3), Vector3(x0 + 1.0, g0 + 4.0, zc + 1.3))
	# the mast, the boom, and the sail furled along it, tied in three places
	var mx := x0 + long * 0.40
	var tm := 0.40
	var dk: float = gw.call(tm) - 2.5
	var top := dk + 66.0
	blk(post, Vector3(mx - 1.6, dk, zc - 1.6), Vector3(mx + 1.6, top, zc + 1.6))
	blk(beam, Vector3(mx - 2.2, top, zc - 2.2), Vector3(mx + 2.2, top + 2.0, zc + 2.2), 0)
	var by := dk + 15.0
	blk(beam, Vector3(mx, by - 1.2, zc - 1.2), Vector3(x1 - 3.0, by + 1.2, zc + 1.2), 0)
	blk(cloth, Vector3(mx + 2.0, by + 1.2, zc - 2.8), Vector3(x1 - 9.0, by + 6.0, zc + 2.8), 0)
	blk(cloth, Vector3(mx + 2.0, by + 6.0, zc - 2.0), Vector3(x1 - 20.0, by + 9.0, zc + 2.0), 0)
	for xt: float in [mx + 9.0, (mx + x1) * 0.5, x1 - 13.0]:
		blk(beam, Vector3(xt - 0.7, by + 0.8, zc - 3.1), Vector3(xt + 0.7, by + 6.6, zc + 3.1), 0)
	# a gaff lying on the furled sail, angled up the mast
	kit.poly(beam, [p(mx + 1.0, by + 22.0, zc + 0.8), p(x1 - 22.0, by + 9.5, zc + 0.8), p(x1 - 22.0, by + 7.5, zc + 0.8), p(mx + 1.0, by + 20.0, zc + 0.8)], Vector3(0, 0, 1), "solid", Vector3(1, 0, 0))
	kit.poly(beam, [p(mx + 1.0, by + 22.0, zc - 0.8), p(x1 - 22.0, by + 9.5, zc - 0.8), p(x1 - 22.0, by + 7.5, zc - 0.8), p(mx + 1.0, by + 20.0, zc - 0.8)], Vector3(0, 0, -1), "solid", Vector3(1, 0, 0))
	# stays and shrouds
	_rope(Vector3(mx, top - 1.0, zc), Vector3(x0 + 0.5, g0 + 3.5, zc), 0.0)
	_rope(Vector3(mx, top - 1.0, zc), Vector3(x1 - 1.0, gs + 1.0, zc), 0.0)
	for s: float in [-1.0, 1.0]:
		var hm: float = hb.call(tm + 0.06)
		_rope(Vector3(mx, top - 6.0, zc), Vector3(mx + 5.0, gw.call(tm + 0.06) + 1.0, zc + s * hm), 0.0)
		_rope(Vector3(mx, top - 6.0, zc), Vector3(mx - 6.0, gw.call(tm - 0.07) + 1.0, zc + s * float(hb.call(tm - 0.07))), 0.0)
	# the stern lantern: a post, an arm, an iron cage round a pane that glows at night
	var iron := iron_tex()
	pane_tex()
	var lx := x1 - 5.0
	var ld: float = gw.call(1.0 - 5.0 / long) - 2.5
	blk(post, Vector3(lx - 1.2, ld, zc - 1.2), Vector3(lx + 1.2, ld + 21.0, zc + 1.2))
	blk(iron, Vector3(lx - 2.6, ld + 13.0, zc - 2.6), Vector3(lx + 2.6, ld + 14.0, zc + 2.6), 0)
	for c: Array in [[-2.6, -2.6], [1.8, -2.6], [-2.6, 1.8], [1.8, 1.8]]:
		blk(iron, Vector3(lx + c[0], ld + 14.0, zc + c[1]), Vector3(lx + c[0] + 0.8, ld + 19.0, zc + c[1] + 0.8), 0)
	blk(iron, Vector3(lx - 3.0, ld + 19.0, zc - 3.0), Vector3(lx + 3.0, ld + 20.5, zc + 3.0), 0)
	for f: Array in [[Vector3(-1.8, 0, 2.2), Vector3(1.8, 0, 2.2), Vector3(0, 0, 1)], [Vector3(1.8, 0, -2.2), Vector3(-1.8, 0, -2.2), Vector3(0, 0, -1)],
			[Vector3(2.2, 0, 1.8), Vector3(2.2, 0, -1.8), Vector3(1, 0, 0)], [Vector3(-2.2, 0, -1.8), Vector3(-2.2, 0, 1.8), Vector3(-1, 0, 0)]]:
		var a3: Vector3 = f[0]
		var b3: Vector3 = f[1]
		kit.panel(_pane, p(lx + a3.x, 0, zc + a3.z), p(lx + b3.x, 0, zc + b3.z), (ld + 14.0) * PX * vs, (ld + 19.0) * PX * vs, f[2], "glass", true)
	# mooring lines: from the stern to the jetty's end posts, from the bow to the nearest bollard
	if place.has("jetty"):
		var j: Dictionary = place["jetty"]
		var jx := float(j["x"]) - float(j.get("wide", 22.0)) * 0.5
		_rope(Vector3(x1 - 2.0, gs + 1.0, zc + hs * 0.6), Vector3(jx - 0.6, float(j.get("up", 2.0)) + 5.5, float(j["z1"]) - 2.0), 4.0)
		_rope(Vector3(x1 - 2.0, gs + 1.0, zc - hs * 0.6), Vector3(jx - 0.6, float(j.get("up", 2.0)) + 0.5, zc - 10.0), 3.0)
	for pond: Dictionary in place.get("water", []):
		if bool(pond.get("quay", false)):
			var bx := x0 + 8.0
			var best := INF
			for x: float in pond.get("bollards", []):
				if absf(x - bx) < absf(best - bx):
					best = x
			if best != INF:
				_rope(Vector3(x0 + 2.0, g0 + 2.0, zc - 1.0), Vector3(best, QUAY_TOP + 5.5, _wall_z(pond, best) - 4.5), 5.0)
	kit.take_corners()


## A rope from a to b (px: x, up, z), a thin strip facing the camera, sagging `sag` px in the middle.
func _rope(a: Vector3, c: Vector3, sag: float) -> void:
	var rope := Art.tex("hub_bbeam")
	var n := 6 if sag > 0.0 else 1
	kit.tint = ROPE
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var q0 := a.lerp(c, t0) - Vector3(0, sag * 4.0 * t0 * (1.0 - t0), 0)
		var q1 := a.lerp(c, t1) - Vector3(0, sag * 4.0 * t1 * (1.0 - t1), 0)
		var d := Vector2(q1.x - q0.x, q1.y - q0.y)
		var side := Vector2(-d.y, d.x).normalized() * 0.4 if d.length() > 0.001 else Vector2(0, 0.4)
		kit.poly(rope, [p(q0.x + side.x, q0.y + side.y, q0.z), p(q1.x + side.x, q1.y + side.y, q1.z), p(q1.x - side.x, q1.y - side.y, q1.z), p(q0.x - side.x, q0.y - side.y, q0.z)], Vector3(0, 0, 1))
	kit.tint = Color.WHITE


## A coil of rope lying on the quay or a deck: three rings of rope one on another, a little smaller
## each, made of the pack's timber washed to the colour of hemp.
func _coil(at: Vector2) -> void:
	var rope := Art.tex("hub_bbeam")
	var lift: float = b.height(at) / (PX * vs)
	kit.tint = ROPE
	var sides := 10
	for ring in 3:
		var r := 5.5 - ring * 1.1
		var y0 := lift + ring * 1.3
		var y1 := y0 + 1.4
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var e0 := at + Vector2(cos(a0) * r, sin(a0) * r * 0.8)
			var e1 := at + Vector2(cos(a1) * r, sin(a1) * r * 0.8)
			var i0 := at + Vector2(cos(a0) * (r - 1.6), sin(a0) * (r - 1.6) * 0.8)
			var i1 := at + Vector2(cos(a1) * (r - 1.6), sin(a1) * (r - 1.6) * 0.8)
			var mid := (a0 + a1) * 0.5
			kit.poly(rope, [p(e0.x, y1, e0.y), p(e1.x, y1, e1.y), p(e1.x, y0, e1.y), p(e0.x, y0, e0.y)], Vector3(cos(mid), 0, sin(mid)))
			kit.poly(rope, [p(i0.x, y1, i0.y), p(i1.x, y1, i1.y), p(e1.x, y1, e1.y), p(e0.x, y1, e0.y)], Vector3.UP)
	kit.tint = Color.WHITE
	_shadow()


# ------------------------------------------------------------------ the Sunwell (round three)
## A PORTICO of the Sands along the back of a court ("portico": {"x0", "x1", "z" the front of its
## columns, "deep", "tall" the columns, "cols" how many, "door" an Art id for the opening in its back
## wall, "banners"}): a stepped stylobate, square columns of sandstone courses with carved bases and
## capitals, the carved blue band of the Sands as its entablature under a cornice, a back wall with the
## doorway in the middle and banners between the columns. It stands where nobody walks (behind the
## walk's top edge); the ground may climb behind it.
func _portico(spec: Dictionary) -> void:
	var brick := Art.tex("hub_bsandbrick")
	var band := Art.tex("hub_bsandwall")
	var cap := Art.tex("hub_bsandcap")
	var x0 := float(spec["x0"])
	var x1 := float(spec["x1"])
	var z := float(spec["z"])
	var deep := float(spec.get("deep", 30.0))
	var tall := float(spec.get("tall", 56.0))
	var cols := int(spec.get("cols", 7))
	var zb := z - deep
	var foot := 6.0
	# the stylobate and two steps along its front
	blk(cap, Vector3(x0 - 6, -4.0, zb - 2.0), Vector3(x1 + 6, foot, z + 5.0), Kit.BOTTOM)
	blk(cap, Vector3(x0 - 9, -2.0, z + 5.0), Vector3(x1 + 9, foot - 2.5, z + 9.0), Kit.BOTTOM | Kit.BACK)
	blk(cap, Vector3(x0 - 12, -2.0, z + 9.0), Vector3(x1 + 12, foot - 4.5, z + 13.0), Kit.BOTTOM | Kit.BACK)
	# the back wall, its doorway, banners between the columns
	var top := foot + tall
	blk(brick, Vector3(x0, foot, zb), Vector3(x1, top, zb + 5.0), Kit.BOTTOM)
	for side: float in [-1.0, 1.0]:
		var xs := x0 if side < 0.0 else x1
		blk(brick, Vector3(xs - 4.0, foot, zb), Vector3(xs + 4.0, top, z - 2.0), Kit.BOTTOM)          # the end walls
	var door_id := String(spec.get("door", ""))
	var cx := (x0 + x1) * 0.5
	if door_id != "":
		var door := Art.tex(door_id)
		var ds := door.get_size()
		kit.panel(door, p(cx - ds.x * 0.5, 0, zb + 5.3), p(cx + ds.x * 0.5, 0, zb + 5.3), foot * PX * vs, (foot + ds.y) * PX * vs, Vector3(0, 0, 1), "solid", true)
	var step := (x1 - x0) / float(cols - 1)
	if bool(spec.get("banners", true)):
		var ban := Art.tex("hub_cbanner_0")
		var bs := ban.get_size()
		for i in cols - 1:
			var bx := x0 + step * (i + 0.5)
			if absf(bx - cx) < 40.0:
				continue
			kit.panel(ban, p(bx - bs.x * 0.5, 0, zb + 5.4), p(bx + bs.x * 0.5, 0, zb + 5.4), (top - 6.0 - bs.y) * PX * vs, (top - 6.0) * PX * vs, Vector3(0, 0, 1), "solid", true)
	# the columns
	for i in cols:
		var x := x0 + step * i
		blk(cap, Vector3(x - 6.0, foot, z - 7.0), Vector3(x + 6.0, foot + 4.0, z + 3.0), Kit.BOTTOM)          # the base
		blk(brick, Vector3(x - 4.0, foot + 4.0, z - 5.0), Vector3(x + 4.0, top - 4.0, z + 1.0), Kit.BOTTOM | Kit.TOP)
		blk(cap, Vector3(x - 6.5, top - 4.0, z - 7.5), Vector3(x + 6.5, top, z + 3.5), Kit.BOTTOM)          # the capital
	# the entablature (the carved blue band), a cornice over it, a flat roof back to the wall
	var bh := 14.0
	blk(band, Vector3(x0 - 7.0, top, zb), Vector3(x1 + 7.0, top + bh, z + 4.0), Kit.BOTTOM, cap)
	blk(cap, Vector3(x0 - 9.0, top + bh, zb - 2.0), Vector3(x1 + 9.0, top + bh + 3.0, z + 6.0), Kit.BOTTOM)
	var x := x0 - 6.0
	while x + 6.0 <= x1 + 7.0:
		blk(cap, Vector3(x, top + bh + 3.0, z + 2.0), Vector3(x + 6.0, top + bh + 7.0, z + 6.0), Kit.BOTTOM)     # a crest of merlons
		x += 13.0
	_shadow()


## A low parapet of the Sands along the near edge ("near" with "style": "sand"): sandstone courses
## under a coping, square piers with a ball, where the camera looks over it into the court.
func _sand_parapet(z: float, runs: Array, piers: Array) -> void:
	var brick := Art.tex("hub_bsandbrick")
	var cap := Art.tex("hub_bsandcap")
	for r: Array in runs:
		var x0 := float(r[0])
		var x1 := float(r[1])
		blk(brick, Vector3(x0, 0, z - 7), Vector3(x1, 12, z), Kit.BOTTOM)
		blk(cap, Vector3(x0 - 1, 12, z - 8), Vector3(x1 + 1, 15, z + 1), Kit.BOTTOM)
		var x := x0
		while x <= x1 + 0.5:
			blk(cap, Vector3(x - 4, 0, z - 9), Vector3(x + 4, 18, z + 2), Kit.BOTTOM)
			x += maxf(30.0, (x1 - x0) / maxf(1.0, round((x1 - x0) / 48.0)))
		_shadow()
	for pier: Array in piers:
		var px_ := float(pier[0])
		var tall := float(pier[1])
		blk(brick, Vector3(px_ - 7, 0, z - 13), Vector3(px_ + 7, tall, z + 1), Kit.BOTTOM)
		blk(cap, Vector3(px_ - 9, tall, z - 15), Vector3(px_ + 9, tall + 3, z + 3), Kit.BOTTOM)
		blk(cap, Vector3(px_ - 4, tall + 3, z - 10), Vector3(px_ + 4, tall + 9, z - 2), Kit.BOTTOM)
		_shadow()
