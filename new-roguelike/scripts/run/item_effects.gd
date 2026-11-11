extends RefCounted
## Item effects: the "smart" part of items (anything that is more than a stat change).
## A plain stat item needs NOTHING here: its "mods" in scripts/data/items.gd are enough.
##
## HOW TO ADD AN EFFECT: write a function below called  <item id>_<hook>.
## It is found by name when the item is picked up; no list to update, no other file to touch.
## Every hook gets (run, player, ...) and these extra arguments:
##     on_added(run, player)                        once, when the item is picked up
##     on_shot_fired(run, player, from, dir)        every time the player fires
##     on_hit(run, player, enemy, damage, pos)      a player shot hit an enemy
##     on_kill(run, player, enemy)                  an enemy died
##     on_hurt(run, player, half_hearts, cause)     the player lost health
##     on_pickup(run, player, pickup_id)            a pickup was collected
##     on_coins(run, player, amount)                coins gained (or spent: negative)
##     on_room_enter(run, player, room)             walked into a room
##     on_room_clear(run, player, room)             a fight was won
##     on_floor_start(run, player)                  arrived on a new floor
##     on_item(run, player, item_id)                ANY item was just taken (after its own on_added)
##     on_tick(run, player, delta)                  every physics frame while the hero lives (keep it tiny)
##     on_shot_end(run, player, pos, dir, damage, hit_anything)
##                                                  one of the hero's own shots ran out of range, died on a
##                                                  wall (dir = the way it would bounce) or was used up on a
##                                                  monster (run.shots.end_victim = its instance id, else 0).
##                                                  A shot that flies back (Tethered Sickle) ends where it turns.
## The Hungry Curse (these are fed by its G.stat counters, see _on_stat below; curse.gd is untouched):
##     on_call(run, player, curse)                  a CALL was accepted
##     on_meal(run, player, curse)                  it swallowed a monster (or bit an elite, a big one, a boss)
##     on_curse_block(run, player, curse)           an enemy shot died on it
## A bite on the hero is  on_hurt  with cause == Curse.CAUSE; half_hearts is 0 when nothing was lost
## (Ransom Plate paid for the hit). It still counts as a bite for every item that speaks of bites.
## Shots made by an effect should carry {"bits": Shots.B_CHILD} so they never start on_hit / on_shot_end again.
## Words an effect shows on screen live in the item's row ("text") in scripts/data/items.gd.
## `counters` is free memory that lasts for the run (for "every third room" style effects).

const Shots = preload("res://scripts/run/shots.gd")
const Items = preload("res://scripts/data/items.gd")
const Curse = preload("res://scripts/entities/curse.gd")
const Status = preload("res://scripts/entities/status.gd")

const HOOKS: Array[String] = ["on_added", "on_shot_fired", "on_hit", "on_kill", "on_hurt", "on_pickup",
	"on_coins", "on_room_enter", "on_room_clear", "on_floor_start", "on_item", "on_tick", "on_shot_end",
	"on_call", "on_meal", "on_curse_block"]
## Which counter of the Hungry Curse (G.stat) starts which hook.
const CURSE_STATS := {"curse_calls": "on_call", "curse_meals": "on_meal", "curse_big_bites": "on_meal",
	"curse_boss_bites": "on_meal", "curse_shots_eaten": "on_curse_block"}
const CHILD := {"knock": 0.3, "bits": Shots.B_CHILD}

var run: Node
var counters := {}
var _table := {}


func _init(the_run: Node) -> void:
	run = the_run
	for h in HOOKS:
		_table[h] = []
	G.stat.connect(_on_stat)


func _on_stat(key: String, _amount: int) -> void:
	if not CURSE_STATS.has(key) or not is_instance_valid(run) or run.room == null:
		return
	var curse: Node2D = run.room.curse
	if curse != null and is_instance_valid(curse):
		fire(CURSE_STATS[key], [curse])


