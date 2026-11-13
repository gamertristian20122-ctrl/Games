extends Node
## GUI mock (art direction, testing only): draws the planned HD interface over real game pictures,
## so the new look can be judged before the screens are rebuilt. Nothing here is used by the game.
##
## 1. Take a clean picture of the game with every 2D layer hidden (Forward+ is slow, one at a time):
##    xvfb-run -a -s "-screen 0 1600x720x24" godot --path . res://dev/gui_mock.tscn \
##        --rendering-method forward_plus --resolution 1600x720 -- \
##        --mockcap=/abs/bg_battle.png --mockwait=8 --battle=story:deepwood --night --nosave
##    (any game flags work: --hub=village --clock=0.7 for a walking place)
## 2. Draw the mock over it (fast, any renderer):
##    xvfb-run -a -s "-screen 0 1600x720x24" godot --path . res://dev/gui_mock.tscn \
##        --rendering-method gl_compatibility --resolution 1600x720 -- \
##        --mock=battle --mockbg=/abs/bg_battle.png --mockout=/abs/mock_battle.png
##    --mock=battle|talk|knight|walk|title   --uiphone (the phone's 400x180 grid)
##    --mockfonts=<dir> (where the OFL fonts are, if not yet in assets/fonts/hd/)

const UI = preload("res://scripts/ui/theme.gd")

# ------------------------------------------------------------------ the palette of the spec
const INK := Color(0.035, 0.045, 0.075)
const FILL_TOP := Color(0.085, 0.10, 0.16, 0.80)
const FILL_BOT := Color(0.03, 0.035, 0.06, 0.90)
const BRASS := Color(0.78, 0.62, 0.36)
const BRASS_DIM := Color(0.78, 0.62, 0.36, 0.45)
const GOLD := Color(0.96, 0.80, 0.47)
const EMBER := Color(1.0, 0.62, 0.26)
const PARCH := Color(0.95, 0.92, 0.85)
const DIM := Color(0.72, 0.70, 0.64)
const FAINT := Color(0.45, 0.44, 0.42)
const HP_A := Color(0.93, 0.36, 0.25)
const HP_B := Color(0.62, 0.13, 0.12)
const MP_A := Color(0.42, 0.70, 1.0)
const MP_B := Color(0.16, 0.32, 0.72)
const STEEL := Color(0.55, 0.72, 0.92)
const FOE := Color(0.92, 0.42, 0.30)

