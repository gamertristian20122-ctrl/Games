extends RefCounted
## AI "chaser": walks straight at the player, finding its way around obstacles.
## params:  weave  0..1 how much it sways from side to side (default 0)
##          lunge  speed multiplier when it gets close (default 1 = none)

func start(e) -> void:
	e.t = e.rng.randf() * 6.0


func tick(e, delta: float) -> void:
	e.t += delta
	var sp := 1.0
	if e.p.has("lunge") and e.dist_to_player() < 44.0:
		sp = float(e.p["lunge"])
	var side := 0.0
	if e.p.has("weave"):
		side = sin(e.t * 4.5) * float(e.p["weave"])
	e.chase(delta, sp, side)
