extends RefCounted
## Room layouts: where the obstacles stand in a room. Use with:
##   const Layouts = preload("res://scripts/data/room_layouts.gd")
##
## FORMAT: one layout = 7 strings of 17 characters (the room floor is 17 tiles wide, 7 tall).
##   .  empty floor
##   #  rock     blocks walking and shots; a bomb destroys it
##   o  pit      blocks walking; shots and flying enemies pass over it
##   ^  spikes   hurt the player while they are up (they go up and down in a steady rhythm)
##   c  crate    blocks walking and shots; breaks after a few shots or a bomb; sometimes drops a coin
##   I  column   blocks walking and shots; never breaks
##   e  a good place for an enemy to appear (optional; without markers enemies pick free tiles)
## Each layout also has:
##   name   only for you and for the --layout=<name> test flag
##   kind   "combat" (normal fights), or "start", "treasure", "shop", "secret", "boss"
##   diff   1 easy, 2 medium, 3 hard. Floor 1 uses 1-2, floor 2 uses 1-3, deeper floors 2-3.
## RULES (checked by problems() and by tools/check.sh):
##   - the four door tiles (middle of each wall) and the tile in front of each must stay empty
##   - every walkable tile must be reachable from the doors (no sealed-off pockets)
## To add a layout: copy a block below, change the drawing, give it a new name.

const COLS := 17
const ROWS := 7

const ALL := [
	# ------------------------------------------------------------ special rooms
	{"name": "start", "kind": "start", "diff": 1, "rows": [
		".................",
		".................",
		".................",
		".................",
		".................",
		".................",
		".................",
	]},
	{"name": "treasure_vault", "kind": "treasure", "diff": 1, "rows": [
		".................",
		"..I...........I..",
		".................",
		".................",
		".................",
		"..I...........I..",
		".................",
	]},
	{"name": "shop_floor", "kind": "shop", "diff": 1, "rows": [
		".................",
		".................",
		".................",
		".................",
		".................",
		".c.............c.",
		".................",
	]},
	{"name": "secret_nook", "kind": "secret", "diff": 1, "rows": [
		".................",
		".#.............#.",
		".................",
		".................",
		".................",
		".#.............#.",
		".................",
	]},
	{"name": "boss_arena", "kind": "boss", "diff": 1, "rows": [
		".................",
		".................",
		".................",
		".................",
		".................",
		".................",
		".................",
	]},
	# ------------------------------------------------------------ fights, easy
	{"name": "open", "kind": "combat", "diff": 1, "rows": [
		".................",
		"..e...........e..",
		".................",
		".................",
		".................",
		"..e...........e..",
		".................",
	]},
	{"name": "four_pillars", "kind": "combat", "diff": 1, "rows": [
		".................",
		"...I.........I...",
		".......e.e.......",
		".................",
		".......e.e.......",
		"...I.........I...",
		".................",
	]},
	{"name": "rock_corners", "kind": "combat", "diff": 1, "rows": [
		"##.............##",
		"#...e.......e...#",
		".................",
		".................",
		".................",
		"#...e.......e...#",
		"##.............##",
	]},
	{"name": "crate_rows", "kind": "combat", "diff": 1, "rows": [
		".................",
		"..cc....e....cc..",
		"..c...........c..",
		".....e.....e.....",
		"..c...........c..",
		"..cc....e....cc..",
		".................",
	]},
	{"name": "centre_block", "kind": "combat", "diff": 1, "rows": [
		".................",
		".e.............e.",
		"......##.##......",
		"......#...#......",
		"......##.##......",
		".e.............e.",
		".................",
	]},
	{"name": "diagonal_rocks", "kind": "combat", "diff": 1, "rows": [
		".................",
		"..#.........e.#..",
		"....#.......#....",
		".e.............e.",
		"....#.......#....",
		"..#.e.........#..",
		".................",
	]},
	{"name": "crate_stores", "kind": "combat", "diff": 1, "rows": [
		".................",
		".cc...........cc.",
		".cc..e.....e..cc.",
		".................",
		".cc..e.....e..cc.",
		".cc...........cc.",
		".................",
	]},
	# ------------------------------------------------------------ fights, medium
	{"name": "pit_islands", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..oo...e.e...oo..",
		"..oo.........oo..",
		".................",
		"..oo.........oo..",
		"..oo...e.e...oo..",
		".................",
	]},
	{"name": "spike_corridor", "kind": "combat", "diff": 2, "rows": [
		".................",
		".^^^^^.....^^^^^.",
		"...e.........e...",
		".................",
		"...e.........e...",
		".^^^^^.....^^^^^.",
		".................",
	]},
	{"name": "crate_maze", "kind": "combat", "diff": 2, "rows": [
		".................",
		".c.c.c.e.e.c.c.c.",
		".................",
		"...c.c.c.c.c.c...",
		".................",
		".c.c.c.e.e.c.c.c.",
		".................",
	]},
	{"name": "spike_cross", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..e....^.^....e..",
		".......^.^.......",
		"..^^^.......^^^..",
		".......^.^.......",
		"..e....^.^....e..",
		".................",
	]},
	{"name": "columns_hall", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..I..I..e..I..I..",
		".................",
		".e.............e.",
		".................",
		"..I..I..e..I..I..",
		".................",
	]},
	{"name": "rubble_field", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..#...e...#...e..",
		".....#.......#...",
		"..c.....#........",
		".....#.......#...",
		"..#...e...#...e..",
		".................",
	]},
	{"name": "split_wall", "kind": "combat", "diff": 2, "rows": [
		".................",
		".e....#...#....e.",
		"......#...#......",
		".................",
		"......#...#......",
		".e....#...#....e.",
		".................",
	]},
	# ------------------------------------------------------------ fights, hard
	{"name": "pit_moat", "kind": "combat", "diff": 3, "rows": [
		".................",
		".e.ooooo.ooooo.e.",
		"...o.........o...",
		".......e.e.......",
		"...o.........o...",
		".e.ooooo.ooooo.e.",
		".................",
	]},
	{"name": "pit_lanes", "kind": "combat", "diff": 3, "rows": [
		".................",
		".ooo.ooo.ooo.ooo.",
		"....e.......e....",
		".................",
		"....e.......e....",
		".ooo.ooo.ooo.ooo.",
		".................",
	]},
	{"name": "spike_ring", "kind": "combat", "diff": 3, "rows": [
		".................",
		"...^^^^^.^^^^^...",
		"...^....e....^...",
		"......e...e......",
		"...^....e....^...",
		"...^^^^^.^^^^^...",
		".................",
	]},
	{"name": "vault", "kind": "combat", "diff": 3, "rows": [
		".................",
		".I.c.o..e..o.c.I.",
		"...c.o.....o.c...",
		".e.............e.",
		"...c.o.....o.c...",
		".I.c.o..e..o.c.I.",
		".................",
	]},
	# ------------------------------------------------------------ test only (never picked by the game)
	{"name": "everything", "kind": "test", "diff": 1, "rows": [
		".................",
		".#.c.I.o.^.#.c.I.",
		".#.c...o.^.......",
		"........e........",
		".^^..oo...cc.##..",
		".^^..oo.e.cc.##..",
		".................",
	]},
]

