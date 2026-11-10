class_name MenuList
extends Control
## A simple up-and-down list of choices that works with keyboard, mouse and
## controller. Used by the title, pause and game-over screens.

signal picked(key: String)

const ROW_HEIGHT := 14.0

var _keys: Array[String] = []
var _rows: Array[Label] = []
var _selected := 0
var _age := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## "entries" is a list of [key, words shown], for example [["start", "Begin a run"]].
func set_entries(entries: Array, width: float = 200.0) -> void:
	for row: Label in _rows:
		row.queue_free()
	_rows.clear()
	_keys.clear()
	_selected = 0
	_age = 0.0
	size = Vector2(width, entries.size() * ROW_HEIGHT)
	for i in entries.size():
		_keys.append(entries[i][0])
		var row := UiKit.label(entries[i][1], 8, Pal.DIM)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.position = Vector2(0, i * ROW_HEIGHT)
		row.size = Vector2(width, ROW_HEIGHT - 2.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(func() -> void: _select(i, true))
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(i, false)
				_pick())
		add_child(row)
		_rows.append(row)
	_refresh()


## Changes the words on one row (used by options that show their value).
func set_text(key: String, text: String) -> void:
	var index := _keys.find(key)
	if index >= 0:
		_rows[index].text = text
		_refresh()


func selected_key() -> String:
	return _keys[_selected] if _selected < _keys.size() else ""


func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _keys.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_select((_selected - 1 + _keys.size()) % _keys.size(), true)
	elif event.is_action_pressed("ui_down"):
		_select((_selected + 1) % _keys.size(), true)
	elif event.is_action_pressed("ui_accept"):
		_pick()
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int, with_sound: bool) -> void:
	if index == _selected:
		return
	_selected = index
	if with_sound:
		Sfx.play("ui_move")
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var on := i == _selected
		_rows[i].add_theme_color_override("font_color", Pal.GOLD if on else Pal.DIM)
		var words := _rows[i].text.trim_prefix("> ").trim_suffix(" <")
		_rows[i].text = "> %s <" % words if on else words


func _pick() -> void:
	if _age < 0.25 or _keys.is_empty():
		return   # ignore presses left over from the screen before
	Sfx.play("ui_ok")
	picked.emit(_keys[_selected])
