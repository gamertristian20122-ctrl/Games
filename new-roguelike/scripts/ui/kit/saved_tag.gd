extends Control
## SavedTag: a small brass lozenge with the word "Saved" in the bottom left corner for a moment,
## whenever the game was written to the disk (Save.flushed). It shows at most once every GAP
## seconds, so a busy stretch of play does not blink at the player; it never takes the focus or a
## click. main.gd adds one to the fade layer and says when it may show (`allowed`: only while a
## place or a battle is on screen, never over the title).
## All of it is drawn by code (a lozenge, a hairline, the word); no art.

const UI = preload("res://scripts/ui/theme.gd")

const WORD := "Saved"
const SHOW := 1.2            ## seconds it stays
const FADE := 0.25           ## seconds it takes to come and to go
const GAP := 20.0            ## at most one every this many seconds

## main.gd: a Callable that returns true while the tag may show.
var allowed: Callable
var _left := 0.0             ## seconds it still shows
var _last := -1000.0         ## when it showed last (seconds since the game started)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	Save.flushed.connect(_on_flushed)
	var ph := UI.is_phone()
	custom_minimum_size = Vector2(52, 14) if not ph else Vector2(44, 12)
	size = custom_minimum_size
	# above the help strip's line, clear of a phone's rounded corner
	var cut := UI.safe_insets(self) if is_inside_tree() else Vector4.ZERO
	offset_left = 8.0 + cut.x
	offset_right = offset_left + custom_minimum_size.x
	offset_bottom = -8.0 - cut.w
	offset_top = offset_bottom - custom_minimum_size.y
	set_process(false)


func _on_flushed() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last < GAP or (allowed.is_valid() and not bool(allowed.call())):
		return
	show_now()


## Shows it at once (the test tour uses this too).
func show_now() -> void:
	_last = Time.get_ticks_msec() / 1000.0
	_left = SHOW
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	# real seconds: a battle's hit-stop or a test's speed-up must not stretch or cut it
	var real := delta / maxf(Engine.time_scale, 0.05)
	_left -= real
	var a := clampf(minf((SHOW - _left) / FADE, _left / FADE), 0.0, 1.0)
	modulate.a = 1.0 if UI.instant and _left > 0.0 else a
	if _left <= 0.0:
		visible = false
		set_process(false)


func _draw() -> void:
	var ci := get_canvas_item()
	var mid := roundf(size.y * 0.5)
	# a soft dark plate so the word reads on any ground
	draw_rect(Rect2(Vector2(-3, 0), size + Vector2(6, 0)), Color(UI.C_WASH, 0.55))
	UI.rs_rule(ci, Vector2(-3, 0.5), Vector2(size.x + 3.0, 0.5), Color(UI.C_BRASS, 0.7), Color(UI.C_BRASS, 0.0))
	UI.rs_rule(ci, Vector2(-3, size.y - 0.5), Vector2(size.x + 3.0, size.y - 0.5), Color(UI.C_BRASS, 0.7), Color(UI.C_BRASS, 0.0))
	UI.rs_lozenge(ci, Vector2(5.0, mid), 3.0, UI.C_BRASS, 0.0)
	var font := UI.font_body
	var fs := UI.size_small
	var base := Vector2(13.0, roundf(mid + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.5))
	draw_string_outline(font, base, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(UI.C_INK, 0.9))
	draw_string(font, base, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.C_GOLD)
