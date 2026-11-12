extends RefCounted
## RPG: the knight's level, his experience (XP) and the points he puts into four stats.
## Asked for by the owner on 12 Nov 2026 ("turn Hollow Hill into an RPG": levels and XP where
## "monsters give XP, I level up and choose what gets stronger"; the owner picked STAT POINTS).
##
## How it works, in five lines:
## 1. Every monster killed in a story level gives XP (xp_for). Bosses and champions give a lot.
## 2. Enough XP = a new level (need). Each level gives POINTS_PER_LEVEL points and heals him fully.
## 3. Points go into the four STATS below, on the Knight screen (scripts/ui/knight.gd).
## 4. Level, XP and points are kept for ever in the save's hub section (keys "rpg:*"):
##    dying loses none of it.
## 5. player.gd apply_rpg() turns the points into numbers (a stats layer called "rpg").
##
## Every number here is a first guess: nobody has played it by hand. Change them freely.
## Words (names, descriptions) are placeholders the owner may rewrite.

const MAX_LEVEL := 30
const POINTS_PER_LEVEL := 3
const STAT_CAP := 20               ## the most points one stat can hold

## The four stats. "each" is what ONE point does, in words; the numbers are just below.
const STATS := [
	{"id": "str", "name": "Strength", "each": "blows hit 5% harder", "color": Color("d9573b")},
	{"id": "vit", "name": "Vitality", "each": "half a heart more health", "color": Color("6fbf5a")},
	{"id": "spi", "name": "Spirit", "each": "4 more mana, spells 6% stronger, guard back 4% sooner", "color": Color("5aa7d9")},
	{"id": "agi", "name": "Agility", "each": "walk 2% and swing 3% faster", "color": Color("e3c15a")},
]
const STR_DAMAGE := 0.05           ## damage per Strength point (5%)
const VIT_HP := 1                  ## half hearts per Vitality point
const SPI_GUARD := 0.04            ## the guard's rest gets this much shorter per Spirit point
const AGI_SPEED := 0.02            ## walking speed per Agility point
const AGI_RATE := 0.03             ## swing speed per Agility point

## Monsters and bosses have this much more health per level of the knight above 1, so a strong
## knight still gets a fight (the same idea as G.ITEM_HP for the items he carries). One point of
## Strength is worth 5%, so a knight who puts a point per level into Strength stays ahead.
const FOE_HP_PER_LEVEL := 0.03

## XP a monster gives: its health divided by this (a 10-health monster gives 3). Bosses divide by BOSS_XP_DIV.
const XP_DIV := 4.0
const BOSS_XP_DIV := 8.0


# ------------------------------------------------------------------ reading
static func level() -> int:
	return maxi(Save.hub_get("rpg:lvl"), 1)


## XP gathered inside the current level (0 .. need(level) - 1).
static func xp() -> int:
	return Save.hub_get("rpg:xp")


## XP it takes to go from this level to the next: 30, 53, 82, 117, 158 ...
## (Measured with the bot: about level 4 after the first story level; the guess is level 18 or so
## at the end of the story, with level 30 left for side areas.)
static func need(lvl: int) -> int:
	var n := lvl - 1
	return 30 + 20 * n + 3 * n * n


static func points() -> int:
	return Save.hub_get("rpg:pts")


static func stat(id: String) -> int:
	return Save.hub_get("rpg:" + id)


static func at_max() -> bool:
	return level() >= MAX_LEVEL


## How full the XP bar is, 0 to 1.
static func fill() -> float:
	if at_max():
		return 1.0
	return clampf(float(xp()) / float(need(level())), 0.0, 1.0)


static func row(id: String) -> Dictionary:
	for r: Dictionary in STATS:
		if String(r["id"]) == id:
			return r
	return {}


## What monster and boss health is multiplied by (enemy.gd _hp_scale, boss.gd).
static func foe_scale() -> float:
	return 1.0 + FOE_HP_PER_LEVEL * float(level() - 1)


