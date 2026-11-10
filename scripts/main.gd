extends Node2D
## The conductor. It builds the screen, starts runs, loads one room after
## another, shows the reward cards, and ends the run on death or victory.
##
## The flow of a run:
##   room loads -> fight -> chest -> pick 1 of 3 -> door opens -> next room
##   ...five fights, then the floor's boss, for three floors.

signal run_ended(result: String)

const ENTER_DELAY := 0.55       # a breath before the enemies arrive

var args: Dictionary = {}
var world: Node2D               # the room and the keeper live here, below the top strip
var room: Room
var keeper: Player
var cam: Camera2D
var hud: Hud
var reward_ui: RewardScreen
var screens: Screens
var fade: ColorRect
var pointer: Sprite2D
var bot: BotRunner
var mode := "title"             # title, play, reward, pause, over

var _enter_timer := 0.0
var _end_timer := 0.0
var _end_result := ""
var _killer := ""
var _changing_room := false
var _shot_dir := ""
var _shot_every := 120
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	args = _read_args()
	_build_screen()
	Game.combo_found.connect(_on_combo_found)

	if args.has("report"):
		BotReport.write_from_folder(args["report"], args.get("out", "docs/balance_report.md"))
		get_tree().quit()
		return
	Game.god_mode = args.has("god")
	_shot_dir = args.get("shots", "")
	_shot_every = int(args.get("shot-every", "120"))
	if args.has("bot"):
		bot = BotRunner.new()
		add_child(bot)
		bot.begin(self, args)
	elif args.has("controls-check"):
		# Self-test of the keyboard, mouse and controller (see controls_check.gd).
		Game.god_mode = true
		_show_title()
		var check := ControlsCheck.new()
		add_child(check)
		check.begin(self)
	elif args.has("play") or args.has("demo"):
		begin_run(int(args.get("seed", "1")))
	else:
		_show_title()
	if args.has("screen"):
		_show_test_screen.call_deferred(args["screen"])


func _exit_tree() -> void:
	Sprites.forget()
	UiKit.forget()


## Reads options typed after "--" on the command line, such as "--bot --runs=20".
func _read_args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.substr(2).split("=", true, 1)
			out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out


