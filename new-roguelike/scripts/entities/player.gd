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
const Hands = preload("res://scripts/entities/hands.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const HeroSkills = preload("res://scripts/entities/hero_skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const AllyScript = preload("res://scripts/entities/ally.gd")

const ACCEL := 950.0
const DECEL := 1500.0
const MAX_HP := 32               ## 16 hearts: two rows of eight on the HUD
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
var off_hand: RefCounted        ## the free hand (hands.gd); the other one holds the weapon
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
	body.modulate = hero.get("tint", Color.WHITE)        # the armour colour chosen at the mirror (looks.gd)
	add_child(body)
	HeroLook.rest(weapon, 1.0)
	HeroLook.layer(weapon, body, true)
	if String(hero.get("hand", "")) != "":
		off_hand = Hands.new()
		off_hand.build(self, body, String(hero["hand"]), float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)), true)
		if bool(hero.get("twin", false)) and off_hand.far != null:
			# twin daggers: the second one rides in the free hand
			var second := Sprite2D.new()
			second.texture = weapon.texture
			second.centered = false
			second.offset = weapon.offset
			second.rotation = 0.5
			second.show_behind_parent = true
			off_hand.far.add_child(second)
	if run.LIGHTING:
		light = PointLight2D.new()
		light.texture = run.light_tex
		light.texture_scale = 3.2
		light.energy = 0.55
		light.color = run.theme.get("light", Color(1, 0.9, 0.7))
		light.position = Vector2(0, -_mid)
		add_child(light)
	if hero.has("melee"):
		# what the camp's smith and cook have done for him (scripts/data/upgrades.gd)
		var camp := Upgrades.mods()
		if not camp.is_empty():
			stats.set_layer("camp", camp)
		max_hp = mini(max_hp + Upgrades.bonus_hp() + int(G.diff("hearts")), MAX_HP)
		hp = max_hp
		block_max = maxi(int(G.diff("block")), 1)
		block_left = block_max
		_block_cool = maxf(BLOCK_COOLDOWN + Upgrades.block_cooldown(), 1.5)
		apply_rpg(true)
		# the companion who travels with him (scripts/data/allies.gd); not into the training yard
		var mate := Allies.with() if G.arg("ally") == "" else Allies.row(G.arg("ally"))      # --ally=<id>: a test
		if not mate.is_empty() and run.get("training") != true:
			ally = AllyScript.new()
			ally.setup(run, self, mate)
	stats.changed.connect(_stats_changed)
	_stats_changed()
	_hook_bomb_button()
	if hero.has("familiar"):
		add_familiar(String(hero["familiar"]))


## RPG: turns the knight's stat points (scripts/data/rpg.gd) into numbers. Called at the start of
## a level, and again whenever a point is spent on the Knight screen in the middle of one.
## Vitality gives health at once (the new half heart comes filled).
## The gear he wears (scripts/data/gear.gd) goes through here too: its stats layer "gear", its
## hearts, the chance that a blow glances off, and (at the start of a level) its blue hearts.
var ally: Node2D                 ## the companion travelling with him (scripts/entities/ally.gd), or null
var skills: RefCounted           ## his mana and skills (scripts/entities/hero_skills.gd); null for the old heroes
var _rpg_hp := 0
var glance := 0.0                ## chance that a blow glances off his armour (Gear.ward())
func apply_rpg(fresh: bool = false) -> void:
	if not hero.has("melee"):
		return
	stats.set_layer("rpg", Rpg.mods())
	stats.set_layer("gear", Gear.mods())
	if skills == null:
		skills = HeroSkills.new()
		skills.setup(self)
	else:
		skills.refresh()
	glance = Gear.ward()
	if fresh:
		armor = mini(armor + Gear.shield(), MAX_ARMOR)
	var more := Rpg.bonus_hp() + Gear.bonus_hp() - _rpg_hp
	if more != 0:
		_rpg_hp += more
		max_hp = clampi(max_hp + more, 2, MAX_HP)
		hp = clampi(hp + maxi(more, 0), 1, max_hp)
	_block_cool = maxf((BLOCK_COOLDOWN + Upgrades.block_cooldown()) * Rpg.guard_mult() * Gear.guard_mult(), 1.5)
	if not fresh:
		G.hud_changed.emit()


