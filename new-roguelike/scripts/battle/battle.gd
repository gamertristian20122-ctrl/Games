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
const Supplies = preload("res://scripts/data/supplies.gd")
const Wounds = preload("res://scripts/data/wounds.gd")
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
const BUI = preload("res://scripts/battle/battle_ui.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Looks = preload("res://scripts/data/battle_looks.gd")   ## boss staging, aiming colours, the new words
const Lessons = preload("res://scripts/data/lessons.gd")      ## (P08) first-fight lessons and the Lantern's words
const LessonCard = preload("res://scripts/ui/kit/lesson.gd")
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
var _root: Control                 ## the UI grid (UI.attach): everything of the screen hangs on it
var _ph := false                   ## the phone's layout (UI.is_phone())
var _rail: Control                 ## the turn order (battle_ui.gd Rail)
var _ribbon: Control               ## the words at the top middle (Ribbon)
var _cards: Array = []             ## your side, one Card each, in the order of fight.party
var _tags: Array = []              ## {"unit", "button", "bar"} per monster
var _menu: PanelContainer          ## the orders (PC bottom left; phone bottom right)
var _page: Control                 ## the page in it now
var _menu_page := ""               ## "commands" | "skills" | "aim" | ""
var _menu_page_next := ""          ## (the page being built: rows are tiles on the phone's commands page)
var _came_from := "commands"       ## where Esc goes back to from aiming
var _skill_focus := -1             ## the skill row to land on when coming back to the list
var _skills_row: Button
var _flee_row: Button
var _warn: PanelContainer          ## the boss's "Guard!" warning over the orders
var _warn_on := false
var _detail: Label                 ## the focused row's words under the list
var _help: Control                 ## the help strip, top right (PC; hidden on touch)
var _help_key := ""
var _flame: Control                ## the ember focus pointer
var _brackets: Control             ## gold corner brackets round the one aimed at
var _plate: Control                ## and a monster's name and health over it
var _plate_key := ""
var _boss: Control                 ## a boss's long bar at the top
var _touch_hint: Label             ## "Tap the monster to strike." (touch only)
var _xp_was := 0                   ## the knight's XP and level as the battle ended (the victory bars fill from there)
var _lvl_was := 1
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
var _arrow: Control                ## and the little ember chevron over his head (battle_ui.gd Pointer)
var _turn_unit := {}
var _boss_bar := {}                ## a boss's own bar at the top of the screen
var _intro := 0.0                  ## the camera comes in from further back as the battle opens (1 -> 0)
var _num_stack := {}               ## numbers popping off one fighter: [when, how many] (they stack upwards)
var _push := 0.0                   ## and moves in a little at the end of a won battle (0 -> 1)
var _fade: ColorRect               ## black over the screen at the start, gold at a victory
var _sky := 0.0                    ## HD: how far up into the sky the camera still looks as the battle opens (1 -> 0)
var _layer: CanvasLayer
var moves: Node                    ## the choreography of every blow and spell (scripts/battle/anim_moves.gd)
var _dying := 0                    ## falls still being shown (a turn waits for them)
var _punch := 0.0                  ## the camera's punch-in on a crit or a finishing blow (0 to 1)
var _punch_at := Vector3.ZERO
var _track := 0.0                  ## the camera leaning towards where the action is (0 to 1)
var _track_at := Vector3.ZERO
var _track_zoom := 0.0             ## + moves in, - pulls back (a boss's big move)
var _track_id := 0
var _lean := 0.0                   ## PC: the camera slides left (world units) so the orders panel never hides the one choosing
var _lean_want := 0.0
var _stop_k := 1.0                 ## the hit-stop's share of the time scale
var _ff := 1.0                     ## and the fast-forward's
var _hold_t := 0.0
var _ff_latch := false               ## Settings > "ff_toggle": fast-forward stays on until "fast" is pressed again
var _combo := {}                   ## a combo's one counting number, by the fighter hit
var _plan: Array = []              ## test: --animplan=lunge,slam,thessaly:volley (what the bot picks, in order)
var _win_do := {}                  ## a story battle's "win" (tale.gd): applied the moment the fight is won
var _snap := {}                    ## wounds and supplies as the fight began ("Try again" puts them back)
var _boss_fight := false
var _aim_ring: MeshInstance3D      ## the pulsing ring on the ground under the one aimed at
var _aim_pool: MeshInstance3D      ## and the soft pool of light inside it
var _aim_shown := {}               ## who wears the aiming look now ({} = nobody)
var _pick := 1.0                   ## the speed plate's share of the time scale (1 while you choose)
var _stop_pick := true             ## may the speed plate hurry the present hit-stop (never a slow-motion moment)
var _lamp: OmniLight3D             ## (P08) the Lantern's warm light over whoever carries it
var _lamp_unit := {}
var _lantern_row: Button
var _passing := false              ## the Lantern is changing hands (the orders wait)
var _lesson_open := false

## PAUSE (main.gd sets it while its pause screen is open over a battle): the whole battle stands
## still: no turn begins, no blow lands, nothing on the stage moves, and no button of it answers.
var frozen := false:
	set(v):
		if frozen == v:
			return
		frozen = v
		process_mode = Node.PROCESS_MODE_DISABLED if v else Node.PROCESS_MODE_INHERIT
		if v:
			Engine.time_scale = 1.0        # (a hit-stop or the fast-forward must not slow or hurry the pause screen)
		else:
			_apply_time()


func _ready() -> void:
	_auto = G.flag("autotest") or G.flag("autobattle")
	if G.flag("autoplay"):              # test: --autoplay : the player's Auto switch starts on
		auto_play = true
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
		_boss_fight = bool(spec["boss"])
		# (the story moves on the moment the fight is won, see _finish; battles.gd may hand the "win" out itself)
		# (Tale.battle_row also knows a module's battles and notes which place foe this fight beats)
		var story_row: Dictionary = Tale.battle_row(story)
		var win: Variant = story_row.get("win", {}) if not story_row.is_empty() else spec.get("win", {})
		_win_do = win if win is Dictionary else {}
	else:
		var kind := Roamers.kind_of(spot)
		_tier = int(kind["tier"])
		title = String(kind.get("title", "A fight"))
		look = Battles.look_for(spot)
		if night and Stage.LOOKS.has(look + "_night"):
			look += "_night"
		fight.call("setup", Battles.party(), Battles.pack_for(spot, rng), rng.randi())
	fight.set("plain_item_turns", false)      # (P08: _play() shows every event of an item's turn)
	if story == "" and not _auto:
		Save.hub_set("wild_fights", int(Save.hub_get("wild_fights")) + 1)     # (P08: the "speed" lesson)
	_snapshot()
	_load_speed()
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
	# BOSS STAGING (scripts/data/battle_looks.gd): a boss stands alone in the middle of its side, drawn
	# big; its helpers stand behind it and to the sides
	var has_boss := false
	for f: Dictionary in foes:
		has_boss = has_boss or bool(f.get("boss", false))
	var minion := 0
	var clear := 0.0                   # (a very wide boss pushes its helpers further out, clear of its body)
	for f: Dictionary in foes:
		if bool(f.get("boss", false)):
			var at: Vector3 = Looks.boss(String(f["id"]))["at"]
			_place(f, at, true)
			clear = maxf(clear, at.x + float(f["wide"]) / 0.8 * 0.5 + 0.9 - (Looks.MINION_AT[0] as Vector3).x)
	for i in foes.size():
		if bool(foes[i].get("boss", false)):
			continue
		if has_boss:
			_place(foes[i], Looks.MINION_AT[minion % Looks.MINION_AT.size()] + Vector3(clear + 1.4 * float(minion / Looks.MINION_AT.size()), 0.0, 0.0), true)
			minion += 1
		else:
			_place(foes[i], FOES_AT[i % FOES_AT.size()], true)
	if has_boss:
		_frame_boss()
	_build_screen()
	_marker = stage.call("ground_glow", Vector3.ZERO, Color(1.0, 0.82, 0.4, 0.75), 1.25, 0.0, true)
	_marker.visible = false
	_aim_ring = stage.call("ground_glow", Vector3.ZERO, Looks.AIM_FOE, 1.5, 0.0, true)
	_aim_ring.visible = false
	_aim_pool = stage.call("ground_glow", Vector3.ZERO, Looks.AIM_FOE, 1.5, 0.0, false)
	_aim_pool.visible = false
	_refresh()
	_enter()
	_run.call_deferred(title)
	if G.arg("shotfight", "") != "" and G.arg("shots", "") != "":
		_fight_shot()


## Test: --shotfight=<s1,s2,...> (game seconds) writes battle_fight_<s>.png at those moments of a
## battle the bot fights (--autobattle; a look only).
func _fight_shot() -> void:
	var waited := 0.0
	for t: String in G.arg("shotfight", "").split(",", false):
		await get_tree().create_timer(maxf(float(t) - waited, 0.0)).timeout
		waited = float(t)
		if not is_inside_tree():
			return
		DirAccess.make_dir_recursive_absolute(G.arg("shots", ""))
		get_viewport().get_texture().get_image().save_png(G.arg("shots", "").path_join("battle_fight_%s.png" % t))


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
	var is_boss := bool(unit.get("boss", false))
	var big := 1.0
	# (the edge light stage.stand() gave it: aiming pulses it and must be able to put it back)
	var key: Array = (stage.look as Dictionary).get("key", [Color(1.0, 0.85, 0.6), 0.5, 1.0])
	var rim_side := float(key[2]) * (1.0 if at.x < 0.0 else -1.0)
	unit["rim"] = [float(key[1]), key[0], rim_side]
	if is_boss:
		# a boss looks like a boss: bigger than its art, its own edge light, a pool of light under it
		var bl := Looks.boss(String(unit["id"]))
		big = maxf(float(bl["scale"]), 0.5)
		tint = bl["tint"]
		unit["rim"] = [float(bl["rim_power"]), bl["rim"], rim_side]
		body.call("set_rim", float(bl["rim_power"]), bl["rim"], rim_side)
	elif String(unit["side"]) == "foes" and Looks.FOE_TINT.has(String(unit["id"])):
		var wash: Color = Looks.FOE_TINT[String(unit["id"])]
		tint = Color(tint.r * wash.r, tint.g * wash.g, tint.b * wash.b)
	unit["tint"] = tint                # (the turn rail's faces and the victory rows wear the same colour)
	body.call("set_tint", tint)
	unit["node"] = body
	unit["home"] = at
	unit["sword"] = null
	unit["hands"] = []
	var m := Art.meta(String(unit["sprite"]))
	var bw := float(m.get("body_width", 16.0)) * PX
	var bh := float(m.get("body_height", 28.0)) * PX
	var drop := 0.0                    # how far a hovering boss is lowered so that growing it does not lift it off the stage
	var air := 0.0                     # and the air left under it
	if bool(unit.get("boss", false)):
		# boss art has no body measurements: its picture, less the empty air the pack leaves round it
		var used := UI.used_rect(String(unit["sprite"]))
		bw = used.size.x * PX * 0.8
		bh = used.size.y * PX
		# (some boss art HOVERS: its body is drawn well above its feet point. Made bigger, that air
		# would grow too and lift it out of the picture: battle_looks.gd "hover" says how much of the
		# art's own air is kept)
		if m.has("feet"):
			var gap := maxf(float(m["feet"][1]) - used.end.y, 0.0) * PX * Sprite3.tall
			air = gap * clampf(float(Looks.boss(String(unit["id"])).get("hover", 1.0)), 0.0, 1.0)
			drop = gap * big - air
	bh *= Sprite3.tall                 # standing pictures are drawn taller by the camera's slant (sprite3.gd)
	bh *= big
	bw *= big
	unit["top"] = bh + air
	unit["wide"] = bw
	unit["big"] = big
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
	var actor: Node = BigActor.new() if (big != 1.0 or drop > 0.0) else Actor.new()
	if actor is BigActor:
		actor.set("big", big)
		actor.set("rise", drop)
	add_child(actor)
	actor.call("setup", body, at - Vector3(0.0, drop, 0.0), hash(String(unit["id"])) + int(at.x * 10.0))
	if drop > 0.0:
		for c in body.get_children():
			if c is MeshInstance3D:        # (its shadows stay on the ground)
				(c as MeshInstance3D).position.y += drop / big
	if String(unit["side"]) == "foes" and not bool(unit.get("boss", false)) and float(Enemies.info(String(unit["id"])).get("hover", 0.0)) > 0.0:
		actor.set("bob", 0.07)
	unit["actor"] = actor
	if is_boss:
		var bl2 := Looks.boss(String(unit["id"]))
		var glow: Color = bl2["glow"]
		unit["glow"] = stage.call("ground_glow", at, glow, clampf(bw * 0.85, 1.6, 4.2), 0.0, false)
		body.scale = Vector3(big, big, 1.0)


## A fighter drawn bigger than its art (a boss): everything anim_actor.gd does, times `big`.
class BigActor extends "res://scripts/battle/anim_actor.gd":
	var big := 1.0
	var rise := 0.0                 ## its picture is set this far down (hovering art, see _place): the ground is here

	func at() -> Vector3:
		return super() + Vector3(0.0, rise, 0.0)

	func centre(height: float) -> Vector3:
		return super(height) + Vector3(0.0, rise, 0.0)

	func _process(delta: float) -> void:
		super(delta)
		if body != null and is_instance_valid(body):
			body.scale = Vector3(body.scale.x * big, body.scale.y * big, 1.0)


## BOSS FRAMING: the camera steps back, along the line it looks down, until the boss's head stands
## under the top of the screen (battle_looks.gd FRAME_TOP), and no further than FRAME_BACK.
func _frame_boss() -> void:
	var cam: Camera3D = stage.cam
	var tallest := {}
	for f: Dictionary in fight.foes:
		if bool(f.get("boss", false)) and (tallest.is_empty() or float(f["top"]) > float(tallest["top"])):
			tallest = f
	if tallest.is_empty():
		return
	var head: Vector3 = (tallest["home"] as Vector3) + Vector3(0.0, float(tallest["top"]), 0.0)
	var home := _cam_home
	var aim: Vector3 = stage.aim
	var want := get_viewport().get_visible_rect().size.y * Looks.FRAME_TOP
	var k := 1.0
	while k <= Looks.FRAME_BACK:
		cam.position = aim + (home - aim) * k
		cam.look_at(aim, Vector3.UP)
		if cam.is_position_behind(head) or cam.unproject_position(head).y >= want:
			break
		k += 0.025
	_cam_home = aim + (home - aim) * minf(k, Looks.FRAME_BACK)
	cam.position = _cam_home
	cam.look_at(aim, Vector3.UP)
	# the phone look blurs by distance from the fighters (stage.gd POST_CODE): the band that stays
	# sharp must hold the whole boss, from its feet to its head, from where the camera stands now
	# (in HD the camera's own depth of field follows the fighters by itself, stage_hd.gd)
	var post: MeshInstance3D = stage.post
	if post != null and post.material_override is ShaderMaterial:
		var to_view := cam.global_transform.affine_inverse()
		var near := 1.0e9
		var far := -1.0e9
		var everybody: Array = (fight.party as Array) + (fight.foes as Array)
		for u: Dictionary in everybody:
			for h: float in [0.0, float(u["top"])]:
				var z := -(to_view * ((u["home"] as Vector3) + Vector3(0.0, h, 0.0))).z
				near = minf(near, z)
				far = maxf(far, z)
		var pm := post.material_override as ShaderMaterial
		pm.set_shader_parameter("focus", (near + far) * 0.5)
		pm.set_shader_parameter("sharp", maxf(3.4, (far - near) * 0.5 + 0.9))


## TRY AGAIN: what the party carried into the fight (every wound and every supply), to put back.
func _snapshot() -> void:
	_snap = {}
	Supplies.count("herb")             # (the starting pack is put in the save the first time it is counted)
	for k: Variant in (Save.data.get("hub", {}) as Dictionary).keys():
		var key := String(k)
		if key.begins_with("wound:") or key.begins_with("bag:"):
			_snap[key] = Save.hub_get(key)


func _restore_snapshot() -> void:
	for k: Variant in (Save.data.get("hub", {}) as Dictionary).keys():
		var key := String(k)
		if (key.begins_with("wound:") or key.begins_with("bag:")) and not _snap.has(key):
			Save.hub_set(key, 0)
	for key: String in _snap:
		Save.hub_set(key, int(_snap[key]))
	Save.flush()


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
## THE INTERFACE (the HD GUI, "Lantern Glass"; the pieces are scripts/battle/battle_ui.gd). It lives
## on the UI grid (UI.attach): PC about 800 x 360 UI px, the phone the game's 400 x 180.
## PC: the turn order top left, the help strip top right, the words top middle, your side as cards
## along the bottom right, the orders in a glass panel bottom left; the middle stays clear.
## Phone: turn coins top left, your side as thin strips top right, the orders as a 2 x 2 block of
## tiles bottom right (under 0.68 of the height), no key prompts.
const MENU_W := 148.0              ## the orders panel's width (PC)
const PHONE_LIST_W := 150.0        ## the phone's skills list

func _build_screen() -> void:
	_ph = UI.is_phone()
	UI._load_fonts()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_layer = layer
	_root = UI.attach(layer)
	_root.theme = UI.theme()
	_root.resized.connect(_layout)

	_rail = BUI.Rail.new()
	_rail.call("setup")
	_root.add_child(_rail)

	# over each monster: a small health bar, always; while you aim, the whole monster is a button
	for i in (fight.foes as Array).size():
		var unit: Dictionary = fight.foes[i]
		var button := Button.new()
		button.name = "foe_%d" % i
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		button.set_meta("no_flame", true)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.size = Vector2(40, 60)
		UI.juice(button)          # (while aiming, the mouse over a monster moves the brackets onto it)
		_root.add_child(button)
		var bar := UI.bar("foe", 22.0 if _ph else 32.0)
		bar.call("set_value", float(unit["hp"]), float(unit["max_hp"]), false)
		_root.add_child(bar)
		var marks: Control = BUI.FoeMarks.new()
		marks.call("setup", unit, Lessons.word("intent_short"))
		_root.add_child(marks)
		_tags.append({"unit": unit, "button": button, "bar": bar, "marks": marks})
		if bool(unit.get("boss", false)):
			bar.visible = false            # a boss has its long bar at the top instead
			_make_boss_bar(unit)
		var who := unit
		button.pressed.connect(func() -> void: _target_picked(who))
		button.mouse_entered.connect(_hover_aim.bind(button))      # the mouse over a monster moves the aim onto it

	# your side: a card each (PC: along the bottom; phone: strips top right). A card is also the
	# button that picks that fighter for a heal.
	for unit: Dictionary in fight.party:
		var card: Control = BUI.Card.new()
		card.set("level", Rpg.level())
		card.call("setup", unit)
		_root.add_child(card)
		_cards.append(card)
		var who := unit
		(card.get("button") as Button).pressed.connect(func() -> void: _target_picked(who))
		(card.get("button") as Button).mouse_entered.connect(_hover_aim.bind(card.get("button")))

	# the boss's warning over the orders, and the orders themselves
	_warn = PanelContainer.new()
	_warn.add_theme_stylebox_override("panel", UI.box("danger"))
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.visible = false
	var warn_text := UI.label("", "Small", (128.0 if _ph else MENU_W - 20.0))
	warn_text.add_theme_color_override("font_color", UI.C_BAD)
	if _ph:
		warn_text.add_theme_font_size_override("font_size", 8)
	_warn.add_child(warn_text)
	_root.add_child(_warn)
	_menu = PanelContainer.new()
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	_root.add_child(_menu)

	_brackets = BUI.Brackets.new()
	_root.add_child(_brackets)
	_plate = BUI.Plate.new()
	_plate.call("setup")
	_plate.visible = false
	_root.add_child(_plate)
	_ribbon = BUI.Ribbon.new()
	_root.add_child(_ribbon)
	# AUTO FIGHT (v0.37.0): a small switch in the top right corner. While it is on the party picks its own
	# moves (the bot's choices, fight.gd auto_choice); a tap takes the fight back. It stays as set from
	# fight to fight until the game is closed. Bosses too: the bot guards when a great blow is coming.
	# (quality pass) beside it a speed plate (x1 / x2 / x3); each has its own key cap (T and F) and a
	# tooltip, and the help strip keeps clear of both (see _place_help)
	_auto_btn = _corner_plate(_toggle_auto, "T", Looks.word("auto_tip"))
	_speed_btn = _corner_plate(_cycle_speed, "F", Looks.word("speed_tip"))
	_auto_btn.visible = not _auto
	_speed_btn.visible = not _auto
	_place_plates()
	_sync_auto_btn()
	_sync_speed_btn()
	_touch_hint = UI.label("", "Small")
	_touch_hint.add_theme_color_override("font_color", UI.C_PARCH)
	_touch_hint.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
	_touch_hint.add_theme_constant_override("outline_size", 3)
	_touch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_touch_hint.visible = false
	_root.add_child(_touch_hint)
	_arrow = BUI.Pointer.new()
	_arrow.visible = false
	_root.add_child(_arrow)
	if not _ph:
		_help = UI.help_strip([], "top_right")
		_root.add_child(_help)
	_flame = UI.flame(_root)
	_root.add_child(_flame)

	# what covers the screen on the way in and at the end
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_root.add_child(_fade)
	_layout()


## Places what has a fixed spot (again when the window changes size).
func _layout() -> void:
	if _root == null or not is_instance_valid(_rail):
		return
	var room: Vector2 = _root.size
	var n := _cards.size()
	var ins := UI.safe_insets(_root) if _ph else Vector4.ZERO
	if _ph:
		# (the phone's camera puts the monsters' heads in the top right: your side's strips sit on
		# the empty ground bottom left, stacked up from the bottom, clear of the orders' tiles)
		for i in n:
			var card: Control = _cards[i]
			card.call("set_width", 120.0)
			card.call("place_at", Vector2(8.0 + ins.x, room.y - 4.0 - ins.w - 18.0 * (n - i)))
	elif n > 0:
		var gap := 6.0
		var avail := room.x - 28.0 - MENU_W - 16.0 - gap * (n - 1)
		var cw := clampf(avail / n, 120.0, 176.0)
		if cw * n > avail:
			cw = maxf(floorf(avail / n), 96.0)       # (four fighters on a narrow screen)
		var x := roundf(room.x - 14.0 - n * cw - gap * (n - 1))
		for card: Control in _cards:
			card.call("set_width", cw)
			card.call("place_at", Vector2(x, room.y - 14.0 - 44.0))
			x += cw + gap
	_rail.position = Vector2(ins.x, ins.y)
	var top := 4.0 if _ph else 14.0
	if is_instance_valid(_boss):
		# the boss's bar: top middle, a little left of the middle (a big boss stands on the right and
		# its head must not sit under its own bar), clear of the turn order and the help strip
		var w := 140.0 if _ph else 260.0
		var rail_end := float(_rail.get("end_x")) + (10.0 if _ph else 14.0)
		var right := room.x - (14.0 if _ph else 200.0)
		w = minf(w, maxf(right - rail_end, 80.0))
		var cx := clampf(room.x * 0.5 - (0.0 if _ph else 56.0), rail_end + w * 0.5, right - w * 0.5)
		_boss.call("set_width", w)
		_boss.position = Vector2(roundf(cx - w * 0.5), 4.0 if _ph else 8.0)
		top = _boss.position.y + _boss.size.y + (4.0 if _ph else 8.0)
	_ribbon.position = Vector2(0, top)
	_ribbon.size = Vector2(room.x, float(_ribbon.call("band_h")))
	_touch_hint.position = Vector2(0, top + float(_ribbon.call("band_h")) + 1.0)
	_touch_hint.size = Vector2(room.x, 12.0)
	_brackets.position = Vector2.ZERO
	_brackets.size = room
	_place_help()


## Every frame: the orders panel keeps its corner as it grows and shrinks.
func _place_menu() -> void:
	if not _menu.visible:
		_warn.visible = false
		return
	var room: Vector2 = _root.size
	var ms := _menu.get_combined_minimum_size()
	if _ph:
		_menu.size = ms
		var ins := UI.safe_insets(_root)
		_menu.position = Vector2(room.x - 8.0 - ins.z - ms.x, room.y - 8.0 - ins.w - ms.y).round()
	else:
		_menu.size = Vector2(maxf(MENU_W, ms.x), ms.y)
		_menu.position = Vector2(14.0, room.y - 14.0 - ms.y).round()
	_warn.visible = _warn_on and _menu_page != "aim"
	if _warn.visible:
		var ws := _warn.get_combined_minimum_size()
		_warn.size = Vector2(_menu.size.x if not _ph else ws.x, ws.y)
		_warn.position = Vector2(_menu.position.x if not _ph else _menu.position.x + _menu.size.x - ws.x, _menu.position.y - 6.0 - ws.y).round()


## PC: how far the camera must slide (world units) so the orders panel clears the fighter who is
## choosing, without pushing the furthest monster off the right edge. Kept while aiming (the
## panel is shut then) so the picture does not swing back and forth; 0 when nobody is choosing.
func _want_lean() -> void:
	if _ph or _acting.is_empty() or String(_acting.get("side", "")) != "party" or _over:
		_lean_want = 0.0
		return
	if not _menu.visible:
		return
	var stand: Vector3 = (_acting["actor"] as Node).call("at") if _acting.get("actor") != null else (_acting["home"] as Vector3)
	var ppu := absf(_on_ui(stand + Vector3(1.0, 0.0, 0.0)).x - _on_ui(stand).x)
	if ppu < 1.0:
		return
	var r := _sprite_rect(_acting)
	var panel := Rect2(_menu.position, _menu.size)
	if r.end.y < panel.position.y + 4.0:
		_lean_want = 0.0
		return
	var base_left := r.position.x - _lean * ppu
	var need := (panel.end.x + 10.0 - base_left) / ppu
	# room on the right: the rightmost living monster keeps a margin from the edge
	var room := 3.0
	for u: Dictionary in fight.call("alive", fight.foes):
		var fr := _sprite_rect(u)
		var fppu := absf(_on_ui((u["home"] as Vector3) + Vector3(1.0, 0.0, 0.0)).x - _on_ui(u["home"]).x)
		if fppu >= 1.0:
			room = minf(room, (_root.size.x - 12.0 - (fr.end.x - _lean * fppu)) / fppu)
	_lean_want = clampf(need, 0.0, maxf(room, 0.0))


## A boss gets its name and a long bar at the top middle of the screen.
func _make_boss_bar(unit: Dictionary) -> void:
	_boss = BUI.BossBar.new()
	_boss.call("setup", unit)
	_root.add_child(_boss)
	_boss_bar = {"unit": unit}


## Where a point of the 3D picture is on the UI grid.
func _on_ui(world: Vector3) -> Vector2:
	return stage.cam.unproject_position(world) / maxf(_layer.scale.x, 0.0001)


## A fighter's picture on the UI grid: Rect2 from the top of its head to its feet.
func _sprite_rect(u: Dictionary) -> Rect2:
	var stand: Vector3 = (u["actor"] as Node).call("at") if u.get("actor") != null else (u["home"] as Vector3)     # (it follows him when he moves)
	var head := _on_ui(stand + Vector3(0.0, float(u["top"]), 0.0))
	var feet := _on_ui(stand)
	var h := maxf(feet.y - head.y, 12.0)
	var w := maxf(h * float(u["wide"]) / maxf(float(u["top"]), 0.1) * 0.9, 20.0 if not _ph else 14.0)
	return Rect2(Vector2(feet.x - w * 0.5, head.y), Vector2(w, h))


## Puts every number and bar right.
func _refresh(acting: Dictionary = {}) -> void:
	for card: Control in _cards:
		card.call("refresh", true)
		card.call("set_acting", is_same(card.get("unit"), acting))
	_sync_lantern()
	for tag: Dictionary in _tags:
		var u: Dictionary = tag["unit"]
		BUI.set_bar(tag["bar"], float(u["hp"]), float(u["max_hp"]))
		(tag["button"] as Button).visible = int(u["hp"]) > 0
	if is_instance_valid(_boss):
		var bu: Dictionary = _boss_bar["unit"]
		BUI.set_bar(_boss.get("bar"), maxf(float(bu["hp"]), 0.0), float(bu["max_hp"]))
	_turn_unit = acting
	if _marker != null:
		_marker.visible = not acting.is_empty() and not _over
		if _marker.visible:
			var at: Vector3 = acting["home"]
			_marker.position = Vector3(at.x, 0.04, at.z)
			var c := Color(1.0, 0.82, 0.4) if String(acting["side"]) == "party" else Color(1.0, 0.36, 0.28)
			(_marker.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.75)
			_marker.scale = Vector3.ONE * clampf(float(acting["wide"]) * 1.1, 0.8, 2.6)
	if acting.is_empty():
		return
	var line: Array = [acting]
	line.append_array(fight.call("upcoming"))
	_rail.call("set_line", line, int(fight.round_no), fight.call("upcoming_next"))
	_layout()


## Only the bars of one fighter (the moment a blow lands on him, not before).
func _refresh_one(u: Dictionary) -> void:
	for card: Control in _cards:
		if is_same(card.get("unit"), u):
			card.call("refresh", true)
	for tag: Dictionary in _tags:
		if is_same(tag["unit"], u):
			BUI.set_bar(tag["bar"], float(u["hp"]), float(u["max_hp"]))
			(tag["button"] as Button).visible = int(u["hp"]) > 0
	if is_instance_valid(_boss) and is_same(_boss_bar["unit"], u):
		BUI.set_bar(_boss.get("bar"), maxf(float(u["hp"]), 0.0), float(u["max_hp"]))


## Your side's card jolts and its HP number flashes red when that fighter is hit (you see who it
## was at a glance, even with your eyes on the menu).
func _row_jolt(u: Dictionary, ratio: float) -> void:
	for card: Control in _cards:
		if is_same(card.get("unit"), u):
			card.call("hit", ratio)


# ------------------------------------------------------------------ the menu on your turn
var _acting := {}
var _waiting_skill := {}           ## the skill that is waiting for a target ({} = a plain Attack)
var _aim := ""                     ## "" | "foe" | "friend": what a tap picks now


func _clear_menu() -> void:
	if is_instance_valid(_page):
		_page.queue_free()
	_page = null
	_detail = null
	_warn_on = false
	_ribbon.call("unpin")
	_touch_hint.visible = false
	_set_aim("")


func _set_aim(aim: String) -> void:
	_aim = aim
	for tag: Dictionary in _tags:
		var b: Button = tag["button"]
		var can := aim == "foe" and int(tag["unit"]["hp"]) > 0
		b.disabled = not can
		b.focus_mode = Control.FOCUS_ALL if can else Control.FOCUS_NONE
	for card: Control in _cards:
		var b: Button = card.get("button")
		var can := aim == "friend" and (int(card.get("unit")["hp"]) > 0) != _raising()
		b.disabled = not can
		b.focus_mode = Control.FOCUS_ALL if can else Control.FOCUS_NONE
		if not can:
			card.call("set_targeted", false)


## Opens a page of the orders panel (it slides in from the side it comes from).
func _open_page(page: Control, kind: String, dir: int) -> void:
	_page = page
	_menu_page = kind
	var glass := not _ph or kind != "commands"
	_menu.add_theme_stylebox_override("panel", _menu_box(glass))
	_menu.add_child(page)
	_menu.visible = true
	UI.page_swap(null, page, dir)


func _menu_box(glass: bool) -> StyleBox:
	if not glass:
		return StyleBoxEmpty.new()
	var g := UI.glass(3.0 if _ph else 4.0, 4.0 if _ph else 6.0, UI.C_BRASS_DIM, not _ph)
	return g


## One order: a row (PC) or a tile (phone) with its icon; `value` right-aligned (a skill's cost).
func _row(text: String, icon_id: String, action: Callable, value: String = "", value_col: Color = UI.C_MP_A) -> Button:
	var b := UI.button(text, action, "Big" if _ph and _menu_page_next == "commands" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if icon_id != "" and Art.has(icon_id):
		b.icon = Art.tex(icon_id)
	if _ph and _menu_page_next == "commands":
		# a touch tile: glass, the icon and a small word, gold edge and the sweep when focused
		var n := UI.glass(4.0, 2.0)
		n.shadow_size = 4
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, n)
		var f := UI.SweepBox.new()
		f.edge = UI.C_GOLD
		f.cut_size = UI.cut
		f.inset = 1.0
		b.add_theme_stylebox_override("focus", f)
		b.add_theme_font_override("font", UI.font_body)
		b.add_theme_font_size_override("font_size", 9)
		b.add_theme_constant_override("h_separation", 3)
		b.custom_minimum_size = Vector2(62, 22)
	else:
		b.custom_minimum_size = Vector2(0, 20.0 if _ph else UI.row_h)
		if _ph:
			b.add_theme_font_size_override("font_size", 9)
	if value != "":
		var v := UI.label(value, "Num")
		v.add_theme_color_override("font_color", value_col)
		v.add_theme_font_size_override("font_size", 8 if _ph else 11)
		v.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		v.offset_left = -30
		v.offset_right = -6 if _ph else -8
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(v)
	b.focus_entered.connect(_on_row_focus.bind(b))
	return b


## A row that cannot be used: it still takes the focus, looks faint, and says why when focused or
## pressed (house rule: never a dead button without its reason on the screen).
func _refuse(b: Button, why: String) -> void:
	b.set_meta("why", why)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, UI.C_FAINT)
	b.add_theme_color_override("font_focus_color", UI.C_DIM)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
		b.add_theme_color_override(key, Color(0.45, 0.45, 0.48, 0.7))
	b.set_meta("refused", true)


