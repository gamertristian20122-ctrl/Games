class_name Player
extends CharacterBody2D
## The keeper: walking, dashing, shooting and getting hurt.
##
## Who decides what the keeper does? Normally the human, through Controls.
## When "brain" is set, the test bot decides instead. Both fill in the same
## PlayerInput, so the bot plays by exactly the same rules as a person.

signal died(killer: String)
signal was_hurt
signal dashed

const BODY_RADIUS := 5.0
const HURT_RADIUS := 3.5        # smaller than the picture, to be forgiving
const ACCELERATION := 1100.0
const DASH_SPEED := 310.0
const DASH_TIME := 0.16
const HURT_INVULNERABLE := 1.0  # seconds of safety after being hit
const SHOT_GAP_DEGREES := 9.0
const MOTH_ORBIT := 22.0
const MOTH_REACH := 70.0          # how far from the keeper a moth will dart
const MOTH_LUNGE_TIME := 0.3

var room: Room
var brain: BotBrain = null
var input := PlayerInput.new()

var alive := true
var active := false             # false while rooms change or menus are up
var aim_dir := Vector2.RIGHT
var in_unison := false
var hits_this_room := 0
var shields_left := 0           # Oilskin Coat charges for this room
var tape: EchoTape = null       # what we are recording for the next room's echo

var _fire_cooldown := 0.0
var _walk := Vector2.ZERO          # the keeper's own walking speed
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_charges := 1
var _dash_recharge := 0.0
var _invulnerable := 0.0
var _dash_pressed := false
var _sprite: Sprite2D
var _moth_angle := 0.0
var _moths: Array[Sprite2D] = []
var _moth_rest: Array[float] = []     # seconds until each moth may bite again
var _moth_lunge: Array[float] = []    # seconds left of each moth's dart
var _moth_goal: Array[Vector2] = []   # where each moth is darting to
var _beam: BeaconBeam
var _unison_pulse := 0.0
var _trail_timer := 0.0


func _ready() -> void:
	z_index = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 8 | 16
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	_sprite = Sprites.sprite(Sprites.KEEPER, Pal.PAPER)
	add_child(_sprite)
	_beam = BeaconBeam.new()
	add_child(_beam)
	Game.items_changed.connect(_refresh_items)
	_refresh_items()


func _unhandled_input(event: InputEvent) -> void:
	# Remember the press so a quick tap between two game ticks is not lost.
	if event.is_action_pressed("dash"):
		_dash_pressed = true


## Puts the keeper at the start of a new room.
func enter_room(new_room: Room) -> void:
	room = new_room
	position = Room.ENTRY_POINT
	velocity = Vector2.ZERO
	_walk = Vector2.ZERO
	hits_this_room = 0
	shields_left = Game.stats.room_shields
	_dash_charges = Game.stats.dash_charges
	_dash_recharge = 0.0
	_dash_left = 0.0
	_invulnerable = 0.0
	in_unison = false
	tape = null
	reset_physics_interpolation()


func start_recording() -> void:
	tape = EchoTape.new()


## Stops recording and hands back the tape.
func stop_recording() -> EchoTape:
	var done := tape
	tape = null
	return done


func _physics_process(delta: float) -> void:
	if not alive or not active or room == null:
		velocity = Vector2.ZERO
		_dash_pressed = false
		return
	var stats := Game.stats
	_read_input()
	aim_dir = input.aim

	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_update_unison(stats, delta)
	_move(stats, delta)
	_shoot(stats, delta)
	_update_moths(stats, delta)
	_beam.tick(room, position, stats.beacon, stats.damage * _damage_bonus(stats), false, delta)

	if tape != null:
		tape.add(position, aim_dir.angle(), input.shoot, _dash_left > 0.0)
	_animate()


func _read_input() -> void:
	if brain != null:
		brain.think(self, room, input)
	else:
		Controls.read(input, global_position, get_global_mouse_position(), _dash_pressed)
	_dash_pressed = false
	if input.aim.length() < 0.01:
		input.aim = aim_dir


func _move(stats: PlayerStats, delta: float) -> void:
	# Dashes refill one at a time.
	if _dash_charges < stats.dash_charges:
		_dash_recharge += delta
		if _dash_recharge >= stats.dash_cooldown:
			_dash_recharge = 0.0
			_dash_charges += 1

	if input.dash and _dash_charges > 0 and _dash_left <= 0.0:
		_start_dash(stats)

	if _dash_left > 0.0:
		_dash_left -= delta
		_walk = _dash_dir * stats.move_speed
		velocity = _dash_dir * DASH_SPEED
		_trail_timer -= delta
		if _trail_timer <= 0.0 and not Game.fast_mode:
			_trail_timer = 0.03
			Fx.stamp(room, position, Sprites.KEEPER, Color(Pal.PAPER, 0.35), 0.2)
	else:
		_walk = _walk.move_toward(input.move.limit_length(1.0) * stats.move_speed, ACCELERATION * delta)
		velocity = _walk + room.drift_at(position)
	move_and_slide()


