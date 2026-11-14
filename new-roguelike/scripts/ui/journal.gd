extends "res://scripts/ui/screen.gd"
## THE JOURNAL (quality pass P11): what a player who comes back after a week needs to read.
## Five tabs, turned with the tabs, Q / E or LB / RB (InputMap page_prev / page_next):
##   Story     every step of the tale so far (tale.gd STEPS) under its chapter (quest_list.gd CHAPTERS)
##             and a short recap of the chapter; done steps green, the step now gold
##   Errands   every side errand (errands.gd, modules too): taken, handed in, or "???" when not met yet,
##             who asked and where, how far along, the reward
##   Secrets   chests and hidden things (finds without an errand), found n of m per place
##   Monsters  every kind of monster: its picture, times beaten (the save's "kills:<id>"), health in
##             words and what it does (its kit line); a dark shape until it has been beaten once
##   Records   time played, coins, beacons, monsters beaten, errands and secrets
## The layout is the Knight screen's: a header with the tabs, the list, and a detail panel at the right.
## Opened with J / the pause menu's Journal row (main.gd and pause.gd find this file by its name).
## Every word is in scripts/data/journal_text.gd. Test hooks: _list, _d_title, page.

const Tale = preload("res://scripts/data/tale.gd")
const Errands = preload("res://scripts/data/errands.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const FoeKits = preload("res://scripts/data/foe_kits.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Supplies = preload("res://scripts/data/supplies.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Skills = preload("res://scripts/data/skills.gd")
const More = preload("res://scripts/data/more.gd")
const QuestList = preload("res://scripts/ui/quest_list.gd")
const Txt = preload("res://scripts/data/journal_text.gd")

const VEIL_GAIN := 2.4

var page := "story"              ## the tab shown (main.gd may set it before the screen builds)
var _ph := false
var _tabs := {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _d_title: Label
var _d_text: Label
var _d_now: Label
var _d_next: Label
var _count: Label


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := UI.safe_insets(self) if is_inside_tree() else Vector4.ZERO
	var side := 6.0 if _ph else 24.0
	margin.add_theme_constant_override("margin_left", int(side + ins.x))
	margin.add_theme_constant_override("margin_right", int(side + ins.z))
	margin.add_theme_constant_override("margin_top", int((4.0 if _ph else 18.0) + ins.y))
	margin.add_theme_constant_override("margin_bottom", int((4.0 if _ph else 32.0) + ins.w))
	add_child(margin)
	var col := UI.vbox(0 if _ph else 4)
	margin.add_child(col)
	col.add_child(_header())
	var rule := UI.rule(100, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	col.add_child(rule)
	var body := UI.hbox(16 if not _ph else 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := UI.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.58 if not _ph else 0.55
	body.add_child(left)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	left.add_child(_scroll)
	_list = UI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var right := UI.vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.42 if not _ph else 0.45
	body.add_child(right)
	if not _ph:
		right.add_child(UI.spacer(0, 14))
	right.add_child(_build_detail())
	if not _ph:
		add_child(UI.mouse_back(on_back))
	_show_page(page)
	UI.pop_in(body, Vector2(0, 6))
	if G.arg("p11tour") != "":
		_tour.call_deferred()


func help_pairs() -> Array:
	return [["confirm", "Read"], ["page", "Page"], ["back", "Close"]]


# ------------------------------------------------------------------ header and tabs
func _header() -> Control:
	var head := UI.hbox(6 if not _ph else 2)
	head.custom_minimum_size.y = 30 if not _ph else 22
	if _ph:
		var back := UI.button("Back", on_back, "", "")
		back.name = "Back"
		back.focus_mode = Control.FOCUS_NONE
		back.custom_minimum_size = Vector2(38, 22)
		head.add_child(back)
	var t := UI.label(String(Txt.WORDS["title"]), "Title" if not _ph else "Head")
	t.size_flags_vertical = Control.SIZE_SHRINK_END if not _ph else Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	_count = UI.label("", "Dim" if not _ph else "Small")
	_count.size_flags_vertical = Control.SIZE_SHRINK_END if not _ph else Control.SIZE_SHRINK_CENTER
	if not _ph:
		_count.add_theme_font_size_override("font_size", 11)
		_count.custom_minimum_size.y = 22
	head.add_child(_count)
	_count.visible = not _ph              # (a phone's header has no room for it: the tabs need the line)
	head.add_child(UI.spacer(0, 0, true))
	if not _ph:
		var q := UI.prompt("page_prev")
		q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(q)
	var tabs := UI.hbox(10 if not _ph else 2)
	head.add_child(tabs)
	for pair: Array in Txt.WORDS["tabs"]:
		var id := String(pair[0])
		var tb := UI.button(String(pair[1]), _on_tab.bind(id), "Tab", "")
		tb.name = "tab_" + id
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		if _ph:
			tb.custom_minimum_size = Vector2(40, 22)
			tb.add_theme_font_size_override("font_size", 7)
		else:
			tb.custom_minimum_size = Vector2(0, 22)
		_tabs[id] = tb
		tabs.add_child(tb)
	if not _ph:
		var e := UI.prompt("page_next")
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(e)
	return head


func _on_tab(id: String) -> void:
	if id != page:
		Sfx.play("ui_click")
	_show_page(id, true)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog):
		return
	var dir := 0
	if InputMap.has_action("page_prev") and event.is_action_pressed("page_prev"):
		dir = -1
	elif InputMap.has_action("page_next") and event.is_action_pressed("page_next"):
		dir = 1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		on_back()
		return
	if dir != 0:
		get_viewport().set_input_as_handled()
		var ids: Array = (Txt.WORDS["tabs"] as Array).map(func(p: Array) -> String: return String(p[0]))
		Sfx.play("ui_click")
		_show_page(String(ids[posmod(ids.find(page) + dir, ids.size())]), true)


func _show_page(which: String, focus_first: bool = false) -> void:
	page = which if _tabs.has(which) else "story"
	for id: String in _tabs:
		(_tabs[id] as Button).set_pressed_no_signal(id == page)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match page:
		"errands":
			_fill_errands()
		"secrets":
			_fill_secrets()
		"monsters":
			_fill_monsters()
		"records":
			_fill_records()
		_:
			_fill_story()
	_scroll.scroll_vertical = 0
	if focus_first and is_inside_tree():
		_focus_first.call_deferred()


func _focus_first() -> void:
	for c in _list.get_children():
		if c is Button and (c as Button).focus_mode != Control.FOCUS_NONE:
			(c as Button).grab_focus()
			if page == "story":
				_focus_current.call_deferred()
			return


## On the Story page the step now (the last row) takes the focus, so the newest is in view.
func _focus_current() -> void:
	var now := _list.get_node_or_null("step_%d" % Tale.step())
	if now is Button:
		(now as Button).grab_focus()


# ------------------------------------------------------------------ detail panel
func _build_detail() -> Control:
	var p := UI.panel("panel" if not _ph else "card")
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size.y = 124 if not _ph else 0
	var v := UI.vbox(3 if not _ph else 1)
	p.add_child(v)
	_d_title = UI.label("", "Head")
	_d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_d_title)
	_d_text = UI.label("", "Small" if _ph else "")
	_d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_text.custom_minimum_size.x = 60
	v.add_child(_d_text)
	v.add_child(UI.spacer(0, 4 if not _ph else 1))
	_d_now = UI.label("", "Small")
	_d_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_now.add_theme_color_override("font_color", UI.C_DIM)
	v.add_child(_d_now)
	_d_next = UI.label("", "Small")
	_d_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_d_next)
	return p


func _detail(title: String, text: String, title_colour: Color = UI.C_GOLD, now: String = "", next: String = "", next_colour: Color = UI.C_GOOD) -> void:
	_d_title.text = title
	_d_title.add_theme_color_override("font_color", title_colour)
	_d_text.text = text
	_d_text.add_theme_color_override("font_color", UI.C_PARCH)
	_d_now.text = now
	_d_now.visible = now != ""
	_d_next.text = next
	_d_next.visible = next != ""
	_d_next.add_theme_color_override("font_color", next_colour)


# ------------------------------------------------------------------ list pieces
func _section(text: String, right_text: String = "") -> Control:
	var row := UI.hbox(4)
	row.custom_minimum_size.y = 18 if not _ph else 12
	var l := UI.label(text, "Head")
	l.add_theme_font_size_override("font_size", 10 if not _ph else 8)
	l.add_theme_color_override("font_color", UI.C_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(l)
	if right_text != "":
		var r := UI.label(right_text, "Gold")
		r.add_theme_font_size_override("font_size", 11 if not _ph else 8)
		r.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		row.add_child(r)
	return row


func _para(text: String) -> Control:
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 10 if not _ph else 6)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_bottom", 3)
	var l := UI.label(text, "Small")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	l.add_theme_color_override("font_color", UI.C_DIM)
	pad.add_child(l)
	return pad


## One row: an optional mark (a lozenge of `mark` colour, or a portrait), words, a right-hand tag.
## `on_focus` fills the detail panel.
func _row(row_name: String, text: String, colour: Color, tag: String, tag_colour: Color, on_focus: Callable, mark := Color(0, 0, 0, 0), portrait: Control = null) -> Button:
	var b := Button.new()
	b.name = row_name
	b.custom_minimum_size = Vector2(0, (28 if portrait != null else 22) if not _ph else (22 if portrait != null else 18))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	var row := UI.hbox(6 if not _ph else 3)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8 if not _ph else 4
	row.offset_right = -6 if not _ph else -3
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if portrait != null:
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)
	elif mark.a > 0.0:
		var m := UI.lozenge(3.0 if not _ph else 2.5, mark, 0.0)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.custom_minimum_size = Vector2(8, 8)
		row.add_child(m)
	var l := UI.label(text, "" if not _ph else "Small")
	l.add_theme_color_override("font_color", colour)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	if tag != "":
		var t := UI.label(tag, "Small")
		t.add_theme_color_override("font_color", tag_colour)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.size_flags_vertical = Control.SIZE_FILL
		row.add_child(t)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.05)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -1
	b.add_child(line)
	b.focus_entered.connect(on_focus)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_focus.call())
	_list.add_child(b)
	return b


