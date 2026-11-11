extends Node2D
## The Hungry Curse: the game's signature mechanic. A black disc that hunts the hero through
## every locked room and swallows whatever it touches: monsters, their shots, bombs, or the hero.
## The room makes one when a fight starts (room.curse) and it sinks away when the fight is won.
##
## THE RULES IN SHORT
##   It rises 1 s after the doors lock, at the far side of the room, then CREEPS straight at the hero.
##   Its lunge timer fills while it creeps (the rim shows it). When full: a pale STRIPE runs from the
##   disc through the hero to the wall, follows for a moment, locks and flashes, then the disc
##   LUNGES along it. The CALL button (Controls.action_pressed) locks the stripe at once.
##   Lit rim = it bites. Dark rim = safe (rising, sated after biting the hero, stunned by a bomb).
##   Small enemies are swallowed whole (no death effect, no loot, +1 coin in the belly); big ones
##   lose half their health per bite; a boss loses a few percent and knocks the disc back.
##   Enemy shots die on it. Hero shots pass through and only slow it down for a moment.
##   A bomb blast stuns it and makes it cough up every coin in its belly.
##   A lunge that ends next to a hidden door cracks the wall; a second one opens it.
##
## This file holds the RULES and EVERY NUMBER. How it looks is scripts/entities/curse_look.gd.
## What lasts between rooms lives on the run: run.curse_level, run.belly, run.starve_bought, run.call_cd.
## Three numbers come from the hero's stats so items can change them (scripts/run/stats.gd):
## call_cooldown, curse_creep, belly_mult.

const Look = preload("res://scripts/entities/curse_look.gd")

# ------------------------------------------------------------------ words the player sees
const CAUSE := "your own Curse"          ## on the death screen
const FEAST_TEXT := "FEAST"              ## stamped when one lunge swallows FEAST_MEALS or more

# ------------------------------------------------------------------ Curse Level 0..5
## radius px, belly = most coins it can hold, bite = half hearts the hero loses, boss_pct = % of a boss's health per bite
const LEVELS := [
	{"radius": 12.0, "belly": 5, "bite": 1, "boss_pct": 5.0},
	{"radius": 14.0, "belly": 7, "bite": 1, "boss_pct": 6.0},
	{"radius": 16.0, "belly": 9, "bite": 1, "boss_pct": 7.0},
	{"radius": 18.0, "belly": 11, "bite": 2, "boss_pct": 8.0},
	{"radius": 20.0, "belly": 13, "bite": 2, "boss_pct": 9.0},
	{"radius": 22.0, "belly": 15, "bite": 2, "boss_pct": 10.0},
]
const MAX_LEVEL := 5
const TEETH_LEVEL := 3                   ## from this level the bite is a full heart and the rim shows teeth

# ------------------------------------------------------------------ appearing
const SPAWN_POINTS: Array[Vector2] = [Vector2(32, 32), Vector2(240, 32), Vector2(32, 80), Vector2(240, 80), Vector2(24, 56), Vector2(248, 56)]
const RISE_DELAY := 1.0                  ## seconds after the doors lock
const RISE_TIME := 1.0                   ## seconds it takes to rise (harmless)
const SINK_TIME := 0.5
# ------------------------------------------------------------------ moving
const CREEP_SPEED := 26.0                ## px/s (times the hero's "curse_creep" stat)
const FLINCH_SPEED := 8.0                ## px/s for FLINCH_TIME after a hero shot passes through it
const FLINCH_TIME := 0.4
const FIRST_FILL := 3.0                  ## seconds of creeping before the first lunge in a room
const FILL := 5.0                        ## ... and before every later one
const FOLLOW_TIME := 0.5                 ## the stripe follows the hero this long
const LOCK_TIME := 0.5                   ## then it is locked and flashes this long
const LUNGE_SPEED := 260.0
const WINDED_TIME := 1.5                 ## it stands still this long after a lunge
# ------------------------------------------------------------------ eating
const HERO_BITE_PAD := 2.0               ## the hero is bitten only this close past the rim (forgiving on purpose)
const SATED_TIME := 3.0                  ## after biting the hero: dark, frozen, harmless
const SWALLOW_TIME := 0.2                ## an enemy shrinks into the disc
const MEAL_HITSTOP := 0.06
const BIG_BITE := 0.5                    ## elites and "big" enemies lose this share of max health per bite
const BIG_SHOVE := 32.0                  ## px they are pushed away
const BIG_BITE_GAP := 1.0                ## seconds between two bites on the same big enemy
const BOSS_BOUNCE := 48.0                ## px the disc is knocked back after biting a boss
const BOSS_REST := 3.0                   ## seconds it then stands still (and cannot bite the boss)
const BOSS_FLINCH := 0.6                 ## seconds the boss is stunned
const BOSS_FLOOR := 0.10                 ## bites never take a boss below this share of its health
const BOSS_FEAT := 0.30                  ## share of one boss's health eaten that counts for the "Iron Leash" unlock
const BELLY_PAY := 1                     ## coins per enemy swallowed (summoned minions pay nothing)
const BELLY_PAY_ELITE := 3
const FEAST_MEALS := 3
const FEAST_TIME := 1.0
# ------------------------------------------------------------------ bombs and walls
const BOMB_REACH := 30.0                 ## a blast this close to the rim stuns it
const STUN_TIME := 4.0
const COUGH_SPEED_MIN := 45.0            ## coins fly out and land about 24-40 px away
const COUGH_SPEED_MAX := 70.0
const COUGH_MAX_PICKUPS := 12            ## bigger hauls come out partly as 5-coin pieces
const CRACK_REACH := 22.0                ## a lunge ending this close (past the rim) to a hidden door cracks it

