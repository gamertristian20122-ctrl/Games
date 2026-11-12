extends Control
## Curse meter: the Hungry Curse on the HUD, next to the coin, key and bomb counters.
##   five skull sockets = the Curse Level (0 to 5). A lit socket is the pack's skull in the
##                        Curse's pale gold; from the third on they glow red, because from Level 3
##                        the Curse's bite costs a full heart.
##   a small black disc and "3/5" = the coins in the Curse's belly and how many it can hold
##                        (the number turns gold when it is full: time for a bomb).
## hud.gd calls set_values() whenever something changed; the changed part pops for a moment.

const UI = preload("res://scripts/ui/theme.gd")

const SOCKETS := 5
const HOT_FROM := 3                       ## sockets from this one on are drawn "hot"
const C_LIT := Color(0.98, 0.90, 0.58)    ## the Curse's pale gold (the same as its rim)
const C_HOT := Color(1.0, 0.52, 0.40)
const C_EMPTY := Color(0.24, 0.23, 0.30)
const C_SOCKET := Color(0.055, 0.05, 0.07, 0.92)   ## the dark slot behind every skull
const C_DISC := Color(0.02, 0.02, 0.03)
const GAP := 3                            ## px between the skulls and the belly
const DISC := 4                           ## radius of the little belly disc

var level := 0
var belly := 0
var cap := 5
var _skull: Texture2D
var _region := Rect2()
var _pop_level := 0.0
var _pop_belly := 0.0
var _text_w := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_skull = Art.tex("skull")
	_region = UI.used_rect("skull")
	_measure()
	set_process(false)


func _step() -> float:
	return _region.size.x + 3.0


func _measure() -> void:
	_text_w = UI.font_body.get_string_size("%d/%d" % [belly, cap], HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body).x if UI.font_body != null else 20.0
	custom_minimum_size = Vector2(SOCKETS * _step() + GAP + DISC * 2 + 2 + _text_w, maxf(_region.size.y + 2.0, 9.0))
	queue_redraw()


func set_values(new_level: int, new_belly: int, new_cap: int) -> void:
	if new_level == level and new_belly == belly and new_cap == cap:
		return
	if new_level != level:
		_pop_level = 0.3
	if new_belly != belly:
		_pop_belly = 0.25
	level = new_level
	belly = new_belly
	cap = maxi(new_cap, 1)
	if _skull != null:
		_measure()
	set_process(not UI.instant)


func _process(delta: float) -> void:
	_pop_level = maxf(0.0, _pop_level - delta)
	_pop_belly = maxf(0.0, _pop_belly - delta)
	queue_redraw()
	if _pop_level <= 0.0 and _pop_belly <= 0.0:
		set_process(false)


func _draw() -> void:
	if _skull == null:
		return
	var mid := roundf(size.y / 2.0)
	var y := mid - roundf(_region.size.y / 2.0)
	for i in SOCKETS:
		var col := C_EMPTY
		var lift := 0.0
		if i < level:
			col = C_HOT if i >= HOT_FROM - 1 else C_LIT
			if _pop_level > 0.0 and i == level - 1:
				col = Color.WHITE
				lift = 1.0
		var sx := i * _step()
		draw_rect(Rect2(sx, y - 1.0, _region.size.x + 2.0, _region.size.y + 2.0), C_SOCKET)
		draw_texture_rect_region(_skull, Rect2(Vector2(sx + 1.0, y - lift), _region.size), _region, col)
	# ---- the belly: a tiny disc with a pale rim, then "coins/room"
	var x := SOCKETS * _step() + GAP
	var full := belly >= cap
	var rim := C_LIT if not full else Color(1.0, 0.87, 0.35)
	if _pop_belly > 0.0:
		rim = Color.WHITE
	for row in range(-DISC, DISC):
		var half := 0
		for k in DISC:
			if (k + 0.5) * (k + 0.5) + (row + 0.5) * (row + 0.5) <= float(DISC * DISC):
				half = k + 1
		draw_rect(Rect2(x + DISC - half, mid + row, half * 2, 1), rim)
		if half > 1 and row > -DISC and row < DISC - 1:
			draw_rect(Rect2(x + DISC - half + 1, mid + row, half * 2 - 2, 1), C_DISC)
	if UI.font_body == null:
		return
	var text := "%d/%d" % [belly, cap]
	var tp := Vector2(x + DISC * 2 + 2, mid + roundf(UI.size_body * 0.36) - (1.0 if _pop_belly > 0.12 else 0.0))
	draw_string_outline(UI.font_body, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, 3, Color(UI.C_INK, 0.9))
	draw_string(UI.font_body, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.size_body, UI.C_GOLD if full else UI.C_BONE)
