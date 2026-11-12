extends RefCounted
## Familiar behaviour "shooter": fires a small shot at the nearest enemy it can see.
## params:  cooldown seconds,  damage per shot,  range px,  shot_speed px/s,  shot (a shot type)

func start(f) -> void:
	f.t = 0.6


func tick(f, delta: float) -> void:
	f.t -= delta
	if f.t > 0.0:
		return
	var e: Node = f.nearest_enemy(float(f.p.get("range", 95.0)))
	if e == null or not f.run.room.sight_clear(f.position, e.position):
		f.t = 0.2
		return
	f.shoot_at(e, float(f.p.get("shot_speed", 150.0)), float(f.p.get("damage", 1.5)), String(f.p.get("shot", "wisp")))
	Sfx.play("familiar_chirp", -16.0)
	f.t = float(f.p.get("cooldown", 1.1))
