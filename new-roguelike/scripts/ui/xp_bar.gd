extends Control
## XP bar: "Lv 3" and a thin bar that fills toward the next level (scripts/data/rpg.gd).
## The HUD shows it under the coins in a level, the camp shows it above the quest list.
## It reads the numbers itself: when G.xp_changed fires and twice a second.

const UI = preload("res://scripts/ui/theme.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const W := 92.0
const H := 9.0
const BAR_H := 5.0

var _level := 0
var _frac := 0.0
var _shown := 0.0
var _picks := 0
var _t := 0.0
var _glow := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func _ready() -> void:
	G.xp_changed.connect(_read)
	G.level_up.connect(func(_l: int) -> void: _glow = 1.0)
	_read()
	_shown = _frac


func _read() -> void:
	var lvl := Rpg.level()
	var f := 1.0 if Rpg.at_max() else clampf(float(Rpg.xp()) / float(maxi(Rpg.xp_need(), 1)), 0.0, 1.0)
	if lvl != _level:
		_shown = 0.0 if lvl > _level and _level > 0 else f
	if lvl != _level or not is_equal_approx(f, _frac) or Rpg.picks() != _picks:
		_level = lvl
		_frac = f
		_picks = Rpg.picks()
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.5:
		_t = 0.0
		_read()
	if not is_equal_approx(_shown, _frac):
		_shown = move_toward(_shown, _frac, delta * 0.9)
		queue_redraw()
	if _glow > 0.0:
		_glow = maxf(_glow - delta * 0.8, 0.0)
		queue_redraw()


func _draw() -> void:
	var font := UI.font_body
	var text := "Lv %d" % _level
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_small).x
	var base := Vector2(1, H - 1.0)
	var col := UI.C_GOLD.lerp(Color.WHITE, _glow)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_small, 3, UI.C_INK)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_small, col)
	var x := roundf(tw + 5.0)
	var w := W - x
	var y := roundf((H - BAR_H) / 2.0) + 1.0
	draw_rect(Rect2(x + 1, y, w - 2, BAR_H), UI.C_INK)
	draw_rect(Rect2(x, y + 1, w, BAR_H - 2), UI.C_INK)
	draw_rect(Rect2(x + 1, y + 1, w - 2, BAR_H - 2), Color("1c2438"))
	var fill := roundf((w - 2.0) * _shown)
	if fill > 0.0:
		draw_rect(Rect2(x + 1, y + 1, fill, BAR_H - 2), UI.C_BLUE.lerp(Color.WHITE, _glow))
		draw_rect(Rect2(x + 1, y + 1, fill, 1), UI.C_ICE.lerp(Color.WHITE, _glow))
	if _picks > 0:
		# a level-up card is waiting to be chosen: a small gold mark at the end of the bar
		draw_rect(Rect2(x + w + 2, y, BAR_H, BAR_H), UI.C_INK)
		draw_rect(Rect2(x + w + 3, y + 1, BAR_H - 2, BAR_H - 2), UI.C_GOLD)