const LEGAL := ".#o^cIeT"
const BLOCKERS := "#ocIT"
## Door tiles and the tile in front of each: these must stay free.
const KEEP_FREE: Array[Vector2i] = [
	Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 6), Vector2i(8, 5),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(16, 3), Vector2i(15, 3),
]


static func by_name(layout_name: String) -> Dictionary:
	for l in ALL:
		if l["name"] == layout_name:
			return l
	return {}


## All layouts of a kind whose difficulty is between lo and hi. floor_number (1 = first floor)
## leaves out layouts whose "floors" list does not name that floor; 0 = any floor.
static func pick_list(kind: String, lo: int = 1, hi: int = 3, floor_number: int = 0) -> Array:
	var out: Array = []
	for l in ALL:
		if l["kind"] != kind or int(l["diff"]) < lo or int(l["diff"]) > hi:
			continue
		if floor_number > 0 and l.has("floors") and not (l["floors"] as Array).has(floor_number):
			continue
		out.append(l)
	return out


## A list of what is wrong with a layout (empty = fine).
static func problems(layout: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rows: Array = layout.get("rows", [])
	var title := String(layout.get("name", "?"))
	if rows.size() != ROWS:
		out.append("%s: needs %d rows, has %d" % [title, ROWS, rows.size()])
		return out
	for y in ROWS:
		var line := String(rows[y])
		if line.length() != COLS:
			out.append("%s: row %d is %d characters long, needs %d" % [title, y, line.length(), COLS])
			return out
		for x in COLS:
			if LEGAL.find(line[x]) < 0:
				out.append("%s: unknown character '%s' at column %d row %d" % [title, line[x], x, y])
	if not out.is_empty():
		return out
	for cell in KEEP_FREE:
		var ch := String(rows[cell.y])[cell.x]
		if ch != "." and ch != "e":
			out.append("%s: tile %s must stay empty (it is a door or the tile in front of one)" % [title, cell])
	# flood fill from the top door tile over everything that can be walked on
	var seen := {}
	var todo: Array[Vector2i] = [Vector2i(8, 0)]
	seen[Vector2i(8, 0)] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS or seen.has(n):
				continue
			if BLOCKERS.find(String(rows[n.y])[n.x]) >= 0:
				continue
			seen[n] = true
			todo.append(n)
	for y in ROWS:
		for x in COLS:
			if BLOCKERS.find(String(rows[y])[x]) < 0 and not seen.has(Vector2i(x, y)):
				out.append("%s: tile (%d,%d) cannot be reached from the doors" % [title, x, y])
	return out


## Checks every layout; returns all problems found.
static func all_problems() -> Array[String]:
	var out: Array[String] = []
	var names := {}
	for l in ALL:
		if names.has(l["name"]):
			out.append("two layouts are called '%s'" % l["name"])
		names[l["name"]] = true
		out.append_array(problems(l))
	return out
