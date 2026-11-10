class_name BossUndertow
extends Boss
## Floor 3 boss: the giant octopus that stole the flame.
## It cycles through four attacks:
##   arms  - turning lines of shots, like tentacles sweeping the room
##   ink   - fans of shots aimed at you
##   tide  - a wall of shots crossing the room with gaps to slip through
##   pull  - it drags you toward itself while throwing slow rings
## Below half health everything gets denser and it calls Cave Eels.

const ORDER := ["arms", "ink", "tide", "pull"]

var _pattern := -1
var _spin := 0.0
var _timer := 0.0
var _count := 0
var _tide_from_left := true


func _think(delta: float) -> void:
	_check_phase()
	var dir := (_target_pos() - position).normalized()
	var frenzy := hp <= max_hp * 0.25
	match state:
		"intro":
			move_velocity = Vector2.ZERO
			if state_time >= INTRO_TIME:
				_next_pattern()
		"arms":
			_drift(1.0)
			_spin += delta * (0.85 if phase == 1 else 1.05) * _side
			_timer -= delta
			if _timer <= 0.0:
				_timer = 0.15
				var arms := 4 if phase == 1 else 5
				for arm in arms:
					_fire_single(Vector2.from_angle(_spin + TAU * float(arm) / float(arms)), 70.0)
				Sfx.play("enemy_shoot")
			if frenzy:
				shot_timer -= delta
				if shot_timer <= 0.0:
					shot_timer = 0.8
					_fire_fan(dir, 100.0, 1, 0.0)
			if state_time >= 3.2:
				_side = -_side
				_enter("pause")
		"ink":
			_drift(0.5)
			_timer -= delta
			if _timer <= 0.3 and not _warned:
				_warned = true
				_flash = 0.3
			if _timer <= 0.0:
				_warned = false
				_timer = 0.6
				_count += 1
				_fire_fan(dir, 95.0, 5 if phase == 1 else 7, 13.0)
			if _count >= (3 if phase == 1 else 4):
				_enter("pause")
		"tide":
			move_velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				_timer = 1.7 if phase == 1 else 1.35
				_count += 1
				_send_tide()
			if _count >= (2 if phase == 1 else 3) and _timer <= 0.6:
				_enter("pause")
		"pull":
			move_velocity = Vector2.ZERO
			room.pull_center = position
			room.pull_strength = 44.0 if phase == 1 else 56.0
			_timer -= delta
			if _timer <= 0.0:
				_timer = 0.8
				_count += 1
				_fire_ring(10 if phase == 1 else 12, 50.0, (PI / 10.0) * (_count % 2))
			if state_time >= 2.7:
				room.pull_strength = 0.0
				if phase == 2:
					_summon("eel", 2, 3)
				_enter("pause")
		"pause":
			_drift(0.6)
			if state_time >= (0.9 if phase == 1 else 0.6):
				_next_pattern()
		_:
			_enter("pause")


func _next_pattern() -> void:
	_pattern = (_pattern + 1) % ORDER.size()
	_timer = 0.5
	_count = 0
	_warned = false
	_enter(ORDER[_pattern])
	if ORDER[_pattern] == "pull" or ORDER[_pattern] == "tide":
		Sfx.play("warn")
		_flash = 0.3


## Floats slowly around the middle of the room.
func _drift(amount: float) -> void:
	var goal := Room.CENTER + Vector2(cos(age * 0.4) * 95.0, sin(age * 0.55) * 46.0)
	move_velocity = (goal - position).limit_length(speed * amount)


## A wall of shots from one side of the room, with gaps to slip through.
func _send_tide() -> void:
	var from_left := _tide_from_left
	_tide_from_left = not _tide_from_left
	var x := 22.0 if from_left else Room.COLS * Room.T - 22.0
	var dir := Vector2.RIGHT if from_left else Vector2.LEFT
	var shot_speed := 60.0 if phase == 1 else 72.0
	var gap_a := Game.combat_rng.randf_range(44.0, 110.0)
	var gap_b := Game.combat_rng.randf_range(130.0, 196.0)
	var y := 22.0
	while y < Room.ROWS * Room.T - 20.0:
		if absf(y - gap_a) > 19.0 and absf(y - gap_b) > 19.0:
			var shot := Shot.enemy_shot(room, Vector2(x, y), dir, shot_speed, id)
			shot.life = 9.0
			room.add_shot(shot)
		y += 11.0
	Sfx.play("enemy_shoot", 0.7)
	Game.shake(1.5)
