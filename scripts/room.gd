class_name Room
extends Node2D
## One room: its walls and obstacles, the enemies that arrive in waves,
## the reward chest and the way out.
##
## A room is a grid of 30 x 15 tiles. The outer ring is wall. Everything
## else comes from a floor plan in scripts/data/room_layouts.gd.

signal cleared
signal exit_reached
signal chest_opened

const FLOOR := 0
const WALL := 1
const TALL := 2        # blocks walking and shots
const LOW := 3         # blocks walking only

const COLS := 30
const ROWS := 15
const T := 16.0
const DOOR_ROW := 7
const ENTRY_POINT := Vector2(26.0, DOOR_ROW * 16.0 + 8.0)
const CENTER := Vector2(240.0, DOOR_ROW * 16.0 + 8.0)
const SPAWN_WARNING := 0.75     # seconds of warning before an enemy appears
const WAVE_TIMEOUT := 16.0      # the next wave comes anyway after this long

var kind := "fight"             # "fight" or "boss"
var floor_def: Dictionary = {}
var keeper: Player
var rng := RandomNumberGenerator.new()

var grid := PackedByteArray()
var enemies: Array[Enemy] = []
var echoes: Array[Echo] = []
var waves: Array = []
var wave_index := -1
var state := "waiting"          # waiting -> fighting -> cleared -> open
var clock := 0.0                # seconds since the fight began
var exit_open := false
var boss: Enemy = null
var pull_center := Vector2.ZERO  # the Undertow boss drags the keeper toward this point
var pull_strength := 0.0

var shot_layer: Node2D
var enemy_layer: Node2D
var fx_layer: Node2D

var _wave_clock := 0.0
var _pending: Array = []        # enemies that are about to appear
var _spawn_queue: Array = []    # enemies born from other enemies (blobs splitting)
var _blast_queue: Array = []
var _flow := PackedInt32Array()
var _flow_timer := 0.0
var _walls: StaticBody2D
var _exit_block: CollisionShape2D
var _decor: Array = []          # [cell, sprite cell, alpha] floor specks
var _obstacle_art: Dictionary = {}
var _chest: Node2D = null
var _chest_ready := 0.0
var _exit_sent := false
var _accent := Color.WHITE


## Builds the room. Call once, before adding it to the scene.
func setup(floor_definition: Dictionary, room_kind: String, plan: Array[String], seed_value: int, keeper_node: Player) -> void:
	floor_def = floor_definition
	kind = room_kind
	keeper = keeper_node
	rng.seed = seed_value
	_accent = floor_def.get("accent", Color.WHITE)

	grid.resize(COLS * ROWS)
	grid.fill(FLOOR)
	for x in COLS:
		grid[x] = WALL
		grid[(ROWS - 1) * COLS + x] = WALL
	for y in ROWS:
		grid[y * COLS] = WALL
		grid[y * COLS + COLS - 1] = WALL
	var art: Array = floor_def.get("obstacles", [Sprites.CRATE])
	for y in plan.size():
		for x in plan[y].length():
			var ch := plan[y][x]
			var index := (y + 1) * COLS + (x + 1)
			if ch == "#":
				grid[index] = TALL
				_obstacle_art[index] = art[rng.randi() % art.size()]
			elif ch == "~":
				grid[index] = LOW

	# A few specks on the floor so it is not a flat colour.
	for i in 46:
		var cx := rng.randi_range(1, COLS - 2)
		var cy := rng.randi_range(1, ROWS - 2)
		if grid[cy * COLS + cx] == FLOOR:
			_decor.append([Vector2i(cx, cy), Sprites.FLOOR_DOTS[rng.randi() % Sprites.FLOOR_DOTS.size()], rng.randf_range(0.25, 0.6)])


