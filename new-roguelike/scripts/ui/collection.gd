extends "res://scripts/ui/screen.gd"
## Collection: three tabs.
##   Items   every item in scripts/data/items.gd; ones you have picked up show their picture,
##           name and description, the rest are a "?"
##   Feats   every unlock rule in scripts/data/unlocks.gd with its hint and progress
##   Stats   lifetime numbers from the save file
## New items and unlock rules appear here by themselves: this screen only reads the data files.

const Items = preload("res://scripts/data/items.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")
const Icon = preload("res://scripts/ui/icon.gd")

const TABS := ["Items", "Feats", "Stats"]
## One item: a 16 px picture with 2 px of air, and a thin purple line under cursed ones.
const CELL := Vector2(20, 22)

var _tab := 0
var _tab_buttons: Array[Button] = []
var _body: Control
var _detail_icon: Control
var _detail_name: Label
var _detail_text: Label
var _detail_curse: Label
var _detail_box: VBoxContainer
var _selected := ""


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)

	# top bar: Back on the left, the three tabs on the right
	var bar := UI.hbox(3)
	bar.custom_minimum_size.y = 20
	col.add_child(bar)
	var back := UI.button("Back", on_back, "", "")
	back.custom_minimum_size = Vector2(40, 19)
	bar.add_child(back)
	var title := UI.label("Collection", "Head")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	bar.add_child(title)
	for i in TABS.size():
		var b := UI.button(TABS[i], show_tab.bind(i), "Tab")
		b.custom_minimum_size = Vector2(40, 19)
		bar.add_child(b)
		_tab_buttons.append(b)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_body)
	default_focus = back
	show_tab(_tab)


func show_tab(index: int) -> void:
	_tab = index
	for i in _tab_buttons.size():
		_tab_buttons[i].disabled = i == index
		_tab_buttons[i].focus_mode = Control.FOCUS_NONE if i == index else Control.FOCUS_ALL
	for c in _body.get_children():
		c.queue_free()
	var page: Control
	match index:
		0: page = _items_page()
		1: page = _feats_page()
		_: page = _stats_page()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(page)
	UI.pop_in(page, Vector2(0, 4))


