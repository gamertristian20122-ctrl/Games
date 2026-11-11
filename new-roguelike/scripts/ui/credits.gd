extends "res://scripts/ui/screen.gd"
## Credits: who made what, built from the list in scripts/data/credits.gd.
## Add a row there and it shows up here; nothing in this file needs to change.

const Credits = preload("res://scripts/data/credits.gd")

var _scroll: ScrollContainer


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	col.add_child(top_bar("Credits"))
	default_focus = col.get_child(0).get_node("Back")

	var panel := UI.panel("panel")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var list := UI.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)

	var game := UI.label(String(ProjectSettings.get_setting("application/config/name", "")).replace(" (working title)", ""), "Head")
	game.add_theme_color_override("font_color", UI.C_GOLD)
	list.add_child(game)
	for note: String in Credits.NOTES:
		var n := UI.label(note, "", 10.0)
		list.add_child(n)
	list.add_child(HSeparator.new())
	for entry: Dictionary in Credits.LIST:
		var block := UI.vbox(0)
		list.add_child(block)
		block.add_child(UI.label(String(entry.get("what", "")), "Gold", 10.0))
		block.add_child(UI.label("by %s  -  licence: %s" % [entry.get("author", "?"), entry.get("licence", "?")], "", 10.0))
		var url := String(entry.get("url", ""))
		if url != "":
			block.add_child(UI.label(url, "Small", 10.0))
	list.add_child(UI.spacer(0, 2))
	UI.pop_in(panel)


## Up / down on keyboard or gamepad scroll the list.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += 14
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= 14
		get_viewport().set_input_as_handled()
