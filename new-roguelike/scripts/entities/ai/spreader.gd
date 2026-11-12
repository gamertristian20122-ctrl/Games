extends RefCounted
## AI "spreader": wanders about and spits a fan of shots toward the player.
## The tell: it stops and blinks for 0.55 s before every volley.
## params:  cooldown    seconds between volleys      shots   how many in the fan
##          arc         how wide the fan is (radians)   shot_speed   px/s
const WANDER := 0
const AIM := 1
const AIM_TIME := 0.55


func start(e) -> void:
	e.state = WANDER
	e.t = float(e.p.get("cooldown", 2.6)) * e.rng.randf_range(0.5, 1.0)
	e.t2 = 0.0
	e.target = e.position


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == AIM:
		e.face(e.to_player())
		if e.t <= 0.0:
			e.shoot_fan(e.to_player(), int(e.p.get("shots", 3)), float(e.p.get("arc", 0.5)), float(e.p.get("shot_speed", 66.0)))
			e.state = WANDER
			e.t = float(e.p.get("cooldown", 2.6)) * e.rng.randf_range(0.85, 1.15)
		return
	if e.t <= AIM_TIME and e.line_of_sight():
		e.state = AIM
		e.t = AIM_TIME
		e.tell(AIM_TIME)
		return
	if e.t <= 0.0:
		e.t = 0.3
	# stroll to random spots, but drift toward the player when far away
	e.t2 -= delta
	if e.t2 <= 0.0 or e.position.distance_to(e.target) < 4.0:
		e.t2 = e.rng.randf_range(1.2, 2.2)
		var around: Vector2 = e.position.lerp(e.player.position, 0.35)
		e.target = e.room.free_spot_near(around + Vector2(e.rng.randf_range(-40, 40), e.rng.randf_range(-28, 28)), false)
	if e.move_toward(e.target, delta, 0.8):
		e.t2 = 0.0