## The words under the list follow the focus: a skill's text, or why a row cannot be used.
func _on_row_focus(b: Button) -> void:
	if not is_instance_valid(_detail):
		return
	var t := String(b.get_meta("why", "")) if b.has_meta("why") else ""
	if t == "":
		t = String(b.get_meta("text", ""))
	_detail.text = t
	_detail.modulate = UI.C_BAD.lerp(Color.WHITE, 0.35) if bool(b.get_meta("refused", false)) else Color.WHITE


## Pressed on a row that cannot be used: the refusal sound and its reason, flashed.
func _refused(b: Button) -> bool:
	if not bool(b.get_meta("refused", false)):
		return false
	Sfx.play("shop_deny")
	_on_row_focus(b)
	if is_instance_valid(_detail) and not UI.instant:
		_detail.modulate = UI.C_BAD
		var tw := _detail.create_tween()
		tw.tween_property(_detail, "modulate", UI.C_BAD.lerp(Color.WHITE, 0.35), 0.4)
	return true


## The words under the list (a hairline, then the focused row's words, two lines at most).
func _add_detail(page: VBoxContainer) -> void:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 6 if not _ph else 3)
	page.add_child(line)
	var w := (PHONE_LIST_W - 12.0) if _ph else (MENU_W - 24.0)
	_detail = UI.label("", "Small", w)
	_detail.add_theme_color_override("font_color", UI.C_DIM)
	_detail.max_lines_visible = 1 if _ph else 2
	_detail.custom_minimum_size.y = (10.0 if _ph else 26.0)
	if _ph:
		_detail.add_theme_font_size_override("font_size", 8)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 4 if _ph else 8)
	pad.add_theme_constant_override("margin_right", 4 if _ph else 6)
	pad.add_theme_constant_override("margin_bottom", 1)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_detail)
	page.add_child(pad)


