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


# ------------------------------------------------------------------ a fighter of your side
class Card extends Control:
	const H_PC := 44.0
	const H_PHONE := 16.0
	var unit: Dictionary
	var level := 1                     ## the "Lv n" on the card (the whole party shares the knight's level)
	var is_phone := false
	var acting := false
	var targeted := false
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
	func set_line(line: Array, round_number: int) -> void:
		round_no = round_number
		var key := ""
		for u: Dictionary in line:
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
			return
		UI.rs_rule(ci, Vector2(28, 26), Vector2(28 + 175, 26), Color(UI.C_BRASS, 0.8), Color(UI.C_BRASS, 0.0))
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
		size = Vector2(w, 17.0 if ph else 26.0)
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