func _w(key: String) -> String:
	return String(Txt.WORDS.get(key, key))


# ------------------------------------------------------------------ Story
func _fill_story() -> void:
	var now := Tale.step()
	_count.text = QuestList.chapter_heading(now)
	var chapters: Array = QuestList.CHAPTERS
	for ci in chapters.size():
		var first := int(chapters[ci][0])
		if first > now:
			break
		var last := int(chapters[ci + 1][0]) - 1 if ci + 1 < chapters.size() else Tale.LAST_STEP
		_list.add_child(_section("%s  ·  %s" % [chapters[ci][1], chapters[ci][2]]))
		if ci < Txt.RECAP.size():
			_list.add_child(_para(String(Txt.RECAP[ci])))
		for s in range(first, mini(last, now) + 1):
			var text := String(Tale.STEPS[s])
			var done := s < now
			var head := "%s  ·  %s" % [chapters[ci][1], chapters[ci][2]]
			var recap := String(Txt.RECAP[ci]) if ci < Txt.RECAP.size() else ""
			_row("step_%d" % s, text, UI.C_DIM if done else UI.C_GOLD, _w("done") if done else _w("now"),
				UI.C_GOOD if done else UI.C_GOLD,
				_detail.bind(text, recap, UI.C_GOLD if not done else UI.C_PARCH, head,
					_w("done") if done else _w("next_step"), UI.C_GOOD if done else UI.C_GOLD),
				UI.C_GOOD if done else UI.C_GOLD)
	_detail(Tale.objective(), _w("story_hint"), UI.C_GOLD, QuestList.chapter_heading(now))


