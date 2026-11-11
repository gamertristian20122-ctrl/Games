extends Node2D
## Room: builds ONE room on screen out of the pack's tiles and runs everything inside it:
## walls, doors, obstacles, the fight (doors shut -> enemies appear -> doors open -> reward),
## bomb blasts, and remembering what the room looked like when the player comes back.
## The run (scripts/run/run.gd) makes a new Room node every time the player walks through a door.
##
## Space: the floor is (0,0)..(G.ROOM_W, G.ROOM_H). Everything is placed by its FEET; things
## lower on the screen are drawn in front (the `ysort` node does that).
##
## Handy calls for other scripts:
##   move_circle(pos, radius, motion, flying, is_player)   walk with wall sliding; returns the new position
##   shot_blocked(pos) / sight_clear(a, b) / walk_clear(a, b, flying)
##   flow_dir(pos, flying)             which way to walk to reach the player around obstacles
##   spawn_enemy(id, pos, opts)        add_thing(kind, desc)        drop(pickup_id, pos)
##   explode(pos)                      free_spot_near(pos)
##
## THINGS (pickups, chests, pedestals, the shopkeeper, the exit) are small scripts in
## scripts/entities/. add_thing("chest", {...}) loads scripts/entities/chest.gd, so a new kind of
## thing is just a new file there with  setup(room, desc)  and  save() -> Dictionary.

const Layouts = preload("res://scripts/data/room_layouts.gd")
const RoomLook = preload("res://scripts/run/room_look.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const BossScript = preload("res://scripts/entities/boss.gd")
const BombScript = preload("res://scripts/entities/bomb.gd")
const CurseScript = preload("res://scripts/entities/curse.gd")

# ---- what a floor tile can hold
const EMPTY := 0
const ROCK := 1
const PIT := 2
const SPIKES := 3
const CRATE := 4
const COLUMN := 5
const CHAR_TO_CELL := {"#": ROCK, "o": PIT, "^": SPIKES, "c": CRATE, "I": COLUMN}

const COLS := G.ROOM_COLS
const ROWS := G.ROOM_ROWS
const W := float(G.ROOM_W)
const H := float(G.ROOM_H)
const T := G.TILE
const DOOR_HALF := 9.0          ## half the width of a door opening
const CRATE_HITS := 3
const SPAWN_DELAY := 0.7        ## the warning time before an enemy appears
const SPAWN_SAFE_DIST := 48.0   ## enemies never appear closer to the player than this

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

# spikes: seconds of each part of their rhythm (down, tips showing = warning, up)
const SPIKE_DOWN := 1.3
const SPIKE_WARN := 0.5
const SPIKE_UP := 0.8

const IRON_DARK := Color(0.15, 0.15, 0.19)
const IRON_LIGHT := Color(0.46, 0.48, 0.56)
const GOLD := Color(0.96, 0.76, 0.24)
const BOSS_RED := Color(0.80, 0.14, 0.14)
const STONE_LIGHT := Color(0.69, 0.60, 0.52)
const STONE_DARK := Color(0.13, 0.12, 0.13)

var run: Node
var coord := Vector2i.ZERO
var rs: Dictionary               ## this room's record in run.rooms (survives when the room node is freed)
var type: int = G.RoomType.COMBAT
var theme: Dictionary
var rng := RandomNumberGenerator.new()

var grid := PackedByteArray()    ## COLS x ROWS cell codes
var crate_hp := {}               ## cell index -> hits left
var cell_nodes := {}             ## cell index -> the obstacle's sprite node
var extra_solids: Array[Rect2] = []   ## small extra blockers (fountain basins)
var walls: Array[Rect2] = []     ## the room edge as rectangles, with gaps where doors are open
var spawn_marks: Array[Vector2i] = []

var enemies: Array = []          ## every living enemy (and boss) in the room
var things: Array = []           ## pickups, chests, pedestals ... (anything with save())
var blockers: Array = []         ## familiars that stop enemy shots (and the Hungry Curse)
var curse: Node2D = null         ## the Hungry Curse while a fight is on (scripts/entities/curse.gd), else null
var bombs: Array = []            ## bombs lying in the room whose fuse is still burning
var fighting := false
var fight_time := 0.0
var spikes_up := false
var has_spikes := false
var _spike_t := 0.0
var _spike_frame := 0

var ysort: Node2D
var tiles: Node2D
var front: Node2D
var door_fx: Node2D
var spikes_node: Node2D
var _top_leaf: Sprite2D

var _block_walk := PackedByteArray([0, 1, 1, 0, 1, 1])
var _block_fly := PackedByteArray([0, 1, 0, 0, 1, 1])
var _block_shot := PackedByteArray([0, 1, 0, 0, 1, 1])
var _flow_walk := PackedInt32Array()
var _flow_fly := PackedInt32Array()
var _flow_cell := -1
var _flow_dirty := true
var look: Node2D                 ## draws the room: floor, walls, doors, torches, decoration (scripts/run/room_look.gd)
var torch_cells := {}            ## cell index -> true where a column is really a standing torch (layout letter T)
var _lock_bump_cd := 0.0
var _pending_reward := false
var _crack_fx: Node2D            ## draws the cracks the Hungry Curse leaves on hidden doors
## Shown once when the Curse cracks a wall.
const CRACK_TEXT := "The wall cracked!"
const CRACK_LIGHT := Color(0.69, 0.60, 0.52, 0.55)
## The crack as pixel steps: x = how deep into the wall, y = sideways.
const CRACK_SHAPE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(6, -1), Vector2i(7, -1), Vector2i(8, 0), Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 2),
	Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, -2), Vector2i(7, -3), Vector2i(8, -4), Vector2i(2, -1), Vector2i(1, -2)]


