extends Button
## Arrow: a button that shows a small pixel triangle instead of text (previous / next hero,
## minus / plus in Settings). The triangle is drawn from plain rectangles.

const UI = preload("res://scripts/ui/theme.gd")

## -1 points left, +1 points right.
var direction := 1
var arrow_size := 5


func _init() -> void:
	theme_type_variation = "Flat"
	custom_minimum_size = Vector2(22, 22)
	UI.juice(self)


func _draw() -> void:
	var colour := UI.C_FAINT if disabled else (UI.C_GOLD if is_hovered() or has_focus() or button_pressed else UI.C_BONE)
	var c := (size / 2.0).round()
	# a stack of 1 px columns, tallest at the back, a single pixel at the tip
	for i in arrow_size:
		var h := (arrow_size - i) * 2 - 1
		var x := c.x + direction * (i - arrow_size / 2.0)
		if direction < 0:
			x -= 1.0
		draw_rect(Rect2(roundf(x), c.y - (h - 1) / 2.0 - 0.5, 1, h), colour)
