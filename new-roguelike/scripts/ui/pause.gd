extends "res://scripts/ui/screen.gd"
## Pause menu. Two kinds:
##   in a walking place (run == null): the veil and one centred glass panel: PAUSED, Resume, Knight,
##     Journal / Map / Items / How to play (each once its screen exists), Settings, Title (asks first).
##   in a turn-based battle (run == null, in_battle): Resume, Settings, Give up the fight (asks first).
##   in an old dungeon run: Resume, Knight, Settings, Back to camp / Give up (asks first), plus what
##     you carry and how the run is going. The game underneath is frozen by main.gd.
## Tap or move onto an item to read what it does. Esc / B / a right click = Resume.

const Heroes = preload("res://scripts/data/heroes.gd")
const Items = preload("res://scripts/data/items.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Rpg = preload("res://scripts/data/rpg.gd")

## The rows a walking pause offers after Knight: [words, the screen's file name in scripts/ui,
## what is sent with "open_screen", the page that screen must have ("" = any)]. A row only shows
## when its screen's file exists (and, for a page, when the screen lists it in its PAGES).
const MORE := [
	["Journal", "journal", "journal", ""],
	["Map", "world_map", "world_map", ""],
	["Items", "knight", ["knight", {"page": "items"}], "items"],
	["How to play", "howto", "howto", ""],
]
## The words of the walking and the battle pause (placeholders the owner may rewrite).
const WORDS := {
	"paused": "Paused", "resume": "Resume", "settings": "Settings", "title": "Title", "stay": "Stay",
	"ask_title": "Back to the title? Your game is saved.",
	"give_up": "Give up the fight",
	"ask_give_up": "Give up this fight? It counts as lost: you wake in a bed and some of your coins are gone.",
	"yes_give_up": "Give up", "no_give_up": "Fight on",
}

var run: Node                    ## set by main.gd
var in_battle := false           ## set by main.gd: the pause over a turn-based battle
var _detail: Label
var _detail_name: Label
var _knight: Button


## main.gd already darkens the world under every menu (its shade); the veil gives some light back.
const VEIL_GAIN := 2.4


func build() -> void:
	veil().call("set_gain", VEIL_GAIN)
	if run == null:
		_build_walking()
		return
	var ph := UI.is_phone()
	var outer: Control
	if ph:
		outer = UI.safe_margin(self, 6)
		add_child(outer)
	else:
		outer = CenterContainer.new()
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(outer)
	var cols := UI.hbox(6 if ph else 12)
	if not ph:
		cols.custom_minimum_size = Vector2(540, 270)
	outer.add_child(cols)
	var player: Variant = run.get("player") if is_instance_valid(run) else null
	var hero := Heroes.by_id(String(run.get("hero_id"))) if is_instance_valid(run) else Heroes.LIST[0]

	# left: the menu, with the hero waiting under it
	var left_panel := UI.panel("panel")
	left_panel.custom_minimum_size.x = 96 if ph else 168
	cols.add_child(left_panel)
	var left := UI.vbox(2 if ph else 3)
	left_panel.add_child(left)
	var head := UI.label("Paused", "Head")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size.y = 14 if ph else 20
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(head)
	var resume := UI.button("Resume", func() -> void: send("resume"))
	resume.custom_minimum_size.y = 20 if ph else UI.row_h + 3.0
	resume.add_theme_color_override("font_color", UI.C_GOLD)
	left.add_child(resume)
	_knight = UI.button(_knight_text(), func() -> void: send("knight"))
	_knight.custom_minimum_size.y = 20 if ph else UI.row_h + 3.0
	left.add_child(_knight)
	var settings := UI.button("Settings", func() -> void: send("settings"))
	settings.custom_minimum_size.y = 20 if ph else UI.row_h + 3.0
	left.add_child(settings)
	var in_yard: bool = run != null and run.get("training") == true
	var in_story: bool = in_yard or (run != null and run.get("level") is Dictionary and not (run.get("level") as Dictionary).is_empty())
	var why_label: Label = null
	if in_story:
		# walk back out with what you carry: only while no fight is on
		var room: Variant = run.get("room")
		var fight: bool = is_instance_valid(room) and room.get("fighting") == true
		var leave := UI.button("Back to camp", (func() -> void: send("leave_run")) if in_yard else _ask_leave)
		leave.custom_minimum_size.y = 20 if ph else UI.row_h + 3.0
		leave.disabled = fight and not in_yard
		if fight and not in_yard:
			leave.text = "Camp (not in a fight)"
		if fight and (run.get("level") as Dictionary).get("encounter", false) == true:
			leave.text = "No way out: win the fight"
		left.add_child(leave)
		if leave.disabled:
			why_label = UI.label("The way out opens when the room is clear.", "Small")
			why_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why_label.custom_minimum_size.x = 60
			why_label.add_theme_color_override("font_color", UI.C_BAD)
			left.add_child(why_label)
	else:
		var give_up := UI.button("Give up", _ask_give_up, "Danger")
		give_up.custom_minimum_size.y = 20 if ph else UI.row_h + 3.0
		left.add_child(give_up)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size.y = 0 if ph else 64
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(stage)
	var sprite := Art.sprite(String(hero["sprite"]))
	sprite.scale = Vector2(2, 2)
	sprite.modulate = hero.get("tint", Color.WHITE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(sprite)
	stage.resized.connect(func() -> void:
		sprite.visible = stage.size.y > 40.0
		sprite.position = Vector2(roundf(stage.size.x / 2.0), roundf(stage.size.y - 6.0)))
	default_focus = resume

	# right: how the run is going, and what you carry
	var panel := UI.panel("card")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var col := UI.vbox(2 if ph else 4)
	panel.add_child(col)
	var floor_no := int(run.get("floor_index")) + 1 if is_instance_valid(run) else 1
	var where := UI.label("Floor %d of %d  ·  %s" % [floor_no, maxi(int(run.get("floor_count")), floor_no), String(run.get("floor_name"))], "Head")
	where.add_theme_color_override("font_color", UI.C_GOLD)
	where.clip_text = true
	col.add_child(where)
	var ids: Array = []
	if is_instance_valid(player) and player.get("items") is Array:
		ids = player.get("items")
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 12 if not ph else 8)
	stats.add_theme_constant_override("v_separation", 1)
	col.add_child(stats)
	var coins := int(player.get("coins")) if is_instance_valid(player) else 0
	for pair: Array in [["Time", UI.time_text(float(run.get("time_s")))], ["Kills", str(int(run.get("kills")))], ["Coins", str(coins)], ["Items", str(ids.size())]]:
		var cell := UI.hbox(4)
		var k := UI.label(pair[0], "Small")
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(k)
		var v := UI.label(pair[1], "Num")
		if pair[0] == "Coins":
			v.add_theme_color_override("font_color", UI.C_GOLD)
		cell.add_child(v)
		stats.add_child(cell)
	var rule := UI.rule(100, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var grid := UI.vbox(0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id: Variant in ids:
		grid.add_child(_item_row(String(id)))

	# what the highlighted item does
	var foot := UI.panel("well")
	col.add_child(foot)
	var foot_col := UI.vbox(0)
	foot.add_child(foot_col)
	_detail_name = UI.label("", "Name")
	_detail_name.clip_text = true
	foot_col.add_child(_detail_name)
	_detail = UI.label("", "Small" if ph else "", 10.0)
	_detail.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_small if ph else UI.size_body)
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


## The pause menu over a walking place (no run): Resume, Knight, then the screens a returning
## player needs (Journal, Map, Items, How to play: each only once its screen exists), Settings,
## Title (asks first). In a battle (in_battle): Resume, Settings, Give up the fight (asks first).
func _build_walking() -> void:
	var ph := UI.is_phone()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := UI.panel("panel")
	panel.custom_minimum_size.x = 220 if not ph else 150
	centre.add_child(panel)
	var col := UI.vbox(3 if not ph else 2)
	panel.add_child(col)
	col.add_child(UI.spacer(0, 4 if not ph else 1))
	var head := UI.label(WORDS["paused"], "Head")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var rule := UI.rule(120, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 7 if not ph else 4)
	col.add_child(rule)
	# (one face for every row: Resume is first and gold; focus is the brass bar and the flame)
	var resume := UI.button(WORDS["resume"], func() -> void: send("resume"))
	resume.name = "Resume"
	resume.add_theme_color_override("font_color", UI.C_GOLD)
	var rows: Array[Button] = [resume]
	if in_battle:
		rows.append(UI.button(WORDS["settings"], func() -> void: send("settings")))
		var give := UI.button(WORDS["give_up"], func() -> void:
			ask(WORDS["ask_give_up"], WORDS["yes_give_up"], WORDS["no_give_up"], func() -> void: send("battle_give_up")), "Danger")
		give.name = "GiveUp"
		rows.append(give)
	else:
		_knight = UI.button(_knight_text(), func() -> void: send("knight"))
		rows.append(_knight)
		for extra: Array in MORE:
			if not has_screen(String(extra[1]), String(extra[3])):
				continue                       # that screen (or that page of it) is not in this build yet: no row
			var b := UI.button(String(extra[0]), send.bind("open_screen", extra[2]))
			b.name = "Open_" + String(extra[1])
			rows.append(b)
		rows.append(UI.button(WORDS["settings"], func() -> void: send("settings")))
		var title := UI.button(WORDS["title"], func() -> void:
			ask(WORDS["ask_title"], WORDS["title"], WORDS["stay"], func() -> void: send("title"), false))
		title.name = "Title"
		rows.append(title)
	# on a phone a long menu gets shorter rows, so it never runs off the 180 px tall screen
	var row_h := (UI.row_h + 3.0) if not ph else (20.0 if rows.size() <= 5 else 16.0)
	for b: Button in rows:
		b.custom_minimum_size.y = row_h
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(b)
	col.add_child(UI.spacer(0, 3 if not ph else 0))
	default_focus = resume
	UI.pop_in(panel)


## True when scripts/ui/<file>.gd exists and, if a page is named, its PAGES table lists that page.
static func has_screen(file: String, page: String = "") -> bool:
	var path := "res://scripts/ui/%s.gd" % file
	if not ResourceLoader.exists(path):
		return false
	if page == "":
		return true
	var script := load(path) as Script
	var pages: Variant = script.get_script_constant_map().get("PAGES") if script != null else null
	if pages is Array:
		for row: Variant in pages:
			if row is Array and not (row as Array).is_empty() and String(row[0]) == page:
				return true
	return false


## A right click means "carry on" (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_back()


func help_pairs() -> Array:
	return [["confirm", "Choose"], ["back", "Resume"]]


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
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	b.custom_minimum_size = Vector2(0, maxf(20.0 if UI.is_phone() else 22.0, UI.font_body.get_height(UI.size_body) + 4.0))
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
