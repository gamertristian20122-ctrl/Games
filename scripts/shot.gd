class_name Shot
extends Node2D
## One projectile flying across the room.
## The keeper's and the echo's shots hurt enemies; enemy shots hurt the keeper.

const KEEPER := 0
const ENEMY := 1
const MAX_STEP := 5.0          # never move farther than this in one check
const BASE_RADIUS := 2.5

var team := KEEPER
var velocity := Vector2.ZERO
var damage := 10.0
var radius := BASE_RADIUS
var life := 0.85
var color := Pal.EMBER
var room: Room

# --- Keeper / echo shots ---
var stats: PlayerStats
var from_echo := false
var crit := false
var pierce_left := 0
var bounces_left := 0
var chains_left := 0
var shard_level := 0           # 0 = a normal shot, 1 = a Prism shard, 2 = shard of a shard
var is_flare := false
var bounces_done := 0
var travelled := 0.0

# --- Enemy shots ---
var source := ""               # which enemy fired it

var _already_hit: Dictionary = {}
var _gone := false


## Builds a shot fired by the keeper (or by an echo) from the keeper's stats.
static func keeper_shot(in_room: Room, from: Vector2, dir: Vector2, with_stats: PlayerStats, echo: bool, damage_mult: float) -> Shot:
	var s := Shot.new()
	s.team = KEEPER
	s.room = in_room
	s.stats = with_stats
	s.from_echo = echo
	s.position = from
	s.velocity = dir * with_stats.shot_speed
	s.life = with_stats.shot_life
	s.radius = BASE_RADIUS * with_stats.shot_size
	s.damage = with_stats.damage * damage_mult
	s.pierce_left = with_stats.pierce
	s.bounces_left = with_stats.bounce
	s.chains_left = with_stats.chain
	s.color = Pal.ECHO if echo else Pal.EMBER
	if with_stats.crit_chance > 0.0 and Game.combat_rng.randf() < with_stats.crit_chance:
		s.crit = true
		s.damage *= with_stats.crit_mult
		if with_stats.trotline > 0:
			s.chains_left += 2
	return s


## Builds a shot fired by an enemy.
static func enemy_shot(in_room: Room, from: Vector2, dir: Vector2, speed: float, fired_by: String) -> Shot:
	var s := Shot.new()
	s.team = ENEMY
	s.room = in_room
	s.position = from
	s.velocity = dir * speed
	s.life = 6.0
	s.radius = 3.0
	s.damage = 1.0
	s.color = Pal.DANGER
	s.source = fired_by
	return s


## Signal Flare: turns this shot into a slow, fat flare that explodes.
func make_flare() -> void:
	is_flare = true
	radius = maxf(radius * 1.6, 4.0)
	velocity *= 0.85
	pierce_left = 0
	chains_left = 0


func _ready() -> void:
	z_index = 3
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if _gone:
		return
	life -= delta
	if life <= 0.0:
		_fade_out()
		return
	if team == KEEPER and stats.homing > 0.0 and not is_flare:
		_steer(delta)

	var total := velocity * delta
	var steps := maxi(1, int(ceil(total.length() / MAX_STEP)))
	var step := total / float(steps)
	for i in steps:
		if not _advance(step):
			return
	rotation = velocity.angle()


## Moves one small step. Returns false if the shot is gone afterwards.
func _advance(step: Vector2) -> bool:
	var next := position + step
	if room.blocks_shot(next):
		if team == KEEPER and bounces_left > 0 and not is_flare:
			bounces_left -= 1
			bounces_done += 1
			var blocked_x := room.blocks_shot(position + Vector2(step.x, 0.0))
			var blocked_y := room.blocks_shot(position + Vector2(0.0, step.y))
			if blocked_x or not blocked_y:
				velocity.x = -velocity.x
			if blocked_y or not blocked_x:
				velocity.y = -velocity.y
			_already_hit.clear()     # a bounced shot may hit the same enemy again
			Fx.burst(room, position, color, 3, 40.0, 0.2, 1.0)
			return true
		_hit_wall()
		return false
	position = next
	travelled += step.length()
	if team == KEEPER:
		return _check_enemies()
	return _check_keeper()


func _check_enemies() -> bool:
	for enemy: Enemy in room.enemies:
		if enemy.dead or not enemy.targetable:
			continue
		if _already_hit.has(enemy.get_instance_id()):
			continue
		var reach := radius + enemy.radius
		if position.distance_squared_to(enemy.position) > reach * reach:
			continue
		if not _strike(enemy):
			return false
	return true


