extends CanvasLayer
## Touch controls: two floating sticks and three buttons, drawn with plain shapes.
##   A stick appears where the thumb lands. Left half of the screen moves, right half aims
##   and fires (the other way round when "Left-handed sticks" is on in Settings).
##   Bomb and CALL sit on the edge of the aiming side, above where that thumb rests.
##   CALL is the game's second button: it calls the Hungry Curse (Controls.press_action()). It
##   shows the pack's skull, is lit only while a call would work (a fight is on and the Curse is
##   creeping), and a ring around it fills up again while the cooldown runs.
##   Pause is the small button in the top right corner.
## Every finger is tracked by its own number, so both sticks work at once and a finger that
## started on a button never drags a stick. The results go to scripts/core/controls.gd
## (Controls.touch_move, Controls.touch_aim, press_bomb() ...), where the game reads them.
## The whole layer hides while a keyboard or gamepad is in use and returns on the next touch.

const UI = preload("res://scripts/ui/theme.gd")

const RADIUS := 22.0            ## stick size: full tilt is this far from where the thumb landed
const DEADZONE := 0.16          ## tiny wobbles around the centre do nothing
const KNOB := 9.0
const BUTTON_R := 14.0          ## visible button radius (28 px across)
const HIT_PAD := 9.0            ## invisible extra reach around every button
const PAUSE_SIZE := 20.0
const ALPHA := 0.35
const BLOCK_LABEL := "BLOCK"                   ## the same button in a level when the hero carries a shield arm (melee)
const TALK_LABEL := "TALK"                     ## the same button in the camp (hub_mode)
const CALL_LABEL := "CALL"                     ## the word under the second button
const CALL_GOLD := Color(0.98, 0.90, 0.58)     ## the Hungry Curse's pale gold

var active := false
var _fingers := {}              ## finger number -> "move", "aim", "bomb", "action", "pause" or "none"
var _origin := {"move": Vector2.ZERO, "aim": Vector2.ZERO}
var _knob := {"move": Vector2.ZERO, "aim": Vector2.ZERO}
var _held := {"move": false, "aim": false}
var _swapped := false
var _bombs := 0
var _block_left := 2            ## blows the knight's guard can still take (player.gd)
var hub_mode := false           ## in the camp: one stick to walk and the second button says TALK (main.gd sets this)
var _action_shown := false
var _canvas: Control
var _bomb_tex: Texture2D
var _skull_tex: Texture2D
var _skull_region := Rect2()
var _call_fill := 1.0           ## 0..1: how far the CALL cooldown has recovered
var _call_ready := false        ## pressing CALL would work right now
var _call_pulse := false        ## the first-run lesson points at the button
var _pulse_t := 0.0
var _pressed_flash := {"bomb": 0.0, "action": 0.0, "pause": 0.0}


func _ready() -> void:
	layer = G.LAYER_TOUCH
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bomb_tex = Art.tex("prop_bomb")
	_skull_tex = Art.tex("skull")
	_skull_region = UI.used_rect("skull")
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UI.theme()
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	G.hud_changed.connect(_read_bombs)
	G.player_hurt.connect(func(_n: int) -> void: _buzz(30))
	G.buzz.connect(_buzz)
	Controls.device_changed.connect(func(_t: bool) -> void: _update_visible())
	get_viewport().size_changed.connect(_canvas.queue_redraw)
	_update_visible()


## main.gd turns the controls on while a run is being played and off in menus and when paused.
func set_active(on: bool) -> void:
	_swapped = bool(Save.setting("swap_sticks"))
	if on == active:
		_canvas.queue_redraw()
		return
	active = on
	_release_all()
	_read_bombs()
	_update_visible()


func _update_visible() -> void:
	visible = active and Controls.using_touch
	_canvas.queue_redraw()


func _release_all() -> void:
	_fingers.clear()
	for role: String in ["move", "aim"]:
		_held[role] = false
	Controls.touch_move = Vector2.ZERO
	Controls.touch_move_active = false
	Controls.touch_aim = Vector2.ZERO
	Controls.touch_aim_active = false
	Controls.touch_action_held = false