## A new level: every heart is filled again.
func level_up_heal() -> void:
	if dead:
		return
	hp = max_hp
	G.hud_changed.emit()


## The hero is taken out of the tree and put back at every room change, so the bomb button is
## hooked up each time he comes back (hooking it up only once left bombs dead after the first room).
func _enter_tree() -> void:
	_hook_bomb_button()


func _hook_bomb_button() -> void:
	if not Controls.bomb_pressed.is_connected(place_bomb):
		Controls.bomb_pressed.connect(place_bomb)
	if not Controls.action_pressed.is_connected(_on_block_tap):
		Controls.action_pressed.connect(_on_block_tap)
	if not Controls.skill_pressed.is_connected(_on_skill):
		Controls.skill_pressed.connect(_on_skill)


func _exit_tree() -> void:
	if Controls.bomb_pressed.is_connected(place_bomb):
		Controls.bomb_pressed.disconnect(place_bomb)
	if Controls.action_pressed.is_connected(_on_block_tap):
		Controls.action_pressed.disconnect(_on_block_tap)
	if Controls.skill_pressed.is_connected(_on_skill):
		Controls.skill_pressed.disconnect(_on_skill)


## A skill button was pressed (not while the game is paused or the guard is up).
func _on_skill(slot: int) -> void:
	if skills == null or dead or blocking or get_tree().paused:
		return
	if not skills.use(slot) and String(skills.said) != "":
		G.skill_refused.emit(String(skills.said))


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


## The knight's guard (the second button: tap it or hold it). It covers him on ALL sides, so there
## is nothing to aim. It takes BLOCK_HITS blows, then it breaks and needs a rest before it is whole
## again (a blow it took also starts that rest, so a half-used guard mends by itself).
## While it is up he walks a little slower and cannot swing.
const BLOCK_HITS := 2            ## blows the guard stops before it breaks
const BLOCK_COOLDOWN := 5.0      ## seconds until the guard is whole again (camp upgrade "Mend the guard" shortens it)
const BLOCK_TAP := 0.8           ## a tap keeps the guard up this long; holding keeps it up as long as you hold
const BLOCK_WALK := 0.6          ## walking speed while the guard is up
var blocking := false
var block_max := BLOCK_HITS      ## blows a whole guard stops (3 on Easy)
var block_left := BLOCK_HITS     ## blows the guard can still take (touch.gd shows it)
var block_fill := 1.0            ## 0..1: how far the guard has mended (touch.gd draws the ring)
var _block_cool := BLOCK_COOLDOWN
var _block_cd := 0.0
var _guard_t := 0.0
var _guard: Node2D

func _on_block_tap() -> void:
	if hero.has("melee") and not dead and block_left > 0:
		_guard_t = BLOCK_TAP


func _update_block(delta: float) -> void:
	if not hero.has("melee"):
		return
	if block_left < block_max:
		_block_cd -= delta
		if _block_cd <= 0.0:
			block_left = block_max
			Sfx.play("door_open", -14.0, 0.0, 1.8)
	block_fill = 1.0 if block_left >= block_max else 1.0 - clampf(_block_cd / maxf(_block_cool, 0.1), 0.0, 1.0)
	_guard_t = maxf(0.0, _guard_t - delta)
	blocking = not dead and block_left > 0 and (Controls.action_held or _guard_t > 0.0)
	if _guard == null:
		_guard = Node2D.new()
		_guard.z_index = 2
		_guard.draw.connect(_draw_guard)
		add_child(_guard)
	_guard.visible = blocking
	if blocking:
		_guard.queue_redraw()


