extends "res://scripts/ui/screen.gd"
## Controls: every action of the game with the key and the gamepad button that does it, and a way
## to change each (Settings > Controls > "Change keys and buttons"; main.gd opens it as the screen
## "rebind"). The actions and their starting keys are the table ACTIONS in scripts/core/controls.gd;
## what the player changed is kept there too (Controls.set_bind, the setting "binds").
## Choose a cap, then press the new key or button. If another action used at the same moment had
## it, the two swap. Esc (or the pad's B) stops waiting; B is always "back" and cannot be given away.
## HD GUI: the veil and one glass panel; the list scrolls and follows the focus.
## Test flag: --rebindwait opens it already waiting for a key (for a picture).

const VEIL_GAIN := 2.4
## The words of this screen (placeholders: the owner rewrites the game's words).
const WORDS := {
	"title": "Controls",
	"action": "Action", "key": "Keyboard", "pad": "Gamepad",
	"reset": "Back to the usual keys",
	"wait_key": "Press a key for \"%s\".  Esc: leave it as it is.",
	"wait_pad": "Press a gamepad button for \"%s\".  Esc or %s: leave it as it is.",
	"waiting": "...",
	"idle": "Choose a key or a button to change it. The arrow keys, the D-pad and the left stick always walk as well.",
	"swapped": "\"%s\" had it: the two changed places.",
	"set": "\"%s\" is now %s.",
	"fixed_b": "%s always means Back.",
	"reset_done": "Every key and button is as it was at the start.",
}

var _ph := false
var _caps := {}                 ## "<action>:<slot>" -> its Button
var _wait_id := ""              ## the action waiting for a new key ("" = none)
var _wait_slot := ""
var _note: Label
var _scroll: ScrollContainer


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var outer: Control
	if _ph:
		outer = UI.safe_margin(self, 4)
	else:
		outer = CenterContainer.new()
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var panel := UI.panel("panel")
	if not _ph:
		panel.custom_minimum_size.x = 440
	outer.add_child(panel)
	var col := UI.vbox(0)
	panel.add_child(col)
	col.add_child(_header())
	col.add_child(_line(WORDS["action"], null, null))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	var screen_h := UI.screen_size(self).y
	# (whole rows only: half a row at the edge reads as a mistake)
	var room := clampf(screen_h - 150.0, 88.0, 242.0) if not _ph else maxf(screen_h - UI.safe_insets(self).y - UI.safe_insets(self).w - 86.0, 60.0)
	var row_h := 22.0 if not _ph else 20.0
	_scroll.custom_minimum_size.y = floorf(room / row_h) * row_h
	col.add_child(_scroll)
	var list := UI.vbox(0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	var first: Control = null
	for row: Dictionary in Controls.ACTIONS:
		var id := String(row["id"])
		var key_cap := _cap(id, "key")
		var pad_cap := _cap(id, "pad")
		list.add_child(_line(String(row["name"]), key_cap, pad_cap))
		if first == null:
			first = key_cap

	col.add_child(UI.spacer(0, 3 if not _ph else 1))
	var rule := UI.rule(200, UI.C_BRASS_DIM, "both")
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)
	_note = UI.label(WORDS["idle"], "Small", 400.0 if not _ph else 300.0)
	_note.custom_minimum_size.y = (UI.size_small * 2 + 8) if not _ph else (UI.size_small + 4)
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", UI.C_DIM)
	if _ph:
		_note.autowrap_mode = TextServer.AUTOWRAP_OFF
		_note.clip_text = true
	col.add_child(_note)
	var reset := UI.button(WORDS["reset"], _reset)
	reset.name = "Reset"
	reset.custom_minimum_size.y = UI.row_h + (3.0 if not _ph else 1.0)
	reset.alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(reset)
	default_focus = first
	Controls.binds_changed.connect(_show)
	Controls.device_changed.connect(func(_t: bool) -> void: _show())
	_show()
	if not _ph:
		add_child(UI.mouse_back(on_back))
	UI.pop_in(panel)
	if G.flag("rebindwait"):
		_listen.call_deferred("interact", "key")


