extends Control
## Icon: shows one sprite from the art pack inside a fixed-size cell, centred, with the empty
## space around the drawing trimmed off. Used for item icons everywhere (HUD, cards, pause,
## collection, end screen) and for the coin and bomb counters.
##   var ic = Icon.new(); ic.setup("icon_whetstone", Vector2(16, 16))
## Sprites are only ever drawn at whole sizes (1x, 2x, 3x) or exactly half, so pixels stay square.

const UI = preload("res://scripts/ui/theme.gd")

var id := ""
var cell := Vector2(12, 12)
## Tall, thin sprites (swords, staffs) lie on their side so a row of icons can stay low.
var lay_flat := false
## Unknown things are drawn as a black shape.
var silhouette := false
var max_scale := 1.0
var animated := false

var _tex: Texture2D
var _frames: SpriteFrames
var _region := Rect2()
var _scale := 1.0
var _rotated := false
var _time := 0.0
var _frame := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(animated)


## flat_row_height > 0 means "this icon sits in a low row": tall sprites are turned on their
## side and the cell becomes as wide as the sprite needs.
func setup(sprite_id: String, cell_size: Vector2, flat_row_height: float = 0.0, biggest_scale: float = 1.0) -> void:
	id = sprite_id
	max_scale = biggest_scale
	_tex = Art.tex(id)
	_region = UI.used_rect(id)
	_rotated = false
	var want := _region.size
	if flat_row_height > 0.0:
		lay_flat = true
		if want.y > flat_row_height and want.y > want.x:
			_rotated = true
			want = Vector2(want.y, want.x)
		cell_size = Vector2(maxf(want.x, 6.0), flat_row_height)
	cell = cell_size
	_scale = 0.5
	for s: float in [4.0, 3.0, 2.0, 1.0, 0.5]:
		if s <= max_scale and want.x * s <= cell.x and want.y * s <= cell.y:
			_scale = s
			break
	if want.x * _scale > cell.x or want.y * _scale > cell.y:
		_scale = minf(cell.x / want.x, cell.y / want.y)
	custom_minimum_size = cell
	size = cell
	queue_redraw()


## Plays the sprite's animation (the spinning coin, the fizzing bomb).
func animate(on: bool = true) -> void:
	_frames = Art.frames(id) if on else null
	animated = _frames != null and _frames.get_frame_count("default") > 1
	set_process(animated)


func _process(delta: float) -> void:
	_time += delta
	var n := _frames.get_frame_count("default")
	var f := int(_time * 8.0) % n
	if f != _frame:
		_frame = f
		_tex = _frames.get_frame_texture("default", f)
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var want := Vector2(_region.size.y, _region.size.x) if _rotated else _region.size
	var top_left := ((size - want * _scale) / 2.0).round()
	var colour := Color.BLACK if silhouette else Color.WHITE
	if _rotated:
		draw_set_transform(top_left + Vector2(want.x * _scale, 0), PI / 2.0, Vector2(_scale, _scale))
	else:
		draw_set_transform(top_left, 0.0, Vector2(_scale, _scale))
	draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, _region.size), _region, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