# =============================================================================== building
func setup(the_run: Node, at: Vector2i) -> void:
	run = the_run
	coord = at
	rs = run.rooms[at]
	type = rs["type"]
	theme = run.theme
	rng.seed = int(rs["seed"])
	_build_nodes()
	_build_grid()
	_roll_look()
	_build_obstacle_sprites()
	_build_decor_nodes()
	_rebuild_walls()
	if rs.has("things"):
		for desc: Dictionary in rs["things"]:
			add_thing(String(desc["kind"]), desc)
	else:
		_first_visit_content()
	_refresh_door_art()
	tiles.queue_redraw()
	front.queue_redraw()
	door_fx.queue_redraw()


func _build_nodes() -> void:
	tiles = Node2D.new()
	tiles.z_index = -10
	tiles.modulate = theme["tile_tint"]
	add_child(tiles)
	tiles.draw.connect(_draw_tiles)
	spikes_node = Node2D.new()
	spikes_node.z_index = -9
	spikes_node.modulate = theme["tile_tint"]
	add_child(spikes_node)
	spikes_node.draw.connect(_draw_spikes)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	front = Node2D.new()
	front.z_index = 1
	front.modulate = theme["tile_tint"]
	add_child(front)
	front.draw.connect(_draw_front)
	door_fx = Node2D.new()
	door_fx.z_index = 2
	add_child(door_fx)
	door_fx.draw.connect(_draw_doors)
	look = RoomLook.new()
	add_child(look)


func _build_grid() -> void:
	grid.resize(COLS * ROWS)
	grid.fill(EMPTY)
	var layout := _pick_layout()
	rs["layout"] = layout.get("name", "")
	var rows: Array = layout.get("rows", [])
	for y in mini(rows.size(), ROWS):
		var line := String(rows[y])
		for x in mini(line.length(), COLS):
			var ch := line[x]
			if ch == "e":
				spawn_marks.append(Vector2i(x, y))
			elif ch == "T":
				# a standing torch: solid like a column, drawn (and lit) by the look
				grid[y * COLS + x] = COLUMN
				torch_cells[y * COLS + x] = true
			elif CHAR_TO_CELL.has(ch):
				grid[y * COLS + x] = CHAR_TO_CELL[ch]
	if rs.has("grid"):
		grid = (rs["grid"] as PackedByteArray).duplicate()
		crate_hp = (rs.get("crate_hp", {}) as Dictionary).duplicate()
	else:
		for i in grid.size():
			if grid[i] == CRATE:
				crate_hp[i] = CRATE_HITS
	for i in grid.size():
		if grid[i] == SPIKES:
			has_spikes = true


func _pick_layout() -> Dictionary:
	if rs.has("layout") and String(rs["layout"]) != "":
		return Layouts.by_name(String(rs["layout"]))
	var forced := G.arg("layout")
	if forced != "" and type == G.RoomType.COMBAT and not Layouts.by_name(forced).is_empty():
		return Layouts.by_name(forced)
	var kind := "combat"
	match type:
		G.RoomType.START: kind = "start"
		G.RoomType.TREASURE: kind = "treasure"
		G.RoomType.SHOP: kind = "shop"
		G.RoomType.SECRET: kind = "secret"
		G.RoomType.BOSS: kind = "boss"
	var lo := 1
	var hi := 2
	if run.floor_index == 1:
		hi = 3
	elif run.floor_index >= 2:
		lo = 2
		hi = 3
	var list := Layouts.pick_list(kind, lo, hi, run.floor_index + 1)
	if list.is_empty():
		list = Layouts.pick_list(kind, 1, 3, run.floor_index + 1)
	if list.is_empty():
		list = Layouts.pick_list(kind)
	if list.is_empty():
		return Layouts.ALL[0]
	return list[rng.randi() % list.size()]


## Decides the room's look from its seed (floor tiles, wall decoration, torches): see room_look.gd.
func _roll_look() -> void:
	look.roll(self)


## Builds the torches, fountains and their lights.
func _build_decor_nodes() -> void:
	look.build()


func _build_obstacle_sprites() -> void:
	for i in grid.size():
		if grid[i] == ROCK or grid[i] == CRATE or grid[i] == COLUMN:
			_make_obstacle_sprite(i)


## STAND-IN: the pack has no rock picture. A "rock" is a broken pillar stump, put together from
## two pieces of the pack's own column sprite (its cap and its foot).
func _make_obstacle_sprite(i: int) -> void:
	var cx := i % COLS
	var cy := i / COLS
	var node := Node2D.new()
	node.position = Vector2(cx * T + 8, cy * T + 15)
	match grid[i]:
		ROCK:
			var top := Sprite2D.new()
			top.texture = Art.tex("column")
			top.region_enabled = true
			top.region_rect = Rect2(0, 4, 16, 12)
			top.centered = false
			top.position = Vector2(-8, -19)
			node.add_child(top)
			var foot := Sprite2D.new()
			foot.texture = Art.tex("column")
			foot.region_enabled = true
			foot.region_rect = Rect2(0, 30, 16, 9)
			foot.centered = false
			foot.position = Vector2(-8, -7)
			node.add_child(foot)
		CRATE:
			var s := Sprite2D.new()
			s.texture = Art.tex("crate")
			s.centered = false
			s.position = Vector2(-8, -22)
			node.add_child(s)
		COLUMN:
			if torch_cells.has(i):
				look.build_floor_torch(node)
			else:
				var s2 := Sprite2D.new()
				s2.texture = Art.tex("column")
				s2.centered = false
				s2.position = Vector2(-8, -36)
				node.add_child(s2)
	if not torch_cells.has(i):
		look.tint_obstacle(node)
	ysort.add_child(node)
	cell_nodes[i] = node


# =============================================================================== drawing
## The floor, the walls and the doors are drawn by the look (scripts/run/room_look.gd).
func _draw_tiles() -> void:
	look.draw_tiles(tiles)