## The panel's head: the actor's name (or "SKILLS" and the mana left).
func _head(page: VBoxContainer, title: String, right: String = "") -> void:
	var row := UI.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(title, "Head")
	l.add_theme_color_override("font_color", UI.C_GOLD)
	l.add_theme_font_size_override("font_size", 8 if _ph else (12 if right == "" else 11))
	if _ph and _menu_page_next == "commands":
		l.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
		l.add_theme_constant_override("outline_size", 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if right != "":
		var r := UI.label(right, "Num")
		r.add_theme_color_override("font_color", UI.C_MP_A)
		r.add_theme_font_size_override("font_size", 8 if _ph else 10)
		row.add_child(r)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 4 if _ph else 8)
	pad.add_theme_constant_override("margin_right", 4 if _ph else 6)
	pad.add_theme_constant_override("margin_top", 0 if _ph else 2)
	pad.add_theme_constant_override("margin_bottom", 1 if _ph else 3)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	page.add_child(pad)


func _show_commands(back: bool = false) -> void:
	_clear_menu()
	_menu_page_next = "commands"
	var page := UI.vbox(0 if not _ph else 2)
	_head(page, String(_acting["name"]))
	var list: Container
	if _ph:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		list = grid
	else:
		list = UI.vbox(0)
	# (P08) the carrier's FLARE, gold, at the very top when the flame is full
	var flare: Dictionary = fight.call("flare_for", _acting)
	var flare_row: Button = null
	if not flare.is_empty():
		var fl := flare
		flare_row = _row(String(flare["name"]), UI.icon_or([_skill_icon(flare), UI.ICON_SKILLS]), func() -> void: _on_skill(fl), String(Lessons.word("flare_text")), UI.C_GOLD)
		flare_row.set_meta("text", String(flare.get("text", "")))
		for key: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			flare_row.add_theme_color_override(key, UI.C_GOLD)
		if _ph:
			flare_row.custom_minimum_size = Vector2(0, 20)
		page.add_child(flare_row)                  # (between the head and the list of orders)
	page.add_child(list)
	var attack := _row("Attack", UI.ICON_ATTACK, _on_attack)
	var skills := _row("Skills", UI.ICON_SKILLS, func() -> void: _on_skills_row())
	var guard := _row("Guard", UI.icon_or([UI.ICON_SHIELD, UI.ICON_GUARD]), func() -> void: _choose({"do": "guard"}))
	var flee := _row("Flee", UI.icon_or([UI.ICON_BOOT, UI.ICON_FLEE]), func() -> void: _on_flee_row())
	var items := _row("Items", "icon_misers_flask", func() -> void: _on_items_row())
	items.set_meta("text", "Herbs and tonics from your pack.")
	_items_row = items
	_skills_row = skills
	_flee_row = flee
	attack.set_meta("text", "Strike one monster.")
	skills.set_meta("text", "Your skills; they cost mana.")
	guard.set_meta("text", "Take less than half until your next turn; a little mana back.")
	flee.set_meta("text", "Try to run from the fight.")
	for b: Button in [attack, skills, items, guard, flee]:
		list.add_child(b)
	# (P08) the sixth order: take the Lantern (free, once a round; the turn is not spent)
	_lantern_row = null
	if (fight.call("alive", fight.party) as Array).size() > 1:
		var lr := _row(String(Lessons.word("lantern")), "", func() -> void: _on_lantern())
		lr.icon = BUI.lantern_tex()
		lr.expand_icon = false
		lr.set_meta("text", String(Lessons.word("lantern_text")))
		if not bool(fight.call("can_take", _acting)):
			_refuse(lr, String(Lessons.word("lantern_no")) if not is_same(fight.get("lantern"), _acting) else String(Lessons.word("lantern_have")))
		list.add_child(lr)
		_lantern_row = lr
	if Supplies.bag().is_empty():
		_refuse(items, "Your pack is empty. Sellers in town have herbs and tonics.")
	var warn := ""
	if bool(fight.get("no_flee")):
		_refuse(flee, "No running from this one.")
	for foe: Dictionary in fight.call("alive", fight.foes):
		if bool(fight.call("sweep_next", foe)):
			warn = "%s draws back for a great blow at everybody. Guard!" % String(foe["name"])
	if (_acting["skills"] as Array).is_empty():
		# never a dead button without the reason on the screen
		_refuse(skills, "No skills yet: the first comes at level 2.")
	if not _ph:
		_add_detail(page)
	_open_page(page, "commands", -1 if back else 1)
	_warn_on = warn != ""
	(_warn.get_child(0) as Label).text = warn
	_set_help("commands")
	if flare_row != null and not back:
		flare_row.grab_focus.call_deferred()
	else:
		(skills if back and _came_from == "skills" else attack).grab_focus.call_deferred()


