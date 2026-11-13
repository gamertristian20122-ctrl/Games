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
const Hd = preload("res://scripts/fx/hd.gd")
const Actor = preload("res://scripts/battle/anim_actor.gd")
const Moves = preload("res://scripts/battle/anim_moves.gd")
const Shatter = preload("res://scripts/battle/anim_death.gd")
const Num = preload("res://scripts/battle/anim_numbers.gd")
## FAST-FORWARD: while the fight plays out (not while you choose), holding Space, Shift, Enter, the
## mouse button, a finger on the screen, or A / the right shoulder of a pad plays it this much faster.
const FF_SPEED := 3.0
const FF_HOLD := 0.18              ## held this long first (a tap that picked an order is not a hold)
## HD (PC): as the battle opens the camera comes DOWN out of the sky (clouds, stars and the moon by
## night) onto the clearing: where it looks first, relative to where it ends up.
const SKY_LOOK := Vector3(0.0, 15.0, -16.0)

## Each side stands in a deep diagonal (front near the middle and the camera, the rest stepping back
## and out), with a broad open floor between them where the spells land.
const PARTY_AT := [Vector3(-3.2, 0.0, 1.9), Vector3(-5.8, 0.0, -0.4), Vector3(-8.3, 0.0, -2.4), Vector3(-10.0, 0.0, 1.0)]
const FOES_AT := [Vector3(3.2, 0.0, 1.9), Vector3(5.8, 0.0, -0.4), Vector3(8.3, 0.0, -2.4), Vector3(10.0, 0.0, 1.0)]
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
var _fx_id := ""                   ## and that skill's id (HD: a storm brings lightning)
var _trauma := 0.0                 ## how shaken the camera is, 0 to 1 (see _feel)
var _shake_t := 0.0
var _xp_bonus := 0                ## a battle of the story may give XP of its own on top
var _marker: MeshInstance3D        ## the ring of light under the one whose turn it is
var _arrow: Polygon2D              ## and the little arrow over his head
var _turn_unit := {}
var _boss_bar := {}                ## a boss's own bar at the top of the screen
var _intro := 0.0                  ## the camera comes in from further back as the battle opens (1 -> 0)
var _push := 0.0                   ## and moves in a little at the end of a won battle (0 -> 1)
var _fade: ColorRect               ## black over the screen at the start, gold at a victory
var _sky := 0.0                    ## HD: how far up into the sky the camera still looks as the battle opens (1 -> 0)
var _layer: CanvasLayer
var _ui := 1.0                     ## HD: the menus are drawn smaller (a whole number of screen pixels per art pixel)
var moves: Node                    ## the choreography of every blow and spell (scripts/battle/anim_moves.gd)
var _dying := 0                    ## falls still being shown (a turn waits for them)
var _punch := 0.0                  ## the camera's punch-in on a crit or a finishing blow (0 to 1)
var _punch_at := Vector3.ZERO
var _track := 0.0                  ## the camera leaning towards where the action is (0 to 1)
var _track_at := Vector3.ZERO
var _track_zoom := 0.0             ## + moves in, - pulls back (a boss's big move)
var _track_id := 0
var _stop_k := 1.0                 ## the hit-stop's share of the time scale
var _ff := 1.0                     ## and the fast-forward's
var _hold_t := 0.0
var _ff_hint: Label
var _combo := {}                   ## a combo's one counting number, by the fighter hit
var _plan: Array = []              ## test: --animplan=lunge,slam,thessaly:volley (what the bot picks, in order)


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
	moves = Moves.new()
	moves.name = "Moves"
	add_child(moves)
	moves.call("setup", self)
	if G.arg("animplan", "") != "":
		_plan = G.arg("animplan", "").split(",", false)
	if G.flag("animfrail"):
		for u: Dictionary in fight.party:      # test: the defeat, quickly (a look only)
			u["hp"] = 1
	if G.flag("animmana"):
		for u: Dictionary in fight.party:      # test: mana for every skill of --animplan (a look only)
			u["max_mp"] = 999
			u["mp"] = 999
	var party: Array = fight.party
	var foes: Array = fight.foes
	for i in party.size():
		_place(party[i], PARTY_AT[i], false)
	for i in foes.size():
		# a boss stands alone in the middle of its side
		_place(foes[i], Vector3(4.6, 0.0, 0.4) if bool(foes[i].get("boss", false)) else FOES_AT[i], true)
	_build_screen()
	_marker = stage.call("ground_glow", Vector3.ZERO, Color(1.0, 0.82, 0.4, 0.75), 1.25, 0.0, true)
	_marker.visible = false
	_refresh()
	_enter()
	_run.call_deferred(title)


