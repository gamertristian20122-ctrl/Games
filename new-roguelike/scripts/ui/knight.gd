extends "res://scripts/ui/screen.gd"
## The Knight screen: his level, his XP, and the four stats he puts points into
## (scripts/data/rpg.gd holds every rule and number). Opened with the "Lv" touch button, C / Tab,
## gamepad Y, or the Knight button of the pause menu. Tap a stat to put one point into it.
## A stat that cannot take a point still answers: it says why (never a dead button).
## Gear, skills and the party will get their own pages here in later steps.

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")

var _stage: Control
var _level: Label
var _xp_text: Label
var _xp_bar: Control
var _points: Label
var _hint: Label
var _rows := {}                  ## stat id -> {"button", "value", "total"}
var _reset: Button


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	col.add_child(top_bar(Looks.hero_name()))
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
