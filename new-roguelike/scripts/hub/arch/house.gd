extends RefCounted
## A HOUSE of the places you walk in, built for real out of the mesh kit (scripts/hub/arch/kit.gd)
## from one row of a place's "houses" (see scripts/data/tale.gd town()). Every part is a solid
## thing with depth, textured with pieces of the purchased packs:
##   a stone plinth with a doorstep        walls of the row's "wall" art, one or two storeys
##   a timber band between the storeys     the upper storey juts out over the street (a jetty)
##   timber corner posts                   a roof slab with real thickness: fascia, bargeboards,
##   a ridge beam, carved eave trim        a stone chimney with a cap (it smokes)
##   windows with stone sills and lintels  flower troughs under the upper windows, a balcony with
##   a little pent roof over the door      a stone balustrade on a wide house
## Row keys (all optional but "at" and "wall"):
##   "at" Vector2 (middle of the front, px) "wide" 96 "deep" 56 "wall" "roof" "rise" 30 "gable" false
##   "door" "windows" "win_dx" 30 "win_up" 12 "chimney" false
##   "floors" 1, 2 or 3 (default: 2 where nobody walks behind the house, else 1, so a tall house never
##            hides a person); "upper" the upper storey's wall art; "balcony" (default: a wide
##            two-storey house); "awning" the pent roof over the door (default: where it fits)
## SHOPFRONTS (round two, like the lamp-lit street of the reference pictures):
##   "shop" "wide": a long awning of "shop_roof" (default the teal tiles) across the whole ground
##            storey on brackets, with a carved fringe; "sign" an Art id hung as the emblem of a
##            hanging shop sign (a board on a bracket at a corner, "sign_side" -1 or 1)
##   "boxes"  true: flower boxes under the ground-floor windows too
##   "door_dx" the door off the middle (px); "win_xs" / "up_xs" [dx, ...] the windows of the ground
##            storey / the storeys above (default either side at win_dx): a narrow house has its
##            door to one side and one window beside it
##   "lift"   px the house stands on (default: the height of the terrace under its front, see
##            scripts/hub/view3d_build.gd "terraces"); "style" "sand": a house of the Sands (sandstone
##            bands and sills, a flat roof behind a parapet, no timber posts, no jetty)

const Kit = preload("res://scripts/hub/arch/kit.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")

const PX := 1.0 / 16.0
const PLINTH := 6.0                ## px: the stone foot of the walls
const BAND := 5.0                  ## px: the timber band between two storeys
const JETTY := 4.0                 ## px: how far the upper storey juts out
const EAVE := 8.0                  ## px: how far the roof reaches past the walls
const SLAB := 3.0                  ## px: how thick the roof is
const UPPER := {"hub_wall_brick": "hub_wall_plaster", "hub_wall_log": "hub_wall_plank", "hub_wall_dark": "hub_wall_dark",
	"hub_wall_white": "hub_wall_white", "hub_wall_plaster": "hub_wall_plaster", "hub_wall_plank": "hub_wall_plank"}

var kit: Kit
var v                              ## the view (scripts/hub/view3d.gd), for its lights
var vs := 1.0
var stone: Texture2D
var beam: Texture2D
var post: Texture2D
var plank: Texture2D
var rail: Texture2D
var fringe: Texture2D
var base := 0.0                    ## px: what the house being built stands on (a terrace)
var sand := false                  ## the house being built is a flat-roofed one of the Sands


func _init(the_kit: Kit, view) -> void:
	kit = the_kit
	v = view
	vs = kit.vs
	stone = Art.tex("hub_bstone")
	beam = Art.tex("hub_bbeam")
	post = Art.tex("hub_bpost")
	plank = Art.tex("hub_bplank")
	rail = Art.tex("hub_brail")
	fringe = Art.tex("hub_bfringe")


## A world spot from art pixels: x across, `up` above the ground, z (the flat picture's y).
func p(x: float, up: float, z: float) -> Vector3:
	return Vector3(x * PX, (up + base) * PX * vs, z * PX)


## A block from two corners in art pixels (x, up, z).
func blk(tex: Texture2D, a: Vector3, b: Vector3, skip := Kit.BOTTOM, top_tex: Texture2D = null) -> void:
	kit.box(tex, p(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)), p(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)), skip, top_tex)


