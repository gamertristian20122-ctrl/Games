extends Node
## A TURN-BASED BATTLE on the lit 3D stage (the owner, 12 Nov 2026: "turn-based", "soft light").
## The rules are scripts/battle/fight.gd, the numbers and words scripts/data/battles.gd, the place
## scripts/battle/stage.gd. This file shows it: the fighters, the menus, what each blow does.
##
## main.gd makes one when a roamer of the world map touches the knight (`spot` = which roamer),
## and waits for `finished(outcome, summary)`: outcome is "win", "lose" or "fled".
## A round: everybody acts once, the quickest first (the faces at the top left show who is next).
## On your turn: Attack (tap a monster), Skills (your learned skills, they cost mana), Guard
## (take less than half until your next turn, a little mana back), Flee.
## Test: `--battle=<spot>` opens one at once; with `--autotest` a bot plays it and the game quits;
## `--knight=<level>` and `--with=<companion id>` set who fights; `--night` picks the night stage; `--shots=<dir>` writes battle.png on the first turn.

signal finished(outcome: String, summary: Dictionary)
signal _picked(action: Dictionary)

const Stage = preload("res://scripts/battle/stage.gd")
const Fight = preload("res://scripts/battle/fight.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const UI = preload("res://scripts/ui/theme.gd")

const PARTY_AT := [Vector3(-2.6, 0.0, 0.7), Vector3(-4.8, 0.0, -0.9), Vector3(-5.4, 0.0, 1.8), Vector3(-7.2, 0.0, 0.2)]
const FOES_AT := [Vector3(2.2, 0.0, 0.9), Vector3(4.5, 0.0, -0.9), Vector3(6.4, 0.0, 1.1), Vector3(7.8, 0.0, -1.4)]
const PX := 1.0 / 16.0

var spot := 0                      ## which roamer of scripts/data/roamers.gd started it
var story := ""                    ## or: a battle of the story (scripts/data/tale.gd BATTLES)
var night := false
var fight: RefCounted
var stage: Node3D
var _root: Control
var _area: Control
var _order_row: HBoxContainer
var _message: Label
var _party_rows: Array = []        ## {"unit", "panel", "hp", "mp", "hp_text", "mp_text", "button"}
var _tags: Array = []              ## {"unit", "box", "bar", "button"}
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _hint: Label
var _speed := 1.0
var _auto := false
var _over := false
var _shot_done := false
var _cam_home := Vector3.ZERO
var _t := 0.0
var _tier := 0
var _fx: Array = []                ## the look of the skill being shown now (battles.gd FX), [] = a plain blow
var _trauma := 0.0                 ## how shaken the camera is, 0 to 1 (see _feel)
var _shake_t := 0.0
var _xp_bonus := 0                ## a battle of the story may give XP of its own on top


func _ready() -> void:
	_auto = G.flag("autotest") or G.flag("autobattle")
	_speed = maxf(float(G.arg("speed", "1")), 1.0) if _auto else 1.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if G.args.has("seed"):
		rng.seed = int(G.arg("seed"))
	fight = Fight.new()
	var title := "A fight"
	var look := "forest"
	if story != "":
		var spec := Battles.scripted(story)
		_tier = int(spec["tier"])
		title = String(spec["title"])
		look = String(spec["look"])
		fight.call("setup", spec["party"], spec["foes"], rng.randi())
		fight.set("no_flee", bool(spec["boss"]))
		_xp_bonus = int(spec["xp_bonus"])
	else:
		var kind := Roamers.kind_of(spot)
		_tier = int(kind["tier"])
		title = String(kind.get("title", "A fight"))
		look = Battles.look_for(spot)
		if night and Stage.LOOKS.has(look + "_night"):
			look += "_night"
		fight.call("setup", Battles.party(), Battles.pack_for(spot, rng), rng.randi())
	stage = Stage.new()
	add_child(stage)
	stage.call("build", look, 11 + maxi(spot, 0) + story.length())
	_cam_home = stage.cam.position
	var party: Array = fight.party
	var foes: Array = fight.foes
	for i in party.size():
		_place(party[i], PARTY_AT[i], false)
	for i in foes.size():
		# a boss stands alone in the middle of its side
		_place(foes[i], Vector3(3.9, 0.0, 0.2) if bool(foes[i].get("boss", false)) else FOES_AT[i], true)
	_build_screen()
	_refresh()
	_run.call_deferred(title)


# ------------------------------------------------------------------ the fighters on the stage
func _place(unit: Dictionary, at: Vector3, faces_left: bool) -> void:
	var body: MeshInstance3D = stage.call("stand", String(unit["sprite"]), at, faces_left)
	var tint: Color = unit.get("tint", Color.WHITE)
	body.call("set_tint", tint)
	unit["node"] = body
	unit["home"] = at
	var m := Art.meta(String(unit["sprite"]))
	var bw := float(m.get("body_width", 16.0)) * PX
	var bh := float(m.get("body_height", 28.0)) * PX
	if bool(unit.get("boss", false)):
		# boss art has no body measurements: its picture, less the empty air the pack leaves round it
		var used := UI.used_rect(String(unit["sprite"]))
		bw = used.size.x * PX * 0.8
		bh = used.size.y * PX
	bh *= Sprite3.tall                 # standing pictures are drawn taller by the camera's slant (sprite3.gd)
	unit["top"] = bh
	unit["wide"] = bw
	# the pack draws bodies without arms: a hand at each side, and the knight's sword in his
	var hands := ""
	if String(unit["id"]) == "knight":
		var hero: Dictionary = Heroes.by_id("knight")
		hands = String(hero.get("hand", ""))
		var sword := Node3D.new()
		sword.position = Vector3(bw * 0.5 + 0.02, bh * 0.36, 0.03)
		sword.rotation.z = deg_to_rad(-28.0)
		body.add_child(sword)
		var blade := Sprite3.make(String(hero["weapon"]))
		blade.position = Vector3(0.0, -float(hero.get("grip", 3)) * PX, 0.0)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sword.add_child(blade)
	elif String(unit["side"]) == "party":
		hands = String(Allies.row(String(unit["id"])).get("hands", ""))
	else:
		hands = String(Enemies.info(String(unit["id"])).get("hands", ""))
	if hands != "" and Art.has(hands):
		for side: float in [-1.0, 1.0]:
			var hand := Sprite3.make(hands)
			hand.position = Vector3(side * (bw * 0.5 + 0.02), bh * 0.3, 0.035)
			hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hand.call("set_tint", tint)
			body.add_child(hand)


# ------------------------------------------------------------------ the screen
func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	var safe := UI.safe_margin(_root, 5)
	_root.add_child(safe)
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_area)

	_order_row = UI.hbox(2)
	_order_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_area.add_child(_order_row)

	_message = UI.label("", "Hud")
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 22
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", UI.C_INK)
	_message.add_theme_constant_override("outline_size", 3)
	_area.add_child(_message)

	# your side (bottom left)
	var party_panel := UI.panel("panel")
	party_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	party_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_area.add_child(party_panel)
	var rows := UI.vbox(2)
	party_panel.add_child(rows)
	for unit: Dictionary in fight.party:
		var button := Button.new()
		button.theme_type_variation = "Flat"
		button.custom_minimum_size = Vector2(182, 19)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("normal", UI.box("slot"))
		button.add_theme_stylebox_override("hover", UI.box("slot_focus"))
		button.add_theme_stylebox_override("focus", UI.box("slot_focus"))
		button.add_theme_stylebox_override("pressed", UI.box("slot_focus"))
		rows.add_child(button)
		var row := UI.hbox(5)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 4
		row.offset_right = -4
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var name_label := UI.label(String(unit["name"]), "Hud")
		name_label.custom_minimum_size.x = 52
		name_label.clip_text = true
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		var hp := _bar(UI.C_RED)
		var mp := _bar(UI.C_BLUE)
		row.add_child(hp["box"])
		row.add_child(mp["box"])
		_party_rows.append({"unit": unit, "button": button, "name": name_label, "hp": hp, "mp": mp})
		var who := unit
		button.pressed.connect(func() -> void: _target_picked(who))

	# what you can do (bottom right)
	_menu = UI.panel("panel")
	_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_area.add_child(_menu)
	_menu_box = UI.vbox(2)
	_menu.add_child(_menu_box)
	_menu.visible = false

	# over each monster: a life bar, always; its name and a frame to tap, while you aim
	for i in (fight.foes as Array).size():
		var unit: Dictionary = fight.foes[i]
		var button := Button.new()
		button.theme_type_variation = "Flat"
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		button.custom_minimum_size = Vector2(maxf(34.0, float(unit["wide"]) / PX * 0.9), float(unit["top"]) / PX * 0.8 + 8.0)
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("normal", UI.box("slot"))
		for state: String in ["hover", "focus", "pressed"]:
			button.add_theme_stylebox_override(state, UI.box("slot_focus"))
		button.self_modulate.a = 0.55
		_root.add_child(button)
		var back := ColorRect.new()
		back.color = UI.C_INK
		back.size = Vector2(30, 2)
		back.position = Vector2((button.custom_minimum_size.x - 30.0) * 0.5, -5.0)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(back)
		var fill := ColorRect.new()
		fill.color = UI.C_RED
		fill.size = Vector2(30, 2)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fill)
		var l := UI.label(String(unit["name"]), "Small")
		l.add_theme_color_override("font_color", UI.C_BONE)
		l.add_theme_color_override("font_outline_color", UI.C_INK)
		l.add_theme_constant_override("outline_size", 3)
		l.visible = false
		button.add_child(l)
		l.position = Vector2((button.custom_minimum_size.x - l.get_minimum_size().x) * 0.5, -17.0 - 9.0 * (i % 2))     # every other name a line higher, so two never share a line
		_tags.append({"unit": unit, "button": button, "fill": fill, "name": l})
		var who := unit
		button.pressed.connect(func() -> void: _target_picked(who))