func _read_bombs() -> void:
	var n := 0
	if is_instance_valid(G.run):
		var p: Variant = G.run.get("player")
		if is_instance_valid(p) and p.get("bombs") != null:
			n = int(p.get("bombs"))
	if n != _bombs:
		_bombs = n
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	if Controls.action_enabled != _action_shown:
		_action_shown = Controls.action_enabled
		_canvas.queue_redraw()
	if Controls.action_enabled:
		_read_call(delta)
	for key: String in _pressed_flash:
		if _pressed_flash[key] > 0.0:
			_pressed_flash[key] = maxf(_pressed_flash[key] - delta * 5.0, 0.0)
			_canvas.queue_redraw()


## What the CALL button shows comes from the run (see "run.call_*" in scripts/core/g.gd).
func _read_call(delta: float) -> void:
	var fill := 1.0
	var ready := false
	var pulse := false
	if hub_mode:
		ready = G.hub_near
	if is_instance_valid(G.run):
		var f: Variant = G.run.get("call_fill")
		if f is float:
			fill = f
		ready = G.run.get("call_ready") == true
		pulse = G.run.get("call_pulse") == true
	if _block_mode():
		var hero: Node = G.run.get("player")
		_block_left = int(hero.get("block_left"))
		ready = _block_left > 0
		fill = float(hero.get("block_fill"))
	if pulse:
		_pulse_t += delta
	if not is_equal_approx(fill, _call_fill) or ready != _call_ready or pulse != _call_pulse or pulse:
		_call_fill = fill
		_call_ready = ready
		_call_pulse = pulse
		_canvas.queue_redraw()


## In a level with a sword hero the second button is BLOCK (hold it).
func _block_mode() -> bool:
	if hub_mode or not is_instance_valid(G.run):
		return false
	var p: Variant = G.run.get("player")
	return is_instance_valid(p) and p.get("hero") is Dictionary and (p.get("hero") as Dictionary).has("melee")


func _buzz(msec: int) -> void:
	if Controls.using_touch and bool(Save.setting("vibration")):
		Input.vibrate_handheld(msec)


# ------------------------------------------------------------------ where things are
func _screen() -> Vector2:
	return _canvas.size


## The edge of the screen on the aiming side, inside the safe area.
func _button_centre(which: String) -> Vector2:
	var ins := UI.safe_insets(self)
	var s := _screen()
	if which == "pause":
		return Vector2(s.x - ins.z - 3.0 - PAUSE_SIZE / 2.0, ins.y + 3.0 + PAUSE_SIZE / 2.0)
	var y := 100.0 if which == "bomb" else 66.0
	if _swapped:
		return Vector2(ins.x + 6.0 + BUTTON_R, y)
	return Vector2(s.x - ins.z - 6.0 - BUTTON_R, y)


func _button_at(pos: Vector2) -> String:
	var p := _button_centre("pause")
	if absf(pos.x - p.x) <= PAUSE_SIZE / 2.0 + HIT_PAD and absf(pos.y - p.y) <= PAUSE_SIZE / 2.0 + HIT_PAD:
		return "pause"
	if not hub_mode and pos.distance_to(_button_centre("bomb")) <= BUTTON_R + HIT_PAD:
		return "bomb"
	if Controls.action_enabled and pos.distance_to(_button_centre("action")) <= BUTTON_R + HIT_PAD:
		return "action"
	return ""


## Which stick a touch at this position starts.
func _role_at(pos: Vector2) -> String:
	var left := pos.x < _screen().x / 2.0
	return "move" if left != _swapped else "aim"


# ------------------------------------------------------------------ fingers
func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)


func _press(finger: int, pos: Vector2) -> void:
	var button := _button_at(pos)
	if button != "":
		_fingers[finger] = button
		_pressed_flash[button] = 1.0
		match button:
			"pause":
				Controls.press_pause()
			"bomb":
				if _bombs > 0:
					_buzz(40)
				Controls.press_bomb()
			"action":
				_buzz(20)
				Controls.touch_action_held = true
				Controls.press_action()
		_canvas.queue_redraw()
		return
	var role := _role_at(pos)
	if _held[role]:
		_fingers[finger] = "none"      # that stick already has a thumb on it
		return
	_fingers[finger] = role
	_held[role] = true
	# keep the whole ring on screen so full tilt is always reachable
	var s := _screen()
	_origin[role] = pos.clamp(Vector2(RADIUS + 2.0, RADIUS + 2.0), s - Vector2(RADIUS + 2.0, RADIUS + 2.0))
	_knob[role] = pos
	_feed(role)