enum { WAIT, RISING, CREEP, FOLLOW, LOCK, LUNGE, WINDED, SATED, STUNNED, SINKING }
const STATE_NAMES := ["wait", "rising", "creep", "follow", "lock", "lunge", "winded", "sated", "stunned", "sinking"]

const FLOOR_Z := -6                      ## above the floor tiles and spikes, below shadows and every sprite
const SHOVE_SPEED := 182.0               ## start speed that carries a shoved enemy about BIG_SHOVE px

var room: Node
var run: Node
var player: Node
var state := WAIT
var t := RISE_DELAY              ## seconds left in the current state
var level := 0
var radius := 12.0
var fill := 0.0                  ## the lunge timer, 0..1
var fill_time := FIRST_FILL
var aim_dir := Vector2.RIGHT     ## where the stripe points
var lunge_end := Vector2.ZERO
var solid := false               ## fully risen: stops enemy shots, flinches, can be bombed
var block_radius := 0.0          ## read by scripts/run/shots.gd (room.blockers); 0 while not solid
var called := false              ## the current lunge was started with CALL
var meals_in_lunge := 0
var boss_eaten := 0.0            ## share of the boss's health eaten in this fight
var age := 0.0
# ---- feedback the look reads
var gulp := 0.0
var belly_pop := 0.0
var flinching := 0.0
var feast_t := 0.0
var _floaters: Array = []        ## little "+1" numbers: [text, position, seconds left]
var _boss_cd := 0.0
var _boss_feat_done := false
var _last_bite := {}             ## big enemy's instance id -> fight time of its last bite
var _lock_pips := 0
var _vp: SubViewport
var _floor: Sprite2D


# =============================================================================== helpers for other scripts
static func row(lvl: int) -> Dictionary:
	return LEVELS[clampi(lvl, 0, MAX_LEVEL)]


## The most coins the belly holds at the run's current Curse Level.
static func belly_cap(the_run: Node) -> int:
	return int(row(the_run.curse_level)["belly"])


## Raises or lowers the run's Curse Level (kept inside 0..MAX_LEVEL). Returns how much it really changed.
static func change_level(the_run: Node, by: int) -> int:
	var before: int = the_run.curse_level
	the_run.curse_level = clampi(before + by, 0, MAX_LEVEL)
	var change: int = the_run.curse_level - before
	if change != 0:
		G.stat.emit("curse_level_up" if change > 0 else "curse_level_down", absi(change))
		G.hud_changed.emit()
	return change


## Rim lit: touching it right now would cost the hero health, and enemies get eaten.
func lit() -> bool:
	return state == CREEP or state == FOLLOW or state == LOCK or state == LUNGE or state == WINDED


## The stripe is on the floor (the bot reads this to step off it).
func stripe_on() -> bool:
	return state == FOLLOW or state == LOCK or state == LUNGE


func can_call() -> bool:
	return state == CREEP and run.call_cd <= 0.0 and not player.dead


# =============================================================================== setting up
func setup(the_room: Node) -> void:
	room = the_room
	run = room.run
	player = run.player
	_read_level()
	state = WAIT
	t = RISE_DELAY
	z_index = 7
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_build_look()
	Controls.action_pressed.connect(_on_call)


