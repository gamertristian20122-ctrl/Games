extends Node
## Controls (autoload): every input method ends up here.
## World code reads `move` and `aim` each frame and connects to the three signals.
## Touch: scripts/ui/touch.gd writes touch_move / touch_aim and calls press_bomb() etc.
## Keyboard: WASD move, arrow keys aim, Space or E bomb, Q or Shift action, Esc pause.
## Gamepad: left stick move, right stick aim, RB/R1 bomb, LB/L1 action, Start pause.

signal bomb_pressed
signal action_pressed        ## the second button (reserved for the game's twist)
signal pause_pressed
signal skill_pressed(slot: int)   ## skill button 1 or 2 (0 or 1): the touch buttons, keys 1 / 2 or F / R, gamepad X / B
signal menu_pressed          ## open the Knight screen (level, stats): the "Lv" touch button, C or Tab, gamepad Y
## The player switched between the touch screen and a keyboard / gamepad.
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

# written by the test bot (when bot == true these replace all other input)
var bot := false
var bot_move := Vector2.ZERO
var bot_aim := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	using_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or G.flag("touch")     # --touch: show the phone buttons in test pictures
	get_window().window_input.connect(_watch_device)


func _set_touch(on: bool) -> void:
	if on != using_touch:
		using_touch = on
		device_changed.emit(on)


## Only watches WHICH device is in use; the real handling is below and in scripts/ui/touch.gd.
## (Connected to the window itself so it also sees events that a menu has already used up.)
func _watch_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_touch(true)
	elif event is InputEventKey:
		# (the phone's Back and volume keys are keys too, and must not hide the touch controls)
		if event.pressed and not event.echo and event.keycode not in [KEY_BACK, KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_VOLUMEMUTE, KEY_MENU]:
			_set_touch(false)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_set_touch(false)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			_set_touch(false)


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
	var m := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): m.x -= 1
	if Input.is_physical_key_pressed(KEY_D): m.x += 1
	if Input.is_physical_key_pressed(KEY_W): m.y -= 1
	if Input.is_physical_key_pressed(KEY_S): m.y += 1
	var a := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT): a.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT): a.x += 1
	if Input.is_physical_key_pressed(KEY_UP): a.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN): a.y += 1
	for pad in Input.get_connected_joypads():
		var jm := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if jm.length() > 0.25: m = jm
		var ja := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if ja.length() > 0.35: a = ja
	if touch_move_active: m = touch_move
	if touch_aim_active: a = touch_aim
	move = m.limit_length(1.0)
	aim = a.limit_length(1.0)
	var held := touch_action_held or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_SHIFT)
	for pad2 in Input.get_connected_joypads():
		held = held or Input.is_joy_button_pressed(pad2, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(pad2, JOY_AXIS_TRIGGER_LEFT) > 0.4
	action_held = (held or G.flag("holdblock")) and not get_tree().paused       # --holdblock: a test, the guard is always up


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_E: press_bomb()
			KEY_Q, KEY_SHIFT: press_action()
			KEY_ESCAPE: press_pause()
			KEY_C, KEY_TAB: press_menu()
			KEY_1, KEY_F: press_skill(0)
			KEY_2, KEY_R: press_skill(1)
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_RIGHT_SHOULDER: press_bomb()
			JOY_BUTTON_LEFT_SHOULDER: press_action()
			JOY_BUTTON_START: press_pause()
			JOY_BUTTON_Y: press_menu()
			JOY_BUTTON_X: press_skill(0)
			JOY_BUTTON_B: press_skill(1)
