extends RefCounted
## Camp upgrades: lasting improvements to Aldous's sword, shield arm and health, bought with the
## coins in the camp chest (coins he carries out of the hill alive; scripts/data/story.gd walk_out).
## The smith and the cook sell them (scripts/hub/hub.gd adds a button per row to the person named
## in "at"). Each row has steps; a step costs the next number in "costs".
##   "mods"            stat changes PER STEP, in the form scripts/run/stats.gd takes (pct / flat / mult)
##   "block_cooldown"  seconds added to the guard's cooldown per step (negative = sooner)
##   "hp"              half hearts of health added per step
## Bought steps are kept in the save's hub section as "up:<id>". Words are placeholders to rewrite.

const LIST := [
	{"id": "edge", "at": "smith", "name": "Sharpen the blade", "text": "blows hit 10% harder", "costs": [15, 30, 50],
		"mods": {"pct": {"damage": 0.10}}},
	{"id": "balance", "at": "smith", "name": "Balance the hilt", "text": "swing 7% faster", "costs": [15, 30, 50],
		"mods": {"pct": {"rate": 0.07}}},
	{"id": "length", "at": "smith", "name": "Draw out the blade", "text": "a little more reach", "costs": [25, 45],
		"mods": {"pct": {"range": 0.12}}},
	{"id": "guard", "at": "smith", "name": "Mend the guard", "text": "block is ready 1 s sooner", "costs": [20, 40],
		"block_cooldown": -1.0},
	{"id": "meal", "at": "cook", "name": "A proper meal", "text": "one more heart", "costs": [25, 50, 80], "hp": 2},
]


static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return {}


static func tier(id: String) -> int:
	return Save.hub_get("up:" + id)


static func steps(r: Dictionary) -> int:
	return (r["costs"] as Array).size()


## What the next step costs, or -1 when every step is bought.
static func cost(r: Dictionary) -> int:
	var t := tier(String(r["id"]))
	return int(r["costs"][t]) if t < steps(r) else -1


static func coins() -> int:
	return Save.hub_get("bank:coins")


static func buy(id: String) -> bool:
	var r := row(id)
	if r.is_empty():
		return false
	var price := cost(r)
	if price < 0 or coins() < price:
		return false
	Save.hub_set("bank:coins", coins() - price)
	Save.hub_set("up:" + id, tier(id) + 1)
	Save.flush()
	return true


## Every bought step as one stats layer.
static func mods() -> Dictionary:
	var out := {}
	for r: Dictionary in LIST:
		var t := tier(String(r["id"]))
		if t <= 0 or not r.has("mods"):
			continue
		for kind: String in r["mods"]:
			if not out.has(kind):
				out[kind] = {}
			for key: String in r["mods"][kind]:
				out[kind][key] = float(out[kind].get(key, 0.0)) + float(r["mods"][kind][key]) * t
	return out


## Seconds the bought steps add to the guard's cooldown (negative).
static func block_cooldown() -> float:
	var r := row("guard")
	return float(r.get("block_cooldown", 0.0)) * tier("guard")


## Half hearts of health the bought steps add.
static func bonus_hp() -> int:
	var n := 0
	for r: Dictionary in LIST:
		n += int(r.get("hp", 0)) * tier(String(r["id"]))
	return n
