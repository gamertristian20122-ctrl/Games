class_name Enemy
extends CharacterBody2D
## One enemy. Its numbers come from scripts/data/enemy_db.gd and its "ai"
## setting picks which of the behaviours below it uses.
## Bosses are also enemies; their scripts (scripts/bosses/) extend this one.

signal died(enemy: Enemy)

const LAYER_WALLS := 1
const LAYER_ENEMY := 4
const LAYER_TALL := 8
const LAYER_LOW := 16
const SPAWN_GRACE := 0.45       # seconds after appearing before it can act or hurt

var id := ""
var def: Dictionary = {}
var room: Room
var display_name := ""
var ai := "chase"
var is_boss := false

var max_hp := 10.0
var hp := 10.0
var speed := 40.0
var radius := 6.0
var flying := false
var touch_damage := 1
var base_color := Color.WHITE
var dead := false
var targetable := true

# --- What the keeper's items have done to it ---
var burn_time := 0.0
var burn_dps := 0.0
var brine_time := 0.0
var brine_amount := 0.0
var chill_time := 0.0
var chill_amount := 0.0
var stun_time := 0.0
var last_keeper_hit := -100.0
var last_echo_hit := -100.0
var last_resonance := -100.0
var moth_cooldown := 0.0
var beam_cooldown := 0.0

# --- Behaviour ---
var age := 0.0
var state := ""
var state_time := 0.0
var shot_timer := 1.0
var move_velocity := Vector2.ZERO    # where it wants to go
var knock := Vector2.ZERO            # shove from being hit
var facing := Vector2.RIGHT
var chases_echo: Echo = null         # Painted Buoy: fooled into chasing an echo
var hp_scale := 1.0
var danger := 1.0                    # speeds up its shots and how often it fires

var _sprite: Sprite2D
var _frames: Array = []
var _frame_time := 0.0
var _flash := 0.0
var _burn_tick := 0.0
var _wobble := 0.0
var _side := 1.0
var _aim_line := Vector2.ZERO        # warning line drawn before a charge
var _warned := false
var _goal := Vector2.ZERO
var _taunt_timer := 0.0


## Fills in the enemy from its entry in enemy_db.gd. Call before adding it to the room.
func setup(enemy_id: String, in_room: Room, health_scale: float) -> void:
	id = enemy_id
	def = EnemyDB.get_enemy(enemy_id)
	room = in_room
	hp_scale = health_scale
	display_name = def.get("name", enemy_id)
	ai = def.get("ai", "chase")
	is_boss = def.get("boss", false)
	max_hp = float(def.get("hp", 10.0)) * health_scale
	hp = max_hp
	danger = Game.danger()
	speed = float(def.get("speed", 40.0)) * (1.0 + (danger - 1.0) * 0.5)
	radius = float(def.get("radius", 6.0))
	flying = def.get("flying", false)
	base_color = def.get("color", Color.WHITE)
	_frames = def.get("frames", [Vector2i(18, 7)])


func _ready() -> void:
	z_index = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WALLS if flying else (LAYER_WALLS | LAYER_TALL | LAYER_LOW)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius - 1.5, 2.0)
	shape.shape = circle
	add_child(shape)

	_sprite = Sprites.sprite(_frames[0], base_color)
	var s := float(def.get("scale", 1.0))
	_sprite.scale = Vector2(s, s)
	add_child(_sprite)

	_wobble = Game.combat_rng.randf() * TAU
	_side = 1.0 if Game.combat_rng.randf() < 0.5 else -1.0
	shot_timer = float(def.get("shot_every", 2.0)) * Game.combat_rng.randf_range(0.5, 1.0)
	_on_spawn()


## Bosses override this to set themselves up.
func _on_spawn() -> void:
	if ai == "burrow":
		_enter("under")
	elif ai == "charge":
		_enter("stalk")


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	state_time += delta
	_tick_statuses(delta)
	if dead:
		return

	var acting := age >= SPAWN_GRACE and stun_time <= 0.0
	if acting:
		_update_taunt(delta)
		_think(delta)
	else:
		move_velocity = Vector2.ZERO

	var slow := 1.0 - (chill_amount if chill_time > 0.0 else 0.0)
	velocity = move_velocity * slow + knock
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()

	if acting and targetable and touch_damage > 0:
		_touch_keeper()
	_animate(delta)


# ----------------------------------------------------------------------
# Behaviours
# ----------------------------------------------------------------------

## Decides what to do this tick. Sets move_velocity.
func _think(delta: float) -> void:
	match ai:
		"chase":
			_ai_chase()
		"flit":
			_ai_flit(delta)
		"shoot":
			_ai_shoot(delta)
		"charge":
			_ai_charge(delta)
		"split":
			_ai_chase()
		"orbit":
			_ai_orbit(delta)
		"turret":
			_ai_turret(delta)
		"bomb":
			_ai_bomb(delta)
		"burrow":
			_ai_burrow(delta)
		_:
			_ai_chase()


