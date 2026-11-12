extends RefCounted
## Gear: helmets, armour and rings the knight wears (RPG step 2, v0.12.0; the owner asked for
## "armour, helmets, rings, weapons with stats, an inventory screen" and for gear to come from
## monster drops, chests and bosses, and shops, in Common / Rare / Epic).
## Weapons stay in scripts/data/weapons.gd; the Gear page of the Knight screen shows both.
##
## A piece is FOUND ONCE and then owned for ever (save's hub section, "gear:<id>" = 1). One piece
## per slot is worn ("worn:<slot>" = its place in LIST + 1, 0 = nothing). Dying loses nothing.
## Finding a piece he already owns pays its "sell" value in coins instead.
##
## A row:
##   "slot"    helmet | armour | ring         "rarity"  0 Common, 1 Rare, 2 Epic
##   "icon"    a picture in assets/art/icons (tools/import_icons.py EXTRA; Raven Fantasy Icons)
##   "tier"    the first part of the world it turns up in: 0 Crypt and Elfwood, 1 the road, the
##             sands and the Warrens, 2 the mountains and the Ashen Halls, 3 the Archive and the Pit
##   "price"   coins at a smith (only pieces of the camp's tier or lower are on his shelf)
##   What it does (any mix; text() turns it into words):
##   "hp"      half hearts of health            "shield"  blue half hearts at the start of every level
##   "ward"    chance that a blow glances off and does nothing (0.08 = 8%; all worn pieces add up,
##             never over WARD_CAP). Hits are whole half hearts, so "less damage" would do nothing.
##   "mods"    stat changes in the form scripts/run/stats.gd takes (damage, rate, speed, coin_mult, luck)
##   "xp"      more XP from every kill (0.15 = 15%)
##   "guard"   the block's rest gets this much shorter (0.2 = 20%)
## Every number is a first guess. Names and words are placeholders the owner may rewrite.

const SLOTS := [
	{"id": "helmet", "name": "Helmet"},
	{"id": "armour", "name": "Armour"},
	{"id": "ring", "name": "Ring"},
]
const RARITY := [
	{"name": "Common", "color": Color("fdf7ed"), "sell": 4},
	{"name": "Rare", "color": Color("5aa7d9"), "sell": 10},
	{"name": "Epic", "color": Color("c77dff"), "sell": 22},
]
const WARD_CAP := 0.5

