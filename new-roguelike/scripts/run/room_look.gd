extends Node2D
## RoomLook: how a room LOOKS. The Room (scripts/run/room.gd) owns one of these and hands it all
## the drawing: floor, walls, the four doors in every state, obstacles, wall lights and decoration.
## Nothing here changes how a room plays.
##
## Every picture comes from ONE tile set of the purchased Pixel Crawler art:
##   assets/art/pc_tiles/<crypt|warrens|ashen|pit>/*.png   the pieces (cut by tools/pc_import_tiles.py)
##   assets/art/pc_tiles/tilesets.json                      what each piece is for and where it goes
## The json is read once and every piece is loaded the first time it is needed, then kept.
## tools/pc_preview_room.py draws the same room in Python; ITS DRAW ORDER IS THE REFERENCE:
##   1 floor  2 floor decoration  3 pits and spikes  4 walls  5 doors, wall decoration
##   6 everything that stands, sorted by its feet  7 the bottom wall and "front" door parts
## Which set a floor uses, and what each kind of room adds, is in scripts/data/floors.gd.
##
## The json counts from the top-left corner of the wall frame; the game counts from the top-left
## corner of the FLOOR. So: game x = json x - 16, game y = json y - 48 (the back wall is 48 tall).
##
## Doors, in all four walls (the json holds one list of pieces per wall and state):
##   open     a doorway                              shut     a door leaf (back wall) or bars
##   locked   a door or hatch with a keyhole plate   boss     red door or hatch + a red skull mark
##   hidden   plain wall until a bomb opens it       cracked  the blown-open secret door
## The only door part made by code is the boss mark (the pack has none): _boss_mark() below.

## The most real lights one room may have: the hero's, plus stands, torches and wall lights.
## Every light costs a little on a phone, so wall lights past this number only get a glow.
const MAX_LIGHTS := 6

const TILES_DIR := "res://assets/art/pc_tiles/"

const T := G.TILE
const COLS := G.ROOM_COLS
const ROWS := G.ROOM_ROWS
const W := float(G.ROOM_W)
const H := float(G.ROOM_H)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
const DOOR_COL := G.DOOR_COL
const DOOR_ROW := G.DOOR_ROW
const SIDE := 16.0                     ## width of the side walls
const WALL_KEY := {UP: "n", DOWN: "s", LEFT: "w", RIGHT: "e"}

# the boss mark (the one door part the pack does not have): a small red skull made of squares
const INK := Color("1a1216")
const BOSS_RED := Color("da4e38")
const BOSS_LIGHT := Color("f58a66")
const BOSS_DARK := Color("3a0d16")
## Floor decoration is drawn a little darker than the pack made it, so shots and pickups stand out.
const DECO_DIM := Color(0.84, 0.84, 0.84)

static var _unshaded: CanvasItemMaterial
static var _additive: CanvasItemMaterial
static var _data: Dictionary = {}      ## tilesets.json, read once
static var _tex: Dictionary = {}       ## "crypt/floor_a" -> Texture2D, kept for the whole game
static var _anims: Dictionary = {}     ## "crypt/flame_f0" -> SpriteFrames shared by every flame

var room: Node2D
var run: Node
var theme: Dictionary                  ## the floor's row in scripts/data/floors.gd
var ts: Dictionary                     ## the floor's tile set from tilesets.json
var set_id := "crypt"
var back := 48.0                       ## height of the back wall
var rng := RandomNumberGenerator.new()

var wall_items: Array = []             ## back wall: {piece, pos, flip, frames, fps, light, lamp}
var decals: Array = []                 ## floor: {"tex": Texture2D, "pos": Vector2}
var floor_pick := PackedByteArray()    ## which entry of _floor_tex each floor tile uses
var lights_left := 0

var _floor_tex: Array[Texture2D] = []
var _pits: Dictionary = {}             ## cell index -> Array of Texture2D (one per animation frame)
var _pit_fps := 0.0
var _pit_frame := 0
var _pit_join_tex: Texture2D           ## the one pit picture that joined pits are cut from
var _pit_ops: Dictionary = {}          ## cell index -> Array of [source Rect2, target Rect2]
var _force_door := ""                  ## test flag --doorlook=<state>: every door is drawn in this state
var _spike_tex: Array[Texture2D] = []
var _spike_off: Array[Vector2] = []
var _torch_lights: Array = []          ## [PointLight2D, base energy, base scale, phase]
var _glows: Array = []                 ## [Sprite2D, base scale, phase]
var _was_fighting := false
var _t := 0.0


static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