## The guard: one pale half-ring for every blow it can still take (a flat code-drawn shape).
func _draw_guard() -> void:
	var part := TAU / float(block_max)
	for i in block_left:
		var a0 := part * float(i) + 0.3 - PI * 0.5
		_guard.draw_arc(Vector2(0, -9), 15.0, a0, a0 + part - 0.6, 14, Color(0.75, 0.9, 1.0, 0.9), 2.0)
		_guard.draw_arc(Vector2(0, -9), 12.5, a0 + 0.1, a0 + part - 0.7, 12, Color(0.75, 0.9, 1.0, 0.3), 2.0)


## A blow lands on the raised guard: it is stopped and the guard is one blow weaker.
func _blocked() -> bool:
	if not blocking:
		return false
	block_left -= 1
	_block_cd = _block_cool
	if block_left <= 0:
		_guard_t = 0.0
		run.fx.ring(position - Vector2(0, 9), 14.0, 30.0, 0.3, Color(0.75, 0.9, 1.0), 2.0)
		Sfx.play("rock_break", -6.0, 0.05, 1.3)
		run.shake(0.25)
	return true


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
	_update_block(delta)
	var want: Vector2 = Controls.move * stats.v("speed") * (BLOCK_WALK if blocking else 1.0)
	vel = vel.move_toward(want, (ACCEL if want != Vector2.ZERO else DECEL) * delta)
	position = room.move_circle(position, radius, (vel + knock) * delta, stats.has_flag("flying"), true)
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	if room.spikes_hurt(position) and _spike_cd <= 0.0 and not stats.has_flag("flying"):
		_spike_cd = 0.3
		hurt(1, position + Vector2(0, 1), "spikes")
	# ---- aiming and firing
	var aim: Vector2 = Controls.aim
	firing = aim.length() > Controls.AIM_DEADZONE and not blocking
	if firing:
		aim_dir = aim.normalized()
	_fire_cd -= delta
	if firing and _fire_cd <= 0.0:
		_fire()
		_fire_cd = 1.0 / (swing_rate() if hero.has("melee") else stats.v("rate"))
	if not _cuts.is_empty():
		_tick_cuts(delta)
	if skills != null:
		skills.tick(delta)
	run.effects.fire("on_tick", [delta])
	_update_look(delta)


func _fire() -> void:
	if hero.has("melee"):
		_swing()
		return
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


## THE KNIGHT'S SWORD. One swing sweeps an arc in front of him: every monster inside is hit at once
## (a boss's guard still stops it) and enemy shots inside are cut out of the air.
## The items were written for thrown shots; this is what each stat and flag means FOR A SWORD
## (the words the player reads are in scripts/data/items.gd):
##   damage, knockback   as they say               rate         swings per second
##   range, shot_size    a longer reach            shot_speed   a quicker (or slower) swing
##   shots               that many cuts per swing, one after the other (Twin Hatchets, Storm Axes)
##   return              one more cut on the way back, lighter (Tethered Sickle)
##   ring                every swing is a full spin, a little softer (Breaking Wheel)
##   homing              each swing steps him toward the nearest monster in front (Seeker Staff)
##   pierce              blows bite deeper into elites, big monsters and bosses (Needle Spear, Hollow Bolt)
##   bounce              the shock of a blow jumps on to that many monsters nearby (Ricochet Mallet);
##   bounce_grow         ... harder with every jump (Stonebiter)
##   reap                a killing blow swings again at once, harder each time (Reaping Hook)
##   eat_shots           every enemy shot cut down makes the next blow hit harder (Starveling Blade)
##   Bone Thistle        (hook on_shot_end) three splinters fly from the tip of the blade
const SWING_TIME := 0.14
const ECHO_GAP := 0.10           ## seconds between the cuts of one swing
const BACKSWING := 0.6           ## damage share of the cut on the way back
const RING_SOFT := 0.8           ## damage share of a full spin
const PIERCE_BONUS := 0.15       ## more damage to elites, big monsters and bosses per point of pierce
const CHAIN_REACH := 46.0        ## how far the shock of a blow jumps
const CHAIN_SHARE := 0.6         ## damage share of a jump
const CHAIN_GROW := 1.3          ## Stonebiter: each jump is this much harder than the last
const REAP_MAX := 4              ## free follow-up swings in a row
const REAP_GROW := 1.25
const EAT_STEP := 0.2            ## Starveling Blade: +20% on the next blow per shot cut down ...
const EAT_MAX := 1.0             ## ... up to +100%
const LUNGE := 58.0              ## px/s of step per point of homing
var _swing_t := 0.0
var _swing_side := 1.0
var _swing_arc := 2.3
var _swing_reach := 34.0
var _slash: Node2D
var _cuts: Array = []            ## cuts still to come: [seconds from now, damage share]
var _eat_bonus := 0.0
var _reaps := 0

