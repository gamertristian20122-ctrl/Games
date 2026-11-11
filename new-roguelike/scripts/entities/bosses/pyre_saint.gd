extends RefCounted
## Boss "The Pyre Saint" (floor 1, sprite boss_fire_skull): a giant burning skull, the FIRST boss a
## new player meets, so every warning is long and every pattern simple. It drifts after the hero,
## works through its three attacks, and then its flame gutters out: the reward for surviving.
## The toolkit is listed at the top of scripts/entities/boss.gd.
##   EMBER RING   Warning: it stops and blinks while a red circle fills under it. Then the circle
##                burns and a ring of slow fire shots rolls out with ONE wide gap on the hero's side.
##                The player: leave the circle, walk through the gap.
##                Phase 2: a second ring follows, its gap turned a quarter of the way round.
##   SWOOP        Warning: a red lane from the skull to the wall. It rushes down the lane, hangs at
##                the wall, marks a second lane at the hero and rushes again (one rebound).
##                The player: step out of the lane, twice. Phase 2: faster, the rebound comes sooner.
##   CANDLE RAIN  Warning: small red circles appear one after another where the hero stands or is
##                heading; each erupts in flame when it is full.
##                The player: keep walking, do not turn back into a circle.
##                Phase 2: more candles, and each keeps burning for a moment.
##   GUTTERS OUT  (the breather, after every third attack) the flame dies: the bare skull ("nofire")
##                sinks to the floor, is harmless to touch and takes "stagger_dmg" times the damage
##                for gutter_seconds. Then a red circle fills under it and it catches fire again.
##                Phase 2: two skeletons climb out of the floor each time it gutters.
## Phase 1 always goes ring, swoop, rain (easy to learn); phase 2 shuffles the three.
## It tumbles, so it has no facing ("no_facing" in its row). Animations: idle (burning), nofire.
## params (bosses.gd): warn s (ring and relight), flare_radius px, ring_shots, ring_gap radians to
##   each side, ring_speed px/s, swoop_warn s, rebound_warn s, swoop_speed px/s, candles, candles2,
##   candle_radius px, candle_warn s, candle_gap s, gutter_seconds, sink px, helper (enemy id), helpers
const DRIFT := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const SWOOP := 2
const REST := 3
const GUTTER := 4          # the flame dies and the skull sinks
const OUT := 5             # it lies on the floor (the boss is staggered: this file is not ticked)
const RELIGHT := 6
const MOVE_RING := 0
const MOVE_SWOOP := 1
const MOVE_RAIN := 2
const FIRE := [Color(1.0, 0.82, 0.35), Color(0.92, 0.42, 0.10), Color(0.72, 0.08, 0.07)]
const SMOKE := [Color(0.34, 0.30, 0.30), Color(0.20, 0.18, 0.20), Color(0.50, 0.44, 0.40)]


func start(e) -> void:
	e.state = DRIFT
	e.t = 1.8
	e.mem = {"done": 0, "bag": [], "left": 0.0, "legs": 0, "drops": 0, "pending": [], "out": false, "gap": 0.0}


func phase_changed(e, _phase: int) -> void:
	e.mem["pending"] = []
	if e.mem["out"]:
		# half health usually falls while it lies on the floor: it stays harmless until it has
		# caught fire again, with the usual warning
		e.harmful = false
		e.lift = -float(e.p.get("sink", 20.0))
		e.state = OUT
		return
	e.stop()
	e.set_loops("idle")
	e.state = DRIFT
	e.t = 1.0


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		DRIFT:
			e.chase(delta, 1.25 if mean else 1.0)
			if e.t <= 0.0:
				_next_attack(e, mean)
		SWOOP:
			var v: float = float(e.p.get("swoop_speed", 185.0)) * (1.15 if mean else 1.0) * e.status_speed()
			# it flies EXACTLY down the marked lane (no sliding along a wall: _aim keeps the lane inside the room)
			var go := minf(v * delta, float(e.mem["left"]))
			e.position += e.dir * go
			e.mem["left"] = float(e.mem["left"]) - go
			e.run.fx.burst(e.body_point() - e.dir * 18.0, FIRE, 1, 30.0, 0.4, 2.6)
			if float(e.mem["left"]) <= 0.01:
				_swoop_ends(e, mean)
		REST:
			if e.t <= 0.0:
				_attack_done(e)
		GUTTER:
			var sink := float(e.p.get("sink", 20.0))
			e.lift = move_toward(e.lift, -sink, sink / 0.4 * delta)
			if e.t <= 0.0:
				e.state = OUT
				e.stagger(float(e.p.get("gutter_seconds", 3.0)), "nofire")
				e.lift = -sink                 # stagger() stands a boss on the floor; this one lies on it
		OUT:
			_begin_relight(e)                  # first tick after the stagger
		RELIGHT:
			e.lift = move_toward(e.lift, 0.0, float(e.p.get("sink", 20.0)) / 0.5 * delta)
			if e.t <= 0.0:
				_relit(e)


