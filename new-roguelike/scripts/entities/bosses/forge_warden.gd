extends RefCounted
## Boss "The Forge Warden" (floor 3, sprite boss_mecha_golem): a hovering golem of stone and brass.
## It keeps a middle distance, so short-range heroes can reach it, and it never turns its back.
##   ARM SHOT  ("attack") a red lane from its arm; on the hit frame the forearm (the pack's own arm
##             picture) flies down the lane to the wall AND COMES BACK the same way. The lane stays
##             marked until the arm is home. Step out of the lane and shoot: it stands still, one-armed.
##             Phase 2: the arm glows, flies faster and throws a ring of shots where it turns round.
##   SLAM      ("attack2") only when the hero is close: a red circle where the fist lands, then a
##             shockwave band round that spot. Stand outside the band.
##             Phase 2: a second, wider band follows: step in behind the first one, or stay far.
##   LASER     ("cast" + the pack's laser) a spark charges on its crystal while a red lane fills, then
##             the beam burns along the lane for laser_time s. Step out of the lane. The beam
##             overheats it: it hangs dazed afterwards (THE BREATHER).
##             Phase 2: the beam SWEEPS. A red wedge shows the ground it will cross and a red lane the
##             edge it starts on: cross that edge before it fires (the short way) or run ahead of it.
##   GUARD     ("block") it folds its arms, blinking, while blue rings close on it; then for guard_time
##             s a blue shield turns the hero's shots round (they come back as enemy shots) and it
##             drifts closer. Stop firing, or step out of your own line of fire.
##             Phase 2: it ends the guard with a blast ("glow"): a red circle, then a ring of shots.
## Phase 2 (half health) begins with the pack's "buff" animation and a sweeping LASER; all of it is faster.
## Its death and its entrance are the pack's own "death" frames (the row plays them backwards to enter).
## params (bosses.gd): keep px it likes to stand from the hero, arm_warn s, arm_speed px/s, arm_reach px,
##   slam_warn s, slam_radius px, wave_inner / wave_outer px, laser_warn s, laser_time s, vent s it is
##   dazed after a beam, sweep rad the phase-2 beam turns, sweep_time s, guard_time s, bounce_speed px/s
const Shots = preload("res://scripts/run/shots.gd")

const HOVER := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const ARM_OUT := 2
const ARM_TURN := 3
const ARM_BACK := 4
const BEAM := 5
const GUARD := 6
const REST := 7
const A_ARM := 0
const A_SLAM := 1
const A_LASER := 2
const A_GUARD := 3

const ARM := "boss_fx_mecha_golem_arm"
const ARM_GLOW := "boss_fx_mecha_golem_arm_glow"
const LASER := "boss_fx_mecha_golem_laser"
const LASER_EYE := Vector2(23, 23)   # the emitter in the laser picture (canvas px)
const LASER_REACH := 248.0           # px of beam the picture holds beyond the emitter
const ARM_HALF := 8.0
const ARM_BODY := 14.0               # half the length of the flying arm
const BEAM_HALF := 6.0
const WAVE_GAP := 0.45               # s between the fist and each shockwave band
const GUARD_WARN := 0.7
const BLAST_WARN := 0.7
const BLAST_RADIUS := 20.0
const BLUE := Color(0.35, 0.9, 1.0)
const DUST := [Color(0.62, 0.58, 0.56), Color(0.36, 0.33, 0.33)]
const SPARK := [Color(0.35, 0.9, 1.0), Color(0.9, 1.0, 1.0)]


func start(e) -> void:
	e.state = HOVER
	e.t = 1.2
	e.mem = {"last": -1, "next": -1, "arm": null, "arm_from": Vector2.ZERO, "arm_len": 0.0, "arm_go": 0.0,
		"arm_lift": Vector2.ZERO, "beam": null, "beam_from": Vector2.ZERO, "beam_px": Vector2.ZERO,
		"a0": 0.0, "a1": 0.0, "beam_t": 0.0, "impact": Vector2.ZERO, "pulse": 0.0, "blast": false,
		"blast_at": Vector2.ZERO}