## An upright panel in art pixels: from (x0, z0) to (x1, z1), between heights y0 and y1.
func pan(tex: Texture2D, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, n: Vector3, kind := "solid", stretch := false) -> void:
	kit.panel(tex, p(x0, 0, z0), p(x1, 0, z1), (y0 + base) * PX * vs, (y1 + base) * PX * vs, n, kind, stretch)


## Builds one house row. `walk_top` = the top edge of where people walk (px).
func build(h: Dictionary, walk_top: float) -> void:
	var at: Vector2 = h["at"]
	var cx := at.x
	var cz := at.y
	var wide := float(h.get("wide", 96.0))
	var deep := float(h.get("deep", 56.0))
	var w := wide * 0.5
	var x0 := cx - w
	var x1 := cx + w
	var back := cz - deep
	var wall_id := String(h["wall"])
	var wall := Art.tex(wall_id)
	base = float(h.get("lift", v.build.terrace_px(Vector2(cx, cz + 4.0)) if v != null else 0.0))
	sand = String(h.get("style", "")) == "sand"
	stone = Art.tex("hub_bsandcap" if sand else "hub_bstone")
	beam = Art.tex("hub_bsandcap" if sand else "hub_bbeam")
	var sh := wall.get_size().y                                     # one storey: the wall art's own height
	var floors := int(h.get("floors", 2 if back <= walk_top + 4.0 else 1))
	var upper := Art.tex(String(h.get("upper", UPPER.get(wall_id, wall_id))))
	var logs := wall_id.contains("log")
	var gable := bool(h.get("gable", false)) and not sand
	_roof_id = String(h.get("roof", "hub_roof_planks"))
	var front := cz + (JETTY if floors > 1 and not sand else 0.0)  # the front of the top storey
	var top := sh * floors + BAND * (floors - 1)                   # where the walls end
	var rise := float(h.get("rise", 30.0))
	var door := Art.tex(String(h.get("door", "hub_door_wood")))
	var ds := door.get_size()
	var win: Texture2D = Art.tex(String(h["windows"])) if String(h.get("windows", "")) != "" else null
	var wz := win.get_size() if win != null else Vector2.ZERO
	var win_dx := float(h.get("win_dx", 30.0))
	var win_up := float(h.get("win_up", 12.0))
	var dx_door := float(h.get("door_dx", 0.0))
	var dc := cx + dx_door                                          # the middle of the door

	# --- the ground storey: front and sides, and the stone plinth (open where the door is)
	pan(wall, x0, cz, x1, cz, 0.0, sh, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w
		pan(wall, x, cz, x, back, 0.0, sh, Vector3(side, 0, 0))
	var dl := dc - ds.x * 0.5 - 2.0
	var dr := dc + ds.x * 0.5 + 2.0
	blk(stone, Vector3(x0 - 2, 0, back), Vector3(dl, PLINTH, cz + 2))
	blk(stone, Vector3(dr, 0, back), Vector3(x1 + 2, PLINTH, cz + 2))
	if base <= 0.0:
		blk(stone, Vector3(x0 - 6, 0, cz), Vector3(x1 + 6, 2.0, cz + 13))      # a flagged pavement in front, a step up from the street
		blk(stone, Vector3(dl - 3, 2.0, cz), Vector3(dr + 3, 4.5, cz + 7))    # the doorstep
	else:
		blk(stone, Vector3(dl - 3, 0.0, cz), Vector3(dr + 3, 2.5, cz + 6))    # (on a terrace: only the doorstep)
	# --- the upper storey: jutting out over a timber band
	if floors > 1:
		blk(beam, Vector3(x0 - 1, sh, back), Vector3(x1 + 1, sh + BAND, front + (2.5 if sand else 1.0)), 0)
		pan(upper, x0, front, x1, front, sh + BAND, top, Vector3(0, 0, 1))
		for side: float in [-1.0, 1.0]:
			var x := cx + side * w
			pan(upper, x, front, x, back, sh + BAND, top, Vector3(side, 0, 0))
		# (a third storey: another timber band between the upper two; nobody walks behind the north row)
		for f in range(2, floors):
			var y := sh * f + BAND * (f - 1)
			blk(beam, Vector3(x0 - 1, y, back), Vector3(x1 + 1, y + BAND, front + 1.5), 0)
	# --- timber corner posts (a log house has its own corner logs)
	if not logs and not sand:
		for side: float in [-1.0, 1.0]:
			var x := cx + side * (w - 1.5)
			blk(post, Vector3(x - 2.5, PLINTH, cz - 3), Vector3(x + 2.5, sh, cz + 1.5), Kit.BOTTOM | Kit.TOP)
			if floors > 1:
				blk(post, Vector3(x - 2.5, sh + BAND, front - 3), Vector3(x + 2.5, top, front + 1.5), Kit.BOTTOM | Kit.TOP)
	# --- the door, a pent roof over it where it fits
	pan(door, dc - ds.x * 0.5, cz + 0.4, dc + ds.x * 0.5, cz + 0.4, 0.0, ds.y, Vector3(0, 0, 1), "solid", true)
	blk(beam, Vector3(dc - ds.x * 0.5 - 3, ds.y, cz), Vector3(dc + ds.x * 0.5 + 3, ds.y + 3, cz + 2.5))     # the lintel
	var room := win_dx - wz.x * 0.5 - ds.x * 0.5 if win != null else 99.0
	if String(h.get("shop", "")) == "wide":
		_shop_awning(cx, w, cz, sh, Art.tex(String(h.get("shop_roof", "hub_roof_tiles"))))
	elif bool(h.get("awning", room > 7.0 and ds.y + 14.0 < sh and dx_door == 0.0)):
		_pent(cx, cz, ds.x + 14.0, ds.y + 12.0)
	if String(h.get("sign", "")) != "":
		var side_s := float(h.get("sign_side", 1.0))
		var sign_up := sh - 3.0 if String(h.get("shop", "")) == "wide" else minf(sh - 4.0, ds.y + 14.0)
		_sign(cx + side_s * (w - 5.0), cz, sign_up, side_s, Art.tex(String(h["sign"])))
	# --- windows: on the ground storey (their light falls on the street at night) ...
	if win != null:
		for dxw: float in h.get("win_xs", [-win_dx, win_dx]):
			_window(win, cx + dxw, cz, win_up, bool(h.get("boxes", false)), true)
		# ... and on the upper storey, with flower troughs; a wide house has a balcony in the middle
		if floors > 1:
			var balcony := bool(h.get("balcony", wide >= 120.0))
			var y0 := sh + BAND + maxf(6.0, (sh - wz.y) * 0.45)
			var xs: Array = h.get("up_xs", [-win_dx, win_dx])
			if not balcony and wide >= 120.0:
				xs = [-wide / 3.0, 0.0, wide / 3.0]
			for dx: float in xs:
				_window(win, cx + dx, front, y0, true, false)
				for f in range(2, floors):
					_window(win, cx + dx, front, y0 + (sh + BAND) * (f - 1), f % 2 == 0, false)
			if balcony:
				_balcony(cx, front, sh + BAND, door)
	# --- the roof
	if sand:
		_flat_roof(x0, x1, front, back, top)
	elif gable:
		_gable_roof(cx, w, front, back, top, rise, win)
	else:
		_long_roof(cx, w, front, back, top, rise)
	# --- the chimney
	if bool(h.get("chimney", false)) and not sand:
		var bx := cx + w * 0.5
		var bz := (front + back) * 0.5 - 4.0
		var tip := top + rise + 14.0
		blk(stone, Vector3(bx - 6, top - 4, bz - 5), Vector3(bx + 6, tip, bz + 5), Kit.BOTTOM)
		blk(stone, Vector3(bx - 7.5, tip, bz - 6.5), Vector3(bx + 7.5, tip + 3, bz + 6.5), 0)
		v.build._smoke(p(bx, tip + 3, bz))


## One window: the art flush with the wall, a stone sill under it and a timber lintel over it.
## `trough` adds a flower trough on the sill; `spill` gives it a pool of light on the street at night.
func _window(win: Texture2D, x: float, z: float, y0: float, trough: bool, spill: bool) -> void:
	var wz := win.get_size()
	pan(win, x - wz.x * 0.5, z + 0.4, x + wz.x * 0.5, z + 0.4, y0, y0 + wz.y, Vector3(0, 0, 1), "glass", true)
	blk(stone, Vector3(x - wz.x * 0.5 - 2, y0 - 3, z), Vector3(x + wz.x * 0.5 + 2, y0, z + 4), 0)
	blk(beam, Vector3(x - wz.x * 0.5 - 2, y0 + wz.y, z), Vector3(x + wz.x * 0.5 + 2, y0 + wz.y + 2.5, z + 2))
	if trough:
		var box := Art.tex("hub_planter")
		var bs := box.get_size()
		blk(plank, Vector3(x - wz.x * 0.5, y0 - 1, z + 4), Vector3(x + wz.x * 0.5, y0 + 4, z + 9), 0)
		pan(box, x - wz.x * 0.5 - 1, z + 9.3, x + wz.x * 0.5 + 1, z + 9.3, y0 - 2, y0 - 2 + bs.y, Vector3(0, 0, 1), "solid", true)
	if spill and v != null:
		var lamp_colour := Color(1.0, 0.72, 0.40)
		var pool := WalkLight.pool(Vector3(x * PX, base * PX * vs, z * PX + 0.9), 1.5, lamp_colour)
		v._world.add_child(pool)
		var glow := WalkLight.halo(p(x, y0 + wz.y * 0.5, z + 1.0), 1.3, lamp_colour)
		v._world.add_child(glow)
		v.light.windows.append([pool.material_override, glow.material_override])


## A little pent roof over a door: a sloping plank slab on two brackets.
func _pent(cx: float, cz: float, wide: float, up: float) -> void:
	var roof := Art.tex("hub_roof_planks")
	var w := wide * 0.5
	var out := 13.0
	var drop := 6.0
	var n := Vector3(0, out, drop * vs).normalized()
	kit.poly(roof, [p(cx - w, up, cz), p(cx + w, up, cz), p(cx + w, up - drop, cz + out), p(cx - w, up - drop, cz + out)], n)
	kit.poly(plank, [p(cx - w, up - 2, cz), p(cx + w, up - 2, cz), p(cx + w, up - drop - 2, cz + out), p(cx - w, up - drop - 2, cz + out)], -n)
	pan(beam, cx - w, cz + out, cx + w, cz + out, up - drop - 2, up - drop, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w
		kit.poly(beam, [p(x, up, cz), p(x, up - drop, cz + out), p(x, up - drop - 2, cz + out), p(x, up - 2, cz)], Vector3(side, 0, 0))
		blk(beam, Vector3(x - side * 4 - 1.5, up - drop - 8, cz), Vector3(x - side * 4 + 1.5, up - drop - 1, cz + out - 2), Kit.BOTTOM | Kit.TOP)


## A balcony on the upper storey: a plank floor, a stone balustrade, a door out onto it.
func _balcony(cx: float, front: float, floor_up: float, door: Texture2D) -> void:
	var w := 26.0
	var out := 11.0
	var ds := door.get_size()
	pan(door, cx - ds.x * 0.5, front + 0.4, cx + ds.x * 0.5, front + 0.4, floor_up + 1, floor_up + 1 + ds.y, Vector3(0, 0, 1), "solid", true)
	blk(plank, Vector3(cx - w, floor_up - 3, front), Vector3(cx + w, floor_up + 1, front + out), 0)
	var rh := rail.get_size().y
	pan(rail, cx - w, front + out - 0.5, cx + w, front + out - 0.5, floor_up + 1, floor_up + 1 + rh, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var x := cx + side * (w - 0.5)
		pan(rail, x, front + out, x, front, floor_up + 1, floor_up + 1 + rh, Vector3(side, 0, 0))
		blk(stone, Vector3(x - 2, floor_up + 1, front + out - 3), Vector3(x + 2, floor_up + 3 + rh, front + out + 1), Kit.BOTTOM)
	# two stone brackets under it
	for side: float in [-1.0, 1.0]:
		var x := cx + side * (w - 6)
		blk(stone, Vector3(x - 2, floor_up - 9, front), Vector3(x + 2, floor_up - 3, front + out - 3), Kit.BOTTOM)


## The roof of a house whose ridge runs from side to side: one long slope faces the street.
func _long_roof(cx: float, w: float, front: float, back: float, top: float, rise: float) -> void:
	var roof := _roof_tex()
	var zr := (front + back) * 0.5
	var hd := (front - back) * 0.5
	var lean := rise / hd                                             # px up per px back
	var xl := cx - w - 6.0
	var xr := cx + w + 6.0
	var ridge := top + rise
	var eave := top - EAVE * lean
	for s: float in [1.0, -1.0]:                                      # the slope to the street, then the back one
		var ez := zr + s * (hd + EAVE)
		var n := Vector3(0, hd, s * rise * vs).normalized()
		kit.poly(roof, [p(xl, ridge, zr), p(xr, ridge, zr), p(xr, eave, ez), p(xl, eave, ez)], n, "solid", Vector3(1, 0, 0))
		kit.poly(plank, [p(xl, ridge - SLAB, zr), p(xr, ridge - SLAB, zr), p(xr, eave - SLAB, ez), p(xl, eave - SLAB, ez)], -n, "solid", Vector3(1, 0, 0))
		pan(beam, xl, ez, xr, ez, eave - SLAB, eave, Vector3(0, 0, s))                     # the fascia
		if s > 0.0:
			pan(fringe, xl, ez + 0.3, xr, ez + 0.3, eave - SLAB - fringe.get_size().y, eave - SLAB, Vector3(0, 0, 1))
		for side: float in [-1.0, 1.0]:                               # the bargeboards along the slopes' ends
			var x := xl if side < 0.0 else xr
			kit.poly(beam, [p(x, ridge + 0.5, zr), p(x, eave + 0.5, ez), p(x, eave - SLAB - 1.5, ez), p(x, ridge - SLAB - 1.5, zr)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
	# the gable ends: the wall art closes the triangle under the roof
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w
		kit.poly(plank, [p(x, top, front), p(x, top, back), p(x, ridge - SLAB, zr)], Vector3(side, 0, 0))
	blk(beam, Vector3(xl - 1, ridge - 1, zr - 2.5), Vector3(xr + 1, ridge + 3, zr + 2.5), Kit.BOTTOM)          # the ridge beam


## The roof of a house whose pointed end faces the street.
func _gable_roof(cx: float, w: float, front: float, back: float, top: float, rise: float, win: Texture2D) -> void:
	var roof := _roof_tex()
	var lean := rise / w
	var zf := front + EAVE
	var zb := back - EAVE
	var ridge := top + rise
	var eave := top - 6.0 * lean
	for side: float in [-1.0, 1.0]:
		var ex := cx + side * (w + 6.0)
		var n := Vector3(side * rise * vs, w, 0).normalized()
		kit.poly(roof, [p(cx, ridge, zf), p(cx, ridge, zb), p(ex, eave, zb), p(ex, eave, zf)], n, "solid", Vector3(0, 0, -1))
		kit.poly(plank, [p(cx, ridge - SLAB, zf), p(cx, ridge - SLAB, zb), p(ex, eave - SLAB, zb), p(ex, eave - SLAB, zf)], -n, "solid", Vector3(0, 0, -1))
		pan(beam, ex, zf, ex, zb, eave - SLAB, eave, Vector3(side, 0, 0))                    # the fascia along the side
		# the bargeboard along the front edge of this slope, and its twin at the back
		for z: float in [zf, zb]:
			kit.poly(beam, [p(cx, ridge + 1, z), p(ex, eave + 1, z), p(ex, eave - SLAB - 2, z), p(cx, ridge - SLAB - 2, z)], Vector3(0, 0, signf(z - front + 0.1)), "solid", Vector3(1, 0, 0))
	# the gable: upright boards close the triangle over the front wall; a small attic window in it
	kit.poly(plank, [p(cx - w, top, front), p(cx + w, top, front), p(cx, ridge - SLAB, front)], Vector3(0, 0, 1))
	kit.poly(plank, [p(cx - w, top, back), p(cx + w, top, back), p(cx, ridge - SLAB, back)], Vector3(0, 0, -1))
	blk(beam, Vector3(cx - w - 1, top - 1, back), Vector3(cx + w + 1, top + 3, front + 1.5), 0)          # the beam under the gable
	if win != null and rise >= 30.0:
		var wz := win.get_size() * 0.62
		var y0 := top + 4.0
		if y0 + wz.y < ridge - 8.0:
			pan(win, cx - wz.x * 0.5, front + 0.4, cx + wz.x * 0.5, front + 0.4, y0, y0 + wz.y, Vector3(0, 0, 1), "glass", true)
			blk(stone, Vector3(cx - wz.x * 0.5 - 1.5, y0 - 2, front), Vector3(cx + wz.x * 0.5 + 1.5, y0, front + 3), 0)
	blk(beam, Vector3(cx - 2.5, ridge - 1, zb - 1), Vector3(cx + 2.5, ridge + 3, zf + 1), Kit.BOTTOM)          # the ridge beam


## A shop's long awning across the whole ground storey: a sloping slab of `roof` from just under the
## storey band out over the street, a carved fringe along its low edge, brackets at the ends and in
## the middle (the shopfronts of the reference pictures have them).
func _shop_awning(cx: float, w: float, cz: float, sh: float, roof: Texture2D) -> void:
	var up := sh - 1.0
	var out := 15.0
	var drop := 7.0
	var xl := cx - w + 2.0
	var xr := cx + w - 2.0
	var n := Vector3(0, out, drop * vs).normalized()
	kit.poly(roof, [p(xl, up, cz), p(xr, up, cz), p(xr, up - drop, cz + out), p(xl, up - drop, cz + out)], n, "solid", Vector3(1, 0, 0))
	kit.poly(plank, [p(xl, up - 1.5, cz), p(xr, up - 1.5, cz), p(xr, up - drop - 1.5, cz + out), p(xl, up - drop - 1.5, cz + out)], -n, "solid", Vector3(1, 0, 0))
	pan(beam, xl, cz + out, xr, cz + out, up - drop - 2, up - drop, Vector3(0, 0, 1))
	pan(fringe, xl, cz + out + 0.3, xr, cz + out + 0.3, up - drop - 2 - fringe.get_size().y, up - drop - 2, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var x := xl if side < 0.0 else xr
		kit.poly(beam, [p(x, up, cz), p(x, up - drop, cz + out), p(x, up - drop - 2, cz + out), p(x, up - 2, cz)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
	for x: float in [xl + 3.0, cx, xr - 3.0]:
		blk(beam, Vector3(x - 1.2, up - drop - 9, cz), Vector3(x + 1.2, up - drop - 2, cz + out - 3), Kit.BOTTOM | Kit.TOP)


## A hanging shop sign: a bracket out from the wall at height `up`, two short hangers and a board of
## planks with the shop's emblem (a pack piece: a jug for the inn, a shield, a pot ...) on its face.
func _sign(x: float, cz: float, up: float, side: float, emblem: Texture2D) -> void:
	var out := 16.0
	blk(beam, Vector3(x - 1.2, up, cz), Vector3(x + 1.2, up + 2.2, cz + out + 1), 0)                   # the arm
	kit.poly(beam, [p(x, up - 8, cz), p(x, up - 6, cz), p(x, up, cz + 9), p(x, up, cz + 7)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
	var es := emblem.get_size()
	var bw := maxf(14.0, es.x + 4.0)
	var bh := maxf(11.0, es.y + 4.0)
	var bz := cz + out - 1.0
	var top := up - 3.0
	for dx: float in [-bw * 0.5 + 2.0, bw * 0.5 - 2.0]:
		blk(beam, Vector3(x + dx - 0.5, top, bz - 0.5), Vector3(x + dx + 0.5, up, bz + 0.5), 0)        # the hangers
	blk(plank, Vector3(x - bw * 0.5, top - bh, bz - 1.0), Vector3(x + bw * 0.5, top, bz + 1.0), 0)
	pan(emblem, x - es.x * 0.5, bz + 1.3, x + es.x * 0.5, bz + 1.3, top - bh * 0.5 - es.y * 0.5, top - bh * 0.5 + es.y * 0.5, Vector3(0, 0, 1), "solid", true)


## The flat roof of a house of the Sands: a slab over the walls and a low parapet round its edge.
func _flat_roof(x0: float, x1: float, front: float, back: float, top: float) -> void:
	blk(stone, Vector3(x0 - 1, top - 1, back - 1), Vector3(x1 + 1, top + 2, front + 1.5), Kit.BOTTOM)
	for e: Array in [[x0 - 1.5, x1 + 1.5, front - 2.0, front + 2.0], [x0 - 1.5, x1 + 1.5, back - 1.5, back + 2.5],
			[x0 - 1.5, x0 + 2.5, back, front], [x1 - 2.5, x1 + 1.5, back, front]]:
		blk(stone, Vector3(e[0], top + 2, e[2]), Vector3(e[1], top + 7, e[3]), Kit.BOTTOM)


var _roof_id := "hub_roof_planks"
func _roof_tex() -> Texture2D:
	return Art.tex(_roof_id)