# ------------------------------------------------------------------ earning
## XP for killing this monster (scripts/entities/enemy.gd). A row in enemies.gd may fix it with "xp".
static func xp_for(e: Node) -> int:
	if e.get("minion") == true:
		return 0                      # helpers a boss or a summoner calls give nothing (no farming)
	var data: Variant = e.get("data")
	if data is Dictionary and (data as Dictionary).has("xp"):
		return int(data["xp"])
	return maxi(1, roundi(float(e.get("max_hp")) / XP_DIV))


static func xp_for_boss(b: Node) -> int:
	return maxi(20, roundi(float(b.get("max_hp")) / BOSS_XP_DIV))


## Adds XP. Returns how many levels were gained (0 most of the time).
static func add_xp(amount: int) -> int:
	if amount <= 0 or at_max():
		return 0
	var lvl := level()
	var have := xp() + amount
	var gained := 0
	while lvl < MAX_LEVEL and have >= need(lvl):
		have -= need(lvl)
		lvl += 1
		gained += 1
	if lvl >= MAX_LEVEL:
		have = 0
	Save.hub_set("rpg:xp", have)
	if gained > 0:
		Save.hub_set("rpg:lvl", lvl)
		Save.hub_set("rpg:pts", points() + gained * POINTS_PER_LEVEL)
	return gained


# ------------------------------------------------------------------ spending
## Why a point cannot go into this stat right now ("" = it can).
static func why_not(id: String) -> String:
	if points() <= 0:
		if at_max():
			return "No points left. Level %d is the highest." % MAX_LEVEL
		return "No points left. Reach level %d for %d more." % [level() + 1, POINTS_PER_LEVEL]
	if stat(id) >= STAT_CAP:
		return "%s is as high as it goes (%d)." % [String(row(id).get("name", id)), STAT_CAP]
	return ""


static func spend(id: String) -> bool:
	if row(id).is_empty() or why_not(id) != "":
		return false
	Save.hub_set("rpg:pts", points() - 1)
	Save.hub_set("rpg:" + id, stat(id) + 1)
	Save.flush()
	return true


## Takes every point back so it can be placed again (free; offered in the camps only).
static func reset() -> void:
	var back := 0
	for r: Dictionary in STATS:
		back += stat(String(r["id"]))
		Save.hub_set("rpg:" + String(r["id"]), 0)
	Save.hub_set("rpg:pts", points() + back)
	Save.flush()


static func spent() -> int:
	var n := 0
	for r: Dictionary in STATS:
		n += stat(String(r["id"]))
	return n


# ------------------------------------------------------------------ what the points do
## The points as one stats layer (scripts/run/stats.gd).
static func mods() -> Dictionary:
	return {"pct": {
		"damage": STR_DAMAGE * stat("str"),
		"speed": AGI_SPEED * stat("agi"),
		"rate": AGI_RATE * stat("agi"),
	}}


## Half hearts of health from Vitality.
static func bonus_hp() -> int:
	return VIT_HP * stat("vit")


## The guard's rest is multiplied by this (1 = unchanged, never under 0.4).
static func guard_mult() -> float:
	return maxf(1.0 - SPI_GUARD * stat("spi"), 0.4)


## What the points in a stat add up to, as short words for the Knight screen.
static func total_text(id: String) -> String:
	var n := stat(id)
	match id:
		"str":
			return "+%d%% damage" % roundi(STR_DAMAGE * n * 100.0)
		"vit":
			return "+%s hearts" % _halves(VIT_HP * n)
		"spi":
			return "+%d mana, +%d%% spells" % [4 * n, 6 * n]
		"agi":
			return "+%d%% walk, +%d%% swing" % [roundi(AGI_SPEED * n * 100.0), roundi(AGI_RATE * n * 100.0)]
	return ""


static func _halves(half_hearts: int) -> String:
	@warning_ignore("integer_division")
	var whole := half_hearts / 2
	if half_hearts % 2 == 0:
		return str(whole)
	return ("%d.5" % whole) if whole > 0 else "0.5"
