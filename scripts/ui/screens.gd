class_name Screens
extends Control
## The full-screen menus: title, pause, and the end of a run.
## Only one is visible at a time. main.gd listens for "picked".

signal picked(key: String)

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _body: Label
var _menu: MenuList
var _icon: TextureRect
var _items_row: Control
var _help: Label
var current := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_icon = UiKit.icon(Vector2i(44, 4), Pal.GOLD, 3.0)
	_icon.position = Vector2(216, 22)
	add_child(_icon)

	_title = UiKit.label("", 32, Pal.PAPER, UiKit.FONT_SQUARE_PATH)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 74)
	_title.size = Vector2(480, 34)
	add_child(_title)

	_subtitle = UiKit.label("", 8, Pal.DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(40, 110)
	_subtitle.size = Vector2(400, 10)
	add_child(_subtitle)

	_body = UiKit.label("", 8, Pal.PAPER)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.position = Vector2(60, 126)
	_body.size = Vector2(360, 44)
	add_child(_body)

	_items_row = Control.new()
	_items_row.position = Vector2(0, 172)
	_items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items_row)

	_menu = MenuList.new()
	_menu.position = Vector2(140, 196)
	_menu.picked.connect(func(key: String) -> void: picked.emit(key))
	add_child(_menu)

	_help = UiKit.label("", 8, Pal.FAINT.lightened(0.25))
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.position = Vector2(0, 256)
	_help.size = Vector2(480, 10)
	add_child(_help)
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_help())


func close() -> void:
	visible = false
	current = ""


func show_title() -> void:
	current = "title"
	_dim.color = Pal.INK
	_icon.visible = true
	_title.text = "ECHOWICK"
	_title.add_theme_color_override("font_color", Pal.PAPER)
	_subtitle.text = "The light is out. Go down and bring it back."
	var lines := "Each room remembers you. Your echo from the last room fights beside you in the next."
	if Game.total_runs > 0:
		lines += "\n\nRuns: %d     Wins: %d     Farthest: %d rooms" % [Game.total_runs, Game.total_wins, Game.best_rooms]
	_body.text = lines
	_fill_items(false)
	_menu.set_entries([["start", "Begin a run"], ["quit", "Quit"]])
	_refresh_help()
	visible = true


func show_pause() -> void:
	current = "pause"
	_dim.color = Color(Pal.INK, 0.88)
	_icon.visible = false
	_title.text = "PAUSED"
	_title.add_theme_color_override("font_color", Pal.PAPER)
	_subtitle.text = "%s  -  room %d" % [Game.floor_def()["name"], Game.room_index + 1]
	var combo_names: Array[String] = []
	for combo_id: String in Game.stats.combos:
		combo_names.append(ItemDB.COMBOS[combo_id]["name"])
	_body.text = "Combos: " + (", ".join(combo_names) if not combo_names.is_empty() else "none yet")
	_fill_items(true)
	_menu.set_entries([["resume", "Keep going"], ["restart", "Start over"], ["title", "Back to title"]])
	_refresh_help()
	visible = true


func show_end(won: bool, killer_name: String) -> void:
	current = "end"
	_dim.color = Color(Pal.INK, 0.9)
	_icon.visible = won
	_title.text = "THE LAMP IS LIT" if won else "THE LIGHT WENT OUT"
	_title.add_theme_color_override("font_color", Pal.GOLD if won else Pal.DANGER)
	var minutes := int(Game.run_time) / 60
	var seconds := int(Game.run_time) % 60
	if won:
		_subtitle.text = "You carried the flame back up the stairs."
	else:
		_subtitle.text = "Lost to %s in %s." % [killer_name, Game.floor_def()["name"]]
	_body.text = "Rooms cleared: %d of %d     Time: %d:%02d\n\n%s" % [
		Game.rooms_cleared, FloorDB.total_rooms(), minutes, seconds,
		"" if won else "Your last moments will echo into your next run."]
	_fill_items(true)
	_menu.set_entries([["start", "Try again"], ["title", "Back to title"]])
	_refresh_help()
	visible = true


func _fill_items(show_them: bool) -> void:
	for child: Node in _items_row.get_children():
		child.queue_free()
	if not show_them or Game.item_order.is_empty():
		return
	var count := Game.item_order.size()
	var step := minf(18.0, 380.0 / float(count))
	var x := (480.0 - count * step) / 2.0
	for i in count:
		var id := Game.item_order[i]
		var item: Dictionary = ItemDB.ITEMS[id]
		var picture := UiKit.icon(item["icon"], Pal.RARITY[int(item["rarity"])])
		picture.position = Vector2(x + i * step, 0)
		_items_row.add_child(picture)
		var stacks := int(Game.items.get(id, 0))
		if stacks > 1:
			var number := UiKit.label(str(stacks), 8, Pal.PAPER)
			number.position = picture.position + Vector2(10, 9)
			_items_row.add_child(number)


func _refresh_help() -> void:
	if Controls.using_pad:
		_help.text = "Left stick: move    Right stick: aim and fire    A: dash    Start: pause"
	else:
		_help.text = "WASD: move    Mouse: aim    Left click: fire    Space: dash    Esc: pause    F11: fullscreen"
