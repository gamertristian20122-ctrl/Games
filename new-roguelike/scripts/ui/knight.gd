extends "res://scripts/ui/screen.gd"
## The Knight screen: his level, his XP, and the four stats he puts points into
## (scripts/data/rpg.gd holds every rule and number). Opened with the "Lv" touch button, C / Tab,
## gamepad Y, or the Knight button of the pause menu. Tap a stat to put one point into it.
## A stat that cannot take a point still answers: it says why (never a dead button).
## Four pages, switched with the tabs at the top right (Q / E on a keyboard, LB / RB on a pad):
##   Stats  the four stats and the points, and what he brings into a battle
##   Gear   what he owns and wears: weapons (scripts/data/weapons.gd) and helmets, armour, rings
##          (scripts/data/gear.gd). Tap a piece to wear it, tap it again to take it off.
##   Skills the sword moves and spells he has learned (scripts/data/skills.gd) and which two
##          sit on the skill buttons. Tap a skill, then "On button 1" or "On button 2".
##   Party  the companions who travel with him (scripts/data/allies.gd): who they are, and (in a
##          camp, old story) whether she comes along or waits.
## HD GUI (Lantern Glass, spec 6.4): the veil, a header (name, title and level, tabs), then three
## columns on a PC: the knight on a warm glow with his XP, the list, and a detail panel. On a phone
## the portrait column is left out and the list and the detail stand side by side.
##   Party  (P11) live health and mana bars per member.
##   Items  (quality pass P11) the supplies in the pack: pick one, then who it is for (cards with live
##          health and mana bars). Supplies.use_on() does the sums of a battle (fight.gd _item), and a
##          use that would do nothing says why. Also the coins in the chest and the arms owned.
## (P11) Skills are told by their battle rules (battles.gd SKILL, made stronger by the rank of arms.gd);
## the pages turn with the InputMap actions page_prev / page_next. New words: scripts/data/journal_text.gd KNIGHT.
## Test hooks kept for scripts/ui/ui_tour.gd: _gear_list, _skill_list, _party_box, _hint, _skill_text,
## _reset and the node names gear_<id>, weapon_<id>, skill_<id>, party_<id>, party_why, stat_<id>.

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Supplies = preload("res://scripts/data/supplies.gd")
const Arms = preload("res://scripts/data/arms.gd")
const Txt = preload("res://scripts/data/journal_text.gd")

## main.gd already darkens the world under every menu (its shade); the veil gives some light back.
const VEIL_GAIN := 2.4
const PAGES := [["stats", "Stats"], ["gear", "Gear"], ["skills", "Skills"], ["party", "Party"], ["items", "Items"]]
const W := Txt.KNIGHT

var page := "stats"              ## "stats", "gear", "skills", "party" or "items" (main.gd may set it before the screen builds)
var _ph := false
var _stage: Control
var _name_head: Label
var _sub: Label
var _level: Label                ## (old name) = _sub
var _xp_text: Label
var _xp_bar: Control
var _points: Label
var _rows := {}                  ## stat id -> {"button", "name", "value", "total", "plus"}
var _battle_vals := {}           ## "hp" ... -> its value label
var _reset: Button
var _tabs := {}                  ## page -> its tab button
var _pages := {}                 ## page -> its list column
var _gear_list: VBoxContainer
var _skill_list: VBoxContainer
var _party_box: VBoxContainer
var _skill_sel := ""             ## the skill tapped last
# the detail panel (one for every page; the old per-page names point at the same labels)
var _detail: PanelContainer
var _d_title: Label
var _d_text: Label
var _d_now: Label
var _d_next: Label
var _put_row: HBoxContainer
var _hint: Label
var _gear_name: Label
var _gear_text: Label
var _skill_name: Label
var _skill_text: Label
var _item_list: VBoxContainer    ## (P11) the Items page
var _item_sel := ""              ## the supply chosen last
var _use_box: VBoxContainer      ## the party cards in the detail panel (Items page)


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
	col.add_child(_phone_header() if _ph else _pc_header())
	var rule := UI.rule(100, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	col.add_child(rule)

	var body := UI.hbox(16 if not _ph else 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	if not _ph:
		var left := _portrait_column()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 0.28
		body.add_child(left)
	var lists := Control.new()
	lists.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.size_flags_stretch_ratio = 0.36 if not _ph else 0.55
	body.add_child(lists)
	for p: Control in [_build_stats_page(), _build_gear_page(), _build_skills_page(), _build_party_page(), _build_items_page()]:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lists.add_child(p)
	var right := UI.vbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.33 if not _ph else 0.45
	body.add_child(right)
	if not _ph:
		right.add_child(UI.spacer(0, 14))
	right.add_child(_build_detail())
	if not _ph:
		_add_back_button()
	_show_page(page)
	refresh()
	_show.call_deferred()
	UI.pop_in(body, Vector2(0, 6))


func help_pairs() -> Array:
	return _pairs_for(page)


func _pairs_for(which: String) -> Array:
	match which:
		"gear":
			return [["confirm", "Wear / take off"], ["page", "Page"], ["back", "Close"]]
		"skills":
			return [["confirm", "Choose"], ["page", "Page"], ["back", "Close"]]
		"party":
			return [["confirm", "Choose"], ["page", "Page"], ["back", "Close"]]
		"items":
			return [["confirm", "Use"], ["page", "Page"], ["back", "Close"]]
	return [["confirm", "Add a point"], ["page", "Page"], ["back", "Close"]]


# ------------------------------------------------------------------ header
func _pc_header() -> Control:
	var head := UI.hbox(6)
	head.custom_minimum_size.y = 30
	var name_label := UI.label(Looks.hero_name(), "Title")
	name_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(name_label)
	_name_head = name_label
	_sub = UI.label("", "Dim")
	_sub.add_theme_font_size_override("font_size", 11)
	_sub.size_flags_vertical = Control.SIZE_SHRINK_END
	_sub.custom_minimum_size.y = 22
	_level = _sub
	head.add_child(_sub)
	head.add_child(UI.spacer(0, 0, true))
	var q := UI.prompt("page_prev")
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(q)
	var tabs := UI.hbox(10)
	head.add_child(tabs)
	for t: Array in PAGES:
		tabs.add_child(_tab(String(t[0]), String(t[1]), false))
	var e := UI.prompt("page_next")
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(e)
	return head


## Phone: Back, the name, then four equal touch tabs, all on one line (22 UI px tall).
func _phone_header() -> Control:
	var head := UI.hbox(2)
	head.custom_minimum_size.y = 22
	var back := UI.button("Back", on_back, "", "")
	back.name = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(38, 22)
	head.add_child(back)
	_name_head = UI.label(Looks.hero_name(), "Head")
	_name_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name_head)
	_sub = UI.label("", "Small")
	_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level = _sub
	head.add_child(_sub)
	head.add_child(UI.spacer(0, 0, true))
	for t: Array in PAGES:
		head.add_child(_tab(String(t[0]), String(t[1]), true))
	return head


func _tab(id: String, text: String, phone: bool) -> Button:
	var tb := UI.button(text, _on_tab.bind(id), "Tab", "")
	tb.name = "tab_" + id
	tb.toggle_mode = true
	tb.focus_mode = Control.FOCUS_NONE      # Q / E (LB / RB) page through; the arrows stay in the list
	if phone:
		tb.custom_minimum_size = Vector2(44, 22)
		tb.add_theme_font_size_override("font_size", 8)
	else:
		tb.custom_minimum_size = Vector2(0, 22)
	_tabs[id] = tb
	return tb


func _on_tab(id: String) -> void:
	if id != page:
		Sfx.play("ui_click")
	_show_page(id)


## A Back button for the mouse at the bottom left (keys and pads have Esc / B).
func _add_back_button() -> void:
	add_child(UI.mouse_back(on_back))


## Q / E and LB / RB turn the pages (only on this screen); a right click goes back.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog):
		return
	var dir := 0
	if InputMap.has_action("page_prev") and event.is_action_pressed("page_prev"):
		dir = -1
	elif InputMap.has_action("page_next") and event.is_action_pressed("page_next"):
		dir = 1
	elif not InputMap.has_action("page_prev") and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:      # (only when the controls file made no page actions)
			dir = -1
		elif event.physical_keycode == KEY_E:
			dir = 1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		on_back()
		return
	if dir != 0:
		get_viewport().set_input_as_handled()
		var i := 0
		for k in PAGES.size():
			if String(PAGES[k][0]) == page:
				i = k
		Sfx.play("ui_click")
		_show_page(String(PAGES[posmod(i + dir, PAGES.size())][0]), true)


# ------------------------------------------------------------------ the portrait column (PC)
func _portrait_column() -> Control:
	var left := UI.vbox(3)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.draw.connect(_draw_stage)
	_stage.resized.connect(func() -> void: _show())
	left.add_child(_stage)
	var xp_head := UI.label("Experience", "Head")
	xp_head.add_theme_font_size_override("font_size", 9)
	xp_head.add_theme_color_override("font_color", UI.C_DIM)
	xp_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(xp_head)
	var bar_box := CenterContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(bar_box)
	_xp_bar = UI.bar("xp", 120)
	bar_box.add_child(_xp_bar)
	_xp_text = UI.label("", "Small")
	_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_xp_text)
	if not is_instance_valid(G.run):
		# only in a camp: take every point back and place them again (free)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(holder)
		_reset = UI.button("Take points back", _ask_reset)
		_reset.add_theme_font_size_override("font_size", UI.size_small + 1)
		# (a real framed button, not a loose line of text)
		var n := UI.glass(10.0, 2.0, UI.C_BRASS_DIM)
		var f := UI.glass(10.0, 2.0, Color(UI.C_GOLD, 0.85))
		for st: String in ["normal", "disabled"]:
			_reset.add_theme_stylebox_override(st, n)
		for st: String in ["hover", "pressed", "hover_pressed", "focus"]:
			_reset.add_theme_stylebox_override(st, f)
		_reset.custom_minimum_size = Vector2(130, UI.row_h)
		holder.add_child(_reset)
	left.add_child(UI.spacer(0, 8))
	return left


