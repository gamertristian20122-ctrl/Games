extends "res://scripts/run/room_look.gd"
## The look of a room OUT OF DOORS (the Elfwood): the same room and rules as in the hill, dressed
## as a forest clearing. room.gd picks this file when the floor's theme says "outdoor": true.
##   floor     the Fairy Forest grass, tufts and flowers, trodden earth at the ways out
##   walls     a wall of trees behind, bushes down the sides and along the bottom
##   doors     a gap in the trees. Shut in a fight = a thorn bush grows across it; locked = a mossy
##             boulder with a gold mark; the champion's glade = a rune stone; a hidden way looks
##             like the rest of the hedge until it is found
##   rock, crate, pillar, torch   a stone, a log, a vine, a glowing mushroom
##   pit, spikes                  a dark sinkhole (flat code-drawn), thorny vines that rise
## All pictures are the hub pieces cut by tools/import_hub.py (ids hub_*); nothing is drawn but
## flat shapes (the sinkhole, the gold mark).

## One set of pieces per "dress" (the theme's "dress" key; "forest" when it has none).
##   trees / hedge   the wall behind, and the low things down the sides and along the bottom
##   obstacle        what a rock, crate, pillar and torch tile become       barrier   what shuts a way out
##   ground / bits / patch   the floor tile, the flat things scattered on it, the trodden earth at ways out
##   spike_up / spike_down   what rises from a spike tile       glow   the colour of a "torch" piece's light
const DRESS := {
	"forest": {
		"trees": ["hub_tree_green_3", "hub_tree_teal_3", "hub_tree_pink_3", "hub_tree_green_3", "hub_tree_green_4", "hub_tree_teal_4"],
		"hedge": ["hub_bush_green_2", "hub_bush_deep_1", "hub_bush_green_3", "hub_bush_deep_2", "hub_bush_green_2", "hub_bush_orange_3"],
		"obstacle": {"rock": ["hub_stone_2", "hub_rock_3", "hub_rock_moss_3"], "crate": ["hub_stump_2"], "pillar": ["hub_vine_3", "hub_bloom_4"], "torch": ["hub_shroom_1"]},
		"barrier": {"shut": "hub_bush_rust_2", "locked": "hub_stone_0", "boss": "hub_rune_0", "cracked": "hub_bush_orange_3"},
		"ground": "hub_grass", "patch": ["hub_patch_0", "hub_patch_1"], "bits": [], "spike_up": "hub_vine_3", "spike_down": "hub_twig_0",
		"glow": Color(0.5, 1.0, 0.85), "pit": [Color("0b1512"), Color("06301f")],
	},
	"desert": {
		"trees": ["hub_dstone_0", "hub_dtree_1", "hub_dstone_1", "hub_obelisk_2", "hub_dstone_2", "hub_cactus_4", "hub_dstone_0", "hub_dbush_1"],
		"hedge": ["hub_dbush_2", "hub_cactus_1", "hub_dshrub", "hub_cactus_0", "hub_dbush_2", "hub_cactus_5", "hub_dblock_1"],
		"obstacle": {"rock": ["hub_dstone_2", "hub_dstone_1"], "crate": ["hub_dpot_0", "hub_dchest"], "pillar": ["hub_dpillar_3", "hub_cactus_0"], "torch": ["hub_dpot_1"]},
		"barrier": {"shut": "hub_dbush_2", "locked": "hub_dstone_1", "boss": "hub_obelisk_2", "cracked": "hub_dblock_1"},
		"ground": "hub_sand", "patch": [], "bits": ["hub_dgrass_0", "hub_dgrass_1", "hub_dgrass_2", "hub_dgrass_3", "hub_dblock_2", "hub_dblock_3"],
		"spike_up": "hub_cactus_5", "spike_down": "hub_dgrass_2", "glow": Color(1.0, 0.8, 0.45), "pit": [Color("2a1a12"), Color("6b4526")],
	},
}
var TREES: Array = []
var HEDGE: Array = []
var OBSTACLE := {}
var BARRIER := {}
var _dress := {}
const MID := {UP: Vector2(136, 2), DOWN: Vector2(136, 126), LEFT: Vector2(-6, 62), RIGHT: Vector2(278, 62)}

