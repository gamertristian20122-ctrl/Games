extends Node
## UI tour (testing only): walks through every screen and HUD state with the fake run and
## saves one screenshot of each, then quits. Nothing is written to the save file.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 -- --uitour --shots=/tmp/shots
## Run it at 1280x720 (16:9) and 1600x720 (20:9 phone) and LOOK at the pictures.
## When you add a screen or a HUD state, add a step for it in _run_tour().
##
## --uitour=kit draws every widget of the HD GUI kit (scripts/ui/theme.gd, scripts/ui/kit/) on one
## board over a walking place and saves kit.png (add --uiphone for the phone grid).
## A second mode, --uitour=flow, plays the real game's whole flow with key presses (title ->
## hero select -> run -> pause -> settings -> death -> try again -> give up -> menu) and prints
## "[flow] ok ..." or "[flow] FAIL ..." for every step. Use it after changing main.gd.

const UI = preload("res://scripts/ui/theme.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Items = preload("res://scripts/data/items.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")

var main: Node            ## scripts/main.gd, set by it
var _count := 0
var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if G.arg("uitour") == "tale":
		_run_tale.call_deferred()
	elif G.arg("uitour") == "kit":
		_run_kit.call_deferred()
	elif G.arg("uitour") == "flow":
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


func _find_button(node: Node, starts_with: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text.begins_with(starts_with) and (node as Button).is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_button(c, starts_with)
		if hit != null:
			return hit
	return null


## Where a control's centre is on the screen, in game pixels (it may live on a scaled UI layer).
func _centre_of(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


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
	main.call("top_screen").call("close_dialog")

	# ---- the pause menu over a walking place (HD GUI: Esc no longer goes straight to the title)
	Controls.call("_set_touch", false, false)       # keyboard again (the touch test above left touch on)
	await main.call("show_hub", "village")
	await _settle(1.0)
	main.call("open_hub_pause")
	await _shot("hub_pause")
	main.call("open", "knight")
	await _shot("hub_pause_knight")
	main.call("close_all")

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
	var second := "Collection" if G.flag("oldstory") else "Settings"      # (the story game has no Collection)
	_check("down moves focus to " + second, _focus_text() == second)
	await _key(KEY_UP)
	# a finger tap on Play (touch reaches buttons as an emulated mouse click)
	var play := get_viewport().gui_get_focus_owner()
	var centre := _centre_of(play)
	_touch(0, centre, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(0, centre, false)
	await _settle(0.9)             # the fade out, your room being built, the fade in
	_check("a tap on Play opens your room", is_instance_valid(main.get("hub")) and String(main.get("hub").get("place_id")) == "room")
	_check("a touch switches to touch controls", Controls.using_touch)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc in the camp opens the pause", main.call("top_name") == "pause" and is_instance_valid(main.get("hub")) and bool(main.get("hub").get("frozen")))
	await G.save_shot("flow_01b_hub_pause.png")
	var to_title := _find_button(main.call("top_screen"), "Title")
	if to_title != null:
		to_title.grab_focus()
		await _key(KEY_ENTER)
		await _settle()
		await _key(KEY_ENTER)          # the question: Stay has the focus, so go right to "Title" first
		await _settle()
	_check("Title asks first, Stay keeps the pause open", main.call("top_name") == "pause")
	to_title = _find_button(main.call("top_screen"), "Title")
	if to_title != null:
		to_title.grab_focus()
		await _key(KEY_ENTER)
		await _settle()
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)
		await _settle(0.8)
	_check("Title goes back to the title", main.call("top_name") == "title" and not is_instance_valid(main.get("hub")))
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
	# the Knight screen (level, XP, stat points): from the pause menu
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _settle()
	_check("the Knight screen opens from the pause menu", main.call("top_name") == "knight" and get_tree().paused)
	Save.hub_set("rpg:pts", 1)
	main.call("top_screen").call("refresh")
	var str_before := Rpg.stat("str")
	await _key(KEY_ENTER)
	await _settle(0.3)
	_check("a tap on Strength spends a point", Rpg.stat("str") == str_before + 1 and Rpg.points() == 0)
	await G.save_shot("flow_03b_knight.png")
	await _key(KEY_ENTER)
	await _settle(0.3)
	var hint: Variant = main.call("top_screen").get("_hint")
	_check("with no points left the stat says why", Rpg.stat("str") == str_before + 1 and hint is Label and (hint as Label).text.contains("No points left"))
	# the Gear page: a piece found is owned, put on, and can be taken off and put back
	Gear.grant("cap_iron")
	Gear.grant("helm_soldier")
	run.get("player").call("apply_rpg")
	main.call("top_screen").call("_show_page", "gear")
	await _settle(0.3)
	var cap: Variant = main.call("top_screen").get("_gear_list").get_node_or_null("gear_cap_iron")
	var helm: Variant = main.call("top_screen").get("_gear_list").get_node_or_null("gear_helm_soldier")
	_check("the Gear page lists the pieces he owns", cap is Button and helm is Button)
	_check("the first piece found is worn at once", Gear.is_worn("cap_iron") and not Gear.is_worn("helm_soldier"))
	var hp_before := int(run.get("player").get("max_hp"))
	if helm is Button:
		(helm as Button).pressed.emit()
	await _settle(0.3)
	_check("a tap wears another piece, and the knight changes at once", Gear.is_worn("helm_soldier") and int(run.get("player").get("max_hp")) == hp_before - 2 and float(run.get("player").get("glance")) > 0.0)
	await G.save_shot("flow_03c_gear.png")
	helm = main.call("top_screen").get("_gear_list").get_node_or_null("gear_helm_soldier")
	if helm is Button:
		(helm as Button).pressed.emit()
	await _settle(0.3)
	_check("a second tap takes it off", Gear.worn("helmet").is_empty())
	var axe: Variant = main.call("top_screen").get("_gear_list").get_node_or_null("weapon_sword")
	_check("the sword is listed as a weapon", axe is Button)
	# the Skills page: a skill not learned yet says why; a learned one goes on a button
	main.call("top_screen").call("_show_page", "skills")
	await _settle(0.3)
	var whirl: Variant = main.call("top_screen").get("_skill_list").get_node_or_null("skill_whirl")
	_check("the Skills page lists the skills", whirl is Button)
	if whirl is Button:
		(whirl as Button).pressed.emit()
	main.call("top_screen").call("_put_skill", 0)
	await _settle(0.2)
	var skill_text: Variant = main.call("top_screen").get("_skill_text")
	_check("a skill not learned yet says at which level it comes", Skills.on_button(0).is_empty() and skill_text is Label and (skill_text as Label).text.contains("level 2"))
	Save.hub_set("rpg:lvl", 3)
	main.call("top_screen").call("_fill_skills")
	main.call("top_screen").call("_put_skill", 1)
	await _settle(0.2)
	_check("a learned skill goes on the button chosen", String(Skills.on_button(1).get("id", "")) == "whirl")
	await G.save_shot("flow_03d_skills.png")
	main.call("top_screen").call("_show_page", "stats")
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc returns from the Knight screen to the pause menu", main.call("top_name") == "pause" and get_tree().paused)
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
	# a skill button: Whirlwind is on button 2 (key 2); it costs mana and then rests
	var book: Variant = run.get("player").get("skills")
	if book != null:
		book.call("refresh")
		var mana_before := float(book.get("mana"))
		await _key(KEY_2)
		await _settle(0.2)
		_check("a skill button casts the skill: mana is spent and it rests", float(book.get("mana")) < mana_before and float(book.get("cd")[1]) > 0.0)
		await _key(KEY_2)
		await _settle(0.2)
		var note: Variant = main.get("hud").get("_note")
		_check("pressed again too soon it says why", note is Label and (note as Label).visible and (note as Label).text.contains("not ready"))
		await _key(KEY_1)
		await _settle(0.2)
		_check("an empty skill button says so", note is Label and (note as Label).text.contains("No skill"))
	else:
		_check("the knight has a skill book", false)
	# the Lv button (here its key) opens the Knight screen straight from the game
	await _key(KEY_C)
	await _settle()
	_check("the Lv button opens the Knight screen and stops the game", main.call("top_name") == "knight" and get_tree().paused)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc closes it and the game goes on", main.call("top_name") == "" and not get_tree().paused)

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
	_check("coming back from a level puts you in the village", String(main.get("hub").get("place_id")) == "village")
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
	# the same on a phone, with the left thumb still resting on the walking stick (finger 0)
	_touch(0, Vector2(50, 130), true)
	await _settle()
	main.get("hub").call("talk_to", "cook")
	await _settle()
	var leave := get_viewport().gui_get_focus_owner()
	_check("the Leave button is there", leave is Button and (leave as Button).text == "Leave")
	if leave is Button:
		var at := _centre_of(leave as Button)
		_touch(1, at, true)
		await get_tree().process_frame
		await get_tree().process_frame
		_touch(1, at, false)
		await _settle()
	_check("a second finger can press Leave while the first rests on the stick", main.call("top_name") == "")
	_touch(0, Vector2(50, 130), false)
	await _settle()
	# the smith sharpens the blade for coins from the camp chest
	Save.hub_set("bank:coins", 40)
	main.call("_on_action", "hub_buy", "edge")
	await _settle()
	_check("the smith's upgrade was bought", Save.hub_get("up:edge") == 1 and Save.hub_get("bank:coins") == 25)
	if main.call("top_name") == "hub_talk":
		await _key(KEY_ESCAPE)
		await _settle()
	Save.hub_set("bank:coins", 0)
	# with an empty chest a greyed choice must still answer the tap and say why
	main.get("hub").call("talk_to", "smith")
	await _settle()
	for i in 4:
		if _find_button(main.call("top_screen"), "Balance") == null:
			await _key(KEY_ENTER)
	await _settle()
	var poor := _find_button(main.call("top_screen"), "Balance")
	_check("the smith offers Balance the hilt", poor != null)
	if poor != null:
		poor.pressed.emit()
		await _settle()
		var why: Variant = main.call("top_screen").get("_why")
		_check("a choice you cannot afford says why", why is Label and (why as Label).visible and (why as Label).text.contains("coins"))
		_check("... and the window stays open", main.call("top_name") == "hub_talk")
	await _key(KEY_ESCAPE)
	await _settle()
	# down into the hill and back out alive
	main.call("_on_action", "hub_level", "crypt_1")
	await _settle(1.5)
	var story_run: Node = main.get("run")
	_check("the gate starts the first level", is_instance_valid(story_run) and String(story_run.get("level").get("id", "")) == "crypt_1")
	if is_instance_valid(story_run):
		story_run.get("player").set("coins", 7)
		# a keyed dungeon: the boss door is sealed until the boss key is picked up
		var sealed := 0
		var marked := 0
		for c: Vector2i in story_run.get("rooms"):
			if story_run.get("rooms")[c].get("boss_key", false):
				marked += 1
			for d: Vector2i in story_run.get("rooms")[c]["doors"]:
				if story_run.get("rooms")[c]["doors"][d].get("sealed", false):
					sealed += 1
		_check("a story dungeon seals its boss door and hides one boss key", sealed >= 1 and marked == 1 and story_run.call("needs_boss_key"))
		story_run.get("player").call("give", {"boss_key": 1})
		_check("picking up the boss key breaks the seal", not story_run.call("needs_boss_key") and story_run.get("boss_key") == true)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("the pause menu is open in a level", main.call("top_name") == "pause")
	var bank := Save.hub_get("bank:coins")
	main.call("_on_action", "leave_run", null)
	await _settle(1.5)
	_check("Back to camp returns to the camp", is_instance_valid(main.get("hub")) and main.get("run") == null and main.call("top_name") == "")
	_check("the coins were banked", Save.hub_get("bank:coins") == bank + 7)
	# the companion: she turns up in the village once the first level is cleared, joins when asked,
	# walks behind the knight, comes into a level and can be sent back from the Party page
	Save.hub_set("lvl:crypt_1", 1)
	main.get("hub").call("enter", "village")
	await _settle(0.5)
	main.get("hub").call("talk_to", "ally_sera")
	await _settle(0.5)
	_check("the companion waits in the village after the first level", main.call("top_name") == "hub_talk")
	await G.save_shot("flow_07_sera.png")
	main.call("_on_action", "hub_ally", "sera")
	await _settle(0.5)
	_check("asked along, she joins and walks behind the knight", String(Allies.with().get("id", "")) == "sera" and is_instance_valid(main.get("hub").get("_mate")) and main.call("top_name") == "")
	main.call("_on_action", "hub_level", "crypt_1")
	await _settle(1.5)
	var with_her: Node = main.get("run")
	_check("she comes into the level with him", is_instance_valid(with_her) and is_instance_valid(with_her.get("player").get("ally")) and with_her.get("player").get("ally").is_inside_tree())
	await G.save_shot("flow_08_level_with_sera.png")
	await _key(KEY_C)
	await _settle()
	main.call("top_screen").call("_show_page", "party")
	await _settle(0.3)
	var ask: Variant = main.call("top_screen").get("_party_box").get_node_or_null("party_sera")
	if ask is Button:
		(ask as Button).pressed.emit()
	await _settle(0.2)
	var party_why: Variant = main.call("top_screen").get("_party_box").get_node_or_null("party_why")
	_check("inside a level the Party button says why it changes nothing", String(Allies.with().get("id", "")) == "sera" and party_why is Label and (party_why as Label).text.contains("camp"))
	await G.save_shot("flow_09_party.png")
	await _key(KEY_ESCAPE)
	await _settle()
	main.call("_on_action", "leave_run", null)
	await _settle(1.5)
	await _key(KEY_C)
	await _settle()
	main.call("top_screen").call("_show_page", "party")
	await _settle(0.3)
	ask = main.call("top_screen").get("_party_box").get_node_or_null("party_sera")
	if ask is Button:
		(ask as Button).pressed.emit()
	await _settle(0.3)
	_check("in a camp the Party page sends her back to wait", Allies.with().is_empty() and not is_instance_valid(main.get("hub").get("_mate")))
	await _key(KEY_ESCAPE)
	await _settle()
	# the smith's shelf of gear
	Save.hub_set("bank:coins", 30)
	main.call("_on_action", "hub_shelf", "Tam")
	await _settle(0.5)
	_check("the smith's shelf opens", main.call("top_name") == "hub_talk")
	await G.save_shot("flow_06_shelf.png")
	main.call("_on_action", "hub_gear", "vest_padded")
	await _settle(0.5)
	_check("a piece bought is owned, worn and paid for", Gear.is_worn("vest_padded") and Save.hub_get("bank:coins") == 10)
	main.call("close_all")
	await _settle(0.3)
	await _key(KEY_C)
	await _settle()
	_check("the Lv button opens the Knight screen in the camp", main.call("top_name") == "knight")
	var take_back: Variant = main.call("top_screen").get("_reset")
	_check("the camp offers to take points back", take_back is Button)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc closes it and you are still in the camp", main.call("top_name") == "" and is_instance_valid(main.get("hub")))
	# roamers: monsters walk the world map; a touch starts a turn-based battle; winning puts him back
	main.call("show_hub", "world")
	await _settle(1.5)
	var world: Node = main.get("hub")
	_check("monsters roam the world map", is_instance_valid(world) and String(world.get("place_id")) == "world" and ((world.get("_roamers") as Array).size() >= 4 or Roamers.RANDOM))
	await G.save_shot("flow_10_world_roamers.png")
	var stood: Vector2 = world.call("hero_pos")
	main.call("_on_action", "hub_encounter", 0)
	await _settle(3.0)
	var ambush: Node = main.get("battle")
	_check("a roamer's touch starts a turn-based battle", is_instance_valid(ambush) and main.get("hub") == null
		and (ambush.get("fight").get("foes") as Array).size() >= 1 and (ambush.get("fight").get("party") as Array).size() >= 1)
	await G.save_shot("flow_11_battle.png")
	var waited := 0
	while _focus_text() != "Attack" and waited < 20:      # (a quicker monster may strike first)
		await _settle(0.4)
		waited += 1
	_check("his turn opens on Attack", _focus_text() == "Attack")
	# Enter, again and again: Attack, the first monster, ... and Continue on the last screen
	var presses := 0
	while is_instance_valid(main.get("battle")) and presses < 90:
		await _key(KEY_ENTER)
		await _settle(0.5)
		presses += 1
	await _settle(2.0)
	world = main.get("hub")
	_check("winning puts him back on the same spot of the map", main.get("battle") == null and is_instance_valid(world) and String(world.get("place_id")) == "world" and (world.call("hero_pos") as Vector2).distance_to(stood) < 4.0)
	_check("the beaten roamer is gone for a while", not Roamers.here(0) and main.call("top_name") == "")
	await G.save_shot("flow_12_back_on_the_map.png")
	await _key(KEY_ESCAPE)
	await _settle(0.6)
	_check("Esc on the map opens the pause", main.call("top_name") == "pause")
	await _key(KEY_ESCAPE)
	await _settle(0.6)
	_check("Esc again resumes the walk", main.call("top_name") == "" and is_instance_valid(main.get("hub")) and not bool(main.get("hub").get("frozen")))
	main.call("show_title")
	await _settle(1.0)
	await _key(KEY_ESCAPE)
	await _settle()
	_check("Esc on the title asks before quitting", _focus_text() == "Stay")
	print("[flow] done: %d checks, %d failed" % [_count, _fails])
	G.quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------ the story test (--uitour=tale)
## Plays chapter one of the story (scripts/data/tale.gd) from the first step to the last: talks to
## the people who move it on, lets a bot fight its battles, and checks after each step that the
## story, the places and the party are what they should be. Prints "[tale] ok / FAIL" lines.
##   xvfb-run ... godot --path . ... -- --uitour=tale --nosave [--shots=<dir>]
func _tale_talk(npc_id: String) -> bool:
	var hub: Node = main.get("hub")
	if not is_instance_valid(hub):
		return false
	var there := false
	for p: Dictionary in hub.get("_people"):
		there = there or String(p["row"]["id"]) == npc_id
	if not there:
		return false
	hub.call("talk_to", npc_id)
	await _settle(0.6)
	var said := Tale.beat(npc_id)
	if main.call("top_name") != "hub_talk" or not said.has("do"):
		return false
	main.call("_on_action", "tale_do", said["do"])
	return true


func _tale_wait_battle() -> void:
	var waited := 0
	while not is_instance_valid(main.get("battle")) and waited < 20:
		await _settle(0.3)
		waited += 1
	waited = 0
	while is_instance_valid(main.get("battle")) and waited < 400:
		await _settle(0.5)
		waited += 1
	await _settle(2.0)


func _tale_go(place: String) -> void:
	main.call("show_hub", place)
	await _settle(1.6)


func _run_tale() -> void:
	G.args["autobattle"] = ""             # a bot fights the story's battles
	G.args["speed"] = "5"
	main.call("close_all")
	await _tale_go("village")
	var hub: Node = main.get("hub")
	_check("the story starts in Wickmere at step 0", Tale.step() == 0 and String(hub.get("place").get("name", "")) == "Wickmere")
	await G.save_shot("tale_01_wickmere.png")
	_check("Captain Hale sends him east", await _tale_talk("hale"))
	await _settle(2.0)
	_check("that was step 1", Tale.step() == 1)
	await _tale_go("elfwood")
	_check("walking into the Elfwood is step 2", Tale.step() == 2)
	await G.save_shot("tale_02_elfwood.png")
	await _tale_go("glade")
	_check("Thessaly asks him to stand with her", await _tale_talk("thessaly"))
	await _tale_wait_battle()
	_check("winning at the glade: step 3 and Thessaly has joined", Tale.step() == 3 and Allies.joined("thessaly"))
	hub = main.get("hub")
	_check("he is back in the glade and she no longer stands at the stones", is_instance_valid(hub) and String(hub.get("place_id")) == "glade"
		and (hub.get("_people") as Array).all(func(p: Dictionary) -> bool: return String(p["row"]["id"]) != "thessaly"))
	await G.save_shot("tale_03_glade_after.png")
	await _tale_go("deepwood")
	await G.save_shot("tale_04_deepwood.png")
	_check("the lost wardens bar the Deepwood", await _tale_talk("thornwatch"))
	await _tale_wait_battle()
	_check("beating them is step 4", Tale.step() == 4)
	await _tale_go("beacon")
	await G.save_shot("tale_05_beacon_dark.png")
	_check("the Bramble Giant sits by the dark beacon", await _tale_talk("giant"))
	await _tale_wait_battle()
	_check("the giant falls: step 5", Tale.step() == 5)
	hub = main.get("hub")
	_check("he stands on the beacon's hill again", is_instance_valid(hub) and String(hub.get("place_id")) == "beacon")
	_check("the shard goes into the beacon", await _tale_talk("beacon"))
	await _settle(2.5)
	_check("the beacon of the Elfwood burns: step 6", Tale.step() == 6 and Tale.lit("elfwood") and Tale.beacons() == 1)
	await G.save_shot("tale_06_beacon_lit.png")
	await _tale_go("elfwood")
	await G.save_shot("tale_07_elfwood_lit.png")
	await _tale_go("village")
	var coins := Save.hub_get("bank:coins")
	_check("Captain Hale hears of it", await _tale_talk("hale"))
	await _settle(2.0)
	_check("chapter one is done: step 7 and the watch's coins", Tale.step() == 7 and Save.hub_get("bank:coins") == coins + 60)
	await G.save_shot("tale_08_wickmere_after.png")
	# chapter two: the Sands
	await _tale_go("dustwatch")
	_check("walking into Dustwatch is step 8", Tale.step() == 8)
	await G.save_shot("tale_09_dustwatch.png")
	_check("Seraphine asks him to hold the wall", await _tale_talk("sera"))
	await _tale_wait_battle()
	_check("holding the wall: step 9 and Seraphine has joined", Tale.step() == 9 and Allies.joined("sera"))
	await _tale_go("suncourt")
	await G.save_shot("tale_10_sunwell_dark.png")
	_check("the Dune Queen sends him after the Gorgon", await _tale_talk("queen"))
	await _settle(2.0)
	_check("that was step 10", Tale.step() == 10)
	await _tale_go("world")
	_check("the Dune Gorgon rises in the Bone Dunes", await _tale_talk("site_dunes"))
	await _tale_wait_battle()
	_check("the Gorgon falls: step 11", Tale.step() == 11)
	await _tale_go("suncourt")
	_check("the Queen gives up her shard", await _tale_talk("queen"))
	await _settle(2.0)
	_check("the shard of the Sands goes into its beacon", await _tale_talk("sandbeacon"))
	await _settle(2.5)
	_check("the beacon of the Sands burns: step 13", Tale.step() == 13 and Tale.lit("sands") and Tale.beacons() == 2)
	await G.save_shot("tale_11_sunwell_lit.png")
	await _tale_go("dustwatch")
	await G.save_shot("tale_12_dustwatch_lit.png")
	await _tale_go("village")
	coins = Save.hub_get("bank:coins")
	_check("Captain Hale hears of the Sands", await _tale_talk("hale"))
	await _settle(2.0)
	_check("chapter two is done: step 14 and the watch's coins", Tale.step() == 14 and Save.hub_get("bank:coins") == coins + 90)
	print("[tale] done: %d checks, %d failed, knight level %d" % [_count, _fails, Rpg.level()])
	G.quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------ the kit board (--uitour=kit)
## Every widget of the HD GUI kit on one board over Wickmere, to look at (kit.png).
func _run_kit() -> void:
	await main.call("show_hub", "village")
	await _settle(1.5)
	var layer := CanvasLayer.new()
	layer.layer = G.LAYER_MENU + 1
	add_child(layer)
	var root := UI.attach(layer)
	root.theme = UI.theme()
	var W := root.size.x
	var H := root.size.y
	var ph := UI.is_phone()
	var k := 0.5 if ph else 1.0        # the phone grid is half as big

	# left: a menu panel with rows (icons, a disabled row with its reason), a Big button, tabs
	var panel := UI.panel("panel")
	panel.position = Vector2(14, 40) * k + Vector2(0, 0)
	panel.custom_minimum_size.x = 160 * (0.8 if ph else 1.0)
	root.add_child(panel)
	var col := UI.vbox(1)
	panel.add_child(col)
	col.add_child(UI.label("Aldous", "Head"))
	var rows: Array[Button] = []
	for pair: Array in [["Attack", UI.ICON_ATTACK], ["Skills", UI.icon_or([UI.ICON_BOOK, UI.ICON_SKILLS])],
			["Guard", UI.icon_or([UI.ICON_SHIELD, UI.ICON_GUARD])], ["Flee", UI.icon_or([UI.ICON_BOOT, UI.ICON_FLEE])]]:
		var b := UI.button(String(pair[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Art.tex(String(pair[1]))
		col.add_child(b)
		rows.append(b)
	rows[3].disabled = true
	col.add_child(HSeparator.new())
	col.add_child(UI.label("A boss blocks the way out.", "Small", 130 * (0.8 if ph else 1.0)))
	var big := UI.button("Continue", Callable(), "Big")
	root.add_child(big)
	big.position = Vector2(14 * k, H - 14 * k - 26)
	big.size = Vector2(120, 26)
	var tabs := UI.hbox(14)
	tabs.position = Vector2(W * 0.40, 10 * k)
	root.add_child(tabs)
	for i in 4:
		var t := UI.button(["Stats", "Gear", "Skills", "Party"][i], Callable(), "Tab")
		t.disabled = i == 0
		tabs.add_child(t)
	var mini := UI.button("+", Callable(), "Mini")
	mini.position = Vector2(W * 0.40, 34 * k)
	root.add_child(mini)

	# middle: bars (full, a fresh loss, low, mana, XP, a foe tag, the boss bar)
	var bx := W * 0.40
	var by := 60.0 * k
	for spec: Array in [["hp", 46, 46, false], ["hp", 21, 38, true], ["hp", 8, 46, false], ["mp", 14, 20, false],
			["xp", 124, 200, false], ["foe", 18, 32, false]]:
		var b2 := UI.bar(String(spec[0]), 32.0 if spec[0] == "foe" else 90.0 * k + 30.0)
		root.add_child(b2)
		b2.position = Vector2(bx, by)
		if spec[3]:
			b2.call("set_value", 38, 38, false)
			b2.call("set_value", spec[1], spec[2], true)
		else:
			b2.call("set_value", spec[1], spec[2], false)
		var l := UI.label("%s %d/%d%s" % [spec[0], spec[1], spec[2], "  low" if b2.call("is_low") else ""], "Small")
		l.position = Vector2(bx + 130 * k + 6, by - 6)
		root.add_child(l)
		by += 14.0 * k + 4.0
	var boss := UI.bar("boss", 200.0 * k + 40.0)
	root.add_child(boss)
	boss.position = Vector2(W * 0.5 - boss.size.x * 0.5, H * 0.45)
	boss.call("set_value", 0.55, 1.0, false)
	var bname := UI.label("Old Bramblejaw", "HudHead")
	bname.position = boss.position + Vector2(0, -18 * (0.7 if ph else 1.0))
	root.add_child(bname)

	# medallions: your side, a monster, the one acting, one knocked out
	var mx := W * 0.40
	for spec: Array in [["pc_knight", UI.C_STEEL, true, false, 13.0], ["pc_elf_ranger", UI.C_FOE, false, false, 9.0],
			["pc_scholar_censor", UI.C_STEEL, false, false, 11.0], ["pc_elf_hunter", UI.C_FOE, false, true, 9.0]]:
		var m := UI.medallion(String(spec[0]), float(spec[4]) * (0.65 if ph else 1.0), spec[1], spec[2])
		m.call("set_ko", spec[3])
		root.add_child(m)
		m.position = Vector2(mx, H * 0.55)
		mx += m.custom_minimum_size.x + 4

	# right: plates, a well, a danger plate, a card with gold edge
	var x2 := W * 0.72
	var y2 := 40.0 * k
	for kind: String in ["plate", "well", "danger", "gold", "card"]:
		var p := UI.panel(kind)
		p.position = Vector2(x2, y2)
		var lab := UI.label(kind.capitalize() if kind != "plate" else "Captain Hale", "Head" if kind == "plate" else "")
		p.add_child(lab)
		root.add_child(p)
		y2 += 30.0 * k + 6.0

	# bottom: prompts (keyboard, then pad), a wash with outlined text, a lozenge, a rule, a coin
	var pr := UI.hbox(10)
	pr.position = Vector2(W * 0.40, H * 0.70)
	root.add_child(pr)
	for kind: String in ["confirm", "back", "talk", "knight", "page"]:
		pr.add_child(UI.prompt(kind, kind.capitalize()))
	Controls.last_pad = true
	var pr2 := UI.hbox(10)
	pr2.position = Vector2(W * 0.40, H * 0.70 + 18)
	root.add_child(pr2)
	for kind: String in ["confirm", "back", "talk", "knight", "page"]:
		pr2.add_child(UI.prompt(kind, kind.capitalize()))
	Controls.last_pad = false
	var wash := UI.wash("right", 0.8)
	wash.position = Vector2(0, H * 0.40)
	wash.size = Vector2(220 * k + 60, 30 * k + 6)
	root.add_child(wash)
	var on_world := UI.label("Find Captain Hale", "Hud")
	on_world.position = wash.position + Vector2(14, 6 * k)
	root.add_child(on_world)
	var loz := UI.lozenge(3.0, UI.C_GOLD, 20.0)
	loz.position = Vector2(W * 0.5 - loz.custom_minimum_size.x * 0.5, H * 0.33)
	root.add_child(loz)
	var c := UI.coin(5.0)
	c.position = Vector2(W - 60, 8)
	root.add_child(c)
	var coins := UI.label("120", "Num")
	coins.position = Vector2(W - 46, 4)
	root.add_child(coins)
	var help := UI.help_strip([["confirm", "Choose"], ["page", "Page"], ["back", "Back"]])
	root.add_child(help)
	var fl := UI.flame(root)
	root.add_child(fl)
	rows[1].grab_focus()
	await _settle(0.6)
	await G.save_shot("kit.png")
	print("[kit] grid %s, %s px per UI px, phone %s" % [root.size, root.get("px"), ph])
	G.quit(0)
