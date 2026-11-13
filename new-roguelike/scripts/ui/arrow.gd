extends Button
## Arrow: a button that shows a small chevron instead of text (previous / next hero, minus / plus in
## Settings, "< Normal >" choices). Parchment normally, gold when focused or hovered, faint when
## disabled. The chevron is a code-drawn mark (two smooth strokes on an ink under-stroke).

const UI = preload("res://scripts/ui/theme.gd")

## -1 points left, +1 points right.
var direction := 1
## Half the chevron's height in UI px.
var arrow_size := 4


func _init() -> void:
	theme_type_variation = "Flat"
	custom_minimum_size = Vector2(18, 18) if not UI.is_phone() else Vector2(22, 22)
	UI.juice(self)
	set_meta("no_flame", true)          # the chevron lights up itself; no flame beside it
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var lit := not disabled and (is_hovered() or has_focus() or button_pressed)
	var colour := UI.C_FAINT if disabled else (UI.C_GOLD if lit else UI.C_PARCH)
	var c := size / 2.0
	var s := float(arrow_size)
	var d := float(direction)
	var pts := PackedVector2Array([c + Vector2(-d * s * 0.5, -s), c + Vector2(d * s * 0.5, 0), c + Vector2(-d * s * 0.5, s)])
	draw_polyline(pts, Color(UI.C_INK, 0.8), 3.2, true)
	draw_polyline(pts, colour, 1.6, true)
	if lit:
		draw_circle(c + Vector2(d * s * 0.5, 0), 1.0, Color(UI.C_EMBER, 0.8), true, -1.0, true)
