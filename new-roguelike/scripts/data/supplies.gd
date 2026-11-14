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
## The pack is kept in the save's hub section: "bag:<id>" = how many.

const LIST := [
	{"id": "herb", "name": "Healing Herb", "text": "Heals one friend: four tenths of their health.", "price": 12, "heal": 0.4, "aim": "friend", "from": 0},
	{"id": "tonic", "name": "Mana Tonic", "text": "Gives one friend back half their mana.", "price": 18, "mana": 0.5, "aim": "friend", "from": 0},
	{"id": "elixir", "name": "Hearth Elixir", "text": "Heals everybody standing: a third of their health.", "price": 45, "heal": 0.34, "aim": "party", "from": 7},
]
const START := {"herb": 3, "tonic": 1}   ## in the pack when the story begins (given once)
const CAP := 9                           ## the most of one kind the pack holds
const DROP_CHANCE := 0.22                ## a won battle leaves a supply this often
## who sells supplies (an id of a person); the barkeep also lets a room (the inn)
const SELLERS := ["barkeep", "mira", "nib"]
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


## Adds to the pack (never past CAP). Returns how many really went in.
static func give(id: String, n: int = 1) -> int:
	var had := count(id)
	var now := mini(CAP, had + n)
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
	var pool := on_sale(step)
	if randf() < 0.65:
		return "herb"
	return String(pool[randi() % pool.size()]["id"])


static func inn_price() -> int:
	return INN_PRICE + INN_PRICE_LEVEL * (Save.hub_get("rpg:lvl") if Save.hub_get("rpg:lvl") > 0 else 1)
