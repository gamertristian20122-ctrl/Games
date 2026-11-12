extends "res://scripts/ui/screen.gd"
## Your knight: his name, the colour of his armour and which sword he carries (scripts/data/looks.gd).
## Opened from Settings and from the mirror in your room. Every change is saved at once.

const SettingRow = preload("res://scripts/ui/setting_row.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")

var _stage: Control
var _body: AnimatedSprite2D
var _weapon: Sprite2D
var _name: LineEdit


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	col.add_child(top_bar("Your knight"))
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centre)
	var cols := UI.hbox(8)
	centre.add_child(cols)

	var well := UI.panel("well")
	well.custom_minimum_size = Vector2(76, 96)
	cols.add_child(well)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_stage)

	var list := UI.vbox(3)
	list.custom_minimum_size.x = 196
	cols.add_child(list)
	var name_row := UI.hbox(4)
	list.add_child(name_row)
	var lab := UI.label("Name")
	lab.custom_minimum_size.x = 40
	name_row.add_child(lab)
	_name = LineEdit.new()
	_name.text = Looks.hero_name()
	_name.max_length = Looks.NAME_MAX
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.custom_minimum_size.y = 20
	_name.placeholder_text = Looks.DEFAULT_NAME
	_name.text_changed.connect(func(t: String) -> void: Save.set_setting("hero_name", t.strip_edges()))
	_name.text_submitted.connect(func(_t: String) -> void: _name.release_focus())
	name_row.add_child(_name)

	var armour := _choice("Armour", Looks.ARMOUR, "armour")
	list.add_child(armour)
	list.add_child(_choice("Sword", Looks.SWORDS, "sword_look"))
	var hint := UI.label("Tap a row to change it. The people of the camp will use your name.", "Small", 190.0)
	list.add_child(hint)
	default_focus = armour
	_show.call_deferred()
	UI.pop_in(cols)


func _choice(title: String, rows: Array, key: String) -> Control:
	var row := SettingRow.new()
	var names: Array = []
	for r: Dictionary in rows:
		names.append(String(r["name"]))
	row.options = names
	row.setup("choice", title, Looks.index_of(rows, String(Save.setting(key))))
	row.changed.connect(func(v: Variant) -> void:
		Save.set_setting(key, String(rows[int(v)]["id"]))
		Sfx.play("ui_click")
		_show())
	return row


## The knight as he will look: twice his size, standing in the box on the left.
func _show() -> void:
	for c in _stage.get_children():
		c.queue_free()
	var hero := Heroes.by_id("knight")
	var holder := Node2D.new()
	holder.scale = Vector2(2, 2)
	holder.position = Vector2(roundf(_stage.size.x / 2.0), roundf(_stage.size.y - 14.0))
	_stage.add_child(holder)
	_weapon = HeroLook.make_weapon(hero)
	holder.add_child(_weapon)
	_body = Art.sprite(String(hero["sprite"]))
	_body.modulate = hero.get("tint", Color.WHITE)
	holder.add_child(_body)
	HeroLook.rest(_weapon, 1.0)
	HeroLook.layer(_weapon, _body, true)


func on_back() -> void:
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
