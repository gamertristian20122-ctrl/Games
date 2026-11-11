extends RefCounted
## Items: every passive item in the game. Use with:  const Items = preload("res://scripts/data/items.gd")
## Fields every item has (the shell's item card, pause list and collection screen rely on these):
##   name, desc (one short line, what it does), icon (an Art id), cursed (bool), pools (Array of pool names)
## Cursed items also have "curse" (one short line describing the downside).
## EVERY cursed item also raises the Curse Level by 1 when taken (the Hungry Curse grows; see
## scripts/entities/curse.gd). That needs no field here: "cursed": true is enough.
##
## HOW AN ITEM WORKS (the world half reads these extra fields; all are optional):
##   mods      stat changes, added as one layer in scripts/run/stats.gd:
##               {"flat": {"damage": 1.0}, "pct": {"speed": 0.15}, "mult": {"damage": 2.0}, "flags": {"pierce": 1}}
##             stats: speed damage rate range shot_speed shot_size knockback shots spread homing
##                    hurt_mult coin_mult luck invuln bomb_damage      flags: pierce bounce (and any you invent)
##             the Hungry Curse reads three more stats: call_cooldown (seconds), curse_creep (speed
##             multiplier), belly_mult (coins a bombed Curse coughs up) and the flag curse_eats_coins
##   give      handed over once when picked up: {"max_hp": 2, "hp": 2, "armor": 2, "coins": 5, "keys": 1, "bombs": 1}
##             (hp, max_hp and armor are HALF hearts)
##   familiar  an id from familiars.gd that joins the player
##   locked    true = only appears after Save.is_unlocked("item:<id>")
##   Anything smarter (on kill, on hit, when hurt ...) is a function in scripts/run/item_effects.gd
##   named <item id>_<hook>, for example  grave_cleaver_on_kill.  No other file needs to change.
## POOLS: "treasure" (treasure rooms), "boss" (boss reward), "shop", "secret", "cursed" (cursed
## pedestals and the shop's bargain stand). An item never appears twice in one run.
## TO ADD AN ITEM: add a row. The icon must be an existing sprite id.

