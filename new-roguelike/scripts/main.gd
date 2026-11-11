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
##   --time=<sec>       quit after this much game time
##   --fakerun          use the fake run (scripts/ui/dev_fake_run.gd) instead of the real one
##   --safe=l,t,r,b     pretend the phone has a notch this many game pixels deep on each side

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
}
## Screens that keep the dungeon picture bright behind them; behind the others it is dimmed.
const BRIGHT := ["title", "hero_select"]
const RUN_SCRIPT := "res://scripts/run/run.gd"
const FAKE_RUN_SCRIPT := "res://scripts/ui/dev_fake_run.gd"

var run: Node                    ## the game being played, or null on the menus
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
var _seed := 0
var _clock := 0.0
var _time_limit := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false       # the phone's Back button is handled in _back()
	_time_limit = float(G.arg("time", "0"))
	var safe := G.arg("safe").split_floats(",")
	if safe.size() == 4:
		UI.fake_safe = Vector4(safe[0], safe[1], safe[2], safe[3])
	_build_layers()
	G.run_ended.connect(_on_run_ended)
	Controls.pause_pressed.connect(_back)
	if G.flag("uitour"):
		UI.instant = true
		var tour: Node = load("res://scripts/ui/ui_tour.gd").new()
		tour.set("main", self)
		add_child(tour)
	elif G.flag("autotest"):
		start_run(G.arg("hero", "knight"), int(G.arg("seed", "1")))
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
	backdrop.visible = not in_run
	backdrop.call("set_dimmed", not _names.is_empty() and not (_names.back() in BRIGHT))
	_shade.visible = in_run and not _stack.is_empty()
	hud.visible = in_run and _stack.is_empty()      # the pause menu shows its own numbers
	touch.call("set_active", in_run and _stack.is_empty() and not _ending)


func show_title() -> void:
	await _drop_run()
	get_tree().paused = false
	close_all()
	open("title")
	Sfx.music("title")


## Every request a screen can send ends up here.
func _on_action(what: String, arg: Variant) -> void:
	if _busy:
		return
	match what:
		"back":
			if top_name() == "pause":
				resume()
			elif _stack.size() > 1:
				close_top()
		"play":
			open("hero_select")
		"collection", "settings", "credits":
			open(what)
		"start":
			_transition(start_run.bind(String(arg), _fresh_seed()))
		"retry":
			_transition(start_run.bind(_hero_id, _fresh_seed()))
		"menu":
			_transition(show_title)
		"resume":
			resume()
		"give_up":
			give_up()
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
	close_all()
	get_tree().paused = false
	_hero_id = hero_id
	_seed = seed_value
	_ending = false
	Save.set_setting("last_hero", hero_id)
	var path := RUN_SCRIPT
	if G.flag("uitour") or G.flag("fakerun") or not ResourceLoader.exists(RUN_SCRIPT):
		path = FAKE_RUN_SCRIPT
	run = (load(path) as Script).new()
	hud.call("begin", run)          # before setup(), so the HUD hears the run's first signals
	_world.add_child(run)
	run.call("setup", hero_id, seed_value)
	_refresh_layers()


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
	if G.flag("autotest"):
		print("[main] run ended: victory=%s floor=%s time=%ds kills=%s (starting another)" % [
			victory, summary.get("floor", "?"), int(summary.get("time_s", 0)), summary.get("kills", "?")])
		_seed += 1
		start_run.call_deferred(_hero_id, _seed)
		return
	_show_end(victory, summary, 1.0)


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
	get_tree().quit()


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