## A bar with its numbers under it.
func _bar(colour: Color) -> Dictionary:
	var box := UI.vbox(1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := UI.label("", "Small")
	text.add_theme_color_override("font_color", UI.C_BONE)
	text.custom_minimum_size.x = 54            # room for "HP 999/999", so the two bars always line up
	box.add_child(text)
	var back := ColorRect.new()
	back.color = UI.C_PANEL_LOW
	back.custom_minimum_size = Vector2(46, 3)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	var fill := ColorRect.new()
	fill.color = colour
	fill.size = Vector2(46, 3)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return {"box": box, "text": text, "fill": fill}


## Puts every number and bar right.
func _refresh(acting: Dictionary = {}) -> void:
	for row: Dictionary in _party_rows:
		var u: Dictionary = row["unit"]
		(row["hp"]["text"] as Label).text = "HP %d/%d" % [int(u["hp"]), int(u["max_hp"])]
		(row["hp"]["fill"] as ColorRect).size.x = 46.0 * float(u["hp"]) / float(u["max_hp"])
		(row["mp"]["text"] as Label).text = "MP %d/%d" % [int(u["mp"]), int(u["max_mp"])]
		(row["mp"]["fill"] as ColorRect).size.x = 46.0 * float(u["mp"]) / maxf(float(u["max_mp"]), 1.0)
		var label: Label = row["name"]
		label.add_theme_color_override("font_color", UI.C_GOLD if u == acting else (UI.C_FAINT if int(u["hp"]) <= 0 else UI.C_BONE))
	for tag: Dictionary in _tags:
		var u: Dictionary = tag["unit"]
		(tag["fill"] as ColorRect).size.x = 30.0 * float(u["hp"]) / float(u["max_hp"])
		(tag["button"] as Button).visible = int(u["hp"]) > 0
	for c in _order_row.get_children():
		c.queue_free()
	if acting.is_empty():
		return
	var line: Array = [acting]
	line.append_array(fight.call("upcoming"))
	for i in mini(line.size(), 7):
		var u: Dictionary = line[i]
		var slot := UI.panel("slot_focus" if i == 0 else "slot")
		slot.custom_minimum_size = Vector2(17, 17)
		var face := TextureRect.new()
		face.texture = _face(String(u["sprite"]))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.custom_minimum_size = Vector2(13, 13)
		face.modulate = u.get("tint", Color.WHITE)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
		_order_row.add_child(slot)


## The head of a fighter for the turn order: the top of the first frame of the pack art.
func _face(sprite_id: String) -> Texture2D:
	var used := UI.used_rect(sprite_id)
	var side := minf(used.size.x, used.size.y * 0.6)
	var at := AtlasTexture.new()
	at.atlas = Art.tex(sprite_id)
	at.region = Rect2(used.position.x + (used.size.x - side) * 0.5, used.position.y, side, side)
	return at


# ------------------------------------------------------------------ the menu on your turn
var _acting := {}
var _waiting_skill := {}           ## the skill that is waiting for a target ({} = a plain Attack)
var _aim := ""                     ## "" | "foe" | "friend": what a tap picks now


func _clear_menu() -> void:
	for c in _menu_box.get_children():
		c.queue_free()
	_set_aim("")


func _set_aim(aim: String) -> void:
	_aim = aim
	for tag: Dictionary in _tags:
		var b: Button = tag["button"]
		b.disabled = aim != "foe"
		b.focus_mode = Control.FOCUS_ALL if aim == "foe" else Control.FOCUS_NONE
		(tag["name"] as Label).visible = aim == "foe"
	for row: Dictionary in _party_rows:
		var b: Button = row["button"]
		var can := aim == "friend" and int(row["unit"]["hp"]) > 0
		b.disabled = not can
		b.focus_mode = Control.FOCUS_ALL if can else Control.FOCUS_NONE


func _show_commands() -> void:
	_clear_menu()
	_menu.visible = true
	var title := UI.label(String(_acting["name"]) + ": what now?", "Small")
	title.add_theme_color_override("font_color", UI.C_GOLD)
	_menu_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_menu_box.add_child(grid)
	var attack := UI.button("Attack", _on_attack)
	var skills := UI.button("Skills", _show_skills)
	var guard := UI.button("Guard", func() -> void: _choose({"do": "guard"}))
	var flee := UI.button("Flee", func() -> void: _choose({"do": "flee"}))
	for b: Button in [attack, skills, guard, flee]:
		b.custom_minimum_size = Vector2(54, 19)
		grid.add_child(b)
	if bool(fight.get("no_flee")):
		flee.disabled = true
		_menu_box.add_child(_reason("No running from this one."))
	for foe: Dictionary in fight.call("alive", fight.foes):
		if bool(fight.call("sweep_next", foe)):
			var warn := _reason("%s draws back for a great blow at everybody. Guard!" % String(foe["name"]))
			warn.add_theme_color_override("font_color", UI.C_ORANGE)
			_menu_box.add_child(warn)
	if (_acting["skills"] as Array).is_empty():
		# never a dead button without the reason on the screen
		skills.disabled = true
		_menu_box.add_child(_reason("No skills yet: the first comes at level 2."))
	attack.grab_focus.call_deferred()


func _reason(text: String) -> Label:
	var l := UI.label(text, "Small", 150.0)
	l.add_theme_color_override("font_color", UI.C_DIM)
	return l


func _on_attack() -> void:
	_waiting_skill = {}
	_ask_target("foe", "Tap the monster to strike.")


func _show_skills() -> void:
	_clear_menu()
	var title := UI.label("Skills  (mana %d)" % int(_acting["mp"]), "Small")
	title.add_theme_color_override("font_color", UI.C_GOLD)
	_menu_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2 if (_acting["skills"] as Array).size() > 4 else 1
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
	_menu_box.add_child(grid)
	_hint = _reason("")
	var first: Button = null
	for s: Dictionary in _acting["skills"]:
		var skill := s
		var b := UI.button("%s  %d" % [String(s["name"]), int(s["mana"])], func() -> void: _on_skill(skill))
		b.custom_minimum_size = Vector2(84, 17)
		b.focus_entered.connect(func() -> void: _hint.text = String(skill.get("text", "")))
		b.mouse_entered.connect(func() -> void: _hint.text = String(skill.get("text", "")))
		if not bool(fight.call("can_use", _acting, s)):
			b.disabled = true
			b.tooltip_text = "Not enough mana"
		elif first == null:
			first = b
		grid.add_child(b)
	_menu_box.add_child(_hint)
	if first == null:
		_hint.text = "Not enough mana for any of them. Guard gives a little back."
	var back := UI.button("Back", _show_commands, "", "ui_back")
	back.custom_minimum_size = Vector2(54, 17)
	_menu_box.add_child(back)
	if first != null:
		first.grab_focus.call_deferred()
	else:
		back.grab_focus.call_deferred()


func _on_skill(skill: Dictionary) -> void:
	_waiting_skill = skill
	match String(skill.get("aim", "foe")):
		"foes", "self":
			_choose({"do": "skill", "skill": skill, "target": null})
		"friend":
			_ask_target("friend", "Tap who gets it.")
		_:
			_ask_target("foe", "Tap the monster to aim at.")


func _ask_target(aim: String, words: String) -> void:
	var choices: Array = fight.call("alive", fight.foes if aim == "foe" else fight.party)
	if choices.size() == 1:
		_target_picked(choices[0], aim)
		return
	_clear_menu()
	_menu_box.add_child(_reason(words))
	var back := UI.button("Back", _show_commands, "", "ui_back")
	back.custom_minimum_size = Vector2(54, 17)
	_menu_box.add_child(back)
	_set_aim(aim)
	# a pad or keys: start on the first one that can be picked
	if aim == "foe":
		for tag: Dictionary in _tags:
			if int(tag["unit"]["hp"]) > 0:
				(tag["button"] as Button).grab_focus.call_deferred()
				break
	else:
		(_party_rows[0]["button"] as Button).grab_focus.call_deferred()


func _target_picked(unit: Dictionary, forced_aim: String = "") -> void:
	var aim := forced_aim if forced_aim != "" else _aim
	if aim == "" or _acting.is_empty():
		return
	Sfx.play("ui_click")
	if _waiting_skill.is_empty():
		_choose({"do": "attack", "target": unit})
	else:
		_choose({"do": "skill", "skill": _waiting_skill, "target": unit})


func _choose(action: Dictionary) -> void:
	if _acting.is_empty():
		return
	_acting = {}
	_clear_menu()
	_menu.visible = false
	_picked.emit(action)


# ------------------------------------------------------------------ the battle, turn by turn
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed, false).timeout