## Walks straight at the keeper, around obstacles.
func _ai_chase() -> void:
	var dir := _path_dir()
	var sway := dir.orthogonal() * sin(age * 3.0 + _wobble) * 0.35
	move_velocity = (dir + sway).normalized() * speed


## Flies at the keeper in loose swoops.
func _ai_flit(delta: float) -> void:
	shot_timer -= delta
	if shot_timer <= 0.0:
		shot_timer = Game.combat_rng.randf_range(0.7, 1.3)
		# Aim for a spot near the keeper; sometimes go straight for them.
		_goal = Vector2.ZERO if Game.combat_rng.randf() < 0.35 \
				else Vector2.from_angle(Game.combat_rng.randf() * TAU) * 42.0
	var want := (_target_pos() + _goal - position)
	if want.length() > 1.0:
		want = want.normalized() * speed
	move_velocity = move_velocity.lerp(want, clampf(4.0 * delta, 0.0, 1.0))


## Keeps its distance and fires aimed shots.
func _ai_shoot(delta: float) -> void:
	var to := _target_pos() - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if dist > float(def.get("keep_max", 110.0)):
		move_velocity = _path_dir() * speed
	elif dist < float(def.get("keep_min", 60.0)):
		move_velocity = -dir * speed
	else:
		move_velocity = dir.orthogonal() * _side * speed * 0.6
	if is_on_wall():
		_side = -_side

	shot_timer -= delta
	if shot_timer <= 0.4 and not _warned:
		_warned = true
		_flash = 0.4
	if shot_timer <= 0.0:
		_warned = false
		shot_timer = float(def.get("shot_every", 2.2)) * Game.combat_rng.randf_range(0.85, 1.15) / danger
		_fire_fan(dir, float(def.get("shot_speed", 80.0)), int(def.get("spread", 1)), 16.0)


## Creeps closer, stops and shakes as a warning, then rushes in a straight line.
func _ai_charge(delta: float) -> void:
	match state:
		"stalk":
			move_velocity = _path_dir() * speed
			var to := _target_pos() - position
			if to.length() < float(def.get("charge_range", 100.0)) and state_time > 0.6 \
					and (flying or room.clear_line(position, _target_pos())):
				facing = to.normalized()
				_enter("windup")
				Sfx.play("warn")
		"windup":
			move_velocity = Vector2.ZERO
			var windup := float(def.get("windup", 0.55))
			# Track the keeper for the first part of the warning, then lock on.
			if state_time < windup * 0.6:
				facing = (_target_pos() - position).normalized()
			_aim_line = facing * float(def.get("charge_speed", 180.0)) * float(def.get("charge_time", 0.6))
			_flash = 0.05
			queue_redraw()
			if state_time >= windup:
				_aim_line = Vector2.ZERO
				queue_redraw()
				_enter("rush")
		"rush":
			move_velocity = facing * float(def.get("charge_speed", 180.0))
			if state_time >= float(def.get("charge_time", 0.6)) or (state_time > 0.08 and is_on_wall()):
				_enter("rest")
		"rest":
			move_velocity = Vector2.ZERO
			if state_time >= float(def.get("rest", 0.9)):
				_enter("stalk")
		_:
			_enter("stalk")


## Circles the keeper at a distance and fires now and then.
func _ai_orbit(delta: float) -> void:
	var from_target := position - _target_pos()
	var want_radius := float(def.get("orbit_radius", 78.0))
	var angle := from_target.angle() + _side * 0.9
	var goal := _target_pos() + Vector2.from_angle(angle) * want_radius
	var want := (goal - position)
	if want.length() > 1.0:
		want = want.normalized() * speed
	move_velocity = move_velocity.lerp(want, clampf(5.0 * delta, 0.0, 1.0))

	shot_timer -= delta
	if shot_timer <= 0.4 and not _warned:
		_warned = true
		_flash = 0.4
	if shot_timer <= 0.0:
		_warned = false
		shot_timer = float(def.get("shot_every", 2.6)) * Game.combat_rng.randf_range(0.85, 1.15) / danger
		_fire_fan((_target_pos() - position).normalized(), float(def.get("shot_speed", 78.0)), 1, 0.0)


## Sits still and fires rings of shots.
func _ai_turret(delta: float) -> void:
	move_velocity = Vector2.ZERO
	shot_timer -= delta
	if shot_timer <= 0.5 and not _warned:
		_warned = true
		_flash = 0.5
	if shot_timer <= 0.0:
		_warned = false
		shot_timer = float(def.get("shot_every", 2.8)) / danger
		_side = -_side
		var count := int(def.get("ring", 8))
		var offset := 0.0 if _side > 0.0 else PI / float(count)
		_fire_ring(count, float(def.get("shot_speed", 62.0)), offset)


