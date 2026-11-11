extends Control
## Minimap: a small map of the floor in the top right corner, drawn from run.rooms.
##   bright = the room you are in, grey = visited, dark = seen through a door but not entered.
##   Special rooms have their own colour and a small mark:
##   boss red, treasure gold, shop green, secret pale blue, altar purple.
##   A small pale nick on a room's edge = a wall the Hungry Curse has cracked (a hidden door).
## It redraws when the HUD says something changed, and twice a second for the blinking room.

const UI = preload("res://scripts/ui/theme.gd")
const GS = preload("res://scripts/core/g.gd")     # only for the RoomType names

const CELL := Vector2(8, 6)      ## one room
const STEP := Vector2(9, 7)      ## room plus the gap to the next
const COLS := 5       ## a level has 6 to 10 rooms; the map scrolls with you when it is wider
const ROWS := 4

const TYPE_COLOUR := {
	GS.RoomType.BOSS: UI.C_RED,
	GS.RoomType.TREASURE: UI.C_GOLD,
	GS.RoomType.SHOP: UI.C_GREEN,
	GS.RoomType.SECRET: UI.C_ICE,
	GS.RoomType.ALTAR: UI.C_CURSE,
}

var run: Node
var _blink := true
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(COLS * STEP.x + 3, ROWS * STEP.y + 3)
	custom_minimum_size = size


func set_run(r: Node) -> void:
	run = r
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _time >= 0.45:
		_time = 0.0
		_blink = not _blink
		queue_redraw()


func _draw() -> void:
	draw_style_box(UI.box("hud"), Rect2(Vector2.ZERO, size))
	if not is_instance_valid(run):
		return
	var rooms: Variant = run.get("rooms")
	if not (rooms is Dictionary) or rooms.is_empty():
		return
	var cur: Vector2i = run.get("cur")
	# the part of the map that is known
	var lo := cur
	var hi := cur
	for c: Vector2i in rooms:
		var info: Dictionary = rooms[c]
		if info.get("visited", false) or info.get("seen", false):
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	# show all of it if it fits, otherwise keep the current room in view
	var centre := Vector2(lo + hi) / 2.0
	if hi.x - lo.x + 1 > COLS:
		centre.x = clampf(cur.x, lo.x + (COLS - 1) / 2.0, hi.x - (COLS - 1) / 2.0)
	if hi.y - lo.y + 1 > ROWS:
		centre.y = clampf(cur.y, lo.y + (ROWS - 1) / 2.0, hi.y - (ROWS - 1) / 2.0)
	var origin := (size / 2.0 - CELL / 2.0 - centre * STEP).round()
	for c: Vector2i in rooms:
		var info: Dictionary = rooms[c]
		var visited: bool = info.get("visited", false)
		if not visited and not info.get("seen", false):
			continue
		var r := Rect2(origin + Vector2(c) * STEP, CELL)
		if r.position.x < 1 or r.position.y < 1 or r.end.x > size.x - 1 or r.end.y > size.y - 1:
			continue
		var type := int(info.get("type", GS.RoomType.COMBAT))
		var special: bool = TYPE_COLOUR.has(type)
		var fill: Color = TYPE_COLOUR[type] if special else Color("8d95a1")
		if not visited:
			fill = fill.darkened(0.5) if special else Color("363b47")
		var here := c == cur
		if here and not special:
			fill = UI.C_BONE
		draw_rect(r.grow(1), UI.C_INK)
		draw_rect(r, fill)
		if special:
			_mark(type, r)
		if visited:
			_crack_marks(info, r)
		if here and _blink:
			# a bright frame around the room you are in
			var f := r.grow(1)
			var col := Color.WHITE
			draw_rect(Rect2(f.position, Vector2(f.size.x, 1)), col)
			draw_rect(Rect2(f.position + Vector2(0, f.size.y - 1), Vector2(f.size.x, 1)), col)
			draw_rect(Rect2(f.position, Vector2(1, f.size.y)), col)
			draw_rect(Rect2(f.position + Vector2(f.size.x - 1, 0), Vector2(1, f.size.y)), col)


## Walls the Hungry Curse has cracked but not yet opened: a pale nick on that side of the room.
func _crack_marks(info: Dictionary, r: Rect2) -> void:
	var doors: Variant = info.get("doors")
	if not (doors is Dictionary):
		return
	for d: Variant in doors:
		var door: Variant = doors[d]
		if not (d is Vector2i) or not (door is Dictionary) or not door.get("cracked", false) or door.get("revealed", false):
			continue
		var edge := (r.position + r.size / 2.0 + Vector2(d) * r.size / 2.0).round()
		draw_rect(Rect2(edge.x - 1, edge.y - 1, 2, 2), UI.C_ICE)


## A tiny dark mark so special rooms can be told apart without relying on colour alone.
func _mark(type: int, r: Rect2) -> void:
	var ink := Color(0.05, 0.04, 0.07, 0.85)
	var p := r.position
	match type:
		GS.RoomType.BOSS:            # two eyes
			draw_rect(Rect2(p.x + 2, p.y + 2, 1, 2), ink)
			draw_rect(Rect2(p.x + 5, p.y + 2, 1, 2), ink)
		GS.RoomType.TREASURE:        # a lid line
			draw_rect(Rect2(p.x + 2, p.y + 2, 4, 1), ink)
			draw_rect(Rect2(p.x + 3, p.y + 3, 2, 1), ink)
		GS.RoomType.SHOP:            # a coin
			draw_rect(Rect2(p.x + 3, p.y + 1, 2, 4), ink)
		GS.RoomType.SECRET:          # a dot
			draw_rect(Rect2(p.x + 3, p.y + 2, 2, 2), ink)
		GS.RoomType.ALTAR:           # a cross
			draw_rect(Rect2(p.x + 3, p.y + 1, 2, 4), ink)
			draw_rect(Rect2(p.x + 2, p.y + 2, 4, 1), ink)
