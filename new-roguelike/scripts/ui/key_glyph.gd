extends Control
## Key glyph: a plain geometric stand-in for the key counter (a ring and a bar), because the
## art pack has no key sprite. It is only ever created by UI.hud_icon("key") in theme.gd,
## so a real key icon can replace it by changing that one function.

const UI = preload("res://scripts/ui/theme.gd")

# x, y, w, h of each gold rectangle, in a 10 x 9 box
const PARTS := [
	[1, 2, 3, 1], [1, 6, 3, 1], [0, 3, 1, 3], [4, 3, 1, 3],   # the ring
	[5, 4, 5, 1],                                             # the bar
	[7, 5, 1, 2], [9, 5, 1, 2],                               # two teeth
]


func _init() -> void:
	custom_minimum_size = Vector2(10, 9)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var o := ((size - Vector2(10, 9)) / 2.0).round()
	for p: Array in PARTS:
		draw_rect(Rect2(o.x + p[0] - 1, o.y + p[1] - 1, p[2] + 2, p[3] + 2), UI.C_INK)
	for p: Array in PARTS:
		draw_rect(Rect2(o.x + p[0], o.y + p[1], p[2], p[3]), UI.C_GOLD)
