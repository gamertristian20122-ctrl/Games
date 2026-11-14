extends "res://scripts/ui/screen.gd"
## Title screen: the game's name, Continue / New Game / Load / Settings / Credits / Quit, and the version.
## Continue and Load only show once a game is saved (scripts/core/save.gd slots; the slot cards are scripts/ui/slots.gd).
## The picture behind it is the lit 3D title scene (scripts/ui/title_scene.gd) or, without the 3D
## look, scripts/ui/backdrop.gd (main.gd keeps both).
## HD GUI (spec 6.5): on a PC a wash on the left, the pixel logo (Alkhemikal at a whole multiple of
## 16 screen px) with its warm glow at 0.3 of the height, the tagline under it, and the menu under
## that, left-aligned: the Big Play plate, then rows. The version bottom left, the help strip bottom
## right. On a phone the name stays centred at the top and the menu on the right (the thumb).

const Heroes = preload("res://scripts/data/heroes.gd")
const Slots = preload("res://scripts/ui/slots.gd")

## The words of the menu rows this screen adds (placeholders the owner may rewrite).
const WORDS := {
	"continue": "Continue", "new": "New Game", "load": "Load", "quit": "Quit",
	"recovered": "A save file was damaged. Its backup copy was loaded.",
}

## The one line under the game's name: what makes this game different.
const TAGLINE := "Four seals are breaking under the hill."

var _name_label: Control           ## the Logo
var _rule: Control
var _tag_label: Label
var _column: VBoxContainer
var _glow: Control
var _wash: Control
var _area: Control
var _version: Label
var _resume_line: Label            ## under Continue: which game it goes on with
var _has_game := false
var _notice: Label                 ## "a backup copy was loaded" (only after a damaged save file)
var _ph := false
var _t := 0.0


## A see-through picture that fades from `inner` at the middle to `outer` at the edges.
func _radial(inner: Color, outer: Color, start: float) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	if start > 0.0:
		g.add_point(start, inner)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Motes of warm light drifting up through the title picture, twinkling. Squares only, added
## light; about forty of them, so it costs nothing on a phone.
class Motes extends Control:
	const COUNT := 40
	var _p: Array[Vector4] = []        ## x, y, speed, phase
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in COUNT:
			_p.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(3.0, 9.0), rng.randf() * TAU))

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if size.x < 4.0:
			return
		for m: Vector4 in _p:
			var y := fposmod(m.y * size.y - _t * m.z, size.y + 8.0) - 4.0
			var x := fposmod(m.x * size.x + sin(_t * 0.5 + m.w) * 6.0 + _t * 1.5, size.x)
			var tw := 0.5 + 0.5 * sin(_t * 1.7 + m.w * 3.0)
			# brighter near the bottom (where the light pools), fading as they rise
			var a := (0.25 + 0.75 * tw) * clampf(y / size.y + 0.2, 0.0, 1.0)
			var warm := Color(1.0, 0.82, 0.48)
			var p := Vector2(roundf(x), roundf(y))
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), Color(warm, a * 0.07))
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(warm, a * 0.16))
			draw_rect(Rect2(p, Vector2(1, 1)) if m.z < 6.0 else Rect2(p, Vector2(2, 2)) , Color(warm, a * 0.7))


## THE LOGO in the house language: the name in Cinzel capitals, filled with a brass gradient
## (pale gold at the top, deep bronze at the foot, a bright band a third of the way down), on an
## ink outline and a soft drop; under it a brass rule with a lozenge. All drawn by code.
class Logo extends Control:
	const UI = preload("res://scripts/ui/theme.gd")
	const FILL := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.0, 0.95, 0.76, 1.0);