## The warm glow, a round stone plinth with a brass rim that the knight stands on, and his level
## on a brass badge on its front (all drawn by code).
func _draw_stage() -> void:
	var c := Vector2(roundf(_stage.size.x * 0.5), roundf(_stage.size.y - 26.0))
	var r := minf(_stage.size.x * 0.48, 78.0)
	for i in 9:
		_stage.draw_circle(c + Vector2(0, -r * 0.55), r - i * r / 9.0, Color(1.0, 0.72, 0.42, 0.028))
	var pw := 46.0          # the plinth's half width
	var squash := 0.26
	var face := 9.0         # how tall its front is
	# the front of the drum: dark stone, lit a little at the middle
	var front := Rect2(c.x - pw, c.y, pw * 2.0, face)
	UI.rs_vgrad(_stage.get_canvas_item(), front, Color(0.16, 0.15, 0.19, 0.95), Color(0.05, 0.05, 0.07, 0.95))
	_stage.draw_set_transform(c + Vector2(0, face), 0.0, Vector2(1.0, squash))
	_stage.draw_circle(Vector2.ZERO, pw, Color(0.05, 0.05, 0.07, 0.95), true, -1.0, true)
	_stage.draw_set_transform(c, 0.0, Vector2(1.0, squash))
	_stage.draw_circle(Vector2.ZERO, pw, Color(0.20, 0.19, 0.23, 1.0), true, -1.0, true)
	_stage.draw_circle(Vector2.ZERO, pw * 0.82, Color(0.25, 0.23, 0.27, 1.0), true, -1.0, true)
	_stage.draw_arc(Vector2.ZERO, pw - 0.5, 0.0, TAU, 48, Color(UI.C_BRASS, 0.85), 1.5 / squash * 0.5, true)
	_stage.draw_circle(Vector2(0, 2), 22.0, Color(0, 0, 0, 0.35), true, -1.0, true)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_stage.draw_line(Vector2(c.x - pw, c.y + face - 0.5), Vector2(c.x + pw, c.y + face - 0.5), Color(UI.C_BRASS, 0.5), 1.0)
	# the level badge on the drum's front
	var lv := "LV %d" % Rpg.level()
	var fs := 9
	var tw := UI.font_bold.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var badge := Rect2(roundf(c.x - tw * 0.5 - 7.0), c.y + 1.0, roundf(tw + 14.0), 13.0)
	UI.glass(0.0, 0.0, Color(UI.C_GOLD, 0.9)).draw(_stage.get_canvas_item(), badge)
	_stage.draw_string(UI.font_bold, Vector2(badge.position.x + 7.0, badge.position.y + 10.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.C_GOLD)


## The knight as he looks now: three UI px to one art pixel, standing on the glow.
func _show() -> void:
	if not is_instance_valid(_stage) or _stage.size.x < 4.0:
		return
	for c in _stage.get_children():
		c.queue_free()
	var hero := Heroes.by_id("knight")
	var holder := Node2D.new()
	holder.scale = Vector2(3, 3)
	holder.position = Vector2(roundf(_stage.size.x / 2.0), roundf(_stage.size.y - 26.0))
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(holder)
	var weapon := HeroLook.make_weapon(hero)
	holder.add_child(weapon)
	var body := Art.sprite(String(hero["sprite"]))
	body.modulate = hero.get("tint", Color.WHITE)
	holder.add_child(body)
	HeroLook.rest(weapon, 1.0)
	HeroLook.layer(weapon, body, true)
	_stage.queue_redraw()


# ------------------------------------------------------------------ the detail panel
func _build_detail() -> Control:
	_detail = UI.panel("panel" if not _ph else "card")
	_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail.custom_minimum_size.y = 124 if not _ph else 0
	var v := UI.vbox(3 if not _ph else 1)
	_detail.add_child(v)
	_d_title = UI.label("", "Head")
	_d_title.add_theme_color_override("font_color", UI.C_GOLD)
	_d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_d_title)
	_d_text = UI.label("", "Small" if _ph else "")
	_d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_text.custom_minimum_size.x = 60
	if not _ph:
		_d_text.add_theme_constant_override("line_spacing", 2)
	v.add_child(_d_text)
	v.add_child(UI.spacer(0, 4 if not _ph else 1))
	_d_now = UI.label("", "Small")
	_d_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_now.add_theme_color_override("font_color", UI.C_DIM)
	if not _ph:
		_d_now.add_theme_font_size_override("font_size", 11)
	v.add_child(_d_now)
	_d_next = UI.label("", "Small")
	_d_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_next.add_theme_color_override("font_color", UI.C_GOOD)
	if not _ph:
		_d_next.add_theme_font_size_override("font_size", 11)
	v.add_child(_d_next)
	_put_row = UI.hbox(4)
	_put_row.visible = false
	v.add_child(_put_row)
	for slot in Skills.SLOTS:
		var b := UI.button("On button %d" % (slot + 1), _put_skill.bind(slot), "", "")
		b.name = "put_%d" % slot
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UI.row_h + (3.0 if _ph else 2.0))
		if _ph:
			b.add_theme_font_size_override("font_size", UI.size_small)
		_put_row.add_child(b)
	_use_box = UI.vbox(2 if not _ph else 1)
	_use_box.visible = false
	v.add_child(_use_box)
	_hint = _d_text
	_gear_name = _d_title
	_gear_text = _d_text
	_skill_name = _d_title
	_skill_text = _d_text
	return _detail