func phase_changed(e, _phase: int) -> void:
	# the base has already taken back marks and timers; put away what this file made itself
	_drop(e)
	e.state = REST
	e.t = 0.3
	e.mem["next"] = A_LASER              # phase 2 shows its new trick first: the sweeping beam
	# the pack's "buff": it plays while the roar holds the boss still
	e.stun = maxf(e.stun, e.play("buff"))
	e._play_free = true
	e.run.fx.ring(e.body_point(), 40.0, 16.0, 0.6, BLUE, 2.0)


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		HOVER:
			var keep := float(e.p.get("keep", 58.0))
			var far: float = e.dist_to_player()
			if far > keep + 10.0:
				e.chase(delta, 1.3 if mean else 1.0)
			elif far < keep - 16.0:
				e.flee(delta, 0.8)
			e.face_player()
			if e.t <= 0.0:
				_pick(e, mean)
		ARM_OUT, ARM_TURN, ARM_BACK:
			_fly_arm(e, delta, mean)
		BEAM:
			_burn(e, delta, mean)
		GUARD:
			_guard(e, delta, mean)
		REST:
			if e.t <= 0.0:
				e.state = HOVER
				e.t = e.rng.randf_range(0.5, 0.9) if mean else e.rng.randf_range(0.9, 1.4)


func _pick(e, mean: bool) -> void:
	var next := int(e.mem["next"])
	e.mem["next"] = -1
	if next < 0:
		var near: bool = e.dist_to_player() < 64.0
		var w: Array[float] = [30.0, 46.0 if near else 0.0, 26.0, 18.0]
		var last := int(e.mem["last"])
		if last >= 0:
			w[last] *= 0.2
		var roll: float = e.rng.randf() * (w[0] + w[1] + w[2] + w[3])
		next = A_GUARD
		for k in 4:
			roll -= w[k]
			if roll < 0.0:
				next = k
				break
	e.mem["last"] = next
	match next:
		A_ARM:
			_begin_arm(e, mean)
		A_SLAM:
			_begin_slam(e, mean)
		A_LASER:
			_begin_laser(e, mean)
		_:
			_begin_guard(e)


# ------------------------------------------------------------------------------ ARM SHOT
func _begin_arm(e, mean: bool) -> void:
	e.state = BUSY
	e.face_player()
	var warn := float(e.p.get("arm_warn", 0.8)) * (0.75 if mean else 1.0)
	e.strike("attack", warn, _launch)
	e.mem["arm_lift"] = e.muzzle_px("attack") - e.muzzle("attack")
	var from: Vector2 = e.muzzle("attack")
	e.dir = (e.player.position - from).normalized() if from.distance_to(e.player.position) > 1.0 else Vector2(e.facing, 0.0)
	from = _onto_floor(from, e.dir)
	var length := minf(_to_wall(from, e.dir), float(e.p.get("arm_reach", 190.0)))
	e.mem["arm_from"] = from
	e.mem["arm_len"] = length
	e.mark_lane(from, from + e.dir * length, ARM_HALF, warn)
	Sfx.play("door_unlock", -6.0, 0.0, 0.7)


func _launch(e, _frame: int) -> void:
	var mean: bool = e.phase >= 2
	e.pose("attack", 8)                # one-armed until the arm is home again
	e.mem["arm"] = e.fx_sprite(ARM_GLOW if mean else ARM, e.muzzle_px("attack"), {"rot": e.dir.angle(), "loop": true, "life": 30.0})
	e.mem["arm_go"] = 0.0
	e.state = ARM_OUT
	# the lane fills again while the arm flies out ...
	var from: Vector2 = e.mem["arm_from"]
	var length := float(e.mem["arm_len"])
	e.mark_lane(from, from + e.dir * length, ARM_HALF, length / _arm_speed(e, mean))
	Sfx.play("enemy_shoot", -2.0, 0.0, 0.55)
	e.run.shake(0.3)
	_fly_arm(e, 0.0, mean)


