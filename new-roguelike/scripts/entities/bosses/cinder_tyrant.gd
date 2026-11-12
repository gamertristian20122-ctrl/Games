extends RefCounted
## Boss "The Cinder Tyrant" (floor 3 spare, sprite boss_demon_slime; art by chierit, CC-BY 4.0).
## A reference fight: it uses the toolkit listed at the top of scripts/entities/boss.gd.
##   CHARGE  a red lane shows the path, then it rushes along it to the wall. It hits the wall
##           and is staggered: the breather.                       (phase 2: twice in a row)
##   CLEAVE  the pack's 15-frame cleave: a red cone fills in front of it and the blade lands on
##           the hit frame, hurting everything in the cone and throwing an arc of fire shots on
##   SLAM    it heaves the blade up and brings it down where it stands: a red circle fills round
##           it, then a ring of shots bursts out                    (phase 2: a second ring follows)
## Phase 2 (half health): it leaves BURNING GROUND for a few seconds, along its charge, where the
## charge ends and where the blade lands; it walks faster and warns a little shorter.
## It only looks left or right, so it cleaves only when the hero is roughly level with it and
## slams when he is close but above or below.
## (No helpers: fast monsters at the feet of a boss this big made the room unfair. A fight that
## wants them calls e.summon_minions(), see boss.gd.)
## params (bosses.gd): charge_speed px/s, charge_warn s, cleave_warn s, cleave_reach px,
##   cleave_angle radians to each side, slam_radius px, slam_warn s, burn_seconds
const WALK := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const CHARGE := 2
const REST := 3
const MOVE_CHARGE := 0
const MOVE_CLEAVE := 1
const MOVE_SLAM := 2
const DUST := [Color(0.5, 0.45, 0.4), Color(0.3, 0.28, 0.26)]
const FIRE := [Color(1.0, 0.75, 0.2), Color(1.0, 0.42, 0.12), Color(0.8, 0.2, 0.1)]


func start(e) -> void:
	e.state = WALK
	e.t = 1.4
	e.mem = {"charges": 0, "last": -1, "left": 0.0, "trail": 0.0}


func phase_changed(e, _phase: int) -> void:
	e.state = REST
	e.t = 0.5


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		WALK:
			e.chase(delta, 1.3 if mean else 1.0)
			if e.t <= 0.0:
				_pick(e, mean)
		CHARGE:
			var v := float(e.p.get("charge_speed", 175.0)) * (1.15 if mean else 1.0)
			var blocked: bool = e.dash(e.dir * v, delta)
			e.mem["left"] = float(e.mem["left"]) - v * delta
			if e.rng.randf() < 0.5:
				e.run.fx.burst(e.position, DUST, 1, 25.0, 0.35, 2.2)
			if mean:
				e.mem["trail"] = float(e.mem["trail"]) - v * delta
				if float(e.mem["trail"]) <= 0.0:
					e.mem["trail"] = 60.0          # small fires with gaps to slip through
					e.burn_ground(e.position, 12.0, float(e.p.get("burn_seconds", 3.5)) * 0.7, 0.3)
			if blocked or float(e.mem["left"]) <= 0.0:
				_charge_ends(e, mean)
		REST:
			if e.t <= 0.0:
				e.state = WALK
				e.t = e.rng.randf_range(0.7, 1.2) if mean else e.rng.randf_range(1.2, 1.9)


func _pick(e, mean: bool) -> void:
	var off: Vector2 = e.to_player()
	var reach := float(e.p.get("cleave_reach", 122.0))
	var w_cleave := 48.0 if absf(off.x) < reach - 12.0 and absf(off.y) < 32.0 else 0.0
	var w_charge := 40.0 if e.room.walk_clear(e.position, e.player.position) else 8.0
	var w_slam := 26.0 + (30.0 if off.length() < 70.0 else 0.0)
	# do not repeat the same move three times
	var last := int(e.mem["last"])
	if last == MOVE_CHARGE:
		w_charge *= 0.4
	elif last == MOVE_CLEAVE:
		w_cleave *= 0.4
	elif last == MOVE_SLAM:
		w_slam *= 0.3
	var roll: float = e.rng.randf() * (w_charge + w_cleave + w_slam)
	if roll < w_cleave:
		e.mem["last"] = MOVE_CLEAVE
		_begin_cleave(e, mean)
	elif roll < w_cleave + w_slam:
		e.mem["last"] = MOVE_SLAM
		_begin_slam(e)
	else:
		e.mem["last"] = MOVE_CHARGE
		e.mem["charges"] = 2 if mean else 1
		_begin_charge(e, float(e.p.get("charge_warn", 0.75)) * (0.8 if mean else 1.0))


