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
##            bands and sills, a flat roof behind a parapet, no timber posts, no jetty): "wall" is then
##            the carved band (hub_bsandwall) that tops each storey of plain brick (hub_bsandbrick)
##   "storey" px: one storey's height (default: the wall art's own; a house of the Sands 56)
## RICHER FRONTS (round three: "the facades are one tone"):
##   every house wears its own TINT of the pack's pieces (code tints, from the house's spot unless the
##   row says): "tint" the walls, "timber" beams and posts, "roof_tint" the roof
##   "frame"  true/false: half-timbering on the upper storeys (studs and braces between the windows;
##            default on plaster and white walls)
##   "bay"    [dx, ...]: a bay window on the first upper storey (a timber box out over the street with
##            its own little roof, on a bracket)
##   "lamp"   -1 or 1: an iron lantern on a bracket beside the door, on that side; its pane glows at night
##   "stair"  -1 or 1: an outside stair of stone up that side wall to a door on the upper storey (only
##            where nobody walks beside the house: the ends of a row)
##   "chimney_dx" px off the middle for the chimney (default half the half-width, east)
##   "eave"   px the roof reaches past the walls (default 10); rafter ends show under it
##   a balcony carries little plants behind its rail and a vine hangs from it

const Kit = preload("res://scripts/hub/arch/kit.gd")
const Sites = preload("res://scripts/hub/arch/sites.gd")
const WalkLight = preload("res://scripts/fx/walk_light.gd")

const PX := 1.0 / 16.0
const PLINTH := 6.0                ## px: the stone foot of the walls
const BAND := 5.0                  ## px: the timber band between two storeys
const JETTY := 4.0                 ## px: how far the upper storey juts out
const EAVE := 10.0                 ## px: how far the roof reaches past the walls (a row's "eave")
## The tints a house may wear (round three): walls, timber, roof. Pale enough that the pack's own
## painting still reads; each house picks by its spot.
## (They must be strong: the HD grade greys colour in the shade, so only a change of value and a
## clear hue survive it.)
const WALL_TINTS := [Color(1.0, 1.0, 1.0), Color(1.0, 0.80, 0.52), Color(0.94, 0.66, 0.58), Color(0.72, 0.84, 0.70),
	Color(0.70, 0.78, 0.92), Color(0.86, 0.76, 0.66), Color(1.0, 0.90, 0.74)]
