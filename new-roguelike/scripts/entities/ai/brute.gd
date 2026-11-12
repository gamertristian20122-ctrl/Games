extends RefCounted
## AI "brute": a slow tank that plods toward the player and slams the ground when close.
## The tell: a red circle on the floor fills up before the slam; step out of it.
## params:  slam_range   how close the player must be to start a slam (px)
##          slam_radius  how big the slam is (px)
##          slam_shots   shots that fly out on impact (default 0)
const WALK := 0
const WINDUP := 1
const REST := 2
const WINDUP_TIME := 0.7


func start(e) -> void:
	e.state = WALK
	e.t = 0.8


func tick(e, delta: float) -> void:
	e.t -= delta
	match e.state:
		WALK:
			e.chase(delta, 1.0)
			if e.t <= 0.0 and e.dist_to_player() < float(e.p.get("slam_range", 30.0)):
				e.state = WINDUP
				e.t = WINDUP_TIME
				e.tell(WINDUP_TIME)
				e.warn_circle(float(e.p.get("slam_radius", 26.0)), WINDUP_TIME)
		WINDUP:
			e.lift = sin((1.0 - e.t / WINDUP_TIME) * PI) * 5.0
			if e.t <= 0.0:
				e.lift = 0.0
				var r := float(e.p.get("slam_radius", 26.0))
				e.run.fx.ring(e.position, 4.0, r, 0.25, Color(1.0, 0.8, 0.5), 2.5, true)
				e.run.fx.burst(e.position, [Color(0.6, 0.55, 0.5), Color(0.35, 0.3, 0.3)], 10, 60.0, 0.4, 2.2)
				e.run.shake(0.3)
				Sfx.play("rock_break", -8.0)
				if e.player.can_be_hit() and e.dist_to_player() < r + e.player.hit_radius - 1.0:
					e.player.hurt(1, e.position, e.display_name)
				var shots := int(e.p.get("slam_shots", 0))
				if shots > 0:
					e.shoot_ring(shots, 62.0, "", e.rng.randf() * TAU)
				e.state = REST
				e.t = 1.0
		REST:
			if e.t <= 0.0:
				e.state = WALK
				e.t = 0.6
