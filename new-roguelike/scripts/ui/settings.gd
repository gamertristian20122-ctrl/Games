extends "res://scripts/ui/screen.gd"
## Settings: sound and music volume (5 steps), vibration, the 3D look, left-handed sticks, screen
## shake, difficulty, the size of the interface (PC), and Your knight / Reset progress (asks twice).
## Every change is stored with Save.set_setting and works at once.
## To add a setting: add a row in build() and give it a default in scripts/core/save.gd.
## HD GUI: the veil and one centred glass panel (420 UI px on a PC, the whole width on a phone).

const SettingRow = preload("res://scripts/ui/setting_row.gd")
const Display = preload("res://scripts/ui/display.gd")
const UI_SIZES := [["small", "Small"], ["normal", "Normal"], ["large", "Large"]]
const VEIL_GAIN := 2.4

var _ph := false


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
		panel.custom_minimum_size.x = 420
	outer.add_child(panel)
	var list := UI.vbox(0)
	panel.add_child(list)
	list.add_child(_header())

	var sound := _row("steps", "Sound", "sfx_volume")
	list.add_child(sound)
	sound.changed.connect(func(_v: Variant) -> void: Sfx.play("ui_click"))
	list.add_child(_row("steps", "Music", "music_volume"))
	var vib := _row("toggle", "Vibration", "vibration")
	vib.changed.connect(func(v: Variant) -> void:
		if v:
			Input.vibrate_handheld(40))
	# the lit 3D look of camps and the world map; off = the old flat picture (for a phone that runs it
	# slowly). It counts from the next time you press Play or come back from a fight.
	var look := _row("toggle", "3D look", "look3d")
	var lefty := _row("toggle", "Left-handed", "swap_sticks")
	var dust := _row("toggle", "Fairy dust", "fairy_dust")      # the glitter that leads to the story goal
	var shake := _row("toggle", "Screen shake", "shake")       # the camera shake on a hit in a battle
	if _ph:
		# two short switches share a line, so the list still fits a phone screen
		for pair: Array in [[vib, look], [lefty, shake], [dust]]:
			var line := UI.hbox(6)
			list.add_child(line)
			for r: Control in pair:
				r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(r)
	else:
		# (a PC has no vibration and no thumb sticks: those two rows are the phone's; it gets
		# Display and VSync instead)
		vib.queue_free()
		lefty.queue_free()
		for r: Control in [look, shake, dust]:
			list.add_child(r)
	# Easy / Normal / Hard (the numbers are G.DIFFICULTY); it counts from the next level you enter
	var hard := SettingRow.new()
	hard.options = G.DIFFICULTY_NAMES
	hard.setup("choice", "Difficulty", maxi(G.DIFFICULTY_IDS.find(String(Save.setting("difficulty"))), 0))
	hard.changed.connect(func(v: Variant) -> void:
		Save.set_setting("difficulty", String(G.DIFFICULTY_IDS[int(v)]))
		Sfx.play("ui_click"))
	list.add_child(hard)
	if not _ph:
		# how big the whole interface is drawn (PC only; a phone keeps its size)
		var size_row := SettingRow.new()
		var names: Array = []
		var at := 1
		for i in UI_SIZES.size():
			names.append(String(UI_SIZES[i][1]))
			if String(UI_SIZES[i][0]) == UI.ui_size_name():
				at = i
		size_row.options = names
		size_row.setup("choice", "Text size", at)
		size_row.changed.connect(func(v: Variant) -> void:
			Save.set_setting("ui_size", String(UI_SIZES[int(v)][0]))
			Sfx.play("ui_click")
			UI.refit_all())
		list.add_child(size_row)
		var disp := SettingRow.new()
		disp.options = Display.MODES.map(func(m: Array) -> String: return String(m[1]))
		disp.setup("choice", "Display", 1 if String(Save.setting("display")) == "full" else 0)
		disp.changed.connect(func(v: Variant) -> void:
			Save.set_setting("display", String(Display.MODES[int(v)][0]))
			Sfx.play("ui_click")
			Display.apply(true))
		list.add_child(disp)
		var vs := _row("toggle", "VSync", "vsync")
		vs.changed.connect(func(_v: Variant) -> void: Display.apply(true))
		list.add_child(vs)
	list.add_child(UI.spacer(0, 6 if not _ph else 2))
	var pair := UI.hbox(8 if not _ph else 4)
	list.add_child(pair)
	var knight := UI.button("Your knight", func() -> void: send("customize"))
	var reset := UI.button("Reset progress", _ask_reset, "Danger")
	for b: Button in [knight, reset]:
		b.custom_minimum_size.y = UI.row_h + (3.0 if not _ph else 1.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pair.add_child(b)
	list.add_child(UI.spacer(0, 2))
	default_focus = sound
	if not _ph:
		_add_back_button()
	UI.pop_in(panel)


## "SETTINGS" in Cinzel over a brass rule (on a phone with a Back button for the thumb).
func _header() -> Control:
	var head := UI.vbox(0)
	var line := Control.new()
	line.custom_minimum_size.y = 22 if not _ph else 20
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	var t := UI.label("Settings", "Head")
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


## A Back button for the mouse at the bottom left (keys and pads have Esc / B).
func _add_back_button() -> void:
	add_child(UI.mouse_back(on_back))


func help_pairs() -> Array:
	return [["target", "Change"], ["confirm", "Choose"], ["back", "Back"]]


func _row(kind: String, title: String, key: String) -> Control:
	var row := SettingRow.new()
	row.setup(kind, title, Save.setting(key))
	row.changed.connect(func(v: Variant) -> void:
		Save.set_setting(key, v)
		Sfx.play("ui_click"))
	return row


func _ask_reset() -> void:
	ask("Erase all unlocks, records and the collection?", "Erase", "Keep", func() -> void:
		ask("Really erase everything? This cannot be undone.", "Erase it all", "Keep", func() -> void:
			Save.reset_progress()
			Sfx.play("ui_back")))


## A right click goes back (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_back()


func on_back() -> void:
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
