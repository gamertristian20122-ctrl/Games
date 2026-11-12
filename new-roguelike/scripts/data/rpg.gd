extends RefCounted
## Rpg: the knight's LEVEL, his XP and the level-up cards (v0.11.0, the first RPG step).
## Use with:  const Rpg = preload("res://scripts/data/rpg.gd")
##
## How it works (the owner's answers of 12 Nov 2026: "1 and 3" = cards AND automatic growth + a skill point):
##   - Every monster killed gives XP (xp_of() below). Bosses and champions give a lot.
##   - A full XP bar = a new level. Each level gives THREE things:
##       1. he grows by himself  (GROW_DAMAGE harder blows per level, half a heart every GROW_HP_EVERY levels)
##       2. the player picks 1 of 3 cards (CARDS below)
##       3. one skill point (kept for the skills of the next RPG step)
##   - XP and levels are never lost, not even when he falls.
## Everything is kept in the save's hub section:
##   "rpg:lvl"   levels gained (0 = level 1)      "rpg:xp"   XP inside the current level
##   "rpg:sp"    skill points not spent yet        "rpg:picks" level-up cards still to choose
##   "card:<id>" how many times that card was taken
## All words and numbers here are placeholders the owner may rewrite.

const MAX_LEVEL := 30
const GROW_DAMAGE := 0.03        ## each level: blows hit this much harder (0.03 = 3%)
const GROW_HP_EVERY := 3         ## every this many levels: half a heart more
const LEVEL_HEAL := 2            ## half hearts mended at the moment of a level-up

## XP a monster is worth: its "cost" in scripts/data/enemies.gd x XP_PER_COST, more in later areas.
const XP_PER_COST := 2.0
const XP_PER_TIER := 0.3         ## +30% for each step of run.scale_floor (the Warrens = 1, the Ashen Halls = 2 ...)
const XP_ELITE := 2.5            ## a gold-ringed elite
const XP_CHAMPION := 10.0        ## the champion that ends a road or forest level
const XP_BOSS := 60.0            ## a boss, x (1 + XP_BOSS_TIER x scale_floor)
const XP_BOSS_TIER := 0.5

## The level-up cards. A card can be taken "max" times; once it is full it is no longer offered.
##   "mods"            stat changes PER PICK, in the form scripts/run/stats.gd takes (pct / flat)
##   "hp"              half hearts of health per pick         "block"   blows more the guard stops, per pick
##   "block_cooldown"  seconds on the guard's rest per pick (negative = sooner)
##   "xp"              more XP per pick (0.10 = 10%)          "icon"    a picture id from assets/art/icons
const CARDS := [
	{"id": "might", "name": "Might", "text": "Blows hit 8% harder.", "icon": "icon_whetstone", "max": 5,
		"mods": {"pct": {"damage": 0.08}}},
	{"id": "vigour", "name": "Vigour", "text": "One more heart.", "icon": "icon_crimson_draught", "max": 3, "hp": 2},
	{"id": "quick", "name": "Quick hands", "text": "Swing 6% faster.", "icon": "icon_swift_tonic", "max": 5,
		"mods": {"pct": {"rate": 0.06}}},
	{"id": "fleet", "name": "Fleet feet", "text": "Walk 5% faster.", "icon": "icon_moth_mantle", "max": 4,
		"mods": {"pct": {"speed": 0.05}}},
	{"id": "reach", "name": "Long arm", "text": "A little more reach.", "icon": "icon_needle_spear", "max": 3,
		"mods": {"pct": {"range": 0.12}}},
	{"id": "wall", "name": "Shield wall", "text": "Your guard stops one more blow.", "icon": "icon_ransom_plate", "max": 2, "block": 1},
	{"id": "ready", "name": "Ready arm", "text": "Your guard is whole half a second sooner.", "icon": "icon_wardwater", "max": 3,
		"block_cooldown": -0.5},
	{"id": "purse", "name": "Deep purse", "text": "Find 15% more coins.", "icon": "icon_misers_flask", "max": 3,
		"mods": {"pct": {"coin_mult": 0.15}}},
	{"id": "grit", "name": "Grit", "text": "Safe a little longer after a hit.", "icon": "icon_barrow_stone", "max": 3,
		"mods": {"flat": {"invuln": 0.2}}},
	{"id": "shove", "name": "Heavy hand", "text": "Blows shove monsters further back.", "icon": "icon_leaden_maul", "max": 3,
		"mods": {"pct": {"knockback": 0.2}}},
	{"id": "study", "name": "Quick study", "text": "Earn 10% more XP.", "icon": "icon_sinners_locket", "max": 3, "xp": 0.10},
	{"id": "luck", "name": "Lucky", "text": "Monsters drop a little more.", "icon": "icon_gilded_fang", "max": 3,
		"mods": {"flat": {"luck": 1.0}}},
]
## When every card is full, a level-up pays this many coins into the camp chest instead.
const FULL_COINS := 25


# ------------------------------------------------------------------ level and XP
static func level() -> int:
	return Save.hub_get("rpg:lvl") + 1


