class_name Boss
extends Enemy
## Things all three bosses share: an entrance, a second phase at half
## health, calling for help, and cleaning up when they fall.

const INTRO_TIME := 1.1

var phase := 1
var _steps_done := 0


func _on_spawn() -> void:
	_enter("intro")
	Sfx.play("boss_in")
	Game.shake(4.0)


## Call at the top of _think(). Switches to phase 2 at half health.
func _check_phase() -> void:
	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		_flash = 0.4
		Game.shake(5.0)
		Sfx.play("boss_in", 1.3)
		Fx.ring(room, position, 60.0, base_color, 0.5, 2.0)
		Fx.words(room, position - Vector2(0, radius + 6.0), "Enraged!", Pal.DANGER)
		_on_phase_two()


func _on_phase_two() -> void:
	pass


## Brings in helpers, but never more than "limit" of that kind at once.
func _summon(enemy_id: String, count: int, limit: int) -> void:
	var alive := 0
	for other: Enemy in room.enemies:
		if not other.dead and other.id == enemy_id:
			alive += 1
	for i in count:
		if alive >= limit:
			return
		alive += 1
		var away := Vector2.from_angle(Game.combat_rng.randf() * TAU)
		room.queue_spawn(enemy_id, position + away * (radius + 10.0), away * 140.0)


func _fire_single(dir: Vector2, shot_speed: float, life: float = 6.0) -> void:
	var shot := Shot.enemy_shot(room, position + dir * (radius * 0.6), dir, shot_speed, id)
	shot.life = life
	room.add_shot(shot)


func _die(info: Dictionary) -> void:
	if dead:
		return
	room.pull_strength = 0.0
	# Helpers leave with their boss.
	for other: Enemy in room.enemies:
		if other != self and not other.dead:
			other.dismiss()
	Sfx.play("boss_down")
	Fx.ring(room, position, 90.0, base_color, 0.7, 3.0)
	Fx.ring(room, position, 50.0, Pal.PAPER, 0.5, 2.0)
	super._die(info)
