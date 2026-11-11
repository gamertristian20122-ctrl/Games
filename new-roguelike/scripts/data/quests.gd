extends RefCounted
## Quests: the jobs the Druid at the camp hands out (scripts/hub/hub.gd shows them).
##
## A quest counts one of Save's lifetime counters from the moment it is first offered:
##   "stat"    the counter (see the list in scripts/core/save.gd and the G.stat keys of the world)
##   "need"    how many more of it finish the quest
##   "abs"     true = the counter itself must reach "need" (best floor), not "need more than at the start"
##   "reward"  supplies for the NEXT run: {"coins": n, "bombs": n, "keys": n}. They wait in the save
##             ("boon:<kind>") until a run starts, then the hero sets out with them (run.gd).
## The Druid offers the first OFFERED quests of the list that are not done yet, in this order.
## To add a quest: add a row. Words are plain text the owner may rewrite.

const OFFERED := 3
const BOONS := ["coins", "bombs", "keys"]
const BOON_NAMES := {"coins": "coins", "bombs": "bombs", "keys": "keys"}
const BOON_CAP := {"coins": 30, "bombs": 5, "keys": 3}      ## the most the pack carries into one run

const LIST := [
	{"id": "thin_the_crypt", "name": "Thin the Crypt", "text": "Slay 25 monsters.", "stat": "total_kills", "need": 25, "reward": {"coins": 5}},
	{"id": "feed_it", "name": "Feed It", "text": "Let the Curse swallow 10 monsters.", "stat": "curse_meals", "need": 10, "reward": {"bombs": 1}},
	{"id": "saint_or_sexton", "name": "The First Seal", "text": "Beat the guardian of the Crypt.", "stat": "boss_killed", "need": 1, "reward": {"keys": 1}},
	{"id": "deep_pockets", "name": "Deep Pockets", "text": "Collect 100 coins.", "stat": "total_coins", "need": 100, "reward": {"coins": 8}},
	{"id": "into_the_warrens", "name": "Into the Warrens", "text": "Reach the second floor.", "stat": "best_floor", "need": 2, "abs": true, "reward": {"bombs": 1}},
	{"id": "crack_it_open", "name": "Crack It Open", "text": "Stun the Curse with a bomb 3 times.", "stat": "curse_stunned", "need": 3, "reward": {"bombs": 2}},
	{"id": "hidden_things", "name": "Hidden Things", "text": "Find 3 secret rooms.", "stat": "secret_found", "need": 3, "reward": {"keys": 1}},
	{"id": "culling", "name": "The Culling", "text": "Slay 150 monsters.", "stat": "total_kills", "need": 150, "reward": {"coins": 10}},
	{"id": "ashen_road", "name": "The Ashen Road", "text": "Reach the third floor.", "stat": "best_floor", "need": 3, "abs": true, "reward": {"keys": 1, "bombs": 1}},
	{"id": "fat_curse", "name": "A Fat Curse", "text": "Let the Curse swallow 60 monsters.", "stat": "curse_meals", "need": 60, "reward": {"coins": 10}},
	{"id": "three_seals", "name": "Three Seals", "text": "Beat 3 more guardians.", "stat": "boss_killed", "need": 3, "reward": {"keys": 1, "coins": 5}},
	{"id": "the_pit", "name": "The Pit", "text": "Reach the fourth floor.", "stat": "best_floor", "need": 4, "abs": true, "reward": {"bombs": 2, "coins": 5}},
	{"id": "starve_the_king", "name": "Starve the King", "text": "Win a run.", "stat": "wins", "need": 1, "reward": {"coins": 15, "keys": 1, "bombs": 1}},
]


## The quests on offer right now (rows of LIST). Offering one remembers where its counter stood.
static func offered() -> Array:
	var out: Array = []
	for q: Dictionary in LIST:
		var id := String(q["id"])
		if Save.hub_get("q:%s:done" % id) > 0:
			continue
		if Save.hub_get("q:%s:on" % id) == 0:
			Save.hub_set("q:%s:on" % id, 1)
			Save.hub_set("q:%s:base" % id, Save.stat_get(String(q["stat"])))
		out.append(q)
		if out.size() >= OFFERED:
			break
	return out


static func progress(q: Dictionary) -> int:
	var now := Save.stat_get(String(q["stat"]))
	if not bool(q.get("abs", false)):
		now -= Save.hub_get("q:%s:base" % String(q["id"]))
	return clampi(now, 0, int(q["need"]))


static func complete(q: Dictionary) -> bool:
	return progress(q) >= int(q["need"])


static func any_complete() -> bool:
	for q: Dictionary in offered():
		if complete(q):
			return true
	return false


static func done_count() -> int:
	var n := 0
	for q: Dictionary in LIST:
		if Save.hub_get("q:%s:done" % String(q["id"])) > 0:
			n += 1
	return n


## Hands the reward over (into the pack for the next run) and closes the quest.
static func claim(id: String) -> void:
	for q: Dictionary in LIST:
		if String(q["id"]) != id or not complete(q) or Save.hub_get("q:%s:done" % id) > 0:
			continue
		Save.hub_set("q:%s:done" % id, 1)
		var reward: Dictionary = q.get("reward", {})
		for kind: String in reward:
			Save.hub_set("boon:" + kind, mini(Save.hub_get("boon:" + kind) + int(reward[kind]), int(BOON_CAP.get(kind, 99))))
		Save.flush()


static func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = []
	for kind: String in BOONS:
		if int(reward.get(kind, 0)) > 0:
			var n := int(reward[kind])
			var word := String(BOON_NAMES[kind])
			parts.append("%d %s" % [n, word if n != 1 else word.trim_suffix("s")])
	return " + ".join(parts)


## What waits in the pack: {"coins": n, ...} with only the kinds above zero.
static func pack() -> Dictionary:
	var out := {}
	for kind: String in BOONS:
		var n := Save.hub_get("boon:" + kind)
		if n > 0:
			out[kind] = n
	return out


## A run starts: the hero takes the pack along and it is empty again.
static func take_pack() -> Dictionary:
	var out := pack()
	for kind: String in out:
		Save.hub_set("boon:" + kind, 0)
	return out
