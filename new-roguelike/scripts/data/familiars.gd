extends RefCounted
## Familiars: little helpers that follow the player. Use with:
##   const Familiars = preload("res://scripts/data/familiars.gd")
## To add one: add a row. To give it a new job, add a file in scripts/entities/familiars/
## and put its file name (without .gd) in "behaviour".
##   name        for the HUD / logs            sprite   an Art id          tint   colour wash over the sprite
##   anim        which animation it shows (default "idle"; the small bat's idle hangs upside down,
##               so it uses its flying loop "run")      hover   px it flies above its shadow
##   behaviour   file name in scripts/entities/familiars/
##   params      numbers that behaviour file understands
## A hero starts with one through "familiar" in heroes.gd; an item grants one through "familiar" in items.gd.
## The row keys ("wisp", "tithe_imp" ...) are ids used by heroes.gd, items.gd and unlocks: do not rename them.
## Behaviours so far: shooter (fires at monsters), tithe (fetches belly coins), pointer (shows hidden
## doors), porter (carries spare hearts), percher (marks the toughest monster).

const ALL := {
	"wisp": {"name": "Dusk Bat", "sprite": "pc_bat_small", "anim": "run", "hover": 16.0, "tint": Color(0.82, 0.95, 1.15),
		"behaviour": "shooter", "params": {"cooldown": 1.15, "damage": 1.6, "range": 95.0, "shot_speed": 150.0, "shot": "wisp"}},
	# After each meal of the Hungry Curse it flies over, takes one coin out of the belly and brings it to you.
	"tithe_imp": {"name": "Tithe Bat", "sprite": "pc_bat_small", "anim": "run", "hover": 16.0, "tint": Color(1.3, 1.05, 0.45),
		"behaviour": "tithe", "params": {"per_room": 3, "speed": 150.0}},
	# Flutters at any wall that hides a secret door (it does nothing else: a living pointer).
	"knocker_bat": {"name": "Knocker Bat", "sprite": "pc_bat_small", "anim": "run", "hover": 16.0, "tint": Color(1.25, 1.2, 1.05),
		"behaviour": "pointer", "params": {"speed": 140.0, "circle": 6.0}},
	# Carries red hearts the hero has no room for (2 half hearts) and feeds him when he is hurt.
	"blood_porter": {"name": "Blood Porter", "sprite": "pc_bat_small", "anim": "run", "hover": 16.0, "tint": Color(1.35, 0.45, 0.45),
		"behaviour": "porter", "params": {"carry": 2, "wait": 1.0}},
	# Sits on the toughest monster in the room; the hero's shots hurt that one half again as much.
	"carrion_bat": {"name": "Carrion Bat", "sprite": "pc_bat_small", "anim": "run", "hover": 16.0, "tint": Color(0.70, 1.15, 0.55),
		"behaviour": "percher", "params": {"speed": 170.0, "bonus": 0.5}},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL["wisp"])
