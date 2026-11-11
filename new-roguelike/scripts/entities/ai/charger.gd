extends RefCounted
## AI "charger": stalks the player, then rushes in a straight line.
## The tell: it stops, blinks, and a red line shows exactly where the rush will go.
## params:  windup      seconds of warning          dash_speed   px/s
##          cooldown    seconds of rest after a rush
const STALK := 0
const WINDUP := 1
const DASH := 2
const REST := 3


func start(e) -> void:
	e.state = STALK
	e.t = e.rng.randf_range(0.6, 1.4)


func tick(e, delta: float) -> void:
	e.t -= delta
	match e.state:
		STALK:
			e.chase(delta, 1.0)
			if e.t <= 0.0 and e.dist_to_player() < 120.0 and e.room.walk_clear(e.position, e.player.position):
				e.state = WINDUP
				e.t = float(e.p.get("windup", 0.65))
				e.dir = e.to_player().normalized()
				var reach: float = e.room.ray_walk(e.position, e.dir, 170.0)
				e.mem["reach"] = reach
				e.tell(e.t)
				e.warn_line(e.dir, reach + 6.0, e.t)
		WINDUP:
			e.face(e.dir)
			if e.t <= 0.0:
				e.state = DASH
				e.mem["left"] = float(e.mem["reach"]) + 4.0
		DASH:
			var v := float(e.p.get("dash_speed", 190.0))
			var blocked: bool = e.dash(e.dir * v, delta)
			e.mem["left"] = float(e.mem["left"]) - v * delta
			if blocked or float(e.mem["left"]) <= 0.0:
				if blocked:
					e.run.shake(0.15)
					e.stun = 0.35
				e.state = REST
				e.t = float(e.p.get("cooldown", 1.6)) * e.rng.randf_range(0.8, 1.2)
		REST:
			if e.t <= 0.0:
				e.state = STALK
				e.t = e.rng.randf_range(0.3, 0.9)
			elif e.t < 0.8:
				e.chase(delta, 0.6)
