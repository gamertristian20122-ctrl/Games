extends Control
## Confirm: a small yes / no question shown on top of a screen ("Give up this run?").
## Created through Screen.ask(); the safe answer is on the left and has the focus, so a stray tap or
## Enter does nothing bad, and Esc / B (Screen.on_back -> close_dialog) is the safe answer too.
## HD GUI: a centred glass panel (260 UI px on a PC), the question in body 13, the two answers side
## by side; a dangerous answer is written in the warning colour.

const UI = preload("res://scripts/ui/theme.gd")

signal answered(yes: bool)

var _message := ""
var _yes := "Yes"
var _no := "No"
var _danger := true


func setup(message: String, yes_text: String, no_text: String, danger: bool) -> void:
	_message = message
	_yes = yes_text
	_no = no_text
	_danger = danger


func _ready() -> void:
	var ph := UI.is_phone()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.025, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := UI.panel("panel")
	var w := 260.0 if not ph else 200.0
	panel.custom_minimum_size.x = w
	centre.add_child(panel)
	var col := UI.vbox(8 if not ph else 4)
	panel.add_child(col)
	col.add_child(UI.spacer(0, 4 if not ph else 1))
	var text := UI.label(_message, "", w - (24.0 if not ph else 14.0))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not ph:
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_constant_override("line_spacing", 2)
	col.add_child(text)
	var rule := UI.rule(w * 0.6, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)
	var row := UI.hbox(8 if not ph else 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var no := UI.button(_no, func() -> void: answered.emit(false), "", "")
	var yes := UI.button(_yes, func() -> void: answered.emit(true), "Danger" if _danger else "")
	for b: Button in [no, yes]:
		b.custom_minimum_size = Vector2((w - 40.0) * 0.5, UI.row_h + (5.0 if not ph else 4.0))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not ph:
			b.add_theme_font_size_override("font_size", 13)
	row.add_child(no)
	row.add_child(yes)
	# keep keyboard / gamepad focus inside the question
	for b: Button in [no, yes]:
		var other: Button = yes if b == no else no
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)
	no.grab_focus.call_deferred()
	UI.pop_in(panel)


## A right click is the safe answer (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		answered.emit(false)
