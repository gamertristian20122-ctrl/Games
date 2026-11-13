extends "res://scripts/ui/screen.gd"
## Credits: who made what, built from the list in scripts/data/credits.gd.
## Add a row there and it shows up here; nothing in this file needs to change.
## HD GUI: the veil and a scrolling glass panel (560 UI px on a PC) with the thin brass scrollbar;
## each entry: what it is (Cinzel, gold), who made it, the licence (dim) and the address (faint).
## Up / down (keys, pad) and the mouse wheel scroll it.

const Credits = preload("res://scripts/data/credits.gd")
const VEIL_GAIN := 2.4

var _scroll: ScrollContainer
var _ph := false


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var outer: Control
	if _ph:
		outer = UI.safe_margin(self, 4)
	else:
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_top", 18)
		m.add_theme_constant_override("margin_bottom", 34)
		outer = m
	add_child(outer)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(centre)
	var panel := UI.panel("panel")
	centre.add_child(panel)
	var col := UI.vbox(2)
	panel.add_child(col)
	col.add_child(_header())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	var list := UI.vbox(7 if not _ph else 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	var w := 540.0 if not _ph else 360.0
	resized.connect(_fit_size.bind(panel, w))
	_fit_size.call_deferred(panel, w)

	var game := UI.label(String(ProjectSettings.get_setting("application/config/name", "")).replace(" (working title)", ""), "Head")
	game.add_theme_color_override("font_color", UI.C_GOLD)
	list.add_child(game)
	for note: String in Credits.NOTES:
		var n := UI.label(note, "", w - 30.0)
		if _ph:
			n.theme_type_variation = "Small"
		list.add_child(n)
	var rule := UI.rule(w * 0.7, UI.C_BRASS, "both")
	rule.custom_minimum_size.y = 5
	list.add_child(rule)
	for entry: Dictionary in Credits.LIST:
		var block := UI.vbox(0)
		list.add_child(block)
		var what := UI.label(String(entry.get("what", "")), "Head", w - 30.0)
		what.add_theme_font_size_override("font_size", 11 if not _ph else 8)
		what.add_theme_color_override("font_color", UI.C_GOLD)
		block.add_child(what)
		var who := UI.label("by %s" % String(entry.get("author", "?")), "", w - 30.0)
		who.add_theme_font_size_override("font_size", 11 if not _ph else 8)
		block.add_child(who)
		var lic := UI.label("Licence: %s" % String(entry.get("licence", "?")), "Small", w - 30.0)
		lic.add_theme_color_override("font_color", UI.C_DIM)
		block.add_child(lic)
		var url := String(entry.get("url", ""))
		if url != "":
			var u := UI.label(url, "Small", w - 30.0)
			u.add_theme_color_override("font_color", UI.C_FAINT)
			block.add_child(u)
	list.add_child(UI.spacer(0, 4))
	UI.pop_in(panel)


## The panel is as tall as the screen allows.
func _fit_size(panel: Control, w: float) -> void:
	var host := UI.screen_size(self)
	var h := host.y - (52.0 if not _ph else 8.0)
	panel.custom_minimum_size = Vector2(minf(w + 20.0, host.x - 16.0), maxf(h, 80.0))


func _header() -> Control:
	var head := UI.vbox(0)
	var line := Control.new()
	line.custom_minimum_size.y = 22 if not _ph else 18
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	var t := UI.label("Credits", "Head")
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(t)
	var back := UI.button("Back", on_back, "", "")
	back.name = "Back"
	back.focus_mode = Control.FOCUS_ALL
	back.custom_minimum_size = Vector2(44, line.custom_minimum_size.y)
	line.add_child(back)
	default_focus = back
	var rule := UI.rule(200, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	head.add_child(rule)
	return head


func help_pairs() -> Array:
	return [["Up/Down", "Scroll"], ["back", "Back"]]


## Up / down on keyboard or gamepad scroll the list; a right click goes back.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += 18
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= 18
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		on_back()