# ------------------------------------------------------------------ items
func _items_page() -> Control:
	var row := UI.hbox(4)
	var left := UI.panel("panel")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var left_col := UI.vbox(2)
	left.add_child(left_col)
	var ids: Array = Items.ALL.keys()
	var seen := 0
	for id: String in ids:
		if Save.has_seen(id):
			seen += 1
	left_col.add_child(UI.label("Found %d of %d" % [seen, ids.size()], "Small"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	left_col.add_child(scroll)
	# all the items in rows that wrap; the list scrolls (drag it, or move the focus) when it is
	# taller than the screen, so any number of items fits
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	scroll.add_child(flow)
	var first: Control = null
	for id: String in ids:
		var cell := _item_cell(id)
		flow.add_child(cell)
		if first == null:
			first = cell

	# the right side explains the highlighted item
	var right := UI.panel("well")
	right.custom_minimum_size.x = 112
	row.add_child(right)
	_detail_box = UI.vbox(3)
	right.add_child(_detail_box)
	_detail_icon = UI.spacer(0, 40)
	_detail_box.add_child(_detail_icon)
	_detail_name = UI.label("", "Gold", 10.0)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(_detail_name)
	_detail_text = UI.label("", "", 10.0)
	_detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(_detail_text)
	_detail_curse = UI.label("", "Red", 10.0)
	_detail_curse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(_detail_curse)
	if not ids.is_empty():
		_select_item(_selected if Items.ALL.has(_selected) else String(ids[0]))
	return row


func _item_state(id: String) -> String:
	if Save.has_seen(id):
		return "seen"
	if Unlocks.is_gated("item:" + id) and not Save.is_unlocked("item:" + id):
		return "locked"
	return "unseen"


func _item_cell(id: String) -> Control:
	var info := Items.info(id)
	var state := _item_state(id)
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_ALL
	if state == "seen":
		var ic := Icon.new()
		ic.setup(String(info.get("icon", "skull")), Vector2(16, 16))
		ic.position = Vector2(2, 2)
		b.add_child(ic)
		if bool(info.get("cursed", false)):
			# a purple line under the picture marks cursed items
			var mark := ColorRect.new()
			mark.color = UI.C_CURSE
			mark.size = Vector2(10, 1)
			mark.position = Vector2(5, CELL.y - 3)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(mark)
	else:
		b.text = "?"
		b.add_theme_color_override("font_color", UI.C_FAINT)
		b.add_theme_color_override("font_focus_color", UI.C_DIM)
		b.add_theme_color_override("font_hover_color", UI.C_DIM)
	b.focus_entered.connect(_select_item.bind(id))
	b.pressed.connect(_select_item.bind(id))
	return b


func _select_item(id: String) -> void:
	_selected = id
	var info := Items.info(id)
	var state := _item_state(id)
	_detail_icon.queue_free()
	if state == "seen":
		var ic := Icon.new()
		ic.setup(String(info.get("icon", "skull")), Vector2(100, 40), 0.0, 2.0)
		_detail_icon = ic
		var cursed := bool(info.get("cursed", false))
		_detail_name.text = String(info.get("name", id))
		_detail_name.add_theme_color_override("font_color", UI.C_CURSE if cursed else UI.C_GOLD)
		_detail_text.text = String(info.get("desc", ""))
		_detail_curse.text = String(info.get("curse", "")) if cursed else ""
	else:
		var q := UI.label("?", "Title")
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.custom_minimum_size = Vector2(0, 40)
		q.add_theme_color_override("font_color", UI.C_FAINT)
		_detail_icon = q
		_detail_name.text = "Unknown"
		_detail_name.add_theme_color_override("font_color", UI.C_DIM)
		_detail_curse.text = ""
		if state == "locked":
			_detail_text.text = "Locked. " + String(Unlocks.by_id("item:" + id).get("hint", ""))
		else:
			_detail_text.text = "Find it in the dungeon to learn what it does."
	_detail_curse.visible = _detail_curse.text != ""
	_detail_box.add_child(_detail_icon)
	_detail_box.move_child(_detail_icon, 0)


# ------------------------------------------------------------------ feats (unlock rules)
func _feats_page() -> Control:
	var panel := UI.panel("panel")
	var col := UI.vbox(2)
	panel.add_child(col)
	var done := 0
	for rule: Dictionary in Unlocks.RULES:
		if Save.is_unlocked(String(rule["id"])):
			done += 1
	col.add_child(UI.label("Unlocked %d of %d" % [done, Unlocks.RULES.size()], "Small"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for rule: Dictionary in Unlocks.RULES:
		grid.add_child(_feat_row(rule))
	return panel


func _feat_row(rule: Dictionary) -> Control:
	var id := String(rule["id"])
	var got := Save.is_unlocked(id)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UI.box("gold" if got else "slot"))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_ALL
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	row.draw.connect(func() -> void:
		if row.has_focus():
			row.draw_rect(Rect2(Vector2(1.5, 1.5), row.size - Vector2(3, 3)), UI.C_BONE, false, 1.0))
	var col := UI.vbox(0)
	row.add_child(col)
	var top := UI.hbox(3)
	col.add_child(top)
	var name_label := UI.label(String(rule["name"]), "Gold" if got else "")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top.add_child(name_label)
	var need := int(rule["at_least"])
	var have := mini(Save.stat_total(String(rule["stat"])), need)
	var progress := UI.label("Done" if got else "%d/%d" % [have, need], "Small")
	if got:
		progress.add_theme_color_override("font_color", UI.C_GOLD)
	top.add_child(progress)
	var hint := UI.label(String(rule["hint"]), "Small", 10.0)
	col.add_child(hint)
	return row


# ------------------------------------------------------------------ stats
func _stats_page() -> Control:
	var panel := UI.panel("panel")
	var centre := CenterContainer.new()
	panel.add_child(centre)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	centre.add_child(grid)
	var seen := 0
	for id: String in Items.ALL:
		if Save.has_seen(id):
			seen += 1
	var fastest := Save.stat_get("fastest_win")
	var rows := [
		["Runs", str(Save.stat_get("runs"))],
		["Wins", str(Save.stat_get("wins"))],
		["Deaths", str(Save.stat_get("deaths"))],
		["Deepest floor", str(Save.stat_get("best_floor")) if Save.stat_get("best_floor") > 0 else "-"],
		["Fastest win", UI.time_text(fastest) if fastest > 0 else "-"],
		["Monsters slain", str(Save.stat_get("total_kills"))],
		["Coins collected", str(Save.stat_get("total_coins"))],
		["Bosses beaten", str(Save.stat_total("boss_killed"))],
		["Secrets found", str(Save.stat_total("secret_found"))],
		["Chests opened", str(Save.stat_total("chest_opened"))],
		["Items found", "%d/%d" % [seen, Items.ALL.size()]],
		["Cursed items taken", str(Save.stat_get("cursed_taken"))],
	]
	for pair: Array in rows:
		var k := UI.label(pair[0], "Dim")
		k.custom_minimum_size.x = 84
		grid.add_child(k)
		var v := UI.label(pair[1], "Gold")
		v.custom_minimum_size.x = 34
		grid.add_child(v)
	return panel