## THE WAY IN: the screen opens from black while the camera glides in to its place.
func _enter() -> void:
	if _speed > 4.0:
		return
	_intro = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_intro", 0.0, 1.4 if Hd.on() else 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if Hd.on():
		_sky = 1.0
		var ts := create_tween()
		ts.tween_interval(0.25)
		ts.tween_property(self, "_sky", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.visible = true
	var tf := create_tween()
	tf.tween_property(_fade, "color:a", 0.0, 0.45 if Hd.on() else 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tf.tween_callback(func() -> void: _fade.visible = false)
	if G.flag("shotintro") and G.arg("shots", "") != "":
		# test: --shotintro writes battle_intro.png while the camera still looks at the sky
		await get_tree().create_timer(float(G.arg("introwait", "0.45"))).timeout
		DirAccess.make_dir_recursive_absolute(G.arg("shots", ""))
		get_viewport().get_texture().get_image().save_png(G.arg("shots", "").path_join("battle_intro.png"))


# ------------------------------------------------------------------ the fighters on the stage
func _place(unit: Dictionary, at: Vector3, faces_left: bool) -> void:
	var body: MeshInstance3D = stage.call("stand", String(unit["sprite"]), at, faces_left)
	var tint: Color = unit.get("tint", Color.WHITE)
	body.call("set_tint", tint)
	unit["node"] = body
	unit["home"] = at
	unit["sword"] = null
	unit["hands"] = []
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
		unit["sword"] = sword
		unit["blade"] = (Art.size(String(hero["weapon"])).y - float(hero.get("grip", 3))) * PX
	elif String(unit["side"]) == "party":
		hands = String(Allies.row(String(unit["id"])).get("hands", ""))
	else:
		hands = String(Enemies.info(String(unit["id"])).get("hands", ""))
	if hands != "" and Art.has(hands):
		for side: float in [-1.0, 1.0]:
			var hand := Sprite3.make(hands)
			hand.position = Vector3(side * (bw * 0.5 + 0.02), bh * 0.3, 0.035)
			hand.set_meta("rest", hand.position)
			hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hand.call("set_tint", tint)
			body.add_child(hand)
			(unit["hands"] as Array).append(hand)
	# HOW IT MOVES (scripts/battle/anim_moves.gd) and the colour of its arcs of light
	unit["style"] = _style(unit)
	unit["colour"] = _colour(unit)
	var actor := Actor.new()
	add_child(actor)
	actor.call("setup", body, at, hash(String(unit["id"])) + int(at.x * 10.0))
	if String(unit["side"]) == "foes" and not bool(unit.get("boss", false)) and float(Enemies.info(String(unit["id"])).get("hover", 0.0)) > 0.0:
		actor.set("bob", 0.07)
	unit["actor"] = actor


## How a fighter moves in a battle (see the header of scripts/battle/anim_moves.gd).
func _style(unit: Dictionary) -> String:
	if bool(unit.get("boss", false)):
		return "boss"
	var id := String(unit["id"])
	if id == "knight":
		return "blade"
	if String(unit["side"]) == "party":
		return "archer" if id == "thessaly" else "mage"
	var sprite := String(unit["sprite"])
	if Art.has_anim(sprite, "attack"):
		return "bat"
	var row := Enemies.info(id)
	if row.has("shot") or String(row.get("ai", "")) == "shooter":
		return "archer" if (sprite.contains("ranger") or sprite.contains("hunter") or sprite.contains("archer")) else "caster"
	return "brute"


## The colour of a fighter's arcs, streaks and after-images.
func _colour(unit: Dictionary) -> Color:
	match String(unit["id"]):
		"knight":
			return Color(1.0, 0.84, 0.5)
		"thessaly":
			return Color(0.55, 1.0, 0.62)
		"sera":
			return Color(1.0, 0.8, 0.38)
	if bool(unit.get("boss", false)):
		return Color(1.0, 0.3, 0.14)
	match String(unit.get("style", "")):
		"caster":
			return Color(0.78, 0.45, 1.0)
		"archer":
			return Color(0.7, 1.0, 0.55)
	return Color(1.0, 0.42, 0.24)


# ------------------------------------------------------------------ the screen
func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_layer = layer
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	if Hd.on():
		# HD (PC): COMPACT menus in the corners, so the big fighters, the ground and the sky stay
		# clear (the night-battle picture the owner sent keeps its numbers small, at the edges).
		# The phone keeps its sizes (the owner: text and buttons are good as they are there).
		_fit_ui()
		get_viewport().size_changed.connect(_fit_ui)
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

	# your side (bottom left; HD: top right, as a column of small rows)
	var party_panel := UI.panel("panel")
	if Hd.on():
		party_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		party_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		party_panel.self_modulate.a = 0.82
	else:
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

	# what you can do (bottom right; HD: bottom left, under your own side)
	_menu = UI.panel("panel")
	if Hd.on():
		_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_menu.self_modulate.a = 0.86
	else:
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
		back.size = Vector2(34, 5)
		back.position = Vector2((button.custom_minimum_size.x - 34.0) * 0.5, -7.0)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(back)
		var well := ColorRect.new()
		well.color = UI.C_PANEL_LOW
		well.position = Vector2(1, 1)
		well.size = Vector2(32, 3)
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(well)
		var lost := ColorRect.new()
		lost.color = Color(1.0, 0.92, 0.75)
		lost.position = Vector2(1, 1)
		lost.size = Vector2(32, 3)
		lost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(lost)
		var fill := ColorRect.new()
		fill.color = UI.C_RED
		fill.position = Vector2(1, 1)
		fill.size = Vector2(32, 3)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fill)
		var gleam := ColorRect.new()
		gleam.color = Color(1.0, 1.0, 1.0, 0.28)
		gleam.size = Vector2(32, 1)
		gleam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(gleam)
		var l := UI.label(String(unit["name"]), "Small")
		l.add_theme_color_override("font_color", UI.C_BONE)
		l.add_theme_color_override("font_outline_color", UI.C_INK)
		l.add_theme_constant_override("outline_size", 3)
		l.visible = false
		button.add_child(l)
		l.position = Vector2((button.custom_minimum_size.x - l.get_minimum_size().x) * 0.5, -17.0 - 9.0 * (i % 2))     # every other name a line higher, so two never share a line
		_tags.append({"unit": unit, "button": button, "fill": fill, "lost": lost, "back": back, "name": l})
		if bool(unit.get("boss", false)):
			back.visible = false           # a boss has its big bar at the top instead
			_make_boss_bar(unit)
		var who := unit
		button.pressed.connect(func() -> void: _target_picked(who))

	# how to speed the fight up (bottom right; hidden while you choose)
	_ff_hint = UI.label("", "Small")
	_ff_hint.add_theme_color_override("font_color", UI.C_BONE)
	_ff_hint.add_theme_color_override("font_outline_color", UI.C_INK)
	_ff_hint.add_theme_constant_override("outline_size", 3)
	_ff_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ff_hint.offset_left = -300.0
	_ff_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ff_hint.offset_right = -2.0
	_ff_hint.offset_top = -12.0
	_ff_hint.offset_bottom = 0.0
	_ff_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ff_hint.visible = false
	_area.add_child(_ff_hint)

	# the arrow over the one whose turn it is
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(0, 2)])
	_arrow.color = UI.C_GOLD
	var rim_line := Line2D.new()
	rim_line.points = PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(0, 2), Vector2(-5, -4)])
	rim_line.width = 1.0
	rim_line.default_color = UI.C_INK
	_arrow.add_child(rim_line)
	_arrow.visible = false
	_root.add_child(_arrow)

	# what covers the screen on the way in and at the end
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_root.add_child(_fade)