func _build_screen() -> void:
	world = Node2D.new()
	world.name = "World"
	world.position = Vector2(0, Game.HUD_H)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	cam = Camera2D.new()
	cam.position = Vector2(240, 135)
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	pointer = Sprites.sprite(Sprites.CROSSHAIR, Pal.PAPER)
	pointer.visible = false
	layer.add_child(pointer)
	reward_ui = RewardScreen.new()
	reward_ui.chosen.connect(_on_reward_chosen)
	layer.add_child(reward_ui)
	screens = Screens.new()
	screens.picked.connect(_on_menu_picked)
	layer.add_child(screens)
	fade = ColorRect.new()
	fade.color = Color(Pal.INK, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


# ----------------------------------------------------------------------
# Starting and stopping runs
# ----------------------------------------------------------------------

func _show_title() -> void:
	_clear_world()
	mode = "title"
	get_tree().paused = false
	hud.visible = false
	reward_ui.visible = false
	screens.show_title()
	Sfx.music("title.ogg")


## Starts a new run. A negative seed means "pick one at random".
func begin_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	get_tree().paused = false
	screens.close()
	reward_ui.visible = false
	_clear_world()
	Game.new_run(seed_value)
	_apply_debug_start()

	keeper = Player.new()
	keeper.name = "Keeper"
	keeper.died.connect(_on_keeper_died)
	if bot != null:
		keeper.brain = bot.brain
	elif args.has("demo"):
		# "--demo" lets the bot play in a normal window so you can watch.
		keeper.brain = BotBrain.new()
		keeper.brain.setup(args.get("skill", "ok"), seed_value)
	world.add_child(keeper)
	hud.set_keeper(keeper)
	hud.visible = true
	mode = "play"
	_end_result = ""
	_killer = ""
	_load_room()


## Test option "--screen=options|pause|lost|won": jumps straight to a menu so
## its layout can be checked (used together with "--shots").
func _show_test_screen(which: String) -> void:
	if which == "options":
		screens.show_options()
		return
	begin_run(int(args.get("seed", "1")))
	_apply_debug_start()
	await get_tree().create_timer(1.5).timeout
	match which:
		"pause":
			mode = "pause"
			get_tree().paused = true
			screens.show_pause()
		"lost":
			_on_keeper_died("clawling")
		"won":
			keeper.active = false
			_end_result = "win"
			_end_timer = 0.3


## Test options: "--floor=2 --room=5 --give=prism,twin_lens" jump ahead in a run.
func _apply_debug_start() -> void:
	if args.has("floor"):
		Game.floor_index = clampi(int(args["floor"]), 0, FloorDB.count() - 1)
	if args.has("room"):
		Game.room_index = clampi(int(args["room"]), 0, int(Game.floor_def()["rooms"]))
	if args.has("give"):
		for id: String in String(args["give"]).split(","):
			Game.add_item(id.strip_edges())
	if args.has("random-items"):
		for i in int(args["random-items"]):
			var offers := ItemDB.roll_offers(Game.rng, Game.items, 1, false, Game.hp, Game.hp)
			if not offers.is_empty():
				Game.add_item(offers[0])


func _clear_world() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
	room = null
	if keeper != null and is_instance_valid(keeper):
		keeper.queue_free()
	keeper = null
	hud.watch_boss(null)
	_changing_room = false


func _load_room() -> void:
	if room != null and is_instance_valid(room):
		room.set_physics_process(false)
		room.queue_free()
	var is_boss := Game.is_boss_room()
	var plan := RoomLayouts.pick(Game.rng, is_boss)
	room = Room.new()
	room.name = "Room"
	room.setup(Game.floor_def(), "boss" if is_boss else "fight", plan, Game.rng.randi(), keeper)
	room.cleared.connect(_on_room_cleared)
	room.chest_opened.connect(_on_chest_opened)
	room.exit_reached.connect(_on_exit_reached)
	world.add_child(room)
	world.move_child(room, 0)       # draw the room underneath the keeper
	keeper.enter_room(room)
	keeper.active = true
	_enter_timer = ENTER_DELAY
	_changing_room = false

	var floor_info := Game.floor_def()
	hud.watch_boss(null)
	hud.set_place(floor_info["name"], Game.room_index + 1, int(floor_info["rooms"]), is_boss)
	hud.show_hint(_hint_for_room())
	if Game.room_index == 0:
		hud.banner(String(floor_info["name"]).to_upper(), floor_info["blurb"], floor_info["accent"], 2.8)
	Sfx.music("boss.ogg" if is_boss else "floor_%d.ogg" % (Game.floor_index + 1))


## A few words of teaching in a player's first runs.
func _hint_for_room() -> String:
	if Game.bot_mode or Game.total_runs >= 3 or (keeper != null and keeper.brain != null):
		return ""
	match Game.rooms_cleared:
		0:
			return "Right stick aims and fires. A dashes." if Controls.using_pad \
					else "WASD to move. Aim with the mouse and hold left click to fire."
		1:
			return "The blue ghost is your echo. It repeats what you did in the last room."
		2:
			return "Stand close to your echo to fire faster. That is called Unison."
		3:
			return "A dashes through shots." if Controls.using_pad else "Space dashes through shots."
	return ""


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if mode == "play" and Game.run_active:
		Game.run_time += delta
		if _enter_timer > 0.0:
			_enter_timer -= delta
			if _enter_timer <= 0.0 and room != null:
				room.start_fight()
				keeper.start_recording()
	if _end_result != "":
		_end_timer -= delta
		if _end_timer <= 0.0:
			_finish_run()


func _process(delta: float) -> void:
	# Screen shake.
	if Game.shake_amount > 0.05:
		var amount := Game.shake_amount * Settings.screen_shake
		cam.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		Game.shake_amount = move_toward(Game.shake_amount, 0.0, delta * 22.0)
	else:
		cam.offset = Vector2.ZERO
		Game.shake_amount = 0.0

	if room != null and is_instance_valid(room) and room.boss != null and is_instance_valid(room.boss):
		hud.watch_boss(room.boss)
	_update_pointer()
	_frame += 1
	if _shot_dir != "" and _frame % _shot_every == 0:
		_save_screenshot()
	if args.has("quit-after") and _frame >= int(args["quit-after"]):
		get_tree().quit()


## The aiming mark: under the mouse, or ahead of the keeper on a controller.
func _update_pointer() -> void:
	var playing := mode == "play" and keeper != null and is_instance_valid(keeper) and keeper.alive and keeper.brain == null
	pointer.visible = playing
	var want_mouse := Input.MOUSE_MODE_HIDDEN if playing and not Controls.using_pad else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want_mouse and bot == null:
		Input.mouse_mode = want_mouse
	if not playing:
		return
	if Controls.using_pad:
		pointer.position = keeper.global_position + keeper.aim_dir * 34.0
		pointer.region_rect = Sprites.region(Sprites.RETICLE)
	else:
		pointer.position = get_viewport().get_mouse_position()
		pointer.region_rect = Sprites.region(Sprites.CROSSHAIR)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) and screens.go_back():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if mode == "play" and _end_result == "":
			mode = "pause"
			get_tree().paused = true
			screens.show_pause()
			Sfx.play("ui_back")
		elif mode == "pause":
			_resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and mode == "pause":
		_resume()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_toggle_autoplay()