func _arm_speed(e, mean: bool) -> float:
	return float(e.p.get("arm_speed", 200.0)) * (1.25 if mean else 1.0)


func _fly_arm(e, delta: float, mean: bool) -> void:
	var from: Vector2 = e.mem["arm_from"]
	var length := float(e.mem["arm_len"])
	var go := float(e.mem["arm_go"])
	var speed := _arm_speed(e, mean)
	if e.state == ARM_OUT:
		go = minf(go + speed * delta, length)
		if go >= length:
			# it bites into the wall (or reaches the end of its chain), hangs a moment and turns round
			e.state = ARM_TURN
			e.t = 0.25
			var tip: Vector2 = from + e.dir * length
			e.run.fx.burst(tip + (e.mem["arm_lift"] as Vector2), DUST, 12, 80.0, 0.4, 2.4)
			e.run.shake(0.4)
			Sfx.play("rock_break", -5.0, 0.0, 1.2)
			if mean:
				e.ring_from(tip - e.dir * 6.0, 8, 66.0, "", e.rng.randf() * TAU)
	elif e.state == ARM_TURN:
		if e.t <= 0.0:
			e.state = ARM_BACK
			e.mark_lane(from, from + e.dir * length, ARM_HALF, length / (speed * 1.15))   # ... and once more for the way home
	else:
		go -= speed * 1.15 * delta
	e.mem["arm_go"] = go
	# `go` is how far the fist is down the lane; the arm trails behind it
	var mid: Vector2 = from + e.dir * (go - ARM_BODY)
	var arm: Node2D = e.mem["arm"]
	if is_instance_valid(arm):
		arm.position = mid + (e.mem["arm_lift"] as Vector2)
	if go > 4.0:
		e.strike_lane(from + e.dir * maxf(go - ARM_BODY * 2.0, 0.0), from + e.dir * go, ARM_HALF - 1.0)
	if e.state == ARM_BACK and go <= 0.0:
		_drop(e)
		e.stop()
		Sfx.play("door_close", -6.0, 0.0, 1.5)
		e.run.fx.burst(e.muzzle_px("attack"), DUST, 6, 50.0, 0.3, 2.0)
		e.state = REST
		e.t = 0.35


# ------------------------------------------------------------------------------ SLAM
func _begin_slam(e, mean: bool) -> void:
	e.state = BUSY
	e.face_player()
	var warn := float(e.p.get("slam_warn", 0.8)) * (0.8 if mean else 1.0)
	e.strike("attack2", warn, _slam_hit)
	var impact: Vector2 = e.position + Vector2(e.facing * 36.0, 0.0)
	impact.x = clampf(impact.x, 8.0, G.ROOM_W - 8.0)
	e.mem["impact"] = impact
	var inner := float(e.p.get("wave_inner", 28.0))
	var outer := float(e.p.get("wave_outer", 60.0))
	e.mark_circle(impact, float(e.p.get("slam_radius", 24.0)), warn)
	e.mark_ring(impact, inner, outer, warn + WAVE_GAP)
	if mean:
		e.mark_ring(impact, outer + 2.0, outer * 2.0 - inner + 2.0, warn + WAVE_GAP * 2.0)


func _slam_hit(e, _frame: int) -> void:
	var impact: Vector2 = e.mem["impact"]
	e.strike_circle(impact, float(e.p.get("slam_radius", 24.0)))
	e.run.fx.burst(impact, DUST, 18, 90.0, 0.5, 2.6)
	e.run.shake(0.6)
	e.run.hitstop(0.04)
	Sfx.play("explosion", -6.0, 0.0, 0.8)
	e.after(WAVE_GAP, _wave)


func _wave(e) -> void:
	var inner := float(e.p.get("wave_inner", 28.0))
	var outer := float(e.p.get("wave_outer", 60.0))
	_band(e, inner, outer)
	if e.phase >= 2:
		e.after(WAVE_GAP, _wave_two)
	else:
		e.state = REST
		e.t = 0.6