func _exit_tree() -> void:
	if Controls.action_pressed.is_connected(_on_call):
		Controls.action_pressed.disconnect(_on_call)
	if room != null and is_instance_valid(room):
		room.blockers.erase(self)
		if room.curse == self:
			room.curse = null
	if is_instance_valid(_floor):
		_floor.queue_free()


func _read_level() -> void:
	level = clampi(run.curse_level, 0, MAX_LEVEL)
	radius = float(LEVELS[level]["radius"])


## The disc is drawn into a small picture exactly as big as the room's floor (one pixel of it is
## one game pixel) and that picture lies on the floor. This keeps it as chunky as the pixel art.
func _build_look() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(G.ROOM_W, G.ROOM_H)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	var look: Node2D = Look.new()
	look.curse = self
	_vp.add_child(look)
	_floor = Sprite2D.new()
	_floor.texture = _vp.get_texture()
	_floor.centered = false
	_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_floor.material = mat
	_floor.z_as_relative = false
	_floor.z_index = FLOOR_Z
	# a sibling of this node, so it stays on the floor while the disc itself moves
	room.add_child(_floor)


func _go(new_state: int, seconds: float) -> void:
	state = new_state
	t = seconds
	var was := solid
	solid = state != WAIT and state != RISING and state != SINKING
	block_radius = radius if solid else 0.0
	if solid and not was:
		room.blockers.append(self)
	elif was and not solid:
		room.blockers.erase(self)


# =============================================================================== every frame
func _physics_process(delta: float) -> void:
	age += delta
	_tick_feedback(delta)
	if state == SINKING:
		t -= delta
		if t <= 0.0:
			queue_free()
		return
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if _fight_over():
		sink()
		return
	_read_level()
	if solid:
		block_radius = radius
	_boss_cd = maxf(0.0, _boss_cd - delta)
	var from := position
	var arrived := false
	match state:
		WAIT:
			t -= delta
			if t <= 0.0:
				_rise()
		RISING:
			t -= delta
			if t <= 0.0:
				fill = 0.0
				fill_time = FIRST_FILL
				_go(CREEP, 0.0)
		CREEP:
			var to: Vector2 = player.position - position
			var dist := to.length()
			var speed: float = CREEP_SPEED * player.stats.v("curse_creep")
			if flinching > 0.0:
				speed = minf(speed, FLINCH_SPEED)
			if dist > 1.0:
				position = _clamp(position + to / dist * minf(speed * delta, dist))
			fill += delta / fill_time
			if fill >= 1.0:
				fill = 1.0
				_aim_at_hero()
				_go(FOLLOW, FOLLOW_TIME)
				Sfx.play("curse_whisper", -9.0, 0.03, 1.5)
		FOLLOW:
			_aim_at_hero()
			t -= delta
			if t <= 0.0:
				_lock(false)
		LOCK:
			t -= delta
			# a rising tone: three quick pips, each higher than the last
			var pip := int((1.0 - t / LOCK_TIME) * 3.0)
			if pip > _lock_pips and pip < 3:
				_lock_pips = pip
				Sfx.play("ui_click", -6.0, 0.0, 1.0 + 0.3 * pip)
			if t <= 0.0:
				_start_lunge()
		LUNGE:
			var left := position.distance_to(lunge_end)
			var step := LUNGE_SPEED * delta
			if step >= left:
				position = lunge_end
				arrived = true
			else:
				position += aim_dir * step
		WINDED, SATED, STUNNED:
			t -= delta
			if t <= 0.0:
				fill = 0.0
				fill_time = FILL
				_go(CREEP, 0.0)
	if solid:
		_touch_things(from, position)
	if arrived and state == LUNGE:
		_end_lunge()


func _fight_over() -> bool:
	if not room.fighting:
		return true
	for e in room.enemies:
		if not e.dead:
			return false
	return true


func _clamp(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, radius, G.ROOM_W - radius), clampf(p.y, radius, G.ROOM_H - radius))


func _aim_at_hero() -> void:
	var to: Vector2 = player.position - position
	if to.length() > 0.5:
		aim_dir = to.normalized()


