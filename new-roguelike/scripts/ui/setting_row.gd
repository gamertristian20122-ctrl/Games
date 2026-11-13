extends PanelContainer
## Setting row: one line on the Settings and Your knight screens. Three kinds:
##   "steps"   a volume-style value from 0 to 5: brass segments between two chevrons
##   "toggle"  On / Off: a small capsule switch (off = a dark well, on = ember fill and the knob right)
##   "choice"  one of `options` (set before setup): "<  Normal  >", the chevrons light on focus
##   "swatch"  a "choice" shown as colour chips (`swatches`, one Color per option); the label says
##             the chosen option's name
## Works with touch and the mouse (tap a chevron or a segment; tap a switch or the row), the keyboard
## and a gamepad (left / right / accept). The mouse moves the focus onto the row it is over.
## HD GUI: 24 UI px tall on a PC (20 on a phone), label body 12 on the left, the value on the right;
## the focused row shows the ember sweep and the screen's flame pointer.

const UI = preload("res://scripts/ui/theme.gd")

signal changed(value: Variant)

const STEPS := 5

var kind := "steps"
var title := ""
var steps := 0           ## 0..STEPS for "steps"
var on := false          ## for "toggle"
var options: Array = []  ## for "choice": the words to cycle through (set before setup)
var index := 0           ## for "choice" and "swatch"
var swatches: Array = [] ## for "swatch": one Color per option (set before setup)
var _label: Label
var _value: Control
var _ph := false


func setup(row_kind: String, row_title: String, start: Variant) -> void:
	kind = row_kind
	title = row_title
	if kind == "steps":
		steps = clampi(int(roundf(float(start) * STEPS)), 0, STEPS)
	elif kind == "choice" or kind == "swatch":
		index = clampi(int(start), 0, maxi(options.size() - 1, 0))
	else:
		on = bool(start)
	if is_instance_valid(_value):
		_show()


func _ready() -> void:
	_ph = UI.is_phone()
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 24 if not _ph else 20)
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 10 if not _ph else 6
	plain.content_margin_right = 8 if not _ph else 4
	add_theme_stylebox_override("panel", plain)
	focus_entered.connect(_paint)
	focus_exited.connect(_paint)
	mouse_entered.connect(func() -> void:
		if not has_focus() and not Controls.using_touch and is_visible_in_tree():
			grab_focus())
	var row := UI.hbox(6 if not _ph else 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_label = UI.label(title)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_FILL
	_label.clip_text = true
	row.add_child(_label)
	_value = Control.new()
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.size_flags_vertical = Control.SIZE_FILL
	_value.custom_minimum_size.x = _value_width()
	_value.draw.connect(_draw_value)
	row.add_child(_value)
	_show()
	_paint()


func _value_width() -> float:
	match kind:
		"steps":
			return (5.0 * 11.0 + 30.0) if not _ph else (5.0 * 8.0 + 24.0)
		"toggle":
			return 58.0 if not _ph else 46.0
		"swatch":
			return swatches.size() * (15.0 if not _ph else 11.0) + 4.0
	return 110.0 if not _ph else 84.0


## The focus look: the theme's ember sweep under the row and gold words.
func _paint() -> void:
	var lit := has_focus()
	var sb: StyleBox
	if lit:
		sb = (get_theme_stylebox("focus", "Button") as StyleBox).duplicate()
	else:
		sb = StyleBoxEmpty.new()
	sb.content_margin_left = 10 if not _ph else 6
	sb.content_margin_right = 8 if not _ph else 4
	add_theme_stylebox_override("panel", sb)
	if is_instance_valid(_label):
		_label.add_theme_color_override("font_color", UI.C_GOLD if lit else UI.C_PARCH)
	if is_instance_valid(_value):
		_value.queue_redraw()


func _show() -> void:
	if is_instance_valid(_value):
		_value.queue_redraw()
	if kind == "swatch" and is_instance_valid(_label) and index < options.size():
		_label.text = "%s:  %s" % [title, String(options[index])]


## A thin line under the row.
func _draw() -> void:
	draw_rect(Rect2(0, size.y - 1.0, size.x, 1.0), Color(1, 1, 1, 0.05))


# ------------------------------------------------------------------ drawing the value
func _chevron(at: Vector2, dir: float, colour: Color) -> void:
	var s := 3.5 if not _ph else 2.5
	var pts := PackedVector2Array([at + Vector2(-dir * s * 0.5, -s), at + Vector2(dir * s * 0.5, 0), at + Vector2(-dir * s * 0.5, s)])
	_value.draw_polyline(pts, Color(UI.C_INK, 0.8), 3.0, true)
	_value.draw_polyline(pts, colour, 1.4, true)


func _draw_value() -> void:
	var lit := has_focus()
	var w := _value.size.x
	var mid := roundf(_value.size.y * 0.5)
	var chev := UI.C_GOLD if lit else Color(UI.C_PARCH, 0.55)
	match kind:
		"steps":
			_chevron(Vector2(5, mid), -1.0, chev if steps > 0 else Color(UI.C_FAINT, 0.6))
			_chevron(Vector2(w - 5, mid), 1.0, chev if steps < STEPS else Color(UI.C_FAINT, 0.6))
			var seg := 9.0 if not _ph else 6.0
			var gap := 2.0
			var h := 6.0 if not _ph else 5.0
			var x0 := roundf((w - (STEPS * seg + (STEPS - 1) * gap)) * 0.5)
			for i in STEPS:
				var r := Rect2(x0 + i * (seg + gap), mid - h * 0.5, seg, h)
				_value.draw_rect(r.grow(1.0), Color(UI.C_INK, 0.85))
				if i < steps:
					_value.draw_rect(r, UI.C_GOLD.lerp(UI.C_EMBER, 0.15) if lit else UI.C_BRASS)
					_value.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Color(1, 0.95, 0.8, 0.55))
				else:
					_value.draw_rect(r, Color(0.08, 0.09, 0.13))
					_value.draw_rect(r, Color(UI.C_BRASS, 0.25), false, 1.0)
		"toggle":
			var cw := 24.0 if not _ph else 18.0
			var ch := 12.0 if not _ph else 9.0
			var cap := Rect2(w - cw - 1.0, mid - ch * 0.5, cw, ch)
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(int(ch * 0.5))
			sb.anti_aliasing = true
			sb.set_border_width_all(1)
			if on:
				sb.bg_color = Color(UI.C_EMBER, 0.9 if lit else 0.75)
				sb.border_color = Color(UI.C_GOLD, 0.9)
			else:
				sb.bg_color = Color(0.015, 0.02, 0.035, 0.9)
				sb.border_color = Color(UI.C_BRASS, 0.55 if lit else 0.3)
			_value.draw_style_box(sb, cap)
			var kr := ch * 0.5 - 2.0
			var kx := cap.end.x - ch * 0.5 if on else cap.position.x + ch * 0.5
			_value.draw_circle(Vector2(kx, mid), kr + 0.6, Color(UI.C_INK, 0.7), true, -1.0, true)
			_value.draw_circle(Vector2(kx, mid), kr, UI.C_PARCH if on else Color(0.55, 0.55, 0.58), true, -1.0, true)
			var word := "On" if on else "Off"
			var fs := UI.size_small if not _ph else UI.size_small
			var tw := UI.font_body.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var base := Vector2(cap.position.x - 5.0 - tw, roundf(mid + UI.font_body.get_ascent(fs) * 0.5 - 1.0))
			_value.draw_string(UI.font_body, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (UI.C_GOLD if lit else UI.C_PARCH) if on else UI.C_DIM)
		"swatch":
			var step := 15.0 if not _ph else 11.0
			var sz := 11.0 if not _ph else 8.0
			for i in swatches.size():
				var c := Vector2(2.0 + i * step + step * 0.5, mid)
				var r := Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
				if i == index:
					_value.draw_rect(r.grow(2.5), UI.C_GOLD if lit else Color(UI.C_GOLD, 0.7))
				_value.draw_rect(r.grow(1.0), Color(UI.C_INK, 0.9))
				var col: Color = swatches[i]
				_value.draw_rect(r, col)
				_value.draw_rect(Rect2(r.position, Vector2(sz, 1.5)), Color(1, 1, 1, 0.3))
		_:
			var word := String(options[index]) if index < options.size() else ""
			var fs := UI.size_body
			_chevron(Vector2(5, mid), -1.0, chev)
			_chevron(Vector2(w - 5, mid), 1.0, chev)
			var base := Vector2(10, roundf(mid + UI.font_body.get_ascent(fs) * 0.5 - 1.0))
			_value.draw_string(UI.font_body, base, word, HORIZONTAL_ALIGNMENT_CENTER, w - 20.0, fs, UI.C_GOLD if lit else UI.C_PARCH)


