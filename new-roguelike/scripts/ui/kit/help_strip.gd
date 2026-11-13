extends Control
## HelpStrip: "[Enter] Choose  [Esc] Back" at a corner of its parent, on a wash (UI.help_strip(pairs,
## corner)). pairs = [[kind, verb], ...]; kind = a UI.PROMPTS key or literal key text. corner:
## "bottom_right" (default), "top_right", "bottom_left", "bottom_center". Hidden on touch. Body 10
## (small), 12 UI px between pairs. set_pairs() changes the words (a screen's page changed).

const UI = preload("res://scripts/ui/theme.gd")
const Prompt = preload("res://scripts/ui/kit/prompt.gd")

var pairs: Array = []
var corner := "bottom_right"
var margin := Vector2(14, 10)
var _row: HBoxContainer
var _wash: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p: Array, where: String = "bottom_right") -> void:
	pairs = p
	corner = where
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	z_index = 5
	_wash = UI.wash("right" if corner == "bottom_left" else ("both" if corner == "bottom_center" else "left"), 0.6)
	add_child(_wash)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12 if not UI.is_phone() else 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	Controls.device_changed.connect(func(_t: bool) -> void: _place.call_deferred())
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_place)
	_rebuild()


func set_pairs(p: Array) -> void:
	pairs = p
	_rebuild()


func _rebuild() -> void:
	if _row == null:
		return
	for c in _row.get_children():
		c.queue_free()
	for pair: Variant in pairs:
		var a: Array = pair
		var pr: Control = Prompt.new()
		pr.call("setup", String(a[0]), String(a[1]) if a.size() > 1 else "")
		_row.add_child(pr)
	_place.call_deferred()


func _place() -> void:
	if not is_inside_tree() or _row == null:
		return
	visible = not Controls.using_touch and not pairs.is_empty()
	var host := get_parent() as Control
	var area := host.size if host != null else UI.screen_size(self)
	var w := _row.get_combined_minimum_size().x
	var h := UI.cap_h + 2.0
	var x := area.x - margin.x - w
	var y := area.y - margin.y - h
	match corner:
		"top_right":
			y = margin.y
		"bottom_left":
			x = margin.x
		"bottom_center":
			x = (area.x - w) * 0.5
	position = Vector2(roundf(x), roundf(y))
	size = Vector2(w, h)
	_row.position = Vector2.ZERO
	_row.size = size
	_wash.position = Vector2(-40, -3)
	_wash.size = Vector2(w + 54, h + 6)
	if corner == "bottom_left":
		_wash.position = Vector2(-14, -3)
	elif corner == "bottom_center":
		_wash.position = Vector2(-40, -3)
		_wash.size = Vector2(w + 80, h + 6)