## Called by the player when an item is picked up: wires up that item's hook functions.
func item_added(item_id: String) -> void:
	for h in HOOKS:
		var method := "%s_%s" % [item_id, h]
		if has_method(method):
			(_table[h] as Array).append(Callable(self, method))
	if has_method(item_id + "_on_added"):
		call(item_id + "_on_added", run, run.player)


## Runs every function hooked to `hook`. Cheap when no item uses it.
func fire(hook: String, args: Array) -> void:
	var list: Array = _table[hook]
	if list.is_empty():
		return
	var full: Array = [run, run.player]
	full.append_array(args)
	for c: Callable in list:
		c.callv(full)


# =============================================================================== Wardwater
func wardwater_on_room_clear(_run: Node, player: Node, _room: Node) -> void:
	counters["wardwater"] = int(counters.get("wardwater", 0)) + 1
	if int(counters["wardwater"]) % 3 == 0:
		player.give({"armor": 1})
		run.fx.ring(player.position - Vector2(0, 8), 4.0, 20.0, 0.4, Color(0.5, 0.8, 1.0), 2.0)
		Sfx.play("heart_pickup", -6.0)


# =============================================================================== Grave Cleaver
func grave_cleaver_on_kill(_run: Node, player: Node, enemy: Node) -> void:
	var damage: float = maxf(1.0, player.stats.v("damage") * 0.4)
	var offset := randf() * TAU
	for k in 6:
		var a := offset + TAU * float(k) / 6.0
		run.shots.fire(enemy.position, Vector2(cos(a), sin(a)) * 120.0, Shots.SIDE_PLAYER, damage, 46.0, "shard", {"knock": 0.3})


# =============================================================================== Gilded Blade (cursed)
func gilded_blade_on_added(_run: Node, player: Node) -> void:
	_gilded_refresh(player)


func gilded_blade_on_coins(_run: Node, player: Node, _amount: int) -> void:
	_gilded_refresh(player)


func gilded_blade_on_hurt(_run: Node, player: Node, _half_hearts: int, _cause: String) -> void:
	var lost: int = mini(5, player.coins)
	if lost <= 0:
		return
	player.coins -= lost
	run.fx.burst(player.position - Vector2(0, 8), [Color(1, 0.85, 0.3), Color(1, 1, 0.7)], lost * 3, 90.0, 0.6, 2.0)
	_gilded_refresh(player)
	G.hud_changed.emit()


## +2% damage per coin carried, up to +100%.
func _gilded_refresh(player: Node) -> void:
	player.stats.set_layer("gilded_blade_bonus", {"pct": {"damage": minf(1.0, float(player.coins) * 0.02)}})


func _bitten(_half_hearts: int, cause: String) -> bool:
	return cause == Curse.CAUSE


func _mid(player: Node) -> Vector2:
	return player.position - Vector2(0, 8)


# =============================================================================== Bone Thistle
## Three splinters (half damage each) where a shot ends: at the end of its reach, on a wall, or on the
## monster it was used up on (they fly on past that monster and never hurt it). They lean toward
## the nearest monster ahead of them, or they would hit one in a dozen.
func bone_thistle_on_shot_end(_run: Node, _player: Node, pos: Vector2, dir: Vector2, damage: float, _hit: bool) -> void:
	var extra := {"knock": 0.3, "bits": Shots.B_CHILD, "skip": run.shots.end_victim, "homing": 2.0}
	for turn: float in [-0.45, 0.0, 0.45]:
		run.shots.fire(pos, dir.rotated(turn) * 150.0, Shots.SIDE_PLAYER, maxf(0.5, damage * 0.5), 60.0, "shard", extra)


# =============================================================================== Winter Nail / Pyre Kindling
func winter_nail_on_hit(_run: Node, _player: Node, enemy: Node, _damage: float, _pos: Vector2) -> void:
	Status.chill(enemy)


func pyre_kindling_on_hit(_run: Node, player: Node, enemy: Node, _damage: float, _pos: Vector2) -> void:
	Status.burn(enemy, player.stats.v("damage") * 0.25)


