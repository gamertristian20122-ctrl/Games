extends "res://scripts/ui/screen.gd"
## The Knight screen: his level, his XP, and the four stats he puts points into
## (scripts/data/rpg.gd holds every rule and number). Opened with the "Lv" touch button, C / Tab,
## gamepad Y, or the Knight button of the pause menu. Tap a stat to put one point into it.
## A stat that cannot take a point still answers: it says why (never a dead button).
## Two pages, switched with the Stats / Gear buttons in the top bar:
##   Stats  the four stats and the points
##   Gear   what he owns and wears: weapons (scripts/data/weapons.gd) and helmets, armour, rings
##          (scripts/data/gear.gd). Tap a piece to wear it, tap it again to take it off.
##   Skills the sword moves and spells he has learned (scripts/data/skills.gd) and which two
##          sit on the skill buttons. Tap a skill, then "On button 1" or "On button 2".
## The party will get its own page here in a later step.

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Skills = preload("res://scripts/data/skills.gd")

var _stage: Control
var _level: Label
var _xp_text: Label
var _xp_bar: Control
var _points: Label
var _hint: Label
var _rows := {}                  ## stat id -> {"button", "value", "total"}
var _reset: Button
var page := "stats"              ## "stats" or "gear" (main.gd may set it before the screen builds)
var _tabs := {}                  ## page -> its button in the top bar
var _pages := {}                 ## page -> its column
var _gear_list: VBoxContainer
var _gear_name: Label
var _gear_text: Label
var _skill_list: VBoxContainer
var _skill_name: Label
var _skill_text: Label
var _skill_sel := ""             ## the skill tapped last


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	var bar := top_bar(Looks.hero_name())
	col.add_child(bar)
	# the two pages, as buttons on the right of the top bar
	var tabs := UI.hbox(2)
	tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tabs.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.add_child(tabs)
	for t: Array in [["stats", "Stats"], ["gear", "Gear"], ["skills", "Skills"]]:
		var tb := UI.button(String(t[1]), _show_page.bind(String(t[0])))
		tb.name = "tab_" + String(t[0])
		tb.custom_minimum_size = Vector2(38, 19)
		tabs.add_child(tb)
		_tabs[t[0]] = tb
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centre)
	var cols := UI.hbox(8)
	centre.add_child(cols)

	# left: the knight, his level and the XP bar
	var left := UI.vbox(2)
	left.custom_minimum_size.x = 84
	cols.add_child(left)
	var well := UI.panel("well")
	well.custom_minimum_size = Vector2(84, 70)
	left.add_child(well)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_stage)
	_level = UI.label("", "Gold")
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_level)
	_xp_bar = Control.new()
	_xp_bar.custom_minimum_size = Vector2(84, 7)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.draw.connect(_draw_xp)
	left.add_child(_xp_bar)
	_xp_text = UI.label("", "Small")
	_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_xp_text)
	if not is_instance_valid(G.run):
		# only in a camp: take every point back and place them again (free)
		_reset = UI.button("Take points back", _ask_reset)
		_reset.custom_minimum_size.y = 18
		left.add_child(_reset)

	# right: the points and the four stats
	var right := UI.vbox(2)
	right.custom_minimum_size.x = 214
	cols.add_child(right)
	_pages["stats"] = right
	_points = UI.label("", "Gold")
	right.add_child(_points)
	for r: Dictionary in Rpg.STATS:
		var b := _stat_row(r)
		right.add_child(b)
		if default_focus == null:
			default_focus = b
	var foot := UI.panel("well")
	right.add_child(foot)
	_hint = UI.label("", "Small", 200.0)
	_hint.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_body)
	_hint.max_lines_visible = 2
	foot.add_child(_hint)
	_say("Tap a stat to put a point into it. Monsters give XP; each level gives %d points." % Rpg.POINTS_PER_LEVEL)
	cols.add_child(_build_gear_page())
	cols.add_child(_build_skills_page())
	_show_page(page)
	refresh()
	_show.call_deferred()
	UI.pop_in(cols)