func _detail_show(title: String, text: String, title_colour: Color = UI.C_GOLD, now: String = "", next: String = "", next_colour: Color = UI.C_GOOD) -> void:
	_d_title.text = title
	_d_title.add_theme_color_override("font_color", title_colour)
	_d_text.text = text
	_d_text.add_theme_color_override("font_color", UI.C_PARCH)
	_d_now.text = now
	_d_now.visible = now != ""
	_d_next.text = next
	_d_next.visible = next != ""
	_d_next.add_theme_color_override("font_color", next_colour)


# ------------------------------------------------------------------ pages
func _show_page(which: String, focus_first: bool = false) -> void:
	var was := page
	page = which if _pages.has(which) else "stats"
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page
		var tb: Button = _tabs[key]
		tb.set_pressed_no_signal(key == page)
	_put_row.visible = page == "skills"
	_use_box.visible = page == "items"
	if page == "gear":
		_fill_gear()
		_detail_show("Gear", "Tap a piece to wear it. Tap it again to take it off.", UI.C_GOLD,
			"Weapons change only in a camp.")
	elif page == "skills":
		_fill_skills()
		_skill_say("Skills", "Learned as you level up. Tap one, then choose its button. Skills cost mana (the blue bar).", UI.C_GOLD)
	elif page == "party":
		_fill_party()
	elif page == "items":
		_fill_items()
		_items_detail()
	else:
		refresh()
	if is_instance_valid(help):
		_new_help(_pairs_for(page))
	if (focus_first or was != page) and is_inside_tree():
		_focus_page.call_deferred()
	if was != page and is_inside_tree() and is_instance_valid(_pages[page]):
		UI.page_swap(null, _pages[page], 1)


## A new help strip for the page (made afresh: the kit's set_pairs measures the old caps too).
func _new_help(pairs: Array) -> void:
	if is_instance_valid(help):
		help.queue_free()
	help = UI.help_strip(pairs, help_corner())
	add_child(help)
	if is_instance_valid(flame):
		move_child(flame, -1)


## The first row of the page shown takes the focus (a page turned with Q / E or a tab).
func _focus_page() -> void:
	var host: Control = _pages.get(page)
	if host == null or not host.is_visible_in_tree():
		return
	var f := get_viewport().gui_get_focus_owner()
	if f != null and host.is_ancestor_of(f):
		return
	var first := _first_button(host)
	if first != null:
		first.grab_focus()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).focus_mode != Control.FOCUS_NONE and (c as Button).is_visible_in_tree():
			return c
		var deeper := _first_button(c)
		if deeper != null:
			return deeper
	return null


func _section(text: String, right_text: String = "") -> Control:
	var row := UI.hbox(4)
	row.custom_minimum_size.y = 16 if not _ph else 12
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


## A thin line under a row.
func _hairline(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.05)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -1
	parent.add_child(line)


# ------------------------------------------------------------------ the Stats page
func _build_stats_page() -> Control:
	var right := UI.vbox(0)
	_pages["stats"] = right
	var head := _section("Attributes", " ")
	right.add_child(head)
	_points = head.get_child(1) as Label
	right.add_child(UI.spacer(0, 3 if not _ph else 1))
	for r: Dictionary in Rpg.STATS:
		var b := _stat_row(r)
		right.add_child(b)
		if default_focus == null:
			default_focus = b
	if not _ph:
		right.add_child(UI.spacer(0, 8))
		right.add_child(_section("In battle"))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 0)
		right.add_child(grid)
		for pair: Array in [["Health", "hp"], ["Mana", "mp"], ["Attack", "atk"], ["Defence", "def"], ["Speed", "speed"]]:
			var k := UI.label(String(pair[0]), "Dim")
			k.add_theme_font_size_override("font_size", 11)
			k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(k)
			var v := UI.label("", "Num")
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.custom_minimum_size.x = 22
			grid.add_child(v)
			_battle_vals[pair[1]] = v
	return right


