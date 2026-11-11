extends RefCounted
## AI "flyer": circles the player in the air (pits do not stop it) and dives in now and then.
## The tell: it hangs still and blinks for 0.4 s before each dive.
## params:  orbit        how far from the player it circles (px)
##          dive_every   seconds between dives
const CIRCLE := 0
const WINDUP := 1
const DIVE := 2
const WINDUP_TIME := 0.4


func start(e) -> void:
	e.state = CIRCLE
	e.t = float(e.p.get("dive_every", 2.6)) * e.rng.randf_range(0.5, 1.0)
	e.mem["spin"] = 1.0 if e.rng.randf() < 0.5 else -1.0
	e.mem["bob"] = e.rng.randf() * 6.0


func tick(e, delta: float) -> void:
	e.t -= delta
	e.mem["bob"] = float(e.mem["bob"]) + delta
	e.lift = 5.0 + sin(float(e.mem["bob"]) * 6.0) * 1.5
	match e.state:
		CIRCLE:
			var orbit := float(e.p.get("orbit", 46.0))
			var away: Vector2 = -e.to_player()
			var d := away.length()
			var around: Vector2 = away.normalized().orthogonal() * float(e.mem["spin"])
			# steer along the circle, correcting toward the right distance
			var steer: Vector2 = around + away.normalized() * clampf((orbit - d) / 20.0, -1.0, 1.0)
			if e.move_dir(steer, delta, 1.0):
				e.mem["spin"] = -float(e.mem["spin"])
			if e.t <= 0.0:
				e.state = WINDUP
				e.t = WINDUP_TIME
				e.tell(WINDUP_TIME)
		WINDUP:
			e.face(e.to_player())
			if e.t <= 0.0:
				e.state = DIVE
				e.dir = e.to_player().normalized()
				e.t = clampf(e.dist_to_player() / (e.speed * 2.4) + 0.25, 0.3, 0.9)
		DIVE:
			e.lift = 2.0
			if e.dash(e.dir * e.speed * 2.4, delta) or e.t <= 0.0:
				e.state = CIRCLE
				e.t = float(e.p.get("dive_every", 2.6)) * e.rng.randf_range(0.8, 1.2)
