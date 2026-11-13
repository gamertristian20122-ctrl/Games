extends RefCounted
## WalkKit: the pieces of the interface in the places you walk in (the HD GUI, "Lantern Glass").
## All sizes are UI px (children of a UI.attach() root); every piece reads the PC / phone tier itself.
##   Portrait   the speaker's bust in the talk box's well (3 UI px per art px, 2 on a phone)
##   TalkMarks  the page dots and the ember chevron in the talk box's corner
##   NameTag    the pill over the person in reach, a brass pointer, "[Q] Talk" above it
##   NewsMark   a gold coin with an ink "!" (news) or the same in C_FOE (a monster that hunts you)
##   Banner     the place's name on arrival ("WICKMERE"), or "Night has fallen" / "Morning" smaller
##   Toast      one small card bottom-centre: what a won fight paid, "The way is shut."
##   Coins      the coin disc and how many coins, top-right on a wash
## The marks are code-drawn geometric shapes (coin, lozenge, chevron), never icon art.
## Use with:  const WalkKit = preload("res://scripts/ui/walk_kit.gd") ... WalkKit.Toast.new()

const UI = preload("res://scripts/ui/theme.gd")


## The shared base of the pieces below: text helpers.
class Base extends Control:
	## Text with an ink outline at a baseline.
	static func _say(c: CanvasItem, f: Font, size: int, at: Vector2, s: String, col: Color, outline := 3, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		if outline > 0:
			c.draw_string_outline(f, at, s, align, width, size, outline, Color(UI.C_INK, 0.85 * col.a))
		c.draw_string(f, at, s, align, width, size, col)

	static func _tw(f: Font, size: int, s: String) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# ------------------------------------------------------------------ the talk box's portrait
## The speaker's bust: the top rows of their own sprite at a whole 3 UI px per art px (2 on a phone),
## standing on the bottom of a lit well (a warm glow behind), cut by the well's bottom edge; a brass
## hairline fading upward on its right. clip_contents keeps the glow inside the well.
class Portrait extends Base:
	var sprite_id := ""
	var k := 3.0
	var glow := true
	var _tex: Texture2D
	var _used := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true

	func setup(id: String, per_px: float) -> void:
		sprite_id = id
		k = per_px
		_tex = null
		if id != "" and Art.has(id):
			_tex = Art.tex(id)
			_used = UI.used_rect(id)
			# a wide figure gets a smaller whole scale so it is not cut at the sides
			while k > 1.0 and _used.size.x * k > size.x + 2.0 and size.x > 0.0:
				k -= 1.0
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and sprite_id != "":
			setup(sprite_id, k if size.x <= 0.0 else (2.0 if UI.is_phone() else 3.0))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.0, 0.0, 0.02, 0.35))
		if glow:
			var at := Vector2(r.size.x * 0.5, r.size.y * 0.42)
			var big := minf(r.size.x, r.size.y) * 0.47
			for i in 7:
				draw_circle(at, big * (1.0 - float(i) / 8.0), Color(1.0, 0.72, 0.42, 0.035), true, -1.0, true)
		if _tex == null:
			return
		var rows := minf(_used.size.y, floorf(r.size.y / k))
		var src := Rect2(_used.position, Vector2(_used.size.x, rows))
		var dst := Rect2(roundf((r.size.x - _used.size.x * k) * 0.5), r.size.y - rows * k, _used.size.x * k, rows * k)
		draw_texture_rect_region(_tex, dst, src)


# ------------------------------------------------------------------ page dots and the chevron
## Bottom-right of the talk box: one dot per page (r 1.6, the page being read in gold) and an ember
## chevron that bobs 2 UI px at 2 Hz when the page is done (a small lozenge on the last page).
class TalkMarks extends Base:
	var pages := 1
	var page := 0
	var done := false          ## the page is fully shown: the chevron appears
	var last := false          ## the last page: a lozenge instead of the chevron
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if done:
			queue_redraw()

	func _draw() -> void:
		var ph := UI.is_phone()
		var gap := 5.0 if ph else 7.0
		var dot := 1.2 if ph else 1.6
		var cx := size.x - (7.0 if ph else 9.0)
		var cy := size.y * 0.5
		if pages > 1:
			var x0 := cx - (12.0 if ph else 16.0) - gap * float(pages - 1)
			for i in pages:
				var on := i == page
				draw_circle(Vector2(x0 + gap * i, cy + 1.0), dot, UI.C_GOLD if on else Color(UI.C_DIM, 0.5), true, -1.0, true)
		if not done:
			return
		var bob := 0.0 if UI.instant else roundf(sin(_t * TAU * 2.0) * 2.0 * 2.0) / 2.0
		var a := Vector2(cx, cy + bob)
		if last:
			UI.rs_lozenge(get_canvas_item(), a, 3.0 if ph else 3.5, UI.C_EMBER, 0.0)
			return
		var s := 0.8 if ph else 1.0
		draw_colored_polygon(PackedVector2Array([a + Vector2(-5, -3) * s, a + Vector2(5, -3) * s, a + Vector2(0, 3.5) * s]), _ink_col(0.9))
		draw_colored_polygon(PackedVector2Array([a + Vector2(-4, -2.4) * s, a + Vector2(4, -2.4) * s, a + Vector2(0, 2.4) * s]), UI.C_EMBER)
		draw_colored_polygon(PackedVector2Array([a + Vector2(-1.6, -2.0) * s, a + Vector2(1.6, -2.0) * s, a + Vector2(0, 0.4) * s]), Color(1, 0.95, 0.75, 0.9))

	func _ink_col(a: float) -> Color:
		return Color(UI.C_INK, a)


