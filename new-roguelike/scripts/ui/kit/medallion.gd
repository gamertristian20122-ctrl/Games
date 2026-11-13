extends Control
## Medallion: a round portrait coin (UI.medallion(sprite_id, radius, ring, active, tint)).
## The top of the sprite (the `_face` crop: side = min(w, h * 0.62) of the drawn part, shifted up 8%)
## as a textured circle (nearest filter), a 1.5 UI px ink rim, a 1 UI px ring in the side's colour
## (UI.C_STEEL your side, UI.C_FOE monsters). Active: a thicker ring, an outer gold ring and an
## ember glow. ko = true: dimmed with a thin red X. The control is (radius + 4) * 2 square, centred.

const UI = preload("res://scripts/ui/theme.gd")

var sprite_id := ""
var radius := 11.0
var ring := UI.C_STEEL
var active := false
var ko := false
var tint := Color.WHITE
var _tex: Texture2D
var _region := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(id: String, rad: float = 11.0, ring_colour: Color = UI.C_STEEL, is_active := false, tint_colour := Color.WHITE) -> void:
	radius = rad
	ring = ring_colour
	active = is_active
	tint = tint_colour
	set_sprite(id)
	custom_minimum_size = Vector2.ONE * (radius + 4.0) * 2.0
	queue_redraw()


func set_sprite(id: String) -> void:
	sprite_id = id
	_tex = null
	if id != "" and Art.has(id):
		_tex = Art.tex(id)
		var used := UI.used_rect(id)
		var side := minf(used.size.x, used.size.y * 0.62)
		_region = Rect2(used.position.x + (used.size.x - side) * 0.5, used.position.y - side * 0.08, side, side)
	queue_redraw()


func set_active(on: bool) -> void:
	active = on
	queue_redraw()


func set_ko(on: bool) -> void:
	ko = on
	queue_redraw()


func _draw() -> void:
	var at := size * 0.5
	if active:
		for i in 5:
			draw_circle(at, radius + 2.0 + i * 1.6, Color(UI.C_EMBER, 0.10 - i * 0.018), true, -1.0, true)
	draw_circle(at, radius + 1.5, Color(UI.C_INK, 0.95), true, -1.0, true)
	draw_circle(at, radius, Color(0.12, 0.13, 0.18), true, -1.0, true)
	if _tex != null:
		var full := _tex.get_size()
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var face := tint if not ko else Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, tint.a)
		for i in 32:
			var ang := TAU * i / 32.0
			var d := Vector2(cos(ang), sin(ang))
			pts.append(at + d * (radius - 0.5))
			uvs.append((_region.position + (d * 0.5 + Vector2(0.5, 0.5)) * _region.size) / full)
			cols.append(face)
		draw_polygon(pts, cols, uvs, _tex)
	draw_arc(at, radius, 0, TAU, 40, Color(ring, 0.5) if ko else ring, 1.6 if active else 1.0, true)
	if active:
		draw_arc(at, radius + 2.0, 0, TAU, 40, Color(UI.C_GOLD, 0.8), 1.0, true)
	if ko:
		var k := radius * 0.55
		draw_line(at + Vector2(-k, -k), at + Vector2(k, k), Color(UI.C_BAD, 0.9), 1.2, true)
		draw_line(at + Vector2(k, -k), at + Vector2(-k, k), Color(UI.C_BAD, 0.9), 1.2, true)
