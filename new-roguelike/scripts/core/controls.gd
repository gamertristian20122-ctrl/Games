extends Node
## Controls (autoload): every input method ends up here.
## World code reads `move` and `aim` each frame and connects to the three signals.
## Touch: scripts/ui/touch.gd writes touch_move / touch_aim and calls press_bomb() etc.
## Keyboard and gamepad: the table ACTIONS below (real InputMap actions, rebindable). In short:
## WASD / arrows / D-pad / left stick walk; E, Space, Enter or pad A talk (ONE confirm button);
## C or Y the Knight screen; Esc or Start pause and back.

signal bomb_pressed
signal action_pressed        ## the second button (reserved for the game's twist)
signal pause_pressed
signal skill_pressed(slot: int)   ## skill button 1 or 2 (0 or 1): the touch buttons, keys 1 / 2 or F / R, gamepad X / B
signal menu_pressed          ## open the Knight screen (level, stats): the "Lv" touch button, C or Tab, gamepad Y
## The player switched between the touch screen and a keyboard / gamepad, or between the
## keyboard (and mouse) and a gamepad (`last_pad` says which). `touch` = using_touch.
signal device_changed(touch: bool)

var move := Vector2.ZERO      ## length 0..1
var aim := Vector2.ZERO       ## length 0..1; the player fires while aim.length() > AIM_DEADZONE
const AIM_DEADZONE := 0.35

# written by the touch layer
var touch_move := Vector2.ZERO
var touch_move_active := false
var touch_aim := Vector2.ZERO
var touch_aim_active := false

## The on-screen Action button stays hidden until this is true (the game's twist turns it on).
var action_enabled := false
## True while the second button is held down (the knight's shield block). Touch sets touch_action_held.
var action_held := false
var touch_action_held := false
## True while the touch screen is the input in use. The touch controls hide themselves when a
## key or gamepad is used and come back on the next touch.
var using_touch := false
## True after a gamepad button or stick was used, false after a key or the mouse: the key
## prompts (scripts/ui/kit/prompt.gd) show pad caps or key caps from it.
var last_pad := false

# written by the test bot (when bot == true these replace all other input)
var bot := false
var bot_move := Vector2.ZERO
var bot_aim := Vector2.ZERO