# ------------------------------------------------------------------ the name tag
## Over the person in reach: their name (ExtraBold 11) in a pill (radius 8, ink 0.72, brass 0.5
## border), a small brass pointer under it, and the "[Q] Talk" prompt above (the prompt widget:
## pad LB, nothing on touch). With news, a small gold "!" coin sits in the pill's left end.
## Its bottom-middle (the pointer's tip) is the point that is placed over the person.
## show_on(bool) fades it in / out (0.12 s).
class NameTag extends Base:
	var text := "":
		set(v):
			if v != text:
				text = v
				_fit()
	var news := false:
		set(v):
			if v != news:
				news = v
				_fit()
	var _prompt: Control
	var _a := 0.0
	var _want := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _ready() -> void:
		_prompt = UI.prompt("talk", "Talk")
		add_child(_prompt)
		_fit()

	func _sizes() -> Dictionary:
		if UI.is_phone():
			return {"font": 8, "h": 12.0, "pad": 6.0, "radius": 6, "point": 2.5, "coin": 3.5}
		return {"font": 11, "h": 16.0, "pad": 8.0, "radius": 8, "point": 3.0, "coin": 4.5}

	func _fit() -> void:
		UI._load_fonts()
		var s := _sizes()
		var w := _tw(UI.font_num, int(s["font"]), text) + float(s["pad"]) * 2.0
		if news:
			w += float(s["coin"]) * 2.0 + 3.0
		w = ceilf(w)
		var ph := 0.0
		if is_instance_valid(_prompt) and _prompt.visible:
			ph = _prompt.size.y + 2.0
		var full := Vector2(maxf(w, _prompt.size.x if is_instance_valid(_prompt) else 0.0), float(s["h"]) + float(s["point"]) + ph)
		custom_minimum_size = full
		size = full
		if is_instance_valid(_prompt):
			_prompt.position = Vector2(roundf((full.x - _prompt.size.x) * 0.5), 0.0)
		queue_redraw()

	func show_on(on: bool) -> void:
		if on and not _want:
			_fit()
		_want = on
		if UI.instant:
			_a = 1.0 if on else 0.0
		visible = _a > 0.0 or on
		modulate.a = _a

	func _process(delta: float) -> void:
		var to := 1.0 if _want else 0.0
		if _a != to:
			_a = move_toward(_a, to, delta / 0.12)
			modulate.a = _a
			visible = _a > 0.0
		if is_instance_valid(_prompt) and _prompt.visible != (size.y > float(_sizes()["h"]) + float(_sizes()["point"]) + 1.0):
			_fit()

	func _draw() -> void:
		var s := _sizes()
		var h := float(s["h"])
		var pt := float(s["point"])
		var w := ceilf(_tw(UI.font_num, int(s["font"]), text) + float(s["pad"]) * 2.0 + (float(s["coin"]) * 2.0 + 3.0 if news else 0.0))
		var top := size.y - pt - h
		var pill := Rect2(roundf((size.x - w) * 0.5), top, w, h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.035, 0.06, 0.72)
		sb.set_corner_radius_all(int(s["radius"]))
		sb.border_color = Color(UI.C_BRASS, 0.5)
		sb.set_border_width_all(1)
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 4
		draw_style_box(sb, pill)
		var x := pill.position.x + float(s["pad"])
		if news:
			var cr := float(s["coin"])
			var cc := Vector2(pill.position.x + float(s["pad"]) * 0.6 + cr, pill.position.y + h * 0.5)
			draw_circle(cc, cr + 0.7, Color(UI.C_INK, 0.9), true, -1.0, true)
			draw_circle(cc, cr, UI.C_GOLD, true, -1.0, true)
			var fs := int(cr * 2.0)
			draw_string(UI.font_num, Vector2(cc.x - cr, cc.y + UI.font_num.get_ascent(fs) * 0.42), "!", HORIZONTAL_ALIGNMENT_CENTER, cr * 2.0, fs, UI.C_INK)
			x = cc.x + cr + 3.0
		var fsz := int(s["font"])
		var base := roundf(pill.position.y + h * 0.5 + UI.font_num.get_ascent(fsz) * 0.5 - 1.0)
		draw_string(UI.font_num, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UI.C_PARCH)
		var m := roundf(size.x * 0.5)
		var py := pill.end.y - 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(m - pt, py), Vector2(m + pt, py), Vector2(m, py + pt)]), Color(UI.C_BRASS, 0.75))