func _resume() -> void:
	mode = "play"
	screens.close()
	get_tree().paused = false


## F9 lets the test bot take over (or hand back) in the middle of a run.
func _toggle_autoplay() -> void:
	if keeper == null or bot != null:
		return
	if keeper.brain == null:
		var brain := BotBrain.new()
		brain.setup("ok", randi())
		keeper.brain = brain
		hud.banner("BOT PLAYING", "Press F9 to take back control.", Pal.ECHO, 2.0)
	else:
		keeper.brain = null
		hud.banner("YOU HAVE CONTROL", "", Pal.PAPER, 1.5)


func _on_menu_picked(key: String) -> void:
	match key:
		"start", "restart":
			begin_run()
		"resume":
			_resume()
		"title":
			_show_title()
		"quit":
			get_tree().quit()


# ----------------------------------------------------------------------
# What happens inside a run
# ----------------------------------------------------------------------

func _on_room_cleared() -> void:
	hud.show_hint("")
	var tape := keeper.stop_recording()
	Game.push_tape(tape)
	Game.room_cleared(room.clock, keeper.hits_this_room, room.kind)
	var final_boss := room.kind == "boss" and Game.floor_index >= FloorDB.count() - 1
	if final_boss:
		keeper.active = false
		_end_result = "win"
		_end_timer = 0.0 if Game.fast_mode else 1.8
		Sfx.play("win")
		Sfx.music("victory.ogg")
		return
	room.show_chest()


func _on_chest_opened() -> void:
	var offers := ItemDB.roll_offers(Game.rng, Game.items, 3, room.kind == "boss", Game.hp, Game.max_hp)
	if offers.is_empty():
		room.open_exit()
		return
	if keeper.brain != null and bot != null:
		_on_reward_chosen(keeper.brain.choose_reward(offers))
		return
	mode = "reward"
	hud.show_hint("")
	get_tree().paused = true
	reward_ui.open(offers, room.kind == "boss")
	if keeper.brain != null:
		# The bot is playing in a window: show the cards for a moment, then pick.
		var pick := keeper.brain.choose_reward(offers)
		get_tree().create_timer(1.6, true).timeout.connect(func() -> void:
			if mode == "reward":
				_on_reward_chosen(pick))


func _on_reward_chosen(id: String) -> void:
	reward_ui.visible = false
	get_tree().paused = false
	mode = "play"
	var was_treat := ItemDB.is_treat(id)
	Game.add_item(id)
	Sfx.play("heal" if was_treat else "pickup")
	if room != null and not Game.fast_mode:
		var item := ItemDB.get_item(id)
		Fx.words(room, keeper.position - Vector2(0, 8), item.get("name", ""), Pal.GOLD)
	room.open_exit()


func _on_combo_found(combo_id: String) -> void:
	if Game.fast_mode:
		return
	var combo: Dictionary = ItemDB.COMBOS[combo_id]
	hud.banner("COMBO: " + String(combo["name"]).to_upper(), combo["text"], Pal.GOLD, 3.2)
	Sfx.play("combo")


func _on_exit_reached() -> void:
	if _changing_room:
		return
	_changing_room = true
	keeper.active = false
	if not Game.advance_room():
		_end_result = "win"
		_end_timer = 0.0
		return
	if Game.fast_mode:
		_load_room()
		return
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.16)
	tween.tween_callback(_load_room)
	tween.tween_property(fade, "color:a", 0.0, 0.22)


func _on_keeper_died(killer: String) -> void:
	_killer = killer
	_end_result = "death"
	_end_timer = 0.0 if Game.fast_mode else 1.3
	Sfx.music("")
	if room != null:
		room.state = "over"


## Ends the run early (the bot uses this if it ever gets stuck).
func abort_run(reason: String) -> void:
	if not Game.run_active:
		return
	_killer = reason
	_end_result = "stalled"
	_end_timer = 0.0


func _finish_run() -> void:
	var result := _end_result
	_end_result = ""
	var tape: EchoTape = keeper.stop_recording() if keeper != null and is_instance_valid(keeper) else null
	Game.end_run(result == "win", _killer, tape)
	if result == "stalled":
		Game.metrics["result"] = "stalled"
	mode = "over"
	if keeper != null and is_instance_valid(keeper):
		keeper.active = false
	run_ended.emit(result)
	if bot != null:
		return
	var killer_name: String = EnemyDB.get_enemy(_killer).get("name", "the dark")
	screens.show_end(result == "win", killer_name)


func _save_screenshot() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/shot_%05d.png" % [_shot_dir, _frame])