var _items_row: Button
var _waiting_item := {}
const LOSE_COINS := 0.2            ## a lost battle costs this share of the coins


func _on_items_row() -> void:
	if _refused(_items_row):
		return
	_show_items()


## The pack (scripts/data/supplies.gd): what is in it and how many; the one picked is aimed like a heal.
func _show_items(back: bool = false) -> void:
	_clear_menu()
	_menu_page_next = "items"
	_came_from = "items"
	var page := UI.vbox(0)
	_head(page, "Items")
	var list := UI.vbox(0)
	page.add_child(list)
	var first: Button = null
	for pair: Array in Supplies.bag():
		var item: Dictionary = pair[0]
		var icon: String = {"herb": "icon_misers_flask", "tonic": "icon_sparking_tonic", "elixir": "icon_swift_tonic", "ember": "icon_pyre_kindling", "salt": "icon_wardwater"}.get(String(item["id"]), "icon_misers_flask")
		if not Art.has(icon):
			icon = "icon_misers_flask"
		var b := _row(String(item["name"]), icon, Callable(), "x%d" % int(pair[1]), UI.C_GOLD)
		b.pressed.connect(func() -> void:
			if not _refused(b):
				_on_item(item))
		b.set_meta("text", String(item["text"]))
		# (P08) an herb nobody needs is greyed, with the reason
		var why := _item_why(item)
		if why != "":
			_refuse(b, why)
		if _ph:
			b.custom_minimum_size.x = PHONE_LIST_W - 8.0
		if first == null:
			first = b
		list.add_child(b)
	if _ph:
		var back_row := _row("Back", "", func() -> void: on_back())
		back_row.set_meta("text", "")
		list.add_child(back_row)
	_add_detail(page)
	_open_page(page, "items", -1 if back else 1)
	_set_help("skills")
	if first != null:
		first.grab_focus.call_deferred()


func _on_item(item: Dictionary) -> void:
	_waiting_skill = {}
	_waiting_item = item
	if String(item.get("aim", "friend")) == "party":
		# (P08) never a wasted item: the reason instead, and the turn is not spent
		var why := String(fight.call("useful", _acting, {"do": "item", "item": item, "target": null}))
		if why != "":
			_say_refusal(why)
			return
		_choose({"do": "item", "item": item, "target": null})
	else:
		_ask_target("friend", "Tap who gets it.")


func _on_skills_row() -> void:
	if _refused(_skills_row):
		return
	_show_skills()


func _on_flee_row() -> void:
	if _refused(_flee_row):
		return
	_choose({"do": "flee"})


## The icon of a skill: the knight's own (skill_<id>), else the nearest picture for its kind.
func _skill_icon(s: Dictionary) -> String:
	var id := String(s.get("id", ""))
	if Art.has("skill_" + id):
		return "skill_" + id
	if s.has("heal"):
		return "skill_mend"
	if id in ["pierce", "volley"]:
		return UI.icon_or(["icon_longbow_string", UI.ICON_ATTACK])
	if s.has("stun"):
		return UI.icon_or(["icon_bone_thistle", "skill_cry"])
	if String(s.get("kind", "")) == "spell":
		return UI.icon_or(["icon_eclipse_shard", UI.ICON_SKILLS])
	return UI.ICON_ATTACK


func _show_skills(back: bool = false) -> void:
	_clear_menu()
	_menu_page_next = "skills"
	_came_from = "skills"
	var page := UI.vbox(0)
	_head(page, "Skills", "MP %d" % int(_acting["mp"]))
	var many := (_acting["skills"] as Array).size() > 4
	var list: Container
	if _ph and many:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 0)
		list = grid
	else:
		list = UI.vbox(0)
	page.add_child(list)
	var first: Button = null
	var any: Button = null
	for s: Dictionary in _acting["skills"]:
		var skill := s
		var can := bool(fight.call("can_use", _acting, s))
		var b := _row(String(s["name"]), _skill_icon(s), Callable(), "%d" % int(s["mana"]), UI.C_MP_A if can else UI.C_FAINT)
		b.pressed.connect(func() -> void: _on_skill_row(b, skill))
		b.set_meta("text", String(skill.get("text", "")))
		b.set_meta("i", list.get_child_count())
		if _ph:
			b.custom_minimum_size.x = 72.0 if many else PHONE_LIST_W - 8.0
		if not can:
			_refuse(b, "Needs %d mana (%d left). Guard gives a little back." % [int(s["mana"]), int(_acting["mp"])])
		elif first == null:
			first = b
		if any == null:
			any = b
		list.add_child(b)
	if _ph:
		var back_row := _row("Back", "", func() -> void: on_back())
		back_row.set_meta("text", "")
		list.add_child(back_row)
	_add_detail(page)
	_open_page(page, "skills", -1 if back else 1)
	_set_help("skills")
	var to: Button = first if first != null else any
	if back and _skill_focus >= 0 and _skill_focus < (_acting["skills"] as Array).size():
		to = list.get_child(_skill_focus) as Button
	if first == null and is_instance_valid(_detail):
		_detail.text = "Not enough mana for any of them. Guard gives a little back."
	if to != null:
		to.grab_focus.call_deferred()


func _on_skill_row(b: Button, skill: Dictionary) -> void:
	if _refused(b):
		return
	_skill_focus = int(b.get_meta("i", -1))
	_on_skill(skill)


func _on_attack() -> void:
	_waiting_skill = {}
	_waiting_item = {}
	_came_from = "commands"
	_ask_target("foe", "Tap the monster to strike.")


func _on_skill(skill: Dictionary) -> void:
	_waiting_skill = skill
	_waiting_item = {}
	match String(skill.get("aim", "foe")):
		"foes", "self", "party":
			_choose({"do": "skill", "skill": skill, "target": null})
		"friend":
			_ask_target("friend", "Tap who gets it.")
		_:
			_ask_target("foe", "Tap the monster to aim at.")


## AIMING: the panel closes, the order's name stands at the top, gold brackets close round the one
## aimed at (a monster also shows its name and health over it). Left / Right (or the mouse) move
## between them, Enter or a click picks, Esc goes back.
func _ask_target(aim: String, words: String) -> void:
	var choices: Array = fight.call("alive", fight.foes if aim == "foe" else fight.party)
	if aim == "friend" and _raising():
		# (P08) a waking item or skill aims at the FALLEN
		choices = (fight.party as Array).filter(func(u: Dictionary) -> bool: return int(u["hp"]) <= 0)
		if choices.is_empty():
			_say_refusal(String(Battles.SAY["standing"]))
			return
	if choices.size() == 1:
		_target_picked(choices[0], aim)
		return
	var order := "Attack" if _waiting_skill.is_empty() else String(_waiting_skill["name"])
	if not _waiting_item.is_empty():
		order = String(_waiting_item["name"])
	_clear_menu()
	_menu_page_next = "aim"
	_menu_page = "aim"
	if _ph:
		# (a touch screen has no Esc: a small Back tile stays in the corner)
		var page := UI.vbox(0)
		_menu_page_next = "commands"
		var back := _row("Back", "", func() -> void: _step_back())
		page.add_child(back)
		_open_page(page, "aim", 1)
		_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		_menu.visible = false
	_ribbon.call("pin", order)
	_touch_hint.text = words
	_touch_hint.visible = Controls.using_touch
	_set_aim(aim)
	_set_help("aim")
	# a pad or keys: start on the first one that can be picked
	if aim == "foe":
		for tag: Dictionary in _tags:
			if int(tag["unit"]["hp"]) > 0:
				(tag["button"] as Button).grab_focus.call_deferred()
				break
	else:
		var raising := _raising()
		for card: Control in _cards:
			if (int(card.get("unit")["hp"]) > 0) != raising:
				(card.get("button") as Button).grab_focus.call_deferred()
				break


## Who is aimed at now (the focused monster or friend), {} when nobody is.
func _aimed() -> Dictionary:
	if _aim == "":
		return {}
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return {}
	if _aim == "foe":
		for tag: Dictionary in _tags:
			if tag["button"] == f:
				return tag["unit"]
	else:
		for card: Control in _cards:
			if card.get("button") == f:
				return card.get("unit")
	return {}


## Left / Right (Up / Down too) step through who can be aimed at, in screen order.
func _cycle(step: int) -> void:
	var list: Array = []
	if _aim == "foe":
		for tag: Dictionary in _tags:
			if int(tag["unit"]["hp"]) > 0:
				list.append(tag["button"])
		list.sort_custom(func(a: Button, b: Button) -> bool: return a.position.x < b.position.x)
	else:
		var raising := _raising()
		for card: Control in _cards:
			if (int(card.get("unit")["hp"]) > 0) != raising:
				list.append(card.get("button"))
	if list.is_empty():
		return
	var at := list.find(get_viewport().gui_get_focus_owner())
	var to: Button = list[posmod(at + step, list.size())] if at >= 0 else list[0]
	to.grab_focus()


## The mouse over a monster (or a friend's card) while aiming: the aim moves onto it.
func _hover_aim(b: Button) -> void:
	if _aim == "" or not is_instance_valid(b) or b.disabled or Controls.using_touch:
		return
	if b.focus_mode != Control.FOCUS_NONE and not b.has_focus():
		b.grab_focus()


## THE AIMING LOOK (every frame from _ui_frame): the one aimed at keeps its colours, gets a pulsing
## ring of light on the ground and a pulsing edge light; everybody else sinks back into shade.
## `aimed` {} = nobody: everything is put back as it was.
func _aim_look(aimed: Dictionary) -> void:
	if not is_same(aimed, _aim_shown) and not (aimed.is_empty() and _aim_shown.is_empty()):
		if not _aim_shown.is_empty():
			_unlight(_aim_shown)
		_aim_shown = aimed
		var everybody: Array = (fight.party as Array) + (fight.foes as Array)
		for u: Dictionary in everybody:
			var k := 1.0
			if not aimed.is_empty() and not is_same(u, aimed):
				k = Looks.AIM_DIM_ACTING if is_same(u, _acting) else Looks.AIM_DIM
			_shade(u, k)
		if is_instance_valid(_aim_ring):
			_aim_ring.visible = not aimed.is_empty()
		if is_instance_valid(_aim_pool):
			_aim_pool.visible = not aimed.is_empty()
	if aimed.is_empty() or not is_instance_valid(_aim_ring) or not is_instance_valid(_aim_pool):
		return
	var beat := 0.5 + 0.5 * sin(_t * 6.0)
	var c: Color = Looks.AIM_FOE if String(aimed["side"]) == "foes" else Looks.AIM_FRIEND
	var at: Vector3 = aimed["home"]
	_aim_ring.position = Vector3(at.x, float(stage.call("height_at", at.z)) + 0.045, at.z)
	var wide := clampf(float(aimed["wide"]) * 0.8, 0.85, 3.2)
	_aim_ring.scale = Vector3.ONE * wide * (1.0 + 0.12 * beat)
	(_aim_ring.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, c.a * (0.6 + 0.4 * beat))
	_aim_pool.position = _aim_ring.position - Vector3(0.0, 0.005, 0.0)
	_aim_pool.scale = Vector3.ONE * wide * 0.9
	(_aim_pool.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.30 + 0.25 * beat)
	var node: Node = aimed.get("node")
	if is_instance_valid(node):
		var rim: Array = aimed.get("rim", [0.5, Color.WHITE, -1.0])
		node.call("set_rim", maxf(float(rim[0]), 0.7) + 0.9 * beat, c, float(rim[2]))


## Puts a fighter's own edge light back after it was aimed at.
func _unlight(u: Dictionary) -> void:
	var node: Node = u.get("node")
	if is_instance_valid(node) and u.has("rim"):
		var rim: Array = u["rim"]
		node.call("set_rim", float(rim[0]), rim[1], float(rim[2]))


## Draws a fighter (body, hands, sword) `k` times as bright as its own tint (1 = as it is).
func _shade(u: Dictionary, k: float) -> void:
	var node: Node = u.get("node")
	if not is_instance_valid(node):
		return
	var t: Color = u.get("tint", Color.WHITE)
	var c := Color(t.r * k, t.g * k, t.b * k)
	node.call("set_tint", c)
	for h: Variant in u.get("hands", []):
		if is_instance_valid(h):
			(h as Node).call("set_tint", c)
	var sword: Variant = u.get("sword")
	if sword != null and is_instance_valid(sword):
		for blade: Node in (sword as Node).get_children():
			if blade.has_method("set_tint"):
				blade.call("set_tint", Color(k, k, k))


