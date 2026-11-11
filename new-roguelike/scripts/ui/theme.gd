extends RefCounted
## Theme: the ONE place that decides how every menu and the HUD look.
## Colours, fonts, panel and button styles, and the little helper functions that build
## labels, buttons, panels and icons all live here. Change a colour or a font size in this
## file and the whole game follows.
## Use with:  const UI = preload("res://scripts/ui/theme.gd")

# ------------------------------------------------------------------ colours (taken from the 0x72 art)
const C_VOID := Color("0b0a10")         ## behind everything
const C_INK := Color("0e0d12")          ## outlines
const C_PANEL := Color("21212c")        ## dark stone panel
const C_PANEL_HI := Color("2e3040")     ## raised stone (buttons)
const C_PANEL_LOW := Color("191921")    ## sunken stone (slots, wells)
const C_EDGE := Color("4b5a6e")         ## the lighter 1 px edge
const C_EDGE_HI := Color("8496aa")
const C_SHADE := Color("14141b")        ## inner shadow
const C_BONE := Color("fdf7ed")         ## main text
const C_DIM := Color("a9b3bd")          ## secondary text
const C_FAINT := Color("66707e")        ## disabled / locked
const C_GOLD := Color("facb3e")         ## coins, highlights, focus
const C_ORANGE := Color("ee8e2e")
const C_RED := Color("da4e38")          ## health, danger
const C_BLOOD := Color("9f294e")
const C_CURSE := Color("b96be0")        ## sickly purple for cursed things
const C_CURSE_DARK := Color("2a1634")
const C_GREEN := Color("4ba747")
const C_BLUE := Color("5698cc")
const C_ICE := Color("72d6ce")

# ------------------------------------------------------------------ fonts
## Drop pixel fonts into this folder under exactly these two names and they are used automatically.
## Without them the engine's built-in font is used.
const FONT_DIR := "res://assets/fonts/"
const FONT_DISPLAY := "display.ttf"      ## big titles and headings
const FONT_BODY := "body.ttf"            ## everything else
## A pixel font is only crisp at whole multiples of the size it was drawn at ("native size").
## The fonts on the project's shortlist are recognised by the name stored inside the file.
## Each row: native size, extra pixels above a line, extra pixels below, extra pixels between letters.
## (Compact fonts get a little air between lines, airy ones lose some, wide ones are tightened a
## pixel, so that every body font ends up with lines 10 to 13 pixels apart on this small screen.)
const FONT_TUNING := {
	"Alkhemikal": [16, 0, 0, 0],
	"Jacquard 12": [21, 0, 0, 0],
	"Jacquard 24": [43, 0, 0, 0],
	"Pixel Operator": [16, -2, -1, 0],
	"Pixel Operator 8": [8, 1, 1, -1],
	"Pixel Operator Mono": [16, -2, -1, 0],
	"Pixel Operator Mono 8": [8, 1, 1, -1],
	"m5x7": [16, -2, -1, 0],
}
## Any other font: set its native size here (the font's own page says what it is).
const DISPLAY_PX := 16
const BODY_PX := 8

static var font_body: Font
static var font_display: Font
static var size_small := 8       ## hints, small print (never below 6 px tall letters)
static var size_body := 9        ## normal text and buttons
static var size_head := 12       ## screen headings, names
static var size_title := 24      ## the game's name, VICTORY, ...
static var pixel_fonts := false  ## true when the pixel fonts above were found
static var body_px := BODY_PX    ## native size of the body font in use
static var display_px := DISPLAY_PX
## Testing only: a folder outside the project to read display.ttf / body.ttf from (--fonts=<dir>).
static var font_dir_override := ""
static var _theme: Theme
static var _boxes := {}
static var _used_rects := {}
## Set by the UI tour so animations do not blur its screenshots.
static var instant := false
## Test override for the phone's safe area, in game pixels: left, top, right, bottom (--safe=l,t,r,b).
static var fake_safe := Vector4.ZERO