# three attacks, then the flame gutters out
func _next_attack(e, mean: bool) -> void:
	if int(e.mem["done"]) >= 3:
		_begin_gutter(e, mean)
		return
	var bag: Array = e.mem["bag"]
	if bag.is_empty():
		bag = [MOVE_RING, MOVE_SWOOP, MOVE_RAIN]
		if mean:
			for k in range(2, 0, -1):
				var j: int = e.rng.randi_range(0, k)
				var keep: int = bag[k]
				bag[k] = bag[j]
				bag[j] = keep
	var move: int = bag.pop_front()
	e.mem["bag"] = bag
	e.mem["done"] = int(e.mem["done"]) + 1
	match move:
		MOVE_RING:
			_begin_ring(e)
		MOVE_SWOOP:
			e.mem["legs"] = 2
			_begin_swoop(e, float(e.p.get("swoop_warn", 0.9)))
		_:
			_begin_rain(e, mean)


func _attack_done(e) -> void:
	e.state = DRIFT
	e.t = 0.9 if e.phase >= 2 else 1.3


# ------------------------------------------------------------------------------ EMBER RING
func _begin_ring(e) -> void:
	e.state = BUSY
	e._say("EMBER RING")
	var warn := float(e.p.get("warn", 0.8))
	e.tell(warn)
	e.mark_circle(e.position, float(e.p.get("flare_radius", 30.0)), warn)
	# the gap opens near the hero, a little to one side: he has to line up with it
	e.mem["gap"] = e.to_player().angle() + e.rng.randf_range(0.35, 0.6) * (1.0 if e.rng.randf() < 0.5 else -1.0)
	Sfx.play("bomb_fuse", -6.0, 0.05, 0.8)
	e.after(warn, _ring_fire)


func _ring_fire(e) -> void:
	var r := float(e.p.get("flare_radius", 30.0))
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 6.0, r, 0.3, FIRE[1], 3.0, true)
	e.run.fx.burst(e.body_point(), FIRE, 22, 110.0, 0.5, 2.8)
	e.run.shake(0.45)
	Sfx.play("explosion", -6.0, 0.06, 1.15)
	_ring(e, float(e.mem["gap"]))
	if e.phase >= 2:
		e.tell(0.8)
		e.after(0.8, _ring_second)
	else:
		e.after(0.5, _attack_done)


func _ring_second(e) -> void:
	e.run.fx.burst(e.body_point(), FIRE, 14, 90.0, 0.45, 2.6)
	e.run.shake(0.3)
	Sfx.play("explosion", -8.0, 0.06, 1.3)
	_ring(e, float(e.mem["gap"]) + (PI * 0.5 if e.rng.randf() < 0.5 else -PI * 0.5))
	e.after(0.5, _attack_done)


## A ring of slow shots from under the skull, without the ones inside the gap.
func _ring(e, gap_at: float) -> void:
	var n := int(e.p.get("ring_shots", 16))
	var half := float(e.p.get("ring_gap", 0.7))
	var v := float(e.p.get("ring_speed", 48.0))
	for k in n:
		var a := gap_at + TAU * (float(k) + 0.5) / float(n)
		if absf(angle_difference(a, gap_at)) < half:
			continue
		e.shoot_from(e.position, Vector2.from_angle(a), v)


# ------------------------------------------------------------------------------ SWOOP
func _begin_swoop(e, warn: float) -> void:
	e.state = BUSY
	var reach := _aim(e)
	e.mem["left"] = reach
	e.tell(warn)
	_mark_swoop(e, warn)
	e._say("SWOOP")
	Sfx.play("boss_roar", -9.0, 0.05, 1.5)
	e.after(warn, _swoop_go)


## Aims a swoop at the hero and returns how far it goes. Its body is too big to reach the last
## strip of floor along a wall, so it aims at the nearest spot it CAN reach: the lane it marks is
## then exactly the lane it flies.
func _aim(e) -> float:
	var r: float = e.radius
	var lo := Vector2(r, r)
	var hi := Vector2(G.ROOM_W - r, G.ROOM_H - r)
	var from: Vector2 = (e.position as Vector2).clamp(lo, hi)
	e.position = from
	var to: Vector2 = (e.player.position as Vector2).clamp(lo, hi)
	var d := to - from
	e.dir = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	# how far along e.dir until the middle of the body meets the wall
	var reach := 400.0
	if absf(e.dir.x) > 0.001:
		reach = minf(reach, ((hi.x if e.dir.x > 0.0 else lo.x) - from.x) / e.dir.x)
	if absf(e.dir.y) > 0.001:
		reach = minf(reach, ((hi.y if e.dir.y > 0.0 else lo.y) - from.y) / e.dir.y)
	return maxf(reach, 0.0)


func _swoop_go(e) -> void:
	e.state = SWOOP
	# the lane stays red for as long as the skull is flying down it
	_mark_swoop(e, maxf(float(e.mem["left"]) / float(e.p.get("swoop_speed", 185.0)), 0.2))