const LIST := [
	# ---- helmets
	{"id": "cap_iron", "slot": "helmet", "name": "Iron Cap", "rarity": 0, "icon": "gear_cap_iron", "tier": 0, "price": 20, "hp": 2},
	{"id": "helm_soldier", "slot": "helmet", "name": "Soldier's Helm", "rarity": 0, "icon": "gear_helm_soldier", "tier": 0, "price": 25, "ward": 0.08},
	{"id": "helm_bronze", "slot": "helmet", "name": "Bronze Helm", "rarity": 0, "icon": "gear_helm_bronze", "tier": 1, "price": 35, "hp": 1, "ward": 0.06},
	{"id": "helm_warden", "slot": "helmet", "name": "Warden's Helm", "rarity": 1, "icon": "gear_helm_warden", "tier": 0, "price": 60, "hp": 2, "ward": 0.08},
	{"id": "helm_visor", "slot": "helmet", "name": "Visored Helm", "rarity": 1, "icon": "gear_helm_visor", "tier": 1, "price": 75, "ward": 0.16},
	{"id": "helm_ember", "slot": "helmet", "name": "Ember Helm", "rarity": 1, "icon": "gear_helm_ember", "tier": 2, "price": 90, "hp": 2, "mods": {"pct": {"damage": 0.12}}},
	{"id": "helm_gilded", "slot": "helmet", "name": "Gilded Helm", "rarity": 2, "icon": "gear_helm_gilded", "tier": 2, "hp": 4, "ward": 0.12, "mods": {"pct": {"coin_mult": 0.15}}},
	# ---- armour
	{"id": "vest_padded", "slot": "armour", "name": "Padded Vest", "rarity": 0, "icon": "gear_vest_padded", "tier": 0, "price": 20, "hp": 2},
	{"id": "plate_steel", "slot": "armour", "name": "Steel Breastplate", "rarity": 0, "icon": "gear_plate_steel", "tier": 0, "price": 30, "ward": 0.10},
	{"id": "plate_bronze", "slot": "armour", "name": "Bronze Breastplate", "rarity": 0, "icon": "gear_plate_bronze", "tier": 1, "price": 40, "hp": 2, "ward": 0.06},
	{"id": "mail_chain", "slot": "armour", "name": "Chain Harness", "rarity": 1, "icon": "gear_mail_chain", "tier": 0, "price": 65, "hp": 4},
	{"id": "plate_warden", "slot": "armour", "name": "Warden's Plate", "rarity": 1, "icon": "gear_plate_warden", "tier": 1, "price": 85, "hp": 2, "ward": 0.12},
	{"id": "plate_ember", "slot": "armour", "name": "Ember Plate", "rarity": 1, "icon": "gear_plate_ember", "tier": 2, "price": 100, "hp": 2, "shield": 2, "mods": {"pct": {"damage": 0.10}}},
	{"id": "plate_gilded", "slot": "armour", "name": "Gilded Plate", "rarity": 2, "icon": "gear_plate_gilded", "tier": 2, "hp": 6, "ward": 0.10},
	{"id": "plate_knight", "slot": "armour", "name": "Plate of the Last Order", "rarity": 2, "icon": "gear_plate_knight", "tier": 3, "hp": 2, "ward": 0.22, "shield": 2},
	# ---- rings
	{"id": "ring_iron", "slot": "ring", "name": "Iron Ring", "rarity": 0, "icon": "gear_ring_iron", "tier": 0, "price": 20, "mods": {"pct": {"damage": 0.06}}},
	{"id": "ring_silver", "slot": "ring", "name": "Silver Band", "rarity": 0, "icon": "gear_ring_silver", "tier": 0, "price": 20, "mods": {"pct": {"rate": 0.06}}},
	{"id": "ring_gold", "slot": "ring", "name": "Gold Band", "rarity": 0, "icon": "gear_ring_gold", "tier": 1, "price": 30, "mods": {"pct": {"coin_mult": 0.20}}},
	{"id": "ring_ruby", "slot": "ring", "name": "Ruby Ring", "rarity": 1, "icon": "gear_ring_ruby", "tier": 0, "price": 70, "mods": {"pct": {"damage": 0.14}}},
	{"id": "ring_emerald", "slot": "ring", "name": "Emerald Ring", "rarity": 1, "icon": "gear_ring_emerald", "tier": 1, "price": 70, "mods": {"pct": {"speed": 0.10}, "flat": {"luck": 1.0}}},
	{"id": "ring_sapphire", "slot": "ring", "name": "Sapphire Ring", "rarity": 1, "icon": "gear_ring_sapphire", "tier": 1, "price": 80, "xp": 0.15},
	{"id": "ring_jade", "slot": "ring", "name": "Ring of the Glade", "rarity": 2, "icon": "gear_ring_jade", "tier": 1, "mods": {"pct": {"damage": 0.12, "rate": 0.12}}},
	{"id": "ring_ember", "slot": "ring", "name": "Ember Signet", "rarity": 2, "icon": "gear_ring_ember", "tier": 3, "guard": 0.20, "mods": {"pct": {"damage": 0.20}}},
]

## Which pieces a camp's smith has on his shelf: pieces of this tier or lower (the village is 0).
const CAMP_TIER := {"dustwatch": 1, "emberfall": 2}
const SHELF_SIZE := 3              ## the cheapest few he shows at a time