# ------------------------------------------------------------------ the stone box
## A flat pixel panel: dark outline with clipped corners, a 1 px lighter edge,
## a fill, and a 1 px inner shadow (or highlight for raised buttons).
class StoneBox extends StyleBox:
	var fill := Color("21212c")
	var edge := Color("4b5a6e")
	var outline := Color("0e0d12")
	var inner_top := Color(0, 0, 0, 0)      ## line just under the top edge
	var inner_bottom := Color(0, 0, 0, 0)   ## line just above the bottom edge
	var draw_fill := true

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := Rect2(rect.position.round(), rect.size.round())
		if r.size.x < 5 or r.size.y < 5:
			return
		var rs := RenderingServer
		var p := r.position
		var s := r.size
		if outline.a > 0.0:
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y, s.x - 2, 1), outline)
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y + s.y - 1, s.x - 2, 1), outline)
			rs.canvas_item_add_rect(ci, Rect2(p.x, p.y + 1, 1, s.y - 2), outline)
			rs.canvas_item_add_rect(ci, Rect2(p.x + s.x - 1, p.y + 1, 1, s.y - 2), outline)
		if draw_fill:
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y + 1, s.x - 2, s.y - 2), edge)
			rs.canvas_item_add_rect(ci, Rect2(p.x + 2, p.y + 2, s.x - 4, s.y - 4), fill)
			if inner_top.a > 0.0:
				rs.canvas_item_add_rect(ci, Rect2(p.x + 2, p.y + 2, s.x - 4, 1), inner_top)
			if inner_bottom.a > 0.0:
				rs.canvas_item_add_rect(ci, Rect2(p.x + 2, p.y + s.y - 3, s.x - 4, 1), inner_bottom)
		else:
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y + 1, s.x - 2, 1), edge)
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y + s.y - 2, s.x - 2, 1), edge)
			rs.canvas_item_add_rect(ci, Rect2(p.x + 1, p.y + 2, 1, s.y - 4), edge)
			rs.canvas_item_add_rect(ci, Rect2(p.x + s.x - 2, p.y + 2, 1, s.y - 4), edge)


static func _stone(fill: Color, edge: Color, margin_x: float, margin_y: float, top := Color(0, 0, 0, 0), bottom := Color(0, 0, 0, 0)) -> StoneBox:
	var sb := StoneBox.new()
	sb.fill = fill
	sb.edge = edge
	sb.inner_top = top
	sb.inner_bottom = bottom
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	return sb


## Named panel looks. Screens ask for these by name so the look is defined once.
##   "panel"  normal dark stone        "well"   sunken area (lists, slots)
##   "card"   pop-up cards             "curse"  cursed item card
##   "hud"    see-through HUD backing  "gold"   highlighted (new unlock)
##   "tag"    a thin gold row          "slot"   one row in a list ("slot_focus" when selected)
static func box(kind: String) -> StyleBox:
	if _boxes.has(kind):
		return _boxes[kind]
	var sb: StoneBox
	match kind:
		"well":
			sb = _stone(C_PANEL_LOW, Color("353d4c"), 4, 3, C_SHADE)
		"card":
			sb = _stone(Color("1c1c26"), C_EDGE_HI, 5, 4, C_SHADE)
		"curse":
			sb = _stone(C_CURSE_DARK, C_CURSE, 5, 4, Color("1b0d22"))
		"gold":
			sb = _stone(Color("2b2616"), C_GOLD, 5, 4, Color("1a160c"))
		"tag":
			sb = _stone(Color("2b2616"), C_GOLD, 4, 2, Color("1a160c"))
		"hud":
			sb = _stone(Color(0.05, 0.05, 0.08, 0.62), Color(0.42, 0.48, 0.56, 0.7), 3, 2)
			sb.outline = Color(0, 0, 0, 0.5)
		"slot":
			sb = _stone(C_PANEL_LOW, Color("353d4c"), 2, 2, C_SHADE)
		"slot_focus":
			sb = _stone(Color("2b2a22"), C_GOLD, 2, 2, C_SHADE)
		_:
			sb = _stone(C_PANEL, C_EDGE, 6, 5, C_SHADE)
	_boxes[kind] = sb
	return sb


