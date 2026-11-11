extends RefCounted
## Boss "The Red Sexton" (floor 1 spare, sprite boss_death): a small red-hooded reaper with a lamp.
## A quick duellist, the opposite of the Pyre Saint: little health, never where you aim. It circles
## the hero at a distance and never just runs at him. The toolkit is at the top of scripts/entities/boss.gd.
## The pack drew only: run (with the lamp), run_nolamp, and "spawn" (it climbs out of the floor,
## scythe first). The whole fight is built from those three.
##   GRAVE STEP   It sinks into the floor ("spawn" backwards) and is gone. Warning: its grave mound
##                and a red circle appear beside the hero, in the way he is walking. When the circle
##                is full the scythe bursts out of the floor there ("spawn" frame 2) and cuts
##                everything in the circle. The player: turn away from the circle, then come back
##                and hit it: climbing out takes it almost 2 s and it cannot hurt until it stands.
##                THAT is the breather. Phase 2: it steps twice, the second mark comes sooner.
##   BLADE FAN    Warning: it stops, blinks, and a red wedge shows where the blades will fly.
##                Then it throws a fan of knives down the wedge. The player: step out of the wedge
##                (or stand between two blades far away). Phase 2: a second, narrower fan follows,
##                aimed again.
##   RAISE        Warning: it stops and lifts its lamp, small red circles mark the floor. Shamblers
##                climb out there (never more than three alive). The player: lead them into the
##                Curse or cut them down. Phase 2: three at once.
## Phase 2 (half health): it smashes its lamp where it stands (the oil burns on the floor for a
## few seconds), walks faster without it ("run_nolamp") and chains its moves as written above.
## params (bosses.gd): step_warn s, step2_warn s, blade_radius px, step_far px (how far from the
##   hero it comes up), fan_warn s, fan_blades, fan_angle radians to each side, fan_speed px/s,
##   helper (enemy id), helpers, helpers2, near / far px (the distance it keeps), lamp_burn s
const WALK := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const SINK := 2
const UNDER := 3
const MOVE_STEP := 0
const MOVE_FAN := 1
const MOVE_RAISE := 2
const SINK_TIME := 0.45
const BLADE := "sexton_blade"
const EMBERS := [Color(1.0, 0.62, 0.15), Color(0.85, 0.30, 0.08), Color(0.55, 0.10, 0.08)]
const CLOTH := [Color(0.78, 0.10, 0.10), Color(0.45, 0.05, 0.08), Color(0.85, 0.85, 0.95)]


func start(e) -> void:
	e.state = WALK
	e.t = 1.0
	e.mem = {"last": -1, "side": 1.0, "chain": 0, "from": 10, "sink": SINK_TIME, "first": true}


func phase_changed(e, _phase: int) -> void:
	# wherever it was (even under the floor) it stands up, and the lamp goes
	e.stop()
	e.shadow.visible = true
	e.set_loops("run_nolamp", "run_nolamp")
	e.run.fx.burst(e.at_feet(Vector2(6.0, -8.0)), EMBERS, 18, 80.0, 0.5, 2.4)
	e.burn_ground(e.position, 20.0, float(e.p.get("lamp_burn", 3.5)), 0.9)
	Sfx.play("rock_break", -5.0, 0.05, 1.6)
	e.harmful = false                      # the hero may be right beside it, hitting it as it climbed out
	e.after(0.9, _harm_on)
	e.state = WALK
	e.t = 0.9


func _harm_on(e) -> void:
	e.harmful = true


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		WALK:
			_circle(e, delta, 1.3 if mean else 1.0)
			if e.t <= 0.0:
				_pick(e, mean)
		SINK:
			var k := clampf(e.t / float(e.mem["sink"]), 0.0, 1.0)
			e.pose("spawn", int(roundf(k * float(e.mem["from"]))))
			if e.t <= 0.0:
				e.hittable = false             # gone: shots pass over the mound
				e.shadow.visible = false
				e.state = UNDER
				e.t = 0.3
		UNDER:
			if e.t <= 0.0:
				_surface(e)


## How it walks: it keeps its distance and circles, like a fencer.
func _circle(e, delta: float, mult: float) -> void:
	var d: float = e.dist_to_player()
	if d > float(e.p.get("far", 85.0)):
		e.chase(delta, mult, 0.5 * float(e.mem["side"]))
	elif d < float(e.p.get("near", 46.0)):
		e.flee(delta, mult)
	elif e.move_dir(e.to_player().orthogonal() * float(e.mem["side"]), delta, mult):
		e.mem["side"] = -float(e.mem["side"])      # a wall: circle the other way


func _pick(e, mean: bool) -> void:
	var w_step := 50.0
	var w_fan := 36.0 if e.line_of_sight() else 6.0
	var w_raise := 24.0 if e.minion_count() < 2 else 0.0
	var last := int(e.mem["last"])
	if e.mem["first"]:
		e.mem["first"] = false             # the fight opens with its signature move
		w_fan = 0.0
		w_raise = 0.0
	elif last == MOVE_STEP:
		w_step *= 0.35
	elif last == MOVE_FAN:
		w_fan *= 0.35
	elif last == MOVE_RAISE:
		w_raise = 0.0
	var roll: float = e.rng.randf() * (w_step + w_fan + w_raise)
	if roll < w_fan:
		e.mem["last"] = MOVE_FAN
		_begin_fan(e, float(e.p.get("fan_warn", 0.7)), int(e.p.get("fan_blades", 5)), 2 if mean else 1)
	elif roll < w_fan + w_raise:
		e.mem["last"] = MOVE_RAISE
		_begin_raise(e, mean)
	else:
		e.mem["last"] = MOVE_STEP
		e.mem["chain"] = 1 if mean else 0
		_begin_sink(e, 10, SINK_TIME)


