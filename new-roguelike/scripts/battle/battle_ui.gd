extends RefCounted
## THE BATTLE'S INTERFACE PIECES in the Lantern Glass look (the HD GUI, spec 6.1). battle.gd builds
## and moves them; nothing here knows the rules. All sizes are UI px (UI.attach grid): PC about
## 800 x 360 or 640 x 360, the phone the game's own 400 x 180.
##   Card     one fighter of your side: a glass card along the bottom (PC) or a thin strip at the
##            top right (phone). Coin, name, level, HP and MP with numbers. Lifts and glows gold
##            while acting or aimed at, shakes and flashes its HP red when hit, dims when down.
##            Its `button` (invisible, the whole card) is what a heal's target is picked with.
##   Rail     the turn order: portrait coins on a brass rule fading out, "ROUND n" under it; the
##            coins slide left when the turn passes.
##   Ribbon   the words at the top middle (what happens, the order being aimed): Cinzel on a
##            two-sided wash between two lozenges.
##   Brackets gold corner brackets round the one being aimed at, breathing.
##   Plate    a monster's name and health over it while it is aimed at.
##   BossBar  the boss's name and long bar at the top.
##   Pointer  the small ember chevron over the head of the one whose turn it is.
##   Banner   VICTORY / FALLEN: big Cinzel with a light sweeping over the letters, rules, lozenges.

const UI = preload("res://scripts/ui/theme.gd")


static func phone() -> bool:
	return UI.is_phone()


## Text drawn with an ink outline (for words straight on the world).
static func ink_text(c: CanvasItem, f: Font, at: Vector2, s: String, size: int, col: Color, outline: int = 3, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if outline > 0:
		c.draw_string_outline(f, at, s, align, width, size, outline, Color(UI.C_INK, 0.85 * col.a))
	c.draw_string(f, at, s, align, width, size, col)


## Sets a bar only when its value really changed (setting it again would cut short the pale
## "lost" part that is still draining).
static func set_bar(bar: Control, v: float, max_v: float, animate: bool = true) -> void:
	if is_equal_approx(float(bar.get("value")), clampf(v, 0.0, max_v)) and is_equal_approx(float(bar.get("max_value")), maxf(max_v, 0.0001)):
		return
	bar.call("set_value", v, max_v, animate)


static func text_w(f: Font, s: String, size: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# ------------------------------------------------------------------ the Lantern, statuses, intents (quality pass P08)
## The colour of each status of battles.gd STATUS on a pip ("stun" = loses its next turn).
const STATUS_COL := {"burn": Color(1.0, 0.5, 0.18), "weak": Color(0.72, 0.5, 0.95), "exposed": Color(0.95, 0.3, 0.3),
	"slowed": Color(0.45, 0.8, 1.0), "braced": Color(0.62, 0.78, 0.95), "stun": Color(0.75, 0.95, 1.0)}
const C_LANTERN := Color(1.0, 0.78, 0.38)


## [[id, colour, turns], ...] of a fighter's statuses (and a stun), in a fixed order.
static func pips_of(u: Dictionary) -> Array:
	var out: Array = []
	var st: Dictionary = u.get("status", {})
	for id: String in ["burn", "weak", "exposed", "slowed", "braced"]:
		if int(st.get(id, 0)) > 0:
			out.append([id, STATUS_COL[id], int(st[id])])
	for id: String in st:
		if not STATUS_COL.has(id) and int(st[id]) > 0:
			out.append([id, UI.C_DIM, int(st[id])])
	if int(u.get("stun", 0)) > 0 and int(u.get("hp", 0)) > 0:
		out.append(["stun", STATUS_COL["stun"], int(u["stun"])])
	return out


## Status pips from `at` (top left) to the right: a coloured square each with its turns in it.
## Returns the width drawn.
static func draw_pips(c: CanvasItem, at: Vector2, u: Dictionary, cell: float = 9.0) -> float:
	var x := at.x
	for p: Array in pips_of(u):
		var col: Color = p[1]
		var r := Rect2(Vector2(x, at.y), Vector2(cell, cell))
		c.draw_rect(r.grow(1.0), Color(UI.C_INK, 0.85))
		c.draw_rect(r, col.darkened(0.25))
		c.draw_rect(Rect2(r.position, Vector2(cell, cell * 0.4)), col.lightened(0.15))
		var n := "%d" % int(p[2])
		var fs := int(maxf(cell - 1.0, 6.0))
		var tw := text_w(UI.font_num, n, fs)
		c.draw_string(UI.font_num, Vector2(x + (cell - tw) * 0.5, at.y + cell - 1.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.C_INK)
		x += cell + 3.0
	return x - at.x


## A small lantern drawn in code: a brass cap and ring, a glass body with a flame in it. `at` = its
## top middle, `k` = scale (1 = 8 x 12 UI px). lit 0..1: how bright the glass glows.
static func draw_lantern(c: CanvasItem, at: Vector2, k: float = 1.0, lit: float = 1.0) -> void:
	var ink := Color(UI.C_INK, 0.9)
	var brass := UI.C_BRASS
	# the ring and cap
	c.draw_arc(at + Vector2(0, 1.5 * k), 1.6 * k, PI, TAU, 6, brass, maxf(1.0, k))
	c.draw_rect(Rect2(at + Vector2(-3.5, 2.5) * k, Vector2(7, 2) * k), ink)
	c.draw_rect(Rect2(at + Vector2(-3, 3) * k, Vector2(6, 1.2) * k), brass)
	# the glass
	var body := Rect2(at + Vector2(-3.5, 4.5) * k, Vector2(7, 6) * k)
	c.draw_rect(body.grow(0.8), ink)
	c.draw_rect(body, Color(0.3, 0.2, 0.1).lerp(Color(1.0, 0.72, 0.3), lit))
	c.draw_rect(Rect2(body.position + Vector2(1.5, 1.5) * k, Vector2(4, 3.2) * k), Color(1.0, 0.95, 0.7, 0.35 + 0.65 * lit))
	c.draw_line(body.position + Vector2(body.size.x * 0.5, 0), body.position + Vector2(body.size.x * 0.5, body.size.y), Color(brass, 0.7), maxf(1.0, k * 0.8))
	# the foot
	c.draw_rect(Rect2(at + Vector2(-4, 10.5) * k, Vector2(8, 1.6) * k), ink)
	c.draw_rect(Rect2(at + Vector2(-3.5, 10.7) * k, Vector2(7, 1.0) * k), brass)


## One flame pip (a teardrop): lit = ember with a hot core, unlit = a dim outline. `at` = its foot.
static func draw_flame(c: CanvasItem, at: Vector2, k: float, lit: bool) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -7) * k, at + Vector2(2.6, -2.6) * k, at + Vector2(2.4, -0.6) * k,
		at + Vector2(0, 0.6) * k, at + Vector2(-2.4, -0.6) * k, at + Vector2(-2.6, -2.6) * k])
	var outline := pts.duplicate()
	outline.append(pts[0])
	if lit:
		c.draw_colored_polygon(pts, UI.C_EMBER)
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3.8) * k, at + Vector2(1.2, -1.2) * k, at + Vector2(0, -0.2) * k, at + Vector2(-1.2, -1.2) * k]), Color(1.0, 0.95, 0.7))
		c.draw_polyline(outline, Color(UI.C_INK, 0.9), 1.0)
	else:
		c.draw_colored_polygon(pts, Color(UI.C_INK, 0.7))
		c.draw_polyline(outline, Color(UI.C_BRASS, 0.55), 1.0)


