extends Node2D
## RoomLook: how a room LOOKS. The Room (scripts/run/room.gd) owns one of these and hands it all
## the drawing: floor, walls, the four doors in every state, torches and their lights, wall and
## floor decoration. Nothing here changes how a room plays, with one exception: a fountain or a
## pile of bags at the foot of the back wall adds a small solid rectangle so nobody walks through it.
##
## What a floor looks like (tints, torch colour, how much moss or how many skulls) comes from
## scripts/data/floors.gd. What a room TYPE gets (shop carpet, boss banners) is in roll() below.
##
## Doors, in all four walls, read the same way:
##   open     a dark doorway in a stone frame          shut    the same frame with a wooden door in it
##   locked   a shut door with a golden keyhole plate   boss    red wood, skulls beside or above it
##   hidden   plain wall until a bomb opens it          cracked a blown-open hole (iron bars in a fight)
##
## To add a wall decoration: give it a kind name, roll it in _roll_walls() and draw it in
## _draw_back_wall() (a still) or build() (anything animated or lit).
## To add a floor decoration: append to `decals` in _roll_floor_bits(). Keep them dim: the floor
## must stay readable (never use pale gold rings or pale stripes; those belong to the Curse).

const EnemyScript = preload("res://scripts/entities/enemy.gd")

## The most real lights one room may have: the hero's, plus stands, fountains and torches.
## Every light costs a little on a phone, so torches past this number only get a glow.
const MAX_LIGHTS := 6

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

# colours taken from the tile pack, so code-drawn door parts sit in the same palette
const INK := Color("222222")
const STONE := Color("aa8d7a")
const STONE_HI := Color("d3bfa9")
const BRICK := Color("775c55")
const BRICK_DARK := Color("483b3a")
const WOOD := Color("8f4029")
const WOOD_DARK := Color("62232f")
const STUD := Color("72d6ce")
const VOID := Color("0e0c0c")
const GOLD := Color("facb3e")
const GOLD_DARK := Color("ee8e2e")
const BOSS_RED := Color("da4e38")
const IRON_DARK := Color(0.15, 0.15, 0.19)
const IRON_LIGHT := Color(0.46, 0.48, 0.56)

const TINT_BOSS := Color(1.25, 0.55, 0.55)
const TINT_LOCKED := Color(1.25, 1.05, 0.55)

## How deep (px) the doorway of a side door is, measured outward from the edge of the floor.
const SIDE_DEPTH := 12.0
## Where the wall torch picture sits above the floor line, and where its flame is.
const TORCH_Y := -25.0
const FLAME_Y := -13.0

static var _unshaded: CanvasItemMaterial
static var _additive: CanvasItemMaterial

var room: Node2D
var run: Node
var theme: Dictionary
var rng := RandomNumberGenerator.new()

var wall_items: Array = []             ## back wall: {"col": int, "kind": String}
var decals: Array = []                 ## floor: {"tex": Texture2D, "pos": Vector2, "mod": Color}
var carpet_id := ""
var carpet := Rect2i()                 ## in tiles
var floor_variant := PackedByteArray() ## which floor picture each tile uses (1-8, 9 = sprouts)
var floor_shade := PackedByteArray()   ## brightness of each tile, 0-255
var lights_left := 0

var _floor_tex: Array[Texture2D] = []
var _torch_lights: Array = []          ## [PointLight2D, base energy, base scale, phase]
var _glows: Array = []                 ## [Sprite2D, base scale, phase]
var _top_leaf: Sprite2D
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


# =============================================================================== deciding the look
## Decides everything from the room's seed, so a room looks the same every time you come back.
func roll(the_room: Node2D) -> void:
	room = the_room
	run = room.run
	theme = room.theme
	rng.seed = int(room.rs["seed"]) + 101
	for k in range(1, 9):
		_floor_tex.append(Art.tex("floor_%d" % k))
	_floor_tex.append(Art.tex("niji_floor_plants") if Art.has("niji_floor_plants") else _floor_tex[0])
	# how many lights are left for torches and fountains after the hero's and the stands'
	var stands := 0
	match room.type:
		G.RoomType.SHOP: stands = 4
		G.RoomType.TREASURE, G.RoomType.SECRET, G.RoomType.BOSS: stands = 1
	lights_left = MAX_LIGHTS - 1 - stands if run.LIGHTING else 0
	for i in room.torch_cells.size():
		lights_left -= 1
	_roll_floor()
	_roll_walls()
	_roll_floor_bits()