## How far the blade reaches from his middle, with everything he carries.
func melee_reach() -> float:
	var m: Dictionary = hero["melee"]
	var k: float = stats.v("range") / maxf(float(hero.get("range", 100.0)), 1.0)
	return float(m.get("reach", 34.0)) * clampf(1.0 + 0.6 * (k - 1.0), 0.7, 1.7) * (1.0 + 0.2 * (stats.v("shot_size") - 1.0))


## Swings per second.
func swing_rate() -> float:
	var k: float = stats.v("shot_speed") / maxf(float(hero.get("shot_speed", 150.0)), 1.0)
	return stats.v("rate") * clampf(sqrt(k), 0.6, 1.35)


func _swing() -> void:
	var m: Dictionary = hero["melee"]
	var spin := stats.has_flag("ring")
	_swing_arc = TAU if spin else float(m.get("arc", 2.3))
	_swing_reach = melee_reach()
	_reaps = 0
	# Seeker Staff: a step toward the nearest monster in front of him
	var pull: float = stats.v("homing")
	if pull > 0.0:
		var best: Node = null
		var best_d := _swing_reach * 2.6
		for e in room.enemies:
			if not is_instance_valid(e) or e.dead or not e.hittable:
				continue
			var to: Vector2 = (e.position as Vector2) - position
			if to.length() < best_d and (spin or absf(angle_difference(aim_dir.angle(), to.angle())) < 1.3):
				best_d = to.length()
				best = e
		if best != null and best_d > _swing_reach * 0.7:
			aim_dir = ((best.position as Vector2) - position).normalized()
			knock += aim_dir * minf(LUNGE * pull, 190.0)
	var cuts := 1 if spin else maxi(1, int(stats.v("shots")))
	_cut(RING_SOFT if spin else 1.0)
	for k in range(1, cuts):
		_cuts.append([ECHO_GAP * float(k), 1.0])
	for k in int(stats.flag("return")):
		_cuts.append([ECHO_GAP * float(cuts + k), BACKSWING])
	Sfx.play(String(hero.get("shoot_sfx", "player_shoot_blade")), -10.0, 0.08, 0.8)
	run.effects.fire("on_shot_fired", [position + aim_dir * 7.0, aim_dir])
	# items that wait for a shot to end (Bone Thistle) hear it at the tip of the blade
	run.shots.end_victim = 0
	run.effects.fire("on_shot_end", [position + aim_dir * _swing_reach * 0.8, aim_dir, stats.v("damage"), false])


