extends Control
## Screen: the base every menu screen is built on (title, hero select, pause, settings ...).
## A screen fills the display, builds its own controls in build(), and never changes the flow
## itself: it sends a request such as send("play") and scripts/main.gd decides what happens.
## To make a new screen: copy a small one (credits.gd), override build(), then add it to
## SCREENS in main.gd.

const UI = preload("res://scripts/ui/theme.gd")
const Confirm = preload("res://scripts/ui/confirm.gd")

## A request for main.gd, e.g. ("play", null), ("start", "knight"), ("back", null).
signal action(what: String, arg: Variant)

## The control that gets keyboard / gamepad focus when the screen appears.
var default_focus: Control
var _last_focus: Control
var _dialog: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	build()
	_focus_default.call_deferred()


## Override: create the screen's controls here.
func build() -> void:
	pass


func send(what: String, arg: Variant = null) -> void:
	action.emit(what, arg)


## Esc, the gamepad's B button or the phone's Back button. Override for special cases.
func on_back() -> void:
	if close_dialog():
		return
	Sfx.play("ui_back")
	send("back")


## main.gd calls this when another screen is put on top of this one (true) or taken away again (false).
func set_covered(covered: bool) -> void:
	if covered:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and is_ancestor_of(f):
			_last_focus = f
		visible = false
	else:
		visible = true
		refresh()
		_focus_default.call_deferred()


## Override: called when the screen becomes visible again (a setting may have changed meanwhile).
func refresh() -> void:
	pass


func _focus_default() -> void:
	if not is_inside_tree() or not visible:
		return
	var target := _last_focus if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() else default_focus
	if is_instance_valid(target) and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()


## The usual top bar: a Back button on the left and the screen's name in the middle.
func top_bar(title_text: String) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := UI.button("Back", on_back, "", "")
	back.name = "Back"
	back.position = Vector2(0, 0)
	back.custom_minimum_size = Vector2(40, 19)
	bar.add_child(back)
	var title := UI.label(title_text, "Head")
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	return bar


## A yes / no question on top of this screen. on_yes runs only if the player agrees.
func ask(message: String, yes_text: String, no_text: String, on_yes: Callable, danger: bool = true) -> void:
	close_dialog()
	var f := get_viewport().gui_get_focus_owner()
	if f != null and is_ancestor_of(f):
		_last_focus = f
	_dialog = Confirm.new()
	_dialog.setup(message, yes_text, no_text, danger)
	add_child(_dialog)
	_dialog.answered.connect(func(yes: bool) -> void:
		close_dialog()
		if yes:
			on_yes.call()
		else:
			Sfx.play("ui_back"))


## Closes the question if one is open. Returns true if there was one.
func close_dialog() -> bool:
	if not is_instance_valid(_dialog):
		return false
	_dialog.queue_free()
	_dialog = null
	_focus_default.call_deferred()
	return true