# ------------------------------------------------------------------ the actions (v0.45, pass P05)
## Every button of the turn-based game is a real InputMap action, made here at start, so it can be
## rebound (scripts/ui/rebind.gd) and so the prompts (UI.cap_for) show what is really bound.
##   id      the InputMap action name other scripts read: event.is_action_pressed("fast")
##   name    the words on the Controls screen (placeholder words; the owner rewrites them)
##   group   which buttons may not share a key: "walk" (in a place), "talk" (talk box and battle),
##           "pages" (tabs); "all" = counts everywhere (pause)
##   keys    physical keys: the FIRST is the one the Controls screen changes, the rest always work too
##   pad     gamepad buttons, same rule (the left stick always walks too: _process reads it)
## To add an action: add a row. Nothing else is needed for it to be rebindable and shown.
const ACTIONS := [
	{"id": "move_up", "name": "Walk up", "group": "walk", "keys": [KEY_W, KEY_UP], "pad": [JOY_BUTTON_DPAD_UP]},
	{"id": "move_down", "name": "Walk down", "group": "walk", "keys": [KEY_S, KEY_DOWN], "pad": [JOY_BUTTON_DPAD_DOWN]},
	{"id": "move_left", "name": "Walk left", "group": "walk", "keys": [KEY_A, KEY_LEFT], "pad": [JOY_BUTTON_DPAD_LEFT]},
	{"id": "move_right", "name": "Walk right", "group": "walk", "keys": [KEY_D, KEY_RIGHT], "pad": [JOY_BUTTON_DPAD_RIGHT]},
	{"id": "interact", "name": "Talk, open, read", "group": "walk", "keys": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Q], "pad": [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER]},
	{"id": "menu", "name": "Knight screen", "group": "walk", "keys": [KEY_C, KEY_TAB], "pad": [JOY_BUTTON_Y]},
	{"id": "open_journal", "name": "Journal", "group": "walk", "keys": [KEY_J], "pad": [JOY_BUTTON_BACK]},
	{"id": "open_map", "name": "Map", "group": "walk", "keys": [KEY_M], "pad": []},
	{"id": "open_items", "name": "Items", "group": "walk", "keys": [KEY_I], "pad": []},
	{"id": "pause", "name": "Pause, back", "group": "all", "keys": [KEY_ESCAPE], "pad": [JOY_BUTTON_START]},
	{"id": "fast", "name": "Hold: faster, skip talk", "group": "talk", "keys": [KEY_SPACE], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"id": "auto", "name": "Auto battle", "group": "talk", "keys": [KEY_T], "pad": []},
	{"id": "talk_log", "name": "Talk log", "group": "talk", "keys": [KEY_L], "pad": [JOY_BUTTON_X]},
	{"id": "page_prev", "name": "Page before", "group": "pages", "keys": [KEY_Q], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	{"id": "page_next", "name": "Next page", "group": "pages", "keys": [KEY_E], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
]
## Sent after a binding changed (the Controls screen redraws; prompts follow device_changed, sent too).
signal binds_changed
## The gamepad last used (-1 = none yet). Only this pad is read, so a second pad lying on the desk
## with a drifting stick does not walk the knight.
var active_pad := -1
## What the player changed: {action id: {"key": physical keycode, "pad": button}} (-1 = nothing bound).
## Kept in the setting "binds".
var _binds := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (a PC with a touch screen, a Steam Deck, shows them only once it is really touched)
	using_touch = OS.has_feature("mobile") or G.flag("touch")     # --touch: show the phone buttons in test pictures
	_build_map()
	get_window().window_input.connect(_watch_device)
	Input.joy_connection_changed.connect(_on_joy_changed)
	_load_binds.call_deferred()        # (Save is the autoload after this one: its file is read by then)


# ------------------------------------------------------------------ bindings
static func action_row(id: String) -> Dictionary:
	for row: Dictionary in ACTIONS:
		if String(row["id"]) == id:
			return row
	return {}


## The saved changes (setting "binds"; missing or broken parts are ignored).
func _load_binds() -> void:
	var saved: Variant = Save.setting("binds")
	_binds = {}
	if saved is Dictionary:
		for id: Variant in saved:
			var one: Variant = saved[id]
			if action_row(String(id)).is_empty() or not (one is Dictionary):
				continue
			var keep := {}
			for slot: String in ["key", "pad"]:
				if one.has(slot) and (one[slot] is int or one[slot] is float):
					keep[slot] = int(one[slot])
			if not keep.is_empty():
				_binds[String(id)] = keep
	_build_map()
	if not _binds.is_empty():
		binds_changed.emit()
		device_changed.emit(using_touch)


func _store_binds() -> void:
	Save.set_setting("binds", _binds.duplicate(true))
	_build_map()
	binds_changed.emit()
	device_changed.emit(using_touch)      # every key prompt on screen reads its cap again


## The default first key (slot "key") or pad button (slot "pad") of an action; -1 = none.
static func default_bind(id: String, slot: String) -> int:
	var list: Array = action_row(id).get("keys" if slot == "key" else "pad", [])
	return int(list[0]) if not list.is_empty() else -1


## The key or pad button the Controls screen shows for an action; -1 = none.
func bind_of(id: String, slot: String) -> int:
	var mine: Dictionary = _binds.get(id, {})
	return int(mine[slot]) if mine.has(slot) else default_bind(id, slot)


static func _clash(a: Dictionary, b: Dictionary) -> bool:
	return String(a["group"]) == String(b["group"]) or String(a["group"]) == "all" or String(b["group"]) == "all"


## Gives an action a new key or pad button. If another action that is used at the same time had
## it, the two swap. Returns that other action's id ("" = no swap).
func set_bind(id: String, slot: String, code: int) -> String:
	var row := action_row(id)
	if row.is_empty() or code == bind_of(id, slot):
		return ""
	var old := bind_of(id, slot)
	var swapped := ""
	for other: Dictionary in ACTIONS:
		var oid := String(other["id"])
		if oid != id and _clash(row, other) and bind_of(oid, slot) == code:
			_put(oid, slot, old)
			swapped = oid
	_put(id, slot, code)
	_store_binds()
	return swapped


func _put(id: String, slot: String, code: int) -> void:
	var mine: Dictionary = _binds.get(id, {})
	if code == default_bind(id, slot):
		mine.erase(slot)
	else:
		mine[slot] = code
	if mine.is_empty():
		_binds.erase(id)
	else:
		_binds[id] = mine


func reset_binds() -> void:
	_binds = {}
	_store_binds()


func binds_are_default() -> bool:
	return _binds.is_empty()


## Every code an action answers to in a slot: the chosen one first, then the fixed extra ones
## (arrows walk, Enter and Space talk ...), minus any that another action of the same moment owns.
func codes_of(id: String, slot: String) -> Array:
	var row := action_row(id)
	var out: Array = []
	var first := bind_of(id, slot)
	if first >= 0:
		out.append(first)
	var defaults: Array = row.get("keys" if slot == "key" else "pad", [])
	for i in range(1, defaults.size()):
		var code := int(defaults[i])
		if out.has(code):
			continue
		var taken := false
		for other: Dictionary in ACTIONS:
			if String(other["id"]) != id and _clash(row, other) and bind_of(String(other["id"]), slot) == code:
				taken = true
		if not taken:
			out.append(code)
	return out


## Writes the actions into the engine's InputMap (at start and after a change). Never while a
## button may be down for another reason: rewriting an action forgets that it is held.
func _build_map() -> void:
	for row: Dictionary in ACTIONS:
		var id := String(row["id"])
		if InputMap.has_action(id):
			InputMap.action_erase_events(id)
		else:
			InputMap.add_action(id, 0.3)
		for code: int in codes_of(id, "key"):
			var k := InputEventKey.new()
			k.physical_keycode = code as Key
			InputMap.action_add_event(id, k)
		for button: int in codes_of(id, "pad"):
			var b := InputEventJoypadButton.new()
			b.button_index = button as JoyButton
			b.device = -1          # (buttons of any pad; the STICK is read from the pad in use, in _process)
			InputMap.action_add_event(id, b)


func _use_pad(id: int) -> void:
	if id == active_pad:
		return
	active_pad = id
	if last_pad:
		device_changed.emit(using_touch)      # (another make of pad: the caps may change)


func _on_joy_changed(device: int, connected: bool) -> void:
	if not connected and device == active_pad:
		_use_pad(-1)


## Mute in background (setting "mute_bg", on unless switched off): the game is silent while its
## window is not the one in use.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var mute: Variant = Save.setting("mute_bg")
		if mute == null or bool(mute):
			AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)


