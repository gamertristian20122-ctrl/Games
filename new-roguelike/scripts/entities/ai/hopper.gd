extends RefCounted
## AI "hopper": sits still, then hops. Most hops go toward the player, some go anywhere.
## The tell is a short blink just before each hop.
## params:  rest        seconds between hops          hop   seconds in the air
##          land_shots  how many shots fly out when it lands (default 0)
const REST := 0
const HOP := 1


func start(e) -> void:
	e.state = REST
	e.t = float(e.p.get("rest", 0.9)) * e.rng.randf_range(0.4, 1.0)
	e.mem["warned"] = false


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == REST:
		if e.t <= 0.25 and not e.mem["warned"]:
			e.mem["warned"] = true
			e.tell(0.25)
		if e.t <= 0.0:
			e.state = HOP
			e.t = float(e.p.get("hop", 0.45))
			var d: Vector2 = e.to_player().normalized()
			if e.rng.randf() < 0.25:
				d = Vector2.RIGHT.rotated(e.rng.randf() * TAU)
			else:
				d = d.rotated(e.rng.randf_range(-0.45, 0.45))
			e.dir = d
	else:
		var total := float(e.p.get("hop", 0.45))
		var u := 1.0 - clampf(e.t / total, 0.0, 1.0)
		e.lift = sin(u * PI) * 9.0
		e.dash(e.dir * e.speed, delta)
		if e.t <= 0.0:
			e.lift = 0.0
			e.state = REST
			e.t = float(e.p.get("rest", 0.9)) * e.rng.randf_range(0.8, 1.2)
			e.mem["warned"] = false
			e.run.fx.ring(e.position, 2.0, e.radius * 2.0, 0.2, Color(1, 1, 1, 0.5), 1.0, true)
			var shots := int(e.p.get("land_shots", 0))
			if shots > 0:
				e.shoot_ring(shots, 58.0, "", e.rng.randf() * TAU)
