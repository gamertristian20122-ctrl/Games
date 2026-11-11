extends RefCounted
## Familiars: little helpers that follow the player. Use with:
##   const Familiars = preload("res://scripts/data/familiars.gd")
## To add one: add a row. To give it a new job, add a file in scripts/entities/familiars/
## and put its file name (without .gd) in "behaviour".
##   name        for the HUD / logs            sprite   an Art id          tint   colour wash over the sprite
##   behaviour   file name in scripts/entities/familiars/
##   params      numbers that behaviour file understands
## A hero starts with one through "familiar" in heroes.gd; an item grants one through "familiar" in items.gd.

const ALL := {
	"wisp": {"name": "Pale Wisp", "sprite": "angel", "tint": Color(0.80, 0.95, 1.0, 0.95),
		"behaviour": "shooter", "params": {"cooldown": 1.15, "damage": 1.6, "range": 95.0, "shot_speed": 150.0, "shot": "wisp"}},
	# After each meal of the Hungry Curse it flies over, takes one coin out of the belly and brings it to you.
	"tithe_imp": {"name": "Tithe Imp", "sprite": "imp", "tint": Color(1.25, 1.0, 0.45),
		"behaviour": "tithe", "params": {"per_room": 3, "speed": 150.0}},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, ALL["wisp"])