func _wave_two(e) -> void:
	var inner := float(e.p.get("wave_inner", 28.0))
	var outer := float(e.p.get("wave_outer", 60.0))
	_band(e, outer + 2.0, outer * 2.0 - inner + 2.0)
	e.state = REST
	e.t = 0.5


func _band(e, inner: float, outer: float) -> void:
	var impact: Vector2 = e.mem["impact"]
	e.strike_ring(impact, inner, outer)
	e.run.fx.ring(impact, inner, outer, 0.3, Color(0.95, 0.45, 0.25), 3.0, true)
	e.run.fx.burst(impact, DUST, 10, 110.0, 0.4, 2.2)
	e.run.shake(0.35)
	Sfx.play("explosion", -10.0, 0.0, 1.3)


# ------------------------------------------------------------------------------ LASER
func _begin_laser(e, mean: bool) -> void:
	e.state = BUSY
	e.face_player()
	var warn := float(e.p.get("laser_warn", 0.9))
	e.strike("cast", warn, _beam_on)
	var from: Vector2 = e.muzzle("cast")
	var aim: float = (e.player.position - from).angle()
	var a0 := aim
	var a1 := aim
	if mean:
		var turn := float(e.p.get("sweep", 0.85))
		var side := _sweep_side(e, from)
		a0 = aim - side * turn * 0.35
		a1 = aim + side * turn * 0.65
		# the wedge: all the ground the beam will cross
		e.mark_cone(from, Vector2.RIGHT.rotated((a0 + a1) * 0.5), LASER_REACH, turn * 0.5, warn)
	e.mem["beam_from"] = from
	e.mem["beam_px"] = e.muzzle_px("cast")
	e.mem["a0"] = a0
	e.mem["a1"] = a1
	# the lane: where the beam appears
	var d0 := Vector2.RIGHT.rotated(a0)
	var start := _onto_floor(from, d0)
	e.mark_lane(start, start + d0 * minf(_to_wall(start, d0), LASER_REACH), BEAM_HALF, warn)
	# the pack's charge spark (frames 0 to 7 of the laser sheet) on its crystal for exactly that long
	e.fx_sprite(LASER, e.muzzle_px("cast"), {"from": 0, "to": 7, "anchor": LASER_EYE, "fps": 8.0 / warn, "flip": false})
	Sfx.play("bomb_fuse", -4.0, 0.0, 1.5)


## +1 or -1: which way the phase-2 beam turns. It starts on the side of the hero that has more
## room, because stepping over that starting edge is the quick way out.
func _sweep_side(e, from: Vector2) -> float:
	var rel: Vector2 = e.player.position - from
	var room_a := _wall_room(from + rel.rotated(-0.5))    # the way out if it turns clockwise (+1)
	var room_b := _wall_room(from + rel.rotated(0.5))
	if absf(room_a - room_b) < 4.0:
		return 1.0 if e.rng.randf() < 0.5 else -1.0
	return 1.0 if room_a > room_b else -1.0


func _wall_room(at: Vector2) -> float:
	return minf(minf(at.x, G.ROOM_W - at.x), minf(at.y, G.ROOM_H - at.y))


func _beam_on(e, _frame: int) -> void:
	var mean: bool = e.phase >= 2
	e.pose("cast", 6)
	# A plain sprite the base frees with the boss (cut_sprite registers it); its picture is swapped
	# for the pack's beam frames and cut off where the beam meets the wall.
	var beam: Sprite2D = e.cut_sprite("cast", 6, Rect2(0, 0, 1, 1))
	beam.centered = false
	beam.offset = -LASER_EYE
	beam.region_enabled = true
	beam.position = e.mem["beam_px"]
	e.mem["beam"] = beam
	e.mem["beam_t"] = 0.0
	e.state = BEAM
	e.run.shake(0.5)
	e.run.fx.flash(Color(0.6, 0.95, 1.0, 0.18), 0.1)
	Sfx.play("player_shoot_magic", 2.0, 0.0, 0.5)
	Sfx.play("explosion", -9.0, 0.0, 1.6)
	if mean:
		# the test bot keeps out of the whole wedge while the beam turns
		var mid := Vector2.RIGHT.rotated((float(e.mem["a0"]) + float(e.mem["a1"])) * 0.5)
		var from: Vector2 = e.mem["beam_from"]
		e.run.fx.hazards.append([2, from, from + mid * LASER_REACH, float(e.p.get("sweep", 0.85)) * 0.5,
			0.3 + float(e.p.get("sweep_time", 1.6)), e.get_instance_id(), 0.0])
	_burn(e, 0.0, mean)


