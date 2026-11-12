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
const PLATE_RISE := 9.0          ## how far the name plate stands above the box's top edge
## a short breath after these marks while the words come out (lines read like speech)
const PAUSES := {".": 0.22, "!": 0.22, "?": 0.22, ",": 0.09, ";": 0.12, ":": 0.12}

var info := {}
var _pages: Array = []
var _page := 0
var _shown := 0.0
var _text: Label
var _more: Label
var _box: Control
var _choices: Control
var _blink := 0.0
var _last_tap := -1000
var _why: Label                  ## says why a greyed choice cannot be taken
var _arrow: Control
var _hold := 0.0


func build() -> void:
	_pages = info.get("pages", [])
	if bool(info.get("black", false)):
		# an intro: the words stand on a black screen, nothing else to look at
		var night := ColorRect.new()
		night.color = UI.C_VOID
		night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		night.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(night)
		var big := UI.label(String(info.get("heading", "")), "Title")
		UI.style_title(big, UI.C_GOLD, Color("7a4a12"))
		big.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		big.grow_horizontal = Control.GROW_DIRECTION_BOTH
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.offset_top = 22
		add_child(big)
		UI.pop_in(big, Vector2(0, -6))
	if _pages.is_empty():
		_show_choices()
		return
	# a soft dark fall-off along the bottom so the words read over any picture (cinema bars, softened)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.01, 0.01, 0.03, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -BOX_H - 34.0
	add_child(shade)
	if not UI.instant:
		shade.modulate.a = 0.0
		shade.create_tween().tween_property(shade, "modulate:a", 1.0, 0.25)
	var margin := UI.safe_margin(self, 5)
	add_child(margin)
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bottom)
	_box = bottom
	# the box, with the name plate sitting on its top edge (so the holder is a little taller)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, BOX_H + PLATE_RISE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(holder)
	var panel := UI.panel("talk")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = PLATE_RISE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var row := UI.hbox(7)
	panel.add_child(row)
	# the speaker's picture: their own sprite, twice as big, in a gold-rimmed frame
	var sprite_id := String(info.get("sprite", ""))
	var has_face := sprite_id != "" and Art.has(sprite_id)
	if has_face:
		# cut away the empty space round the figure and show it at a whole-pixel scale, as big as fits
		var face := TextureRect.new()
		var tex := Art.tex(sprite_id)
		var used := UI.used_rect(sprite_id)
		var cut := AtlasTexture.new()
		if tex is AtlasTexture:
			cut.atlas = (tex as AtlasTexture).atlas
			cut.region = Rect2((tex as AtlasTexture).region.position + used.position, used.size)
		else:
			cut.atlas = tex
			cut.region = used
		var zoom := maxf(1.0, floorf(minf(34.0 / maxf(used.size.x, 1.0), 32.0 / maxf(used.size.y, 1.0))))
		face.texture = cut
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.custom_minimum_size = (used.size * zoom).round()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := CenterContainer.new()
		frame.custom_minimum_size = Vector2(38, 36)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(face)
		var well := UI.panel("portrait")
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		well.add_child(frame)
		row.add_child(well)
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UI.spacer(0, 3))
	_text = UI.label("", "")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 30)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_text)
	# the name plate: a brass tab on the box's top edge, name in gold, what they are beside it
	var plate := UI.panel("plate")
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(54.0 if has_face else 8.0, 0.0)
	var head := UI.hbox(4)
	plate.add_child(head)
	var name_label := UI.label(String(info.get("name", "")), "Gold")
	name_label.add_theme_color_override("font_outline_color", Color("1a1208"))
	name_label.add_theme_constant_override("outline_size", 2)
	head.add_child(name_label)
	var title_text := String(info.get("title", ""))
	if title_text != "":
		var title := UI.label(title_text, "Small")
		title.add_theme_color_override("font_color", Color("b8a888"))
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
	holder.add_child(plate)
	# "more" is no longer a word: a little gold arrow bobs in the corner when the page is done
	_more = Label.new()
	_more.visible = false
	holder.add_child(_more)
	_arrow = NextArrow.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_arrow.offset_left = -16
	_arrow.offset_top = -12
	_arrow.offset_right = -6
	_arrow.offset_bottom = -3
	_arrow.visible = false
	holder.add_child(_arrow)
	focus_mode = Control.FOCUS_ALL
	default_focus = self
	_start_page()
	UI.pop_in(holder, Vector2(0, 8))