## Full menus over the world: the picture behind is softened, darkened and cooled (a code shader).
const BLUR_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = vec3(0.0);
	float n = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 6.0, 2.5).rgb;
			n += 1.0;
		}
	}
	c /= n;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(l), c, 0.55) * 0.42 + vec3(0.008, 0.012, 0.03);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(c, 1.0);
}
"""

var _layer: CanvasLayer
var _root: Control
var _p := 2.0                 ## screen pixels per UI pixel
var _phone := false
var font_body: Font
var font_bold: Font
var font_head: Font
var font_logo: Font


func _ready() -> void:
	if G.arg("mockcap") != "":
		_capture.call_deferred()
		return
	_setup_fonts()
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	_phone = G.flag("uiphone")
	_fit()
	_build.call_deferred()


# ------------------------------------------------------------------ capture
func _capture() -> void:
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(float(G.arg("mockwait", "8"))).timeout
	_hide_layers(get_tree().root)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(G.arg("mockcap"))
	print("[mock] saved ", G.arg("mockcap"))
	get_tree().quit()


func _hide_layers(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	for c in n.get_children():
		_hide_layers(c)


# ------------------------------------------------------------------ the UI grid
## PC: the UI is laid out on a grid about 360 UI pixels tall (twice as fine as the game's 180),
## each UI pixel a whole number of screen pixels where possible. Phone: the game's own grid.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var s := win.y / vp.y                  # screen px per game px
	if _phone:
		_p = s
	else:
		_p = maxf(1.0, roundf(win.y / 360.0 * 2.0) / 2.0)
	_layer.scale = Vector2.ONE * (_p / s)
	_root.position = Vector2.ZERO
	_root.size = win / _p


func _setup_fonts() -> void:
	var dirs: Array[String] = ["res://assets/fonts/hd/"]
	if G.arg("mockfonts") != "":
		dirs.push_front(G.arg("mockfonts"))
	font_body = _font(dirs, ["AlegreyaSans-Medium.ttf", "alegreyasans_AlegreyaSans-Medium.ttf"], 500)
	font_bold = _font(dirs, ["AlegreyaSans-ExtraBold.ttf", "alegreyasans_AlegreyaSans-ExtraBold.ttf"], 800)
	font_head = _font(dirs, ["Cinzel.ttf", "cinzel_Cinzel[wght].ttf"], 700)
	font_logo = load("res://assets/fonts/display.ttf")


func _font(dirs: Array[String], names: Array, weight: int) -> Font:
	for d: String in dirs:
		for n: String in names:
			var path := d.path_join(n)
			var f := FontFile.new()
			var ok := false
			if path.begins_with("res://"):
				if ResourceLoader.exists(path):
					f = load(path)
					ok = true
			elif FileAccess.file_exists(path):
				ok = f.load_dynamic_font(path) == OK
			if ok:
				f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
				f.hinting = TextServer.HINTING_LIGHT
				f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
				var v := FontVariation.new()
				v.base_font = f
				v.variation_opentype = {"wght": weight}
				v.opentype_features = {"lnum": 1, "tnum": 1}
				return v
	return ThemeDB.fallback_font


# ------------------------------------------------------------------ build
func _build() -> void:
	var bg_path := G.arg("mockbg")
	if bg_path != "":
		var img := Image.load_from_file(bg_path)
		var bg := TextureRect.new()
		bg.texture = ImageTexture.create_from_image(img)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size = _root.size
		_root.add_child(bg)
	if G.arg("mock", "battle") in ["knight", "pause"]:
		var veil := ColorRect.new()
		veil.size = _root.size
		var sh := Shader.new()
		sh.code = BLUR_CODE
		var mat := ShaderMaterial.new()
		mat.shader = sh
		veil.material = mat
		_root.add_child(veil)
	var canvas := MockCanvas.new()
	canvas.mock = self
	canvas.which = G.arg("mock", "battle")
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.size = _root.size
	_root.add_child(canvas)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := G.arg("mockout")
	if out != "":
		get_viewport().get_texture().get_image().save_png(out)
		print("[mock] saved ", out, "  ui grid ", _root.size, "  px ", _p)
		get_tree().quit()


## Every mock screen is drawn by hand on one Control (no real widgets: this is a picture).
class MockCanvas extends Control:
	var mock: Node
	var which := "battle"
	var t := 0.0

	func _draw() -> void:
		match which:
			"battle": mock.call("draw_battle", self)
			"target": mock.call("draw_target", self)
			"talk": mock.call("draw_talk", self)
			"knight": mock.call("draw_knight", self)
			"walk": mock.call("draw_walk", self)
			"title": mock.call("draw_title", self)


# ------------------------------------------------------------------ drawing kit (the spec's widgets)
## Cut-corner outline of a rect (corner cut c).
func _octa(r: Rect2, c: float) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])


func _vgrad(pts: PackedVector2Array, r: Rect2, top: Color, bot: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bot, clampf((q.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	return cols


func shadow(c: CanvasItem, r: Rect2, size := 10.0, alpha := 0.45) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.shadow_color = Color(0, 0, 0, alpha)
	sb.shadow_size = int(size)
	sb.shadow_offset = Vector2(0, 3)
	sb.set_corner_radius_all(4)
	c.draw_style_box(sb, r)


## THE PANEL: night glass (dark translucent gradient), a fine brass hairline, cut corners, a soft
## shadow, a faint sheen under the top edge and a small lozenge on the top edge.
func panel(c: CanvasItem, r: Rect2, ornament := true, edge := BRASS_DIM) -> void:
	shadow(c, r)
	var pts := _octa(r, 3.0)
	c.draw_polygon(pts, _vgrad(pts, r, FILL_TOP, FILL_BOT))
	var line := pts.duplicate()
	line.append(pts[0])
	c.draw_polyline(line, edge, 1.0, true)
	var inner := _octa(r.grow(-2.5), 2.0)
	inner.append(inner[0])
	c.draw_polyline(inner, Color(1, 1, 1, 0.045), 1.0, true)
	c.draw_line(Vector2(r.position.x + 6, r.position.y + 1.5), Vector2(r.end.x - 6, r.position.y + 1.5), Color(1, 0.95, 0.85, 0.08), 1.0)
	if ornament:
		lozenge(c, Vector2(r.position.x + r.size.x * 0.5, r.position.y), 3.0, BRASS)


func lozenge(c: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]), Color(INK, 0.95))
	var k := s - 1.0
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k), at + Vector2(-k, 0)]), col)
	# fading rules each side
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array([at + Vector2(side * (s + 2.0), 0), at + Vector2(side * (s + 22.0), 0)])
		c.draw_polyline_colors(pts, PackedColorArray([Color(col, 0.9), Color(col, 0.0)]), 1.0, true)


## Text over the world with no box: a soft dark wash that fades out to one side (or both).
func wash(c: CanvasItem, r: Rect2, from_left := true, alpha := 0.72) -> void:
	var a := Color(0.02, 0.025, 0.045, 0.0)
	var b := Color(0.02, 0.025, 0.045, alpha)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([a, b, b, a]) if from_left else PackedColorArray([b, a, a, b])
	c.draw_polygon(pts, cols)


func text(c: CanvasItem, f: Font, size: int, at: Vector2, s: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if width < 0.0 and align == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x -= tw(f, size, s)
		align = HORIZONTAL_ALIGNMENT_LEFT
	if outline > 0:
		c.draw_string_outline(f, at, s, align, width, size, outline, Color(0.01, 0.01, 0.03, 0.85))
	c.draw_string(f, at, s, align, width, size, col)


func tw(f: Font, size: int, s: String) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A bar: dark well, hairline, fill lit from the top, the pale part just lost, a gleam.
func bar(c: CanvasItem, r: Rect2, ratio: float, a: Color, b: Color, lost := 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.012, 0.02, 0.85)
	sb.set_corner_radius_all(int(ceilf(r.size.y * 0.5)))
	sb.border_color = Color(BRASS, 0.30)
	sb.set_border_width_all(1)
	sb.expand_margin_left = 1
	sb.expand_margin_right = 1
	sb.expand_margin_top = 1
	sb.expand_margin_bottom = 1
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)
	if lost > ratio:
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * lost, r.size.y)), Color(1.0, 0.9, 0.7, 0.75))
	var f := Rect2(r.position, Vector2(r.size.x * ratio, r.size.y))
	var pts := PackedVector2Array([f.position, Vector2(f.end.x, f.position.y), f.end, Vector2(f.position.x, f.end.y)])
	c.draw_polygon(pts, _vgrad(pts, f, a.lightened(0.15), b))
	c.draw_line(f.position + Vector2(0.5, 0.5), Vector2(f.end.x - 0.5, f.position.y + 0.5), Color(1, 1, 1, 0.35), 0.5)


## A key prompt: a small key cap with its letter (keyboard) or a round face button (pad).
func keycap(c: CanvasItem, at: Vector2, key: String) -> float:
	var w := maxf(tw(font_bold, 9, key) + 7.0, 12.0)
	var r := Rect2(at + Vector2(0, -9), Vector2(w, 12))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.88, 0.80, 0.92)
	sb.set_corner_radius_all(3)
	sb.border_color = Color(0.3, 0.26, 0.2)
	sb.border_width_bottom = 2
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)
	text(c, font_bold, 9, Vector2(r.position.x, r.position.y + 9), key, INK, HORIZONTAL_ALIGNMENT_CENTER, w)
	return w


## The bottom help strip: [key] what, [key] what ...
func helpbar(c: CanvasItem, pairs: Array, right := true, top := false) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	var total := 0.0
	for p: Array in pairs:
		total += maxf(tw(font_bold, 9, String(p[0])) + 7.0, 12.0) + 4.0 + tw(font_body, 10, String(p[1])) + 12.0
	var x := W - 14.0 - total if right else (W - total) * 0.5
	var y := 20.0 if top else H - 10.0
	wash(c, Rect2(x - 40, y - 13, total + 54, 18), true, 0.6)
	for p: Array in pairs:
		x += keycap(c, Vector2(x, y), String(p[0])) + 4.0
		text(c, font_body, 10, Vector2(x, y), String(p[1]), PARCH, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		x += tw(font_body, 10, String(p[1])) + 12.0


## The focus: a warm light sweeping in from the left under the row, gold text, and a small flame
## pointer that breathes. Hover = the same (the mouse moves the focus).
func focus_row(c: CanvasItem, r: Rect2) -> void:
	var a := Color(1.0, 0.62, 0.26, 0.34)
	var b := Color(1.0, 0.62, 0.26, 0.0)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	c.draw_polygon(pts, PackedColorArray([a, b, b, a]))
	c.draw_line(Vector2(r.position.x, r.position.y + 0.5), Vector2(r.end.x * 0.6 + r.position.x * 0.4, r.position.y + 0.5), Color(GOLD, 0.55), 1.0)
	c.draw_line(Vector2(r.position.x, r.end.y - 0.5), Vector2(r.end.x * 0.6 + r.position.x * 0.4, r.end.y - 0.5), Color(GOLD, 0.35), 1.0)
	flame(c, Vector2(r.position.x - 5.0, r.position.y + r.size.y * 0.5))


func flame(c: CanvasItem, at: Vector2) -> void:
	# a small pointed ember: a lozenge stretched sideways, hot core
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(0, -3.5), at + Vector2(5, 0), at + Vector2(0, 3.5)]), Color(INK, 0.9))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(0, -2.5), at + Vector2(4, 0), at + Vector2(0, 2.5)]), EMBER)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-1, 0), at + Vector2(0.5, -1.2), at + Vector2(2.2, 0), at + Vector2(0.5, 1.2)]), Color(1, 0.95, 0.75))


var _imgs := {}
func _face_img(id: String) -> Array:
	if not _imgs.has(id):
		var img := Art.tex(id).get_image()
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		_imgs[id] = [ImageTexture.create_from_image(img), used, img.get_size()]
	return _imgs[id]


## A round portrait coin: the top of the fighter's sprite, a dark rim, a coloured ring for the side.
func medallion(c: CanvasItem, at: Vector2, rad: float, id: String, ring: Color, active := false) -> void:
	if active:
		for i in 5:
			c.draw_circle(at, rad + 2.0 + i * 1.6, Color(EMBER, 0.10 - i * 0.018))
	c.draw_circle(at, rad + 1.5, Color(INK, 0.95))
	c.draw_circle(at, rad, Color(0.12, 0.13, 0.18))
	var fi := _face_img(id)
	var tex: Texture2D = fi[0]
	var used: Rect2i = fi[1]
	var full: Vector2 = Vector2(fi[2])
	var side := minf(used.size.x, used.size.y * 0.62)
	var reg := Rect2(used.position.x + (used.size.x - side) * 0.5, used.position.y - side * 0.08, side, side)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 32:
		var ang := TAU * i / 32.0
		var d := Vector2(cos(ang), sin(ang))
		pts.append(at + d * (rad - 0.5))
		uvs.append((reg.position + (d * 0.5 + Vector2(0.5, 0.5)) * reg.size) / full)
		cols.append(Color.WHITE)
	c.draw_polygon(pts, cols, uvs, tex)
	c.draw_arc(at, rad, 0, TAU, 40, ring, 1.6 if active else 1.0, true)
	if active:
		c.draw_arc(at, rad + 2.0, 0, TAU, 40, Color(GOLD, 0.8), 1.0, true)


func sprite(c: CanvasItem, id: String, center_bottom: Vector2, k: float, flip := false) -> void:
	var fi := _face_img(id)
	var used: Rect2i = fi[1]
	var dst := Rect2(center_bottom - Vector2(used.size.x * k * 0.5, used.size.y * k), Vector2(used.size) * k)
	if flip:
		dst.size.x = -dst.size.x
		dst.position.x -= dst.size.x
	c.draw_texture_rect_region(fi[0], dst, Rect2(used))


func icon(c: CanvasItem, path: String, r: Rect2, mod := Color.WHITE) -> void:
	var t: Texture2D = Art.tex(path.get_file().get_basename())
	c.draw_texture_rect(t, r, false, mod)


# ------------------------------------------------------------------ the mock screens
const FOES_AT := [[Vector2(0.650, 0.535), "pc_elf_ranger", "Elf Stalker"], [Vector2(0.738, 0.520), "pc_elf_hunter", "Wood Beast"],
	[Vector2(0.812, 0.495), "pc_elf_ranger", "Elf Stalker"], [Vector2(0.930, 0.420), "pc_fungus_long", "Long Cap"]]


func _party_cards(c: CanvasItem, W: float, H: float, acting: int, menu_w: float) -> void:
	var rows := [["Aldous", 4, 46, 46, 14, 20, "pc_knight"], ["Thessaly", 3, 21, 38, 18, 18, "pc_elf_ranger"], ["Seraphine", 3, 30, 30, 9, 24, "pc_scholar_censor"]]
	var n := rows.size() if not G.flag("two") else 2
	var gap := 6.0
	var cw := clampf((W - 28.0 - menu_w - 16.0 - gap * (n - 1)) / n, 120.0, 176.0)
	var ch := 44.0
	var x := W - 14.0 - n * cw - gap * (n - 1)
	for i in n:
		var r: Array = rows[i]
		var up := 6.0 if i == acting else 0.0
		var card := Rect2(x, H - 14.0 - ch - up, cw, ch)
		if i == acting:
			for k in 4:
				c.draw_rect(Rect2(card.position.x + 6 + k * 4, card.end.y - 2, cw - 12 - k * 8, 6 + k * 3), Color(EMBER, 0.05))
		panel(c, card, false, GOLD if i == acting else BRASS_DIM)
		var y := card.position.y
		medallion(c, Vector2(x + 17, y + 22), 11.0, String(r[6]), STEEL, i == acting)
		text(c, font_bold, 12, Vector2(x + 34, y + 15), String(r[0]), GOLD if i == acting else PARCH)
		text(c, font_body, 9, Vector2(x + cw - 9, y + 15), "Lv %d" % int(r[1]), DIM, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		var bx := x + 34.0
		var bw := cw - 34.0 - 9.0
		var hw := floorf(bw * 0.6)
		var low := float(r[2]) / float(r[3]) < 0.6
		text(c, font_bold, 8, Vector2(bx, y + 29), "HP", DIM)
		text(c, font_bold, 12, Vector2(bx + hw, y + 29), "%d" % int(r[2]), Color(1.0, 0.72, 0.55) if low else PARCH, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		bar(c, Rect2(bx, y + 32, hw, 4), float(r[2]) / float(r[3]), HP_A, HP_B, 0.72 if low else 0.0)
		var mx := bx + hw + 6.0
		var mw := bw - hw - 6.0
		text(c, font_bold, 8, Vector2(mx, y + 29), "MP", DIM)
		text(c, font_bold, 12, Vector2(mx + mw, y + 29), "%d" % int(r[4]), PARCH, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		bar(c, Rect2(mx, y + 32, mw, 4), float(r[4]) / float(r[5]), MP_A, MP_B)
		x += cw + gap


func _turn_rail(c: CanvasItem) -> void:
	var line := [["pc_knight", STEEL], ["pc_elf_ranger", FOE], ["pc_elf_ranger", STEEL], ["pc_elf_hunter", FOE], ["pc_fungus_long", FOE], ["pc_elf_ranger", FOE]]
	var x0 := 28.0
	var y := 26.0
	wash(c, Rect2(0, 0, 230, 52), false, 0.55)
	c.draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + 175, y)]), PackedColorArray([Color(BRASS, 0.8), Color(BRASS, 0.0)]), 1.0)
	var x := x0
	for i in line.size():
		var rad := 13.0 if i == 0 else 9.0
		var id := String(line[i][0])
		if not Art.has(id):
			id = "pc_" + id
		medallion(c, Vector2(x, y), rad, id if Art.has(id) else "pc_knight", line[i][1], i == 0)
		x += (rad + 9.0 + 13.0) if i == 0 else 22.0
	text(c, font_head, 8, Vector2(x0 - 13, y + 24), "ROUND 2", DIM)


func _foe_tags(c: CanvasItem, W: float, H: float, target: int) -> void:
	for i in FOES_AT.size():
		var at: Vector2 = FOES_AT[i][0] * Vector2(W, H)
		if i == target:
			continue
		bar(c, Rect2(at.x - 16, at.y - 6, 32, 3), [1.0, 0.55, 1.0, 0.8][i], HP_A, HP_B)


func draw_battle(c: CanvasItem) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	if _phone:
		_phone_battle(c, W, H)
		return
	var mw := 148.0 if not _phone else 120.0
	_turn_rail(c)
	_foe_tags(c, W, H, -1)
	_party_cards(c, W, H, 0, mw)
	# the order list, bottom left: the skills page has taken the commands' place (Esc goes back)
	var skills := [["Firebolt", 6, "skill_firebolt", true], ["Frost Lance", 5, "skill_frost", true],
		["Storm Call", 9, "skill_storm", true], ["Mend", 16, "skill_mend", false]]
	if G.flag("commands"):
		skills = [["Attack", -1, "icon_gilded_blade", true], ["Skills", -1, "skill_firebolt", true], ["Guard", -1, "gear_helm_warden", true], ["Flee", -1, "icon_swift_tonic", true]]
	var rh := 19.0
	var desc := wrap_words(font_body, 10, "A bolt of fire at one foe. It burns.", mw - 20.0)
	var ph := 26.0 + skills.size() * rh + 8.0 + (desc.size() * 12.0 + 8.0 if not G.flag("commands") else 0.0)
	var p := Rect2(14, H - 14 - ph, mw, ph)
	panel(c, p)
	if G.flag("commands"):
		text(c, font_head, 12, Vector2(p.position.x + 12, p.position.y + 18), "ALDOUS", GOLD)
	else:
		text(c, font_head, 11, Vector2(p.position.x + 12, p.position.y + 18), "SKILLS", GOLD)
		text(c, font_bold, 10, Vector2(p.end.x - 10, p.position.y + 18), "MP 14", MP_A, HORIZONTAL_ALIGNMENT_RIGHT, -1)
	var y := p.position.y + 24.0
	var focus := 1 if G.flag("commands") else 0
	for i in skills.size():
		var rr := Rect2(p.position.x + 4, y, mw - 8, rh)
		var can: bool = skills[i][3]
		if i == focus:
			focus_row(c, rr)
		icon(c, String(skills[i][2]), Rect2(rr.position.x + 6, y + 1.5, 16, 16), Color.WHITE if can else Color(0.45, 0.45, 0.48, 0.7))
		text(c, font_body, 12, Vector2(rr.position.x + 28, y + 14), String(skills[i][0]), GOLD if i == focus else (PARCH if can else FAINT))
		if int(skills[i][1]) >= 0:
			text(c, font_bold, 11, Vector2(rr.end.x - 8, y + 14), "%d" % int(skills[i][1]), MP_A if can else FAINT, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		y += rh
	if not G.flag("commands"):
		c.draw_line(Vector2(p.position.x + 10, y + 4), Vector2(p.end.x - 10, y + 4), Color(BRASS, 0.25), 1.0)
		y += 6.0
		for l: String in desc:
			y += 12.0
			text(c, font_body, 10, Vector2(p.position.x + 12, y), l, DIM)
	helpbar(c, [["Enter", "Choose"], ["Esc", "Back"]], true, true)


func draw_target(c: CanvasItem) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	_turn_rail(c)
	var t := 1
	_foe_tags(c, W, H, t)
	_party_cards(c, W, H, 0, 148.0)
	# the brackets round the target, its name plate and its bar
	var at: Vector2 = FOES_AT[t][0] * Vector2(W, H)
	var box := Rect2(at.x - 22, at.y - 2, 44, 62)
	var k := 6.0
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var sx := 1.0 if corner.x == box.position.x else -1.0
		var sy := 1.0 if corner.y == box.position.y else -1.0
		c.draw_polyline(PackedVector2Array([corner + Vector2(0, sy * k), corner, corner + Vector2(sx * k, 0)]), Color(INK, 0.8), 3.0)
		c.draw_polyline(PackedVector2Array([corner + Vector2(0, sy * k), corner, corner + Vector2(sx * k, 0)]), GOLD, 1.4)
	var name := String(FOES_AT[t][2])
	var nw := tw(font_head, 11, name.to_upper()) + 24.0
	var plate := Rect2(at.x - nw * 0.5, at.y - 34, nw, 26)
	panel(c, plate, false, Color(FOE, 0.7))
	text(c, font_head, 11, Vector2(plate.position.x, plate.position.y + 13), name.to_upper(), PARCH, HORIZONTAL_ALIGNMENT_CENTER, nw)
	bar(c, Rect2(plate.position.x + 8, plate.position.y + 17, nw - 16, 3), 0.55, HP_A, HP_B, 0.7)
	# the order being aimed, top middle
	var title := "FIREBOLT"
	var ww := tw(font_head, 13, title) + 120.0
	wash(c, Rect2(W * 0.5 - ww * 0.5, 14, ww * 0.5, 22), true, 0.7)
	wash(c, Rect2(W * 0.5, 14, ww * 0.5, 22), false, 0.7)
	text(c, font_head, 13, Vector2(W * 0.5 - 100, 30), title, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 200)
	lozenge(c, Vector2(W * 0.5 - tw(font_head, 13, title) * 0.5 - 12, 25), 2.5, BRASS)
	lozenge(c, Vector2(W * 0.5 + tw(font_head, 13, title) * 0.5 + 12, 25), 2.5, BRASS)
	helpbar(c, [["<  >", "Target"], ["Enter", "Cast"], ["Esc", "Back"]], true, true)
	# a damage number as it pops (the look of anim_numbers)
	var foe0: Vector2 = FOES_AT[0][0] * Vector2(W, H)
	text(c, font_bold, 22, Vector2(foe0.x - 30, foe0.y + 8), "37", Color(1.0, 0.86, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 60, 5)
	text(c, font_head, 8, Vector2(foe0.x - 30, foe0.y - 12), "CRITICAL", EMBER, HORIZONTAL_ALIGNMENT_CENTER, 60, 4)


## Wraps words into lines no wider than w.
func wrap_words(f: Font, size: int, s: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if tw(f, size, t) > w and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


func draw_talk(c: CanvasItem) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	if _phone:
		_phone_talk(c, W, H)
		return
	# a soft dark fall-off along the bottom (as today), then the box
	c.draw_polygon(PackedVector2Array([Vector2(0, H * 0.55), Vector2(W, H * 0.55), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.01, 0.03, 0.55), Color(0.01, 0.01, 0.03, 0.55)]))
	var bw := minf(W - 40.0, 600.0)
	var bh := 92.0 if not _phone else 62.0
	var box := Rect2((W - bw) * 0.5, H - bh - 14.0, bw, bh)
	panel(c, box, false)
	# the portrait: a bust of the speaker at a whole 3 UI px per art pixel, in a lit well at the box's left end
	var pr := Rect2(box.position.x + 6, box.position.y + 6, 86, bh - 12)
	c.draw_rect(pr, Color(0.0, 0.0, 0.02, 0.35))
	for i in 7:
		c.draw_circle(Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + pr.size.y * 0.42), 40.0 - i * 5.0, Color(1.0, 0.72, 0.42, 0.035))
	var fi := _face_img("pc_royal_knight")
	var used: Rect2i = fi[1]
	var k := 3.0 if not _phone else 2.0
	var rows_shown := floorf(pr.size.y / k)
	var src := Rect2(used.position.x, used.position.y, used.size.x, minf(used.size.y, rows_shown))
	var dst := Rect2(pr.position.x + (pr.size.x - used.size.x * k) * 0.5, pr.end.y - src.size.y * k, used.size.x * k, src.size.y * k)
	c.draw_texture_rect_region(fi[0], dst, src)
	c.draw_polyline_colors(PackedVector2Array([Vector2(pr.end.x + 4, pr.position.y), Vector2(pr.end.x + 4, pr.end.y)]), PackedColorArray([Color(BRASS, 0.0), Color(BRASS, 0.45)]), 1.0)
	# name plate on the top edge
	var name := "Captain Hale"
	var role := "Captain of the Lantern Watch"
	var nw := tw(font_head, 13, name.to_upper()) + tw(font_body, 10, role) + 40.0
	var plate := Rect2(box.position.x + 100, box.position.y - 13, nw, 22)
	panel(c, plate, false, BRASS)
	text(c, font_head, 13, Vector2(plate.position.x + 12, plate.position.y + 16), name.to_upper(), GOLD)
	text(c, font_body, 10, Vector2(plate.position.x + 22 + tw(font_head, 13, name.to_upper()), plate.position.y + 16), role, DIM)
	# the words (the page being typed: the last word half out)
	var words := "Then you know what broke. The crown is in four pieces and the beacons are cold. We burn lamps here from dusk to dawn, and dusk comes earlier every week."
	var tx := box.position.x + 108.0
	var lines := wrap_words(font_body, 14, words, box.end.x - tx - 24.0)
	var y := box.position.y + 30.0
	for l: String in lines:
		text(c, font_body, 14, Vector2(tx, y), l, PARCH)
		y += 18.0
	# next arrow and the page dots
	var a := Vector2(box.end.x - 16, box.end.y - 12)
	c.draw_colored_polygon(PackedVector2Array([a + Vector2(-4, -2), a + Vector2(4, -2), a + Vector2(0, 3)]), EMBER)
	for i in 4:
		c.draw_circle(Vector2(box.end.x - 60 + i * 7, box.end.y - 10), 1.6, GOLD if i == 1 else Color(DIM, 0.5))
	# the choices, standing on the box's right end
	var opts := ["Go east to the Elfwood", "Tell me about the beacons", "Not yet"]
	var ow := 190.0
	var oh := 14.0 + opts.size() * 20.0
	var o := Rect2(box.end.x - ow - 8, box.position.y - oh - 18, ow, oh)
	panel(c, o)
	var oy := o.position.y + 8.0
	for i in opts.size():
		var rr := Rect2(o.position.x + 4, oy, ow - 8, 19)
		if i == 0:
			focus_row(c, rr)
		text(c, font_body, 12, Vector2(rr.position.x + 12, oy + 14), opts[i], GOLD if i == 0 else PARCH)
		oy += 20.0
	helpbar(c, [["Enter", "Next"], ["Esc", "Leave"]])


func draw_walk(c: CanvasItem) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	# the story line, top left: no box, a wash and a small heading
	wash(c, Rect2(0, 0, 330, 66), false, 0.80)
	text(c, font_head, 9, Vector2(16, 18), "CHAPTER ONE  ·  THE ELFWOOD", Color(BRASS, 0.95))
	c.draw_polyline_colors(PackedVector2Array([Vector2(16, 23), Vector2(200, 23)]), PackedColorArray([Color(BRASS, 0.6), Color(BRASS, 0.0)]), 1.0)
	lozenge(c, Vector2(12, 34), 2.5, GOLD)
	text(c, font_body, 13, Vector2(20, 39), "Find Captain Hale in the square", PARCH, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	text(c, font_body, 13, Vector2(20, 53), "of Wickmere", PARCH, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	# coins, top right
	wash(c, Rect2(W - 120, 0, 120, 30), true, 0.55)
	c.draw_circle(Vector2(W - 60, 16), 5.0, Color(0.95, 0.75, 0.3))
	c.draw_circle(Vector2(W - 60, 16), 3.2, Color(1.0, 0.88, 0.5))
	text(c, font_bold, 13, Vector2(W - 50, 21), "120", PARCH, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	# the place's name as you arrive (top middle)
	var name := "WICKMERE"
	wash(c, Rect2(W * 0.5 - 190, 46, 190, 50), true, 0.55)
	wash(c, Rect2(W * 0.5, 46, 190, 50), false, 0.55)
	text(c, font_head, 24, Vector2(W * 0.5 - 200, 72), name, PARCH, HORIZONTAL_ALIGNMENT_CENTER, 400, 6)
	var nw := tw(font_head, 24, name)
	lozenge(c, Vector2(W * 0.5 - nw * 0.5 - 14, 64), 3.0, GOLD)
	lozenge(c, Vector2(W * 0.5 + nw * 0.5 + 14, 64), 3.0, GOLD)
	text(c, font_body, 11, Vector2(W * 0.5 - 200, 88), "The lantern town under Hollow Hill", DIM, HORIZONTAL_ALIGNMENT_CENTER, 400, 3)
	# a name tag with the talk prompt over the nearest person
	var at := Vector2(float(G.arg("tagx", "0.565")) * W, float(G.arg("tagy", "0.36")) * H)
	var who := "Captain Hale"
	var w := tw(font_bold, 11, who) + 16.0
	var tag := Rect2(at.x - w * 0.5, at.y - 18, w, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.06, 0.72)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(BRASS, 0.5)
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	c.draw_style_box(sb, tag)
	text(c, font_bold, 11, Vector2(tag.position.x, tag.position.y + 12), who, PARCH, HORIZONTAL_ALIGNMENT_CENTER, w)
	c.draw_colored_polygon(PackedVector2Array([Vector2(at.x - 3, at.y - 2), Vector2(at.x + 3, at.y - 2), Vector2(at.x, at.y + 1)]), Color(BRASS, 0.7))
	var kx := at.x - 22.0
	kx += keycap(c, Vector2(kx, at.y - 24), "Q") + 4.0
	text(c, font_body, 10, Vector2(kx, at.y - 24), "Talk", PARCH, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	# a news mark over another person
	var m := Vector2(float(G.arg("markx", "0.33")) * W, float(G.arg("marky", "0.30")) * H)
	c.draw_circle(m, 6.5, Color(INK, 0.8))
	c.draw_circle(m, 5.5, Color(GOLD, 0.95))
	text(c, font_bold, 11, Vector2(m.x - 5, m.y + 4), "!", INK, HORIZONTAL_ALIGNMENT_CENTER, 10)
	# a toast: what a won fight paid, bottom middle
	var toast := "Won: +38 XP, 12 coins"
	var tww := tw(font_body, 12, toast) + 40.0
	panel(c, Rect2(W * 0.5 - tww * 0.5, H - 46, tww, 24), false)
	text(c, font_body, 12, Vector2(W * 0.5 - tww * 0.5, H - 29), toast, PARCH, HORIZONTAL_ALIGNMENT_CENTER, tww)
	helpbar(c, [["C", "Knight"], ["Esc", "Pause"]])


func draw_knight(c: CanvasItem) -> void:
	var W: float = c.get_rect().size.x
	var H: float = c.get_rect().size.y
	# the world stays behind, dimmed and cooled
	wash(c, Rect2(0, 0, W * 0.4, H), false, 0.35)
	# header: name, level, tabs
	text(c, font_head, 20, Vector2(24, 36), "ALDOUS", PARCH)
	text(c, font_body, 11, Vector2(28 + tw(font_head, 20, "ALDOUS"), 36), "The Last Knight  ·  Level 4", DIM)
	var tabs := ["Stats", "Gear", "Skills", "Party"]
	var tx := W - 24.0
	for i in range(tabs.size() - 1, -1, -1):
		var ww := tw(font_head, 11, tabs[i].to_upper())
		tx -= ww
		text(c, font_head, 11, Vector2(tx, 34), tabs[i].to_upper(), GOLD if i == 0 else DIM)
		if i == 0:
			c.draw_line(Vector2(tx - 2, 40), Vector2(tx + ww + 2, 40), GOLD, 1.5)
			lozenge(c, Vector2(tx + ww * 0.5, 40), 2.0, GOLD)
		tx -= 22.0
	keycap(c, Vector2(tx - 6, 34), "Q")
	keycap(c, Vector2(W - 20, 34), "E")
	c.draw_polyline_colors(PackedVector2Array([Vector2(24, 48), Vector2(W * 0.5, 48), Vector2(W - 24, 48)]), PackedColorArray([Color(BRASS, 0.0), Color(BRASS, 0.6), Color(BRASS, 0.0)]), 1.0)
	# the knight on a soft lit plinth
	var px := 24.0 + (W * 0.28) * 0.5
	for i in 8:
		c.draw_circle(Vector2(px, 200), 70.0 - i * 8.0, Color(1.0, 0.72, 0.42, 0.03))
	c.draw_set_transform(Vector2(px, 236), 0, Vector2(1, 0.28))
	c.draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.35))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	sprite(c, "pc_knight", Vector2(px, 238), 3.0 if not _phone else 2.0)
	text(c, font_head, 9, Vector2(px - 60, 262), "EXPERIENCE", DIM, HORIZONTAL_ALIGNMENT_CENTER, 120)
	bar(c, Rect2(px - 60, 268, 120, 4), 0.62, Color(0.98, 0.8, 0.4), Color(0.7, 0.45, 0.15))
	text(c, font_body, 10, Vector2(px - 60, 284), "124 / 200 to level 5", DIM, HORIZONTAL_ALIGNMENT_CENTER, 120)
	# the list: stats
	var lx := W * 0.29
	var lw := W * 0.34
	var rows := [["Strength", 6, "+5% damage a point"], ["Vitality", 4, ""], ["Spirit", 3, ""], ["Agility", 2, ""]]
	var y := 70.0
	text(c, font_head, 10, Vector2(lx, y), "ATTRIBUTES", DIM)
	text(c, font_body, 11, Vector2(lx + lw, y), "3 points to spend", GOLD, HORIZONTAL_ALIGNMENT_RIGHT, -1)
	y += 10.0
	for i in rows.size():
		var rr := Rect2(lx, y, lw, 24)
		if i == 0:
			focus_row(c, rr)
		else:
			c.draw_line(Vector2(lx, y + 24), Vector2(lx + lw, y + 24), Color(1, 1, 1, 0.05), 1.0)
		text(c, font_body, 13, Vector2(lx + 10, y + 17), String(rows[i][0]), GOLD if i == 0 else PARCH)
		text(c, font_bold, 14, Vector2(lx + lw - 30, y + 17), str(rows[i][1]), PARCH, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		var plus := Rect2(lx + lw - 22, y + 5, 15, 15)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(EMBER, 0.85) if i == 0 else Color(0.1, 0.1, 0.14, 0.8)
		sb.set_corner_radius_all(3)
		sb.border_color = Color(BRASS, 0.6)
		sb.set_border_width_all(1)
		sb.anti_aliasing = true
		c.draw_style_box(sb, plus)
		text(c, font_bold, 12, Vector2(plus.position.x, plus.position.y + 12), "+", INK if i == 0 else PARCH, HORIZONTAL_ALIGNMENT_CENTER, 15)
		y += 26.0
	y += 8.0
	text(c, font_head, 10, Vector2(lx, y + 6), "IN BATTLE", DIM)
	y += 14.0
	var bat := [["Health", "46"], ["Mana", "20"], ["Attack", "14"], ["Defence", "9"], ["Speed", "11"]]
	for i in bat.size():
		var cx := lx + (i % 2) * lw * 0.5
		var cy := y + floorf(i / 2.0) * 16.0
		text(c, font_body, 11, Vector2(cx + 10, cy + 12), String(bat[i][0]), DIM)
		text(c, font_bold, 12, Vector2(cx + lw * 0.5 - 12, cy + 12), String(bat[i][1]), PARCH, HORIZONTAL_ALIGNMENT_RIGHT, -1)
	# the detail card on the right
	var d := Rect2(W * 0.67, 66, W * 0.33 - 24, 150)
	panel(c, d)
	text(c, font_head, 13, Vector2(d.position.x + 12, d.position.y + 24), "STRENGTH", GOLD)
	var lines := wrap_words(font_body, 12, "Each point makes every blow and every sword skill land 5% harder.", d.size.x - 24)
	var dy := d.position.y + 44.0
	for l: String in lines:
		text(c, font_body, 12, Vector2(d.position.x + 12, dy), l, PARCH)
		dy += 15.0
	text(c, font_body, 11, Vector2(d.position.x + 12, dy + 10), "Now: +30% damage", DIM)
	text(c, font_body, 11, Vector2(d.position.x + 12, dy + 25), "Next point: +35%", Color(0.6, 0.9, 0.55))
	helpbar(c, [["Enter", "Add a point"], ["Q / E", "Page"], ["Esc", "Close"]])



# ------------------------------------------------------------------ the phone (400 x 180 UI grid, touch first)
## Same materials, smaller type (body 9, names 9 bold, heads 9), and layouts made of big touch targets
## (rows at least 20 UI px = 120 screen px on a 1080-high phone). No key prompts on touch.
func _phone_battle(c: CanvasItem, W: float, H: float) -> void:
	# turn order: small coins, top left
	var line := [["pc_knight", STEEL], ["pc_elf_ranger", FOE], ["pc_elf_ranger", STEEL], ["pc_elf_hunter", FOE], ["pc_fungus_long", FOE]]
	var x := 14.0
	wash(c, Rect2(0, 0, 120, 26), false, 0.5)
	for i in line.size():
		var rad := 8.0 if i == 0 else 6.0
		medallion(c, Vector2(x, 13), rad, String(line[i][0]), line[i][1], i == 0)
		x += (rad + 10.0) if i == 0 else 14.0
	# your side: one thin strip each, top right (name, HP and MP bars, the HP number)
	var rows := [["Aldous", 46, 46, 14, 20], ["Thessaly", 21, 38, 18, 18], ["Seraphine", 30, 30, 9, 24]]
	var y := 4.0
	for i in rows.size():
		var r: Array = rows[i]
		var strip := Rect2(W - 136, y, 132, 17)
		wash(c, Rect2(strip.position.x - 20, y, strip.size.x + 20, 17), true, 0.8 if i == 0 else 0.62)
		if i == 0:
			c.draw_line(Vector2(strip.position.x - 2, y + 2), Vector2(strip.position.x - 2, y + 15), EMBER, 1.5)
		text(c, font_bold, 8, Vector2(strip.position.x + 2, y + 11), String(r[0]), GOLD if i == 0 else PARCH)
		bar(c, Rect2(strip.position.x + 50, y + 5, 46, 3), float(r[1]) / float(r[2]), HP_A, HP_B)
		bar(c, Rect2(strip.position.x + 50, y + 10, 46, 2), float(r[3]) / float(r[4]), MP_A, MP_B)
		text(c, font_bold, 8, Vector2(strip.end.x - 2, y + 11), "%d" % int(r[1]), PARCH, HORIZONTAL_ALIGNMENT_RIGHT, -1)
		y += 19.0
	# the orders: a 2 x 2 block of big touch tiles, bottom right (the thumb's corner)
	var names := [["Attack", "icon_gilded_blade"], ["Skills", "skill_firebolt"], ["Guard", "gear_helm_warden"], ["Flee", "icon_swift_tonic"]]
	var tw_ := 62.0
	var th := 22.0
	var ox := W - 8.0 - tw_ * 2 - 4
	var oy := H - 8.0 - th * 2 - 4
	for i in 4:
		var tr := Rect2(ox + (i % 2) * (tw_ + 4), oy + floorf(i / 2.0) * (th + 4), tw_, th)
		panel(c, tr, false, GOLD if i == 0 else BRASS_DIM)
		if i == 0:
			focus_row(c, tr.grow(-2))
		icon(c, String(names[i][1]), Rect2(tr.position.x + 5, tr.position.y + 3, 16, 16))
		text(c, font_body, 9, Vector2(tr.position.x + 24, tr.position.y + 14), String(names[i][0]), GOLD if i == 0 else PARCH)
	text(c, font_head, 8, Vector2(ox, oy - 5), "ALDOUS", GOLD)


func _phone_talk(c: CanvasItem, W: float, H: float) -> void:
	var box := Rect2(8, H - 58, W - 16, 52)
	panel(c, box, false)
	var pr := Rect2(box.position.x + 4, box.position.y + 4, 40, box.size.y - 8)
	var fi := _face_img("pc_royal_knight")
	var used: Rect2i = fi[1]
	var src := Rect2(used.position.x, used.position.y, used.size.x, minf(used.size.y, pr.size.y / 2.0))
	c.draw_texture_rect_region(fi[0], Rect2(pr.position.x + (pr.size.x - used.size.x * 2.0) * 0.5, pr.end.y - src.size.y * 2.0, used.size.x * 2.0, src.size.y * 2.0), src)
	var plate := Rect2(box.position.x + 50, box.position.y - 9, tw(font_head, 9, "CAPTAIN HALE") + 16, 14)
	panel(c, plate, false, BRASS)
	text(c, font_head, 9, Vector2(plate.position.x + 8, plate.position.y + 10), "CAPTAIN HALE", GOLD)
	var lines := wrap_words(font_body, 10, "Then you know what broke. The crown is in four pieces and the beacons are cold. We burn lamps here from dusk to dawn.", box.end.x - box.position.x - 66)
	var y := box.position.y + 18.0
	for l: String in lines:
		text(c, font_body, 10, Vector2(box.position.x + 52, y), l, PARCH)
		y += 12.0
	var opts := ["Go east to the Elfwood", "Not yet"]
	var o := Rect2(W - 148, box.position.y - 62, 140, 50)
	panel(c, o, false)
	for i in opts.size():
		var rr := Rect2(o.position.x + 3, o.position.y + 3 + i * 22, o.size.x - 6, 21)
		if i == 0:
			focus_row(c, rr)
		text(c, font_body, 10, Vector2(rr.position.x + 8, rr.position.y + 14), opts[i], GOLD if i == 0 else PARCH)