func _roll_floor() -> void:
	var cracks := float(theme.get("cracks", 0.2))
	var moss := int((theme.get("floor_bits", {}) as Dictionary).get("moss", 0))
	floor_variant.resize(COLS * ROWS)
	floor_shade.resize(COLS * ROWS)
	for i in COLS * ROWS:
		floor_variant[i] = 1 if rng.randf() >= cracks else 2 + rng.randi() % 7
		floor_shade[i] = 232 + rng.randi() % 24
	for k in moss:
		floor_variant[rng.randi() % (COLS * ROWS)] = 9
	match room.type:
		G.RoomType.SHOP:
			carpet_id = "niji_carpet_red"
			carpet = Rect2i(3, 2, 11, 2)
		G.RoomType.TREASURE:
			carpet_id = "niji_carpet_red"
			carpet = Rect2i(5, 2, 7, 3)
		G.RoomType.START:
			carpet_id = "niji_carpet_grey"
			carpet = Rect2i(6, 2, 5, 3)
	if carpet_id != "" and not Art.has(carpet_id + "_tl"):
		carpet_id = ""


func _free_cols() -> Array[int]:
	var out: Array[int] = []
	for c in range(1, COLS - 1):
		if room.door_exists(UP) and c >= 6 and c <= 10:
			continue
		out.append(c)
	return out


func _add_wall(col: int, kind: String, used: Dictionary) -> bool:
	if col < 0 or col >= COLS or used.has(col) or (room.door_exists(UP) and col >= 6 and col <= 10):
		return false
	# fountains and bags stand on the floor in front of the wall: not where an obstacle already is
	if (kind.begins_with("fountain") or kind == "bags") and room.grid[col] != room.EMPTY:
		return false
	used[col] = true
	wall_items.append({"col": col, "kind": kind})
	return true


func _roll_walls() -> void:
	var used := {}
	var banners: Array = theme.get("banners", ["wall_banner_red"])
	var bits: Dictionary = theme.get("wall_bits", {})
	var fountain := "fountain:" + String(theme.get("fountain", "blue"))
	if rng.randf() < 0.3:
		fountain = "fountain:red" if fountain.ends_with("blue") else "fountain:blue"
	match room.type:
		G.RoomType.SHOP:
			for c: int in [4, 12]:
				_add_wall(c, "torch", used)
			for c: int in [2, 14]:
				_add_wall(c, "banner:wall_banner_yellow", used)
			_add_wall(11, "sign", used)
			_add_wall(5, "bags", used)
		G.RoomType.TREASURE:
			for c: int in [4, 12]:
				_add_wall(c, "fountain:blue", used)
			for c: int in [2, 14]:
				_add_wall(c, "torch", used)
		G.RoomType.BOSS:
			for c: int in [3, 13]:
				_add_wall(c, "torch", used)
			for c: int in [2, 4, 12, 14]:
				_add_wall(c, "banner:wall_banner_red", used)
		G.RoomType.SECRET:
			for c: int in [4, 12]:
				_add_wall(c, "torch_unlit", used)
			_add_wall([2, 3, 13, 14][rng.randi() % 4], "goo", used)
			_add_wall([6, 7, 9, 10][rng.randi() % 4], "hole:%d" % (1 + rng.randi() % 2), used)
		_:
			# torches first: a matching pair, sometimes two pairs
			var pair: int = [2, 3, 4, 5][rng.randi() % 4]
			_add_wall(pair, "torch", used)
			_add_wall(16 - pair, "torch", used)
			if rng.randf() < float(bits.get("banners", 0.5)):
				var c: int = [2, 3, 4, 5][rng.randi() % 4]
				var b := "banner:" + String(banners[rng.randi() % banners.size()])
				if not used.has(c) and not used.has(16 - c):
					_add_wall(c, b, used)
					_add_wall(16 - c, b, used)
			if rng.randf() < float(bits.get("fountain", 0.3)):
				var c2: int = [3, 4, 5][rng.randi() % 3]
				if rng.randf() < 0.5:
					c2 = 16 - c2
				_add_wall(c2, fountain, used)
			var free := _free_cols()
			for kind: String in ["goo", "pipe", "grate"]:
				if rng.randf() < float(bits.get(kind, 0.0)) and not free.is_empty():
					_add_wall(free[rng.randi() % free.size()], kind, used)
			var holes := float(bits.get("hole", 0.4))
			for k in 3:
				if rng.randf() < holes * 0.6 and not free.is_empty():
					_add_wall(free[rng.randi() % free.size()], "hole:%d" % (1 + rng.randi() % 2), used)