## How often gear turns up (scripts/entities/enemy.gd, chest.gd, scripts/run/run.gd).
const DROP_MONSTER := 0.012        ## a normal monster
const DROP_ELITE := 0.10           ## an elite (gold ring)
const DROP_CHEST := 0.12           ## a chest       (a rich chest: DROP_CHEST_RICH)
const DROP_CHEST_RICH := 0.35
const RARE_ODDS := 0.22            ## a monster's or chest's piece is Rare this often (else Common)
const BOSS_EPIC_ODDS := 0.4        ## a boss always gives a piece: Epic this often, else Rare


# ------------------------------------------------------------------ rows
static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if String(LIST[i]["id"]) == id:
			return i
	return -1


static func slot_name(slot: String) -> String:
	for s: Dictionary in SLOTS:
		if String(s["id"]) == slot:
			return String(s["name"])
	return slot


static func rarity_name(r: Dictionary) -> String:
	return String(RARITY[int(r.get("rarity", 0))]["name"])


static func color(r: Dictionary) -> Color:
	return RARITY[int(r.get("rarity", 0))]["color"]


static func sell_value(r: Dictionary) -> int:
	return int(RARITY[int(r.get("rarity", 0))]["sell"])


# ------------------------------------------------------------------ owning and wearing
static func owned(id: String) -> bool:
	return Save.hub_get("gear:" + id) > 0


static func owned_rows(slot: String = "") -> Array:
	var out: Array = []
	for r: Dictionary in LIST:
		if owned(String(r["id"])) and (slot == "" or String(r["slot"]) == slot):
			out.append(r)
	return out


## Hands the piece over. Returns true when it is new. A new piece is put on at once when its
## slot is empty, so the first helmet he finds is on his head without a visit to the menu.
static func grant(id: String) -> bool:
	var r := row(id)
	if r.is_empty() or owned(id):
		return false
	Save.hub_set("gear:" + id, 1)
	if worn(String(r["slot"])).is_empty():
		Save.hub_set("worn:" + String(r["slot"]), index_of(id) + 1)
	Save.flush()
	return true


## The piece worn in this slot ({} = nothing).
static func worn(slot: String) -> Dictionary:
	var i := Save.hub_get("worn:" + slot) - 1
	if i < 0 or i >= LIST.size() or String(LIST[i]["slot"]) != slot or not owned(String(LIST[i]["id"])):
		return {}
	return LIST[i]


static func is_worn(id: String) -> bool:
	var r := row(id)
	return not r.is_empty() and String(worn(String(r["slot"])).get("id", "")) == id


static func wear(id: String) -> bool:
	var r := row(id)
	if r.is_empty() or not owned(id):
		return false
	Save.hub_set("worn:" + String(r["slot"]), index_of(id) + 1)
	Save.flush()
	return true


static func take_off(slot: String) -> void:
	Save.hub_set("worn:" + slot, 0)
	Save.flush()


static func worn_rows() -> Array:
	var out: Array = []
	for s: Dictionary in SLOTS:
		var r := worn(String(s["id"]))
		if not r.is_empty():
			out.append(r)
	return out


# ------------------------------------------------------------------ what the worn pieces do
## Every worn piece's stat changes as one stats layer.
static func mods() -> Dictionary:
	var out := {}
	for r: Dictionary in worn_rows():
		var m: Dictionary = r.get("mods", {})
		for kind: String in m:
			if not out.has(kind):
				out[kind] = {}
			for key: String in m[kind]:
				out[kind][key] = float(out[kind].get(key, 0.0)) + float(m[kind][key])
	return out


static func _sum(key: String) -> float:
	var n := 0.0
	for r: Dictionary in worn_rows():
		n += float(r.get(key, 0.0))
	return n


static func bonus_hp() -> int:
	return int(_sum("hp"))


static func shield() -> int:
	return int(_sum("shield"))


## The chance that a blow glances off.
static func ward() -> float:
	return minf(_sum("ward"), WARD_CAP)


static func xp_mult() -> float:
	return 1.0 + _sum("xp")


