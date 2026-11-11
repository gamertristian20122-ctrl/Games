extends "res://scripts/ui/screen.gd"
## Pause menu: Resume, Settings, Give up (asks first), plus what you carry and how the run
## is going. The game underneath is frozen by main.gd (get_tree().paused).
## Tap or move onto an item to read what it does.

const Heroes = preload("res://scripts/data/heroes.gd")
const Items = preload("res://scripts/data/items.gd")
const Icon = preload("res://scripts/ui/icon.gd")

var run: Node                    ## set by main.gd
var _detail: Label
var _detail_name: Label


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var cols := UI.hbox(6)
	safe.add_child(cols)

	# left: the three buttons
	var left := UI.vbox(4)
	left.custom_minimum_size.x = 92
	cols.add_child(left)
	var head := UI.label("Paused", "Head")
	head.custom_minimum_size.y = 20
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(head)
	var resume := UI.button("Resume", func() -> void: send("resume"), "Big")
	resume.custom_minimum_size.y = 26
	left.add_child(resume)
	var settings := UI.button("Settings", func() -> void: send("settings"))
	settings.custom_minimum_size.y = 22
	left.add_child(settings)
	left.add_child(UI.spacer(0, 0, true))
	var give_up := UI.button("Give up", _ask_give_up)
	give_up.custom_minimum_size.y = 22
	left.add_child(give_up)
	default_focus = resume

	# right: run stats and items
	var panel := UI.panel("panel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var col := UI.vbox(3)
	panel.add_child(col)
	var player: Variant = run.get("player") if is_instance_valid(run) else null
	var hero := Heroes.by_id(String(run.get("hero_id"))) if is_instance_valid(run) else Heroes.LIST[0]
	var floor_no := int(run.get("floor_index")) + 1 if is_instance_valid(run) else 1
	var where := UI.label("%s  -  Floor %d of %d" % [hero["name"], floor_no, maxi(int(run.get("floor_count")), floor_no)], "Gold")
	col.add_child(where)
	var place := UI.label(String(run.get("floor_name")), "Dim")
	place.clip_text = true
	col.add_child(place)
	var stats := UI.hbox(10)
	col.add_child(stats)
	var coins := int(player.get("coins")) if is_instance_valid(player) else 0
	for pair: Array in [["Time", UI.time_text(float(run.get("time_s")))], ["Kills", str(int(run.get("kills")))], ["Coins", str(coins)]]:
		var cell := UI.hbox(3)
		cell.add_child(UI.label(pair[0], "Small"))
		cell.add_child(UI.label(pair[1]))
		stats.add_child(cell)
	col.add_child(HSeparator.new())

	var ids: Array = []
	if is_instance_valid(player) and player.get("items") is Array:
		ids = player.get("items")
	col.add_child(UI.label("Items (%d)" % ids.size(), "Small"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id: Variant in ids:
		grid.add_child(_item_row(String(id)))
	if ids.is_empty():
		var none := UI.label("Nothing yet.", "Dim")
		grid.add_child(none)

	# what the highlighted item does
	var foot := UI.panel("well")
	foot.custom_minimum_size.y = 26
	col.add_child(foot)
	var foot_col := UI.vbox(0)
	foot.add_child(foot_col)
	_detail_name = UI.label("", "Gold")
	_detail_name.clip_text = true
	foot_col.add_child(_detail_name)
	_detail = UI.label("", "", 10.0)
	_detail.max_lines_visible = 2
	foot_col.add_child(_detail)
	if ids.is_empty():
		_detail_name.text = ""
		_detail.text = "Items you pick up are listed here."
		_detail.add_theme_color_override("font_color", UI.C_DIM)
	else:
		_show_item(String(ids[ids.size() - 1]))
	UI.pop_in(cols)


func _item_row(id: String) -> Control:
	var info := Items.info(id)
	var cursed := bool(info.get("cursed", false))
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.custom_minimum_size = Vector2(0, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = String(info.get("name", id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_constant_override("h_separation", 0)
	if cursed:
		b.add_theme_color_override("font_color", UI.C_CURSE)
		b.add_theme_color_override("font_focus_color", UI.C_CURSE)
		b.add_theme_color_override("font_hover_color", UI.C_CURSE)
	# the picture sits in a fixed 32 px slot on the left so the names line up
	var ic := Icon.new()
	ic.setup(String(info.get("icon", "skull")), Vector2.ZERO, 12.0)
	ic.position = Vector2(3 + roundf((32 - ic.size.x) / 2.0), 2)
	b.add_child(ic)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBox = UI.theme().get_stylebox(state, "Flat").duplicate()
		sb.content_margin_left = 38
		sb.content_margin_right = 3
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		b.add_theme_stylebox_override(state, sb)
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
		text += "  Curse: " + String(info.get("curse", ""))
	_detail.text = text


func _ask_give_up() -> void:
	ask("Give up this run?", "Give up", "Keep going", func() -> void: send("give_up"))


## Back / Esc / Start while paused means "carry on playing".
func on_back() -> void:
	if close_dialog():
		return
	Sfx.play("ui_back")
	send("resume")