## The lantern and its three flames, left to right from `at` (the lantern's top left). Width drawn.
static func draw_holder(c: CanvasItem, at: Vector2, flame: int, k: float = 1.0) -> float:
	draw_lantern(c, at + Vector2(4.0 * k, 0.0), k, 0.45 + 0.55 * float(flame) / 3.0)
	for i in 3:
		draw_flame(c, at + Vector2((12.0 + 6.5 * i) * k, 11.0 * k), k, i < flame)
	return 30.0 * k


## A 12 x 16 lantern picture made in code (the Lantern order's icon on the commands page).
static var _lantern_tex: Texture2D
static func lantern_tex() -> Texture2D:
	if _lantern_tex != null:
		return _lantern_tex
	var rows := [
		"....oooo....",
		"...o....o...",
		"...o....o...",
		"..kkkkkkkk..",
		".kbbbbbbbbk.",
		".kgyyyyyygk.",
		".kgyywwyygk.",
		".kgywwwwygk.",
		".kgywwwwygk.",
		".kgyywwyygk.",
		".kgyyyyyygk.",
		".kbbbbbbbbk.",
		"..kkkkkkkk..",
		"...kbbbbk...",
		"..kbbbbbbk..",
		"..kkkkkkkk..",
	]
	var cols := {"o": Color(0.55, 0.42, 0.25), "k": Color(0.1, 0.08, 0.1), "b": Color(0.78, 0.62, 0.36), "g": Color(0.95, 0.6, 0.2),
		"y": Color(1.0, 0.8, 0.35), "w": Color(1.0, 0.97, 0.8)}
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if cols.has(line[x]):
				img.set_pixel(x, y, cols[line[x]])
	_lantern_tex = ImageTexture.create_from_image(img)
	return _lantern_tex


## The little code picture of an intent (fight.gd unit["intent"]["icon"]), centred on `at`.
static func draw_intent_icon(c: CanvasItem, at: Vector2, icon: String, k: float = 1.0) -> void:
	var ink := Color(UI.C_INK, 0.95)
	match icon:
		"blow":
			# a short sword, point up and right
			c.draw_line(at + Vector2(-3.5, 3.5) * k, at + Vector2(3.5, -3.5) * k, ink, 3.0 * k)
			c.draw_line(at + Vector2(-3.0, 3.0) * k, at + Vector2(3.5, -3.5) * k, UI.C_PARCH, 1.4 * k)
			c.draw_line(at + Vector2(-3.2, -0.2) * k, at + Vector2(0.2, 3.2) * k, UI.C_BRASS, 1.6 * k)
		"heavy":
			# two heavy chevrons pointing down
			for i in 2:
				var y := (-3.5 + 3.5 * i) * k
				var pts := PackedVector2Array([at + Vector2(-4, y), at + Vector2(0, y + 3.0 * k), at + Vector2(4, y)])
				c.draw_polyline(pts, ink, 3.2 * k)
				c.draw_polyline(pts, UI.C_BAD, 1.6 * k)
		"all":
			# a burst: eight rays
			for i in 8:
				var d := Vector2.from_angle(TAU * float(i) / 8.0)
				c.draw_line(at + d * 1.5 * k, at + d * 4.5 * k, ink, 2.6 * k)
				c.draw_line(at + d * 1.5 * k, at + d * 4.2 * k, UI.C_BAD, 1.2 * k)
		"fuse":
			c.draw_circle(at, 4.5 * k, ink)
			c.draw_circle(at, 3.5 * k, Color(1.0, 0.45, 0.2))
			c.draw_line(at + Vector2(2, -3) * k, at + Vector2(4, -5.5) * k, UI.C_GOLD, 1.2 * k)
		"heal":
			c.draw_rect(Rect2(at + Vector2(-1.5, -4.5) * k, Vector2(3, 9) * k).grow(1.0), ink)
			c.draw_rect(Rect2(at + Vector2(-4.5, -1.5) * k, Vector2(9, 3) * k).grow(1.0), ink)
			c.draw_rect(Rect2(at + Vector2(-1.5, -4.5) * k, Vector2(3, 9) * k), UI.C_GOOD)
			c.draw_rect(Rect2(at + Vector2(-4.5, -1.5) * k, Vector2(9, 3) * k), UI.C_GOOD)
		"wind":
			# drawing back: two chevrons pointing away (right)
			for i in 2:
				var x := (-3.0 + 3.5 * i) * k
				var pts := PackedVector2Array([at + Vector2(x, -3.5 * k), at + Vector2(x + 3.0 * k, 0), at + Vector2(x, 3.5 * k)])
				c.draw_polyline(pts, ink, 3.0 * k)
				c.draw_polyline(pts, UI.C_GOLD, 1.4 * k)
		_:
			# stunned / nothing: a small grey "z"
			var pts := PackedVector2Array([at + Vector2(-3, -3) * k, at + Vector2(3, -3) * k, at + Vector2(-3, 3) * k, at + Vector2(3, 3) * k])
			c.draw_polyline(pts, ink, 3.0 * k)
			c.draw_polyline(pts, UI.C_DIM, 1.4 * k)