# =============================================================================== Moth Mantle (cursed)
## Checked 5 times a second: +60% fire rate within 44 px of the Curse's rim, -20% farther away,
## nothing at all while no Curse is up. (It turns off again at 52 px so it never flickers.)
func moth_mantle_on_tick(_run: Node, player: Node, delta: float) -> void:
	counters["moth_t"] = float(counters.get("moth_t", 0.0)) - delta
	if float(counters["moth_t"]) > 0.0:
		return
	counters["moth_t"] = 0.2
	var was := int(counters.get("moth", 0))
	var now := 0
	var curse: Node2D = run.room.curse if run.room != null else null
	if curse != null and is_instance_valid(curse) and curse.solid:
		var gap: float = player.position.distance_to(curse.position) - curse.radius
		now = 1 if gap < (52.0 if was == 1 else 44.0) else 2
	if now == 1:
		run.fx.burst(_mid(player), [Color(1.0, 0.97, 0.8), Color(0.8, 0.75, 0.6)], 1, 25.0, 0.5, 2.0, Vector2(0, -0.8))
	if now == was:
		return
	counters["moth"] = now
	player.weapon.self_modulate = Color(1.5, 1.45, 1.2) if now == 1 else Color(1, 1, 1)
	if now == 0:
		player.stats.remove_layer("moth_mantle_stance")
	else:
		player.stats.set_layer("moth_mantle_stance", {"pct": {"rate": 0.60 if now == 1 else -0.20}})


# =============================================================================== Ossuary Chain (cursed)
func ossuary_chain_on_added(_run: Node, player: Node) -> void:
	Curse.change_level(run, 1)           # two Levels, not one (the first came with "cursed": true)
	_ossuary_refresh(player)


func ossuary_chain_on_item(_run: Node, player: Node, _item_id: String) -> void:
	_ossuary_refresh(player)


func ossuary_chain_on_room_enter(_run: Node, player: Node, _room: Node) -> void:
	_ossuary_refresh(player)


## +12% damage and +10% shot size per Curse Level, whatever raised or lowered it.
func _ossuary_refresh(player: Node) -> void:
	var level := float(run.curse_level)
	player.stats.set_layer("ossuary_chain_bonus", {"pct": {"damage": 0.12 * level, "shot_size": 0.10 * level}})


# =============================================================================== Howling Scar (cursed)
func howling_scar_on_hurt(_run: Node, player: Node, half_hearts: int, cause: String) -> void:
	if not _bitten(half_hearts, cause):
		return
	var damage: float = player.stats.v("damage") * 8.0      # (5 was tried: the bot did no better with the item than without)
	for e in run.room.enemies.duplicate():
		if is_instance_valid(e) and e.hittable:
			e.hurt(damage, ((e.position as Vector2) - player.position).normalized(), 2.0)
	run.fx.ring(_mid(player), 8.0, 300.0, 0.45, Color(0.85, 0.75, 1.0), 3.0)
	run.fx.flash(Color(0.8, 0.7, 1.0, 0.25), 0.2)
	run.shake(0.6)
	Sfx.play("boss_roar", -6.0, 0.03, 0.6)


# =============================================================================== Cry of Knives
func cry_of_knives_on_call(_run: Node, player: Node, _curse: Node) -> void:
	player.fire_ring(8, 0.7)
	run.fx.ring(_mid(player), 4.0, 22.0, 0.25, Color(0.9, 0.95, 1.0), 2.0)
	Sfx.play(String(player.hero.get("shoot_sfx", "player_shoot_blade")), -6.0, 0.05, 0.8)


# =============================================================================== Bitter Marrow
func bitter_marrow_on_hurt(_run: Node, _player: Node, half_hearts: int, cause: String) -> void:
	var curse: Node2D = run.room.curse
	if _bitten(half_hearts, cause) and run.belly > 0 and curse != null and is_instance_valid(curse):
		curse._cough()                   # the same cough a bomb gets out of it, without the stun


