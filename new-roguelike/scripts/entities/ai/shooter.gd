extends RefCounted
## AI "shooter": keeps its distance, strafes, and fires one aimed shot at a time.
## The tell: it stops and blinks for 0.45 s before every shot.
## params:  keep        the distance it likes to stay at (px)
##          cooldown    seconds between shots          shot_speed   px/s
const MOVE := 0
const AIM := 1
const AIM_TIME := 0.45


func start(e) -> void:
	e.state = MOVE
	e.t = float(e.p.get("cooldown", 2.2)) * e.rng.randf_range(0.5, 1.0)
	e.t2 = 0.0
	e.mem["side"] = 1.0 if e.rng.randf() < 0.5 else -1.0


func tick(e, delta: float) -> void:
	e.t -= delta
	var keep := float(e.p.get("keep", 70.0))
	var sees: bool = e.line_of_sight()
	if e.state == AIM:
		e.face(e.to_player())
		if e.t <= 0.0:
			e.shoot_at_player(float(e.p.get("shot_speed", 72.0)))
			e.state = MOVE
			e.t = float(e.p.get("cooldown", 2.2)) * e.rng.randf_range(0.85, 1.15)
		return
	if e.t <= AIM_TIME and sees:
		e.state = AIM
		e.t = AIM_TIME
		e.tell(AIM_TIME)
		return
	if e.t <= 0.0:
		e.t = 0.3      # no clear shot yet: try again soon
	var d: float = e.dist_to_player()
	if d < keep * 0.7:
		e.flee(delta, 1.0)
	elif d > keep * 1.35 or not sees:
		e.chase(delta, 0.9)
	else:
		e.t2 -= delta
		if e.t2 <= 0.0:
			e.t2 = e.rng.randf_range(1.0, 2.4)
			e.mem["side"] = -float(e.mem["side"])
		var blocked: bool = e.move_dir(e.to_player().orthogonal() * float(e.mem["side"]), delta, 0.6)
		if blocked:
			e.mem["side"] = -float(e.mem["side"])
