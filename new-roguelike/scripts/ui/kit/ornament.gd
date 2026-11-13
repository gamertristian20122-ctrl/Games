extends Control
## Ornament: the lozenge (a small diamond with brass rules fading out each side) or a plain rule.
## Built by UI.lozenge() / UI.rule(). Centred in its rect.

const UI = preload("res://scripts/ui/theme.gd")

var kind := "lozenge"          ## "lozenge", "rule_both", "rule_right", "rule_left"
var half := 3.0                ## lozenge half size, or the rule's width
var colour := UI.C_BRASS
var rules := 20.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(what: String, half_size: float, col: Color, rule_len: float) -> void:
	kind = what
	half = half_size
	colour = col
	rules = rule_len
	if kind == "lozenge":
		custom_minimum_size = Vector2((half + 2.0 + rules) * 2.0, half * 2.0 + 1.0)
	else:
		custom_minimum_size = Vector2(half, 1.0)
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var mid := (size * 0.5).round()
	match kind:
		"lozenge":
			UI.rs_lozenge(ci, mid, half, colour, rules)
		"rule_right":
			UI.rs_rule(ci, Vector2(0, mid.y), Vector2(size.x, mid.y), Color(colour, 0.7), Color(colour, 0.0))
		"rule_left":
			UI.rs_rule(ci, Vector2(0, mid.y), Vector2(size.x, mid.y), Color(colour, 0.0), Color(colour, 0.7))
		_:
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2(0, mid.y), Vector2(mid.x, mid.y), Vector2(size.x, mid.y)]),
				PackedColorArray([Color(colour, 0.0), Color(colour, 0.6), Color(colour, 0.0)]), 1.0, true)
