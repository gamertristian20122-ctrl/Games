extends RefCounted
## Room layouts: where the obstacles stand in a room. Use with:
##   const Layouts = preload("res://scripts/data/room_layouts.gd")
##
## FORMAT: one layout = 7 strings of 17 characters (the room floor is 17 tiles wide, 7 tall).
##   .  empty floor
##   #  rock     blocks walking and shots; a bomb destroys it
##   o  pit      blocks walking; shots and flying enemies pass over it
##   ^  spikes   hurt the player while they are up (they all go up and down in the same steady rhythm)
##   c  crate    blocks walking and shots; breaks after a few shots or a bomb; sometimes drops a coin
##   I  column   blocks walking and shots; never breaks
##   T  torch    a standing torch: solid like a column, and it lights the room around it
##               (use a few: every one is a real light, and a room can only afford about five)
##   e  a good place for an enemy to appear (optional; without markers enemies pick free tiles)
## Each layout also has:
##   name    only for you and for the --layout=<name> test flag
##   kind    "combat" (normal fights), or "start", "treasure", "shop", "secret", "boss"
##   diff    1 easy, 2 medium, 3 hard. Floor 1 uses 1-2, floor 2 uses 1-3, deeper floors 2-3.
##   floors  optional: the floors this layout may appear on, e.g. [3, 4]. Leave it out for "anywhere".
##           The set-piece rooms of each floor are tagged this way.
## RULES (checked by problems(), by dev/validate.gd and so by tools/check.sh):
##   - the four door tiles (middle of each wall) and the tile in front of each must stay empty
##   - every walkable tile must be reachable from the doors (no sealed-off pockets)
##   - THE WIDE LANE: a block of 3x3 tiles (48 px, a little wider than the biggest Hungry Curse) must be
##     able to slide from in front of every door to every other door without touching a rock, pit,
##     column or torch. Crates and spikes do not count: crates can be shot away, spikes are flat.
##     In practice: keep rows 2-4 clear and put the solid things on rows 0-1 and 5-6 away from the
##     middle three columns, OR put them on row 3 only and keep rows 0-2 and 4-6 clear.
##   - a fight room needs at least 4 enemy markers
## To add a layout: copy a block below, change the drawing, give it a new name, run ./tools/check.sh.

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
	{"name": "start_hall", "kind": "start", "diff": 1, "rows": [
		".................",
		"..T...........T..",
		".................",
		".................",
		".................",
		"..T...........T..",
		".................",
	]},
	{"name": "treasure_vault", "kind": "treasure", "diff": 1, "rows": [
		".................",
		"...I.........I...",
		".................",
		".................",
		".................",
		"...I.........I...",
		".................",
	]},
	{"name": "treasure_shrine", "kind": "treasure", "diff": 1, "rows": [
		"#...............#",
		".....T.....T.....",
		".................",
		".................",
		".................",
		"..I...........I..",
		"#...............#",
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
	{"name": "shop_stalls", "kind": "shop", "diff": 1, "rows": [
		"cc.............cc",
		"c...............c",
		".................",
		".................",
		".................",
		"..cc.........cc..",
		"..c...........c..",
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
	{"name": "secret_cache", "kind": "secret", "diff": 1, "rows": [
		"ccc...........#c.",
		"c..............c.",
		".................",
		".................",
		".................",
		".#............c..",
		".c#..........ccc.",
	]},
	{"name": "secret_crypt", "kind": "secret", "diff": 1, "rows": [
		"..I...........I..",
		".................",
		".................",
		".................",
		".................",
		".................",
		"..I...........I..",
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
	{"name": "boss_pillars", "kind": "boss", "diff": 1, "rows": [
		".................",
		"...I.........I...",
		".................",
		".................",
		".................",
		"...I.........I...",
		".................",
	]},
	{"name": "boss_torches", "kind": "boss", "diff": 1, "rows": [
		".................",
		"..T...........T..",
		".................",
		".................",
		".................",
		"..T...........T..",
		".................",
	]},
	{"name": "boss_crypt", "kind": "boss", "diff": 1, "floors": [1, 2], "rows": [
		".I.............I.",
		".................",
		".................",
		".................",
		".................",
		".................",
		".I.............I.",
	]},
	{"name": "boss_embers", "kind": "boss", "diff": 1, "floors": [3], "rows": [
		"#...............#",
		".....T.....T.....",
		".................",
		".................",
		".................",
		".................",
		"#...............#",
	]},
	{"name": "boss_abyss", "kind": "boss", "diff": 1, "floors": [4], "rows": [
		"oo.............oo",
		"o...............o",
		".................",
		".................",
		".................",
		"o...............o",
		"oo.............oo",
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
	{"name": "centre_stones", "kind": "combat", "diff": 1, "rows": [
		".................",
		".e.............e.",
		".................",
		"......##.##......",
		".................",
		".e.............e.",
		".................",
	]},
	{"name": "scattered_rocks", "kind": "combat", "diff": 1, "rows": [
		"...#.........#...",
		".....#.e.e.#.....",
		".................",
		".e.............e.",
		".................",
		".....#.e.e.#.....",
		"...#.........#...",
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
	{"name": "corner_torches", "kind": "combat", "diff": 1, "rows": [
		".................",
		".T.............T.",
		".....e.....e.....",
		".................",
		".....e.....e.....",
		".T.............T.",
		".................",
	]},
	{"name": "pillar_gallery", "kind": "combat", "diff": 1, "rows": [
		"..I..I.....I..I..",
		".................",
		"....e.......e....",
		".................",
		"....e.......e....",
		".................",
		"..I..I.....I..I..",
	]},
	{"name": "crate_corner", "kind": "combat", "diff": 1, "rows": [
		"ccccc............",
		"ccc.......e......",
		"c.............e..",
		".................",
		"..e..............",
		"......e.......##.",
		".............###.",
	]},
	{"name": "low_wall", "kind": "combat", "diff": 1, "rows": [
		".................",
		"..e...........e..",
		".................",
		"....###...###....",
		".................",
		"..e...........e..",
		".................",
	]},
	{"name": "long_pit", "kind": "combat", "diff": 1, "rows": [
		".................",
		"...e.........e...",
		".................",
		".....ooooooo.....",
		".................",
		"...e.........e...",
		".................",
	]},
	{"name": "spike_patches", "kind": "combat", "diff": 1, "rows": [
		".................",
		"....^^.....^^....",
		"....^^..e..^^....",
		".e.............e.",
		"....^^..e..^^....",
		"....^^.....^^....",
		".................",
	]},
	# set piece: the Crypt
	{"name": "tomb_rows", "kind": "combat", "diff": 1, "floors": [1], "rows": [
		".....#.....#.....",
		".I.I.I.....I.I.I.",
		"........e........",
		"...e.........e...",
		"........e........",
		".I.I.I.....I.I.I.",
		".....#.....#.....",
	]},
	# ------------------------------------------------------------ fights, medium
	{"name": "pit_islands", "kind": "combat", "diff": 2, "rows": [
		"...ooo.....ooo...",
		"...ooo.e.e.ooo...",
		".................",
		".................",
		".................",
		"...ooo.e.e.ooo...",
		"...ooo.....ooo...",
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
		".#....#....#...#.",
		"...#.e.....e.#...",
		".................",
		"....c.......c....",
		".................",
		"..#..e.....e..#..",
		".#...#.....#...#.",
	]},
	{"name": "split_wall", "kind": "combat", "diff": 2, "rows": [
		"......#...#......",
		".e....#...#....e.",
		".................",
		".................",
		".................",
		".e....#...#....e.",
		"......#...#......",
	]},
	{"name": "torch_crossing", "kind": "combat", "diff": 2, "rows": [
		".................",
		".e...T.....T...e.",
		".................",
		"....^^^...^^^....",
		".................",
		".e...T.....T...e.",
		".................",
	]},
	{"name": "bridge", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..e...........e..",
		".................",
		"...oooo...oooo...",
		".................",
		"..e...........e..",
		".................",
	]},
	{"name": "pit_shelves", "kind": "combat", "diff": 2, "rows": [
		".oooo.......oooo.",
		".ooo..e...e..ooo.",
		".................",
		".................",
		".................",
		"...ooo.e.e.ooo...",
		"...ooo.....ooo...",
	]},
	{"name": "spike_curtains", "kind": "combat", "diff": 2, "rows": [
		".....^.....^.....",
		".e...^.....^...e.",
		".....^.....^.....",
		".................",
		".....^.....^.....",
		".e...^.....^...e.",
		".....^.....^.....",
	]},
	{"name": "crate_walls", "kind": "combat", "diff": 2, "rows": [
		".....c.....c.....",
		".e...c.....c...e.",
		".....c.....c.....",
		".................",
		".....c.....c.....",
		".e...c.....c...e.",
		".....c.....c.....",
	]},
	{"name": "broken_colonnade", "kind": "combat", "diff": 2, "rows": [
		"............#....",
		"..I..I.e.....#...",
		".................",
		".e.............e.",
		".................",
		"...#.....e.I..I..",
		"....#............",
	]},
	{"name": "hourglass", "kind": "combat", "diff": 2, "rows": [
		"....###...###....",
		".e..###...###..e.",
		".................",
		".................",
		".................",
		".e..###...###..e.",
		"....###...###....",
	]},
	{"name": "lit_spine", "kind": "combat", "diff": 2, "rows": [
		".................",
		"..e...........e..",
		".................",
		"....I.I.T.I.I....",
		".................",
		"..e...........e..",
		".................",
	]},
	# set piece: the Warrens
	{"name": "warrens_stores", "kind": "combat", "diff": 2, "floors": [2], "rows": [
		"o...............o",
		"..ccc..e.e..ccc..",
		"..ccc.......ccc..",
		".................",
		"..ccc.......ccc..",
		"..ccc..e.e..ccc..",
		"o...............o",
	]},
	# set piece: the Warrens
	{"name": "sump", "kind": "combat", "diff": 2, "floors": [2], "rows": [
		"..c...........c..",
		".e.............e.",
		".................",
		"....ooo.c.ooo....",
		".................",
		".e.............e.",
		"..c...........c..",
	]},
	# set piece: the Crypt
	{"name": "crypt_nave", "kind": "combat", "diff": 2, "floors": [1], "rows": [
		"I...I.......I...I",
		"......e...e......",
		"..^...........^..",
		".................",
		"..^...........^..",
		"......e...e......",
		"I...I.......I...I",
	]},
	# set piece: the Ashen Halls
	{"name": "forge_floor", "kind": "combat", "diff": 2, "floors": [3], "rows": [
		"#...............#",
		"...T..^...^..T...",
		".e....^...^....e.",
		".................",
		".e....^...^....e.",
		"...T..^...^..T...",
		"#...............#",
	]},
	# ------------------------------------------------------------ fights, hard
	{"name": "pit_moat", "kind": "combat", "diff": 3, "rows": [
		".e.............e.",
		"..ooooo...ooooo..",
		".................",
		".......e.e.......",
		".................",
		"..ooooo...ooooo..",
		".e.............e.",
	]},
	{"name": "pit_lanes", "kind": "combat", "diff": 3, "rows": [
		".................",
		".ooo.oo...oo.ooo.",
		"....e.......e....",
		".................",
		"....e.......e....",
		".ooo.oo...oo.ooo.",
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
		".....o.....o.....",
		".I.c.o..e..o.c.I.",
		"...c.........c...",
		".e.............e.",
		"...c.........c...",
		".I.c.o..e..o.c.I.",
		".....o.....o.....",
	]},
	{"name": "spike_maze", "kind": "combat", "diff": 3, "rows": [
		"#...^.......^...#",
		".e^...^.e.^...^e.",
		"....^...^...^....",
		"..^...^...^...^..",
		"....^...^...^....",
		".e^...^.e.^...^e.",
		"#...^.......^...#",
	]},
	{"name": "pit_bridges", "kind": "combat", "diff": 3, "rows": [
		".................",
		".e..^^^...^^^..e.",
		".................",
		"...oooo...oooo...",
		".................",
		".e..^^^...^^^..e.",
		".................",
	]},
	# set piece: the Ashen Halls
	{"name": "ember_gauntlet", "kind": "combat", "diff": 3, "floors": [3], "rows": [
		".e.............e.",
		"...T.........T...",
		".....^^^.^^^.....",
		".e......T......e.",
		".....^^^.^^^.....",
		"...T.........T...",
		".e.............e.",
	]},
	# set piece: the Pit
	{"name": "abyss_rim", "kind": "combat", "diff": 3, "floors": [4], "rows": [
		"oooooo.....oooooo",
		"oo..e.......e..oo",
		".................",
		".................",
		".................",
		"oo..e.......e..oo",
		"oooooo.....oooooo",
	]},
	# set piece: the Pit
	{"name": "last_bridge", "kind": "combat", "diff": 3, "floors": [4], "rows": [
		"ooooo.......ooooo",
		"oooo..e...e..oooo",
		".................",
		".....^^...^^.....",
		".................",
		"oooo..e...e..oooo",
		"ooooo.......ooooo",
	]},
	{"name": "pit_checker", "kind": "combat", "diff": 3, "floors": [3, 4], "rows": [
		"oo.oo.......oo.oo",
		"....o.e...e.o....",
		".................",
		".................",
		".................",
		"....o.e...e.o....",
		"oo.oo.......oo.oo",
	]},
	{"name": "narrow_keep", "kind": "combat", "diff": 3, "rows": [
		"######...........",
		"#####...e.....e..",
		"..........^^.....",
		".................",
		".....^^..........",
		"..e.....e...#####",
		"...........######",
	]},
	{"name": "crate_fortress", "kind": "combat", "diff": 3, "rows": [
		".................",
		".e...ccc.ccc...e.",
		".....c.e.e.c.....",
		".................",
		".....c.e.e.c.....",
		".e...ccc.ccc...e.",
		".................",
	]},
	{"name": "spike_lanes", "kind": "combat", "diff": 3, "rows": [
		".................",
		"^^^^^^^...^^^^^^^",
		".e.............e.",
		"....^^^...^^^....",
		".e.............e.",
		"^^^^^^^...^^^^^^^",
		".................",
	]},
	{"name": "stone_teeth", "kind": "combat", "diff": 3, "rows": [
		"..#..#.....#..#..",
		"..#..#.e.e.#..#..",
		".................",
		".e....^...^....e.",
		".................",
		"..#..#.e.e.#..#..",
		"..#..#.....#..#..",
	]},
	# ------------------------------------------------------------ test only (never picked by the game)
	{"name": "everything", "kind": "test", "diff": 1, "rows": [
		".................",
		".#.c.I.o.^.#.c.T.",
		".#.c...o.^.......",
		"........e........",
		".^^..oo...cc.##..",
		".^^..oo.e.cc.##..",
		".................",
	]},
]

const LEGAL := ".#o^cIeT"
## Everything that blocks walking.
const BLOCKERS := "#ocIT"
## What the wide lane must keep clear of (crates can be shot away, so they do not count).
const HARD := "#oIT"
## Door tiles and the tile in front of each: these must stay free.
const KEEP_FREE: Array[Vector2i] = [
	Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 6), Vector2i(8, 5),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(16, 3), Vector2i(15, 3),
]
## The middle of the 3x3 block that must fit in front of each door (top, bottom, left, right).
const DOOR_BLOCKS: Array[Vector2i] = [Vector2i(8, 1), Vector2i(8, 5), Vector2i(1, 3), Vector2i(15, 3)]
const MIN_SPAWN_MARKS := 4
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


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


## True when a 3x3 block centred on tile (x, y) touches nothing hard.
static func _wide(rows: Array, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x > COLS - 2 or y > ROWS - 2:
		return false
	for yy in range(y - 1, y + 2):
		var line := String(rows[yy])
		for xx in range(x - 1, x + 2):
			if HARD.find(line[xx]) >= 0:
				return false
	return true


## A list of what is wrong with a layout (empty = fine).
static func problems(layout: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rows: Array = layout.get("rows", [])
	var title := String(layout.get("name", "?"))
	if rows.size() != ROWS:
		out.append("%s: needs %d rows, has %d" % [title, ROWS, rows.size()])
		return out
	var marks := 0
	for y in ROWS:
		var line := String(rows[y])
		if line.length() != COLS:
			out.append("%s: row %d is %d characters long, needs %d" % [title, y, line.length(), COLS])
			return out
		for x in COLS:
			if LEGAL.find(line[x]) < 0:
				out.append("%s: unknown character '%s' at column %d row %d" % [title, line[x], x, y])
			elif line[x] == "e":
				marks += 1
	if not out.is_empty():
		return out
	if int(layout.get("diff", 0)) < 1 or int(layout.get("diff", 0)) > 3:
		out.append("%s: diff must be 1, 2 or 3" % title)
	for f in layout.get("floors", []):
		if int(f) < 1:
			out.append("%s: floors count from 1" % title)
	# ---- doors and the tile in front of each
	for cell in KEEP_FREE:
		var ch := String(rows[cell.y])[cell.x]
		if ch != "." and ch != "e":
			out.append("%s: tile %s must stay empty (it is a door or the tile in front of one)" % [title, cell])
	# ---- no sealed-off pockets: flood fill from the top door over everything that can be walked on
	var seen := {}
	var todo: Array[Vector2i] = [Vector2i(8, 0)]
	seen[Vector2i(8, 0)] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in NEIGHBOURS:
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
	if layout.get("kind", "") == "test":
		return out
	# ---- the wide lane: a 3x3 block must be able to slide between all four doors
	var start: Vector2i = DOOR_BLOCKS[0]
	if not _wide(rows, start.x, start.y):
		out.append("%s: something solid stands right in front of the top door" % title)
		return out
	var lane := {}
	lane[start] = true
	todo = [start]
	while not todo.is_empty():
		var c2: Vector2i = todo.pop_back()
		for d2: Vector2i in NEIGHBOURS:
			var n2 := c2 + d2
			if lane.has(n2) or not _wide(rows, n2.x, n2.y):
				continue
			lane[n2] = true
			todo.append(n2)
	for door in DOOR_BLOCKS:
		if not lane.has(door):
			out.append("%s: no 3-tile-wide lane reaches the door at %s (rocks, pits, columns or torches are in the way)" % [title, door])
	if layout.get("kind", "") == "combat" and marks < MIN_SPAWN_MARKS:
		out.append("%s: a fight room needs at least %d enemy markers (e), it has %d" % [title, MIN_SPAWN_MARKS, marks])
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