func _rise() -> void:
	var best := SPAWN_POINTS[0]
	var best_d := -1.0
	for p in SPAWN_POINTS:
		var d: float = p.distance_squared_to(player.position)
		if d > best_d:
			best_d = d
			best = p
	position = _clamp(best)
	_aim_at_hero()
	_go(RISING, RISE_TIME)
	Sfx.play("curse_whisper", -5.0, 0.03, 0.7)
	run.fx.burst(position, [Color(0.05, 0.04, 0.06), Color(0.30, 0.27, 0.22)], 10, 40.0, 0.6, 2.0)


## When the last enemy dies: harmless at once, gone in half a second.
func sink() -> void:
	if state == SINKING:
		return
	var seen := state != WAIT
	_go(SINKING, SINK_TIME if seen else 0.0)
	if seen:
		Sfx.play("curse_whisper", -12.0, 0.03, 0.55)


# =============================================================================== the stripe and the lunge
func _lock(by_call: bool) -> void:
	_aim_at_hero()
	called = by_call
	_lock_pips = 0
	_go(LOCK, LOCK_TIME)
	Sfx.play("ui_click", -6.0, 0.0, 0.8)
	G.buzz.emit(20)


func _on_call() -> void:
	if not can_call():
		return
	run.call_cd = player.stats.v("call_cooldown")
	G.stat.emit("curse_calls", 1)
	_lock(true)


func _start_lunge() -> void:
	lunge_end = _ray_to_wall(position, aim_dir)
	meals_in_lunge = 0
	_go(LUNGE, 0.0)
	G.stat.emit("curse_lunges", 1)
	Sfx.play("door_close", -4.0, 0.04, 1.7)


## Where the disc's middle ends up when it slides from `from` along `dir` until its rim meets a wall.
func _ray_to_wall(from: Vector2, dir: Vector2) -> Vector2:
	var far := INF
	if dir.x > 0.001:
		far = minf(far, (G.ROOM_W - radius - from.x) / dir.x)
	elif dir.x < -0.001:
		far = minf(far, (radius - from.x) / dir.x)
	if dir.y > 0.001:
		far = minf(far, (G.ROOM_H - radius - from.y) / dir.y)
	elif dir.y < -0.001:
		far = minf(far, (radius - from.y) / dir.y)
	if far == INF or far < 0.0:
		return from
	return from + dir * far


## The lunge reached the wall.
func _end_lunge() -> void:
	_lunge_tally()
	_go(WINDED, WINDED_TIME)
	run.shake(0.25)
	Sfx.play("rock_break", -9.0, 0.05, 0.6)
	run.fx.burst(position + aim_dir * radius, [Color(0.55, 0.50, 0.45), Color(0.30, 0.27, 0.25)], 8, 60.0, 0.4, 2.0, -aim_dir * 0.5)
	# hidden doors: the first hit cracks the wall, the second opens it
	for dir: Vector2i in room.rs["doors"]:
		var door: Dictionary = room.rs["doors"][dir]
		if not door["hidden"] or door["revealed"]:
			continue
		if (room.door_pos(dir) as Vector2).distance_to(position) > radius + CRACK_REACH:
			continue
		if door.get("cracked", false):
			room.reveal_door(dir)
		else:
			room.crack_door(dir)


## Called whenever a lunge is over, however it ended.
func _lunge_tally() -> void:
	if meals_in_lunge >= FEAST_MEALS:
		feast_t = FEAST_TIME
		G.stat.emit("curse_feast", 1)
		run.shake(0.4)
		Sfx.play("enemy_die_big", -4.0, 0.03, 0.7)
	meals_in_lunge = 0


# =============================================================================== touching things
static func seg_dist2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_squared_to(a)
	var k := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_squared_to(a + ab * k)


## Everything the disc swept over this frame (a..b is how far its middle moved, so nothing is
## skipped at lunge speed).
func _touch_things(a: Vector2, b: Vector2) -> void:
	if not lit():
		return
	# an unexploded bomb goes off at once (and that blast stuns the disc)
	for bomb in room.bombs.duplicate():
		if is_instance_valid(bomb) and seg_dist2(bomb.position, a, b) < radius * radius:
			bomb.detonate()
			if not lit():
				return
	for e in room.enemies.duplicate():
		if not is_instance_valid(e) or e.dead or not e.hittable:
			continue
		var reach: float = radius + e.radius
		if seg_dist2(e.position, a, b) > reach * reach:
			continue
		if _bite_enemy(e):
			return
	if player.can_be_hit():
		var reach2 := radius + HERO_BITE_PAD
		if seg_dist2(player.position, a, b) <= reach2 * reach2:
			_bite_hero()
	if lit() and player.stats.has_flag("curse_eats_coins"):
		_eat_floor_coins()


