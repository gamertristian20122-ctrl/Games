extends Node2D
## Familiar: a small helper that trails behind the player and acts on its own.
## What it IS comes from scripts/data/familiars.gd; what it DOES comes from a behaviour file in
## scripts/entities/familiars/<behaviour>.gd:
##     extends RefCounted
##     func start(f) -> void                 # optional
##     func tick(f, delta: float) -> void    # every physics frame
## One behaviour object is shared, so keep memory on the familiar: f.p (params), f.t, f.t2, f.mem.
## Helpers: f.nearest_enemy(range) -> enemy or null, f.shoot_at(enemy, speed, damage, type),
##          f.run, f.player, f.block_radius (set > 0 and add yourself to room.blockers to stop enemy shots).

const Familiars = preload("res://scripts/data/familiars.gd")
const Shots = preload("res://scripts/run/shots.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

var run: Node
var player: Node
var id := ""
var data: Dictionary
var display_name := ""
var p: Dictionary = {}
var behaviour: RefCounted
var slot := 0
var t := 0.0
var t2 := 0.0
var mem := {}
var block_radius := 0.0
var sprite: AnimatedSprite2D
var _bob := 0.0
var _hover := 5.0
var _started := false


func setup(the_run: Node, the_player: Node, familiar_id: String, index: int) -> void:
	run = the_run
	player = the_player
	id = familiar_id
	slot = index
	data = Familiars.info(familiar_id)
	display_name = String(data.get("name", familiar_id))
	p = data.get("params", {})
	behaviour = EnemyScript.ai_for(String(data.get("behaviour", "shooter")), "familiars")
	var shadow := EnemyScript.make_shadow(9.0)
	add_child(shadow)
	sprite = Art.sprite(String(data.get("sprite", "pc_bat_small")), String(data.get("anim", "idle")))
	sprite.modulate = data.get("tint", Color(1, 1, 1))
	_hover = float(data.get("hover", 5.0))
	add_child(sprite)
	_bob = randf() * 6.0


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if not _started:
		_started = true
		if behaviour.has_method("start"):
			behaviour.start(self)
	# trail behind the player, each familiar a little further back
	var back := Vector2(-15.0 - 11.0 * slot, -3.0)
	if player.body.flip_h:
		back.x = -back.x
	var want: Vector2 = player.position + back
	var before := position
	position = position.lerp(want, 1.0 - exp(-5.0 * delta))
	position.x = clampf(position.x, 4.0, G.ROOM_W - 4.0)
	position.y = clampf(position.y, 4.0, G.ROOM_H - 4.0)
	if absf(position.x - before.x) > 0.02:
		sprite.flip_h = position.x < before.x
	_bob += delta
	sprite.position.y = -_hover + sin(_bob * 4.0) * 1.5
	behaviour.tick(self, delta)


## Called when the player walks into a new room.
func entered_room() -> void:
	position = player.position + Vector2(-8, -2)


func nearest_enemy(max_range: float) -> Node:
	var best: Node = null
	var best_d := max_range * max_range
	for e in run.room.enemies:
		if not e.hittable:
			continue
		var d: float = position.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func shoot_at(enemy: Node, shot_speed: float, damage: float, type: String = "wisp") -> void:
	var d: Vector2 = (enemy.position - position).normalized()
	run.shots.fire(position, d * shot_speed, Shots.SIDE_PLAYER, damage, float(p.get("range", 100.0)) + 20.0, type, {"knock": 0.4})
	sprite.flip_h = d.x < 0.0


## A shot just hit this familiar (only happens when block_radius > 0 and it is in room.blockers).
func blocked_shot() -> void:
	run.fx.ring(position - Vector2(0, _hover + 6.0), 2.0, 9.0, 0.2, Color(0.8, 1.0, 1.0), 1.5)
