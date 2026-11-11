extends Node
## UI tour (testing only): walks through every screen and HUD state with the fake run and
## saves one screenshot of each, then quits. Nothing is written to the save file.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 -- --uitour --shots=/tmp/shots
## Run it at 1280x720 (16:9) and 1600x720 (20:9 phone) and LOOK at the pictures.
## When you add a screen or a HUD state, add a step for it in _run_tour().

const UI = preload("res://scripts/ui/theme.gd")
const Items = preload("res://scripts/data/items.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")

var main: Node            ## scripts/main.gd, set by it
var _count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	get_tree().quit()