## Returns true when the bite stopped the disc (a boss knocks it back).
func _bite_enemy(e: Node) -> bool:
	if e.has_method("bitten"):
		if _boss_cd > 0.0:
			return false
		_boss_cd = BOSS_REST
		var lost: float = e.bitten(float(LEVELS[level]["boss_pct"]), BOSS_FLOOR, BOSS_FLINCH)
		boss_eaten += lost / maxf(float(e.max_hp), 1.0)
		G.stat.emit("curse_boss_bites", 1)
		G.stat.emit("curse_boss_permille", int(round(lost / maxf(float(e.max_hp), 1.0) * 1000.0)))
		if boss_eaten >= BOSS_FEAT - 0.0001 and not _boss_feat_done:
			_boss_feat_done = true
			G.stat.emit("boss_bitten_30", 1)
		var away: Vector2 = position - e.position
		if away.length() < 0.5:
			away = -aim_dir
		if state == LUNGE:
			_lunge_tally()
		position = _clamp(position + away.normalized() * BOSS_BOUNCE)
		_go(WINDED, BOSS_REST)
		gulp = 0.2
		run.shake(0.5)
		run.hitstop(MEAL_HITSTOP)
		run.fx.ring(e.position - Vector2(0, 8), 4.0, 26.0, 0.3, Color(0.98, 0.93, 0.66), 2.0)
		Sfx.play("enemy_die_big", -3.0, 0.04, 0.55)
		G.buzz.emit(30)
		return true
	if e.elite or e.data.get("big", false):
		var id := e.get_instance_id()
		if room.fight_time - float(_last_bite.get(id, -99.0)) < BIG_BITE_GAP:
			return false
		_last_bite[id] = room.fight_time
		var bite: float = e.max_hp * BIG_BITE
		if e.hp - bite > 0.01:
			var away2: Vector2 = e.position - position
			e.hurt(bite, Vector2.ZERO, 0.0)
			e.knock = (away2.normalized() if away2.length() > 0.5 else aim_dir) * SHOVE_SPEED
			gulp = 0.15
			run.hitstop(MEAL_HITSTOP * 0.5)
			G.stat.emit("curse_big_bites", 1)
			Sfx.play("enemy_die", -4.0, 0.04, 0.6)
			return false
	_swallow(e)
	return false


func _swallow(e: Node) -> void:
	var pay := 0
	if not e.minion:
		pay = BELLY_PAY_ELITE if e.elite else BELLY_PAY
	e.devour(self, SWALLOW_TIME)
	if state == LUNGE:
		meals_in_lunge += 1
	var paid: int = clampi(belly_cap(run) - run.belly, 0, pay)
	run.belly += paid
	G.stat.emit("curse_meals", 1)
	if run.floor_index == 0:
		G.stat.emit("curse_meals_f1", 1)
	if paid > 0:
		belly_pop = 0.3
		_floaters.append(["+%d" % paid, position - Vector2(0, radius * 0.5), 0.7])
	gulp = 0.18
	run.hitstop(MEAL_HITSTOP)
	Sfx.play("enemy_die", -3.0, 0.04, 0.5)
	Sfx.play("rock_break", -12.0, 0.05, 1.7)
	G.buzz.emit(20)
	for f in player.familiars:
		if is_instance_valid(f) and f.behaviour.has_method("on_meal"):
			f.behaviour.on_meal(f, self)
	G.hud_changed.emit()


func _bite_hero() -> void:
	var before: int = player.hp + player.armor
	var warded: bool = player.ward_ready
	player.hurt(int(LEVELS[level]["bite"]), position, CAUSE)
	var lost: int = before - (player.hp + player.armor)
	G.stat.emit("curse_bites", 1)
	if lost > 0:
		G.stat.emit("curse_bite_damage", lost)
	if warded:
		G.stat.emit("curse_bites_warded", 1)
	if state == LUNGE:
		_lunge_tally()
	_go(SATED, SATED_TIME)
	gulp = 0.2
	Sfx.play("enemy_die_big", -5.0, 0.04, 0.5)