uniform vec4 band_col : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform vec4 foot_col : source_color = vec4(0.62, 0.38, 0.16, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 40.0;
varying float ly;
void vertex() {
	ly = VERTEX.y;
}
void fragment() {
	float a = texture(TEXTURE, UV).a * COLOR.a;
	float t = clamp((ly - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
	vec3 c = t < 0.38 ? mix(top_col.rgb, band_col.rgb, t / 0.38) : mix(band_col.rgb, foot_col.rgb, (t - 0.38) / 0.62);
	COLOR = vec4(c, a);
}
"""
	var text := ""
	var font_size := 40
	var font: Font
	var rule := true
	var _fill: Control
	var _mat: ShaderMaterial

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill = Control.new()
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = FILL
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_fill.material = _mat
		_fill.draw.connect(_draw_fill)
		add_child(_fill)

	func setup(t: String, size_px: int) -> void:
		text = t.to_upper()
		font_size = size_px
		var fv := FontVariation.new()
		fv.base_font = (UI.font_head as FontVariation).base_font if UI.font_head is FontVariation else UI.font_head
		fv.variation_opentype = {"wght": 760}
		fv.spacing_glyph = maxi(int(roundf(size_px * 0.06)), 1)
		font = fv
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		custom_minimum_size = Vector2(ceilf(w) + 8.0, ceilf(font.get_height(font_size)) + (12.0 if rule else 4.0))
		size = custom_minimum_size
		_fill.size = size
		queue_redraw()
		_fill.queue_redraw()

	func _base() -> Vector2:
		return Vector2(4.0, roundf(font.get_ascent(font_size)) + 1.0)

	func _draw() -> void:
		if font == null:
			return
		var at := _base()
		var o := maxi(int(roundf(font_size / 9.0)), 2)
		draw_string_outline(font, at + Vector2(0, roundf(font_size * 0.07)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, o + 4, Color(0.08, 0.02, 0.0, 0.45))
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, o, Color(UI.C_INK, 0.92))
		if rule:
			var y := size.y - 5.0
			var ci := get_canvas_item()
			var mid := size.x * 0.5
			UI.rs_rule(ci, Vector2(mid - 8.0, y), Vector2(4.0, y), Color(UI.C_BRASS, 0.95), Color(UI.C_BRASS, 0.0))
			UI.rs_rule(ci, Vector2(mid + 8.0, y), Vector2(size.x - 4.0, y), Color(UI.C_BRASS, 0.95), Color(UI.C_BRASS, 0.0))
			UI.rs_lozenge(ci, Vector2(mid, y), 3.5, UI.C_EMBER, 0.0)

	func _draw_fill() -> void:
		if font == null:
			return
		var at := _base()
		# the gradient runs from the tops of the capitals to the baseline
		_mat.set_shader_parameter("y0", at.y - font.get_ascent(font_size) * 0.72)
		_mat.set_shader_parameter("y1", at.y)
		_fill.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## A thin brass rule down the left of the menu with a lozenge at each end: it holds the rows together.
class MenuRule extends Control:
	const UI = preload("res://scripts/ui/theme.gd")
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ci := get_canvas_item()
		var x := roundf(size.x * 0.5) + 0.5
		UI.rs_rule(ci, Vector2(x, 4.0), Vector2(x, size.y * 0.5), Color(UI.C_BRASS, 0.2), Color(UI.C_BRASS, 0.7))
		UI.rs_rule(ci, Vector2(x, size.y * 0.5), Vector2(x, size.y - 4.0), Color(UI.C_BRASS, 0.7), Color(UI.C_BRASS, 0.2))
		UI.rs_lozenge(ci, Vector2(x, 3.0), 2.5, UI.C_BRASS, 0.0)
		UI.rs_lozenge(ci, Vector2(x, size.y - 3.0), 2.5, UI.C_BRASS, 0.0)


## The game's name comes from the project settings, so renaming the game renames the title.
static func game_name() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "Game")).replace(" (working title)", "").strip_edges()


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph = UI.is_phone()
	# the lit look over the living picture: a soft vignette, a wash on the menu's side, a warm glow
	# behind the name, and motes of light drifting up through it (all drawn in code: no art made here)
	var vignette := _radial(Color(0, 0, 0, 0), Color(0.01, 0.01, 0.04, 0.58), 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)
	if not _ph:
		_wash = UI.wash("right", 0.66)
		_wash.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		add_child(_wash)
	_glow = _radial(Color(1.0, 0.76, 0.36, 0.42), Color(1.0, 0.55, 0.18, 0.0), 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	var motes := Motes.new()
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(motes)
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(area)
	_area = area

	# the name: the logo lockup (Cinzel in a brass gradient, ink outline, brass rule; sized in _fit)
	_name_label = Logo.new()
	area.add_child(_name_label)
	_name_label.call("setup", game_name(), 40 if not _ph else 22)

	_tag_label = UI.label(TAGLINE if G.flag("oldstory") else "The beacons are dark. The nights grow long.", "Body")
	_tag_label.add_theme_font_size_override("font_size", 13 if not _ph else UI.size_small)
	_tag_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.66))
	_tag_label.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
	_tag_label.add_theme_constant_override("outline_size", 3)
	area.add_child(_tag_label)

	_column = UI.vbox(1 if not _ph else 3)
	area.add_child(_column)
	if not _ph:
		_rule = MenuRule.new()
		area.add_child(_rule)
	# every row in one face (Alegreya): the focus is shown by the brass bar and the flame only.
	# The old roguelike's Collection is only offered with the old story (--oldstory).
	_fill_rows()

	_version = UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0")) + ("  DEMO" if G.demo() else ""), "Small")
	_version.add_theme_color_override("font_color", UI.C_FAINT)
	area.add_child(_version)
	if Save.recovered:
		# a save file was cut short or garbled and its backup copy was used: say so, once, plainly
		_notice = UI.label(WORDS["recovered"], "Small")
		_notice.add_theme_color_override("font_color", UI.C_GOLD)
		_notice.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
		_notice.add_theme_constant_override("outline_size", 2)
		area.add_child(_notice)

	resized.connect(_fit)
	area.resized.connect(_fit)          # the safe margin sizes the area a moment after the screen
	_fit.call_deferred()
	refresh()
	UI.pop_in(_column, Vector2(-8, 0) if not _ph else Vector2(8, 0))
	UI.pop_in(_name_label, Vector2(0, -6))
	UI.pop_in(_tag_label, Vector2(0, -3))


## The menu rows (built again when the saved games changed while another screen was open).
func _fill_rows() -> void:
	# Continue (only when a game is saved; it is gold and has the focus then), New Game, Load.
	for old: Node in _column.get_children():
		_column.remove_child(old)
		old.queue_free()
	_resume_line = null
	var has_game := Save.any_slot()
	_has_game = has_game
	var rows: Array = []
	if has_game:
		rows.append([WORDS["continue"], "continue"])
	rows.append([WORDS["new"], "new"])
	if has_game:
		rows.append([WORDS["load"], "load"])
	if G.flag("oldstory"):
		rows.append(["Collection", "collection"])
	rows.append_array([["Settings", "settings"], ["Credits", "credits"], [WORDS["quit"], "quit"]])
	var first: Button = null
	# a phone's screen is 180 px tall and the help strip sits under the menu: more than four rows
	# go in two columns there (Continue | New Game, Load | Settings, Credits | Quit)
	var holder: Container = _column
	var two := _ph and rows.size() > 4
	if two:
		if has_game:
			_resume_line = _make_resume_line()
			_resume_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_column.add_child(_resume_line)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 3)
		_column.add_child(grid)
		holder = grid
	for row: Array in rows:
		var what: String = row[1]
		var b := UI.button(row[0], _press.bind(what), "", "ui_start" if what in ["continue", "new"] else "ui_click")
		b.name = "Row_" + what
		b.custom_minimum_size = Vector2(150 if not _ph else (104 if not two else 92), 24 if not _ph else 20)
		if not _ph:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 15 if first == null else 13)
		if first == null:
			b.add_theme_color_override("font_color", UI.C_GOLD)
			first = b
		holder.add_child(b)
		if what == "continue" and not two:
			# under Continue: which game it is (chapter, level, place, time played)
			_resume_line = _make_resume_line()
			var pad := MarginContainer.new()
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_theme_constant_override("margin_left", 9 if not _ph else 4)
			pad.add_theme_constant_override("margin_bottom", 3 if not _ph else 1)
			pad.add_child(_resume_line)
			_column.add_child(pad)
	default_focus = first
	if is_inside_tree():
		_fit.call_deferred()
		_focus_default.call_deferred()


func _make_resume_line() -> Label:
	var l := UI.label(_resume_text(), "Small")
	l.add_theme_color_override("font_color", Color(0.80, 0.74, 0.60))
	l.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
	l.add_theme_constant_override("outline_size", 2)
	return l


func help_pairs() -> Array:
	return [["confirm", "Choose"], ["back", "Quit"]]


## The hero you played last stands in the picture (the first hero on a fresh save).
func refresh() -> void:
	if is_instance_valid(_column) and _has_game != Save.any_slot():
		_fill_rows()                     # a game was erased or copied on the slots screen
	elif is_instance_valid(_resume_line):
		_resume_line.text = _resume_text()
	if not is_instance_valid(backdrop):
		return
	var hero := Heroes.by_id("knight")          # Aldous is the only hero now
	if bool(hero.get("locked", false)) and not Save.is_unlocked("hero:" + String(hero["id"])):
		hero = Heroes.LIST[0]
	backdrop.call("set_hero", hero, false)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_glow):
		# the glow behind the name breathes slowly, like a lamp
		_glow.modulate.a = 0.78 + 0.22 * sin(_t * 1.3)


func _fit() -> void:
	if not is_instance_valid(_area) or _area.size.y < 20.0:
		return
	var a := _area.size
	var want := int(roundf(a.y * (0.115 if not _ph else 0.13)))
	if int(_name_label.get("font_size")) != want:
		_name_label.call("setup", game_name(), want)
	var name_size := _name_label.get_combined_minimum_size()
	var tag_size := _tag_label.get_minimum_size()
	var col_size := _column.get_combined_minimum_size()
	if _ph:
		# the phone: the name centred at the top, the menu on the right (the thumb's side)
		_name_label.position = Vector2(roundf((a.x - name_size.x) * 0.5), 0)
		_tag_label.position = Vector2(roundf((a.x - tag_size.x) * 0.5), roundf(name_size.y + 1.0))
		_column.position = Vector2(roundf(a.x - col_size.x - 2.0), roundf(maxf((a.y - col_size.y) * 0.5 + 14.0, name_size.y + tag_size.y + 4.0)))
	else:
		# a PC: the name in the left third at 0.3 of the height, the tagline and the menu under it
		var left := 34.0
		var name_y := roundf(a.y * 0.30 - name_size.y * 0.6)
		_name_label.position = Vector2(left, name_y)
		_tag_label.position = Vector2(left + 4.0, roundf(name_y + name_size.y + 3.0))
		_column.position = Vector2(left, roundf(_tag_label.position.y + tag_size.y + 22.0))
		if is_instance_valid(_rule):
			_rule.position = Vector2(left - 16.0, _column.position.y - 2.0)
			_rule.size = Vector2(6.0, col_size.y + 4.0)
		if is_instance_valid(_wash):
			_wash.size.x = maxf(name_size.x + left + 120.0, size.x * 0.5)
	_column.size = col_size
	_version.position = Vector2(2, a.y - _version.get_minimum_size().y)
	if is_instance_valid(_notice):
		_notice.position = Vector2(2, _version.position.y - _notice.get_minimum_size().y - 1.0)
	_glow.size = Vector2(name_size.x * 1.5 + 60.0, name_size.y * 2.6)
	_glow.position = _area.position + _name_label.position + name_size * 0.5 - _glow.size * 0.5 + Vector2(0, 2)


## The logo font size in UI px: 16 screen pixels a step (Alkhemikal is a 16 px pixel font), the
## biggest step at or under `max_ui` whose size in UI px is a whole number.
static func _logo_size(max_ui: float, px: float) -> float:
	var n := int(floorf(max_ui * px / 16.0))
	while n > 1:
		var s := 16.0 * n / px
		if absf(s - roundf(s)) < 0.01:
			return roundf(s)
		n -= 1
	return maxf(roundf(16.0 / px), 8.0)


## A row of the menu was chosen.
func _press(what: String) -> void:
	match what:
		"continue":
			send("continue", _resume_slot())
		"new":
			# a free slot is taken without a question; with all three full the player picks one
			var free := Save.free_slot()
			if free > 0:
				send("new_game", free)
			else:
				send("slots", "new")
		"load":
			send("slots", "load")
		"quit":
			_ask_quit()
		_:
			send(what)


## The slot Continue goes on with: the one played last, or else the one saved most recently.
func _resume_slot() -> int:
	if bool(Save.slot_info(Save.slot)["exists"]):
		return Save.slot
	var best := 0
	var best_date := ""
	for n: int in range(1, Save.SLOTS + 1):
		var info: Dictionary = Save.slot_info(n)
		if bool(info["exists"]) and (best == 0 or String(info["date"]) > best_date):
			best = n
			best_date = String(info["date"])
	return maxi(best, 1)


func _resume_text() -> String:
	return Slots.line(Save.slot_info(_resume_slot()))


func _ask_quit() -> void:
	on_back()


## Back on the title means "leave the game?".
func on_back() -> void:
	if close_dialog():
		return
	ask("Quit the game?", "Quit", "Stay", func() -> void: send("quit"), false)
