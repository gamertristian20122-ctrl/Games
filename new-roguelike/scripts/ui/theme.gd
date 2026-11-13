extends RefCounted
## Theme: the ONE place that decides how every menu and the HUD look ("Lantern Glass", the HD GUI).
## Colours, fonts, panel and button styles, the UI grid (UI.attach), and the little helpers that build
## labels, buttons, panels, bars, prompts and icons all live here. Change a colour or a size in this
## file and the whole game follows.
## Use with:  const UI = preload("res://scripts/ui/theme.gd")
##
## THE UI GRID. Every layout number is in "UI px". A CanvasLayer is put on the grid with
##   var root := UI.attach(layer)        # a Control the size of the screen in UI px; add children to it
## PC: the grid is about 360 UI px tall (TARGET_H by the "Text size" setting; 1600x720 -> 800x360,
## 1920x1080 -> 640x360). Phone (or --uiphone): the grid IS the game's 400x180 grid.
## A layer that is NOT attached still works in game px (the old way); text there is about the old size.
##
## WIDGETS (the kit, scripts/ui/kit/*.gd, built through these helpers):
##   UI.bar(preset)          hp / mp / xp / boss / foe        -> set_value(v, max, animate)
##   UI.medallion(id, r, ring, active)                         round portrait coin
##   UI.flame()              the ember focus pointer (one per screen; screen.gd adds it)
##   UI.prompt(kind, verb)   a key cap / pad cap + verb        kinds = PROMPTS keys
##   UI.help_strip(pairs, corner)                              "[Enter] Choose  [Esc] Back" on a wash
##   UI.wash(fade_to, alpha) UI.veil()  UI.lozenge(r, colour, rules)  UI.coin(r)
##   UI.pop_in / pop_out / page_swap                          motion (UI.instant turns it all off)

# ------------------------------------------------------------------ colours: Lantern Glass
## Night glass held in fine brass: dark see-through panels, a 1 UI px brass hairline, ember-gold focus.
const C_GLASS_TOP := Color(0.085, 0.10, 0.16, 0.80)    ## panel fill, top of the gradient
const C_GLASS_BOT := Color(0.03, 0.035, 0.06, 0.90)    ## panel fill, bottom
const C_INK := Color(0.035, 0.045, 0.075)              ## outlines under text, rims
const C_BRASS := Color(0.78, 0.62, 0.36)               ## ornaments; hairlines use C_BRASS_DIM
const C_BRASS_DIM := Color(0.78, 0.62, 0.36, 0.45)
const C_GOLD := Color(0.96, 0.80, 0.47)                ## focused text, names, headings that matter
const C_EMBER := Color(1.0, 0.62, 0.26)                ## focus sweep, flame pointer, acting fighter
const C_PARCH := Color(0.95, 0.92, 0.85)               ## body text
const C_DIM := Color(0.72, 0.70, 0.64)                 ## secondary text, labels
const C_FAINT := Color(0.45, 0.44, 0.42)               ## disabled
const C_HP_A := Color(0.93, 0.36, 0.25)                ## HP fill, top
const C_HP_B := Color(0.62, 0.13, 0.12)                ## HP fill, bottom
const C_MP_A := Color(0.42, 0.70, 1.0)
const C_MP_B := Color(0.16, 0.32, 0.72)
const C_XP_A := Color(0.98, 0.80, 0.40)                ## XP and Victory gold
const C_XP_B := Color(0.70, 0.45, 0.15)
const C_STEEL := Color(0.55, 0.72, 0.92)               ## your side (medallion ring)
const C_FOE := Color(0.92, 0.42, 0.30)                 ## monsters (medallion ring, target plate edge)
const C_GOOD := Color(0.6, 0.9, 0.55)                  ## "next point", heals
const C_BAD := Color(1.0, 0.55, 0.45)                  ## warnings, "why" lines, danger answers
const C_LOW := Color(1.0, 0.72, 0.55)                  ## an HP number under 30%
const C_COMMON := Color(0.95, 0.92, 0.85)              ## rarity text
const C_RARE := Color(0.5, 0.75, 1.0)
const C_EPIC := Color(0.78, 0.55, 1.0)
const C_WASH := Color(0.02, 0.025, 0.045)              ## the wash behind text on the bare world

# ---- the old names, kept so every older screen still compiles (remapped onto the new palette)
const C_VOID := Color("0b0a10")         ## behind everything (the fade)
const C_PANEL := Color(0.06, 0.07, 0.11)
const C_PANEL_HI := Color(0.10, 0.11, 0.17)
const C_PANEL_LOW := Color(0.025, 0.03, 0.05)
const C_EDGE := Color(0.78, 0.62, 0.36, 0.45)
const C_EDGE_HI := Color(0.78, 0.62, 0.36, 0.8)
const C_SHADE := Color(0.02, 0.022, 0.04)
const C_BONE := C_PARCH                 ## main text
const C_ORANGE := Color("ee8e2e")
const C_RED := Color("da4e38")          ## health, danger
const C_BLOOD := Color("9f294e")
const C_CURSE := Color("b96be0")        ## sickly purple for cursed things
const C_CURSE_DARK := Color("2a1634")
const C_GREEN := Color("4ba747")
const C_BLUE := Color("5698cc")
const C_ICE := Color("72d6ce")

# ------------------------------------------------------------------ icons the screens share
## Raven Fantasy Icons already in assets/art/icons (16 x 16, drawn at whole multiples, nearest).
const ICON_ATTACK := "icon_gilded_blade"
const ICON_SKILLS := "skill_firebolt"
const ICON_GUARD := "gear_helm_warden"
const ICON_FLEE := "icon_swift_tonic"
const ICON_SHIELD := "ui_shield"         ## cut by tools/import_icons.py (EXTRA, "ui_*"); see icon_or()
const ICON_BOOT := "ui_boot"
const ICON_BOOK := "ui_book"
const ICON_COIN := "icon_tithe_imp"       ## the same gold coin picture as the old Tithe Imp item

# ------------------------------------------------------------------ key prompts
## THE binding table the prompts show. It mirrors scripts/core/controls.gd and the engine's ui_*
## actions exactly; change a key there, change it here. "hold" = the verb means holding it down.
const PROMPTS := {
	"confirm": {"key": "Enter", "pad": "A"},
	"back": {"key": "Esc", "pad": "B"},
	"talk": {"key": "Q", "pad": "LB"},
	"knight": {"key": "C", "pad": "Y"},
	"pause": {"key": "Esc", "pad": "Start"},
	"fast": {"key": "Space", "pad": "A", "hold": true},
	"page": {"key": "Q/E", "pad": "LB/RB"},
	"page_prev": {"key": "Q", "pad": "LB"},
	"page_next": {"key": "E", "pad": "RB"},
	"target": {"key": "< >", "pad": "D-pad"},
	"move": {"key": "WASD", "pad": "L"},
}

