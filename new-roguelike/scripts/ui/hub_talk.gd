extends "res://scripts/ui/screen.gd"
## The talk window of the camp: who speaks, what they say, a few lines and a few buttons.
## scripts/hub/hub.gd fills `info` and main.gd opens it:
##   {"name", "title", "text", "lines": [String or [String, Color]], "options": [{"text", "what", "arg", "off"}]}
## A button sends its "what" and "arg" to main.gd; "off": true shows it greyed out.

var info := {}


func build() -> void:
	var margin := UI.safe_margin(self, 6)
	add_child(margin)
	var centre := CenterContainer.new()
	margin.add_child(centre)
	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(250, 0)
	centre.add_child(panel)
	var col := UI.vbox(2)
	panel.add_child(col)
	var head := UI.hbox(4)
	col.add_child(head)
	var name_label := UI.label(String(info.get("name", "")), "Head")
	head.add_child(name_label)
	var title := UI.label(String(info.get("title", "")), "Small")
	title.add_theme_color_override("font_color", UI.C_GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(title)
	if String(info.get("text", "")) != "":
		var text := UI.label(String(info["text"]), "", 240.0)
		text.add_theme_color_override("font_color", UI.C_DIM)
		col.add_child(text)
	for line: Variant in info.get("lines", []):
		var words := String(line[0]) if line is Array else String(line)
		var lab := UI.label(words, "", 240.0)
		if line is Array and line.size() > 1:
			lab.add_theme_color_override("font_color", line[1])
		col.add_child(lab)
	var first: Control = null
	for opt: Dictionary in info.get("options", []):
		var what := String(opt.get("what", "back"))
		var arg: Variant = opt.get("arg")
		var b := UI.button(String(opt["text"]), func() -> void: send(what, arg))
		b.custom_minimum_size = Vector2(240, 17)
		b.disabled = bool(opt.get("off", false))
		col.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := UI.button("Leave", on_back, "", "")
	back.custom_minimum_size = Vector2(240, 17)
	col.add_child(back)
	default_focus = first if first != null else back
	UI.pop_in(panel, Vector2(0, 5))