func _draw_front() -> void:
	look.draw_front(front)


func _draw_spikes() -> void:
	if not has_spikes:
		return
	var tex: Texture2D = Art.frames("floor_spikes").get_frame_texture("default", _spike_frame)
	for i in grid.size():
		if grid[i] == SPIKES:
			spikes_node.draw_texture(tex, Vector2((i % COLS) * T, (i / COLS) * T))


## Door states (open, shut, locked, boss, hidden, blown open) are explained at the top of room_look.gd.
func _draw_doors() -> void:
	look.draw_doors(door_fx)


func _refresh_door_art() -> void:
	look.refresh_door_art()
	door_fx.queue_redraw()


# =============================================================================== doors
func door_exists(dir: Vector2i) -> bool:
	return (rs["doors"] as Dictionary).has(dir)


## A door you can see (hidden ones only after a bomb revealed them).
func door_visible(dir: Vector2i) -> bool:
	if not door_exists(dir):
		return false
	var door: Dictionary = rs["doors"][dir]
	return not door["hidden"] or door["revealed"]


## A door you can walk through right now.
func door_passable(dir: Vector2i) -> bool:
	if fighting or not door_visible(dir):
		return false
	var door: Dictionary = rs["doors"][dir]
	return not door["locked"] or type == G.RoomType.TREASURE


## Where a door sits on the edge of the floor.
func door_pos(dir: Vector2i) -> Vector2:
	if dir == UP:
		return Vector2(G.DOOR_COL * T + 8, 0)
	if dir == DOWN:
		return Vector2(G.DOOR_COL * T + 8, H)
	if dir == LEFT:
		return Vector2(0, G.DOOR_ROW * T + 8)
	return Vector2(W, G.DOOR_ROW * T + 8)


func _rebuild_walls() -> void:
	walls.clear()
	var far := 48.0
	for dir: Vector2i in [UP, DOWN, LEFT, RIGHT]:
		var open := door_passable(dir)
		var m := door_pos(dir)
		if dir == UP or dir == DOWN:
			var y0 := -far if dir == UP else H
			if open:
				walls.append(Rect2(-far, y0, far + m.x - DOOR_HALF, far))
				walls.append(Rect2(m.x + DOOR_HALF, y0, W + far - m.x - DOOR_HALF, far))
			else:
				walls.append(Rect2(-far, y0, W + 2 * far, far))
		else:
			var x0 := -far if dir == LEFT else W
			if open:
				walls.append(Rect2(x0, -far, far, far + m.y - DOOR_HALF))
				walls.append(Rect2(x0, m.y + DOOR_HALF, far, H + far - m.y - DOOR_HALF))
			else:
				walls.append(Rect2(x0, -far, far, H + 2 * far))


func _doors_changed() -> void:
	_rebuild_walls()
	_refresh_door_art()
	tiles.queue_redraw()
	front.queue_redraw()
	door_fx.queue_redraw()


## Opens a locked door for good (both sides).
func unlock_door(dir: Vector2i) -> void:
	var door: Dictionary = rs["doors"][dir]
	door["locked"] = false
	var other: Dictionary = run.rooms[door["to"]]["doors"]
	if other.has(-dir):
		other[-dir]["locked"] = false
	_doors_changed()


## Shows a hidden door for good (both sides).
func reveal_door(dir: Vector2i) -> void:
	var door: Dictionary = rs["doors"][dir]
	if door["revealed"]:
		return
	door["revealed"] = true
	var other: Dictionary = run.rooms[door["to"]]["doors"]
	if other.has(-dir):
		other[-dir]["revealed"] = true
	run.rooms[door["to"]]["seen"] = true
	var at := door_pos(dir)
	run.fx.burst(at, [STONE_LIGHT, Color(0.4, 0.35, 0.32), Color(0.25, 0.22, 0.22)], 26, 80.0, 0.7, 2.6)
	Sfx.play("secret_found")
	run.secret_revealed()
	_doors_changed()
	_refresh_cracks()
	G.hud_changed.emit()


## The Hungry Curse slammed into the wall in front of a hidden door: it leaves a crack that stays
## for good (on both sides) and shows on the minimap. A second slam, or a bomb, opens the door.
func crack_door(dir: Vector2i) -> void:
	var door: Dictionary = rs["doors"][dir]
	if door.get("cracked", false) or door["revealed"]:
		return
	door["cracked"] = true
	var other: Dictionary = run.rooms[door["to"]]["doors"]
	if other.has(-dir):
		other[-dir]["cracked"] = true
	run.fx.burst(door_pos(dir), [STONE_LIGHT, Color(0.4, 0.35, 0.32), Color(0.25, 0.22, 0.22)], 14, 60.0, 0.5, 2.2)
	Sfx.play("rock_break", -4.0, 0.05, 0.75)
	G.stat.emit("wall_cracked", 1)
	G.toast.emit(CRACK_TEXT, "")
	_refresh_cracks()
	G.hud_changed.emit()


## Cracked hidden doors are drawn by a small canvas of their own, on top of the walls.
func _refresh_cracks() -> void:
	var any := false
	for dir: Vector2i in rs["doors"]:
		var door: Dictionary = rs["doors"][dir]
		if door["hidden"] and not door["revealed"] and door.get("cracked", false):
			any = true
	if _crack_fx == null:
		if not any:
			return
		_crack_fx = Node2D.new()
		_crack_fx.z_index = 2
		add_child(_crack_fx)
		_crack_fx.draw.connect(_draw_cracks)
	_crack_fx.queue_redraw()