func _burn(e, delta: float, mean: bool) -> void:
	var t := float(e.mem["beam_t"]) + delta
	e.mem["beam_t"] = t
	var hold := 0.3 if mean else float(e.p.get("laser_time", 0.7))
	var turning := float(e.p.get("sweep_time", 1.6)) if mean else 0.0
	var a := float(e.mem["a0"])
	if mean:
		a = lerpf(a, float(e.mem["a1"]), clampf((t - hold) / turning, 0.0, 1.0))
	var d := Vector2.RIGHT.rotated(a)
	var from: Vector2 = e.mem["beam_from"]
	var start := _onto_floor(from, d)
	var reach := minf(from.distance_to(start) + _to_wall(start, d), LASER_REACH)
	var beam: Sprite2D = e.mem["beam"]
	if is_instance_valid(beam):
		# frames 8 to 13 of the laser sheet: the flare first, then the steady beam
		var f := int(t * 14.0)
		beam.texture = Art.frames(LASER).get_frame_texture("default", 8 + f if f < 6 else 10 + (f - 6) % 4)
		beam.region_rect = Rect2(0.0, 0.0, LASER_EYE.x + reach, 46.0)
		beam.rotation = a
	var tip: Vector2 = from + d * reach
	e.strike_lane(start, tip, BEAM_HALF - 1.0)
	if not mean and delta > 0.0 and t < 0.1:
		e.run.fx.hazards.append([1, start, tip, BEAM_HALF, hold, e.get_instance_id(), 0.0])
	if fmod(t, 0.07) < delta:
		e.run.fx.burst(tip + (e.mem["beam_px"] as Vector2) - from, SPARK, 3, 70.0, 0.25, 2.0)
	if t >= hold + turning:
		_drop(e)
		e.stop()
		e.state = HOVER
		e.t = 0.5
		e.stagger(float(e.p.get("vent", 1.2)))     # overheated: the breather


# ------------------------------------------------------------------------------ GUARD
func _begin_guard(e) -> void:
	e.state = BUSY
	e.face_player()
	e.tell(GUARD_WARN)
	e.strike("block", GUARD_WARN, _guard_on)
	_shield_ring(e)
	e.after(GUARD_WARN * 0.33, _shield_ring)
	e.after(GUARD_WARN * 0.66, _shield_ring)
	Sfx.play("door_close", -4.0, 0.0, 1.6)


func _shield_ring(e) -> void:
	e.run.fx.ring(e.body_point(), 52.0, 30.0, 0.24, BLUE, 2.0)


func _guard_on(e, _frame: int) -> void:
	e.pose("block", 7)
	e.hittable = false
	e.state = GUARD
	e.t = float(e.p.get("guard_time", 2.0))
	e.mem["pulse"] = 0.0
	e.mem["blast"] = false
	Sfx.play("spike_trap", -5.0, 0.0, 1.4)


