extends "res://scripts/ui/screen.gd"
## Settings: sound and music volume (5 big steps), vibration, left-handed sticks, and
## Reset progress (asks twice). Every change is stored with Save.set_setting and works at once.
## To add a setting: add a row in build() and give it a default in scripts/core/save.gd.

const SettingRow = preload("res://scripts/ui/setting_row.gd")


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	col.add_child(top_bar("Settings"))

	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centre)
	var list := UI.vbox(2)
	list.custom_minimum_size.x = 236
	centre.add_child(list)

	var sound := _row("steps", "Sound", "sfx_volume")
	list.add_child(sound)
	sound.changed.connect(func(_v: Variant) -> void: Sfx.play("ui_click"))
	list.add_child(_row("steps", "Music", "music_volume"))
	var vib := _row("toggle", "Vibration", "vibration")
	list.add_child(vib)
	vib.changed.connect(func(v: Variant) -> void:
		if v:
			Input.vibrate_handheld(40))
	list.add_child(_row("toggle", "Left-handed sticks", "swap_sticks"))
	# Easy / Normal / Hard (the numbers are G.DIFFICULTY); it counts from the next level you enter
	var hard := SettingRow.new()
	hard.options = G.DIFFICULTY_NAMES
	hard.setup("choice", "Difficulty", maxi(G.DIFFICULTY_IDS.find(String(Save.setting("difficulty"))), 0))
	hard.changed.connect(func(v: Variant) -> void:
		Save.set_setting("difficulty", String(G.DIFFICULTY_IDS[int(v)]))
		Sfx.play("ui_click"))
	list.add_child(hard)
	var pair := UI.hbox(3)
	list.add_child(pair)
	var knight := UI.button("Your knight", func() -> void: send("customize"))
	knight.custom_minimum_size.y = 19
	knight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(knight)
	var reset := UI.button("Reset progress", _ask_reset)
	reset.custom_minimum_size.y = 19
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.add_theme_color_override("font_color", UI.C_RED)
	reset.add_theme_color_override("font_focus_color", UI.C_RED)
	reset.add_theme_color_override("font_hover_color", UI.C_RED)
	pair.add_child(reset)
	default_focus = sound
	UI.pop_in(list)


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


func on_back() -> void:
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
