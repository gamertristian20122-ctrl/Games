extends RefCounted
## Boss "Stonejaw" (floor 2, sprite boss_ogre): an ogre with a club. A reference fight: it uses
## most of the toolkit listed at the top of scripts/entities/boss.gd.
##   SMASH   (phase 1) the club comes down in front of it: a red circle where it lands, and a red
##           band round that spot for the shockwave that follows. Afterwards the club is stuck
##           and Stonejaw is staggered: the breather.
##   LEAP    a red circle marks where it lands; it cannot be hit in the air; the landing hurts
##           inside the circle and throws a ring of shots            (phase 2: two leaps in a row)
##   THROW   rocks in high arcs, each landing spot marked            (phase 2: five, thrown faster)
## Phase 2 (half health): it HURLS THE CLUB along a red lane across the room, then fights
## bare-handed and faster (loops idle_unarmed / run_unarmed). SMASH is replaced by
##   POUND   it jumps on the spot: a wide red circle round itself, then a ring of shots
## params (bosses.gd): leap_time s in the air, shock_radius px, smash_warn s, smash_reach px in
##   front, smash_radius px, wave_inner / wave_outer px (the shockwave band), club_speed px/s, club_warn s
const WALK := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const LEAP_AIR := 2
const THROW := 3
const REST := 4
const HURL_AIM := 5
const CLUB_FLY := 6
const CROUCH := 0.45
const POUND_RADIUS := 44.0
## The club in frame 0 of "idle" (canvas px). cut_sprite() cuts it out for the throw: the artist's
## own pixels, nothing drawn.
const CLUB_RECT := Rect2(53, 64, 24, 13)
const DUST := [Color(0.6, 0.55, 0.5), Color(0.35, 0.3, 0.3)]


func start(e) -> void:
	e.state = WALK
	e.t = 1.2
	e.mem = {"leaps": 0, "rocks": 0, "from": e.position, "last": -1, "armed": true, "shock": 34.0,
		"impact": Vector2.ZERO, "tail": 0.3, "club": null, "club_at": Vector2.ZERO, "club_left": 0.0}


func phase_changed(e, _phase: int) -> void:
	# the base has already cleaned up (marks, timers, back on the ground); aim the throw once the roar is over
	e.state = HURL_AIM if e.mem["armed"] else REST
	e.t = 0.3


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		WALK:
			e.chase(delta, 1.35 if mean else 1.0)
			if e.t <= 0.0:
				_pick(e, mean)
		LEAP_AIR:
			var total := float(e.p.get("leap_time", 0.9))
			var u := clampf(1.0 - e.t / total, 0.0, 1.0)
			e.position = (e.mem["from"] as Vector2).lerp(e.target, u)
			e.lift = sin(u * PI) * 40.0
			if e.t <= 0.0:
				_land(e, mean)
		THROW:
			e.face_player()
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
		HURL_AIM:
			if e.t <= 0.0:
				_begin_hurl(e)
		CLUB_FLY:
			_fly_club(e, delta)


func _pick(e, mean: bool) -> void:
	var near: bool = absf(e.to_player().x) < 80.0 and absf(e.to_player().y) < 26.0
	if not e.mem["armed"]:
		near = e.dist_to_player() < 64.0
	var last := int(e.mem["last"])
	var w_close := 50.0 if near else 0.0     # SMASH, or POUND once the club is gone
	var w_leap := 34.0
	var w_throw := 30.0
	if last == BUSY:
		w_close *= 0.3
	elif last == LEAP_AIR:
		w_leap *= 0.3
	elif last == THROW:
		w_throw *= 0.3
	var roll: float = e.rng.randf() * (w_close + w_leap + w_throw)
	if roll < w_close:
		e.mem["last"] = BUSY
		if e.mem["armed"]:
			_begin_smash(e)
		else:
			e.mem["leaps"] = 1
			_begin_leap(e, e.position, POUND_RADIUS)
	elif roll < w_close + w_leap:
		e.mem["last"] = LEAP_AIR
		e.mem["leaps"] = 2 if mean else 1
		_begin_leap(e, e.player.position, float(e.p.get("shock_radius", 34.0)))
	else:
		e.mem["last"] = THROW
		e.mem["rocks"] = 5 if mean else 3
		e.state = THROW
		e.t = 0.5
		e.tell(0.5)


# ------------------------------------------------------------------------------ SMASH
func _begin_smash(e) -> void:
	e.state = BUSY
	e.face_player()
	var side := 1.0 if e.to_player().x >= 0.0 else -1.0
	var warn := float(e.p.get("smash_warn", 0.9))
	var impact: Vector2 = e.position + Vector2(side * float(e.p.get("smash_reach", 50.0)), 0.0)
	impact.x = clampf(impact.x, 8.0, G.ROOM_W - 8.0)
	e.mem["impact"] = impact
	# the hit frame comes exactly `warn` seconds from now; the shockwave follows when the swing is over
	var total: float = e.strike("attack", warn, _smash_hit, _smash_end)
	e.mem["tail"] = total - warn + 0.1
	e.mark_circle(impact, float(e.p.get("smash_radius", 26.0)), warn)
	e.mark_ring(impact, float(e.p.get("wave_inner", 30.0)), float(e.p.get("wave_outer", 58.0)), warn + float(e.mem["tail"]))


