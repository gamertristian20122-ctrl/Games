extends Node2D
## Pickup: a coin, heart, key or bomb lying on the floor. What each one gives comes from
## scripts/data/pickups.gd. It pops out with a bounce, slides toward the player when close,
## and is collected on touch (hearts stay on the floor while you are at full health).
## desc: {"id": "coin", "pos": Vector2, "pop": bool}

const Pickups = preload("res://scripts/data/pickups.gd")
const Gear = preload("res://scripts/data/gear.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const MAGNET_RANGE := 28.0
const TAKE_RANGE := 8.0

var kind := "pickup"
var solid := false
var room: Node
var id := "coin"
var info: Dictionary
var sprite: AnimatedSprite2D
var vel := Vector2.ZERO
var lift := 0.0
var lift_v := 0.0
var bounces := 0
var age := 0.0
var gear_id := ""               ## set when this pickup is a piece of gear ("gear:<id>")
var _bob := 0.0
var _ground_y := 0.0


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	id = String(desc.get("id", "coin"))
	info = Pickups.info(id)
	if id.begins_with("gear:"):
		# a piece of gear lying on the floor (scripts/data/gear.gd): its own icon, picked up like a coin
		gear_id = id.substr(5)
		info = {"sprite": [String(Gear.row(gear_id).get("icon", "prop_gem"))], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 11.0, "give": {}, "kind": "gear", "sfx": "key_pickup"}
	position = desc.get("pos", G.ROOM_CENTER)
	var s := float(info.get("scale", 1.0))
	var shadow := EnemyScript.make_shadow(float(info.get("shadow", 8.0)) * s)
	add_child(shadow)
	var sprite_id := Pickups.sprite_for(id) if gear_id == "" else String(info["sprite"][0])
	sprite = Art.sprite(sprite_id, "default")
	sprite.scale = Vector2(s, s)
	sprite.modulate = info.get("tint", Color(1, 1, 1))
	# how far the picture's lowest drawn row sits above the bottom of its image: the "prop_"
	# pictures are cut tight, the old 16 px ones have empty rows under them
	_ground_y = 1.0 if sprite_id.begins_with("prop_") or Art.size(sprite_id).y < 16.0 else 3.0
	# start on a random frame, so a pile of coins does not spin as one
	if sprite.sprite_frames.get_frame_count("default") > 1:
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count("default")
	add_child(sprite)
	if String(info.get("kind", "")) in ["heart", "gear"]:
		_add_plate()
	_bob = randf() * 6.0
	if desc.get("pop", false):
		var a := randf() * TAU
		vel = Vector2(cos(a), sin(a) * 0.7) * randf_range(25.0, 60.0)
		lift_v = randf_range(70.0, 110.0)
		lift = 2.0
		bounces = 2
	_place_sprite()


## A soft dark plate behind a heart (code-drawn discs, no art), so a red or half heart still reads
## on the red Ashen Halls floor and on every other one. It rides on the sprite, behind it.
func _add_plate() -> void:
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture("default", 0)
	if tex == null:
		return
	var plate := Node2D.new()
	plate.show_behind_parent = true
	plate.position = sprite.offset + tex.get_size() / 2.0
	var r := maxf(tex.get_size().x, tex.get_size().y) * 0.5 + 1.5
	plate.draw.connect(func() -> void:
		plate.draw_circle(Vector2.ZERO, r + 1.5, Color(0.04, 0.02, 0.05, 0.3))
		plate.draw_circle(Vector2.ZERO, r, Color(0.04, 0.02, 0.05, 0.6)))
	sprite.add_child(plate)


func save() -> Dictionary:
	return {"kind": "pickup", "id": id, "pos": position}


func _place_sprite() -> void:
	sprite.position.y = _ground_y * sprite.scale.y - lift + (sin(_bob * 3.0) * 0.8 if bounces == 0 and lift <= 0.0 else 0.0)


func _physics_process(delta: float) -> void:
	age += delta
	_bob += delta
	# the little bounce when it pops out
	if lift > 0.0 or lift_v > 0.0:
		lift += lift_v * delta
		lift_v -= 420.0 * delta
		if lift <= 0.0:
			lift = 0.0
			if bounces > 0:
				bounces -= 1
				lift_v = -lift_v * 0.45
				vel *= 0.55
			else:
				lift_v = 0.0
	if vel.length_squared() > 1.0:
		position = room.move_circle(position, 3.0, vel * delta, false, false)
		vel = vel.move_toward(Vector2.ZERO, 90.0 * delta)
	var player: Node = room.run.player
	if player != null and not player.dead and age > 0.25:
		var d: Vector2 = player.position - position
		var dist := d.length()
		if dist < MAGNET_RANGE and player.wants(String(info.get("need", ""))):
			if dist < TAKE_RANGE:
				_collect(player)
				return
			# slide toward the player, faster the closer it is
			position += d / dist * (40.0 + (MAGNET_RANGE - dist) * 6.0) * delta
	_place_sprite()


func _collect(player: Node) -> void:
	if gear_id != "":
		Sfx.play("key_pickup", -6.0)
		room.run.fx.burst(position - Vector2(0, 4), [Color(1, 1, 1), Gear.color(Gear.row(gear_id))], 8, 45.0, 0.4, 1.8)
		room.run.found_gear(gear_id)
		room.remove_thing(self)
		return
	var give: Dictionary = info.get("give", {})
	var coins: int = player.give(give)
	var amount := 1
	for key in give:
		amount = int(give[key])
	if give.has("coins"):
		amount = coins
	G.pickup_collected.emit(String(info.get("kind", "coin")), amount)
	Sfx.play(String(info.get("sfx", "coin_pickup")), -8.0)
	room.run.fx.burst(position - Vector2(0, 4), [Color(1, 1, 0.8), Color(1, 0.9, 0.4)], 4, 35.0, 0.3, 1.6)
	room.run.effects.fire("on_pickup", [id])
	room.remove_thing(self)
