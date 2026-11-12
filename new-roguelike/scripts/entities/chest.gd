extends Node2D
## Chest: walk into it to open it. A plain chest pops 2-4 pickups and sometimes an item.
## A LOCKED chest (the golden one with a padlock, it glints) needs a key and holds better loot.
## desc: {"pos": Vector2, "locked": bool, "rich": bool, "opened": bool, "gold": bool}
##   rich = locked-chest loot without needing a key (used by secret rooms)
##   gold = it was a locked chest (it keeps its golden look after it is opened)
## The pictures are Pixel Crawler chests cut by tools/import_props.py: one style per floor tile
## set ("prop_chest_<tiles>" and "..._open"), and "prop_chest_locked" for every locked chest.
## The pack draws a chest shut and open, nothing in between: the opening is a squash, a pop
## and a few sparkles on the lid, made here.
## Test flag: --lockchests makes every chest a locked one (to look at it).

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const BLOCK_RADIUS := 7.0
const BLOCK_HALF_WIDTH := 12.0     ## the chest pictures are 28-32 px wide
## What can pop out, and how likely (weights).
const LOOT := {"coin": 60, "coin5": 5, "half_heart": 12, "key": 8, "bomb": 10, "armor": 3}
const LOOT_RICH := {"coin": 40, "coin5": 16, "heart": 12, "key": 10, "bomb": 12, "armor": 10}
const ITEM_CHANCE := 0.12
const ITEM_CHANCE_RICH := 0.45
## The look. SPILL_AT is when the loot comes out (seconds after the touch).
const LOOK_FALLBACK := "crypt"       ## the style used when a floor's tile set has no chest of its own
const LOOK_LOCKED := "locked"
const SQUASH_TIME := 0.10            ## the shut chest ducks, then the lid flies up
const SPILL_AT := 0.24
const POP_TIME := 0.30
const GLINT_EVERY := 1.7             ## a locked chest twinkles this often (seconds)
const GLINT_COLOR := Color(1.0, 0.92, 0.55)

var kind := "chest"
var solid := true
var room: Node
var locked := false
var rich := false
var opened := false
var gold := false
var body: Node2D                 ## holds both pictures; shaken and squashed as one
var shut: AnimatedSprite2D
var open: AnimatedSprite2D
var _open_t := -1.0
var _spilled := false
var _deny_cd := 0.0
var _shake := 0.0
var _glint := 0.0


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	locked = desc.get("locked", false) or (G.flag("lockchests") and not desc.get("opened", false))
	rich = desc.get("rich", false) or locked
	opened = desc.get("opened", false)
	gold = desc.get("gold", false) or locked
	var look := "prop_chest_" + (LOOK_LOCKED if gold else String(room.run.theme.get("tiles", LOOK_FALLBACK)))
	if not Art.has(look):
		look = "prop_chest_" + LOOK_FALLBACK
	add_child(EnemyScript.make_shadow(Art.size(look).x + 2.0))
	body = Node2D.new()
	body.position = Vector2(0, 5)
	add_child(body)
	shut = Art.sprite(look)
	open = Art.sprite(look + "_open")
	body.add_child(shut)
	body.add_child(open)
	shut.visible = not opened
	open.visible = opened
	_glint = randf() * GLINT_EVERY


func save() -> Dictionary:
	return {"kind": "chest", "pos": position, "locked": locked, "rich": rich, "opened": opened, "gold": gold}