# =============================================================================== Sour Gullet
## Every second enemy shot the Curse swallows is spat at the nearest monster (5 a second at most).
func sour_gullet_on_curse_block(_run: Node, player: Node, curse: Node) -> void:
	counters["sour_n"] = int(counters.get("sour_n", 0)) + 1
	var now: float = run.room.fight_time
	if int(counters["sour_n"]) % 2 != 0 or absf(now - float(counters.get("sour_t", -9.0))) < 0.2:
		return
	var best: Node = null
	var best_d := INF
	for e in run.room.enemies:
		var d: float = (e.position as Vector2).distance_squared_to(curse.position)
		if e.hittable and d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	counters["sour_t"] = now
	var dir: Vector2 = ((best.position as Vector2) - (curse.position as Vector2)).normalized()
	run.shots.fire(curse.position + dir * float(curse.radius), dir * 180.0, Shots.SIDE_PLAYER, player.stats.v("damage"), 140.0, "spit", CHILD)


# =============================================================================== Fasting Vow
func fasting_vow_on_hurt(_run: Node, _player: Node, half_hearts: int, cause: String) -> void:
	if _bitten(half_hearts, cause) and not counters.get("vow_broken", false):
		counters["vow_broken"] = true
		G.toast.emit(String(Items.info("fasting_vow")["text"]["broken"]), "")


func fasting_vow_on_floor_start(_run: Node, player: Node) -> void:
	if not counters.get("vow_broken", false):
		if run.curse_level > 0:
			Curse.change_level(run, -1)
		else:
			player.give({"armor": 1})
		G.toast.emit(String(Items.info("fasting_vow")["text"]["kept"]), "")
		run.fx.ring(_mid(player), 4.0, 26.0, 0.45, Color(0.98, 0.95, 0.8), 2.0)
		Sfx.play("heart_pickup", -4.0, 0.0, 0.8)
	counters["vow_broken"] = false


# =============================================================================== Sexton's Satchel
func sextons_satchel_on_floor_start(_run: Node, player: Node) -> void:
	var bundle := {}
	if player.bombs < 2:
		bundle["bombs"] = 2 - player.bombs
	if player.keys < 1:
		bundle["keys"] = 1
	if bundle.is_empty():
		return
	player.give(bundle)
	run.fx.sparkle(_mid(player))
	Sfx.play("key_pickup", -4.0)


# =============================================================================== Sinner's Locket
func sinners_locket_on_item(_run: Node, player: Node, item_id: String) -> void:
	if not Items.info(item_id).get("cursed", false) or player.hp >= player.max_hp:
		return
	player.hp = player.max_hp
	run.fx.ring(_mid(player), 4.0, 26.0, 0.45, Color(1.0, 0.3, 0.3), 2.5)
	Sfx.play("heart_pickup")
	G.hud_changed.emit()


# =============================================================================== Undertaker's Due
## The last monster of a room, when the hero's side kills it (a swallowed one never gets here).
func undertakers_due_on_kill(_run: Node, player: Node, enemy: Node) -> void:
	if enemy.minion:
		return
	for e in run.room.enemies:
		if e != enemy and not e.dead:
			return
	var roll: float = randf() * 100.0 - player.stats.v("luck") * 2.0
	var drop := "coin5" if roll < 12.0 else "bomb" if roll < 25.0 else "key" if roll < 37.0 else "half_heart" if roll < 57.0 else "coin"
	run.room.drop(drop, enemy.position)
	if drop == "coin":
		run.room.drop("coin", enemy.position + Vector2(5, 2))
	run.fx.sparkle(enemy.position - Vector2(0, 6))


# =============================================================================== Carrion Bat
func carrion_bat_on_hit(_run: Node, player: Node, enemy: Node, damage: float, pos: Vector2) -> void:
	for f in player.familiars:
		if is_instance_valid(f) and f.id == "carrion_bat" and f.mem.get("perch") == enemy:
			enemy.hurt(damage * float(f.p.get("bonus", 0.5)), Vector2.ZERO, 0.0)
			run.fx.burst(pos - Vector2(0, 7), [Color(0.75, 1.0, 0.5), Color(1, 1, 1)], 4, 55.0, 0.25, 2.0)
			return
