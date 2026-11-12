extends RefCounted
## Familiar behaviour "percher": the Carrion Bat. In a fight it flies to the monster with the most
## health left (bosses and elites included) and sits on its head; f.mem["perch"] is that monster.
## The item's hook (carrion_bat_on_hit in scripts/run/item_effects.gd) makes the hero's shots hurt
## the perched monster more. When its perch dies or is swallowed it moves on to the next toughest.
## params:  speed  px/s while it flies to its perch

func tick(f, delta: float) -> void:
	var perch: Variant = f.mem.get("perch")
	if perch == null or not is_instance_valid(perch) or perch.dead or not perch.hittable:
		perch = null
		var most := 0.0
		for e in f.run.room.enemies:
			if e.hittable and not e.dead and float(e.hp) > most:
				most = float(e.hp)
				perch = e
		f.mem["perch"] = perch
		if perch == null:
			f.mem.erase("pos")
			return
	if not f.mem.has("pos"):
		f.mem["pos"] = f.position
	var want: Vector2 = perch.position + Vector2(0, 0.5)       # just in front of it, so it draws on top
	var pos: Vector2 = (f.mem["pos"] as Vector2).move_toward(want, float(f.p.get("speed", 170.0)) * delta)
	f.mem["pos"] = pos
	f.position = pos
	if pos.distance_to(want) < 2.0:
		f.sprite.position.y = -(float(perch._mid) * 2.0 + 4.0)   # on its head, not at shoulder height
