extends RefCounted
## AI "exploder": runs at the player and blows itself up into a ring of shots.
## The tell: once close it stops, blinks faster and faster, and a red circle fills up.
## Kill it before the fuse runs out and nothing happens.
## params:  trigger      how close it gets before lighting the fuse (px)
##          fuse         seconds of warning          shots   how many shots in the ring
##          shot_speed   px/s
const RUSH := 0
const FUSE := 1


func start(e) -> void:
	e.state = RUSH
	e.t = e.rng.randf() * 6.0


func tick(e, delta: float) -> void:
	if e.state == RUSH:
		e.t += delta
		e.chase(delta, 1.0, sin(e.t * 5.0) * 0.3)
		if e.dist_to_player() < float(e.p.get("trigger", 26.0)):
			e.state = FUSE
			e.t = float(e.p.get("fuse", 0.6))
			e.tell(e.t)
			e.warn_circle(18.0, e.t)
		return
	e.t -= delta
	if e.t <= 0.0:
		var fx: Node = e.run.fx
		fx.ring(e.position, 3.0, 22.0, 0.25, Color(1.0, 0.7, 0.3), 2.5)
		e.run.shake(0.3)
		Sfx.play("explosion", -8.0)
		if e.player.can_be_hit() and e.dist_to_player() < 18.0 + e.player.hit_radius:
			e.player.hurt(1, e.position, e.display_name)
		e.shoot_ring(int(e.p.get("shots", 10)), float(e.p.get("shot_speed", 78.0)), "", e.rng.randf() * TAU)
		e.die(false)
