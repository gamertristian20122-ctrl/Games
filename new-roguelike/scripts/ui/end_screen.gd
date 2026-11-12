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
var _rack: Control
var _inner: VBoxContainer
var _extras: Control
var _rack_rows := 2


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var cols := UI.hbox(8)
	safe.add_child(cols)

	# left: the big word, one line about what happened, and the two buttons
	var left := UI.vbox(4)
	left.custom_minimum_size.x = 112
	cols.add_child(left)
	var in_level := String(summary.get("level", "")) != ""
	var whole := not in_level or bool(summary.get("final", false))       # only the last level is the Victory
	var title := UI.label(("Victory" if whole else "Cleared") if victory else "Fallen", "Title")
	UI.style_title(title, UI.C_GOLD if victory else UI.C_RED, Color("7a4a12") if victory else Color("5a1626"))
	UI.fit_title(title, 112.0)
	left.add_child(title)
	var line := UI.label(_story(), "", 100.0)
	left.add_child(line)
	left.add_child(UI.spacer(0, 0, true))
	var again := UI.button("Try again", func() -> void: send("retry"), "Big", "ui_start")
	again.custom_minimum_size.y = 26
	left.add_child(again)
	var menu := UI.button("Camp", func() -> void: send("menu"))
	menu.custom_minimum_size.y = 22
	left.add_child(menu)
	default_focus = again
	if in_level and victory:
		again.visible = false          # the level is done: back to the camp for the next one
		menu.custom_minimum_size.y = 26
		default_focus = menu

	# right: the numbers, the items, and anything new
	var panel := UI.panel("panel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var inner := UI.vbox(5)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	_inner = inner
	panel.add_child(inner)
	var tiles := UI.hbox(3)
	inner.add_child(tiles)
	for pair: Array in [
			["Floor", str(int(summary.get("floor", 1)))],
			["Time", UI.time_text(float(summary.get("time_s", 0.0)))],
			["Kills", str(int(summary.get("kills", 0)))],
			["To chest" if summary.has("banked") else "Coins", str(int(summary.get("banked", summary.get("coins", 0))))]]:
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

	# the smaller numbers, when the world sent them
	var extras := GridContainer.new()
	extras.columns = 2
	extras.add_theme_constant_override("h_separation", 12)
	extras.add_theme_constant_override("v_separation", 1)
	extras.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for pair: Array in [["Rooms", "rooms_cleared"], ["Secrets", "secrets_found"], ["Bosses", "bosses"], ["Hits taken", "damage_taken"]]:
		if not summary.has(pair[1]):
			continue
		var value: Variant = summary[pair[1]]
		var cell := UI.hbox(3)
		cell.add_child(UI.label(pair[0], "Small"))
		cell.add_child(UI.label(str(value.size()) if value is Array else str(int(value))))
		extras.add_child(cell)
	if extras.get_child_count() > 0:
		inner.add_child(extras)
		_extras = extras
	else:
		extras.free()

	# the items carried at the end
	var ids: Variant = summary.get("items", [])
	if ids is Array and not ids.is_empty():
		inner.add_child(HSeparator.new())
		_rack = ItemRack.new()
		_rack.centred = true
		_rack.set_items(ids, 140.0, 2)
		inner.add_child(_rack)
		panel.resized.connect(_fit_rack)

	# new unlocks: one gold box with every name
	if not unlocks.is_empty():
		var names: Array[String] = []
		for id: Variant in unlocks:
			if names.size() >= 4:
				break
			names.append(String(Unlocks.by_id(String(id)).get("name", id)))
		var text := ", ".join(names)
		if unlocks.size() > names.size():
			text += " and %d more" % (unlocks.size() - names.size())
		var box := UI.panel("tag")
		var v := UI.vbox(0)
		box.add_child(v)
		v.add_child(UI.label("Unlocked", "Gold"))
		v.add_child(UI.label(text + ".", "", 10.0))
		inner.add_child(box)
	UI.pop_in(cols)
	_squeeze.call_deferred()


## With a very large font the panel can be taller than the screen: drop the least important parts.
func _squeeze() -> void:
	var room := size.y - 12.0 - UI.safe_insets(self).y - UI.safe_insets(self).w - 10.0
	if _inner.get_combined_minimum_size().y > room and is_instance_valid(_extras):
		_extras.visible = false
	if _inner.get_combined_minimum_size().y > room and is_instance_valid(_rack):
		_rack_rows = 1
		_rack.call("set_items", summary.get("items", []), _rack.size.x, 1)


## The item row is as wide as the panel turns out to be.
func _fit_rack() -> void:
	var ids: Variant = summary.get("items", [])
	var w := _rack.get_parent_control().size.x
	if ids is Array and absf(w - _rack.size.x) > 1.0 and w > 40.0:
		_rack.call("set_items", ids, w, _rack_rows)


## One line about what happened.
func _story() -> String:
	var hero := String(Heroes.by_id(String(summary.get("hero", "knight")))["name"])
	var where := String(summary.get("floor_name", ""))
	if victory and String(summary.get("level", "")) != "":
		if String(summary.get("side", "")) != "":
			return "%s walks out of %s. The wood is quiet behind him." % [hero, String(summary.get("level_name", where))]
		if bool(summary.get("final", false)):
			return "%s climbs out of the Hollow Hill. The last seal holds." % hero
		if String(summary.get("champion", "")) != "":
			return "%s walks out of %s. The way on is open." % [hero, String(summary.get("level_name", where))]
		return "%s carries the seal shard out of %s. One more anchor holds." % [hero, String(summary.get("level_name", where))]
	if victory:
		return "%s climbs back into the light. The dungeon is quiet." % hero
	var cause := String(summary.get("cause", ""))
	var place := " in %s" % where if where != "" else ""
	if cause == "gave_up":
		return "%s turns back%s." % [hero, place]
	if cause == "":
		return "The dark takes %s%s." % [hero, place]
	return "%s was slain by %s%s." % [hero, _with_article(cause), place]


## "Gnasher" -> "a Gnasher", "Imp" -> "an Imp"; "the dark", "your own bomb" and "The Warden" stay as they are.
static func _with_article(cause: String) -> String:
	var first := cause.substr(0, 1)
	if first != first.to_upper() or first == first.to_lower() or cause.begins_with("The ") or cause.begins_with("A ") or cause.begins_with("An "):
		return cause
	return ("an " if first in ["A", "E", "I", "O", "U"] else "a ") + cause


## Back on the end screen goes to the menu.
func on_back() -> void:
	Sfx.play("ui_back")
	send("menu")
