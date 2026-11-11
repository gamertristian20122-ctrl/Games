extends Node2D
## Floor exit: the trapdoor with a ladder that appears when a boss dies. Walk onto it to go down.
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
	s.texture = Art.tex("floor_ladder")
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
	# a soft pulsing ring so the way down is easy to spot
	var k := fmod(_t, 1.4) / 1.4
	draw_arc(Vector2.ZERO, 9.0 + k * 6.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.6, 0.6 * (1.0 - k)), 1.0)
