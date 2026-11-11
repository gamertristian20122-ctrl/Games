extends Node2D
## Floor exit: the stone stairwell that opens in the floor when a boss dies. Walk onto it to go down.
## The picture (prop_stairs_down, 48 x 48, cut by tools/import_props.py) lies flat, centred on the spot.
## desc: {"pos": Vector2}

var kind := "floor_exit"
var solid := false
var room: Node
var _t := 0.0
var _used := false


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	z_index = -3      # flat on the floor, under shadows and feet
	var s := Sprite2D.new()
	s.texture = Art.tex("prop_stairs_down")
	s.show_behind_parent = true      # the arrows drawn below go on top of the picture
	add_child(s)
	room.run.fx.ring(position, 2.0, 22.0, 0.5, Color(1, 1, 0.8), 2.0, true)


func save() -> Dictionary:
	return {"kind": "floor_exit", "pos": position}


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var player: Node = room.run.player
	if _used or player == null or player.dead or room.run.busy():
		return
	if (player.position as Vector2).distance_to(position) < 7.0:
		_used = true
		room.run.next_floor()


func _draw() -> void:
	# two small arrows sinking into the dark, so the way down is easy to spot
	for i in 2:
		var k := fmod(_t / 1.4 + i * 0.5, 1.0)
		var y := -2.0 + k * 12.0
		var c := Color(1.0, 0.95, 0.8, 0.75 * sin(k * PI))
		draw_line(Vector2(-5, y - 4), Vector2(0, y), c, 1.0)
		draw_line(Vector2(0, y), Vector2(5, y - 4), c, 1.0)