## The lane of a swoop: a little wider than the body really is (standing just outside the red is
## safe with room to spare, also when the skull comes to rest there) and long enough for the body
## at its far end.
func _mark_swoop(e, seconds: float) -> void:
	var to: Vector2 = e.position + e.dir * (float(e.mem["left"]) + 24.0)
	e.mark_lane(e.position, to, e.radius + e.player.radius + 4.0, seconds)
	Sfx.play("enemy_shoot", -3.0, 0.05, 0.6)


func _swoop_ends(e, mean: bool) -> void:
	e.run.shake(0.4)
	e.run.fx.burst(e.body_point() + e.dir * 16.0, FIRE, 16, 90.0, 0.45, 2.6)
	Sfx.play("rock_break", -6.0, 0.06, 0.9)
	e.mem["legs"] = int(e.mem["legs"]) - 1
	if int(e.mem["legs"]) > 0:
		_begin_swoop(e, float(e.p.get("rebound_warn", 0.85)) * (0.85 if mean else 1.0))
		return
	e.state = REST                         # it hangs where it stopped for a moment
	e.t = 0.7 if mean else 1.0


# ------------------------------------------------------------------------------ CANDLE RAIN
func _begin_rain(e, mean: bool) -> void:
	e.state = BUSY
	e._say("CANDLE RAIN")
	e.mem["drops"] = int(e.p.get("candles2", 7)) if mean else int(e.p.get("candles", 5))
	e.mem["pending"] = []
	e.tell(0.5)
	Sfx.play("boss_roar", -10.0, 0.05, 1.8)
	e.after(0.3, _rain_drop)


func _rain_drop(e) -> void:
	var n := int(e.mem["drops"]) - 1
	e.mem["drops"] = n
	var warn := float(e.p.get("candle_warn", 0.9))
	# one candle where the hero stands, the next where he is heading
	var at: Vector2 = e.player.position
	if n % 2 == 1:
		at += (e.player.vel as Vector2).limit_length(100.0) * 0.45
	at = Vector2(clampf(at.x, 10.0, G.ROOM_W - 10.0), clampf(at.y, 8.0, G.ROOM_H - 8.0))
	(e.mem["pending"] as Array).append(at)
	e.mark_circle(at, float(e.p.get("candle_radius", 15.0)), warn)
	e.after(warn, _rain_erupt)
	if n > 0:
		e.after(float(e.p.get("candle_gap", 0.4)), _rain_drop)
	else:
		e.after(warn + 0.4, _attack_done)


func _rain_erupt(e) -> void:
	var pending: Array = e.mem["pending"]
	if pending.is_empty():
		return
	var at: Vector2 = pending.pop_front()
	var r := float(e.p.get("candle_radius", 15.0))
	e.strike_circle(at, r)
	e.run.fx.ring(at, 3.0, r, 0.25, FIRE[1], 2.0, true)
	e.run.fx.burst(at, FIRE, 12, 40.0, 0.55, 2.6, Vector2.UP, -70.0)
	e.run.fx.burst(at, FIRE, 6, 70.0, 0.35, 2.2)
	Sfx.play("explosion", -11.0, 0.1, 1.5)
	if e.phase >= 2:
		e.burn_ground(at, r - 5.0, 0.8, 0.0)


# ------------------------------------------------------------------------------ GUTTERS OUT
func _begin_gutter(e, mean: bool) -> void:
	e.mem["done"] = 0
	e.mem["out"] = true
	e.state = GUTTER
	e.t = 0.45
	e.harmful = false                      # the bare skull is safe to touch
	e.set_loops("nofire")
	e.run.fx.burst(e.body_point(), SMOKE, 20, 50.0, 0.8, 3.0, Vector2.UP, -50.0)
	Sfx.play("bomb_fuse", -3.0, 0.05, 0.55)
	if mean:
		e.summon_minions(String(e.p.get("helper", "bone_walker")), int(e.p.get("helpers", 2)), {"max": 4, "far": 50.0})


func _begin_relight(e) -> void:
	var warn := float(e.p.get("warn", 0.8))
	e.stop()
	e.state = RELIGHT
	e.t = warn
	e.tell(warn)
	e.mark_circle(e.position, float(e.p.get("flare_radius", 30.0)), warn)
	Sfx.play("bomb_fuse", -6.0, 0.05, 0.8)


func _relit(e) -> void:
	var r := float(e.p.get("flare_radius", 30.0))
	e.lift = 0.0
	e.mem["out"] = false
	e.harmful = true
	e.set_loops("idle")
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 6.0, r, 0.3, FIRE[1], 3.0, true)
	e.run.fx.burst(e.body_point(), FIRE, 26, 120.0, 0.55, 2.8)
	e.run.shake(0.5)
	Sfx.play("explosion", -5.0, 0.06, 1.0)
	_attack_done(e)
