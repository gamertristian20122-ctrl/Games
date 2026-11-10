class_name BossDiver
extends Boss
## Floor 2 boss: a haunted diving suit.
## It plods toward you firing fast harpoons, stomps out rings of shots, then
## sprays a turning spiral from its air hose. Keep moving in circles.

var _rings_left := 0
var _ring_timer := 0.0
var _hose_angle := 0.0
var _hose_timer := 0.0


func _think(delta: float) -> void:
	_check_phase()
	var dir := (_target_pos() - position).normalized()
	match state:
		"intro":
			move_velocity = Vector2.ZERO
			if state_time >= INTRO_TIME:
				_enter("walk")
		"walk":
			move_velocity = _path_dir() * speed * (1.3 if phase == 2 else 1.0)
			shot_timer -= delta
			if shot_timer <= 0.45 and not _warned:
				_warned = true
				_flash = 0.45
			if shot_timer <= 0.0:
				_warned = false
				shot_timer = 1.25
				_fire_fan(dir, 150.0, 1 if phase == 1 else 2, 12.0)
			if state_time >= 3.0:
				_enter("brace")
				Sfx.play("warn")
		"brace":
			move_velocity = Vector2.ZERO
			_flash = 0.05
			if state_time >= 0.6:
				_rings_left = 3 if phase == 1 else 4
				_ring_timer = 0.0
				_steps_done = 0
				_enter("stomp")
		"stomp":
			move_velocity = Vector2.ZERO
			_ring_timer -= delta
			if _ring_timer <= 0.0 and _rings_left > 0:
				_rings_left -= 1
				_ring_timer = 0.4
				var count := 14
				_fire_ring(count, 55.0 + 14.0 * _steps_done, (PI / count) * (_steps_done % 2))
				_steps_done += 1
				Fx.ring(room, position, 36.0, base_color, 0.3, 2.0)
				Game.shake(2.5)
			if _rings_left <= 0 and _ring_timer <= 0.0:
				_hose_timer = 0.0
				_enter("hose")
		"hose":
			move_velocity = _path_dir() * speed * 0.4
			_hose_angle += delta * 1.7 * _side
			_hose_timer -= delta
			if _hose_timer <= 0.0:
				_hose_timer = 0.13
				var arms := 2 if phase == 1 else 3
				for arm in arms:
					_fire_single(Vector2.from_angle(_hose_angle + TAU * float(arm) / float(arms)), 68.0)
				Sfx.play("enemy_shoot")
			if state_time >= 2.6:
				_side = -_side
				_enter("rest")
		"rest":
			move_velocity = Vector2.ZERO
			if state_time >= (0.9 if phase == 1 else 0.6):
				_enter("walk")
		_:
			_enter("walk")