func _ready() -> void:
	_build_collision()
	enemy_layer = Node2D.new()
	enemy_layer.name = "Enemies"
	add_child(enemy_layer)
	shot_layer = Node2D.new()
	shot_layer.name = "Shots"
	add_child(shot_layer)
	fx_layer = Node2D.new()
	fx_layer.name = "Effects"
	add_child(fx_layer)
	_flow.resize(COLS * ROWS)
	_update_flow()


# ----------------------------------------------------------------------
# The fight
# ----------------------------------------------------------------------

## Locks the room and sends in the first wave.
func start_fight() -> void:
	if state != "waiting":
		return
	state = "fighting"
	clock = 0.0
	Game.room_started()
	_spawn_echoes()
	if kind == "boss":
		waves = [[floor_def.get("boss", "clatterclaw")]]
	else:
		waves = _plan_waves()
	_next_wave()


func _physics_process(delta: float) -> void:
	# Tidy the lists first, so nothing else ever sees a half-removed entry.
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]) or enemies[i].dead:
			enemies.remove_at(i)

	if state == "fighting":
		clock += delta
		_wave_clock += delta
		_run_pending(delta)
		_run_queues()
		_flow_timer -= delta
		if _flow_timer <= 0.0:
			_flow_timer = 0.25
			_update_flow()
		var more_waves := wave_index + 1 < waves.size()
		if enemies.is_empty() and _pending.is_empty() and _spawn_queue.is_empty():
			if more_waves:
				_next_wave()
			else:
				_finish_fight()
		elif more_waves and kind != "boss" and _pending.is_empty() \
				and (enemies.size() <= 1 or _wave_clock > WAVE_TIMEOUT):
			# Keep the pressure on: do not wait for the last straggler.
			_next_wave()
	else:
		_run_queues()

	if _chest != null and keeper != null:
		_chest_ready -= delta
		if _chest_ready <= 0.0 and keeper.position.distance_to(_chest.position) < 15.0:
			_open_chest()

	if exit_open and not _exit_sent and keeper != null and keeper.position.x > (COLS - 1) * T + 3.0:
		_exit_sent = true
		exit_reached.emit()


func _finish_fight() -> void:
	state = "cleared"
	pull_strength = 0.0
	clear_enemy_shots(CENTER, 1000.0)
	# The echoes have done their work: take them off the list, then fade them.
	var leaving := echoes.duplicate()
	echoes.clear()
	for echo: Echo in leaving:
		echo.fade_away()
	cleared.emit()


## Works out who attacks in this room, split into waves.
func _plan_waves() -> Array:
	var pool: Dictionary = floor_def.get("enemies", {"clawling": 1})
	var crowd := float(Game.difficulty_def()["crowd"])
	var budget := (float(floor_def.get("budget_start", 5.0)) + float(floor_def.get("budget_step", 2.0)) * Game.room_index) * crowd
	var cap := float(floor_def.get("wave_cap", 7.0)) * crowd

	# Use only two or three kinds per room so each fight has a character.
	var kinds: Array = pool.keys()
	var chosen: Dictionary = {}
	var want := mini(kinds.size(), 2 + (1 if rng.randf() < 0.5 else 0))
	while chosen.size() < want:
		var pick := _weighted_pick(pool)
		chosen[pick] = pool[pick]

	var plan: Array = []
	var left := budget
	while left >= 1.0:
		var wave: Array = []
		var wave_left := minf(cap, left)
		var tries := 0
		while wave_left >= 1.0 and tries < 60:
			tries += 1
			var enemy_id := _weighted_pick(chosen)
			var cost := float(EnemyDB.get_enemy(enemy_id).get("cost", 1))
			if cost <= wave_left:
				wave.append(enemy_id)
				wave_left -= cost
				left -= cost
		if wave.is_empty():
			break
		plan.append(wave)
	return plan


func _weighted_pick(pool: Dictionary) -> String:
	var total := 0.0
	for key: String in pool:
		total += float(pool[key])
	var roll := rng.randf() * total
	var last := ""
	for key: String in pool:
		last = key
		roll -= float(pool[key])
		if roll <= 0.0:
			return key
	return last


