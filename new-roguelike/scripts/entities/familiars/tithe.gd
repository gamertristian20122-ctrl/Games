extends RefCounted
## Familiar behaviour "tithe": the Tithe Bat (row key "tithe_imp"). After each meal of the Hungry Curse it flies to the
## disc, takes ONE coin out of the belly and carries it to the hero, so some belly coins arrive
## without spending a bomb. It fetches at most `per_room` coins in one room.
## params:  per_room  coins it may fetch per room          speed  px/s while it is fetching
## The Curse tells it about meals by calling on_meal() (see _swallow in scripts/entities/curse.gd).

const FOLLOW := 0
const TO_BELLY := 1
const TO_HERO := 2


func start(f) -> void:
	f.mem = {"state": FOLLOW, "owed": 0, "done": 0, "room": 0, "spot": Vector2.ZERO, "pos": Vector2.ZERO, "coin": null}


## The Curse just swallowed something at `curse.position`.
func on_meal(f, curse) -> void:
	_fresh_room(f)
	f.mem["spot"] = curse.position
	if int(f.mem["done"]) + int(f.mem["owed"]) < int(f.p.get("per_room", 3)):
		f.mem["owed"] = int(f.mem["owed"]) + 1


func tick(f, delta: float) -> void:
	_fresh_room(f)
	var speed := float(f.p.get("speed", 150.0))
	match int(f.mem["state"]):
		FOLLOW:
			if int(f.mem["owed"]) > 0:
				if f.run.belly > 0:
					f.mem["state"] = TO_BELLY
					f.mem["pos"] = f.position
				else:
					f.mem["owed"] = 0            # the belly is empty: nothing to fetch
		TO_BELLY:
			var curse: Node2D = f.run.room.curse
			if curse != null and is_instance_valid(curse) and curse.state != curse.SINKING:
				f.mem["spot"] = curse.position   # the disc keeps moving: follow it
			var pos: Vector2 = (f.mem["pos"] as Vector2).move_toward(f.mem["spot"], speed * delta)
			f.mem["pos"] = pos
			f.position = pos
			if pos.distance_to(f.mem["spot"]) < 2.0:
				if f.run.belly > 0:
					f.run.belly -= 1
					G.hud_changed.emit()
					var coin: AnimatedSprite2D = Art.sprite("coin", "default")
					coin.position = Vector2(0, -15)
					f.add_child(coin)
					f.mem["coin"] = coin
					f.mem["state"] = TO_HERO
					Sfx.play("familiar_chirp", -10.0, 0.05, 1.3)
				else:
					f.mem["owed"] = 0
					f.mem["state"] = FOLLOW
		TO_HERO:
			var pos2: Vector2 = (f.mem["pos"] as Vector2).move_toward(f.player.position, speed * delta)
			f.mem["pos"] = pos2
			f.position = pos2
			if pos2.distance_to(f.player.position) < 8.0:
				_hand_over(f)
				f.mem["state"] = FOLLOW


func _hand_over(f) -> void:
	var coin: Variant = f.mem.get("coin")
	if coin == null:
		return
	if is_instance_valid(coin):
		(coin as Node).queue_free()
	f.mem["coin"] = null
	f.mem["owed"] = maxi(0, int(f.mem["owed"]) - 1)
	f.mem["done"] = int(f.mem["done"]) + 1
	var got: int = f.player.give({"coins": 1})
	G.pickup_collected.emit("coin", got)
	G.stat.emit("belly_coins", 1)
	G.stat.emit("imp_coins", 1)
	Sfx.play("coin_pickup", -6.0)
	f.run.fx.burst(f.player.position - Vector2(0, 8), [Color(1, 1, 0.8), Color(1, 0.9, 0.4)], 4, 35.0, 0.3, 1.6)


## A new room: the count starts again (a coin still in its hands is handed over at once).
func _fresh_room(f) -> void:
	if not f.mem.has("state"):
		start(f)
	var room_id: int = f.run.room.get_instance_id()
	if int(f.mem["room"]) == room_id:
		return
	_hand_over(f)
	f.mem["room"] = room_id
	f.mem["owed"] = 0
	f.mem["done"] = 0
	f.mem["state"] = FOLLOW
