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
##     boss_killed and boss_killed:<boss id>, secret_found, chest_opened, rooms_cleared, key_used,
##     bomb_used, shop_buy, kills, coins, floor_reached:<n> ... and anything else it likes
##     (kills and coins also feed total_kills / total_coins at once; floor_reached feeds best_floor)
##   sent by the Hungry Curse (scripts/entities/curse.gd):
##     curse_meals (enemies swallowed), curse_feast (3 or more in one lunge), belly_burst_10 (10 or more
##     coins coughed up by one bomb), boss_bitten_30 (one boss lost 30% of its health to bites),
##     win_curse_0 / win_curse_5 (won a run at Curse Level 0 / 5), curse_bites, curse_calls, belly_coins ...
## A rule that watches "boss_killed" also counts every "boss_killed:<something>".
##
## To add an unlock: add one row. Nothing else needs to change.
## Anything NOT listed here is available from the start.

const RULES := [
	# ---------------------------------------------------------------- heroes
	{"id": "hero:witch", "name": "Ozric, the Old Hexer", "hint": "Defeat the first boss.", "stat": "boss_killed", "at_least": 1},
	{"id": "hero:robber", "name": "Tobin, the Grave Robber", "hint": "Find two secret rooms.", "stat": "secret_found", "at_least": 2},

	# ---------------------------------------------------------------- achievements
	{"id": "ach:first_win", "name": "Daylight", "hint": "Win a run.", "stat": "wins", "at_least": 1},
	{"id": "ach:win_knight", "name": "Oath Kept", "hint": "Win a run as Aldous.", "stat": "wins:knight", "at_least": 1},
	{"id": "ach:win_witch", "name": "Old Tricks", "hint": "Win a run as Ozric.", "stat": "wins:witch", "at_least": 1},
	{"id": "ach:win_robber", "name": "Clean Getaway", "hint": "Win a run as Tobin.", "stat": "wins:robber", "at_least": 1},
	{"id": "ach:kills_500", "name": "Grave Filler", "hint": "Defeat 500 monsters in total.", "stat": "total_kills", "at_least": 500},
	{"id": "ach:coins_300", "name": "Heavy Purse", "hint": "Collect 300 coins in total.", "stat": "total_coins", "at_least": 300},
	{"id": "ach:chests_10", "name": "Lid Lifter", "hint": "Open 10 chests.", "stat": "chest_opened", "at_least": 10},
	{"id": "ach:cursed_5", "name": "Bad Habits", "hint": "Take 5 cursed items in total.", "stat": "cursed_taken", "at_least": 5},
	{"id": "ach:floor_3", "name": "Further Down", "hint": "Reach the third floor.", "stat": "best_floor", "at_least": 3},
	{"id": "ach:secrets_5", "name": "Wall Knocker", "hint": "Find 5 secret rooms in total.", "stat": "secret_found", "at_least": 5},
	{"id": "ach:paid_in_full", "name": "Paid in Full", "hint": "Win a run at Curse Level 0.", "stat": "win_curse_0", "at_least": 1},
	{"id": "ach:bottomless", "name": "Bottomless", "hint": "Win a run at Curse Level 5.", "stat": "win_curse_5", "at_least": 1},

	# ---------------------------------------------------------------- ITEM UNLOCKS
	# Content agents: add item rows BELOW this line, one per locked item, for example
	#   {"id": "item:glass_blade", "name": "Glass Blade", "hint": "Win a run as Aldous.", "stat": "wins:knight", "at_least": 1},
	# An item with a row here stays out of the item pools until Save.is_unlocked("item:<id>") is true.
	{"id": "item:spiked_goad", "name": "Spiked Goad", "hint": "Let your Curse swallow 100 monsters in total.", "stat": "curse_meals", "at_least": 100},
	{"id": "item:tithe_imp", "name": "Tithe Bat", "hint": "Feed your Curse 3 monsters in one lunge.", "stat": "curse_feast", "at_least": 1},
	{"id": "item:gilded_fang", "name": "Gilded Fang", "hint": "Make your Curse cough up 10 coins with one bomb.", "stat": "belly_burst_10", "at_least": 1},
	{"id": "item:iron_leash", "name": "Iron Leash", "hint": "Let your Curse bite 30% off one boss.", "stat": "boss_bitten_30", "at_least": 1},
	{"id": "item:reaping_hook", "name": "Reaping Hook", "hint": "Defeat 300 monsters in total.", "stat": "total_kills", "at_least": 300},
	{"id": "item:ossuary_chain", "name": "Ossuary Chain", "hint": "Take 5 cursed items in total.", "stat": "cursed_taken", "at_least": 5},
	{"id": "item:cry_of_knives", "name": "Cry of Knives", "hint": "CALL your Curse 40 times in total.", "stat": "curse_calls", "at_least": 40},
	{"id": "item:knocker_bat", "name": "Knocker Bat", "hint": "Find 3 secret rooms in total.", "stat": "secret_found", "at_least": 3},
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