## HD: the menus at a smaller size. The game's 2D picture is 180 art pixels high, stretched to the
## window; here every art pixel of the menus is drawn as a whole number of screen pixels, about
## three quarters of the usual (3 on a 720-high window, 4 on 1080), so pixel letters stay crisp.
func _fit_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size()) if get_viewport() == get_tree().root else vp
	var base := maxf(win.y / maxf(vp.y, 1.0), 1.0)          # screen pixels per art pixel
	var k := maxf(floorf(base * 0.75), minf(2.0, base))
	_ui = clampf(k / base, 0.4, 1.0)
	_layer.scale = Vector2(_ui, _ui)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = Vector2.ZERO
	_root.size = vp / _ui


## Where a point of the 3D picture is on the menus' layer.
func _on_ui(world: Vector3) -> Vector2:
	return stage.cam.unproject_position(world) / _ui


## A boss gets its name and a long bar at the top middle of the screen.
func _make_boss_bar(unit: Dictionary) -> void:
	var box := UI.vbox(1)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 2
	# (left of the middle: a big boss stands on the right, its head must not sit under its own bar)
	box.offset_left -= 56
	box.offset_right -= 56
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(box)
	var name_label := UI.label(String(unit["name"]), "Hud")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", UI.C_GOLD)
	name_label.add_theme_color_override("font_outline_color", UI.C_INK)
	name_label.add_theme_constant_override("outline_size", 3)
	box.add_child(name_label)
	var back := ColorRect.new()
	back.color = UI.C_INK
	back.custom_minimum_size = Vector2(162, 7)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	var well := ColorRect.new()
	well.color = UI.C_PANEL_LOW
	well.position = Vector2(1, 1)
	well.size = Vector2(160, 5)
	back.add_child(well)
	var lost := ColorRect.new()
	lost.color = Color(1.0, 0.92, 0.75)
	lost.position = Vector2(1, 1)
	lost.size = Vector2(160, 5)
	back.add_child(lost)
	var fill := ColorRect.new()
	fill.color = UI.C_BLOOD.lerp(UI.C_RED, 0.5)
	fill.position = Vector2(1, 1)
	fill.size = Vector2(160, 5)
	back.add_child(fill)
	var gleam := ColorRect.new()
	gleam.color = Color(1.0, 1.0, 1.0, 0.25)
	gleam.size = Vector2(160, 1)
	fill.add_child(gleam)
	_boss_bar = {"unit": unit, "fill": fill, "lost": lost, "width": 160.0}
	_message.offset_top = 32               # the words move down under the bar


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
		_drain(tag["fill"], tag["lost"], 32.0 * float(u["hp"]) / float(u["max_hp"]))
		(tag["button"] as Button).visible = int(u["hp"]) > 0
	if not _boss_bar.is_empty():
		var bu: Dictionary = _boss_bar["unit"]
		_drain(_boss_bar["fill"], _boss_bar["lost"], float(_boss_bar["width"]) * maxf(float(bu["hp"]), 0.0) / float(bu["max_hp"]))
	_turn_unit = acting
	if _marker != null:
		_marker.visible = not acting.is_empty() and not _over
		if _marker.visible:
			var at: Vector3 = acting["home"]
			_marker.position = Vector3(at.x, 0.04, at.z)
			var c := Color(1.0, 0.82, 0.4) if String(acting["side"]) == "party" else Color(1.0, 0.36, 0.28)
			(_marker.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.75)
			_marker.scale = Vector3.ONE * clampf(float(acting["wide"]) * 1.1, 0.8, 2.6)
	for c in _order_row.get_children():
		c.queue_free()
	if acting.is_empty():
		return
	var line: Array = [acting]
	line.append_array(fight.call("upcoming"))
	for i in mini(line.size(), 7):
		var u: Dictionary = line[i]
		var slot := UI.panel("slot_focus" if i == 0 else "slot")
		slot.custom_minimum_size = Vector2(21, 21) if i == 0 else Vector2(17, 17)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		# a coloured line under each face: blue = your side, red = a monster
		var side_line := ColorRect.new()
		side_line.color = UI.C_BLUE if String(u["side"]) == "party" else UI.C_RED
		side_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side_line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		side_line.offset_top = 1
		side_line.offset_bottom = 3
		slot.add_child(side_line)
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


## Only the bars of one fighter (the moment a blow lands on him, not before).
func _refresh_one(u: Dictionary) -> void:
	for row: Dictionary in _party_rows:
		if is_same(row["unit"], u):
			(row["hp"]["text"] as Label).text = "HP %d/%d" % [int(u["hp"]), int(u["max_hp"])]
			(row["hp"]["fill"] as ColorRect).size.x = 46.0 * float(u["hp"]) / float(u["max_hp"])
			(row["mp"]["text"] as Label).text = "MP %d/%d" % [int(u["mp"]), int(u["max_mp"])]
	for tag: Dictionary in _tags:
		if is_same(tag["unit"], u):
			_drain(tag["fill"], tag["lost"], 32.0 * float(u["hp"]) / float(u["max_hp"]))
			(tag["button"] as Button).visible = int(u["hp"]) > 0
	if not _boss_bar.is_empty() and is_same(_boss_bar["unit"], u):
		_drain(_boss_bar["fill"], _boss_bar["lost"], float(_boss_bar["width"]) * maxf(float(u["hp"]), 0.0) / float(u["max_hp"]))


## Your side's row in the corner jolts and flashes red when that fighter is hit (you see who it was
## at a glance, even with your eyes on the menu).
func _row_jolt(u: Dictionary, ratio: float) -> void:
	for row: Dictionary in _party_rows:
		if not is_same(row["unit"], u):
			continue
		var b: Button = row["button"]
		var tw := b.create_tween()
		b.modulate = Color(1.0, 0.45, 0.4)
		tw.tween_property(b, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var name_label: Label = row["name"]
		var kick := 2.0 + 4.0 * ratio
		var tl := name_label.create_tween()
		for i in 4:
			tl.tween_property(name_label, "position:x", name_label.position.x + kick * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.22), 0.03)
		tl.tween_property(name_label, "position:x", name_label.position.x, 0.03)


