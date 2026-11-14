extends "res://scripts/ui/screen.gd"
## Talking to someone in a walking place (the HD GUI talk box, "Lantern Glass"): a glass box along
## the bottom with the speaker's bust in a lit well, a brass name plate on its top edge, the words
## appearing letter by letter one page at a time, page dots and an ember chevron in the corner.
## Tap / click / Enter / pad A finishes a page, again for the next. After the last page the
## speaker's choices stand in a panel on the box's right end (the last page stays readable; "lines"
## replace it as small rows), or the box closes.
## scripts/hub/hub.gd fills `info` and main.gd opens it:
##   {"name", "title", "sprite" (an Art id for the picture), "pages": [String],
##    "lines": [String or [String, Color]], "options": [{"text", "what", "arg", "off", "why"}],
##    "heard": npc id, "black": true + "heading" (words on a black screen under a heading)}
## A button sends its "what" and "arg" to main.gd; "off": true shows it greyed out, and pressing it
## says why on the line under the list. The "Leave" button and these names are used by the UI tour.
## Layout numbers are UI px (spec 6.2); a phone uses its own smaller set (see _geo()).
## Test flags: --talkdone (each page is shown whole at once), --talkchoices (straight to the choices),
## --talkwhy (presses the first greyed choice so its reason shows).

const Story = preload("res://scripts/data/story.gd")
const Looks = preload("res://scripts/data/looks.gd")
const WalkKit = preload("res://scripts/ui/walk_kit.gd")
const LETTERS_PER_SECOND := 48.0
## a short breath after these marks while the words come out (lines read like speech)
const PAUSES := {".": 0.22, "!": 0.22, "?": 0.22, ",": 0.09, ";": 0.12, ":": 0.12}

var info := {}
var _pages: Array = []
var _page := 0
var _shown := 0.0
var _text: Label
var _well: Control              ## (v0.40.0) the speaker's portrait: it blinks, nods while the words come, reacts
var _box: Control                ## the glass box (talk panel) with its plate, portrait and words
var _marks: Control              ## page dots + chevron
var _choices: Control            ## the choice panel (null until the words are done)
var _last_tap := -1000
var _why: Label                  ## says why a greyed choice cannot be taken
var _hold := 0.0
var _g := {}                     ## the layout numbers in use (_geo())
var _box_rect := Rect2()


## The layout numbers (UI px): PC (spec 6.2) or phone (spec 6.2, last line).
func _geo() -> Dictionary:
	var W := UI.screen_size(self)
	var ins := UI.safe_insets(self)
	if UI.is_phone():
		var bw := W.x - 16.0 - ins.x - ins.z
		return {"box": Rect2(8.0 + ins.x, W.y - 58.0 - ins.w, bw, 52.0), "well": Vector2(40.0, 44.0), "k": 2.0, "well_pad": 4.0,
			"text_x": 52.0, "text_y": 9.0, "text_r": 14.0, "talk": 10, "line": 12, "plate_x": 50.0, "plate_up": 8.0, "plate_h": 13.0,
			"name": 9, "title": 0, "choice_w": 140.0, "row": 22.0, "choice": 10, "gap": 10.0, "marks_h": 10.0, "small": 8}
	var bw2 := minf(minf(W.x - 40.0, roundf(W.x * 0.72)), 600.0)       # (never a full-width slab for two lines)
	var bh := 92.0
	return {"box": Rect2(roundf((W.x - bw2) * 0.5), W.y - bh - 24.0 - ins.w, bw2, bh), "well": Vector2(86.0, bh - 12.0), "k": 3.0, "well_pad": 6.0,
		"text_x": 108.0, "text_y": 17.0, "text_r": 24.0, "talk": 14, "line": 18, "plate_x": 100.0, "plate_up": 13.0, "plate_h": 22.0,
		"name": 13, "title": 10, "choice_w": 190.0, "row": 20.0, "choice": 12, "gap": 18.0, "marks_h": 14.0, "small": 11}


func help_pairs() -> Array:
	if UI.is_phone():
		return []
	if _choices != null:
		return [["confirm", "Choose"], ["back", "Leave"]]
	return [["confirm", "Next"], ["back", "Leave"]]


func help_corner() -> String:
	return "bottom_right"


func build() -> void:
	_pages = info.get("pages", [])
	_g = _geo()
	_box_rect = _g["box"]
	var black := bool(info.get("black", false))
	if black:
		_build_black()
	else:
		_build_shade()
	if _pages.is_empty() and not black:
		_build_box(false)
		_show_choices()
		return
	if not black:
		_build_box(true)
	focus_mode = Control.FOCUS_ALL
	default_focus = self
	_start_page()
	if G.flag("talkchoices"):
		_finish_words.call_deferred()