func _set_touch(on: bool, pad: Variant = null) -> void:
	var changed := on != using_touch
	using_touch = on
	if pad != null and bool(pad) != last_pad:
		last_pad = bool(pad)
		changed = true
	if changed:
		device_changed.emit(using_touch)


## Only watches WHICH device is in use; the real handling is below and in scripts/ui/touch.gd.
## (Connected to the window itself so it also sees events that a menu has already used up.)
func _watch_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_touch(true)
	elif event is InputEventKey:
		# (the phone's Back and volume keys are keys too, and must not hide the touch controls)
		if event.pressed and not event.echo and event.keycode not in [KEY_BACK, KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_VOLUMEMUTE, KEY_MENU]:
			_set_touch(false, false)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_use_pad(event.device)
			_set_touch(false, true)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			_use_pad(event.device)
			_set_touch(false, true)
	elif event is InputEventMouseButton:
		# a real mouse (not a touch the engine turned into a click) means keyboard prompts
		if event.pressed and last_pad and not using_touch and event.device != InputEvent.DEVICE_ID_EMULATION:
			_set_touch(false, false)


func press_bomb() -> void:
	if not get_tree().paused:        # no bombs while the pause menu is open
		bomb_pressed.emit()


func press_action() -> void:
	if not get_tree().paused:
		action_pressed.emit()


func press_pause() -> void:
	pause_pressed.emit()


func press_skill(slot: int) -> void:
	skill_pressed.emit(slot)


func press_menu() -> void:
	menu_pressed.emit()


func _process(_delta: float) -> void:
	if bot:
		move = bot_move.limit_length(1.0)
		aim = bot_aim.limit_length(1.0)
		action_held = G.flag("holdblock")        # the bot never blocks, except in the --holdblock test
		return
	# walking: WASD, the arrows, the D-pad and the left stick of the pad in use (all rebindable)
	var m := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.25)
	if active_pad >= 0:
		var jm := Vector2(Input.get_joy_axis(active_pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(active_pad, JOY_AXIS_LEFT_Y))
		if jm.length() > 0.25: m = jm
	# aiming belongs to the retired real-time game (dev pages still use it): the right stick only
	var a := Vector2.ZERO
	var held := touch_action_held or Input.is_physical_key_pressed(KEY_SHIFT)
	if active_pad >= 0:
		var ja := Vector2(Input.get_joy_axis(active_pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(active_pad, JOY_AXIS_RIGHT_Y))
		if ja.length() > 0.35: a = ja
		held = held or Input.get_joy_axis(active_pad, JOY_AXIS_TRIGGER_LEFT) > 0.4
	if touch_move_active: m = touch_move
	if touch_aim_active: a = touch_aim
	move = m.limit_length(1.0)
	aim = a.limit_length(1.0)
	action_held = (held or G.flag("holdblock")) and not get_tree().paused       # --holdblock: a test, the guard is always up


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		press_pause()
	elif event.is_action_pressed("menu"):
		press_menu()
	elif event.is_action_pressed("interact"):
		# ONE confirm button: whatever talks in a walking place (hub.gd listens to action_pressed)
		if action_enabled:
			press_action()
	# the retired real-time game's buttons (dev pages): bomb, guard and the two skills
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_SPACE: press_bomb()
			KEY_SHIFT: press_action()
			KEY_1, KEY_F: press_skill(0)
			KEY_2, KEY_R: press_skill(1)
	elif event is InputEventJoypadButton and event.pressed and event.device == active_pad:
		match event.button_index:
			JOY_BUTTON_RIGHT_SHOULDER: press_bomb()
			JOY_BUTTON_X: press_skill(0)
			JOY_BUTTON_B: press_skill(1)
