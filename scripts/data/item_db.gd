class_name ItemDB
## Every item (the game calls them "keepsakes") and every combo.
##
## HOW TO EDIT
##  - "name" and "text" are the words players see. Change them freely.
##  - "icon" is (column, row) on the sprite sheet (see scripts/sprites.gd).
##  - "max" is how many times the item can be picked up (stacked).
##  - "mods" are the numbers. Each one reads [what, how, amount]:
##        "add" adds the amount once for every copy you hold.
##        "mul" adds that fraction for every copy: 0.15 means +15% each.
##    The "what" names are listed in scripts/player_stats.gd.
##  - A combo switches on by itself when you hold every item in "needs".

const COMMON := 0
const UNCOMMON := 1
const RARE := 2

const RARITY_NAMES := ["Common", "Uncommon", "Rare"]

const ITEMS := {
	# ------------------------------------------------------------------
	# LAMP - light and fire
	# ------------------------------------------------------------------
	"spare_wick": {
		"name": "Spare Wick",
		"text": "+15% fire rate.",
		"icon": Vector2i(3, 15), "rarity": COMMON, "max": 5, "family": "lamp",
		"mods": [["fire_rate", "mul", 0.15]],
	},
	"lamp_oil": {
		"name": "Lamp Oil",
		"text": "+20% damage.",
		"icon": Vector2i(46, 3), "rarity": COMMON, "max": 5, "family": "lamp",
		"mods": [["damage", "mul", 0.20]],
	},
	"burning_glass": {
		"name": "Burning Glass",
		"text": "Shots pass through 1 more enemy and grow bigger.",
		"icon": Vector2i(37, 2), "rarity": UNCOMMON, "max": 3, "family": "lamp",
		"mods": [["pierce", "add", 1], ["shot_size", "mul", 0.15]],
	},
	"storm_lantern": {
		"name": "Storm Lantern",
		"text": "Shots set enemies alight.",
		"icon": Vector2i(44, 4), "rarity": UNCOMMON, "max": 3, "family": "lamp",
		"mods": [["burn_dps", "add", 6.0]],
	},
	"twin_lens": {
		"name": "Twin Lens",
		"text": "Fire 1 more shot at a time. Each shot is 10% weaker.",
		"icon": Vector2i(38, 2), "rarity": RARE, "max": 3, "family": "lamp",
		"mods": [["shot_count", "add", 1], ["damage", "mul", -0.10]],
	},
	"mirror_shard": {
		"name": "Mirror Shard",
		"text": "Shots bounce off walls 1 more time and fly longer.",
		"icon": Vector2i(33, 10), "rarity": COMMON, "max": 3, "family": "lamp",
		"mods": [["bounce", "add", 1], ["shot_life", "mul", 0.15]],
	},
	"signal_flare": {
		"name": "Signal Flare",
		"text": "Every few shots you fire a flare that explodes.",
		"icon": Vector2i(32, 21), "rarity": UNCOMMON, "max": 3, "family": "lamp",
		"mods": [["flare", "add", 1]],
	},
	"prism": {
		"name": "Prism",
		"text": "Shots break into shards when they hit.",
		"icon": Vector2i(34, 10), "rarity": RARE, "max": 3, "family": "lamp",
		"mods": [["split", "add", 1]],
	},
	"beacon": {
		"name": "Beacon",
		"text": "A beam of light sweeps around you, burning what it touches.",
		"icon": Vector2i(43, 20), "rarity": RARE, "max": 3, "family": "lamp",
		"mods": [["beacon", "add", 1]],
	},
	"lamp_moths": {
		"name": "Lamp Moths",
		"text": "A moth circles you and darts out to bite enemies that come near.",
		"icon": Vector2i(31, 5), "rarity": UNCOMMON, "max": 4, "family": "lamp",
		"mods": [["moths", "add", 1]],
	},

	# ------------------------------------------------------------------
	# SEA - salt, cold and storm
	# ------------------------------------------------------------------
	"brine_jar": {
		"name": "Brine Jar",
		"text": "Shots soak enemies. Soaked enemies take +20% damage.",
		"icon": Vector2i(45, 4), "rarity": UNCOMMON, "max": 3, "family": "sea",
		"mods": [["brine", "add", 0.20]],
	},
	"cold_draught": {
		"name": "Cold Draught",
		"text": "Shots chill enemies and slow them down.",
		"icon": Vector2i(36, 11), "rarity": COMMON, "max": 3, "family": "sea",
		"mods": [["chill", "add", 0.20]],
	},
	"fishing_line": {
		"name": "Fishing Line",
		"text": "Shots jump to 1 more enemy nearby.",
		"icon": Vector2i(42, 3), "rarity": UNCOMMON, "max": 3, "family": "sea",
		"mods": [["chain", "add", 1]],
	},
	"barbed_hook": {
		"name": "Barbed Hook",
		"text": "+12% chance for a shot to deal double damage.",
		"icon": Vector2i(12, 13), "rarity": COMMON, "max": 4, "family": "sea",
		"mods": [["crit_chance", "add", 0.12]],
	},
	"lead_sinker": {
		"name": "Lead Sinker",
		"text": "+30% damage and a harder shove, but slower shots.",
		"icon": Vector2i(20, 5), "rarity": COMMON, "max": 3, "family": "sea",
		"mods": [["damage", "mul", 0.30], ["knockback", "mul", 0.50], ["shot_speed", "mul", -0.10]],
	},
	"storm_glass": {
		"name": "Storm Glass",
		"text": "Every few hits, lightning strikes and arcs to others.",
		"icon": Vector2i(40, 12), "rarity": RARE, "max": 3, "family": "sea",
		"mods": [["shock", "add", 1]],
	},
	"brass_compass": {
		"name": "Brass Compass",
		"text": "Shots curve toward enemies.",
		"icon": Vector2i(41, 3), "rarity": UNCOMMON, "max": 3, "family": "sea",
		"mods": [["homing", "add", 2.2]],
	},
	"gull_feather": {
		"name": "Gull Feather",
		"text": "+20% shot speed and reach.",
		"icon": Vector2i(29, 11), "rarity": COMMON, "max": 3, "family": "sea",
		"mods": [["shot_speed", "mul", 0.20], ["shot_life", "mul", 0.05]],
	},

	# ------------------------------------------------------------------
	# KEEPER - body, coat and boots
	# ------------------------------------------------------------------
	"driftwood_charm": {
		"name": "Driftwood Charm",
		"text": "+1 heart, and heal 1 heart now.",
		"icon": Vector2i(43, 7), "rarity": COMMON, "max": 5, "family": "keeper",
		"mods": [["max_hp_bonus", "add", 1]],
		"heal_on_pick": 1,
	},
	"oilskin_coat": {
		"name": "Oilskin Coat",
		"text": "Shrug off the first hit in every room.",
		"icon": Vector2i(37, 1), "rarity": RARE, "max": 2, "family": "keeper",
		"mods": [["room_shields", "add", 1]],
	},
	"sea_boots": {
		"name": "Sea Boots",
		"text": "+10% walking speed.",
		"icon": Vector2i(39, 0), "rarity": COMMON, "max": 3, "family": "keeper",
		"mods": [["move_speed", "mul", 0.10]],
	},
	"rope_coil": {
		"name": "Rope Coil",
		"text": "Hold 1 more dash.",
		"icon": Vector2i(11, 14), "rarity": UNCOMMON, "max": 2, "family": "keeper",
		"mods": [["dash_charges", "add", 1]],
	},
	"foghorn": {
		"name": "Foghorn",
		"text": "Dashing blasts enemies back and wipes out nearby shots.",
		"icon": Vector2i(12, 10), "rarity": UNCOMMON, "max": 3, "family": "keeper",
		"mods": [["foghorn", "add", 1]],
	},
	"tin_kettle": {
		"name": "Tin Kettle",
		"text": "At 2 hearts or fewer: +40% fire rate.",
		"icon": Vector2i(46, 4), "rarity": COMMON, "max": 2, "family": "keeper",
		"mods": [["kettle", "add", 1]],
	},
	"keepers_log": {
		"name": "Keeper's Log",
		"text": "+5% damage for each room in a row cleared without a scratch.",
		"icon": Vector2i(46, 5), "rarity": UNCOMMON, "max": 2, "family": "keeper",
		"mods": [["logbook", "add", 1]],
	},
	"tide_table": {
		"name": "Tide Table",
		"text": "Heal 1 heart every 3 rooms. A second copy makes it every 2.",
		"icon": Vector2i(33, 15), "rarity": UNCOMMON, "max": 2, "family": "keeper",
		"mods": [["tide", "add", 1]],
	},

	# ------------------------------------------------------------------
	# ECHO - your ghost from the room before
	# ------------------------------------------------------------------
	"tuning_fork": {
		"name": "Tuning Fork",
		"text": "Your echo hits 25% harder.",
		"icon": Vector2i(5, 15), "rarity": UNCOMMON, "max": 3, "family": "echo",
		"mods": [["echo_damage", "add", 0.25]],
	},
	"old_conch": {
		"name": "Old Conch",
		"text": "A second echo joins you, from the room before last.",
		"icon": Vector2i(32, 20), "rarity": RARE, "max": 2, "family": "echo",
		"mods": [["echo_count", "add", 1]],
	},
	"bell_buoy": {
		"name": "Bell Buoy",
		"text": "Unison is easier to reach and also gives +20% damage.",
		"icon": Vector2i(47, 2), "rarity": UNCOMMON, "max": 3, "family": "echo",
		"mods": [["unison_damage", "add", 0.20], ["unison_radius", "add", 6.0]],
	},
	"painted_buoy": {
		"name": "Painted Buoy",
		"text": "Some enemies chase your echo instead of you.",
		"icon": Vector2i(15, 12), "rarity": UNCOMMON, "max": 2, "family": "echo",
		"mods": [["echo_taunt", "add", 0.30]],
	},
	"breakwater": {
		"name": "Breakwater",
		"text": "Enemy shots break against your echo.",
		"icon": Vector2i(37, 3), "rarity": RARE, "max": 1, "family": "echo",
		"mods": [["echo_blocks", "add", 1]],
	},
	"metronome": {
		"name": "Metronome",
		"text": "Your echo takes aim by itself.",
		"icon": Vector2i(39, 16), "rarity": RARE, "max": 1, "family": "echo",
		"mods": [["echo_autoaim", "add", 1]],
	},
	"afterglow": {
		"name": "Afterglow",
		"text": "When you and your echo hit the same enemy, it bursts.",
		"icon": Vector2i(28, 12), "rarity": UNCOMMON, "max": 3, "family": "echo",
		"mods": [["resonance", "add", 1]],
	},
}

