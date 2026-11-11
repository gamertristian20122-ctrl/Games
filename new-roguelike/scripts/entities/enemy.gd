extends Node2D
## Enemy: ONE script for every normal enemy. What an enemy IS comes from its row in
## scripts/data/enemies.gd; how it BEHAVES comes from a small AI file in scripts/entities/ai/.
##
## ------------------------------------------------------------------ writing an AI file
## scripts/entities/ai/<name>.gd (the row's "ai" field is the file name):
##     extends RefCounted
##     func start(e) -> void                # optional, once, when the enemy appears
##     func tick(e, delta: float) -> void   # every physics frame while it is awake
##     func hurt(e, amount: float) -> void  # optional
##     func died(e) -> void                 # optional
## ONE AI object is shared by every enemy that uses it, so keep per-enemy memory ON THE ENEMY:
##     e.p        the row's "params" Dictionary        e.state   an int for your state machine
##     e.t, e.t2  two free timers                      e.dir, e.target   two free Vector2
##     e.mem      a free Dictionary                    e.rng     random numbers
## Helpers the enemy offers (all movement slides along walls and obstacles):
##     e.player, e.to_player(), e.dist_to_player(), e.line_of_sight()
##     e.chase(delta, speed_mult, sidestep)   walk to the player, finding a way round obstacles
##     e.flee(delta, speed_mult)              walk away from the player
##     e.move_dir(dir, delta, speed_mult)     walk in a direction        e.move_toward(point, delta, speed_mult)
##     e.dash(velocity, delta) -> bool        raw move; true when it ran into something
##     e.shoot(dir, speed, type)   e.shoot_at_player(speed, type)   e.shoot_fan(dir, n, arc, speed, type)   e.shoot_ring(n, speed, type)
##     e.tell(seconds)                        THE WARNING: the enemy flashes and a ring closes in on it
##     e.warn_line(dir, length, seconds)      a red line on the floor (charges)
##     e.warn_circle(radius, seconds)         a red circle on the floor (slams, blasts)
##     e.summon(enemy_id, position)           e.face(dir)        e.lift (px above the floor, for hops)
##     e.die()                                e.stun = seconds
## Rule of thumb: every move that can hurt gets a tell() or warn_*() first.

const Enemies = preload("res://scripts/data/enemies.gd")
const Shots = preload("res://scripts/run/shots.gd")

const FLASH_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(1.0, 1.0, 1.0, c.a);\n}\n"

static var _ai_cache := {}
static var _white: ShaderMaterial
static var _shadow_tex: GradientTexture2D

var room: Node
var run: Node
var player: Node
var id := ""
var data: Dictionary
var display_name := ""
var ai: RefCounted
var p: Dictionary = {}
var rng := RandomNumberGenerator.new()

var hp := 1.0
var max_hp := 1.0
var speed := 30.0
var radius := 5.0
var mass := 1.0
var touch := 1
var flying := false
var elite := false
var minion := false
var owner_id := 0
var shot_type := "enemy"
var hit_up := 0.0           ## how far above the feet the middle of the body is, for shots
var hit_grow := 0.0         ## extra hit size for shots
var hittable := false       ## shots and bombs can hurt it
var harmful := true         ## touching it hurts
var dead := false

# free memory for AI files
var state := 0
var t := 0.0
var t2 := 0.0
var dir := Vector2.RIGHT
var target := Vector2.ZERO
var mem := {}

var stun := 0.0
var lift := 0.0
var knock := Vector2.ZERO
var vel_est := Vector2.ZERO  ## measured velocity (the bot uses it to lead its shots)
var appear := 0.0
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var _flash := 0.0
var _tell := 0.0
var _tell_dur := 0.0
var _moved := false
var _face := 1.0
var _last_pos := Vector2.ZERO
var _los := false
var _los_t := 0.0
var _direct := false
var _direct_t := 0.0
var _pop := 0.0
var _base_scale := 1.0
var _tint := Color(1, 1, 1)
var _aura_t := 0.0


static func ai_for(ai_name: String, folder: String = "ai") -> RefCounted:
	var key := folder + "/" + ai_name
	if not _ai_cache.has(key):
		var script: GDScript = load("res://scripts/entities/%s/%s.gd" % [folder, ai_name])
		if script == null:
			push_warning("Enemy: no AI file '%s'" % key)
			script = load("res://scripts/entities/ai/chaser.gd")
		_ai_cache[key] = script.new()
	return _ai_cache[key]