## The block's rest is multiplied by this.
static func guard_mult() -> float:
	return maxf(1.0 - _sum("guard"), 0.4)


## What a piece does, in a few words: "+1 heart, 8% of blows glance off".
static func text(r: Dictionary) -> String:
	var bits: Array = []
	if r.has("hp"):
		bits.append("+%s" % _hearts(int(r["hp"])))
	if r.has("shield"):
		bits.append("%s each level" % _hearts(int(r["shield"]), "blue heart"))
	if r.has("ward"):
		bits.append("%d%% of blows glance off" % roundi(float(r["ward"]) * 100.0))
	var m: Dictionary = r.get("mods", {})
	var pct: Dictionary = m.get("pct", {})
	var words := {"damage": "damage", "rate": "swing speed", "speed": "walking speed", "coin_mult": "coins", "range": "reach"}
	for key: String in pct:
		bits.append("+%d%% %s" % [roundi(float(pct[key]) * 100.0), String(words.get(key, key))])
	var flat: Dictionary = m.get("flat", {})
	if flat.has("luck"):
		bits.append("better drops")
	if r.has("xp"):
		bits.append("+%d%% XP" % roundi(float(r["xp"]) * 100.0))
	if r.has("guard"):
		bits.append("guard back %d%% sooner" % roundi(float(r["guard"]) * 100.0))
	return ", ".join(bits)


## The same with a capital letter, for a line of its own.
static func text_cap(r: Dictionary) -> String:
	var t := text(r)
	return t.substr(0, 1).to_upper() + t.substr(1)


static func _hearts(half_hearts: int, word: String = "heart") -> String:
	if half_hearts == 1:
		return "half a " + word
	if half_hearts == 2:
		return "1 " + word
	if half_hearts % 2 == 0:
		@warning_ignore("integer_division")
		return "%d %ss" % [half_hearts / 2, word]
	return "%.1f %ss" % [half_hearts / 2.0, word]


# ------------------------------------------------------------------ finding
## A piece for a monster, a chest or a boss in a part of the world of this tier. It prefers a
## piece he does not own yet; "" when the tier has none of that rarity at all.
static func roll(tier: int, rarity: int, rng: RandomNumberGenerator = null) -> String:
	var fresh: Array = []
	var any: Array = []
	for r: Dictionary in LIST:
		if int(r["tier"]) > tier or int(r["rarity"]) != rarity:
			continue
		any.append(String(r["id"]))
		if not owned(String(r["id"])):
			fresh.append(String(r["id"]))
	var pool := fresh if not fresh.is_empty() else any
	if pool.is_empty():
		return ""
	return pool[(rng.randi() if rng != null else randi()) % pool.size()]


## What a monster or a chest leaves: mostly Common, sometimes Rare.
static func roll_common(tier: int, luck: float = 0.0) -> String:
	var rarity := 1 if randf() < RARE_ODDS + luck * 0.02 else 0
	var id := roll(tier, rarity)
	return id if id != "" else roll(tier, 0)


## What a boss or a champion leaves: Rare, sometimes Epic.
static func roll_boss(tier: int) -> String:
	var id := roll(tier, 2) if randf() < BOSS_EPIC_ODDS else ""
	if id == "" or owned(id):
		var rare := roll(tier, 1)
		if rare != "" and not owned(rare):
			return rare
	return id if id != "" else roll(tier, 1)


## The pieces on a smith's shelf: every piece with a price, of this camp's tier or lower, not owned yet.
static func shelf(tier: int) -> Array:
	var out: Array = []
	for r: Dictionary in LIST:
		if r.has("price") and int(r["tier"]) <= tier and not owned(String(r["id"])):
			out.append(r)
	return out


static func buy(id: String) -> bool:
	var r := row(id)
	var coins := Save.hub_get("bank:coins")
	if r.is_empty() or not r.has("price") or owned(id) or coins < int(r["price"]):
		return false
	Save.hub_set("bank:coins", coins - int(r["price"]))
	grant(id)
	return true