# ------------------------------------------------------------------ the theme
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_load_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = size_body

	# labels
	t.set_color("font_color", "Label", C_BONE)
	t.set_constant("line_spacing", "Label", 0)
	_label_kind(t, "Title", font_display, size_title, C_BONE)
	_label_kind(t, "Head", font_display, size_head, C_BONE)
	_label_kind(t, "Small", font_body, size_small, C_DIM)
	_label_kind(t, "Dim", font_body, size_body, C_DIM)
	_label_kind(t, "Gold", font_body, size_body, C_GOLD)
	_label_kind(t, "Red", font_body, size_body, C_RED)
	_label_kind(t, "Curse", font_body, size_body, C_CURSE)
	# HUD text sits on top of the dungeon, so it gets a dark outline.
	_label_kind(t, "Hud", font_body, size_body, C_BONE)
	t.set_color("font_outline_color", "Hud", C_INK)
	t.set_constant("outline_size", "Hud", 3)
	_label_kind(t, "HudHead", font_display, size_head, C_BONE)
	t.set_color("font_outline_color", "HudHead", C_INK)
	t.set_constant("outline_size", "HudHead", 4)

	# buttons
	var hi := Color(1, 1, 1, 0.07)
	var lo := Color(0, 0, 0, 0.28)
	var normal := _stone(C_PANEL_HI, C_EDGE, 7, 3, hi, lo)
	var hover := _stone(Color("383b4e"), C_EDGE_HI, 7, 3, hi, lo)
	var pressed := _stone(Color("1c1d28"), C_GOLD, 7, 3, lo)
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 2
	var disabled := _stone(Color("1d1d26"), Color("333946"), 7, 3)
	var focus := _stone(C_PANEL_HI, C_GOLD, 7, 3)
	focus.draw_fill = false
	focus.outline = Color(0, 0, 0, 0)
	for type in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, C_BONE)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, C_GOLD)
		t.set_color("font_pressed_color", type, C_GOLD)
		t.set_color("font_hover_pressed_color", type, C_GOLD)
		t.set_color("font_disabled_color", type, C_FAINT)
		t.set_constant("h_separation", type, 3)
	# "Big" buttons: the main call to action on a screen.
	t.set_type_variation("Big", "Button")
	t.set_font("font", "Big", font_display)
	t.set_font_size("font_size", "Big", size_head)
	# "Flat" buttons: tabs and arrows that should not look like stone slabs until focused.
	t.set_type_variation("Flat", "Button")
	t.set_stylebox("normal", "Flat", _stone(Color("1a1a23"), Color("303746"), 5, 3))
	t.set_stylebox("disabled", "Flat", _stone(Color("15151c"), Color("23272f"), 5, 3))
	# "Tab" buttons: the selected tab uses the disabled look turned gold (it cannot be pressed again).
	t.set_type_variation("Tab", "Button")
	t.set_stylebox("normal", "Tab", _stone(Color("1a1a23"), Color("303746"), 6, 3))
	t.set_stylebox("disabled", "Tab", _stone(C_PANEL, C_GOLD, 6, 3, C_SHADE))
	t.set_color("font_disabled_color", "Tab", C_GOLD)
	t.set_color("font_color", "Tab", C_DIM)

	# panels
	t.set_stylebox("panel", "PanelContainer", box("panel"))
	t.set_stylebox("panel", "Panel", box("panel"))

	# thin scrollbars
	var grab := StyleBoxFlat.new()
	grab.bg_color = C_EDGE
	grab.content_margin_left = 1.5
	grab.content_margin_right = 1.5
	var track := StyleBoxFlat.new()
	track.bg_color = C_SHADE
	track.content_margin_left = 1.5
	track.content_margin_right = 1.5
	for sbar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbar, track)
		t.set_stylebox("scroll_focus", sbar, track)
		t.set_stylebox("grabber", sbar, grab)
		t.set_stylebox("grabber_highlight", sbar, grab)
		t.set_stylebox("grabber_pressed", sbar, grab)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())

	# separators
	var line := StyleBoxLine.new()
	line.color = Color("353d4c")
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 3)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 3)
	t.set_constant("h_separation", "GridContainer", 3)
	t.set_constant("v_separation", "GridContainer", 2)
	t.set_constant("h_separation", "HFlowContainer", 2)
	t.set_constant("v_separation", "HFlowContainer", 2)
	_theme = t
	return t


