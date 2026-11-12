extends RefCounted
## Turn-based battles: every NUMBER and WORD of them (the rules are scripts/battle/fight.gd, the
## screen is scripts/battle/battle.gd). The owner asked for turn-based on 12 Nov 2026.
##
## Who fights: the knight, the companion who travels with him (scripts/data/allies.gd), and a small
## pack of monsters. The knight's level, stat points, worn gear and learned skills all count:
##   Strength = harder blows    Vitality = more health    Spirit = more mana, stronger spells
##   Agility  = acts earlier in the round
## A round: everybody acts once, the quickest first. On your turn: Attack, Skills, Guard or Flee.
## Everybody starts every battle rested (full health and mana): there are no potions or inns yet.
## Every number is a first guess, measured only with the test bot (`--battlesim`). Words are
## placeholders the owner may rewrite.

const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Heroes = preload("res://scripts/data/heroes.gd")

const CRIT_CHANCE := 0.08          ## a blow lands half as hard again this often
const CRIT_MULT := 1.5
const GUARD_TAKES := 0.45          ## a guarding fighter takes this share of a blow ...
const GUARD_MANA := 3              ## ... and gets a little mana back
const FLEE_CHANCE := 0.75          ## running away works this often (never from a boss)
const SPREAD := 0.12               ## blows vary by this much up and down
const LOOT_CHANCE := 0.10          ## a won battle leaves a piece of gear this often

# ---- the knight
const KNIGHT_HP := 46
const KNIGHT_HP_LEVEL := 7
const KNIGHT_HP_VIT := 6
const KNIGHT_HP_GEAR := 4          ## per half heart a worn piece gives
const KNIGHT_ATK := 9.0
const KNIGHT_ATK_LEVEL := 2.0
const KNIGHT_DEF := 2.0
const KNIGHT_DEF_LEVEL := 0.5
const KNIGHT_DEF_SHIELD := 2.0     ## per shield heart of the worn gear
const KNIGHT_SPEED := 10.0
const KNIGHT_SPEED_AGI := 1.5

# ---- monsters (their rows are scripts/data/enemies.gd; "hp" and "speed" there were written for
# the old real-time game and are scaled here)
const FOE_HP := 2.3                ## battle health per point of the row's "hp"
const FOE_HP_TIER := 0.36          ## and this much more per tier of the land (0 = the woods .. 3)
const FOE_ATK := 4.6
const FOE_ATK_TIER := 1.8
const FOE_ATK_LEVEL := 0.07        ## monsters hit this much harder per level of the knight
const FOE_DEF_TIER := 1.0
const FOE_XP := 0.7                ## XP per point of the row's "hp" (x 1 + tier)
const FOE_COINS := 2

## What each of the knight's skills (scripts/data/skills.gd) does in a battle.
##   "aim"    foe = one monster | foes = all of them | friend = one of your side | self
##   "power"  the blow, as a share of a plain Attack ("spell" skills also grow with Spirit)
##   "heal"   share of the target's health given back      "stun" chance to make a monster miss its next turn
##   "safe"   the knight guards as well this round          "text"  what the player reads in the list
const SKILL := {
	"whirl": {"aim": "foes", "power": 0.95, "text": "A spin that cuts every monster."},
	"firebolt": {"aim": "foe", "power": 2.1, "text": "A bolt of fire at one monster."},
	"lunge": {"aim": "foe", "power": 1.5, "safe": true, "text": "A quick thrust; you guard as you land."},
	"mend": {"aim": "friend", "heal": 0.4, "text": "Give back a good part of a friend's health."},
	"cry": {"aim": "foes", "power": 0.0, "stun": 0.6, "text": "A shout: monsters may lose their next turn."},
	"frost": {"aim": "foes", "power": 0.8, "stun": 0.3, "text": "Ice on every monster; some freeze."},
	"slam": {"aim": "foes", "power": 1.5, "text": "A heavy blow that shakes every monster."},
	"storm": {"aim": "foes", "power": 1.35, "text": "Lightning leaps to every monster."},
}

## What a companion brings to a battle, by her id in allies.gd.
const ALLY := {
	"sera": {"hp": 34, "hp_level": 5, "mp": 26, "mp_level": 3, "atk": 6.0, "atk_level": 1.5, "def": 1.0, "def_level": 0.3, "speed": 12.0,
		"skills": [
			{"id": "sunbolt", "name": "Sunbolt", "kind": "spell", "mana": 5, "aim": "foe", "power": 1.9, "text": "A bolt of sunlight at one monster."},
			{"id": "sunmend", "name": "Sun's Mercy", "kind": "spell", "mana": 9, "aim": "friend", "heal": 0.38, "text": "Light that closes a friend's wounds."},
			{"id": "sunflare", "name": "Sunflare", "kind": "spell", "mana": 12, "aim": "foes", "power": 1.1, "text": "A burst of light over every monster."},
		]},
}