const TIMBER_TINTS := [Color(1.0, 1.0, 1.0), Color(0.56, 0.50, 0.50), Color(1.0, 0.80, 0.62), Color(0.54, 0.60, 0.70), Color(0.74, 0.62, 0.50)]
const ROOF_TINTS := [Color(1.0, 1.0, 1.0), Color(0.76, 0.90, 1.0), Color(1.0, 0.76, 0.64), Color(0.70, 0.80, 0.72), Color(0.88, 0.80, 0.96)]
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
var wall_tint := Color.WHITE
var timber_tint := Color.WHITE
var roof_tint := Color.WHITE
var eave_px := EAVE


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
	var sh := float(h.get("storey", wall.get_size().y))              # one storey: the wall art's own height
	var floors := int(h.get("floors", 2 if back <= walk_top + 4.0 else 1))
	var upper := Art.tex(String(h.get("upper", UPPER.get(wall_id, wall_id))))
	var band: Texture2D = null                                      # (the Sands: the wall art's carved band tops each storey)
	if sand:
		band = wall
		wall = Art.tex("hub_bsandbrick")
		upper = wall
		sh = float(h.get("storey", 56.0))
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
	var k := int(absf(cx * 13.0 + cz * 7.0)) / 8
	wall_tint = h.get("tint", WALL_TINTS[k % WALL_TINTS.size()])
	timber_tint = h.get("timber", TIMBER_TINTS[(k / 3) % TIMBER_TINTS.size()])
	roof_tint = h.get("roof_tint", ROOF_TINTS[(k / 2) % ROOF_TINTS.size()])
	if sand:
		wall_tint = h.get("tint", Color.WHITE)
		timber_tint = Color.WHITE
		roof_tint = Color.WHITE
	eave_px = float(h.get("eave", EAVE))

	# --- the ground storey: front and sides, and the stone plinth (open where the door is)
	kit.tint = wall_tint
	pan(wall, x0, cz, x1, cz, 0.0, sh, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var x := cx + side * w
		pan(wall, x, cz, x, back, 0.0, sh, Vector3(side, 0, 0))
	kit.tint = Color.WHITE
	var dl := dc - ds.x * 0.5 - 2.0
	var dr := dc + ds.x * 0.5 + 2.0
	blk(stone, Vector3(x0 - 2, 0, back), Vector3(dl, PLINTH, cz + 2))
	blk(stone, Vector3(dr, 0, back), Vector3(x1 + 2, PLINTH, cz + 2))
	if base <= 0.0:
		blk(stone, Vector3(x0 - 6, 0, cz), Vector3(x1 + 6, 2.0, cz + 13))      # a flagged pavement in front, a step up from the street
		blk(stone, Vector3(dl - 3, 2.0, cz), Vector3(dr + 3, 4.5, cz + 7))    # the doorstep
	else:
		blk(stone, Vector3(dl - 3, 0.0, cz), Vector3(dr + 3, 2.5, cz + 6))    # (on a terrace: only the doorstep)
	if band != null:
		_band(band, x0, x1, cz, back, sh)
	# --- the upper storey: jutting out over a timber band
	if floors > 1:
		if band != null:
			_band(band, x0, x1, front, back, top)
		kit.tint = timber_tint
		blk(beam, Vector3(x0 - 1, sh, back), Vector3(x1 + 1, sh + BAND, front + (2.5 if sand else 1.0)), 0)
		kit.tint = wall_tint
		pan(upper, x0, front, x1, front, sh + BAND, top, Vector3(0, 0, 1))
		for side: float in [-1.0, 1.0]:
			var x := cx + side * w
			pan(upper, x, front, x, back, sh + BAND, top, Vector3(side, 0, 0))
		kit.tint = timber_tint
		# (a third storey: another timber band between the upper two; nobody walks behind the north row)
		for f in range(2, floors):
			var y := sh * f + BAND * (f - 1)
			blk(beam, Vector3(x0 - 1, y, back), Vector3(x1 + 1, y + BAND, front + 1.5), 0)
		kit.tint = Color.WHITE
	# --- timber corner posts (a log house has its own corner logs)
	kit.tint = timber_tint
	if not logs and not sand:
		for side: float in [-1.0, 1.0]:
			var x := cx + side * (w - 1.5)
			blk(post, Vector3(x - 2.5, PLINTH, cz - 3), Vector3(x + 2.5, sh, cz + 1.5), Kit.BOTTOM | Kit.TOP)
			if floors > 1:
				blk(post, Vector3(x - 2.5, sh + BAND, front - 3), Vector3(x + 2.5, top, front + 1.5), Kit.BOTTOM | Kit.TOP)
	# --- the door, a pent roof over it where it fits
	kit.tint = Color.WHITE
	pan(door, dc - ds.x * 0.5, cz + 0.4, dc + ds.x * 0.5, cz + 0.4, 0.0, ds.y, Vector3(0, 0, 1), "solid", true)
	kit.tint = timber_tint
	blk(beam, Vector3(dc - ds.x * 0.5 - 3, ds.y, cz), Vector3(dc + ds.x * 0.5 + 3, ds.y + 3, cz + 2.5))     # the lintel
	kit.tint = Color.WHITE
	if h.has("lamp"):
		_door_lamp(dc + float(h["lamp"]) * (ds.x * 0.5 + 7.0), cz, minf(ds.y + 2.0, sh - 10.0))
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
			var bays: Array = h.get("bay", [])
			for dx: float in xs:
				if bays.has(dx):
					continue
				_window(win, cx + dx, front, y0, true, false)
			for dx: float in xs + bays:
				for f in range(2, floors):
					_window(win, cx + dx, front, y0 + (sh + BAND) * (f - 1), f % 2 == 0, false)
			for dx: float in bays:
				_bay(win, cx + dx, front, y0, upper)
			if bool(h.get("frame", (wall_id == "hub_wall_plaster" or wall_id == "hub_wall_white") and not sand)):
				for f in range(1, floors):
					var fy := (sh + BAND) * f
					_frame(x0, x1, front, fy, fy + sh, (xs + bays).map(func(d: float) -> float: return cx + d), wz.x + 6.0, 0.0 if (balcony and f == 1) else -1.0, cx)
			if balcony:
				_balcony(cx, front, sh + BAND, door)
	# --- the roof
	kit.tint = timber_tint
	if sand:
		_flat_roof(x0, x1, front, back, top)
	elif gable:
		_gable_roof(cx, w, front, back, top, rise, win)
	else:
		_long_roof(cx, w, front, back, top, rise)
	kit.tint = Color.WHITE
	if h.has("stair") and floors > 1 and not sand:
		_side_stair(cx + float(h["stair"]) * w, float(h["stair"]), cz, back, sh + BAND, door, upper)
	# --- the chimney
	if bool(h.get("chimney", false)) and not sand:
		var bx := cx + float(h.get("chimney_dx", w * 0.5))
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
	_roof_face(roof, [p(cx - w, up, cz), p(cx + w, up, cz), p(cx + w, up - drop, cz + out), p(cx - w, up - drop, cz + out)], n)
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
	# (round three) planters of greens along the top of its rail, a vine hanging from its floor
	var box := Art.tex("hub_planter")
	var bs := box.get_size()
	for side: float in [-1.0, 1.0]:
		var x := cx + side * (w - 4.0 - bs.x * 0.5)
		pan(box, x - bs.x * 0.5, front + out + 0.2, x + bs.x * 0.5, front + out + 0.2, floor_up + rh - 3.0, floor_up + rh - 3.0 + bs.y, Vector3(0, 0, 1), "solid", true)
	var vine := Art.tex("hub_vine_2")
	var vz := vine.get_size()
	pan(vine, cx + w - 14.0 - vz.x * 0.5, front + out + 0.8, cx + w - 14.0 + vz.x * 0.5, front + out + 0.8, floor_up - 3.0 - vz.y, floor_up + 1.0, Vector3(0, 0, 1), "solid", true)


## The roof of a house whose ridge runs from side to side: one long slope faces the street.
func _long_roof(cx: float, w: float, front: float, back: float, top: float, rise: float) -> void:
	var roof := _roof_tex()
	var zr := (front + back) * 0.5
	var hd := (front - back) * 0.5
	var lean := rise / hd                                             # px up per px back
	var xl := cx - w - 6.0
	var xr := cx + w + 6.0
	var ridge := top + rise
	var eave := top - eave_px * lean
	for s: float in [1.0, -1.0]:                                      # the slope to the street, then the back one
		var ez := zr + s * (hd + eave_px)
		var n := Vector3(0, hd, s * rise * vs).normalized()
		_roof_face(roof, [p(xl, ridge, zr), p(xr, ridge, zr), p(xr, eave, ez), p(xl, eave, ez)], n, "solid", Vector3(1, 0, 0))
		kit.poly(plank, [p(xl, ridge - SLAB, zr), p(xr, ridge - SLAB, zr), p(xr, eave - SLAB, ez), p(xl, eave - SLAB, ez)], -n, "solid", Vector3(1, 0, 0))
		pan(beam, xl, ez, xr, ez, eave - SLAB, eave, Vector3(0, 0, s))                     # the fascia
		if s > 0.0:
			pan(fringe, xl, ez + 0.3, xr, ez + 0.3, eave - SLAB - fringe.get_size().y, eave - SLAB, Vector3(0, 0, 1))
			# rafter ends under the deep eave, every 9 px
			var rx := xl + 5.0
			while rx < xr - 4.0:
				blk(beam, Vector3(rx - 0.9, eave - SLAB - 2.0, front), Vector3(rx + 0.9, eave - SLAB + 0.5, ez - 1.0), 0)
				rx += 9.0
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
	var zf := front + eave_px
	var zb := back - eave_px
	var ridge := top + rise
	var eave := top - 6.0 * lean
	for side: float in [-1.0, 1.0]:
		var ex := cx + side * (w + 6.0)
		var n := Vector3(side * rise * vs, w, 0).normalized()
		_roof_face(roof, [p(cx, ridge, zf), p(cx, ridge, zb), p(ex, eave, zb), p(ex, eave, zf)], n, "solid", Vector3(0, 0, -1))
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


## The Sands: the top rows of the carved wall art (its coping and blue band) along the top of a storey,
## laid just proud of the plain brick, on the front and both sides.
func _band(tex: Texture2D, x0: float, x1: float, zf: float, zb: float, up: float) -> void:
	var bh := 14.0
	pan(tex, x0 - 0.3, zf + 0.3, x1 + 0.3, zf + 0.3, up - bh, up, Vector3(0, 0, 1))
	pan(tex, x0 - 0.3, zf + 0.3, x0 - 0.3, zb, up - bh, up, Vector3(-1, 0, 0))
	pan(tex, x1 + 0.3, zf + 0.3, x1 + 0.3, zb, up - bh, up, Vector3(1, 0, 0))


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
	_roof_face(roof, [p(xl, up, cz), p(xr, up, cz), p(xr, up - drop, cz + out), p(xl, up - drop, cz + out)], n, "solid", Vector3(1, 0, 0))
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


## A roof face wears the house's roof tint (the timber round it keeps the timber tint).
func _roof_face(tex: Texture2D, pts: Array, n: Vector3, kind := "solid", u_dir := Vector3.ZERO) -> void:
	var was := kit.tint
	kit.tint = roof_tint
	kit.poly(tex, pts, n, kind, u_dir)
	kit.tint = was


## A lantern on an iron bracket beside a door (row key "lamp"): a short arm out from the wall, a
## four-barred cage hanging from it round a pane that glows at night, a cap; at night a warm pool on
## the doorstep and a glow round the lantern (they fade in with the windows).
func _door_lamp(x: float, cz: float, up: float) -> void:
	var iron := Sites.iron_tex()
	var pane := Sites.pane_tex()
	var out := 7.0
	var z := cz + out
	blk(iron, Vector3(x - 0.7, up + 1.0, cz), Vector3(x + 0.7, up + 2.2, z + 0.6), 0)                  # the arm
	kit.poly(iron, [p(x, up - 5.0, cz), p(x, up - 3.5, cz), p(x, up + 1.0, cz + 4.5), p(x, up + 1.0, cz + 3.0)], Vector3(1, 0, 0), "solid", Vector3(0, 0, 1))
	blk(iron, Vector3(x - 0.4, up - 1.0, z - 0.4), Vector3(x + 0.4, up + 1.0, z + 0.4), 0)              # the hook
	blk(iron, Vector3(x - 3.0, up - 2.5, z - 3.0), Vector3(x + 3.0, up - 1.0, z + 3.0), 0)              # the cap
	for c: Array in [[-2.6, -2.6], [1.8, -2.6], [-2.6, 1.8], [1.8, 1.8]]:
		blk(iron, Vector3(x + c[0], up - 8.5, z + c[1]), Vector3(x + c[0] + 0.8, up - 2.5, z + c[1] + 0.8), 0)
	blk(iron, Vector3(x - 2.6, up - 9.5, z - 2.6), Vector3(x + 2.6, up - 8.5, z + 2.6), 0)              # its floor
	for f: Array in [[Vector3(-1.8, 0, 2.2), Vector3(1.8, 0, 2.2), Vector3(0, 0, 1)], [Vector3(2.2, 0, 1.8), Vector3(2.2, 0, -1.8), Vector3(1, 0, 0)],
			[Vector3(-2.2, 0, -1.8), Vector3(-2.2, 0, 1.8), Vector3(-1, 0, 0)]]:
		var a3: Vector3 = f[0]
		var b3: Vector3 = f[1]
		pan(pane, x + a3.x, z + a3.z, x + b3.x, z + b3.z, up - 8.5, up - 2.5, f[2], "glass", true)
	if v != null:
		var lamp_colour := Color(1.0, 0.66, 0.32)
		var pool := WalkLight.pool(Vector3(x * PX, base * PX * vs, (cz + 10.0) * PX), 1.7, lamp_colour)
		v._world.add_child(pool)
		var glow := WalkLight.halo(p(x, up - 5.5, z + 0.5), 1.0, lamp_colour)
		v._world.add_child(glow)
		v.light.windows.append([pool.material_override, glow.material_override])


## A bay window on the first upper storey (row key "bay"): a box of the storey's own wall jutting
## out over the street on a timber bracket, the window in its face, a sill, a lintel, and a little
## sloping roof of the house's roof cover.
func _bay(win: Texture2D, x: float, front: float, y0: float, wall: Texture2D) -> void:
	var wz := win.get_size()
	var bw := wz.x * 0.5 + 5.0
	var out := 10.0
	var clad := plank                                     # (the bay is clad in timber: it stands out from the plaster)
	var lo := y0 - 6.0
	var hi := y0 + wz.y + 5.0
	var zf := front + out
	kit.tint = timber_tint
	pan(clad, x - bw, zf, x + bw, zf, lo, hi, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		pan(clad, x + side * bw, zf, x + side * bw, front, lo, hi, Vector3(side, 0, 0))
	kit.tint = timber_tint
	blk(beam, Vector3(x - bw - 1.0, lo - 2.5, front), Vector3(x + bw + 1.0, lo, zf + 1.0), 0)           # its floor
	blk(beam, Vector3(x - 1.5, lo - 10.0, front), Vector3(x + 1.5, lo - 2.5, zf - 2.0), Kit.BOTTOM)    # the bracket
	kit.poly(beam, [p(x - 1.5, lo - 2.5, zf - 2.0), p(x + 1.5, lo - 2.5, zf - 2.0), p(x + 1.5, lo - 10.0, front), p(x - 1.5, lo - 10.0, front)], Vector3(0, -0.6, 1))
	for side: float in [-1.0, 1.0]:
		blk(post, Vector3(x + side * bw - 1.5, lo, zf - 1.5), Vector3(x + side * bw + 1.5, hi, zf + 0.8), Kit.BOTTOM | Kit.TOP)
	kit.tint = Color.WHITE
	_window(win, x, zf, y0, true, false)
	# the little roof
	var rise := 6.0
	var n := Vector3(0, out + 3.0, rise * vs).normalized()
	_roof_face(_roof_tex(), [p(x - bw - 2.0, hi + rise, front), p(x + bw + 2.0, hi + rise, front), p(x + bw + 2.0, hi, zf + 3.0), p(x - bw - 2.0, hi, zf + 3.0)], n, "solid", Vector3(1, 0, 0))
	kit.tint = timber_tint
	pan(beam, x - bw - 2.0, zf + 3.0, x + bw + 2.0, zf + 3.0, hi - 2.0, hi, Vector3(0, 0, 1))
	for side: float in [-1.0, 1.0]:
		var sx := x + side * (bw + 2.0)
		kit.poly(beam, [p(sx, hi + rise, front), p(sx, hi, zf + 3.0), p(sx, hi - 2.0, zf + 3.0), p(sx, hi + rise - 2.0, front)], Vector3(side, 0, 0), "solid", Vector3(0, 0, 1))
	kit.tint = Color.WHITE


## Half-timbering on one upper storey (row key "frame"): studs between the windows and a brace in
## every bay without a window, a rail across under the windows. `xs` are the windows' middles,
## `gap` how wide a window is with its frame; `skip_mid` 0 leaves the middle (a balcony door) clear.
func _frame(x0: float, x1: float, front: float, y0: float, y1: float, xs: Array, gap: float, skip_mid: float, cx: float) -> void:
	var z := front + 0.6
	kit.tint = timber_tint
	var edges: Array = [x0 + 3.0]
	var sorted := xs.duplicate()
	sorted.sort()
	for x: float in sorted:
		edges.append(x - gap * 0.5)
		edges.append(x + gap * 0.5)
	edges.append(x1 - 3.0)
	# the rail under the windows
	kit.panel(beam, p(x0 + 2.0, 0, z), p(x1 - 2.0, 0, z), (y0 + 5.0 + base) * PX * vs, (y0 + 7.0 + base) * PX * vs, Vector3(0, 0, 1))
	var i := 0
	while i + 1 < edges.size():
		var a: float = edges[i]
		var c: float = edges[i + 1]
		i += 2
		if c - a < 7.0:
			continue
		if skip_mid == 0.0 and a < cx and c > cx:
			continue
		# studs at both sides of the bay, a brace across it (leaning in towards the middle of the house)
		for x: float in [a + 1.0, c - 1.0]:
			blk(post, Vector3(x - 1.2, y0, front), Vector3(x + 1.2, y1, z + 0.6), Kit.BOTTOM | Kit.TOP)
		var lean := 1.0 if (a + c) * 0.5 < cx else -1.0
		var xa := a + 1.0 if lean > 0.0 else c - 1.0
		var xb := c - 1.0 if lean > 0.0 else a + 1.0
		kit.poly(beam, [p(xa, y0 + 7.0, z + 0.2), p(xa, y0 + 10.0, z + 0.2), p(xb, y1 - 1.0, z + 0.2), p(xb, y1 - 4.0, z + 0.2)], Vector3(0, 0, 1), "solid", Vector3(1, 0, 0))
	kit.tint = Color.WHITE


## An outside stair of stone up a side wall (row key "stair"): from the front corner at the street it
## climbs towards the back to a landing at the upper storey, where a door opens in the side wall; a
## timber hand rail on posts runs up its open side. `x` is the side wall, `side` which way is out.
func _side_stair(x: float, side: float, cz: float, back: float, rise: float, door: Texture2D, wall: Texture2D) -> void:
	var deep := 12.0
	var xo := x + side * deep
	var lo := minf(x, xo)
	var hi := maxf(x, xo)
	var land_b := back + 3.0
	var land_f := back + 17.0
	var z_start := cz - 1.0
	var n := int(ceil(rise / 4.2))
	var run := (z_start - land_f) / float(n)
	kit.tint = wall_tint * Color(0.92, 0.92, 0.92)
	for i in n:
		var zf := z_start - run * i
		var zb := zf - run
		var up := rise * float(i + 1) / float(n + 1)
		blk(stone, Vector3(lo, -1.0, zb), Vector3(hi, up, zf), Kit.BOTTOM | (Kit.LEFT if side > 0.0 else Kit.RIGHT))
	blk(stone, Vector3(lo, -1.0, land_b), Vector3(hi, rise, land_f), Kit.BOTTOM | (Kit.LEFT if side > 0.0 else Kit.RIGHT))
	kit.tint = Color.WHITE
	# the door on the landing, in the side wall of the upper storey
	var ds := door.get_size()
	var dz := (land_b + land_f) * 0.5
	pan(door, x + side * 0.4, dz + ds.x * 0.5, x + side * 0.4, dz - ds.x * 0.5, rise, rise + ds.y, Vector3(side, 0, 0), "solid", true)
	kit.tint = timber_tint
	blk(beam, Vector3(x + side * 0.2 - 1.0, rise + ds.y, dz - ds.x * 0.5 - 2.0), Vector3(x + side * 2.5, rise + ds.y + 2.5, dz + ds.x * 0.5 + 2.0), 0)
	# the hand rail: posts and a sloping rail along the open side, a level one round the landing
	var rx := xo - side * 1.0
	var rail_h := 10.0
	var zz := z_start - 1.0
	var k := 0
	while k <= n:
		var zp := z_start - run * k - 1.0
		var yp := rise * float(k) / float(n + 1)
		blk(post, Vector3(rx - 0.9, yp, zp - 0.9), Vector3(rx + 0.9, yp + rail_h, zp + 0.9), Kit.BOTTOM)
		k += 3
	kit.poly(beam, [p(rx, rail_h + 1.0, zz), p(rx, rise + rail_h + 1.0, land_f), p(rx, rise + rail_h - 1.0, land_f), p(rx, rail_h - 1.0, zz)], Vector3(side, 0, 0), "solid", Vector3(0, 0, -1))
	kit.poly(beam, [p(rx, rise + rail_h + 1.0, land_f), p(rx, rise + rail_h + 1.0, land_b), p(rx, rise + rail_h - 1.0, land_b), p(rx, rise + rail_h - 1.0, land_f)], Vector3(side, 0, 0), "solid", Vector3(0, 0, -1))
	blk(post, Vector3(rx - 0.9, rise, land_b - 0.9), Vector3(rx + 0.9, rise + rail_h + 1.0, land_b + 0.9), Kit.BOTTOM)
	kit.tint = Color.WHITE