# ------------------------------------------------------------------------------ CHARGE
func _begin_charge(e, warn: float) -> void:
	e.state = BUSY
	e.dir = e.to_player().normalized() if e.dist_to_player() > 1.0 else Vector2.RIGHT
	e.face(e.dir)
	var reach: float = e.room.ray_walk(e.position, e.dir, 260.0)
	e.mem["left"] = reach + 6.0
	e.mem["trail"] = 24.0
	e.pose("attack", 4)                # crouched, the blade drawn back
	e.tell(warn)
	e.mark_charge(e.dir, reach + 10.0, warn)
	e.after(warn, _charge_go)


func _charge_go(e) -> void:
	e.stop()
	e.state = CHARGE


func _charge_ends(e, mean: bool) -> void:
	e.run.shake(0.45)
	e.run.fx.ring(e.position, 4.0, 26.0, 0.25, Color(0.95, 0.45, 0.25), 2.0, true)
	e.run.fx.burst(e.position, DUST, 14, 80.0, 0.45, 2.4)
	Sfx.play("rock_break", -4.0)
	e.mem["charges"] = int(e.mem["charges"]) - 1
	if int(e.mem["charges"]) > 0:
		_begin_charge(e, 0.6)
		return
	if mean:
		e.burn_ground(e.position + e.dir * 12.0, 20.0, float(e.p.get("burn_seconds", 3.5)), 0.4)
	e.state = WALK
	e.t = 0.5
	e.stagger(0.9 if mean else 1.2)    # it ran into the wall: the breather


# ------------------------------------------------------------------------------ CLEAVE
func _begin_cleave(e, mean: bool) -> void:
	e.state = BUSY
	e.face_player()
	e.dir = Vector2(1.0 if e.to_player().x >= 0.0 else -1.0, 0.0)
	var warn := float(e.p.get("cleave_warn", 0.9)) * (0.85 if mean else 1.0)
	e.mark_cone(e.position, e.dir, float(e.p.get("cleave_reach", 122.0)), float(e.p.get("cleave_angle", 0.5)), warn)
	e.strike("attack", warn, _cleave_hit, _cleave_end)


func _cleave_hit(e, _frame: int) -> void:
	var mean: bool = e.phase >= 2
	var reach := float(e.p.get("cleave_reach", 122.0))
	var angle := float(e.p.get("cleave_angle", 0.5))
	e.strike_cone(e.position, e.dir, reach, angle)
	var blade: Vector2 = e.position + e.dir * reach * 0.62
	e.run.fx.burst(blade, FIRE, 26, 120.0, 0.5, 2.8)
	e.run.fx.ring(blade, 6.0, 30.0, 0.3, Color(1.0, 0.45, 0.15), 3.0, true)
	e.run.shake(0.65)
	e.run.hitstop(0.05)
	Sfx.play("explosion", -5.0)
	# the arc of fire: shots fan out INSIDE the cone (a little narrower, so its edges stay safe) and fly on past its end
	e.fan_from(e.position + e.dir * 34.0, e.dir, 7 if mean else 5, angle * 1.6, 78.0)
	if mean:
		e.burn_ground(blade, 24.0, float(e.p.get("burn_seconds", 3.5)), 0.5)


func _cleave_end(e) -> void:
	e.state = REST
	e.t = 0.6 if e.phase >= 2 else 0.9


# ------------------------------------------------------------------------------ SLAM
func _begin_slam(e) -> void:
	e.state = BUSY
	var warn := float(e.p.get("slam_warn", 0.8))
	e.face_player()
	e.pose("attack", 7)                # the blade heaved up over its head
	e.tell(warn)
	e.mark_circle(e.position, float(e.p.get("slam_radius", 44.0)), warn)
	e.after(warn, _slam)


func _slam(e) -> void:
	var r := float(e.p.get("slam_radius", 44.0))
	e.pose("attack", 10)               # the blade in the floor
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 6.0, r, 0.3, Color(1.0, 0.45, 0.15), 3.0, true)
	e.run.fx.burst(e.position, FIRE, 20, 100.0, 0.5, 2.6)
	e.run.shake(0.6)
	Sfx.play("explosion", -6.0)
	e.ring_from(e.position, 10, 60.0)
	if e.phase >= 2:
		e.after(0.45, _slam_echo)
	else:
		e.after(0.35, _slam_done)


func _slam_echo(e) -> void:
	e.ring_from(e.position, 10, 60.0, "", PI / 10.0)
	e.run.shake(0.3)
	e.after(0.3, _slam_done)


func _slam_done(e) -> void:
	e.stop()
	e.state = REST
	e.t = 0.7 if e.phase >= 2 else 1.0
