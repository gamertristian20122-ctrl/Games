extends RefCounted
## DAMAGE NUMBERS that POP and ARC (battles). A number bursts out of the one hit at twice its size,
## snaps to size, flies off in a little arc away from the blow (thrown up, then falling) and fades.
## A critical blow is bigger, gold, shakes, and carries a small "CRITICAL" over it. A healing number
## rises straight up in green. A combo keeps ONE number that counts up with every blow of it
## (`bump`), so the last figure is exactly what the fight took off.
##   var l := Num.pop(root, at_on_screen, "24", colour, {"dir": 1.0, "crit": true})
##   Num.bump(l, "48")

const UI = preload("res://scripts/ui/theme.gd")


static func pop(root: Control, at: Vector2, text: String, colour: Color, opts: Dictionary = {}) -> Label:
	var crit := bool(opts.get("crit", false))
	var heal := bool(opts.get("heal", false))
	var word := bool(opts.get("word", false))          # "Miss", "Guard", "Stunned": smaller, no arc
	var dir := float(opts.get("dir", 1.0))
	var l := UI.label(text, "Head")
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", UI.C_INK)
	l.add_theme_constant_override("outline_size", 5 if crit else 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var sz := l.get_minimum_size()
	l.pivot_offset = sz * 0.5
	l.position = (at - Vector2(sz.x * 0.5, sz.y)).round()
	var big := (1.45 if crit else (1.0 if not word else 0.8)) * float(opts.get("size", 1.0))
	l.scale = Vector2.ONE * big * 2.1
	l.set_meta("big", big)
	if crit:
		var tag := UI.label("CRITICAL", "Small")
		tag.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		tag.add_theme_color_override("font_outline_color", UI.C_INK)
		tag.add_theme_constant_override("outline_size", 3)
		tag.position = Vector2((sz.x - tag.get_minimum_size().x) * 0.5, -9.0)
		l.add_child(tag)
	var start := l.position
	var life := 0.95 if not word else 0.8
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * big, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# (a combo's number waits where it popped while the blows land, then flies)
	var hold := float(opts.get("hold", 0.0))
	if hold > 0.0:
		tw.tween_interval(hold)
	else:
		tw.parallel()
	if heal or word:
		tw.tween_property(l, "position:y", start.y - 26.0, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# the arc: thrown up and away from the blow, then falling a little (t from 0 to 1)
		var side := dir * randf_range(14.0, 24.0)
		var up := 30.0 if crit else 24.0
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(l):
				l.position = start + Vector2(side * t, -up * 4.0 * t * (1.0 - t * 0.62) + 2.0 * t), 0.0, 1.0, life).set_trans(Tween.TRANS_LINEAR)
	if crit:
		# a crit shakes for a moment as it lands
		tw.parallel().tween_method(func(t: float) -> void:
			if is_instance_valid(l):
				l.rotation = sin(t * 40.0) * 0.12 * (1.0 - t), 0.0, 1.0, 0.35)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.28).set_delay(life - 0.28)
	tw.tween_callback(l.queue_free)
	return l


## A combo's number counts up: new text, and a quick pop again.
static func bump(l: Label, text: String, colour: Color = Color(0, 0, 0, 0)) -> void:
	if l == null or not is_instance_valid(l):
		return
	l.text = text
	if colour.a > 0.0:
		l.add_theme_color_override("font_color", colour)
	l.pivot_offset = l.get_minimum_size() * 0.5
	var big := float(l.get_meta("big", 1.0))
	l.scale = Vector2.ONE * big * 1.7
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * big, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
