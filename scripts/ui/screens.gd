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
var _return_to := "title"      # where the Options screen goes back to


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_menu.picked.connect(_on_menu_picked)
	_menu.adjusted.connect(_on_menu_adjusted)
	_menu.moved.connect(func(_key: String) -> void: _refresh_option_help())
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
	_body.position.y = 126
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
	_menu.position.y = 196
	_menu.set_entries([["start", "Begin a run"], ["options", "Options"], ["quit", "Quit"]])
	_refresh_help()
	visible = true


func show_pause() -> void:
	current = "pause"
	_body.position.y = 126
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
	_menu.position.y = 194
	_menu.set_entries([["resume", "Keep going"], ["options", "Options"], ["restart", "Start over"], ["title", "Back to title"]])
	_refresh_help()
	visible = true


func show_end(won: bool, killer_name: String) -> void:
	current = "end"
	_body.position.y = 126
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
	_menu.position.y = 196
	_menu.set_entries([["start", "Try again"], ["title", "Back to title"]])
	_refresh_help()
	visible = true


# ----------------------------------------------------------------------
# Options
# ----------------------------------------------------------------------

func show_options() -> void:
	if current != "options":
		_return_to = current
	current = "options"
	_dim.color = Pal.INK if _return_to == "title" else Color(Pal.INK, 0.94)
	_icon.visible = false
	_title.text = "OPTIONS"
	_title.add_theme_color_override("font_color", Pal.PAPER)
	_subtitle.text = "Left and right change a setting."
	_fill_items(false)
	_menu.position.y = 126
	_menu.set_entries([
		["difficulty", ""], ["music", ""], ["sound", ""], ["fullscreen", ""], ["shake", ""], ["back", "Back"],
	])
	_refresh_options()
	_body.position.y = 218
	_refresh_option_help()
	_refresh_help()
	visible = true


func _refresh_options() -> void:
	_menu.set_text("difficulty", "Difficulty: %s" % Game.DIFFICULTIES[Settings.difficulty]["name"])
	_menu.set_text("music", "Music: %d%%" % roundi(Settings.music_volume * 100.0))
	_menu.set_text("sound", "Sound: %d%%" % roundi(Settings.sfx_volume * 100.0))
	_menu.set_text("fullscreen", "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off"))
	_menu.set_text("shake", "Screen shake: %s" % ("On" if Settings.screen_shake > 0.0 else "Off"))


## A line of explanation under the options list.
func _refresh_option_help() -> void:
	if current != "options":
		return
	match _menu.selected_key():
		"difficulty":
			var tips := [
				"Calm: fewer, slower enemies and 2 extra hearts.",
				"Standard: the game as it is meant to be played.",
				"Stormy: bigger crowds and faster shots.",
			]
			_body.text = "%s\nTakes effect when the next run starts." % tips[Settings.difficulty]
		"shake":
			_body.text = "Shakes the screen on big hits. Turn it off if it bothers you."
		"fullscreen":
			_body.text = "F11 or Alt+Enter also switch this at any time."
		_:
			_body.text = ""


func _change_option(key: String, direction: int) -> void:
	match key:
		"difficulty":
			Settings.difficulty = wrapi(Settings.difficulty + direction, 0, Game.DIFFICULTIES.size())
		"music":
			Settings.music_volume = clampf(snappedf(Settings.music_volume + 0.1 * direction, 0.1), 0.0, 1.0)
		"sound":
			Settings.sfx_volume = clampf(snappedf(Settings.sfx_volume + 0.1 * direction, 0.1), 0.0, 1.0)
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
		"shake":
			Settings.screen_shake = 0.0 if Settings.screen_shake > 0.0 else 1.0
		_:
			return
	Settings.apply()
	Settings.save_settings()
	_refresh_options()
	_refresh_option_help()
	Sfx.play("ui_move")


func _on_menu_adjusted(key: String, direction: int) -> void:
	if current == "options":
		_change_option(key, direction)


func _on_menu_picked(key: String) -> void:
	if key == "options":
		show_options()
	elif current == "options":
		if key == "back":
			_leave_options()
		else:
			_change_option(key, 1)
	else:
		picked.emit(key)


func _leave_options() -> void:
	if _return_to == "pause":
		show_pause()
	else:
		show_title()
	_menu.select_key("options")


## Called by main.gd when Esc or B is pressed. Returns true if it was used.
func go_back() -> bool:
	if current == "options":
		_leave_options()
		Sfx.play("ui_back")
		return true
	return false


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