## Words on a black screen: a gold Cinzel heading at 22% height, the words centred under it.
func _build_black() -> void:
	var W := UI.screen_size(self)
	var night := ColorRect.new()
	night.color = UI.C_VOID
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	var ph := UI.is_phone()
	var big := UI.label(String(info.get("heading", "")), "Banner")
	big.add_theme_font_size_override("font_size", 13 if ph else 24)
	UI.style_title(big, UI.C_GOLD, Color("7a4a12"))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.position = Vector2(0, roundf(W.y * 0.22) - (10.0 if ph else 18.0))
	big.size = Vector2(W.x, 30)
	add_child(big)
	var rule := UI.lozenge(3.0 if not ph else 2.0, UI.C_GOLD, 40.0 if not ph else 24.0)
	rule.position = Vector2(roundf(W.x * 0.5 - rule.custom_minimum_size.x * 0.5), roundf(W.y * 0.22) + (8.0 if ph else 14.0))
	rule.size = rule.custom_minimum_size
	add_child(rule)
	UI.pop_in(big, Vector2(0, -6))
	if _pages.is_empty():
		return
	var w := minf(420.0 if not ph else 300.0, W.x - 40.0)
	_text = _words_label(int(_g["talk"]), int(_g["line"]))
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.position = Vector2(roundf((W.x - w) * 0.5), roundf(W.y * 0.22) + (18.0 if ph else 30.0))
	_text.size = Vector2(w, W.y * 0.5)
	add_child(_text)
	_marks = WalkKit.TalkMarks.new()
	_marks.position = Vector2(roundf(W.x * 0.5 - 40.0), W.y - (30.0 if ph else 52.0))
	_marks.size = Vector2(80, _g["marks_h"])
	_marks.set("pages", _pages.size())
	add_child(_marks)


## A soft dark fall-off along the bottom so the box reads over any picture.
func _build_shade() -> void:
	var W := UI.screen_size(self)
	var shade := UI.wash("up", 0.55)
	shade.position = Vector2(0, W.y * (0.45 if UI.is_phone() else 0.55))
	shade.size = Vector2(W.x, W.y - shade.position.y)
	add_child(shade)
	if not UI.instant:
		shade.modulate.a = 0.0
		shade.create_tween().tween_property(shade, "modulate:a", 1.0, 0.25)


## The glass box: the well with the bust, the name plate on its top edge, the words, the marks.
func _build_box(with_words: bool) -> void:
	var r := _box_rect
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = r.position
	holder.size = r.size
	add_child(holder)
	_box = holder
	var glass := Panel.new()
	glass.add_theme_stylebox_override("panel", UI.box("talk"))
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(glass)
	var sprite_id := String(info.get("sprite", ""))
	var has_face := sprite_id != "" and Art.has(sprite_id)
	var pad: float = _g["well_pad"]
	var text_x: float = _g["text_x"]
	if has_face:
		var well: Control = WalkKit.Portrait.new()
		var ws: Vector2 = _g["well"]
		well.position = Vector2(pad, pad)
		well.size = ws
		holder.add_child(well)
		well.call("setup", sprite_id, float(_g["k"]))
		_well = well
		if not UI.is_phone():
			# a brass hairline fading upward beside the well
			var line := HairLine.new()
			line.position = Vector2(pad + ws.x + 4.0, pad)
			line.size = Vector2(1, ws.y)
			holder.add_child(line)
	else:
		text_x = 14.0 if not UI.is_phone() else 8.0
	# the name plate, standing on the box's top edge
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UI.box("plate"))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UI.hbox(10 if not UI.is_phone() else 5)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(head)
	var name_label := UI.label(String(info.get("name", "")), "Head")
	name_label.add_theme_font_size_override("font_size", int(_g["name"]))
	name_label.add_theme_color_override("font_color", UI.C_GOLD)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	var title_text := String(info.get("title", ""))
	if title_text != "" and int(_g["title"]) > 0:
		var title := UI.label(title_text, "Small")
		title.add_theme_font_size_override("font_size", int(_g["title"]))
		title.add_theme_color_override("font_color", UI.C_DIM)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
	plate.custom_minimum_size = Vector2(0, _g["plate_h"])
	plate.position = Vector2(float(_g["plate_x"]) if has_face else text_x - 6.0, -float(_g["plate_up"]))
	holder.add_child(plate)
	plate.reset_size()
	UI.pop_in(plate, Vector2(-12, 0))        # (the name plate slides in from the left)
	# the words
	if with_words:
		_text = _words_label(int(_g["talk"]), int(_g["line"]))
		_text.position = Vector2(text_x, _g["text_y"])
		_text.size = Vector2(r.size.x - text_x - float(_g["text_r"]), r.size.y - float(_g["text_y"]) - 6.0)
		_text.clip_text = false
		holder.add_child(_text)
	_marks = WalkKit.TalkMarks.new()
	_marks.size = Vector2(90 if not UI.is_phone() else 60, _g["marks_h"])
	_marks.position = Vector2(r.size.x - _marks.size.x - 4.0, r.size.y - _marks.size.y - (4.0 if not UI.is_phone() else 2.0))
	_marks.set("pages", maxi(_pages.size(), 1))
	_marks.visible = with_words
	holder.add_child(_marks)
	UI.pop_in(holder, Vector2(0, 8))


