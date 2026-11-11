extends RefCounted
## Boss "The Forge Warden" (floor 3, sprite boss_mecha_golem): a hovering golem of stone and brass.
## STUB: a minimal working fight for the boss builder to replace. The toolkit is listed at the top
## of scripts/entities/boss.gd; the sprite's notes are in assets/art/boss/boss_cast.json.
##   ARM SHOT   a red lane fills from its arm to the hero, then the arm fires along it ("attack")
## Animations: idle, glow, attack (ranged arm shot), attack2 (melee), cast (laser), buff, block,
## death (the row plays it backwards as the entrance). Effect sprites: boss_fx_mecha_golem_arm,
## boss_fx_mecha_golem_arm_glow, boss_fx_mecha_golem_laser (frames 0-7 charge, 8-13 beam).
const HOVER := 0
const AIM := 1
const WARN := 0.8
const KEEP := 80.0          # px it likes to keep from the hero


func start(e) -> void:
	e.state = HOVER
	e.t = 1.5


func phase_changed(e, _phase: int) -> void:
	e.state = HOVER
	e.t = 0.6


func tick(e, delta: float) -> void:
	e.t -= delta
	if e.state == HOVER:
		if e.dist_to_player() > KEEP + 12.0:
			e.chase(delta)
		elif e.dist_to_player() < KEEP - 12.0:
			e.flee(delta)
		e.face_player()
		if e.t <= 0.0:
			e.state = AIM
			e.face_player()
			e.strike("attack", WARN, _fire, _done)
			e.dir = (e.player.position - e.muzzle("attack")).normalized()
			e.mark_lane(e.muzzle("attack"), e.muzzle("attack") + e.dir * 300.0, 5.0, WARN)


func _fire(e, _frame: int) -> void:
	e.shoot_from(e.muzzle("attack"), e.dir, 150.0, "enemy_big")
	if e.phase >= 2:
		e.fan_from(e.muzzle("attack"), e.dir, 2, 0.5, 120.0)


func _done(e) -> void:
	e.state = HOVER
	e.t = 1.1 if e.phase >= 2 else 1.8