## The edge colour of an intent's chip: how much it should worry you.
static func intent_col(icon: String) -> Color:
	match icon:
		"heavy", "all", "fuse":
			return UI.C_BAD
		"blow":
			return UI.C_EMBER
		"heal":
			return UI.C_GOOD
		"wind":
			return UI.C_GOLD
	return UI.C_FAINT


## OVER EACH MONSTER: what it means to do this round (an icon, a short word, the face of the one it
## goes for) and under its bar its status pips. battle.gd moves `head_at` / `feet_at` every frame.
class FoeMarks extends Control:
	var unit: Dictionary
	var short := {}                    ## lessons.gd WORDS intent_short
	var face: Control                  ## a small coin of the one a single blow goes for
	var _face_id := ""
	var _key := ""
	var head_at := Vector2.ZERO        ## the chip's bottom middle (over the head)
	var feet_at := Vector2.ZERO        ## the pips' top left (beside the bar)
	var show_intent := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(u: Dictionary, words: Dictionary) -> void:
		unit = u
		short = words
		UI._load_fonts()

	func _intent() -> Dictionary:
		var it: Dictionary = unit.get("intent", {})
		if it.is_empty() or bool(it.get("done", false)) or int(unit.get("hp", 0)) <= 0:
			return {}
		return it

	func _word(it: Dictionary) -> String:
		var icon := String(it.get("icon", "none"))
		var w := String(short.get(icon, ""))
		if icon == "fuse":
			return w % maxi(1, int(unit.get("fuse", 1))) if w.contains("%d") else w
		if icon == "blow" or (icon == "heavy" and it.get("target") is Dictionary):
			var t: Variant = it.get("target")
			if t is Dictionary and not (t as Dictionary).is_empty():
				return (w + " " if w != "" else "") + String((t as Dictionary).get("name", "")).get_slice(" ", 0)
		return w

	## Called every frame by battle.gd; redraws only when something changed.
	func sync() -> void:
		var it := _intent()
		var tgt: Variant = it.get("target") if not it.is_empty() else null
		var tid := ""
		if tgt is Dictionary and not (tgt as Dictionary).is_empty():
			tid = String((tgt as Dictionary).get("sprite", ""))
		var key := str(head_at) + str(feet_at) + str(show_intent) + String(it.get("icon", "")) + _word(it) + tid + str(pips_of_unit())
		if key == _key:
			return
		_key = key
		var want_face := show_intent and tid != "" and ["blow", "heavy"].has(String(it.get("icon", "")))
		if want_face and tid != _face_id:
			if is_instance_valid(face):
				face.queue_free()
			face = UI.medallion(tid, 5.0 if UI.is_phone() else 7.0, UI.C_STEEL, false, (tgt as Dictionary).get("tint", Color.WHITE))
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(face)
			_face_id = tid
		if is_instance_valid(face):
			face.visible = want_face
		queue_redraw()

	func pips_of_unit() -> Array:
		return load("res://scripts/battle/battle_ui.gd").call("pips_of", unit)

	func _draw() -> void:
		if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
			if is_instance_valid(face):
				face.visible = false
			return
		var ph := UI.is_phone()
		var ui: GDScript = load("res://scripts/battle/battle_ui.gd")
		ui.call("draw_pips", self, feet_at, unit, 6.0 if ph else 8.0)
		var it := _intent()
		if it.is_empty() or not show_intent:
			return
		var icon := String(it.get("icon", "none"))
		var word := _word(it)
		var fs := 7 if ph else 9
		var k := 0.75 if ph else 1.0
		var face_w := 0.0
		if is_instance_valid(face) and face.visible:
			face_w = face.custom_minimum_size.x + 2.0
			word = String(short.get(icon, ""))       # (the face says who)
		var tw := UI.font_bold.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if word != "" else 0.0
		var h := 12.0 if ph else 16.0
		var w := 4.0 + 10.0 * k + (3.0 + tw if word != "" else 0.0) + face_w + 4.0
		var r := Rect2(Vector2(roundf(head_at.x - w * 0.5), roundf(head_at.y - h)), Vector2(w, h))
		var edge: Color = ui.call("intent_col", icon)
		draw_rect(r, Color(UI.C_WASH, 0.82))
		draw_rect(r, Color(edge, 0.9), false, 1.0)
		draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), Color(edge, 0.45))
		var ic := r.position + Vector2(4.0 + 5.0 * k, h * 0.5)
		ui.call("draw_intent_icon", self, ic, icon, k)
		var x := r.position.x + 4.0 + 10.0 * k + 3.0
		if word != "":
			ui.call("ink_text", self, UI.font_bold, Vector2(x, r.position.y + h * 0.5 + fs * 0.36), word, fs, edge.lerp(UI.C_PARCH, 0.35), 2)
			x += tw + 2.0
		if is_instance_valid(face) and face.visible:
			face.position = Vector2(x, r.position.y + (h - face.custom_minimum_size.y) * 0.5).round()


