extends "res://scripts/ui/screen.gd"
## Character: the knight's level, XP, numbers and the level-up cards he has taken
## (scripts/data/rpg.gd). Opened from the pause menu in a level and from the camp's menu.
## Later RPG steps add their pages here (gear, skills, party).

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Stats = preload("res://scripts/run/stats.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const Icon = preload("res://scripts/ui/icon.gd")

var _detail: Label


func build() -> void:
	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var col := UI.vbox(3)
	safe.add_child(col)
	col.add_child(top_bar("%s  -  level %d" % [Looks.hero_name(), Rpg.level()]))
	var cols := UI.hbox(6)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)

	# left: the knight, his XP and his numbers
	var left := UI.panel("panel")
	left.custom_minimum_size.x = 132
	cols.add_child(left)
	var lcol := UI.vbox(1)
	left.add_child(lcol)
	if Rpg.at_max():
		lcol.add_child(UI.label("Highest level reached", "Gold"))
	else:
		lcol.add_child(UI.label("XP  %d / %d" % [Rpg.xp(), Rpg.xp_need()], "Gold"))
	var sp := UI.label("Skill points: %d" % Rpg.skill_points())
	lcol.add_child(sp)
	var soon := UI.label("Skills arrive in the next update.", "Small", 120.0)
	soon.add_theme_color_override("font_color", UI.C_DIM)
	lcol.add_child(soon)
	lcol.add_child(HSeparator.new())
	for pair: Array in _numbers():
		var line := UI.hbox(3)
		var k := UI.label(String(pair[0]), "Small")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(k)
		line.add_child(UI.label(String(pair[1]), "Small"))
		lcol.add_child(line)

	# right: the cards taken so far
	var right := UI.panel("panel")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rcol := UI.vbox(2)
	right.add_child(rcol)
	rcol.add_child(UI.label("Level-up cards", "Gold"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	rcol.add_child(scroll)
	var list := UI.vbox(1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var any := false
	var first: Button = null
	for r: Dictionary in Rpg.CARDS:
		var t := Rpg.taken(String(r["id"]))
		if t <= 0:
			continue
		any = true
		var b := _card_row(r, t)
		list.add_child(b)
		if first == null:
			first = b
	_detail = UI.label("", "Small", 10.0)
	_detail.custom_minimum_size.y = 2.0 * UI.font_body.get_height(UI.size_small)
	_detail.add_theme_color_override("font_color", UI.C_DIM)
	rcol.add_child(_detail)
	if not any:
		_detail.text = "None yet. Every new level lets you take one card. Monsters give XP."
	else:
		_detail.text = "Tap a card to read what it does."
	default_focus = first if first != null else find_child("Back", true, false)
	UI.pop_in(cols)


func _card_row(r: Dictionary, times: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Flat"
	b.custom_minimum_size = Vector2(0, 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 3
	row.offset_right = -4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(18, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var ic := Icon.new()
	ic.setup(String(r.get("icon", "icon_whetstone")), Vector2.ZERO, 16.0)
	slot.add_child(ic)
	var name_label := UI.label(String(r["name"]))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UI.label("%d of %d" % [times, int(r["max"])], "Small"))
	var show := func() -> void:
		_detail.text = "%s: %s" % [String(r["name"]), String(r["text"])]
		_detail.add_theme_color_override("font_color", UI.C_BONE)
	b.focus_entered.connect(show)
	b.pressed.connect(show)
	return b


## His numbers as [name, value] pairs: from the live knight in a level, or worked out for the camp.
func _numbers() -> Array:
	var hero := Heroes.by_id("knight")
	var stats: Stats
	var hearts := 0
	var blocks := 0
	var rest := 0.0
	var p: Variant = G.run.get("player") if is_instance_valid(G.run) else null
	if is_instance_valid(p) and (p.get("hero") as Dictionary).has("melee"):
		stats = p.get("stats")
		hearts = int(p.get("max_hp"))
		blocks = int(p.get("block_max"))
		rest = float(p.get("_block_cool"))
	else:
		stats = Stats.new(hero)
		if hero.has("mods"):
			stats.set_layer("hero", hero["mods"])
		stats.set_layer("camp", Upgrades.mods())
		stats.set_layer("level", Rpg.mods())
		hearts = mini(int(hero.get("hp", 6)) + Upgrades.bonus_hp() + Rpg.bonus_hp() + int(G.diff("hearts")), 24)
		blocks = maxi(int(G.diff("block")) + Rpg.bonus_block(), 1)
		rest = maxf(5.0 + Upgrades.block_cooldown() + Rpg.block_cooldown(), 1.5)
	var half := "" if hearts % 2 == 0 else " and a half"
	return [
		["Hearts", "%d%s" % [hearts / 2, half]],
		["Damage per blow", "%.1f" % stats.v("damage")],
		["Blows per second", "%.2f" % stats.v("rate")],
		["Walking speed", "%d" % int(stats.v("speed"))],
		["Guard stops", "%d blows" % blocks],
		["Guard rests", "%.1f s" % rest],
		["Coins found", "%d%%" % int(round(stats.v("coin_mult") * 100.0))],
		["XP earned", "%d%%" % int(round(Rpg.xp_mult() * 100.0))],
	]