func _physics_process(delta: float) -> void:
	_deny_cd = maxf(0.0, _deny_cd - delta)
	if _shake > 0.0:
		_shake -= delta
		body.position.x = sin(_shake * 60.0) * 1.5 if _shake > 0.0 else 0.0
	if locked and not opened:
		_glint -= delta
		if _glint <= 0.0:
			_glint = GLINT_EVERY
			var sz: Vector2 = shut.sprite_frames.get_frame_texture("idle", 0).get_size()
			room.run.fx.sparkle(position + Vector2(randf_range(-0.35, 0.35) * sz.x, 5.0 - randf_range(0.45, 0.95) * sz.y), GLINT_COLOR)
	if _open_t >= 0.0:
		_open_t += delta
		_animate_opening()
		if _open_t >= SPILL_AT and not _spilled:
			_spilled = true
			_spill()
		if _open_t >= SQUASH_TIME + POP_TIME:
			_open_t = -1.0
			body.scale = Vector2.ONE
	var player: Node = room.run.player
	if player == null or player.dead or opened:
		return       # an OPENED chest no longer blocks anyone (it stays to look at; it never traps the hero by a door)
	# An oval as wide as the art (about 30 px) and BLOCK_RADIUS deep, so the hero stops at its sides.
	var d: Vector2 = player.position - position
	var reach := Vector2(BLOCK_HALF_WIDTH, BLOCK_RADIUS) + Vector2.ONE * float(player.radius)
	var q := d / reach
	if q.length() < 1.0:
		player.position = position + (q.normalized() if q.length() > 0.01 else Vector2.DOWN) * reach
		if not opened and _open_t < 0.0:
			_try_open(player)


## The shut chest ducks (wide and low), then the open one jumps up tall and settles.
func _animate_opening() -> void:
	if _open_t < SQUASH_TIME:
		var k := _open_t / SQUASH_TIME
		body.scale = Vector2(1.0 + 0.14 * k, 1.0 - 0.20 * k)
		return
	if shut.visible:
		shut.visible = false
		open.visible = true
		_lid_sparkles()
	var k2 := clampf((_open_t - SQUASH_TIME) / POP_TIME, 0.0, 1.0)
	# a spring that overshoots once and dies away
	var spring := exp(-5.0 * k2) * cos(k2 * 9.0)
	body.scale = Vector2(1.0 - 0.12 * spring, 1.0 + 0.22 * spring)


func _lid_sparkles() -> void:
	var sz: Vector2 = open.sprite_frames.get_frame_texture("idle", 0).get_size()
	var color := GLINT_COLOR if gold else Color(1, 1, 0.85)
	for i in 3:
		var at := position + Vector2((i - 1) * sz.x * 0.3 + randf_range(-2, 2), 5.0 - sz.y * randf_range(0.75, 1.0))
		room.run.fx.sparkle(at, color, i * 0.07)


func _try_open(player: Node) -> void:
	if locked:
		if player.keys <= 0:
			if _deny_cd <= 0.0:
				_deny_cd = 0.9
				_shake = 0.25
				Sfx.play("shop_deny", -4.0)
				G.toast.emit("Locked", "You need a key.")
			return
		player.keys -= 1
		G.stat.emit("key_used", 1)
		Sfx.play("door_unlock", -4.0)
		G.hud_changed.emit()
	opened = true
	locked = false
	_open_t = 0.0
	_spilled = false
	Sfx.play("chest_open")
	G.stat.emit("chest_opened", 1)


func _spill() -> void:
	var table: Dictionary = LOOT_RICH if rich else LOOT
	var amount := (4 + randi() % 3) if rich else (2 + randi() % 3)
	var total := 0
	for k in table:
		total += int(table[k])
	for n in amount:
		var roll := randi() % total
		for k in table:
			roll -= int(table[k])
			if roll < 0:
				room.drop(k, position + Vector2(randf_range(-3, 3), 6))
				break
	if rich:
		room.drop("coin5", position + Vector2(0, 6))
	room.run.fx.burst(position - Vector2(0, 6), [Color(1, 0.9, 0.4), Color(1, 1, 0.8)], 10, 60.0, 0.45, 2.0)
	if randf() < (ITEM_CHANCE_RICH if rich else ITEM_CHANCE):
		var item: String = room.run.take_item("treasure", room.rng)
		if item != "":
			room.add_thing("pedestal", {"item": item, "pos": room.free_spot_near(position + Vector2(0, 20))})