# ------------------------------------------------------------------ Errands
static func reward_text(reward: Dictionary) -> String:
	var bits: Array = []
	if int(reward.get("coins", 0)) > 0:
		bits.append("%d coins" % int(reward["coins"]))
	for id: String in reward.get("supply", {}):
		var n := int(reward["supply"][id])
		bits.append(("%d x %s" % [n, String(Supplies.row(id).get("name", id))]) if n > 1 else String(Supplies.row(id).get("name", id)))
	if reward.has("gear"):
		bits.append(["a common piece of gear", "a rare piece of gear", "an epic piece of gear"][clampi(int(reward["gear"]), 0, 2)])
	if reward.has("key"):
		bits.append(String(reward.get("key_name", "a key")))
	return ", ".join(bits) if not bits.is_empty() else "-"


func _fill_errands() -> void:
	var all := Errands.all_errands()
	var done := all.filter(func(r: Dictionary) -> bool: return Errands.state(String(r["id"])) == 2).size()
	_count.text = _w("rec_errands") + ": " + _w("of") % [done, all.size()]
	# taken first, then handed in, then those not met yet
	for want: int in [1, 2, 0]:
		var rows := all.filter(func(r: Dictionary) -> bool: return Errands.state(String(r["id"])) == want)
		if rows.is_empty():
			continue
		_list.add_child(_section([_w("errand_unknown").split(".")[0], _w("errand_taken"), _w("errand_done")][want]))
		for r: Dictionary in rows:
			var id := String(r["id"])
			var giver: Array = Txt.GIVER_AT.get(String(r["giver"]), [String(r["giver"]).capitalize(), "?"])
			if want == 0:
				_row("errand_" + id, "???", UI.C_FAINT, "", UI.C_FAINT, _detail.bind("???", _w("errand_unknown"), UI.C_DIM), UI.C_FAINT)
				continue
			var pr := Errands.progress(r)
			var ready := Errands.complete(r)
			var tag := _w("errand_done") if want == 2 else "%d/%d" % [int(pr[0]), int(pr[1])]
			var next := ""
			var next_col := UI.C_GOOD
			if want == 1:
				next = (_w("errand_ready") % String(giver[0])) if ready else "%d / %d" % [int(pr[0]), int(pr[1])]
				next_col = UI.C_GOOD if ready else UI.C_GOLD
			var words := String(r.get("ask", "")) if want == 1 else String(r.get("thanks", r.get("ask", "")))
			_row("errand_" + id, String(r["name"]), UI.C_GOLD if want == 1 else UI.C_DIM, tag,
				UI.C_GOOD if (want == 2 or ready) else UI.C_DIM,
				_detail.bind(String(r["name"]), "\"%s\"" % words, UI.C_GOLD,
					(_w("errand_from") % [giver[0], giver[1]]) + "  " + (_w("errand_reward") % reward_text(r.get("reward", {}))), next, next_col),
				UI.C_GOOD if (want == 2 or ready) else UI.C_GOLD)
	_detail(_w("title"), _w("errand_hint"), UI.C_GOLD, _count.text)


