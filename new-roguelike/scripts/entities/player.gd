extends Node2D
## Player: the hero you control. One node that lives for the whole run and is moved from room to room.
##   position      the middle of a small circle at the FEET (radius 5). The sprite stands on it.
##   hp, max_hp, armor   in HALF hearts.   coins, keys, bombs   plain counts.   items   ids in pickup order.
##   stats         all the numbers (see scripts/run/stats.gd). Items change them through layers.
## It reads Controls.move / Controls.aim every physics frame, fires by itself while aiming,
## and places a bomb when Controls.bomb_pressed fires.
## Item logic does NOT live here: see scripts/data/items.gd and scripts/run/item_effects.gd.

const Stats = preload("res://scripts/run/stats.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Items = preload("res://scripts/data/items.gd")
const Shots = preload("res://scripts/run/shots.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const FamiliarScript = preload("res://scripts/entities/familiar.gd")
const Curse = preload("res://scripts/entities/curse.gd")

const ACCEL := 950.0
const DECEL := 1500.0
const MAX_HP := 24
const MAX_ARMOR := 12
const SHOT_KNOCK := 1.0

var run: Node
var room: Node
var hero: Dictionary
var stats: Stats

var hp := 6
var max_hp := 6
var armor := 0
var coins := 0
var keys := 0
var bombs := 1
var items: Array[String] = []
var familiars: Array = []

var radius := 5.0
var hit_radius := 3.5
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var firing := false
var invuln := 0.0
var dead := false
var god := false
var ward_ready := false
var damage_taken := 0
var coins_collected := 0
var last_cause := ""

var body: AnimatedSprite2D
var weapon: Sprite2D
var shadow: Sprite2D
var light: PointLight2D
var _fire_cd := 0.0
var _kick := 0.0
var _hit_anim := 0.0
var _face := 1.0
var _ward_flash := 0.0
var _step_t := 0.0
var _spike_cd := 0.0
var _shot_extra := {}
var _dead_t := 0.0


func setup(the_run: Node, hero_id: String) -> void:
	run = the_run
	hero = Heroes.by_id(hero_id)
	stats = Stats.new(hero)
	if hero.has("mods"):
		stats.set_layer("hero", hero["mods"])
	max_hp = int(hero.get("hp", 6))
	hp = max_hp
	armor = int(hero.get("armor", 0))
	var start: Dictionary = hero.get("start", {})
	bombs = int(start.get("bombs", 1))
	keys = int(start.get("keys", 0))
	coins = int(start.get("coins", 0))
	god = G.flag("god")
	shadow = EnemyScript.make_shadow(13.0)
	add_child(shadow)
	weapon = Sprite2D.new()
	weapon.texture = Art.tex(String(hero.get("weapon", "weapon_knife")))
	weapon.centered = false
	var ws := weapon.texture.get_size()
	weapon.offset = Vector2(-ws.x * 0.5, -ws.y + 3.0)
	add_child(weapon)
	body = Art.sprite(String(hero.get("sprite", "knight_m")))
	body.position = Vector2(0, 2)
	add_child(body)
	if run.LIGHTING:
		light = PointLight2D.new()
		light.texture = run.light_tex
		light.texture_scale = 3.2
		light.energy = 0.55
		light.color = run.theme.get("light", Color(1, 0.9, 0.7))
		light.position = Vector2(0, -8)
		add_child(light)
	stats.changed.connect(_stats_changed)
	_stats_changed()
	_hook_bomb_button()
	if hero.has("familiar"):
		add_familiar(String(hero["familiar"]))


## The hero is taken out of the tree and put back at every room change, so the bomb button is
## hooked up each time he comes back (hooking it up only once left bombs dead after the first room).
func _enter_tree() -> void:
	_hook_bomb_button()


func _hook_bomb_button() -> void:
	if not Controls.bomb_pressed.is_connected(place_bomb):
		Controls.bomb_pressed.connect(place_bomb)


func _exit_tree() -> void:
	if Controls.bomb_pressed.is_connected(place_bomb):
		Controls.bomb_pressed.disconnect(place_bomb)


func _stats_changed() -> void:
	_shot_extra = {
		"pierce": int(stats.flag("pierce")),
		"bounce": int(stats.flag("bounce")),
		"homing": stats.v("homing"),
		"knock": stats.v("knockback") * SHOT_KNOCK,
		"size": stats.v("shot_size"),
	}


## Called by the run every time the player walks into a room.
func entered_room(the_room: Node) -> void:
	room = the_room
	ward_ready = hero.get("ward", false) or stats.has_flag("ward")
	vel = Vector2.ZERO
	knock = Vector2.ZERO
	if light != null:
		light.color = run.theme.get("light", Color(1, 0.9, 0.7))


func can_be_hit() -> bool:
	return not dead and invuln <= 0.0 and not run.busy()


# =============================================================================== every frame
func _physics_process(delta: float) -> void:
	if room == null:
		return
	if dead:
		_dead_t += delta
		body.rotation = minf(_dead_t * 6.0, PI * 0.5) * _face
		body.modulate.a = clampf(1.6 - _dead_t, 0.0, 1.0)
		return
	invuln = maxf(0.0, invuln - delta)
	_spike_cd = maxf(0.0, _spike_cd - delta)
	# ---- walking
	var want: Vector2 = Controls.move * stats.v("speed")
	vel = vel.move_toward(want, (ACCEL if want != Vector2.ZERO else DECEL) * delta)
	position = room.move_circle(position, radius, (vel + knock) * delta, stats.has_flag("flying"), true)
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	if room.spikes_hurt(position) and _spike_cd <= 0.0 and not stats.has_flag("flying"):
		_spike_cd = 0.3
		hurt(1, position + Vector2(0, 1), "spikes")
	# ---- aiming and firing
	var aim: Vector2 = Controls.aim
	firing = aim.length() > Controls.AIM_DEADZONE
	if firing:
		aim_dir = aim.normalized()
	_fire_cd -= delta
	if firing and _fire_cd <= 0.0:
		_fire()
		_fire_cd = 1.0 / stats.v("rate")
	_update_look(delta)


func _fire() -> void:
	var n := maxi(1, int(stats.v("shots")))
	var spread := stats.v("spread")
	var speed := stats.v("shot_speed")
	var from := position + aim_dir * 7.0
	for k in n:
		var a := aim_dir.angle() + (float(k) - float(n - 1) * 0.5) * 0.17
		if spread > 0.0:
			a += randf_range(-spread, spread)
		run.shots.fire(from, Vector2(cos(a), sin(a)) * speed, Shots.SIDE_PLAYER, stats.v("damage"), stats.v("range"),
			String(hero.get("shot", "blade")), _shot_extra)
	_kick = 1.0
	Sfx.play(String(hero.get("shoot_sfx", "player_shoot_blade")), -12.0)
	run.effects.fire("on_shot_fired", [from, aim_dir])


func _update_look(delta: float) -> void:
	var moving := vel.length() > 12.0
	if firing:
		if absf(aim_dir.x) > 0.15:
			_face = signf(aim_dir.x)
	elif absf(vel.x) > 12.0:
		_face = signf(vel.x)
	body.flip_h = _face < 0.0
	if _hit_anim > 0.0:
		_hit_anim -= delta
		if body.animation != "hit":
			body.play("hit")
	else:
		var want := "run" if moving else "idle"
		if body.animation != want:
			body.play(want)
	# blink while safe after a hit
	body.visible = invuln <= 0.0 or fmod(invuln * 12.0, 1.0) < 0.6
	weapon.visible = body.visible
	# the weapon: held in the hand, pointing where you aim, kicking back with each shot
	_kick = maxf(0.0, _kick - delta * 9.0)
	if firing:
		weapon.rotation = aim_dir.angle() + PI * 0.5
		weapon.position = Vector2(0, -7) + aim_dir * (5.0 - 3.5 * _kick)
		weapon.show_behind_parent = aim_dir.y < -0.35
	else:
		weapon.rotation = lerp_angle(weapon.rotation, 0.55 * _face, minf(1.0, delta * 14.0))
		weapon.position = Vector2(5.0 * _face, -5.0)
		weapon.show_behind_parent = false
	if moving:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.3
			Sfx.play("footstep", -22.0, 0.12)
	if _ward_flash > 0.0 or ward_ready:
		_ward_flash = maxf(0.0, _ward_flash - delta)
		queue_redraw()


func _draw() -> void:
	# the knight's ward: a faint ring while it is ready, a bright flash when it blocks a hit
	if _ward_flash > 0.0:
		var k := _ward_flash / 0.45
		draw_arc(Vector2(0, -8), 11.0 + (1.0 - k) * 8.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, k), 2.0)
		draw_circle(Vector2(0, -8), 11.0, Color(0.6, 0.85, 1.0, 0.25 * k))
	elif ward_ready and not dead:
		# a quiet circle on the floor around the feet (flattened, like the shadows)
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.30), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =============================================================================== getting hurt
## Takes `half_hearts` of damage from something at `from` (armor first). `cause` ends up on the death screen.
func hurt(half_hearts: int, from: Vector2, cause: String = "") -> void:
	if not can_be_hit():
		return
	if ward_ready:
		ward_ready = false
		_ward_flash = 0.45
		invuln = 0.5
		run.fx.ring(position - Vector2(0, 8), 6.0, 22.0, 0.3, Color(0.6, 0.85, 1.0), 2.0)
		Sfx.play("shot_hit_wall", -2.0)
		queue_redraw()
		return
	var amount := maxi(1, int(round(float(half_hearts) * stats.v("hurt_mult"))))
	var from_armor := mini(armor, amount)
	armor -= from_armor
	hp -= amount - from_armor
	damage_taken += amount
	last_cause = cause
	invuln = stats.v("invuln")
	_hit_anim = 0.3
	var away := position - from
	knock = (away.normalized() if away.length() > 0.5 else Vector2.DOWN) * 150.0
	run.shake(0.55)
	run.hitstop(0.05)
	run.fx.burst(position - Vector2(0, 8), [Color(1, 0.3, 0.3), Color(1, 1, 1)], 8, 70.0, 0.4, 2.2)
	run.fx.flash(Color(1, 0.1, 0.1, 0.18), 0.15)
	Sfx.play("player_hurt", -3.0)
	G.player_hurt.emit(amount)
	run.effects.fire("on_hurt", [amount, cause])
	if hp <= 0:
		if god:
			hp = 1
		else:
			hp = 0
			_die()
	G.hud_changed.emit()


