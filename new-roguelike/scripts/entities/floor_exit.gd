extends Node2D
## Floor exit: the stone stairwell that opens in the floor when a boss dies. Walk onto it to go down.
## The picture (prop_stairs_down, 48 x 48, cut by tools/import_props.py) is a stone frame with
## steps along its top edge and nothing in the middle: the dark of the shaft and the two sinking
## arrows are flat shapes drawn here. It lies flat on the floor, centred on the spot.
## desc: {"pos": Vector2}

const PICTURE := "prop_stairs_down"
const FRAME := 2.0                               ## px of the stone frame that hide the edge of the dark
const DARK := Color(0.055, 0.045, 0.075)         ## the shaft
const ARROW := Color(1.0, 0.95, 0.8)

var kind := "floor_exit"
var solid := false
var room: Node
var _t := 0.0
var _used := false
var _arrows: Node2D


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = _clear_spot(desc.get("pos", G.ROOM_CENTER))
	z_index = -3      # flat on the floor, under shadows and feet
	var s := Sprite2D.new()
	s.texture = Art.tex(PICTURE)
	add_child(s)
	_arrows = Node2D.new()
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)
	room.run.fx.ring(position, 2.0, 22.0, 0.5, Color(1, 1, 0.8), 2.0, true)


## The picture covers 3 x 3 floor tiles. When a rock, pillar or brazier of the room's layout
## stands on one of them (it would stand in the shaft), the stairwell opens on the nearest tile
## where all nine are clear. Look only: it is still one spot to walk onto, a tile or two away.
func _clear_spot(at: Vector2) -> Vector2:
	var c := G.cell_of(at)
	if _nine_free(c):
		return at
	var best := at
	var best_d := INF
	for oy in range(-2, 3):
		for ox in range(-4, 5):
			var n := c + Vector2i(ox, oy)
			var d := Vector2(ox, oy).length()
			if d >= best_d or not _nine_free(n):
				continue
			var q := G.cell_center(n.x, n.y)
			var taken := false
			for t in room.things:
				if is_instance_valid(t) and t.solid and absf(t.position.x - q.x) < 32.0 and absf(t.position.y - q.y) < 32.0:
					taken = true
			if not taken:
				best_d = d
				best = q
	return best


func _nine_free(c: Vector2i) -> bool:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if not room.is_free_cell(c + Vector2i(ox, oy)):
				return false
	return true


func save() -> Dictionary:
	return {"kind": "floor_exit", "pos": position}


func _physics_process(delta: float) -> void:
	_t += delta
	_arrows.queue_redraw()
	var player: Node = room.run.player
	if _used or player == null or player.dead or room.run.busy():
		return
	if (player.position as Vector2).distance_to(position) < 7.0:
		_used = true
		room.run.next_floor()


## The dark of the shaft: drawn first, so the picture's frame and steps lie on top of it.
func _draw() -> void:
	var half := Art.size(PICTURE) / 2.0 - Vector2(FRAME, FRAME)
	draw_rect(Rect2(-half, half * 2.0), DARK)


## Two small arrows sinking into the dark, so the way down is easy to spot.
func _draw_arrows() -> void:
	for i in 2:
		var k := fmod(_t / 1.4 + i * 0.5, 1.0)
		var y := -2.0 + k * 12.0
		var c := Color(ARROW, 0.75 * sin(k * PI))
		_arrows.draw_line(Vector2(-5, y - 4), Vector2(0, y), c, 1.0)
		_arrows.draw_line(Vector2(0, y), Vector2(5, y - 4), c, 1.0)