# ------------------------------------------------------------------ fonts
## Two OFL families (assets/fonts/hd/, credits in scripts/data/credits.gd) + the pixel logo font.
const HD_DIR := "res://assets/fonts/hd/"
const FONT_DIR := "res://assets/fonts/"
const FONT_DISPLAY := "display.ttf"      ## Alkhemikal: the "Hollow Hill" logo only
const FONT_BODY := "body.ttf"            ## m5x7: old pixel text (kept for anyone who asks for it)
const DISPLAY_PX := 16
const BODY_PX := 8

static var font_body: Font               ## Alegreya Sans Medium: body, buttons, lists
static var font_bold: Font               ## Alegreya Sans Bold: names
static var font_num: Font                ## Alegreya Sans ExtraBold, lining + tabular figures: numbers, key caps
static var font_head: Font               ## Cinzel 700: heads, names on plates, tabs, titles (caps)
static var font_logo: Font               ## Alkhemikal (pixel, no smoothing): the logo, at whole multiples of 16 SCREEN px
static var font_display: Font            ## old name: = font_head
static var font_pixel: Font              ## old m5x7 body font (unused by the new look)

## Sizes in UI px. Set per tier (PC / phone) by _apply_tier(); read them, never hard-code.
static var size_body := 12       ## body text, buttons, lists
static var size_talk := 14       ## the talk box's words
static var size_small := 10      ## hints, small print (never below 9 on PC, 7 on phone)
static var size_name := 12       ## names (Bold)
static var size_num := 12        ## numbers (ExtraBold)
static var size_head := 13       ## Cinzel heads
static var size_title := 20      ## screen titles
static var size_banner := 24     ## the place banner
static var size_display := 40    ## VICTORY / FALLEN
static var size_key := 9         ## the letter on a key cap
static var cap_h := 12.0         ## a key cap's height
static var line_body := 15       ## line height for body text
static var line_talk := 18
static var cut := 3.0            ## panel corner cut
static var row_h := 19.0         ## a list row / Row button's height
static var pixel_fonts := false  ## old: true when pixel fonts were the theme's fonts (never now)
static var body_px := BODY_PX
static var display_px := DISPLAY_PX
## Testing only (old): a folder to read display.ttf / body.ttf from (--fonts=<dir>).
static var font_dir_override := ""
static var _theme: Theme
static var _boxes := {}
static var _used_rects := {}
static var _tier := ""
## Set by the UI tour so animations do not blur its screenshots. Turns off ALL UI motion.
static var instant := false
## Test override for the phone's safe area, in game pixels: left, top, right, bottom (--safe=l,t,r,b).
static var fake_safe := Vector4.ZERO

const SIZES := {
	"pc": {"body": 12, "talk": 14, "small": 10, "name": 12, "num": 12, "head": 13, "title": 20, "banner": 24,
		"display": 40, "key": 9, "cap": 12, "line_body": 15, "line_talk": 18, "cut": 3.0, "row": 19.0},
	"phone": {"body": 10, "talk": 10, "small": 8, "name": 9, "num": 9, "head": 9, "title": 13, "banner": 13,
		"display": 24, "key": 7, "cap": 9, "line_body": 12, "line_talk": 12, "cut": 2.0, "row": 20.0},
}


## The size for a kind of text: "body", "talk", "small", "name", "num", "head", "title", "banner",
## "display", "key". Unknown kinds give the body size.
static func fs(kind: String) -> int:
	_apply_tier()
	return int(SIZES[_tier].get(kind, SIZES[_tier]["body"]))


## True on a phone (and with the test flag --uiphone): the UI grid is the game's 400 x 180 grid.
static func is_phone() -> bool:
	return OS.has_feature("mobile") or G.flag("uiphone")


static func _apply_tier() -> void:
	var t := "phone" if is_phone() else "pc"
	if t == _tier:
		return
	_tier = t
	var s: Dictionary = SIZES[t]
	size_body = s["body"]
	size_talk = s["talk"]
	size_small = s["small"]
	size_name = s["name"]
	size_num = s["num"]
	size_head = s["head"]
	size_title = s["title"]
	size_banner = s["banner"]
	size_display = s["display"]
	size_key = s["key"]
	cap_h = s["cap"]
	line_body = s["line_body"]
	line_talk = s["line_talk"]
	cut = s["cut"]
	row_h = s["row"]


# ------------------------------------------------------------------ the UI grid
## "Text size" setting -> how many UI px tall the PC grid is (smaller number = bigger interface).
const TARGET_H := {"small": 420.0, "normal": 360.0, "large": 300.0}
const UiRootScript = preload("res://scripts/ui/kit/ui_root.gd")


## The Text size in use: --uisize=small|normal|large wins over the saved setting "ui_size".
static func ui_size_name() -> String:
	var n := G.arg("uisize")
	if n == "":
		n = String(Save.setting("ui_size"))
	return n if TARGET_H.has(n) else "normal"


## [p, s] for the current window: p = screen px per UI px, s = screen px per game px.
static func grid_scale(tree: SceneTree) -> Vector2:
	var win := Vector2(tree.root.size)
	var vp := tree.root.get_visible_rect().size
	var s := win.y / maxf(vp.y, 1.0) if win.y > 0.0 else 1.0
	s = maxf(s, 0.01)
	var p := s
	if not is_phone():
		p = maxf(1.0, roundf(win.y / float(TARGET_H[ui_size_name()]) * 2.0) / 2.0)
	return Vector2(p, s)


## Puts a CanvasLayer on the UI grid and returns its root Control: add every child to the root
## and anchor them to it as usual. The root refits itself when the window changes size and on
## UI.refit_all() (the Text size setting). layer.scale is owned by it from now on.
static func attach(layer: CanvasLayer) -> Control:
	if layer.has_meta("ui_root") and is_instance_valid(layer.get_meta("ui_root")):
		return layer.get_meta("ui_root")
	var root: Control = UiRootScript.new()
	root.name = "UiRoot"
	root.set("layer", layer)
	layer.set_meta("ui_root", root)
	layer.add_child(root)
	if root.is_inside_tree():
		root.call("fit")
	return root


## Refits every attached layer (call after the Text size setting changed).
static func refit_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group("ui_root", "fit")