# ------------------------------------------------------------------ Secrets
func _fill_secrets() -> void:
	var by_place := {}
	var order: Array = []
	for f: Dictionary in Errands.all_finds():
		if f.has("errand"):
			continue
		var p := String(f["place"])
		if not by_place.has(p):
			by_place[p] = []
			order.append(p)
		(by_place[p] as Array).append(f)
	var found_all := 0
	var total := 0
	for p: String in order:
		var rows: Array = by_place[p]
		var found: Array = rows.filter(func(f: Dictionary) -> bool: return Save.hub_get("find:" + String(f["id"])) > 0)
		found_all += found.size()
		total += rows.size()
		var seen := Save.hub_get("seen:place:" + p) > 0 or not found.is_empty()
		var nm := String(Txt.PLACE_NAME.get(p, p.capitalize()))
		if not seen:
			_row("secret_" + p, "???", UI.C_FAINT, "?/%d" % rows.size(), UI.C_FAINT, _detail.bind("???", _w("secrets_place_unseen"), UI.C_DIM), UI.C_FAINT)
			continue
		var all_done := found.size() >= rows.size()
		var names: Array = found.map(func(f: Dictionary) -> String: return String(f["name"]))
		var left := rows.size() - found.size()
		_row("secret_" + p, nm, UI.C_PARCH if not all_done else UI.C_DIM, "%d/%d" % [found.size(), rows.size()],
			UI.C_GOOD if all_done else UI.C_GOLD,
			_detail.bind(nm, (_w("secrets_found") % ", ".join(names)) if not names.is_empty() else _w("secrets_hint"), UI.C_GOLD,
				"", _w("secrets_all") if all_done else _w("secrets_left") % left, UI.C_GOOD if all_done else UI.C_GOLD),
			UI.C_GOOD if all_done else UI.C_GOLD)
	_count.text = _w("rec_secrets") + ": " + _w("of") % [found_all, total]
	_detail(_w("rec_secrets"), _w("secrets_hint"), UI.C_GOLD, _count.text)


