extends PanelContainer
## Setting row: one line on the Settings screen. Two kinds:
##   "steps"   a volume-style value from 0 to 5 shown as squares, with minus and plus buttons
##   "toggle"  On / Off
## Works with touch (tap the buttons or the row), keyboard and gamepad (left / right / accept).

const UI = preload("res://scripts/ui/theme.gd")
const Pips = preload("res://scripts/ui/pips.gd")
const Arrow = preload("res://scripts/ui/arrow.gd")

signal changed(value: Variant)

const STEPS := 5

var kind := "steps"
var title := ""
var steps := 0           ## 0..STEPS for "steps"
var on := false          ## for "toggle"
var _pips: Control
var _state: Label


func setup(row_kind: String, row_title: String, start: Variant) -> void:
	kind = row_kind
	title = row_title
	if kind == "steps":
		steps = clampi(int(roundf(float(start) * STEPS)), 0, STEPS)
	else:
		on = bool(start)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 26)
	add_theme_stylebox_override("panel", UI.box("slot"))
	focus_entered.connect(func() -> void: add_theme_stylebox_override("panel", UI.box("slot_focus")))
	focus_exited.connect(func() -> void: add_theme_stylebox_override("panel", UI.box("slot")))
	var row := UI.hbox(4)
	add_child(row)
	row.add_child(UI.spacer(3, 0))
	var name_label := UI.label(title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if kind == "steps":
		var minus := Arrow.new()
		minus.direction = -1
		minus.focus_mode = Control.FOCUS_NONE
		minus.pressed.connect(_nudge.bind(-1))
		row.add_child(minus)
		_pips = Pips.new()
		_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_pips)
		var plus := Arrow.new()
		plus.direction = 1
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(_nudge.bind(1))
		row.add_child(plus)
	else:
		_state = UI.label("")
		_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_state.custom_minimum_size = Vector2(46, 0)
		row.add_child(_state)
	_show()


func _show() -> void:
	if kind == "steps":
		_pips.call("setup", steps, STEPS, UI.C_GOLD)
	else:
		_state.text = "On" if on else "Off"
		_state.add_theme_color_override("font_color", UI.C_GOLD if on else UI.C_FAINT)


func _nudge(by: int) -> void:
	var next := clampi(steps + by, 0, STEPS)
	if next == steps:
		return
	steps = next
	_show()
	changed.emit(steps / float(STEPS))


func _flip() -> void:
	on = not on
	_show()
	changed.emit(on)


func _gui_input(event: InputEvent) -> void:
	if kind == "steps":
		if event.is_action_pressed("ui_left"):
			_nudge(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			_nudge(1)
			accept_event()
	else:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_flip()
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_flip()
			accept_event()