const ALL := {
	# ---------------------------------------------------------------- plain stat items
	"whetstone": {"name": "Whetstone", "desc": "Damage up.", "icon": "weapon_regular_sword", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"flat": {"damage": 1.0}}},
	"swift_tonic": {"name": "Swift Tonic", "desc": "Move faster.", "icon": "flask_big_green", "cursed": false, "pools": ["treasure", "shop"],
		"mods": {"pct": {"speed": 0.18}}},
	"sparking_tonic": {"name": "Sparking Tonic", "desc": "Fire faster.", "icon": "flask_big_yellow", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"pct": {"rate": 0.30}}},
	"longbow_string": {"name": "Longbow String", "desc": "Shots fly farther and faster.", "icon": "weapon_bow", "cursed": false, "pools": ["treasure", "shop"],
		"mods": {"pct": {"range": 0.35, "shot_speed": 0.25}}},
	"crimson_draught": {"name": "Crimson Draught", "desc": "One more heart, and it comes full.", "icon": "flask_big_red", "cursed": false, "pools": ["treasure", "boss", "shop", "secret"],
		"give": {"max_hp": 2, "hp": 2}},
	# ---------------------------------------------------------------- shot changers
	"twin_hatchets": {"name": "Twin Hatchets", "desc": "Throw two shots at once, each a little weaker.", "icon": "weapon_double_axe", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flat": {"shots": 1.0, "spread": 0.05}, "pct": {"damage": -0.25}}},
	"needle_spear": {"name": "Needle Spear", "desc": "Shots pass through one more enemy.", "icon": "weapon_spear", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"mods": {"flags": {"pierce": 1}, "pct": {"shot_speed": 0.10}}},
	"ricochet_mallet": {"name": "Ricochet Mallet", "desc": "Shots bounce off walls twice.", "icon": "weapon_hammer", "cursed": false, "pools": ["treasure", "secret"],
		"mods": {"flags": {"bounce": 2}, "pct": {"range": 0.30}}},
	"seeker_staff": {"name": "Seeker Staff", "desc": "Shots curve toward enemies.", "icon": "weapon_green_magic_staff", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flat": {"homing": 2.6}}},
	# ---------------------------------------------------------------- items with hooks (see item_effects.gd)
	"wardwater": {"name": "Wardwater", "desc": "A blue heart now, and half of one every third room you clear.", "icon": "flask_big_blue", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"give": {"armor": 2}},
	"grave_cleaver": {"name": "Grave Cleaver", "desc": "Slain enemies burst into bone shards that hurt others.", "icon": "weapon_cleaver", "cursed": false, "pools": ["treasure", "boss", "secret"]},
	# ---------------------------------------------------------------- cursed: stronger, with a price
	"glass_blade": {"name": "Glass Blade", "desc": "Damage doubled.", "curse": "You take double damage.", "icon": "weapon_red_gem_sword", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"damage": 2.0, "hurt_mult": 2.0}}},
	"frenzy_saw": {"name": "Frenzy Saw", "desc": "Fire almost twice as fast.", "curse": "Your shots fly wild and fall short.", "icon": "weapon_saw_sword", "cursed": true, "pools": ["cursed"],
		"mods": {"pct": {"rate": 0.85, "range": -0.25}, "flat": {"spread": 0.30}}},
	"gilded_blade": {"name": "Gilded Blade", "desc": "Every coin you carry adds damage.", "curse": "Getting hit knocks 5 coins out of your purse.", "icon": "weapon_golden_sword", "cursed": true, "pools": ["cursed"]},
	"leaden_maul": {"name": "Leaden Maul", "desc": "Damage nearly doubled.", "curse": "You walk slower.", "icon": "weapon_big_hammer", "cursed": true, "pools": ["cursed"],
		"mods": {"pct": {"damage": 0.80, "speed": -0.20}}},
	"storm_axes": {"name": "Storm Axes", "desc": "Throw two more shots at once.", "curse": "They spray wide and fall short.", "icon": "weapon_throwing_axe", "cursed": true, "pools": ["cursed"],
		"mods": {"flat": {"shots": 2.0, "spread": 0.35}, "pct": {"range": -0.20}}},
	"misers_flask": {"name": "Miser's Flask", "desc": "Every coin counts double.", "curse": "Half as long to recover after a hit.", "icon": "flask_yellow", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"coin_mult": 2.0, "invuln": 0.5}}},
	"hollow_bolt": {"name": "Hollow Bolt", "desc": "Shots pass through two more enemies and fly farther.", "curse": "You fire slower.", "icon": "weapon_arrow", "cursed": true, "pools": ["cursed"],
		"mods": {"flags": {"pierce": 2}, "pct": {"range": 0.40, "rate": -0.25}}},
	"gilded_fang": {"name": "Gilded Fang", "desc": "A bombed Curse coughs up double.", "curse": "Your Curse also eats coins lying on the floor.", "icon": "weapon_lavish_sword", "cursed": true, "pools": ["cursed"], "locked": true,
		"mods": {"mult": {"belly_mult": 2.0}, "flags": {"curse_eats_coins": 1}}},
	# ---------------------------------------------------------------- items that handle the Hungry Curse (not cursed)
	"spiked_goad": {"name": "Spiked Goad", "desc": "CALL is ready again much sooner.", "icon": "weapon_baton_with_spikes", "cursed": false, "pools": ["treasure", "shop", "secret"], "locked": true,
		"mods": {"flat": {"call_cooldown": -1.5}}},
	"iron_leash": {"name": "Iron Leash", "desc": "Your Curse creeps slower.", "icon": "weapon_mace", "cursed": false, "pools": ["treasure", "shop", "boss"], "locked": true,
		"mods": {"mult": {"curse_creep": 0.615}}},
	"tithe_imp": {"name": "Tithe Imp", "desc": "After each meal it fetches you a coin from the Curse's belly.", "icon": "imp", "cursed": false, "pools": ["treasure", "shop", "secret"], "locked": true,
		"familiar": "tithe_imp"},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "desc": "", "icon": "skull", "cursed": false, "pools": []})
