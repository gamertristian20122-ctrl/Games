extends Node
## Bot: plays the game by itself so the game can be tested without hands (flag --autotest).
## It only presses the same buttons a player has: it writes Controls.bot_move / bot_aim and
## calls Controls.press_bomb(). It is not allowed to cheat (one exception: when it is walled in
## inside a secret room it bombs its way out).
## In a fight it keeps its distance, strafes, leads its shots, steps out of red warnings and
## sidesteps shots that come close. Between fights it grabs pickups, opens chests, takes items,
## shops, hunts for the secret room with a bomb, clears every room, then fights the boss and
## takes the exit.
## It prints one line per event starting with "AUTOTEST ", restarts the run when it dies, and
## after --time=<game seconds> prints "AUTOTEST RESULT {json}" and quits with exit code 0.

const RoomScript = preload("res://scripts/run/room.gd")
const Items = preload("res://scripts/data/items.gd")
const Pickups = preload("res://scripts/data/pickups.gd")

const DEFAULT_TIME := 600.0

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
	time_limit = float(G.arg("time", str(DEFAULT_TIME)))
	Controls.bot = true
	G.room_cleared.connect(_on_room_cleared)
	G.item_acquired.connect(func(id: String) -> void:
		items_taken += 1
		_log("item %s" % id))
	G.boss_started.connect(func(b: Node) -> void:
		boss_starts += 1
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
	G.run_ended.connect(_on_run_ended)
	_log("start hero=%s seed=%d floor=%d \"%s\" rooms=%d" % [run.hero_id, run.seed_value, run.floor_index + 1, run.floor_name, run.rooms.size()])


func _exit_tree() -> void:
	Controls.bot = false
	Controls.bot_move = Vector2.ZERO
	Controls.bot_aim = Vector2.ZERO


func _log(text: String) -> void:
	print("AUTOTEST t=%.1f f%d %s" % [total_time, run.floor_index + 1, text])


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
	print("AUTOTEST RESULT " + JSON.stringify(result))
	get_tree().quit(0)


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
		var want := clampf(shot_range * 0.62, 42.0, 78.0)
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
	for e in room.enemies:
		var away: Vector2 = pos - e.position
		var d2 := away.length()
		var danger: float = 40.0 + e.radius * 2.0
		if d2 < danger and d2 > 0.01:
			move += away / d2 * 2.2 * (danger - d2) / danger
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
	# ---- get out of red warnings
	for h in run.fx.hazards:
		if h[0] == 0:
			var c: Vector2 = h[1]
			var r: float = float(h[3]) + 12.0
			var off := pos - c
			if off.length() < r:
				move += (off.normalized() if off.length() > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)) * 3.5
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
	# ---- do not hug walls, do not stand on spikes
	move += _wall_push(pos) * 1.2
	move += _spike_push(room, pos) * 2.0
	return [move.limit_length(1.0) if move.length() > 0.15 else Vector2.ZERO, aim]


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
			return p.hp + p.armor >= 6 and not p.items.has("glass_blade")
		return true
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
	var first := _search(p, false)
	if first != Vector2i.ZERO:
		return first
	return _search(p, true)


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