## Things offered beside items that are used up at once instead of kept.
const TREATS := {
	"hot_supper": {
		"name": "Hot Supper",
		"text": "Heal 2 hearts.",
		"icon": Vector2i(34, 19), "heal": 2,
	},
}

const COMBOS := {
	"salt_fire": {
		"name": "Salt Fire",
		"needs": ["storm_lantern", "brine_jar"],
		"text": "Soaked enemies that die on fire explode.",
		"mods": [["salt_fire", "add", 1]],
	},
	"black_ice": {
		"name": "Black Ice",
		"needs": ["cold_draught", "storm_glass"],
		"text": "Lightning freezes chilled enemies solid.",
		"mods": [["black_ice", "add", 1]],
	},
	"trotline": {
		"name": "Trotline",
		"needs": ["fishing_line", "barbed_hook"],
		"text": "Double-damage shots jump to 2 extra enemies.",
		"mods": [["trotline", "add", 1]],
	},
	"hall_of_mirrors": {
		"name": "Hall of Mirrors",
		"needs": ["mirror_shard", "burning_glass"],
		"text": "Every bounce makes a shot hit 30% harder.",
		"mods": [["hall_of_mirrors", "add", 1]],
	},
	"kaleidoscope": {
		"name": "Kaleidoscope",
		"needs": ["twin_lens", "prism"],
		"text": "Shards break into shards again.",
		"mods": [["kaleidoscope", "add", 1]],
	},
	"powder_keg": {
		"name": "Powder Keg",
		"needs": ["signal_flare", "lamp_oil"],
		"text": "Flares blast wider and set enemies alight.",
		"mods": [["powder_keg", "add", 1]],
	},
	"two_tone": {
		"name": "Two-Tone",
		"needs": ["foghorn", "rope_coil"],
		"text": "Every second foghorn blast is huge and stuns.",
		"mods": [["two_tone", "add", 1]],
	},
	"standing_wave": {
		"name": "Standing Wave",
		"needs": ["tuning_fork", "bell_buoy"],
		"text": "In Unison, your echo's shots pass through enemies and hit 50% harder.",
		"mods": [["standing_wave", "add", 1]],
	},
	"choir": {
		"name": "Choir",
		"needs": ["old_conch", "afterglow"],
		"text": "Afterglow bursts are twice as wide.",
		"mods": [["choir", "add", 1]],
	},
	"true_north": {
		"name": "True North",
		"needs": ["brass_compass", "fishing_line"],
		"text": "Jumping shots reach farther and jump once more.",
		"mods": [["true_north", "add", 1], ["chain", "add", 1]],
	},
	"moths_to_flame": {
		"name": "Moths to a Flame",
		"needs": ["lamp_moths", "storm_lantern"],
		"text": "Moths fly faster and set enemies alight.",
		"mods": [["moths_to_flame", "add", 1]],
	},
	"squall": {
		"name": "Squall",
		"needs": ["oilskin_coat", "foghorn"],
		"text": "When your coat blocks a hit, the foghorn goes off.",
		"mods": [["squall", "add", 1]],
	},
	"slingstone": {
		"name": "Slingstone",
		"needs": ["lead_sinker", "gull_feather"],
		"text": "Shots hit up to 40% harder the farther they fly.",
		"mods": [["slingstone", "add", 1]],
	},
	"twin_lights": {
		"name": "Twin Lights",
		"needs": ["beacon", "tuning_fork"],
		"text": "Your echo carries a beacon too.",
		"mods": [["twin_lights", "add", 1]],
	},
}