## A crack is a jagged dark line with a paler edge: plain pixels, no picture.
func _draw_cracks() -> void:
	for dir: Vector2i in rs["doors"]:
		var door: Dictionary = rs["doors"][dir]
		if not door["hidden"] or door["revealed"] or not door.get("cracked", false):
			continue
		var into := Vector2(dir)                 # from the floor's edge into the wall
		var along := Vector2(absf(into.y), absf(into.x))
		var from := door_pos(dir) + into * (1.0 if dir == UP or dir == LEFT else 0.0)
		if dir == DOWN:
			from.y -= 2.0                        # the bottom wall's top edge overlaps the floor
		for step: Vector2i in CRACK_SHAPE:
			var p := from + into * float(step.x) + along * float(step.y)
			_crack_fx.draw_rect(Rect2(floorf(p.x) + 1.0, floorf(p.y), 1, 1), CRACK_LIGHT)
			_crack_fx.draw_rect(Rect2(floorf(p.x), floorf(p.y), 1, 1), STONE_DARK)


func _check_doors(player: Node) -> void:
	var p: Vector2 = player.position
	for dir: Vector2i in rs["doors"]:
		var m := door_pos(dir)
		var along := absf(p.x - m.x) if (dir == UP or dir == DOWN) else absf(p.y - m.y)
		if along > DOOR_HALF + 2.0:
			continue
		var beyond := 0.0
		if dir == UP:
			beyond = -p.y
		elif dir == DOWN:
			beyond = p.y - H
		elif dir == LEFT:
			beyond = -p.x
		else:
			beyond = p.x - W
		if door_passable(dir):
			if beyond > 3.0:
				if rs["doors"][dir]["locked"]:
					unlock_door(dir)
				run.go(dir)
				return
		elif door_visible(dir) and not fighting and rs["doors"][dir]["locked"] and beyond > -(player.radius + 2.5):
			# pushing against a locked door: a key opens it
			if Controls.move.dot(Vector2(dir)) > 0.3 and _lock_bump_cd <= 0.0:
				_lock_bump_cd = 0.8
				if player.keys > 0:
					player.keys -= 1
					G.stat.emit("key_used", 1)
					Sfx.play("door_unlock")
					G.toast.emit("Unlocked", "")
					run.fx.burst(m, [GOLD, Color(1, 1, 0.8)], 12, 60.0, 0.5, 2.0)
					unlock_door(dir)
					G.hud_changed.emit()
				else:
					Sfx.play("shop_deny", -4.0)
					G.toast.emit("Locked", "You need a key.")


# =============================================================================== collisions
## Moves a circle through the room, sliding along walls and obstacles. Returns where it ends up.
func move_circle(p: Vector2, r: float, motion: Vector2, flying: bool = false, is_player: bool = false) -> Vector2:
	var dist := motion.length()
	if dist < 0.0001:
		return _resolve(p, r, flying, is_player)
	var steps := int(dist / 4.0) + 1
	var step := motion / float(steps)
	for s in steps:
		p = _resolve(p + step, r, flying, is_player)
	return p


func _resolve(p: Vector2, r: float, flying: bool, is_player: bool) -> Vector2:
	var table := _block_fly if flying else _block_walk
	for pass_i in 2:
		if is_player:
			if p.x < r + 1.0 or p.y < r + 1.0 or p.x > W - r - 1.0 or p.y > H - r - 1.0:
				for w in walls:
					p = _push_rect(p, r, w)
		else:
			p.x = clampf(p.x, r, W - r)
			p.y = clampf(p.y, r, H - r)
		var x0 := maxi(int(floor((p.x - r) / T)), 0)
		var x1 := mini(int(floor((p.x + r) / T)), COLS - 1)
		var y0 := maxi(int(floor((p.y - r) / T)), 0)
		var y1 := mini(int(floor((p.y + r) / T)), ROWS - 1)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				if table[grid[cy * COLS + cx]] != 0:
					p = _push_rect(p, r, Rect2(cx * T, cy * T, T, T))
		for e in extra_solids:
			p = _push_rect(p, r, e)
	return p


func _push_rect(p: Vector2, r: float, rect: Rect2) -> Vector2:
	var qx := clampf(p.x, rect.position.x, rect.end.x)
	var qy := clampf(p.y, rect.position.y, rect.end.y)
	var dx := p.x - qx
	var dy := p.y - qy
	var d2 := dx * dx + dy * dy
	if d2 >= r * r:
		return p
	if d2 > 0.0001:
		var d := sqrt(d2)
		return Vector2(qx + dx / d * r, qy + dy / d * r)
	# the centre is inside the rectangle: leave through the nearest side
	var l := p.x - rect.position.x
	var rt := rect.end.x - p.x
	var t := p.y - rect.position.y
	var b := rect.end.y - p.y
	var m := minf(minf(l, rt), minf(t, b))
	if m == l:
		return Vector2(rect.position.x - r, p.y)
	if m == rt:
		return Vector2(rect.end.x + r, p.y)
	if m == t:
		return Vector2(p.x, rect.position.y - r)
	return Vector2(p.x, rect.end.y + r)


func cell_index(p: Vector2) -> int:
	return clampi(int(p.y) / T, 0, ROWS - 1) * COLS + clampi(int(p.x) / T, 0, COLS - 1)


func cell_at(p: Vector2) -> int:
	if p.x < 0.0 or p.y < 0.0 or p.x >= W or p.y >= H:
		return EMPTY
	return grid[int(p.y) / T * COLS + int(p.x) / T]


## True when a shot at this floor position has hit a wall or a solid obstacle.
func shot_blocked(p: Vector2) -> bool:
	if p.x < -2.0 or p.y < -5.0 or p.x > W + 2.0 or p.y > H + 3.0:
		return true
	if p.x < 0.0 or p.y < 0.0 or p.x >= W or p.y >= H:
		return false
	return _block_shot[grid[int(p.y) / T * COLS + int(p.x) / T]] != 0


