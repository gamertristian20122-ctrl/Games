extends RefCounted
## Items: every passive item in the game. Use with:  const Items = preload("res://scripts/data/items.gd")
## THE HERO SWINGS A SWORD NOW (v0.5+). The words in "desc" are written for the sword; what each stat
## and flag below does for a sword is listed above _swing() in scripts/entities/player.gd. The names
## and pictures are relics he carries (a bow string wound round the hilt, a hatchet charm ...).
## "needs_curse": true marks the 13 items that only did something with the Hungry Curse (switched
## off, see G.curse_on()): they are never offered and are hidden in the Collection.
## "cursed" items are RISKY items now: strong, with a price (the "curse" line). No Curse grows.
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
## TO ADD AN ITEM: add a row here and a row in tools/import_icons.py (its picture), then run that tool.
## ICONS: every item has its own picture icon_<item id> in assets/art/icons/, copied from the
## "Raven Fantasy Icons" pack by tools/import_icons.py (the table of which picture is at its top).
## Statuses (chill, freeze, burn) are in scripts/entities/status.gd; helpers in scripts/data/familiars.gd.

const ALL := {
	# ---------------------------------------------------------------- plain stat items
	"whetstone": {"name": "Whetstone", "desc": "A sharper edge: every blow hits harder.", "icon": "icon_whetstone", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"flat": {"damage": 1.0}}},
	"swift_tonic": {"name": "Swift Tonic", "desc": "Move faster.", "icon": "icon_swift_tonic", "cursed": false, "pools": ["treasure", "shop"],
		"mods": {"pct": {"speed": 0.18}}},
	"sparking_tonic": {"name": "Sparking Tonic", "desc": "Swing faster.", "icon": "icon_sparking_tonic", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"pct": {"rate": 0.30}}},
	"longbow_string": {"name": "Longbow String", "desc": "Wound round the hilt: longer reach and quicker swings.", "icon": "icon_longbow_string", "cursed": false, "pools": ["treasure", "shop"],
		"mods": {"pct": {"range": 0.35, "shot_speed": 0.25}}},
	"crimson_draught": {"name": "Crimson Draught", "desc": "One more heart, and it comes full.", "icon": "icon_crimson_draught", "cursed": false, "pools": ["treasure", "boss", "shop", "secret"],
		"give": {"max_hp": 2, "hp": 2}},
	# ---------------------------------------------------------------- shot changers
	"twin_hatchets": {"name": "Twin Hatchets", "desc": "Every swing cuts twice, each cut a little weaker.", "icon": "icon_twin_hatchets", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flat": {"shots": 1.0, "spread": 0.05}, "pct": {"damage": -0.25}}},
	"needle_spear": {"name": "Needle Spear", "desc": "Blows bite deeper into big monsters and bosses.", "icon": "icon_needle_spear", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"mods": {"flags": {"pierce": 1}, "pct": {"shot_speed": 0.10}}},
	"ricochet_mallet": {"name": "Ricochet Mallet", "desc": "The shock of a blow jumps on to two more monsters nearby.", "icon": "icon_ricochet_mallet", "cursed": false, "pools": ["treasure", "secret"],
		"mods": {"flags": {"bounce": 2}, "pct": {"range": 0.30}}},
	"seeker_staff": {"name": "Seeker Staff", "desc": "Every swing steps you toward the nearest monster.", "icon": "icon_seeker_staff", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flat": {"homing": 2.6}}},
	# ---------------------------------------------------------------- items with hooks (see item_effects.gd)
	"wardwater": {"name": "Wardwater", "desc": "A blue heart now, and half of one every third room you clear.", "icon": "icon_wardwater", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"give": {"armor": 2}},
	"grave_cleaver": {"name": "Grave Cleaver", "desc": "Slain enemies burst into bone shards that hurt others.", "icon": "icon_grave_cleaver", "cursed": false, "pools": ["treasure", "boss", "secret"]},
	# ---------------------------------------------------------------- cursed: stronger, with a price
	"glass_blade": {"name": "Glass Blade", "desc": "Damage doubled.", "curse": "You take double damage.", "icon": "icon_glass_blade", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"damage": 2.0, "hurt_mult": 2.0}}},
	"frenzy_saw": {"name": "Frenzy Saw", "desc": "Swing almost twice as fast.", "curse": "Your reach is shorter.", "icon": "icon_frenzy_saw", "cursed": true, "pools": ["cursed"],
		"mods": {"pct": {"rate": 0.85, "range": -0.25}, "flat": {"spread": 0.30}}},
	"gilded_blade": {"name": "Gilded Blade", "desc": "Every coin you carry adds damage.", "curse": "Getting hit knocks 5 coins out of your purse.", "icon": "icon_gilded_blade", "cursed": true, "pools": ["cursed"]},
	"leaden_maul": {"name": "Leaden Maul", "desc": "Damage nearly doubled.", "curse": "You walk slower.", "icon": "icon_leaden_maul", "cursed": true, "pools": ["cursed"],
		"mods": {"pct": {"damage": 0.80, "speed": -0.20}}},
	"storm_axes": {"name": "Storm Axes", "desc": "Every swing cuts three times.", "curse": "Your reach is shorter.", "icon": "icon_storm_axes", "cursed": true, "pools": ["cursed"],
		"mods": {"flat": {"shots": 2.0, "spread": 0.35}, "pct": {"range": -0.20}}},
	"misers_flask": {"name": "Miser's Flask", "desc": "Every coin counts double.", "curse": "Half as long to recover after a hit.", "icon": "icon_misers_flask", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"coin_mult": 2.0, "invuln": 0.5}}},
	"hollow_bolt": {"name": "Hollow Bolt", "desc": "Much longer reach, and blows bite deeper into big monsters.", "curse": "You swing slower.", "icon": "icon_hollow_bolt", "cursed": true, "pools": ["cursed"],
		"mods": {"flags": {"pierce": 2}, "pct": {"range": 0.40, "rate": -0.25}}},
	"gilded_fang": {"name": "Gilded Fang", "needs_curse": true, "desc": "A bombed Curse coughs up double.", "curse": "Your Curse also eats coins lying on the floor.", "icon": "icon_gilded_fang", "cursed": true, "pools": ["cursed"], "locked": true,
		"mods": {"mult": {"belly_mult": 2.0}, "flags": {"curse_eats_coins": 1}}},
	# ---------------------------------------------------------------- items that handle the Hungry Curse (not cursed)
	"spiked_goad": {"name": "Spiked Goad", "needs_curse": true, "desc": "CALL is ready again much sooner.", "icon": "icon_spiked_goad", "cursed": false, "pools": ["treasure", "shop", "secret"], "locked": true,
		"mods": {"flat": {"call_cooldown": -1.5}}},
	"iron_leash": {"name": "Iron Leash", "needs_curse": true, "desc": "Your Curse creeps slower.", "icon": "icon_iron_leash", "cursed": false, "pools": ["treasure", "shop", "boss"], "locked": true,
		"mods": {"mult": {"curse_creep": 0.73}}},
	"tithe_imp": {"name": "Tithe Bat", "needs_curse": true, "desc": "A little bat. After each meal it fetches you a coin from the Curse's belly.", "icon": "icon_tithe_imp", "cursed": false, "pools": ["treasure", "shop", "secret"], "locked": true,
		"familiar": "tithe_imp"},
	# ================================================================ THE SECOND BATCH (25 items)
	# ---------------------------------------------------------------- shots that behave differently
	"bone_thistle": {"name": "Bone Thistle", "desc": "Each swing throws three bone splinters from the tip of the blade.", "icon": "icon_bone_thistle", "cursed": false, "pools": ["treasure", "secret"]},
	"tethered_sickle": {"name": "Tethered Sickle", "desc": "Every swing cuts again on the way back.", "icon": "icon_tethered_sickle", "cursed": false, "pools": ["treasure", "boss"],
		"mods": {"flags": {"return": 1}}},
	"stonebiter": {"name": "Stonebiter", "desc": "A blow jumps on to one more monster, harder with every jump.", "icon": "icon_stonebiter", "cursed": false, "pools": ["treasure", "secret"],
		"mods": {"flags": {"bounce": 1, "bounce_grow": 1}}},
	"reaping_hook": {"name": "Reaping Hook", "desc": "A killing blow swings again at once, harder each time.", "icon": "icon_reaping_hook", "cursed": false, "pools": ["treasure", "boss"], "locked": true,
		"mods": {"flags": {"reap": 1}}},
	"starveling_blade": {"name": "Starveling Blade", "desc": "Every enemy shot you cut down makes your next blow hit harder.", "icon": "icon_starveling_blade", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"mods": {"flags": {"eat_shots": 1}}},
	"winter_nail": {"name": "Winter Nail", "desc": "Hits chill monsters. The third hit freezes one solid.", "icon": "icon_winter_nail", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"eclipse_shard": {"name": "Eclipse Shard", "needs_curse": true, "desc": "Shots that fly through your Curse hit twice as hard.", "curse": "Your shots no longer slow it.", "icon": "icon_eclipse_shard", "cursed": true, "pools": ["cursed"],
		"mods": {"flags": {"eclipse": 1}}},
	"breaking_wheel": {"name": "Breaking Wheel", "desc": "Every swing spins all the way round you.", "curse": "Spinning blows land softer.", "icon": "icon_breaking_wheel", "cursed": true, "pools": ["cursed"],
		"mods": {"flat": {"shots": 4.0}, "flags": {"ring": 1}}},
	"barrow_stone": {"name": "Barrow Stone", "desc": "A huge blade: longer reach, harder hits, and it shoves monsters back.", "curse": "It is slow to swing.", "icon": "icon_barrow_stone", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"shot_size": 2.0, "shot_speed": 0.5}, "pct": {"damage": 0.6, "knockback": 1.0}}},
	"pyre_kindling": {"name": "Pyre Kindling", "desc": "Blows set monsters alight. Fire leaps to monsters that touch.", "curse": "Burning monsters run faster.", "icon": "icon_pyre_kindling", "cursed": true, "pools": ["cursed"]},
	# ---------------------------------------------------------------- more ways to play with the Hungry Curse
	"moth_mantle": {"name": "Moth Mantle", "needs_curse": true, "desc": "Fire much faster while you stand close to your Curse.", "curse": "You fire slower when you are far from it.", "icon": "icon_moth_mantle", "cursed": true, "pools": ["cursed"]},
	"ossuary_chain": {"name": "Ossuary Chain", "needs_curse": true, "desc": "Bigger, harder shots for every Curse Level.", "curse": "It raises your Curse by two Levels, not one.", "icon": "icon_ossuary_chain", "cursed": true, "pools": ["cursed"], "locked": true},
	"howling_scar": {"name": "Howling Scar", "needs_curse": true, "desc": "When your Curse bites you, every monster in the room is blasted.", "curse": "Your Curse creeps faster.", "icon": "icon_howling_scar", "cursed": true, "pools": ["cursed"],
		"mods": {"mult": {"curse_creep": 1.3}}},
	"oxbone_cudgel": {"name": "Oxbone Cudgel", "needs_curse": true, "desc": "Your shots shove your Curse the way they fly.", "icon": "icon_oxbone_cudgel", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"mods": {"flags": {"curse_shove": 1}}},
	"cry_of_knives": {"name": "Cry of Knives", "needs_curse": true, "desc": "CALL also throws a ring of your shots.", "icon": "icon_cry_of_knives", "cursed": false, "pools": ["treasure", "boss", "shop"], "locked": true},
	"bitter_marrow": {"name": "Bitter Marrow", "needs_curse": true, "desc": "A bite makes your Curse cough up its whole belly.", "icon": "icon_bitter_marrow", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"sour_gullet": {"name": "Sour Gullet", "needs_curse": true, "desc": "Your Curse spits swallowed shots back at monsters.", "icon": "icon_sour_gullet", "cursed": false, "pools": ["treasure", "boss", "shop"]},
	"fasting_vow": {"name": "Fasting Vow", "needs_curse": true, "desc": "No bites on a floor: your Curse drops a Level.", "icon": "icon_fasting_vow", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"text": {"broken": "Vow broken", "kept": "Vow kept"}},
	# ---------------------------------------------------------------- staying alive, coins, helpers
	"ransom_plate": {"name": "Ransom Plate", "desc": "A hit costs you 8 coins instead of health, while you can pay.", "icon": "icon_ransom_plate", "cursed": false, "pools": ["treasure", "secret", "boss"],
		"mods": {"flags": {"coin_ward": 8}}},
	"sextons_satchel": {"name": "Sexton's Satchel", "desc": "Start every level with at least 2 bombs and a key.", "icon": "icon_sextons_satchel", "cursed": false, "pools": ["treasure", "shop", "secret"],
		"give": {"bombs": 1, "keys": 1}},
	"sinners_locket": {"name": "Sinner's Locket", "desc": "One more heart, empty. Taking a risky item heals you to full.", "icon": "icon_sinners_locket", "cursed": false, "pools": ["treasure", "boss", "shop", "secret"],
		"give": {"max_hp": 2}},
	"undertakers_due": {"name": "Undertaker's Due", "desc": "The last monster you slay in each room always drops something.", "icon": "icon_undertakers_due", "cursed": false, "pools": ["treasure", "shop", "secret"]},
	"knocker_bat": {"name": "Knocker Bat", "desc": "It flutters at any wall that hides a secret door.", "icon": "icon_knocker_bat", "cursed": false, "pools": ["treasure", "shop", "boss"], "locked": true,
		"familiar": "knocker_bat"},
	"blood_porter": {"name": "Blood Porter", "desc": "Feeds you a spare heart when you bleed, and keeps hearts you cannot hold.", "icon": "icon_blood_porter", "cursed": false, "pools": ["treasure", "shop", "boss"],
		"familiar": "blood_porter"},
	"carrion_bat": {"name": "Carrion Bat", "desc": "Sits on the toughest monster. Your blows hurt it half again as much.", "icon": "icon_carrion_bat", "cursed": false, "pools": ["treasure", "boss", "secret"],
		"familiar": "carrion_bat"},
}


static func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "desc": "", "icon": "skull", "cursed": false, "pools": []})


## The item ids the game shows and offers: without the ones that needed the Hungry Curse while it is off.
static func ids() -> Array:
	var out: Array = []
	for id: String in ALL:
		if G.curse_on() or not bool(ALL[id].get("needs_curse", false)):
			out.append(id)
	return out
