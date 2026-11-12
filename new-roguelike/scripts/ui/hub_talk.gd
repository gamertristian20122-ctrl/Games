extends "res://scripts/ui/screen.gd"
## Talking to someone in the camp, the way old 2D adventure games do it: a box along the bottom
## with the speaker's picture and name, the words appearing letter by letter, one page at a time.
## Tap (or press any button) to finish a page, tap again for the next. After the last page the
## speaker's choices appear as buttons, if there are any; otherwise the box closes.
## scripts/hub/hub.gd fills `info` and main.gd opens it:
##   {"name", "title", "sprite" (an Art id for the picture), "pages": [String],
##    "lines": [String or [String, Color]], "options": [{"text", "what", "arg", "off"}], "heard": npc id}
## A button sends its "what" and "arg" to main.gd; "off": true shows it greyed out.

const Story = preload("res://scripts/data/story.gd")
const Looks = preload("res://scripts/data/looks.gd")
const LETTERS_PER_SECOND := 48.0
const BOX_H := 46.0

var info := {}
var _pages: Array = []
var _page := 0
var _shown := 0.0
var _text: Label
var _more: Label
var _box: Control
var _choices: Control
var _blink := 0.0


func build() -> void:
	_pages = info.get("pages", [])
	if _pages.is_empty():
		_show_choices()
		return
	var margin := UI.safe_margin(self, 5)
	add_child(margin)
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bottom)
	_box = bottom
	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(0, BOX_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(panel)
	var row := UI.hbox(6)
	panel.add_child(row)
	# the speaker's picture: their own sprite, twice as big
	var sprite_id := String(info.get("sprite", ""))
	if sprite_id != "":
		var face := TextureRect.new()
		face.texture = Art.tex(sprite_id)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.custom_minimum_size = Vector2(40, 38)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var well := UI.panel("well")
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(face)
		row.add_child(well)
	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := UI.hbox(4)
	col.add_child(head)
	var name_label := UI.label(String(info.get("name", "")), "Gold")
	head.add_child(name_label)
	var title := UI.label(String(info.get("title", "")), "Small")
	title.add_theme_color_override("font_color", UI.C_FAINT)
	title.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(title)
	head.add_child(UI.spacer(0, 0, true))
	_more = UI.label("", "Small")
	_more.add_theme_color_override("font_color", UI.C_GOLD)
	head.add_child(_more)
	_text = UI.label("", "")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 28)
	col.add_child(_text)
	focus_mode = Control.FOCUS_ALL
	default_focus = self
	_start_page()
	UI.pop_in(panel, Vector2(0, 6))


func _start_page() -> void:
	_text.text = Looks.say(String(_pages[_page]))
	_text.visible_characters = 0
	_shown = 0.0


func _process(delta: float) -> void:
	if _text == null or _choices != null:
		return
	var total := _text.text.length()
	if _shown < total:
		var before := int(_shown)
		_shown = minf(_shown + delta * LETTERS_PER_SECOND, float(total))
		_text.visible_characters = int(_shown)
		if int(_shown) / 3 != before / 3:
			Sfx.play("ui_move", -18.0, 0.1, 1.4)
		_more.text = ""
	else:
		_blink += delta
		_more.text = ("next" if _page < _pages.size() - 1 else "ok") if fmod(_blink, 0.8) < 0.5 else ""


func _advance() -> void:
	if _choices != null or _text == null:
		return
	if _shown < float(_text.text.length()):
		_shown = float(_text.text.length())          # first tap: show the whole page
		_text.visible_characters = -1
		return
	if _page < _pages.size() - 1:
		_page += 1
		_start_page()
		Sfx.play("ui_click", -8.0)
		return
	if String(info.get("heard", "")) != "":
		Story.heard(String(info["heard"]))
	if (info.get("options", []) as Array).is_empty() and (info.get("lines", []) as Array).is_empty():
		Sfx.play("ui_back")
		send("back")
	else:
		_show_choices()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _choices != null or _text == null or not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		get_viewport().set_input_as_handled()
		_advance()


## After the words: what you can ask of them.
func _show_choices() -> void:
	if _box != null:
		_box.visible = false
	var margin := UI.safe_margin(self, 6)
	add_child(margin)
	_choices = margin
	var centre := CenterContainer.new()
	margin.add_child(centre)
	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(226, 0)
	centre.add_child(panel)
	var col := UI.vbox(1)
	panel.add_child(col)
	var head := UI.hbox(4)
	col.add_child(head)
	head.add_child(UI.label(String(info.get("name", "")), "Gold"))
	var title := UI.label(String(info.get("title", "")), "Small")
	title.add_theme_color_override("font_color", UI.C_GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(title)
	for line: Variant in info.get("lines", []):
		var words := String(line[0]) if line is Array else String(line)
		var lab := UI.label(Looks.say(words), "Small", 220.0)
		if line is Array and line.size() > 1:
			lab.add_theme_color_override("font_color", line[1])
		col.add_child(lab)
	var first: Control = null
	for opt: Dictionary in info.get("options", []):
		var what := String(opt.get("what", "back"))
		var arg: Variant = opt.get("arg")
		var b := UI.button(String(opt["text"]), func() -> void: send(what, arg))
		b.custom_minimum_size = Vector2(220, 15)
		b.disabled = bool(opt.get("off", false))
		col.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := UI.button("Leave", on_back, "", "")
	back.custom_minimum_size = Vector2(220, 15)
	col.add_child(back)
	default_focus = first if first != null else back
	default_focus.grab_focus.call_deferred()
	UI.pop_in(panel, Vector2(0, 5))
