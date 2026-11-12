extends Control
## Pips: a row of small squares, some of them filled in. Used for the hero stats on the
## hero-select screen and for the volume steps in Settings.

const UI = preload("res://scripts/ui/theme.gd")

const PIP := 6       ## size of one square
const STEP := 7      ## distance from one square to the next

var total := 5
var filled := 0
var colour := UI.C_GOLD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(filled_count: int, total_count: int = 5, pip_colour: Color = UI.C_GOLD) -> void:
	total = total_count
	filled = clampi(filled_count, 0, total_count)
	colour = pip_colour
	custom_minimum_size = Vector2(total * STEP - 1, PIP)
	queue_redraw()


func _draw() -> void:
	var y := roundf((size.y - PIP) / 2.0)
	for i in total:
		var x := float(i * STEP)
		draw_rect(Rect2(x, y, PIP, PIP), UI.C_INK)
		if i < filled:
			draw_rect(Rect2(x + 1, y + 1, PIP - 2, PIP - 2), colour)
			draw_rect(Rect2(x + 1, y + 1, PIP - 2, 1), colour.lightened(0.35))
		else:
			draw_rect(Rect2(x + 1, y + 1, PIP - 2, PIP - 2), Color("2c313d"))
