extends RefCounted
## Boss "Stonejaw" (floor 2): an ogre that fights from the air and from afar.
##   LEAP    a red circle marks where it will land; it jumps (it cannot be hit in the air) and the
##           landing sends out a shockwave and a ring of shots     (phase 2: two leaps in a row)
##   THROW   it lobs rocks in high arcs; each rock's landing spot is marked with a red circle
##           (phase 2: more rocks, thrown faster)
## params (bosses.gd):  leap_time seconds in the air,  shock_radius px
const WALK := 0
const LEAP_WIND := 1
const LEAP_AIR := 2
const THROW := 3
const REST := 4
const CROUCH := 0.35


func start(e) -> void:
	e.state = WALK
	e.t = 1.2
	e.mem = {"leaps": 0, "rocks": 0, "from": e.position, "last": -1}


func phase_changed(e, _phase: int) -> void:
	e.hittable = true
	e.harmful = true
	e.lift = 0.0
	e.state = REST
	e.t = 0.8


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		WALK:
			e.chase(delta, 1.3 if mean else 1.0)
			if e.t <= 0.0:
				var leap_chance := 0.45
				if int(e.mem["last"]) == LEAP_WIND:
					leap_chance = 0.25
				elif int(e.mem["last"]) == THROW:
					leap_chance = 0.7
				if e.rng.randf() < leap_chance:
					e.mem["last"] = LEAP_WIND
					e.mem["leaps"] = 2 if mean else 1
					_begin_leap(e)
				else:
					e.mem["last"] = THROW
					e.mem["rocks"] = 5 if mean else 3
					e.state = THROW
					e.t = 0.5
					e.tell(0.5)
		LEAP_WIND:
			if e.t <= 0.0:
				e.state = LEAP_AIR
				e.t = float(e.p.get("leap_time", 0.9))
				e.mem["from"] = e.position
				e.hittable = false
				e.harmful = false
		LEAP_AIR:
			var total := float(e.p.get("leap_time", 0.9))
			var u := clampf(1.0 - e.t / total, 0.0, 1.0)
			e.position = (e.mem["from"] as Vector2).lerp(e.target, u)
			e.lift = sin(u * PI) * 40.0
			e.face(e.target - (e.mem["from"] as Vector2))
			if e.t <= 0.0:
				e.position = e.target
				e.lift = 0.0
				e.hittable = true
				e.harmful = true
				_land(e, mean)
				e.mem["leaps"] = int(e.mem["leaps"]) - 1
				if int(e.mem["leaps"]) > 0:
					_begin_leap(e)
				else:
					e.state = REST
					e.t = 0.8 if mean else 1.2
		THROW:
			e.face(e.to_player())
			if e.t <= 0.0:
				var lead: Vector2 = e.player.vel * 0.45
				var to: Vector2 = e.player.position + lead + Vector2.RIGHT.rotated(e.rng.randf() * TAU) * e.rng.randf_range(0.0, 14.0)
				to = Vector2(clampf(to.x, 8, G.ROOM_W - 8), clampf(to.y, 8, G.ROOM_H - 8))
				e.run.shots.lob(e.position + Vector2(0, -6), to, 0.85, 13.0, "rock", e.display_name)
				Sfx.play("enemy_shoot", -4.0)
				e.mem["rocks"] = int(e.mem["rocks"]) - 1
				if int(e.mem["rocks"]) > 0:
					e.t = 0.3 if mean else 0.45
				else:
					e.state = REST
					e.t = 0.7 if mean else 1.0
		REST:
			if e.t <= 0.0:
				e.state = WALK
				e.t = e.rng.randf_range(0.6, 1.1) if mean else e.rng.randf_range(1.0, 1.6)


func _begin_leap(e) -> void:
	e.state = LEAP_WIND
	e.t = CROUCH
	var to: Vector2 = e.player.position
	e.target = Vector2(clampf(to.x, 14, G.ROOM_W - 14), clampf(to.y, 14, G.ROOM_H - 14))
	e.tell(CROUCH)
	e.warn_circle(float(e.p.get("shock_radius", 34.0)), CROUCH + float(e.p.get("leap_time", 0.9)), e.target)


func _land(e, mean: bool) -> void:
	var r := float(e.p.get("shock_radius", 34.0))
	e.run.fx.ring(e.position, 6.0, r, 0.3, Color(1.0, 0.8, 0.5), 3.0, true)
	e.run.fx.burst(e.position, [Color(0.6, 0.55, 0.5), Color(0.35, 0.3, 0.3)], 22, 100.0, 0.5, 2.8)
	e.run.shake(0.75)
	e.run.hitstop(0.04)
	Sfx.play("explosion", -5.0)
	if e.player.can_be_hit() and e.dist_to_player() < r + e.player.hit_radius - 2.0:
		e.player.hurt(1, e.position, e.display_name)
	e.shoot_ring(12 if mean else 8, 62.0, "", e.rng.randf() * TAU)
