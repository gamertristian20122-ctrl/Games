extends Node
## Main: the game's front door. It owns the flow between screens:
##   boot -> title -> hero select -> run -> (pause) -> game over or victory -> title
## It creates the run exactly as scripts/core/g.gd describes and frees it when the run ends.
## The screens themselves live in scripts/ui; each one only SENDS a request ("play",
## "start", "back" ...) and _on_action() below decides what happens next.
##
## Command-line flags (after "--"):
##   --autotest         no menus: start a run at once (--hero, --seed); a new one starts when it ends
##   --uitour           walk through every screen with a fake run and save screenshots (--shots=<dir>)
##   --uitour=flow      play the whole flow with the REAL game using key presses, and check each step
##   --time=<sec>       quit after this much game time
##   --fakerun          use the fake run (scripts/ui/dev_fake_run.gd) instead of the real one
##   --safe=l,t,r,b     pretend the phone has a notch this many game pixels deep on each side
##   --fonts=<dir>      try display.ttf / body.ttf from a folder outside the project

const UI = preload("res://scripts/ui/theme.gd")
const Heroes = preload("res://scripts/data/heroes.gd")

## Every menu screen by name. To add a screen: write scripts/ui/<name>.gd (it extends
## screen.gd), add it here, and open it from _on_action().
const SCREENS := {
	"title": "res://scripts/ui/title.gd",
	"hero_select": "res://scripts/ui/hero_select.gd",
	"pause": "res://scripts/ui/pause.gd",
	"end": "res://scripts/ui/end_screen.gd",
	"collection": "res://scripts/ui/collection.gd",
	"settings": "res://scripts/ui/settings.gd",
	"credits": "res://scripts/ui/credits.gd",
	"hub_talk": "res://scripts/ui/hub_talk.gd",
	"customize": "res://scripts/ui/customize.gd",
}
## Screens that keep the dungeon picture bright behind them; behind the others it is dimmed.
const BRIGHT := ["title", "hero_select"]
const RUN_SCRIPT := "res://scripts/run/run.gd"
const FAKE_RUN_SCRIPT := "res://scripts/ui/dev_fake_run.gd"
const HUB_SCRIPT := "res://scripts/hub/hub.gd"
const INTRO_SCRIPT := "res://scripts/hub/intro.gd"
const Quests = preload("res://scripts/data/quests.gd")
const Story = preload("res://scripts/data/story.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const Shop = preload("res://scripts/data/shop.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const HubData = preload("res://scripts/data/hub.gd")

var run: Node                    ## the game being played, or null on the menus
var hub: Node                    ## the camp between runs (scripts/hub/hub.gd), or null
var intro: Node                  ## the animated intro while it plays (scripts/hub/intro.gd), or null
var hud: CanvasLayer             ## scripts/ui/hud.gd
var touch: CanvasLayer           ## scripts/ui/touch.gd
var backdrop: Control            ## scripts/ui/backdrop.gd
var _world: Node                 ## runs are added under this node; it stops when the game is paused
var _menu: CanvasLayer
var _shade: ColorRect            ## darkens the frozen game behind the pause menu
var _fade: ColorRect
var _stack: Array[Control] = []  ## open screens, the last one is on top
var _names: Array[String] = []
var _busy := false               ## a fade is running: ignore buttons
var _ending := false             ## the run is over and the end screen is on its way
var _hero_id := "knight"
var _level_id := ""              ## the story level being played ("" = none)
var _waiting_talk: Variant = null    ## words that could not be shown yet (see _on_action "talk")
var _seed := 0
var _clock := 0.0
var _time_limit := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false       # the phone's Back button is handled in _back()
	_time_limit = float(G.arg("time", "0"))
	if _time_limit > 0.0 and G.flag("autotest"):
		_time_limit += 3.0             # the world's bot prints its report and quits first; this is the safety net
	var safe := G.arg("safe").split_floats(",")
	if safe.size() == 4:
		UI.fake_safe = Vector4(safe[0], safe[1], safe[2], safe[3])
	UI.font_dir_override = G.arg("fonts")
	_build_layers()
	G.run_ended.connect(_on_run_ended)
	G.note_found.connect(_on_note_found)
	Controls.pause_pressed.connect(_back)
	if G.flag("uitour"):
		UI.instant = G.arg("uitour") != "flow"       # the flow test keeps the animations on
		var tour: Node = load("res://scripts/ui/ui_tour.gd").new()
		tour.set("main", self)
		add_child(tour)
	elif G.flag("autotest"):
		if G.flag("yard"):               # --yard: the bot spars in the training yard
			G.next_run = {"training": true, "kit": []}
		if G.arg("level") != "":       # --level=<story level id>: the bot plays that level
			G.next_run = {"level": Story.level(G.arg("level")), "kit": []}
		start_run(G.arg("hero", "knight"), int(G.arg("seed", "1")))
	elif G.flag("intro"):
		show_intro()                   # test: --intro plays the cutscene at once
	elif G.flag("hub"):
		show_hub("village" if G.arg("hub") == "" else G.arg("hub"))
	else:
		_fade.color.a = 1.0
		show_title()
		_fade_to(0.0, 0.3)


func _build_layers() -> void:
	# main.gd never pauses, but the game must: runs live under a node that does.
	_world = Node.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/ui/hud.gd"))
	hud.name = "Hud"
	add_child(hud)
	touch = CanvasLayer.new()
	touch.set_script(load("res://scripts/ui/touch.gd"))
	touch.name = "Touch"
	add_child(touch)
	_menu = CanvasLayer.new()
	_menu.layer = G.LAYER_MENU
	_menu.name = "Menu"
	add_child(_menu)
	backdrop = Control.new()
	backdrop.set_script(load("res://scripts/ui/backdrop.gd"))
	backdrop.name = "Backdrop"
	_menu.add_child(backdrop)
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.02, 0.04, 0.66)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.visible = false
	_menu.add_child(_shade)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = G.LAYER_FADE
	fade_layer.name = "Fade"
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(UI.C_VOID, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	_refresh_layers()


func _process(delta: float) -> void:
	if _time_limit > 0.0:
		_clock += delta
		if _clock >= _time_limit:
			_time_limit = 0.0
			print("[main] --time reached after %.1f s of game time, quitting" % _clock)
			quit_game()


# ------------------------------------------------------------------ screens
## Opens a screen on top of the others. `setup` sets variables on it before it builds itself.
func open(screen_name: String, setup: Dictionary = {}) -> Control:
	var s: Control = (load(SCREENS[screen_name]) as Script).new()
	s.name = screen_name
	s.set("backdrop", backdrop)
	for key: String in setup:
		s.set(key, setup[key])
	if not _stack.is_empty():
		_stack.back().call("set_covered", true)
	_stack.append(s)
	_names.append(screen_name)
	s.connect("action", _on_action)
	_menu.add_child(s)
	_refresh_layers()
	return s


func close_top() -> void:
	if _stack.is_empty():
		return
	var s: Control = _stack.pop_back()
	_names.pop_back()
	s.queue_free()
	if not _stack.is_empty():
		_stack.back().call("set_covered", false)
	_refresh_layers()
	if _stack.is_empty():
		_show_waiting_talk.call_deferred()


func _show_waiting_talk() -> void:
	if _waiting_talk == null or _busy or not _stack.is_empty() or not is_instance_valid(hub):
		return
	var words: Variant = _waiting_talk
	_waiting_talk = null
	open("hub_talk", {"info": words})


func close_all() -> void:
	for s in _stack:
		s.queue_free()
	_stack.clear()
	_names.clear()
	_refresh_layers()


func top_name() -> String:
	return "" if _names.is_empty() else _names.back()


func top_screen() -> Control:
	return null if _stack.is_empty() else _stack.back()


func _refresh_layers() -> void:
	var in_run := run != null
	var in_hub := is_instance_valid(hub)
	backdrop.visible = not in_run and not in_hub and not is_instance_valid(intro)
	backdrop.call("set_dimmed", not _names.is_empty() and not (_names.back() in BRIGHT))
	_shade.visible = (in_run or in_hub) and not _stack.is_empty()
	hud.visible = in_run and _stack.is_empty()      # the pause menu shows its own numbers
	touch.set("hub_mode", in_hub)
	touch.call("set_active", (in_run or in_hub) and _stack.is_empty() and not _ending)
	if in_hub:
		hub.set("frozen", not _stack.is_empty())


func show_title() -> void:
	await _drop_run()
	_drop_hub()
	_drop_intro()
	get_tree().paused = false
	close_all()
	open("title")
	Sfx.music("title")


## The animated intro (scripts/hub/intro.gd). When it ends, or is skipped, you wake in your room.
func show_intro() -> void:
	await _drop_run()
	_drop_hub()
	get_tree().paused = false
	close_all()
	Save.hub_set("seen:cutscene", 1)
	intro = (load(INTRO_SCRIPT) as Script).new()
	intro.name = "Intro"
	intro.connect("finished", func() -> void:
		if G.flag("intro"):
			print("[main] intro finished")
		_busy = false
		_transition(show_hub))
	_world.add_child(intro)
	_refresh_layers()


func _drop_intro() -> void:
	if is_instance_valid(intro):
		intro.queue_free()
	intro = null


## The camp between runs: walk around, talk, pick a stage at the gate.
func show_hub(place: String = "", at: Vector2 = Vector2.INF) -> void:
	await _drop_run()
	_drop_intro()
	_drop_hub()
	get_tree().paused = false
	close_all()
	_ending = false
	hub = (load(HUB_SCRIPT) as Script).new()
	hub.name = "Hub"
	hub.set("start_place", place)          # "" = your room in the tavern (Places.START)
	hub.set("start_at", at)
	hub.connect("action", _on_action)
	_world.add_child(hub)
	_refresh_layers()
	Sfx.music("title")


func _drop_hub() -> void:
	if is_instance_valid(hub):
		hub.queue_free()
	hub = null
	_refresh_layers()


## Every request a screen can send ends up here.
func _on_action(what: String, arg: Variant) -> void:
	if what == "talk" and (_busy or not _stack.is_empty()):
		_waiting_talk = arg          # a story moment that came during a fade or over another window: shown right after
		return
	if _busy:
		return
	match what:
		"back":
			if top_name() == "pause" or (run != null and top_name() == "hub_talk"):
				resume()                # (a note read in a level closes like the pause menu)
			elif _stack.size() > 1 or is_instance_valid(hub):
				close_top()             # in the camp a talk window is the only screen open: Leave must close it
				if is_instance_valid(hub) and _stack.is_empty():
					hub.call("refresh_heroes")      # the mirror may have changed his looks
		"play":
			if Save.hub_get("seen:cutscene") == 0 and not G.flag("uitour"):
				_transition(show_intro)     # the first time: the animated intro, then your room
			else:
				_transition(show_hub)       # you wake in your room at the tavern
		"hub_train":
			G.next_run = {"training": true, "kit": Story.kit()}
			_transition(start_run.bind("knight", _fresh_seed()))
		"hub_shop":
			var ok := false
			if (arg as Dictionary).has("slot"):
				ok = Shop.buy_item(int(arg["slot"]))
			else:
				ok = Shop.buy_supply(String(arg["supply"]))
			Sfx.play("ui_start" if ok else "ui_back")
			close_top()
			if is_instance_valid(hub):
				hub.call("retalk")
		"talk":
			open("hub_talk", {"info": arg})
		"hub_level":
			_level_id = String(arg)
			_transition(_start_level)
		"hub_hero":
			Save.set_setting("last_hero", String(arg))
			close_top()
			if is_instance_valid(hub):
				hub.call("refresh_heroes")
		"hub_buy":
			if Upgrades.buy(String(arg)):
				Sfx.play("ui_start")
			close_top()
			if is_instance_valid(hub):
				hub.call("retalk")
		"hub_intro":
			_transition(show_intro)         # the bed: watch the intro again
		"hub_sleep":
			close_top()
			if is_instance_valid(hub):
				hub.call("sleep")
		"hub_notes":
			var pages: Array = []
			for i: int in Story.notes_found():
				pages.append(String(Story.NOTES[i]))
			close_top()
			open("hub_talk", {"info": {"name": "Notes from the hill", "title": "%d of %d" % [pages.size(), Story.NOTES.size()], "sprite": "hub_note", "pages": pages}})
		"hub_weapon":
			if Weapons.owned(String(arg)):
				Save.set_setting("weapon", String(arg))
				Sfx.play("ui_start")
			close_top()
			if is_instance_valid(hub):
				hub.call("refresh_heroes")
				hub.call("retalk")
		"hub_forge":
			var w := Weapons.row(String(arg))
			if not Weapons.owned(String(arg)) and Upgrades.coins() >= int(w.get("price", 9999)):
				Save.hub_set("bank:coins", Upgrades.coins() - int(w["price"]))
				Weapons.grant(String(arg))
				Sfx.play("ui_start")
			close_top()
			if is_instance_valid(hub):
				hub.call("retalk")
		"hub_claim":
			Quests.claim(String(arg))
			Sfx.play("ui_start")
			close_top()
			if is_instance_valid(hub):
				hub.call("retalk")
		"collection", "settings", "credits", "customize":
			open(what)
		"start":
			_transition(start_run.bind(String(arg), _fresh_seed()))
		"retry":
			if _level_id != "":
				_transition(_start_level)
			else:
				_transition(start_run.bind(_hero_id, _fresh_seed()))
		"menu":
			_transition(_back_to_world)       # after a run you stand at the gate you went in by
		"title":
			_transition(show_title)
		"resume":
			resume()
		"give_up":
			give_up()
		"leave_run":
			leave_run()
		"quit":
			quit_game()


func _fresh_seed() -> int:
	if G.args.has("seed"):
		return int(G.arg("seed"))
	return int(randi() % 1000000)


# ------------------------------------------------------------------ the run
## Starts a new run (and throws away the old one, if any).
func start_run(hero_id: String, seed_value: int) -> void:
	await _drop_run()
	_drop_hub()
	close_all()
	get_tree().paused = false
	_hero_id = hero_id
	_seed = seed_value
	_ending = false
	Save.set_setting("last_hero", hero_id)
	var path := RUN_SCRIPT
	if (G.flag("uitour") and G.arg("uitour") != "flow") or G.flag("fakerun") or not ResourceLoader.exists(RUN_SCRIPT):
		path = FAKE_RUN_SCRIPT
	run = (load(path) as Script).new()
	hud.call("begin", run)          # before setup(), so the HUD hears the run's first signals
	_world.add_child(run)
	run.call("setup", hero_id, seed_value)
	_refresh_layers()


## Goes down into the story level `_level_id` with the gear kept from earlier levels.
func _start_level() -> void:
	var lv := Story.level(_level_id)
	if lv.is_empty():
		return
	G.next_run = {"level": lv, "kit": Story.kit(), "pack": Quests.take_pack()}
	Shop.restock()                    # the barkeep's shelf changes while you are away
	await start_run("knight", _fresh_seed())       # Aldous is the only hero (weapons will be switchable later)


## Frees the current run and waits a frame so it is really gone before anything new starts.
func _drop_run() -> void:
	if run == null:
		return
	if is_instance_valid(run):
		run.queue_free()
	run = null
	hud.call("end")
	_refresh_layers()
	await get_tree().process_frame
	await get_tree().process_frame


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	if _ending or run == null:
		return
	_ending = true
	_refresh_layers()
	# story: "Try again" starts at the level he fell in; a win banks his coins at the camp
	if String(summary.get("level", "")) != "":
		_level_id = String(summary["level"])
		if victory:
			Story.walk_out(summary.get("items", []), int(summary.get("coins_held", 0)))
			summary["banked"] = int(summary.get("coins_held", 0))
		elif run.get("training") != true:
			summary["banked"] = Story.fall(int(summary.get("coins_held", 0)))
	if G.flag("autotest") and String(summary.get("level", "")) != "":
		print("[main] level %s victory=%s chapter=%d kit=%s joined=%s" % [summary["level"], victory, Story.chapter(), Story.kit(), summary.get("joined", "")])
	if G.flag("autotest"):
		print("[main] run ended: victory=%s floor=%s time=%ds kills=%s" % [
			victory, summary.get("floor", "?"), int(summary.get("time_s", 0)), summary.get("kills", "?")])
		_ending = false
		if run.has_method("restart") and is_instance_valid(run.get("bot")):
			return                      # the world's own bot starts the next run in the same node
		_seed += 1
		start_run.call_deferred(_hero_id, _seed)
		return
	# (the world has already let the death or the win play out before it sends run_ended)
	_show_end(victory, summary, 0.4)


func _show_end(victory: bool, summary: Dictionary, delay: float) -> void:
	if delay > 0.0 and not UI.instant:
		# a moment to see what happened before the screen changes
		await get_tree().create_timer(delay, false).timeout
	Sfx.music("victory" if victory else "gameover")
	var show := func() -> void:
		await _drop_run()
		get_tree().paused = false
		close_all()
		open("end", {"victory": victory, "summary": summary, "unlocks": Save.run_unlocks.duplicate()})
	_busy = false
	await _transition(show)


func pause() -> void:
	if run == null or _ending or _busy or not _stack.is_empty():
		return
	get_tree().paused = true
	Sfx.play("ui_click")
	open("pause", {"run": run})


func resume() -> void:
	close_all()
	get_tree().paused = false
	Save.flush()


## A note was picked up in a level: the game stops and its words are shown in the talk box.
func _on_note_found(index: int) -> void:
	if run == null or _ending or G.flag("autotest"):
		return
	get_tree().paused = true
	open("hub_talk", {"info": {"name": "A note", "title": "%d of %d" % [Story.notes_found().size(), Story.NOTES.size()], "sprite": "hub_note",
		"pages": [String(Story.NOTES[index])]}})


## Where a run puts you back: the village's crypt gate, or the glade for the Elfwood's levels.
func _back_to_world() -> void:
	if String(Story.level(_level_id).get("side", "")) == "forest":
		await show_hub("glade", Vector2(300, 236))
	else:
		await show_hub("village", HubData.GATE_SPOT)


## "Back to camp" in the pause menu (only offered while no fight is on): the hero walks out alive.
## He keeps his items, his coins go into the camp's chest, and cleared levels stay cleared.
func leave_run() -> void:
	if run == null or _ending:
		return
	var p: Variant = run.get("player")
	var yard: bool = run.get("training") == true       # nothing done in the yard is kept
	if is_instance_valid(p) and not yard:
		Story.walk_out(p.get("items"), int(p.get("coins")))
	_ending = true
	_busy = false
	if not yard and run.get("level") is Dictionary:
		_level_id = String((run.get("level") as Dictionary).get("id", _level_id))
	if yard:
		await _transition(show_hub.bind("village", Vector2(620, 330)))
	else:
		await _transition(_back_to_world)


## "Give up" in the pause menu: the run counts as lost and the end screen is shown.
func give_up() -> void:
	if run == null or _ending:
		return
	var summary := {}
	if run.has_method("summary"):
		summary = run.call("summary")
	summary["victory"] = false
	summary["cause"] = "gave_up"
	_ending = true
	Save.record_run(false, summary)
	_show_end(false, summary, 0.0)


func quit_game() -> void:
	Save.flush()
	G.quit()


# ------------------------------------------------------------------ back / pause
## Esc, the gamepad's Start, the on-screen pause button and the phone's Back button all land here:
## in a run it pauses, in a menu it goes back one step, on the title it asks before quitting.
func _back() -> void:
	if _busy:
		return
	if not _stack.is_empty():
		_stack.back().call("on_back")
	elif run != null:
		pause()
	elif is_instance_valid(intro):
		intro.call("skip")             # Back during the intro: skip it
	elif is_instance_valid(hub):
		_transition(show_title)        # Back in the camp: to the title


func _unhandled_input(event: InputEvent) -> void:
	# the gamepad's B button also means "back" while a menu is open
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and not _stack.is_empty():
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# the phone switched to another app: do not let the hero die meanwhile
		if run != null and not G.flag("autotest") and not G.flag("uitour"):
			pause()


# ------------------------------------------------------------------ fades
## Fades to black, runs `change`, fades back in. Buttons are ignored meanwhile.
func _transition(change: Callable) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	await change.call()
	await _fade_to(0.0)
	_busy = false
	_show_waiting_talk()


func _fade_to(alpha: float, time: float = 0.16) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if UI.instant:
		_fade.color.a = alpha
	else:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", alpha, time)
		await tw.finished
	if alpha <= 0.0:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
