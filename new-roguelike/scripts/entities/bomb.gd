extends Node2D
## Bomb: placed at the player's feet. It blinks faster and faster for FUSE seconds, then
## the room handles the blast (room.explode): enemies, the player if too close, rocks, crates
## and hidden doors. The numbers for the blast live at the top of scripts/run/run.gd.

const EnemyScript = preload("res://scripts/entities/enemy.gd")

const FUSE := 1.4

var room: Node
var t := 0.0
var sprite: AnimatedSprite2D
var _fuse_sfx := 0.0
var _gone := false


func setup(the_room: Node, at: Vector2) -> void:
	room = the_room
	position = at
	add_child(EnemyScript.make_shadow(11.0))
	sprite = Art.sprite("bomb", "default")
	sprite.position = Vector2(0, 3)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	var k := clampf(t / FUSE, 0.0, 1.0)
	# blink white, faster toward the end; swell a little just before the blast
	var phase := fmod(k * k * 9.0 + k * 3.0, 1.0)
	sprite.material = EnemyScript.white_material() if phase > 0.5 else null
	var s := 1.0 + 0.25 * k * k + (0.08 if phase > 0.5 else 0.0)
	sprite.scale = Vector2(s, s)
	_fuse_sfx -= delta
	if _fuse_sfx <= 0.0:
		_fuse_sfx = 0.45
		Sfx.play("bomb_fuse", -12.0)
	if t >= FUSE:
		detonate()


## Goes off right now (the fuse ran out, or the Hungry Curse swallowed it).
func detonate() -> void:
	if _gone:
		return
	_gone = true
	room.bombs.erase(self)
	room.explode(position, room.run.player.stats.v("bomb_damage"))
	queue_free()
