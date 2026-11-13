extends Control
## Wash: a soft dark gradient behind text that sits straight on the world (no box).
## fade_to: "right" (dark on the left, fading out to the right), "left", "both" (dark band in the
## middle fading out to both sides), "up", "down". Size it like any Control.

const UI = preload("res://scripts/ui/theme.gd")

var fade_to := "right":
	set(v):
		fade_to = v
		queue_redraw()
var alpha := 0.72:
	set(v):
		alpha = v
		queue_redraw()
var colour := UI.C_WASH


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var dark := Color(colour, alpha)
	var none := Color(colour, 0.0)
	var r := Rect2(Vector2.ZERO, size)
	match fade_to:
		"left":
			UI.rs_hgrad(ci, r, none, dark)
		"both":
			var half := Rect2(Vector2.ZERO, Vector2(size.x * 0.5, size.y))
			UI.rs_hgrad(ci, half, none, dark)
			UI.rs_hgrad(ci, Rect2(Vector2(size.x * 0.5, 0), half.size), dark, none)
		"up":
			UI.rs_vgrad(ci, r, none, dark)
		"down":
			UI.rs_vgrad(ci, r, dark, none)
		_:
			UI.rs_hgrad(ci, r, dark, none)
