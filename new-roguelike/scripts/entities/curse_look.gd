extends Node2D
## How the Hungry Curse LOOKS (its rules and numbers are in scripts/entities/curse.gd).
## This node lives inside a small picture exactly as big as the room's floor (272 x 112, one
## pixel = one game pixel). Everything here is drawn with whole pixels and hard edges, and the
## finished picture lies on the floor under every sprite, so the Curse is as chunky as the art.
##
## What the player must be able to read at a glance:
##   a flat black DISC with a thin pale-gold RIM       rim lit = it bites,  rim dark = safe
##   a brighter, thicker arc growing clockwise         the lunge timer
##   two pale EYE pixels                               they look at the hero (shut while it is safe)
##   TEETH on the rim                                  from Curse Level 3 (a bite is a full heart)
##   a pale hatched STRIPE                             where it is about to lunge
##   a small number inside                             the coins in its belly
## It is never a pit: pits are square brown-edged tiles in the room's own dim light, the Curse is a
## bigger, perfectly round, moving disc whose rim is drawn at full brightness on every floor.

const UI = preload("res://scripts/ui/theme.gd")

# ------------------------------------------------------------------ colours
const C_VOID := Color(0.02, 0.02, 0.03)          ## the disc
const C_RIM := Color(0.98, 0.90, 0.58)           ## pale gold: used by nothing else in the game
const C_RIM_HOT := Color(1.0, 1.0, 0.92)         ## the lunge timer and the lock flash
const C_RIM_DARK := Color(0.33, 0.30, 0.27)      ## safe: rising, sated, stunned
const C_EYE := Color(1.0, 0.97, 0.80)
const C_BELLY := Color(0.80, 0.68, 0.34)         ## the belly number
const C_BELLY_FULL := Color(1.0, 0.87, 0.35)
const C_STRIPE := Color(0.98, 0.93, 0.70)
const C_FLASH := Color(1.0, 1.0, 1.0)

const HATCH_GAP := 9.0                           ## px between two hatch marks on the stripe
const HATCH_SPEED := 70.0                        ## px/s the hatching runs toward the wall
const TEETH_AT_3 := 9                            ## how many teeth at Curse Level 3 (two more per level)

var curse: Node2D
static var _shapes := {}


func _process(_delta: float) -> void:
	queue_redraw()


## The pixels of a disc `r` pixels in radius: "spans" = [row, half width, ...] for the fill and
## "rim" = its 1 px outline, sorted clockwise starting at the top (so the timer can fill it).
static func shape(r: int) -> Dictionary:
	if _shapes.has(r):
		return _shapes[r]
	var spans := PackedInt32Array()
	var inside := {}
	for y in range(-r, r):
		var hw := 0
		for x in range(0, r):
			if (x + 0.5) * (x + 0.5) + (y + 0.5) * (y + 0.5) <= float(r * r):
				hw = x + 1
		if hw > 0:
			spans.append(y)
			spans.append(hw)
			for x in range(-hw, hw):
				inside[Vector2i(x, y)] = true
	var rim: Array = []
	for cell: Vector2i in inside:
		if not (inside.has(cell + Vector2i(1, 0)) and inside.has(cell + Vector2i(-1, 0)) and inside.has(cell + Vector2i(0, 1)) and inside.has(cell + Vector2i(0, -1))):
			rim.append(cell)
	rim.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _clock(a) < _clock(b))
	var out := {"spans": spans, "rim": rim}
	_shapes[r] = out
	return out


## Angle of a pixel around the middle: 0 at the top, growing clockwise.
static func _clock(cell: Vector2i) -> float:
	return fposmod(atan2(cell.x + 0.5, -(cell.y + 0.5)), TAU)


func _draw() -> void:
	var c := curse
	if c == null or not is_instance_valid(c) or c.state == c.WAIT:
		return
	var state: int = c.state
	var full := int(round(c.radius))
	var r := full
	if state == c.RISING:
		r = int(round(c.radius * (1.0 - clampf(c.t / c.RISE_TIME, 0.0, 1.0))))
	elif state == c.SINKING:
		r = int(round(c.radius * clampf(c.t / c.SINK_TIME, 0.0, 1.0)))
	elif c.gulp > 0.09:
		r += 1                                   # a quick swell when it swallows
	if r < 2:
		return
	var mid := Vector2(roundf(c.position.x), roundf(c.position.y))
	var lit: bool = c.lit()
	if c.stripe_on():
		_draw_stripe(c, mid, float(full))
	# ---- the disc
	var sh := shape(r)
	var spans: PackedInt32Array = sh["spans"]
	for i in range(0, spans.size(), 2):
		draw_rect(Rect2(mid.x - spans[i + 1], mid.y + spans[i], spans[i + 1] * 2, 1), C_VOID)
	# ---- the rim: lit or dark, with the lunge timer as a brighter, thicker arc
	var rim: Array = sh["rim"]
	var base := C_RIM if lit else C_RIM_DARK
	var hot := 0.0
	if state == c.CREEP:
		hot = c.fill
	elif c.stripe_on():
		hot = 1.0
	var hot_col := C_RIM_HOT
	if state == c.LOCK and fmod(c.t * 14.0, 1.0) < 0.5:
		hot_col = C_RIM                          # the whole rim blinks while the stripe is locked
	var hot_n := int(round(hot * rim.size()))
	for i in rim.size():
		var cell: Vector2i = rim[i]
		draw_rect(Rect2(mid.x + cell.x, mid.y + cell.y, 1, 1), hot_col if i < hot_n else base)
	if hot > 0.0 and r > 4:
		var inner: Array = shape(r - 1)["rim"]
		var inner_n := int(round(hot * inner.size()))
		for i in inner_n:
			var cell2: Vector2i = inner[i]
			draw_rect(Rect2(mid.x + cell2.x, mid.y + cell2.y, 1, 1), hot_col)
	if r < full - 1:
		return                                   # still rising or sinking: no face yet
	if c.level >= c.TEETH_LEVEL:
		_draw_teeth(mid, r, c.level, (hot_col if hot >= 1.0 else C_RIM) if lit else C_RIM_DARK)
	_draw_face(c, mid, r, lit)


