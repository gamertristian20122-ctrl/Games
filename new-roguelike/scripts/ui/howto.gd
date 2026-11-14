extends "res://scripts/ui/screen.gd"
## HOW TO PLAY (quality pass P08): the battle lessons the player has already seen (scripts/data/
## lessons.gd, remembered with Save.flag("taught:b_<id>")), each with its head and words, in a list
## that scrolls. Pause > "How to play" opens it (main.gd's open_screen fallback finds this file);
## Back closes it. Nothing here changes the game.

const Lessons = preload("res://scripts/data/lessons.gd")
const LessonCard = preload("res://scripts/ui/kit/lesson.gd")

var _ph := false


func help_pairs() -> Array:
	return [["back", "Back"]]


func build() -> void:
	_ph = UI.is_phone()
	veil()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := UI.panel("panel")
	centre.add_child(panel)
	var col := UI.vbox(4 if not _ph else 2)
	panel.add_child(col)
	var w := 420.0 if not _ph else 320.0
	var h := 260.0 if not _ph else 140.0
	if is_inside_tree():
		var room := UI.screen_size(self)
		w = minf(w, room.x - 40.0)
		h = minf(h, room.y - (70.0 if not _ph else 30.0))
	col.add_child(top_bar(String(Lessons.word("howto_title"))))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(w, h)
	scroll.follow_focus = true
	col.add_child(scroll)
	var list := UI.vbox(6 if not _ph else 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var any := false
	for row: Dictionary in Lessons.LIST:
		if not Lessons.seen(String(row["id"])):
			continue
		any = true
		# (a focusable row each, so a pad or the keys can scroll through them)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(w - 12.0, 0)
		var inner := UI.vbox(1)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := UI.label(String(row["title"]), "Head")
		head.add_theme_color_override("font_color", UI.C_GOLD)
		head.add_theme_font_size_override("font_size", 9 if _ph else 12)
		inner.add_child(head)
		var body := UI.label(LessonCard._fill(String(row["text"])), "Small", w - 24.0)
		body.add_theme_color_override("font_color", UI.C_PARCH)
		inner.add_child(body)
		b.add_child(inner)
		inner.resized.connect(func() -> void: b.custom_minimum_size.y = inner.size.y + 4.0)
		list.add_child(b)
		if default_focus == null:
			default_focus = b
	if not any:
		var none := UI.label(String(Lessons.word("howto_none")), "", w - 20.0)
		none.add_theme_color_override("font_color", UI.C_DIM)
		list.add_child(none)
