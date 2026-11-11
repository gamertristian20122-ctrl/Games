extends RefCounted
## THE FINAL BOSS "The Starved King" (floor 4, sprite boss_demon): a winged, skull-faced demon.
## STUB: a minimal working fight for the boss builder to replace. The toolkit is listed at the top
## of scripts/entities/boss.gd; the sprite's notes are in assets/art/boss/boss_cast.json.
##   BREATH   a red cone fills in front of it, then blue fire fills the cone ("attack2") and a
##            fan of shots flies on
## Animations: idle, attack (a swipe; no hit frame listed, add "hit_frames" to its row), attack2
## (the breath: starts on frame 6, burns until frame 15). Effect sprites: boss_fx_demon_fireball,
## boss_fx_demon_fireball_blue (frame 0 a falling fireball, 1-4 its burst).
## Its row says "final": its death is long and wins the run. Its room has no obstacles.
const HOVER := 0
const BREATH := 1
const WARN := 0.9
const REACH := 120.0
const HALF_ANGLE := 0.42


func start(e) -> void:
	e.state = HOVER
	e.t = 1.8


func phase_changed(e, _phase: int) -> void:
	e.state = HOVER
	e.t = 0.8


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == HOVER:
		# line up beside the hero: the breath only goes left or right
		var side := -signf(e.to_player().x) if absf(e.to_player().x) > 1.0 else 1.0
		e.move_toward(e.player.position + Vector2(side * 70.0, 0.0), delta, 1.3 if e.phase >= 2 else 1.0)
		e.face_player()
		if e.t <= 0.0:
			e.state = BREATH
			e.face_player()
			e.dir = Vector2(signf(e.to_player().x) if absf(e.to_player().x) > 1.0 else 1.0, 0.0)
			e.strike("attack2", WARN, _breath, _done)
			e.mark_cone(e.position, e.dir, REACH, HALF_ANGLE, WARN)


func _breath(e, _frame: int) -> void:
	e.strike_cone(e.position, e.dir, REACH, HALF_ANGLE)
	e.fan_from(e.muzzle("attack2"), e.dir, 7 if e.phase >= 2 else 5, 0.9, 85.0)
	e.run.shake(0.4)


func _done(e) -> void:
	e.state = HOVER
	e.t = 1.4 if e.phase >= 2 else 2.2
