extends RefCounted
## Boss "The Cinder Tyrant" (floor 3 spare, sprite boss_demon_slime; art by chierit, CC-BY 4.0).
## A reference fight: it uses the toolkit listed at the top of scripts/entities/boss.gd.
##   CHARGE  a red lane shows the path, then it rushes along it to the wall. It hits the wall
##           and is staggered: the breather.                       (phase 2: twice in a row)
##   CLEAVE  the pack's 15-frame cleave: a red cone fills in front of it and the blade lands on
##           the hit frame, hurting everything in the cone and throwing an arc of fire shots on
##   RAISE   red circles mark where dust mummies climb out of the floor
## Phase 2 (half health): it leaves BURNING GROUND for a few seconds, along its charge, where the
## charge ends and where the blade lands; it walks faster and warns a little shorter.
## It only looks left or right, so it cleaves only when the hero is roughly level with it.
## params (bosses.gd): charge_speed px/s, charge_warn s, cleave_warn s, cleave_reach px,
##   cleave_angle radians to each side, burn_seconds, minion (an enemy id)
const WALK := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const CHARGE := 2
const REST := 3
const MOVE_CHARGE := 0
const MOVE_CLEAVE := 1
const MOVE_RAISE := 2
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
					e.mem["trail"] = 46.0
					e.burn_ground(e.position, 15.0, float(e.p.get("burn_seconds", 3.5)), 0.3)
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
	var w_raise := 22.0 if e.minion_count() < (3 if mean else 2) else 0.0
	# do not repeat the same move three times
	var last := int(e.mem["last"])
	if last == MOVE_CHARGE:
		w_charge *= 0.4
	elif last == MOVE_CLEAVE:
		w_cleave *= 0.4
	elif last == MOVE_RAISE:
		w_raise = 0.0
	var roll: float = e.rng.randf() * (w_charge + w_cleave + w_raise)
	if roll < w_cleave:
		e.mem["last"] = MOVE_CLEAVE
		_begin_cleave(e, mean)
	elif roll < w_cleave + w_raise:
		e.mem["last"] = MOVE_RAISE
		_begin_raise(e, mean)
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
		_begin_charge(e, 0.55)
		return
	if mean:
		e.burn_ground(e.position + e.dir * 12.0, 24.0, float(e.p.get("burn_seconds", 3.5)), 0.4)
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
	# the arc of fire: shots fan out over the cone's angle and fly on past its end
	e.fan_from(e.position + e.dir * 34.0, e.dir, 7 if mean else 5, angle * 2.0, 78.0)
	if mean:
		e.burn_ground(blade, 24.0, float(e.p.get("burn_seconds", 3.5)), 0.5)


func _cleave_end(e) -> void:
	e.state = REST
	e.t = 0.6 if e.phase >= 2 else 0.9


# ------------------------------------------------------------------------------ RAISE
func _begin_raise(e, mean: bool) -> void:
	e.state = BUSY
	e.tell(0.9)
	e.summon_minions(String(e.p.get("minion", "dust_mummy")), 3 if mean else 2, {"max": 3 if mean else 2, "delay": 0.9})
	e.after(0.9, _raise_done)


func _raise_done(e) -> void:
	e.state = REST
	e.t = 0.6
