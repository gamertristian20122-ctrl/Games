extends RefCounted
## Pickups: the small things you walk over to collect. Use with:
##   const Pickups = preload("res://scripts/data/pickups.gd")
## To add one: add a row. No code needed as long as "give" uses the words the player understands.
##   sprite   a list of Art ids; the first one that exists is used (so better art can be dropped in later)
##   tint     colour wash          scale   size multiplier
##   give     what the player gets: {"coins": n} {"hp": half hearts} {"armor": half hearts} {"keys": n} {"bombs": n}
##   kind     what G.pickup_collected reports: "coin", "key", "bomb", "heart" or "armor"
##   sfx      sound name          need   "hurt" = only picked up when not at full health
## The key is Niji's "niji_key_gold" (assets/art/niji, cut out by tools/import_assets.py); the yellow
## flask is only the fallback if that art is ever missing.

const ALL := {
	"coin": {"sprite": ["coin"], "tint": Color(1, 1, 1), "scale": 1.0, "give": {"coins": 1}, "kind": "coin", "sfx": "coin_pickup"},
	"coin5": {"sprite": ["coin"], "tint": Color(1.35, 1.25, 0.75), "scale": 1.6, "give": {"coins": 5}, "kind": "coin", "sfx": "coin_pickup"},
	"half_heart": {"sprite": ["ui_heart_half"], "tint": Color(1, 1, 1), "scale": 0.8, "give": {"hp": 1}, "kind": "heart", "sfx": "heart_pickup", "need": "hurt"},
	"heart": {"sprite": ["ui_heart_full"], "tint": Color(1, 1, 1), "scale": 0.8, "give": {"hp": 2}, "kind": "heart", "sfx": "heart_pickup", "need": "hurt"},
	"armor": {"sprite": ["ui_heart_full"], "tint": Color(0.45, 0.75, 1.6), "scale": 0.8, "give": {"armor": 2}, "kind": "armor", "sfx": "heart_pickup"},
	"key": {"sprite": ["key", "niji_key_gold", "flask_yellow"], "tint": Color(1, 1, 1), "scale": 1.0, "give": {"keys": 1}, "kind": "key", "sfx": "key_pickup"},
	"bomb": {"sprite": ["bomb"], "tint": Color(1, 1, 1), "scale": 0.8, "give": {"bombs": 1}, "kind": "bomb", "sfx": "bomb_pickup"},
}

## What a cleared fight room may leave behind (weights; see room.gd roll_room_reward()).
const ROOM_REWARD := {"nothing": 34, "coins": 30, "heart": 12, "key": 10, "bomb": 10, "chest": 4}
## The key weight while the player has no key and the treasure room is still locked.
const KEY_WEIGHT_WHEN_NEEDED := 30

## Shop prices in coins.
const PRICE_HEART := 3
const PRICE_SUPPLY := 5
const PRICE_ITEM := 15
const PRICE_CURSED := 7
## "Starve the Curse" (the shop's skull stand, shown from Curse Level 1): one level off per
## purchase. The first one in a run costs 15, the second 25, the third 35; then it is sold out.
const PRICE_STARVE := [15, 25, 35]


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL["coin"])


## The first sprite id in the row's list that really exists.
static func sprite_for(id: String) -> String:
	var list: Array = info(id)["sprite"]
	for s in list:
		if Art.has(s):
			return s
	return String(list[list.size() - 1])