## Runs at the keeper, swells up, and bursts into a ring of shots.
func _ai_bomb(delta: float) -> void:
	if state == "fuse":
		move_velocity = Vector2.ZERO
		_flash = 0.05
		var swell := 1.0 + state_time / float(def.get("fuse", 0.75)) * 0.6
		_sprite.scale = Vector2(swell, swell)
		if state_time >= float(def.get("fuse", 0.75)):
			_fire_ring(int(def.get("ring", 10)), float(def.get("shot_speed", 75.0)), _wobble)
			Fx.ring(room, position, 26.0, Pal.DANGER, 0.3, 2.0)
			Sfx.play("explode")
			if room.keeper != null and position.distance_to(room.keeper.position) < 22.0:
				room.keeper.take_hit(1, id)
			_die({"source": "self"})
		return
	_ai_chase()
	move_velocity *= 1.0 + minf(age * 0.08, 0.3)
	if position.distance_to(_target_pos()) < 30.0:
		_enter("fuse")
		Sfx.play("warn")


## Digs under the floor, comes up near the keeper, fires, and digs again.
func _ai_burrow(delta: float) -> void:
	match state:
		"under":
			targetable = false
			var to := _target_pos() - position
			move_velocity = Vector2.ZERO if to.length() < 44.0 else _path_dir() * speed
			if state_time >= 1.4 and (to.length() < 70.0 or state_time >= 3.0):
				_enter("rise")
				Sfx.play("warn")
		"rise":
			move_velocity = Vector2.ZERO
			targetable = true
			_flash = 0.05
			if state_time >= 0.45:
				_fire_fan((_target_pos() - position).normalized(), float(def.get("shot_speed", 82.0)), int(def.get("spread", 5)), 18.0)
				_enter("up")
		"up":
			move_velocity = Vector2.ZERO
			if state_time >= 1.8:
				_enter("under")
		_:
			_enter("under")


# ----------------------------------------------------------------------
# Helpers the behaviours share
# ----------------------------------------------------------------------

func _enter(new_state: String) -> void:
	state = new_state
	state_time = 0.0


## Where this enemy is trying to get to: the keeper, or an echo if fooled.
func _target_pos() -> Vector2:
	if chases_echo != null and is_instance_valid(chases_echo) and chases_echo.solid:
		return chases_echo.position
	if room.keeper != null:
		return room.keeper.position
	return position


## Painted Buoy: now and then an enemy picks an echo to chase instead.
func _update_taunt(delta: float) -> void:
	_taunt_timer -= delta
	if _taunt_timer > 0.0:
		return
	_taunt_timer = 3.0
	chases_echo = null
	if is_boss or room.echoes.is_empty() or Game.stats.echo_taunt <= 0.0:
		return
	if Game.combat_rng.randf() < Game.stats.echo_taunt:
		chases_echo = room.echoes[Game.combat_rng.randi() % room.echoes.size()]


## The direction to walk in to reach the target, going around obstacles.
func _path_dir() -> Vector2:
	var target := _target_pos()
	var direct := target - position
	if direct.length() < 1.0:
		return Vector2.ZERO
	if flying or chases_echo != null or direct.length() < 26.0:
		return direct.normalized()
	var dir := room.flow_dir(position)
	return dir if dir != Vector2.ZERO else direct.normalized()


func _fire_fan(dir: Vector2, shot_speed: float, count: int, gap_degrees: float) -> void:
	for i in count:
		var offset := (float(i) - float(count - 1) / 2.0) * deg_to_rad(gap_degrees)
		room.add_shot(Shot.enemy_shot(room, position + dir * (radius + 1.0), dir.rotated(offset), shot_speed * danger, id))
	Sfx.play("enemy_shoot")


func _fire_ring(count: int, shot_speed: float, offset: float) -> void:
	for i in count:
		var dir := Vector2.from_angle(offset + TAU * float(i) / float(count))
		room.add_shot(Shot.enemy_shot(room, position + dir * (radius + 1.0), dir, shot_speed * danger, id))
	Sfx.play("enemy_shoot")


func _touch_keeper() -> void:
	var keeper := room.keeper
	if keeper == null or not keeper.alive:
		return
	var reach := radius + Player.HURT_RADIUS - 1.0
	if position.distance_squared_to(keeper.position) <= reach * reach:
		keeper.take_hit(touch_damage, id)


# ----------------------------------------------------------------------
# Getting hurt
# ----------------------------------------------------------------------

## Takes damage. "info" says which way it was pushed and what hit it.
func take_hit(amount: float, info: Dictionary) -> void:
	if dead:
		return
	var total := amount
	if brine_time > 0.0:
		total *= 1.0 + brine_amount
	hp -= total
	Game.note_damage(total, info.get("source", "shot"))
	_flash = 0.09
	if not is_boss:
		knock += (info.get("dir", Vector2.ZERO) as Vector2) * float(info.get("knock", 0.0))
	queue_redraw()
	if hp <= 0.0:
		_die(info)