func _input(event: InputEvent) -> void:
	# Auto and the speed plate have keys of their own (T and F; pad Y and X), in the fight and while choosing
	# (Settings > fast-forward as a switch, "ff_toggle": a press of the "fast" action turns it on or off)
	if not _over and InputMap.has_action("fast") and event.is_action_pressed("fast") and not event.is_echo() and Save.setting("ff_toggle") == true:
		_ff_latch = not _ff_latch
	# (the "auto" action may be rebound to any key or pad button: scripts/core/controls.gd)
	if not _over and not _auto and InputMap.has_action("auto") and event.is_action_pressed("auto") and not event.is_echo():
		Sfx.play("ui_click")
		_toggle_auto()
		get_viewport().set_input_as_handled()
		return
	if not _over and not _auto and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var code := (event as InputEventKey).physical_keycode
		if not InputMap.has_action("auto") and code == KEY_T:
			Sfx.play("ui_click")
			_toggle_auto()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_F:
			Sfx.play("ui_click")
			_cycle_speed()
			get_viewport().set_input_as_handled()
			return
	if not _over and not _auto and event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
			Sfx.play("ui_click")
			_toggle_auto()
			get_viewport().set_input_as_handled()
			return
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			Sfx.play("ui_click")
			_cycle_speed()
			get_viewport().set_input_as_handled()
			return
	if _acting.is_empty() or _over:
		return
	# the mouse's right button goes one step back (as Esc does) on every page; on the orders page
	# there is nothing to go back to
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if _step_back():
			get_viewport().set_input_as_handled()
		return
	if _aim == "":
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle(1)
		get_viewport().set_input_as_handled()


func _target_picked(unit: Dictionary, forced_aim: String = "") -> void:
	var aim := forced_aim if forced_aim != "" else _aim
	if aim == "" or _acting.is_empty():
		return
	# (P08) never a wasted order: an herb on the whole, a mend on the unhurt is refused, the turn kept
	var want := {"do": "attack", "target": unit}
	if not _waiting_item.is_empty():
		want = {"do": "item", "item": _waiting_item, "target": unit}
	elif not _waiting_skill.is_empty():
		want = {"do": "skill", "skill": _waiting_skill, "target": unit}
	if String(want["do"]) != "attack":
		var why := String(fight.call("useful", _acting, want))
		if why != "":
			_say_refusal(why)
			return
	Sfx.play("ui_click")
	if not _waiting_item.is_empty():
		_choose({"do": "item", "item": _waiting_item, "target": unit})
	elif _waiting_skill.is_empty():
		_choose({"do": "attack", "target": unit})
	else:
		_choose({"do": "skill", "skill": _waiting_skill, "target": unit})


static var auto_play := false      ## the player's Auto switch (kept from fight to fight)
var _auto_btn: Button


func _sync_auto_btn() -> void:
	_auto_btn.text = "Auto: ON" if auto_play else "Auto"
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_auto_btn.add_theme_color_override(key, UI.C_GOLD if auto_play else UI.C_PARCH)


## THE SPEED PLATE (x1 / x2 / x3, beside Auto): how fast blows and spells play out. Kept from fight
## to fight and in the settings ("battle_speed"). The hold-to-hurry of _fast_forward goes on top.
static var speed_pick := 1
var _speed_btn: Button


func _load_speed() -> void:
	var saved: Variant = Save.setting("battle_speed")        # (null before the settings know the key: 1)
	speed_pick = clampi(int(saved) if (saved is int or saved is float) else 1, 1, int(Looks.SPEEDS.back()))


func _sync_speed_btn() -> void:
	if not is_instance_valid(_speed_btn):
		return
	_speed_btn.text = "x%d" % speed_pick
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_speed_btn.add_theme_color_override(key, UI.C_GOLD if speed_pick > 1 else UI.C_PARCH)


func _cycle_speed() -> void:
	var at := Looks.SPEEDS.find(speed_pick)
	speed_pick = int(Looks.SPEEDS[(at + 1) % Looks.SPEEDS.size()])
	Save.set_setting("battle_speed", speed_pick)
	_sync_speed_btn()


## A small glass plate in the top right corner (Auto, the speed): a key cap on its left on PC.
func _corner_plate(action: Callable, cap: String, tip: String) -> Button:
	var b := UI.button("", action, "", "ui_click")
	b.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, UI.box("plate"))       # a small glass plate, so it reads as a button
	b.tooltip_text = tip
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	_root.add_child(b)
	if _ph:
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 8)
	else:
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var key := UI.prompt(cap, "")
		key.name = "Cap"
		key.set("outlined", false)
		b.add_child(key)
	return b


## Where the two plates sit: Auto in the corner, the speed plate left of it.
func _place_plates() -> void:
	var auto_size := Vector2(46, 14) if _ph else Vector2(92, 22)
	var speed_size := Vector2(24, 14) if _ph else Vector2(52, 22)
	var gap := 6.0 if _ph else 12.0
	var top := 4.0 if _ph else 10.0
	var right := -gap
	for pair: Array in [[_auto_btn, auto_size], [_speed_btn, speed_size]]:
		var b: Button = pair[0]
		var sz: Vector2 = pair[1]
		b.offset_right = right
		b.offset_left = right - sz.x
		b.offset_top = top
		b.offset_bottom = top + sz.y
		right -= sz.x + (3.0 if _ph else 6.0)
		var key := b.get_node_or_null("Cap") as Control
		if key != null:
			key.position = Vector2(6.0, roundf((sz.y - key.size.y) * 0.5))
	_plates_w = -right


var _plates_w := 0.0               ## how much of the top right corner the plates take (with their gaps)


## THE HELP STRIP keeps clear of the plates: on their row, its right edge 12 px left of them; when
## that would run it into the boss's bar it drops to a row of its own under them.
func _place_help() -> void:
	if not is_instance_valid(_help):
		return
	var row: Control = _help.get("_row")
	var w := row.get_combined_minimum_size().x if row != null else 0.0
	var room: Vector2 = _root.size
	var shown := is_instance_valid(_auto_btn) and _auto_btn.visible
	var side := (_plates_w + 6.0) if shown else 14.0
	var top := 10.0
	if shown and is_instance_valid(_boss) and room.x - side - w - 44.0 < _boss.position.x + _boss.size.x + 30.0:
		side = 14.0
		top = 10.0 + 22.0 + 6.0
	var m := Vector2(side, top)
	if m != (_help.get("margin") as Vector2):
		_help.set("margin", m)
		_help.call("_place")


func _toggle_auto() -> void:
	auto_play = not auto_play
	_sync_auto_btn()
	if auto_play and not _acting.is_empty():
		_choose(fight.call("auto_choice", _acting))        # somebody was waiting for an order: the bot gives it


func _choose(action: Dictionary) -> void:
	if _acting.is_empty():
		return
	_acting = {}
	_clear_menu()
	_menu.visible = false
	_menu_page = ""
	_skill_focus = -1
	_came_from = "commands"
	_set_help("")
	_picked.emit(action)


## The help strip (top right, PC; never on touch): what the keys do now.
func _set_help(state: String) -> void:
	if not is_instance_valid(_help):
		return
	var pairs: Array = []
	match state:
		"commands":
			pairs = [["confirm", "Choose"]]
		"skills":
			pairs = [["confirm", "Choose"], ["back", "Back"]]
		"aim":
			var verb := "Strike"
			if not _waiting_skill.is_empty() and (String(_waiting_skill.get("kind", "")) == "spell" or _waiting_skill.has("heal")):
				verb = "Cast"
			pairs = [["target", "Target"], ["confirm", verb], ["back", "Back"]]
		"fight":
			pairs = [["fast", "Hold: faster"]]
		"fast":
			pairs = [["fast", "Faster x%d" % int(minf(FF_SPEED * _pick, TIME_CAP))]]
	var key := str(pairs)
	if key == _help_key:
		return
	_help_key = key
	_help.call("set_pairs", pairs)
	_place_help()


# ------------------------------------------------------------------ the battle, turn by turn
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed, false).timeout
	if frozen:
		await _thaw()


## While the game is paused over the battle (`frozen`) nothing goes on: whoever waits, waits here.
func _thaw() -> void:
	while frozen and is_inside_tree():
		await get_tree().process_frame


## What happens, in the ribbon at the top middle (held 1.2 s, then it fades).
func _say(text: String) -> void:
	_ribbon.call("say", text, 1.2)


func _run(title: String) -> void:
	_say(title)
	await _wait(1.45 if Hd.on() and _speed <= 4.0 else 0.9)      # (HD: the camera comes down out of the sky first)
	while String(fight.call("result")) == "":
		if frozen:
			await _thaw()
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
			elif auto_play:
				await _wait(0.3)
				action = fight.call("auto_choice", who) if auto_play else {}
				if action.is_empty():                      # (switched off during the wait: he asks as usual)
					_acting = who
					_say("")
					_show_commands()
					action = await _picked
			else:
				_acting = who
				_say("")
				await _lessons_for(who)            # (P08: a first-fight lesson waits for the player first)
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
			_float(who, "Guard", UI.C_STEEL)
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
		"item":
			_say("%s uses a %s." % [String(who["name"]), String(first["item"]["name"])])
			Sfx.play("potion", -5.0)
			for e: Dictionary in events:
				if String(e["type"]) != "item":
					continue            # (P08: statuses, burns ... come after, in _play_extras)
				var t: Dictionary = e["target"]
				var at: Vector3 = (t["home"] as Vector3) + Vector3(0.0, float(t["top"]) * 0.5, 0.15)
				stage.call("burst", at, Color(0.55, 0.75, 1.0) if bool(e["mana"]) else Color(0.6, 1.0, 0.55), 0.7, 1.2)
				if bool(e.get("raised", false)):
					_stand_up(t)
				elif bool(e.get("cure", false)):
					pass
				else:
					_float(t, "+%d" % int(e["amount"]), UI.C_MP_A if bool(e["mana"]) else UI.C_GREEN)
			_refresh()
			await _wait(0.8)
	# (P08) what the rules added to the turn: statuses, burns, the Lantern, a phase, the raised
	await _play_extras(events)
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
			"burn":
				_refresh()
				if bool(e["dead"]) and String(e["target"]["side"]) == "foes" and is_instance_valid(e["target"]["node"]):
					(e["target"]["node"] as Node3D).visible = false
				await _wait(0.05)
			"flee", "say":
				await _wait(0.3)
			_:
				await _wait(0.05)
	_sync_lantern()
	_fx = []


# ------------------------------------------------------------------ the Lantern, statuses, lessons (quality pass P08)
## Shows what the rules added to a turn after its own move (fight.gd "NEW EVENTS"): a status put on or
## taken off, a burn's tick (and the fall it may cause), the Lantern changing hands, the flame, a
## boss's next phase, the whole side guarding, a fallen friend standing up, lines said mid-turn.
func _play_extras(events: Array) -> void:
	var first_type := String((events[0] as Dictionary).get("type", "")) if not events.is_empty() else ""
	for i in range(1, events.size()):
		var e: Dictionary = events[i]
		match String(e["type"]):
			"status":
				var t: Dictionary = e["target"]
				if int(e["turns"]) <= 0 or int(t.get("hp", 0)) <= 0:
					_refresh_one(t)
					continue
				var row: Dictionary = Battles.STATUS.get(String(e["id"]), {})
				var col: Color = BUI.STATUS_COL.get(String(e["id"]), UI.C_PARCH)
				_float(t, String(row.get("name", e["id"])), col, {"hold": 0.15})
				Sfx.play("debuff" if bool(row.get("bad", false)) else "buff", -8.0)
				_tint_pulse(t, col)
				_refresh_one(t)
				await _wait(0.18)
			"burn":
				var t: Dictionary = e["target"]
				if not is_instance_valid(t.get("node")):
					continue
				var col: Color = BUI.STATUS_COL.get(String(e.get("id", "burn")), Color(1.0, 0.5, 0.18))
				_float(t, "%d" % int(e["amount"]), col, {"dir": 0.0})
				_tint_pulse(t, col)
				Sfx.play("fire", -10.0)
				_refresh_one(t)
				if String(t["side"]) == "party":
					_row_jolt(t, 0.1)
				await _wait(0.3)
				if bool(e["dead"]):
					_die(t, {})
			"lantern":
				_lantern_to(e["who"], true)
				if bool(e.get("fell", false)):
					_say(String(Lessons.word("takes")) % String(e["who"]["name"]))
				await _wait(0.35)
			"flame":
				_sync_lantern()
				var holder: Dictionary = e.get("holder", {})
				if int(e["n"]) >= Battles.FLAME_MAX and int(e["was"]) < Battles.FLAME_MAX and not holder.is_empty():
					_float(holder, String(Lessons.word("flare_ready")), UI.C_GOLD, {"hold": 0.3})
					Sfx.play("flare", -10.0)
					_lamp_flare(1.6)
			"phase":
				var who: Dictionary = e["who"]
				if is_instance_valid(who.get("node")):
					track((who["home"] as Vector3) + Vector3(0.0, float(who["top"]) * 0.5, 0.0), 1.3, -0.25)
					shake(0.35)
					Sfx.play("boss_roar", -6.0)
				await _wait(0.6)
			"rally":
				for u: Dictionary in fight.call("alive", fight.party if String(e["who"]["side"]) == "party" else fight.foes):
					_float(u, "Guard", UI.C_STEEL)
			"heal":
				if bool(e.get("raised", false)):
					_stand_up(e["target"])
			"say":
				if String(e.get("text", "")) != "" and first_type != "say":
					_say(String(e["text"]))
					await _wait(0.55)
	_sync_lantern()


## The fighter's own pixels flash the colour of a status for a moment (the sprite3 shader's flash).
func _tint_pulse(u: Dictionary, col: Color) -> void:
	var node: Node = u.get("node")
	if not is_instance_valid(node) or _speed > 4.0:
		return
	node.call("set_flash", 0.4 * _flash_k(), col, 0.0)
	_later(0.22, node, func(n: Node) -> void: n.call("set_flash", 0.0))


