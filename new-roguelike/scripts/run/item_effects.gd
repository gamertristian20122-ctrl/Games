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
## `counters` is free memory that lasts for the run (for "every third room" style effects).

const Shots = preload("res://scripts/run/shots.gd")

const HOOKS: Array[String] = ["on_added", "on_shot_fired", "on_hit", "on_kill", "on_hurt", "on_pickup",
	"on_coins", "on_room_enter", "on_room_clear", "on_floor_start"]

var run: Node
var counters := {}
var _table := {}


func _init(the_run: Node) -> void:
	run = the_run
	for h in HOOKS:
		_table[h] = []


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
