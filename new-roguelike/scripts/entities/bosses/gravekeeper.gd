extends RefCounted
## Boss "The Gravekeeper" (floor 1): a lumbering giant with three moves.
##   CHARGE  a red line shows the path, then it rushes along it          (phase 2: twice in a row, shots on impact)
##   SLAM    a red circle fills under it, then a ring of shots bursts out (phase 2: a second ring follows)
##   RAISE   red circles mark where small zombies climb out of the floor
## Under half health (phase 2) it walks faster and rests less.
## params (bosses.gd):  charge_speed px/s,  slam_radius px
const WALK := 0
const CHARGE_WIND := 1
const CHARGE := 2
const SLAM_WIND := 3
const SLAM_ECHO := 4
const RAISE := 5
const REST := 6


func start(e) -> void:
	e.state = WALK
	e.t = 1.4
	e.mem = {"charges": 0, "last": -1, "left": 0.0, "spots": []}


func phase_changed(e, _phase: int) -> void:
	e.state = REST
	e.t = 0.8
	e.lift = 0.0


func tick(e, delta: float) -> void:
	e.t -= delta
	var mean: bool = e.phase >= 2
	match e.state:
		WALK:
			e.chase(delta, 1.35 if mean else 1.0)
			if e.t <= 0.0:
				_pick(e)
		CHARGE_WIND:
			e.face(e.dir)
			if e.t <= 0.0:
				e.state = CHARGE
		CHARGE:
			var v := float(e.p.get("charge_speed", 170.0)) * (1.15 if mean else 1.0)
			var blocked: bool = e.dash(e.dir * v, delta)
			e.mem["left"] = float(e.mem["left"]) - v * delta
			if randf() < 0.5:
				e.run.fx.burst(e.position, [Color(0.5, 0.45, 0.4), Color(0.3, 0.28, 0.26)], 1, 25.0, 0.35, 2.2)
			if blocked or float(e.mem["left"]) <= 0.0:
				e.run.shake(0.45)
				e.run.fx.ring(e.position, 4.0, 26.0, 0.25, Color(1.0, 0.8, 0.5), 2.0, true)
				Sfx.play("rock_break", -4.0)
				if mean:
					e.shoot_ring(8, 64.0, "", e.rng.randf() * TAU)
				e.mem["charges"] = int(e.mem["charges"]) - 1
				if int(e.mem["charges"]) > 0:
					_begin_charge(e, 0.45)
				else:
					e.state = REST
					e.t = 0.7 if mean else 1.1
		SLAM_WIND:
			var total := 0.8
			e.lift = sin(clampf(1.0 - e.t / total, 0.0, 1.0) * PI) * 9.0
			if e.t <= 0.0:
				e.lift = 0.0
				_slam(e, 12 if mean else 10, 0.0)
				if mean:
					e.state = SLAM_ECHO
					e.t = 0.45
				else:
					e.state = REST
					e.t = 1.1
		SLAM_ECHO:
			if e.t <= 0.0:
				_slam(e, 12, PI / 12.0)
				e.state = REST
				e.t = 0.8
		RAISE:
			if e.t <= 0.0:
				for at: Vector2 in e.mem["spots"]:
					e.summon("shambler", at)
				e.state = REST
				e.t = 0.6
		REST:
			if e.t <= 0.0:
				e.state = WALK
				e.t = e.rng.randf_range(0.7, 1.2) if mean else e.rng.randf_range(1.2, 1.9)


func _pick(e) -> void:
	var d: float = e.dist_to_player()
	var mean: bool = e.phase >= 2
	var w_charge := 40.0 if e.room.walk_clear(e.position, e.player.position) else 0.0
	var w_slam := 30.0 + (35.0 if d < 55.0 else 0.0)
	var w_raise := 25.0 if e.minion_count() < (3 if mean else 2) else 0.0
	# do not repeat the same move three times
	var last := int(e.mem["last"])
	if last == CHARGE:
		w_charge *= 0.4
	elif last == SLAM_WIND:
		w_slam *= 0.4
	elif last == RAISE:
		w_raise = 0.0
	var roll: float = e.rng.randf() * (w_charge + w_slam + w_raise)
	if roll < w_charge:
		e.mem["last"] = CHARGE
		e.mem["charges"] = 2 if mean else 1
		_begin_charge(e, 0.55 if mean else 0.75)
	elif roll < w_charge + w_slam:
		e.mem["last"] = SLAM_WIND
		e.state = SLAM_WIND
		e.t = 0.8
		e.tell(0.8)
		e.warn_circle(float(e.p.get("slam_radius", 40.0)), 0.8)
	else:
		e.mem["last"] = RAISE
		e.state = RAISE
		e.t = 0.9
		e.tell(0.9)
		var spots: Array = []
		for k in (3 if mean else 2):
			var at: Vector2 = e.room.random_spawn_spot(e.player.position, false, 40.0)
			spots.append(at)
			e.warn_circle(7.0, 0.9 + 0.7, at)
		e.mem["spots"] = spots


func _begin_charge(e, windup: float) -> void:
	e.state = CHARGE_WIND
	e.t = windup
	e.dir = e.to_player().normalized()
	var reach: float = e.room.ray_walk(e.position, e.dir, 240.0)
	e.mem["left"] = reach + 6.0
	e.tell(windup)
	e.warn_line(e.dir, reach + 10.0, windup)


func _slam(e, shots: int, offset: float) -> void:
	var r := float(e.p.get("slam_radius", 40.0))
	e.run.fx.ring(e.position, 6.0, r, 0.3, Color(1.0, 0.8, 0.5), 3.0, true)
	e.run.fx.burst(e.position, [Color(0.6, 0.55, 0.5), Color(0.35, 0.3, 0.3)], 18, 90.0, 0.5, 2.6)
	e.run.shake(0.6)
	Sfx.play("explosion", -6.0)
	if e.player.can_be_hit() and e.dist_to_player() < r + e.player.hit_radius - 2.0:
		e.player.hurt(1, e.position, e.display_name)
	e.shoot_ring(shots, 60.0, "", offset)
