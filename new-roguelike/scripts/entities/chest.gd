extends Node2D
## Chest: walk into it to open it. A plain chest pops 2-4 pickups and sometimes an item.
## A LOCKED chest (golden, with a keyhole plate) needs a key and holds better loot.
## desc: {"pos": Vector2, "locked": bool, "rich": bool, "opened": bool}
##   rich = locked-chest loot without needing a key (used by secret rooms)

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const BLOCK_RADIUS := 7.0
## What can pop out, and how likely (weights).
const LOOT := {"coin": 60, "coin5": 5, "half_heart": 12, "key": 8, "bomb": 10, "armor": 3}
const LOOT_RICH := {"coin": 40, "coin5": 16, "heart": 12, "key": 10, "bomb": 12, "armor": 10}
const ITEM_CHANCE := 0.12
const ITEM_CHANCE_RICH := 0.45

var kind := "chest"
var solid := true
var room: Node
var locked := false
var rich := false
var opened := false
var sprite: AnimatedSprite2D
var _open_t := -1.0
var _deny_cd := 0.0
var _shake := 0.0


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	locked = desc.get("locked", false)
	rich = desc.get("rich", false) or locked
	opened = desc.get("opened", false)
	add_child(EnemyScript.make_shadow(18.0))
	sprite = Art.sprite("chest_empty_open" if opened else "chest_full_open", "default")
	sprite.position = Vector2(0, 4)
	sprite.stop()
	sprite.frame = 2 if opened else 0
	if locked and not opened:
		sprite.modulate = Color(1.3, 1.15, 0.6)
	add_child(sprite)


func save() -> Dictionary:
	return {"kind": "chest", "pos": position, "locked": locked, "rich": rich, "opened": opened}


func _draw() -> void:
	if locked and not opened:
		# keyhole plate
		draw_rect(Rect2(-3, -6, 6, 7), Color(0.13, 0.12, 0.13))
		draw_rect(Rect2(-2, -5, 4, 5), Color(0.96, 0.76, 0.24))
		draw_rect(Rect2(-1, -4, 2, 3), Color(0.13, 0.12, 0.13))


func _physics_process(delta: float) -> void:
	_deny_cd = maxf(0.0, _deny_cd - delta)
	if _shake > 0.0:
		_shake -= delta
		sprite.position.x = sin(_shake * 60.0) * 1.5 if _shake > 0.0 else 0.0
	if _open_t >= 0.0:
		_open_t += delta
		sprite.frame = mini(2, int(_open_t / 0.08))
		if _open_t >= 0.24:
			_open_t = -1.0
			_spill()
	var player: Node = room.run.player
	if player == null or player.dead:
		return
	var d: Vector2 = player.position - position
	var reach: float = BLOCK_RADIUS + player.radius
	if d.length() < reach:
		player.position = position + (d.normalized() if d.length() > 0.1 else Vector2.DOWN) * reach
		if not opened and _open_t < 0.0:
			_try_open(player)


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
	sprite.modulate = Color(1, 1, 1)
	queue_redraw()
	_open_t = 0.0
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
	# the lid stays open and the chest is now empty
	sprite.sprite_frames = Art.frames("chest_empty_open")
	sprite.stop()
	sprite.frame = 2