## The label the words are typed into: body text at `size`, lines `line` UI px apart.
func _words_label(size: int, line: int) -> Label:
	var l := UI.label("", "Talk")
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("line_spacing", maxi(line - int(ceilf(UI.font_body.get_height(size))), 0))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A 1 UI px brass line fading out toward its top.
class HairLine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		RenderingServer.canvas_item_add_polyline(get_canvas_item(), PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, size.y)]),
			PackedColorArray([Color(0.78, 0.62, 0.36, 0.0), Color(0.78, 0.62, 0.36, 0.45)]), 1.0, true)


func _start_page() -> void:
	_text.text = Looks.say(String(_pages[_page]))
	_text.visible_characters = 0
	_shown = 0.0
	_hold = 0.0
	if is_instance_valid(_marks):
		_marks.set("page", _page)
		_marks.set("done", false)
		_marks.set("last", _page >= _pages.size() - 1 and (info.get("options", []) as Array).is_empty() and (info.get("lines", []) as Array).is_empty())
		_marks.queue_redraw()
	if G.flag("talkdone") or UI.instant:
		_shown = float(_text.text.length())
		_text.visible_characters = -1
	if is_instance_valid(_well):
		_well.call("react", _text.text)


func _process(delta: float) -> void:
	if _text == null or _choices != null:
		if is_instance_valid(_well):
			_well.set("talking", false)
		return
	var total := _text.text.length()
	if is_instance_valid(_well):
		_well.set("talking", _shown < float(total) and _hold <= 0.0)
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
	elif is_instance_valid(_marks) and not bool(_marks.get("done")):
		_marks.set("done", true)
		_marks.queue_redraw()


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
	_finish_words()


## The words are done: the choices (and lines), or the box closes.
func _finish_words() -> void:
	if _choices != null:
		return
	if _text != null:
		_page = _pages.size() - 1
		_text.text = Looks.say(String(_pages[_page])) if not _pages.is_empty() else ""
		_shown = float(_text.text.length())
		_text.visible_characters = -1
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
	if is_instance_valid(_box) and _why.get_parent() == _box:
		for c in _box.get_children():           # (phone: the reason takes the place of the words)
			if c != _why and (c == _text or c is VBoxContainer):
				(c as Control).visible = false
	UI.pop_in(_why, Vector2(0, 2))
	_place_choices.call_deferred()