## Small pointed teeth just inside the rim.
func _draw_teeth(mid: Vector2, r: int, level: int, col: Color) -> void:
	var n := TEETH_AT_3 + 2 * (level - 3)
	for k in n:
		var a := TAU * (float(k) + 0.5) / float(n)
		var out := Vector2(sin(a), -cos(a))
		var side := Vector2(-out.y, out.x)
		var root := mid + out * (r - 1.6)
		for p: Vector2 in [root, root + side, root - side, mid + out * (r - 2.6), mid + out * (r - 3.6)]:
			draw_rect(Rect2(floorf(p.x), floorf(p.y), 1, 1), col)


func _draw_face(c: Node2D, mid: Vector2, r: int, lit: bool) -> void:
	var look: Vector2 = c.aim_dir
	if c.state == c.CREEP or c.state == c.WINDED or c.state == c.SATED or c.state == c.STUNNED:
		var to: Vector2 = c.player.position - c.position
		if to.length() > 0.5:
			look = to.normalized()
	var gap: int = 2 + int(c.level) / 2
	var eyes := mid + look * (r * 0.42)
	var ex := roundf(eyes.x)
	var ey := roundf(eyes.y)
	if c.state == c.STUNNED:
		# dizzy: no eyes, three specks circling
		for k in 3:
			var a: float = c.age * 5.0 + TAU * float(k) / 3.0
			var p := mid + Vector2(cos(a), sin(a) * 0.6) * (r * 0.5)
			draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), C_RIM_DARK.lightened(0.3))
	elif not lit or c.gulp > 0.0:
		# shut: two flat dashes (sated, or blinking as it swallows)
		var shut := C_RIM_DARK.lightened(0.25) if not lit else C_EYE
		draw_rect(Rect2(ex - gap - 1, ey, 2, 1), shut)
		draw_rect(Rect2(ex + gap - 1, ey, 2, 1), shut)
	else:
		# open: two upright slits
		draw_rect(Rect2(ex - gap, ey - 1, 1, 2), C_EYE)
		draw_rect(Rect2(ex + gap - 1, ey - 1, 1, 2), C_EYE)
	# ---- the belly: how many coins are inside (behind the eyes, so the two never overlap)
	var belly: int = c.run.belly
	if belly <= 0:
		return
	var font: Font = UI.font_body if UI.font_body != null else c.run.font()
	var size: int = UI.size_body if UI.font_body != null else 8
	var text := str(belly)
	var full: bool = belly >= c.belly_cap(c.run)
	var col := C_BELLY_FULL if full else C_BELLY
	if not lit:
		col = col.darkened(0.25)
	if c.belly_pop > 0.0 or (full and fmod(c.age * 2.0, 1.0) < 0.5):
		col = C_RIM_HOT if c.belly_pop > 0.0 else C_BELLY_FULL.lightened(0.35)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var at := mid - look * (r * 0.34)
	var pop := 1.0 if c.belly_pop > 0.15 else 0.0
	draw_string(font, Vector2(roundf(at.x - ts.x * 0.5), roundf(at.y + ts.y * 0.30 - pop)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The stripe: a pale band as wide as the disc, from the disc to the wall, with hatch marks that
## run the way the lunge will go. It flashes white at the moment it locks.
func _draw_stripe(c: Node2D, mid: Vector2, r: float) -> void:
	var dir: Vector2 = c.aim_dir
	var side := dir.orthogonal() * r
	var length := 340.0
	var far := mid + dir * length
	var fill_a := 0.10
	var line_a := 0.55
	var col := C_STRIPE
	if c.state == c.LOCK:
		var k: float = 1.0 - clampf(c.t / c.LOCK_TIME, 0.0, 1.0)
		if k < 0.22:
			col = C_FLASH
			fill_a = 0.70
			line_a = 1.0
		else:
			var blink := fmod(k * 9.0, 1.0) < 0.5
			fill_a = 0.34 if blink else 0.20
			line_a = 1.0 if blink else 0.75
	elif c.state == c.LUNGE:
		fill_a = 0.22
		line_a = 0.85
	draw_colored_polygon(PackedVector2Array([mid + side, far + side, far - side, mid - side]), Color(col.r, col.g, col.b, fill_a))
	var line := Color(col.r, col.g, col.b, line_a)
	draw_line(mid + side, far + side, line, -1.0)
	draw_line(mid - side, far - side, line, -1.0)
	# hatch marks: arrow heads marching toward the wall
	var s := fmod(c.age * HATCH_SPEED, HATCH_GAP)
	var tip := r * 0.75
	while s < length:
		var at := mid + dir * s
		draw_line(at + side, at + dir * tip, line, -1.0)
		draw_line(at - side, at + dir * tip, line, -1.0)
		s += HATCH_GAP
