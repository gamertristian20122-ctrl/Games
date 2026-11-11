extends RefCounted
## Boss "The Red Sexton" (floor 1 spare, sprite boss_death): a small, quick red-hooded reaper.
## STUB: a minimal working fight for the boss builder to replace. The toolkit is listed at the top
## of scripts/entities/boss.gd; the sprite's notes are in assets/art/boss/boss_cast.json.
##   LAMP FIRE   a red circle fills where the hero stands, then it burns for a moment
## The pack has no idle, attack, hit or death frames: animations are run (with lamp), run_nolamp
## and spawn (it rises out of the floor; the row's "enter" plays it when the fight starts).
const WALK := 0
const CAST := 1
const WARN := 0.7
const RADIUS := 18.0


func start(e) -> void:
	e.state = WALK
	e.t = 1.5


func phase_changed(e, _phase: int) -> void:
	e.state = WALK
	e.t = 0.6


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == WALK:
		e.chase(delta, 1.25 if e.phase >= 2 else 1.0, 0.5)
		if e.t <= 0.0:
			e.state = CAST
			e.target = e.player.position
			e.face_player()
			e.pose("run", 0)
			e.tell(WARN)
			e.mark_circle(e.target, RADIUS, WARN)
			e.after(WARN, _burn)


func _burn(e) -> void:
	e.strike_circle(e.target, RADIUS)
	e.burn_ground(e.target, RADIUS, 1.5, 0.0)
	e.stop()
	e.state = WALK
	e.t = 1.2 if e.phase >= 2 else 1.8