func _start_dash(stats: PlayerStats) -> void:
	_dash_dir = input.move.normalized() if input.move.length() > 0.2 else aim_dir
	_dash_left = DASH_TIME
	_dash_charges -= 1
	_invulnerable = maxf(_invulnerable, DASH_TIME + 0.07)
	Game.dashes_done += 1
	Sfx.play("dash")
	dashed.emit()
	if stats.foghorn > 0:
		var big := stats.two_tone > 0 and Game.dashes_done % 2 == 0
		Combat.foghorn_blast(room, position, stats, big)


func _shoot(stats: PlayerStats, delta: float) -> void:
	_fire_cooldown -= delta
	if not input.shoot or _fire_cooldown > 0.0 or room.state == "waiting":
		return
	_fire_cooldown = 1.0 / fire_rate_now(stats)
	Game.shots_fired += 1
	var every := stats.flare_every()
	var flare_now := every > 0 and Game.shots_fired % every == 0
	var count := stats.shot_count
	var bonus := _damage_bonus(stats)
	for i in count:
		var offset := (float(i) - float(count - 1) / 2.0) * deg_to_rad(SHOT_GAP_DEGREES)
		var dir := aim_dir.rotated(offset)
		var shot := Shot.keeper_shot(room, position + dir * 7.0, dir, stats, false, bonus)
		if flare_now and i == count / 2:
			shot.make_flare()
		room.add_shot(shot)
	Sfx.play("flare" if flare_now else "shoot")


## Shots per second right now, counting Unison and the Tin Kettle.
func fire_rate_now(stats: PlayerStats) -> float:
	var rate := stats.fire_rate
	if in_unison:
		rate *= 1.0 + stats.unison_fire_rate
	if stats.kettle > 0 and Game.hp <= 2:
		rate *= 1.0 + 0.4 * stats.kettle
	return rate


func _damage_bonus(stats: PlayerStats) -> float:
	var bonus := Game.log_bonus()
	if in_unison:
		bonus *= 1.0 + stats.unison_damage
	return bonus


## Unison: standing close to an echo makes you both stronger.
func _update_unison(stats: PlayerStats, delta: float) -> void:
	var was := in_unison
	in_unison = false
	for echo: Echo in room.echoes:
		if echo.solid and position.distance_to(echo.position) <= stats.unison_radius:
			in_unison = true
			break
	if in_unison and not was:
		Sfx.play("unison")
		Fx.ring(room, position, stats.unison_radius, Pal.ECHO, 0.3, 1.0)
	if in_unison:
		_unison_pulse += delta
		if _unison_pulse >= 0.6:
			_unison_pulse = 0.0
			Fx.ring(room, position, 12.0, Color(Pal.ECHO, 0.7), 0.35, 1.0)


# ----------------------------------------------------------------------
# Getting hurt
# ----------------------------------------------------------------------

## Something hit the keeper. Returns true if the hit "landed" (so a shot
## should disappear), false if the keeper was dashing or still flashing.
func take_hit(amount: int, source: String) -> bool:
	if not alive or not active or _invulnerable > 0.0 or Game.god_mode:
		return false
	if shields_left > 0:
		shields_left -= 1
		_invulnerable = 0.7
		Fx.words(room, position, "Blocked", Pal.PAPER)
		Fx.ring(room, position, 14.0, Pal.PAPER, 0.25)
		Sfx.play("blocked")
		if Game.stats.squall > 0:
			Combat.foghorn_blast(room, position, Game.stats, true)
		return true
	hits_this_room += 1
	_invulnerable = HURT_INVULNERABLE
	var dead := Game.lose_hp(amount, source)
	was_hurt.emit()
	Sfx.play("hurt")
	Game.shake(4.0)
	Controls.rumble(0.4, 0.7, 0.25)
	Fx.burst(room, position, Pal.HEART, 10, 90.0, 0.4, 1.6)
	if dead:
		alive = false
		velocity = Vector2.ZERO
		_sprite.modulate = Pal.DIM
		_sprite.rotation = PI / 2.0
		Sfx.play("death")
		died.emit(source)
	return true


func is_dashing() -> bool:
	return _dash_left > 0.0


func dash_ready() -> bool:
	return _dash_charges > 0 and _dash_left <= 0.0


func dash_charges() -> int:
	return _dash_charges


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