# ------------------------------------------------------------------ a fighter of your side
class Card extends Control:
	const H_PC := 44.0
	const H_PHONE := 16.0
	var unit: Dictionary
	var level := 1                     ## the "Lv n" on the card (the whole party shares the knight's level)
	var is_phone := false
	var acting := false
	var targeted := false
	var holder := false                ## (quality pass P08) carries the Lantern: a lantern and three flame pips
	var flame := 0
	var base := Vector2.ZERO           ## where the layout puts it (lift and jolt move it from there)
	var button: Button                 ## the whole card: picks this fighter for a heal
	var hp_bar: Control
	var mp_bar: Control
	var coin: Control
	var lift := 0.0:
		set(v):
			lift = v
			_place()
	var jolt := 0.0:
		set(v):
			jolt = v
			_place()
	var flash := 0.0:
		set(v):
			flash = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var _lift_tw: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(u: Dictionary) -> void:
		unit = u
		is_phone = UI.is_phone()
		UI._load_fonts()
		if not is_phone:
			coin = UI.medallion(String(u["sprite"]), 11.0, UI.C_STEEL, false, u.get("tint", Color.WHITE))
			add_child(coin)
		hp_bar = UI.bar("hp", 46.0)
		mp_bar = UI.bar("mp", 46.0)
		add_child(hp_bar)
		add_child(mp_bar)
		button = Button.new()
		button.name = "pick"
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = true
		button.flat = true
		button.set_meta("no_flame", true)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		UI.juice(button)          # (the mouse over a card aims at it while a heal is aimed)
		add_child(button)
		size = Vector2(150.0, H_PHONE if is_phone else H_PC)
		refresh(false)

	## The card's width (its height is fixed); places what is inside it.
	func set_width(w: float) -> void:
		var h := H_PHONE if is_phone else H_PC
		custom_minimum_size = Vector2(w, h)
		size = Vector2(w, h)
		button.position = Vector2.ZERO
		button.size = size
		if is_phone:
			_bar_at(hp_bar, Vector2(46, 5), Vector2(46, 3))
			_bar_at(mp_bar, Vector2(46, 10), Vector2(46, 2))
		else:
			coin.position = (Vector2(17, 22) - coin.custom_minimum_size * 0.5).round()
			var bx := 34.0
			var bw := w - 34.0 - 9.0
			var hw := floorf(bw * 0.6)
			_bar_at(hp_bar, Vector2(bx, 32), Vector2(hw, 4))
			_bar_at(mp_bar, Vector2(bx + hw + 6.0, 32), Vector2(bw - hw - 6.0, 4))
		queue_redraw()

	func _bar_at(b: Control, at: Vector2, s: Vector2) -> void:
		b.custom_minimum_size = s
		b.size = s
		b.position = at

	func place_at(at: Vector2) -> void:
		base = at
		_place()

	func _place() -> void:
		position = (base + Vector2(jolt, -lift)).round()

	## Numbers and bars from the unit (animate = the bars drain / fill).
	func refresh(animate: bool = true) -> void:
		var ui_script: GDScript = load("res://scripts/battle/battle_ui.gd")
		ui_script.call("set_bar", hp_bar, float(unit["hp"]), float(unit["max_hp"]), animate)
		ui_script.call("set_bar", mp_bar, float(unit["mp"]), maxf(float(unit["max_mp"]), 1.0), animate)
		var down := int(unit["hp"]) <= 0
		modulate.a = 0.5 if down else 1.0
		if coin != null:
			coin.call("set_ko", down)
		queue_redraw()

	func set_acting(on: bool) -> void:
		if on == acting:
			return
		acting = on
		if coin != null:
			coin.call("set_active", on)
		_lift_to()

	func set_targeted(on: bool) -> void:
		if on == targeted:
			return
		targeted = on
		_lift_to()

	func _lift_to() -> void:
		var up := 6.0 if (acting or targeted) and not is_phone else 0.0
		var g := 1.0 if (acting or targeted) else 0.0
		if _lift_tw != null and _lift_tw.is_valid():
			_lift_tw.kill()
		if UI.instant or not is_inside_tree():
			lift = up
			glow = g
			return
		_lift_tw = create_tween().set_parallel(true)
		_lift_tw.tween_property(self, "lift", up, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_lift_tw.tween_property(self, "glow", g, 0.2)
		queue_redraw()

	## A blow landed on this fighter: the card shakes (2-6 UI px by how much it took) and the HP
	## number flashes red.
	func hit(ratio: float) -> void:
		if not is_inside_tree():
			return
		flash = 1.0
		var tf := create_tween()
		tf.tween_property(self, "flash", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var kick := (2.0 + 4.0 * clampf(ratio, 0.0, 1.0)) * (0.6 if is_phone else 1.0)
		var tj := create_tween()
		for i in 4:
			tj.tween_property(self, "jolt", kick * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.22), 0.03)
		tj.tween_property(self, "jolt", 0.0, 0.03)

	func _draw() -> void:
		if unit.is_empty():
			return
		var ci := get_canvas_item()
		var w := size.x
		var down := int(unit["hp"]) <= 0
		var hot := acting or targeted
		var name_col := UI.C_GOLD if hot else (UI.C_FAINT if down else UI.C_PARCH)
		var hp_col := UI.C_LOW if bool(hp_bar.call("is_low")) else UI.C_PARCH
		hp_col = hp_col.lerp(UI.C_BAD, flash)
		if is_phone:
			# a thin strip on a wash that fades out to the right
			UI.rs_hgrad(ci, Rect2(-8, 0, w + 30, size.y), Color(UI.C_WASH, 0.62 + 0.2 * glow), Color(UI.C_WASH, 0.0))
			if glow > 0.0:
				draw_line(Vector2(-2, 2), Vector2(-2, size.y - 2), Color(UI.C_EMBER, glow), 1.5)
			ink_text_(UI.font_bold, Vector2(2, 11), String(unit["name"]), 8, name_col)
			var hp_s := "%d" % int(unit["hp"])
			ink_text_(UI.font_num, Vector2(w - 2, 11), hp_s, 8, hp_col, HORIZONTAL_ALIGNMENT_RIGHT)
			# (and the mana, small and blue, left of the health: a caster reads it without opening Skills)
			var mp_x := w - 2.0 - UI.font_num.get_string_size(hp_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x - 5.0
			ink_text_(UI.font_num, Vector2(mp_x, 11), "%d" % int(unit["mp"]), 7, UI.C_MP_A.lerp(Color.WHITE, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
			# (P08) right of the numbers (the name and the bars leave no room inside): the Lantern
			# and its flames, then the status pips
			var ui_p: GDScript = load("res://scripts/battle/battle_ui.gd")
			var nx := w + 4.0
			if holder and not down:
				nx += float(ui_p.call("draw_holder", self, Vector2(nx, 2.5), flame, 0.6)) + 3.0
			ui_p.call("draw_pips", self, Vector2(nx, 4.0), unit, 6.0)
			return
		# an ember glow spilling out under the acting card
		if glow > 0.0:
			for k in 4:
				draw_rect(Rect2(6 + k * 4, size.y - 2, w - 12 - k * 8, 6 + k * 3), Color(UI.C_EMBER, 0.06 * glow))
		draw_style_box(UI.box("gold" if hot else "card"), Rect2(Vector2.ZERO, size))
		var bx := 34.0
		var bw := w - 34.0 - 9.0
		var hw := floorf(bw * 0.6)
		var mx := bx + hw + 6.0
		var mw := bw - hw - 6.0
		_txt(UI.font_bold, Vector2(bx, 15), String(unit["name"]), 12, name_col)
		_txt(UI.font_body, Vector2(w - 9, 15), "Lv %d" % level, 9, UI.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(UI.font_bold, Vector2(bx, 29), "HP", 8, UI.C_DIM)
		_txt(UI.font_num, Vector2(bx + hw, 29), "%d" % int(unit["hp"]), 12, hp_col, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(UI.font_bold, Vector2(mx, 29), "MP", 8, UI.C_DIM)
		_txt(UI.font_num, Vector2(mx + mw, 29), "%d" % int(unit["mp"]), 12, UI.C_PARCH, HORIZONTAL_ALIGNMENT_RIGHT)
		# (P08) the Lantern sits on the card's top edge at the right, its three flames beside it;
		# the status pips on the top edge at the left
		var ui_p: GDScript = load("res://scripts/battle/battle_ui.gd")
		if holder and not down:
			var hold_at := Vector2(w - 50.0, -11.0)
			for k in 3:
				draw_circle(hold_at + Vector2(10, 11), 12.0 - k * 3.5, Color(UI.C_EMBER, 0.05 + 0.05 * k + 0.04 * flame))
			ui_p.call("draw_holder", self, hold_at, flame, 1.3)
		ui_p.call("draw_pips", self, Vector2(bx, -5.0), unit, 8.0)

	## Text at a baseline point; right-aligned text ENDS at `at.x`.
	func _txt(f: Font, at: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var p := at
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func ink_text_(f: Font, at: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var p := at
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			p.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(UI.C_INK, 0.85))
		draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


# ------------------------------------------------------------------ the turn order
class Rail extends Control:
	var is_phone := false
	var holder: Control
	var round_no := 0
	var end_x := 0.0                    ## where the last coin ends (the boss bar keeps clear of it)
	var div_x := -1.0                   ## (P08) where the divider before the next round stands (-1 = none)
	var _key := ""
	var _tw: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup() -> void:
		is_phone = UI.is_phone()
		UI._load_fonts()
		holder = Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		size = Vector2(120, 26) if is_phone else Vector2(240, 56)

	## line = the fighters in the order they act, the one acting now first.
	## (P08) next = the next round's order (fight.gd upcoming_next()): smaller coins after a divider.
	func set_line(line: Array, round_number: int, next: Array = []) -> void:
		round_no = round_number
		var key := ""
		for u: Dictionary in line:
			key += String(u["id"]) + str(u["home"]) + str(int(u.get("stun", 0)) > 0) + ";"
		key += "|"
		for u: Dictionary in next:
			key += String(u["id"]) + str(u["home"]) + ";"
		queue_redraw()
		if key == _key:
			return
		var had := _key != ""
		_key = key
		for c in holder.get_children():
			c.queue_free()
		var x := 14.0 if is_phone else 28.0
		var y := 13.0 if is_phone else 26.0
		for i in mini(line.size(), 7 if not is_phone else 6):
			var u: Dictionary = line[i]
			var r: float = (8.0 if i == 0 else 6.0) if is_phone else (13.0 if i == 0 else 9.0)
			var ring := UI.C_STEEL if String(u["side"]) == "party" else UI.C_FOE
			var m := UI.medallion(String(u["sprite"]), r, ring, i == 0, u.get("tint", Color.WHITE))
			if String(u["side"]) != "party":
				m.set("shape", "foe")
			m.position = (Vector2(x, y) - m.custom_minimum_size * 0.5).round()
			# (the mouse over a face says who it is; the first acts now)
			m.mouse_filter = Control.MOUSE_FILTER_PASS
			m.tooltip_text = String(u["name"])
			if int(u.get("stun", 0)) > 0 and i > 0:
				m.modulate = Color(0.5, 0.52, 0.58, 0.85)      # (stunned: it will lose that turn)
			holder.add_child(m)
			if i == 1 and not is_phone:
				# who comes next: a small NEXT above the second coin
				var nx := Label.new()
				nx.text = "NEXT"
				nx.add_theme_font_override("font", UI.font_bold)
				nx.add_theme_font_size_override("font_size", 8)
				nx.add_theme_color_override("font_color", UI.C_GOLD)
				nx.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.9))
				nx.add_theme_constant_override("outline_size", 3)
				nx.mouse_filter = Control.MOUSE_FILTER_IGNORE
				nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				nx.size = Vector2(30, 10)
				nx.position = Vector2(x - 15.0, y - r - 15.0).round()
				holder.add_child(nx)
			end_x = x + r
			if is_phone:
				x += (r + 10.0) if i == 0 else 14.0
			else:
				x += (r + 9.0 + 13.0) if i == 0 else 22.0
		# (P08) the next round, after a thin divider: smaller, fainter coins
		div_x = -1.0
		var room := 2 if is_phone else 5
		if not next.is_empty() and line.size() <= (6 if is_phone else 7):
			div_x = x - (6.0 if is_phone else 10.0) + (2.0 if is_phone else 4.0)
			x = div_x + (8.0 if is_phone else 12.0)
			for j in mini(next.size(), room):
				var u: Dictionary = next[j]
				var r := 4.5 if is_phone else 7.0
				var ring := UI.C_STEEL if String(u["side"]) == "party" else UI.C_FOE
				var m := UI.medallion(String(u["sprite"]), r, ring, false, u.get("tint", Color.WHITE))
				if String(u["side"]) != "party":
					m.set("shape", "foe")
				m.position = (Vector2(x, y) - m.custom_minimum_size * 0.5).round()
				m.modulate.a = 0.7
				m.mouse_filter = Control.MOUSE_FILTER_PASS
				m.tooltip_text = String(u["name"])
				holder.add_child(m)
				end_x = x + r
				x += 11.0 if is_phone else 17.0
		var want_w := maxf(end_x + (10.0 if is_phone else 20.0), 120.0 if is_phone else 240.0)
		size.x = want_w
		# the turn passed: the coins slide in from the right into their places
		if had and not UI.instant and is_inside_tree():
			if _tw != null and _tw.is_valid():
				_tw.kill()
			holder.position.x = 14.0 if is_phone else 22.0
			holder.modulate.a = 0.4
			_tw = create_tween().set_parallel(true)
			_tw.tween_property(holder, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tw.tween_property(holder, "modulate:a", 1.0, 0.2)

	func clear() -> void:
		_key = ""
		for c in holder.get_children():
			c.queue_free()
		queue_redraw()

	func _draw() -> void:
		var ci := get_canvas_item()
		var a := 0.5 if is_phone else 0.55
		UI.rs_hgrad(ci, Rect2(Vector2.ZERO, size), Color(UI.C_WASH, a), Color(UI.C_WASH, 0.0))
		if holder == null or holder.get_child_count() == 0:
			return
		if is_phone:
			UI.rs_rule(ci, Vector2(14, 13), Vector2(14 + 100, 13), Color(UI.C_BRASS, 0.7), Color(UI.C_BRASS, 0.0))
			if div_x > 0.0:
				draw_line(Vector2(div_x, 6), Vector2(div_x, 20), Color(UI.C_BRASS, 0.8), 1.0)
			return
		UI.rs_rule(ci, Vector2(28, 26), Vector2(28 + maxf(175.0, end_x - 20.0), 26), Color(UI.C_BRASS, 0.8), Color(UI.C_BRASS, 0.0))
		if div_x > 0.0:
			draw_line(Vector2(div_x, 13), Vector2(div_x, 39), Color(UI.C_INK, 0.8), 3.0)
			draw_line(Vector2(div_x, 13), Vector2(div_x, 39), Color(UI.C_BRASS, 0.9), 1.0)
			if round_no > 0:
				var rs := "%d" % (round_no + 1)
				draw_string_outline(UI.font_bold, Vector2(div_x + 4, 12), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(UI.C_INK, 0.85))
				draw_string(UI.font_bold, Vector2(div_x + 4, 12), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.C_DIM)
		if round_no > 0:
			var s := "ROUND  %d" % round_no
			draw_string_outline(UI.font_bold, Vector2(14, 51), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(UI.C_INK, 0.85))
			draw_string(UI.font_bold, Vector2(14, 51), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.C_GOLD.lerp(UI.C_DIM, 0.4))


# ------------------------------------------------------------------ the words at the top
class Ribbon extends Control:
	var text := ""
	var pinned := false
	var colour := UI.C_GOLD
	var _tw: Tween
	var _fs := 13

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func band_h() -> float:
		return 14.0 if UI.is_phone() else 22.0

	## Shows words for `hold` seconds, then fades them (0 = until the next words).
	func say(words: String, hold: float = 1.2, col: Color = UI.C_GOLD) -> void:
		if pinned and words == "":
			return
		if words == "":
			_fade_out()
			return
		text = words.to_upper()
		colour = col
		queue_redraw()
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UI.instant or not is_inside_tree():
			modulate.a = 1.0
			if hold > 0.0 and is_inside_tree():
				_tw = create_tween()
				_tw.tween_interval(hold)
				_tw.tween_property(self, "modulate:a", 0.0, 0.2)
			return
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 1.0, 0.12)
		if hold > 0.0:
			_tw.tween_interval(hold)
			_tw.tween_property(self, "modulate:a", 0.0, 0.2)

	## Words that stay (the order being aimed) until unpin().
	func pin(words: String, col: Color = UI.C_GOLD) -> void:
		pinned = true
		say(words, 0.0, col)

	func unpin() -> void:
		if pinned:
			pinned = false
			_fade_out()

	func _fade_out() -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UI.instant or not is_inside_tree():
			modulate.a = 0.0
			return
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 0.0, 0.2)

	func _draw() -> void:
		if text == "":
			return
		var ph := UI.is_phone()
		var f: Font = UI.font_head
		var room := size.x - (60.0 if ph else 160.0)
		_fs = 9 if ph else 13
		while _fs > (7 if ph else 10) and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x > room:
			_fs -= 1
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		var h := band_h()
		var ww := tw + (60.0 if ph else 120.0)
		var c := roundf(size.x * 0.5)
		var ci := get_canvas_item()
		UI.rs_hgrad(ci, Rect2(c - ww * 0.5, 0, ww * 0.5, h), Color(UI.C_WASH, 0.0), Color(UI.C_WASH, 0.72))
		UI.rs_hgrad(ci, Rect2(c, 0, ww * 0.5, h), Color(UI.C_WASH, 0.72), Color(UI.C_WASH, 0.0))
		var base := roundf(h * 0.5 + _fs * 0.36)
		var x := roundf(c - tw * 0.5)
		draw_string_outline(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, 3, Color(UI.C_INK, 0.85))
		draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, colour)
		var mid := roundf(h * 0.5) - 0.5
		var gap := 8.0 if ph else 12.0
		var rule := 14.0 if ph else 26.0
		var s := 2.0 if ph else 2.5
		for side: float in [-1.0, 1.0]:
			var at := Vector2(c + side * (tw * 0.5 + gap), mid)
			UI.rs_lozenge(ci, at, s, UI.C_BRASS, 0.0)
			UI.rs_rule(ci, at + Vector2(side * (s + 1.5), 0), at + Vector2(side * (s + 1.5 + rule), 0), Color(UI.C_BRASS, 0.9), Color(UI.C_BRASS, 0.0))
			UI.rs_rule(ci, at - Vector2(side * (s + 1.5), 0), at - Vector2(side * (s + 4.0), 0), Color(UI.C_BRASS, 0.7), Color(UI.C_BRASS, 0.2))


# ------------------------------------------------------------------ aiming
class Brackets extends Control:
	var box := Rect2()                 ## the target's picture on the UI grid
	var shown := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not shown or box.size.x < 2.0:
			return
		var k := 1.0 if UI.instant else 1.0 + 0.03 * (1.0 + sin(_t * TAU * 1.4))
		var r := Rect2(box.get_center() - box.size * k * 0.5, box.size * k)
		var arm := 4.0 if UI.is_phone() else 6.0
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if is_equal_approx(corner.x, r.position.x) else -1.0
			var sy := 1.0 if is_equal_approx(corner.y, r.position.y) else -1.0
			var pts := PackedVector2Array([corner + Vector2(0, sy * arm), corner, corner + Vector2(sx * arm, 0)])
			draw_polyline(pts, Color(UI.C_INK, 0.8), 3.0, true)
			draw_polyline(pts, UI.C_GOLD, 1.4, true)


## A monster's name and health over it while it is aimed at (a `danger` glass plate).
class Plate extends Control:
	var title := ""
	var bar: Control
	var lines: Array = []              ## (P08) [[text, colour], ...] under the bar: intent, kit line, damage preview
	var unit: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup() -> void:
		UI._load_fonts()
		bar = UI.bar("foe", 40.0)
		add_child(bar)

	func set_unit(u: Dictionary, animate: bool) -> void:
		var t := String(u["name"]).to_upper()
		var ph := UI.is_phone()
		var fs := 8 if ph else 11
		if t != title:
			title = t
			animate = false
		var w := maxf(ceilf(UI.font_head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + (14.0 if ph else 24.0), 56.0 if ph else 80.0)
		unit = u
		var lfs := 7 if ph else 9
		for l: Array in lines:
			w = maxf(w, minf(ceilf(UI.font_body.get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x) + (12.0 if ph else 18.0), 200.0 if ph else 260.0))
		size = Vector2(w, (17.0 if ph else 26.0) + lines.size() * (9.0 if ph else 12.0) + (2.0 if not lines.is_empty() else 0.0))
		var bw := w - (10.0 if ph else 16.0)
		bar.custom_minimum_size.x = bw
		bar.size.x = bw
		bar.position = Vector2(5.0 if ph else 8.0, 12.0 if ph else 17.0)
		bar.call("set_value", float(u["hp"]), float(u["max_hp"]), animate)
		queue_redraw()

	func _draw() -> void:
		var ph := UI.is_phone()
		var sb := UI.box("danger")
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var fs := 8 if ph else 11
		var tw := UI.font_head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(roundf((size.x - tw) * 0.5), 9.0 if ph else 13.0)
		draw_string(UI.font_head, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.C_PARCH)
		# (P08) the status pips at the right end of the title row, then the lines under the bar
		if not unit.is_empty():
			var ui_p: GDScript = load("res://scripts/battle/battle_ui.gd")
			var n := (ui_p.call("pips_of", unit) as Array).size()
			if n > 0:
				var cell := 6.0 if ph else 7.0
				ui_p.call("draw_pips", self, Vector2(size.x - 4.0 - n * (cell + 3.0), -cell - 4.0), unit, cell)
		var lfs := 7 if ph else 9
		var y := (17.0 if ph else 26.0) + (7.0 if ph else 9.0)
		for l: Array in lines:
			draw_string(UI.font_body, Vector2(6.0 if ph else 9.0, y), String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - (10.0 if ph else 16.0), lfs, l[1])
			y += 9.0 if ph else 12.0


## The boss's name and long bar at the top (brass caps on the bar).
class BossBar extends Control:
	var title := ""
	var bar: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(u: Dictionary) -> void:
		UI._load_fonts()
		title = String(u["name"]).to_upper()
		var w := 140.0 if UI.is_phone() else 260.0
		bar = UI.bar("boss", w)
		add_child(bar)
		size = Vector2(w, 18.0 if UI.is_phone() else 30.0)
		bar.position = Vector2(0, 12.0 if UI.is_phone() else 20.0)
		bar.call("set_value", float(u["hp"]), float(u["max_hp"]), false)

	func set_width(w: float) -> void:
		size.x = w
		bar.custom_minimum_size.x = w
		bar.size.x = w
		queue_redraw()

	func _draw() -> void:
		var ph := UI.is_phone()
		var ci := get_canvas_item()
		var c := size.x * 0.5
		UI.rs_hgrad(ci, Rect2(c - size.x * 0.5 - 30, -2, size.x * 0.5 + 30, size.y + 2), Color(UI.C_WASH, 0.0), Color(UI.C_WASH, 0.55))
		UI.rs_hgrad(ci, Rect2(c, -2, size.x * 0.5 + 30, size.y + 2), Color(UI.C_WASH, 0.55), Color(UI.C_WASH, 0.0))
		var fs := 9 if ph else 13
		var tw := UI.font_head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(roundf(c - tw * 0.5), 9.0 if ph else 14.0)
		draw_string_outline(UI.font_head, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(UI.C_INK, 0.85))
		draw_string(UI.font_head, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.C_PARCH)


## The ember chevron over the head of the one whose turn it is (it bobs).
class Pointer extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := 0.8 if UI.is_phone() else 1.2
		var y := 0.0 if UI.instant else 2.0 * sin(_t * 5.0)
		var pts := PackedVector2Array([Vector2(-5, -5) * k, Vector2(5, -5) * k, Vector2(0, 1.5) * k])
		for i in pts.size():
			pts[i].y += y
		var rim := PackedVector2Array([pts[0] + Vector2(-1.2, -1), pts[1] + Vector2(1.2, -1), pts[2] + Vector2(0, 1.6)])
		draw_colored_polygon(rim, Color(UI.C_INK, 0.9))
		draw_polygon(pts, PackedColorArray([UI.C_GOLD, UI.C_GOLD, UI.C_EMBER]))
		draw_line(pts[0] + Vector2(1.5, 0.8), pts[1] + Vector2(-1.5, 0.8), Color(1, 0.97, 0.85, 0.7), 0.8)


# ------------------------------------------------------------------ the end of a battle
## VICTORY / FALLEN: a two-sided wash band, the word in big Cinzel with a light that sweeps over
## the letters once, and brass rules with lozenges out to each side.
class Banner extends Control:
	const SWEEP_CODE := """
shader_type canvas_item;
uniform float sweep = -1.0;
uniform float span = 400.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	float x = (local.x + local.y * 0.45) / span;
	float band = 1.0 - smoothstep(0.0, 0.09, abs(x - sweep));
	float lum = dot(COLOR.rgb, vec3(0.333));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.98, 0.9), band * 0.85 * smoothstep(0.25, 0.6, lum));
}
"""
	var word := ""
	var colour := UI.C_GOLD
	var label: Label
	var _mat: ShaderMaterial
	var _tw_w := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(text: String, col: Color, shadow: Color) -> void:
		UI._load_fonts()
		word = text.to_upper()
		colour = col
		label = Label.new()
		label.text = word
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", UI.font_head)
		var fs := UI.fs("display")
		label.add_theme_font_size_override("font_size", fs)
		UI.style_title(label, col, shadow)
		label.add_theme_constant_override("outline_size", 5)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sh := Shader.new()
		sh.code = SWEEP_CODE
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		label.material = _mat
		add_child(label)
		_tw_w = UI.font_head.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_mat.set_shader_parameter("span", maxf(_tw_w, 1.0))

	## Lays it out across `width`, `h` tall.
	func fit(width: float) -> void:
		var h := label.get_combined_minimum_size().y
		size = Vector2(width, h)
		label.position = Vector2(0, 0)
		label.size = Vector2(width, h)
		queue_redraw()

	## The light sweeps over the letters once (0.6 s).
	func play_sweep(delay: float = 0.15) -> void:
		var x0 := (size.x - _tw_w) * 0.5
		# the shader's x counts from the label's left edge: shift so 0..1 runs over the letters
		_mat.set_shader_parameter("span", maxf(_tw_w, 1.0))
		if UI.instant or not is_inside_tree():
			return
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("sweep", v + x0 / maxf(_tw_w, 1.0)), -0.3, 1.5, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		var ci := get_canvas_item()
		var ph := UI.is_phone()
		var c := roundf(size.x * 0.5)
		var band := Rect2(0, size.y * 0.12, size.x, size.y * 0.8)
		UI.rs_hgrad(ci, Rect2(band.position, Vector2(band.size.x * 0.5, band.size.y)), Color(UI.C_WASH, 0.0), Color(UI.C_WASH, 0.6))
		UI.rs_hgrad(ci, Rect2(Vector2(c, band.position.y), Vector2(band.size.x * 0.5, band.size.y)), Color(UI.C_WASH, 0.6), Color(UI.C_WASH, 0.0))
		var mid := roundf(size.y * 0.52)
		var gap := 10.0 if ph else 18.0
		var rule := 50.0 if ph else 110.0
		for side: float in [-1.0, 1.0]:
			var at := Vector2(c + side * (_tw_w * 0.5 + gap), mid)
			UI.rs_lozenge(ci, at, 2.5 if ph else 3.5, UI.C_BRASS, 0.0)
			UI.rs_rule(ci, at + Vector2(side * 6.0, 0), at + Vector2(side * (6.0 + rule), 0), Color(UI.C_BRASS, 0.9), Color(UI.C_BRASS, 0.0))