## The knight as he walks into a battle.
static func knight() -> Dictionary:
	var hero: Dictionary = Heroes.by_id("knight")
	var lvl := Rpg.level()
	var pct: Dictionary = Gear.mods().get("pct", {})
	var hp := KNIGHT_HP + KNIGHT_HP_LEVEL * (lvl - 1) + KNIGHT_HP_VIT * Rpg.stat("vit") + KNIGHT_HP_GEAR * Gear.bonus_hp()
	var skills: Array = []
	for row: Dictionary in Skills.LIST:
		if Skills.known(String(row["id"])) and SKILL.has(String(row["id"])):
			var s: Dictionary = (SKILL[String(row["id"])] as Dictionary).duplicate()
			s["id"] = row["id"]
			s["name"] = row["name"]
			s["kind"] = row["kind"]
			s["mana"] = int(row["mana"])
			skills.append(s)
	return {"id": "knight", "name": String(Save.setting("hero_name")), "sprite": String(hero["sprite"]), "side": "party",
		"max_hp": hp, "max_mp": roundi(Skills.max_mana()),
		"atk": (KNIGHT_ATK + KNIGHT_ATK_LEVEL * (lvl - 1)) * (1.0 + Rpg.STR_DAMAGE * Rpg.stat("str") + float(pct.get("damage", 0.0))),
		"def": KNIGHT_DEF + KNIGHT_DEF_LEVEL * (lvl - 1) + KNIGHT_DEF_SHIELD * Gear.shield(),
		"speed": KNIGHT_SPEED + KNIGHT_SPEED_AGI * Rpg.stat("agi"), "magic": Skills.spell_power(), "dodge": Gear.ward(), "skills": skills}


## Everybody on the knight's side: he first, then whoever travels with him.
static func party() -> Array:
	var out: Array = [knight()]
	var with: Dictionary = Allies.with()
	if not with.is_empty() and ALLY.has(String(with["id"])):
		var a: Dictionary = ALLY[String(with["id"])]
		var lvl := Rpg.level()
		out.append({"id": String(with["id"]), "name": String(with["name"]), "sprite": String(with["sprite"]), "side": "party",
			"max_hp": int(a["hp"]) + int(a["hp_level"]) * (lvl - 1), "max_mp": int(a["mp"]) + int(a["mp_level"]) * (lvl - 1),
			"atk": float(a["atk"]) + float(a["atk_level"]) * (lvl - 1), "def": float(a["def"]) + float(a["def_level"]) * (lvl - 1),
			"speed": float(a["speed"]), "magic": 1.0, "dodge": 0.0, "skills": (a["skills"] as Array).duplicate(true)})
	return out


## One monster ready for a battle. `tier` is how dangerous the land is (0 = the woods .. 3).
static func foe(enemy_id: String, tier: int) -> Dictionary:
	var row := Enemies.info(enemy_id)
	var lvl := Rpg.level()
	var base := float(row.get("hp", 8.0))
	return {"id": enemy_id, "name": String(row.get("name", enemy_id)), "sprite": String(row.get("sprite", "pc_skeleton_base")), "side": "foes",
		"tint": row.get("tint", Color.WHITE),
		"max_hp": maxi(6, roundi(base * FOE_HP * (1.0 + FOE_HP_TIER * tier) * Rpg.foe_scale())), "max_mp": 0,
		"atk": (FOE_ATK + FOE_ATK_TIER * tier) * (1.0 + FOE_ATK_LEVEL * (lvl - 1)), "def": FOE_DEF_TIER * tier,
		"speed": 5.0 + float(row.get("speed", 40.0)) / 9.0, "magic": 1.0, "dodge": 0.0, "skills": [],
		"xp": maxi(2, roundi(base * FOE_XP * (1.0 + tier))), "coins": FOE_COINS + tier}


## The pack a roamer of the world map brings (scripts/data/roamers.gd): what it looks like on the
## map leads, one or two more of its kind come with it (a new knight meets smaller packs).
static func pack_for(spot: int, rng: RandomNumberGenerator) -> Array:
	var kind := Roamers.kind_of(spot)
	var tier := int(kind["tier"])
	var shows: Array = kind["shows"]
	var count := 2 + (1 if rng.randf() < 0.45 else 0)
	if Rpg.level() < 3 and tier == 0:
		count = 1 + (1 if rng.randf() < 0.6 else 0)
	var out: Array = [foe(Roamers.shows(spot), tier)]
	while out.size() < count:
		out.append(foe(String(shows[rng.randi() % shows.size()]), tier))
	return out


## Which battle stage (scripts/battle/stage.gd LOOKS) a roamer's land uses.
static func look_for(spot: int) -> String:
	var kind := Roamers.kind_of(spot)
	return String(kind.get("look", "rock"))


## What a won battle gives: {"xp", "coins", "gear" (an id of gear.gd, or "")}.
static func reward(foes: Array, tier: int) -> Dictionary:
	var xp := 0
	var coins := 0
	for f: Dictionary in foes:
		xp += int(f.get("xp", 0))
		coins += int(f.get("coins", 0))
	xp = roundi(float(xp) * Gear.xp_mult())
	var gear := ""
	if randf() < LOOT_CHANCE:
		gear = Gear.roll_common(tier)
		if gear != "" and Gear.owned(gear):
			gear = ""
	return {"xp": xp, "coins": coins, "gear": gear}