static func xp() -> int:
	return Save.hub_get("rpg:xp")


## XP needed to get from `lvl` to the next level.
static func xp_for(lvl: int) -> int:
	return 40 + 30 * (lvl - 1)


static func xp_need() -> int:
	return xp_for(level())


static func at_max() -> bool:
	return level() >= MAX_LEVEL


static func skill_points() -> int:
	return Save.hub_get("rpg:sp")


## Level-up cards the player has not chosen yet.
static func picks() -> int:
	return Save.hub_get("rpg:picks")


static func xp_mult() -> float:
	return 1.0 + float(row("study").get("xp", 0.0)) * taken("study")


## What a dead monster is worth. `e` is an enemy node (scripts/entities/enemy.gd).
static func xp_of(e: Node, tier: int) -> int:
	if e.get("minion") == true:
		return 0                      # summoned helpers give nothing, so a summoner cannot be farmed
	var data: Dictionary = e.get("data")
	var cost := float(data.get("cost", 1.0))
	if cost > 10.0:
		return 0                      # the straw dummy and other set pieces
	var v := cost * XP_PER_COST * (1.0 + XP_PER_TIER * tier)
	if e.get("champion") == true:
		v *= XP_CHAMPION
	elif e.get("elite") == true:
		v *= XP_ELITE
	return maxi(int(round(v)), 1)


static func xp_of_boss(tier: int) -> int:
	return int(round(XP_BOSS * (1.0 + XP_BOSS_TIER * tier)))


## Adds XP. Returns how many levels that gained (0 most of the time).
static func gain(amount: int) -> int:
	if amount <= 0 or at_max():
		return 0
	var have := xp() + int(round(amount * xp_mult()))
	var gained := 0
	while not at_max() and have >= xp_need():
		have -= xp_need()
		Save.hub_set("rpg:lvl", Save.hub_get("rpg:lvl") + 1)
		Save.hub_set("rpg:sp", skill_points() + 1)
		Save.hub_set("rpg:picks", picks() + 1)
		gained += 1
	if at_max():
		have = 0
	Save.hub_set("rpg:xp", have)
	return gained


# ------------------------------------------------------------------ cards
static func row(id: String) -> Dictionary:
	for r: Dictionary in CARDS:
		if String(r["id"]) == id:
			return r
	return {}


static func taken(id: String) -> int:
	return Save.hub_get("card:" + id)


## Three different cards that are not full yet (fewer when few are left; none when all are full).
static func offer(rng: RandomNumberGenerator = null) -> Array:
	var open: Array = []
	for r: Dictionary in CARDS:
		if taken(String(r["id"])) < int(r["max"]):
			open.append(String(r["id"]))
	var out: Array = []
	while out.size() < 3 and not open.is_empty():
		var i := (rng.randi() if rng != null else randi()) % open.size()
		out.append(open[i])
		open.remove_at(i)
	return out


## Takes a card for one waiting pick. Returns false when there was no pick or the card is full.
static func pick(id: String) -> bool:
	var r := row(id)
	if picks() <= 0 or r.is_empty() or taken(id) >= int(r["max"]):
		return false
	Save.hub_set("card:" + id, taken(id) + 1)
	Save.hub_set("rpg:picks", picks() - 1)
	Save.flush()
	return true


## Every card is full: the pick turns into coins in the camp chest.
static func pick_coins() -> void:
	if picks() <= 0:
		return
	Save.hub_set("rpg:picks", picks() - 1)
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") + FULL_COINS)
	Save.flush()


# ------------------------------------------------------------------ what it all adds up to
## Level growth and every card taken as one stats layer (scripts/entities/player.gd puts it on as "level").
static func mods() -> Dictionary:
	var out := {"pct": {"damage": GROW_DAMAGE * (level() - 1)}}
	for r: Dictionary in CARDS:
		var t := taken(String(r["id"]))
		if t <= 0 or not r.has("mods"):
			continue
		for kind: String in r["mods"]:
			if not out.has(kind):
				out[kind] = {}
			for key: String in r["mods"][kind]:
				out[kind][key] = float(out[kind].get(key, 0.0)) + float(r["mods"][kind][key]) * t
	return out


## Half hearts from levels and cards.
static func bonus_hp() -> int:
	return (level() - 1) / GROW_HP_EVERY + int(row("vigour").get("hp", 0)) * taken("vigour")


static func bonus_block() -> int:
	return int(row("wall").get("block", 0)) * taken("wall")


static func block_cooldown() -> float:
	return float(row("ready").get("block_cooldown", 0.0)) * taken("ready")


## What the next level brings by itself, in words (the level-up screen shows it).
static func growth_text(lvl: int) -> String:
	var parts: Array = ["+%d%% damage" % int(round(GROW_DAMAGE * 100.0))]
	if (lvl - 1) % GROW_HP_EVERY == 0:
		parts.append("+half a heart")
	parts.append("+1 skill point")
	return ", ".join(parts)
