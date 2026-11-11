extends RefCounted
## Boss "The Gutter King" (floor 2 spare, sprite boss_mutant_toad): a fat toad that never walks.
## It sits and watches; everything it does is a jump, a lick or a spit.
##   HOP      ("jump") it crouches, blinking, and a red circle marks where it will come down; it
##            cannot be hit in the air. The landing hurts inside the circle and throws a ring of
##            slime shots. Leave the circle, then slip between the shots.
##            Phase 2: THREE hops in a row with smaller rings, each landing leaves a puddle of slime
##            that hurts to stand in; after the third it sits winded (THE BREATHER of phase 2).
##   TONGUE   ("attack") only when the hero stands level with it: a red lane along the floor in
##            front of its mouth, then the tongue lashes out along it. Step up or down out of the
##            lane. The pack's tongue is 41 px long and cut flat at its tip, so a plain line in the
##            tongue's own colour carries it on to tongue_reach px. After a lash it sits dazed
##            (THE BREATHER). Phase 2: a shorter warning.
##   SPIT     its throat swells while thin red lanes show where three globs of slime will fly; the
##            globs are slow and bounce off the walls twice. Phase 2: five globs.
##   BROOD    phase 2 only: two Spore Caps on marked spots (only when none is left, and not more
##            often than every brood_gap s).
## Phase 2 (half health) begins with BROOD and a triple HOP.
## Its slime is GREEN (shot type "slime", puddles in the colours below); nothing here is pale gold.
## params (bosses.gd): hop_time s in the air, hop_radius px, hop_shots, tongue_warn s, tongue_reach px,
##   spit_warn s, spit_speed px/s, puddle_radius px, puddle_seconds, brood_gap s
const SIT := 0
const BUSY := 1            # an attack is running; its callbacks move the fight on
const AIR := 2
const LASH := 3
const REST := 4
const A_HOP := 0
const A_TONGUE := 1
const A_SPIT := 2
const A_BROOD := 3

const TONGUE := Color8(184, 56, 32)          # the tongue's colour in the pack's frame
const TONGUE_FROM := 40.0                    # px in front of the feet where the pack's tongue ends (42) minus an overlap
const TONGUE_UP := -21.0                     # its height over the feet line
const MOUTH := Vector2(16.0, -20.0)          # where a glob leaves (forward, -up from the feet)
const LANE_HALF := 7.0
const SLIME_DARK := Color(0.16, 0.36, 0.08, 0.80)
const SLIME := Color(0.44, 0.80, 0.20, 0.80)
const SLIME_LIGHT := Color(0.76, 1.0, 0.46, 0.85)
const SPLASH := [Color(0.44, 0.80, 0.20), Color(0.16, 0.36, 0.08), Color(0.76, 1.0, 0.46)]


func start(e) -> void:
	e.set_loops("idle", "idle")          # the pack drew no walk: it only ever hops
	e.state = SIT
	e.t = 1.2
	# the rest of the tongue: a 2 px line and a small knob at its tip, drawn over the sprite
	var tongue := _line(e, 2.0)
	var knob := _line(e, 4.0)
	e.mem = {"last": -1, "queue": [], "hops": 0, "from": e.position, "tongue": tongue, "knob": knob,
		"lash_t": 0.0, "reach": 90.0, "brood": 0.0, "dirs": [], "mouth": Vector2.ZERO}


