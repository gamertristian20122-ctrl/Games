extends SceneTree
## Writes the keyboard, mouse and controller bindings into project.godot.
##
## You normally never need to run this. The bindings it writes show up in
## Godot under Project > Project Settings > Input Map, where you can change
## them with the mouse. It is kept so the bindings can be rebuilt from scratch:
##
##   godot --headless --path . --script tools/make_input_map.gd


func _init() -> void:
	var actions := {
		# Moving: WASD, arrow keys, left stick or d-pad.
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)],
		# Aiming with a controller: right stick. (The mouse aims by pointing.)
		"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		# Shooting: left mouse button, right trigger or right bumper.
		"shoot": [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _button(JOY_BUTTON_RIGHT_SHOULDER)],
		# Dashing: Space, Shift, right mouse button, A button, left trigger or left bumper.
		"dash": [_key(KEY_SPACE), _key(KEY_SHIFT), _mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_A),
				_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _button(JOY_BUTTON_LEFT_SHOULDER)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)],
		"fullscreen": [_key(KEY_F11)],
	}
	for action: String in actions:
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.25, "events": actions[action]})

	# Let WASD steer menus too (arrow keys, d-pad and left stick already do).
	_extend("ui_left", [_key(KEY_A)])
	_extend("ui_right", [_key(KEY_D)])
	_extend("ui_up", [_key(KEY_W)])
	_extend("ui_down", [_key(KEY_S)])
	# Godot's built-in menu actions have no controller buttons, so add them:
	# A confirms, B goes back.
	_extend("ui_accept", [_button(JOY_BUTTON_A)])
	_extend("ui_cancel", [_button(JOY_BUTTON_B)])

	var err := ProjectSettings.save()
	print("Input map written to project.godot (error code %d, 0 means OK)." % err)
	quit()


func _extend(action: String, extra: Array) -> void:
	var events: Array = InputMap.action_get_events(action)
	for e: InputEvent in extra:
		var already := false
		for old: InputEvent in events:
			if old.is_match(e):
				already = true
		if not already:
			events.append(e)
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1     # -1 means "any controller", not just the first one
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1     # -1 means "any controller", not just the first one
	e.axis = axis
	e.axis_value = value
	return e