## One cut through the arc. `share` is how much of his damage it carries.
func _cut(share: float) -> void:
	var m: Dictionary = hero["melee"]
	var damage: float = stats.v("damage") * share * (1.0 + _eat_bonus)
	var shove: float = float(m.get("knock", 1.6)) * stats.v("knockback")
	var pierce: float = stats.flag("pierce")
	var struck: Array = []
	var killed := false
	for e in room.enemies.duplicate():
		if not is_instance_valid(e) or e.dead or not e.hittable or e.get("shielded") == true:
			continue
		var to: Vector2 = (e.position as Vector2) - Vector2(0.0, float(e.hit_up) * 0.5) - position
		var far: float = to.length() - float(e.radius) - float(e.hit_grow)
		if far > _swing_reach:
			continue
		if far > 4.0 and absf(angle_difference(aim_dir.angle(), to.angle())) > _swing_arc * 0.5:
			continue
		var d := damage
		if pierce > 0.0 and (e.elite or "boss_id" in e or bool(e.data.get("big", false))):
			d *= 1.0 + PIERCE_BONUS * pierce
		_strike(e, d, to.normalized(), shove)
		struck.append(e)
		killed = killed or e.dead
	# Ricochet Mallet, Stonebiter: the shock of the blow jumps on
	var jumps := int(stats.flag("bounce"))
	if jumps > 0 and not struck.is_empty():
		var last: Node = struck[0]
		var d2 := damage * CHAIN_SHARE
		for j in jumps:
			var next: Node = null
			var best := CHAIN_REACH
			for e in room.enemies:
				if not is_instance_valid(e) or e.dead or not e.hittable or struck.has(e):
					continue
				var gap: float = (e.position as Vector2).distance_to(last.position) - float(e.radius)
				if gap < best:
					best = gap
					next = e
			if next == null:
				break
			if stats.has_flag("bounce_grow"):
				d2 *= CHAIN_GROW
			var dir: Vector2 = ((next.position as Vector2) - (last.position as Vector2)).normalized()
			run.fx.ring((last.position as Vector2) - Vector2(0, float(last.hit_up)), 3.0, 12.0, 0.18, Color(1, 1, 1, 0.8), 1.5)
			_strike(next, d2, dir, shove * 0.5)
			struck.append(next)
			killed = killed or next.dead
			last = next
	# the war hammer smashes rocks and logs inside the swing
	if bool(m.get("break", false)):
		for i in room.grid.size():
			if room.grid[i] != room.ROCK and room.grid[i] != room.CRATE:
				continue
			var to3: Vector2 = Vector2((i % G.ROOM_COLS) * 16 + 8, (i / G.ROOM_COLS) * 16 + 8) - position
			if to3.length() <= _swing_reach + 4.0 and absf(angle_difference(aim_dir.angle(), to3.angle())) <= _swing_arc * 0.5:
				room.break_cell(i)
	# enemy shots inside the arc are cut down
	var eaten := 0
	var shots: Node = run.shots
	for i in shots.count:
		if shots.side[i] != Shots.SIDE_ENEMY or shots.left[i] <= 0.0:
			continue
		var to2: Vector2 = shots.pos[i] - Vector2(0.0, 7.0) - position
		if to2.length() <= _swing_reach + 2.0 and absf(angle_difference(aim_dir.angle(), to2.angle())) <= _swing_arc * 0.5:
			shots.left[i] = 0.0
			eaten += 1
			run.fx.burst(shots.pos[i] - Vector2(0.0, 7.0), [Color(1, 1, 1)], 3, 50.0, 0.18, 2.0)
	if not struck.is_empty():
		_eat_bonus = 0.0                      # the stored force went into this blow
	if eaten > 0 and stats.has_flag("eat_shots"):
		_eat_bonus = minf(_eat_bonus + EAT_STEP * float(eaten), EAT_MAX)
	# Reaping Hook: a killing blow swings again
	if killed and stats.has_flag("reap") and _reaps < REAP_MAX:
		_reaps += 1
		_cuts.append([0.08, share * REAP_GROW])
	_swing_t = SWING_TIME
	_swing_side = -_swing_side
	if _slash == null:
		_slash = Node2D.new()
		_slash.z_index = 2
		_slash.draw.connect(_draw_slash)
		add_child(_slash)
	_slash.queue_redraw()


func _strike(e: Node, damage: float, dir: Vector2, shove: float) -> void:
	e.hurt(damage, dir, shove)
	var daze := float((hero["melee"] as Dictionary).get("stun", 0.0))      # the war hammer
	if daze > 0.0 and not ("boss_id" in e) and is_instance_valid(e) and not e.dead:
		e.stun = maxf(e.stun, daze)
	run.effects.fire("on_hit", [e, damage, e.position])
	run.fx.burst((e.position as Vector2) - Vector2(0, float(e.hit_up)), [Color(1, 1, 1), Color(0.8, 0.9, 1.0)], 4, 70.0, 0.2, 2.0, dir)