## Dim things lying on the floor of ordinary rooms: bone piles by the walls. Never on the door
## lines (the middle column and the middle row), never on an obstacle.
func _roll_floor_bits() -> void:
	if room.type != G.RoomType.COMBAT and room.type != G.RoomType.SECRET and room.type != G.RoomType.BOSS:
		return
	var bits: Dictionary = theme.get("floor_bits", {})
	var piles := int(bits.get("skulls", 0))
	if piles <= 0 or not Art.has("skull"):
		return
	var edge: Array[Vector2i] = []
	for x in COLS:
		if absi(x - DOOR_COL) > 1:
			edge.append(Vector2i(x, 0))
			edge.append(Vector2i(x, ROWS - 1))
	for y in range(1, ROWS - 1):
		if absi(y - DOOR_ROW) > 1:
			edge.append(Vector2i(0, y))
			edge.append(Vector2i(COLS - 1, y))
	var skull := Art.tex("skull")
	var fountains := {}
	for item: Dictionary in wall_items:
		if String(item["kind"]).begins_with("fountain") or item["kind"] == "bags":
			fountains[int(item["col"])] = true
	for k in rng.randi_range(0, piles):
		var cell: Vector2i = edge[rng.randi() % edge.size()]
		if room.grid[cell.y * COLS + cell.x] != room.EMPTY or (cell.y == 0 and fountains.has(cell.x)):
			continue
		for n in 1 + rng.randi() % 3:
			var shade := rng.randf_range(0.55, 0.78)
			decals.append({"tex": skull, "mod": Color(shade, shade, shade),
				"pos": Vector2(cell.x * T + rng.randi_range(-3, 3), cell.y * T + rng.randi_range(-4, 2))})


