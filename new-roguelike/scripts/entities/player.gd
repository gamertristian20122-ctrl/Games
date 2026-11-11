extends Node2D
## Player: the hero you control. One node that lives for the whole run and is moved from room to room.
##   position      the middle of a small circle at the FEET (radius 5). The sprite stands on it.
##   look          body = a hero sprite (idle / run / death), weapon = a separate still held in the
##                 hand and turned toward the aim (scripts/entities/hero_look.gd). Hurt = white flash + blink.
##   hp, max_hp, armor   in HALF hearts.   coins, keys, bombs   plain counts.   items   ids in pickup order.
##   stats         all the numbers (see scripts/run/stats.gd). Items change them through layers.
## It reads Controls.move / Controls.aim every physics frame, fires by itself while aiming,
## and places a bomb when Controls.bomb_pressed fires.
## Item logic does NOT live here: see scripts/data/items.gd and scripts/run/item_effects.gd.
## The few item flags read here: ring (volleys leave in a full circle), coin_ward (a hit is paid in
## coins; the flag's value is the price), and the shot flags turned into Shots.B_ bits in _stats_changed().

const Stats = preload("res://scripts/run/stats.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Items = preload("res://scripts/data/items.gd")
const Shots = preload("res://scripts/run/shots.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const FamiliarScript = preload("res://scripts/entities/familiar.gd")
const Curse = preload("res://scripts/entities/curse.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")

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
var _flash := 0.0
var _sprite_id := ""
var _has_hit := false
var _has_death := false
var _mid := 8.0             ## how far above the feet the middle of the body is (effects aim at it)


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
	_sprite_id = String(hero.get("sprite", "pc_knight"))
	_has_hit = Art.has_anim(_sprite_id, "hit")
	_has_death = Art.has_anim(_sprite_id, "death")
	var m := Art.meta(_sprite_id)
	_mid = float(m.get("body_height", 16.0)) * 0.4
	shadow = EnemyScript.make_shadow(clampf(float(m.get("body_width", 16.0)) * 0.85, 13.0, 18.0))
	add_child(shadow)
	# the weapon is a child just before or just after the body: behind it when aiming up
	weapon = HeroLook.make_weapon(hero)
	add_child(weapon)
	body = Art.sprite(_sprite_id)
	body.position = Vector2(0, 2)
	add_child(body)
	HeroLook.rest(weapon, 1.0)
	HeroLook.layer(weapon, body, true)
	if run.LIGHTING:
		light = PointLight2D.new()
		light.texture = run.light_tex
		light.texture_scale = 3.2
		light.energy = 0.55
		light.color = run.theme.get("light", Color(1, 0.9, 0.7))
		light.position = Vector2(0, -_mid)
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
		"bits": _shot_bits(),
	}


## Which tricks the hero's own shots carry (item flags -> the B_ bits of scripts/run/shots.gd).
func _shot_bits() -> int:
	var b := Shots.B_HERO
	for pair: Array in [["return", Shots.B_RETURN], ["reap", Shots.B_REAP], ["bounce_grow", Shots.B_GROW],
			["eat_shots", Shots.B_EAT], ["curse_shove", Shots.B_SHOVE], ["eclipse", Shots.B_ECLIPSE]]:
		if stats.has_flag(pair[0]):
			b |= int(pair[1])
	return b


## Fires `amount` of the hero's own shots in an even ring (items use this: Cry of Knives).
func fire_ring(amount: int, range_mult: float = 1.0) -> void:
	var speed := stats.v("shot_speed")
	var turn := aim_dir.angle()
	for k in amount:
		var a := turn + TAU * float(k) / float(amount)
		run.shots.fire(position + Vector2(cos(a), sin(a)) * 7.0, Vector2(cos(a), sin(a)) * speed, Shots.SIDE_PLAYER,
			stats.v("damage"), stats.v("range") * range_mult, String(hero.get("shot", "blade")), _shot_extra)


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
		if _has_death:
			body.modulate.a = clampf(2.2 - _dead_t, 0.0, 1.0)      # the pack's own fall, then a slow fade
		else:
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
	run.effects.fire("on_tick", [delta])
	_update_look(delta)


func _fire() -> void:
	var n := maxi(1, int(stats.v("shots")))
	var spread := stats.v("spread")
	var speed := stats.v("shot_speed")
	var from := position + aim_dir * 7.0
	var ring := stats.has_flag("ring")       # Breaking Wheel: the volley leaves in a full circle
	for k in n:
		var a := aim_dir.angle() + (float(k) - float(n - 1) * 0.5) * 0.17
		if ring:
			a = aim_dir.angle() + TAU * float(k) / float(n)
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
	if _flash > 0.0:
		_flash -= delta
		body.material = EnemyScript.white_material()
	elif body.material != null:
		body.material = null
	if _hit_anim > 0.0 and _has_hit:
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
		HeroLook.layer(weapon, body, HeroLook.aim(weapon, aim_dir, _kick, _face))
	else:
		HeroLook.rest(weapon, _face, delta)
		HeroLook.layer(weapon, body, true)
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
		draw_arc(Vector2(0, -_mid), _mid + 4.0 + (1.0 - k) * 8.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, k), 2.0)
		draw_circle(Vector2(0, -_mid), _mid + 4.0, Color(0.6, 0.85, 1.0, 0.25 * k))
	elif ward_ready and not dead:
		# a quiet circle on the floor around the feet (flattened, like the shadows)
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.30), 1.0)
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
		run.fx.ring(position - Vector2(0, _mid), 6.0, 24.0, 0.3, Color(0.6, 0.85, 1.0), 2.0)
		Sfx.play("shot_hit_wall", -2.0)
		queue_redraw()
		return
	var amount := maxi(1, int(round(float(half_hearts) * stats.v("hurt_mult"))))
	var ransom := int(stats.flag("coin_ward"))       # Ransom Plate: the hit is paid in coins while the purse can
	if ransom > 0 and coins >= ransom:
		coins -= ransom
		amount = 0
		run.fx.burst(position - Vector2(0, _mid), [Color(1, 0.85, 0.3), Color(1, 1, 0.7)], ransom * 2, 90.0, 0.6, 2.0)
		Sfx.play("coin_pickup", -2.0, 0.05, 0.7)
		run.effects.fire("on_coins", [-ransom])
	var from_armor := mini(armor, amount)
	armor -= from_armor
	hp -= amount - from_armor
	damage_taken += amount
	last_cause = cause
	invuln = stats.v("invuln")
	_hit_anim = 0.3
	_flash = 0.07            # a few frames of white, then the usual blink
	var away := position - from
	knock = (away.normalized() if away.length() > 0.5 else Vector2.DOWN) * 150.0
	run.shake(0.55)
	run.hitstop(0.05)
	if amount > 0:
		run.fx.burst(position - Vector2(0, _mid), [Color(1, 0.3, 0.3), Color(1, 1, 1)], 8, 70.0, 0.4, 2.2)
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
	body.material = null
	body.play("death" if _has_death else "hit")
	if light != null:
		light.energy = 0.25
	run.fx.burst(position - Vector2(0, _mid), Art.palette(_sprite_id), 14 if _has_death else 26, 90.0, 0.9, 2.8)
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
		var spare := hp + int(bundle["hp"]) - max_hp
		hp = mini(max_hp, hp + int(bundle["hp"]))
		if spare > 0:
			_helpers("stash", spare)          # the Blood Porter keeps what does not fit
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
		return hp < max_hp or _helpers("can_carry", 1)
	return true


## Asks every familiar whose behaviour file has `method(f, amount) -> bool`; true when one said yes.
func _helpers(method: String, amount: int) -> bool:
	for f in familiars:
		if is_instance_valid(f) and f.behaviour.has_method(method) and f.behaviour.call(method, f, amount):
			return true
	return false


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
	run.fx.ring(position - Vector2(0, _mid), 4.0, 30.0, 0.45, Color(1, 0.95, 0.6), 2.0)
	run.effects.item_added(item_id)
	run.effects.fire("on_item", [item_id])
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
