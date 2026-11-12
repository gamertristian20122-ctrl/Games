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
const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Shots = preload("res://scripts/run/shots.gd")

const Hands = preload("res://scripts/entities/hands.gd")
const CHAMPION_HP := 8.0          ## a side level's champion has this many times its kind's health
const CORPSE_FADE := 0.45       ## seconds a fallen body takes to fade after its death animation
const SHOT_PLANE := 7.0         ## shots are drawn this far above the floor (see shot_look.gd)

## The hit flash brightens the sprite but keeps its drawing and colours (a pure white cut-out of
## these big sprites read as a white cloud).
const FLASH_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), 0.55), c.a);\n}\n"

## The wind-up blink: the sprite goes pale but keeps its drawing (a full white shape of these tall
## sprites looked like a blank cut-out). Pure white is kept for the short hit flash only.
const TELL_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0, 0.96, 0.85), 0.6), c.a);\n}\n"
const HIT_FLASH := 0.05         ## seconds of bright flash when a shot lands (3 frames)
const FLASH_GAP := 0.1          ## after a flash, at least this long unflashed: rapid fire flickers, never stays white

static var _ai_cache := {}
static var _white: ShaderMaterial
static var _pale: ShaderMaterial
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
var status: RefCounted         ## chill / burn from items (scripts/entities/status.gd); null until something puts one on it
var lift := 0.0
var knock := Vector2.ZERO
var vel_est := Vector2.ZERO  ## measured velocity (the bot uses it to lead its shots)
var appear := 0.0
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var hands: RefCounted          ## the pack's hand pieces at its sides (hands.gd); null when the row names none
var _flash := 0.0
var _flash_gap := 0.0
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
var _eaten_by: Node2D          ## the Hungry Curse that is swallowing this enemy (see devour())
var _eaten_t := 0.0
var _eaten_dur := 0.0
var _sprite_id := ""
var _idle_anim := "idle"       ## the row's "idle": bats use their flying loop ("run") while they hang in the air
var _hover := 0.0              ## the row's "hover": px the sprite floats above its shadow
var _mid := 6.0                ## how far above the feet the middle of the body is drawn (effects aim at it)
var _has_hit := false
var _has_attack := false
var _has_death := false
var _hit_t := 0.0
var _attack_t := 0.0
var _corpse_t := 0.0           ## > 0 while the dead body plays its death animation and fades


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


static func tell_material() -> ShaderMaterial:
	if _pale == null:
		var sh := Shader.new()
		sh.code = TELL_SHADER
		_pale = ShaderMaterial.new()
		_pale.shader = sh
	return _pale


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
		elite = run.scale_floor + 1 >= Enemies.ELITE_FROM_FLOOR and randf() < run.elite_chance
	max_hp = float(data["hp"]) * _hp_scale()
	speed = float(data["speed"]) * (1.0 if opts.get("boss", false) else maxf(G.diff("speed"), 0.5))
	touch = int(data.get("touch", 1))
	flying = data.get("flying", false)
	shot_type = String(data.get("shot", "enemy"))
	_base_scale = float(data.get("scale", 1.0))
	_tint = data.get("tint", Color(1, 1, 1))
	_sprite_id = String(data["sprite"])
	_idle_anim = String(data.get("idle", "idle"))
	_hover = float(data.get("hover", 0.0))
	_has_hit = Art.has_anim(_sprite_id, "hit")
	_has_attack = Art.has_anim(_sprite_id, "attack")
	_has_death = Art.has_anim(_sprite_id, "death")
	# Size: from the sprite's own measurements (assets/art/pc/pc_cast.json) unless the row says otherwise.
	# The body circle stays under a tile wide so everything fits through a one-tile gap.
	var m := Art.meta(_sprite_id)
	var body_w := float(m.get("body_width", 12.0)) * _base_scale
	var body_h := float(m.get("body_height", 14.0)) * _base_scale
	radius = float(data.get("radius", clampf(float(m.get("radius", 5.0)), 5.0, 7.5) * _base_scale))
	_mid = body_h * 0.5 + _hover
	hit_up = float(data.get("hit_up", clampf(_mid - SHOT_PLANE, 0.0, 26.0) if not m.is_empty() else 0.0))
	# shots test ONE circle around the middle of the body: halfway between half its width and half
	# its height, so a shot that visibly touches the chest or the head counts
	hit_grow = clampf((body_w + body_h) * 0.25 - radius, 0.0, 4.0 * _base_scale) if not m.is_empty() else 0.0
	if opts.get("champion", false):
		max_hp *= CHAMPION_HP             # the champion that ends a side level
		display_name = "the " + display_name
	if minion:
		max_hp *= Enemies.MINION_HP
	if elite:
		max_hp *= Enemies.ELITE_HP
		speed *= Enemies.ELITE_SPEED
		_tint = _tint.lerp(Enemies.ELITE_COLOR, 0.3)      # elites: a gold wash and the ring (no odd-size pixels)
	hp = max_hp
	mass = radius * radius / 45.0
	ai = _load_ai()
	shadow = make_shadow(clampf(body_w * 0.85, radius * 2.2, radius * 3.6))
	add_child(shadow)
	sprite = Art.sprite(_sprite_id, _idle_anim)
	sprite.position = Vector2(0, 2.0 - _hover)
	sprite.scale = Vector2(_base_scale, _base_scale)
	sprite.modulate = _tint
	add_child(sprite)
	if String(data.get("hands", "")) != "":
		hands = Hands.new()
		hands.build(self, sprite, String(data["hands"]), body_w, body_h)
		hands.hide()
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
	return (1.0 + Enemies.HP_PER_FLOOR * run.scale_floor) * G.diff("enemy_hp") * _kit_scale() * _level_scale()


