class_name Sprites
## Names for the pictures we use from the Kenney 1-Bit Pack sprite sheet.
##
## The sheet is a grid of 16x16 pixel pictures. Each name below is the
## (column, row) of one picture, counting from 0 at the top-left corner.
## To swap a picture, open the sheet in assets/kenney_1-bit-pack/, find the
## one you like, count its column and row, and change the numbers here.

const SHEET_PATH := "res://assets/kenney_1-bit-pack/monochrome_transparent_packed.png"
const TILE := 16

# --- The keeper ---
const KEEPER := Vector2i(28, 4)

# --- Room pieces ---
const WALL_BRICK := Vector2i(0, 13)
const WALL_BRICK_ALT := Vector2i(6, 13)
const WALL_ROCK := Vector2i(6, 0)
const WALL_ROCK_ALT := Vector2i(7, 0)
const FLOOR_DOTS := [Vector2i(1, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0)]
const FLOOR_STONE := Vector2i(16, 0)
const DOOR_OPEN := Vector2i(5, 16)
const DOOR_CLOSED := Vector2i(6, 16)
const STAIRS := Vector2i(2, 6)
const CRATE := Vector2i(13, 18)
const BARREL := Vector2i(13, 13)
const BARREL_ALT := Vector2i(14, 13)
const BOULDER := Vector2i(20, 5)
const STALAGMITE := Vector2i(19, 6)
const STALAGMITE_ALT := Vector2i(20, 6)
const WATER := Vector2i(18, 5)
const CHEST_CLOSED := Vector2i(8, 6)
const CHEST_OPEN := Vector2i(9, 6)
const COBWEB := Vector2i(2, 15)
const BONES := Vector2i(0, 15)

# --- Hearts and small symbols ---
const HEART_FULL := Vector2i(39, 10)
const HEART_EMPTY := Vector2i(40, 10)
const SKULL := Vector2i(38, 11)
const TARGET := Vector2i(37, 11)
const SPARKLE := Vector2i(36, 11)
const BUBBLES := Vector2i(35, 11)
const FLAME := Vector2i(28, 11)
const BURST := Vector2i(28, 12)
const BURST_SMALL := Vector2i(29, 12)
const RING_SMALL := Vector2i(27, 20)
const CROSSHAIR := Vector2i(22, 14)
const RETICLE := Vector2i(27, 14)
const ARROW_RIGHT := Vector2i(24, 20)
const WARNING := Vector2i(35, 21)

static var _sheet: Texture2D = null
static var _atlas_cache: Dictionary = {}


## The whole sprite sheet as one texture.
static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(SHEET_PATH) as Texture2D
	return _sheet


## The rectangle on the sheet for one picture.
static func region(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)


## Makes a ready-to-use sprite node showing one picture, tinted with a colour.
static func sprite(cell: Vector2i, color: Color = Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = sheet()
	s.region_enabled = true
	s.region_rect = region(cell)
	s.modulate = color
	return s


## One picture as a texture, for menus and the heads-up display.
static func atlas(cell: Vector2i) -> AtlasTexture:
	if not _atlas_cache.has(cell):
		var a := AtlasTexture.new()
		a.atlas = sheet()
		a.region = region(cell)
		_atlas_cache[cell] = a
	return _atlas_cache[cell]


## Draws one picture straight onto something that has a _draw() function.
static func draw(canvas: CanvasItem, cell: Vector2i, top_left: Vector2, color: Color = Color.WHITE, scale: float = 1.0) -> void:
	canvas.draw_texture_rect_region(sheet(), Rect2(top_left, Vector2(TILE, TILE) * scale), region(cell), color)
