extends RefCounted
## SUPPLIES (v0.38.0, "make fights matter"): things carried in the pack and used in a battle (the
## Items order), bought from the people who sell them, sometimes left behind by a beaten pack.
## Each row:
##   "id", "name", "text"   what it is and what it does (words the owner may rewrite)
##   "price"                coins at a seller
##   "heal"                 share of the health of the one it is used on (or of everybody, "aim": "party")
##   "mana"                 share of the mana given back
##   "aim"                  "friend" (one of your side) or "party" (everybody standing)
##   "from"                 the story step it is sold from (tale.gd STEPS)
##   "raise"                (quality pass P01) stands a FALLEN friend up with this share of their health
##   "cure"                 true = takes every bad status (burning, weak, exposed, slowed) off the party
##   "cap"                  the most of it the pack holds (left out = CAP)
##   "no_drop"              true = never left behind by a beaten pack (only bought)
## The pack is kept in the save's hub section: "bag:<id>" = how many.

const LIST := [
	{"id": "herb", "name": "Healing Herb", "text": "Heals one friend: four tenths of their health.", "price": 12, "heal": 0.4, "aim": "friend", "from": 0},
	{"id": "tonic", "name": "Mana Tonic", "text": "Gives one friend back half their mana.", "price": 18, "mana": 0.5, "aim": "friend", "from": 0},
	{"id": "elixir", "name": "Hearth Elixir", "text": "Heals everybody standing: a third of their health.", "price": 45, "heal": 0.34, "aim": "party", "from": 7},
	{"id": "ember", "name": "Waking Ember", "text": "Stands a fallen friend up with three tenths of their health.", "price": 60, "raise": 0.3, "aim": "friend", "from": 5, "cap": 3, "no_drop": true},
	{"id": "salt", "name": "Cleansing Salt", "text": "Takes burning, weakness and every other ill off the whole party.", "price": 25, "cure": true, "aim": "party", "from": 7},
]
const START := {"herb": 3, "tonic": 1}   ## in the pack when the story begins (given once)
const CAP := 9                           ## the most of one kind the pack holds
const DROP_CHANCE := 0.22                ## a won battle leaves a supply this often
## who sells supplies (an id of a person); the barkeep also lets a room (the inn)
const SELLERS := ["barkeep", "mira", "nib", "pell"]
const INN := ["barkeep"]
const INN_PRICE := 6                     ## a room for the night: this ...
const INN_PRICE_LEVEL := 2               ## ... and this much more per level of the knight


static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return {}


static func _ready_bag() -> void:
	if Save.hub_get("bag:init") == 0:
		Save.hub_set("bag:init", 1)
		for id: String in START:
			Save.hub_set("bag:" + id, int(START[id]))


static func count(id: String) -> int:
	_ready_bag()
	return Save.hub_get("bag:" + id)


## The most of this the pack holds.
static func cap_of(id: String) -> int:
	return int(row(id).get("cap", CAP))


## Adds to the pack (never past CAP). Returns how many really went in.
static func give(id: String, n: int = 1) -> int:
	var had := count(id)
	var now := mini(maxi(had, cap_of(id)), had + n)
	Save.hub_set("bag:" + id, now)
	return now - had


static func take(id: String) -> bool:
	if count(id) <= 0:
		return false
	Save.hub_set("bag:" + id, count(id) - 1)
	return true


## Everything in the pack: [[row, how many]], only what there is some of.
static func bag() -> Array:
	var out: Array = []
	for r: Dictionary in LIST:
		var n := count(String(r["id"]))
		if n > 0:
			out.append([r, n])
	return out


## What a seller has at this step of the story.
static func on_sale(step: int) -> Array:
	return LIST.filter(func(r: Dictionary) -> bool: return step >= int(r["from"]))


## A random supply left behind by a won battle ("" = none).
static func drop(step: int) -> String:
	if randf() >= DROP_CHANCE:
		return ""
	var pool := on_sale(step).filter(func(r: Dictionary) -> bool: return not bool(r.get("no_drop", false)))
	if pool.is_empty() or randf() < 0.65:
		return "herb"
	return String(pool[randi() % pool.size()]["id"])


static func inn_price() -> int:
	return INN_PRICE + INN_PRICE_LEVEL * (Save.hub_get("rpg:lvl") if Save.hub_get("rpg:lvl") > 0 else 1)