## ... and with the knight's level (scripts/data/rpg.gd). Not in the training yard.
func _level_scale() -> float:
	var p: Variant = run.get("player")
	if run.get("training") == true or not is_instance_valid(p) or not (p.get("hero") as Dictionary).has("melee"):
		return 1.0
	return Rpg.foe_scale()


## Monsters toughen with what the hero carries, so a full pack of relics does not turn the late game soft.
func _kit_scale() -> float:
	var p: Variant = run.get("player")
	if not is_instance_valid(p) or run.get("training") == true:
		return 1.0
	return 1.0 + G.ITEM_HP * float(mini((p.get("items") as Array).size(), G.ITEM_HP_CAP))


func _load_ai() -> RefCounted:
	return ai_for(String(data.get("ai", "chaser")))


func _appear() -> void:
	sprite.visible = true
	shadow.visible = true
	hittable = true
	_pop = 0.18
	run.fx.burst(position - Vector2(0, _mid), Art.palette(_sprite_id), 6, 45.0, 0.3, 2.0)
	if ai.has_method("start"):
		ai.start(self)


func _physics_process(delta: float) -> void:
	if dead:
		if _eaten_dur > 0.0:
			_tick_eaten(delta)
		elif _corpse_t > 0.0:
			_tick_corpse(delta)
		return
	if appear > 0.0:
		appear -= delta
		if appear <= 0.0:
			_appear()
		return
	_moved = false
	_los_t -= delta
	_direct_t -= delta
	if status != null:
		status.tick(self, delta)       # a burn can kill
		if dead:
			return
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
	if _attack_t > 0.0:
		_attack_t -= delta               # the pack's attack animation, started by tell()
	elif _hit_t > 0.0:
		_hit_t -= delta                  # the pack's hit animation, started by hurt()
	else:
		var want := "run" if _moved else _idle_anim
		if sprite.animation != want:
			sprite.play(want)
	sprite.position.y = 2.0 - lift - _hover
	var sc := _base_scale
	if _pop > 0.0:
		_pop -= delta
		sc *= 1.0 + 0.35 * sin(clampf(_pop / 0.18, 0.0, 1.0) * PI)
	sprite.scale = Vector2(sc, sc)
	shadow.modulate.a = clampf(1.0 - lift / 40.0, 0.35, 1.0)
	_flash_gap -= delta
	_update_hands(delta)
	if _flash > 0.0:
		_flash -= delta
		sprite.material = white_material()
	elif _tell > 0.0:
		_tell -= delta
		# the tell: blink white faster and faster
		var k := 1.0 - _tell / maxf(_tell_dur, 0.01)
		sprite.material = tell_material() if fmod(k * k * 7.0 + k * 3.0, 1.0) < 0.5 else null
	else:
		sprite.material = null
	if elite:
		_aura_t += delta
		queue_redraw()


## The hands follow the body: same flash, same tint, hidden while the pack's own hit or attack
## animation plays (those frames move the whole body) and when it dies.
func _update_hands(delta: float) -> void:
	if hands == null:
		return
	var steady := _attack_t <= 0.0 and _hit_t <= 0.0
	hands.update(delta, _moved, _face, -lift - _hover, sprite.visible and steady, sprite.material, _tint)


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
	if status != null:
		v *= status.speed              # chilled = slower, burning = faster
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
	if _has_attack:
		_attack_t = Art.anim_time(_sprite_id, "attack")
		_hit_t = 0.0
		sprite.play("attack")
	run.fx.ring(position - Vector2(0, _mid), radius * 3.0, radius * 0.8, seconds, Color(1.0, 0.9, 0.5, 0.95), 1.5)


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


