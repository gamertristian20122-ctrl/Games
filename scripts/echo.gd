class_name Echo
extends Node2D
## The echo: a ghost of the keeper that replays the room before this one.
##
## It walks where you walked and holds the trigger when you held it. It uses
## your CURRENT items, so a stronger keeper has a stronger echo. Standing
## close to it puts you "in Unison", which makes you fire faster.

const FADE_TICKS := 14

var tape: EchoTape
var room: Room
var solid := false              # false while fading in or out
var radius := 7.0

var _tick := 0
var _fire_cooldown := 0.0
var _sprite: Sprite2D
var _alpha := 0.0
var _leaving := false
var _beam: Player.BeaconBeam
var _aim := Vector2.RIGHT


func setup(with_tape: EchoTape, in_room: Room) -> void:
	tape = with_tape
	room = in_room


func _ready() -> void:
	z_index = 1
	_sprite = Sprites.sprite(Sprites.KEEPER, Pal.ECHO)
	add_child(_sprite)
	_beam = Player.BeaconBeam.new()
	_beam.beam_color = Pal.ECHO
	add_child(_beam)
	if tape != null and tape.size() > 0:
		position = tape.pos[0]
	modulate.a = 0.0


func _physics_process(delta: float) -> void:
	if tape == null or tape.size() == 0:
		return
	if _leaving:
		_alpha = maxf(_alpha - delta * 2.5, 0.0)
		modulate.a = _alpha
		solid = false
		if _alpha <= 0.0:
			queue_free()
		return

	var size := tape.size()
	var i := _tick % size
	var previous := position
	position = tape.pos[i]
	if i == 0 and _tick > 0:
		reset_physics_interpolation()   # the tape looped: jump, do not slide
	if absf(position.x - previous.x) > 2.0:
		_sprite.flip_h = position.x < previous.x

	# Fade at both ends of the tape so the loop is not a hard pop.
	var edge := mini(i, size - 1 - i)
	var want := clampf(float(edge) / float(FADE_TICKS), 0.0, 1.0) * 0.62
	_alpha = move_toward(_alpha, want, delta * 3.0)
	modulate.a = _alpha
	solid = _alpha > 0.3

	var stats := Game.stats
	_aim = Vector2.from_angle(tape.aim[i])
	if stats.echo_autoaim > 0:
		var target := room.nearest_enemy(position, 170.0)
		if target != null:
			_aim = (target.position - position).normalized()

	_fire_cooldown -= delta
	var held := (tape.flags[i] & EchoTape.SHOOTING) != 0
	if solid and held and _fire_cooldown <= 0.0 and room.state == "fighting" and not room.enemies.is_empty():
		_fire(stats)

	var beam_level := stats.beacon if stats.twin_lights > 0 else 0
	_beam.tick(room, position, beam_level if solid else 0, stats.damage * stats.echo_damage, true, delta)
	_tick += 1


func _fire(stats: PlayerStats) -> void:
	_fire_cooldown = 1.0 / stats.fire_rate
	var power := stats.echo_damage
	var in_unison := room.keeper != null and room.keeper.in_unison
	if stats.standing_wave > 0 and in_unison:
		power *= 1.5
	var count := stats.shot_count
	for n in count:
		var offset := (float(n) - float(count - 1) / 2.0) * deg_to_rad(Player.SHOT_GAP_DEGREES)
		var dir := _aim.rotated(offset)
		var shot := Shot.keeper_shot(room, position + dir * 7.0, dir, stats, true, power)
		if stats.standing_wave > 0 and in_unison:
			shot.pierce_left += 1
		room.add_shot(shot)
	Sfx.play("echo_shoot", 1.3)


## Called when the room is cleared: the echo's work is done.
func fade_away() -> void:
	_leaving = true