func _line(e, width: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = TONGUE
	line.visible = false
	e.add_child(line)
	return line


func phase_changed(e, _phase: int) -> void:
	_hide_tongue(e)
	e.state = SIT
	e.t = 0.3
	e.mem["queue"] = [A_BROOD, A_HOP]


func tick(e, delta: float) -> void:
	e.t -= delta
	e.mem["brood"] = float(e.mem["brood"]) - delta
	var mean: bool = e.phase >= 2
	match e.state:
		SIT:
			e.face_player()
			if e.t <= 0.0:
				_pick(e, mean)
		AIR:
			var total := _hop_time(e, mean)
			var u := clampf(1.0 - e.t / total, 0.0, 1.0)
			e.position = (e.mem["from"] as Vector2).lerp(e.target, u)
			e.lift = sin(u * PI) * 44.0
			if u > 0.55 and e.sprite.frame != 3:
				e.pose("jump", 3)          # legs trailing: coming down
			if e.t <= 0.0:
				_land(e, mean)
		LASH:
			_lash(e, delta)
		REST:
			if e.t <= 0.0:
				e.stop()
				e.state = SIT
				e.t = e.rng.randf_range(0.5, 0.9) if mean else e.rng.randf_range(0.9, 1.4)


func _pick(e, mean: bool) -> void:
	var queue: Array = e.mem["queue"]
	var next := -1
	if not queue.is_empty():
		next = int(queue.pop_front())
	else:
		var rel: Vector2 = e.to_player()
		var level: bool = absf(rel.y) <= 12.0 and absf(rel.x) > 14.0 and absf(rel.x) < float(e.p.get("tongue_reach", 90.0)) - 4.0
		var brood: bool = mean and float(e.mem["brood"]) <= 0.0 and e.minion_count() == 0
		var w: Array[float] = [40.0, 70.0 if level else 0.0, 30.0, 25.0 if brood else 0.0]
		var last := int(e.mem["last"])
		if last >= 0:
			w[last] *= 0.25
		var roll: float = e.rng.randf() * (w[0] + w[1] + w[2] + w[3])
		next = A_HOP
		for k in 4:
			roll -= w[k]
			if roll < 0.0:
				next = k
				break
	e.mem["last"] = next
	match next:
		A_TONGUE:
			_begin_tongue(e, mean)
		A_SPIT:
			_begin_spit(e, mean)
		A_BROOD:
			_begin_brood(e)
		_:
			e.mem["hops"] = 3 if mean else 1
			_begin_hop(e)


## Turns it at once, also while it holds a pose (the base only turns a boss that is in a loop).
func _turn(e, dx: float) -> void:
	e.face(Vector2(dx, 0.0))
	if absf(dx) > 0.05:
		e.facing = signf(dx)


# ------------------------------------------------------------------------------ HOP
func _hop_time(e, mean: bool) -> float:
	return float(e.p.get("hop_time", 0.75)) * (0.8 if mean else 1.0)


func _begin_hop(e) -> void:
	var mean: bool = e.phase >= 2
	e.state = BUSY
	var to: Vector2 = e.player.position
	e.target = Vector2(clampf(to.x, 16.0, G.ROOM_W - 16.0), clampf(to.y, 14.0, G.ROOM_H - 10.0))
	var crouch := 0.4 if mean else 0.45
	e.pose("jump", 1)
	_turn(e, e.target.x - e.position.x)
	e.tell(crouch)
	e.mark_circle(e.target, float(e.p.get("hop_radius", 26.0)), crouch + _hop_time(e, mean))
	e.after(crouch, _jump)


func _jump(e) -> void:
	e.state = AIR
	e.t = _hop_time(e, e.phase >= 2)
	e.mem["from"] = e.position
	e.hittable = false
	e.harmful = false
	e.pose("jump", 2)
	e.run.fx.burst(e.position, SPLASH, 6, 50.0, 0.3, 2.0)
	Sfx.play("footstep", 0.0, 0.0, 0.5)


func _land(e, mean: bool) -> void:
	var r := float(e.p.get("hop_radius", 26.0))
	e.position = e.target
	e.lift = 0.0
	e.hittable = true
	e.harmful = true
	e.pose("jump", 1)                  # squashed flat for a moment
	e.strike_circle(e.position, r)
	e.run.fx.ring(e.position, 6.0, r, 0.3, SLIME, 3.0, true)
	e.run.fx.burst(e.position, SPLASH, 20, 100.0, 0.5, 2.8)
	e.run.shake(0.7)
	e.run.hitstop(0.04)
	Sfx.play("explosion", -6.0, 0.0, 1.3)
	var shots := int(e.p.get("hop_shots", 8))
	e.ring_from(e.position, maxi(shots - 2, 3) if mean else shots, 58.0, "slime", e.rng.randf() * TAU)   # three smaller rings in phase 2
	if mean:
		_puddle(e, e.position, float(e.p.get("puddle_radius", 15.0)), float(e.p.get("puddle_seconds", 3.5)))
	e.mem["hops"] = int(e.mem["hops"]) - 1
	if int(e.mem["hops"]) > 0:
		e.after(0.18, _begin_hop)
	elif mean:
		e.state = SIT
		e.t = 0.4
		e.stagger(1.2)                 # winded after three jumps: the breather of phase 2
	else:
		e.state = REST
		e.t = 0.9


## A puddle of slime: flat green blobs on the floor (no rim, so it is neither a warning mark nor
## the Curse). The base deals the damage (hurt_ground), this only draws it and lets it fade.
func _puddle(e, at: Vector2, r: float, seconds: float) -> void:
	e.hurt_ground(at, r, seconds, 0.6)
	var puddle := Node2D.new()
	puddle.position = at
	puddle.modulate.a = 0.0
	for n in 6:
		var off := Vector2.RIGHT.rotated(TAU * float(n) / 6.0 + r) * r * 0.5
		puddle.add_child(_blob(off, r * 0.52, SLIME_DARK))
	for n in 5:
		var off := Vector2.RIGHT.rotated(TAU * float(n) / 5.0 + r * 2.0) * r * 0.36
		puddle.add_child(_blob(off, r * 0.40, SLIME))
	puddle.add_child(_blob(Vector2.ZERO, r * 0.45, SLIME))
	puddle.add_child(_blob(Vector2(-r * 0.25, -r * 0.2), 2.0, SLIME_LIGHT))
	puddle.add_child(_blob(Vector2(r * 0.3, r * 0.1), 1.5, SLIME_LIGHT))
	e.room.spikes_node.add_child(puddle)
	var tween := puddle.create_tween()
	tween.tween_method(_puddle_fade.bind(puddle, e), 0.0, 1.0, seconds)
	tween.tween_callback(puddle.queue_free)


func _blob(at: Vector2, r: float, color: Color) -> Polygon2D:
	var blob := Polygon2D.new()
	var points := PackedVector2Array()
	for n in 14:
		points.append(at + Vector2.RIGHT.rotated(TAU * float(n) / 14.0) * r)
	blob.polygon = points
	blob.color = color
	return blob


## k runs from 0 to 1 over the puddle's life. It is gone at once when the boss is.
static func _puddle_fade(k: float, puddle: Node2D, boss: Variant) -> void:
	if not is_instance_valid(puddle):
		return
	if not is_instance_valid(boss) or boss.dead:
		puddle.visible = false
		return
	puddle.modulate.a = minf(minf(k / 0.05, 1.0), (1.0 - k) / 0.15)


# ------------------------------------------------------------------------------ TONGUE
func _begin_tongue(e, mean: bool) -> void:
	e.state = BUSY
	e.position = e.position.round()    # whole pixels, so the drawn line sits exactly on the pack's tongue
	var side := 1.0 if e.to_player().x >= 0.0 else -1.0
	_turn(e, side)
	e.dir = Vector2(side, 0.0)
	var warn := float(e.p.get("tongue_warn", 0.6)) * (0.75 if mean else 1.0)
	# it cannot lick through a wall: the lane and the tongue stop there
	var reach := float(e.p.get("tongue_reach", 90.0))
	reach = minf(reach, (G.ROOM_W - 3.0 - e.position.x) if side > 0.0 else (e.position.x - 3.0))
	e.mem["reach"] = maxf(reach, TONGUE_FROM + 2.0)
	e.strike("attack", warn, _lick)
	e.mark_lane(e.position + e.dir * 12.0, e.position + e.dir * float(e.mem["reach"]), LANE_HALF, warn)
	Sfx.play("enemy_hit", -6.0, 0.0, 0.5)


func _lick(e, _frame: int) -> void:
	e.pose("attack", 2)                # mouth open, the pack's tongue out
	_turn(e, e.dir.x)
	e.state = LASH
	e.mem["lash_t"] = 0.0
	Sfx.play("player_shoot_blade", -2.0, 0.0, 0.6)
	_lash(e, 0.0)


## The tongue is out: full length at once, held a moment, then drawn back in.
func _lash(e, delta: float) -> void:
	var t := float(e.mem["lash_t"]) + delta
	e.mem["lash_t"] = t
	var reach := float(e.mem["reach"])
	var out := reach
	if t > 0.2:
		out = lerpf(reach, TONGUE_FROM, clampf((t - 0.2) / 0.14, 0.0, 1.0))
	if t <= 0.2:
		e.strike_lane(e.position + e.dir * 12.0, e.position + e.dir * reach, LANE_HALF)
	var tongue: Line2D = e.mem["tongue"]
	var knob: Line2D = e.mem["knob"]
	var y: float = e.at_feet(Vector2(0.0, TONGUE_UP)).y - e.position.y
	tongue.points = PackedVector2Array([Vector2(e.dir.x * TONGUE_FROM, y), Vector2(e.dir.x * out, y)])
	knob.points = PackedVector2Array([Vector2(e.dir.x * (out - 1.0), y), Vector2(e.dir.x * (out + 2.0), y)])
	tongue.visible = out > TONGUE_FROM + 0.5
	knob.visible = tongue.visible
	if t >= 0.34:
		_hide_tongue(e)
		e.stop()
		e.state = SIT
		e.t = 0.4
		e.stagger(0.9)                 # it has to swallow its tongue again: the breather


func _hide_tongue(e) -> void:
	(e.mem["tongue"] as Line2D).visible = false
	(e.mem["knob"] as Line2D).visible = false


# ------------------------------------------------------------------------------ SPIT
func _begin_spit(e, mean: bool) -> void:
	e.state = BUSY
	e.pose("idle", 2)                  # throat swollen
	_turn(e, e.to_player().x)
	var warn := float(e.p.get("spit_warn", 0.6))
	e.tell(warn)
	var mouth: Vector2 = e.at_feet(MOUTH) + Vector2(0.0, e.SHOT_PLANE)
	var aim: float = (e.player.position - mouth).angle()
	var amount := 5 if mean else 3
	var arc := 1.3 if mean else 0.8
	var dirs: Array = []
	for k in amount:
		var d := Vector2.RIGHT.rotated(aim + (float(k) - float(amount - 1) * 0.5) * arc / float(amount - 1))
		dirs.append(d)
		e.mark_lane(mouth, mouth + d * 64.0, 3.0, warn)
	e.mem["dirs"] = dirs
	e.mem["mouth"] = mouth
	e.after(warn, _spit)


func _spit(e) -> void:
	for d: Vector2 in e.mem["dirs"]:
		e.shoot_from(e.mem["mouth"], d, float(e.p.get("spit_speed", 80.0)), "slime", {"bounce": 2, "range": 230.0, "size": 1.25})
	e.run.fx.burst(e.at_feet(MOUTH), SPLASH, 8, 60.0, 0.3, 2.0, Vector2(e.facing, 0.0))
	Sfx.play("enemy_shoot", -2.0, 0.0, 0.6)
	e.state = REST
	e.t = 0.8


# ------------------------------------------------------------------------------ BROOD
func _begin_brood(e) -> void:
	e.state = REST
	e.t = 1.0
	e.pose("idle", 2)
	e.tell(0.6)
	e.mem["brood"] = float(e.p.get("brood_gap", 12.0))
	e.summon_minions("spore_cap", 2, {"max": 2})
	Sfx.play("boss_roar", -8.0, 0.0, 1.5)