# ------------------------------------------------------------------ Monsters
## Every monster id a battle can bring, in the order of the lands: [id, is a boss].
static func monster_ids() -> Array:
	var out: Array = []
	var seen := {}
	for land: String in ["grass", "robbers", "sand", "rock"]:
		var k: Dictionary = Roamers.KINDS.get(land, {})
		for id: String in (k.get("shows", []) as Array) + (k.get("night", []) as Array):
			if not seen.has(id) and Enemies.ALL.has(id):
				seen[id] = true
				out.append([id, false])
	var battles: Dictionary = Tale.BATTLES.duplicate()
	battles.merge(More._dict("battles"))
	for b: String in battles:
		for id: String in (battles[b] as Dictionary).get("foes", []):
			if not seen.has(id) and Enemies.ALL.has(id):
				seen[id] = true
				out.append([id, false])
	var bosses: Dictionary = Tale.BOSSES.duplicate()
	bosses.merge(More._dict("bosses"))
	for id: String in bosses:
		if not seen.has(id):
			seen[id] = true
			out.append([id, true])
	return out


static func band(hp: float) -> String:
	for row: Array in Txt.BANDS:
		if hp <= float(row[0]):
			return String(row[1])
	return String(Txt.BANDS[-1][1])


func _fill_monsters() -> void:
	var ids := monster_ids()
	var met := 0
	var bosses: Dictionary = Tale.BOSSES.duplicate()
	bosses.merge(More._dict("bosses"))
	for pair: Array in ids:
		var id := String(pair[0])
		var boss := bool(pair[1])
		var n := Save.hub_get("kills:" + id)
		if n > 0:
			met += 1
		var row: Dictionary = bosses.get(id, {}) if boss else Enemies.ALL[id]
		var sprite := String(row.get("sprite", ""))
		var tint: Color = row.get("tint", Color.WHITE)
		var coin := UI.medallion(sprite, 11.0 if not _ph else 8.0, UI.C_FOE, false, tint if n > 0 else UI.C_SILHOUETTE)
		if n == 0:
			_row("monster_" + id, "???", UI.C_FAINT, "", UI.C_FAINT, _detail.bind("???", _w("monster_unknown"), UI.C_DIM), Color(0, 0, 0, 0), coin)
			continue
		var nm := String(row.get("name", id))
		var line := _w("boss_line")
		var hp_word := "Huge"
		if not boss:
			var kit := FoeKits.of(id, String(row.get("ai", "")))
			line = String(kit.get("line", ""))
			hp_word = band(float(row.get("hp", 10.0)) * float(kit.get("hp", 1.0)))
		var times := _w("monster_beaten_one") if n == 1 else _w("monster_beaten") % n
		_row("monster_" + id, nm, UI.C_GOLD if boss else UI.C_PARCH, "x%d" % n, UI.C_DIM,
			_detail.bind(nm, line, UI.C_GOLD, "Health: %s" % hp_word, times, UI.C_GOOD), Color(0, 0, 0, 0), coin)
	_count.text = _w("rec_kinds") + ": " + _w("of") % [met, ids.size()]
	_detail(_w("rec_kinds"), _w("monsters_hint"), UI.C_GOLD, _count.text)