func _walk_again(e) -> void:
	e.stop()
	e.state = WALK
	e.t = e.rng.randf_range(0.7, 1.1) if e.phase >= 2 else e.rng.randf_range(1.0, 1.5)


# ------------------------------------------------------------------------------ GRAVE STEP
## It goes down: the "spawn" frames backwards, from frame `from` to the bare mound.
func _begin_sink(e, from: int, seconds: float) -> void:
	e.state = SINK
	e.t = seconds
	e.mem["from"] = from
	e._say("GRAVE STEP" if from == 10 else "second step")
	e.mem["sink"] = seconds
	e.harmful = false
	e.run.fx.burst(e.position, EMBERS, 8, 40.0, 0.4, 2.0)
	Sfx.play("door_close", -6.0, 0.05, 0.75)   # a deep thud (the Curse uses this sound high)


## Where it comes up: beside the hero, in the way he is walking, on free floor.
func _spot(e) -> Vector2:
	var hero: Vector2 = e.player.position
	var far := float(e.p.get("step_far", 28.0))
	var vel: Vector2 = e.player.vel
	var base: float = vel.angle() if vel.length() > 20.0 else e.rng.randf() * TAU
	for k in 8:
		# straight ahead first, then further and further to the sides
		var a := base + ceilf(float(k) * 0.5) * (PI / 4.0) * (1.0 if k % 2 == 1 else -1.0)
		var q := hero + Vector2.from_angle(a) * far
		if q.x < 12.0 or q.x > G.ROOM_W - 12.0 or q.y < 12.0 or q.y > G.ROOM_H - 10.0:
			continue
		if e.room.blocks_walk(G.cell_of(q)):
			continue
		return q
	return e.room.free_spot_near(hero)


func _surface(e) -> void:
	e.state = BUSY
	e.position = _spot(e)
	e.face_player()
	var second: bool = e.mem["from"] != 10
	var warn := float(e.p.get("step2_warn", 0.6)) if second else float(e.p.get("step_warn", 0.8))
	e.mark_circle(e.position, float(e.p.get("blade_radius", 16.0)), warn)
	e.run.fx.burst(e.position, EMBERS, 6, 30.0, 0.4, 2.0)
	Sfx.play("bomb_fuse", -8.0, 0.05, 1.3)
	# the mound lies there while the circle fills; the scythe comes up on the hit frame
	e.strike("spawn", warn, _blade, _risen)


func _blade(e, _frame: int) -> void:
	var r := float(e.p.get("blade_radius", 16.0))
	e.hittable = true
	e.shadow.visible = true
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 3.0, r, 0.22, Color(1.0, 0.3, 0.2), 2.0, true)
	e.run.fx.burst(e.position, EMBERS, 14, 90.0, 0.45, 2.4, Vector2.UP, 120.0)
	e.run.shake(0.35)
	Sfx.play("spike_trap", -3.0, 0.06, 0.85)
	if int(e.mem["chain"]) > 0:
		e.mem["chain"] = int(e.mem["chain"]) - 1
		e.after(0.3, _dive_again)


func _dive_again(e) -> void:
	e.stop()
	_begin_sink(e, 3, 0.2)


func _risen(e) -> void:
	e.harmful = true
	_walk_again(e)
	e.t = 0.5


# ------------------------------------------------------------------------------ BLADE FAN
func _begin_fan(e, warn: float, blades: int, fans: int) -> void:
	e.state = BUSY
	e.mem["fans"] = fans
	e._say("BLADE FAN")
	e.mem["blades"] = blades
	e.face_player()
	e.dir = e.to_player().normalized() if e.dist_to_player() > 1.0 else Vector2(e.facing, 0.0)
	e.pose(e.run_anim, 2)
	e.tell(warn)
	e.mark_cone(e.position, e.dir, 84.0, float(e.p.get("fan_angle", 0.42)) * (1.0 if blades >= 5 else 0.7), warn)
	e.after(warn, _fan_throw)


func _fan_throw(e) -> void:
	var blades := int(e.mem["blades"])
	var arc := float(e.p.get("fan_angle", 0.42)) * (1.7 if blades >= 5 else 1.2)
	e.pose(e.run_anim, 4)
	e.fan_from(e.position + e.dir * 8.0, e.dir, blades, arc, float(e.p.get("fan_speed", 105.0)), BLADE)
	e.run.fx.burst(e.position + e.dir * 10.0, CLOTH, 6, 60.0, 0.3, 2.0, e.dir)
	Sfx.play("player_shoot_knife", -2.0, 0.08, 0.7)
	e.mem["fans"] = int(e.mem["fans"]) - 1
	if int(e.mem["fans"]) > 0:
		e.after(0.25, _fan_again)
	else:
		e.after(0.45, _walk_again)


func _fan_again(e) -> void:
	_begin_fan(e, 0.55, 4, 1)


# ------------------------------------------------------------------------------ RAISE
func _begin_raise(e, mean: bool) -> void:
	e.state = BUSY
	e._say("RAISE")
	e.face_player()
	e.pose(e.run_anim, 0)
	e.tell(0.9)
	e.run.fx.burst(e.at_feet(Vector2(6.0, -8.0)), EMBERS, 10, 45.0, 0.6, 2.0, Vector2.UP, -40.0)
	Sfx.play("boss_roar", -8.0, 0.05, 1.7)
	e.summon_minions(String(e.p.get("helper", "shambler")), int(e.p.get("helpers2", 3)) if mean else int(e.p.get("helpers", 2)), {"max": 3, "delay": 0.9})
	e.after(1.0, _walk_again)