func _say(text: String) -> void:
	_message.text = text


func _run(title: String) -> void:
	_say(title)
	await _wait(0.9)
	while String(fight.call("result")) == "":
		var who: Dictionary = fight.call("next")
		if who.is_empty():
			break
		_refresh(who)
		var events: Array = []
		if bool(fight.call("stunned", who)):
			events = fight.call("act", who, {})
		elif String(who["side"]) == "party":
			var action := {}
			if _auto:
				await _wait(0.25)
				action = fight.call("auto_choice", who)
			else:
				_acting = who
				_say("")
				_show_commands()
				_take_shot()
				action = await _picked
			events = fight.call("act", who, action)
		else:
			await _wait(0.35)
			events = fight.call("act", who, fight.call("foe_choice", who))
		await _play(events)
		_refresh()
	await _finish()


## Shows what a turn did, one thing after another.
func _play(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"skill":
				_say("%s: %s!" % [String(e["who"]["name"]), String(e["skill"]["name"])])
				Sfx.play("ui_start", -6.0)
				_fx = Battles.FX.get(String(e["skill"].get("id", "")), [])
				await _step(e["who"], 0.5)
			"hit":
				var who: Dictionary = e["who"]
				var target: Dictionary = e["target"]
				if _message.text == "" or not _message.text.ends_with("!"):
					_say("%s strikes %s." % [String(who["name"]), String(target["name"])])
				if _fx.is_empty():
					await _step(who, 0.9)          # (a skill has already stepped forward once)
				Sfx.play("hit", -4.0)
				_show_fx(target)
				_flash(target)
				# how hard the hit FEELS: a plain blow is "medium", a crit, a kill or a boss's blow "large"
				var big := bool(e["crit"]) or bool(e["dead"]) or bool(who.get("boss", false)) or (not _fx.is_empty() and float(_fx[2]) >= 2.0)
				_feel(target, "large" if big else "medium")
				_float(target, ("%d!" if bool(e["crit"]) else "%d") % int(e["amount"]), UI.C_GOLD if bool(e["crit"]) else UI.C_BONE)
				_refresh()
				await _wait(0.28)
				if bool(e["dead"]):
					await _fall(target)
			"heal":
				_show_fx(e["target"])
				_float(e["target"], "+%d" % int(e["amount"]), UI.C_GREEN)
				Sfx.play("pickup", -6.0)
				_refresh()
				await _wait(0.4)
			"miss":
				_float(e["target"], "Miss", UI.C_DIM)
				await _wait(0.35)
			"guard":
				_say("%s guards." % String(e["who"]["name"]))
				_float(e["who"], "Guard", UI.C_ICE)
				await _wait(0.35)
			"stun":
				if not _fx.is_empty() and String(_fx[1]) == "rise":
					_show_fx(e["target"])
				_float(e["target"], "Stunned", UI.C_ICE)
				await _wait(0.25)
			"stunned":
				_say("%s cannot move." % String(e["who"]["name"]))
				_float(e["who"], "...", UI.C_ICE)
				await _wait(0.45)
			"flee":
				_say("You get away." if bool(e["ok"]) else "No way out!")
				Sfx.play("ui_back")
				await _wait(0.6)
			"say":
				_say(String(e["text"]))
				await _wait(0.5)
	_fx = []
	await _wait(0.12)


## The light and sparks of a blow or a spell on the one it lands on (scripts/data/battles.gd FX).
func _show_fx(target: Dictionary) -> void:
	if _speed > 4.0:
		return
	var at: Vector3 = (target["home"] as Vector3) + Vector3(0.0, float(target["top"]) * 0.5, 0.15)
	if _fx.is_empty():
		stage.call("burst", at, Color(1.0, 0.97, 0.9), 0.8)
		return
	var colour: Color = _fx[0]
	var power := float(_fx[2])
	if G.flag("shotfx") and not _shot_done and G.arg("shots", "") != "" and String(_fx[1]) == "pillar":
		_shot_done = true                  # test: --shotfx writes battle_fx.png in the middle of a spell
		get_tree().create_timer(0.09).timeout.connect(func() -> void:
			DirAccess.make_dir_recursive_absolute(G.arg("shots", ""))
			get_viewport().get_texture().get_image().save_png(G.arg("shots", "").path_join("battle_fx.png"))
			G.quit(0))
	match String(_fx[1]):
		"pillar":
			stage.call("pillar", target["home"], colour, 0.5 + 0.25 * power)
			stage.call("burst", at, colour, power)
		"rise":
			stage.call("burst", (target["home"] as Vector3) + Vector3(0.0, 0.2, 0.15), colour, power, 1.6)
		_:
			stage.call("burst", at, colour, power)


## GAME FEEL (v0.23.0): several small, brief answers to one hit, sized by a tier.
##   medium  a normal blow: a little shake, a very short freeze, the one hit squashes
##   large   a crit, a kill, a boss's blow, a big spell: more of each
## The shake is "trauma" that decays in real time; the camera moves by trauma SQUARED along
## smooth waves (never a random jitter). The freeze slows the whole game for a few hundredths of
## a second; only the newest freeze may end it. Settings > Screen shake turns the shake off.
const FEEL := {"medium": {"trauma": 0.32, "stop": 0.045}, "large": {"trauma": 0.7, "stop": 0.1}}

func _feel(target: Dictionary, tier: String) -> void:
	if _speed > 4.0:
		return                             # the test bot plays without it
	var f: Dictionary = FEEL[tier]
	_trauma = clampf(_trauma + float(f["trauma"]), 0.0, 1.0)
	_pop(target)
	_hit_stop(float(f["stop"]))


## Squash and spring back (the picture only; nothing in the fight changes).
func _pop(unit: Dictionary) -> void:
	var node: Node3D = unit["node"]
	if not is_instance_valid(node):
		return
	if unit.get("pop") is Tween and (unit["pop"] as Tween).is_valid():
		(unit["pop"] as Tween).kill()      # two tweens on one scale would fight
	node.scale = Vector3(1.22, 0.8, 1.0)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unit["pop"] = tw


var _stop_id := 0
func _hit_stop(duration: float, slow: float = 0.05) -> void:
	_stop_id += 1
	var mine := _stop_id
	Engine.time_scale = slow
	# (process_always, not physics, IGNORE the time scale: or the timer itself would crawl)
	await get_tree().create_timer(duration, true, false, true).timeout
	if mine == _stop_id:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0                # never leave the game slowed when a battle is freed


## A fighter steps towards the other side and back.
func _step(unit: Dictionary, reach: float) -> void:
	var node: Node3D = unit["node"]
	if not is_instance_valid(node) or _speed > 4.0:
		return
	if String(unit["side"]) == "foes" and Art.has_anim(String(unit["sprite"]), "attack"):
		# the pack drew this one striking: play that instead of a step (then back to standing)
		node.call("play", "attack")
		await get_tree().create_timer(0.45 / _speed, false).timeout
		_later(0.5 / _speed, node, func(n: Node) -> void:
			if int(unit["hp"]) > 0:
				n.call("play", "idle"))
		return
	var home: Vector3 = unit["home"]
	var dir := 1.0 if String(unit["side"]) == "party" else -1.0
	var tw := create_tween()
	tw.tween_property(node, "position", home + Vector3(dir * reach, 0.0, 0.0), 0.11 / _speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", home, 0.16 / _speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.12 / _speed, false).timeout


func _flash(unit: Dictionary) -> void:
	var node: MeshInstance3D = unit["node"]
	if not is_instance_valid(node):
		return
	node.call("set_flash", 0.85)
	if Art.has_anim(String(unit["sprite"]), "hit") and int(unit["hp"]) > 0:
		node.call("play", "hit")
	var home: Vector3 = unit["home"]
	var back := -0.25 if String(unit["side"]) == "party" else 0.25
	var tw := create_tween()
	tw.tween_property(node, "position", home + Vector3(back, 0.0, 0.0), 0.05)
	tw.tween_property(node, "position", home, 0.14)
	_later(0.09, node, func(n: Node) -> void: n.call("set_flash", 0.0))
	_later(0.36, node, func(n: Node) -> void:
		if int(unit["hp"]) > 0:
			n.call("play", "idle"))


## Does something to a fighter's picture a moment later, if the picture is still there then (a
## battle may end, and free it, before the moment comes).
func _later(seconds: float, node: Node, what: Callable) -> void:
	var id := node.get_instance_id()
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		var n := instance_from_id(id) as Node
		if n != null and is_instance_valid(n):
			what.call(n))


## A fighter goes down: the pack's own death animation, then monsters fade from the ground.
func _fall(unit: Dictionary) -> void:
	var node: MeshInstance3D = unit["node"]
	if not is_instance_valid(node):
		return
	_say("%s falls." % String(unit["name"]))
	for c in node.get_children():
		if c is Node3D and not (c as Node3D).rotation.is_zero_approx() or c.has_method("set_tint"):
			(c as Node3D).visible = false      # hands and sword: the death pictures do not hold them
	if Art.has_anim(String(unit["sprite"]), "death"):
		node.call("play", "death")
	await _wait(0.55)
	if String(unit["side"]) == "foes":
		node.visible = false


## A number or a word that floats up from a fighter.
func _float(unit: Dictionary, text: String, colour: Color) -> void:
	var l := UI.label(text, "Head")
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", UI.C_INK)
	l.add_theme_constant_override("outline_size", 4)
	_root.add_child(l)
	var p: Vector2 = stage.cam.unproject_position((unit["home"] as Vector3) + Vector3(0.0, float(unit["top"]) + 0.4, 0.0))
	l.position = p - Vector2(l.get_minimum_size().x * 0.5, 14.0)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 16.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ the end
func _finish() -> void:
	_over = true
	_menu.visible = false
	var outcome := String(fight.call("result"))
	var summary := {"spot": spot, "story": story, "rounds": int(fight.round_no), "xp": 0, "coins": 0, "gear": "", "levels": 0}
	var lines: Array = []
	var head := "Victory!"
	if outcome == "win":
		var reward := Battles.reward(fight.foes, _tier)
		reward["xp"] = int(reward["xp"]) + _xp_bonus
		summary.merge(reward, true)
		var before := Rpg.level()
		summary["levels"] = Rpg.add_xp(int(reward["xp"]))
		Save.hub_set("bank:coins", Save.hub_get("bank:coins") + int(reward["coins"]))
		lines.append("+%d XP" % int(reward["xp"]))
		lines.append("+%d coins" % int(reward["coins"]))
		if int(summary["levels"]) > 0:
			lines.append("Level %d!  %d points to spend on the Knight page" % [Rpg.level(), Rpg.points()])
			for lvl in range(before + 1, Rpg.level() + 1):
				for s: Dictionary in Skills.learn_at(lvl):
					lines.append("New skill: %s" % String(s["name"]))
			Skills.fill_empty()
		if String(reward["gear"]) != "" and Gear.grant(String(reward["gear"])):
			lines.append("Found: %s" % String(Gear.row(String(reward["gear"]))["name"]))
		Save.flush()
		Sfx.play("victory_sting", -6.0)
	elif outcome == "lose":
		head = "You fall..."
		lines.append("Somebody carries you back to your bed.")
		lines.append("Nothing is lost.")
	else:
		outcome = "fled"
		head = "You got away"
	if _auto:
		print("[battle] result=%s rounds=%d xp=%d coins=%d party_hp=%s" % [outcome, int(fight.round_no), int(summary["xp"]), int(summary["coins"]),
			(fight.party as Array).map(func(u: Dictionary) -> int: return int(u["hp"]))])
		finished.emit(outcome, summary)
		return
	if outcome == "fled":
		await _wait(0.3)
		finished.emit(outcome, summary)
		return
	_say("")
	var panel := UI.panel("panel")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_area.add_child(panel)
	var col := UI.vbox(3)
	panel.add_child(col)
	var title := UI.label(head, "Head")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UI.C_GOLD if outcome == "win" else UI.C_RED)
	col.add_child(title)
	for line: String in lines:
		var l := UI.label(line, "Hud")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var go := UI.button("Continue", func() -> void: finished.emit(outcome, summary), "", "ui_start")
	go.custom_minimum_size = Vector2(90, 20)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(go)
	UI.pop_in(panel)
	go.grab_focus.call_deferred()


