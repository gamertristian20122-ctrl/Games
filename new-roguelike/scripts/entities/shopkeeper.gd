extends Node2D
## Shopkeeper: "the Peddler", who stands behind the shop stands (the pack's "doc" sprite).
## He only stands there and looks at you; the stands do the selling (see pedestal.gd).
## desc: {"pos": Vector2}

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const BLOCK_RADIUS := 6.0

var kind := "shopkeeper"
var solid := true
var room: Node
var sprite: AnimatedSprite2D


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	add_child(EnemyScript.make_shadow(13.0))
	sprite = Art.sprite("doc", "idle")
	sprite.position = Vector2(0, 2)
	add_child(sprite)


func save() -> Dictionary:
	return {"kind": "shopkeeper", "pos": position}


func _physics_process(_delta: float) -> void:
	var player: Node = room.run.player
	if player == null or player.dead:
		return
	var d: Vector2 = player.position - position
	sprite.flip_h = d.x < 0.0
	var reach: float = BLOCK_RADIUS + player.radius
	if d.length() < reach:
		player.position = position + (d.normalized() if d.length() > 0.1 else Vector2.DOWN) * reach
