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
##                    hurt_mult coin_mult luck invuln bomb_damage
##             the Hungry Curse reads three more stats: call_cooldown (seconds), curse_creep (speed
##             multiplier), belly_mult (coins a bombed Curse coughs up) and the flag curse_eats_coins
##             FLAGS (a flag is a plain counter; each is read in ONE place):
##               pierce, bounce     how many monsters a shot passes through / walls it bounces off
##               return             shots fly home at the end of their flight      (scripts/run/shots.gd,
##               reap               a shot that kills flies on and grows            where every number
##               bounce_grow        shots grow at every bounce                      of these six lives)
##               eat_shots          shots destroy enemy shots and grow on them
##               curse_shove        shots push the Hungry Curse along
##               eclipse            shots through the Curse are doubled and no longer slow it
##               ring               a volley leaves in a full circle                (scripts/entities/player.gd)
##               coin_ward          a hit costs this many coins instead of health   (scripts/entities/player.gd)
##               curse_eats_coins   the Curse eats coins on the floor               (scripts/entities/curse.gd)
##   give      handed over once when picked up: {"max_hp": 2, "hp": 2, "armor": 2, "coins": 5, "keys": 1, "bombs": 1}
##             (hp, max_hp and armor are HALF hearts)
##   familiar  an id from familiars.gd that joins the player
##   locked    true = only appears after Save.is_unlocked("item:<id>")
##   text      words an effect shows on screen (so they can be rewritten here)
##   Anything smarter (on kill, on hit, when hurt ...) is a function in scripts/run/item_effects.gd
##   named <item id>_<hook>, for example  grave_cleaver_on_kill.  No other file needs to change.
## POOLS: "treasure" (treasure rooms), "boss" (boss reward), "shop", "secret", "cursed" (cursed
## pedestals and the shop's bargain stand). An item never appears twice in one run.
## TO ADD AN ITEM: add a row. The icon must be an existing sprite id.
## ICONS: every item has its own picture icon_<item id> in assets/art/icons/, copied from the
## "Raven Fantasy Icons" pack by tools/import_icons.py (the table of which picture is at its top).
## Statuses (chill, freeze, burn) are in scripts/entities/status.gd; helpers in scripts/data/familiars.gd.

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
		"mods": {"mult": {"curse_creep": 0.73}}},
	"tithe_imp": {"name": "Tithe Imp", "desc": "After each meal it fetches you a coin from the Curse's belly.", "icon": "imp", "cursed": false, "pools": ["treasure", "shop", "secret"], "locked": true,
		"familiar": "tithe_imp"},
	# ================================================================ THE SECOND BATCH (25 items)
	# ---------------------------------------------------------------- shots that behave differently
	"bone_thistle": {"name": "Bone Thistle", "desc": "Shots burst into three splinters where their flight ends.", "icon": "skull", "cursed": false, "pools": ["treasure", "secret"]},
	"tethered_sickle": {"name": "Tethered Sickle", "desc": "Shots fly back to you and cut again on the way.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flags": {"return": 1}}},
	"stonebiter": {"name": "Stonebiter", "desc": "Shots bounce once more and grow with every bounce.", "icon": "skull", "cursed": false, "pools": ["treasure", "secret"],
		"mods": {"flags": {"bounce": 1, "bounce_grow": 1}}},
	"reaping_hook": {"name": "Reaping Hook", "desc": "A shot that kills flies on, bigger with each kill.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss"], "locked": true,
		"mods": {"flags": {"reap": 1}}},
	"starveling_blade": {"name": "Starveling Blade", "desc": "Your shots swallow enemy shots and grow on them.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"flags": {"eat_shots": 1}}},
	"winter_nail": {"name": "Winter Nail", "desc": "Hits chill monsters. The third hit freezes one solid.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"eclipse_shard": {"name": "Eclipse Shard", "desc": "Shots that fly through your Curse hit twice as hard.", "curse": "Your shots no longer slow it.", "icon": "skull", "cursed": true, "pools": ["cursed"],
		"mods": {"flags": {"eclipse": 1}}},
	"breaking_wheel": {"name": "Breaking Wheel", "desc": "Throw four more shots at once.", "curse": "They leave in a ring around you. Only one flies where you aim.", "icon": "skull", "cursed": true, "pools": ["cursed"],
		"mods": {"flat": {"shots": 4.0}, "flags": {"ring": 1}}},
	"barrow_stone": {"name": "Barrow Stone", "desc": "Shots are huge, hit harder and shove monsters back.", "curse": "They crawl through the air.", "icon": "skull", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"shot_size": 2.0, "shot_speed": 0.5}, "pct": {"damage": 0.6, "knockback": 1.0}}},
	"pyre_kindling": {"name": "Pyre Kindling", "desc": "Shots set monsters alight. Fire leaps to monsters that touch.", "curse": "Burning monsters run faster.", "icon": "skull", "cursed": true, "pools": ["cursed"]},
	# ---------------------------------------------------------------- more ways to play with the Hungry Curse
	"moth_mantle": {"name": "Moth Mantle", "desc": "Fire much faster while you stand close to your Curse.", "curse": "You fire slower when you are far from it.", "icon": "skull", "cursed": true, "pools": ["cursed"]},
	"ossuary_chain": {"name": "Ossuary Chain", "desc": "Bigger, harder shots for every Curse Level.", "curse": "It raises your Curse by two Levels, not one.", "icon": "skull", "cursed": true, "pools": ["cursed"], "locked": true},
	"howling_scar": {"name": "Howling Scar", "desc": "When your Curse bites you, every monster in the room is blasted.", "curse": "Your Curse creeps faster.", "icon": "skull", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"curse_creep": 1.3}}},
	"oxbone_cudgel": {"name": "Oxbone Cudgel", "desc": "Your shots shove your Curse the way they fly.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"mods": {"flags": {"curse_shove": 1}}},
	"cry_of_knives": {"name": "Cry of Knives", "desc": "CALL also throws a ring of your shots.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss", "shop"], "locked": true},
	"bitter_marrow": {"name": "Bitter Marrow", "desc": "A bite makes your Curse cough up its whole belly.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"sour_gullet": {"name": "Sour Gullet", "desc": "Your Curse spits swallowed shots back at monsters.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss", "shop"]},
	"fasting_vow": {"name": "Fasting Vow", "desc": "No bites on a floor: your Curse drops a Level.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"text": {"broken": "Vow broken", "kept": "Vow kept"}},
	# ---------------------------------------------------------------- staying alive, coins, helpers
	"ransom_plate": {"name": "Ransom Plate", "desc": "A hit costs you 8 coins instead of health, while you can pay.", "icon": "skull", "cursed": false, "pools": ["treasure", "secret", "boss"],
		"mods": {"flags": {"coin_ward": 8}}},
	"sextons_satchel": {"name": "Sexton's Satchel", "desc": "Reach every new floor with at least 2 bombs and a key.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"give": {"bombs": 1, "keys": 1}},
	"sinners_locket": {"name": "Sinner's Locket", "desc": "One more heart. Taking a cursed item heals you to full.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss", "shop", "secret"],
		"give": {"max_hp": 2, "hp": 2}},
	"undertakers_due": {"name": "Undertaker's Due", "desc": "The last monster you slay in each room always drops something.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"knocker_bat": {"name": "Knocker Bat", "desc": "It flutters at any wall that hides a secret door.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "boss"], "locked": true,
		"familiar": "knocker_bat"},
	"blood_porter": {"name": "Blood Porter", "desc": "Carries hearts you have no room for and feeds you when you bleed.", "icon": "skull", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"familiar": "blood_porter"},
	"carrion_bat": {"name": "Carrion Bat", "desc": "Sits on the toughest monster. Your shots hurt it half again as much.", "icon": "skull", "cursed": false, "pools": ["treasure", "boss", "secret"],
		"familiar": "carrion_bat"},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "desc": "", "icon": "skull", "cursed": false, "pools": []})
