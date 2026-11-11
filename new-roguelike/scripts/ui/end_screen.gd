extends "res://scripts/ui/screen.gd"
## End screen: shown when a run is over, for both a death and a win.
## It shows the summary the world sent with G.run_ended (floor, time, kills, coins, items),
## anything that was unlocked during the run, and the buttons Try again / Menu.

const Heroes = preload("res://scripts/data/heroes.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")
const ItemRack = preload("res://scripts/ui/item_rack.gd")

var victory := false             ## set by main.gd
var summary := {}                ## set by main.gd
var unlocks: Array = []          ## ids unlocked during this run, set by main.gd


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)

	var title := UI.label("Victory" if victory else "Fallen", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UI.C_GOLD if victory else UI.C_RED)
	title.add_theme_color_override("font_shadow_color", Color("6b4a12") if victory else Color("4a1420"))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_outline_color", UI.C_INK)
	title.add_theme_constant_override("outline_size", 4)
	col.add_child(title)

	var line := UI.label(_story(), "Dim")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)

	var panel := UI.panel("panel")
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size.x = 252
	col.add_child(panel)
	var inner := UI.vbox(4)
	panel.add_child(inner)

	# the four numbers
	var tiles := UI.hbox(4)
	inner.add_child(tiles)
	var floor_no := int(summary.get("floor", 1))
	for pair: Array in [
			["Floor", str(floor_no)],
			["Time", UI.time_text(float(summary.get("time_s", 0.0)))],
			["Kills", str(int(summary.get("kills", 0)))],
			["Coins", str(int(summary.get("coins", 0)))]]:
		var tile := UI.panel("well")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UI.vbox(0)
		tile.add_child(t)
		var k := UI.label(pair[0], "Small")
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_child(k)
		var v := UI.label(pair[1], "Head")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if pair[0] == "Coins":
			v.add_theme_color_override("font_color", UI.C_GOLD)
		t.add_child(v)
		tiles.add_child(tile)

	# the items carried at the end
	var ids: Variant = summary.get("items", [])
	if ids is Array and not ids.is_empty():
		var rack := ItemRack.new()
		rack.centred = true
		rack.set_items(ids, 238.0, 1)
		inner.add_child(rack)

	# new unlocks, most important first
	var shown := 0
	var max_rows := 2
	for id: Variant in unlocks:
		if shown >= max_rows:
			break
		var rule := Unlocks.by_id(String(id))
		var kind := {"hero": "New hero", "item": "New item", "ach": "Achievement"}.get(Unlocks.kind(String(id)), "Unlocked") as String
		var row := UI.panel("gold")
		var h := UI.hbox(5)
		row.add_child(h)
		h.add_child(UI.label(kind, "Gold"))
		var n := UI.label(String(rule.get("name", id)))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		h.add_child(n)
		inner.add_child(row)
		shown += 1
	if unlocks.size() > shown:
		var more := UI.label("+%d more unlocked. See the Collection." % (unlocks.size() - shown), "Gold")
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(more)

	var buttons := UI.hbox(6)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var again := UI.button("Try again", func() -> void: send("retry"), "Big", "ui_start")
	again.custom_minimum_size = Vector2(110, 26)
	buttons.add_child(again)
	var menu := UI.button("Menu", func() -> void: send("menu"), "Big")
	menu.custom_minimum_size = Vector2(80, 26)
	buttons.add_child(menu)
	default_focus = again
	UI.pop_in(col)


## One line about what happened.
func _story() -> String:
	var hero := Heroes.by_id(String(summary.get("hero", "knight")))
	var where := String(summary.get("floor_name", ""))
	if victory:
		return "%s climbs back into the light. The dungeon is quiet." % hero["name"]
	var cause := String(summary.get("cause", ""))
	var text := "The dark takes %s." % hero["name"]
	if cause == "gave_up":
		text = "%s turns back." % hero["name"]
	elif cause != "":
		text = "%s was slain by %s." % [hero["name"], cause]
	if where != "":
		text += "  " + where + "."
	return text


## Back on the end screen goes to the menu.
func on_back() -> void:
	Sfx.play("ui_back")
	send("menu")