## The UiRoot a node lives under (or the root of the CanvasLayer it is in), else null.
static func ui_root_of(node: Node) -> Control:
	var n := node
	while n != null:
		if n.has_meta("ui_root"):
			var r: Variant = n.get_meta("ui_root")
			if r is Control and is_instance_valid(r):
				return r
			if r is bool and n is Control:
				return n
		if n is CanvasLayer:
			return null
		n = n.get_parent()
	return null


## Screen pixels per layout pixel for this node: p under a UiRoot, else the game's stretch.
static func ui_px(node: Node) -> float:
	var r := ui_root_of(node)
	if r != null:
		return float(r.get("px"))
	if node != null and node.is_inside_tree():
		return grid_scale(node.get_tree()).y
	return 1.0


## Size of the screen in the node's layout pixels: the UiRoot's size under one (UI px), else the
## viewport (game px: always 180 tall; the width depends on the screen).
static func screen_size(node: Node) -> Vector2:
	var r := ui_root_of(node)
	if r != null:
		return r.size
	return node.get_viewport().get_visible_rect().size


## How far the phone's notch / rounded corners push in from each edge, in the node's layout
## pixels (UI px under a UiRoot, game px otherwise). x = left, y = top, z = right, w = bottom.
static func safe_insets(node: Node) -> Vector4:
	var per_game := 1.0
	if ui_root_of(node) != null and node.is_inside_tree():
		var g := grid_scale(node.get_tree())
		per_game = g.y / maxf(ui_px(node), 0.01)       # UI px per game px
	if fake_safe != Vector4.ZERO:
		return (fake_safe * per_game).ceil()
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var k := 1.0 / maxf(ui_px(node), 0.01)              # layout px per screen px
	var out := Vector4(
		maxf(safe.position.x, 0.0) * k,
		maxf(safe.position.y, 0.0) * k,
		maxf(win.x - safe.end.x, 0.0) * k,
		maxf(win.y - safe.end.y, 0.0) * k)
	var cap := screen_size(node)
	# never trust a silly value from a strange device
	return Vector4(ceilf(minf(out.x, cap.x * 0.15)), ceilf(minf(out.y, cap.y * 0.17)), ceilf(minf(out.z, cap.x * 0.15)), ceilf(minf(out.w, cap.y * 0.17)))


## A full-screen container that keeps its children inside the safe area plus a small margin.
static func safe_margin(node: Node, margin: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := safe_insets(node) if node.is_inside_tree() else Vector4.ZERO
	m.add_theme_constant_override("margin_left", margin + int(s.x))
	m.add_theme_constant_override("margin_top", margin + int(s.y))
	m.add_theme_constant_override("margin_right", margin + int(s.z))
	m.add_theme_constant_override("margin_bottom", margin + int(s.w))
	return m


# ------------------------------------------------------------------ drawing kit (RenderingServer)
## Shared by the StyleBoxes below and the kit widgets: draw on any canvas item RID.
static func octa(r: Rect2, c: float) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])


static func vgrad(pts: PackedVector2Array, r: Rect2, top: Color, bot: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bot, clampf((q.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	return cols


## A rect filled with a horizontal gradient a -> b (left -> right).
static func rs_hgrad(ci: RID, r: Rect2, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([a, b, b, a]))


## A rect filled with a vertical gradient a -> b (top -> bottom).
static func rs_vgrad(ci: RID, r: Rect2, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([a, a, b, b]))


## A line that fades from colour a to colour b.
static func rs_rule(ci: RID, from: Vector2, to: Vector2, a: Color, b: Color, width := 1.0) -> void:
	RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([from, to]), PackedColorArray([a, b]), width, true)


## The lozenge ornament: a small diamond (ink rim, coloured body) with optional brass rules fading
## out to each side (rule_len UI px).
static func rs_lozenge(ci: RID, at: Vector2, s: float, col: Color, rule_len := 20.0) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]),
		PackedColorArray([Color(C_INK, 0.95)]))
	var k := maxf(s - 1.0, 0.8)
	rs.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k), at + Vector2(-k, 0)]),
		PackedColorArray([col]))
	if rule_len > 0.0:
		for side: float in [-1.0, 1.0]:
			rs_rule(ci, at + Vector2(side * (s + 2.0), 0), at + Vector2(side * (s + 2.0 + rule_len), 0), Color(col, 0.9), Color(col, 0.0))


## The flame pointer (focus cursor): a lozenge stretched sideways, ink rim, ember body, pale core.
## `at` = its centre; it points right.
static func rs_flame(ci: RID, at: Vector2, alpha := 1.0) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(-4, 0), at + Vector2(0, -3.5), at + Vector2(5, 0), at + Vector2(0, 3.5)]),
		PackedColorArray([Color(C_INK, 0.9 * alpha)]))
	rs.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(-3, 0), at + Vector2(0, -2.5), at + Vector2(4, 0), at + Vector2(0, 2.5)]),
		PackedColorArray([Color(C_EMBER, alpha)]))
	rs.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(-1, 0), at + Vector2(0.5, -1.2), at + Vector2(2.2, 0), at + Vector2(0.5, 1.2)]),
		PackedColorArray([Color(1, 0.95, 0.75, alpha)]))


## The focus sweep under a row: ember light from the left, gold hairlines over the left 60%.
static func rs_sweep(ci: RID, r: Rect2, alpha := 0.34) -> void:
	rs_hgrad(ci, r, Color(C_EMBER, alpha), Color(C_EMBER, 0.0))
	var mid := r.position.x + r.size.x * 0.6
	rs_rule(ci, Vector2(r.position.x, r.position.y + 0.5), Vector2(mid, r.position.y + 0.5), Color(C_GOLD, 0.55), Color(C_GOLD, 0.0))
	rs_rule(ci, Vector2(r.position.x, r.end.y - 0.5), Vector2(mid, r.end.y - 0.5), Color(C_GOLD, 0.35), Color(C_GOLD, 0.0))