# ------------------------------------------------------------------ changing it
func _nudge(by: int) -> void:
	var next := clampi(steps + by, 0, STEPS)
	if next == steps:
		return
	steps = next
	_show()
	changed.emit(steps / float(STEPS))


func _set_steps(n: int) -> void:
	n = clampi(n, 0, STEPS)
	if n == steps:
		return
	steps = n
	_show()
	changed.emit(steps / float(STEPS))


func _flip(by: int = 1) -> void:
	if kind == "choice" or kind == "swatch":
		if options.is_empty():
			return
		index = posmod(index + by, options.size())
		_show()
		changed.emit(index)
		return
	on = not on
	_show()
	changed.emit(on)


## Where a click / tap on the value lands: -1 the left chevron, +1 the right one, 0 elsewhere;
## for steps also which segment (returned as 10 + segment number).
func _hit(local: Vector2) -> int:
	var vr := Rect2(_value.global_position - global_position, _value.size)
	if not vr.grow_individual(0, 4, 4, 4).has_point(local):
		return 0
	var x := local.x - vr.position.x
	if x < 14.0:
		return -1
	if x > vr.size.x - 14.0:
		return 1
	if kind == "steps":
		var seg := 9.0 if not _ph else 6.0
		var gap := 2.0
		var x0 := roundf((vr.size.x - (STEPS * seg + (STEPS - 1) * gap)) * 0.5)
		return 10 + clampi(int((x - x0) / (seg + gap)), 0, STEPS - 1)
	return 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _hit(event.position)
		if not has_focus():
			grab_focus()
		match kind:
			"steps":
				if at == -1 or at == 1:
					_nudge(at)
				elif at >= 10:
					_set_steps(at - 10 + 1 if steps != at - 10 + 1 else at - 10)
			"choice":
				_flip(-1 if at == -1 else 1)
			"swatch":
				var vx: float = event.position.x - (_value.global_position.x - global_position.x)
				var pick := int((vx - 2.0) / (15.0 if not _ph else 11.0))
				if vx >= 0.0 and pick >= 0 and pick < swatches.size():
					if pick != index:
						index = pick
						_show()
						changed.emit(index)
				else:
					_flip()
			_:
				_flip()
		accept_event()
		return
	if kind == "steps":
		if event.is_action_pressed("ui_left"):
			_nudge(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			_nudge(1)
			accept_event()
	else:
		if event.is_action_pressed("ui_left") and (kind == "choice" or kind == "swatch"):
			_flip(-1)
			accept_event()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_flip()
			accept_event()
