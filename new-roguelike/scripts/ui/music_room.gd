extends "res://scripts/ui/screen.gd"
## The Music room: every tune and every short flourish in the game, by title and composer, with
## where the game plays it. Press a row to hear it (through Sfx, so at the game's own levels);
## Stop or Back gives back whatever was playing before.
## It exists so the owner can LISTEN on the phone and say which tracks to keep or swap: nobody
## could hear anything while the score was chosen (see docs/pass/06_audio.md).
## Everything shown comes from scripts/data/tracks.gd. Nothing in this file needs to change when
## a track is swapped.
## Opened by main.gd as the screen "music_room" (Settings has the button).

const Tracks = preload("res://scripts/data/tracks.gd")
const VEIL_GAIN := 2.4

var _scroll: ScrollContainer
var _ph := false
var _rows := {}             # music file -> [Button, the "playing" Label]
var _now: Label
var _playing := ""


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var outer: Control
	if _ph:
		outer = UI.safe_margin(self, 4)
	else:
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_top", 18)
		m.add_theme_constant_override("margin_bottom", 34)
		outer = m
	add_child(outer)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(centre)
	var panel := UI.panel("panel")
	centre.add_child(panel)
	var col := UI.vbox(2)
	panel.add_child(col)
	var w := 560.0 if not _ph else 364.0
	if is_inside_tree():
		var room := UI.screen_size(self)
		var cut := UI.safe_insets(self)
		w = minf(w, room.x - cut.x - cut.z - (24.0 if _ph else 40.0))
	col.add_child(_header())
	var about := UI.label(String(Tracks.WORDS["about"]), "Small", w - 20.0)
	about.add_theme_color_override("font_color", UI.C_DIM)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(about)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	col.add_child(_scroll)
	var list := UI.vbox(2 if not _ph else 1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	resized.connect(_fit_size.bind(panel, w))
	_fit_size(panel, w)         # now, not deferred: the panel must have its size before it is placed

	var first: Button = null
	for row: Dictionary in Tracks.MUSIC:
		var file := String(row["file"])
		if not Sfx.has_music(file):
			continue                    # a row whose file is not in the game is not offered
		var b := _row(list, w, String(row["title"]), String(row["by"]), String(row["plays"]),
			_play.bind(file))
		_rows[file] = b
		if first == null:
			first = b[0]
	var rule := UI.rule(w * 0.6, UI.C_BRASS, "both")
	rule.custom_minimum_size.y = 7
	list.add_child(rule)
	var head := UI.label(String(Tracks.WORDS["stings"]), "Head")
	head.add_theme_color_override("font_color", UI.C_GOLD)
	list.add_child(head)
	for row: Dictionary in Tracks.STINGS:
		var name := String(row["name"])
		if not Sfx.STINGS.has(name) or not Sfx.has(String(Sfx.STINGS[name][0])):
			continue
		_row(list, w, String(row["title"]), String(row["by"]), String(row["plays"]), _sting.bind(name))
	list.add_child(UI.spacer(0, 4))
	if first != null:
		default_focus = first
	_mark(Sfx.playing())
	UI.pop_in(panel)


## One line: a button with the title (press = hear it), then who wrote it and where it plays.
func _row(list: Control, w: float, title: String, by: String, plays: String, press: Callable) -> Array:
	var line := UI.hbox(6)
	list.add_child(line)
	var b := UI.button(title, press, "", "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(floorf(w * 0.36), UI.row_h)
	line.add_child(b)
	var words := UI.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(words)
	var where := UI.label(plays, "Small", w * 0.6 - 16.0)
	words.add_child(where)
	var who := UI.label(String(Tracks.WORDS["by"]) % by, "Small")
	who.add_theme_color_override("font_color", UI.C_FAINT)
	words.add_child(who)
	return [b, where]


func _play(file: String) -> void:
	if _playing == file:
		_stop()
		return
	_playing = file
	Sfx.audition(file)
	_mark(file)


func _sting(name: String) -> void:
	Sfx.sting(name)


func _stop() -> void:
	_playing = ""
	Sfx.audition_end()
	_mark(Sfx.playing())


## Gold on the row that is playing, and its title in the top bar.
func _mark(file: String) -> void:
	var title := ""
	for key: String in _rows:
		var on := key == file or String(Sfx.MUSIC_FILE.get(file, file)) == key
		var b: Button = _rows[key][0]
		var where: Label = _rows[key][1]
		if on:
			b.add_theme_color_override("font_color", UI.C_GOLD)
			where.add_theme_color_override("font_color", UI.C_GOLD)
			title = b.text
		else:
			b.remove_theme_color_override("font_color")
			where.remove_theme_color_override("font_color")
	if is_instance_valid(_now):
		# (a phone's bar is short: the title alone, in gold, says it)
		_now.text = "" if title == "" else (title if _ph else "%s: %s" % [String(Tracks.WORDS["playing"]), title])


func on_back() -> void:
	if close_dialog():
		return
	Sfx.audition_end()
	Sfx.play("ui_back")
	send("back")


func _exit_tree() -> void:
	Sfx.audition_end()          # however the room is left, the game's own music comes back


## The panel is as tall as the screen allows.
func _fit_size(panel: Control, w: float) -> void:
	var host := UI.screen_size(self)
	var h := host.y - (52.0 if not _ph else 8.0)
	var cut := UI.safe_insets(self) if _ph else Vector4.ZERO
	h -= cut.y + cut.w
	panel.custom_minimum_size = Vector2(minf(w + 20.0, host.x - 16.0 - cut.x - cut.z), maxf(h, 80.0))


func _header() -> Control:
	var head := UI.vbox(0)
	var line := Control.new()
	line.custom_minimum_size.y = 22 if not _ph else 18
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	var t := UI.label(String(Tracks.WORDS["title"]), "Head")
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(t)
	var back := UI.button(String(Tracks.WORDS["back"]), on_back, "", "")
	back.name = "Back"
	back.custom_minimum_size = Vector2(44, line.custom_minimum_size.y)
	line.add_child(back)
	default_focus = back
	var stop := UI.button(String(Tracks.WORDS["stop"]), _stop, "", "ui_click")
	stop.name = "Stop"
	stop.custom_minimum_size = Vector2(44, line.custom_minimum_size.y)
	stop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stop.offset_left = -44
	stop.offset_right = 0
	stop.offset_bottom = line.custom_minimum_size.y
	line.add_child(stop)
	_now = UI.label("", "Small")
	_now.add_theme_color_override("font_color", UI.C_GOLD)
	_now.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_now.offset_left = -200 if not _ph else -138
	_now.offset_right = -50
	_now.offset_bottom = line.custom_minimum_size.y
	_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_now.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_now.clip_text = true
	line.add_child(_now)
	var rule := UI.rule(200, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	head.add_child(rule)
	return head


func help_pairs() -> Array:
	return [["confirm", String(Tracks.WORDS["listen"])], ["back", String(Tracks.WORDS["back"])]]


## A right click goes back.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		on_back()