func _guard(e, delta: float, mean: bool) -> void:
	_reflect(e)
	# the shield: a blue ring that keeps pulsing round its body
	e.mem["pulse"] = float(e.mem["pulse"]) - delta
	if float(e.mem["pulse"]) <= 0.0:
		e.mem["pulse"] = 0.22
		e.run.fx.ring(e.body_point(), 29.0, 31.0, 0.3, BLUE, 2.0)
		e.run.fx.ring(e.body_point(), 31.0, 26.0, 0.3, Color(BLUE.r, BLUE.g, BLUE.b, 0.5), 1.0)
	if mean and not e.mem["blast"] and e.t <= BLAST_WARN:
		# phase 2: it lets the blow go as a ring of shots when the guard ends
		e.mem["blast"] = true
		var at: Vector2 = e.body_point() + Vector2(0.0, e.SHOT_PLANE)
		at.y = maxf(at.y, 8.0)
		e.mem["blast_at"] = at
		e.mark_circle(at, BLAST_RADIUS, e.t)
		e.tell(e.t)
		e.play("glow", Callable(), Callable(), e.anim_time("glow") / maxf(e.t, 0.1))
	elif not e.mem["blast"]:
		e.chase(delta, 0.55)
	if e.t <= 0.0:
		e.hittable = true
		e.stop()
		e.state = REST
		e.t = 0.5
		Sfx.play("door_open", -8.0, 0.0, 1.5)
		if e.mem["blast"]:
			var at: Vector2 = e.mem["blast_at"]
			e.strike_circle(at, BLAST_RADIUS)
			e.ring_from(at, 12, 72.0, "", e.rng.randf() * TAU)
			e.run.fx.ring(e.body_point(), 20.0, 60.0, 0.3, BLUE, 3.0)
			e.run.shake(0.5)
			Sfx.play("explosion", -6.0, 0.0, 1.2)


## Every shot of the hero that reaches the shield ends there, and an enemy shot flies back the way
## it came. (The hero's shot is ended by running its range out, so the shot manager finishes it in
## its own way: items still hear about it, a Tethered Sickle still flies home.)
func _reflect(e) -> void:
	var shots: Node = e.run.shots
	var mid: Vector2 = e.position - Vector2(0.0, e.hit_up)
	var reach: float = e.radius + e.hit_grow + 5.0
	var back: Array = []
	for i in shots.count:
		if shots.side[i] != Shots.SIDE_PLAYER or shots.bits[i] & Shots.B_BACK != 0 or shots.left[i] <= 0.0:
			continue
		var at: Vector2 = shots.pos[i]
		var v: Vector2 = shots.vel[i]
		var r: float = reach + shots.rad[i]
		if at.distance_squared_to(mid) > r * r or v.dot(mid - at) <= 0.0:
			continue
		shots.left[i] = 0.0
		back.append([at, -v])
	for b: Array in back:
		e.shoot_from(b[0], b[1], float(e.p.get("bounce_speed", 105.0)), "enemy")
		e.run.fx.burst((b[0] as Vector2) - Vector2(0.0, e.SHOT_PLANE), SPARK, 4, 60.0, 0.25, 2.0)
	if not back.is_empty():
		Sfx.play("shot_hit_wall", -6.0, 0.08, 1.7)


# ------------------------------------------------------------------------------ helpers
## Frees the flying arm and the beam.
func _drop(e) -> void:
	for key: String in ["arm", "beam"]:
		var node: Variant = e.mem[key]
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
		e.mem[key] = null


## A beam or an arm leaves from high on its body, which on screen is above the top of the floor
## when it hovers near the back wall: the mark and the damage begin where the line reaches the floor.
func _onto_floor(from: Vector2, d: Vector2) -> Vector2:
	if from.y < 2.0 and d.y > 0.001:
		return from + d * ((2.0 - from.y) / d.y)
	return from


## How far it is from `from` along `d` to the wall of the room.
func _to_wall(from: Vector2, d: Vector2) -> float:
	var best := 400.0
	if absf(d.x) > 0.001:
		best = minf(best, ((G.ROOM_W - 4.0 if d.x > 0.0 else 4.0) - from.x) / d.x)
	if absf(d.y) > 0.001:
		best = minf(best, ((G.ROOM_H - 4.0 if d.y > 0.0 else 4.0) - from.y) / d.y)
	return maxf(best, 0.0)
