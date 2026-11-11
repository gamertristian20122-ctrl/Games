extends RefCounted
## Pickups: the small things you walk over to collect. Use with:
##   const Pickups = preload("res://scripts/data/pickups.gd")
## To add one: add a row. No code needed as long as "give" uses the words the player understands.
##   sprite   a list of Art ids; the first one that exists is used (the old art stays as a fallback)
##   tint     colour wash          scale   size multiplier (keep 1.0: pixel art does not scale well)
##   shadow   width of the shadow it sits on, in px
##   give     what the player gets: {"coins": n} {"hp": half hearts} {"armor": half hearts} {"keys": n} {"bombs": n}
##   kind     what G.pickup_collected reports: "coin", "key", "bomb", "heart" or "armor"
##   sfx      sound name          need   "hurt" = only picked up when not at full health
## The pictures are ids "prop_*" in assets/art/props, cut by tools/import_props.py (which pack each
## one comes from is in assets/art/props/props.json): a spinning gold coin, a green gem for five
## coins, a heart, the same heart with its right half emptied for half a heart (as on the HUD),
## a blue heart for armour, a key that rocks (it never turns edge-on like the coin) and a bomb.

const ALL := {
	"coin": {"sprite": ["prop_coin", "coin"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 9.0, "give": {"coins": 1}, "kind": "coin", "sfx": "coin_pickup"},
	"coin5": {"sprite": ["prop_gem", "coin"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 10.0, "give": {"coins": 5}, "kind": "coin", "sfx": "coin_pickup"},
	"half_heart": {"sprite": ["prop_half_heart", "ui_heart_half"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 11.0, "give": {"hp": 1}, "kind": "heart", "sfx": "heart_pickup", "need": "hurt"},
	"heart": {"sprite": ["prop_heart", "ui_heart_full"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 11.0, "give": {"hp": 2}, "kind": "heart", "sfx": "heart_pickup", "need": "hurt"},
	"armor": {"sprite": ["prop_armor", "ui_heart_full"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 11.0, "give": {"armor": 2}, "kind": "armor", "sfx": "heart_pickup"},
	"key": {"sprite": ["prop_key", "niji_key_gold", "flask_yellow"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 8.0, "give": {"keys": 1}, "kind": "key", "sfx": "key_pickup"},
	"bomb": {"sprite": ["prop_bomb", "bomb"], "tint": Color(1, 1, 1), "scale": 1.0, "shadow": 11.0, "give": {"bombs": 1}, "kind": "bomb", "sfx": "bomb_pickup"},
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