## A shot hit something solid here: crates take damage.
func shot_hit_solid(p: Vector2, damage: float, by_player: bool) -> void:
	if p.x < 0.0 or p.y < 0.0 or p.x >= W or p.y >= H:
		return
	var i := int(p.y) / T * COLS + int(p.x) / T
	if grid[i] == CRATE and by_player and damage > 0.0:
		crate_hp[i] = int(crate_hp.get(i, CRATE_HITS)) - 1
		var node: Node2D = cell_nodes.get(i)
		if node != null:
			var tw := node.create_tween()
			tw.tween_property(node, "scale", Vector2(1.12, 0.9), 0.04)
			tw.tween_property(node, "scale", Vector2.ONE, 0.08)
		if int(crate_hp[i]) <= 0:
			break_cell(i)


func _line_clear(a: Vector2, b: Vector2, table: PackedByteArray) -> bool:
	var d := b - a
	var n := int(d.length() / 5.0) + 1
	for k in range(1, n):
		var q := a + d * (float(k) / float(n))
		if q.x < 0.0 or q.y < 0.0 or q.x >= W or q.y >= H:
			continue
		if table[grid[int(q.y) / T * COLS + int(q.x) / T]] != 0:
			return false
	return true


## Could a shot fly from a to b?
func sight_clear(a: Vector2, b: Vector2) -> bool:
	return _line_clear(a, b, _block_shot)


## Could something walk (or fly) straight from a to b?
func walk_clear(a: Vector2, b: Vector2, flying: bool = false) -> bool:
	return _line_clear(a, b, _block_fly if flying else _block_walk)


func blocks_walk(cell: Vector2i, flying: bool = false) -> bool:
	if not G.in_room(cell):
		return true
	return (_block_fly if flying else _block_walk)[grid[cell.y * COLS + cell.x]] != 0


## How far something could travel from p along dir before hitting a wall or obstacle (up to max_dist).
func ray_walk(p: Vector2, dir: Vector2, max_dist: float, flying: bool = false) -> float:
	var table := _block_fly if flying else _block_walk
	var d := 0.0
	while d < max_dist:
		var q := p + dir * (d + 4.0)
		if q.x < 4.0 or q.y < 4.0 or q.x > W - 4.0 or q.y > H - 4.0:
			break
		if table[grid[int(q.y) / T * COLS + int(q.x) / T]] != 0:
			break
		d += 4.0
	return d