## After the words: what you can ask of them. The box keeps the last page (or shows the "lines");
## the choices stand in a panel on the box's right end.
func _show_choices() -> void:
	var ph := UI.is_phone()
	var lines: Array = info.get("lines", [])
	if not lines.is_empty() and is_instance_valid(_box):
		_show_lines(lines)
	if is_instance_valid(_marks):
		_marks.visible = false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box("panel" if not ph else "card"))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_choices = panel
	var col := UI.vbox(0)
	panel.add_child(col)
	var row_h: float = _g["row"]
	var fs := int(_g["choice"])
	var inner_w: float = _g["choice_w"] - (12.0 if ph else 20.0)
	# a wider list when the words need it (never past most of the box)
	for opt: Dictionary in info.get("options", []):
		inner_w = maxf(inner_w, UI.font_body.get_string_size(String(opt["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (22.0 if ph else 30.0))
	inner_w = minf(inner_w, _box_rect.size.x * (0.9 if ph else 0.62))
	var first: Control = null
	for opt: Dictionary in info.get("options", []):
		var what := String(opt.get("what", "back"))
		var arg: Variant = opt.get("arg")
		var off := bool(opt.get("off", false))
		var why := String(opt.get("why", "You cannot do that yet."))
		# a choice you cannot take is greyed but still takes the focus and answers a tap: it says why
		# (a dead button looked like a broken one: the owner, 12 Nov 2026)
		var b := UI.button(String(opt["text"]), (func() -> void: _say_why(why)) if off else (func() -> void: send(what, arg)), "", "ui_back" if off else "ui_click")
		_row_look(b, row_h, inner_w, fs)
		if off:
			for colour: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(colour, UI.C_FAINT)
		col.add_child(b)
		if first == null and not off:
			first = b
		if off and G.flag("talkwhy") and _why == null:
			b.pressed.emit.call_deferred()        # test: --talkwhy presses the first greyed choice (its reason shows)
	var back := UI.button("Leave", on_back, "", "")
	_row_look(back, row_h, inner_w, fs)
	back.add_theme_color_override("font_color", UI.C_DIM)
	col.add_child(back)
	if ph and is_instance_valid(_box):
		# a phone has no room above the box for a reason line: it takes the box's words instead
		var tx: float = _text.position.x if is_instance_valid(_text) else 8.0
		_why = UI.label("", "Small", _box_rect.size.x - tx - 10.0)
		_why.position = Vector2(tx, _g["text_y"])
		_why.add_theme_font_size_override("font_size", 9)
		_why.add_theme_constant_override("line_spacing", 0)
		_why.add_theme_color_override("font_color", UI.C_BAD)
		_why.visible = false
		_box.add_child(_why)
	else:
		_why = UI.label("", "Small", inner_w - 8.0)
		_why.add_theme_font_size_override("font_size", 8 if ph else 10)
		_why.add_theme_color_override("font_color", UI.C_BAD)
		_why.visible = false
		var why_row := MarginContainer.new()
		why_row.add_theme_constant_override("margin_left", 6 if ph else 8)
		why_row.add_theme_constant_override("margin_top", 2)
		why_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		why_row.add_child(_why)
		col.add_child(why_row)
	panel.resized.connect(_place_choices)
	_place_choices.call_deferred()
	if help != null:          # (during build() the strip is not made yet: help_pairs() says Choose then)
		set_help(help_pairs())
	default_focus = first if first != null else back
	default_focus.grab_focus.call_deferred()
	UI.pop_in(panel, Vector2(0, 6))


func _row_look(b: Button, h: float, w: float, fs: int) -> void:
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## The choice panel stands on the box's right end, its bottom `gap` above the box's top edge
## (in the middle of the screen when there is no box).
func _place_choices() -> void:
	if not is_instance_valid(_choices):
		return
	var s := _choices.get_combined_minimum_size()
	_choices.size = s
	var W := UI.screen_size(self)
	if is_instance_valid(_box) and _box.visible:
		# docked on the box's top right corner, its foot just over the box's top edge
		var x := _box_rect.end.x - s.x - (4.0 if UI.is_phone() else 0.0)
		var y := _box_rect.position.y - (float(_g["gap"]) if UI.is_phone() else 2.0) - s.y
		_choices.position = Vector2(roundf(x), roundf(maxf(y, 4.0)))
	else:
		_choices.position = ((W - s) * 0.5).round()


## Small rows in the box after the words (the smith's shelf: what each piece does).
func _show_lines(lines: Array) -> void:
	var ph := UI.is_phone()
	var fs := int(_g["small"])
	if lines.size() > 4 and not ph:
		fs = 10
	var list := UI.vbox(0 if ph else 1)
	list.position = Vector2(_text.position.x if is_instance_valid(_text) else (14.0 if not ph else 8.0), float(_g["text_y"]))
	# the last page stays when the rows fit under it; otherwise the rows take its place
	if is_instance_valid(_text) and _text.visible:
		var used := float(_text.get_line_count() * int(_g["line"]))
		var row := ceilf(UI.font_body.get_height(fs)) + (0.0 if ph else 1.0)
		if _text.position.y + used + row * lines.size() <= _box_rect.size.y - 4.0:
			list.position.y = _text.position.y + used
		else:
			_text.visible = false
	var w := _box_rect.size.x - list.position.x - (20.0 if not ph else 10.0)
	for line: Variant in lines:
		var words := String(line[0]) if line is Array else String(line)
		var lab := UI.label(Looks.say(words), "Small", w)
		lab.add_theme_font_size_override("font_size", fs)
		lab.add_theme_color_override("font_color", line[1] if line is Array and line.size() > 1 else UI.C_PARCH)
		lab.add_theme_constant_override("line_spacing", 0)
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF if ph else TextServer.AUTOWRAP_WORD_SMART
		if ph:
			lab.clip_text = true
			lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list.add_child(lab)
	list.size = Vector2(w, _box_rect.size.y - list.position.y - 4.0)
	_box.add_child(list)
	UI.pop_in(list, Vector2(0, 3))
