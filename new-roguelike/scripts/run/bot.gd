extends Node
## Bot: plays the game by itself so the game can be tested without hands (flag --autotest).
## It only presses the same buttons a player has: it writes Controls.bot_move / bot_aim and
## calls Controls.press_bomb(). It is not allowed to cheat (one exception: when it is walled in
## inside a secret room it bombs its way out).
## In a fight it keeps its distance, strafes, leads its shots, steps out of red warnings and
## sidesteps shots that come close. Between fights it grabs pickups, opens chests, takes items,
## shops, hunts for the secret room with a bomb, clears every room, then fights the boss and
## takes the exit.
## THE HUNGRY CURSE: the bot plays it in one of three styles, chosen with --botstyle=
##   dodge    steps off a locked stripe and never walks into a lit rim. Nothing else.
##   feeder   (the default) also stands so that the most enemies lie on the line between the
##            disc and itself when a lunge is near, and bombs the disc when its belly is full
##   caller   also presses CALL when 2 or more enemies are on that line and the disc is 40+ px away
## It logs every meal, bite and belly cough, and the RESULT line carries the Curse's numbers.
## It prints one line per event starting with "AUTOTEST ", restarts the run when it dies, and
## after --time=<game seconds> prints "AUTOTEST RESULT {json}" and quits with exit code 0.