# ------------------------------------------------------------------ the glass box
## THE PANEL (successor of StoneBox): night glass (a dark see-through vertical gradient), a fine
## brass hairline round cut corners, a faint inner line, a sheen under the top edge, a soft shadow,
## and an optional lozenge ornament on the middle of the top edge.
class GlassBox extends StyleBox:
	var fill_top := Color(0.085, 0.10, 0.16, 0.80)
	var fill_bot := Color(0.03, 0.035, 0.06, 0.90)
	var edge := Color(0.78, 0.62, 0.36, 0.45)
	var inner := Color(1, 1, 1, 0.045)
	var sheen := Color(1, 0.95, 0.85, 0.08)
	var cut_size := 3.0
	var shadow_size := 10
	var shadow_alpha := 0.45
	var ornament := false
	var ornament_color := Color(0.78, 0.62, 0.36)
	var draw_fill := true
	var _shadow: StyleBoxFlat

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := rect
		if r.size.x < 4.0 or r.size.y < 4.0:
			return
		var rs := RenderingServer
		if shadow_alpha > 0.0 and shadow_size > 0:
			if _shadow == null:
				_shadow = StyleBoxFlat.new()
				_shadow.bg_color = Color(0, 0, 0, 0)
				_shadow.draw_center = false
				_shadow.set_corner_radius_all(4)
			_shadow.shadow_color = Color(0, 0, 0, shadow_alpha)
			_shadow.shadow_size = shadow_size
			_shadow.shadow_offset = Vector2(0, 3)
			_shadow.draw(ci, r)
		var c := minf(cut_size, minf(r.size.x, r.size.y) * 0.3)
		var pts: PackedVector2Array = (load("res://scripts/ui/theme.gd") as GDScript).call("octa", r, c)
		if draw_fill:
			var cols := PackedColorArray()
			for q in pts:
				cols.append(fill_top.lerp(fill_bot, clampf((q.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
			rs.canvas_item_add_polygon(ci, pts, cols)
		if edge.a > 0.0:
			var line := pts.duplicate()
			line.append(pts[0])
			rs.canvas_item_add_polyline(ci, line, PackedColorArray([edge]), 1.0, true)
		if inner.a > 0.0 and r.size.x > 10.0 and r.size.y > 10.0:
			var ip: PackedVector2Array = (load("res://scripts/ui/theme.gd") as GDScript).call("octa", r.grow(-2.5), maxf(c - 1.0, 1.0))
			ip.append(ip[0])
			rs.canvas_item_add_polyline(ci, ip, PackedColorArray([inner]), 1.0, true)
		if sheen.a > 0.0 and r.size.x > 16.0:
			rs.canvas_item_add_line(ci, Vector2(r.position.x + 6, r.position.y + 1.5), Vector2(r.end.x - 6, r.position.y + 1.5), sheen, 1.0)
		if ornament and r.size.x > 60.0:
			(load("res://scripts/ui/theme.gd") as GDScript).call("rs_lozenge", ci, Vector2(roundf(r.position.x + r.size.x * 0.5), r.position.y), 3.0, ornament_color, 20.0)


## The focus / hover / pressed look of a row: the ember sweep. With `edge` set (Big buttons) a
## cut-corner outline in that colour is drawn round it too.
class SweepBox extends StyleBox:
	var alpha := 0.34
	var edge := Color(0, 0, 0, 0)
	var cut_size := 3.0
	var inset := 0.0

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := rect.grow(-inset)
		if r.size.x < 4.0 or r.size.y < 4.0:
			return
		var ui := load("res://scripts/ui/theme.gd") as GDScript
		ui.call("rs_sweep", ci, r, alpha)
		if edge.a > 0.0:
			var pts: PackedVector2Array = ui.call("octa", rect, cut_size)
			pts.append(pts[0])
			RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([edge]), 1.0, true)


## The selected tab: a gold underline with a small lozenge in its middle.
class TabMark extends StyleBox:
	func _draw(ci: RID, rect: Rect2) -> void:
		var y := rect.end.y - 1.5
		RenderingServer.canvas_item_add_line(ci, Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), Color(0.96, 0.80, 0.47), 1.5, true)
		(load("res://scripts/ui/theme.gd") as GDScript).call("rs_lozenge", ci, Vector2(roundf(rect.get_center().x), y), 2.0, Color(0.96, 0.80, 0.47), 0.0)


## OLD: the flat stone slab of the phone UI. Nothing in the theme uses it any more; kept so code
## that names it still compiles (it draws as a glass card now).
class StoneBox extends StyleBox:
	var fill := Color("21212c")
	var edge := Color("4b5a6e")
	var outline := Color("0e0d12")
	var inner_top := Color(0, 0, 0, 0)
	var inner_bottom := Color(0, 0, 0, 0)
	var draw_fill := true
	var trim := Color(0, 0, 0, 0)
	var studs := Color(0, 0, 0, 0)
	var top_light := Color(0, 0, 0, 0)

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := rect
		if r.size.x < 4.0 or r.size.y < 4.0:
			return
		var ui := load("res://scripts/ui/theme.gd") as GDScript
		var pts: PackedVector2Array = ui.call("octa", r, 3.0)
		if draw_fill:
			RenderingServer.canvas_item_add_polygon(ci, pts, ui.call("vgrad", pts, r, Color(fill.lightened(0.05), 0.85), Color(fill.darkened(0.3), 0.92)))
		pts.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([Color(edge, 0.7)]), 1.0, true)


static func glass(margin_x: float, margin_y: float, edge := C_BRASS_DIM, ornament := false) -> GlassBox:
	_apply_tier()
	var g := GlassBox.new()
	g.edge = edge
	g.ornament = ornament
	g.ornament_color = C_BRASS
	g.cut_size = cut
	g.content_margin_left = margin_x
	g.content_margin_right = margin_x
	g.content_margin_top = margin_y
	g.content_margin_bottom = margin_y
	return g


## Named panel looks. Screens ask for these by name so the look is defined once.
##   "panel"   major panels (menus, choice lists, detail cards): glass + lozenge ornament
##   "card"    smaller panels: glass, no ornament          "tooltip" = card
##   "plate"   name plates: full brass edge, small margins  "well"   sunken list area (darker, no sheen)
##   "gold"    acting / selected (gold edge)                "danger" monster / warning (foe edge)
## Old names still work: "talk" (card), "portrait" (well), "slot" / "slot_focus" (well / gold, small
## margins), "hud" (light card), "tag" (gold plate), "curse" (purple edge).
static func box(kind: String) -> StyleBox:
	_apply_tier()
	if _boxes.has(kind):
		return _boxes[kind]
	var ph := is_phone()
	var mx := 6.0 if ph else 10.0
	var my := 4.0 if ph else 8.0
	var sb: GlassBox
	match kind:
		"card", "tooltip", "talk":
			sb = glass(mx, my)
		"plate":
			sb = glass(6.0 if ph else 8.0, 2.0 if ph else 3.0, C_BRASS)
			sb.shadow_size = 6
		"well", "portrait":
			sb = glass(4.0 if ph else 6.0, 3.0 if ph else 4.0, Color(C_BRASS, 0.22))
			sb.fill_top = Color(0.01, 0.012, 0.02, 0.55)
			sb.fill_bot = Color(0.02, 0.024, 0.04, 0.70)
			sb.sheen = Color(0, 0, 0, 0)
			sb.inner = Color(0, 0, 0, 0.25)
			sb.shadow_alpha = 0.0
		"gold":
			sb = glass(mx, my, C_GOLD)
		"danger":
			sb = glass(mx, my, Color(C_FOE, 0.7))
		"curse":
			sb = glass(mx, my, Color(C_CURSE, 0.8))
			sb.fill_top = Color(0.12, 0.06, 0.16, 0.82)
		"tag":
			sb = glass(4.0, 2.0, C_GOLD)
			sb.shadow_size = 4
		"slot":
			sb = glass(3.0, 2.0, Color(C_BRASS, 0.22))
			sb.fill_top = Color(0.01, 0.012, 0.02, 0.5)
			sb.fill_bot = Color(0.02, 0.024, 0.04, 0.65)
			sb.sheen = Color(0, 0, 0, 0)
			sb.shadow_alpha = 0.0
		"slot_focus":
			sb = glass(3.0, 2.0, C_GOLD)
			sb.fill_top = Color(0.20, 0.13, 0.06, 0.6)
			sb.shadow_alpha = 0.0
		"hud":
			sb = glass(4.0 if ph else 6.0, 2.0 if ph else 4.0, Color(C_BRASS, 0.3))
			sb.fill_top = Color(0.03, 0.035, 0.06, 0.55)
			sb.fill_bot = Color(0.02, 0.025, 0.045, 0.70)
			sb.shadow_size = 6
			sb.shadow_alpha = 0.3
		_:
			sb = glass(mx, my, C_BRASS_DIM, true)
	_boxes[kind] = sb
	return sb


# ------------------------------------------------------------------ the theme
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_apply_tier()
	_load_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = size_body
	var ph := is_phone()

	# labels
	t.set_color("font_color", "Label", C_PARCH)
	t.set_color("font_outline_color", "Label", Color(C_INK, 0.85))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 1 if not ph else 0)
	_label_kind(t, "Body", font_body, size_body, C_PARCH)
	_label_kind(t, "Talk", font_body, size_talk, C_PARCH)
	_label_kind(t, "Small", font_body, size_small, C_DIM)
	_label_kind(t, "Dim", font_body, size_body, C_DIM)
	_label_kind(t, "Faint", font_body, size_body, C_FAINT)
	_label_kind(t, "Gold", font_body, size_body, C_GOLD)
	_label_kind(t, "Red", font_body, size_body, C_BAD)
	_label_kind(t, "Good", font_body, size_body, C_GOOD)
	_label_kind(t, "Curse", font_body, size_body, C_CURSE)
	_label_kind(t, "Name", font_bold, size_name, C_PARCH)
	_label_kind(t, "Num", font_num, size_num, C_PARCH)
	_label_kind(t, "Head", font_head, size_head, C_PARCH)
	_label_kind(t, "Title", font_head, size_title, C_PARCH)
	_label_kind(t, "Banner", font_head, size_banner, C_PARCH)
	_label_kind(t, "Display", font_head, size_display, C_GOLD)
	# text straight on the world gets an ink outline
	_label_kind(t, "Hud", font_body, size_body, C_PARCH)
	t.set_constant("outline_size", "Hud", 3)
	_label_kind(t, "HudHead", font_head, size_head, C_PARCH)
	t.set_constant("outline_size", "HudHead", 4)
	t.set_constant("outline_size", "Banner", 5)
	t.set_constant("outline_size", "Display", 5)

	# rich text
	t.set_font("normal_font", "RichTextLabel", font_body)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", size_body)
	t.set_font_size("bold_font_size", "RichTextLabel", size_body)
	t.set_color("default_color", "RichTextLabel", C_PARCH)

	# buttons: the "Row" look by default (no slab; focus = hover = the ember sweep, gold text)
	var mx := 6.0 if ph else 8.0
	var row_normal := _empty(mx, 2.0)
	var row_focus := SweepBox.new()
	var row_pressed := SweepBox.new()
	row_pressed.alpha = 0.5
	_margins(row_pressed, mx, 3.0, 1.0)
	for type: String in ["Button", "CheckButton", "OptionButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", type, row_normal)
		t.set_stylebox("hover", type, row_normal)
		t.set_stylebox("pressed", type, row_pressed)
		t.set_stylebox("hover_pressed", type, row_pressed)
		t.set_stylebox("disabled", type, row_normal)
		t.set_stylebox("focus", type, row_focus)
		t.set_font("font", type, font_body)
		t.set_font_size("font_size", type, size_body)
		t.set_color("font_color", type, C_PARCH)
		t.set_color("font_hover_color", type, C_GOLD)
		t.set_color("font_focus_color", type, C_GOLD)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, C_FAINT)
		t.set_color("font_outline_color", type, Color(C_INK, 0.85))
		t.set_color("icon_normal_color", type, Color(1, 1, 1, 0.85))
		t.set_color("icon_hover_color", type, Color.WHITE)
		t.set_color("icon_focus_color", type, Color.WHITE)
		t.set_color("icon_pressed_color", type, Color.WHITE)
		t.set_color("icon_disabled_color", type, Color(0.45, 0.45, 0.48, 0.7))
		t.set_constant("h_separation", type, 6 if not ph else 4)
	t.set_type_variation("Row", "Button")
	# "Big": the main call to action (Play, Continue, Resume): a glass plate, Cinzel, gold edge on focus
	t.set_type_variation("Big", "Button")
	var big := glass(12.0 if not ph else 8.0, 4.0 if not ph else 3.0, C_BRASS_DIM)
	big.shadow_size = 6
	var big_focus := SweepBox.new()
	big_focus.edge = C_GOLD
	big_focus.cut_size = cut
	big_focus.inset = 1.0
	var big_disabled := glass(12.0 if not ph else 8.0, 4.0 if not ph else 3.0, Color(C_BRASS, 0.18))
	t.set_stylebox("normal", "Big", big)
	t.set_stylebox("hover", "Big", big)
	t.set_stylebox("pressed", "Big", big)
	t.set_stylebox("hover_pressed", "Big", big)
	t.set_stylebox("disabled", "Big", big_disabled)
	t.set_stylebox("focus", "Big", big_focus)
	t.set_font("font", "Big", font_head)
	t.set_font_size("font_size", "Big", size_head)
	# "Flat": arrows and small buttons that should not look like anything until focused
	t.set_type_variation("Flat", "Button")
	t.set_stylebox("normal", "Flat", _empty(4.0, 2.0))
	t.set_stylebox("hover", "Flat", _empty(4.0, 2.0))
	t.set_stylebox("disabled", "Flat", _empty(4.0, 2.0))
	# "Tab": Cinzel caps; the selected tab (disabled, or pressed in toggle mode) is gold with an underline
	t.set_type_variation("Tab", "Button")
	var tab_n := _empty(6.0, 3.0)
	var tab_sel := TabMark.new()
	_margins(tab_sel, 6.0, 3.0)
	t.set_stylebox("normal", "Tab", tab_n)
	t.set_stylebox("hover", "Tab", tab_n)
	t.set_stylebox("disabled", "Tab", tab_sel)
	t.set_stylebox("pressed", "Tab", tab_sel)
	t.set_stylebox("hover_pressed", "Tab", tab_sel)
	t.set_font("font", "Tab", font_head)
	t.set_font_size("font_size", "Tab", size_head - 2)
	t.set_color("font_color", "Tab", C_DIM)
	t.set_color("font_disabled_color", "Tab", C_GOLD)
	t.set_color("font_pressed_color", "Tab", C_GOLD)
	t.set_color("font_hover_pressed_color", "Tab", C_GOLD)
	# "Mini": the square "+" stat buttons (15 x 15), ember when focused
	t.set_type_variation("Mini", "Button")
	var mini := StyleBoxFlat.new()
	mini.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	mini.set_corner_radius_all(3)
	mini.border_color = Color(C_BRASS, 0.6)
	mini.set_border_width_all(1)
	mini.anti_aliasing = true
	mini.set_content_margin_all(1.0)
	var mini_on := mini.duplicate() as StyleBoxFlat
	mini_on.bg_color = Color(C_EMBER, 0.85)
	var mini_off := mini.duplicate() as StyleBoxFlat
	mini_off.bg_color = Color(0.06, 0.06, 0.08, 0.6)
	mini_off.border_color = Color(C_BRASS, 0.2)
	t.set_stylebox("normal", "Mini", mini)
	t.set_stylebox("hover", "Mini", mini_on)
	t.set_stylebox("pressed", "Mini", mini_on)
	t.set_stylebox("hover_pressed", "Mini", mini_on)
	t.set_stylebox("focus", "Mini", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Mini", mini_off)
	t.set_font("font", "Mini", font_num)
	t.set_font_size("font_size", "Mini", size_num)
	t.set_color("font_focus_color", "Mini", C_INK)
	t.set_color("font_hover_color", "Mini", C_INK)
	t.set_color("font_pressed_color", "Mini", C_INK)
	# "Danger": a row whose words warn (Reset progress, Give up, Quit)
	t.set_type_variation("Danger", "Button")
	for key: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(key, "Danger", C_BAD)

	# panels
	t.set_stylebox("panel", "PanelContainer", box("panel"))
	t.set_stylebox("panel", "Panel", box("panel"))
	t.set_stylebox("panel", "TooltipPanel", box("tooltip"))
	t.set_stylebox("panel", "PopupPanel", box("card"))
	t.set_stylebox("panel", "PopupMenu", box("card"))
	t.set_color("font_color", "TooltipLabel", C_PARCH)
	t.set_font_size("font_size", "TooltipLabel", size_small)
	t.set_color("font_color", "PopupMenu", C_PARCH)
	t.set_color("font_hover_color", "PopupMenu", C_GOLD)
	t.set_stylebox("hover", "PopupMenu", SweepBox.new())

	# text fields sit in a well; a gold edge when focused
	var le := box("well").duplicate() as GlassBox
	var le_focus := glass(6.0, 4.0, C_GOLD)
	le_focus.draw_fill = false
	le_focus.shadow_alpha = 0.0
	le_focus.inner = Color(0, 0, 0, 0)
	le_focus.sheen = Color(0, 0, 0, 0)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", C_PARCH)
	t.set_color("font_placeholder_color", "LineEdit", C_FAINT)
	t.set_color("caret_color", "LineEdit", C_GOLD)
	t.set_color("selection_color", "LineEdit", Color(C_EMBER, 0.35))

	# thin brass scrollbars: a 2 UI px track, a 3 UI px grabber
	var track := StyleBoxFlat.new()
	track.bg_color = Color(C_INK, 0.55)
	track.set_corner_radius_all(1)
	track.content_margin_left = 1.0
	track.content_margin_right = 1.0
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(C_BRASS, 0.6)
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 1.5
	grab.content_margin_right = 1.5
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = C_GOLD
	for sbar: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbar, track)
		t.set_stylebox("scroll_focus", sbar, track)
		t.set_stylebox("grabber", sbar, grab)
		t.set_stylebox("grabber_highlight", sbar, grab_hi)
		t.set_stylebox("grabber_pressed", sbar, grab_hi)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())

	# separators: a brass hairline
	var line := StyleBoxLine.new()
	line.color = Color(C_BRASS, 0.25)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = Color(C_BRASS, 0.25)
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "HSeparator", 5 if not ph else 3)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 4 if not ph else 3)
	t.set_constant("h_separation", "GridContainer", 4 if not ph else 3)
	t.set_constant("v_separation", "GridContainer", 2)
	t.set_constant("h_separation", "HFlowContainer", 3 if not ph else 2)
	t.set_constant("v_separation", "HFlowContainer", 2)
	_theme = t
	return t


