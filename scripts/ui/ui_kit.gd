class_name UiKit
## Shared helpers so every menu and label looks the same.

const FONT_SMALL_PATH := "res://assets/kenney_fonts/kenney_mini.ttf"         # sharp at size 8 and 16
const FONT_SQUARE_PATH := "res://assets/kenney_fonts/kenney_mini_square.ttf" # capitals, sharp at 8 and 16

static var _fonts: Dictionary = {}


## Loads a font and switches off smoothing so the pixels stay crisp.
static func font(path: String) -> FontFile:
	if not _fonts.has(path):
		var f := load(path) as FontFile
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[path] = f
	return _fonts[path]


## Lets go of the loaded fonts (called when the game closes).
static func forget() -> void:
	_fonts.clear()


## A line of text. Sizes 8 and 16 are the sharp ones for the small font.
static func label(text: String, size: int = 8, color: Color = Pal.PAPER, font_path: String = FONT_SMALL_PATH) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A flat box with a one-pixel border.
static func box(fill: Color = Pal.INK_SOFT, border: Color = Pal.DIM, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.anti_aliasing = false
	return s


static func panel(fill: Color = Pal.INK_SOFT, border: Color = Pal.DIM) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(fill, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## One picture from the sprite sheet, for menus.
static func icon(cell: Vector2i, color: Color = Pal.PAPER, scale: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.atlas(cell)
	t.modulate = color
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(16, 16) * scale
	t.size = Vector2(16, 16) * scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
