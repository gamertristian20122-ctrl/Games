extends Control
## Hearts: the row of health hearts on the HUD. Health is counted in HALF hearts everywhere
## (6 = three full hearts). Red hearts come first, then armour hearts in blue.
## It only redraws when the numbers change.

const UI = preload("res://scripts/ui/theme.gd")

const STEP := 13        ## distance from one heart to the next (a heart is 13 x 12 px)
const ROW := 12

## Turns the pack's red heart blue for armour by swapping its red and blue (a tint, not new art).
const BLUE_SHADER := "shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.b, min(c.g * 0.9 + c.r * 0.25, 1.0), c.r, c.a);
}"

var hp := 0
var max_hp := 0
var armor := 0
var per_row := 10
var _armor_layer: Control
var _full: Texture2D
var _half: Texture2D
var _empty: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_full = Art.tex("ui_heart_full")
	_half = Art.tex("ui_heart_half")
	_empty = Art.tex("ui_heart_empty")
	_armor_layer = Control.new()
	_armor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_armor_layer.material = mat
	_armor_layer.draw.connect(_draw_armor)
	add_child(_armor_layer)


## Returns true when something changed.
func set_values(new_hp: int, new_max: int, new_armor: int) -> bool:
	new_max = maxi(new_max, 0)
	new_hp = clampi(new_hp, 0, new_max)
	new_armor = maxi(new_armor, 0)
	if new_hp == hp and new_max == max_hp and new_armor == armor:
		return false
	hp = new_hp
	max_hp = new_max
	armor = new_armor
	var n := _containers() + _armor_hearts()
	var rows := maxi(ceili(n / float(per_row)), 1)
	size = Vector2(mini(n, per_row) * STEP, rows * ROW)
	queue_redraw()
	if _armor_layer != null:
		_armor_layer.queue_redraw()
	return true


func _containers() -> int:
	return ceili(max_hp / 2.0)


func _armor_hearts() -> int:
	return ceili(armor / 2.0)


func _slot(i: int) -> Vector2:
	return Vector2((i % per_row) * STEP, (i / per_row) * ROW)


func _draw() -> void:
	for i in _containers():
		var v := clampi(hp - i * 2, 0, 2)
		draw_texture(_full if v == 2 else (_half if v == 1 else _empty), _slot(i))


func _draw_armor() -> void:
	var first := _containers()
	for i in _armor_hearts():
		var v := clampi(armor - i * 2, 0, 2)
		_armor_layer.draw_texture(_full if v == 2 else _half, _slot(first + i))