var _behind: Array = []          ## [Texture2D, top-left, gap dir or ZERO, flip]: trees and side bushes, drawn under the characters
var _before: Array = []          ## the same for the bottom hedge, drawn over their feet
var _bits: Array = []            ## [Texture2D, top-left]: flat things on the grass


func roll(the_room: Node2D) -> void:
	room = the_room
	run = room.run
	theme = room.theme
	back = 48.0
	_dress = DRESS.get(String(theme.get("dress", "forest")), DRESS["forest"])
	TREES = _dress["trees"]
	HEDGE = _dress["hedge"]
	OBSTACLE = _dress["obstacle"]
	BARRIER = _dress["barrier"]
	rng.seed = int(room.rs["seed"]) + 101
	_force_door = G.arg("doorlook")
	_behind.clear()
	_before.clear()
	_bits.clear()
	# the wall of trees behind, with bushes at their feet
	var x := -14.0
	while x < W + 20.0:
		_add(_behind, String(TREES[rng.randi() % TREES.size()]), Vector2(x + rng.randf_range(-4, 4), rng.randf_range(-10, -3)), UP if absf(x - 136.0) < 24.0 else Vector2i.ZERO)
		x += 27.0
	x = -10.0
	while x < W + 14.0:
		_add(_behind, String(HEDGE[rng.randi() % HEDGE.size()]), Vector2(x, 3.0 + rng.randf_range(-2, 2)), UP if absf(x - 136.0) < 22.0 else Vector2i.ZERO)
		x += 21.0
	# bushes down both sides
	var y := 14.0
	while y < H + 8.0:
		var gap := absf(y - 62.0) < 15.0
		_add(_behind, String(HEDGE[rng.randi() % HEDGE.size()]), Vector2(-8.0 + rng.randf_range(-3, 1), y), LEFT if gap else Vector2i.ZERO)
		_add(_behind, String(HEDGE[rng.randi() % HEDGE.size()]), Vector2(W + 8.0 + rng.randf_range(-1, 3), y), RIGHT if gap else Vector2i.ZERO)
		y += 17.0
	_behind.sort_custom(func(a: Array, b: Array) -> bool: return float(a[4]) < float(b[4]))
	# the hedge along the bottom, over the feet of whoever stands by it
	x = -10.0
	while x < W + 14.0:
		_add(_before, String(HEDGE[rng.randi() % HEDGE.size()]), Vector2(x, H + 16.0 + rng.randf_range(-2, 3)), DOWN if absf(x - 136.0) < 22.0 else Vector2i.ZERO)
		x += 21.0
	# flat things on the grass, and trodden earth at the four ways out
	for dir: Vector2i in [UP, DOWN, LEFT, RIGHT]:
		if room.door_exists(dir):
			var at: Vector2 = MID[dir]
			var patches: Array = _dress["patch"]
			if not patches.is_empty():
				_bits.append([Art.tex(String(patches[rng.randi() % patches.size()])), (at - Vector2(24, 24) - Vector2(dir) * 10.0).round()])
	var flat: Array = _dress["bits"]
	for i in 16:
		var id := "hub_tuft_%d" % (rng.randi() % 24) if rng.randf() < 0.7 else "hub_flower_%d" % (rng.randi() % 26)
		if not flat.is_empty():
			id = String(flat[rng.randi() % flat.size()])
		_bits.append([Art.tex(id), Vector2(rng.randf_range(4, W - 12), rng.randf_range(4, H - 10)).round()])


## A piece standing with its base on `base`.
func _add(list: Array, id: String, base: Vector2, gap: Vector2i) -> void:
	var tex := Art.tex(id)
	var sz := tex.get_size()
	list.append([tex, Vector2(roundf(base.x - sz.x * 0.5), roundf(base.y - sz.y)), gap, rng.randf() < 0.5, base.y])


func build() -> void:
	set_process(not _glows.is_empty())


func build_obstacle(node: Node2D, kind: String, cx: int, cy: int) -> void:
	var names: Array = OBSTACLE.get(kind, OBSTACLE["rock"])
	var mirror_x := mini(cx, COLS - 1 - cx)
	var id := String(names[posmod(hash(Vector3i(int(room.rs["seed"]) & 0xFFFFFF, mirror_x, cy * 8 + kind.length())), names.size())])
	var s := Sprite2D.new()
	s.texture = Art.tex(id)
	s.centered = false
	var sz := s.texture.get_size()
	s.position = Vector2(-floorf(sz.x * 0.5), 1.0 - sz.y)
	node.add_child(s)
	if kind == "torch":
		_add_glow(node, Vector2(0, -sz.y + 6.0), _dress["glow"], 0.5, 0.32, true)
		set_process(true)


