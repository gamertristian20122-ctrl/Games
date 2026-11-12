extends Node
## UI tour (testing only): walks through every screen and HUD state with the fake run and
## saves one screenshot of each, then quits. Nothing is written to the save file.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 -- --uitour --shots=/tmp/shots
## Run it at 1280x720 (16:9) and 1600x720 (20:9 phone) and LOOK at the pictures.
## When you add a screen or a HUD state, add a step for it in _run_tour().
##
## A second mode, --uitour=flow, plays the real game's whole flow with key presses (title ->
## hero select -> run -> pause -> settings -> death -> try again -> give up -> menu) and prints
## "[flow] ok ..." or "[flow] FAIL ..." for every step. Use it after changing main.gd.

const UI = preload("res://scripts/ui/theme.gd")
const Items = preload("res://scripts/data/items.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")

var main: Node            ## scripts/main.gd, set by it
var _count := 0
var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if G.arg("uitour") == "flow":
		_run_flow.call_deferred()
	else:
		_run_tour.call_deferred()


func _settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _settle()
	_count += 1
	var file := "%02d_%s.png" % [_count, shot_name]
	await G.save_shot(file)
	print("[tour] ", file)


## Pretends a finger touches the screen at a position given in game pixels.
func _touch(finger: int, game_pos: Vector2, pressed: bool) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / UI.screen_size(self)
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.position = game_pos * scale
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(finger: int, game_pos: Vector2) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / UI.screen_size(self)
	var ev := InputEventScreenDrag.new()
	ev.index = finger
	ev.position = game_pos * scale
	Input.parse_input_event(ev)


func _items(n: int) -> Array[String]:
	var ids: Array = Items.ALL.keys()
	var out: Array[String] = []
	for i in n:
		out.append(String(ids[i % ids.size()]))
	return out


func _first_cursed() -> String:
	for id: String in Items.ALL:
		if Items.ALL[id].get("cursed", false):
			return id
	return String(Items.ALL.keys()[0])


func _first_normal() -> String:
	for id: String in Items.ALL:
		if not Items.ALL[id].get("cursed", false):
			return id
	return String(Items.ALL.keys()[0])


func _run_tour() -> void:
	var size := UI.screen_size(self)
	print("[tour] screen is %d x %d game pixels, pixel fonts: %s" % [size.x, size.y, UI.pixel_fonts])
	Controls.using_touch = true
	Controls.device_changed.emit(true)

	# ---- menus
	main.call("show_title")
	await _shot("title")
	main.call("open", "hero_select")
	await _shot("hero_select")
	main.call("top_screen").call("select", 1)
	await _shot("hero_locked")

	# ---- HUD states on the fake run
	await main.call("start_run", "knight", 1)
	var run: Node = main.get("run")
	var hud: Node = main.get("hud")
	run.call("set_health", 1, 2, 0)
	await _shot("hud_one_heart_floor_banner")
	hud.call("clear_popups")
	run.call("set_health", 15, 18, 3)
	run.get("player").set("keys", 2)
	run.get("player").set("bombs", 3)
	run.get("player").set("items", _items(17))
	run.call("add_coins", 137)
	run.set("kills", 48)
	run.call("explore")
	await _settle(0.8)
	await _shot("hud_nine_hearts_armor_items")
	G.toast.emit("Secret found", "The wall gives way.")
	await _shot("toast")
	hud.call("clear_popups")
	run.call("give_item", _first_normal())
	await _shot("item_card")
	hud.call("clear_popups")
	run.call("give_item", _first_cursed())
	await _shot("item_card_cursed")
	hud.call("clear_popups")
	run.call("start_boss")
	run.get("boss").set("hp", 62.0)
	await _shot("boss_bar")
	G.stat.emit("boss_killed:test_warden", 1)
	await _shot("unlock_banner")
	hud.call("clear_popups")

	# ---- touch controls: both sticks held, action button on
	Controls.action_enabled = true
	_touch(0, Vector2(58, 128), true)
	_drag(0, Vector2(74, 116))
	_touch(1, Vector2(size.x - 70, 124), true)
	_drag(1, Vector2(size.x - 86, 112))
	await _shot("touch_both_sticks_action")
	print("[tour] sticks: move=%s aim=%s" % [Controls.move, Controls.aim])
	_touch(0, Vector2.ZERO, false)
	_touch(1, Vector2.ZERO, false)
	Controls.action_enabled = false

	# ---- pause, give up, settings
	main.call("pause")
	await _shot("pause")
	main.call("top_screen").call("_ask_give_up")
	await _shot("pause_give_up_question")
	main.call("top_screen").call("close_dialog")
	main.call("open", "settings")
	await _shot("settings")
	Save.set_setting("armour", "crimson")
	Save.set_setting("sword_look", "elven")
	main.call("open", "customize")
	await _shot("customize")
	Save.set_setting("armour", "steel")
	Save.set_setting("sword_look", "knight")
	main.call("close_top")
	main.call("close_top")
	main.call("resume")

	# ---- game over with unlocks, then victory
	G.stat.emit("secret_found", 2)
	G.stat.emit("chest_opened", 10)
	run.call("finish", false)
	await _settle(0.6)
	await _shot("game_over_unlocks")
	await main.call("start_run", "knight", 2)
	run = main.get("run")
	run.get("player").set("items", _items(9))
	run.call("add_coins", 212)
	run.set("kills", 164)
	run.set("time_s", 1085.0)
	run.set("floor_index", 2)
	run.set("floor_name", "The Drowned Archive")
	run.call("finish", true)
	await _settle(0.6)
	await _shot("victory")

	# ---- collection: empty, then half full
	Save.reset_progress()
	await main.call("show_title")
	main.call("open", "collection")
	await _shot("collection_empty")
	main.call("top_screen").call("show_tab", 1)
	await _shot("feats_empty")
	var ids: Array = Items.ALL.keys()
	for i in ids.size():
		if i % 2 == 0:
			Save.mark_seen(String(ids[i]))
	Save.mark_seen(_first_cursed())
	for stat: Array in [["runs", 23], ["wins", 2], ["wins:knight", 2], ["deaths", 21], ["best_floor", 3], ["fastest_win", 1085],
			["total_kills", 1312], ["total_coins", 644], ["boss_killed:test_warden", 4], ["secret_found", 3], ["chest_opened", 7], ["cursed_taken", 2]]:
		Save.stat_add(stat[0], stat[1])
	Save.check_unlocks()
	main.call("top_screen").call("show_tab", 0)
	main.call("top_screen").call("_select_item", _first_cursed())
	await _shot("collection_half")
	main.call("top_screen").call("show_tab", 1)
	await _shot("feats_some")
	main.call("top_screen").call("show_tab", 2)
	await _shot("stats")
	main.call("close_top")

	# ---- credits, settings from the title, the two questions
	main.call("open", "credits")
	await _shot("credits")
	main.call("close_top")
	main.call("open", "settings")
	main.call("top_screen").call("_ask_reset")
	await _shot("settings_reset_question")
	main.call("close_top")
	main.call("top_screen").call("on_back")
	await _shot("title_quit_question")

	print("[tour] done, %d screenshots" % _count)
	G.quit()


