extends Control
## FocusFlame: the ember pointer that marks the focused control (UI.flame(scope)). ONE per screen
## (screen.gd adds it). It sits 5 UI px left of the focused control inside `scope`, vertically
## centred, glides to a new focus in 0.08 s, breathes +-1 UI px at 1.6 Hz, and plays the focus-move
## click once per change (ui_click at -12 dB, pitch 1.18; never twice within 0.05 s). Hidden while
## the touch screen is the input, and for controls with meta "no_flame" = true.
## The row itself shows the sweep (theme "focus" stylebox); the mouse moves the focus (hover).

const UI = preload("res://scripts/ui/theme.gd")

## The node whose descendants it follows (default: the parent).
var scope: Node
## Extra x offset (UI px) for rows whose flame should sit further in or out.
var gap := 5.0

static var _last_sound := 0
var _owner: Control
var _first := true
var _tw: Tween
var _gliding := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 20
	size = Vector2.ZERO
	visible = false


func _ready() -> void:
	if scope == null:
		scope = get_parent()


func _target(c: Control) -> Vector2:
	var r := c.get_global_rect()
	return Vector2(r.position.x - gap, r.position.y + r.size.y * 0.5)


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	var ok := f != null and is_instance_valid(scope) and scope.is_ancestor_of(f) and f.is_visible_in_tree() \
		and not bool(f.get_meta("no_flame", false)) and not Controls.using_touch
	if not ok:
		visible = false
		if f == null:
			_owner = null
		return
	if f != _owner:
		var was := _owner
		_owner = f
		if was == null or not visible or UI.instant:
			_gliding = false
			if _tw != null and _tw.is_valid():
				_tw.kill()
			global_position = _target(f)
		else:
			_gliding = true
			if _tw != null and _tw.is_valid():
				_tw.kill()
			_tw = create_tween()
			_tw.tween_property(self, "global_position", _target(f), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tw.tween_callback(func() -> void: _gliding = false)
		if not _first:
			_click()
		_first = false
	elif not _gliding:
		global_position = _target(f)      # follows scrolling and layout changes
	visible = true
	queue_redraw()


func _click() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound < 50:
		return
	_last_sound = now
	Sfx.play("ui_click", -12.0, 0.03, 1.18)


func _draw() -> void:
	var breathe := 0.0 if UI.instant else sin(_t * TAU * 1.6)
	UI.rs_flame(get_canvas_item(), Vector2(breathe, 0))