static func _label_kind(t: Theme, kind: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(kind, "Label")
	t.set_font("font", kind, font)
	t.set_font_size("font_size", kind, size)
	t.set_color("font_color", kind, color)


static func _load_fonts() -> void:
	var fallback: Font = ThemeDB.fallback_font
	var body := _pixel_font(FONT_BODY, BODY_PX)
	var display := _pixel_font(FONT_DISPLAY, DISPLAY_PX)
	pixel_fonts = not body.is_empty()
	if pixel_fonts:
		font_body = body[0]
		body_px = body[1]
		size_body = body_px
		size_small = body_px
	else:
		font_body = fallback
	if not display.is_empty():
		font_display = display[0]
		display_px = display[1]
		size_head = display_px
		size_title = display_px * 2
	elif pixel_fonts:
		# only a body font arrived: use it for headings too, at whole multiples
		font_display = font_body
		display_px = body_px
		size_head = body_px * (2 if body_px <= 8 else 1)
		size_title = body_px * (3 if body_px <= 8 else 2)
	else:
		font_display = fallback


## Loads one pixel font. Returns [font, native size] or [] when the file is not there.
static func _pixel_font(file_name: String, default_px: int) -> Array:
	var f: FontFile = null
	if font_dir_override != "":
		var ff := FontFile.new()
		if ff.load_dynamic_font(font_dir_override.path_join(file_name)) == OK:
			f = ff
	elif ResourceLoader.exists(FONT_DIR + file_name):
		f = load(FONT_DIR + file_name) as FontFile
	if f == null:
		return []
	# hard pixel edges: no smoothing, no hinting, no sub-pixel placement
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	var tune: Array = FONT_TUNING.get(f.get_font_name(), [default_px, 0, 0, 0])
	if tune[1] == 0 and tune[2] == 0 and tune[3] == 0:
		return [f, int(tune[0])]
	var spaced := FontVariation.new()
	spaced.base_font = f
	spaced.set_spacing(TextServer.SPACING_TOP, int(tune[1]))
	spaced.set_spacing(TextServer.SPACING_BOTTOM, int(tune[2]))
	spaced.set_spacing(TextServer.SPACING_GLYPH, int(tune[3]))
	return [spaced, int(tune[0])]


## The sizes a big title may shrink through when the text is too wide (whole multiples for pixel fonts).
static func title_sizes() -> Array[int]:
	var out: Array[int] = []
	if font_display != ThemeDB.fallback_font:
		var n := maxi(size_title / display_px, 1)
		while n >= 1:
			out.append(display_px * n)
			n -= 1
	else:
		out.assign([24, 20, 16, 14, 12])
	return out


## The look of the biggest words (game name, Victory, Fallen): a solid drop shadow two pixels down.
static func style_title(lab: Label, colour: Color, shadow: Color) -> void:
	lab.add_theme_color_override("font_color", colour)
	lab.add_theme_color_override("font_shadow_color", shadow)
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 2)
	lab.add_theme_constant_override("shadow_outline_size", 0)
	lab.add_theme_constant_override("outline_size", 0)


## Shrinks a title label step by step until its text fits in max_width (then lets it wrap).
static func fit_title(lab: Label, max_width: float) -> void:
	var sizes := title_sizes()
	var chosen: int = sizes[sizes.size() - 1]
	for s in sizes:
		if font_display.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= max_width:
			chosen = s
			break
	lab.add_theme_font_size_override("font_size", chosen)
	if font_display.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > max_width:
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = max_width


