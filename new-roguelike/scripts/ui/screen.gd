extends Control
## Screen: the base every menu screen is built on (title, hero select, pause, settings ...).
## A screen fills the display, builds its own controls in build(), and never changes the flow
## itself: it sends a request such as send("play") and scripts/main.gd decides what happens.
## To make a new screen: copy a small one (credits.gd), override build(), then add it to
## SCREENS in main.gd.
## HD GUI: screens are built under the menu layer's UiRoot (UI.attach in main.gd), so every number
## here is in UI px (about 800 x 360 on a PC, 400 x 180 on a phone: read UI.screen_size(self)).
## Every screen gets ONE focus flame (the ember pointer) and, if help_pairs() returns any, a help
## strip at the bottom right. Full menus over the world call veil() first in build().

const UI = preload("res://scripts/ui/theme.gd")
const Confirm = preload("res://scripts/ui/confirm.gd")

## A request for main.gd, e.g. ("play", null), ("start", "knight"), ("back", null).
signal action(what: String, arg: Variant)

## The dungeon picture behind the menus (scripts/ui/backdrop.gd); main.gd fills this in.
var backdrop: Control
## The control that gets keyboard / gamepad focus when the screen appears.
var default_focus: Control
var _last_focus: Control
var _dialog: Control
## The ember focus pointer (added after build()).
var flame: Control
## The help strip, if help_pairs() gave any (set_help() changes its words).
var help: Control


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	build()
	var pairs := help_pairs()
	if not pairs.is_empty():
		help = UI.help_strip(pairs, help_corner())
		add_child(help)
	flame = UI.flame(self)
	add_child(flame)
	_focus_default.call_deferred()


## Override: the help strip's pairs, e.g. [["confirm", "Choose"], ["back", "Back"]] ([] = none).
func help_pairs() -> Array:
	return []


## Override: where the help strip sits ("bottom_right", "top_right", "bottom_left", "bottom_center").
func help_corner() -> String:
	return "bottom_right"


## Changes the help strip's words (a page changed). Makes the strip if there was none.
func set_help(pairs: Array) -> void:
	if help == null:
		help = UI.help_strip(pairs, help_corner())
		add_child(help)
		if is_instance_valid(flame):
			move_child(flame, -1)
	else:
		help.call("set_pairs", pairs)


## The full-screen veil (the world behind softened, darkened, cooled). Call first in build().
func veil() -> Control:
	var v := UI.veil()
	add_child(v)
	move_child(v, 0)
	return v


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


## The usual top bar: a Back row button (with its [Esc] prompt) on the left, the screen's name in
## Cinzel in the middle, and a brass rule fading out at both ends under it.
func top_bar(title_text: String) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 24 if not UI.is_phone() else 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UI.label(title_text, "Title" if not UI.is_phone() else "Head")
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var back := UI.button("Back", on_back, "", "")
	back.name = "Back"
	back.position = Vector2(8, 0)
	back.custom_minimum_size = Vector2(44, UI.row_h)
	bar.add_child(back)
	var esc := UI.prompt("back")
	esc.position = Vector2(56, (UI.row_h - 14.0) * 0.5)
	bar.add_child(esc)
	var line := UI.rule(10, UI.C_BRASS, "both")
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = 0
	line.offset_bottom = 1
	bar.add_child(line)
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
