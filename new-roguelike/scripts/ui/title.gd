extends "res://scripts/ui/screen.gd"
## Title screen: the game's name, Play / Collection / Settings / Credits, and the version.
## The dungeon picture behind it is scripts/ui/backdrop.gd (main.gd keeps it).

const Heroes = preload("res://scripts/data/heroes.gd")

## The one line under the game's name: what makes this game different.
const TAGLINE := "Four seals are breaking under the hill."

var _name_label: Label
var _tag_label: Label
var _column: VBoxContainer
var _glow: Control
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


## The game's name comes from the project settings, so renaming the game renames the title.
static func game_name() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "Game")).replace(" (working title)", "").strip_edges()


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(area)
	# the lit look over the living picture: a soft vignette, a warm glow behind the name, and
	# motes of light drifting up through it (all drawn in code: no art made here)
	var vignette := _radial(Color(0, 0, 0, 0), Color(0.01, 0.01, 0.04, 0.58), 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)
	move_child(vignette, 0)
	_glow = _radial(Color(1.0, 0.76, 0.36, 0.42), Color(1.0, 0.55, 0.18, 0.0), 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_glow.offset_left = -150
	_glow.offset_right = 150
	_glow.offset_top = -34
	_glow.offset_bottom = 66
	add_child(_glow)
	move_child(_glow, 1)
	var motes := Motes.new()
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(motes)
	move_child(motes, 2)

	_name_label = UI.label(game_name(), "Title")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_title(_name_label, UI.C_BONE, UI.C_BLOOD)
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_top = 2
	area.add_child(_name_label)

	_tag_label = UI.label(TAGLINE if G.flag("oldstory") else "The beacons are dark. The nights grow long.", "Small")
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tag_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.58))
	_tag_label.add_theme_color_override("font_outline_color", UI.C_INK)
	_tag_label.add_theme_constant_override("outline_size", 3)
	_tag_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	area.add_child(_tag_label)

	_column = UI.vbox(3)
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_column.offset_top = 12
	_column.offset_bottom = 12
	_column.offset_right = -2
	_column.offset_left = -2
	area.add_child(_column)
	var play := UI.button("Play", func() -> void: send("play"), "Big", "ui_start")
	play.custom_minimum_size = Vector2(104, 26)
	_column.add_child(play)
	for row: Array in [["Collection", "collection"], ["Settings", "settings"], ["Credits", "credits"]]:
		var what: String = row[1]
		var b := UI.button(row[0], func() -> void: send(what))
		b.custom_minimum_size = Vector2(104, 19)
		_column.add_child(b)
	default_focus = play

	var version := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0")), "Small")
	version.add_theme_color_override("font_color", UI.C_FAINT)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)      # (bottom right is under the fifth button now)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = 2
	area.add_child(version)

	resized.connect(_fit)
	_fit.call_deferred()
	refresh()
	UI.pop_in(_column, Vector2(8, 0))
	UI.pop_in(_name_label, Vector2(0, -6))
	UI.pop_in(_tag_label, Vector2(0, -3))


## The hero you played last stands in the picture (the first hero on a fresh save).
func refresh() -> void:
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
	UI.fit_title(_name_label, maxf(size.x - 28.0, 120.0))
	# the tagline sits right under the name, whatever size the name ended up
	_tag_label.offset_top = _name_label.offset_top + _name_label.get_minimum_size().y - 1.0


## Back on the title means "leave the game?".
func on_back() -> void:
	if close_dialog():
		return
	ask("Quit the game?", "Quit", "Stay", func() -> void: send("quit"), false)