## The phone's Back button, Esc or B: one step back in the menu (never out of the fight).
func on_back() -> void:
	if not _acting.is_empty() and _menu.visible:
		_show_commands()


func _take_shot() -> void:
	if _shot_done or G.arg("shots", "") == "" or not G.args.has("battle"):
		return
	_shot_done = true
	await get_tree().create_timer(0.6).timeout
	var dir := G.arg("shots", "")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("battle.png"))
	if G.flag("shotmenu"):
		_show_skills()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_skills.png"))
	G.quit(0)


func _process(delta: float) -> void:
	_t += delta
	# the camera breathes a little from side to side: it shows the depth of the place
	# the shake: decays in real time (also during a freeze), moves by trauma squared on smooth waves
	var real := delta / maxf(Engine.time_scale, 0.0001)
	_trauma = maxf(_trauma - 1.5 * real, 0.0)
	_shake_t += real * 30.0
	var shake := _trauma * _trauma * (1.0 if bool(Save.setting("shake")) else 0.0)
	var jolt := Vector3(0.42 * sin(_shake_t * 1.7), 0.26 * sin(_shake_t * 2.3), 0.0) * shake
	stage.cam.position = _cam_home + Vector3(sin(_t * 0.25) * 0.45, 0.0, 0.0) + jolt
	stage.cam.look_at(Stage.AIM, Vector3.UP)
	for tag: Dictionary in _tags:
		var u: Dictionary = tag["unit"]
		var b: Button = tag["button"]
		var p: Vector2 = stage.cam.unproject_position((u["home"] as Vector3) + Vector3(0.0, float(u["top"]), 0.0))
		b.position = (p - Vector2(b.size.x * 0.5, 2.0)).round()