## One stat: its name, the points in it, what they add up to, and a plus sign.
func _stat_row(r: Dictionary) -> Button:
	var id := String(r["id"])
	var b := Button.new()
	b.name = "stat_" + id
	b.custom_minimum_size = Vector2(0, 21)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	var row := UI.hbox(4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = r["color"]
	swatch.custom_minimum_size = Vector2(4, 9)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var name_label := UI.label(String(r["name"]))
	name_label.custom_minimum_size.x = 50
	row.add_child(name_label)
	var value := UI.label("0", "Gold")
	value.custom_minimum_size.x = 14
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var total := UI.label("", "Small")
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.clip_text = true
	row.add_child(total)
	var plus := UI.label("+", "Gold")
	row.add_child(plus)
	_rows[id] = {"button": b, "value": value, "total": total, "plus": plus}
	b.focus_entered.connect(func() -> void: _say("%s: each point = %s." % [String(r["name"]), String(r["each"])]))
	b.pressed.connect(_spend.bind(id))
	return b


# ------------------------------------------------------------------ the Gear page
func _build_gear_page() -> Control:
	var right := UI.vbox(2)
	right.custom_minimum_size = Vector2(214, 126)
	_pages["gear"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_gear_list = UI.vbox(1)
	_gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_gear_list)
	var foot := UI.panel("well")
	right.add_child(foot)
	var foot_col := UI.vbox(0)
	foot.add_child(foot_col)
	_gear_name = UI.label("", "Gold")
	_gear_name.clip_text = true
	foot_col.add_child(_gear_name)
	_gear_text = UI.label("", "Small", 200.0)
	_gear_text.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_body)
	_gear_text.max_lines_visible = 2
	foot_col.add_child(_gear_text)
	_gear_say("Gear", "Tap a piece to wear it. Tap it again to take it off.", UI.C_GOLD)
	return right


func _show_page(which: String) -> void:
	page = which if _pages.has(which) else "stats"
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page
		(_tabs[key] as Button).add_theme_color_override("font_color", UI.C_GOLD if key == page else UI.C_DIM)
	if page == "gear":
		_fill_gear()
	elif page == "skills":
		_fill_skills()


func _gear_say(title: String, text: String, colour: Color = UI.C_GOLD) -> void:
	_gear_name.text = title
	_gear_name.add_theme_color_override("font_color", colour)
	_gear_text.text = text


## Rebuilds the list: the weapons, then each slot with the pieces he owns.
func _fill_gear() -> void:
	var keep := ""
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and _gear_list.is_ancestor_of(f):
		keep = String(f.name)
	for c in _gear_list.get_children():
		_gear_list.remove_child(c)
		c.queue_free()
	_gear_list.add_child(_gear_head("Weapon"))
	var carried := String(Weapons.current()["id"])
	for w: Dictionary in Weapons.LIST:
		if Weapons.owned(String(w["id"])):
			_gear_list.add_child(_weapon_row(w, String(w["id"]) == carried))
	for s: Dictionary in Gear.SLOTS:
		var slot := String(s["id"])
		_gear_list.add_child(_gear_head(String(s["name"])))
		var rows := Gear.owned_rows(slot)
		if rows.is_empty():
			var none := UI.label("  None yet. Monsters, chests, bosses and smiths have them.", "Small", 200.0)
			none.add_theme_color_override("font_color", UI.C_FAINT)
			_gear_list.add_child(none)
		for r: Dictionary in rows:
			_gear_list.add_child(_gear_row(r))
	if keep != "":
		var again := _gear_list.get_node_or_null(NodePath(keep))
		if again is Control:
			(again as Control).grab_focus.call_deferred()


func _gear_head(text: String) -> Control:
	var l := UI.label(text, "Small")
	l.add_theme_color_override("font_color", UI.C_DIM)
	return l