## Hits one enemy. Returns false if the shot is used up.
func _strike(enemy: Enemy) -> bool:
	_already_hit[enemy.get_instance_id()] = true
	if is_flare:
		_explode()
		return false

	var amount := damage
	if stats.hall_of_mirrors > 0:
		amount *= 1.0 + 0.3 * mini(bounces_done, 4)
	if stats.slingstone > 0:
		amount *= 1.0 + 0.4 * clampf(travelled / 180.0, 0.0, 1.0)
	Combat.shot_hit(room, enemy, amount, self)

	# Prism: break into shards.
	var max_level := 2 if stats.kaleidoscope > 0 else 1
	if stats.split > 0 and shard_level < max_level:
		_spawn_shards(enemy)

	# Fishing Line: jump to another enemy nearby.
	if chains_left > 0:
		var reach := Combat.CHAIN_RANGE * (1.6 if stats.true_north > 0 else 1.0)
		var target := room.nearest_enemy(position, reach, _already_hit)
		if target != null:
			chains_left -= 1
			damage *= 0.8
			velocity = (target.position - position).normalized() * velocity.length()
			life = maxf(life, 0.4)
			Fx.bolt(room, position, target.position, Color(color, 0.5))
			return true

	# Burning Glass: carry on through.
	if pierce_left > 0:
		pierce_left -= 1
		return true

	_vanish()
	return false


func _spawn_shards(enemy: Enemy) -> void:
	if room.keeper_shot_count() > 220:
		return   # safety valve so wild builds cannot flood the room
	var count := (1 + stats.split) if shard_level == 0 else 2
	var base := velocity.angle()
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / float(count - 1)) * 2.0 - 1.0
		var dir := Vector2.from_angle(base + t * deg_to_rad(55.0))
		var shard := Shot.new()
		shard.team = KEEPER
		shard.room = room
		shard.stats = stats
		shard.from_echo = from_echo
		shard.position = position
		shard.velocity = dir * velocity.length() * 0.9
		shard.life = 0.32
		shard.radius = maxf(radius * 0.65, 1.5)
		shard.damage = damage * 0.4
		shard.color = color
		shard.shard_level = shard_level + 1
		shard._already_hit[enemy.get_instance_id()] = true
		room.add_shot(shard)


func _explode() -> void:
	var radius_out := 30.0 * (1.5 if stats.powder_keg > 0 else 1.0)
	_gone = true
	Combat.explosion(room, position, radius_out, damage * 2.5, "flare", stats.powder_keg > 0, color)
	queue_free()


## Brass Compass: lean toward the closest enemy in front of the shot.
func _steer(delta: float) -> void:
	var best: Enemy = null
	var best_d := 110.0 * 110.0
	var heading := velocity.normalized()
	for enemy: Enemy in room.enemies:
		if enemy.dead or not enemy.targetable or _already_hit.has(enemy.get_instance_id()):
			continue
		var to := enemy.position - position
		var d := to.length_squared()
		if d < best_d and heading.dot(to.normalized()) > 0.25:
			best_d = d
			best = enemy
	if best == null:
		return
	var want := (best.position - position).angle()
	var now := velocity.angle()
	var turn := clampf(wrapf(want - now, -PI, PI), -stats.homing * delta, stats.homing * delta)
	velocity = velocity.rotated(turn)


func _check_keeper() -> bool:
	var keeper := room.keeper
	if keeper == null or not keeper.alive:
		return true
	# Breakwater: enemy shots break against the echo.
	if Game.stats.echo_blocks > 0:
		for echo: Echo in room.echoes:
			if echo.solid and position.distance_squared_to(echo.position) <= 49.0:
				Fx.burst(room, position, Pal.ECHO, 4, 40.0, 0.2, 1.0)
				_vanish()
				return false
	var reach := radius + Player.HURT_RADIUS
	if position.distance_squared_to(keeper.position) <= reach * reach:
		if keeper.take_hit(int(damage), source):
			_vanish()
			return false
	return true


func _hit_wall() -> void:
	if is_flare:
		_explode()
		return
	Fx.burst(room, position, color, 3, 35.0, 0.18, 1.0)
	_vanish()


func _fade_out() -> void:
	if is_flare:
		_explode()
		return
	_vanish()


func _vanish() -> void:
	_gone = true
	queue_free()


## Removes the shot quietly (used when the foghorn wipes enemy shots).
func cancel() -> void:
	if not _gone:
		Fx.burst(room, position, color, 3, 35.0, 0.2, 1.0)
		_vanish()


func is_gone() -> bool:
	return _gone


func _draw() -> void:
	var r := radius
	if team == KEEPER:
		if is_flare:
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), color)
			draw_rect(Rect2(-r * 0.5, -r * 0.5, r, r), Color.WHITE)
			draw_rect(Rect2(-r * 2.6, -r * 0.4, r * 1.6, r * 0.8), Color(color, 0.5))
			return
		# A small ember with a short tail behind it.
		draw_rect(Rect2(-r * 2.4, -r * 0.45, r * 1.5, r * 0.9), Color(color, 0.4))
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), color)
		if crit:
			draw_rect(Rect2(-r * 0.6, -r * 0.6, r * 1.2, r * 1.2), Color.WHITE)
	else:
		# A plus-shaped blob that reads as round at this size.
		draw_rect(Rect2(-r, -r * 0.5, r * 2.0, r), color)
		draw_rect(Rect2(-r * 0.5, -r, r, r * 2.0), color)
		draw_rect(Rect2(-r * 0.35, -r * 0.35, r * 0.7, r * 0.7), Color.WHITE)