## Only with the Gilded Fang: coins lying on the floor go into the belly (or are lost when it is full).
func _eat_floor_coins() -> void:
	for th in room.things.duplicate():
		if not is_instance_valid(th) or th.kind != "pickup" or String(th.info.get("kind", "")) != "coin":
			continue
		if (th.position as Vector2).distance_squared_to(position) > radius * radius:
			continue
		if run.belly < belly_cap(run):
			run.belly += 1
			belly_pop = 0.3
		room.remove_thing(th)
		gulp = 0.1
		G.stat.emit("curse_coins_eaten", 1)
		G.hud_changed.emit()


# =============================================================================== shots and bombs
## A hero or familiar shot passed through: it keeps flying, the disc slows down for a moment.
func flinch() -> void:
	if state == CREEP:
		flinching = FLINCH_TIME


## An enemy shot died on the disc (scripts/run/shots.gd calls this for everything in room.blockers).
func blocked_shot() -> void:
	gulp = maxf(gulp, 0.06)
	G.stat.emit("curse_shots_eaten", 1)


## A bomb went off at `at` (room.explode calls this).
func on_blast(at: Vector2) -> void:
	if not solid or at.distance_to(position) > BOMB_REACH + radius:
		return
	if state == LUNGE:
		_lunge_tally()
	_go(STUNNED, STUN_TIME)
	fill = 0.0
	G.stat.emit("curse_stunned", 1)
	_cough()


## Everything in the belly flies out as coin pickups.
func _cough() -> void:
	var coins := int(round(float(run.belly) * player.stats.v("belly_mult")))
	run.belly = 0
	G.hud_changed.emit()
	if coins <= 0:
		return
	var fives := 0
	if coins > COUGH_MAX_PICKUPS:
		fives = int(ceil(float(coins - COUGH_MAX_PICKUPS) / 4.0))
	var ones := coins - fives * 5
	var total := ones + fives
	var turn := randf() * TAU
	for k in total:
		var a := turn + TAU * float(k) / float(total) + randf_range(-0.2, 0.2)
		var dir := Vector2(cos(a), sin(a) * 0.8)
		var at := position + dir * 6.0
		at = Vector2(clampf(at.x, 4.0, G.ROOM_W - 4.0), clampf(at.y, 4.0, G.ROOM_H - 4.0))
		var coin: Node2D = room.add_thing("pickup", {"id": "coin5" if k < fives else "coin", "pos": at, "pop": true})
		if coin != null:
			coin.vel = dir * randf_range(COUGH_SPEED_MIN, COUGH_SPEED_MAX)
	G.stat.emit("belly_coins", coins)
	if coins >= 10:
		G.stat.emit("belly_burst_10", 1)
	run.fx.burst(position, [Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 0.7), Color(0.98, 0.93, 0.66)], 14 + coins, 110.0, 0.5, 2.0)
	Sfx.play("coin_pickup", 0.0, 0.1, 0.7)
	Sfx.play("chest_open", -4.0, 0.05, 1.3)


# =============================================================================== feedback drawn above everything
func _tick_feedback(delta: float) -> void:
	gulp = maxf(0.0, gulp - delta)
	belly_pop = maxf(0.0, belly_pop - delta)
	flinching = maxf(0.0, flinching - delta)
	var redraw := feast_t > 0.0 or not _floaters.is_empty()
	feast_t = maxf(0.0, feast_t - delta)
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i][2] -= delta
		_floaters[i][1] += Vector2(0, -14.0 * delta)
		if _floaters[i][2] <= 0.0:
			_floaters.remove_at(i)
	if redraw:
		queue_redraw()


## The "+1" belly ticks and the FEAST stamp (the disc itself is drawn by curse_look.gd).
func _draw() -> void:
	var font: Font = run.font()
	for f in _floaters:
		var text: String = f[0]
		var at: Vector2 = (f[1] as Vector2) - position
		var a := clampf(float(f[2]) / 0.25, 0.0, 1.0)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var p := Vector2(roundf(at.x - w * 0.5), roundf(at.y))
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.06, a))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.87, 0.35, a))
	if feast_t > 0.0:
		var k := 1.0 - feast_t / FEAST_TIME
		var size := 16
		var w2 := font.get_string_size(FEAST_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var drop := 6.0 * maxf(0.0, 1.0 - k * 8.0)       # it slams down in the first eighth of a second
		var p2 := Vector2(roundf(-w2 * 0.5), roundf(-radius - 6.0 - drop))
		var a2 := clampf((1.0 - k) * 4.0, 0.0, 1.0)
		draw_string_outline(font, p2, FEAST_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.05, 0.04, 0.06, a2))
		draw_string(font, p2, FEAST_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.98, 0.93, 0.66, a2))