# ------------------------------------------------------------------ the news mark
## A gold coin (r 5.5; 3.5 on a phone) with an ink rim and an ink "!" (ExtraBold), bobbing 1.5 UI px.
## foe = true: the same in C_FOE (a roaming monster that has seen the knight).
## Its bottom-middle is the point placed over the head.
class NewsMark extends Base:
	var foe := false
	var _t := 0.0
	var _r := 5.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_r = 3.5 if UI.is_phone() else 5.5
		custom_minimum_size = Vector2(_r * 2.0 + 4.0, _r * 2.0 + 6.0)
		size = custom_minimum_size
		_t = randf() * 3.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		UI._load_fonts()
		var bob := 0.0 if UI.instant else sin(_t * 5.0) * 1.5
		var c := Vector2(size.x * 0.5, size.y - _r - 2.5 + bob)
		var body := UI.C_FOE if foe else UI.C_GOLD
		draw_circle(c + Vector2(0, 1.0), _r + 1.2, Color(0, 0, 0, 0.35), true, -1.0, true)
		draw_circle(c, _r + 1.0, Color(UI.C_INK, 0.9), true, -1.0, true)
		draw_circle(c, _r, body, true, -1.0, true)
		draw_arc(c, _r * 0.72, PI * 1.05, PI * 1.7, 8, Color(1, 1, 1, 0.45), 0.8, true)
		var fs := int(roundf(_r * 2.0))
		draw_string(UI.font_num, Vector2(c.x - _r, roundf(c.y + UI.font_num.get_ascent(fs) * 0.40)), "!", HORIZONTAL_ALIGNMENT_CENTER, _r * 2.0, fs, UI.C_INK)


# ------------------------------------------------------------------ the place banner
## The place's name on arrival: Cinzel caps (24 UI px; 13 on a phone) centred near the top with a
## gold lozenge either side on a two-sided wash band, a subtitle (body 11) under it. small = the
## same, smaller (Cinzel 16): "Night has fallen", "Morning". Shows `hold` s: 0.3 in, 0.5 out.
## Lay it over the whole screen (it ignores the mouse).
class Banner extends Base:
	var title := ""
	var sub := ""
	var small := false
	var _t := 0.0
	var _len := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_text(words: String, subtitle: String = "", is_small := false, hold := 2.2) -> void:
		title = words.to_upper()
		sub = subtitle
		small = is_small
		_t = 0.0
		_len = hold
		visible = true
		queue_redraw()

	func hide_now() -> void:
		_len = 0.0
		visible = false

	func _alpha() -> float:
		if UI.instant:
			return 1.0
		return clampf(_t / 0.3, 0.0, 1.0) * clampf((_len - _t) / 0.5, 0.0, 1.0)

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if _t >= _len and not UI.instant:
			visible = false
		queue_redraw()

	func _draw() -> void:
		UI._load_fonts()
		var ph := UI.is_phone()
		var a := _alpha()
		if a <= 0.0:
			return
		var W := size.x
		var fs := (11 if ph else 16) if small else (13 if ph else 24)
		var base := (36.0 if ph else (84.0 if W < 720.0 else 72.0)) - (4.0 if small else 0.0)
		base += (1.0 - clampf(_t / 0.3, 0.0, 1.0)) * 4.0 if not UI.instant else 0.0
		var half := (110.0 if ph else 190.0) * (0.75 if small else 1.0)
		var band_h := (26.0 if ph else 50.0) * (0.8 if small else 1.0)
		var top := base - (17.0 if ph else 26.0)
		var ci := get_canvas_item()
		UI.rs_hgrad(ci, Rect2(W * 0.5 - half, top, half, band_h), Color(UI.C_WASH, 0.0), Color(UI.C_WASH, 0.55 * a))
		UI.rs_hgrad(ci, Rect2(W * 0.5, top, half, band_h), Color(UI.C_WASH, 0.55 * a), Color(UI.C_WASH, 0.0))
		var head := UI.font_head
		var tw := _tw(head, fs, title)
		_say(self, head, fs, Vector2(roundf(W * 0.5 - tw * 0.5), base), title, Color(UI.C_PARCH, a), 3 if ph else 5)
		var mid := base - head.get_ascent(fs) * 0.36
		var lz := 2.0 if ph else 3.0
		var gap := (8.0 if ph else 13.0)
		var reach := (14.0 if ph else 26.0) * (0.7 if small else 1.0)
		for side: float in [-1.0, 1.0]:
			var at := Vector2(roundf(W * 0.5 + side * (tw * 0.5 + gap)), roundf(mid))
			UI.rs_lozenge(ci, at, lz, Color(UI.C_GOLD, a), 0.0)
			UI.rs_rule(ci, at + Vector2(side * (lz + 2.0), 0.5), at + Vector2(side * (lz + 2.0 + reach), 0.5), Color(UI.C_GOLD, 0.8 * a), Color(UI.C_GOLD, 0.0))
		if sub != "" and not small:
			var ss := 8 if ph else 11
			var sw := _tw(UI.font_body, ss, sub)
			_say(self, UI.font_body, ss, Vector2(roundf(W * 0.5 - sw * 0.5), base + (10.0 if ph else 16.0)), sub, Color(UI.C_DIM, a), 3)


