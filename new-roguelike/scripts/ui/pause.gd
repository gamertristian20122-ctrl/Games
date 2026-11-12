extends "res://scripts/ui/screen.gd"
## Pause menu: Resume, Settings, Give up (asks first), plus what you carry and how the run
## is going. The game underneath is frozen by main.gd (get_tree().paused).
## Tap or move onto an item to read what it does.

const Heroes = preload("res://scripts/data/heroes.gd")
const Items = preload("res://scripts/data/items.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Rpg = preload("res://scripts/data/rpg.gd")

var run: Node                    ## set by main.gd
var _detail: Label
var _detail_name: Label
var _knight: Button


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var cols := UI.hbox(6)
	safe.add_child(cols)
	var player: Variant = run.get("player") if is_instance_valid(run) else null
	var hero := Heroes.by_id(String(run.get("hero_id"))) if is_instance_valid(run) else Heroes.LIST[0]

	# left: the three buttons, with the hero waiting in between
	var left := UI.vbox(3)
	left.custom_minimum_size.x = 88
	cols.add_child(left)
	var head := UI.label("Paused", "Head")
	head.custom_minimum_size.y = 18
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(head)
	var resume := UI.button("Resume", func() -> void: send("resume"), "Big")
	resume.custom_minimum_size.y = 22
	left.add_child(resume)
	_knight = UI.button(_knight_text(), func() -> void: send("knight"))
	_knight.custom_minimum_size.y = 20
	left.add_child(_knight)
	var settings := UI.button("Settings", func() -> void: send("settings"))
	settings.custom_minimum_size.y = 20
	left.add_child(settings)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(stage)
	var sprite := Art.sprite(String(hero["sprite"]))
	sprite.scale = Vector2(2, 2)
	sprite.modulate = hero.get("tint", Color.WHITE)
	stage.add_child(sprite)
	stage.resized.connect(func() -> void:
		sprite.position = Vector2(roundf(stage.size.x / 2.0), roundf(stage.size.y / 2.0 + Art.size(String(hero["sprite"])).y) - 2.0))
	var in_yard: bool = run != null and run.get("training") == true
	var in_story: bool = in_yard or (run != null and run.get("level") is Dictionary and not (run.get("level") as Dictionary).is_empty())
	if in_story:
		# walk back out with what you carry: only while no fight is on
		var room: Variant = run.get("room")
		var fight: bool = is_instance_valid(room) and room.get("fighting") == true
		var leave := UI.button("Back to camp", (func() -> void: send("leave_run")) if in_yard else _ask_leave)
		leave.custom_minimum_size.y = 20
		leave.disabled = fight and not in_yard
		if fight and not in_yard:
			leave.text = "Camp (not in a fight)"
		left.add_child(leave)
	else:
		var give_up := UI.button("Give up", _ask_give_up)
		give_up.custom_minimum_size.y = 20
		left.add_child(give_up)
	default_focus = resume

	# right: how the run is going, and what you carry
	var panel := UI.panel("panel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var col := UI.vbox(3)
	panel.add_child(col)
	var floor_no := int(run.get("floor_index")) + 1 if is_instance_valid(run) else 1
	var where := UI.label("Floor %d of %d  -  %s" % [floor_no, maxi(int(run.get("floor_count")), floor_no), String(run.get("floor_name"))], "Gold")
	where.clip_text = true
	col.add_child(where)
	var ids: Array = []
	if is_instance_valid(player) and player.get("items") is Array:
		ids = player.get("items")
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 1)
	col.add_child(stats)
	var coins := int(player.get("coins")) if is_instance_valid(player) else 0
	for pair: Array in [["Time", UI.time_text(float(run.get("time_s")))], ["Kills", str(int(run.get("kills")))], ["Coins", str(coins)], ["Items", str(ids.size())]]:
		var cell := UI.hbox(3)
		cell.add_child(UI.label(pair[0], "Small"))
		cell.add_child(UI.label(pair[1]))
		stats.add_child(cell)
	col.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var grid := UI.vbox(1)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id: Variant in ids:
		grid.add_child(_item_row(String(id)))

	# what the highlighted item does
	var foot := UI.panel("well")
	col.add_child(foot)
	var foot_col := UI.vbox(0)
	foot.add_child(foot_col)
	_detail_name = UI.label("", "Gold")
	_detail_name.clip_text = true
	foot_col.add_child(_detail_name)
	_detail = UI.label("", "", 10.0)
	_detail.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_body)
	_detail.max_lines_visible = 2
	foot_col.add_child(_detail)
	if ids.is_empty():
		_detail_name.text = "No items yet"
		_detail_name.add_theme_color_override("font_color", UI.C_DIM)
		_detail.text = "Things you pick up are listed here with what they do."
		_detail.add_theme_color_override("font_color", UI.C_DIM)
	else:
		_show_item(String(ids[ids.size() - 1]))
	UI.pop_in(cols)


## The Knight button says his level, and how many points wait to be spent.
func _knight_text() -> String:
	if Rpg.points() > 0:
		return "Knight  Lv %d  (+%d)" % [Rpg.level(), Rpg.points()]
	return "Knight  Lv %d" % Rpg.level()


func refresh() -> void:
	if is_instance_valid(_knight):
		_knight.text = _knight_text()


## One line of the list: picture, name, and as much of the description as fits.
func _item_row(id: String) -> Control:
	var info := Items.info(id)
	var cursed := bool(info.get("cursed", false))
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.custom_minimum_size = Vector2(0, maxf(18.0, UI.font_body.get_height(UI.size_body) + 4.0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 3
	row.offset_right = -4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# the picture sits in a fixed 18 px slot so the names line up
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(18, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var ic := Icon.new()
	ic.setup(String(info.get("icon", "skull")), Vector2.ZERO, 16.0)
	slot.add_child(ic)
	var name_label := UI.label(String(info.get("name", id)), "Curse" if cursed else "")
	row.add_child(name_label)
	var desc := UI.label(String(info.get("desc", "")), "Small")
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.clip_text = true
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(desc)
	b.focus_entered.connect(_show_item.bind(id))
	b.pressed.connect(_show_item.bind(id))
	return b


func _show_item(id: String) -> void:
	var info := Items.info(id)
	var cursed := bool(info.get("cursed", false))
	_detail_name.text = String(info.get("name", id))
	_detail_name.add_theme_color_override("font_color", UI.C_CURSE if cursed else UI.C_GOLD)
	var text := String(info.get("desc", ""))
	if cursed and String(info.get("curse", "")) != "":
		text += "  Price: " + String(info.get("curse", ""))
	_detail.text = text


func _ask_leave() -> void:
	ask("Walk back to the camp? You keep your items and ALL your coins go into the camp chest (only half if you fall).", "To camp", "Keep going", func() -> void: send("leave_run"), false)


func _ask_give_up() -> void:
	ask("Give up this run?", "Give up", "Keep going", func() -> void: send("give_up"))


## Back / Esc / Start while paused means "carry on playing".
func on_back() -> void:
	if close_dialog():
		return
	Sfx.play("ui_back")
	send("resume")
