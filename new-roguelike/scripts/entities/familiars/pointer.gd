extends RefCounted
## Familiar behaviour "pointer": the Knocker Bat. When the room has a hidden door that is not open
## yet (cracked or not), it leaves the hero's shoulder, flies to that spot on the wall and circles
## there until the door is opened, fights included. No hidden door = it just follows.
## params:  speed  px/s while it flies to the wall      circle  px radius of its circling

func tick(f, delta: float) -> void:
	var room: Node = f.run.room
	var spot := Vector2.INF
	for dir: Vector2i in room.rs["doors"]:
		var door: Dictionary = room.rs["doors"][dir]
		if door["hidden"] and not door["revealed"]:
			spot = room.door_pos(dir)
			break
	if spot == Vector2.INF or int(f.mem.get("room", 0)) != room.get_instance_id():
		# nothing to show (or a new room: start again from the hero's shoulder)
		f.mem["room"] = room.get_instance_id()
		f.mem["pos"] = f.position
		return
	f.t += delta
	var r := float(f.p.get("circle", 6.0))
	var want := spot + Vector2(cos(f.t * 5.0), sin(f.t * 5.0) * 0.6) * r
	want = Vector2(clampf(want.x, 6.0, G.ROOM_W - 6.0), clampf(want.y, 6.0, G.ROOM_H - 6.0))
	var pos: Vector2 = (f.mem["pos"] as Vector2).move_toward(want, float(f.p.get("speed", 140.0)) * delta)
	if pos.distance_to(want) < 1.0 and int(f.mem.get("found", 0)) != room.get_instance_id():
		f.mem["found"] = room.get_instance_id()        # one chirp when it reaches the wall
		Sfx.play("familiar_chirp", -8.0, 0.05, 1.4)
	f.sprite.flip_h = want.x < pos.x
	f.mem["pos"] = pos
	f.position = pos
