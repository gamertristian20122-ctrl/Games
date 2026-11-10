class_name BossClatterclaw
extends Boss
## Floor 1 boss: a giant crab.
## It scuttles sideways spitting fans of shots, then rushes across the room.
## When the rush ends it slams down and throws a ring of shots.
## Below half health it rushes twice and calls Clawlings.

const RUSH_SPEED := 195.0

var _rushes_left := 0
var _turned_at := 0.0


func _think(delta: float) -> void:
	_check_phase()
	var to := _target_pos() - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	match state:
		"intro":
			move_velocity = Vector2.ZERO
			if state_time >= INTRO_TIME:
				_enter("scuttle")
		"scuttle":
			# Crab walk: mostly sideways, drifting in or out to keep its distance.
			var radial := 0.0
			if dist > 115.0:
				radial = 0.7
			elif dist < 70.0:
				radial = -0.7
			move_velocity = (dir.orthogonal() * _side + dir * radial).normalized() * speed
			if is_on_wall() and state_time - _turned_at > 0.5:
				_side = -_side
				_turned_at = state_time
			shot_timer -= delta
			if shot_timer <= 0.0:
				shot_timer = 1.1 if phase == 1 else 0.8
				_fire_fan(dir, 78.0, 3, 16.0)
			if state_time >= 2.4:
				_rushes_left = 1 if phase == 1 else 2
				_turned_at = 0.0
				_enter("windup")
				Sfx.play("warn")
		"windup":
			move_velocity = Vector2.ZERO
			if state_time < 0.45:
				facing = dir
			_aim_line = facing * 200.0
			_flash = 0.05
			queue_redraw()
			if state_time >= 0.85:
				_aim_line = Vector2.ZERO
				queue_redraw()
				_enter("rush")
		"rush":
			move_velocity = facing * RUSH_SPEED
			if (state_time > 0.1 and is_on_wall()) or state_time > 1.2:
				_slam()
				_rushes_left -= 1
				if _rushes_left > 0:
					_enter("windup")
					Sfx.play("warn")
				else:
					_enter("rest")
		"rest":
			move_velocity = Vector2.ZERO
			if state_time >= (1.2 if phase == 1 else 0.85):
				if phase == 2:
					_summon("clawling", 2, 4)
				_enter("scuttle")
		_:
			_enter("scuttle")


func _slam() -> void:
	var count := 10 if phase == 1 else 14
	_fire_ring(count, 66.0, Game.combat_rng.randf() * TAU)
	Fx.ring(room, position, 40.0, base_color, 0.35, 2.0)
	Sfx.play("explode")
	Game.shake(4.0)