# ------------------------------------------------------------------ the toast
## One small card bottom-centre (24 UI px tall, body 12; 16 / 9 on a phone): what a won fight paid,
## "The way is shut." Slides up 6 UI px as it comes, stays `hold` s, fades. A new one replaces the old.
class Toast extends Base:
	var _text := ""
	var _t := 0.0
	var _len := 0.0
	var _box: StyleBox

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_text(words: String, hold := 2.5) -> void:
		_text = words
		_t = 0.0
		_len = hold
		visible = true
		queue_redraw()

	func hide_now() -> void:
		visible = false

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if _t >= _len and not UI.instant:
			visible = false
		queue_redraw()

	func _draw() -> void:
		UI._load_fonts()
		if _box == null:
			_box = UI.box("card")
		var ph := UI.is_phone()
		var fs := 9 if ph else 12
		var h := 16.0 if ph else 24.0
		var a := 1.0 if UI.instant else clampf(_t / 0.2, 0.0, 1.0) * clampf((_len - _t) / 0.3, 0.0, 1.0)
		var rise := 0.0 if UI.instant else (1.0 - ease(clampf(_t / 0.25, 0.0, 1.0), 0.4)) * 6.0
		var maxw := size.x - 24.0
		var tw := minf(_tw(UI.font_body, fs, _text), maxw - 24.0)
		var w := ceilf(tw + (24.0 if ph else 40.0))
		var r := Rect2(roundf((size.x - w) * 0.5), size.y - h + rise, w, h)
		modulate.a = a
		draw_style_box(_box, r)
		var base := roundf(r.position.y + h * 0.5 + UI.font_body.get_ascent(fs) * 0.5 - 1.0)
		draw_string(UI.font_body, Vector2(r.position.x, base), _text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, UI.C_PARCH)


# ------------------------------------------------------------------ coins
## The coin disc (gold, r 5; 3.5 on a phone) and the number (ExtraBold 13; 9 on a phone) at the
## top-right corner on a wash that fades out to the left. Anchor it top-right; value = the coins.
class Coins extends Base:
	var value := -1:
		set(v):
			if v != value:
				value = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UI._load_fonts()
		var ph := UI.is_phone()
		var fs := 9 if ph else 13
		var r := 3.5 if ph else 5.0
		var ci := get_canvas_item()
		UI.rs_hgrad(ci, Rect2(Vector2.ZERO, size), Color(UI.C_WASH, 0.0), Color(UI.C_WASH, 0.55))
		var s := str(maxi(value, 0))
		var tw := _tw(UI.font_num, fs, s)
		var right := size.x - (8.0 if ph else 16.0)
		var cy := roundf(size.y * 0.5)
		var base := roundf(cy + UI.font_num.get_ascent(fs) * 0.5 - 1.0)
		_say(self, UI.font_num, fs, Vector2(right - tw, base), s, UI.C_PARCH, 3)
		var cc := Vector2(right - tw - r - (4.0 if ph else 6.0), cy)
		draw_circle(cc, r + 0.8, Color(UI.C_INK, 0.85), true, -1.0, true)
		draw_circle(cc, r, Color(0.95, 0.75, 0.3), true, -1.0, true)
		draw_circle(cc, r * 0.64, Color(1.0, 0.88, 0.5), true, -1.0, true)
		draw_arc(cc, r * 0.64, PI * 0.9, PI * 1.6, 8, Color(1, 1, 1, 0.5), 0.8, true)