static func _empty(margin_x: float, margin_y: float) -> StyleBoxEmpty:
	var e := StyleBoxEmpty.new()
	_margins(e, margin_x, margin_y)
	return e


static func _margins(sb: StyleBox, margin_x: float, margin_y: float, down := 0.0) -> void:
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y + down
	sb.content_margin_bottom = margin_y - down


static func _label_kind(t: Theme, kind: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(kind, "Label")
	t.set_font("font", kind, font)
	t.set_font_size("font_size", kind, size)
	t.set_color("font_color", kind, color)


static func _load_fonts() -> void:
	if font_body != null:
		return
	_apply_tier()
	var medium := _hd_font("AlegreyaSans-Medium.ttf")
	var bold := _hd_font("AlegreyaSans-Bold.ttf")
	var extra := _hd_font("AlegreyaSans-ExtraBold.ttf")
	var cinzel := _hd_font("Cinzel-Variable.ttf")
	font_body = medium if medium != null else ThemeDB.fallback_font
	font_bold = bold if bold != null else font_body
	var num := FontVariation.new()
	num.base_font = extra if extra != null else font_bold
	num.opentype_features = {"lnum": 1, "tnum": 1}
	font_num = num
	if cinzel != null:
		var head := FontVariation.new()
		head.base_font = cinzel
		head.variation_opentype = {"wght": 700}
		font_head = head
	else:
		font_head = font_bold
	font_display = font_head
	var logo := _pixel_font(FONT_DISPLAY)
	font_logo = logo if logo != null else font_head
	font_pixel = _pixel_font(FONT_BODY)
	pixel_fonts = false


## One of the HD fonts, smooth: greyscale antialiasing, NO hinting, sub-pixel placement. (The UI
## grid's glyphs are made at exactly the screen's size (ui_root.gd sets the oversampling); hinting
## at that size snapped Cinzel's hairlines away and squeezed the spaces between words.)
static func _hd_font(file_name: String) -> FontFile:
	var path := HD_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	var f := load(path) as FontFile
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


## A pixel font (the logo): hard pixel edges, no smoothing, no hinting, no sub-pixel placement.
static func _pixel_font(file_name: String) -> Font:
	var f: FontFile = null
	if font_dir_override != "":
		var ff := FontFile.new()
		if ff.load_dynamic_font(font_dir_override.path_join(file_name)) == OK:
			f = ff
	elif ResourceLoader.exists(FONT_DIR + file_name):
		f = load(FONT_DIR + file_name) as FontFile
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f


## The logo size (Alkhemikal is a 16 px pixel font): the biggest whole multiple of 16 SCREEN px that
## stays at or under `max_ui` UI px on this node's grid. Returns UI px.
static func logo_size(node: Node, max_ui: float) -> float:
	var p := ui_px(node)
	var n := maxf(floorf(max_ui * p / 16.0), 1.0)
	return 16.0 * n / p


## The sizes a big title may shrink through when the text is too wide.
static func title_sizes() -> Array[int]:
	_apply_tier()
	var out: Array[int] = []
	var s := size_title
	while s >= size_head:
		out.append(s)
		s -= 2
	if out.is_empty():
		out.append(size_head)
	return out


## The look of the biggest words (game name, Victory, Fallen): an ink outline and a soft drop.
static func style_title(lab: Label, colour: Color, shadow: Color) -> void:
	lab.add_theme_color_override("font_color", colour)
	lab.add_theme_color_override("font_shadow_color", Color(shadow, minf(shadow.a, 0.6)))
	lab.add_theme_color_override("font_outline_color", Color(C_INK, 0.85))
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 2)
	lab.add_theme_constant_override("shadow_outline_size", 4)
	lab.add_theme_constant_override("outline_size", 4)