# ------------------------------------------------------------------ the flow test (--uitour=flow)
func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _check(what: String, ok: bool) -> void:
	_count += 1
	if ok:
		print("[flow] ok    ", what)
	else:
		_fails += 1
		print("[flow] FAIL  ", what)


func _focus_text() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return String(f.get("text")) if f != null and f.get("text") != null else ""


func _run_flow() -> void:
	main.call("show_title")
	await _settle()
	_check("title is open", main.call("top_name") == "title")
	_check("Play has the focus", _focus_text() == "Play")
	await G.save_shot("flow_01_title.png")
	await _key(KEY_DOWN)
	_check("down moves focus to Collection", _focus_text() == "Collection")
	await _key(KEY_UP)
	# a finger tap on Play (touch reaches buttons as an emulated mouse click)
	var play := get_viewport().gui_get_focus_owner()
	var centre := play.get_global_rect().get_center()
	_touch(0, centre, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(0, centre, false)
	await _settle()
	_check("a tap on Play opens the camp", is_instance_valid(main.get("hub")))
	_check("a touch switches to touch controls", Controls.using_touch)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc in the camp goes back to the title", main.call("top_name") == "title" and not is_instance_valid(main.get("hub")))
	main.call("open", "hero_select")
	await _settle()
	await _key(KEY_RIGHT)
	_check("a key switches them off again", not Controls.using_touch)
	_check("right shows the next hero", String(main.call("top_screen").call("current")["id"]) != "knight")
	await _key(KEY_LEFT)
	_check("left goes back to the first hero", String(main.call("top_screen").call("current")["id"]) == "knight")
	# a swipe to the left shows the next hero too
	_touch(0, Vector2(110, 60), true)
	await get_tree().process_frame
	_drag(0, Vector2(70, 62))
	await get_tree().process_frame
	_touch(0, Vector2(50, 62), false)
	await _settle()
	_check("a swipe changes the hero", String(main.call("top_screen").call("current")["id"]) != "knight")
	await _key(KEY_LEFT)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc goes back to the title", main.call("top_name") == "title")
	main.call("open", "hero_select")
	await _settle()
	await _key(KEY_ENTER)
	await _settle(1.2)
	var run: Node = main.get("run")
	_check("Start creates a run", is_instance_valid(run) and G.run == run)
	_check("menus are closed during the run", main.call("top_name") == "")
	_check("the HUD is showing", main.get("hud").visible)
	if not is_instance_valid(run):
		G.quit(1)
		return
	await _settle(1.5)
	await G.save_shot("flow_02_run.png")

	# pause and resume
	var before := float(run.get("time_s"))
	await _key(KEY_ESCAPE)
	await _settle(0.8)
	_check("Esc pauses", get_tree().paused and main.call("top_name") == "pause")
	_check("the run's clock stands still while paused", absf(float(run.get("time_s")) - before) < 0.3)
	await G.save_shot("flow_03_pause.png")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _settle()
	_check("Settings opens from the pause menu", main.call("top_name") == "settings")
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc returns to the pause menu", main.call("top_name") == "pause" and get_tree().paused)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc resumes", not get_tree().paused and main.call("top_name") == "")
	var t2 := float(run.get("time_s"))
	await _settle(0.6)
	_check("the run's clock runs again", float(run.get("time_s")) > t2)

	# die
	var deaths := Save.stat_get("deaths")
	run.call("player_died", "the flow test")
	await _settle(3.5)
	_check("death opens the end screen", main.call("top_name") == "end")
	_check("the run was freed", main.get("run") == null and G.run == null)
	_check("the death was recorded once", Save.stat_get("deaths") == deaths + 1 and Save.stat_get("runs") == deaths + 1)
	await G.save_shot("flow_04_game_over.png")
	_check("Try again has the focus", _focus_text() == "Try again")
	await _key(KEY_ENTER)
	await _settle(1.5)
	run = main.get("run")
	_check("Try again starts a new run", is_instance_valid(run) and main.call("top_name") == "")

	# give up
	await _key(KEY_ESCAPE)
	await _settle()
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	_check("Give up can be reached", _focus_text() == "Give up")
	await _key(KEY_ENTER)
	await _settle()
	_check("the question keeps the safe answer focused", _focus_text() == "Keep going")
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	await _settle(1.5)
	_check("giving up opens the end screen", main.call("top_name") == "end" and not get_tree().paused)
	_check("giving up counts as a death", Save.stat_get("deaths") == deaths + 2)
	await G.save_shot("flow_05_gave_up.png")
	await _key(KEY_DOWN)
	_check("Camp can be reached", _focus_text() == "Camp")
	await _key(KEY_ENTER)
	await _settle(1.0)
	_check("Camp opens the camp", is_instance_valid(main.get("hub")) and main.get("run") == null)
	# talking, and LEAVING the talk window (this was broken in v0.5.1)
	main.get("hub").call("talk_to", "cook")
	await _settle()
	_check("talking opens the talk box", main.call("top_name") == "hub_talk")
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Back closes the talk box", main.call("top_name") == "" and is_instance_valid(main.get("hub")))
	main.get("hub").call("talk_to", "cook")
	await _settle()
	for i in 4:
		await _key(KEY_ENTER)          # through the pages to the choices
	await _settle()
	_check("the Leave button has the focus", _focus_text() == "Leave")
	await _key(KEY_ENTER)
	await _settle()
	_check("Leave closes the talk box", main.call("top_name") == "" and is_instance_valid(main.get("hub")))
	# the smith sharpens the blade for coins from the camp chest
	Save.hub_set("bank:coins", 40)
	main.call("_on_action", "hub_buy", "edge")
	await _settle()
	_check("the smith's upgrade was bought", Save.hub_get("up:edge") == 1 and Save.hub_get("bank:coins") == 25)
	if main.call("top_name") == "hub_talk":
		await _key(KEY_ESCAPE)
		await _settle()
	Save.hub_set("bank:coins", 0)
	# down into the hill and back out alive
	main.call("_on_action", "hub_level", "crypt_1")
	await _settle(1.5)
	var story_run: Node = main.get("run")
	_check("the gate starts the first level", is_instance_valid(story_run) and String(story_run.get("level").get("id", "")) == "crypt_1")
	if is_instance_valid(story_run):
		story_run.get("player").set("coins", 7)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("the pause menu is open in a level", main.call("top_name") == "pause")
	var bank := Save.hub_get("bank:coins")
	main.call("_on_action", "leave_run", null)
	await _settle(1.5)
	_check("Back to camp returns to the camp", is_instance_valid(main.get("hub")) and main.get("run") == null and main.call("top_name") == "")
	_check("the coins were banked", Save.hub_get("bank:coins") == bank + 7)
	await _key(KEY_ESCAPE)
	await _settle(1.0)
	_check("Esc in the camp returns to the title", main.call("top_name") == "title")
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc on the title asks before quitting", _focus_text() == "Stay")
	print("[flow] done: %d checks, %d failed" % [_count, _fails])
	G.quit(1 if _fails > 0 else 0)
