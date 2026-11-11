extends RefCounted
## Heroes: the playable characters. Use with:  const Heroes = preload("res://scripts/data/heroes.gd")
## The shell reads id / name / title / desc / passive / sprite / unlock_hint for the hero-select screen.
## A hero is locked while Save.is_unlocked("hero:<id>") is false AND its "locked" field is true.
## Stats: hp and armor are HALF hearts; speed px/s; damage per shot; rate shots/s; range px; shot_speed px/s.

const LIST := [
	{
		"id": "knight", "name": "Aldous", "title": "The Cursed Knight", "sprite": "knight_m", "weapon": "weapon_knight_sword",
		"desc": "A fallen knight who hurls spectral blades. Slow, sturdy, hits hard.",
		"passive": "Oath Ward: the first hit in every room is blocked.",
		"locked": false, "unlock_hint": "",
		"hp": 8, "armor": 0, "speed": 86.0, "damage": 4.0, "rate": 1.9, "range": 115.0, "shot_speed": 150.0,
	},
	{
		"id": "witch", "name": "Mirelle", "title": "The Young Witch", "sprite": "wizzard_f", "weapon": "weapon_red_magic_staff",
		"desc": "An apprentice with fast, curving hex bolts. Fragile.",
		"passive": "Companion: starts every run with a familiar.",
		"locked": true, "unlock_hint": "Defeat the first boss.",
		"hp": 4, "armor": 2, "speed": 98.0, "damage": 2.6, "rate": 3.0, "range": 125.0, "shot_speed": 165.0,
	},
	{
		"id": "robber", "name": "Tobin", "title": "The Grave Robber", "sprite": "elf_m", "weapon": "weapon_knife",
		"desc": "A thief who went too deep. Quick feet, quick knives, short reach.",
		"passive": "Prepared: starts with a key and two bombs, and finds more coins.",
		"locked": true, "unlock_hint": "Find two secret rooms.",
		"hp": 6, "armor": 0, "speed": 108.0, "damage": 3.0, "rate": 2.5, "range": 85.0, "shot_speed": 190.0,
	},
]


static func by_id(id: String) -> Dictionary:
	for h in LIST:
		if h["id"] == id:
			return h
	return LIST[0]