static func white_material() -> ShaderMaterial:
	if _white == null:
		var sh := Shader.new()
		sh.code = FLASH_SHADER
		_white = ShaderMaterial.new()
		_white.shader = sh
	return _white


## A soft dark blob used under every character (one shared texture).
static func shadow_texture() -> GradientTexture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.0)])
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 32
		_shadow_tex.height = 32
	return _shadow_tex


static func make_shadow(width: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = shadow_texture()
	s.scale = Vector2(width / 32.0, width * 0.45 / 32.0)
	s.z_index = -1
	return s


func setup(the_room: Node, enemy_id: String, opts: Dictionary = {}) -> void:
	room = the_room
	run = room.run
	player = run.player
	id = enemy_id
	data = _row(enemy_id)
	display_name = String(data.get("name", enemy_id))
	p = data.get("params", {})
	rng.randomize()
	minion = opts.get("minion", false) or data.get("minion", false)
	owner_id = int(opts.get("owner", 0))
	elite = opts.get("elite", false)
	if not opts.has("elite") and not minion and not opts.get("boss", false):
		elite = run.floor_index + 1 >= Enemies.ELITE_FROM_FLOOR and randf() < run.elite_chance
	max_hp = float(data["hp"]) * _hp_scale()
	speed = float(data["speed"])
	radius = float(data["radius"])
	touch = int(data.get("touch", 1))
	flying = data.get("flying", false)
	shot_type = String(data.get("shot", "enemy"))
	hit_up = float(data.get("hit_up", 0.0))
	_base_scale = float(data.get("scale", 1.0))
	_tint = data.get("tint", Color(1, 1, 1))
	if elite:
		max_hp *= Enemies.ELITE_HP
		speed *= Enemies.ELITE_SPEED
		_base_scale *= 1.12
	hp = max_hp
	mass = radius * radius / 25.0
	ai = _load_ai()
	shadow = make_shadow(radius * 2.6 * _base_scale)
	add_child(shadow)
	sprite = Art.sprite(String(data["sprite"]))
	sprite.position = Vector2(0, 2)
	sprite.scale = Vector2(_base_scale, _base_scale)
	sprite.modulate = _tint
	add_child(sprite)
	_last_pos = position
	appear = float(opts.get("delay", room.SPAWN_DELAY))
	sprite.visible = false
	shadow.visible = false
	hittable = false
	# the warning that something is about to appear here
	run.fx.ring(position, radius * 3.2, 2.0, appear, Color(1.0, 0.35, 0.3, 0.9), 1.5, true)
	run.fx.ring(position, 2.0, radius * 1.6, appear, Color(0.1, 0.0, 0.0, 0.7), 3.0, true)


func _row(enemy_id: String) -> Dictionary:
	return Enemies.info(enemy_id)


func _hp_scale() -> float:
	return 1.0 + Enemies.HP_PER_FLOOR * run.floor_index


func _load_ai() -> RefCounted:
	return ai_for(String(data.get("ai", "chaser")))


func _appear() -> void:
	sprite.visible = true
	shadow.visible = true
	hittable = true
	_pop = 0.18
	run.fx.burst(position - Vector2(0, 5), Art.palette(String(data["sprite"])), 6, 45.0, 0.3, 2.0)
	if ai.has_method("start"):
		ai.start(self)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if appear > 0.0:
		appear -= delta
		if appear <= 0.0:
			_appear()
		return
	_moved = false
	_los_t -= delta
	_direct_t -= delta
	if stun > 0.0:
		stun -= delta
	else:
		ai.tick(self, delta)
		if dead:
			return
	if knock.length_squared() > 4.0:
		position = room.move_circle(position, radius, knock * delta, flying)
		knock = knock.move_toward(Vector2.ZERO, 520.0 * delta)
	vel_est = vel_est.lerp((position - _last_pos) / delta, 0.25)
	_last_pos = position
	if harmful and touch > 0 and lift < 6.0 and player.can_be_hit():
		var reach: float = radius + player.radius - 1.5
		if position.distance_squared_to(player.position) < reach * reach:
			player.hurt(touch, position, display_name)
	_update_look(delta)


func _update_look(delta: float) -> void:
	sprite.flip_h = _face < 0.0
	var want := "run" if _moved else "idle"
	if sprite.animation != want:
		sprite.play(want)
	sprite.position.y = 2.0 - lift
	var sc := _base_scale
	if _pop > 0.0:
		_pop -= delta
		sc *= 1.0 + 0.35 * sin(clampf(_pop / 0.18, 0.0, 1.0) * PI)
	sprite.scale = Vector2(sc, sc)
	shadow.modulate.a = clampf(1.0 - lift / 40.0, 0.35, 1.0)
	if _flash > 0.0:
		_flash -= delta
		sprite.material = white_material()
	elif _tell > 0.0:
		_tell -= delta
		# the tell: blink white faster and faster
		var k := 1.0 - _tell / maxf(_tell_dur, 0.01)
		sprite.material = white_material() if fmod(k * k * 7.0 + k * 3.0, 1.0) < 0.5 else null
	else:
		sprite.material = null
	if elite:
		_aura_t += delta
		queue_redraw()


func _draw() -> void:
	if elite and appear <= 0.0 and not dead:
		var c: Color = Enemies.ELITE_COLOR
		var pulse := 0.5 + 0.5 * sin(_aura_t * 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius * 1.9 + pulse, 0.0, TAU, 20, Color(c.r, c.g, c.b, 0.9), 1.5)
		draw_circle(Vector2.ZERO, radius * 1.9, Color(c.r, c.g, c.b, 0.16 + 0.08 * pulse))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------------------ helpers for AI files
func to_player() -> Vector2:
	return player.position - position


func dist_to_player() -> float:
	return position.distance_to(player.position)


## Can a shot fly from here to the player? (checked a few times per second, not every frame)
func line_of_sight() -> bool:
	if _los_t <= 0.0:
		_los_t = 0.2 + rng.randf() * 0.1
		_los = room.sight_clear(position, player.position)
	return _los


func face(d: Vector2) -> void:
	if absf(d.x) > 0.05:
		_face = signf(d.x)


func _step(v: Vector2, delta: float) -> bool:
	var before := position
	var want := v * delta
	position = room.move_circle(position, radius, want, flying)
	var done := position - before
	if done.length_squared() > 0.0004:
		_moved = true
		if absf(v.x) > 3.0:
			_face = signf(v.x)
	return done.length_squared() < want.length_squared() * 0.36


func move_dir(d: Vector2, delta: float, speed_mult: float = 1.0) -> bool:
	if d == Vector2.ZERO:
		return false
	return _step(d.normalized() * speed * speed_mult, delta)


func move_toward(point: Vector2, delta: float, speed_mult: float = 1.0) -> bool:
	var d := point - position
	if d.length() < 1.5:
		return false
	return _step(d.normalized() * speed * speed_mult, delta)


## Walk to the player. Goes straight when nothing is in the way, otherwise follows the room's path map.
func chase(delta: float, speed_mult: float = 1.0, sidestep: float = 0.0) -> void:
	if _direct_t <= 0.0:
		_direct_t = 0.25 + rng.randf() * 0.1
		_direct = room.walk_clear(position, player.position, flying)
	var d: Vector2 = to_player().normalized() if _direct else room.flow_dir(position, flying)
	if sidestep != 0.0:
		d = (d + d.orthogonal() * sidestep).normalized()
	_step(d * speed * speed_mult, delta)


## Walk away from the player (and slide along walls instead of getting stuck in a corner).
func flee(delta: float, speed_mult: float = 1.0) -> void:
	var away := -to_player().normalized()
	# near a wall, bend the escape along it
	var probe := position + away * 14.0
	if probe.x < 8.0 or probe.x > G.ROOM_W - 8.0 or probe.y < 8.0 or probe.y > G.ROOM_H - 8.0 or room.blocks_walk(G.cell_of(probe), flying):
		var side := away.orthogonal()
		if (G.ROOM_CENTER - position).dot(side) < 0.0:
			side = -side
		away = (away * 0.25 + side).normalized()
	_step(away * speed * speed_mult, delta)


## Raw movement for charges and hops. Returns true when it ran into something.
func dash(v: Vector2, delta: float) -> bool:
	return _step(v, delta)


func shoot(d: Vector2, shot_speed: float, type: String = "") -> void:
	run.shots.fire(position + d.normalized() * (radius + 1.0), d.normalized() * shot_speed, Shots.SIDE_ENEMY, 1.0, 170.0,
		type if type != "" else shot_type, {"src": display_name})
	Sfx.play("enemy_shoot", -10.0)


func shoot_at_player(shot_speed: float, type: String = "") -> void:
	shoot(to_player(), shot_speed, type)


func shoot_fan(d: Vector2, amount: int, arc: float, shot_speed: float, type: String = "") -> void:
	var base := d.angle()
	for k in amount:
		var a := base + (float(k) - float(amount - 1) * 0.5) * (arc / maxf(1.0, float(amount - 1)))
		run.shots.fire(position, Vector2(cos(a), sin(a)) * shot_speed, Shots.SIDE_ENEMY, 1.0, 170.0,
			type if type != "" else shot_type, {"src": display_name})
	Sfx.play("enemy_shoot", -8.0)


func shoot_ring(amount: int, shot_speed: float, type: String = "", angle_offset: float = 0.0) -> void:
	run.shots.ring_of(position, amount, shot_speed, type if type != "" else shot_type, 150.0, display_name, angle_offset)
	Sfx.play("enemy_shoot", -6.0)


## THE WARNING before a dangerous move: the enemy blinks white and a ring closes in on it.
func tell(seconds: float) -> void:
	_tell = seconds
	_tell_dur = seconds
	run.fx.ring(position - Vector2(0, 6), radius * 3.0, radius * 0.8, seconds, Color(1.0, 0.9, 0.5, 0.95), 1.5)


func warn_line(d: Vector2, length: float, seconds: float) -> void:
	run.fx.warn_line(position, position + d.normalized() * length, radius, seconds)


func warn_circle(warn_radius: float, seconds: float, at: Vector2 = Vector2.INF) -> void:
	run.fx.warn_circle(position if at == Vector2.INF else at, warn_radius, seconds)


func summon(enemy_id: String, at: Vector2) -> Node2D:
	return room.spawn_enemy(enemy_id, at, {"minion": true, "delay": 0.7, "owner": get_instance_id()})


## How many living enemies this one has summoned.
func minion_count() -> int:
	var n := 0
	var me := get_instance_id()
	for e in room.enemies:
		if e.owner_id == me:
			n += 1
	return n


# ------------------------------------------------------------------------------ getting hurt
func hurt(amount: float, from_dir: Vector2 = Vector2.ZERO, knock_mult: float = 1.0) -> void:
	if dead or not hittable:
		return
	hp -= amount
	_flash = 0.09
	knock += from_dir * 85.0 * knock_mult / maxf(mass, 0.6)
	Sfx.play("enemy_hit", -9.0)
	if ai.has_method("hurt"):
		ai.hurt(self, amount)
	if hp <= 0.0:
		die()


## drops = false: vanish without loot (used when an exploder blows itself up).
func die(drops: bool = true) -> void:
	if dead:
		return
	dead = true
	hittable = false
	room.enemy_died(self)
	if ai.has_method("died"):
		ai.died(self)
	var colors := Art.palette(String(data["sprite"]))
	run.fx.burst(position - Vector2(0, 6), colors, 10 + int(radius * 2.0), 75.0, 0.5, 2.6)
	run.fx.ring(position - Vector2(0, 5), 2.0, radius * 2.4, 0.22, Color(1, 1, 1, 0.8), 1.5)
	Sfx.play("enemy_die", -6.0)
	if elite or radius >= 5.5:
		run.shake(0.22)
	run.enemy_killed(self)
	if drops and not minion:
		_drop_loot()
	queue_free()


func _drop_loot() -> void:
	var luck: float = player.stats.v("luck") * 0.02
	if elite:
		for k in 2 + randi() % 2:
			room.drop("coin", position)
	elif randf() < float(data.get("coin", 0.2)) + luck:
		room.drop("coin", position)
	if randf() < float(data.get("heart", 0.04)) + luck * 0.5:
		room.drop("half_heart", position)
