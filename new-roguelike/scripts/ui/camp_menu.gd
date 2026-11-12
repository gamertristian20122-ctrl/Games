extends "res://scripts/ui/screen.gd"
## The camp's menu (Back / pause while walking in a camp or on the world map): carry on, look at
## your character, settings, or go to the title screen.

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")


func build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := UI.panel("panel")
	centre.add_child(panel)
	var col := UI.vbox(4)
	col.custom_minimum_size.x = 130
	panel.add_child(col)
	var head := UI.label("%s, level %d" % [Looks.hero_name(), Rpg.level()], "Head")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var resume := UI.button("Carry on", func() -> void: send("back"), "Big")
	resume.custom_minimum_size.y = 26
	col.add_child(resume)
	for pair: Array in [["Character", "sheet"], ["Settings", "settings"], ["Title screen", "title"]]:
		var b := UI.button(String(pair[0]), send.bind(String(pair[1])))
		b.custom_minimum_size.y = 22
		col.add_child(b)
	default_focus = resume
	UI.pop_in(panel)
