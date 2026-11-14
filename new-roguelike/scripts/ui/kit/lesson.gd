extends PanelContainer
## Lesson: a small glass card with a head, two or three lines and a key cap ("Got it"), shown in the
## middle of the battle screen while nothing moves (quality pass P08). It is dismissed with the
## confirm button, a click or a tap; the one who shows it awaits `done`.
## The words come from scripts/data/lessons.gd. All of it is code (a glass box, labels, a prompt).
##
##   var card: Control = load("res://scripts/ui/kit/lesson.gd").new()
##   parent.add_child(card); card.call("setup", "Title", "Words ...")
##   await card.done

signal done

const UI = preload("res://scripts/ui/theme.gd")
const Lessons = preload("res://scripts/data/lessons.gd")

var _closing := false
var _born := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(title: String, text: String) -> void:
	var ph := UI.is_phone()
	add_theme_stylebox_override("panel", UI.glass(8.0 if ph else 12.0, 6.0 if ph else 9.0, UI.C_BRASS, not ph))
	var col := UI.vbox(3 if ph else 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := UI.label(title, "Head")
	head.add_theme_color_override("font_color", UI.C_GOLD)
	head.add_theme_font_size_override("font_size", 9 if ph else 13)
	col.add_child(head)
	var body := UI.label(_fill(text), "Small" if ph else "", 190.0 if ph else 300.0)
	body.add_theme_color_override("font_color", UI.C_PARCH)
	if ph:
		body.add_theme_font_size_override("font_size", 8)
	col.add_child(body)
	var foot := UI.hbox(4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(UI.prompt("confirm", String(Lessons.word("lesson_ok"))))
	col.add_child(foot)
	_born = Time.get_ticks_msec()


## {fast}, {auto} and {teacher} in a lesson's words.
static func _fill(text: String) -> String:
	var pad := bool(Controls.get("last_pad"))
	return text.replace("{fast}", UI.cap_text("fast", pad)).replace("{auto}", UI.cap_text("auto", pad)) \
		.replace("{teacher}", Lessons.TEACHER_LINE)


## Centred in the parent, a little above the middle.
func centre() -> void:
	var room: Vector2 = (get_parent() as Control).size if get_parent() is Control else Vector2(640, 360)
	reset_size()
	position = ((room - size) * Vector2(0.5, 0.42)).round()
	UI.pop_in(self)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		accept_event()
		close()


func _input(event: InputEvent) -> void:
	if _closing or Time.get_ticks_msec() - _born < 250:
		return            # (the press that ended a turn does not close the card it opened)
	var ok := event.is_action_pressed("ui_accept") or (InputMap.has_action("interact") and event.is_action_pressed("interact"))
	if ok and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("ui_click")
	done.emit()
	queue_free()