# ----------------------------------------------------------------------
# Items that follow the keeper around
# ----------------------------------------------------------------------

func _refresh_items() -> void:
	var want := Game.stats.moths
	while _moths.size() < want:
		var moth := Sprites.sprite(Vector2i(31, 5), Pal.EMBER)
		moth.scale = Vector2(0.7, 0.7)
		moth.z_index = 1
		add_child(moth)
		_moths.append(moth)
		_moth_rest.append(0.3 * _moths.size())
		_moth_lunge.append(0.0)
		_moth_goal.append(Vector2.ZERO)
	while _moths.size() > want:
		_moths.pop_back().queue_free()
		_moth_rest.pop_back()
		_moth_lunge.pop_back()
		_moth_goal.pop_back()


## Lamp Moths: circle the keeper, and dart out to bite any enemy that comes near.
func _update_moths(stats: PlayerStats, delta: float) -> void:
	if _moths.is_empty():
		return
	var quick := stats.moths_to_flame > 0
	_moth_angle += delta * (4.2 if quick else 2.8)
	var bite := stats.damage * 0.6 * _damage_bonus(stats)
	for i in _moths.size():
		var home := Vector2.from_angle(_moth_angle + TAU * float(i) / float(_moths.size())) * MOTH_ORBIT
		_moths[i].flip_h = int(_moth_angle * 3.0) % 2 == 0

		if _moth_lunge[i] > 0.0:
			# Out and back: the moth reaches the enemy halfway through.
			_moth_lunge[i] -= delta
			var t := clampf(1.0 - _moth_lunge[i] / MOTH_LUNGE_TIME, 0.0, 1.0)
			var out_and_back := 1.0 - absf(t * 2.0 - 1.0)
			_moths[i].position = home.lerp(_moth_goal[i] - position, out_and_back)
			continue

		_moths[i].position = home
		_moth_rest[i] -= delta
		if _moth_rest[i] > 0.0:
			continue
		var target := room.nearest_enemy(position, MOTH_REACH)
		if target == null:
			continue
		_moth_rest[i] = 0.55 if quick else 0.85
		_moth_lunge[i] = MOTH_LUNGE_TIME
		_moth_goal[i] = target.position
		target.take_hit(bite, {"dir": (target.position - position).normalized(), "knock": 20.0, "crit": false, "source": "moth"})
		if quick and not target.dead:
			target.set_burning(maxf(stats.burn_dps, 6.0), Combat.BURN_TIME)
		Fx.burst(room, target.position, Pal.EMBER, 3, 40.0, 0.2, 1.0)


func _animate() -> void:
	if absf(velocity.x) > 5.0:
		_sprite.flip_h = velocity.x < 0.0
	var c := Pal.PAPER
	if in_unison:
		c = c.lerp(Pal.ECHO, 0.45)
	# Blink while safe after a hit.
	if _invulnerable > 0.0 and _dash_left <= 0.0:
		c.a = 0.35 if int(_invulnerable * 14.0) % 2 == 0 else 1.0
	_sprite.modulate = c


## The Beacon item: a beam of light that sweeps in a circle.
## The echo can carry one too (the Twin Lights combo).
class BeaconBeam extends Node2D:
	var angle := 0.0
	var reach := 0.0
	var beam_color := Pal.EMBER

	func tick(room: Room, at: Vector2, level: int, base_damage: float, from_echo: bool, delta: float) -> void:
		var new_reach := 0.0 if level <= 0 else 62.0 + 20.0 * level
		if new_reach != reach:
			reach = new_reach
			queue_redraw()
		if level <= 0:
			return
		angle += delta * 2.6
		rotation = angle
		var tip := at + Vector2.from_angle(angle) * reach
		for enemy: Enemy in room.enemies:
			if enemy.dead or not enemy.targetable or enemy.beam_cooldown > 0.0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position, at, tip)
			var touch := enemy.radius + 3.0
			if closest.distance_squared_to(enemy.position) <= touch * touch:
				enemy.beam_cooldown = 0.8
				enemy.take_hit(base_damage * (1.0 + 0.6 * level), {
					"dir": Vector2.from_angle(angle), "knock": 30.0, "crit": false,
					"source": "echo_beacon" if from_echo else "beacon",
				})
				enemy.set_burning(maxf(Game.stats.burn_dps, 4.0), 1.5)
				Fx.burst(room, enemy.position, beam_color, 4, 50.0, 0.2, 1.2)

	func _draw() -> void:
		if reach <= 0.0:
			return
		draw_line(Vector2(8, 0), Vector2(reach, 0), Color(beam_color, 0.28), 5.0)
		draw_line(Vector2(8, 0), Vector2(reach, 0), Color(beam_color, 0.8), 1.0)
