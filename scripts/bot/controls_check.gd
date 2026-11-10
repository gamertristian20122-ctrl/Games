class_name ControlsCheck
extends Node
## A self-test for the controls. It presses pretend keys, mouse buttons and
## controller sticks and checks that the keeper really moves, aims, fires
## and dashes, and that the menus respond.
##
## Run it in a window (it needs a mouse pointer to move):
##   godot --path . -- --controls-check
##
## It prints PASS or FAIL for each check and then quits.

var _main: Node
var _passed := 0
var _failed := 0


func begin(main: Node) -> void:
	_main = main
	_run.call_deferred()


func _run() -> void:
	print("Controls check starting.")
	await _frames(20)

	# --- Title menu: Enter starts a run ---
	_check("title screen is showing", _main.mode == "title")
	await _tap_key(KEY_ENTER)
	await _frames(10)
	_check("Enter on the title starts a run", _main.mode == "play" and _main.keeper != null)
	if _main.keeper == null:
		_finish()
		return
	var keeper: Player = _main.keeper
	await _frames(50)

	# --- Keyboard: walk right with D ---
	var start_x := keeper.position.x
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_D, false)
	_check("D walks right (moved %.0f px)" % (keeper.position.x - start_x), keeper.position.x > start_x + 20.0)
	_check("keyboard is the active device", not Controls.using_pad)

	# --- Keyboard: walk up with W, and arrow keys work too ---
	var start_y := keeper.position.y
	_key(KEY_W, true)
	await _frames(20)
	_key(KEY_W, false)
	_check("W walks up", keeper.position.y < start_y - 10.0)
	start_x = keeper.position.x
	_key(KEY_LEFT, true)
	await _frames(20)
	_key(KEY_LEFT, false)
	_check("Left arrow walks left", keeper.position.x < start_x - 10.0)

	# --- Mouse: aim up and to the right of the keeper, then hold fire ---
	await _frames(10)
	var scale := Vector2(get_window().size) / Vector2(480, 270)
	var aim_point := keeper.global_position + Vector2(80, -60)
	Input.warp_mouse(aim_point * scale)
	await _frames(6)
	var motion := InputEventMouseMotion.new()
	motion.position = aim_point * scale
	motion.relative = Vector2(10, 10)
	Input.parse_input_event(motion)
	await _frames(6)
	var want := (aim_point - keeper.global_position).normalized()
	_check("mouse aims the keeper (off by %.0f degrees)" % rad_to_deg(absf(keeper.aim_dir.angle_to(want))),
			absf(keeper.aim_dir.angle_to(want)) < 0.3)
	var before := Game.shots_fired
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _frames(45)
	_mouse(MOUSE_BUTTON_LEFT, false)
	_check("holding left click fires (%d shots)" % (Game.shots_fired - before), Game.shots_fired - before >= 2)

	# --- Keyboard: Space dashes ---
	await _frames(60)
	var dashes := Game.dashes_done
	_key(KEY_D, true)
	await _frames(3)
	await _tap_key(KEY_SPACE)
	await _frames(4)
	_key(KEY_D, false)
	_check("Space dashes", Game.dashes_done == dashes + 1)

	# --- Controller: left stick walks, right stick aims and fires, A dashes ---
	await _frames(70)
	start_y = keeper.position.y
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await _frames(25)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check("left stick walks down (moved %.0f px)" % (keeper.position.y - start_y), keeper.position.y > start_y + 15.0)
	_check("controller became the active device", Controls.using_pad)
	before = Game.shots_fired
	_axis(JOY_AXIS_RIGHT_X, -1.0)
	await _frames(45)
	_check("right stick aims left", keeper.aim_dir.x < -0.9)
	_check("right stick fires (%d shots)" % (Game.shots_fired - before), Game.shots_fired - before >= 2)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(10)
	before = Game.shots_fired
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(40)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_check("right trigger fires (%d shots)" % (Game.shots_fired - before), Game.shots_fired - before >= 2)
	await _frames(60)
	dashes = Game.dashes_done
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(3)
	_button(JOY_BUTTON_A, true)
	await _frames(3)
	_button(JOY_BUTTON_A, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(4)
	_check("A button dashes", Game.dashes_done == dashes + 1)

	# --- Pause and resume, on controller and keyboard ---
	_button(JOY_BUTTON_START, true)
	await _frames(3)
	_button(JOY_BUTTON_START, false)
	await _frames(5)
	_check("Start pauses", _main.mode == "pause" and get_tree().paused)
	await _frames(20)
	await _tap_key(KEY_ESCAPE)
	await _frames(5)
	_check("Esc resumes", _main.mode == "play" and not get_tree().paused)

	# --- Reward cards: open them, move the choice, take one ---
	for enemy: Enemy in _main.room.enemies:
		enemy.dismiss()
	_main.room.waves = []
	await _frames(30)
	keeper.position = _main.room.chest_position() + Vector2(-30, 0)
	await _frames(40)
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_D, false)
	await _frames(10)
	_check("touching the chest opens the reward cards", _main.mode == "reward")
	await _frames(30)
	var held_before: int = (Game.metrics["items"] as Array).size()
	_button(JOY_BUTTON_DPAD_RIGHT, true)
	await _frames(2)
	_button(JOY_BUTTON_DPAD_RIGHT, false)
	await _frames(4)
	_button(JOY_BUTTON_A, true)
	await _frames(2)
	_button(JOY_BUTTON_A, false)
	await _frames(6)
	_check("d-pad and A take a reward", _main.mode == "play" and (Game.metrics["items"] as Array).size() > held_before)
	_check("the door opens after the reward", _main.room.exit_open)
	_finish()


func _finish() -> void:
	print("Controls check finished: %d passed, %d failed." % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await _frames(3)
	_key(code, false)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	Input.parse_input_event(e)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)
