extends RefCounted
## AI "summoner": stays away from the player and raises small minions from the floor.
## The tell: it blinks for 0.8 s, and red circles show where the minions will climb out.
## params:  minion       enemy id to raise           count   how many per cast
##          cooldown     seconds between casts       max_minions   it stops casting at this many alive
##          keep         the distance it tries to keep from the player (px)
const ROAM := 0
const CAST := 1
const CAST_TIME := 0.8


func start(e) -> void:
	e.state = ROAM
	e.t = float(e.p.get("cooldown", 4.5)) * 0.35
	e.t2 = 0.0
	e.target = e.position


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == CAST:
		if e.t <= 0.0:
			for at: Vector2 in e.mem.get("spots", []):
				e.summon(String(e.p.get("minion", "shambler")), at)
			e.state = ROAM
			e.t = float(e.p.get("cooldown", 4.5)) * e.rng.randf_range(0.85, 1.15)
		return
	if e.t <= 0.0:
		if e.minion_count() < int(e.p.get("max_minions", 4)):
			e.state = CAST
			e.t = CAST_TIME
			e.tell(CAST_TIME)
			var spots: Array = []
			for k in int(e.p.get("count", 2)):
				var at: Vector2 = e.room.free_spot_near(e.position + Vector2.RIGHT.rotated(e.rng.randf() * TAU) * e.rng.randf_range(16, 30), false)
				spots.append(at)
				e.warn_circle(7.0, CAST_TIME + 0.7, at)
			e.mem["spots"] = spots
			return
		e.t = 1.0
	var keep := float(e.p.get("keep", 75.0))
	if e.dist_to_player() < keep:
		e.flee(delta, 1.0)
	else:
		e.t2 -= delta
		if e.t2 <= 0.0 or e.position.distance_to(e.target) < 4.0:
			e.t2 = e.rng.randf_range(1.5, 3.0)
			e.target = e.room.free_spot_near(e.position + Vector2(e.rng.randf_range(-36, 36), e.rng.randf_range(-24, 24)), false)
		e.move_toward(e.target, delta, 0.5)