## How often each rarity shows up: [common, uncommon, rare].
const WEIGHTS_NORMAL := [60.0, 30.0, 10.0]
const WEIGHTS_BOSS := [15.0, 45.0, 40.0]


static func get_item(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	return TREATS.get(id, {})


static func is_treat(id: String) -> bool:
	return TREATS.has(id)


## The combos that are switched on by a set of held items.
static func active_combos(held: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for combo_id: String in COMBOS:
		var ok := true
		for need: String in COMBOS[combo_id]["needs"]:
			if int(held.get(need, 0)) <= 0:
				ok = false
				break
		if ok:
			out.append(combo_id)
	return out


## Combos that picking this item would complete right now.
static func combos_completed_by(id: String, held: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(held.get(id, 0)) > 0:
		return out
	for combo_id: String in COMBOS:
		var needs: Array = COMBOS[combo_id]["needs"]
		if not needs.has(id):
			continue
		var ok := true
		for need: String in needs:
			if need != id and int(held.get(need, 0)) <= 0:
				ok = false
				break
		if ok:
			out.append(combo_id)
	return out


## Combos this item is part of (used for hints).
static func combos_with(id: String) -> Array[String]:
	var out: Array[String] = []
	for combo_id: String in COMBOS:
		if (COMBOS[combo_id]["needs"] as Array).has(id):
			out.append(combo_id)
	return out


## Picks the items offered after a room. Never offers the same item twice,
## never offers an item you already hold the maximum of.
static func roll_offers(rng: RandomNumberGenerator, held: Dictionary, count: int, boss: bool, hp: int, max_hp: int) -> Array[String]:
	var weights: Array = WEIGHTS_BOSS if boss else WEIGHTS_NORMAL
	var pool: Array[String] = []
	var pool_weights: Array[float] = []
	for id: String in ITEMS:
		var item: Dictionary = ITEMS[id]
		if int(held.get(id, 0)) >= int(item["max"]):
			continue
		var w: float = weights[int(item["rarity"])]
		# Nudge the odds toward items that finish a combo or stack what you hold.
		if not combos_completed_by(id, held).is_empty():
			w *= 1.6
		elif int(held.get(id, 0)) > 0:
			w *= 1.15
		pool.append(id)
		pool_weights.append(w)

	var offers: Array[String] = []
	while offers.size() < count and not pool.is_empty():
		var total := 0.0
		for w: float in pool_weights:
			total += w
		var roll := rng.randf() * total
		var pick := pool.size() - 1
		for i in pool.size():
			roll -= pool_weights[i]
			if roll <= 0.0:
				pick = i
				break
		offers.append(pool[pick])
		pool.remove_at(pick)
		pool_weights.remove_at(pick)

	# When hurt, one of the choices may be a meal instead of an item.
	if not boss and offers.size() >= 2:
		var missing := max_hp - hp
		var chance := 0.0
		if hp <= 1:
			chance = 0.85
		elif missing >= 3:
			chance = 0.5
		elif missing >= 1:
			chance = 0.25
		if rng.randf() < chance:
			offers[offers.size() - 1] = "hot_supper"
	return offers
