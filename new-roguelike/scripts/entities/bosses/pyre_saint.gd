extends RefCounted
## Boss "The Pyre Saint" (floor 1, sprite boss_fire_skull): a burning skull that drifts after the hero.
## STUB: a minimal working fight for the boss builder to replace. The toolkit is listed at the top
## of scripts/entities/boss.gd; the sprite's notes are in assets/art/boss/boss_cast.json.
##   FLARE   a red circle fills under it, then it bursts: the circle hurts and a ring of shots flies out
##   Every third flare its flame goes out for a moment (the "nofire" loop): the breather.
## It tumbles, so it has no facing ("no_facing" in its row). Animations: idle (burning), nofire.
const DRIFT := 0
const FLARE := 1
const WARN := 0.8          # seconds of warning (floor 1: never under 0.5)
const RADIUS := 34.0


func start(e) -> void:
	e.state = DRIFT
	e.t = 1.6
	e.mem = {"flares": 0}


func phase_changed(e, _phase: int) -> void:
	e.set_loops("idle")
	e.state = DRIFT
	e.t = 0.8


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == DRIFT:
		e.chase(delta, 1.3 if e.phase >= 2 else 1.0)
		if e.t <= 0.0:
			e.state = FLARE
			e.set_loops("idle")
			e.tell(WARN)
			e.mark_circle(e.position, RADIUS, WARN)
			e.after(WARN, _flare)


func _flare(e) -> void:
	e.strike_circle(e.position, RADIUS)
	e.ring_from(e.position, 10 if e.phase >= 2 else 8, 62.0)
	e.run.shake(0.4)
	e.state = DRIFT
	e.t = 1.4 if e.phase >= 2 else 2.0
	e.mem["flares"] = int(e.mem["flares"]) + 1
	if int(e.mem["flares"]) % 3 == 0:
		e.set_loops("nofire")              # the flame is out until the next flare
		e.stagger(1.3, "nofire")