## A bar falls to its new length at once; a pale piece behind it shows what was lost, then drains.
func _drain(fill: ColorRect, lost: ColorRect, width: float) -> void:
	width = maxf(width, 0.0)
	var was := fill.size.x
	fill.size.x = width
	if width >= was or _speed > 4.0:
		lost.size.x = width
		return
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(lost, "size:x", width, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


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
	grid.columns = 4 if Hd.on() else 2          # (HD: one low row along the bottom, under every fighter's feet)
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
	var l := UI.label(text, "Small", 236.0 if Hd.on() else 150.0)
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
	if Hd.on():
		grid.columns = clampi((_acting["skills"] as Array).size(), 1, 4)
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
	await _wait(1.45 if Hd.on() and _speed <= 4.0 else 0.9)      # (HD: the camera comes down out of the sky first)
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
				action = _planned(who)
				if action.is_empty():
					action = fight.call("auto_choice", who)
			else:
				_acting = who
				_say("")
				_show_commands()
				_take_shot()
				action = await _picked
			events = fight.call("act", who, action)
		else:
			await _wait(0.25)          # (a short quiet beat, then the monster's own wind-up)
			events = fight.call("act", who, fight.call("foe_choice", who))
		await _play(events)
		_refresh()
	await _finish()


## Test: --animplan=lunge,slam,thessaly:volley,guard picks the bot's orders in that order (an id
## alone is the knight's; "attack" and "guard" are orders too). A look only: the fight's rules apply.
func _planned(who: Dictionary) -> Dictionary:
	for i in _plan.size():
		var item := String(_plan[i])
		var owner := "knight"
		if item.contains(":"):
			owner = item.get_slice(":", 0)
			item = item.get_slice(":", 1)
		if owner != String(who["id"]):
			continue
		_plan.remove_at(i)
		var foes: Array = fight.call("alive", fight.foes)
		if item == "guard":
			return {"do": "guard"}
		for sk: Dictionary in who["skills"]:
			if String(sk["id"]) == item and bool(fight.call("can_use", who, sk)):
				var aim := String(sk.get("aim", "foe"))
				return {"do": "skill", "skill": sk, "target": who if aim == "friend" else foes[0]}
		return {"do": "attack", "target": foes[0]}
	return {}


## Shows what a turn did: the whole move of the one who acts (scripts/battle/anim_moves.gd), which
## calls impact() at the moment each blow lands.
func _play(events: Array) -> void:
	if events.is_empty():
		return
	var first: Dictionary = events[0]
	var who: Dictionary = first.get("who", {})
	if _marker != null:
		_marker.visible = false
	_turn_unit = {}                    # (the arrow over his home spot would stay behind while he moves)
	if _speed > 4.0:
		await _play_quick(events)
		return
	match String(first["type"]):
		"skill":
			_say("%s: %s!" % [String(who["name"]), String(first["skill"]["name"])])
			Sfx.play("ui_start", -8.0)
			_fx = Battles.FX.get(String(first["skill"].get("id", "")), [])
			_fx_id = String(first["skill"].get("id", ""))
			await moves.call("turn", who, events)
		"hit", "miss":
			_say("%s strikes %s." % [String(who["name"]), String(first["target"]["name"])])
			await moves.call("turn", who, events)
		"guard":
			_say("%s guards." % String(who["name"]))
			_float(who, "Guard", UI.C_ICE)
			await moves.call("turn", who, events)
		"stunned":
			_say("%s cannot move." % String(who["name"]))
			_float(who, "...", UI.C_ICE)
			var a: Node = who["actor"]
			var tw := a.create_tween()
			for i in 4:
				tw.tween_property(a, "lean", 0.08 * (1.0 if i % 2 == 0 else -1.0), 0.07)
			tw.tween_property(a, "lean", 0.0, 0.07)
			await _wait(0.4)
		"flee":
			_say("You get away." if bool(first["ok"]) else "No way out!")
			Sfx.play("ui_back")
			if bool(first["ok"]):
				for u: Dictionary in fight.call("alive", fight.party):
					(u["node"] as Node).call("set_flip", true)
					var tf := (u["actor"] as Node).create_tween()
					tf.tween_property(u["actor"], "offset", Vector3(-4.0, 0.0, 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			else:
				var a: Node = who["actor"]
				var tf := a.create_tween()
				tf.tween_property(a, "offset", Vector3(-0.8, 0.0, 0.0), 0.15)
				tf.tween_property(a, "offset", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			await _wait(0.6)
		"say":
			_say(String(first["text"]))
			await _wait(0.5)
	# a turn is over when every fall it caused has been shown
	var guard_t := 0.0
	while _dying > 0 and guard_t < 4.0:
		await get_tree().process_frame
		guard_t += get_process_delta_time()
	_fx = []
	_combo.clear()
	# (a spell's vortex, streaks and column burn on for a second or more: the next fighter began 0.3 s
	# after the impact and the fight turned to soup. A spell's turn lets its light die down first)
	var spelled := String(first["type"]) == "skill" and not ["whirl", "lunge", "slam", "cry", "sweep", "pierce", "volley", "guard"].has(String(first["skill"].get("id", "")))
	await _wait(0.6 if spelled else 0.06)


## The test bot at high speed: the same events, nothing to see.
func _play_quick(events: Array) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"hit":
				_refresh()
				if bool(e["dead"]) and String(e["target"]["side"]) == "foes" and is_instance_valid(e["target"]["node"]):
					(e["target"]["node"] as Node3D).visible = false
				await _wait(0.1)
			"flee", "say":
				await _wait(0.3)
			_:
				await _wait(0.05)
	_fx = []


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
			var width := 0.5 + 0.25 * power
			if Hd.on():
				width = maxf(width, float(target["wide"]) * 2.4)    # (HD: it stands behind the one hit, so it must be wider to glow round it)
			stage.call("pillar", target["home"], colour, width, 9.0, target["node"], _fx_id)
			stage.call("burst", at, colour, power, 0.0, "", target["node"])
		"rise":
			stage.call("burst", (target["home"] as Vector3) + Vector3(0.0, 0.2, 0.15), colour, power, 1.6)
		_:
			stage.call("burst", at, colour, power, 0.0, "", target["node"])


## THE MOMENT A BLOW LANDS (called by scripts/battle/anim_moves.gd). Everything the one hit does:
##   a flash (white; gold on a crit), the pack's hit animation, a KNOCK-BACK away from the blow and
##   a recoil lean, a squash, sparks in the striker's colour (or the spell's light), a number that
##   pops and arcs, the bar draining, and the feel: HIT-STOP (a freeze of a few hundredths of a
##   second) and SCREEN SHAKE, both scaled by how much of its health the blow took; a camera
##   PUNCH-IN on a critical blow and on a finishing blow. A fall starts here too.
## opts: "from" (who struck), "part"/"parts" (a combo: blow i of n; the number counts up and the
## full weight lands on the last), "fx" (show the skill's spell light), "launch" (thrown upward).
func impact(e: Dictionary, opts: Dictionary = {}) -> void:
	var target: Dictionary = e.get("target", {})
	if target.is_empty() or not is_instance_valid(target.get("node")):
		return
	var who: Dictionary = opts.get("from", e.get("who", {}))
	match String(e["type"]):
		"hit":
			_hit(e, target, who, opts)
		"miss":
			_float(target, "Miss", UI.C_DIM)
			Sfx.play("player_shoot_knife", -14.0, 0.1, 1.4)
			var a: Node = target["actor"]
			var d := _away(target, who)
			var tw := a.create_tween()
			tw.tween_method(func(t: float) -> void: a.set("lift", 0.35 * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.28)
			tw.parallel().tween_property(a, "kick", Vector3(d * 0.6, 0.0, 0.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(a, "kick", Vector3.ZERO, 0.22)
		"heal":
			if bool(opts.get("fx", false)):
				_show_fx(target)
			else:
				stage.call("burst", (target["home"] as Vector3) + Vector3(0.0, 0.2, 0.15), Color(0.5, 1.0, 0.6), 1.4, 1.6)
			_float(target, "+%d" % int(e["amount"]), UI.C_GREEN, {"heal": true})
			Sfx.play("pickup", -6.0)
			var node: Node = target["node"]
			node.call("set_flash", 0.45, Color(0.6, 1.0, 0.65))
			_later(0.25, node, func(n: Node) -> void: n.call("set_flash", 0.0))
			_refresh_one(target)
		"stun":
			if not _fx.is_empty() and String(_fx[1]) == "rise":
				_show_fx(target)
			_float(target, "Stunned", UI.C_ICE)
			stage.call("ground_glow", target["home"], Color(0.6, 0.85, 1.0, 0.8), 1.0, 0.5, true)
			var a: Node = target["actor"]
			var tw := a.create_tween()
			for i in 3:
				tw.tween_property(a, "lean", 0.12 * (1.0 if i % 2 == 0 else -1.0), 0.06)
			tw.tween_property(a, "lean", 0.0, 0.08)


## Which way a blow from `who` throws `target` (+1 = to the right of the screen).
func _away(target: Dictionary, who: Dictionary) -> float:
	if who.is_empty():
		return 1.0 if String(target["side"]) == "foes" else -1.0
	var d := signf((target["home"] as Vector3).x - (who["home"] as Vector3).x)
	return d if d != 0.0 else (1.0 if String(target["side"]) == "foes" else -1.0)


func _hit(e: Dictionary, target: Dictionary, who: Dictionary, opts: Dictionary) -> void:
	var part := int(opts.get("part", 0))
	var parts := maxi(int(opts.get("parts", 1)), 1)
	var last := part >= parts - 1
	var amount := int(e["amount"])
	var shown := amount if last else maxi(1, roundi(float(amount) * float(part + 1) / float(parts)))
	var ratio := clampf(float(amount) / maxf(float(target["max_hp"]), 1.0), 0.0, 1.0)
	var crit := bool(e["crit"]) and last
	var dead := bool(e["dead"]) and last
	var weight := (1.0 if last else 0.45)
	var d := _away(target, who)
	var node: Node = target["node"]
	var a: Node = target["actor"]
	var big_one := bool(target.get("boss", false))
	# sound
	if String(target["side"]) == "party":
		Sfx.play("player_hurt", -6.0)
	Sfx.play("hit", -3.0 if last else -8.0, 0.1, 0.85 if crit else 1.0)
	if crit:
		Sfx.play("explosion", -14.0, 0.05, 1.6)
	# light and sparks where it lands
	var at: Vector3 = a.call("centre", float(target["top"]))
	at.z += 0.15
	if bool(opts.get("fx", false)) and not _fx.is_empty():
		_show_fx(target)
	elif _speed <= 4.0:
		var c: Color = who.get("colour", Color.WHITE) if not who.is_empty() else Color.WHITE
		# (a sword, a claw, a bite or an arrow lands as a blade blow: the white-hot slash and its sparks
		# from fx_impact.gd; a caster's bolt keeps the element its colour names)
		var element := "" if String(who.get("style", "")) == "caster" else "blade"
		stage.call("burst", at, c.lerp(Color.WHITE, 0.4), minf((0.55 + 0.9 * ratio + (0.5 if crit else 0.0)) * weight + 0.15, 1.6 if crit else 1.3), 0.0, "", node, element)
		# a heavy blow kicks up the ground under the one hit
		if last and (ratio >= 0.3 or crit or dead):
			stage.call("dust", target["home"], (0.5 + 0.8 * ratio + (0.3 if crit else 0.0)) * (1.4 if big_one else 1.0))
	# the flash (gold on a crit), and the pack's own hit animation
	# (the flash shines by itself only a little: a big picture flashing hot blooms into a white blob)
	var strength := 1.0 if crit else (0.55 if big_one else 0.8)
	var party_hit := String(target["side"]) == "party"
	# (a white albedo under the blow's own lights blooms; a flash at 0.8 that also shone by itself
	# turned the one hit into a white slab taller than him at night, and on the phone into a pink
	# blob. The flash now lifts his own pixels half way (sprite3.gd keeps the ink outline) and does
	# not shine; one of your side flashes a hurt red instead of white)
	if party_hit:
		node.call("set_flash", 0.4, Color(1.0, 0.42, 0.32), 0.12)
	else:
		node.call("set_flash", minf(strength * 0.5, 0.45), Color(1.0, 0.85, 0.45) if crit else Color.WHITE, 0.0)
	# (ended on REAL time: the hit-stop slows the game to 0.04, and on game time it held the flash
	# for the whole freeze. One or two frames, whatever the freeze does)
	_later(0.035 if party_hit else (0.045 if not crit else 0.07), node, func(n: Node) -> void: n.call("set_flash", 0.0), true)
	if Art.has_anim(String(target["sprite"]), "hit") and int(target["hp"]) > 0:
		node.call("play", "hit")
		_later(0.36, node, func(n: Node) -> void:
			if int(target["hp"]) > 0:
				n.call("play", "idle"))
	# knock-back, recoil and squash (a boss barely moves; a launched one leaves the ground)
	var shove := (0.18 + 0.55 * ratio + (0.3 if crit else 0.0) + 0.35 * float(opts.get("launch", 0.0))) * weight * (0.35 if big_one else 1.0)
	var lean_by := (0.16 + 0.3 * ratio) * weight * (0.4 if big_one else 1.0)
	if party_hit:
		# (one of your side takes a blow with weight: thrown back 0.4+, leaning well back, a dip down)
		shove = maxf(shove, 0.42 * weight)
		lean_by = maxf(lean_by, 0.35 * weight)
	var tw := a.create_tween().set_parallel(true)
	a.set("kick", Vector3(d * shove * 0.45, 0.0, 0.0))
	tw.tween_property(a, "kick", Vector3(d * shove, -0.06 if party_hit else 0.0, 0.0), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(a, "lean", -d * lean_by, 0.05)
	tw.tween_property(a, "squash", Vector2(0.95, 1.04) if not big_one else Vector2(0.97, 1.02), 0.05)
	if float(opts.get("launch", 0.0)) > 0.0 and not big_one:
		var up := 0.7 * float(opts.get("launch", 0.0))
		tw.tween_method(func(t: float) -> void: a.set("lift", up * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.36)
	var back := a.create_tween().set_parallel(true)
	back.tween_interval(0.07)
	back.chain().tween_property(a, "kick", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(a, "lean", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	back.tween_property(a, "squash", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# the number: a combo keeps one that counts up
	var key := String(target["id"]) + str(target["home"])
	if parts > 1 and part > 0 and _combo.has(key) and is_instance_valid(_combo[key]):
		Num.bump(_combo[key], ("%d" % shown), Color(1.0, 0.85, 0.35) if crit else Color(0, 0, 0, 0))
	else:
		var l := _float(target, ("%d" % shown), UI.C_GOLD if crit else UI.C_BONE, {"dir": d, "crit": crit, "hold": 0.22 * float(parts - 1 - part)})
		if parts > 1:
			_combo[key] = l
	if last:
		_refresh_one(target)
		if String(target["side"]) == "party":
			_row_jolt(target, ratio)
	# the feel: freeze and shake by how much it took, a punch-in on a crit or a finishing blow
	if _speed <= 4.0:
		var trauma := (0.16 + 0.85 * ratio + (0.25 if crit else 0.0) + (0.15 if dead else 0.0)) * weight
		if String(target["side"]) == "party":
			trauma *= 1.2
		shake(trauma)
		var stop := (0.035 + 0.1 * ratio + (0.05 if crit else 0.0) + (0.06 if dead else 0.0)) if last else 0.025
		_hit_stop(minf(stop, 0.2))
		var finishing := dead and (big_one or (fight.call("alive", fight.foes) as Array).is_empty())
		if crit or finishing:
			punch(at, 1.0)
		elif dead:
			punch(at, 0.45)
	if dead:
		_die(target, who)


## A FALL. A monster: it flashes white, is thrown back, plays the pack's death animation where there
## is one, then breaks into its own pixels (scripts/battle/anim_death.gd); a boss first burns away
## in slow motion with embers. One of your side: his death animation or a topple, and he stays down.
func _die(u: Dictionary, killer: Dictionary) -> void:
	_dying += 1
	var node: MeshInstance3D = u["node"]
	var a: Node = u["actor"]
	a.set("breath", 0.0)
	_say("%s falls." % String(u["name"]))
	for c in node.get_children():
		if c is Node3D and (c == u.get("sword") or (u["hands"] as Array).has(c)):
			(c as Node3D).visible = false      # hands and sword: the death pictures do not hold them
	if String(u["side"]) == "party":
		Sfx.play("player_die", -8.0)
		moves.call("collapse", u)
		await _wait(0.45)
		_dying -= 1
		return
	var boss := bool(u.get("boss", false))
	Sfx.play("boss_die" if boss else "enemy_die", -4.0 if boss else -8.0)
	# (a kill flash at 1.0 that shone by itself made the fallen a solid white slab for 5-10 frames
	# under the hit-stop; now half way toward white over his own pixels, ended on real time)
	node.call("set_flash", 0.45, Color.WHITE, 0.0)
	var d := _away(u, killer)
	var tw := a.create_tween().set_parallel(true)
	tw.tween_property(a, "offset", Vector3(d * (0.4 if boss else 0.8), 0.0, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void: a.set("lift", (0.15 if boss else 0.5) * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.32)
	await _wait(0.09)
	if boss and _speed <= 4.0:
		_slow_motion(0.35, 0.9)
	if not is_instance_valid(node):
		_dying -= 1
		return
	var has_death := Art.has_anim(String(u["sprite"]), "death")
	if has_death:
		node.call("play", "death")
	var fade := node.create_tween().set_ignore_time_scale(true)
	fade.tween_method(func(v: float) -> void: node.call("set_flash", v, Color.WHITE, 0.0), 0.35, 0.0, 0.08 if boss else 0.12)
	await _wait(minf(float(node.call("anim_length", "death")), 0.5) if has_death else 0.2)
	if boss and is_instance_valid(node):
		# the boss burns away from the top, embers flying, then breaks
		var burn := node.create_tween()
		burn.tween_method(func(v: float) -> void: node.call("set_dissolve", v, Color(1.0, 0.45, 0.15)), 0.0, 0.55, 0.7)
		for i in 4:
			_later(0.15 * i, node, func(_n: Node) -> void:
				stage.call("burst", (u["home"] as Vector3) + Vector3(randf_range(-1.0, 1.0), float(u["top"]) * randf_range(0.3, 0.9), 0.3), Color(1.0, 0.5, 0.2), 1.6, 0.8))
		shake(0.6)
		await _wait(0.7)
	if is_instance_valid(node) and _speed <= 4.0:
		var sh := Shatter.new()
		stage.add_child(sh)
		sh.call("burst", node, (killer["home"] as Vector3).x if not killer.is_empty() else 0.0, 2.0 if boss else 1.0)
		stage.call("ground_glow", u["home"], Color(1.0, 0.75, 0.45, 0.6), 1.2 if not boss else 2.6, 0.5)
		Sfx.play("rock_break", -14.0, 0.1, 1.5)
	if is_instance_valid(node):
		node.visible = false
	_dying -= 1


## THE FEEL of a blow (kept for the test pictures): a normal one, or a large one.
const FEEL := {"medium": {"trauma": 0.32, "stop": 0.045}, "large": {"trauma": 0.7, "stop": 0.1}}

func _feel(_target: Dictionary, tier: String) -> void:
	if _speed > 4.0:
		return                             # the test bot plays without it
	var f: Dictionary = FEEL[tier]
	shake(float(f["trauma"]))
	_hit_stop(float(f["stop"]))


## SCREEN SHAKE: "trauma" that decays in real time; the camera moves by trauma SQUARED on smooth
## waves (never a random jitter). Settings > Screen shake turns it off.
func shake(amount: float) -> void:
	if _speed > 4.0:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## CAMERA PUNCH-IN: a quick move in on a spot (a crit, a finishing blow), held a moment, eased out.
func punch(at: Vector3, strength: float = 1.0) -> void:
	if _speed > 4.0:
		return
	_punch_at = at
	var tw := create_tween()
	tw.tween_property(self, "_punch", strength, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_property(self, "_punch", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The camera leans towards where the action is for `seconds` (zoom + moves in, - pulls back).
func track(at: Vector3, seconds: float, zoom: float = 0.0) -> void:
	if _speed > 4.0:
		return
	_track_id += 1
	var mine := _track_id
	_track_at = at
	_track_zoom = zoom
	var tw := create_tween()
	tw.tween_property(self, "_track", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(seconds - 0.25, 0.0))
	tw.tween_callback(func() -> void:
		if mine == _track_id:
			var back := create_tween()
			back.tween_property(self, "_track", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


## HIT-STOP: the whole game nearly stops for a few hundredths of a second (only the newest stop
## may end it; the fast-forward shortens it too).
var _stop_id := 0
func _hit_stop(duration: float, slow: float = 0.04) -> void:
	await _slow_motion(slow, duration)


## Slows the whole game to `scale` for `seconds` of real time (a hit-stop; a boss's fall).
func _slow_motion(scale: float, seconds: float) -> void:
	_stop_id += 1
	var mine := _stop_id
	_stop_k = scale
	_apply_time()
	# (process_always, not physics, IGNORE the time scale: or the timer itself would crawl)
	await get_tree().create_timer(seconds / _ff, true, false, true).timeout
	if mine == _stop_id:
		_stop_k = 1.0
		_apply_time()


func _apply_time() -> void:
	var want := _stop_k * _ff
	if not is_equal_approx(Engine.time_scale, want):
		Engine.time_scale = want


func _exit_tree() -> void:
	Engine.time_scale = 1.0                # never leave the game slowed (or sped up) when a battle is freed


## Does something to a fighter's picture a moment later, if the picture is still there then (a
## battle may end, and free it, before the moment comes).
func _later(seconds: float, node: Node, what: Callable, real: bool = false) -> void:
	var id := node.get_instance_id()
	get_tree().create_timer(seconds, false, false, real).timeout.connect(func() -> void:
		var n := instance_from_id(id) as Node
		if n != null and is_instance_valid(n):
			what.call(n))


## A number or a word that pops out of a fighter (scripts/battle/anim_numbers.gd).
func _float(unit: Dictionary, text: String, colour: Color, opts: Dictionary = {}) -> Label:
	var a: Node = unit.get("actor")
	var top: Vector3 = (unit["home"] as Vector3) + Vector3(0.0, float(unit["top"]), 0.0)
	if a != null:
		top = a.call("centre", float(unit["top"])) + Vector3(0.0, float(unit["top"]) * 0.5, 0.0)
	var p: Vector2 = _on_ui(top + Vector3(0.0, 0.35, 0.0))
	# (never off the screen, nor under the words and the boss's bar at the top: a tall boss's head
	# can be out of the picture)
	var room: Vector2 = _root.size
	p = Vector2(clampf(p.x, 24.0, maxf(room.x - 24.0, 24.0)), clampf(p.y, 58.0 if not _boss_bar.is_empty() else 46.0, maxf(room.y - 30.0, 60.0)))
	var o := opts.duplicate()
	if not text.is_valid_int() and not text.begins_with("+"):
		o["word"] = true
	return Num.pop(_root, p, text, colour, o)


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
		Sfx.victory()
	elif outcome == "lose":
		head = "You fall..."
		lines.append("Somebody carries you back to your bed.")
		lines.append("Nothing is lost.")
	else:
		outcome = "fled"
		head = "You got away"
	if _auto and G.flag("animend") and outcome != "fled":
		await _closing(outcome == "win")            # test: the victory poses / the defeat, under the bot too
		await _wait(1.6)
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
	await _closing(outcome == "win")
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


## THE WAY OUT: a won battle flashes gold, the camera moves in on the winners and they hop for
## joy; a lost one sinks into dark red. Then the panel with what was won.
func _closing(won: bool) -> void:
	_marker.visible = false
	_turn_unit = {}
	_fade.get_parent().move_child(_fade, 0)     # under the panel that comes next, over the stage
	_fade.visible = true
	if won:
		for u: Dictionary in fight.call("alive", fight.party):
			stage.call("ground_glow", u["home"], Color(1.0, 0.85, 0.45, 0.6), 1.6, 1.4)
		moves.call("victory", fight.call("alive", fight.party))      # the knight's sword up, the others hop and turn
		_fade.color = Color(1.0, 0.86, 0.5, 0.0)
		var tf := create_tween()
		tf.tween_property(_fade, "color:a", 0.45, 0.08)
		tf.tween_property(_fade, "color:a", 0.0, 0.5)
		tf.tween_property(_fade, "color", Color(0.05, 0.03, 0.02, 0.28), 0.6)
		var tp := create_tween()
		tp.tween_property(self, "_push", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# the defeat: everybody already lies where he fell; the camera sinks slowly, all goes dark red
		_fade.color = Color(0.12, 0.0, 0.02, 0.0)
		var tl := create_tween()
		tl.tween_property(_fade, "color:a", 0.62, 1.0)
		track(Vector3(-4.0, 0.4, 0.5), 2.0, 0.35)
	await _wait(0.75)


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
	if G.arg("shotspell", "") != "":
		# test: --shotspell=<skill id of battles.gd FX> writes battle_spell.png in the middle of that
		# spell's light, landing on the first monster (a look only: nothing in the fight changes)
		_fx = Battles.FX.get(G.arg("shotspell", ""), [])
		_fx_id = G.arg("shotspell", "")
		_menu.visible = false
		_show_fx(fight.foes[0])
		_feel(fight.foes[0], "large")
		await get_tree().create_timer(float(G.arg("spellwait", "0.16")), true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_spell.png"))
		_fx = []
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
	var amp := _trauma * _trauma * (1.0 if bool(Save.setting("shake")) else 0.0)
	var jolt := Vector3(0.42 * sin(_shake_t * 1.7), 0.26 * sin(_shake_t * 2.3), 0.0) * amp
	var glide := Vector3(-1.6, 2.2, 6.5) * _intro * _intro - Vector3(0.0, 1.4, 4.2) * _push
	var pos := _cam_home + Vector3(sin(_t * 0.25) * 0.45, 0.0, 0.0) + glide
	var look: Vector3 = stage.aim + Vector3(0.0, 0.5, 0.0) * _push + SKY_LOOK * _sky
	# the camera leans towards the action (a jump, a boss's blow) and PUNCHES IN on a crit or a
	# finishing blow; the shake goes on top of all of it
	if _track > 0.0:
		look = look.lerp(_track_at, 0.22 * _track)
		pos += (_track_at - pos).normalized() * _track_zoom * 4.0 * _track
	if _punch > 0.0:
		look = look.lerp(_punch_at, 0.45 * _punch)
		pos = pos.lerp(_punch_at, 0.13 * _punch)
	stage.cam.position = pos + jolt
	stage.cam.look_at(look + jolt * 0.4, Vector3.UP)
	_fast_forward(real)
	if _marker != null and _marker.visible:
		var m := _marker.material_override as StandardMaterial3D
		m.albedo_color.a = 0.5 + 0.25 * sin(_t * 4.0)
	_arrow.visible = not _turn_unit.is_empty() and not _over and String(_turn_unit.get("side", "")) == "party"
	if _arrow.visible:
		var head: Vector2 = _on_ui((_turn_unit["home"] as Vector3) + Vector3(0.0, float(_turn_unit["top"]), 0.0))
		_arrow.position = (head + Vector2(0.0, -3.0 + 2.0 * sin(_t * 5.0))).round()
	for tag: Dictionary in _tags:
		var u: Dictionary = tag["unit"]
		var b: Button = tag["button"]
		var stand: Vector3 = (u["actor"] as Node).call("at") if u.get("actor") != null else (u["home"] as Vector3)     # (the bar follows him when he moves)
		var p: Vector2 = _on_ui(stand + Vector3(0.0, float(u["top"]), 0.0))
		if Hd.on():
			# (HD: the frame to tap is as big as the monster really is on the screen)
			var feet: Vector2 = _on_ui(stand)
			var h := maxf(feet.y - p.y, 12.0)
			var want := Vector2(maxf(h * float(u["wide"]) / maxf(float(u["top"]), 0.1) * 0.9, 24.0), h * 0.85 + 4.0).round()
			if b.custom_minimum_size != want:
				b.custom_minimum_size = want
				b.size = want
				(tag["back"] as Control).position.x = (want.x - 34.0) * 0.5
				var nl: Label = tag["name"]
				nl.position.x = (want.x - nl.get_minimum_size().x) * 0.5
		b.position = (p - Vector2(b.size.x * 0.5, 2.0)).round()


## FAST-FORWARD: while the fight plays out (never while you choose), holding a button plays the
## animations FF_SPEED times as fast. A tap is not a hold (FF_HOLD), so the press that picked an
## order never speeds up its own blow by accident. The bottom corner says how.
func _fast_forward(real: float) -> void:
	if _speed > 4.0:
		return
	var choosing := not _acting.is_empty()
	var held := not choosing and not _over and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
		or Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER))
	_hold_t = _hold_t + real if held else 0.0
	var want := FF_SPEED if _hold_t >= FF_HOLD else 1.0
	if want != _ff:
		_ff = want
		_apply_time()
	if _ff_hint != null:
		_ff_hint.visible = not choosing and not _over and _intro <= 0.0
		_ff_hint.text = ">> x%d" % int(FF_SPEED) if _ff > 1.0 else ("Hold the screen: faster" if OS.has_feature("mobile") else "Hold Space: faster")
		_ff_hint.modulate.a = 0.95 if _ff > 1.0 else 0.55