## Shrinks a title label step by step until its text fits in max_width (then lets it wrap).
static func fit_title(lab: Label, max_width: float) -> void:
	_load_fonts()
	var font: Font = lab.get_theme_font("font") if lab.is_inside_tree() else font_head
	var sizes := title_sizes()
	var chosen: int = sizes[sizes.size() - 1]
	for s in sizes:
		if font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_width:
			chosen = s
			break
	lab.add_theme_font_size_override("font_size", chosen)
	if font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > max_width:
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = max_width


# ------------------------------------------------------------------ small builders
const CAPS_KINDS := ["Head", "Title", "Banner", "Display", "HudHead"]


## A text label. kind is one of "", "Body", "Talk", "Small", "Dim", "Faint", "Gold", "Red", "Good",
## "Curse", "Name", "Num", "Head", "Title", "Banner", "Display", "Hud", "HudHead".
## Cinzel kinds (Head, Title, Banner, Display, HudHead) are shown in capitals.
static func label(text: String, kind: String = "", wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if kind != "":
		l.theme_type_variation = kind
		if kind in CAPS_KINDS:
			l.uppercase = true
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A button that clicks, squashes a little when pressed, takes the focus under the mouse, and
## calls `action` when released. kind: "" (= Row), "Row", "Big", "Flat", "Tab", "Mini", "Danger".
static func button(text: String, action: Callable = Callable(), kind: String = "", sound: String = "ui_click") -> Button:
	_apply_tier()
	var b := Button.new()
	b.text = text
	if kind != "":
		b.theme_type_variation = kind
	match kind:
		"Big":
			b.custom_minimum_size = Vector2(60, 26 if not is_phone() else 26)
		"Mini":
			b.custom_minimum_size = Vector2(15, 15)
		_:
			b.custom_minimum_size = Vector2(26, row_h)
	b.focus_mode = Control.FOCUS_ALL
	juice(b)
	b.pressed.connect(func() -> void:
		if sound != "":
			Sfx.play(sound))
	if action.is_valid():
		b.pressed.connect(action)
	return b


## Makes any button squash when pressed and spring back when released, and makes the mouse move
## the focus onto it (one highlight on a screen, never two).
static func juice(b: BaseButton) -> void:
	b.button_down.connect(func() -> void: _squash(b, Vector2(1.03, 0.92)))
	b.button_up.connect(func() -> void: _squash(b, Vector2.ONE))
	b.mouse_entered.connect(func() -> void:
		if is_instance_valid(b) and b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE and not b.has_focus() and not Controls.using_touch:
			b.grab_focus())


static func _squash(c: Control, to: Vector2) -> void:
	if instant or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", to, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func panel(kind: String = "panel") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(kind))
	return p


static func vbox(sep: int = 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(w: float = 0.0, h: float = 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


# ------------------------------------------------------------------ kit widgets (scripts/ui/kit/)
## A bar: preset "hp", "mp", "xp", "boss", "foe". Then bar.set_value(v, max, animate).
static func bar(preset: String = "hp", width: float = 60.0) -> Control:
	var b: Control = load("res://scripts/ui/kit/bar.gd").new()
	b.call("setup", preset, width)
	return b


## A round portrait coin of a sprite: ring C_STEEL (your side) or C_FOE (monsters).
static func medallion(sprite_id: String, radius: float = 11.0, ring: Color = C_STEEL, active := false, tint := Color.WHITE) -> Control:
	var m: Control = load("res://scripts/ui/kit/medallion.gd").new()
	m.call("setup", sprite_id, radius, ring, active, tint)
	return m


## The ember focus pointer. ONE per screen (screen.gd adds it); it follows the focused control
## inside `scope` (default: its parent).
static func flame(scope: Node = null) -> Control:
	var f: Control = load("res://scripts/ui/kit/focus_flame.gd").new()
	f.set("scope", scope)
	return f


## A key prompt: kind = a PROMPTS key ("confirm", "back", "talk" ...) or any literal key text.
## Shows a key cap on keyboard, a round cap on a pad, nothing on touch. verb = the word after it.
static func prompt(kind: String, verb: String = "") -> Control:
	var p: Control = load("res://scripts/ui/kit/prompt.gd").new()
	p.call("setup", kind, verb)
	return p


## The help strip: pairs [[kind, verb], ...] on a wash, at a corner of its parent:
## "bottom_right" (default), "top_right", "bottom_left", "bottom_center". Hidden on touch.
static func help_strip(pairs: Array, corner: String = "bottom_right") -> Control:
	var h: Control = load("res://scripts/ui/kit/help_strip.gd").new()
	h.call("setup", pairs, corner)
	return h


## A wash: a soft dark gradient behind text on the bare world. fade_to "right" (dark on the left,
## fading out to the right), "left", "both" (dark in the middle), "up", "down".
static func wash(fade_to: String = "right", alpha: float = 0.72) -> Control:
	var w: Control = load("res://scripts/ui/kit/wash.gd").new()
	w.set("fade_to", fade_to)
	w.set("alpha", alpha)
	return w


## The full-screen veil behind full menus: the world softened, darkened, cooled and vignetted.
static func veil() -> Control:
	return load("res://scripts/ui/kit/veil.gd").new()


## The lozenge ornament (a small diamond, optional rules fading out each side).
static func lozenge(half_size: float = 3.0, colour: Color = C_BRASS, rules: float = 20.0) -> Control:
	var o: Control = load("res://scripts/ui/kit/ornament.gd").new()
	o.call("setup", "lozenge", half_size, colour, rules)
	return o


## A brass rule fading out at both ends (or one: fade "both" / "right" / "left"), `width` UI px.
static func rule(width: float = 120.0, colour: Color = C_BRASS, fade: String = "both") -> Control:
	var o: Control = load("res://scripts/ui/kit/ornament.gd").new()
	o.call("setup", "rule_" + fade, width, colour, 0.0)
	return o


## A code-drawn coin disc (gold), radius in UI px.
static func coin(radius: float = 5.0) -> Control:
	var c: Control = load("res://scripts/ui/kit/coin.gd").new()
	c.set("radius", radius)
	return c


## An icon from the art (16 UI px cell by default, whole pixels). Falls back to `fallback` when
## the id does not exist.
static func icon(sprite_id: String, cell: float = 16.0, fallback: String = "") -> Control:
	var id := sprite_id
	if not Art.has(id) and fallback != "":
		id = fallback
	return _sprite_icon(id, Vector2(cell, cell))


## The first of these sprite ids that exists ("" if none): UI.icon_or([ICON_SHIELD, ICON_GUARD]).
static func icon_or(ids: Array) -> String:
	for id: Variant in ids:
		if Art.has(String(id)):
			return String(id)
	return ""


# ------------------------------------------------------------------ motion (all under 0.25 s)
## Panel open: fade 0 -> 1 in 0.14 s, slide `from` UI px back to its place, scale 0.98 -> 1.
static func pop_in(c: Control, from: Vector2 = Vector2(0, 8)) -> void:
	if instant or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.14)
	# The slide waits one frame so containers have already placed the control.
	var slide := func() -> void:
		if not is_instance_valid(c):
			return
		var home := c.position
		c.position = home + from
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(0.98, 0.98)
		var tw2 := c.create_tween().set_parallel(true)
		tw2.tween_property(c, "position", home, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.call_deferred()


## Panel close: a 0.10 s fade, then (free_after) the control is freed.
static func pop_out(c: Control, free_after: bool = true) -> void:
	if not is_instance_valid(c):
		return
	if instant or not c.is_inside_tree():
		if free_after:
			c.queue_free()
		else:
			c.visible = false
		return
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.10)
	if free_after:
		tw.tween_callback(c.queue_free)
	else:
		tw.tween_callback(c.hide)


## Page change (skills replacing commands, tabs): the old page fades out, the new one fades in
## with a 12 UI px slide in the direction of travel (dir +1 = forward / right, -1 = back).
## Either may be null. The old page is hidden (not freed).
static func page_swap(old: Control, new: Control, dir: int = 1) -> void:
	if is_instance_valid(old):
		if instant or not old.is_inside_tree():
			old.visible = false
		else:
			var to := old.create_tween()
			to.tween_property(old, "modulate:a", 0.0, 0.12)
			to.tween_callback(old.hide)
			to.tween_callback(func() -> void: old.modulate.a = 1.0)
	if is_instance_valid(new):
		new.visible = true
		if instant or not new.is_inside_tree():
			new.modulate.a = 1.0
			return
		new.modulate.a = 0.0
		var tn := new.create_tween()
		tn.tween_property(new, "modulate:a", 1.0, 0.12)
		var slide := func() -> void:
			if not is_instance_valid(new):
				return
			var home := new.position
			new.position = home + Vector2(12.0 * dir, 0)
			new.create_tween().tween_property(new, "position", home, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		slide.call_deferred()


# ------------------------------------------------------------------ icons
## THE one place that decides what the small HUD icons are. kind: "coin", "key", "bomb".
## Returns a ready-made control. To swap in a real key sprite later, change only this function.
static func hud_icon(kind: String) -> Control:
	match kind:
		"coin":
			return _sprite_icon("prop_coin", Vector2(11, 11))
		"bomb":
			return _sprite_icon("prop_bomb", Vector2(13, 16))
		"key":
			# The props key (Treasure Hunters, see tools/import_props.py); the old art below is the fallback.
			if Art.has("prop_key"):
				return _sprite_icon("prop_key", Vector2(8, 15))
			if Art.has("niji_key_gold_long"):
				return _sprite_icon("niji_key_gold_long", Vector2(16, 9))
			if ResourceLoader.exists("res://assets/ui/icon_key.png"):
				var tr := TextureRect.new()
				tr.texture = load("res://assets/ui/icon_key.png")
				tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				tr.custom_minimum_size = Vector2(10, 10)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				return tr
			return load("res://scripts/ui/key_glyph.gd").new()
	return spacer(8, 8)


static func _sprite_icon(id: String, cell: Vector2) -> Control:
	# load() instead of preload(): icon.gd preloads this file, so a preload here would be circular
	var ic: Control = load("res://scripts/ui/icon.gd").new()
	ic.call("setup", id, cell)
	return ic


## The part of a sprite that is not empty space (so icons can be centred properly). Cached.
static func used_rect(id: String) -> Rect2:
	if _used_rects.has(id):
		return _used_rects[id]
	var tex := Art.tex(id)
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var u := img.get_used_rect()
		if u.size.x > 0 and u.size.y > 0:
			r = Rect2(u)
	_used_rects[id] = r
	return r


## 75 -> "1:15"
static func time_text(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