## A fallen friend stands up again (the reverse of anim_moves.gd collapse()).
func _stand_up(u: Dictionary) -> void:
	var node: Node = u.get("node")
	var a: Node = u.get("actor")
	if not is_instance_valid(node) or not is_instance_valid(a):
		return
	_float(u, String(Lessons.word("raised")), UI.C_GOOD, {"hold": 0.3})
	Sfx.play("revive", -4.0)
	stage.call("ground_glow", u["home"], Color(1.0, 0.85, 0.5, 0.8), 1.4, 0.6)
	if Art.has_anim(String(u["sprite"]), "idle"):
		node.call("play", "idle")
	for c in node.get_children():
		if c is Node3D and (c == u.get("sword") or (u.get("hands", []) as Array).has(c)):
			(c as Node3D).visible = true
	var tw := a.create_tween().set_parallel(true)
	tw.tween_property(a, "lean", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(a, "kick", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void: a.set("lift", 0.3 * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.35)
	tw.chain().tween_callback(func() -> void: a.set("breath", 0.022))
	_refresh_one(u)


## The cards' lantern and flames, and the warm light over whoever carries it.
func _sync_lantern() -> void:
	var holder: Dictionary = fight.get("lantern")
	var flame := int(fight.get("flame"))
	for card: Control in _cards:
		var on := is_same(card.get("unit"), holder)
		if bool(card.get("holder")) != on or int(card.get("flame")) != flame:
			card.set("holder", on)
			card.set("flame", flame)
			card.queue_redraw()
	if not is_same(holder, _lamp_unit):
		_lantern_to(holder, false)


## The Lantern's light: a warm OmniLight3D at the carrier's shoulder; it glides to a new carrier.
func _lantern_to(u: Dictionary, show: bool) -> void:
	_lamp_unit = u
	if stage == null or u.is_empty() or not (u.get("home") is Vector3):
		return
	var at: Vector3 = (u["home"] as Vector3) + Vector3(0.35, float(u.get("top", 1.6)) * 0.75, 0.6)
	if _lamp == null:
		_lamp = OmniLight3D.new()
		_lamp.light_color = Color(1.0, 0.72, 0.38)
		_lamp.omni_range = 3.2
		_lamp.light_energy = 1.1
		_lamp.shadow_enabled = false
		stage.add_child(_lamp)
		_lamp.position = at
	if not show or _speed > 4.0:
		_lamp.position = at
		_sync_lantern_cards(u)
		return
	_float(u, String(Lessons.word("lantern_taken")), UI.C_GOLD, {"hold": 0.2})
	Sfx.play("lantern_pass", -4.0)
	var tw := _lamp.create_tween()
	tw.tween_property(_lamp, "position", at + Vector3(0.0, 0.8, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lamp, "position", at, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_lamp_flare(1.0)
	stage.call("ground_glow", u["home"], Color(1.0, 0.75, 0.4, 0.7), 1.1, 0.5)
	_sync_lantern_cards(u)


func _sync_lantern_cards(u: Dictionary) -> void:
	for card: Control in _cards:
		card.set("holder", is_same(card.get("unit"), u))
		card.set("flame", int(fight.get("flame")))
		card.queue_redraw()


## The Lantern blazes up for a moment (a pass, a full flame).
func _lamp_flare(mult: float) -> void:
	if _lamp == null or _speed > 4.0:
		return
	var tw := _lamp.create_tween()
	tw.tween_property(_lamp, "light_energy", 1.1 + 2.4 * mult, 0.08)
	tw.tween_property(_lamp, "light_energy", 1.1, 0.5)


## The "Lantern" order: the one choosing takes it. Free: the orders come back, the turn goes on.
func _on_lantern() -> void:
	if not is_instance_valid(_lantern_row) or _refused(_lantern_row) or _passing:
		return
	var events: Array = fight.call("take_lantern", _acting)
	if events.is_empty():
		return
	_passing = true
	_clear_menu()
	_menu.visible = false
	_set_help("")
	_say(String(Lessons.word("takes")) % String(_acting["name"]))
	_lantern_to(_acting, true)
	_refresh(_acting)
	await _wait(0.6)
	_passing = false
	if not _acting.is_empty() and not _over:
		_show_commands()


## Does the order being aimed stand a FALLEN friend up?
func _raising() -> bool:
	if not _waiting_item.is_empty():
		return _waiting_item.has("raise")
	return not _waiting_skill.is_empty() and _waiting_skill.has("raise") and String(_waiting_skill.get("aim", "")) == "friend"


## An order that would be wasted: the refusal sound and its reason; the turn is not spent.
func _say_refusal(why: String) -> void:
	Sfx.play("shop_deny")
	_ribbon.call("say", why, 1.6)
	if is_instance_valid(_detail):
		_detail.text = why
		_detail.modulate = UI.C_BAD


## The reason an item from the pack would do nothing for anybody ("" = it would help somebody).
func _item_why(item: Dictionary) -> String:
	var first := ""
	var who: Array = [_acting]
	who.append_array(fight.party)
	for u: Dictionary in who:
		var why := String(fight.call("useful", _acting, {"do": "item", "item": item, "target": u}))
		if why == "":
			return ""
		if first == "":
			first = why
	return first


## The aiming plate's lines under a monster's bar: what it means to do, its kind (??? until one was
## beaten), the damage the order being aimed would do.
func _plate_lines(u: Dictionary) -> Array:
	var out: Array = []
	var it: Dictionary = u.get("intent", {})
	if not it.is_empty() and not bool(it.get("done", false)) and String(it.get("text", "")) != "":
		out.append([String(it["text"]), BUI.intent_col(String(it.get("icon", ""))).lerp(UI.C_PARCH, 0.3)])
	for p: Array in BUI.pips_of(u):
		var row: Dictionary = Battles.STATUS.get(String(p[0]), {})
		if not row.is_empty():
			out.append(["%s (%d): %s" % [String(row.get("name", p[0])), int(p[2]), String(row.get("text", ""))], p[1]])
	var known := int(Save.hub_get("kills:" + String(u["id"]))) > 0
	var line := String(u.get("line", ""))
	if line != "" and not _ph:
		out.append([line if known else String(Lessons.word("unknown_kit")), UI.C_DIM])
	if not _acting.is_empty() and _waiting_item.is_empty():
		var power := 1.0
		var opts := {}
		if not _waiting_skill.is_empty():
			power = float(_waiting_skill.get("power", 1.0))
			opts = {"pierce": bool(_waiting_skill.get("pierce", false)), "bonus": _waiting_skill.get("bonus", {})}
		if power > 0.0:
			var r: Array = fight.call("preview", _acting, u, power, opts)
			out.append([String(Lessons.word("preview")) % [int(r[0]), int(r[1])], UI.C_GOLD])
	return out


## LESSONS (scripts/data/lessons.gd): one card, once, while Settings > Tutorial hints is on. Waits for
## the player to close it. Never in a test run (the bot) and never twice.
func _lesson(id: String) -> void:
	if _auto or _lesson_open or Lessons.seen(id) or Save.setting("hints") == false or G.flag("nolessons"):
		return
	var row := Lessons.row(id)
	if row.is_empty():
		return
	Save.set_flag("taught:b_" + id)
	_lesson_open = true
	var card: Control = LessonCard.new()
	_root.add_child(card)
	card.call("setup", String(row["title"]), String(row["text"]))
	card.call("centre")
	await card.done
	_lesson_open = false


## Which lesson (if any) this turn of the player's teaches, the first that applies.
func _lessons_for(who: Dictionary) -> void:
	await _lesson("orders")
	if (fight.call("alive", fight.party) as Array).size() > 1:
		await _lesson("lantern")
	for u: Dictionary in fight.call("intents"):
		var icon := String((u.get("intent", {}) as Dictionary).get("icon", ""))
		if icon == "heavy" or icon == "all":
			await _lesson("guard")
			break
	if float(who["hp"]) < float(who["max_hp"]) * 0.4 and not Supplies.bag().is_empty():
		await _lesson("items")
	if story == "" and int(Save.hub_get("wild_fights")) >= 2:
		await _lesson("speed")


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
			_float(target, "+%d" % int(e["amount"]), Num.C_HEAL, {"heal": true})
			Sfx.play("pickup", -6.0)
			var node: Node = target["node"]
			node.call("set_flash", 0.45 * _flash_k(), Color(0.6, 1.0, 0.65))
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


func _flash_k() -> float:
	return 0.5 if _reduced() else 1.0


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
	var fk := _flash_k()                # (Settings > Reduce flashes: half as bright)
	if party_hit:
		node.call("set_flash", 0.4 * fk, Color(1.0, 0.42, 0.32), 0.12 * fk)
	else:
		node.call("set_flash", minf(strength * 0.5, 0.45) * fk, Color(1.0, 0.85, 0.45) if crit else Color.WHITE, 0.0)
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
		Num.bump(_combo[key], ("%d" % shown), Num.C_CRIT if crit else Color(0, 0, 0, 0))
	else:
		var l := _float(target, ("%d" % shown), Num.C_CRIT if crit else Num.C_DAMAGE, {"dir": d, "crit": crit, "hold": 0.22 * float(parts - 1 - part)})
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
	node.call("set_flash", 0.45 * _flash_k(), Color.WHITE, 0.0)
	if is_instance_valid(u.get("glow")):
		# (a boss's pool of light dies with it)
		var pool: MeshInstance3D = u["glow"]
		var tg := pool.create_tween()
		tg.tween_property(pool.material_override, "albedo_color:a", 0.0, 0.8)
		tg.tween_callback(pool.queue_free)
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
	fade.tween_method(func(v: float) -> void: node.call("set_flash", v, Color.WHITE, 0.0), 0.35 * _flash_k(), 0.0, 0.08 if boss else 0.12)
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
	if _reduced():
		return                             # Settings > Reduce flashes: no freeze frames either
	await _slow_motion(slow, duration, true)


## Slows the whole game to `scale` for `seconds` of real time (a hit-stop; a boss's fall).
## `hurry`: the speed plate shortens it (a hit-stop); a slow-motion MOMENT is never hurried by it.
func _slow_motion(scale: float, seconds: float, hurry: bool = false) -> void:
	_stop_id += 1
	var mine := _stop_id
	_stop_k = scale
	_stop_pick = hurry
	_apply_time()
	# (process_always, not physics, IGNORE the time scale: or the timer itself would crawl)
	await get_tree().create_timer(seconds / (_ff * (_pick if hurry else 1.0)), true, false, true).timeout
	if mine == _stop_id:
		_stop_k = 1.0
		_stop_pick = true
		_apply_time()


const TIME_CAP := 6.0              ## the speed plate times the hold-to-hurry never plays faster than this

func _apply_time() -> void:
	if frozen:
		return                             # (paused: the time scale is 1 for the pause screen; set right again on thawing)
	var want := _stop_k * minf(_ff * (_pick if _stop_pick else 1.0), TIME_CAP)
	if not is_equal_approx(Engine.time_scale, want):
		Engine.time_scale = want


## Settings > Reduce flashes (the setting "flashes" = "reduced"; unset = full).
func _reduced() -> bool:
	var v: Variant = Save.setting("flashes")
	return v is String and String(v) == "reduced"


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
	var top_y := float(_ribbon.position.y) + float(_ribbon.call("band_h")) + (16.0 if _ph else 30.0)
	p = Vector2(clampf(p.x, 24.0, maxf(room.x - 24.0, 24.0)), clampf(p.y, top_y, maxf(room.y - 30.0, top_y + 10.0)))
	# (round three: bigger in HD, and numbers popping off one fighter close together stack upwards
	# instead of landing on one another: a volley's "CRITICAL 46 28" collided)
	var key := str(unit.get("home"))
	var now := Time.get_ticks_msec()
	var last: Array = _num_stack.get(key, [-100000, -1])
	var n := int(last[1]) + 1 if now - int(last[0]) < 650 else 0
	_num_stack[key] = [now, n]
	p.y = maxf(p.y - (15.0 if _ph else 26.0) * float(n % 3), top_y)
	var o := opts.duplicate()
	if not text.is_valid_int() and not text.begins_with("+"):
		o["word"] = true
	return Num.pop(_root, p, text, colour, o)


# ------------------------------------------------------------------ the end
func _finish() -> void:
	_over = true
	_menu.visible = false
	_xp_was = Rpg.xp()                 # (what the XP bars on the victory panel fill up from)
	_lvl_was = Rpg.level()
	var outcome := String(fight.call("result"))
	var summary := {"spot": spot, "story": story, "rounds": int(fight.round_no), "xp": 0, "coins": 0, "gear": "", "levels": 0}
	var lines: Array = []
	var head := "Victory!"
	if outcome == "win":
		var reward := Battles.reward(fight.foes, _tier, fight.get("stats"))     # (P08: deeds pay a bonus)
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
				for s: Dictionary in Skills.LIST.filter(func(r: Dictionary) -> bool: return int(r["level"]) == lvl):
					lines.append("A teacher can now teach: %s" % String(s["name"]))
					summary["opens_skill"] = true
			Skills.fill_empty()
		if String(reward["gear"]) != "" and Gear.grant(String(reward["gear"])):
			lines.append("Found: %s" % String(Gear.row(String(reward["gear"]))["name"]))
		if String(reward.get("supply", "")) != "" and Supplies.give(String(reward["supply"])) > 0:
			lines.append("Found: a %s" % String(Supplies.row(String(reward["supply"]))["name"]))
		# (v0.38.0) the hurt stay hurt; a new level makes everybody whole
		Wounds.keep(fight.party)
		if int(summary["levels"]) > 0:
			Wounds.rest()
			lines.append("Everybody is rested by the new level.")
		# every monster beaten is counted (the bestiary reads "kills:<id>")
		for f: Dictionary in fight.foes:
			Save.hub_set("kills:" + String(f["id"]), Save.hub_get("kills:" + String(f["id"])) + 1)
		# A STORY FIGHT IS WON FOR GOOD HERE, not on "Continue": the story moves on and is written to
		# the save at once (closing the game on the victory panel used to lose the win). main.gd
		# sees summary["applied"] and does not apply it again (twice is harmless: a step never goes back).
		if story != "":
			var did: Dictionary = Tale.apply(_win_do)
			summary["applied"] = true
			summary["say"] = String(did.get("say", "Won"))
			for k: String in did:
				if k != "say":
					summary["do_" + k] = did[k]      # (what else the win asks for: "battle", "screen")
		Save.flush()
		Sfx.victory()
	elif outcome == "lose":
		head = "You fall..."
		# (v0.38.0) it costs something: a share of the coins, and the way back. (quality pass) But
		# only once the player picks "Rest and return" on the Fallen screen (_give_in); "Try again"
		# costs nothing. The bot has no screen: it pays at once.
		summary["night"] = night
		lines.append(Looks.word("fallen"))
		if not _auto:
			Sfx.sting("defeat")                     # (P08: the sad piece; the battle music stops)
		if _auto:
			_give_in(summary)
	else:
		outcome = "fled"
		head = "You got away"
		Wounds.keep(fight.party)
		Save.flush()
	if G.flag("autoplay"):
		print("[battle] autoplay result=%s rounds=%d" % [outcome, int(fight.round_no)])
	if _auto and G.flag("animend") and outcome != "fled":
		await _closing(outcome == "win")            # test: the victory poses / the defeat, under the bot too
		if G.flag("shotend") and G.arg("shots", "") != "":
			await _end_shot(outcome, summary, lines, head)
		await _wait(1.6)
	if _auto:
		print("[battle] result=%s rounds=%d xp=%d coins=%d party_hp=%s" % [outcome, int(fight.round_no), int(summary["xp"]), int(summary["coins"]),
			(fight.party as Array).map(func(u: Dictionary) -> int: return int(u["hp"]))])
		finished.emit(outcome, summary)
		return
	if outcome == "fled":
		_ribbon.call("say", head, 1.2)
		await _wait(0.3)
		finished.emit(outcome, summary)
		return
	_say("")
	await _closing(outcome == "win")
	if outcome == "win":
		# (P08) lessons of a won fight: wounds stay; a level only opens a skill
		var hurt := false
		for u: Dictionary in fight.party:
			hurt = hurt or int(u["hp"]) < int(u["max_hp"])
		if hurt and int(summary["levels"]) == 0:
			await _lesson("beds")
		if bool(summary.get("opens_skill", false)):
			await _lesson("teach")
	_end_screen(outcome, summary, lines, head)


## A LOST FIGHT, taken as lost: a share of the coins is gone and everybody wakes rested in bed.
func _give_in(summary: Dictionary) -> void:
	var lost := _coins_at_stake()
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") - lost)
	Wounds.rest()
	summary["lost"] = lost
	Save.flush()


func _coins_at_stake() -> int:
	return roundi(float(Save.hub_get("bank:coins")) * LOSE_COINS)


## A LOST FIGHT, fought again: wounds and supplies are as they were when it began, no coins are
## taken, and main.gd starts the same battle anew (outcome "retry"; spot, night and story are in
## the summary).
func _try_again(summary: Dictionary) -> void:
	_restore_snapshot()
	summary["night"] = night
	summary["retry"] = true
	finished.emit("retry", summary)


## THE END OF A BATTLE on the screen. Won: VICTORY in big gold letters with a light sweeping over
## them, then a glass panel: a row per fighter (coin, name, the XP counting up, the XP bar filling,
## LEVEL UP when it comes), the coins, new skills, gear found in its rarity colour, and Continue.
## Lost: FALLEN in a dark red over the red veil, today's two lines, Continue.
func _end_screen(outcome: String, summary: Dictionary, lines: Array, _head: String) -> Button:
	_ribbon.call("unpin")
	_ribbon.call("say", "", 0.0)
	_menu.visible = false
	_warn.visible = false
	_set_help("")
	# (the turn order and the boss's bar are done with: they make way for the result)
	var done: Array = [_rail, _boss]
	for plate: Button in [_auto_btn, _speed_btn]:
		if is_instance_valid(plate):
			plate.visible = false          # (Auto and the speed have nothing to do with the result)
	if _ph:
		done.append_array(_cards)          # (the phone's panel needs the whole height)
	for c: Control in done:
		if is_instance_valid(c):
			UI.pop_out(c, false)
	var room: Vector2 = _root.size
	var won := outcome == "win"
	# (the cards under the panel show the level the party has NOW, not the one it came in with)
	for card: Control in _cards:
		if is_instance_valid(card) and int(card.get("level")) != Rpg.level():
			card.set("level", Rpg.level())
			card.queue_redraw()
	var banner: Control = BUI.Banner.new()
	banner.call("setup", "Victory" if won else "Fallen", UI.C_GOLD if won else Color(0.80, 0.40, 0.36),
		Color(0.45, 0.25, 0.05, 0.6) if won else Color(0.2, 0.0, 0.0, 0.6))
	_root.add_child(banner)
	banner.call("fit", room.x)
	banner.position = Vector2(0, roundf(room.y * (0.05 if _ph else 0.11)))
	UI.pop_in(banner, Vector2(0, -6))
	banner.call("play_sweep", 0.25)
	var col := UI.vbox(2 if _ph else 4)
	var holder: Control = col
	var width := minf(room.x - 40.0, 236.0) if _ph else 300.0
	if won:
		var panel := UI.panel("panel")
		panel.add_child(col)
		holder = panel
		_victory_rows(col, summary, lines)
	var go: Button
	if won:
		go = UI.button("Continue", func() -> void: finished.emit(outcome, summary), "Big", "ui_start")
		go.custom_minimum_size.x = 90.0 if _ph else 130.0
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(go)
	else:
		# FALLEN: two ways on. "Try again" (the same fight, as you walked into it, nothing lost) or
		# "Rest and return" (today's way: a share of the coins, and you wake in your bed). The words
		# under the buttons follow the focus, so the cost is read before it is paid.
		for line: String in lines:
			var l := UI.label(line, "Hud")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 9 if _ph else 13)
			col.add_child(l)
		var stake := _coins_at_stake()
		var what := UI.label("", "Hud", width - 8.0)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		what.add_theme_font_size_override("font_size", 9 if _ph else 13)
		what.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
		what.add_theme_constant_override("outline_size", 3)
		what.custom_minimum_size.y = 22.0 if _ph else 34.0
		col.add_child(what)
		var row := UI.hbox(6 if _ph else 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		go = UI.button(Looks.word("try_again"), func() -> void: _try_again(summary), "Big", "ui_start")
		var rest := UI.button(Looks.word("rest"), func() -> void:
			_give_in(summary)
			finished.emit(outcome, summary), "Big", "ui_click")
		var texts := {go: Looks.word("try_again_text"),
			rest: (Looks.word("rest_text") % stake) if stake > 0 else Looks.word("rest_text_free")}
		for b: Button in [go, rest]:
			b.custom_minimum_size.x = 96.0 if _ph else 138.0
			row.add_child(b)
			var say: String = texts[b]
			b.focus_entered.connect(func() -> void: what.text = say)
			b.mouse_entered.connect(func() -> void:
				if is_instance_valid(b) and not b.has_focus():
					b.grab_focus())
		go.focus_neighbor_right = go.get_path_to(rest)
		rest.focus_neighbor_left = rest.get_path_to(go)
		col.add_child(row)
		what.text = String(texts[go])
	_root.add_child(holder)
	var hs := holder.get_combined_minimum_size()
	holder.size = Vector2(width, hs.y)
	var under: float = banner.position.y + banner.size.y + (2.0 if _ph else 6.0)
	holder.position = Vector2(roundf((room.x - width) * 0.5), roundf(minf(under, room.y - hs.y - 4.0)))
	UI.pop_in(holder)
	go.grab_focus.call_deferred()
	return go


func _victory_rows(col: VBoxContainer, summary: Dictionary, lines: Array) -> void:
	var gain := int(summary["xp"])
	var levels := int(summary["levels"])
	var from := clampf(float(_xp_was) / float(Rpg.need(_lvl_was)), 0.0, 1.0)
	var to := Rpg.fill()
	var i := 0
	for u: Dictionary in fight.party:
		var row := UI.hbox(4 if _ph else 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := UI.medallion(String(u["sprite"]), 5.0 if _ph else 9.0, UI.C_STEEL, false, u.get("tint", Color.WHITE))
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if int(u["hp"]) <= 0:
			m.call("set_ko", true)
		row.add_child(m)
		var nm := UI.label(String(u["name"]), "Name")
		nm.custom_minimum_size.x = 50.0 if _ph else 78.0
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var xp := UI.label("+0 XP", "Num")
		xp.add_theme_color_override("font_color", UI.C_XP_A)
		xp.custom_minimum_size.x = 38.0 if _ph else 58.0
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(xp)
		var bar := UI.bar("xp", 44.0 if _ph else 100.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.call("set_value", from, 1.0, false)
		row.add_child(bar)
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UI.box("tag"))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tl := UI.label("Level %d" % Rpg.level() if levels > 0 else "Level up", "Head")
		tl.add_theme_font_size_override("font_size", 7 if _ph else 10)
		tl.add_theme_color_override("font_color", UI.C_GOLD)
		tag.add_child(tl)
		tag.modulate.a = 0.0
		row.add_child(tag)
		col.add_child(row)
		_count_up(xp, bar, tag, gain, from, to, levels, 0.35 + 0.1 * i)
		i += 1
	col.add_child(HSeparator.new())
	var coins := UI.hbox(5)
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := UI.coin(3.5 if _ph else 5.0)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.add_child(disc)
	var cl := UI.label("+%d coins" % int(summary["coins"]), "Num")
	cl.add_theme_color_override("font_color", UI.C_GOLD)
	coins.add_child(cl)
	for line: String in lines:
		if line.begins_with("Level "):
			var ll := UI.label(line.replace("!  ", "!   "), "Gold")
			ll.add_theme_font_size_override("font_size", 8 if _ph else 11)
			ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ll.clip_text = true
			coins.add_child(ll)
	col.add_child(coins)
	# (P08) the deeds the fight earned (battles.gd DEED), gold rows ticking in one after another
	var d := 0
	for id: Variant in summary.get("deeds", []):
		var deed: Dictionary = Battles.DEED.get(String(id), {})
		if deed.is_empty():
			continue
		var drow := UI.hbox(6)
		drow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dn := UI.label(String(Lessons.word("deed")) % String(deed["name"]), "Gold")
		dn.add_theme_font_size_override("font_size", 8 if _ph else 11)
		drow.add_child(dn)
		var dt := UI.label(String(deed.get("text", "")), "Dim")
		dt.add_theme_font_size_override("font_size", 7 if _ph else 10)
		dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drow.add_child(dt)
		var db := UI.label(String(Lessons.word("deed_bonus")) % roundi(Battles.DEED_BONUS * 100.0), "Num")
		db.add_theme_color_override("font_color", UI.C_GOLD)
		db.add_theme_font_size_override("font_size", 8 if _ph else 11)
		drow.add_child(db)
		col.add_child(drow)
		if not UI.instant:
			drow.modulate.a = 0.0
			var tw := drow.create_tween()
			tw.tween_interval(0.9 + 0.3 * d)
			tw.tween_callback(func() -> void: Sfx.play("coins", -10.0))
			tw.tween_property(drow, "modulate:a", 1.0, 0.2)
		d += 1
	for line: String in lines:
		if line.begins_with("New skill: "):
			var sl := UI.label(line, "Gold")
			sl.add_theme_font_size_override("font_size", 9 if _ph else 12)
			col.add_child(sl)
	var gear_id := String(summary.get("gear", ""))
	for line: String in lines:
		if line.begins_with("Found: ") and gear_id != "":
			var row := UI.hbox(5)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var g := Gear.row(gear_id)
			if Art.has(String(g.get("icon", ""))):
				row.add_child(UI.icon(String(g["icon"]), 12.0 if _ph else 16.0))
			var fl := UI.label("Found:", "Dim")
			fl.add_theme_font_size_override("font_size", 9 if _ph else 12)
			row.add_child(fl)
			var gl := UI.label(String(g.get("name", "")), "Name")
			gl.add_theme_color_override("font_color", [UI.C_COMMON, UI.C_RARE, UI.C_EPIC][clampi(int(g.get("rarity", 0)), 0, 2)])
			row.add_child(gl)
			col.add_child(row)
	col.add_child(UI.spacer(0, 2 if _ph else 4))


## A fighter's row: "+38 XP" counts up while the bar fills; past the top it says LEVEL UP and
## fills again from empty.
func _count_up(xp: Label, bar: Control, tag: Control, gain: int, from: float, to: float, levels: int, delay: float) -> void:
	if UI.instant or not xp.is_inside_tree():
		xp.text = "+%d XP" % gain
		bar.call("set_value", to if levels == 0 else to, 1.0, false)
		tag.modulate.a = 1.0 if levels > 0 else 0.0
		return
	var tw := xp.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: xp.text = "+%d XP" % roundi(v), 0.0, float(gain), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tb := bar.create_tween()
	tb.tween_interval(delay)
	if levels == 0:
		tb.tween_method(func(v: float) -> void: bar.call("set_value", v, 1.0, false), from, to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	# a level up: the bar fills to the top, flashes and holds there a moment (LEVEL n pops), then
	# rolls over and fills again from empty to what is left over
	tb.tween_method(func(v: float) -> void: bar.call("set_value", v, 1.0, false), from, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.tween_callback(_level_up_tag.bind(tag))
	tb.tween_property(bar, "modulate", Color(1.8, 1.6, 1.2), 0.06)
	tb.tween_property(bar, "modulate", Color.WHITE, 0.35)
	tb.tween_interval(0.35)
	tb.tween_method(func(v: float) -> void: bar.call("set_value", v, 1.0, false), 0.0, to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


var _level_sung := false
func _level_up_tag(tag: Control) -> void:
	if not is_instance_valid(tag):
		return
	tag.modulate.a = 1.0
	tag.pivot_offset = tag.size * 0.5
	tag.scale = Vector2(1.5, 1.5)
	tag.create_tween().tween_property(tag, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _level_sung:
		_level_sung = true
		Sfx.sting("level_up")              # (P08: once, not once per row)


## Test: --shotend (with --autobattle --animend --shots=<dir>) writes battle_end.png with the
## victory / defeat screen up (a look only: the bot's battle then ends as usual).
func _end_shot(outcome: String, summary: Dictionary, lines: Array, head: String) -> void:
	_end_screen(outcome, summary, lines, head)
	await get_tree().create_timer(float(G.arg("endwait", "1.8")), true, false, true).timeout
	DirAccess.make_dir_recursive_absolute(G.arg("shots", ""))
	get_viewport().get_texture().get_image().save_png(G.arg("shots", "").path_join("battle_end.png"))


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
		tf.tween_property(_fade, "color:a", 0.45 * _flash_k(), 0.08)
		tf.tween_property(_fade, "color:a", 0.0, 0.5)
		tf.tween_property(_fade, "color", Color(0.05, 0.03, 0.02, 0.28), 0.6)
		var tp := create_tween()
		tp.tween_property(self, "_push", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# (round three: and in on the party's middle, not up at the sky)
		var mid := Vector3.ZERO
		var alive: Array = fight.call("alive", fight.party)
		for u: Dictionary in alive:
			mid += u["home"] as Vector3
		if not alive.is_empty():
			track(mid / float(alive.size()) + Vector3(0.0, 1.2, 0.0), 2.0, 0.45)
	else:
		# the defeat: everybody already lies where he fell; the camera sinks slowly, all goes dark red
		_fade.color = Color(0.12, 0.0, 0.02, 0.0)
		var tl := create_tween()
		tl.tween_property(_fade, "color:a", 0.62, 1.0)
		track(Vector3(-4.0, 0.4, 0.5), 2.0, 0.35)
	await _wait(0.75)


## The phone's Back button, Esc or B. Returns true when it was used here (one step back in the
## menu, or the result is on the screen); FALSE on the orders page and while the others act: there
## is nothing to step back to, so main.gd opens its pause screen over the battle (and sets `frozen`).
func on_back() -> bool:
	if _over:
		return true
	return _step_back()


## One step back in the orders (skills / items / aiming). False when there is no step to take.
func _step_back() -> bool:
	if _acting.is_empty() or _over:
		return false
	match _menu_page:
		"skills", "items":
			Sfx.play("ui_back")
			_show_commands(true)
			return true
		"aim":
			Sfx.play("ui_back")
			if not _waiting_item.is_empty():
				_show_items(true)
			elif _waiting_skill.is_empty():
				_show_commands(true)
			else:
				_show_skills(true)
			return true
	return false


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
	if G.flag("shotitems"):
		# test: --shotitems writes battle_items.png (the pack), uses a herb on the knight, then battle_herb.png
		for u: Dictionary in fight.party:
			u["hp"] = maxi(1, int(u["max_hp"]) / 3)
		_refresh()
		_show_items()
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_items.png"))
		var before := int(fight.party[0]["hp"])
		_on_item(Supplies.row("herb"))
		await get_tree().create_timer(0.3).timeout
		_target_picked(fight.party[0], "friend")
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_herb.png"))
		print("[battle] herb test: knight %d -> %d, herbs left %d" % [before, int(fight.party[0]["hp"]), Supplies.count("herb")])
	if G.flag("shotlantern"):
		# test (P08): --shotlantern writes battle_lantern.png: a full flame (the Flare row on top), a
		# burn and a weakness on show, then battle_lesson.png with a lesson card over it (a look only)
		fight.set("lantern", _acting)
		fight.set("flame", Battles.FLAME_MAX)
		var ev: Array = []
		fight.call("add_status", fight.foes[0], "burn", 0, ev)
		if (fight.party as Array).size() > 1:
			fight.call("add_status", fight.party[1], "weak", 0, ev)
		_refresh(_acting)
		_show_commands()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_lantern.png"))
		var card: Control = LessonCard.new()
		_root.add_child(card)
		var row := Lessons.row("lantern")
		card.call("setup", String(row["title"]), String(row["text"]))
		card.call("centre")
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_lesson.png"))
		card.queue_free()
		_show_commands()
		await get_tree().create_timer(0.2).timeout
	if G.flag("shotmenu"):
		_show_skills()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_skills.png"))
		_show_commands(true)
		await get_tree().create_timer(0.2).timeout
	if G.flag("shotaim"):
		# test: --shotaim writes battle_target.png while aiming an Attack (on the second monster)
		_on_attack()
		await get_tree().create_timer(0.2).timeout
		_cycle(1)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_target.png"))
		on_back()
		await get_tree().create_timer(0.2).timeout
	if G.flag("shotheal"):
		# test: --shotheal writes battle_heal.png while the one acting aims a heal at a friend
		for sk: Dictionary in _acting.get("skills", []):
			if sk.has("heal"):
				_waiting_skill = sk
				_ask_target("friend", "Tap who gets it.")
				break
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_heal.png"))
		on_back()
		await get_tree().create_timer(0.2).timeout
	if G.flag("shotfallen"):
		# test: --shotfallen writes battle_fallen.png: the lost fight's screen with "Try again" and
		# "Rest and return" (a look only: nothing is taken, the game quits after the picture)
		_acting = {}
		_clear_menu()
		_over = true
		await _closing(false)
		_end_screen("lose", {"spot": spot, "story": story, "night": night}, [Looks.word("fallen")], "")
		await get_tree().create_timer(1.6, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_fallen.png"))
	if G.flag("shotwarn"):
		# test: --shotwarn writes battle_warn.png with the boss's "Guard!" plate over the orders (a look only)
		_show_commands()
		_warn_on = true
		(_warn.get_child(0) as Label).text = "%s draws back for a great blow at everybody. Guard!" % String(fight.foes[0]["name"])
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("battle_warn.png"))
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
	# (PC: while you choose, the picture slides right just enough that the panel clears the one
	# whose turn it is; it slides back when the turn is played)
	_lean = lerpf(_lean, _lean_want, 1.0 - exp(-6.0 * real))
	pos.x -= _lean
	look.x -= _lean
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
	_ui_frame()


## The screen, every frame: each monster's button and bar follow it, the aimed one gets the
## brackets (and its plate), the chevron bobs over the one whose turn it is, the panel keeps its
## corner, the help strip says what the keys do now.
func _ui_frame() -> void:
	if _root == null:
		return
	var aimed := _aimed()
	if _over:
		aimed = {}
	_aim_look(aimed)
	# the chevron: over the one whose turn it is; while aiming it bobs over the one aimed at instead
	var arrow_on: Dictionary = aimed if not aimed.is_empty() else _turn_unit
	_arrow.visible = not arrow_on.is_empty() and not _over and (not aimed.is_empty() or (String(_turn_unit.get("side", "")) == "party" and _aim == ""))
	if _arrow.visible:
		var r := _sprite_rect(arrow_on)
		# (never up among the turn-order coins: the chevron stays under the rail's bottom)
		var rail_bottom := float(_rail.position.y) + float(_rail.size.y) + 8.0
		_arrow.position = Vector2(r.get_center().x, maxf(r.position.y - (3.0 if _ph else 6.0), rail_bottom if r.get_center().x < float(_rail.size.x) + 20.0 else 12.0)).round()
	for tag: Dictionary in _tags:
		var u: Dictionary = tag["unit"]
		var b: Button = tag["button"]
		var r := _sprite_rect(u)
		b.position = r.position.round()
		b.size = r.size.round()
		var bar: Control = tag["bar"]
		bar.visible = int(u["hp"]) > 0 and not bool(u.get("boss", false)) and not is_same(u, aimed) and not _over
		# (under the feet, on the ground line: every monster's bar sits at the same height above
		# its own shadow, whatever the shape of its head)
		bar.position = Vector2(r.get_center().x - bar.size.x * 0.5, r.end.y + (3.0 if _ph else 5.0)).round()
		# (P08) the intent chip over its head, the status pips right of its bar
		var marks: Control = tag.get("marks")
		if is_instance_valid(marks):
			marks.visible = not _over and int(u["hp"]) > 0 and _intro <= 0.0
			marks.set("show_intent", not is_same(u, aimed))
			var top := maxf(r.position.y - (2.0 if _ph else 4.0), float(_rail.position.y) + float(_rail.size.y) + (12.0 if _ph else 16.0))
			if bool(u.get("boss", false)):
				top = maxf(r.position.y + r.size.y * 0.12, top)
			marks.set("head_at", Vector2(r.get_center().x, top))
			var feet := bar.position + Vector2(bar.size.x + 3.0, -2.0)
			if bool(u.get("boss", false)):
				feet = Vector2(r.get_center().x - 12.0, r.end.y + 4.0)
			marks.set("feet_at", feet)
			marks.call("sync")
	_brackets.set("shown", not aimed.is_empty())
	if not aimed.is_empty():
		_brackets.set("box", _sprite_rect(aimed).grow(3.0 if not _ph else 2.0))
	var plate_on := not aimed.is_empty() and String(aimed["side"]) == "foes"
	_plate.visible = plate_on
	if plate_on:
		var key := String(aimed["id"]) + str(aimed["home"]) + ":" + str(aimed["hp"]) + str(aimed.get("status", {})) + str((aimed.get("intent", {}) as Dictionary).get("text", "")) + str(_waiting_skill.get("id", ""))
		if key != _plate_key:
			_plate.set("lines", _plate_lines(aimed))
			_plate.call("set_unit", aimed, _plate_key.begins_with(String(aimed["id"]) + str(aimed["home"]) + ":"))
			_plate_key = key
		var box := _sprite_rect(aimed)
		var ps: Vector2 = _plate.size
		var room: Vector2 = _root.size
		var min_y := float(_ribbon.position.y) + float(_ribbon.call("band_h")) + 4.0
		var py := maxf(box.position.y - 22.0 - ps.y, min_y)      # (over the chevron that bobs above the head)
		var px := box.get_center().x - ps.x * 0.5
		if _ph:
			# (the phone's monsters stand close: over the head the plate covered the next one's
			# bar and body, so there it goes under the feet, where the bar was)
			py = minf(box.end.y + 3.0, room.y - ps.y - 2.0)
		elif box.position.y - 22.0 - ps.y < min_y:
			# (P08: a taller plate with its lines does not fit over the head: beside the monster instead,
			# on the side with more room)
			py = clampf(box.get_center().y - ps.y * 0.5, min_y, room.y - ps.y - 4.0)
			px = box.position.x - ps.x - 10.0 if box.get_center().x > room.x * 0.5 else box.end.x + 10.0
		_plate.position = Vector2(clampf(px, 4.0, room.x - ps.x - 4.0), py).round()
	else:
		_plate_key = ""
	for card: Control in _cards:
		card.call("set_targeted", _aim == "friend" and is_same(card.get("unit"), aimed))
	_place_menu()
	_want_lean()
	if _acting.is_empty():
		_set_help("" if _over or _intro > 0.0 else ("fast" if _ff > 1.0 else "fight"))


## FAST-FORWARD: while the fight plays out (never while you choose), holding a button plays the
## animations FF_SPEED times as fast. A tap is not a hold (FF_HOLD), so the press that picked an
## order never speeds up its own blow by accident. The bottom corner says how.
func _fast_forward(real: float) -> void:
	if _speed > 4.0:
		return
	var choosing := not _acting.is_empty()
	var held := not choosing and not _over and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
		or Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or (InputMap.has_action("fast") and Input.is_action_pressed("fast"))
		or Input.is_joy_button_pressed(maxi(0, Controls.active_pad), JOY_BUTTON_A) or Input.is_joy_button_pressed(maxi(0, Controls.active_pad), JOY_BUTTON_RIGHT_SHOULDER))
	_hold_t = _hold_t + real if held else 0.0
	var latched: bool = _ff_latch and not choosing and not _over and Save.setting("ff_toggle") == true
	var want := FF_SPEED if (_hold_t >= FF_HOLD or latched) else 1.0
	# (the speed plate: only while the fight plays out, never while you choose or read the result)
	var pick := float(speed_pick) if (not choosing and not _over and _intro <= 0.0) else 1.0
	if want != _ff or pick != _pick:
		_ff = want
		_pick = pick
		_apply_time()