# =============================================================================== pathing
## Steps to the player from every tile (breadth-first search). 9999 = cannot get there.
func bfs(from: Vector2i, flying: bool = false) -> PackedInt32Array:
	var table := _block_fly if flying else _block_walk
	var out := PackedInt32Array()
	out.resize(COLS * ROWS)
	out.fill(9999)
	from = Vector2i(clampi(from.x, 0, COLS - 1), clampi(from.y, 0, ROWS - 1))
	var start := from.y * COLS + from.x
	out[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % COLS
		var y := i / COLS
		var nd := out[i] + 1
		if x > 0 and out[i - 1] > nd and table[grid[i - 1]] == 0:
			out[i - 1] = nd
			queue.append(i - 1)
		if x < COLS - 1 and out[i + 1] > nd and table[grid[i + 1]] == 0:
			out[i + 1] = nd
			queue.append(i + 1)
		if y > 0 and out[i - COLS] > nd and table[grid[i - COLS]] == 0:
			out[i - COLS] = nd
			queue.append(i - COLS)
		if y < ROWS - 1 and out[i + COLS] > nd and table[grid[i + COLS]] == 0:
			out[i + COLS] = nd
			queue.append(i + COLS)
	return out


func _update_flow() -> void:
	var cell := cell_index(run.player.position)
	if cell == _flow_cell and not _flow_dirty:
		return
	_flow_cell = cell
	_flow_dirty = false
	var from := Vector2i(cell % COLS, cell / COLS)
	_flow_walk = bfs(from, false)
	_flow_fly = bfs(from, true)


## Which way to step from p to follow a distance map made by bfs(). Zero when already there.
func follow(dist: PackedInt32Array, p: Vector2, flying: bool = false) -> Vector2:
	var table := _block_fly if flying else _block_walk
	var cx := clampi(int(p.x) / T, 0, COLS - 1)
	var cy := clampi(int(p.y) / T, 0, ROWS - 1)
	var best := dist[cy * COLS + cx]
	if best == 0:
		return Vector2.ZERO
	var bx := cx
	var by := cy
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nx := cx + ox
			var ny := cy + oy
			if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
				continue
			var d := dist[ny * COLS + nx]
			if d >= best:
				continue
			if ox != 0 and oy != 0:
				# no cutting corners between two blocked tiles
				if table[grid[cy * COLS + nx]] != 0 or table[grid[ny * COLS + cx]] != 0:
					continue
			best = d
			bx = nx
			by = ny
	if bx == cx and by == cy:
		return Vector2.ZERO
	return (Vector2(bx * T + 8, by * T + 8) - p).normalized()


## Which way an enemy at p should walk to reach the player around obstacles.
func flow_dir(p: Vector2, flying: bool = false) -> Vector2:
	var d := follow(_flow_fly if flying else _flow_walk, p, flying)
	if d == Vector2.ZERO:
		return (run.player.position - p).normalized()
	return d


# =============================================================================== obstacles
func _cell_center(i: int) -> Vector2:
	return Vector2((i % COLS) * T + 8, (i / COLS) * T + 8)


## Destroys a rock or crate.
func break_cell(i: int) -> void:
	var what := grid[i]
	if what != ROCK and what != CRATE:
		return
	grid[i] = EMPTY
	_flow_dirty = true
	crate_hp.erase(i)
	var node: Node2D = cell_nodes.get(i)
	if node != null:
		node.queue_free()
		cell_nodes.erase(i)
	var at := _cell_center(i)
	if what == CRATE:
		run.fx.burst(at - Vector2(0, 6), Art.palette("crate"), 12, 60.0, 0.5, 2.4)
		Sfx.play("rock_break", -8.0, 0.2)
		if randf() < 0.3:
			drop("coin", at)
	else:
		run.fx.burst(at - Vector2(0, 6), Art.palette("column"), 14, 70.0, 0.55, 2.6)
		Sfx.play("rock_break", -3.0)


func is_free_cell(c: Vector2i) -> bool:
	if not G.in_room(c) or grid[c.y * COLS + c.x] != EMPTY:
		return false
	var p := G.cell_center(c.x, c.y)
	for e in extra_solids:
		if e.grow(4.0).has_point(p):
			return false
	return true


## The centre of the nearest empty tile to p that has nothing standing on it.
func free_spot_near(p: Vector2, avoid_things: bool = true) -> Vector2:
	var c := G.cell_of(Vector2(clampf(p.x, 1, W - 1), clampf(p.y, 1, H - 1)))
	for radius in range(0, 9):
		var best := Vector2.INF
		var best_d := INF
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				if maxi(absi(ox), absi(oy)) != radius:
					continue
				var n := c + Vector2i(ox, oy)
				if not is_free_cell(n):
					continue
				var q := G.cell_center(n.x, n.y)
				if avoid_things and _thing_near(q, 11.0):
					continue
				var d := q.distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best != Vector2.INF:
			return best
	return G.ROOM_CENTER


func _thing_near(p: Vector2, dist: float) -> bool:
	for t in things:
		if is_instance_valid(t) and t.solid and (t.position as Vector2).distance_to(p) < dist:
			return true
	return false


# =============================================================================== things
## Adds a pickup / chest / pedestal / ... from a description (see the file header).
func add_thing(kind: String, desc: Dictionary) -> Node2D:
	var script: GDScript = load("res://scripts/entities/%s.gd" % kind)
	if script == null:
		push_warning("Room: no thing script called '%s'" % kind)
		return null
	var node: Node2D = script.new()
	desc["kind"] = kind
	ysort.add_child(node)
	node.setup(self, desc)
	things.append(node)
	return node


func remove_thing(node: Node) -> void:
	things.erase(node)
	node.queue_free()


## Drops a pickup that pops out with a little bounce.
func drop(pickup_id: String, at: Vector2, pop: bool = true) -> Node2D:
	if blocks_walk(G.cell_of(at)):
		at = free_spot_near(at, false)
	return add_thing("pickup", {"id": pickup_id, "pos": at, "pop": pop})


func add_bomb(at: Vector2) -> void:
	var bomb: Node2D = BombScript.new()
	ysort.add_child(bomb)
	bomb.setup(self, at)
	bombs.append(bomb)


## Writes everything worth remembering into the room record (called when the player leaves).
func save_state() -> void:
	rs["grid"] = grid.duplicate()
	rs["crate_hp"] = crate_hp.duplicate()
	var list: Array = []
	for t in things:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			var d: Dictionary = t.save()
			if not d.is_empty():
				list.append(d)
	rs["things"] = list


# =============================================================================== content
## `at` itself when its tile is empty, else the middle of the nearest empty tile.
func _spot_or_near(at: Vector2) -> Vector2:
	return at if is_free_cell(G.cell_of(at)) else free_spot_near(at)


func _first_visit_content() -> void:
	match type:
		G.RoomType.TREASURE:
			var item: String = run.take_item("treasure", rng)
			# every key is a temptation: a normal item and a cursed one stand side by side, and
			# taking one makes the other crumble (only the normal one when no cursed item is left)
			var twin: String = run.take_item("cursed", rng) if item != "" else ""
			if item != "" and twin != "":
				add_thing("pedestal", {"item": item, "pair": 1, "pos": _spot_or_near(G.ROOM_CENTER + Vector2(-26, 0))})
				add_thing("pedestal", {"item": twin, "pair": 1, "pos": _spot_or_near(G.ROOM_CENTER + Vector2(26, 0))})
			elif item != "":
				add_thing("pedestal", {"item": item, "pos": G.ROOM_CENTER})
			else:
				add_thing("chest", {"pos": G.ROOM_CENTER, "locked": false, "rich": true})
		G.RoomType.SHOP:
			add_thing("shopkeeper", {"pos": Vector2(W * 0.5, 18)})
			var y := 46.0
			add_thing("pedestal", {"pickup": "heart", "price": Pickups.PRICE_HEART, "pos": Vector2(W * 0.5 - 60, y)})
			# the supply stand: a key or a bomb, but always a bomb when the hero holds none
			# (a bomb is how you get the coins out of the Hungry Curse's belly)
			var supply := "key" if rng.randf() < 0.5 else "bomb"
			if run.player.bombs <= 0:
				supply = "bomb"
			add_thing("pedestal", {"pickup": supply, "price": Pickups.PRICE_SUPPLY, "pos": Vector2(W * 0.5 - 20, y)})
			# "Starve the Curse": it only shows itself from Curse Level 1 (see pedestal.gd)
			add_thing("pedestal", {"service": "starve", "pos": _spot_or_near(Vector2(W * 0.5 + 100, y))})
			var item2: String = run.take_item("shop", rng)
			if item2 != "":
				add_thing("pedestal", {"item": item2, "price": Pickups.PRICE_ITEM, "pos": Vector2(W * 0.5 + 20, y)})
			var cursed: String = run.take_item("cursed", rng)
			if cursed != "":
				add_thing("pedestal", {"item": cursed, "price": Pickups.PRICE_CURSED, "pos": Vector2(W * 0.5 + 60, y)})
		G.RoomType.SECRET:
			if rng.randf() < 0.5:
				add_thing("chest", {"pos": G.ROOM_CENTER + Vector2(-24, 0), "locked": false, "rich": true})
			else:
				for k in 6 + rng.randi() % 4:
					var a := rng.randf() * TAU
					drop("coin5" if k == 0 else "coin", G.ROOM_CENTER + Vector2(-24, 0) + Vector2(cos(a), sin(a)) * rng.randf_range(4, 18), false)
			if rng.randf() < 0.5:
				var c2: String = run.take_item("cursed", rng)
				if c2 != "":
					add_thing("pedestal", {"item": c2, "pos": G.ROOM_CENTER + Vector2(28, 0)})


## Called by the run once the player stands in the room.
func begin(first_visit: bool) -> void:
	_update_flow()
	_refresh_cracks()
	if (type == G.RoomType.COMBAT or type == G.RoomType.BOSS) and not rs["cleared"]:
		_start_fight()
	elif not rs["cleared"]:
		rs["cleared"] = true
	if first_visit:
		match type:
			G.RoomType.SHOP:
				G.toast.emit("The Peddler", "\"Coins first, friend. Then take what you like.\"")
			G.RoomType.TREASURE:
				G.toast.emit("Treasure Room", "")
			G.RoomType.SECRET:
				G.toast.emit("Secret Room", "")


func _start_fight() -> void:
	fighting = true
	fight_time = 0.0
	Sfx.play("door_close")
	_doors_changed()
	_spawn_curse()
	var player_pos: Vector2 = run.player.position
	if type == G.RoomType.BOSS:
		spawn_enemy(run.boss_id, G.ROOM_CENTER + Vector2(0, -8), {"boss": true, "delay": 1.1})
		return
	# the first-run lesson stages its first two fights (scripts/run/curse_tutor.gd)
	var lesson: Array = run.tutor.fight_lineup(self) if run.tutor != null and is_instance_valid(run.tutor) else []
	if not lesson.is_empty():
		for row: Dictionary in lesson:
			var spot: Vector2 = row["pos"]
			if spot == Vector2.INF:
				spot = random_spawn_spot(player_pos)
			var staged: Node2D = spawn_enemy(String(row["id"]), spot, {"delay": SPAWN_DELAY, "elite": false})
			staged.stun = float(row.get("stand", 0.0))
		return
	var marks := spawn_marks.duplicate()
	for i in range(marks.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Vector2i = marks[i]
		marks[i] = marks[j]
		marks[j] = tmp
	for id in _roll_enemies():
		var at := Vector2.INF
		while not marks.is_empty() and at == Vector2.INF:
			var m: Vector2i = marks.pop_back()
			var q := G.cell_center(m.x, m.y)
			if q.distance_to(player_pos) >= SPAWN_SAFE_DIST and is_free_cell(m):
				at = q
		if at == Vector2.INF:
			at = random_spawn_spot(player_pos, Enemies.info(id).get("flying", false))
		spawn_enemy(id, at + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), {"delay": SPAWN_DELAY + rng.randf() * 0.15})


## Every locked room gets the Hungry Curse. It waits a second, rises, and sinks again when the
## fight is won (it watches room.fighting and room.enemies by itself).
func _spawn_curse() -> void:
	if G.flag("nocurse"):
		return
	curse = CurseScript.new()
	add_child(curse)
	curse.setup(self)


## A random empty tile at least SPAWN_SAFE_DIST away from `avoid`.
func random_spawn_spot(avoid: Vector2, flying: bool = false, min_dist: float = SPAWN_SAFE_DIST + 8.0) -> Vector2:
	for attempt in 60:
		var c := Vector2i(rng.randi() % COLS, rng.randi() % ROWS)
		if blocks_walk(c, flying) or grid[c.y * COLS + c.x] == SPIKES:
			continue
		var q := G.cell_center(c.x, c.y)
		if q.distance_to(avoid) < min_dist:
			continue
		if not flying and _flow_walk.size() > 0 and _flow_walk[c.y * COLS + c.x] >= 9999:
			continue
		return q
	return free_spot_near(G.ROOM_CENTER + (G.ROOM_CENTER - avoid).limit_length(60.0), false)


## Spends the room's spawn budget on enemies from the floor's pool.
func _roll_enemies() -> Array[String]:
	var pool: Array[String] = run.enemy_pool
	var out: Array[String] = []
	if pool.is_empty():
		return out
	var budget: float = run.SPAWN_BUDGET_BASE + run.SPAWN_BUDGET_PER_FLOOR * run.floor_index + run.SPAWN_BUDGET_PER_ROOM * run.rooms_cleared_floor
	# two or three kinds per room keeps fights readable
	var kinds: Array[String] = []
	var want := 2 + rng.randi() % 2
	var guard := 0
	while kinds.size() < mini(want, pool.size()) and guard < 40:
		guard += 1
		var id: String = pool[rng.randi() % pool.size()]
		if not kinds.has(id):
			kinds.append(id)
	var cheapest := INF
	for id in kinds:
		cheapest = minf(cheapest, float(Enemies.info(id)["cost"]))
	guard = 0
	while budget >= cheapest and out.size() < run.MAX_ENEMIES_PER_ROOM and guard < 80:
		guard += 1
		var id: String = kinds[rng.randi() % kinds.size()]
		var cost := float(Enemies.info(id)["cost"])
		if cost <= budget:
			out.append(id)
			budget -= cost
	return out


## Adds an enemy (or the boss when opts.boss is true). It appears after a short warning.
## opts: delay (seconds), minion (bool: no drops), boss (bool), elite (bool), owner (who summoned it)
func spawn_enemy(id: String, at: Vector2, opts: Dictionary = {}) -> Node2D:
	var e: Node2D = BossScript.new() if opts.get("boss", false) else EnemyScript.new()
	e.position = Vector2(clampf(at.x, 6, W - 6), clampf(at.y, 6, H - 6))
	ysort.add_child(e)
	e.setup(self, id, opts)
	enemies.append(e)
	return e


func enemy_died(e: Node) -> void:
	enemies.erase(e)


func _room_cleared() -> void:
	fighting = false
	rs["cleared"] = true
	if curse != null and is_instance_valid(curse):
		curse.sink()
	Sfx.play("door_open")
	_doors_changed()
	run.on_room_cleared(self)
	if type == G.RoomType.BOSS:
		var item: String = run.take_item("boss", rng)
		if item != "":
			add_thing("pedestal", {"item": item, "pos": free_spot_near(G.ROOM_CENTER + Vector2(-28, 4))})
		if run.floor_index < run.floor_count - 1:
			add_thing("floor_exit", {"pos": free_spot_near(G.ROOM_CENTER + Vector2(28, -12))})
	else:
		_roll_room_reward()


func _roll_room_reward() -> void:
	var weights: Dictionary = Pickups.ROOM_REWARD.duplicate()
	if run.player.keys == 0 and run.treasure_locked():
		weights["key"] = Pickups.KEY_WEIGHT_WHEN_NEEDED
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi() % total
	var pick := "nothing"
	for k in weights:
		roll -= int(weights[k])
		if roll < 0:
			pick = k
			break
	var at := free_spot_near(G.ROOM_CENTER)
	match pick:
		"coins":
			for k in 2 + rng.randi() % 3:
				drop("coin5" if rng.randf() < 0.08 else "coin", at)
		"heart":
			drop("heart" if rng.randf() < 0.3 else "half_heart", at)
		"key":
			drop("key", at)
		"bomb":
			drop("bomb", at)
		"chest":
			add_thing("chest", {"pos": at, "locked": rng.randf() < 0.3})
	if pick != "nothing":
		run.fx.ring(at, 2.0, 14.0, 0.35, Color(1, 1, 0.8, 0.8), 1.5, true)


# =============================================================================== bombs
## A bomb goes off at `at`: hurts enemies, the player if close, breaks rocks and crates, reveals secret doors.
func explode(at: Vector2, damage: float = 40.0) -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.hittable and (e.position as Vector2).distance_to(at) < run.BOMB_RADIUS + e.radius:
			e.hurt(damage, ((e.position as Vector2) - at).normalized(), 3.0)
	var player: Node = run.player
	if (player.position as Vector2).distance_to(at) < run.BOMB_HURT_RADIUS:
		player.hurt(2, at, "your own bomb")
	for i in grid.size():
		if (grid[i] == ROCK or grid[i] == CRATE) and _cell_center(i).distance_to(at) < run.BOMB_BREAK_RADIUS:
			break_cell(i)
	for dir: Vector2i in rs["doors"]:
		var door: Dictionary = rs["doors"][dir]
		if door["hidden"] and not door["revealed"] and door_pos(dir).distance_to(at) < run.BOMB_REVEAL_RADIUS:
			reveal_door(dir)
	for t in things.duplicate():
		if is_instance_valid(t) and t.has_method("bombed") and (t.position as Vector2).distance_to(at) < run.BOMB_RADIUS:
			t.bombed()
	# the Hungry Curse: a blast close enough stuns it and makes it cough up its coins
	if curse != null and is_instance_valid(curse):
		curse.on_blast(at)
	run.fx.explosion(at, run.BOMB_RADIUS)      # picture + ring + debris + flash (scripts/run/fx.gd)
	run.shake(0.9)
	run.hitstop(0.05)
	Sfx.play("explosion")


# =============================================================================== every frame
func _physics_process(delta: float) -> void:
	var player: Node = run.player
	if player == null or not is_instance_valid(player):
		return
	_lock_bump_cd = maxf(0.0, _lock_bump_cd - delta)
	_update_flow()
	if has_spikes:
		_tick_spikes(delta)
	_separate_enemies()
	if fighting:
		fight_time += delta
		if enemies.is_empty():
			_room_cleared()
	if not player.dead and not run.busy():
		_check_doors(player)


func _tick_spikes(delta: float) -> void:
	_spike_t = fmod(_spike_t + delta, SPIKE_DOWN + SPIKE_WARN + SPIKE_UP)
	var frame := 0
	if _spike_t > SPIKE_DOWN + SPIKE_WARN + 0.06:
		frame = 3
	elif _spike_t > SPIKE_DOWN + SPIKE_WARN:
		frame = 2
	elif _spike_t > SPIKE_DOWN:
		frame = 1
	var up := frame >= 2
	if up and not spikes_up:
		Sfx.play("spike_trap", -12.0)
	spikes_up = up
	if frame != _spike_frame:
		_spike_frame = frame
		spikes_node.queue_redraw()


## True when standing at p would hurt right now (spikes that are up).
func spikes_hurt(p: Vector2) -> bool:
	return spikes_up and cell_at(p) == SPIKES


## Enemies push each other apart a little so they never stack into one blob.
func _separate_enemies() -> void:
	var n := enemies.size()
	for i in n:
		var a: Node2D = enemies[i]
		if not a.hittable:
			continue
		var ap := a.position
		for j in range(i + 1, n):
			var b: Node2D = enemies[j]
			if not b.hittable:
				continue
			var d := b.position - ap
			var min_d: float = a.radius + b.radius
			var l2 := d.length_squared()
			if l2 >= min_d * min_d:
				continue
			var l := sqrt(l2)
			var push := (d / l if l > 0.01 else Vector2(1, 0)) * (min_d - l) * 0.5
			# heavier things (bosses) barely move
			var wa: float = b.mass / (a.mass + b.mass)
			a.position -= push * wa * 0.6
			b.position += push * (1.0 - wa) * 0.6
			ap = a.position
