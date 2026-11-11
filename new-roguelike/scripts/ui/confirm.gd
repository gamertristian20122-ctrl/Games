extends Control
## Confirm: a small yes / no question shown on top of a screen ("Give up this run?").
## Created through Screen.ask(); the safe answer has the focus so a stray tap does nothing bad.

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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := UI.panel("card")
	centre.add_child(panel)
	var col := UI.vbox(6)
	panel.add_child(col)
	var text := UI.label(_message, "", 150.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var no := UI.button(_no, func() -> void: answered.emit(false), "", "")
	var yes := UI.button(_yes, func() -> void: answered.emit(true))
	no.custom_minimum_size = Vector2(66, 20)
	yes.custom_minimum_size = Vector2(66, 20)
	if _danger:
		yes.add_theme_color_override("font_color", UI.C_RED)
		yes.add_theme_color_override("font_focus_color", UI.C_RED)
		yes.add_theme_color_override("font_hover_color", UI.C_RED)
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
