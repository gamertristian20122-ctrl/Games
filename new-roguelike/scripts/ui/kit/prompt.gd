extends Control
## Prompt: a key prompt (UI.prompt(kind, verb)). Keyboard: a parchment key cap with the key.
## Gamepad: a round parchment cap with the face letter (a pill for longer names). No platform colours
## or logos. Touch: nothing (the control hides). Updates live when the device changes.
## kind = a key of UI.PROMPTS ("confirm", "back", "talk", "knight", "pause", "fast", "page", "target")
## or any literal key text ("Tab"). verb = the word drawn after the cap ("" = cap only).

const UI = preload("res://scripts/ui/theme.gd")

var kind := "confirm"
var verb := ""
## Text after the cap is outlined (for prompts straight on the world).
var outlined := true
var verb_colour := UI.C_PARCH
var verb_size := 0          ## 0 = UI.size_small
var _cap := ""
var _round := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(what: String, word: String = "") -> void:
	kind = what
	verb = word
	_refresh()


func _ready() -> void:
	Controls.device_changed.connect(_on_device)
	_refresh()


func _on_device(_touch: bool) -> void:
	_refresh()


## The text on the cap for this kind and device.
static func cap_text(what: String, pad: bool) -> String:
	if UI.PROMPTS.has(what):
		var row: Dictionary = UI.PROMPTS[what]
		return String(row["pad"] if pad else row["key"])
	return what


func _refresh() -> void:
	var pad := bool(Controls.get("last_pad"))
	_cap = cap_text(kind, pad)
	_round = pad and _cap.length() <= 1
	visible = not Controls.using_touch
	custom_minimum_size = Vector2(_width(), 14.0)
	size = custom_minimum_size
	queue_redraw()


func _vs() -> int:
	return verb_size if verb_size > 0 else UI.size_small


func cap_width() -> float:
	UI._load_fonts()
	var tw := UI.font_num.get_string_size(_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_key).x
	if _round:
		return 13.0
	return maxf(tw + 7.0, 12.0)


func _width() -> float:
	var w := cap_width()
	if verb != "":
		w += 4.0 + UI.font_body.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, _vs()).x
	return ceilf(w)


func _draw() -> void:
	draw_cap(self, Vector2(0, (size.y - 12.0) * 0.5), _cap, _round)
	if verb != "":
		var x := cap_width() + 4.0
		var base := Vector2(x, roundf(size.y * 0.5 + UI.font_body.get_ascent(_vs()) * 0.5 - 1.0))
		if outlined:
			draw_string_outline(UI.font_body, base, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, _vs(), 3, Color(UI.C_INK, 0.85))
		draw_string(UI.font_body, base, verb, HORIZONTAL_ALIGNMENT_LEFT, -1, _vs(), verb_colour)


## Draws one cap with its top-left at `at` (12 UI px tall). Returns its width.
static func draw_cap(c: CanvasItem, at: Vector2, text: String, round_cap: bool) -> float:
	UI._load_fonts()
	var ks := UI.size_key
	var tw := UI.font_num.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x
	var w := 13.0 if round_cap else maxf(tw + 7.0, 12.0)
	var r := Rect2(at, Vector2(w, 12.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.88, 0.80, 0.92)
	sb.set_corner_radius_all(7 if round_cap else 3)
	sb.border_color = Color(0.3, 0.26, 0.2)
	sb.border_width_bottom = 2
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)
	var base := Vector2(r.position.x, roundf(r.position.y + 6.0 + UI.font_num.get_ascent(ks) * 0.5 - 1.5))
	c.draw_string(UI.font_num, base, text, HORIZONTAL_ALIGNMENT_CENTER, w, ks, UI.C_INK)
	return w
