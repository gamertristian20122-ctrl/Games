extends RefCounted
## Floor generator: lays out the rooms of one floor on a grid. Use with:
##   const FloorGen = preload("res://scripts/run/floor_gen.gd")
##   var rooms := FloorGen.generate(rng, room_count)
## It grows rooms outward from the start room, then turns dead ends into the special rooms:
##   BOSS = the dead end farthest from the start, TREASURE (locked door, costs a key) and SHOP = two others.
## One SECRET room is added in an empty spot that touches two or more rooms (never the boss room);
## its doors are hidden until a bomb goes off next to the wall.
## The same rng seed always gives the same floor.
##
## Result: Dictionary  Vector2i -> room record:
##   type (G.RoomType), visited, seen, cleared (bools for the minimap), seed (int), dist (steps from the start),
##   doors: Dictionary  Vector2i direction -> {"to": Vector2i, "locked": bool, "hidden": bool, "revealed": bool, "boss": bool}

const MAX_X := 4
const MAX_Y := 3


## `boss_far`: the boss room is at least this many rooms from the start.
static func generate(rng: RandomNumberGenerator, room_count: int, boss_far: int = 3) -> Dictionary:
	for attempt in 1500:
		var result := _try(rng, room_count, boss_far)
		if not result.is_empty():
			return result
	push_warning("FloorGen: could not build a good floor, using a plain corridor")
	return _fallback(rng, room_count)


static func _neighbours(cells: Dictionary, c: Vector2i) -> int:
	var n := 0
	for d in G.DIRS:
		if cells.has(c + d):
			n += 1
	return n


static func _try(rng: RandomNumberGenerator, room_count: int, boss_far: int = 3) -> Dictionary:
	var cells := {Vector2i.ZERO: true}
	var order: Array[Vector2i] = [Vector2i.ZERO]
	var guard := 0
	while order.size() < room_count and guard < 3000:
		guard += 1
		# prefer growing from recent rooms: gives corridors with branches instead of a blob
		var base: Vector2i = order[rng.randi() % order.size()]
		if rng.randf() < 0.45:
			base = order[order.size() - 1 - (rng.randi() % mini(3, order.size()))]
		var c: Vector2i = base + G.DIRS[rng.randi() % 4]
		if cells.has(c) or absi(c.x) > MAX_X or absi(c.y) > MAX_Y:
			continue
		if _neighbours(cells, c) > 1:
			continue
		cells[c] = true
		order.append(c)
	if order.size() < room_count:
		return {}
	# distances from the start
	var dist := {Vector2i.ZERO: 0}
	var todo: Array[Vector2i] = [Vector2i.ZERO]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		for d in G.DIRS:
			if cells.has(c + d) and not dist.has(c + d):
				dist[c + d] = int(dist[c]) + 1
				todo.append(c + d)
	var dead_ends: Array[Vector2i] = []
	for c in order:
		if c != Vector2i.ZERO and _neighbours(cells, c) == 1:
			dead_ends.append(c)
	if dead_ends.size() < 3:
		return {}
	var boss: Vector2i = dead_ends[0]
	for c in dead_ends:
		if int(dist[c]) > int(dist[boss]):
			boss = c
	if int(dist[boss]) < boss_far:
		return {}
	dead_ends.erase(boss)
	# shuffle the rest with our own rng so the result depends only on the seed
	for i in range(dead_ends.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Vector2i = dead_ends[i]
		dead_ends[i] = dead_ends[j]
		dead_ends[j] = tmp
	var treasure: Vector2i = dead_ends[0]
	var shop: Vector2i = dead_ends[1]
	# the secret room: an empty spot touching 2+ rooms, none of them the boss room
	var best: Array[Vector2i] = []
	var best_score := 0
	for x in range(-MAX_X - 1, MAX_X + 2):
		for y in range(-MAX_Y - 1, MAX_Y + 2):
			var c := Vector2i(x, y)
			if cells.has(c):
				continue
			var touching := 0
			var bad := false
			for d in G.DIRS:
				if cells.has(c + d):
					touching += 1
					if c + d == boss:
						bad = true
			if bad or touching < 2:
				continue
			if touching > best_score:
				best_score = touching
				best.clear()
			if touching == best_score:
				best.append(c)
	if best.is_empty():
		return {}
	var secret: Vector2i = best[rng.randi() % best.size()]

	var rooms := {}
	for c in order:
		var type := G.RoomType.COMBAT
		if c == Vector2i.ZERO:
			type = G.RoomType.START
		elif c == boss:
			type = G.RoomType.BOSS
		elif c == treasure:
			type = G.RoomType.TREASURE
		elif c == shop:
			type = G.RoomType.SHOP
		rooms[c] = _record(type, rng, int(dist[c]))
	rooms[secret] = _record(G.RoomType.SECRET, rng, 99)
	_link(rooms)
	return rooms


static func _record(type: int, rng: RandomNumberGenerator, dist: int) -> Dictionary:
	return {"type": type, "visited": false, "seen": false, "cleared": type == G.RoomType.START,
		"seed": int(rng.randi() & 0x7fffffff), "dist": dist, "doors": {}}


## Fills in the doors between rooms that sit next to each other.
static func _link(rooms: Dictionary) -> void:
	for c: Vector2i in rooms:
		var rec: Dictionary = rooms[c]
		for d in G.DIRS:
			var n: Vector2i = c + d
			if not rooms.has(n):
				continue
			var other: Dictionary = rooms[n]
			var secret: bool = rec["type"] == G.RoomType.SECRET or other["type"] == G.RoomType.SECRET
			var locked: bool = not secret and (rec["type"] == G.RoomType.TREASURE or other["type"] == G.RoomType.TREASURE)
			rec["doors"][d] = {"to": n, "locked": locked, "hidden": secret, "revealed": false,
				"boss": other["type"] == G.RoomType.BOSS and not secret}


## Only used if the random builder fails 400 times (it practically never does): a straight line of rooms.
static func _fallback(rng: RandomNumberGenerator, room_count: int) -> Dictionary:
	var rooms := {}
	var n := maxi(room_count, 5)
	for i in n - 2:
		var type := G.RoomType.COMBAT
		if i == 0:
			type = G.RoomType.START
		elif i == n - 3:
			type = G.RoomType.BOSS
		rooms[Vector2i(i, 0)] = _record(type, rng, i)
	rooms[Vector2i(1, -1)] = _record(G.RoomType.TREASURE, rng, 2)
	rooms[Vector2i(2, 1)] = _record(G.RoomType.SHOP, rng, 3)
	rooms[Vector2i(1, 1)] = _record(G.RoomType.SECRET, rng, 99)
	_link(rooms)
	return rooms
