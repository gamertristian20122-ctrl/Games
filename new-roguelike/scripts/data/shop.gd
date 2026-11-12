extends RefCounted
## The barkeep's shelf in the tavern: a few items from the hill and supplies for your pack, paid
## with coins from the camp chest. The shelf is restocked every time you go down into the hill.
## An item you buy joins what you carry (scripts/data/story.gd kit). Prices are first guesses.

const Items = preload("res://scripts/data/items.gd")
const Story = preload("res://scripts/data/story.gd")
const Quests = preload("res://scripts/data/quests.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")

const PRICES := [18, 24, 30]     ## one price per place on the shelf
const SUPPLIES := [
	{"id": "bomb", "name": "A bomb for your pack", "price": 6, "boon": "bombs"},
	{"id": "key", "name": "A key for your pack", "price": 9, "boon": "keys"},
]


## What is on the shelf now: [[item id, price], ...] (fewer when you have bought some).
static func stock() -> Array:
	var round_no := Save.hub_get("shop:n")
	var kit := Story.kit()
	var pool: Array = []
	for id: String in Items.ids():
		var info: Dictionary = Items.ALL[id]
		if bool(info.get("cursed", false)) or info.has("familiar") or kit.has(id):
			continue
		if bool(info.get("locked", false)) and not Save.is_unlocked("item:" + id):
			continue
		if (info.get("pools", []) as Array).has("shop") or (info.get("pools", []) as Array).has("treasure"):
			pool.append(id)
	pool.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["shelf", round_no])
	var out: Array = []
	for i in PRICES.size():
		if pool.is_empty():
			break
		var id: String = pool[rng.randi() % pool.size()]
		pool.erase(id)
		if Save.hub_get("shop:sold:%d:%d" % [round_no, i]) == 0:
			out.append([id, int(PRICES[i]), i])
	return out


static func buy_item(slot: int) -> bool:
	for entry: Array in stock():
		if int(entry[2]) != slot:
			continue
		if Upgrades.coins() < int(entry[1]):
			return false
		Save.hub_set("bank:coins", Upgrades.coins() - int(entry[1]))
		Save.hub_set("shop:sold:%d:%d" % [Save.hub_get("shop:n"), slot], 1)
		Story.add_to_kit(String(entry[0]))
		Save.flush()
		return true
	return false


static func buy_supply(id: String) -> bool:
	for row: Dictionary in SUPPLIES:
		if String(row["id"]) != id or Upgrades.coins() < int(row["price"]):
			continue
		var kind := String(row["boon"])
		if Save.hub_get("boon:" + kind) >= int(Quests.BOON_CAP.get(kind, 99)):
			return false
		Save.hub_set("bank:coins", Upgrades.coins() - int(row["price"]))
		Save.hub_set("boon:" + kind, Save.hub_get("boon:" + kind) + 1)
		Save.flush()
		return true
	return false


## A new shelf (main.gd calls this when a descent starts).
static func restock() -> void:
	Save.hub_set("shop:n", Save.hub_get("shop:n") + 1)
