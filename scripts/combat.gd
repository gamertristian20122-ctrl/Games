class_name Combat
## What happens when the keeper's attacks land: burning, soaking, chilling,
## lightning, explosions and the echo's Afterglow bursts.
##
## Shots, moths, the beacon and blasts all come through here, so an item
## effect only has to be written once.

const BURN_TIME := 3.0
const BRINE_TIME := 4.0
const CHILL_TIME := 3.0
const RESONANCE_WINDOW := 1.0     # seconds between the two hits
const RESONANCE_COOLDOWN := 0.6
const CHAIN_RANGE := 72.0


## A keeper or echo shot has hit an enemy.
static func shot_hit(room: Room, enemy: Enemy, amount: float, shot: Shot) -> void:
	var stats := shot.stats
	var source := "echo" if shot.from_echo else "shot"
	enemy.take_hit(amount, {
		"dir": shot.velocity.normalized(), "knock": stats.knockback,
		"crit": shot.crit, "source": source,
	})
	apply_statuses(enemy, stats)
	_count_hit(room, enemy, stats)
	_check_resonance(room, enemy, stats, shot.from_echo)
	if not Game.fast_mode:
		Fx.burst(room, shot.position, shot.color, 4, 55.0, 0.22, 1.2)
		Sfx.play("crit" if shot.crit else "hit")
		if shot.crit:
			Fx.words(room, enemy.position - Vector2(0, 6), "!", Pal.GOLD)


## Sets an enemy burning, soaked or chilled, depending on the keeper's items.
static func apply_statuses(enemy: Enemy, stats: PlayerStats) -> void:
	if enemy.dead:
		return
	if stats.burn_dps > 0.0:
		enemy.set_burning(stats.burn_dps, BURN_TIME)
	if stats.brine > 0.0:
		enemy.brine_amount = maxf(enemy.brine_amount, stats.brine)
		enemy.brine_time = BRINE_TIME
	if stats.chill > 0.0:
		enemy.chill_amount = maxf(enemy.chill_amount, stats.chill)
		enemy.chill_time = CHILL_TIME


## Storm Glass: every few hits, lightning strikes the enemy and arcs on.
static func _count_hit(room: Room, enemy: Enemy, stats: PlayerStats) -> void:
	Game.hits_landed += 1
	var every := stats.shock_every()
	if every <= 0 or Game.hits_landed % every != 0:
		return
	var amount := stats.shock_damage()
	var struck: Dictionary = {}
	var from := enemy.position + Vector2(randf_range(-20, 20), -70.0)
	var current := enemy
	for jump in 3:
		if current == null:
			break
		struck[current.get_instance_id()] = true
		Fx.bolt(room, from, current.position, Pal.SHOCK)
		from = current.position
		if stats.black_ice > 0 and current.chill_time > 0.0:
			current.stun_time = maxf(current.stun_time, 1.5)
			Fx.stamp(room, current.position, Sprites.SPARKLE, Pal.CHILL, 0.5)
		current.take_hit(amount, {"dir": Vector2.ZERO, "knock": 0.0, "crit": false, "source": "lightning"})
		amount *= 0.6
		current = room.nearest_enemy(from, 64.0, struck)
	Sfx.play("zap")
	Game.shake(1.5)


## Afterglow: the keeper and an echo hitting the same enemy close together.
static func _check_resonance(room: Room, enemy: Enemy, stats: PlayerStats, from_echo: bool) -> void:
	var now := room.clock
	if from_echo:
		enemy.last_echo_hit = now
	else:
		enemy.last_keeper_hit = now
	if stats.resonance <= 0 or enemy.dead:
		return
	if absf(enemy.last_echo_hit - enemy.last_keeper_hit) > RESONANCE_WINDOW:
		return
	if now - enemy.last_resonance < RESONANCE_COOLDOWN:
		return
	enemy.last_resonance = now
	var radius := 30.0 * (2.0 if stats.choir > 0 else 1.0)
	var amount := 10.0 + 12.0 * stats.resonance
	Fx.ring(room, enemy.position, radius, Pal.ECHO, 0.35, 2.0)
	Fx.ring(room, enemy.position, radius * 0.7, Pal.EMBER, 0.3, 1.0)
	Sfx.play("unison", 1.4)
	blast(room, enemy.position, radius, amount, "afterglow", 0.0, false)


## Hurts every enemy inside a circle.
static func blast(room: Room, center: Vector2, radius: float, amount: float, source: String, knock: float, burn: bool) -> int:
	var count := 0
	for enemy: Enemy in room.enemies:
		if enemy.dead or not enemy.targetable:
			continue
		var reach := radius + enemy.radius
		if center.distance_squared_to(enemy.position) > reach * reach:
			continue
		var dir := (enemy.position - center).normalized()
		enemy.take_hit(amount, {"dir": dir, "knock": knock, "crit": false, "source": source})
		if burn and not enemy.dead:
			enemy.set_burning(maxf(Game.stats.burn_dps, 6.0), BURN_TIME)
		count += 1
	return count


## Signal Flare (and anything else that explodes).
static func explosion(room: Room, center: Vector2, radius: float, amount: float, source: String, burn: bool, color: Color) -> void:
	Fx.ring(room, center, radius, color, 0.32, 2.0)
	Fx.burst(room, center, color, 14, 110.0, 0.4, 2.0)
	Sfx.play("explode")
	Game.shake(2.5)
	blast(room, center, radius, amount, source, 90.0, burn)


## Foghorn: shoves enemies away, hurts a little, and wipes out enemy shots.
static func foghorn_blast(room: Room, center: Vector2, stats: PlayerStats, big: bool) -> void:
	var level := maxi(stats.foghorn, 1)
	var radius := 30.0 + 8.0 * level
	if big:
		radius *= 2.0
	Fx.ring(room, center, radius, Pal.PAPER, 0.3, 2.0)
	Fx.ring(room, center, radius * 0.6, Pal.DIM, 0.25, 1.0)
	Sfx.play("foghorn", 0.8 if big else 1.0)
	Game.shake(3.0 if big else 1.5)
	for enemy: Enemy in room.enemies:
		if enemy.dead or not enemy.targetable:
			continue
		var reach := radius + enemy.radius
		if center.distance_squared_to(enemy.position) > reach * reach:
			continue
		var dir := (enemy.position - center).normalized()
		enemy.take_hit(8.0 + 6.0 * level, {"dir": dir, "knock": 230.0, "crit": false, "source": "foghorn"})
		if big and not enemy.dead:
			enemy.stun_time = maxf(enemy.stun_time, 1.0)
	room.clear_enemy_shots(center, radius)


## Called when an enemy dies, for effects that trigger on death.
static func enemy_died(room: Room, enemy: Enemy) -> void:
	var stats := Game.stats
	# Salt Fire: soaked enemies that die on fire explode and spread the fire.
	if stats.salt_fire > 0 and enemy.burn_time > 0.0 and enemy.brine_time > 0.0:
		room.queue_explosion(enemy.position, 30.0, 14.0 + stats.burn_dps * 2.0, "salt_fire", true, Pal.BURN)