func set_burning(dps: float, seconds: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = seconds


func _tick_statuses(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	stun_time = maxf(stun_time - delta, 0.0)
	chill_time = maxf(chill_time - delta, 0.0)
	brine_time = maxf(brine_time - delta, 0.0)
	moth_cooldown = maxf(moth_cooldown - delta, 0.0)
	beam_cooldown = maxf(beam_cooldown - delta, 0.0)
	if is_boss:
		stun_time = 0.0
		chill_amount = minf(chill_amount, 0.2)
	if chill_time <= 0.0:
		chill_amount = 0.0
	if brine_time <= 0.0:
		brine_amount = 0.0
	if burn_time > 0.0:
		burn_time -= delta
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick -= 0.5
			take_hit(burn_dps * 0.5, {"source": "burn"})
			if not dead:
				Fx.stamp(room, position + Vector2(randf_range(-3, 3), -6), Sprites.FLAME, Pal.BURN, 0.3, 0.6)
		if burn_time <= 0.0:
			burn_dps = 0.0


func _die(info: Dictionary) -> void:
	if dead:
		return
	dead = true
	targetable = false
	Combat.enemy_died(room, self)
	if def.has("split_into") and info.get("source", "") != "self":
		for i in int(def.get("split_count", 2)):
			var away := Vector2.from_angle(TAU * float(i) / float(def.get("split_count", 2)) + _wobble)
			room.queue_spawn(def["split_into"], position + away * 6.0, away * 120.0)
	if not Game.fast_mode:
		Fx.burst(room, position, base_color, 12 if not is_boss else 40, 90.0 if not is_boss else 160.0, 0.45, 1.8)
		Fx.stamp(room, position, Sprites.BURST, base_color, 0.25)
		Sfx.play("kill")
		Game.shake(1.2 if not is_boss else 6.0)
	died.emit(self)
	queue_free()


## Removes the enemy without counting it as a kill (a boss's helpers when it falls).
func dismiss() -> void:
	if dead:
		return
	dead = true
	targetable = false
	Fx.burst(room, position, base_color, 6, 60.0, 0.3, 1.2)
	died.emit(self)
	queue_free()


# ----------------------------------------------------------------------
# Looks
# ----------------------------------------------------------------------

func _animate(delta: float) -> void:
	# Flip between frames.
	if _frames.size() > 1:
		_frame_time += delta
		var frame := int(_frame_time / 0.22) % _frames.size()
		_sprite.region_rect = Sprites.region(_frames[frame])
	if ai == "burrow":
		var cell: Vector2i = def.get("buried_frame", _frames[0]) if state == "under" else _frames[0]
		_sprite.region_rect = Sprites.region(cell)
	if absf(velocity.x) > 4.0:
		_sprite.flip_h = (velocity.x < 0.0) != bool(def.get("faces_left", false))

	# Pop in when it appears.
	if age < 0.25 and ai != "bomb":
		var s := float(def.get("scale", 1.0)) * lerpf(0.3, 1.0, age / 0.25)
		_sprite.scale = Vector2(s, s)
	elif age < 0.3 and ai != "bomb":
		var full := float(def.get("scale", 1.0))
		_sprite.scale = Vector2(full, full)

	# Colour shows what state it is in.
	var c := base_color
	if burn_time > 0.0:
		c = c.lerp(Pal.BURN, 0.6 + 0.3 * sin(age * 20.0))
	elif chill_time > 0.0:
		c = c.lerp(Pal.CHILL, 0.6)
	elif brine_time > 0.0:
		c = c.lerp(Pal.BRINE, 0.5)
	if stun_time > 0.0:
		c = c.lerp(Pal.CHILL, 0.8)
	if _flash > 0.0:
		c = Color.WHITE
	if ai == "burrow" and state == "under":
		c = Color(c, 0.55)
	_sprite.modulate = c
	# Shake while winding up a charge.
	_sprite.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) if state == "windup" or state == "fuse" else Vector2.ZERO


func _draw() -> void:
	# Warning line before a charge.
	if _aim_line != Vector2.ZERO:
		draw_line(Vector2.ZERO, _aim_line, Color(Pal.DANGER, 0.55), 1.0)
	# A small health bar once it has been hurt.
	if not is_boss and hp < max_hp and hp > 0.0:
		var w := 12.0
		var top := -radius - 6.0
		draw_rect(Rect2(-w / 2.0, top, w, 2.0), Color(Pal.INK, 0.8))
		draw_rect(Rect2(-w / 2.0, top, w * clampf(hp / max_hp, 0.0, 1.0), 2.0), Pal.DANGER)