## The later cuts of a swing (second and third cuts, the backswing, a reaping follow-up).
func _tick_cuts(delta: float) -> void:
	if dead:
		_cuts.clear()
		return
	var due: Array = []
	for c: Array in _cuts:
		c[0] = float(c[0]) - delta
		if float(c[0]) <= 0.0:
			due.append(c)
	for c: Array in due:
		_cuts.erase(c)
		_cut(float(c[1]))
		Sfx.play(String(hero.get("shoot_sfx", "player_shoot_blade")), -14.0, 0.1, 1.0)


## The white crescent a swing leaves for a moment (a flat code-drawn shape, like the other effects).
func _draw_slash() -> void:
	if _swing_t <= 0.0:
		return
	var k := 1.0 - _swing_t / SWING_TIME                    # 0 -> 1 through the swing
	var mid := aim_dir.angle()
	var a0 := mid - _swing_arc * 0.5 * _swing_side
	var a1 := a0 + _swing_arc * _swing_side * clampf(k * 1.4 + 0.25, 0.0, 1.0)
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / float(steps))
		pts.append(Vector2(0, -9) + Vector2.RIGHT.rotated(a) * _swing_reach)
	for i in range(steps, -1, -1):
		var a := lerpf(a0, a1, float(i) / float(steps))
		var thick := 7.0 * sin(PI * float(i) / float(steps))
		pts.append(Vector2(0, -9) + Vector2.RIGHT.rotated(a) * (_swing_reach - thick))
	_slash.draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.75 * (1.0 - k)))


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
	if off_hand != null:
		off_hand.update(delta, moving, _face, 0.0, body.visible, body.material)
	# the weapon: held in the hand, pointing where you aim, kicking back with each shot
	_kick = maxf(0.0, _kick - delta * 9.0)
	if _swing_t > 0.0:
		# the blade sweeps through the arc
		_swing_t -= delta
		var k := 1.0 - maxf(_swing_t, 0.0) / SWING_TIME
		var dir := aim_dir.rotated((k - 0.5) * _swing_arc * _swing_side)
		HeroLook.layer(weapon, body, HeroLook.aim(weapon, dir, 0.0, _face))
		_slash.queue_redraw()
	elif blocking:
		# the sword held upright in front of him
		HeroLook.layer(weapon, body, HeroLook.aim(weapon, Vector2(0.35 * _face, -1.0).normalized(), 0.0, _face))
	elif firing:
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
	if cause != "spikes" and _blocked():
		invuln = 0.35
		var away := (position - from).normalized() if position.distance_to(from) > 0.5 else Vector2.ZERO
		knock = away * 70.0
		run.fx.burst(position - Vector2(0, 9) - away * 13.0, [Color(1, 1, 1), Color(0.75, 0.9, 1.0)], 6, 80.0, 0.2, 2.0, -away)
		Sfx.play("shot_hit_wall", -3.0, 0.06, 1.3)
		return
	if ward_ready:
		ward_ready = false
		_ward_flash = 0.45
		invuln = 0.5
		run.fx.ring(position - Vector2(0, _mid), 6.0, 24.0, 0.3, Color(0.6, 0.85, 1.0), 2.0)
		Sfx.play("shot_hit_wall", -2.0)
		queue_redraw()
		return
	if glance > 0.0 and randf() < glance:
		# the blow glances off his armour (gear's "ward"): sparks, a clink, a moment of safety
		invuln = 0.4
		run.fx.burst(position - Vector2(0, _mid), [Color(1, 1, 1), Color(0.8, 0.85, 0.95)], 5, 70.0, 0.2, 1.8)
		Sfx.play("shot_hit_wall", -3.0, 0.06, 1.5)
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
		if run.get("training") == true:
			hp = max_hp                  # the yard: he gets back up
			G.toast.emit("Again!", "Nobody dies in the yard")
		elif god:
			hp = 1
		else:
			hp = 0
			_die()
	G.hud_changed.emit()


func _die() -> void:
	dead = true
	vel = Vector2.ZERO
	weapon.visible = false
	if off_hand != null:
		off_hand.hide()
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
	if bundle.has("boss_key"):
		run.take_boss_key()
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