func _die() -> void:
	dead = true
	vel = Vector2.ZERO
	weapon.visible = false
	body.visible = true
	body.play("hit")
	if light != null:
		light.energy = 0.25
	run.fx.burst(position - Vector2(0, 8), Art.palette(String(hero.get("sprite", "knight_m"))), 26, 90.0, 0.9, 2.8)
	run.shake(1.0)
	Sfx.play("player_die")
	G.player_died.emit()
	run.player_died(last_cause)


# =============================================================================== getting things
## Hands the player a bundle: {"coins": n, "hp": n, "max_hp": n, "armor": n, "keys": n, "bombs": n}.
## Returns how many coins were really added (the coin multiplier can add extras).
func give(bundle: Dictionary) -> int:
	var coins_added := 0
	if bundle.has("coins"):
		var raw := float(bundle["coins"]) * stats.v("coin_mult")
		coins_added = int(raw)
		if randf() < raw - float(coins_added):
			coins_added += 1
		coins += coins_added
		coins_collected += coins_added
		G.stat.emit("coins", coins_added)
		run.effects.fire("on_coins", [coins_added])
	if bundle.has("max_hp"):
		max_hp = clampi(max_hp + int(bundle["max_hp"]), 2, MAX_HP)
		hp = mini(hp, max_hp)
	if bundle.has("hp"):
		hp = mini(max_hp, hp + int(bundle["hp"]))
	if bundle.has("armor"):
		armor = mini(MAX_ARMOR, armor + int(bundle["armor"]))
	if bundle.has("keys"):
		keys += int(bundle["keys"])
	if bundle.has("bombs"):
		bombs += int(bundle["bombs"])
	G.hud_changed.emit()
	return coins_added