## One stat: its name, the points in it and a "+" box (ember while the row has the focus).
func _stat_row(r: Dictionary) -> Button:
	var id := String(r["id"])
	var b := Button.new()
	b.name = "stat_" + id
	b.custom_minimum_size = Vector2(0, 25 if not _ph else 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	var row := UI.hbox(6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10 if not _ph else 6
	row.offset_right = -6 if not _ph else -3
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Color(r["color"], 0.9)
	swatch.custom_minimum_size = Vector2(2, 9 if not _ph else 7)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var name_label := UI.label(String(r["name"]))
	name_label.add_theme_font_size_override("font_size", UI.size_body + 1)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(name_label)
	var value := UI.label("0", "Num")
	value.add_theme_font_size_override("font_size", 14 if not _ph else 10)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_FILL
	value.custom_minimum_size.x = 18
	row.add_child(value)
	var plus := PanelContainer.new()
	plus.custom_minimum_size = Vector2(15, 15) if not _ph else Vector2(12, 12)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus_label := UI.label("+", "Num")
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_child(plus_label)
	row.add_child(plus)
	_hairline(b)
	var total := UI.label("")        # (what the points add up to: shown in the detail panel)
	_rows[id] = {"button": b, "name": name_label, "value": value, "total": total, "plus": plus, "plus_label": plus_label}
	b.focus_entered.connect(func() -> void:
		_stat_detail(id)
		_paint_row(id))
	b.focus_exited.connect(_paint_row.bind(id))
	b.pressed.connect(_spend.bind(id))
	return b


## The row's words and its "+" box follow the focus and whether a point can go in.
func _paint_row(id: String) -> void:
	if not _rows.has(id):
		return
	var row: Dictionary = _rows[id]
	var b: Button = row["button"]
	var focused := b.has_focus()
	(row["name"] as Label).add_theme_color_override("font_color", UI.C_GOLD if focused else UI.C_PARCH)
	var can := Rpg.why_not(id) == ""
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3 if not _ph else 2)
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	if can and focused:
		sb.bg_color = Color(UI.C_EMBER, 0.85)
		sb.border_color = Color(UI.C_GOLD, 0.9)
	elif can:
		sb.bg_color = Color(0.1, 0.1, 0.14, 0.8)
		sb.border_color = Color(UI.C_BRASS, 0.6)
	else:
		sb.bg_color = Color(0.06, 0.06, 0.08, 0.5)
		sb.border_color = Color(UI.C_BRASS, 0.2)
	(row["plus"] as PanelContainer).add_theme_stylebox_override("panel", sb)
	var pl: Label = row["plus_label"]
	pl.add_theme_font_size_override("font_size", 12 if not _ph else 9)
	pl.add_theme_color_override("font_color", UI.C_INK if (can and focused) else (UI.C_PARCH if can else UI.C_FAINT))


## What the stat does, what its points add up to now, and whether one can go in.
func _stat_detail(id: String) -> void:
	var r := Rpg.row(id)
	var why := Rpg.why_not(id)
	var next := "Enter adds a point." if why == "" else why
	if Controls.using_touch:
		next = "Tap to add a point." if why == "" else why
	_detail_show(String(r["name"]), "Each point: %s." % String(r["each"]), UI.C_GOLD,
		"Now: %s" % Rpg.total_text(id), next, UI.C_GOOD if why == "" else UI.C_BAD)


# ------------------------------------------------------------------ the Gear page
func _build_gear_page() -> Control:
	var right := UI.vbox(0)
	_pages["gear"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_gear_list = UI.vbox(0)
	_gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_gear_list)
	return right


func _gear_say(title: String, text: String, colour: Color = UI.C_GOLD, now: String = "", next: String = "", next_colour: Color = UI.C_GOOD) -> void:
	_detail_show(title, text, colour, now, next, next_colour)


## Rebuilds the list: the weapons, then each slot with the pieces he owns.
func _fill_gear() -> void:
	var keep := ""
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and _gear_list.is_ancestor_of(f):
		keep = String(f.name)
	for c in _gear_list.get_children():
		_gear_list.remove_child(c)
		c.queue_free()
	_gear_list.add_child(_section("Weapon"))
	var carried := String(Weapons.current()["id"])
	for w: Dictionary in Weapons.LIST:
		if Weapons.owned(String(w["id"])):
			_gear_list.add_child(_weapon_row(w, String(w["id"]) == carried))
	for s: Dictionary in Gear.SLOTS:
		var slot := String(s["id"])
		_gear_list.add_child(UI.spacer(0, 3 if not _ph else 1))
		_gear_list.add_child(_section(String(s["name"])))
		var rows := Gear.owned_rows(slot)
		if rows.is_empty():
			var none := UI.label("None yet. Monsters, chests, bosses and smiths have them.", "Small")
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			none.custom_minimum_size.x = 60
			none.add_theme_color_override("font_color", UI.C_FAINT)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 10 if not _ph else 6)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_child(none)
			_gear_list.add_child(pad)
		for r: Dictionary in rows:
			_gear_list.add_child(_gear_row(r))
	if keep != "":
		var again := _gear_list.get_node_or_null(NodePath(keep))
		if again is Control:
			(again as Control).grab_focus.call_deferred()


## Rarity colours of the Lantern Glass palette (Common parchment, Rare blue, Epic violet).
static func _rarity_colour(r: Dictionary) -> Color:
	match int(r.get("rarity", 0)):
		1:
			return UI.C_RARE
		2:
			return UI.C_EPIC
	return UI.C_COMMON