## How fast statuses let it move right now (1.0 = normal). The walking helpers already use it;
## a boss fight that writes `position` itself should multiply its movement by this.
func status_speed() -> float:
	return status.speed if status != null else 1.0


# ------------------------------------------------------------------------------ getting hurt
func hurt(amount: float, from_dir: Vector2 = Vector2.ZERO, knock_mult: float = 1.0) -> void:
	if dead or not hittable:
		return
	hp -= amount
	if _flash_gap <= 0.0:
		_flash = HIT_FLASH
		_flash_gap = HIT_FLASH + FLASH_GAP
	if _has_hit and _attack_t <= 0.0:
		_flash = minf(_flash, HIT_FLASH * 0.7)
		_hit_t = Art.anim_time(_sprite_id, "hit")
		sprite.play("hit")
		sprite.frame = 0
	knock += from_dir * 85.0 * knock_mult * (status.knock if status != null else 1.0) / maxf(mass, 0.6)
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
	if hands != null:
		hands.hide()
	hittable = false
	room.enemy_died(self)
	if ai.has_method("died"):
		ai.died(self)
	var colors := Art.palette(_sprite_id)
	if _has_death:
		# the body falls by itself: only a few bits in its own colours fly off
		run.fx.burst(position - Vector2(0, _mid), colors, 5 + int(radius * 0.5), 60.0, 0.4, 2.2, Vector2.ZERO, 70.0)
	else:
		run.fx.death_puff(position - Vector2(0, 6), colors, radius)      # smoke, bits and a ring, in its own colours
	Sfx.play("enemy_die", -6.0)
	if elite or data.get("big", false):
		run.shake(0.22)
	run.enemy_killed(self)
	if drops and not minion:
		_drop_loot()
	if _has_death:
		_start_corpse()
	else:
		queue_free()


## The dead body plays the pack's death animation once, then fades. It is already out of
## room.enemies (dead = true), so shots, the Curse and other monsters ignore it.
func _start_corpse() -> void:
	_corpse_t = Art.anim_time(_sprite_id, "death") + CORPSE_FADE
	lift = 0.0
	sprite.material = null
	sprite.scale = Vector2(_base_scale, _base_scale)
	sprite.position.y = 2.0 - _hover
	sprite.play("death")
	queue_redraw()


func _tick_corpse(delta: float) -> void:
	_corpse_t -= delta
	if _corpse_t < CORPSE_FADE:
		var k := clampf(_corpse_t / CORPSE_FADE, 0.0, 1.0)
		sprite.modulate.a = k
		shadow.modulate.a = k
	if _corpse_t <= 0.0:
		queue_free()


## Swallowed whole by the Hungry Curse (scripts/entities/curse.gd): the enemy shrinks into the
## disc and is gone. Unlike die() there is no death effect and no loot, and the AI's died() is
## NOT called (so an exploder does not blow up).
func devour(into: Node2D, seconds: float = 0.2) -> void:
	if dead:
		return
	dead = true
	if hands != null:
		hands.hide()
	hittable = false
	room.enemy_died(self)
	run.enemy_devoured(self)
	_eaten_by = into
	_eaten_t = seconds
	_eaten_dur = maxf(seconds, 0.01)
	shadow.visible = false
	sprite.material = null
	queue_redraw()


func _tick_eaten(delta: float) -> void:
	_eaten_t -= delta
	var k := clampf(_eaten_t / _eaten_dur, 0.0, 1.0)
	if is_instance_valid(_eaten_by):
		position = position.lerp(_eaten_by.position, 1.0 - exp(-14.0 * delta))
	sprite.scale = Vector2(_base_scale * k, _base_scale * k)
	sprite.position.y = 2.0 - (lift + _hover) * k
	sprite.modulate = _tint.darkened(1.0 - k)
	if _eaten_t <= 0.0:
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
	# a piece of gear, now and then (scripts/data/gear.gd): only for the knight, never in the yard
	if run.get("training") != true and (player.hero as Dictionary).has("melee") and randf() < (Gear.DROP_ELITE if elite else Gear.DROP_MONSTER) + luck * 0.2 + (0.5 if G.flag("gearrain") else 0.0):      # --gearrain: a test, half the monsters drop a piece
		var piece := Gear.roll_common(run.gear_tier(), player.stats.v("luck"))
		if piece != "":
			room.drop("gear:" + piece, position)