## One line: picture, name in its rarity's colour, and WORN when it is on.
func _line(row_name: String, icon_id: String, title: String, colour: Color, on: bool, tag: String, tag_colour: Color = UI.C_GOLD) -> Button:
	var b := Button.new()
	b.name = row_name
	b.theme_type_variation = "Flat"
	b.custom_minimum_size = Vector2(0, 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 3
	row.offset_right = -5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(18, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var ic := Icon.new()
	ic.setup(icon_id, Vector2.ZERO, 16.0)
	slot.add_child(ic)
	var name_label := UI.label(title)
	name_label.add_theme_color_override("font_color", colour)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var worn := UI.label(tag if on else "", "Gold")
	worn.add_theme_color_override("font_color", tag_colour)
	row.add_child(worn)
	return b


func _gear_row(r: Dictionary) -> Button:
	var id := String(r["id"])
	var b := _line("gear_" + id, String(r["icon"]), String(r["name"]), Gear.color(r), Gear.is_worn(id), "WORN")
	var about := func() -> void: _gear_say("%s  (%s %s)" % [String(r["name"]), Gear.rarity_name(r), Gear.slot_name(String(r["slot"])).to_lower()], Gear.text_cap(r) + ".", Gear.color(r))
	b.focus_entered.connect(about)
	b.pressed.connect(func() -> void:
		if Gear.is_worn(id):
			Gear.take_off(String(r["slot"]))
			Sfx.play("ui_back")
		else:
			Gear.wear(id)
			Sfx.play("ui_start")
		_gear_changed()
		about.call())
	return b


func _weapon_row(w: Dictionary, carried: bool) -> Button:
	var id := String(w["id"])
	var icon_id := String(w.get("sprite", Looks.sword().get("weapon", "pc_weapon_castle_13")))      # the sword wears the look chosen at the mirror
	var b := _line("weapon_" + id, icon_id, String(w["name"]), UI.C_BONE, carried, "CARRIED")
	var numbers := "Damage x%.2f, speed x%.2f." % [float(w.get("damage", 1.0)), float(w.get("rate", 1.0))]
	var about := func() -> void: _gear_say(String(w["name"]), "%s %s" % [String(w["text"]), numbers], UI.C_BONE)
	b.focus_entered.connect(about)
	b.pressed.connect(func() -> void:
		if carried:
			about.call()
		elif is_instance_valid(G.run):
			# the hero's whole swing is built from his weapon when a level starts
			Sfx.play("ui_back")
			_gear_say(String(w["name"]), "Weapons can only be changed in a camp, not inside a level.", UI.C_ORANGE)
		else:
			Save.set_setting("weapon", id)
			Sfx.play("ui_start")
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
	var right := UI.vbox(2)
	right.custom_minimum_size = Vector2(214, 126)
	_pages["skills"] = right
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	_skill_list = UI.vbox(1)
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skill_list)
	var foot := UI.panel("well")
	right.add_child(foot)
	var foot_col := UI.vbox(0)
	foot.add_child(foot_col)
	_skill_name = UI.label("", "Gold")
	_skill_name.clip_text = true
	foot_col.add_child(_skill_name)
	_skill_text = UI.label("", "Small", 200.0)
	_skill_text.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_body)
	_skill_text.max_lines_visible = 2
	foot_col.add_child(_skill_text)
	var pick := UI.hbox(3)
	right.add_child(pick)
	for slot in Skills.SLOTS:
		var b := UI.button("On button %d" % (slot + 1), _put_skill.bind(slot), "", "")
		b.name = "put_%d" % slot
		b.custom_minimum_size = Vector2(0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_child(b)
	_skill_say("Skills", "Learned as you level up. Tap one, then choose its button. Skills cost mana (the blue bar).", UI.C_GOLD)
	return right


func _skill_say(title: String, text: String, colour: Color = UI.C_GOLD) -> void:
	_skill_name.text = title
	_skill_name.add_theme_color_override("font_color", colour)
	_skill_text.text = text


func _fill_skills() -> void:
	for c in _skill_list.get_children():
		_skill_list.remove_child(c)
		c.queue_free()
	for r: Dictionary in Skills.LIST:
		var id := String(r["id"])
		var known := Skills.known(id)
		var slot := Skills.button_of(id)
		var tag := "BUTTON %d" % (slot + 1) if slot >= 0 else ("" if known else "Level %d" % int(r["level"]))
		var b := _line("skill_" + id, String(r["icon"]), String(r["name"]), UI.C_BONE if known else UI.C_FAINT, tag != "", tag, UI.C_GOLD if slot >= 0 else UI.C_FAINT)
		if not known:
			b.modulate = Color(1, 1, 1, 0.6)
		b.focus_entered.connect(_about_skill.bind(id))
		b.pressed.connect(func() -> void:
			_skill_sel = id
			Sfx.play("ui_click")
			_about_skill(id))
		_skill_list.add_child(b)


func _about_skill(id: String) -> void:
	var r := Skills.row(id)
	var head := "%s  (%s, %d mana, rests %s s)" % [String(r["name"]), String(r["kind"]), int(r["mana"]), str(float(r["cd"])).trim_suffix(".0")]
	if Skills.known(id):
		_skill_say(head, String(r["text"]), UI.C_GOLD)
	else:
		_skill_say(head, "Learned at level %d. %s" % [int(r["level"]), String(r["text"])], UI.C_DIM)


## "On button 1 / 2": puts the tapped skill there. It always answers: when it cannot, it says why.
func _put_skill(slot: int) -> void:
	if _skill_sel == "":
		Sfx.play("ui_back")
		_skill_say("Tap a skill first", "Then choose the button it goes on.", UI.C_ORANGE)
		return
	var r := Skills.row(_skill_sel)
	if not Skills.known(_skill_sel):
		Sfx.play("ui_back")
		_skill_say(String(r["name"]), "Not learned yet: it comes at level %d. You are level %d." % [int(r["level"]), Rpg.level()], UI.C_ORANGE)
		return
	Skills.assign(_skill_sel, slot)
	Sfx.play("ui_start")
	_fill_skills()
	_skill_say(String(r["name"]), "It is on skill button %d now." % (slot + 1), UI.C_GOLD)


# ------------------------------------------------------------------ the Stats page
func _spend(id: String) -> void:
	var why := Rpg.why_not(id)
	if why != "":
		Sfx.play("ui_back")
		_say(why, UI.C_ORANGE)
		return
	Rpg.spend(id)
	Sfx.play("ui_start")
	var r := Rpg.row(id)
	_say("%s %d: %s." % [String(r["name"]), Rpg.stat(id), Rpg.total_text(id)], UI.C_GOLD)
	# in the middle of a level the knight changes at once
	if is_instance_valid(G.run) and is_instance_valid(G.run.get("player")):
		G.run.get("player").call("apply_rpg")
	refresh()


func _ask_reset() -> void:
	if Rpg.spent() <= 0:
		Sfx.play("ui_back")
		_say("No points are placed yet, so there is nothing to take back.", UI.C_ORANGE)
		return
	ask("Take all %d points back, to place them again? It costs nothing." % Rpg.spent(), "Take back", "Leave them", func() -> void:
		Rpg.reset()
		Sfx.play("ui_start")
		_say("All points are back in your hand.", UI.C_GOLD)
		refresh(), false)


func _say(text: String, colour: Color = UI.C_DIM) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", colour)


func refresh() -> void:
	if _points == null:
		return
	var lvl := Rpg.level()
	_level.text = "Level %d" % lvl
	_xp_text.text = "Highest level" if Rpg.at_max() else "%d / %d XP" % [Rpg.xp(), Rpg.need(lvl)]
	_xp_bar.queue_redraw()
	var pts := Rpg.points()
	_points.text = "Points to spend: %d" % pts if pts > 0 else "No points to spend"
	_points.add_theme_color_override("font_color", UI.C_GOLD if pts > 0 else UI.C_DIM)
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		(row["value"] as Label).text = str(Rpg.stat(id))
		(row["total"] as Label).text = Rpg.total_text(id)
		# the plus sign is bright only while a point can go in; the row itself always answers
		(row["plus"] as Label).modulate.a = 1.0 if Rpg.why_not(id) == "" else 0.25


func _draw_xp() -> void:
	var w := _xp_bar.size.x
	var h := _xp_bar.size.y
	_xp_bar.draw_rect(Rect2(0, 0, w, h), UI.C_INK)
	var fill := Rpg.fill()
	if fill > 0.0:
		_xp_bar.draw_rect(Rect2(1, 1, maxf(roundf((w - 2.0) * fill), 1.0), h - 2.0), Color("5aa7d9"))
	_xp_bar.draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), Color(UI.C_BONE, 0.6), false, 1.0)


## The knight as he looks now: twice his size, standing in the box on the left.
func _show() -> void:
	for c in _stage.get_children():
		c.queue_free()
	var hero := Heroes.by_id("knight")
	var holder := Node2D.new()
	holder.scale = Vector2(2, 2)
	holder.position = Vector2(roundf(_stage.size.x / 2.0), roundf(_stage.size.y - 8.0))
	_stage.add_child(holder)
	var weapon := HeroLook.make_weapon(hero)
	holder.add_child(weapon)
	var body := Art.sprite(String(hero["sprite"]))
	body.modulate = hero.get("tint", Color.WHITE)
	holder.add_child(body)
	HeroLook.rest(weapon, 1.0)
	HeroLook.layer(weapon, body, true)
