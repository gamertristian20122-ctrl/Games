extends RefCounted
## Unlocks: the rules that open up heroes, items and achievements.
## Use with:  const Unlocks = preload("res://scripts/data/unlocks.gd")
##
## Each rule:
##   id        "hero:<hero id>", "item:<item id>" or "ach:<any id>"
##   name      shown in the "Unlocked: ..." banner, on the end screen and in the Collection
##   hint      how to earn it (shown while it is still locked)
##   stat      the lifetime counter to watch (see the list below)
##   at_least  the rule unlocks when the counter reaches this number
##
## Counters the game keeps (scripts/core/save.gd):
##   recorded by the shell at the end of every run:
##     runs, deaths, wins, wins:<hero id>, best_floor (1 = first floor), fastest_win (seconds),
##     total_kills, total_coins
##   recorded by the shell when an item is picked up:
##     items_taken, cursed_taken
##   sent by the world with G.stat.emit(key, amount):
##     boss_killed or boss_killed:<boss id>, secret_found, chest_opened, and anything else it likes
## A rule that watches "boss_killed" also counts every "boss_killed:<something>".
##
## To add an unlock: add one row. Nothing else needs to change.
## Anything NOT listed here is available from the start.

const RULES := [
	# ---------------------------------------------------------------- heroes
	{"id": "hero:witch", "name": "Mirelle, the Young Witch", "hint": "Defeat the first boss.", "stat": "boss_killed", "at_least": 1},
	{"id": "hero:robber", "name": "Tobin, the Grave Robber", "hint": "Find two secret rooms.", "stat": "secret_found", "at_least": 2},

	# ---------------------------------------------------------------- achievements
	{"id": "ach:first_win", "name": "Daylight", "hint": "Win a run.", "stat": "wins", "at_least": 1},
	{"id": "ach:win_knight", "name": "Oath Kept", "hint": "Win a run as Aldous.", "stat": "wins:knight", "at_least": 1},
	{"id": "ach:win_witch", "name": "Top of the Class", "hint": "Win a run as Mirelle.", "stat": "wins:witch", "at_least": 1},
	{"id": "ach:win_robber", "name": "Clean Getaway", "hint": "Win a run as Tobin.", "stat": "wins:robber", "at_least": 1},
	{"id": "ach:kills_500", "name": "Grave Filler", "hint": "Defeat 500 monsters in total.", "stat": "total_kills", "at_least": 500},
	{"id": "ach:coins_300", "name": "Heavy Purse", "hint": "Collect 300 coins in total.", "stat": "total_coins", "at_least": 300},
	{"id": "ach:chests_10", "name": "Lid Lifter", "hint": "Open 10 chests.", "stat": "chest_opened", "at_least": 10},
	{"id": "ach:cursed_5", "name": "Bad Habits", "hint": "Take 5 cursed items in total.", "stat": "cursed_taken", "at_least": 5},
	{"id": "ach:floor_3", "name": "Further Down", "hint": "Reach the third floor.", "stat": "best_floor", "at_least": 3},
	{"id": "ach:secrets_5", "name": "Wall Knocker", "hint": "Find 5 secret rooms in total.", "stat": "secret_found", "at_least": 5},

	# ---------------------------------------------------------------- ITEM UNLOCKS
	# Content agents: add item rows BELOW this line, one per locked item, for example
	#   {"id": "item:glass_blade", "name": "Glass Blade", "hint": "Win a run as Aldous.", "stat": "wins:knight", "at_least": 1},
	# An item with a row here stays out of the item pools until Save.is_unlocked("item:<id>") is true.
	# ---------------------------------------------------------------- end of item unlocks
]


static func by_id(id: String) -> Dictionary:
	for r: Dictionary in RULES:
		if r["id"] == id:
			return r
	return {}


## "hero", "item" or "ach".
static func kind(id: String) -> String:
	return id.get_slice(":", 0)


## Is there a rule for this id at all? (No rule = always available.)
static func is_gated(id: String) -> bool:
	return not by_id(id).is_empty()