func _header() -> Control:
	var head := UI.vbox(0)
	var line := Control.new()
	line.custom_minimum_size.y = 22 if not _ph else 20
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	var t := UI.label(WORDS["title"], "Head")
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(t)
	if _ph:
		var back := UI.button("Back", on_back, "", "")
		back.name = "Back"
		back.focus_mode = Control.FOCUS_NONE
		back.custom_minimum_size = Vector2(40, 20)
		line.add_child(back)
	var rule := UI.rule(200, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	head.add_child(rule)
	return head


func _col_w() -> float:
	return 104.0 if not _ph else 78.0


## One line: the action's name, then the two caps (or, with no caps, the column heads).
func _line(words: String, key_cap: Control, pad_cap: Control) -> Control:
	var line := UI.hbox(6 if not _ph else 3)
	line.custom_minimum_size.y = 22 if not _ph else 20
	line.add_child(UI.spacer(8 if not _ph else 4, 0))
	var name_label := UI.label(words, "" if key_cap != null else "Small")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.clip_text = true
	line.add_child(name_label)
	if key_cap == null:
		name_label.add_theme_color_override("font_color", UI.C_DIM)
		for head: String in [WORDS["key"], WORDS["pad"]]:
			var h := UI.label(head, "Small")
			h.custom_minimum_size.x = _col_w()
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.size_flags_vertical = Control.SIZE_FILL
			h.add_theme_color_override("font_color", UI.C_DIM)
			line.add_child(h)
	else:
		line.add_child(key_cap)
		line.add_child(pad_cap)
	line.add_child(UI.spacer(10 if not _ph else 4, 0))       # (room for the scroll bar)
	return line


func _cap(id: String, slot: String) -> Button:
	var b := UI.button("", _listen.bind(id, slot))
	b.name = "%s_%s" % [id, slot]
	b.custom_minimum_size = Vector2(_col_w(), 20 if not _ph else 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_override("font", UI.font_num)
	_caps["%s:%s" % [id, slot]] = b
	return b


func help_pairs() -> Array:
	return [["confirm", "Change"], ["back", "Back"]]


## Writes every cap again (a change, a swap, another make of pad).
func _show() -> void:
	for tag: String in _caps:
		var parts := tag.split(":")
		var b: Button = _caps[tag]
		var waiting := parts[0] == _wait_id and parts[1] == _wait_slot
		var code: int = Controls.bind_of(parts[0], parts[1])
		b.text = WORDS["waiting"] if waiting else (UI.key_name(code) if parts[1] == "key" else UI.pad_name(code))
		var changed := code != Controls.default_bind(parts[0], parts[1])
		b.add_theme_color_override("font_color", UI.C_EMBER if waiting else (UI.C_GOLD if changed else UI.C_PARCH))


func _name_of(id: String) -> String:
	return String(Controls.action_row(id).get("name", id))


func _listen(id: String, slot: String) -> void:
	_wait_id = id
	_wait_slot = slot
	if slot == "key":
		_say(WORDS["wait_key"] % _name_of(id), true)
	else:
		_say(WORDS["wait_pad"] % [_name_of(id), UI.pad_name(JOY_BUTTON_B)], true)
	_show()


func _stop(words: String = "") -> void:
	_wait_id = ""
	_wait_slot = ""
	_say(words if words != "" else String(WORDS["idle"]), false)
	_show()


func _say(words: String, lit: bool) -> void:
	_note.text = words
	_note.add_theme_color_override("font_color", UI.C_GOLD if lit else UI.C_DIM)


func _give(code: int) -> void:
	var id := _wait_id
	var slot := _wait_slot
	var other: String = Controls.set_bind(id, slot, code)
	Sfx.play("ui_click")
	var cap := UI.key_name(code) if slot == "key" else UI.pad_name(code)
	_stop((WORDS["swapped"] % _name_of(other)) if other != "" else (WORDS["set"] % [_name_of(id), cap]))


## While a cap waits, the next key or button is the answer and nothing else sees it.
func _input(event: InputEvent) -> void:
	if _wait_id == "" or not is_visible_in_tree():
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		var code := int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
		if code == KEY_ESCAPE and not (_wait_slot == "key" and _wait_id == "pause"):
			Sfx.play("ui_back")
			_stop()
		elif _wait_slot == "key" and code != 0:
			_give(code)
	elif event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		var j := event as InputEventJoypadButton
		if not j.pressed:
			return
		if j.button_index == JOY_BUTTON_B:
			Sfx.play("ui_back")
			_stop(WORDS["fixed_b"] % UI.pad_name(JOY_BUTTON_B) if _wait_slot == "pad" else "")
		elif _wait_slot == "pad":
			_give(int(j.button_index))
	elif event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()        # (a stick must not move the focus meanwhile)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_stop()


func _reset() -> void:
	Controls.reset_binds()
	_stop(WORDS["reset_done"])


## A right click goes back (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_back()


func on_back() -> void:
	if _wait_id != "":
		_stop()
		return
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
