extends RefCounted
## Behaviour tests for the Hungry Curse (scripts/entities/curse.gd). They build a real run, put
## the disc, the hero and a few enemies exactly where a rule needs them, and step the game by hand
## (60 steps per second, no waiting), so they run in a blink and always give the same answer.
## dev/validate.gd calls run_all(); tools/check.sh runs that with:
##   godot --headless --path . res://dev/world_test.tscn -- --validate
## Each failed rule comes back as one line of plain text. To add a test: write a function that
## calls _expect(...) and add it to the list in run_all().

const Curse = preload("res://scripts/entities/curse.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const Shots = preload("res://scripts/run/shots.gd")

const DT := 1.0 / 60.0
const HERO_SAFE := Vector2(250, 100)     ## where the hero waits when a test does not need him
const ANCHOR := Vector2(264, 8)          ## a stunned enemy stands here so the fight never "ends"

## Every test is a function below called _t_<name>.
const TESTS: Array[String] = ["level_table", "where_it_appears", "lunge_meal", "minion_and_elite", "boss_bite", "hero_bite",
	"shots", "bomb", "call", "secret_wall", "cursed_items_and_starve", "belly_kept", "treasure_pair"]

static var _fails: Array[String] = []
static var _stats := {}
static var _test := ""


static func run_all(host: Node) -> Array[String]:
	_fails = []
	_stats = {}
	Save.disk = false                      # nothing here may reach the real save file
	var counter := func(key: String, n: int) -> void: _stats[key] = int(_stats.get(key, 0)) + n
	G.stat.connect(counter)
	var run: Node = load("res://scripts/run/run.gd").new()
	host.add_child(run)
	run.setup("knight", 4242)
	if run.tutor != null:
		run.tutor.free()                   # the first-run lesson would stage fights of its own
		run.tutor = null
	var me: GDScript = load("res://dev/curse_tests.gd")
	for test_name in TESTS:
		_test = test_name
		me.call("_t_" + test_name, run)
	G.stat.disconnect(counter)
	run.queue_free()
	return _fails


static func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append("curse test '%s': %s" % [_test, what])


# =============================================================================== helpers
## A clean fight in the start room: doors shut, the hero out of the way, one stunned enemy far
## off so the fight is not over, and the disc already awake and creeping at `at`.
static func _arena(run: Node, at: Vector2, level: int = 0) -> Node2D:
	run._enter_room(Vector2i.ZERO, Vector2i.ZERO)
	var room: Node = run.room
	run.curse_level = level
	run.belly = 0
	run.call_cd = 0.0
	run.shots.clear()
	room.grid.fill(0)                      # no rocks or crates: nothing but what the test puts there
	room.fighting = true
	room.fight_time = 0.0
	room._spawn_curse()
	var p: Node = run.player
	p.hp = p.max_hp
	p.armor = 0
	p.invuln = 0.0
	p.ward_ready = false
	p.knock = Vector2.ZERO
	p.position = HERO_SAFE
	_enemy(run, "shambler", ANCHOR)
	var c: Node2D = room.curse
	c._read_level()
	c.position = at
	c._go(Curse.CREEP, 0.0)
	c.fill = 0.0
	c.fill_time = 999.0                    # no lunge unless the test asks for one
	return c


## An enemy that has finished appearing and stands still.
static func _enemy(run: Node, id: String, at: Vector2, opts: Dictionary = {}) -> Node2D:
	opts["delay"] = 0.001
	if not opts.has("elite"):
		opts["elite"] = false
	var e: Node2D = run.room.spawn_enemy(id, at, opts)
	e._physics_process(DT)
	e.stun = 9999.0
	e.position = at
	return e


static func _tick(run: Node, seconds: float) -> void:
	var room: Node = run.room
	for i in int(round(seconds * 60.0)):
		room.fight_time += DT
		for e in room.enemies.duplicate():
			if is_instance_valid(e):
				e._physics_process(DT)
		for b in room.bombs.duplicate():
			if is_instance_valid(b):
				b._physics_process(DT)
		run.shots._physics_process(DT)
		if room.curse != null and is_instance_valid(room.curse):
			room.curse._physics_process(DT)
		run.call_cd = maxf(0.0, run.call_cd - DT)


static func _coins_on_floor(room: Node) -> int:
	var n := 0
	for t in room.things:
		if is_instance_valid(t) and t.kind == "pickup" and not t.is_queued_for_deletion():
			n += int((t.info.get("give", {}) as Dictionary).get("coins", 0))
	return n


static func _pickups(room: Node) -> int:
	var n := 0
	for t in room.things:
		if is_instance_valid(t) and t.kind == "pickup":
			n += 1
	return n


static func _first_room(run: Node, type: int) -> Vector2i:
	for c: Vector2i in run.rooms:
		if run.rooms[c]["type"] == type:
			return c
	return Vector2i(99, 99)


# =============================================================================== the tests
static func _t_level_table(_run: Node) -> void:
	_expect(Curse.LEVELS.size() == 6 and Curse.MAX_LEVEL == 5, "there must be six levels, 0 to 5")
	for lvl in 6:
		var row: Dictionary = Curse.row(lvl)
		_expect(is_equal_approx(float(row["radius"]), 12.0 + 2.0 * lvl), "level %d radius should be %d" % [lvl, 12 + 2 * lvl])
		_expect(int(row["belly"]) == 5 + 2 * lvl, "level %d belly should hold %d" % [lvl, 5 + 2 * lvl])
		_expect(int(row["bite"]) == (1 if lvl < 3 else 2), "level %d bite should be %d half hearts" % [lvl, 1 if lvl < 3 else 2])
		_expect(is_equal_approx(float(row["boss_pct"]), 5.0 + lvl), "level %d boss bite should be %d%%" % [lvl, 5 + lvl])


static func _t_where_it_appears(run: Node) -> void:
	run._enter_room(Vector2i.ZERO, Vector2i.ZERO)
	_expect(run.room.curse == null, "no Curse in the start room")
	for type: int in [G.RoomType.TREASURE, G.RoomType.SHOP, G.RoomType.SECRET]:
		var c := _first_room(run, type)
		if run.rooms.has(c):
			run._enter_room(c, Vector2i.ZERO)
			_expect(run.room.curse == null and not run.room.fighting, "no Curse in a %s room" % run.TYPE_NAMES[type])
	var fight := _first_room(run, G.RoomType.COMBAT)
	run._enter_room(fight, Vector2i.ZERO)
	_expect(run.room.fighting and run.room.curse != null, "a fight room that is not cleared has the Curse")
	if run.room.curse != null:
		var c2: Node2D = run.room.curse
		_expect(c2.state == Curse.WAIT and not c2.solid, "it waits before it rises")
		run.player.position = Vector2(20, 20)
		_tick(run, Curse.RISE_DELAY + 0.05)
		_expect(c2.state == Curse.RISING and not c2.lit(), "it rises %.1f s after the doors lock, harmless" % Curse.RISE_DELAY)
		var far := Curse.SPAWN_POINTS[0]
		for sp in Curse.SPAWN_POINTS:
			if sp.distance_to(Vector2(20, 20)) > far.distance_to(Vector2(20, 20)):
				far = sp
		_expect(c2.position.distance_to(far) < 1.0, "it rises at the spawn point farthest from the hero")
		_tick(run, Curse.RISE_TIME + 0.05)
		_expect(c2.state == Curse.CREEP and c2.lit() and c2.solid, "after rising it creeps and its rim is lit")
		# the last enemy dies: it sinks, harmless at once
		for e in run.room.enemies.duplicate():
			e.die(false)
		_tick(run, 0.05)
		_expect(c2.state == Curse.SINKING and not c2.lit() and not c2.solid, "it sinks when the last enemy dies")
	run.rooms[fight]["cleared"] = true
	run._enter_room(fight, Vector2i.ZERO)
	_expect(run.room.curse == null, "no Curse in a cleared fight room")
	var boss := _first_room(run, G.RoomType.BOSS)
	run._enter_room(boss, Vector2i.ZERO)
	_expect(run.room.curse != null, "the boss room has the Curse")


static func _t_lunge_meal(run: Node) -> void:
	var c := _arena(run, Vector2(40, 56))
	var room: Node = run.room
	for x: float in [100.0, 130.0, 160.0]:
		_enemy(run, "shambler", Vector2(x, 56))
	_enemy(run, "lantern_head", Vector2(190, 56))          # an exploder: swallowed, it must not blast
	run.player.position = Vector2(230, 56)
	var loot_before := _pickups(room)
	var feasts := int(_stats.get("curse_feast", 0))
	c.fill = 1.0
	c.fill_time = Curse.FILL
	_tick(run, 0.05)
	_expect(c.state == Curse.FOLLOW and c.stripe_on(), "a full timer starts the stripe")
	_tick(run, Curse.FOLLOW_TIME)
	_expect(c.state == Curse.LOCK, "the stripe locks after following for %.1f s" % Curse.FOLLOW_TIME)
	_expect(c.aim_dir.distance_to(Vector2.RIGHT) < 0.01, "the stripe runs from the disc through the hero")
	run.player.position = HERO_SAFE                         # the hero steps off the stripe
	_tick(run, Curse.LOCK_TIME + 0.02)
	_expect(c.state == Curse.LUNGE, "after the lock comes the lunge")
	_tick(run, 1.2)
	_expect(c.state == Curse.WINDED, "it rests after reaching the wall")
	_expect(c.position.distance_to(Vector2(G.ROOM_W - c.radius, 56)) < 1.0, "the lunge ends with its rim on the wall")
	_expect(room.enemies.size() == 1, "the lunge swallowed everything on the line (left: %d)" % (room.enemies.size() - 1))
	_expect(run.belly == 4, "four meals put 4 coins in the belly (belly = %d)" % run.belly)
	_expect(_pickups(room) == loot_before, "swallowed enemies drop nothing on the floor")
	_expect(run.shots.count == 0, "a swallowed exploder does not blast")
	_expect(int(_stats.get("curse_feast", 0)) == feasts + 1, "3 or more meals in one lunge is a FEAST")
	_expect(run.player.hp == run.player.max_hp, "the hero who stepped off the stripe is not hurt")
	_tick(run, Curse.WINDED_TIME + 0.05)
	_expect(c.state == Curse.CREEP, "after %.1f s it creeps again" % Curse.WINDED_TIME)
	# a full belly: meals pay nothing more
	run.belly = Curse.belly_cap(run)
	_enemy(run, "shambler", c.position)
	_tick(run, 0.05)
	_expect(run.belly == Curse.belly_cap(run), "a full belly does not grow")
	# enemies that are still appearing cannot be eaten
	var late: Node2D = room.spawn_enemy("shambler", c.position, {"delay": 5.0, "elite": false})
	_tick(run, 0.1)
	_expect(is_instance_valid(late) and not late.dead, "an enemy that is still appearing is not eaten")


static func _t_minion_and_elite(run: Node) -> void:
	var c := _arena(run, Vector2(100, 56))
	_enemy(run, "shambler", Vector2(100, 56), {"minion": true})
	_tick(run, 0.05)
	_expect(run.room.enemies.size() == 1 and run.belly == 0, "a summoned minion is swallowed but pays nothing")
	for case: Array in [["shambler", {"elite": true}, 3, "an elite"], ["rot_hulk", {}, 1, "a big enemy"]]:
		c = _arena(run, Vector2(100, 56))
		var big: Node2D = _enemy(run, case[0], Vector2(100, 56), case[1])
		var full: float = big.max_hp
		_tick(run, 0.05)
		_expect(not big.dead and is_equal_approx(big.hp, full * (1.0 - Curse.BIG_BITE)), "%s loses half its health to the first bite" % case[3])
		_expect(big.knock.length() > 50.0, "%s is shoved away by the bite" % case[3])
		for part: float in [0.5, 0.3]:
			big.knock = Vector2.ZERO
			big.position = Vector2(100, 56)
			c.position = Vector2(100, 56)
			_tick(run, part)
		_expect(not big.dead, "%s is bitten at most once per second" % case[3])
		big.knock = Vector2.ZERO
		big.position = Vector2(100, 56)
		c.position = Vector2(100, 56)
		_tick(run, 0.3)
		_expect(big.dead and run.belly == int(case[2]), "the second bite swallows %s and pays %d (belly = %d)" % [case[3], case[2], run.belly])


static func _t_boss_bite(run: Node) -> void:
	for lvl: int in [0, 5]:
		var c := _arena(run, Vector2(60, 56), lvl)
		var boss: Node2D = run.room.spawn_enemy(run.boss_id, Vector2(136, 56), {"boss": true, "delay": 0.001})
		boss._physics_process(DT)
		boss.stun = 9999.0
		boss.position = Vector2(136, 56)
		var full: float = boss.max_hp
		c.position = Vector2(118, 56)
		_tick(run, 0.03)
		var pct := 5.0 + lvl
		_expect(is_equal_approx(boss.hp, full * (1.0 - pct / 100.0)), "at level %d a bite takes %d%% of a boss (took %.1f%%)" % [lvl, int(pct), 100.0 * (full - boss.hp) / full])
		_expect(c.state == Curse.WINDED and c.t > Curse.BOSS_REST - 0.2, "after biting a boss it stands still for %.0f s" % Curse.BOSS_REST)
		_expect(absf(c.position.x - (118.0 - Curse.BOSS_BOUNCE)) < 1.0, "the boss knocks it back %d px" % int(Curse.BOSS_BOUNCE))
		# while it rests it cannot bite the boss again
		var before: float = boss.hp
		c.position = Vector2(118, 56)
		_tick(run, 1.0)
		_expect(is_equal_approx(boss.hp, before), "no second boss bite while it rests")
		# the floor: bites never take a boss below 10%
		boss.hp = full * 0.12
		c.position = Vector2(118, 56)
		c._boss_cd = 0.0
		c._go(Curse.CREEP, 0.0)
		_tick(run, 0.03)
		_expect(is_equal_approx(boss.hp, full * Curse.BOSS_FLOOR) and not boss.dead, "a bite stops at %d%% of the boss's health" % int(Curse.BOSS_FLOOR * 100.0))
		run.room.enemies.erase(boss)
		boss.free()
		run.boss = null


static func _t_hero_bite(run: Node) -> void:
	var p: Node = run.player
	for lvl: int in [0, 2, 3, 5]:
		var c := _arena(run, Vector2(100, 56), lvl)
		p.position = Vector2(100.0 + c.radius + Curse.HERO_BITE_PAD + 2.0, 56)
		_tick(run, 0.02)
		_expect(p.hp == p.max_hp and c.state == Curse.CREEP, "level %d: two pixels outside the bite range nothing happens" % lvl)
		p.position = Vector2(100.0 + c.radius, 56)
		c.position = Vector2(100, 56)
		_tick(run, 0.02)
		var want := 1 if lvl < Curse.TEETH_LEVEL else 2
		_expect(p.max_hp - p.hp == want, "level %d: the bite costs %d half hearts (cost %d)" % [lvl, want, p.max_hp - p.hp])
		_expect(c.state == Curse.SATED and not c.lit(), "after biting the hero it is sated and dark")
		_expect(p.last_cause == Curse.CAUSE, "the death screen would name the Curse")
		# sated: frozen and harmless for 3 seconds, however close the hero stands
		var hp: int = p.hp
		var at := c.position
		p.invuln = 0.0
		p.position = c.position
		_tick(run, Curse.SATED_TIME - 0.1)
		_expect(p.hp == hp and c.state == Curse.SATED and c.position == at, "sated lasts %.0f s: no second bite, no movement" % Curse.SATED_TIME)
		p.position = HERO_SAFE
		_tick(run, 0.2)
		_expect(c.state == Curse.CREEP, "then it creeps again")
	# the knight's ward blocks the bite
	var c2 := _arena(run, Vector2(100, 56))
	p.ward_ready = true
	p.position = Vector2(104, 56)
	_tick(run, 0.02)
	_expect(p.hp == p.max_hp and not p.ward_ready, "the Oath Ward blocks the bite")
	_expect(c2.state == Curse.SATED, "a blocked bite still leaves it sated")
	# mercy time: no bite, and it stays hungry
	c2 = _arena(run, Vector2(100, 56))
	p.invuln = 1.0
	p.position = Vector2(104, 56)
	_tick(run, 0.02)
	_expect(p.hp == p.max_hp and c2.state == Curse.CREEP, "no bite during the mercy time after a hit")
	# armor goes first, like any other hit
	c2 = _arena(run, Vector2(100, 56))
	p.armor = 2
	p.position = Vector2(104, 56)
	_tick(run, 0.02)
	_expect(p.armor == 1 and p.hp == p.max_hp, "a bite takes armor first")
	p.armor = 0
	# rising and sinking are harmless
	c2 = _arena(run, Vector2(100, 56))
	c2._go(Curse.RISING, 1.0)
	p.position = Vector2(100, 56)
	_tick(run, 0.5)
	_expect(p.hp == p.max_hp, "a rising Curse does not bite")


static func _t_shots(run: Node) -> void:
	var c := _arena(run, Vector2(100, 56))
	var shots: Node = run.shots
	shots.fire(Vector2(50, 56), Vector2(120, 0), Shots.SIDE_ENEMY, 1.0, 200.0, "enemy")
	_tick(run, 0.5)
	_expect(shots.count == 0, "an enemy shot dies on the Curse")
	_expect(run.player.hp == run.player.max_hp, "and never reaches the hero behind it")
	shots.clear()
	# the disc crept toward the hero during the half second above, so aim at where it is NOW
	# (the shot starts 30 px to its left and is inside the disc a quarter of a second later)
	shots.fire(c.position - Vector2(30, 0), Vector2(160, 0), Shots.SIDE_PLAYER, 3.0, 200.0, "blade")
	_tick(run, 0.25)
	_expect(shots.count == 1, "a hero shot passes through the Curse")
	_expect(c.flinching > 0.0, "and makes it flinch")
	shots.clear()                          # one touch only: the slow-down must last by itself
	var before := c.position
	run.player.position = Vector2(100, 100)
	_tick(run, 0.1)
	var speed := before.distance_to(c.position) / 0.1
	_expect(speed < Curse.FLINCH_SPEED + 1.0, "a flinching Curse creeps at %d px/s (measured %.1f)" % [int(Curse.FLINCH_SPEED), speed])
	shots.clear()
	_tick(run, Curse.FLINCH_TIME + 0.1)
	before = c.position
	_tick(run, 0.5)
	speed = before.distance_to(c.position) / 0.5
	_expect(absf(speed - Curse.CREEP_SPEED) < 1.5, "it creeps at %d px/s (measured %.1f)" % [int(Curse.CREEP_SPEED), speed])
	# the Iron Leash slows the creep
	run.player.stats.set_layer("test", {"mult": {"curse_creep": 0.5}})
	before = c.position
	_tick(run, 0.5)
	speed = before.distance_to(c.position) / 0.5
	run.player.stats.remove_layer("test")
	_expect(absf(speed - Curse.CREEP_SPEED * 0.5) < 1.0, "the curse_creep stat scales the creep (measured %.1f)" % speed)


static func _t_bomb(run: Node) -> void:
	var c := _arena(run, Vector2(100, 56))
	var room: Node = run.room
	run.belly = 4
	var coins := _coins_on_floor(room)
	room.explode(Vector2(100.0 + c.radius + Curse.BOMB_REACH + 2.0, 56))
	_expect(c.state == Curse.CREEP and run.belly == 4, "a blast out of reach does nothing to it")
	c.fill = 0.6
	room.explode(Vector2(100.0 + c.radius + Curse.BOMB_REACH - 2.0, 56))
	_expect(c.state == Curse.STUNNED and not c.lit(), "a blast next to it stuns it")
	_expect(is_equal_approx(c.t, Curse.STUN_TIME), "for %.0f seconds" % Curse.STUN_TIME)
	_expect(c.fill == 0.0, "and resets its lunge timer")
	_expect(run.belly == 0 and _coins_on_floor(room) - coins == 4, "it coughs the whole belly out as coins (%d on the floor)" % (_coins_on_floor(room) - coins))
	run.player.position = c.position
	_tick(run, Curse.STUN_TIME - 0.1)
	_expect(c.state == Curse.STUNNED and run.player.hp == run.player.max_hp, "a stunned Curse is harmless")
	run.player.position = HERO_SAFE
	_tick(run, 0.2)
	_expect(c.state == Curse.CREEP, "then it wakes up")
	# belly_mult (the Gilded Fang) multiplies the haul
	c = _arena(run, Vector2(100, 56), 3)
	room = run.room
	run.belly = 7
	run.player.stats.set_layer("test", {"mult": {"belly_mult": 2.0}})
	coins = _coins_on_floor(room)
	var bursts := int(_stats.get("belly_burst_10", 0))
	room.explode(Vector2(110, 56))
	run.player.stats.remove_layer("test")
	_expect(_coins_on_floor(room) - coins == 14, "belly x belly_mult coins come out (%d)" % (_coins_on_floor(room) - coins))
	_expect(int(_stats.get("belly_burst_10", 0)) == bursts + 1, "10 or more coins from one bomb is counted")
	# a bomb it touches goes off at once
	c = _arena(run, Vector2(100, 56))
	room = run.room
	room.add_bomb(Vector2(100.0 + c.radius + 4.0, 56))
	_tick(run, 0.05)
	_expect(room.bombs.size() == 1 and c.state == Curse.CREEP, "a bomb beside it just burns")
	run.player.position = Vector2(100.0 + c.radius + 60.0, 56)       # it creeps toward the hero, over the bomb
	_tick(run, 0.5)
	_expect(room.bombs.is_empty() and c.state == Curse.STUNNED, "a bomb it touches goes off at once and stuns it")
	# the bomb button still works after a room change (the hero leaves the tree and comes back)
	c = _arena(run, Vector2(30, 20))
	room = run.room
	run.player.bombs = 1
	Controls.press_bomb()
	_expect(room.bombs.size() == 1 and run.player.bombs == 0, "the bomb button places a bomb in every room, not only the first")
	room.bombs[0].queue_free()
	room.bombs.clear()


static func _t_call(run: Node) -> void:
	var c := _arena(run, Vector2(60, 56))
	var cooldown: float = run.player.stats.v("call_cooldown")
	_expect(is_equal_approx(cooldown, 4.0), "the CALL cooldown is 4 seconds")
	c._go(Curse.WINDED, 1.0)
	Controls.press_action()
	_expect(c.state == Curse.WINDED and run.call_cd == 0.0, "CALL does nothing while it is not creeping")
	c._go(Curse.CREEP, 0.0)
	run.player.position = Vector2(200, 56)
	Controls.press_action()
	_expect(c.state == Curse.LOCK and c.called, "CALL locks the stripe at once")
	_expect(is_equal_approx(run.call_cd, cooldown), "and starts the cooldown")
	run.player.position = HERO_SAFE
	_tick(run, Curse.LOCK_TIME + 0.02)
	_expect(c.state == Curse.LUNGE and c.aim_dir.distance_to(Vector2.RIGHT) < 0.01, "it lunges at where the hero stood when CALL was pressed")
	_tick(run, 1.0 + Curse.WINDED_TIME)
	_expect(c.state == Curse.CREEP and run.call_cd > 0.0, "it creeps again while the cooldown still runs")
	Controls.press_action()
	_expect(c.state == Curse.CREEP, "CALL does nothing during its cooldown")
	run.player.position = Vector2(20, 20)
	_tick(run, cooldown)
	_expect(run.call_cd == 0.0 and c.can_call(), "after the cooldown CALL works again")
	# the Spiked Goad shortens it
	run.player.stats.set_layer("test", {"flat": {"call_cooldown": -1.5}})
	Controls.press_action()
	_expect(is_equal_approx(run.call_cd, 2.5), "call_cooldown is a stat items can change")
	run.player.stats.remove_layer("test")


static func _t_secret_wall(run: Node) -> void:
	# a room next to the secret room, and the side its hidden door is on
	var spot := Vector2i(99, 99)
	var side := Vector2i.ZERO
	for c: Vector2i in run.rooms:
		if run.rooms[c]["type"] == G.RoomType.SECRET or run.rooms[c]["type"] == G.RoomType.BOSS:
			continue
		for d: Vector2i in run.rooms[c]["doors"]:
			if run.rooms[c]["doors"][d]["hidden"]:
				spot = c
				side = d
	if side == Vector2i.ZERO:
		_expect(false, "this floor has no hidden door to test with")
		return
	run.rooms[spot]["cleared"] = true
	run._enter_room(spot, Vector2i.ZERO)
	var room: Node = run.room
	var door: Dictionary = room.rs["doors"][side]
	room.fighting = true
	room._spawn_curse()
	_enemy(run, "shambler", ANCHOR)
	var c2: Node2D = room.curse
	# the game counts one secret per floor, and an earlier test (a bomb) may already have blown a
	# hidden door open on this floor: start the count afresh
	run._secret_counted = false
	var secrets := int(_stats.get("secret_found", 0))
	for hit in 2:
		run.player.position = HERO_SAFE
		c2.position = (room.door_pos(side) as Vector2) - Vector2(side) * 50.0
		c2._go(Curse.CREEP, 0.0)
		c2.aim_dir = Vector2(side)
		c2._go(Curse.LOCK, 0.01)
		_tick(run, 1.0)
		if hit == 0:
			_expect(door.get("cracked", false) and not door["revealed"], "the first lunge into a hidden door cracks the wall")
			_expect(run.rooms[door["to"]]["doors"][-side].get("cracked", false), "the crack is remembered on the other side too")
		else:
			_expect(door["revealed"], "the second lunge opens it")
			_expect(int(_stats.get("secret_found", 0)) == secrets + 1, "and that counts as finding the secret")
		_tick(run, Curse.WINDED_TIME)
	run._enter_room(Vector2i.ZERO, Vector2i.ZERO)


static func _t_cursed_items_and_starve(run: Node) -> void:
	run._enter_room(Vector2i.ZERO, Vector2i.ZERO)
	var p: Node = run.player
	run.curse_level = 0
	p.add_item("glass_blade")
	_expect(run.curse_level == 1, "a cursed item adds 1 Curse Level")
	p.add_item("whetstone")
	_expect(run.curse_level == 1, "a normal item adds none")
	run.curse_level = Curse.MAX_LEVEL
	p.add_item("frenzy_saw")
	_expect(run.curse_level == Curse.MAX_LEVEL, "the Curse Level stops at %d" % Curse.MAX_LEVEL)
	# the stand
	run.starve_bought = 0
	run.curse_level = 0
	var stand: Node2D = run.room.add_thing("pedestal", {"service": "starve", "pos": Vector2(60, 60)})
	_expect(not stand.visible, "the Starve stand is hidden at Curse Level 0")
	run.curse_level = 3
	stand._refresh_service()
	_expect(stand.visible and stand.price == 15, "it shows from Level 1 and the first price is 15")
	p.coins = 10
	stand._touched(p)
	_expect(run.curse_level == 3 and p.coins == 10, "it does not sell without the coins")
	p.coins = 100
	var paid: Array[int] = []
	for k in 3:
		var before: int = p.coins
		stand._away = true
		stand._touched(p)
		paid.append(before - p.coins)
	_expect(paid == [15, 25, 35], "Starve costs 15, then 25, then 35 (paid %s)" % [paid])
	_expect(run.curse_level == 0, "each purchase takes one level off")
	run.curse_level = 2
	stand._refresh_service()
	_expect(not stand.visible, "after three purchases it is sold out for the run")
	run.starve_bought = 0
	run.curse_level = 0


static func _t_belly_kept(run: Node) -> void:
	run._enter_room(Vector2i.ZERO, Vector2i.ZERO)
	run.curse_level = 1
	run.belly = 6
	run._enter_room(_first_room(run, G.RoomType.SHOP), Vector2i.ZERO)
	_expect(run.belly == 6 and run.curse_level == 1, "the belly and the level survive a room change")
	run.floor_index += 1
	run._start_floor()
	_expect(run.belly == 6 and run.curse_level == 1, "... and a floor change")
	run.belly = 0
	run.curse_level = 0


static func _t_treasure_pair(run: Node) -> void:
	var c := _first_room(run, G.RoomType.TREASURE)
	run._enter_room(c, Vector2i.ZERO)
	var room: Node = run.room
	var normal: Node2D = null
	var cursed: Node2D = null
	for t in room.things:
		if t.kind == "pedestal" and t.pair != 0:
			if t.cursed:
				cursed = t
			else:
				normal = t
	_expect(normal != null and cursed != null, "the treasure room offers a normal item and a cursed item")
	if normal == null or cursed == null:
		return
	_expect(normal.badge == null and cursed.badge != null, "only the cursed one wears the +1 skull badge")
	var level: int = run.curse_level
	cursed._touched(run.player)
	_expect(run.curse_level == level + 1, "taking the cursed one raises the Curse Level")
	_expect(not room.things.has(normal), "and the other pedestal crumbles")
	_expect(room.things.has(cursed) and cursed.taken, "the one that was taken stays, empty")
