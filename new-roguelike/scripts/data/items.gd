extends RefCounted
## Items: every passive item in the game. Use with:  const Items = preload("res://scripts/data/items.gd")
## Fields every item has (the shell's item card, pause list and collection screen rely on these):
##   name, desc (one short line, what it does), icon (an Art id), cursed (bool), pools (Array of pool names)
## Cursed items also have "curse" (one short line describing the downside).
## The world half adds whatever effect fields it needs (stat changes, flags, hooks).

const ALL := {
	"whetstone": {"name": "Whetstone", "desc": "Damage up.", "icon": "weapon_regular_sword", "cursed": false, "pools": ["treasure", "shop", "boss"]},
	"swift_tonic": {"name": "Swift Tonic", "desc": "Move faster.", "icon": "flask_big_green", "cursed": false, "pools": ["treasure", "shop"]},
	"glass_blade": {"name": "Glass Blade", "desc": "Damage doubled.", "curse": "You take double damage.", "icon": "weapon_red_gem_sword", "cursed": true, "pools": ["cursed"]},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "desc": "", "icon": "skull", "cursed": false, "pools": []})