## True when a pickup with this "need" would be useful right now (hearts are left on the floor at full health).
func wants(need: String) -> bool:
	if need == "hurt":
		return hp < max_hp
	return true


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	run.effects.fire("on_coins", [-amount])
	G.hud_changed.emit()
	return true


func add_item(item_id: String) -> void:
	var info: Dictionary = Items.info(item_id)
	items.append(item_id)
	if info.has("mods"):
		stats.set_layer("item:" + item_id, info["mods"])
	if info.has("give"):
		give(info["give"])
	if info.has("familiar"):
		add_familiar(String(info["familiar"]))
	Save.mark_seen(item_id)
	G.stat.emit("item_taken", 1)
	if info.get("cursed", false):
		Curse.change_level(run, 1)           # every cursed item makes the Hungry Curse bigger
		G.stat.emit("cursed_taken", 1)
		Sfx.play("cursed_item_pickup")
		run.fx.flash(Color(0.5, 0.0, 0.3, 0.3), 0.3)
	else:
		Sfx.play("item_pickup")
	run.fx.ring(position - Vector2(0, 8), 4.0, 30.0, 0.45, Color(1, 0.95, 0.6), 2.0)
	run.effects.item_added(item_id)
	G.item_acquired.emit(item_id)
	G.hud_changed.emit()


func add_familiar(familiar_id: String) -> void:
	var f: Node2D = FamiliarScript.new()
	f.setup(run, self, familiar_id, familiars.size())
	familiars.append(f)
	if room != null:
		f.position = position + Vector2(-10, -2)
		room.ysort.add_child(f)
		G.hud_changed.emit()


func place_bomb() -> void:
	if dead or bombs <= 0 or room == null or run.busy() or get_tree().paused:
		return
	bombs -= 1
	room.add_bomb(position)
	G.stat.emit("bomb_used", 1)
	Sfx.play("bomb_place")
	G.hud_changed.emit()
