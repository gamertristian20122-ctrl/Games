extends "res://scripts/ui/screen.gd"
## Your knight: his name, the colour of his armour and which sword he carries (scripts/data/looks.gd).
## Opened from Settings and from the mirror in your room. Every change is saved at once.
## HD GUI: the veil and a glass panel; on the left the knight as he will look (3 UI px to an art
## pixel on a PC, on a warm glow, changing live), on the right the rows: the name in a text well,
## the armour colour as chips, the sword look as "< name >".

const SettingRow = preload("res://scripts/ui/setting_row.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const VEIL_GAIN := 2.4
## The steel of the knight's armour, multiplied by each colour's tint for its chip.
const STEEL := Color(0.62, 0.74, 0.86)

var _stage: Control
var _body: AnimatedSprite2D
var _weapon: Sprite2D
var _name: LineEdit
var _ph := false


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var outer: Control
	if _ph:
		outer = UI.safe_margin(self, 4)
	else:
		outer = CenterContainer.new()
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var panel := UI.panel("panel")
	if not _ph:
		panel.custom_minimum_size = Vector2(480, 0)
	outer.add_child(panel)
	var col := UI.vbox(0)
	panel.add_child(col)
	col.add_child(_header())
	var cols := UI.hbox(14 if not _ph else 6)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(140, 150) if not _ph else Vector2(84, 100)
	_stage.draw.connect(_draw_stage)
	_stage.resized.connect(_show)
	cols.add_child(_stage)

	var list := UI.vbox(2 if not _ph else 1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(list)
	var name_row := UI.hbox(8 if not _ph else 4)
	name_row.custom_minimum_size.y = 26 if not _ph else 22
	list.add_child(name_row)
	name_row.add_child(UI.spacer(4 if not _ph else 2, 0))
	var lab := UI.label("Name")
	lab.custom_minimum_size.x = 44 if not _ph else 34
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_vertical = Control.SIZE_FILL
	name_row.add_child(lab)
	_name = LineEdit.new()
	_name.text = Looks.hero_name()
	_name.max_length = Looks.NAME_MAX
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.custom_minimum_size.y = 22 if not _ph else 20
	_name.placeholder_text = Looks.DEFAULT_NAME
	_name.text_changed.connect(func(t: String) -> void: Save.set_setting("hero_name", t.strip_edges()))
	_name.text_submitted.connect(func(_t: String) -> void: _name.release_focus())
	name_row.add_child(_name)
	name_row.add_child(UI.spacer(6 if not _ph else 3, 0))

	# (v0.39.0, the owner: swords and armour are UPGRADES now, earned at the smith; only the name is chosen here)
	list.add_child(UI.spacer(0, 6 if not _ph else 2))
	var hint := UI.label("The people of the town will use your name. Better swords and armour (they change how you look) are sold by the smith.", "Small")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 60
	hint.add_theme_color_override("font_color", UI.C_DIM)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10 if not _ph else 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(hint)
	list.add_child(pad)
	default_focus = _name
	if not _ph:
		_add_back_button()
	_show.call_deferred()
	UI.pop_in(panel)


func _header() -> Control:
	var head := UI.vbox(0)
	var line := Control.new()
	line.custom_minimum_size.y = 22 if not _ph else 20
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	var t := UI.label("Your knight", "Head")
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(t)
	if _ph:
		var back := UI.button("Back", on_back, "", "")
		back.name = "Back"
		back.focus_mode = Control.FOCUS_NONE
		back.custom_minimum_size = Vector2(40, 20)
		line.add_child(back)
	var rule := UI.rule(200, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	head.add_child(rule)
	return head


## A Back button for the mouse at the bottom left (keys and pads have Esc / B).
func _add_back_button() -> void:
	add_child(UI.mouse_back(on_back))


func help_pairs() -> Array:
	return [["target", "Change"], ["back", "Back"]]


func _choice(title: String, rows: Array, key: String, kind: String, chips: Array = []) -> Control:
	var row := SettingRow.new()
	var names: Array = []
	for r: Dictionary in rows:
		names.append(String(r["name"]))
	row.options = names
	row.swatches = chips
	row.setup(kind, title, Looks.index_of(rows, String(Save.setting(key))))
	row.changed.connect(func(v: Variant) -> void:
		Save.set_setting(key, String(rows[int(v)]["id"]))
		Sfx.play("ui_click")
		_show())
	return row


## The warm glow and the oval shadow he stands on.
func _draw_stage() -> void:
	var c := Vector2(roundf(_stage.size.x * 0.5), roundf(_stage.size.y - 12.0))
	var r := minf(_stage.size.x * 0.5, 70.0)
	for i in 9:
		_stage.draw_circle(c + Vector2(0, -r * 0.55), r - i * r / 9.0, Color(1.0, 0.72, 0.42, 0.03))
	_stage.draw_set_transform(c + Vector2(0, 1), 0.0, Vector2(1.0, 0.28))
	_stage.draw_circle(Vector2.ZERO, 26.0 if not _ph else 18.0, Color(0, 0, 0, 0.4))
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The knight as he will look: 3 UI px to an art pixel (2 on a phone), on the glow.
func _show() -> void:
	if not is_instance_valid(_stage) or _stage.size.x < 4.0:
		return
	for c in _stage.get_children():
		c.queue_free()
	var hero := Heroes.by_id("knight")
	var holder := Node2D.new()
	var k := 3.0 if not _ph else 2.0
	holder.scale = Vector2(k, k)
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.position = Vector2(roundf(_stage.size.x / 2.0), roundf(_stage.size.y - 12.0))
	_stage.add_child(holder)
	_weapon = HeroLook.make_weapon(hero)
	holder.add_child(_weapon)
	_body = Art.sprite(String(hero["sprite"]))
	_body.modulate = hero.get("tint", Color.WHITE)
	holder.add_child(_body)
	HeroLook.rest(_weapon, 1.0)
	HeroLook.layer(_weapon, _body, true)
	_stage.queue_redraw()


## A right click goes back (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_back()


func on_back() -> void:
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
