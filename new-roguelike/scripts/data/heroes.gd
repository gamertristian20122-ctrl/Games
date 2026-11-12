extends RefCounted
## Heroes: the playable characters. Use with:  const Heroes = preload("res://scripts/data/heroes.gd")
## The shell reads id / name / title / desc / passive / sprite / unlock_hint for the hero-select screen.
## A hero is locked while Save.is_unlocked("hero:<id>") is false AND its "locked" field is true.
## Stats: hp and armor are HALF hearts; speed px/s; damage per shot; rate shots/s; range px; shot_speed px/s.
##
## Extra fields the world half reads (all optional):
##   shot        a shot type from shot_types.gd            shoot_sfx   sound played per shot
##   start       what the hero carries at the start: {"keys": 1, "bombs": 2}   (bombs default to 1)
##   mods        a permanent stat layer, same shape as an item's "mods" (see items.gd)
##   familiar    an id from familiars.gd that follows the hero from the start
##   ward        true = the first hit in every room is blocked
##
## How a hero looks: "sprite" is a Pixel Crawler hero (idle, run and death animations), "weapon" is a
## weapon still from the same pack (pc_weapon_*; they point up) and "grip" is how many pixels above
## the bottom of that picture the hand holds it, "hand" is the pack's hand piece (pc_hand_*) closed
## around the grip. scripts/entities/hero_look.gd does the holding. Pick a weapon about as long as
## the hero is tall or shorter (the heroes are 29 to 32 px tall); never scale one.
## The hero ids ("knight", "witch", "robber") are used by saves, unlocks and test flags: do not rename
## them. Names, titles and descriptions are placeholders and can be rewritten freely.

const Looks = preload("res://scripts/data/looks.gd")

const LIST := [
	{
		"id": "knight", "name": "Aldous", "title": "The Last Knight", "sprite": "pc_knight", "weapon": "pc_weapon_castle_13", "grip": 3, "hand": "pc_hand_castle_16",
		"desc": "A knight with a sword and nothing else. He cuts down what stands close and bats shots out of the air.",
		"passive": "Oath Ward: the first hit in every room is blocked.",
		"locked": false, "unlock_hint": "",
		"hp": 8, "armor": 0, "speed": 94.0, "damage": 6.0, "rate": 2.3, "range": 100.0, "shot_speed": 150.0,      # range and shot_speed are only the BASE that items scale (reach, swing speed)
		"shot": "blade", "shoot_sfx": "player_shoot_blade", "ward": true,
		# a SWORD SWING instead of shots (player.gd _swing): everything inside the arc in front of him is hit
		# at once and enemy shots inside it are cut down. reach px from his middle, arc in radians.
		# What every item stat means for the sword is listed above _swing() in player.gd.
		"melee": {"reach": 34.0, "arc": 2.3, "knock": 1.6, "guard_arc": 2.4},     # guard_arc: how wide the BLOCK covers (radians)
	},
	{
		"id": "witch", "name": "Ozric", "title": "The Old Hexer", "sprite": "pc_wizard", "weapon": "pc_weapon_hideout_14", "grip": 11, "hand": "pc_hand_base_0",
		"desc": "An old wizard whose fast hex bolts curve after their prey. Frail.",
		"passive": "Companion: starts every run with a familiar.",
		"locked": true, "unlock_hint": "Defeat the first boss.",
		"hp": 4, "armor": 2, "speed": 98.0, "damage": 2.6, "rate": 3.0, "range": 125.0, "shot_speed": 165.0,
		"shot": "hex", "shoot_sfx": "player_shoot_magic", "familiar": "wisp", "mods": {"flat": {"homing": 1.6}},
	},
	{
		"id": "robber", "name": "Tobin", "title": "The Grave Robber", "sprite": "pc_rogue", "weapon": "pc_weapon_garden_8", "grip": 4, "hand": "pc_hand_hideout_16",
		"desc": "A thief who went too deep. Quick feet, quick knives, short reach.",
		"passive": "Prepared: starts with a key and two bombs, and finds more coins.",
		"locked": true, "unlock_hint": "Find two secret rooms.",
		"hp": 6, "armor": 0, "speed": 108.0, "damage": 3.3, "rate": 2.5, "range": 108.0, "shot_speed": 190.0,
		"shot": "knife", "shoot_sfx": "player_shoot_knife", "start": {"keys": 1, "bombs": 2},
		"mods": {"flags": {"pierce": 1}, "pct": {"coin_mult": 0.25}},
	},
]


static func by_id(id: String) -> Dictionary:
	for h in LIST:
		if h["id"] == id:
			# the knight is the player's own: name, armour colour, sword (scripts/data/looks.gd)
			return Looks.apply(h) if id == "knight" else h
	return LIST[0]
