extends Control
## CoinDisc: a small code-drawn gold coin (a plain geometric mark, not icon art).

const UI = preload("res://scripts/ui/theme.gd")

var radius := 5.0:
	set(v):
		radius = v
		custom_minimum_size = Vector2(v * 2.0 + 2.0, v * 2.0 + 2.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0 + 2.0, radius * 2.0 + 2.0)


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius + 0.8, Color(UI.C_INK, 0.85), true, -1.0, true)
	draw_circle(c, radius, Color(0.95, 0.75, 0.3), true, -1.0, true)
	draw_circle(c, radius * 0.64, Color(1.0, 0.88, 0.5), true, -1.0, true)
	draw_arc(c, radius * 0.64, PI * 0.9, PI * 1.6, 8, Color(1, 1, 1, 0.5), 0.8, true)