## The bobbing "tap for more" mark: a small gold triangle (a square on the last page),
## drawn from plain rectangles like scripts/ui/arrow.gd.
class NextArrow extends Control:
	var last := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var bob := roundf(sin(_t * 6.0) * 1.2)
		var c := Vector2(roundf(size.x / 2.0), roundf(size.y / 2.0) - 2.0 + bob)
		var gold := Color("facb3e")
		var ink := Color("1a1208")
		if last:
			draw_rect(Rect2(c.x - 3, c.y - 2, 6, 6), ink)
			draw_rect(Rect2(c.x - 2, c.y - 1, 4, 4), gold)
			draw_rect(Rect2(c.x - 2, c.y - 1, 2, 1), gold.lightened(0.5))
			return
		# outline first, then the gold triangle (7 wide at the top, 1 at the tip)
		for i in 5:
			draw_rect(Rect2(c.x - 4 + i, c.y - 2 + i, 9 - i * 2, 1), ink)
		for i in 4:
			draw_rect(Rect2(c.x - 3 + i, c.y - 2 + i, 7 - i * 2, 1), gold if i > 0 else gold.lightened(0.4))


func _start_page() -> void:
	_text.text = Looks.say(String(_pages[_page]))
	_text.visible_characters = 0
	_shown = 0.0
	_hold = 0.0


func _process(delta: float) -> void:
	if _text == null or _choices != null:
		return
	var total := _text.text.length()
	if _shown < total:
		if _hold > 0.0:
			_hold -= delta
			return
		var before := int(_shown)
		_shown = minf(_shown + delta * LETTERS_PER_SECOND, float(total))
		var now := int(_shown)
		_text.visible_characters = now
		if now > before:
			var ch := _text.text[now - 1]
			# a soft tick every few letters, never on a space
			if now / 3 != before / 3 and ch != " ":
				Sfx.play("ui_move", -20.0, 0.12, 1.5)
			if PAUSES.has(ch) and now < total and _text.text[now] == " ":
				_hold = float(PAUSES[ch])
		if is_instance_valid(_arrow):
			_arrow.visible = false
	else:
		_blink += delta
		if is_instance_valid(_arrow):
			_arrow.visible = true
			_arrow.set("last", _page >= _pages.size() - 1)


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
	# a phone sends a touch AND a click for one tap: count it once
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		var now := Time.get_ticks_msec()
		if now - _last_tap > 120:
			_last_tap = now
			_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _choices != null or _text == null or not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		get_viewport().set_input_as_handled()
		_advance()


func _say_why(why: String) -> void:
	_why.text = why
	_why.visible = true
	UI.pop_in(_why, Vector2(0, 2))


## After the words: what you can ask of them.
func _show_choices() -> void:
	if _box != null:
		_box.visible = false
	var margin := UI.safe_margin(self, 6)
	add_child(margin)
	_choices = margin
	var centre := CenterContainer.new()
	margin.add_child(centre)
	var panel := UI.panel("talk")
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
		var off := bool(opt.get("off", false))
		var why := String(opt.get("why", "You cannot do that yet."))
		# a choice you cannot take is greyed but still answers a tap: it says why (a dead button
		# looked like a broken one: the owner, 12 Nov 2026, "your buttons for menus keep not working")
		var b := UI.button(String(opt["text"]), (func() -> void: _say_why(why)) if off else (func() -> void: send(what, arg)), "", "ui_back" if off else "ui_click")
		b.custom_minimum_size = Vector2(220, 15)
		if off:
			for colour: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				b.add_theme_color_override(colour, UI.C_FAINT)
		col.add_child(b)
		if first == null and not off:
			first = b
	_why = UI.label("", "Small", 220.0)
	_why.add_theme_color_override("font_color", UI.C_ORANGE)
	_why.visible = false
	col.add_child(_why)
	var back := UI.button("Leave", on_back, "", "")
	back.custom_minimum_size = Vector2(220, 15)
	col.add_child(back)
	default_focus = first if first != null else back
	default_focus.grab_focus.call_deferred()
	UI.pop_in(panel, Vector2(0, 5))