# =============================================================================== nodes: torches, fountains, lights
## Builds everything that moves or glows. Called once, after the room's own nodes exist.
func build() -> void:
	var torches: Array[Vector2] = []
	for item: Dictionary in wall_items:
		var col: int = item["col"]
		var kind: String = item["kind"]
		if kind.begins_with("fountain"):
			_build_fountain(col, "red" if kind.ends_with("red") else "blue")
		elif kind == "torch" or kind == "torch_unlit":
			_build_wall_torch(col, kind == "torch")
			if kind == "torch":
				torches.append(Vector2(col * T + 8, FLAME_Y))
		elif kind == "bags":
			room.extra_solids.append(Rect2(col * T - 6, 0, 26, 6))
	# one light per torch while the room can afford it; otherwise the torches share one
	var colour: Color = theme.get("torch_light", Color(1.0, 0.72, 0.42))
	var power := float(theme.get("torch_power", 1.0))
	if not torches.is_empty() and lights_left >= torches.size():
		for at in torches:
			_add_light(at + Vector2(0, 8), colour, 0.85 * power, 2.1, true)
	elif not torches.is_empty() and lights_left >= 1:
		var mid := Vector2.ZERO
		for at in torches:
			mid += at
		_add_light(mid / float(torches.size()) + Vector2(0, 10), colour, 0.8 * power, 3.4, true)
	_was_fighting = room.fighting
	if run.fx.has_method("set_atmosphere"):
		run.fx.set_atmosphere(theme, room.type)
	set_process(not _torch_lights.is_empty() or not _glows.is_empty())


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
func _add_glow(parent: Node2D, at: Vector2, colour: Color, glow_scale: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = run.light_tex
	glow.material = additive()
	glow.modulate = Color(colour.r, colour.g, colour.b, 0.32)
	glow.scale = Vector2(glow_scale, glow_scale)
	glow.position = at
	parent.add_child(glow)
	_glows.append([glow, glow_scale, rng.randf() * 20.0])


func _build_wall_torch(col: int, lit: bool) -> void:
	var id := "niji_wall_torch" if lit else "niji_wall_torch_unlit"
	if not Art.has(id):
		return
	var s := Art.sprite(id, "default")
	s.offset = Vector2.ZERO
	s.position = Vector2(col * T, TORCH_Y)
	s.z_index = -8
	if lit:
		s.material = unshaded()
		s.modulate = theme.get("flame_tint", Color(1, 1, 1))
		s.frame = rng.randi() % 8
		s.speed_scale = rng.randf_range(0.9, 1.15)
	else:
		s.modulate = theme["tile_tint"]
	add_child(s)
	if lit:
		var holder := Node2D.new()
		holder.z_index = -8
		add_child(holder)
		_add_glow(holder, Vector2(col * T + 8, FLAME_Y), theme.get("torch_light", Color(1.0, 0.72, 0.42)), 0.55)


func _build_fountain(col: int, colour: String) -> void:
	var mid := Art.sprite("wall_fountain_mid_" + colour, "default")
	mid.position = Vector2(col * T + 8, 0)
	mid.z_index = -9
	mid.modulate = theme["tile_tint"]
	add_child(mid)
	var basin := Art.sprite("wall_fountain_basin_" + colour, "default")
	basin.position = Vector2(col * T + 8, 16)
	basin.z_index = -9
	basin.modulate = theme["tile_tint"]
	add_child(basin)
	room.extra_solids.append(Rect2(col * T + 1, 0, 14, 7))
	_add_light(Vector2(col * T + 8, 2), Color(1.0, 0.45, 0.25) if colour == "red" else Color(0.35, 0.65, 1.0), 0.75, 1.1, false)


## Rocks, crates and columns stand in the light of the room, so they take some of the floor's tint.
func tint_obstacle(node: Node2D) -> void:
	node.modulate = (theme["tile_tint"] as Color).lerp(Color(1, 1, 1), 0.45)


## A standing torch on the floor (layout letter T). The Room already made it solid, like a column;
## this gives its obstacle node the picture, the glow and (if the room can afford it) a light.
func build_floor_torch(node: Node2D) -> void:
	node.add_child(EnemyScript.make_shadow(13.0))
	if not Art.has("niji_floor_torch"):
		return
	var s := Art.sprite("niji_floor_torch", "default")
	s.offset = Vector2.ZERO
	s.position = Vector2(-8, -23)
	s.material = unshaded()
	s.modulate = theme.get("flame_tint", Color(1, 1, 1))
	s.frame = rng.randi() % 8
	node.add_child(s)
	var colour: Color = theme.get("torch_light", Color(1.0, 0.72, 0.42))
	_add_glow(node, Vector2(0, -15), colour, 0.6)
	if run.LIGHTING:
		# floor torches were counted before the wall was rolled, so they always get their light
		lights_left += 1
		_add_light(Vector2(0, -8), colour, 0.9 * float(theme.get("torch_power", 1.0)), 2.2, true, node)
	set_process(true)


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


# =============================================================================== door states
func _locked(dir: Vector2i) -> bool:
	return room.rs["doors"][dir]["locked"] and room.type != G.RoomType.TREASURE


func _shut(dir: Vector2i) -> bool:
	return room.fighting or _locked(dir)


func _door_tint(dir: Vector2i) -> Color:
	if room.rs["doors"][dir]["boss"]:
		return TINT_BOSS
	if _locked(dir):
		return TINT_LOCKED
	return Color(1, 1, 1)


## The back-wall door is a real sprite (the pack's double door), so it can be lit like the wall.
## Also the place where a fight starting or ending is noticed: dust puffs out of every doorway.
func refresh_door_art() -> void:
	if room.fighting != _was_fighting:
		_was_fighting = room.fighting
		_door_dust(room.fighting)
	if not room.door_visible(UP) or room.rs["doors"][UP]["hidden"]:
		if _top_leaf != null:
			_top_leaf.visible = false
		return
	if _top_leaf == null:
		_top_leaf = Sprite2D.new()
		_top_leaf.centered = false
		_top_leaf.position = Vector2(8 * T - 8, -2 * T)
		_top_leaf.z_index = -9
		add_child(_top_leaf)
	_top_leaf.visible = true
	_top_leaf.texture = Art.tex("doors_leaf_closed" if _shut(UP) else "doors_leaf_open")
	var tint := _door_tint(UP)
	_top_leaf.modulate = theme["tile_tint"] if tint == Color(1, 1, 1) else tint


func _door_dust(slam: bool) -> void:
	if not run.fx.has_method("dust"):
		return
	for dir: Vector2i in room.rs["doors"]:
		if not room.door_visible(dir):
			continue
		var at: Vector2 = room.door_pos(dir) - Vector2(dir) * 5.0
		run.fx.dust(at, -Vector2(dir), 1.0 if slam else 0.6)


# =============================================================================== drawing: floor and walls
## Everything under the characters: floor, carpet, bone piles, back wall, side walls, doorways.
func draw_tiles(c: Node2D) -> void:
	var grid: PackedByteArray = room.grid
	var hole := Art.tex("hole")
	for y in ROWS:
		for x in COLS:
			var i := y * COLS + x
			var v := float(floor_shade[i]) / 255.0
			c.draw_texture(_floor_tex[floor_variant[i] - 1], Vector2(x * T, y * T), Color(v, v, v))
			if grid[i] == room.PIT:
				c.draw_texture(hole, Vector2(x * T, y * T))
	_draw_carpet(c)
	for d: Dictionary in decals:
		c.draw_texture(d["tex"], d["pos"], d["mod"])
	# the walls throw a little shadow onto the floor at their feet
	c.draw_rect(Rect2(0, 0, W, 2), Color(0, 0, 0, 0.30))
	c.draw_rect(Rect2(0, 2, W, 3), Color(0, 0, 0, 0.14))
	c.draw_rect(Rect2(0, 0, 2, H), Color(0, 0, 0, 0.16))
	c.draw_rect(Rect2(W - 2, 0, 2, H), Color(0, 0, 0, 0.16))
	_draw_back_wall(c)
	# side walls: thin strips of trim, with a doorway where a door is
	for y in range(-1, ROWS):
		if y == DOOR_ROW and room.door_visible(LEFT):
			_draw_side_doorway(c, LEFT)
		else:
			c.draw_texture(Art.tex("wall_outer_mid_left"), Vector2(-T, y * T))
		if y == DOOR_ROW and room.door_visible(RIGHT):
			_draw_side_doorway(c, RIGHT)
		else:
			c.draw_texture(Art.tex("wall_outer_mid_right"), Vector2(W, y * T))
	c.draw_texture(Art.tex("wall_outer_top_left"), Vector2(-T, -2 * T))
	c.draw_texture(Art.tex("wall_outer_top_right"), Vector2(W, -2 * T))
	if room.door_visible(DOWN):
		# the floor you see through the bottom doorway, going dark under the wall
		var x0 := float(DOOR_COL * T)
		c.draw_texture(_floor_tex[0], Vector2(x0, H), Color(0.62, 0.62, 0.62))
		c.draw_rect(Rect2(x0, H + 3, T, 5), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(x0, H + 8, T, 10), Color(VOID.r, VOID.g, VOID.b, 0.9))
	if room.door_visible(UP):
		_draw_top_door(c)


func _draw_carpet(c: Node2D) -> void:
	if carpet_id == "" or carpet.size.x < 2 or carpet.size.y < 2:
		return
	var soft := Color(0.80, 0.80, 0.80)
	for ry in carpet.size.y:
		for rx in carpet.size.x:
			var part := "fill"
			var left := rx == 0
			var right := rx == carpet.size.x - 1
			if ry == 0:
				part = "tl" if left else ("tr" if right else "t")
			elif ry == carpet.size.y - 1:
				part = "bl" if left else ("br" if right else "b")
			elif left:
				part = "l"
			elif right:
				part = "r"
			c.draw_texture(Art.tex("%s_%s" % [carpet_id, part]), Vector2((carpet.position.x + rx) * T, (carpet.position.y + ry) * T), soft)


func _draw_back_wall(c: Node2D) -> void:
	# brick face (row -1) with the trim on top (row -2)
	for x in COLS:
		var face := "wall_mid"
		var trim := "wall_top_mid"
		if x == 0:
			face = "wall_left"
			trim = "wall_top_left"
		elif x == COLS - 1:
			face = "wall_right"
			trim = "wall_top_right"
		c.draw_texture(Art.tex(face), Vector2(x * T, -T))
		c.draw_texture(Art.tex(trim), Vector2(x * T, -2 * T))
	for item: Dictionary in wall_items:
		var col: int = item["col"]
		var kind: String = item["kind"]
		var at := Vector2(col * T, -T)
		if kind.begins_with("fountain"):
			c.draw_texture(Art.tex("wall_fountain_top_%d" % (1 + col % 3)), Vector2(col * T, -2 * T))
		elif kind.begins_with("banner:"):
			c.draw_texture(Art.tex(kind.trim_prefix("banner:")), at)
		elif kind.begins_with("hole:"):
			c.draw_texture(Art.tex("wall_hole_" + kind.trim_prefix("hole:")), at)
		elif kind == "goo":
			c.draw_texture(Art.tex("wall_goo"), at)
			if room.grid[col] == room.EMPTY:
				c.draw_texture(Art.tex("wall_goo_base"), Vector2(col * T, 0))
		elif kind == "pipe" and Art.has("niji_wall_pipe"):
			c.draw_texture(Art.tex("niji_wall_pipe"), at)
		elif kind == "grate" and Art.has("niji_wall_grate"):
			c.draw_texture(Art.tex("niji_wall_grate"), at)
		elif kind == "sign" and Art.has("niji_wall_sign_orange"):
			c.draw_texture(Art.tex("niji_wall_sign_orange"), at + Vector2(0, -1))
		elif kind == "bags" and Art.has("niji_bag_brown"):
			# the Peddler's stock, leaning against the wall
			c.draw_texture(Art.tex("niji_bag_brown"), Vector2(col * T - 8, -9))
			c.draw_texture(Art.tex("niji_bag_gold"), Vector2(col * T + 5, -8))
			c.draw_texture(Art.tex("niji_bag_brown_patched"), Vector2(col * T - 1, -6))


func _draw_top_door(c: Node2D) -> void:
	var door: Dictionary = room.rs["doors"][UP]
	if door["hidden"]:
		# a secret door that was blown open: broken bricks around a dark hole
		c.draw_texture(Art.tex("wall_hole_1"), Vector2(7 * T, -T))
		c.draw_texture(Art.tex("wall_hole_2"), Vector2(9 * T, -T))
		c.draw_rect(Rect2(8 * T - 1, -T + 2, T + 2, T - 2), VOID)
		c.draw_rect(Rect2(8 * T + 1, -T, T - 2, 3), VOID)
		return
	c.draw_rect(Rect2(8 * T - 6, -2 * T + 4, 28, 28), VOID)
	c.draw_texture(Art.tex("doors_frame_left"), Vector2(8 * T - 24, -2 * T))
	c.draw_texture(Art.tex("doors_frame_right"), Vector2(8 * T + 24, -2 * T))
	c.draw_texture(Art.tex("doors_frame_top"), Vector2(8 * T - 8, -3 * T))


## The doorway of a side door: a short piece of floor going dark, no deeper than the door frame.
func _draw_side_doorway(c: Node2D, dir: Vector2i) -> void:
	var y0 := float(DOOR_ROW * T)
	var x0 := -SIDE_DEPTH if dir == LEFT else W
	c.draw_texture_rect_region(_floor_tex[0], Rect2(x0, y0, SIDE_DEPTH, T), Rect2(2, 0, SIDE_DEPTH, T), Color(0.6, 0.6, 0.6))
	var far := x0 if dir == LEFT else W + SIDE_DEPTH - 7.0
	var mid := x0 + 4.0 if dir == LEFT else W + 3.0
	c.draw_rect(Rect2(mid, y0, 5, T), Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(far, y0, 7, T), Color(VOID.r, VOID.g, VOID.b, 0.9))
	# the shadow of the frame on the threshold
	c.draw_rect(Rect2(x0, y0, SIDE_DEPTH, 2), Color(0, 0, 0, 0.35))


# =============================================================================== drawing: the bottom wall
## The bottom wall, drawn IN FRONT of everything standing in the room, with its door.
func draw_front(c: Node2D) -> void:
	var gap: bool = room.door_visible(DOWN)
	var trim_y := H - 14.0
	var face_y := H + 2.0
	for x in COLS:
		if gap and x == DOOR_COL:
			continue
		var face := "wall_mid"
		var trim := "wall_top_mid"
		if x == 0:
			face = "wall_left"
			trim = "wall_top_left"
		elif x == COLS - 1:
			face = "wall_right"
			trim = "wall_top_right"
		c.draw_texture(Art.tex(trim), Vector2(x * T, trim_y))
		c.draw_texture(Art.tex(face), Vector2(x * T, face_y))
	# the side strips run down past the floor and end in a brick foot
	c.draw_texture_rect_region(Art.tex("wall_outer_mid_left"), Rect2(-T, H - 2, T, 4), Rect2(0, 0, T, 4))
	c.draw_texture_rect_region(Art.tex("wall_outer_mid_right"), Rect2(W, H - 2, T, 4), Rect2(0, 0, T, 4))
	c.draw_texture(Art.tex("wall_outer_front_left"), Vector2(-T, face_y))
	c.draw_texture(Art.tex("wall_outer_front_right"), Vector2(W, face_y))
	if not gap:
		return
	var x0 := float(DOOR_COL * T)
	if room.rs["doors"][DOWN]["hidden"]:
		# blown open: ragged brick ends either side of the hole
		c.draw_texture(Art.tex("wall_hole_1"), Vector2(x0 - T, face_y))
		c.draw_texture(Art.tex("wall_hole_2"), Vector2(x0 + T, face_y))
		c.draw_rect(Rect2(x0 - 2, trim_y + 12, 3, 20), VOID)
		c.draw_rect(Rect2(x0 + T - 1, trim_y + 12, 3, 20), VOID)
		c.draw_rect(Rect2(x0 - 3, trim_y + 18, 2, 6), VOID)
		c.draw_rect(Rect2(x0 + T + 2, trim_y + 21, 2, 5), VOID)
		return
	# the Niji single door is exactly as tall as this wall (32 px) and 21 px wide
	var shut := _shut(DOWN)
	var id := "niji_door_single_a_closed" if shut else "niji_door_single_a_open"
	if Art.has(id):
		c.draw_texture(Art.tex(id), Vector2(x0 - 2, trim_y), _door_tint(DOWN))
	else:
		c.draw_rect(Rect2(x0 - 2, trim_y + 11, 3, 21), INK)
		c.draw_rect(Rect2(x0 + T - 1, trim_y + 11, 3, 21), INK)
		if shut:
			c.draw_rect(Rect2(x0, trim_y + 4, T, 26), WOOD_DARK)


# =============================================================================== drawing: door parts above everything
## Frames, leaves and signs of the doors (drawn above the characters). The back-wall door leaf
## is a sprite (see refresh_door_art), the bottom door is in draw_front.
func draw_doors(c: Node2D) -> void:
	for dir: Vector2i in room.rs["doors"]:
		if not room.door_visible(dir):
			continue
		var door: Dictionary = room.rs["doors"][dir]
		var locked := _locked(dir)
		var shut := _shut(dir)
		var boss: bool = door["boss"]
		var cracked: bool = door["hidden"]
		var mid: Vector2 = room.door_pos(dir)
		if dir == UP:
			if cracked:
				if shut:
					_bars_h(c, Rect2(mid.x - 8, -14, 16, 14))
				continue
			if locked:
				_keyhole(c, Vector2(mid.x, -9))
			if boss:
				c.draw_texture(Art.tex("skull"), Vector2(mid.x - 8, -47))
		elif dir == DOWN:
			if cracked:
				if shut:
					_bars_h(c, Rect2(mid.x - 8, H - 3, 16, 22))
				continue
			if locked:
				_keyhole(c, Vector2(mid.x, H + 2))
			if boss:
				c.draw_texture(Art.tex("skull"), Vector2(mid.x - 26, H - 5))
				c.draw_texture(Art.tex("skull"), Vector2(mid.x + 10, H - 5))
		else:
			_draw_side_door(c, dir, mid, shut, locked, boss, cracked)


func _draw_side_door(c: Node2D, dir: Vector2i, mid: Vector2, shut: bool, locked: bool, boss: bool, cracked: bool) -> void:
	var left := dir == LEFT
	var x0 := -SIDE_DEPTH if left else W        # outer edge (left door) / floor edge (right door)
	if cracked:
		# a blown hole: no frame, ragged stone ends, a little rubble
		for s: float in [-1.0, 1.0]:
			var y := mid.y + s * 8.0
			c.draw_rect(Rect2(-5.0 if left else W, y - 2.0, 5, 3), INK)
			c.draw_rect(Rect2(-7.0 if left else W + 4.0, y - 1.0 + s, 3, 2), BRICK_DARK)
			c.draw_rect(Rect2(-3.0 if left else W + 1.0, y + s * 2.0, 2, 2), BRICK)
		if shut:
			_bars_v(c, Rect2(-6.0 if left else W, mid.y - 9, 6, 18))
		return
	# the door leaf, seen from above: a plank across the doorway with two studs
	if shut:
		var lx := -5.0 if left else W + 1.0
		var wood := WOOD
		var grain := WOOD_DARK
		if boss:
			wood = Color("a8242a")
			grain = Color("5e1120")
		c.draw_rect(Rect2(lx - 1, mid.y - 8, 6, 16), INK)
		c.draw_rect(Rect2(lx, mid.y - 8, 4, 16), wood)
		c.draw_rect(Rect2(lx + (3 if left else 0), mid.y - 8, 1, 16), grain)
		c.draw_rect(Rect2(lx, mid.y - 3, 4, 1), grain)
		c.draw_rect(Rect2(lx, mid.y + 3, 4, 1), grain)
		c.draw_rect(Rect2(lx + 1, mid.y - 6, 2, 1), STUD)
		c.draw_rect(Rect2(lx + 1, mid.y + 5, 2, 1), STUD)
		# the doorway behind a shut door is dark
		c.draw_rect(Rect2(x0 if left else W + 5.0, mid.y - 8, SIDE_DEPTH - 5.0, 16), Color(VOID.r, VOID.g, VOID.b, 0.85))
	# the frame: two stone jambs that stick out of the wall
	var cap := STONE
	var cap_hi := STONE_HI
	if boss:
		cap = Color("b23a30")
		cap_hi = BOSS_RED
	elif locked:
		cap = GOLD_DARK
		cap_hi = GOLD
	for s2: float in [-1.0, 1.0]:
		var jy := mid.y - 13.0 if s2 < 0.0 else mid.y + 8.0
		c.draw_rect(Rect2(x0, jy, SIDE_DEPTH, 5), INK)
		c.draw_rect(Rect2(x0 + 1, jy + 1, SIDE_DEPTH - 2, 3), cap)
		c.draw_rect(Rect2(x0 + 1, jy + 1, SIDE_DEPTH - 2, 1), cap_hi)
		c.draw_rect(Rect2(x0 + 5, jy + 1, 1, 3), INK)
	if locked:
		_keyhole(c, Vector2(-3.0 if left else W + 3.0, mid.y - 2.0))
	if boss:
		c.draw_texture(Art.tex("skull"), Vector2(-14.0 if left else W - 2.0, mid.y - 28))


## The golden plate with a keyhole that marks a locked door (Niji's keyhole, tinted gold).
func _keyhole(c: Node2D, at: Vector2) -> void:
	if Art.has("niji_keyhole_light"):
		c.draw_texture(Art.tex("niji_keyhole_light"), at - Vector2(8, 10), Color(1.0, 0.86, 0.42))
	else:
		c.draw_rect(Rect2(at.x - 4, at.y - 5, 8, 9), INK)
		c.draw_rect(Rect2(at.x - 3, at.y - 4, 6, 7), GOLD)
		c.draw_rect(Rect2(at.x - 1, at.y - 2, 2, 3), INK)


## Upright iron bars seen from the front (a blown-open hole in the back or bottom wall, in a fight).
func _bars_h(c: Node2D, r: Rect2) -> void:
	c.draw_rect(r, Color(0.03, 0.03, 0.05, 0.85))
	var x := r.position.x + 1.0
	while x < r.end.x - 1.0:
		c.draw_rect(Rect2(x, r.position.y, 2, r.size.y), IRON_DARK)
		c.draw_rect(Rect2(x, r.position.y, 1, r.size.y), IRON_LIGHT)
		x += 4.0
	c.draw_rect(Rect2(r.position.x, r.position.y + 3, r.size.x, 2), IRON_DARK)
	c.draw_rect(Rect2(r.position.x, r.position.y + 3, r.size.x, 1), IRON_LIGHT)


## An iron gate in a side wall, seen from above: a thick strip with rivets.
func _bars_v(c: Node2D, r: Rect2) -> void:
	c.draw_rect(r, IRON_DARK)
	c.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), IRON_LIGHT.darkened(0.25))
	var y := r.position.y + 2.0
	while y < r.end.y - 2.0:
		c.draw_rect(Rect2(r.position.x + 2, y, 2, 2), IRON_LIGHT.lightened(0.3))
		y += 4.0