func debris(kind: String) -> Array:
	if kind == "crate":
		return [Color("6b4a2b"), Color("3c2a1a"), Color("8a6a3c")]
	return [Color("7d7f8c"), Color("4a4c58"), Color("2f6a3a")]


func refresh_door_art() -> void:
	_was_fighting = room.fighting


## True while a way out in this wall can be seen (so the hedge leaves a gap there).
func _open_gap(dir: Vector2i) -> bool:
	var state := door_state(dir)
	return state != "" and state != "hidden"


func _draw_list(c: Node2D, list: Array) -> void:
	for item: Array in list:
		var gap: Vector2i = item[2]
		if gap != Vector2i.ZERO and _open_gap(gap):
			continue
		var tex: Texture2D = item[0]
		var at: Vector2 = item[1]
		if bool(item[3]):
			c.draw_texture_rect(tex, Rect2(at + Vector2(tex.get_width(), 0), Vector2(-tex.get_width(), tex.get_height())), false)
		else:
			c.draw_texture(tex, at)


## What blocks a way out right now (nothing when it is open).
func _draw_barrier(c: Node2D, dir: Vector2i) -> void:
	var state := door_state(dir)
	if not BARRIER.has(state):
		return
	var tex := Art.tex(String(BARRIER[state]))
	var at: Vector2 = MID[dir]
	var corner := Vector2(roundf(at.x - tex.get_width() * 0.5), roundf(at.y - tex.get_height() + (4.0 if dir != DOWN else 0.0)))
	c.draw_texture(tex, corner)
	if state == "locked":
		# the gold mark of a way that wants a key (a flat shape, like the keyhole plate in the hill)
		var m := corner + Vector2(tex.get_width() * 0.5 - 3.0, tex.get_height() * 0.5 - 3.0)
		c.draw_rect(Rect2(m, Vector2(6, 7)), INK)
		c.draw_rect(Rect2(m + Vector2(1, 1), Vector2(4, 5)), LOCK_GOLD)
		c.draw_rect(Rect2(m + Vector2(2, 2), Vector2(2, 2)), INK)


func draw_tiles(c: Node2D) -> void:
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.draw_texture_rect(Art.tex(String(_dress["ground"])), Rect2(-224, -144, 720, 432), true)
	for bit: Array in _bits:
		c.draw_texture(bit[0], bit[1], DECO_DIM)
	_draw_list(c, _behind)
	for dir: Vector2i in [UP, LEFT, RIGHT]:
		_draw_barrier(c, dir)


func draw_flat(c: Node2D, spike_frame: int) -> void:
	# sinkholes: dark, with a lighter lip on the far side
	for i: int in room.grid.size():
		if room.grid[i] != room.PIT:
			continue
		var pos := Vector2((i % COLS) * T, (i / COLS) * T)
		c.draw_rect(Rect2(pos, Vector2(T, T)), (_dress["pit"] as Array)[0])
		if not _is_pit(i % COLS, i / COLS - 1):
			c.draw_rect(Rect2(pos.x, pos.y, T, 2), (_dress["pit"] as Array)[1])
			c.draw_rect(Rect2(pos.x, pos.y + 2, T, 3), Color(0, 0, 0, 0.5))
	if not room.has_spikes:
		return
	var up := spike_frame > 0
	var tex := Art.tex(String(_dress["spike_up"] if up else _dress["spike_down"]))
	for i: int in room.grid.size():
		if room.grid[i] == room.SPIKES:
			var mid := Vector2((i % COLS) * T + 8.0, (i / COLS) * T + 14.0)
			c.draw_texture(tex, Vector2(roundf(mid.x - tex.get_width() * 0.5), roundf(mid.y - tex.get_height())))


func draw_front(c: Node2D) -> void:
	_draw_list(c, _before)
	_draw_barrier(c, DOWN)


func draw_doors(_c: Node2D) -> void:
	pass