func _smash_hit(e, _frame: int) -> void:
	var impact: Vector2 = e.mem["impact"]
	e.strike_circle(impact, float(e.p.get("smash_radius", 26.0)))
	e.run.fx.burst(impact, DUST, 18, 90.0, 0.5, 2.6)
	e.run.shake(0.6)
	e.run.hitstop(0.04)
	Sfx.play("explosion", -6.0)
	e.after(float(e.mem["tail"]), _wave)


func _smash_end(e) -> void:
	# the pack's swing ends a step forward and has no step back: stand him where the swing left him
	e.position = e.room.move_circle(e.position, e.radius, Vector2(15.0 * e.facing, 0.0), false)


func _wave(e) -> void:
	var impact: Vector2 = e.mem["impact"]
	var inner := float(e.p.get("wave_inner", 30.0))
	var outer := float(e.p.get("wave_outer", 58.0))
	e.strike_ring(impact, inner, outer)
	e.run.fx.ring(impact, inner, outer, 0.3, Color(0.95, 0.45, 0.25), 3.0, true)
	e.run.fx.burst(impact, DUST, 14, 110.0, 0.4, 2.2)
	e.run.shake(0.35)
	e.state = WALK
	e.t = 0.5
	e.stagger(1.1)                     # the club is stuck in the floor: the breather


# ------------------------------------------------------------------------------ LEAP and POUND
func _begin_leap(e, to: Vector2, shock: float) -> void:
	e.state = BUSY
	e.target = Vector2(clampf(to.x, 14, G.ROOM_W - 14), clampf(to.y, 14, G.ROOM_H - 14))
	e.mem["shock"] = shock
	e.face(e.target - e.position)
	e.tell(CROUCH)
	e.mark_circle(e.target, shock, CROUCH + float(e.p.get("leap_time", 0.9)))
	e.after(CROUCH, _jump)


func _jump(e) -> void:
	e.state = LEAP_AIR
	e.t = float(e.p.get("leap_time", 0.9))
	e.mem["from"] = e.position
	e.hittable = false
	e.harmful = false
	if e.mem["armed"]:
		e.pose("attack", 3)            # the club raised over its head
	else:
		e.pose("run_unarmed", 1)


func _land(e, mean: bool) -> void:
	var r := float(e.mem["shock"])
	e.position = e.target
	e.lift = 0.0
	e.hittable = true
	e.harmful = true
	e.stop()
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 6.0, r, 0.3, Color(0.95, 0.45, 0.25), 3.0, true)
	e.run.fx.burst(e.position, DUST, 22, 100.0, 0.5, 2.8)
	e.run.shake(0.75)
	e.run.hitstop(0.04)
	Sfx.play("explosion", -5.0)
	e.ring_from(e.position, 10 if mean else 8, 62.0, "", e.rng.randf() * TAU)
	e.mem["leaps"] = int(e.mem["leaps"]) - 1
	if int(e.mem["leaps"]) > 0:
		_begin_leap(e, e.player.position, r)
	elif mean:
		e.state = WALK
		e.t = 0.4
		e.stagger(0.9)                 # winded after its jumps: the breather of phase 2
	else:
		e.state = REST
		e.t = 1.2


# ------------------------------------------------------------------------------ the club throw (phase 2 begins)
func _begin_hurl(e) -> void:
	e.state = BUSY
	e.face_player()
	var warn := float(e.p.get("club_warn", 0.8))
	e.dir = e.to_player().normalized() if e.dist_to_player() > 1.0 else Vector2.RIGHT
	var from: Vector2 = e.position + e.dir * 10.0
	var reach := _to_wall(from, e.dir)
	e.mem["club_at"] = from
	e.mem["club_left"] = reach
	e.pose("attack", 3)
	e.tell(warn)
	e.mark_lane(from, from + e.dir * reach, 9.0, warn)
	e.after(warn, _hurl)


func _hurl(e) -> void:
	e.mem["armed"] = false
	e.set_loops("idle_unarmed", "run_unarmed")
	e.stop()
	e.mem["club"] = e.cut_sprite("idle", 0, CLUB_RECT)
	e.state = CLUB_FLY
	Sfx.play("enemy_shoot", -2.0, 0.0, 0.7)
	_fly_club(e, 0.0)


func _fly_club(e, delta: float) -> void:
	var club: Sprite2D = e.mem["club"]
	var step: float = float(e.p.get("club_speed", 230.0)) * delta
	var at: Vector2 = (e.mem["club_at"] as Vector2) + e.dir * step
	e.mem["club_at"] = at
	e.mem["club_left"] = float(e.mem["club_left"]) - step
	if is_instance_valid(club):
		club.position = at - Vector2(0, 12)
		club.rotation += 20.0 * delta
	e.strike_circle(at, 10.0)
	if float(e.mem["club_left"]) <= 0.0:
		if is_instance_valid(club):
			club.queue_free()
		e.run.fx.burst(at - Vector2(0, 8), [Color(0.55, 0.24, 0.12), Color(0.35, 0.16, 0.10)], 16, 90.0, 0.5, 2.6)
		e.run.shake(0.5)
		Sfx.play("rock_break", -3.0)
		e.state = REST
		e.t = 0.7


## How far it is from `from` along `d` to the wall of the room.
func _to_wall(from: Vector2, d: Vector2) -> float:
	var best := 400.0
	if absf(d.x) > 0.001:
		best = minf(best, ((G.ROOM_W - 6.0 if d.x > 0.0 else 6.0) - from.x) / d.x)
	if absf(d.y) > 0.001:
		best = minf(best, ((G.ROOM_H - 6.0 if d.y > 0.0 else 6.0) - from.y) / d.y)
	return maxf(best, 0.0)