func _drag(finger: int, pos: Vector2) -> void:
	var role := String(_fingers.get(finger, "none"))
	if role != "move" and role != "aim":
		return
	var offset: Vector2 = pos - _origin[role]
	# the ring follows a thumb that wanders too far, so turning back is always quick
	if offset.length() > RADIUS * 1.25:
		_origin[role] = pos - offset.normalized() * RADIUS * 1.25
	_knob[role] = pos
	_feed(role)


func _release(finger: int) -> void:
	var role := String(_fingers.get(finger, "none"))
	_fingers.erase(finger)
	if role == "action":
		Controls.touch_action_held = false
		_canvas.queue_redraw()
	if role == "move" or role == "aim":
		_held[role] = false
		_feed(role)


## Turns a thumb position into a 0..1 stick value and hands it to Controls.
func _feed(role: String) -> void:
	var v := Vector2.ZERO
	if _held[role]:
		var offset: Vector2 = (_knob[role] - _origin[role]) / RADIUS
		var amount := offset.length()
		if amount > DEADZONE:
			v = offset.normalized() * clampf((amount - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	if role == "move":
		Controls.touch_move = v
		Controls.touch_move_active = _held[role]
	else:
		Controls.touch_aim = v
		Controls.touch_aim_active = _held[role]
	_canvas.queue_redraw()


# ------------------------------------------------------------------ drawing
func _draw_controls() -> void:
	if not active:
		return
	var s := _screen()
	var ins := UI.safe_insets(self)
	for role: String in ["move", "aim"]:
		if _held[role]:
			var o: Vector2 = _origin[role]
			var k: Vector2 = o + (_knob[role] - o).limit_length(RADIUS)
			_canvas.draw_circle(o, RADIUS, Color(0, 0, 0, 0.14))
			_canvas.draw_arc(o, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, ALPHA), 1.5, true)
			_canvas.draw_circle(k, KNOB, Color(1, 1, 1, ALPHA))
			_canvas.draw_arc(k, KNOB, 0.0, TAU, 24, Color(1, 1, 1, ALPHA + 0.15), 1.0, true)
		elif not (hub_mode and role == "aim"):
			# a faint ring where each thumb usually rests, so new players know where to touch
			var left := (role == "move") != _swapped
			var x := ins.x + 52.0 if left else s.x - ins.z - 62.0
			var rest := Vector2(x, s.y - ins.w - 46.0)
			_canvas.draw_arc(rest, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.13), 1.0, true)
			_canvas.draw_circle(rest, KNOB, Color(1, 1, 1, 0.09))

	# bomb: the pack's bomb sprite and how many are left
	var font := UI.font_body
	if not hub_mode:
		var bc := _button_centre("bomb")
		var dim := 1.0 if _bombs > 0 else 0.4
		_round_button(bc, _pressed_flash["bomb"], dim)
		_canvas.draw_texture(_bomb_tex, (bc - _bomb_tex.get_size() / 2.0 + Vector2(-1, -1)).round(), Color(1, 1, 1, 0.9 * dim))
		var text := str(_bombs)
		var tp := bc + Vector2(5, 12)
		_canvas.draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, 3, Color(UI.C_INK, 0.9 * dim))
		_canvas.draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, Color(UI.C_BONE, dim))

	# CALL: the pack's skull (drawn at twice its size), lit only while a call would work,
	# with a ring that fills up again while the cooldown runs
	if Controls.action_enabled:
		var ac := _button_centre("action")
		var lit := 1.0 if _call_ready else 0.4
		_round_button(ac, _pressed_flash["action"], lit)
		var skull_size := _skull_region.size * 2.0
		if _block_mode():
			# a small shield: a flat shape
			var held := 1.0 if Controls.touch_action_held else 0.8
			_canvas.draw_rect(Rect2(ac.x - 5.0, ac.y - 6.0, 10, 7), Color(UI.C_BONE, held * lit))
			_canvas.draw_colored_polygon(PackedVector2Array([ac + Vector2(-5, 1), ac + Vector2(5, 1), ac + Vector2(0, 7)]), Color(UI.C_BONE, held * lit))
			_canvas.draw_rect(Rect2(ac.x - 1.0, ac.y - 4.0, 2, 7), Color(UI.C_INK, 0.6 * lit))
			for k in 2:       # one pip for every blow the guard can still take
				_canvas.draw_rect(Rect2(ac.x - 5.0 + 6.0 * k, ac.y + 9.0, 4, 2), Color(UI.C_BONE, 0.95) if k < _block_left else Color(UI.C_BONE, 0.2))
		elif hub_mode:
			for k in 3:       # three dots: "speak"
				_canvas.draw_rect(Rect2(ac.x - 7.0 + 5.0 * k, ac.y - 1.0, 3, 3), Color(UI.C_BONE, 0.95 * lit))
		else:
			_canvas.draw_texture_rect_region(_skull_tex, Rect2((ac - skull_size / 2.0).round(), skull_size), _skull_region, Color(CALL_GOLD, 0.95 * lit))
		if _call_fill < 1.0:
			_canvas.draw_arc(ac, BUTTON_R - 2.5, -PI / 2.0, -PI / 2.0 + TAU * _call_fill, 32, Color(CALL_GOLD, 0.85), 2.0, true)
		elif _call_ready:
			_canvas.draw_arc(ac, BUTTON_R - 2.5, 0.0, TAU, 32, Color(CALL_GOLD, 0.9), 1.5, true)
		if _call_pulse:
			# the first-run lesson: a ring closes in on the button again and again
			var k := fmod(_pulse_t * 1.4, 1.0)
			_canvas.draw_arc(ac, BUTTON_R + 10.0 * (1.0 - k), 0.0, TAU, 32, Color(CALL_GOLD, 0.25 + 0.6 * k), 2.0, true)
		var label_text := TALK_LABEL if hub_mode else (BLOCK_LABEL if _block_mode() else CALL_LABEL)
		var lw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body).x
		var lp := Vector2(roundf(ac.x - lw / 2.0), ac.y - BUTTON_R - 3.0)      # above the button: the bomb button is right below
		_canvas.draw_string_outline(font, lp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, 3, Color(UI.C_INK, 0.9 * lit))
		_canvas.draw_string(font, lp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, Color(CALL_GOLD, lit))

	# pause: two bars in a small square
	var pc := _button_centre("pause")
	var half := PAUSE_SIZE / 2.0
	var a := 0.5 + 0.4 * float(_pressed_flash["pause"])
	_canvas.draw_rect(Rect2(pc - Vector2(half, half), Vector2(PAUSE_SIZE, PAUSE_SIZE)), Color(0, 0, 0, 0.3))
	_canvas.draw_rect(Rect2(pc - Vector2(half, half) + Vector2(0.5, 0.5), Vector2(PAUSE_SIZE - 1, PAUSE_SIZE - 1)), Color(1, 1, 1, a * 0.7), false, 1.0)
	_canvas.draw_rect(Rect2(pc.x - 4, pc.y - 5, 3, 10), Color(1, 1, 1, a))
	_canvas.draw_rect(Rect2(pc.x + 1, pc.y - 5, 3, 10), Color(1, 1, 1, a))


func _round_button(c: Vector2, flash: float, dim: float) -> void:
	_canvas.draw_circle(c, BUTTON_R, Color(0, 0, 0, 0.28 * dim))
	if flash > 0.0:
		_canvas.draw_circle(c, BUTTON_R, Color(1, 1, 1, 0.3 * flash))
	_canvas.draw_arc(c, BUTTON_R, 0.0, TAU, 32, Color(1, 1, 1, (ALPHA + 0.1) * dim), 1.5, true)