func _next_wave() -> void:
	wave_index += 1
	_wave_clock = 0.0
	if wave_index >= waves.size():
		return
	var delay := 0.0
	for enemy_id: String in waves[wave_index]:
		var is_boss: bool = EnemyDB.get_enemy(enemy_id).get("boss", false)
		var where := Vector2(352.0, CENTER.y) if is_boss else _find_spawn_point()
		_pending.append({"id": enemy_id, "pos": where, "time": SPAWN_WARNING + delay, "mark": _make_mark(where, is_boss)})
		delay += 0.08
	if not waves[wave_index].is_empty():
		Sfx.play("spawn")


## A warning mark on the floor where an enemy is about to appear.
func _make_mark(where: Vector2, big: bool) -> Node2D:
	if Game.fast_mode:
		return null
	var mark := Sprites.sprite(Sprites.TARGET, Color(Pal.DANGER, 0.8))
	mark.position = where
	mark.z_index = 0
	if big:
		mark.scale = Vector2(3, 3)
	fx_layer.add_child(mark)
	return mark


func _run_pending(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		p["time"] -= delta
		var mark: Node2D = p["mark"]
		if mark != null:
			mark.visible = int(p["time"] * 12.0) % 2 == 0
			mark.rotation += delta * 4.0
		if p["time"] <= 0.0:
			if mark != null:
				mark.queue_free()
			spawn_enemy(p["id"], p["pos"], Vector2.ZERO)
			_pending.remove_at(i)


## Enemies and explosions asked for in the middle of a tick happen here,
## at a safe moment, so lists are never changed while something loops over them.
func _run_queues() -> void:
	if not _spawn_queue.is_empty():
		var births := _spawn_queue
		_spawn_queue = []
		for b: Dictionary in births:
			var e := spawn_enemy(b["id"], b["pos"], b["push"])
			e.age = Enemy.SPAWN_GRACE * 0.5
	if not _blast_queue.is_empty():
		var blasts := _blast_queue
		_blast_queue = []
		for b: Dictionary in blasts:
			Combat.explosion(self, b["pos"], b["radius"], b["amount"], b["source"], b["burn"], b["color"])


func spawn_enemy(enemy_id: String, where: Vector2, push: Vector2) -> Enemy:
	var enemy: Enemy
	match EnemyDB.get_enemy(enemy_id).get("ai", ""):
		"boss_clatterclaw":
			enemy = BossClatterclaw.new()
		"boss_diver":
			enemy = BossDiver.new()
		"boss_undertow":
			enemy = BossUndertow.new()
		_:
			enemy = Enemy.new()
	enemy.setup(enemy_id, self, float(floor_def.get("hp_scale", 1.0)))
	enemy.position = where
	enemy.knock = push
	enemy_layer.add_child(enemy)
	enemies.append(enemy)
	if enemy.is_boss:
		boss = enemy
	if not Game.fast_mode:
		Fx.burst(self, where, enemy.base_color, 6, 50.0, 0.3, 1.2)
	return enemy


func queue_spawn(enemy_id: String, where: Vector2, push: Vector2) -> void:
	_spawn_queue.append({"id": enemy_id, "pos": clamp_inside(where, 8.0), "push": push})


func queue_explosion(where: Vector2, radius: float, amount: float, source: String, burn: bool, color: Color) -> void:
	_blast_queue.append({"pos": where, "radius": radius, "amount": amount, "source": source, "burn": burn, "color": color})


## Picks a free floor tile well away from the keeper.
func _find_spawn_point() -> Vector2:
	var best := CENTER
	var best_score := -1.0
	for attempt in 24:
		var cx := rng.randi_range(2, COLS - 3)
		var cy := rng.randi_range(2, ROWS - 3)
		if grid[cy * COLS + cx] != FLOOR:
			continue
		var p := Vector2(cx * T + 8.0, cy * T + 8.0)
		var d := p.distance_to(keeper.position) if keeper != null else 200.0
		for other: Dictionary in _pending:
			if p.distance_to(other["pos"]) < 22.0:
				d = 0.0
		if d >= 90.0:
			return p
		if d > best_score:
			best_score = d
			best = p
	return best


func _spawn_echoes() -> void:
	for tape: EchoTape in Game.tapes_to_play():
		var echo := Echo.new()
		echo.setup(tape, self)
		add_child(echo)
		echoes.append(echo)
	if not echoes.is_empty():
		Sfx.play("echo_in")


# ----------------------------------------------------------------------
# Shots
# ----------------------------------------------------------------------

func add_shot(shot: Shot) -> void:
	shot_layer.add_child(shot)


func keeper_shot_count() -> int:
	return shot_layer.get_child_count()


## Removes enemy shots inside a circle (foghorn, end of fight).
func clear_enemy_shots(center: Vector2, radius: float) -> void:
	for node: Node in shot_layer.get_children():
		var shot := node as Shot
		if shot != null and shot.team == Shot.ENEMY and not shot.is_gone() \
				and shot.position.distance_to(center) <= radius:
			shot.cancel()


## Enemy shots that are still flying (the bot uses this to dodge).
func enemy_shots() -> Array[Shot]:
	var out: Array[Shot] = []
	for node: Node in shot_layer.get_children():
		var shot := node as Shot
		if shot != null and shot.team == Shot.ENEMY and not shot.is_gone():
			out.append(shot)
	return out


# ----------------------------------------------------------------------
# Questions other scripts ask the room
# ----------------------------------------------------------------------

func cell_at(p: Vector2) -> int:
	var cx := int(floor(p.x / T))
	var cy := int(floor(p.y / T))
	if cx < 0 or cy < 0 or cx >= COLS or cy >= ROWS:
		return WALL
	return grid[cy * COLS + cx]


func blocks_shot(p: Vector2) -> bool:
	var c := cell_at(p)
	return c == WALL or c == TALL


func blocks_walk(p: Vector2) -> bool:
	return cell_at(p) != FLOOR


## True if nothing tall stands between two points.
func clear_line(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / 8.0) + 1
	for i in steps + 1:
		if blocks_shot(from.lerp(to, float(i) / float(steps))):
			return false
	return true


## A push on the keeper at this spot (only the Undertow boss uses it).
func drift_at(p: Vector2) -> Vector2:
	if pull_strength <= 0.0:
		return Vector2.ZERO
	return (pull_center - p).normalized() * pull_strength


func clamp_inside(p: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(p.x, T + margin, (COLS - 1) * T - margin), clampf(p.y, T + margin, (ROWS - 1) * T - margin))


## The closest living enemy to a point, or null. "skip" holds ids to ignore.
func nearest_enemy(from: Vector2, max_distance: float, skip: Dictionary = {}) -> Enemy:
	var best: Enemy = null
	var best_d := max_distance * max_distance
	for enemy: Enemy in enemies:
		if enemy.dead or not enemy.targetable or skip.has(enemy.get_instance_id()):
			continue
		var d := from.distance_squared_to(enemy.position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


## Which way a walking enemy at "from" should step to reach the keeper.
func flow_dir(from: Vector2) -> Vector2:
	return _step_dir(_flow, from)


## Which way to walk from one point to reach another, around obstacles.
## (The test bot uses this to find the chest and the door.)
func dir_toward(from: Vector2, goal: Vector2) -> Vector2:
	var direct := goal - from
	if direct.length() < 14.0:
		return direct.normalized()
	var field := PackedInt32Array()
	field.resize(COLS * ROWS)
	_fill_distances(field, goal)
	var dir := _step_dir(field, from)
	return dir if dir != Vector2.ZERO else direct.normalized()


## The nearest floor tile (by walking distance from the keeper) that has a
## clear line to "target" and is at least "min_distance" away from it.
## Returns the target itself if there is no such tile.
func vantage_point(target: Vector2, min_distance: float) -> Vector2:
	var best := target
	var best_steps := 99999
	for y in range(1, ROWS - 1):
		for x in range(1, COLS - 1):
			var index := y * COLS + x
			if grid[index] != FLOOR or _flow[index] >= best_steps:
				continue
			var spot := Vector2(x * T + 8.0, y * T + 8.0)
			if spot.distance_to(target) < min_distance or not clear_line(spot, target):
				continue
			best_steps = _flow[index]
			best = spot
	return best


## Looks at the eight tiles around "from" and heads for the one closest to the goal.
func _step_dir(field: PackedInt32Array, from: Vector2) -> Vector2:
	var cx := clampi(int(from.x / T), 0, COLS - 1)
	var cy := clampi(int(from.y / T), 0, ROWS - 1)
	var best := field[cy * COLS + cx]
	var best_cell := Vector2i(cx, cy)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
				continue
			# No cutting corners diagonally past an obstacle.
			if dx != 0 and dy != 0 and (grid[cy * COLS + nx] != FLOOR or grid[ny * COLS + cx] != FLOOR):
				continue
			var value := field[ny * COLS + nx]
			if value < best:
				best = value
				best_cell = Vector2i(nx, ny)
	if best_cell == Vector2i(cx, cy):
		return Vector2.ZERO
	return (Vector2(best_cell.x * T + 8.0, best_cell.y * T + 8.0) - from).normalized()


func _update_flow() -> void:
	if keeper == null:
		_flow.fill(99999)
		return
	_fill_distances(_flow, keeper.position)


## Fills every floor tile with its walking distance to "goal".
func _fill_distances(field: PackedInt32Array, goal: Vector2) -> void:
	field.fill(99999)
	var sx := clampi(int(goal.x / T), 0, COLS - 1)
	var sy := clampi(int(goal.y / T), 0, ROWS - 1)
	var start := sy * COLS + sx
	field[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var next_value := field[index] + 1
		var x := index % COLS
		if x > 0:
			_visit(field, queue, index - 1, next_value)
		if x < COLS - 1:
			_visit(field, queue, index + 1, next_value)
		if index >= COLS:
			_visit(field, queue, index - COLS, next_value)
		if index < COLS * (ROWS - 1):
			_visit(field, queue, index + COLS, next_value)


func _visit(field: PackedInt32Array, queue: PackedInt32Array, index: int, value: int) -> void:
	if grid[index] == FLOOR and field[index] > value:
		field[index] = value
		queue.append(index)


# ----------------------------------------------------------------------
# Chest and doors
# ----------------------------------------------------------------------

## Puts the reward chest in the middle of the room.
func show_chest() -> void:
	if _chest != null:
		return
	_chest = Sprites.sprite(Sprites.CHEST_CLOSED, Pal.GOLD)
	_chest.position = CENTER
	_chest.z_index = 1
	add_child(_chest)
	_chest_ready = 0.5
	Fx.ring(self, CENTER, 22.0, Pal.GOLD, 0.4)
	Sfx.play("clear")


func chest_position() -> Vector2:
	return CENTER


func _open_chest() -> void:
	var chest := _chest as Sprite2D
	_chest = null
	chest.region_rect = Sprites.region(Sprites.CHEST_OPEN)
	chest.modulate = Color(Pal.GOLD, 0.5)
	Sfx.play("chest")
	chest_opened.emit()


## Unlocks the way out on the right-hand side.
func open_exit() -> void:
	if exit_open:
		return
	exit_open = true
	state = "open"
	grid[DOOR_ROW * COLS + COLS - 1] = FLOOR
	_exit_block.set_deferred("disabled", true)
	Sfx.play("door")
	queue_redraw()


func exit_position() -> Vector2:
	return Vector2((COLS - 1) * T + 10.0, DOOR_ROW * T + 8.0)


func _build_collision() -> void:
	_walls = StaticBody2D.new()
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	add_child(_walls)
	# Four wall strips; the right-hand one is split around the exit door.
	_add_box(_walls, Rect2(0, 0, COLS * T, T))
	_add_box(_walls, Rect2(0, (ROWS - 1) * T, COLS * T, T))
	_add_box(_walls, Rect2(0, 0, T, ROWS * T))
	_add_box(_walls, Rect2((COLS - 1) * T, 0, T, DOOR_ROW * T))
	_add_box(_walls, Rect2((COLS - 1) * T, (DOOR_ROW + 1) * T, T, (ROWS - DOOR_ROW - 1) * T))
	# A wall just outside the exit so nobody can walk off the screen.
	_add_box(_walls, Rect2(COLS * T + 2.0, 0, T, ROWS * T))
	_exit_block = _add_box(_walls, Rect2((COLS - 1) * T, DOOR_ROW * T, T, T))

	var tall := StaticBody2D.new()
	tall.collision_layer = 8
	tall.collision_mask = 0
	add_child(tall)
	var low := StaticBody2D.new()
	low.collision_layer = 16
	low.collision_mask = 0
	add_child(low)
	# Join side-by-side obstacle tiles into one wide box each.
	for y in range(1, ROWS - 1):
		var x := 1
		while x < COLS - 1:
			var c := grid[y * COLS + x]
			if c == TALL or c == LOW:
				var run := 1
				while x + run < COLS - 1 and grid[y * COLS + x + run] == c:
					run += 1
				_add_box(tall if c == TALL else low, Rect2(x * T, y * T, run * T, T))
				x += run
			else:
				x += 1


func _add_box(body: StaticBody2D, rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	return shape


# ----------------------------------------------------------------------
# Drawing
# ----------------------------------------------------------------------

func _draw() -> void:
	var wall_tiles: Array = floor_def.get("wall_tiles", [Sprites.WALL_BRICK])
	var wall_color := _accent.darkened(0.42)
	var wall_dark := _accent.darkened(0.82)
	draw_rect(Rect2(0, 0, COLS * T, ROWS * T), Pal.INK)

	for d: Array in _decor:
		var cell: Vector2i = d[0]
		Sprites.draw(self, d[1], Vector2(cell.x * T, cell.y * T), Color(_accent.darkened(0.55), d[2]))

	for y in ROWS:
		for x in COLS:
			var index := y * COLS + x
			var c := grid[index]
			var at := Vector2(x * T, y * T)
			var is_edge := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			if c == WALL or (is_edge and c == FLOOR):
				draw_rect(Rect2(at, Vector2(T, T)), wall_dark)
				if c == WALL:
					# Mostly one brick pattern, with the odd different one mixed in.
					var pick := 1 if (x * 7 + y * 13) % 5 == 0 else 0
					Sprites.draw(self, wall_tiles[pick % wall_tiles.size()], at, wall_color)
			elif c == TALL:
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(T - 2, T - 2)), wall_dark)
				Sprites.draw(self, _obstacle_art.get(index, Sprites.CRATE), at, _accent.darkened(0.12))
			elif c == LOW:
				# Water: always blue, so it reads as something you can shoot across.
				draw_rect(Rect2(at, Vector2(T, T)), Pal.WATER_DEEP)
				Sprites.draw(self, Sprites.WATER, at, Pal.WATER)

	# The way in (always shut behind you) and the way out.
	var entry := Vector2(0, DOOR_ROW * T)
	draw_rect(Rect2(entry, Vector2(T, T)), wall_dark)
	Sprites.draw(self, Sprites.DOOR_CLOSED, entry, wall_color.darkened(0.25))
	var exit := Vector2((COLS - 1) * T, DOOR_ROW * T)
	if exit_open:
		draw_rect(Rect2(exit, Vector2(T, T)), Pal.INK)
		Sprites.draw(self, Sprites.ARROW_RIGHT, exit, Pal.GOLD)
	else:
		draw_rect(Rect2(exit, Vector2(T, T)), wall_dark)
		Sprites.draw(self, Sprites.DOOR_CLOSED, exit, _accent)
