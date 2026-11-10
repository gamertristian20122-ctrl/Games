extends Node
## Works out whether the player is using keyboard + mouse or a controller,
## and turns their button presses into a PlayerInput for the keeper.
##
## The actual key and button bindings live in Project Settings > Input Map.

signal device_changed(using_pad: bool)

const STICK_DEADZONE := 0.3

## True while the last thing touched was a controller.
var using_pad := false

var _last_aim := Vector2.RIGHT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_using_pad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_set_using_pad(true)
	elif event is InputEventKey and event.pressed:
		_set_using_pad(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_using_pad(false)
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		_set_using_pad(false)


func _set_using_pad(value: bool) -> void:
	if value != using_pad:
		using_pad = value
		device_changed.emit(using_pad)


## Reads the controls for one tick. "keeper_pos" and "mouse_pos" are in the
## same coordinates (the room), so the keeper can aim at the mouse pointer.
func read(into: PlayerInput, keeper_pos: Vector2, mouse_pos: Vector2, dash_pressed: bool) -> void:
	into.move = Input.get_vector("move_left", "move_right", "move_up", "move_down", STICK_DEADZONE)
	into.dash = dash_pressed
	if using_pad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", STICK_DEADZONE)
		if stick.length() > 0.01:
			_last_aim = stick.normalized()
			into.shoot = true   # pushing the right stick aims and fires
		else:
			into.shoot = Input.is_action_pressed("shoot")
			if into.move.length() > 0.2 and not into.shoot:
				_last_aim = into.move.normalized()   # face where you walk
		into.aim = _last_aim
	else:
		var to_mouse := mouse_pos - keeper_pos
		if to_mouse.length() > 1.0:
			_last_aim = to_mouse.normalized()
		into.aim = _last_aim
		into.shoot = Input.is_action_pressed("shoot")


## A short buzz on the controller (does nothing on keyboard).
func rumble(weak: float, strong: float, seconds: float) -> void:
	if using_pad and not Game.bot_mode:
		for pad: int in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, weak, strong, seconds)
