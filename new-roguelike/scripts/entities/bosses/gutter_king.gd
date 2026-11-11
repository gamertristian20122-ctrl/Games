extends RefCounted
## Boss "The Gutter King" (floor 2 spare, sprite boss_mutant_toad): a fat toad with a long tongue.
## STUB: a minimal working fight for the boss builder to replace. The toolkit is listed at the top
## of scripts/entities/boss.gd; the sprite's notes are in assets/art/boss/boss_cast.json.
##   TONGUE   a red lane fills in front of it, then the tongue lashes along it (animation "attack")
## Animations: idle, jump (4 frames), attack (3 frames; the tongue is 41 px long and cut flat at its
## tip in the pack, so keep the lane no longer than REACH).
const WALK := 0
const LASH := 1
const WARN := 0.6
const REACH := 44.0
const HALF_WIDTH := 7.0


func start(e) -> void:
	e.state = WALK
	e.t = 1.4


func phase_changed(e, _phase: int) -> void:
	e.state = WALK
	e.t = 0.6


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == WALK:
		e.chase(delta, 1.3 if e.phase >= 2 else 1.0)
		if e.t <= 0.0 and absf(e.to_player().y) < 14.0 and e.dist_to_player() < REACH + 20.0:
			e.state = LASH
			e.face_player()
			e.dir = Vector2(signf(e.to_player().x), 0.0)
			e.mark_lane(e.position, e.position + e.dir * REACH, HALF_WIDTH, WARN)
			e.strike("attack", WARN, _lash, _done)


func _lash(e, _frame: int) -> void:
	e.strike_lane(e.position, e.position + e.dir * REACH, HALF_WIDTH)


func _done(e) -> void:
	e.state = WALK
	e.t = 1.0 if e.phase >= 2 else 1.6
