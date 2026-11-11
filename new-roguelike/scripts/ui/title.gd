extends "res://scripts/ui/screen.gd"
## Title screen: the game's name, Play / Collection / Settings / Credits, and the version.
## The dungeon picture behind it is scripts/ui/backdrop.gd (main.gd keeps it).

var _name_label: Label
var _column: VBoxContainer


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

	_name_label = UI.label(game_name(), "Title")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_shadow_color", UI.C_BLOOD)
	_name_label.add_theme_constant_override("shadow_offset_x", 0)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.add_theme_color_override("font_outline_color", UI.C_INK)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_top = 2
	area.add_child(_name_label)

	_column = UI.vbox(3)
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_column.offset_top = 16
	_column.offset_bottom = 16
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
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -2
	area.add_child(version)

	resized.connect(_fit)
	_fit.call_deferred()
	UI.pop_in(_column, Vector2(8, 0))
	UI.pop_in(_name_label, Vector2(0, -6))


func _fit() -> void:
	UI.fit_title(_name_label, maxf(size.x - 28.0, 120.0))


## Back on the title means "leave the game?".
func on_back() -> void:
	if close_dialog():
		return
	ask("Quit the game?", "Quit", "Stay", func() -> void: send("quit"), false)