# ------------------------------------------------------------------ Records
func _fill_records() -> void:
	var beaten := 0
	var bosses := 0
	var kinds := 0
	var ids := monster_ids()
	for pair: Array in ids:
		var n := Save.hub_get("kills:" + String(pair[0]))
		if n > 0:
			kinds += 1
		if bool(pair[1]):
			bosses += n
		else:
			beaten += n
	var errands := Errands.all_errands()
	var done := errands.filter(func(r: Dictionary) -> bool: return Errands.state(String(r["id"])) == 2).size()
	var finds := Errands.all_finds().filter(func(f: Dictionary) -> bool: return not f.has("errand"))
	var found := finds.filter(func(f: Dictionary) -> bool: return Save.hub_get("find:" + String(f["id"])) > 0).size()
	var learned := Skills.LIST.filter(func(r: Dictionary) -> bool: return Skills.known(String(r["id"]))).size()
	var rows: Array = [
		["rec_time", UI.time_text(Save.play_s)],
		["rec_level", str(Rpg.level())],
		["rec_coins", str(Save.hub_get("bank:coins"))],
		["rec_beacons", _w("of") % [Tale.beacons(), 4]],
		["rec_beaten", str(beaten)],
		["rec_bosses", str(bosses)],
		["rec_kinds", _w("of") % [kinds, ids.size()]],
		["rec_errands", _w("of") % [done, errands.size()]],
		["rec_secrets", _w("of") % [found, finds.size()]],
		["rec_skills", _w("of") % [learned, Skills.LIST.size()]],
	]
	if Save.hub_get("rec:wins") > 0:          # (counted only once battle.gd writes it: see docs/pass/11_menus.md)
		rows.insert(4, ["rec_wins", str(Save.hub_get("rec:wins"))])
	for r: Array in rows:
		_row("rec_" + String(r[0]), _w(String(r[0])), UI.C_PARCH, String(r[1]), UI.C_GOLD,
			_detail.bind(_w(String(r[0])), String(r[1]), UI.C_GOLD), UI.C_BRASS)
	_count.text = UI.time_text(Save.play_s)
	_detail(_w("records_hint"), "", UI.C_GOLD)


# ------------------------------------------------------------------ test pictures (--p11tour=<dir>)
## Every tab of this screen, then the World map, the Knight screen's Items, Skills and Party pages, as
## PNGs in that folder, then quits. One renderer run for the whole package.
func _tour() -> void:
	var dir := G.arg("p11tour")
	DirAccess.make_dir_recursive_absolute(dir)
	var tag := "_phone" if _ph else ""
	await get_tree().create_timer(1.0, true, false, true).timeout
	for pair: Array in Txt.WORDS["tabs"]:
		_show_page(String(pair[0]), true)
		await get_tree().create_timer(0.4, true, false, true).timeout
		await _snap(dir, "journal_%s%s.png" % [pair[0], tag])
	var main: Node = get_tree().current_scene
	for spec: Array in [["world_map", {}], ["knight", {"page": "items"}], ["knight", {"page": "skills"}], ["knight", {"page": "party"}]]:
		var s: Control = main.call("open", String(spec[0]), spec[1])
		await get_tree().create_timer(1.0, true, false, true).timeout
		if String(spec[0]) == "knight" and String((spec[1] as Dictionary).get("page", "")) == "skills":
			var first := s.find_child("skill_whirl", true, false)
			if first is Control:
				(first as Control).grab_focus()
				await get_tree().create_timer(0.3, true, false, true).timeout
		await _snap(dir, "%s_%s%s.png" % [spec[0], String((spec[1] as Dictionary).get("page", "map")), tag])
		if String((spec[1] as Dictionary).get("page", "")) == "items" and s.has_method("tour_use"):
			s.call("tour_use")
			await get_tree().create_timer(0.5, true, false, true).timeout
			await _snap(dir, "knight_items_used%s.png" % tag)
		main.call("close_top")
		await get_tree().create_timer(0.3, true, false, true).timeout
	print("[journal] --p11tour: pictures in ", dir)
	G.quit(0)


func _snap(dir: String, file_name: String) -> void:
	if DisplayServer.get_name() == "headless":          # (no frames are drawn: say what would be taken)
		print("[journal] --p11tour: ", file_name, "  top screen: ", get_tree().current_scene.call("top_name"))
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(dir.path_join(file_name))
	else:
		print("[journal] --p11tour: no picture without a renderer: ", file_name)