const RoomScript = preload("res://scripts/run/room.gd")
const Items = preload("res://scripts/data/items.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const Curse = preload("res://scripts/entities/curse.gd")

const DEFAULT_TIME := 600.0
const STYLES: Array[String] = ["dodge", "feeder", "caller"]
const CALL_MIN_ENEMIES := 2      ## caller: enemies on the line before it presses CALL
const CALL_MIN_DIST := 40.0      ## caller: ... and the disc at least this far away
const FEED_FROM_FILL := 0.45     ## feeder: starts lining enemies up when the lunge timer is this full
const FEED_MAX_DANGER := 0.6    ## feeder: ... but only while the fight is not pressing it harder than this
const BOMB_BELLY := 5            ## feeder: bombs the disc when its belly holds this much (or is full)
const CURSED_UP_TO := 2          ## it takes cursed items only below this Curse Level
const STARVE_FROM := 3           ## it buys "Starve the Curse" from this Curse Level

var run: Node
var time_limit := DEFAULT_TIME
var total_time := 0.0
var runs := 1
var deaths := 0
var wins := 0
var max_floor := 1
var rooms_cleared := 0
var fights := 0
var fight_time := 0.0
var boss_starts := 0
var boss_kills := 0
var floor1_boss_starts := 0
var floor1_boss_kills := 0
var items_taken := 0
var secrets := 0
var damage := 0
var base_seed := 0
# ---- the Hungry Curse
var style := "feeder"
var tally := {}                  ## counters by G.stat key (curse_meals, curse_bites, belly_coins ...)
var kills_f1 := 0
var boss_bite_now := 0           ## thousandths of the current boss's health eaten by the Curse
var boss_bite_max := 0
var _bomb_spot := Vector2.INF    ## a bomb we dropped for the Curse: keep away from it
var _bomb_spot_t := 0.0

var _danger := 0.0               ## how hard the fight is pushing us around right now (enemies close, shots, warnings)
var _restart := false
var _done := false
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _path_cell := -1
var _path := PackedInt32Array()
var _path_room: Node
var _path_grid_hash := 0
var _bomb_wait := 0.0
var _bomb_dir := Vector2i.ZERO
var _bomb_phase := 0
var _tried_gaps := {}
var _skip := {}
var _idle_t := 0.0
var _was_fighting := false
var _fight_start := 0.0


func setup(the_run: Node) -> void:
	run = the_run
	base_seed = run.seed_value
	max_floor = run.floor_index + 1
	time_limit = float(G.arg("time", str(DEFAULT_TIME)))
	style = G.arg("botstyle", "feeder")
	if not STYLES.has(style):
		style = "feeder"
	Controls.bot = true
	G.room_cleared.connect(_on_room_cleared)
	G.item_acquired.connect(func(id: String) -> void:
		items_taken += 1
		_log("item %s" % id))
	G.boss_started.connect(func(b: Node) -> void:
		boss_starts += 1
		boss_bite_now = 0
		if run.floor_index == 0:
			floor1_boss_starts += 1
		_log("boss_start %s hp=%d player_hp=%d" % [b.boss_id, int(b.max_hp), run.player.hp + run.player.armor]))
	G.boss_defeated.connect(func(id: String) -> void:
		boss_kills += 1
		if run.floor_index == 0:
			floor1_boss_kills += 1
		_log("boss_defeated %s player_hp=%d" % [id, run.player.hp + run.player.armor]))
	G.floor_started.connect(func(index: int, floor_name: String) -> void:
		max_floor = maxi(max_floor, index + 1)
		_tried_gaps.clear()
		_skip.clear()
		_log("floor %d \"%s\" rooms=%d" % [index + 1, floor_name, run.rooms.size()]))
	G.player_hurt.connect(func(n: int) -> void: damage += n)
	G.stat.connect(func(key: String, _n: int) -> void:
		if key == "secret_found":
			secrets += 1
			_log("secret_found"))
	G.stat.connect(_on_curse_stat)
	G.run_ended.connect(_on_run_ended)
	_log("start hero=%s seed=%d floor=%d \"%s\" rooms=%d" % [run.hero_id, run.seed_value, run.floor_index + 1, run.floor_name, run.rooms.size()])


func _exit_tree() -> void:
	Controls.bot = false
	Controls.bot_move = Vector2.ZERO
	Controls.bot_aim = Vector2.ZERO


func _log(text: String) -> void:
	print("AUTOTEST t=%.1f f%d %s" % [total_time, run.floor_index + 1, text])


## Counts everything the Hungry Curse reports and logs the moments worth reading back.
func _on_curse_stat(key: String, n: int) -> void:
	tally[key] = int(tally.get(key, 0)) + n
	match key:
		"kills":
			if run.floor_index == 0:
				kills_f1 += n
		"curse_meals":
			var c0: Node2D = run.room.curse if run.room != null else null
			_log("meal belly=%d/%d meals=%d while=%s t=%.1f" % [run.belly, run.belly_cap(), int(tally[key]),
				Curse.STATE_NAMES[c0.state] if c0 != null and is_instance_valid(c0) else "?", run.room.fight_time if run.room != null else 0.0])
		"curse_bites":
			var c: Node2D = run.room.curse if run.room != null else null
			_log("bite level=%d hp=%d/%d armor=%d while=%s enemies=%d" % [run.curse_level, run.player.hp, run.player.max_hp, run.player.armor,
				Curse.STATE_NAMES[c.state] if c != null and is_instance_valid(c) else "?", run.room.enemies.size() if run.room != null else 0])
		"belly_coins":
			if n > 1:
				_log("belly_cough coins=%d" % n)
		"curse_feast":
			_log("feast")
		"curse_boss_permille":
			boss_bite_now += n
			boss_bite_max = maxi(boss_bite_max, boss_bite_now)
			_log("boss_bite %.1f%% (this boss %.1f%%)" % [n / 10.0, boss_bite_now / 10.0])
		"wall_cracked":
			_log("wall_cracked")
		"curse_starved":
			_log("starved level=%d" % run.curse_level)


func _on_room_cleared(coord: Vector2i) -> void:
	rooms_cleared += 1
	var p: Node = run.player
	_log("room_cleared %s type=%s fight=%.1fs hp=%d/%d armor=%d" % [coord, run.TYPE_NAMES[run.rooms[coord]["type"]],
		run.room.fight_time, p.hp, p.max_hp, p.armor])
	if run.rooms[coord]["type"] == G.RoomType.COMBAT:
		fights += 1
		fight_time += run.room.fight_time


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	if victory:
		wins += 1
		_log("WIN time=%.1f kills=%d items=%s" % [summary["time_s"], summary["kills"], summary["items"]])
	else:
		deaths += 1
		_log("death floor=%d room=%s cause=\"%s\" kills=%d rooms=%d items=%s" % [summary["floor"],
			run.TYPE_NAMES[run.rooms[run.cur]["type"]], summary["cause"], summary["kills"], summary["rooms_cleared"], summary["items"]])
	_restart = true


func _finish() -> void:
	if _done:
		return
	_done = true
	var result := {
		"hero": run.hero_id, "seed": base_seed, "time": snappedf(total_time, 0.1), "runs": runs, "deaths": deaths, "wins": wins,
		"max_floor": max_floor, "rooms_cleared": rooms_cleared, "fights": fights,
		"avg_fight_s": snappedf(fight_time / maxf(1.0, float(fights)), 0.1),
		"boss_starts": boss_starts, "boss_kills": boss_kills,
		"floor1_boss_starts": floor1_boss_starts, "floor1_boss_kills": floor1_boss_kills,
		"items": items_taken, "secrets": secrets, "damage_taken": damage,
	}
	# ---- the Hungry Curse
	var kills_all := int(tally.get("kills", 0))
	var meals := int(tally.get("curse_meals", 0))
	var bite_dmg := int(tally.get("curse_bite_damage", 0))
	var coins := int(tally.get("coins", 0))
	result["style"] = style
	result["kills"] = kills_all
	result["curse_meals"] = meals
	result["curse_kill_pct"] = snappedf(100.0 * meals / maxf(1.0, float(kills_all)), 0.1)
	result["kills_f1"] = kills_f1
	result["curse_meals_f1"] = int(tally.get("curse_meals_f1", 0))
	result["curse_kill_pct_f1"] = snappedf(100.0 * float(tally.get("curse_meals_f1", 0)) / maxf(1.0, float(kills_f1)), 0.1)
	result["bites"] = int(tally.get("curse_bites", 0))
	result["bites_warded"] = int(tally.get("curse_bites_warded", 0))
	result["bites_per_run"] = snappedf(float(tally.get("curse_bites", 0)) / float(runs), 0.1)
	result["bite_damage"] = bite_dmg
	result["bite_damage_pct"] = snappedf(100.0 * bite_dmg / maxf(1.0, float(damage)), 0.1)
	result["lunges"] = int(tally.get("curse_lunges", 0))
	result["calls"] = int(tally.get("curse_calls", 0))
	result["feasts"] = int(tally.get("curse_feast", 0))
	result["stuns"] = int(tally.get("curse_stunned", 0))
	result["shots_eaten"] = int(tally.get("curse_shots_eaten", 0))
	result["coins"] = coins
	result["belly_coins"] = int(tally.get("belly_coins", 0))
	result["belly_coin_pct"] = snappedf(100.0 * float(tally.get("belly_coins", 0)) / maxf(1.0, float(coins)), 0.1)
	result["boss_bite_pct_avg"] = snappedf(float(tally.get("curse_boss_permille", 0)) / 10.0 / maxf(1.0, float(boss_starts)), 0.1)
	result["boss_bite_pct_max"] = snappedf(boss_bite_max / 10.0, 0.1)
	print("AUTOTEST RESULT " + JSON.stringify(result))
	G.quit(0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	total_time += delta
	if total_time >= time_limit:
		_finish()
		return
	if _restart:
		_restart = false
		runs += 1
		run.restart(base_seed + runs - 1)
		_tried_gaps.clear()
		_skip.clear()
		_log("restart run=%d seed=%d" % [runs, run.seed_value])
		return
	var p: Node = run.player
	var move := Vector2.ZERO
	var aim := Vector2.ZERO
	if p != null and not p.dead and not run.over and run.room != null:
		var room: Node = run.room
		if room.fighting and room.fight_time > 45.0 and fmod(room.fight_time, 15.0) < delta:
			# a fight that drags on is worth a line in the log: who is left, and where
			var left: Array = []
			for e in room.enemies:
				left.append("%s@%d,%d hp=%d state=%d" % [e.id, int(e.position.x), int(e.position.y), int(e.hp), e.state])
			_log("slow_fight %.0fs layout=%s player@%d,%d left=%s" % [room.fight_time, room.rs.get("layout", ""), int(p.position.x), int(p.position.y), left])
		if not room.enemies.is_empty():
			var out := _fight(p, room, delta)
			move = out[0]
			aim = out[1]
		else:
			move = _explore(p, room, delta)
		move = _unstick(p, move, delta)
	Controls.bot = true
	Controls.bot_move = move
	Controls.bot_aim = aim
	Controls.move = move.limit_length(1.0)
	Controls.aim = aim.limit_length(1.0)


# =============================================================================== fighting
func _fight(p: Node, room: Node, delta: float) -> Array:
	var pos: Vector2 = p.position
	var shot_range: float = p.stats.v("range")
	var shot_speed: float = p.stats.v("shot_speed")
	# ---- pick a target: the nearest enemy we can see, else the nearest
	var target: Node = null
	var best := INF
	for e in room.enemies:
		if not e.hittable:
			continue
		var d: float = pos.distance_to(e.position)
		if not room.sight_clear(pos, e.position):
			d += 60.0
		# like a player would: go for the summoner, not for the things it keeps raising
		if e.minion:
			d += 45.0
		elif e.data.get("ai", "") == "summoner":
			d -= 50.0
		if d < best:
			best = d
			target = e
	var aim := Vector2.ZERO
	var move := Vector2.ZERO
	if target != null:
		var tp: Vector2 = target.position - Vector2(0, target.hit_up)
		var dist := pos.distance_to(tp)
		var lead: Vector2 = tp + target.vel_est * (dist / shot_speed) * 0.85
		aim = (lead - pos).normalized()
		# ---- keep a comfortable distance and circle
		# (a short-range hero fights near the end of his reach instead of in the monsters' faces)
		var want := clampf(maxf(shot_range * 0.62, minf(shot_range - 22.0, 64.0)), 42.0, 78.0)
		var to: Vector2 = (tp - pos).normalized()
		if dist > shot_range * 0.85 or not room.sight_clear(pos, tp):
			move += _path_dir(room, pos, tp) * 1.0
		elif dist < want:
			move -= to * (1.2 * (want - dist) / want + 0.3)
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(0.8, 2.0)
			_strafe = -_strafe
		move += to.orthogonal() * _strafe * 0.7
	# ---- stay away from every enemy (also the ones still appearing)
	_danger = 0.0
	for e in room.enemies:
		var away: Vector2 = pos - e.position
		var d2 := away.length()
		var danger: float = 40.0 + e.radius * 2.0
		if d2 < danger and d2 > 0.01:
			move += away / d2 * 2.2 * (danger - d2) / danger
			_danger += 2.2 * (danger - d2) / danger
	# ---- sidestep enemy shots that are coming at us
	var shots: Node = run.shots
	for i in shots.count:
		if shots.side[i] != 1:
			continue
		var rel: Vector2 = pos - shots.pos[i]
		var d3 := rel.length()
		if d3 > 44.0 or d3 < 0.01:
			continue
		var v: Vector2 = shots.vel[i]
		var along := rel.dot(v.normalized())
		if along < 0.0:
			continue
		var side_dist := absf(rel.cross(v.normalized()))
		if side_dist > 11.0:
			continue
		var perp: Vector2 = v.normalized().orthogonal()
		if rel.dot(perp) < 0.0:
			perp = -perp
		move += perp * 1.8 * (1.0 - d3 / 44.0 + 0.3)
		_danger += 1.0
	# ---- get out of red warnings
	for h in run.fx.hazards:
		if h[0] == 0:
			var c: Vector2 = h[1]
			var r: float = float(h[3]) + 12.0
			var off := pos - c
			if off.length() < r:
				move += (off.normalized() if off.length() > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)) * 3.5
				_danger += 2.0
		elif h[0] == 2:
			# a boss's cone: leave it over the nearer edge
			var tip: Vector2 = h[1]
			var mid: Vector2 = (h[2] as Vector2) - tip
			var rel2 := pos - tip
			var turn := mid.angle_to(rel2)
			if rel2.length() < mid.length() + 14.0 and absf(turn) < float(h[3]) + 14.0 / maxf(rel2.length(), 14.0):
				move += mid.normalized().orthogonal() * (1.0 if turn >= 0.0 else -1.0) * 3.5
				_danger += 2.0
		elif h[0] == 3:
			# a boss's ring: step inside it or outside it, whichever edge is nearer
			var off3 := pos - (h[1] as Vector2)
			var r_in := float(h[6])
			var r_out := float(h[3])
			var d4 := off3.length()
			if d4 > r_in - 12.0 and d4 < r_out + 12.0:
				var inward := r_in > 16.0 and d4 - r_in < r_out - d4
				move += (off3.normalized() if d4 > 0.5 else Vector2.RIGHT) * (-3.5 if inward else 3.5)
				_danger += 2.0
		else:
			var a: Vector2 = h[1]
			var b: Vector2 = h[2]
			var ab := b - a
			var tt := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
			var nearest := a + ab * tt
			var off2 := pos - nearest
			if off2.length() < float(h[3]) + 14.0:
				var side: Vector2 = ab.normalized().orthogonal()
				if off2.dot(side) < 0.0:
					side = -side
				move += side * 3.5
				_danger += 2.0
	# ---- do not hug walls, do not stand on spikes
	move += _wall_push(pos) * 1.2
	move += _spike_push(room, pos) * 2.0
	# ---- the Hungry Curse
	var curse: Node2D = room.curse
	if curse != null and is_instance_valid(curse) and curse.solid:
		move = _curse_moves(p, room, curse, move.limit_length(1.0), delta)
	return [move.limit_length(1.0) if move.length() > 0.15 else Vector2.ZERO, aim]


# =============================================================================== the Hungry Curse
## How many enemies the disc would sweep up if it lunged from where it is through `through`.
func _on_line(room: Node, curse: Node2D, through: Vector2) -> float:
	var from: Vector2 = curse.position
	var dir := through - from
	if dir.length() < 1.0:
		return 0.0
	dir = dir.normalized()
	var to := from + dir * 400.0
	var n := 0.0
	for e in room.enemies:
		if not e.hittable:
			continue
		var reach: float = curse.radius + e.radius - 1.0
		if Curse.seg_dist2(e.position, from, to) < reach * reach:
			n += 0.5 if e.has_method("bitten") else 1.0
	return n


## Changes the move the fight wanted so that it suits the Curse: off the stripe, away from a lit
## rim, and (feeder, caller) onto the spot that lines the most enemies up for the next lunge.
func _curse_moves(p: Node, room: Node, curse: Node2D, move: Vector2, delta: float) -> Vector2:
	var pos: Vector2 = p.position
	var cpos: Vector2 = curse.position
	var r: float = curse.radius
	var state: int = curse.state
	_bomb_spot_t = maxf(0.0, _bomb_spot_t - delta)
	# ---- 1. step off a locked stripe (every style): the short way out, unless a wall or a rock
	# is in the way there and the other side is open
	if state == Curse.LOCK or state == Curse.LUNGE:
		var dir: Vector2 = curse.aim_dir
		var orth := dir.orthogonal()
		var rel := pos - cpos
		var along := rel.dot(dir)
		var side_off := rel.dot(orth)              # signed distance from the stripe's middle line
		var need := r + Curse.HERO_BITE_PAD + 8.0
		if along > -need and absf(side_off) < need:
			var s := 1.0 if side_off >= 0.0 else -1.0
			var near_need := need - absf(side_off) + 3.0
			var far_need := need + absf(side_off) + 3.0
			var near_free := _free_dist(room, pos, orth * s, near_need)
			if near_free >= near_need:
				return orth * s
			var far_free := _free_dist(room, pos, -orth * s, far_need)
			if far_free >= far_need:
				return -orth * s
			# boxed in on both sides: go where there is more room, and away from the disc
			var pick := orth * s if near_free >= far_free else -orth * s
			return (pick + dir * 0.6).normalized()
	if not curse.lit():
		return move
	# ---- 2. never walk into a lit rim, and never let it push us into a corner (every style)
	var away := pos - cpos
	var dist := away.length()
	var keep := r + 20.0
	if dist < keep and dist > 0.01:
		var out := away / dist
		move += out * 3.0 * (keep - dist) / 20.0
		if _free_dist(room, pos, out, 30.0) < 30.0:
			# a wall is behind us: slip around the disc toward the open side of the room
			var slip := out.orthogonal()
			var a := _free_dist(room, pos, slip, 60.0)
			var b := _free_dist(room, pos, -slip, 60.0)
			if b > a or (is_equal_approx(a, b) and slip.dot(G.ROOM_CENTER - pos) < 0.0):
				slip = -slip
			move = move.limit_length(1.0) * 0.4 + slip * 1.6
	var next := pos + move.limit_length(1.0) * 22.0
	if next.distance_to(cpos) < r + 8.0 and dist > 0.01:
		var inward := -away / dist
		move -= inward * maxf(0.0, move.dot(inward))      # slide past it instead of through it
	if style == "dodge":
		return move
	# ---- 3. a bomb for a full belly (feeder, caller)
	# The disc creeps at us, so a bomb dropped at our feet when it is close is still in reach
	# when the fuse runs out (or the disc walks into it, which sets it off at once). Not when
	# the fight is almost won: the disc would sink before the blast.
	if _bomb_spot_t > 0.0:
		if pos.distance_to(_bomb_spot) < 44.0:
			move += (pos - _bomb_spot).normalized() * 3.0
	elif p.bombs > 0 and (state == Curse.CREEP or state == Curse.WINDED) and run.belly >= mini(BOMB_BELLY, run.belly_cap()) \
			and dist < r + Curse.BOMB_REACH - 6.0 and dist > r + 10.0 and _fight_will_last(room):
		Controls.press_bomb()
		_bomb_spot = pos
		_bomb_spot_t = 1.8
		_log("bombs the Curse belly=%d" % run.belly)
	# ---- 4. line the enemies up (feeder, caller)
	if state == Curse.FOLLOW or (state == Curse.CREEP and (curse.fill >= FEED_FROM_FILL or style == "caller")):
		var best := pos
		var best_score := _on_line(room, curse, pos)
		var here_score := best_score
		for ring: float in [20.0, 40.0]:
			for k in 12:
				var c := pos + Vector2.RIGHT.rotated(TAU * k / 12.0) * ring
				if c.x < 12.0 or c.y < 12.0 or c.x > G.ROOM_W - 12.0 or c.y > G.ROOM_H - 12.0 or room.blocks_walk(G.cell_of(c)):
					continue
				if c.distance_to(cpos) < r + 34.0:
					continue
				var score := _on_line(room, curse, c) - ring * 0.006
				for e in room.enemies:
					if (e.position as Vector2).distance_to(c) < 32.0:
						score -= 1.0
				if score > best_score + 0.01:
					best_score = score
					best = c
		# ... and the whole room: for every direction the disc could lunge in, how many would it
		# swallow, and where would we have to stand (just past the last of them)?
		for k in 24:
			var ray := Vector2.RIGHT.rotated(TAU * k / 24.0)
			var n := 0.0
			var far := 0.0
			for e in room.enemies:
				if not e.hittable:
					continue
				var rel: Vector2 = (e.position as Vector2) - cpos
				var al := rel.dot(ray)
				if al > 0.0 and absf(rel.cross(ray)) < r + e.radius - 2.0:
					n += 0.5 if e.has_method("bitten") else 1.0
					far = maxf(far, al)
			if n < 1.0:
				continue
			var c := cpos + ray * (far + 36.0)
			c = Vector2(clampf(c.x, 12.0, G.ROOM_W - 12.0), clampf(c.y, 12.0, G.ROOM_H - 12.0))
			if (c - cpos).dot(ray) < far + 22.0 or room.blocks_walk(G.cell_of(c)) or c.distance_to(cpos) < r + 34.0:
				continue
			var score := _on_line(room, curse, c) - pos.distance_to(c) * 0.008
			if score > best_score + 0.3:
				best_score = score
				best = c
		# (safety first: only while nothing is pressing us, so lining them up never costs health)
		# (and never around a boss: a bite takes only a few percent off it, not worth a hit)
		var boss_room: bool = room.type == G.RoomType.BOSS
		if _danger < FEED_MAX_DANGER and not boss_room:
			if best != pos and best_score >= 1.0:
				var way: Vector2 = _path_dir(room, pos, best) if pos.distance_to(best) > 44.0 else (best - pos).normalized()
				move = move.limit_length(1.0) * 0.5 + way * 0.8
			elif here_score >= 1.0 and state == Curse.FOLLOW:
				move *= 0.4                                # good spot: hold it while the stripe sweeps
		# caller: 2 or more on the line (in a boss fight the boss alone is worth a call)
		if style == "caller" and here_score >= (0.5 if boss_room else float(CALL_MIN_ENEMIES)) and dist >= CALL_MIN_DIST and curse.can_call():
			Controls.press_action()
	return move


## How far (up to `far` px) the hero can walk from `from` along `dir` before a wall, rock or pit.
func _free_dist(room: Node, from: Vector2, dir: Vector2, far: float) -> float:
	var d := 4.0
	while d <= far + 3.9:
		var q := from + dir * minf(d, far)
		if q.x < 5.0 or q.y < 5.0 or q.x > G.ROOM_W - 5.0 or q.y > G.ROOM_H - 5.0 or room.blocks_walk(G.cell_of(q)):
			return d - 4.0
		d += 4.0
	return far


## True when the enemies left will not all be dead within a bomb's fuse (a boss, or 2 or more).
func _fight_will_last(room: Node) -> bool:
	var n := 0
	for e in room.enemies:
		if e.has_method("bitten"):
			return e.hp > e.max_hp * 0.2
		if not e.dead:
			n += 1
	return n >= 2


func _wall_push(pos: Vector2) -> Vector2:
	var out := Vector2.ZERO
	var m := 16.0
	if pos.x < m:
		out.x += (m - pos.x) / m
	if pos.x > G.ROOM_W - m:
		out.x -= (pos.x - (G.ROOM_W - m)) / m
	if pos.y < m:
		out.y += (m - pos.y) / m
	if pos.y > G.ROOM_H - m:
		out.y -= (pos.y - (G.ROOM_H - m)) / m
	return out


func _spike_push(room: Node, pos: Vector2) -> Vector2:
	if not room.has_spikes:
		return Vector2.ZERO
	var out := Vector2.ZERO
	var c := G.cell_of(pos)
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var n := c + Vector2i(ox, oy)
			if G.in_room(n) and room.grid[n.y * RoomScript.COLS + n.x] == RoomScript.SPIKES:
				var away := pos - G.cell_center(n.x, n.y)
				var d := away.length()
				if d < 18.0:
					out += (away / d if d > 0.1 else Vector2.UP) * (18.0 - d) / 18.0
	return out


# =============================================================================== between fights
func _explore(p: Node, room: Node, delta: float) -> Vector2:
	var pos: Vector2 = p.position
	if run.busy():
		return Vector2.ZERO
	# ---- a bomb we placed is about to go off: back away
	if _bomb_wait > 0.0:
		_bomb_wait -= delta
		return ((G.ROOM_CENTER - pos).normalized() if pos.distance_to(G.ROOM_CENTER) > 20.0 else Vector2.ZERO)
	# ---- things lying around
	var goal := Vector2.INF
	var best := INF
	for t in room.things:
		if not is_instance_valid(t) or _skip.has(t.get_instance_id()):
			continue
		var worth := false
		match t.kind:
			"pickup":
				worth = p.wants(String(t.info.get("need", "")))
			"chest":
				worth = not t.opened and (not t.locked or p.keys > 0)
			"pedestal":
				worth = _wants_pedestal(p, t)
			"floor_exit":
				worth = _nothing_left_here(p, room)
		if not worth:
			continue
		var d: float = pos.distance_to(t.position) + (300.0 if t.kind == "floor_exit" else 0.0)
		if d < best:
			best = d
			goal = t.position
	if goal != Vector2.INF:
		_idle_t = 0.0
		return _walk_to(room, pos, goal)
	# ---- hunt for the secret room with a bomb
	var hunt := _secret_hunt(p, room)
	if hunt != Vector2.INF:
		return hunt
	# ---- go to the next room worth visiting
	var dir := _next_door(p)
	if dir != Vector2i.ZERO:
		_idle_t = 0.0
		var door_at: Vector2 = room.door_pos(dir)
		var inside := door_at - Vector2(dir) * 10.0
		if pos.distance_to(inside) > 7.0 and absf((pos - door_at).cross(Vector2(dir))) > 4.0:
			return _walk_to(room, pos, inside)
		return (door_at + Vector2(dir) * 14.0 - pos).normalized()
	# ---- nowhere to go: walled in (a secret room entered with --goto), blow a way out
	_idle_t += delta
	if _idle_t > 1.0 and p.bombs > 0:
		for d2: Vector2i in room.rs["doors"]:
			var door: Dictionary = room.rs["doors"][d2]
			if door["hidden"] and not door["revealed"]:
				var spot: Vector2 = room.door_pos(d2) - Vector2(d2) * 8.0
				if pos.distance_to(spot) > 5.0:
					return _walk_to(room, pos, spot)
				Controls.press_bomb()
				_bomb_wait = 1.9
				_idle_t = 0.0
				return Vector2.ZERO
	return Vector2.ZERO


func _nothing_left_here(p: Node, room: Node) -> bool:
	for t in room.things:
		if is_instance_valid(t) and t.kind == "pedestal" and _wants_pedestal(p, t) and not _skip.has(t.get_instance_id()):
			return false
	return true


func _wants_pedestal(p: Node, t: Node) -> bool:
	if t.taken:
		return false
	if t.price > p.coins:
		return false
	if t.item != "":
		# cursed items: only when healthy enough to pay the price
		if t.cursed:
			return p.hp + p.armor >= 6 and not p.items.has("glass_blade") and run.curse_level < CURSED_UP_TO
		return true
	if t.service == "starve":
		return t.visible and run.curse_level >= STARVE_FROM
	if t.pickup == "heart" or t.pickup == "half_heart":
		return p.hp <= p.max_hp - 2
	if t.pickup == "key":
		return p.keys == 0 and run.treasure_locked()
	if t.pickup == "bomb":
		return p.bombs == 0
	return t.price == 0


## Walks toward a point, going around obstacles (and around spikes when there is another way).
func _walk_to(room: Node, pos: Vector2, goal: Vector2) -> Vector2:
	return _path_dir(room, pos, goal)


func _path_dir(room: Node, pos: Vector2, goal: Vector2) -> Vector2:
	var straight := (goal - pos).normalized()
	if pos.distance_to(goal) < 10.0:
		return straight
	if room.walk_clear(pos, goal) and not _spikes_between(room, pos, goal):
		return straight
	var gc := G.cell_of(Vector2(clampf(goal.x, 1, G.ROOM_W - 1), clampf(goal.y, 1, G.ROOM_H - 1)))
	var cell := gc.y * RoomScript.COLS + gc.x
	var grid_hash: int = hash(room.grid)
	if cell != _path_cell or room != _path_room or grid_hash != _path_grid_hash:
		_path_cell = cell
		_path_room = room
		_path_grid_hash = grid_hash
		_path = _bfs_no_spikes(room, gc)
		var here: int = room.cell_index(pos)
		if _path[here] >= 9999:
			_path = room.bfs(gc, false)
	var d: Vector2 = room.follow(_path, pos, false)
	return d if d != Vector2.ZERO else straight


func _spikes_between(room: Node, a: Vector2, b: Vector2) -> bool:
	if not room.has_spikes:
		return false
	var d := b - a
	var n := int(d.length() / 6.0) + 1
	for k in range(1, n + 1):
		if room.cell_at(a + d * (float(k) / float(n))) == RoomScript.SPIKES:
			return true
	return false


## Like room.bfs(), but spikes count as walls.
func _bfs_no_spikes(room: Node, from: Vector2i) -> PackedInt32Array:
	var cols := RoomScript.COLS
	var rows := RoomScript.ROWS
	var out := PackedInt32Array()
	out.resize(cols * rows)
	out.fill(9999)
	var start := from.y * cols + from.x
	out[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % cols
		var y := i / cols
		for d: Vector2i in G.DIRS:
			var n := Vector2i(x + d.x, y + d.y)
			if not G.in_room(n):
				continue
			var j := n.y * cols + n.x
			if out[j] <= out[i] + 1 or room.blocks_walk(n) or room.grid[j] == RoomScript.SPIKES:
				continue
			out[j] = out[i] + 1
			queue.append(j)
	return out


## The door to walk through next: toward the nearest room not visited yet (the boss room last).
func _next_door(p: Node) -> Vector2i:
	# --goto=boss: a boss test. Walk straight in (once per floor) instead of clearing the floor first.
	if G.arg("goto") == "boss" and run.bosses_beaten.size() <= run.floor_index:
		var straight := _boss_step(p)
		if straight != Vector2i.ZERO:
			return straight
	var first := _search(p, false)
	if first != Vector2i.ZERO:
		return first
	return _search(p, true)


## The first step of the shortest way to the boss room that is not beaten yet (ZERO = none).
func _boss_step(p: Node) -> Vector2i:
	var rooms: Dictionary = run.rooms
	var seen := {run.cur: Vector2i.ZERO}
	var queue: Array[Vector2i] = [run.cur]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in rooms[c]["doors"]:
			var door: Dictionary = rooms[c]["doors"][d]
			var n: Vector2i = door["to"]
			if seen.has(n) or (door["hidden"] and not door["revealed"]) or (door["locked"] and p.keys <= 0):
				continue
			seen[n] = d if c == run.cur else seen[c]
			if rooms[n]["type"] == G.RoomType.BOSS:
				if not rooms[n]["cleared"]:
					return seen[n]
				continue
			queue.append(n)
	return Vector2i.ZERO


## Breadth-first search over the rooms we may walk through; returns the first step's direction.
func _search(p: Node, allow_boss: bool) -> Vector2i:
	var rooms: Dictionary = run.rooms
	var seen := {run.cur: Vector2i.ZERO}
	var queue: Array[Vector2i] = [run.cur]
	var keys: int = p.keys
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in rooms[c]["doors"]:
			var door: Dictionary = rooms[c]["doors"][d]
			var n: Vector2i = door["to"]
			if seen.has(n):
				continue
			if door["hidden"] and not door["revealed"]:
				continue
			if door["locked"] and keys <= 0 and rooms[c]["type"] != G.RoomType.TREASURE:
				continue
			var is_boss: bool = rooms[n]["type"] == G.RoomType.BOSS
			if is_boss and not allow_boss:
				continue
			var step: Vector2i = d if c == run.cur else seen[c]
			seen[n] = step
			if not rooms[n]["visited"] or (is_boss and not rooms[n]["cleared"]):
				return step
			# never path THROUGH an uncleared boss room
			queue.append(n)
	# a cleared boss room with an exit we have not taken yet
	if allow_boss:
		for c2: Vector2i in rooms:
			if rooms[c2]["type"] == G.RoomType.BOSS and rooms[c2]["cleared"] and seen.has(c2) and c2 != run.cur:
				return seen[c2]
	return Vector2i.ZERO


## Like a player would: an empty spot on the map that touches two or more known rooms is
## suspicious. Go to a room next to it, walk to the wall facing it and place a bomb.
## Returns Vector2.INF when not hunting.
func _secret_hunt(p: Node, room: Node) -> Vector2:
	if p.bombs <= 0 or _secret_known() or _tried_gaps.size() >= 2 or _search(p, false) != Vector2i.ZERO:
		return Vector2.INF
	# the last bomb is worth more on a full belly (the boss fight is next) than on a wall
	if style != "dodge" and p.bombs == 1 and run.belly >= mini(BOMB_BELLY, run.belly_cap()) and not G.flag("nocurse"):
		return Vector2.INF
	var plan := _secret_plan()
	if plan.is_empty():
		return Vector2.INF
	var from: Vector2i = plan[0]
	var d: Vector2i = plan[1]
	if from != run.cur:
		var step := _step_toward(p, from)
		if step == Vector2i.ZERO:
			_tried_gaps[from + d] = true
			return Vector2.INF
		var door_at: Vector2 = room.door_pos(step)
		var inside := door_at - Vector2(step) * 10.0
		if p.position.distance_to(inside) > 7.0 and absf((p.position - door_at).cross(Vector2(step))) > 4.0:
			return _walk_to(room, p.position, inside)
		return (door_at + Vector2(step) * 14.0 - p.position).normalized()
	var spot: Vector2 = room.door_pos(d) - Vector2(d) * 8.0
	if p.position.distance_to(spot) > 5.0:
		return _walk_to(room, p.position, spot)
	Controls.press_bomb()
	_tried_gaps[from + d] = true
	_bomb_wait = 1.9
	_log("bombs wall toward %s" % [from + d])
	return Vector2.ZERO


## [room, direction] of the most suspicious untested gap, or [] when there is none.
func _secret_plan() -> Array:
	var best: Array = []
	var best_score := 1
	for c: Vector2i in run.rooms:
		var rec: Dictionary = run.rooms[c]
		if not rec["visited"] or rec["type"] == G.RoomType.BOSS or rec["type"] == G.RoomType.SECRET:
			continue
		for d: Vector2i in G.DIRS:
			var gap: Vector2i = c + d
			if _tried_gaps.has(gap) or (run.rooms.has(gap) and not _is_hidden_room(gap)):
				continue
			var touching := 0
			for d2: Vector2i in G.DIRS:
				var n: Vector2i = gap + d2
				if run.rooms.has(n) and run.rooms[n]["visited"] and run.rooms[n]["type"] != G.RoomType.BOSS:
					touching += 1
			var score := touching * 10 - (absi(c.x - run.cur.x) + absi(c.y - run.cur.y))
			if touching >= 2 and score > best_score:
				best_score = score
				best = [c, d]
	return best


## First step (a direction) on the way from the current room to `target` through open doors.
func _step_toward(p: Node, target: Vector2i) -> Vector2i:
	var rooms: Dictionary = run.rooms
	var seen := {run.cur: Vector2i.ZERO}
	var queue: Array[Vector2i] = [run.cur]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in rooms[c]["doors"]:
			var door: Dictionary = rooms[c]["doors"][d]
			var n: Vector2i = door["to"]
			if seen.has(n) or (door["hidden"] and not door["revealed"]):
				continue
			if door["locked"] and p.keys <= 0 and rooms[c]["type"] != G.RoomType.TREASURE:
				continue
			if not rooms[n]["visited"]:
				continue
			seen[n] = d if c == run.cur else seen[c]
			if n == target:
				return seen[n]
			queue.append(n)
	return Vector2i.ZERO


func _is_hidden_room(c: Vector2i) -> bool:
	return run.rooms[c]["type"] == G.RoomType.SECRET and not run.rooms[c]["seen"]


func _secret_known() -> bool:
	for c: Vector2i in run.rooms:
		if run.rooms[c]["type"] == G.RoomType.SECRET and run.rooms[c]["seen"]:
			return true
	return false


# =============================================================================== not getting stuck
func _unstick(p: Node, move: Vector2, delta: float) -> Vector2:
	if _wander_t > 0.0:
		_wander_t -= delta
		return _wander
	if move.length() < 0.2:
		_stuck_t = 0.0
		_stuck_pos = p.position
		return move
	_stuck_t += delta
	if _stuck_t > 0.7:
		if (p.position as Vector2).distance_to(_stuck_pos) < 3.0:
			_wander = Vector2.RIGHT.rotated(randf() * TAU)
			_wander_t = 0.35
		_stuck_t = 0.0
		_stuck_pos = p.position
	return move