# =============================================================================== the tile sets
## Everything tilesets.json says (read once; the Android export carries *.json).
static func tilesets() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TILES_DIR + "tilesets.json"))
		if parsed is Dictionary:
			_data = parsed
	return _data


static func tile_set(id: String) -> Dictionary:
	return (tilesets().get("themes", {}) as Dictionary).get(id, {})


static func has_piece(id: String, piece_name: String) -> bool:
	return (tile_set(id).get("pieces", {}) as Dictionary).has(piece_name)


## One picture of a tile set, loaded the first time it is asked for.
static func piece(id: String, piece_name: String) -> Texture2D:
	var key := id + "/" + piece_name
	var tex: Texture2D = _tex.get(key)
	if tex == null:
		tex = load(TILES_DIR + key + ".png")
		_tex[key] = tex
	return tex


## The frames of an animated piece as one shared SpriteFrames.
static func anim(id: String, names: Array, fps: float) -> SpriteFrames:
	var key := id + "/" + String(names[0])
	if _anims.has(key):
		return _anims[key]
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	for n in names:
		frames.add_frame("default", piece(id, String(n)))
	_anims[key] = frames
	return frames


# =============================================================================== deciding the look
## Decides everything from the room's seed, so a room looks the same every time you come back.
func roll(the_room: Node2D) -> void:
	room = the_room
	run = room.run
	theme = room.theme
	set_id = String(theme.get("tiles", "crypt"))
	ts = tile_set(set_id)
	back = float(ts.get("back_wall_h", 48))
	rng.seed = int(room.rs["seed"]) + 101
	_force_door = G.arg("doorlook")
	# how many lights are left for the wall after the hero's, the stands' and the floor torches'
	var stands := 0
	match room.type:
		G.RoomType.SHOP: stands = 4
		G.RoomType.TREASURE, G.RoomType.SECRET, G.RoomType.BOSS: stands = 1
	lights_left = MAX_LIGHTS - 1 - stands if run.LIGHTING else 0
	lights_left -= room.torch_cells.size()
	_roll_floor()
	_roll_flat()
	_roll_walls()
	_roll_floor_bits()


func _kind() -> String:
	match room.type:
		G.RoomType.START: return "start"
		G.RoomType.SHOP: return "shop"
		G.RoomType.TREASURE: return "treasure"
		G.RoomType.SECRET: return "secret"
		G.RoomType.BOSS: return "boss"
	return "fight"


