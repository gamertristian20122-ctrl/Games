extends Control
## Bar: a health / mana / XP bar in the Lantern Glass look (UI.bar(preset, width)).
## A capsule well with a faint brass border, a fill lit from the top with a gleam, the part just
## LOST shown pale (held 0.35 s, then drains in 0.45 s), gains fill up in 0.25 s with a bright edge,
## and under 30% an HP bar pulses (is_low() tells a number beside it to turn C_LOW).
##   var hp := UI.bar("hp", 60); hp.set_value(21, 38, false) ... hp.set_value(9, 38)   # animated
## Presets: "hp", "mp", "xp", "boss" (brass end caps), "foe". Heights are per tier (PC / phone).

const UI = preload("res://scripts/ui/theme.gd")

const PRESETS := {
	"hp": {"a": UI.C_HP_A, "b": UI.C_HP_B, "h": 4.0, "h_phone": 3.0, "pulse": true},
	"mp": {"a": UI.C_MP_A, "b": UI.C_MP_B, "h": 4.0, "h_phone": 3.0, "pulse": false},
	"xp": {"a": UI.C_XP_A, "b": UI.C_XP_B, "h": 4.0, "h_phone": 4.0, "pulse": false},
	"boss": {"a": UI.C_HP_A, "b": UI.C_HP_B, "h": 6.0, "h_phone": 4.0, "pulse": false, "caps": true},
	"foe": {"a": UI.C_HP_A, "b": UI.C_HP_B, "h": 3.0, "h_phone": 2.0, "pulse": false},
}
const HOLD := 0.35          ## the lost part waits ...
const DRAIN := 0.45         ## ... then drains this fast
const GAIN := 0.25          ## a gain fills up this fast
const LOW := 0.30

var preset := "hp"
var col_a := UI.C_HP_A
var col_b := UI.C_HP_B
var pulse := true
var caps := false
var value := 1.0
var max_value := 1.0
var _shown := 1.0           ## the fill drawn (ratio)
var _lost := 0.0            ## the pale part reaches this far (ratio), 0 = none
var _edge := 0.0            ## the bright edge of a gain, fading
var _tw: Tween
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(which: String, width: float = 60.0) -> void:
	preset = which if PRESETS.has(which) else "hp"
	var p: Dictionary = PRESETS[preset]
	col_a = p["a"]
	col_b = p["b"]
	pulse = bool(p.get("pulse", false))
	caps = bool(p.get("caps", false))
	var h: float = p["h_phone"] if UI.is_phone() else p["h"]
	custom_minimum_size = Vector2(width, h)
	size = custom_minimum_size
	queue_redraw()


## Sets the bar. animate = false snaps it (first show, tests).
func set_value(v: float, max_v: float, animate: bool = true) -> void:
	max_value = maxf(max_v, 0.0001)
	var old := _shown
	value = clampf(v, 0.0, max_value)
	var r := ratio()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not animate or UI.instant or not is_inside_tree():
		_shown = r
		_lost = 0.0
		_edge = 0.0
	elif r < old - 0.0001:
		# a loss: the fill drops at once, the pale part waits and then drains
		_lost = maxf(_lost, old)
		_shown = r
		_tw = create_tween()
		_tw.tween_interval(HOLD)
		_tw.tween_method(_set_lost, _lost, r, DRAIN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	elif r > old + 0.0001:
		_lost = 0.0
		_edge = 1.0
		_tw = create_tween().set_parallel(true)
		_tw.tween_method(_set_shown, old, r, GAIN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.tween_method(_set_edge, 1.0, 0.0, GAIN + 0.2)
	set_process(pulse and is_low() and not UI.instant)
	queue_redraw()


func ratio() -> float:
	return clampf(value / maxf(max_value, 0.0001), 0.0, 1.0)


## True under 30% (an HP number beside it turns UI.C_LOW).
func is_low() -> bool:
	return ratio() < LOW and value > 0.0


func _set_lost(v: float) -> void:
	_lost = v
	queue_redraw()


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _set_edge(v: float) -> void:
	_edge = v
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 1.0:
		return
	var ci := get_canvas_item()
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.01, 0.012, 0.02, 0.85)
	well.set_corner_radius_all(int(ceilf(r.size.y * 0.5)))
	well.border_color = Color(UI.C_BRASS, 0.30)
	well.set_border_width_all(1)
	well.expand_margin_left = 1
	well.expand_margin_right = 1
	well.expand_margin_top = 1
	well.expand_margin_bottom = 1
	well.anti_aliasing = true
	well.draw(ci, r)
	if _lost > _shown:
		draw_rect(Rect2(Vector2(r.size.x * _shown, 0), Vector2(r.size.x * (_lost - _shown), r.size.y)), Color(1.0, 0.9, 0.7, 0.75))
	if _shown > 0.0:
		var f := Rect2(Vector2.ZERO, Vector2(maxf(r.size.x * _shown, 1.0), r.size.y))
		var a := col_a.lightened(0.15)
		var b := col_b
		if pulse and is_low() and not UI.instant:
			var k := 1.0 + 0.15 * sin(_t * TAU * 1.5)
			a = Color(a.r * k, a.g * k, a.b * k, a.a)
			b = Color(b.r * k, b.g * k, b.b * k, b.a)
		UI.rs_vgrad(ci, f, a, b)
		draw_line(Vector2(0.5, 0.5), Vector2(f.end.x - 0.5, 0.5), Color(1, 1, 1, 0.35), 0.5)
		if _edge > 0.0:
			draw_rect(Rect2(Vector2(f.end.x - 1.5, 0), Vector2(1.5, r.size.y)), Color(1, 0.97, 0.85, 0.8 * _edge))
	if caps:
		# brass end caps: two small lozenges
		UI.rs_lozenge(ci, Vector2(-3.0, r.size.y * 0.5), r.size.y * 0.5 + 1.5, UI.C_BRASS, 0.0)
		UI.rs_lozenge(ci, Vector2(r.size.x + 3.0, r.size.y * 0.5), r.size.y * 0.5 + 1.5, UI.C_BRASS, 0.0)