## One line: picture, name (in its rarity's colour), a cost and a tag (WORN, BUTTON 1 ...).
func _line(row_name: String, icon_id: String, title: String, colour: Color, on: bool, tag: String, tag_colour: Color = UI.C_GOLD, cost: String = "") -> Button:
	var b := Button.new()
	b.name = row_name
	b.custom_minimum_size = Vector2(0, 24 if not _ph else 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	var row := UI.hbox(6 if not _ph else 3)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6 if not _ph else 3
	row.offset_right = -6 if not _ph else -3
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(16, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var ic := Icon.new()
	ic.setup(icon_id, Vector2.ZERO, 16.0 if not _ph else 14.0)
	slot.add_child(ic)
	var name_label := UI.label(title)
	name_label.add_theme_color_override("font_color", colour)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	if cost != "":
		var c := UI.label(cost, "Small")
		c.add_theme_color_override("font_color", Color(UI.C_MP_A, 0.95) if colour != UI.C_FAINT else UI.C_FAINT)
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.size_flags_vertical = Control.SIZE_FILL
		row.add_child(c)
	if on and tag != "":
		var worn := UI.label(tag, "Head")
		worn.add_theme_font_size_override("font_size", 8 if not _ph else 7)
		worn.add_theme_color_override("font_color", tag_colour)
		worn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		worn.size_flags_vertical = Control.SIZE_FILL
		worn.custom_minimum_size.x = 0
		row.add_child(worn)
		if tag_colour == UI.C_GOLD:
			var mark := UI.lozenge(2.0, UI.C_GOLD, 0.0)
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mark)
	_hairline(b)
	return b


func _gear_row(r: Dictionary) -> Button:
	var id := String(r["id"])
	var b := _line("gear_" + id, String(r["icon"]), String(r["name"]), _rarity_colour(r), Gear.is_worn(id), "Worn")
	var about := func() -> void: _about_gear(r)
	b.focus_entered.connect(about)
	b.pressed.connect(func() -> void:
		if Gear.is_worn(id):
			Gear.take_off(String(r["slot"]))
			Sfx.play("ui_back")
		else:
			Gear.wear(id)
			Sfx.play("shop_buy")
		_gear_changed()
		about.call())
	return b


## What a piece does, and the piece worn in its slot now (the comparison).
func _about_gear(r: Dictionary) -> void:
	var id := String(r["id"])
	var slot := String(r["slot"])
	var kind := "%s %s" % [Gear.rarity_name(r), Gear.slot_name(slot).to_lower()]
	var now := ""
	var next := ""
	var next_col := UI.C_GOOD
	if Gear.is_worn(id):
		now = "You wear it. Tap again to take it off."
	else:
		var on := Gear.worn(slot)
		if on.is_empty():
			now = "Nothing is worn as a %s now." % Gear.slot_name(slot).to_lower()
			next = "Wear it: %s" % Gear.text(r)
		else:
			now = "Worn now: %s (%s)" % [String(on["name"]), Gear.text(on)]
			next = "Wear this instead: %s" % Gear.text(r)
	_gear_say(String(r["name"]), "%s. %s." % [kind, Gear.text_cap(r)], _rarity_colour(r), now, next, next_col)


func _weapon_row(w: Dictionary, carried: bool) -> Button:
	var id := String(w["id"])
	var icon_id := String(w.get("sprite", Looks.sword().get("weapon", "pc_weapon_castle_13")))      # the sword wears the look chosen at the mirror
	var b := _line("weapon_" + id, icon_id, String(w["name"]), UI.C_PARCH, carried, "Carried")
	var numbers := "Damage x%.2f, speed x%.2f." % [float(w.get("damage", 1.0)), float(w.get("rate", 1.0))]
	var about := func() -> void: _gear_say(String(w["name"]), String(w["text"]), UI.C_GOLD, numbers, "You carry it." if carried else "")
	b.focus_entered.connect(about)
	b.pressed.connect(func() -> void:
		if carried:
			about.call()
		elif is_instance_valid(G.run):
			# the hero's whole swing is built from his weapon when a level starts
			Sfx.play("shop_deny")
			_gear_say(String(w["name"]), String(w["text"]), UI.C_GOLD, numbers, "Weapons can only be changed in a camp, not inside a level.", UI.C_BAD)
		else:
			Save.set_setting("weapon", id)
			Sfx.play("shop_buy")
			_fill_gear()
			_show()
			about.call())
	return b


## A piece was put on or taken off: the list, and the knight himself if a level is running.
func _gear_changed() -> void:
	if is_instance_valid(G.run) and is_instance_valid(G.run.get("player")):
		G.run.get("player").call("apply_rpg")
	_fill_gear()


# ------------------------------------------------------------------ the Skills page
func _build_skills_page() -> Control:
	var right := UI.vbox(0)
	_pages["skills"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_skill_list = UI.vbox(0)
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skill_list)
	return right


func _skill_say(title: String, text: String, colour: Color = UI.C_GOLD, now: String = "", next: String = "", next_colour: Color = UI.C_GOOD) -> void:
	_detail_show(title, text, colour, now, next, next_colour)


func _fill_skills() -> void:
	for c in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	_skill_list.add_child(_section("Skills", "%d of %d learned" % [_known_count(), Skills.LIST.size()]))
	for r: Dictionary in Skills.LIST:
		var id := String(r["id"])
		var known := Skills.known(id)
		var slot := Skills.button_of(id)
		var rk := Save.hub_get("lore:knight:" + id)
		var tag := ("Rank %d" % rk) if known else ("Teacher" if Skills.open_for(id) else "Lv %d" % int(r["level"]))
		var b := _line("skill_" + id, String(r["icon"]), String(r["name"]), (UI.C_GOLD if id == _skill_sel else UI.C_PARCH) if known else UI.C_FAINT,
			tag != "", tag, UI.C_GOLD if slot >= 0 else UI.C_FAINT, "%d mana" % int(r["mana"]))
		if not known:
			(b.get_child(0).get_child(0) as Control).modulate = Color(0.55, 0.55, 0.6, 0.7)
		b.focus_entered.connect(_about_skill.bind(id))
		b.pressed.connect(func() -> void:
			_skill_sel = id
			Sfx.play("ui_click")
			_about_skill(id))
		_skill_list.add_child(b)


func _known_count() -> int:
	var n := 0
	for r: Dictionary in Skills.LIST:
		if Skills.known(String(r["id"])):
			n += 1
	return n


func _about_skill(id: String) -> void:
	var r := Skills.row(id)
	var meta := String(W["mana"]) % [String(r["kind"]).capitalize(), int(r["mana"])]
	var rules := skill_rules(id)
	var text := String(r["text"]) if rules == "" else rules
	if Skills.known(id):
		_skill_say(String(r["name"]), text, UI.C_GOLD, meta, rank_line(id), UI.C_GOOD)
	else:
		var how := "A teacher can teach it now: Brother Odo in Wickmere, Sister Imre in Dustwatch." if Skills.open_for(id) \
			else "It opens at level %d; then a teacher (Brother Odo in Wickmere) teaches it." % int(r["level"])
		_skill_say(String(r["name"]), text, UI.C_DIM, meta, how, UI.C_DIM)


## (P11) What a skill does in a battle, with its numbers at the rank it has (battles.gd SKILL, arms.gd ranked()):
## "Hits every monster for 95% of a blow. Stun chance 25%." ("" = the skill has no battle row).
static func skill_rules(id: String, who: String = "knight") -> String:
	if not Battles.SKILL.has(id):
		return ""
	var base: Dictionary = (Battles.SKILL[id] as Dictionary).duplicate()
	base["id"] = id
	base["name"] = String(Skills.row(id).get("name", id))
	var s := Arms.ranked(who, base)
	var aim := String(W.get("aim_" + String(s.get("aim", "foe")), "one monster"))
	var out: Array = [String(s.get("text", ""))]
	if float(s.get("power", 0.0)) > 0.0:
		out.append(String(W["hits"]) % [aim, roundi(float(s["power"]) * 100.0)])
	if s.has("heal"):
		out.append(String(W["heals"]) % [aim, roundi(float(s["heal"]) * 100.0)])
	if s.has("stun"):
		out.append(String(W["stun"]) % roundi(float(s["stun"]) * 100.0))
	if s.has("status"):
		var st: Dictionary = Battles.STATUS.get(String(s["status"][0]), {})
		out.append(String(W["status"]) % [roundi(float(s["status"][1]) * 100.0), String(st.get("name", "")), String(st.get("text", ""))])
	if s.has("bonus"):
		var vs: Array = (s["bonus"]["vs"] as Array).map(func(v: String) -> String:
			return "stunned" if v == "stun" else String((Battles.STATUS.get(v, {}) as Dictionary).get("name", v)).to_lower())
		out.append(String(W["bonus"]) % [str(float(s["bonus"]["mult"])), " and ".join(vs)])
	if bool(s.get("safe", false)):
		out.append(String(W["safe"]))
	if bool(s.get("pierce", false)):
		out.append(String(W["pierce"]))
	if bool(s.get("cleanse", false)):
		out.append(String(W["cleanse"]))
	return " ".join(out).strip_edges()


## (P11) "Rank 1 of 3. Next rank (a teacher, 52 coins): +22% to its blow."
static func rank_line(id: String, who: String = "knight") -> String:
	var rk := maxi(1, Arms.rank(who, id))
	var line := String(W["rank"]) % [rk, Arms.RANK_MAX]
	if rk >= Arms.RANK_MAX:
		return line + " " + String(W["rank_top"])
	var row: Dictionary = Battles.SKILL.get(id, {})
	var adds: Array = []
	if row.has("power") and float(row["power"]) > 0.0:
		adds.append(String(W["rank_power"]) % roundi(Arms.RANK_POWER * 100.0))
	if row.has("heal"):
		adds.append(String(W["rank_heal"]) % roundi(Arms.RANK_HEAL * 100.0))
	if row.has("stun"):
		adds.append(String(W["rank_stun"]) % roundi(Arms.RANK_STUN * 100.0))
	if adds.is_empty():
		return line
	return line + " " + String(W["rank_next"]) % [Arms.price(who, id, Skills.index_of(id)), ", ".join(adds)]


## "On button 1 / 2": puts the tapped skill there. It always answers: when it cannot, it says why.
func _put_skill(slot: int) -> void:
	if _skill_sel == "":
		Sfx.play("shop_deny")
		_skill_say("Choose a skill first", "Then choose the button it goes on.", UI.C_BAD)
		return
	var r := Skills.row(_skill_sel)
	if not Skills.known(_skill_sel):
		Sfx.play("shop_deny")
		_skill_say(String(r["name"]), "Not learned yet: a teacher teaches it (it opens at level %d; you are level %d)." % [int(r["level"]), Rpg.level()], UI.C_BAD)
		return
	Skills.assign(_skill_sel, slot)
	Sfx.play("ui_start")
	_fill_skills()
	_skill_say(String(r["name"]), "It is on skill button %d now." % (slot + 1), UI.C_GOLD)


# ------------------------------------------------------------------ the Party page
func _build_party_page() -> Control:
	var right := UI.vbox(0)
	_pages["party"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_party_box = UI.vbox(3 if not _ph else 1)
	_party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_party_box)
	return right


func _fill_party() -> void:
	for c in _party_box.get_children():
		_party_box.remove_child(c)
		c.queue_free()
	if Tale.on():                          # (P11) everybody's health and mana as the last battle left them
		_party_box.add_child(_section(String(W["health_head"])))
		for u: Dictionary in Battles.party():
			_party_box.add_child(_member_card(u, Callable()))
		_party_box.add_child(UI.spacer(0, 4 if not _ph else 2))
	var mate := Allies.with()
	var known: Array = []
	for r: Dictionary in Allies.LIST:
		if Allies.joined(String(r["id"])):
			known.append(r)
	_party_box.add_child(_section("Companions"))
	if known.is_empty():
		var none := UI.label("Nobody travels with you yet.", "Gold")
		_party_box.add_child(none)
		_detail_show("Companions", "Companions join as the story moves on. Mend the first seal under the hill, then look for a newcomer by the fire in Hollow Hill village.", UI.C_GOLD)
		return
	var units := {}
	if Tale.on():
		for u: Dictionary in Battles.party():
			units[String(u["id"])] = u
	var first := true
	for r: Dictionary in known:
		var id := String(r["id"])
		var here := String(mate.get("id", "")) == id
		var card := UI.panel("card")
		_party_box.add_child(card)
		var row := UI.hbox(8 if not _ph else 4)
		card.add_child(row)
		var coin := UI.medallion(String(r["sprite"]), 16.0 if not _ph else 10.0, UI.C_STEEL, here or Tale.on())
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(coin)
		var words := UI.vbox(0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var who := UI.label(String(r["name"]), "Name")
		who.add_theme_color_override("font_color", UI.C_GOLD)
		words.add_child(who)
		var title := UI.label(String(r["title"]), "Small")
		title.add_theme_color_override("font_color", UI.C_DIM)
		words.add_child(title)
		var numbers := ""
		if units.has(id):
			var u: Dictionary = units[id]
			numbers = "Health %d   Mana %d   Attack %d" % [int(u["max_hp"]), int(u["max_mp"]), roundi(float(u["atk"]))]
		else:
			numbers = "%s hearts, bolts at %d%% of your blow" % [str(Allies.max_hp(r) / 2.0).trim_suffix(".0"), roundi(float(r["damage"]) * 100.0)]
		var nl := UI.label(numbers, "Small")
		nl.add_theme_color_override("font_color", UI.C_PARCH)
		words.add_child(nl)
		var state_text := "She travels with you." if here else "She waits in Hollow Hill village."
		if Tale.on():
			state_text = "She fights beside you." if units.has(id) else state_text
		var state := UI.label(state_text, "Small")
		state.add_theme_color_override("font_color", UI.C_GOOD if (here or units.has(id)) else UI.C_DIM)
		_party_box.add_child(state)
		var b := UI.button("Ask her to wait in the village" if here else "Ask her to come with you", _party_toggle.bind(id, here))
		b.name = "party_" + id
		b.custom_minimum_size = Vector2(0, UI.row_h + (1.0 if _ph else 2.0))
		if _ph:
			b.add_theme_font_size_override("font_size", UI.size_small + 1)
		b.focus_entered.connect(_detail_show.bind(String(r["name"]), String(r["about"]), UI.C_GOLD, String(r["title"]), state_text, UI.C_GOOD if (here or units.has(id)) else UI.C_DIM))
		_party_box.add_child(b)
		var why := UI.label("", "Small")
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 60
		why.name = "party_why"
		why.add_theme_color_override("font_color", UI.C_BAD)
		_party_box.add_child(why)
		if first:
			_detail_show(String(r["name"]), String(r["about"]), UI.C_GOLD, String(r["title"]), state_text, UI.C_GOOD if (here or units.has(id)) else UI.C_DIM)
			first = false


## The button always answers: inside a level it says why nothing changes.
func _party_toggle(id: String, here: bool) -> void:
	if is_instance_valid(G.run):
		Sfx.play("shop_deny")
		var why := _party_box.get_node_or_null("party_why")
		if why is Label:
			(why as Label).text = "Not inside a level. Who travels with you can only be changed in a camp."
		return
	Sfx.play("ui_start")
	send("party_set", "" if here else id)
	_fill_party()


# ------------------------------------------------------------------ (P11) the Items page
func _build_items_page() -> Control:
	var right := UI.vbox(0)
	_pages["items"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_item_list = UI.vbox(0)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)
	return right


## The icon a supply shows (the battle screen's own choice; new items fall back to the flask).
static func _item_icon(id: String) -> String:
	return String({"herb": "icon_misers_flask", "tonic": "icon_sparking_tonic", "elixir": "icon_swift_tonic"}.get(id, "icon_misers_flask"))


func _fill_items() -> void:
	var keep := ""
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and _item_list.is_ancestor_of(f):
		keep = String(f.name)
	for c in _item_list.get_children():
		_item_list.remove_child(c)
		c.queue_free()
	_item_list.add_child(_section(String(W["items_head"])))
	var any := false
	for r: Dictionary in Supplies.LIST:
		var id := String(r["id"])
		var n := Supplies.count(id)
		if n <= 0 and id != _item_sel:
			continue
		any = true
		var b := _line("item_" + id, _item_icon(id), String(r["name"]), UI.C_GOLD if id == _item_sel else UI.C_PARCH, true, "x%d" % n,
			UI.C_GOLD if n > 0 else UI.C_FAINT)
		b.focus_entered.connect(_about_item.bind(id))
		b.pressed.connect(_pick_item.bind(id))
		_item_list.add_child(b)
	if not any:
		var none := UI.label(String(W["items_none"]), "Small")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 60
		none.add_theme_color_override("font_color", UI.C_FAINT)
		_item_list.add_child(none)
	_item_list.add_child(UI.spacer(0, 4 if not _ph else 2))
	_item_list.add_child(_section(String(W["coins_head"]), String(W["coins"]) % Save.hub_get("bank:coins")))
	_item_list.add_child(UI.spacer(0, 2))
	_item_list.add_child(_section(String(W["arms_head"])))
	for line: String in Arms.LINES:
		var who := String(Arms.LINES[line]["who"])
		if who != "knight" and not Allies.joined(who):
			continue
		var tiers: Array = Arms.LINES[line]["tiers"]
		var cur := Arms.current(line)
		var l := UI.label(String(W["arms_line"]) % [String(Arms.LINES[line]["label"]).capitalize(), String(cur["name"]), tiers.find(cur) + 1, tiers.size()], "Small")
		l.add_theme_color_override("font_color", UI.C_PARCH)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 10 if not _ph else 6)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(l)
		_item_list.add_child(pad)
	if keep != "":
		var again := _item_list.get_node_or_null(NodePath(keep))
		if again is Control:
			(again as Control).grab_focus.call_deferred()


## The detail panel of the Items page: the supply chosen (or the page's hint) and a card per party member.
func _items_detail(said: String = "", said_colour: Color = UI.C_GOOD) -> void:
	if _item_sel != "" and not Supplies.row(_item_sel).is_empty():
		var r := Supplies.row(_item_sel)
		_detail_show(String(r["name"]), String(r["text"]), UI.C_GOLD,
			String(W["item_have"]) % [Supplies.count(_item_sel), Supplies.cap_of(_item_sel)], said if said != "" else String(W["item_pick"]), said_colour)
	else:
		_detail_show(String(W["items_tab"]), String(W["items_hint"]), UI.C_GOLD, "", said, said_colour)
	_fill_use_box()


func _about_item(id: String) -> void:
	var r := Supplies.row(id)
	_detail_show(String(r["name"]), String(r["text"]), UI.C_GOLD, String(W["item_have"]) % [Supplies.count(id), Supplies.cap_of(id)],
		String(W["item_pick"]) if id == _item_sel else "", UI.C_GOOD)


func _pick_item(id: String) -> void:
	_item_sel = id
	Sfx.play("ui_click")
	_fill_items()
	_items_detail()
	if _use_box.get_child_count() > 0:
		var first := _first_button(_use_box)
		if first != null:
			first.grab_focus.call_deferred()


## One card per party member: name, health and mana bars with numbers, and what the chosen supply
## would give them ("+12"). Pressing it uses the supply on them.
func _fill_use_box() -> void:
	for c in _use_box.get_children():
		_use_box.remove_child(c)
		c.queue_free()
	var party := Battles.party()
	var head := UI.label(String(W["use_head"]), "Head")
	head.add_theme_font_size_override("font_size", 10 if not _ph else 8)
	head.add_theme_color_override("font_color", UI.C_DIM)
	_use_box.add_child(head)
	for u: Dictionary in party:
		_use_box.add_child(_member_card(u, _use_on.bind(String(u["id"]))))


func _member_card(u: Dictionary, on_press: Callable) -> Button:
	var id := String(u["id"])
	var b := Button.new()
	b.name = "member_" + id
	b.custom_minimum_size = Vector2(0, 30 if not _ph else 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL if on_press.is_valid() else Control.FOCUS_NONE
	if not on_press.is_valid():
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.juice(b)
	var row := UI.hbox(6 if not _ph else 3)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6 if not _ph else 3
	row.offset_right = -6 if not _ph else -3
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var coin := UI.medallion(String(u["sprite"]), 10.0 if not _ph else 7.0, UI.C_STEEL, false)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var words := UI.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var hp := int(u.get("start_hp", u["max_hp"]))
	var mp := int(u.get("start_mp", u["max_mp"]))
	var top := UI.hbox(4)
	words.add_child(top)
	var nl := UI.label(String(u["name"]), "Small")
	nl.add_theme_color_override("font_color", UI.C_GOLD)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	var nums := UI.label("%d/%d  %d/%d" % [hp, int(u["max_hp"]), mp, int(u["max_mp"])], "Small")
	nums.add_theme_color_override("font_color", UI.C_LOW if hp * 10 < int(u["max_hp"]) * 3 else UI.C_DIM)
	top.add_child(nums)
	if _item_sel != "" and on_press.is_valid():
		var pv := Supplies.preview_use(_item_sel, id)
		var gain := 0
		for pair: Array in pv["targets"]:
			if String(pair[0]["id"]) == id:
				gain = int(pair[1])
		var g := UI.label(("+%d" % gain) if gain > 0 else "-", "Small")
		g.add_theme_color_override("font_color", (UI.C_MP_A if bool(pv["mana"]) else UI.C_GOOD) if gain > 0 else UI.C_FAINT)
		top.add_child(g)
	var bars := UI.hbox(3)
	words.add_child(bars)
	var bw := 70.0 if not _ph else 40.0
	var hb := UI.bar("hp", bw)
	hb.call("set_value", float(hp), float(u["max_hp"]), false)
	bars.add_child(hb)
	var mb := UI.bar("mp", bw * 0.7)
	mb.call("set_value", float(mp), maxf(1.0, float(u["max_mp"])), false)
	bars.add_child(mb)
	_hairline(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _use_on(member_id: String) -> void:
	if _item_sel == "":
		Sfx.play("shop_deny")
		_items_detail(String(W["item_choose_first"]), UI.C_BAD)
		return
	var r := Supplies.row(_item_sel)
	var got := Supplies.use_on(_item_sel, member_id)
	if String(got["why"]) != "":
		Sfx.play("shop_deny")
		_items_detail(String(got["why"]), UI.C_BAD)
		return
	Sfx.play("shop_buy")
	var targets: Array = got["targets"]
	var what := String(W["mp"] if bool(got["mana"]) else W["hp"])
	var said := ""
	if targets.size() == 1:
		said = String(W["item_used"]) % [String(r["name"]), String(targets[0][0]["name"]), int(targets[0][1]), what]
	else:
		var sum := 0
		for pair: Array in targets:
			sum += int(pair[1])
		said = String(W["item_used_all"]) % [String(r["name"]), sum, what]
	var keep := "member_" + member_id
	_fill_items()
	_items_detail(said, UI.C_GOOD)
	var again := _use_box.get_node_or_null(NodePath(keep))
	if again is Control:
		(again as Control).grab_focus.call_deferred()


## Test (journal.gd --p11tour): choose a Healing Herb and use it on the knight, as a player would.
func tour_use() -> void:
	if Supplies.count("herb") <= 0:
		Supplies.give("herb")
	var lost := Save.hub_get("wound:hp:knight")
	var n := Supplies.count("herb")
	var whole := Supplies.preview_use("tonic", "knight")
	_pick_item("herb")
	_use_on("knight")
	print("[knight] items test: herb used on the knight, health lost %d -> %d, herbs %d -> %d, %s; a tonic on a knight with full mana says \"%s\"" % [
		lost, Save.hub_get("wound:hp:knight"), n, Supplies.count("herb"), _d_next.text, String(whole["why"])])


# ------------------------------------------------------------------ the Stats page: spending
func _spend(id: String) -> void:
	var why := Rpg.why_not(id)
	if why != "":
		Sfx.play("shop_deny")
		_stat_detail(id)
		_say(why, UI.C_BAD)
		return
	Rpg.spend(id)
	Sfx.play("ui_start")
	# in the middle of a level the knight changes at once
	if is_instance_valid(G.run) and is_instance_valid(G.run.get("player")):
		G.run.get("player").call("apply_rpg")
	refresh()
	_stat_detail(id)
	var r := Rpg.row(id)
	_say("%s %d: %s." % [String(r["name"]), Rpg.stat(id), Rpg.total_text(id)], UI.C_GOLD)


func _ask_reset() -> void:
	if Rpg.spent() <= 0:
		Sfx.play("shop_deny")
		_show_page("stats")
		_say("No points are placed yet, so there is nothing to take back.", UI.C_BAD)
		return
	ask("Take all %d points back, to place them again? It costs nothing." % Rpg.spent(), "Take back", "Leave them", func() -> void:
		Rpg.reset()
		Sfx.play("ui_start")
		refresh()
		_say("All points are back in your hand.", UI.C_GOLD), false)


## The line of words in the detail panel (the stat that was tapped, or why not).
func _say(text: String, colour: Color = UI.C_PARCH) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", colour)


func refresh() -> void:
	if _points == null:
		return
	var lvl := Rpg.level()
	if is_instance_valid(_name_head):
		_name_head.text = Looks.hero_name()
	var hero := Heroes.by_id("knight")
	_sub.text = ("%s  ·  Level %d" % [String(hero.get("title", "")), lvl]) if not _ph else ("Lv %d" % lvl)
	if is_instance_valid(_xp_text):
		_xp_text.text = "Highest level" if Rpg.at_max() else "%d / %d to level %d" % [Rpg.xp(), Rpg.need(lvl), lvl + 1]
	if is_instance_valid(_xp_bar):
		if Rpg.at_max():
			_xp_bar.call("set_value", 1.0, 1.0, false)
		else:
			_xp_bar.call("set_value", float(Rpg.xp()), float(Rpg.need(lvl)), false)
	var pts := Rpg.points()
	_points.text = ("%d point%s to spend" % [pts, "" if pts == 1 else "s"]) if pts > 0 else "No points to spend"
	_points.add_theme_color_override("font_color", UI.C_GOLD if pts > 0 else UI.C_DIM)
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		(row["value"] as Label).text = str(Rpg.stat(id))
		(row["total"] as Label).text = Rpg.total_text(id)
		_paint_row(id)
	if not _battle_vals.is_empty():
		var k := Battles.knight()
		(_battle_vals["hp"] as Label).text = str(int(k["max_hp"]))
		(_battle_vals["mp"] as Label).text = str(int(k["max_mp"]))
		(_battle_vals["atk"] as Label).text = str(roundi(float(k["atk"])))
		(_battle_vals["def"] as Label).text = str(roundi(float(k["def"])))
		(_battle_vals["speed"] as Label).text = str(roundi(float(k["speed"])))
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if page == "stats":
		var shown := false
		for id: String in _rows:
			if f == _rows[id]["button"]:
				_stat_detail(id)
				shown = true
		if not shown and _d_title.text == "":
			_stat_detail(String(Rpg.STATS[0]["id"]))