# ------------------------------------------------------------------ small builders
## A text label. kind is one of "", "Title", "Head", "Small", "Dim", "Gold", "Red", "Curse", "Hud", "HudHead".
static func label(text: String, kind: String = "", wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if kind != "":
		l.theme_type_variation = kind
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A button that clicks, squashes a little when pressed, and calls `action` when released.
static func button(text: String, action: Callable = Callable(), kind: String = "", sound: String = "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	if kind != "":
		b.theme_type_variation = kind
	b.custom_minimum_size = Vector2(26, 18)
	b.focus_mode = Control.FOCUS_ALL
	juice(b)
	b.pressed.connect(func() -> void:
		if sound != "":
			Sfx.play(sound))
	if action.is_valid():
		b.pressed.connect(action)
	return b


## Makes any button squash when pressed and spring back when released.
static func juice(b: BaseButton) -> void:
	b.button_down.connect(func() -> void: _squash(b, Vector2(1.05, 0.88)))
	b.button_up.connect(func() -> void: _squash(b, Vector2.ONE))


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


## Quick pop-in for panels: a short fade and slide (always under 0.2 s).
static func pop_in(c: Control, from: Vector2 = Vector2(0, 6)) -> void:
	if instant or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	# The slide waits one frame so containers have already placed the control.
	var slide := func() -> void:
		if not is_instance_valid(c):
			return
		var home := c.position
		c.position = home + from
		var tw2 := c.create_tween()
		tw2.tween_property(c, "position", home, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.call_deferred()


# ------------------------------------------------------------------ icons
## THE one place that decides what the small HUD icons are. kind: "coin", "key", "bomb".
## Returns a ready-made control. To swap in a real key sprite later, change only this function.
static func hud_icon(kind: String) -> Control:
	match kind:
		"coin":
			return _sprite_icon("coin", Vector2(8, 9))
		"bomb":
			return _sprite_icon("bomb", Vector2(14, 13))
		"key":
			# The art pack has no key. If an icon pack adds one, it is used; until then a plain
			# geometric stand-in (a ring and a bar) drawn by key_glyph.gd.
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
		var u := img.get_used_rect()
		if u.size.x > 0 and u.size.y > 0:
			r = Rect2(u)
	_used_rects[id] = r
	return r


# ------------------------------------------------------------------ screen helpers
## Size of the screen in game pixels (always 180 tall; the width depends on the phone).
static func screen_size(node: Node) -> Vector2:
	return node.get_viewport().get_visible_rect().size


## How far the phone's notch / rounded corners push in from each edge, in game pixels.
## x = left, y = top, z = right, w = bottom.
static func safe_insets(node: Node) -> Vector4:
	if fake_safe != Vector4.ZERO:
		return fake_safe
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var vp := screen_size(node)
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	var out := Vector4(
		maxf(safe.position.x, 0.0) * sx,
		maxf(safe.position.y, 0.0) * sy,
		maxf(win.x - safe.end.x, 0.0) * sx,
		maxf(win.y - safe.end.y, 0.0) * sy)
	# never trust a silly value from a strange device
	return Vector4(ceilf(minf(out.x, 60.0)), ceilf(minf(out.y, 30.0)), ceilf(minf(out.z, 60.0)), ceilf(minf(out.w, 30.0)))


## A full-screen container that keeps its children inside the safe area plus a small margin.
static func safe_margin(node: Node, margin: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := safe_insets(node)
	m.add_theme_constant_override("margin_left", margin + int(s.x))
	m.add_theme_constant_override("margin_top", margin + int(s.y))
	m.add_theme_constant_override("margin_right", margin + int(s.z))
	m.add_theme_constant_override("margin_bottom", margin + int(s.w))
	return m


## 75 -> "1:15"
static func time_text(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