func _pick(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0.0:
			return i
	return weights.size() - 1


## How many of something a room gets: `key` is a [fewest, most] pair in the floor's row.
func _count(key: String, kind: String) -> int:
	var span: Array = theme.get(key, [0, 0])
	var lo := int(span[0])
	var hi := int(span[1])
	match kind:
		"fight": return rng.randi_range(lo, hi)
		"secret": return hi
		"boss", "start": return lo
	return 0


func _roll_floor() -> void:
	var fl: Dictionary = ts["floor"]
	var variants: Array = fl["variants"]
	var weights := PackedFloat32Array()
	for v: Array in variants:
		_floor_tex.append(piece(set_id, String(v[0])))
		weights.append(float(v[1]))
	# the tiles in the shadow of the back wall and of the left wall
	var shade := {}
	for key: String in ["shade_top", "shade_left", "shade_corner"]:
		if fl.has(key):
			shade[key] = _floor_tex.size()
			_floor_tex.append(piece(set_id, String(fl[key])))
	floor_pick.resize(COLS * ROWS)
	for i in COLS * ROWS:
		var k := _pick(weights)
		if i < COLS and shade.has("shade_top"):
			k = shade["shade_corner"] if i == 0 and shade.has("shade_corner") else shade["shade_top"]
		elif i % COLS == 0 and shade.has("shade_left"):
			k = shade["shade_left"]
		floor_pick[i] = k


func _is_pit(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < COLS and y < ROWS and room.grid[y * COLS + x] == room.PIT


## True when this pit tile is part of a 2 x 2 (or bigger) block of pits: those merge into one pool.
func _in_pool(x: int, y: int) -> bool:
	if not _is_pit(x, y):
		return false
	for oy: int in [-1, 0]:
		for ox: int in [-1, 0]:
			if _is_pit(x + ox, y + oy) and _is_pit(x + ox + 1, y + oy) and _is_pit(x + ox, y + oy + 1) and _is_pit(x + ox + 1, y + oy + 1):
				return true
	return false


## Pits and spikes lie flat on the floor: remember their pictures so drawing them is cheap.
func _roll_flat() -> void:
	var obstacles: Dictionary = ts["obstacles"]
	var spikes: Dictionary = obstacles["spikes"]
	for f: Dictionary in spikes["frames"]:
		_spike_tex.append(piece(set_id, String(f["piece"])))
		_spike_off.append(Vector2(float(f["dx"]), float(f["dy"])))
	var pit: Dictionary = obstacles["pit"]
	var frames: Array = pit.get("frames", pit.get("variants", []))
	var animated := pit.has("frames")
	_pit_fps = float(pit.get("fps", 4.0)) if animated else 0.0
	var pools := pit.has("autotile9")
	var join := bool(theme.get("pit_join", false)) and not animated and not pools
	if join:
		_pit_join_tex = piece(set_id, String(frames[0]["piece"]))
	for i: int in room.grid.size():
		if room.grid[i] != room.PIT:
			continue
		var x := i % COLS
		var y := i / COLS
		if join:
			_pit_ops[i] = _joined_pit(x, y)
			continue
		var list: Array = []
		if pools and _in_pool(x, y):
			# one of the nine pool tiles: which edges of the pool this tile is on
			var left := _in_pool(x - 1, y)
			var right := _in_pool(x + 1, y)
			var row := "" if _in_pool(x, y - 1) and _in_pool(x, y + 1) else ("t" if _in_pool(x, y + 1) else "b")
			var col := "c" if left and right else ("l" if right else "r")
			var part := row + col if col != "c" else ("c" if row == "" else row)
			for f in frames.size():
				list.append(piece(set_id, "pit9_%s_f%d" % [part, f]))
		elif animated:
			for f: Dictionary in frames:
				list.append(piece(set_id, String(f["piece"])))
		else:
			list.append(piece(set_id, String(frames[(x + y) % frames.size()]["piece"])))
		_pits[i] = list


## A pit picture that is one stone-rimmed hole per tile (the Pit's shaft) would turn a block of pits
## into a grid of little squares. So touching pits are joined into one big shaft, cut from that same
## picture a quarter at a time: a corner quarter stays as it is, a quarter on a straight side is one
## line of the rim stretched along it, a quarter in the middle is the dark of the hole.
## Needs a 16 x 16 picture with a rim at most 4 px wide (floors.gd "pit_join").
func _joined_pit(x: int, y: int) -> Array:
	var ops: Array = []
	var at := Vector2(x * T, y * T)
	for sy: int in [-1, 1]:
		for sx: int in [-1, 1]:
			var qx := 0.0 if sx < 0 else 8.0
			var qy := 0.0 if sy < 0 else 8.0
			var ix := 7.0 if sx < 0 else 8.0     # the line of pixels next to the middle of the tile
			var iy := 7.0 if sy < 0 else 8.0
			var side := _is_pit(x + sx, y)
			var updown := _is_pit(x, y + sy)
			var target := Rect2(at + Vector2(qx, qy), Vector2(8, 8))
			if not side and not updown:
				ops.append([Rect2(qx, qy, 8, 8), target])
			elif side and not updown:
				ops.append([Rect2(ix, qy, 1, 8), target])
			elif updown and not side:
				ops.append([Rect2(qx, iy, 8, 1), target])
			else:
				ops.append([Rect2(ix, iy, 1, 1), target])
				if not _is_pit(x + sx, y + sy):
					# the floor pokes into the shaft here: the rim turns round its corner
					# (rim colours, outermost first, are the first pixels of the picture's middle row)
					for r: Array in [[2, 0, 0, 4, 4], [1, 0, 1, 2, 1], [1, 1, 0, 1, 1], [0, 0, 0, 1, 1]]:
						ops.append([Rect2(float(r[0]), 7, 1, 1), _from_corner(at, sx, sy, r[1], r[2], r[3], r[4])])
					if sy < 0:
						# and throws the same shadow into the hole as the rest of the far rim
						ops.append([Rect2(7, 5, 1, 1), _from_corner(at, sx, sy, 0, 4, 4, 3)])
	return ops


## A small rectangle counted from one corner of a tile (sx, sy = which corner) in room pixels.
func _from_corner(at: Vector2, sx: int, sy: int, i: int, j: int, w: int, h: int) -> Rect2:
	return Rect2(at.x + (i if sx < 0 else T - i - w), at.y + (j if sy < 0 else T - j - h), w, h)


func _wall_item(piece_name: String, x: float, y: float, d: Dictionary = {}) -> Dictionary:
	return {"piece": piece_name, "pos": Vector2(x, y - back), "flip": bool(d.get("flip", false)),
		"frames": int(d.get("frames", 0)), "fps": float(d.get("fps", 8.0)),
		"light": d.get("light", {}), "lamp": d.has("columns")}


func _roll_walls() -> void:
	var kind := _kind()
	var wd: Dictionary = ts["wall_deco"]
	var pieces: Array = wd["pieces"]
	var used := {}                     # floor column -> true: a door or a decoration is there
	if room.door_exists(UP):
		for c in wd["keep_clear"]:
			used[int(c)] = true
		if room.rs["doors"][UP]["boss"]:
			for c in range(5, 12):         # the boss door brings banners or lamps of its own
				used[c] = true
	# 1. what this kind of room stands against or hangs on its wall (floors.gd "dress")
	for row: Dictionary in (theme.get("dress", {}) as Dictionary).get(kind, []):
		var pname := String(row["piece"])
		var tex := piece(set_id, pname)
		var x := float(int(row["col"]) * T) + float(row.get("dx", 0))
		var y := float(row["y"])
		var first := int(floorf((x + 2.0) / T))
		var last := int(floorf((x + tex.get_width() - 3.0) / T))
		var free := true
		for c in range(first, last + 1):
			# not over a door, and not standing in a rock or a pit at the foot of the wall
			if used.has(c) or (y + tex.get_height() > back and c >= 0 and c < COLS and room.grid[c] != room.EMPTY):
				free = false
		if not free:
			continue
		for c in range(first, last + 1):
			used[c] = true
		var item := _wall_item(pname, x, y, row)
		for d: Dictionary in pieces:      # a lit window keeps its light wherever it hangs
			if String(d["piece"]) == pname and d.has("light"):
				item["light"] = d["light"]
		wall_items.append(item)
	# 2. the wall lights, at the columns the set gives them, in matching pairs
	var pairs := 2
	if kind == "secret":
		pairs = 0                      # a secret room is dark
	elif kind == "fight":
		var span: Array = theme.get("wall_lights", [1, 2])
		pairs = rng.randi_range(int(span[0]), int(span[1]))
	var inner_first := rng.randf() < 0.5
	for d: Dictionary in pieces:
		if not d.has("columns"):
			continue
		var cols: Array = d["columns"]
		var half := cols.size() / 2
		for k in mini(pairs, half):
			var p := (half - 1 - k) if inner_first else k
			for c: int in [int(cols[p]), int(cols[cols.size() - 1 - p])]:
				if not used.has(c):
					used[c] = true
					wall_items.append(_wall_item(String(d["piece"]), c * T + float(d["dx"]), float(d["y"]), d))
	# 3. loose decoration, picked by the set's weights
	var loose: Array = []
	var weights := PackedFloat32Array()
	for d: Dictionary in pieces:
		if not d.has("columns") and float(d.get("weight", 0)) > 0.0:
			loose.append(d)
			weights.append(float(d["weight"]))
	var free_cols: Array[int] = []
	for c in range(1, COLS - 1):
		if not used.has(c):
			free_cols.append(c)
	var want := 1 if kind == "shop" or kind == "treasure" else _count("wall_deco", kind)
	for k in want:
		if loose.is_empty() or free_cols.is_empty():
			break
		var d: Dictionary = loose[_pick(weights)]
		var at := rng.randi() % free_cols.size()
		var c: int = free_cols[at]
		free_cols.remove_at(at)
		wall_items.append(_wall_item(String(d["piece"]), c * T + float(d["dx"]), float(d["y"]), d))


## Small dim things lying on the floor. Never on an obstacle, never in the middle of a secret room
## (its chest and stand are there), none at all where things are sold or given.
func _roll_floor_bits() -> void:
	var kind := _kind()
	var want := 1 if kind == "start" else _count("floor_deco", kind)
	var skip: Array = theme.get("no_floor_deco", [])
	var list: Array = []
	var weights := PackedFloat32Array()
	for d: Dictionary in ts.get("floor_deco", []):
		if not skip.has(d["piece"]):
			list.append(d)
			weights.append(float(d.get("weight", 1)))
	if want <= 0 or list.is_empty():
		return
	var free: Array[int] = []
	for i: int in room.grid.size():
		var x := i % COLS
		var y := i / COLS
		if room.grid[i] != room.EMPTY or (kind == "secret" and absi(x - DOOR_COL) <= 3 and absi(y - DOOR_ROW) <= 1):
			continue
		free.append(i)
	for k in want:
		if free.is_empty():
			break
		var d: Dictionary = list[_pick(weights)]
		var at := rng.randi() % free.size()
		var cell := free[at]
		free.remove_at(at)
		var tex := piece(set_id, String(d["piece"]))
		var pos := Vector2((cell % COLS) * T, (cell / COLS) * T)
		if not bool(d.get("tile", false)):
			pos += Vector2(rng.randi() % (T + 1 - tex.get_width()), rng.randi() % (T + 1 - tex.get_height()))
		decals.append({"tex": tex, "pos": pos})


# =============================================================================== nodes: wall lights, glows
## Builds everything on the wall that moves or glows. Called once, after the room's own nodes exist.
func build() -> void:
	var lamps: Array = []              # [position, colour, radius] of every lit wall light
	for item: Dictionary in wall_items:
		var pos: Vector2 = item["pos"]
		if int(item["frames"]) > 0:
			var names: Array = []
			for f in int(item["frames"]):
				names.append("%s_f%d" % [item["piece"], f])
			var s := AnimatedSprite2D.new()
			s.sprite_frames = anim(set_id, names, float(item["fps"]))
			s.centered = false
			s.position = pos
			s.z_index = -8
			s.speed_scale = rng.randf_range(0.9, 1.1)
			add_child(s)
			s.play("default")
			s.frame = rng.randi() % names.size()
		var light: Dictionary = item["light"]
		if light.is_empty():
			continue
		var at := pos + Vector2(float(light["lx"]), float(light["ly"]))
		var colour := Color(String(light["color"]))
		var radius := float(light["radius"])
		_add_glow(self, at, colour, radius / 64.0 * 0.6, 0.30, true).z_index = -8
		if bool(item["lamp"]):
			lamps.append([at, colour, radius])
	# one real light per wall light while the room can afford it; otherwise they share one
	var power := float(theme.get("torch_power", 1.0))
	if not lamps.is_empty() and lights_left >= lamps.size():
		for l: Array in lamps:
			_add_light(l[0] + Vector2(0, 6), l[1], 0.85 * power, float(l[2]) / 32.0, true)
	elif not lamps.is_empty() and lights_left >= 1:
		var mid := Vector2.ZERO
		for l: Array in lamps:
			mid += l[0]
		_add_light(mid / float(lamps.size()) + Vector2(0, 10), lamps[0][1], 0.8 * power, 3.4, true)
	# pits that glow (lava): a faint still glow each, no real light
	var pit: Dictionary = ts["obstacles"]["pit"]
	if pit.has("light"):
		var pl: Dictionary = pit["light"]
		for i: int in _pits:
			var at2 := Vector2((i % COLS) * T + float(pl["lx"]), (i / COLS) * T + float(pl["ly"]))
			_add_glow(self, at2, Color(String(pl["color"])), float(pl["radius"]) / 64.0 * 1.2, 0.13, false).z_index = -8
	_was_fighting = room.fighting
	if run.fx.has_method("set_atmosphere"):
		run.fx.set_atmosphere(theme, room.type)
	set_process(not _torch_lights.is_empty() or not _glows.is_empty() or (_pit_fps > 0.0 and not _pits.is_empty()))


func _add_light(at: Vector2, colour: Color, energy: float, light_scale: float, flicker: bool, parent: Node2D = null) -> void:
	if not run.LIGHTING or lights_left <= 0:
		return
	lights_left -= 1
	var light := PointLight2D.new()
	light.texture = run.light_tex
	light.texture_scale = light_scale
	light.energy = energy
	light.color = colour
	light.position = at
	if parent == null:
		add_child(light)
	else:
		parent.add_child(light)
	if flicker:
		_torch_lights.append([light, energy, light_scale, rng.randf() * 20.0])


## The soft bloom around a flame (an additive sprite: far cheaper than a real light).
func _add_glow(parent: Node2D, at: Vector2, colour: Color, glow_scale: float, alpha: float, flicker: bool) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = run.light_tex
	glow.material = additive()
	glow.modulate = Color(colour.r, colour.g, colour.b, alpha)
	glow.scale = Vector2(glow_scale, glow_scale)
	glow.position = at
	parent.add_child(glow)
	if flicker:
		_glows.append([glow, glow_scale, rng.randf() * 20.0])
	return glow


## The picture of something that stands on a floor tile: "rock", "crate", "pillar" or "torch"
## (the set decides what those are: tombstones, urns, statues...). `node` is the obstacle's own
## y-sorted node; it sits at the tile's bottom edge, so tall pieces overlap whatever is behind them.
func build_obstacle(node: Node2D, kind: String, cx: int, cy: int) -> void:
	var ob: Dictionary = ts["obstacles"][kind]
	var variants: Array = ob["variants"]
	# Which of the set's pictures this tile gets: a real mix from the room's seed (not a stripe
	# pattern, which gave a row of pillars the same picture), the same every visit, and mirrored
	# left to right so a hall of columns or statues still looks built on purpose.
	var mirror_x := mini(cx, COLS - 1 - cx)
	var v: Dictionary = variants[posmod(hash(Vector3i(int(room.rs["seed"]) & 0xFFFFFF, mirror_x, cy * 8 + kind.length())), variants.size())]
	var corner := Vector2(-8, -15)     # the tile's top-left corner, seen from the node
	var s := Sprite2D.new()
	s.texture = piece(set_id, String(v["piece"]))
	s.centered = false
	s.position = corner + Vector2(float(v["dx"]), float(v["dy"]))
	node.add_child(s)
	if ob.has("flame"):
		var fl: Dictionary = ob["flame"]
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = anim(set_id, fl["frames"], float(fl.get("fps", 8)))
		flame.centered = false
		flame.position = corner + Vector2(float(fl["dx"]), float(fl["dy"]))
		flame.material = unshaded()
		node.add_child(flame)
		flame.play("default")
		flame.frame = rng.randi() % (fl["frames"] as Array).size()
	if ob.has("light"):
		var light: Dictionary = ob["light"]
		var at := corner + Vector2(float(light["lx"]), float(light["ly"]))
		var colour := Color(String(light["color"]))
		_add_glow(node, at, colour, float(light["radius"]) / 64.0 * 0.7, 0.30, true)
		if run.LIGHTING:
			# floor torches were counted before the wall was rolled, so they always get their light
			lights_left += 1
			_add_light(at + Vector2(0, 7), colour, 0.9 * float(theme.get("torch_power", 1.0)), float(light["radius"]) / 32.0 * 1.25, true, node)
		set_process(true)


## Colours of the bits that fly off a broken "rock" or "crate".
func debris(kind: String) -> Array:
	return (theme.get("debris", {}) as Dictionary).get(kind, [Color(0.5, 0.46, 0.42), Color(0.3, 0.28, 0.27)])


func _process(delta: float) -> void:
	_t += delta
	for l: Array in _torch_lights:
		var light: PointLight2D = l[0]
		if not is_instance_valid(light):
			continue
		var p: float = l[3]
		var k := 1.0 + 0.055 * sin(_t * 11.0 + p) + 0.045 * sin(_t * 23.7 + p * 1.7) + 0.03 * sin(_t * 5.1 + p * 0.6)
		light.energy = float(l[1]) * k
		light.texture_scale = float(l[2]) * (0.985 + 0.03 * k)
	for g: Array in _glows:
		var glow: Sprite2D = g[0]
		if not is_instance_valid(glow):
			continue
		var p2: float = g[2]
		var s := float(g[1]) * (1.0 + 0.08 * sin(_t * 9.0 + p2) + 0.05 * sin(_t * 17.3 + p2))
		glow.scale = Vector2(s, s)
	if _pit_fps > 0.0 and not _pits.is_empty():
		var frame := int(_t * _pit_fps)
		if frame != _pit_frame:
			_pit_frame = frame
			room.spikes_node.queue_redraw()


# =============================================================================== door states
func _locked(dir: Vector2i) -> bool:
	return room.rs["doors"][dir]["locked"] and room.type != G.RoomType.TREASURE


## Which of the json's door states this wall shows right now ("" = no door at all).
func door_state(dir: Vector2i) -> String:
	if _force_door != "":
		return _force_door                 # test flag: all four walls show a door in this state
	if not room.door_exists(dir):
		return ""
	var door: Dictionary = room.rs["doors"][dir]
	if door["hidden"]:
		return "cracked" if door["revealed"] else "hidden"
	if door["boss"]:
		# the red door stays shut (you walk in through it) until its boss is dead
		return "boss_open" if run.rooms[door["to"]].get("cleared", false) else "boss"
	if _locked(dir):
		return "locked"
	return "shut" if room.fighting else "open"


## The top-left corner of the door's tile in the wall frame (the json's "door cell").
func _door_cell(dir: Vector2i) -> Vector2:
	if dir == UP:
		return Vector2(DOOR_COL * T, -back)
	if dir == DOWN:
		return Vector2(DOOR_COL * T, H)
	if dir == LEFT:
		return Vector2(-SIDE, DOOR_ROW * T)
	return Vector2(W, DOOR_ROW * T)


## The wall-strip tiles a side or bottom door replaces (their top-left corners).
func _gap(dir: Vector2i) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var state := door_state(dir)
	if state == "":
		return out
	var at := _door_cell(dir)
	for g: Array in ts["doors"][WALL_KEY[dir]][state]["gap"]:
		out.append(at + Vector2(float(g[0]) * T, float(g[1]) * T))
	return out


## Draws one door's pieces: those behind the characters (front = false) or those in front.
func _draw_door(c: Node2D, dir: Vector2i, front: bool) -> void:
	var state := door_state(dir)
	if state == "":
		return
	var at := _door_cell(dir)
	for op: Dictionary in ts["doors"][WALL_KEY[dir]][state]["ops"]:
		if bool(op.get("front", false)) != front or not op.has("piece"):
			continue
		var pos := at + Vector2(float(op["dx"]), float(op["dy"]))
		c.draw_texture(piece(set_id, String(op["piece"])), pos)
		if state == "cracked" and dir == UP and not room.fighting:
			# a blown-open secret door in the back wall: the opening is dark while you can walk in
			var dark := Color(String(ts.get("void_color", "#000000"))).darkened(0.4)
			for r: Rect2 in theme.get("secret_hole", []):
				c.draw_rect(Rect2(pos + r.position, r.size), dark)
	# a blown-open door in a side or bottom wall gets the pack's bars across it during a fight
	if state == "cracked" and dir != UP and room.fighting and front == (dir == DOWN):
		c.draw_texture(piece(set_id, "door_bars"), at)


## Also the place where a fight starting or ending is noticed: dust puffs out of every doorway.
func refresh_door_art() -> void:
	if room.fighting != _was_fighting:
		_was_fighting = room.fighting
		_door_dust(room.fighting)


func _door_dust(slam: bool) -> void:
	if not run.fx.has_method("dust"):
		return
	for dir: Vector2i in room.rs["doors"]:
		if not room.door_visible(dir):
			continue
		var at: Vector2 = room.door_pos(dir) - Vector2(dir) * 5.0
		run.fx.dust(at, -Vector2(dir), 1.0 if slam else 0.6)


# =============================================================================== drawing: floor and walls
## Everything under the characters: floor, floor decoration, back wall, side walls, the door
## pieces that are not marked "front", wall decoration.
func draw_tiles(c: Node2D) -> void:
	# the dark outside the room; wall pieces are see-through where the wall mass shows it
	c.draw_rect(Rect2(-240, -back - 120, W + 480, back + H + 260), Color(String(ts.get("void_color", "#000000"))))
	# floor, one picture at a time so the renderer can batch the tiles
	for k in _floor_tex.size():
		var tex := _floor_tex[k]
		for i in COLS * ROWS:
			if floor_pick[i] == k:
				c.draw_texture(tex, Vector2((i % COLS) * T, (i / COLS) * T))
	for d: Dictionary in decals:
		c.draw_texture(d["tex"], d["pos"], DECO_DIM)
	# walls: the rows of the back wall, then the side strips and the top corners
	var walls: Dictionary = ts["walls"]
	for row: Dictionary in walls["back_rows"]:
		var names: Array = row["repeat"]
		var y := float(row["y"]) - back
		for x in COLS:
			var pname := String(names[x % names.size()])
			if x == 0:
				pname = String(row.get("first", pname))
			elif x == COLS - 1:
				pname = String(row.get("last", pname))
			c.draw_texture(piece(set_id, pname), Vector2(x * T, y))
	var skip_left := _gap(LEFT)
	var skip_right := _gap(RIGHT)
	var left: Array = walls["left"]
	var right: Array = walls["right"]
	var n := 0
	var sy := T - back
	while sy < H:
		if not skip_left.has(Vector2(-SIDE, sy)):
			c.draw_texture(piece(set_id, String(left[n % left.size()])), Vector2(-SIDE, sy))
		if not skip_right.has(Vector2(W, sy)):
			c.draw_texture(piece(set_id, String(right[n % right.size()])), Vector2(W, sy))
		sy += T
		n += 1
	c.draw_texture(piece(set_id, String(walls["corner_tl"])), Vector2(-SIDE, -back))
	c.draw_texture(piece(set_id, String(walls["corner_tr"])), Vector2(W, -back))
	# doors, then what hangs on the wall (animated pieces are sprites, see build())
	for dir: Vector2i in [UP, LEFT, RIGHT, DOWN]:
		_draw_door(c, dir, false)
	for item: Dictionary in wall_items:
		if int(item["frames"]) > 0:
			continue
		var tex2 := piece(set_id, String(item["piece"]))
		if bool(item["flip"]):
			c.draw_texture_rect(tex2, Rect2(item["pos"], Vector2(-tex2.get_width(), tex2.get_height())), false)
		else:
			c.draw_texture(tex2, item["pos"])


## Pits and spikes: flat on the floor, under everything that stands. `spike_frame` is the Room's
## spike rhythm: 0 down (safe), 1 tips showing (warning), 2 and 3 up.
func draw_flat(c: Node2D, spike_frame: int) -> void:
	var depth := float(theme.get("pit_depth", 0.0))
	for i: int in _pit_ops:
		for op: Array in _pit_ops[i]:
			c.draw_texture_rect_region(_pit_join_tex, op[1], op[0])
	for i: int in _pits:
		var frames: Array = _pits[i]
		var pos := Vector2((i % COLS) * T, (i / COLS) * T)
		c.draw_texture(frames[_pit_frame % frames.size()], pos)
		if depth > 0.0 and not _is_pit(i % COLS, i / COLS - 1):
			# the far wall of the shaft, in shadow
			c.draw_rect(Rect2(pos.x, pos.y, T, 3), Color(0, 0, 0, depth))
			c.draw_rect(Rect2(pos.x, pos.y + 3, T, 2), Color(0, 0, 0, depth * 0.45))
	if not room.has_spikes:
		return
	var f := mini(spike_frame, _spike_tex.size() - 1)
	for i: int in room.grid.size():
		if room.grid[i] == room.SPIKES:
			c.draw_texture(_spike_tex[f], Vector2((i % COLS) * T, (i / COLS) * T) + _spike_off[f])


# =============================================================================== drawing: in front of the characters
## The bottom wall and the door pieces marked "front": they hide the feet of whoever stands behind.
func draw_front(c: Node2D) -> void:
	var walls: Dictionary = ts["walls"]
	var bottom: Array = walls["bottom"]
	var skip := _gap(DOWN)
	for x in COLS:
		if not skip.has(Vector2(x * T, H)):
			c.draw_texture(piece(set_id, String(bottom[x % bottom.size()])), Vector2(x * T, H))
	c.draw_texture(piece(set_id, String(walls["corner_bl"])), Vector2(-SIDE, H))
	c.draw_texture(piece(set_id, String(walls["corner_br"])), Vector2(W, H))
	for dir: Vector2i in [UP, DOWN, LEFT, RIGHT]:
		_draw_door(c, dir, true)


## Door parts made by code, above everything: the boss mark, where the json says "code".
func draw_doors(c: Node2D) -> void:
	for dir: Vector2i in [UP, DOWN, LEFT, RIGHT]:
		var state := door_state(dir)
		if state != "boss":
			continue
		var at := _door_cell(dir)
		for op: Dictionary in ts["doors"][WALL_KEY[dir]][state]["ops"]:
			if op.has("code"):
				var p := at + Vector2(float(op["dx"]), float(op["dy"]))
				p.y = maxf(p.y, 5.0 - back)      # keep the mark inside the wall, on the screen
				_boss_mark(c, p)


## The mark of a boss door: a red skull, 9 x 9 px, made of plain squares (the pack has no emblem).
func _boss_mark(c: Node2D, mid: Vector2) -> void:
	var x := floorf(mid.x) - 4.0
	var y := floorf(mid.y) - 4.0
	c.draw_rect(Rect2(x + 1, y, 7, 1), INK)
	c.draw_rect(Rect2(x, y + 1, 9, 5), INK)
	c.draw_rect(Rect2(x + 1, y + 6, 7, 2), INK)
	c.draw_rect(Rect2(x + 2, y + 8, 5, 1), INK)
	c.draw_rect(Rect2(x + 1, y + 1, 7, 5), BOSS_RED)
	c.draw_rect(Rect2(x + 2, y + 6, 5, 2), BOSS_RED)
	c.draw_rect(Rect2(x + 2, y + 1, 5, 1), BOSS_LIGHT)
	c.draw_rect(Rect2(x + 2, y + 3, 2, 2), BOSS_DARK)
	c.draw_rect(Rect2(x + 5, y + 3, 2, 2), BOSS_DARK)
	c.draw_rect(Rect2(x + 4, y + 5, 1, 1), BOSS_DARK)
	c.draw_rect(Rect2(x + 3, y + 7, 1, 1), BOSS_DARK)
	c.draw_rect(Rect2(x + 5, y + 7, 1, 1), BOSS_DARK)
