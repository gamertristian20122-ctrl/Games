extends RefCounted
## Turn-based battles: every NUMBER and WORD of them (the rules are scripts/battle/fight.gd, the
## screen is scripts/battle/battle.gd). The owner asked for turn-based on 12 Nov 2026.
##
## Who fights: the knight, the companion who travels with him (scripts/data/allies.gd), and a small
## pack of monsters. The knight's level, stat points, worn gear and learned skills all count:
##   Strength = harder blows    Vitality = more health    Spirit = more mana, stronger spells
##   Agility  = acts earlier in the round
## A round: everybody acts once, the quickest first. On your turn: Attack, Skills, Guard or Flee.
## v0.38.0: health and mana CARRY OVER between battles (scripts/data/wounds.gd); the pack's supplies
## (scripts/data/supplies.gd) are the Items order; a bed, the inn or a level-up makes everybody whole.
## Every number is a first guess, measured only with the test bot (`--battlesim`). Words are
## placeholders the owner may rewrite.

const Rpg = preload("res://scripts/data/rpg.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Wounds = preload("res://scripts/data/wounds.gd")
const Supplies = preload("res://scripts/data/supplies.gd")
const Arms = preload("res://scripts/data/arms.gd")

const DEF_HALF := 24.0             ## this much defence halves a blow (see fight.gd _blow)
const CRIT_CHANCE := 0.06          ## a blow lands half as hard again this often
const CRIT_MULT := 1.5
const GUARD_TAKES := 0.45          ## a guarding fighter takes this share of a blow ...
const GUARD_MANA := 3              ## ... and gets a little mana back
const FLEE_CHANCE := 0.75          ## running away works this often (never from a boss)
const SPREAD := 0.10               ## blows vary by this much up and down
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
const FOE_COINS := 3              ## (v0.39.0: was 2; skills and arms are bought now)

## What a blow or a spell LOOKS like (scripts/battle/battle.gd shows it with light and sparks):
## by skill id: [colour, "burst" | "pillar" | "rise", strength]. "pillar" = a column of light
## from the sky, "rise" = sparks that float up (healing). Anything not listed: a plain white hit.
const FX := {
	"whirl": [Color(0.9, 0.95, 1.0), "burst", 1.4], "lunge": [Color(0.9, 0.95, 1.0), "burst", 1.6],
	"slam": [Color(1.0, 0.85, 0.55), "burst", 2.4], "cry": [Color(1.0, 0.9, 0.6), "burst", 1.2],
	"firebolt": [Color(1.0, 0.5, 0.15), "pillar", 2.4], "frost": [Color(0.5, 0.85, 1.0), "burst", 2.0],
	"storm": [Color(0.45, 0.7, 1.0), "pillar", 2.8], "mend": [Color(0.5, 1.0, 0.6), "rise", 1.6],
	"sunbolt": [Color(1.0, 0.85, 0.4), "pillar", 2.2], "sunflare": [Color(1.0, 0.9, 0.5), "burst", 2.4],
	"sunmend": [Color(1.0, 0.95, 0.6), "rise", 1.6],
	"pierce": [Color(0.7, 1.0, 0.7), "burst", 1.6], "volley": [Color(0.8, 1.0, 0.8), "burst", 1.2],
	"roots": [Color(0.4, 0.9, 0.4), "rise", 1.4], "sweep": [Color(0.5, 0.9, 0.4), "burst", 2.2],
}

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
	"thessaly": {"hp": 38, "hp_level": 5, "mp": 18, "mp_level": 2, "atk": 7.5, "atk_level": 1.7, "def": 1.5, "def_level": 0.35, "speed": 15.0,
		"skills": [
			{"id": "pierce", "name": "Piercing Shot", "kind": "sword", "mana": 4, "aim": "foe", "power": 1.8, "text": "One arrow, drawn to the ear."},
			{"id": "volley", "name": "Volley", "kind": "sword", "mana": 8, "aim": "foes", "power": 0.9, "text": "Arrows over every monster."},
			{"id": "roots", "name": "Binding Roots", "kind": "spell", "mana": 6, "aim": "foe", "power": 0.6, "stun": 0.8, "text": "Roots hold one monster: it may lose its next turn."},
		]},
}


## The knight as he walks into a battle.
static func knight() -> Dictionary:
	var hero: Dictionary = Heroes.by_id("knight")
	var lvl := Rpg.level()
	var pct: Dictionary = Gear.mods().get("pct", {})
	var arms := Arms.bonus("knight")              # (v0.39.0) his sword and armour
	var hp := KNIGHT_HP + KNIGHT_HP_LEVEL * (lvl - 1) + KNIGHT_HP_VIT * Rpg.stat("vit") + KNIGHT_HP_GEAR * Gear.bonus_hp() + int(arms["hp"])
	var skills: Array = []
	for row: Dictionary in Skills.LIST:
		if Skills.known(String(row["id"])) and SKILL.has(String(row["id"])):
			var s: Dictionary = (SKILL[String(row["id"])] as Dictionary).duplicate()
			s["id"] = row["id"]
			s["name"] = row["name"]
			s["kind"] = row["kind"]
			s["mana"] = int(row["mana"])
			skills.append(Arms.ranked("knight", s))
	return {"id": "knight", "name": String(Save.setting("hero_name")), "sprite": String(hero["sprite"]), "side": "party",
		"max_hp": hp, "max_mp": roundi(Skills.max_mana()),
		"atk": (KNIGHT_ATK + KNIGHT_ATK_LEVEL * (lvl - 1)) * (1.0 + Rpg.STR_DAMAGE * Rpg.stat("str") + float(pct.get("damage", 0.0)) + float(arms["atk"])),
		"def": KNIGHT_DEF + KNIGHT_DEF_LEVEL * (lvl - 1) + KNIGHT_DEF_SHIELD * Gear.shield() + float(arms["def"]),
		"speed": KNIGHT_SPEED + KNIGHT_SPEED_AGI * Rpg.stat("agi"), "magic": Skills.spell_power(), "dodge": Gear.ward(), "skills": skills}


## Everybody on the knight's side: he first, then his companions. In the story
## (scripts/data/tale.gd) every companion who has joined fights, up to four in all; `extra` adds
## somebody who fights beside him before she has joined. In the old story: the one who travels
## with him.
static func party(extra: Array = []) -> Array:
	var out: Array = [knight()]
	var ids: Array = []
	if Tale.on():
		for row: Dictionary in Allies.LIST:
			if Allies.joined(String(row["id"])) or extra.has(String(row["id"])):
				ids.append(String(row["id"]))
	elif not Allies.with().is_empty():
		ids.append(String(Allies.with()["id"]))
	var lvl := Rpg.level()
	for id: String in ids:
		if not ALLY.has(id) or out.size() >= 4:
			continue
		var who := Allies.row(id)
		var a: Dictionary = ALLY[id]
		var arms := Arms.bonus(id)                # (v0.39.0) her bow or staff
		var known: Array = []                     # (v0.39.0) her first skill, and what a teacher taught her
		for i in (a["skills"] as Array).size():
			var sk: Dictionary = a["skills"][i]
			if Arms.knows(id, String(sk["id"]), i):
				known.append(Arms.ranked(id, sk))
		out.append({"id": id, "name": String(who["name"]), "sprite": String(who["sprite"]), "side": "party",
			"max_hp": int(a["hp"]) + int(a["hp_level"]) * (lvl - 1) + int(arms["hp"]), "max_mp": int(a["mp"]) + int(a["mp_level"]) * (lvl - 1),
			"atk": (float(a["atk"]) + float(a["atk_level"]) * (lvl - 1)) * (1.0 + float(arms["atk"])), "def": float(a["def"]) + float(a["def_level"]) * (lvl - 1) + float(arms["def"]),
			"speed": float(a["speed"]), "magic": 1.0, "dodge": 0.0, "skills": known})
	Wounds.apply(out)                  # everybody starts as hurt as the last battle left them
	return out


## A boss of the story (scripts/data/tale.gd BOSSES) ready for a battle. It grows a little with
## the knight, so coming back stronger helps but never makes it nothing.
static func boss(boss_id: String) -> Dictionary:
	var row: Dictionary = Tale.BOSSES[boss_id]
	var lvl := Rpg.level()
	return {"id": boss_id, "name": String(row["name"]), "sprite": String(row["sprite"]), "side": "foes", "boss": true,
		"tint": row.get("tint", Color.WHITE),
		"max_hp": roundi(float(row["hp"]) * (1.0 + 0.09 * (lvl - 1))), "max_mp": 0,
		"atk": float(row["atk"]) * (1.0 + FOE_ATK_LEVEL * (lvl - 1)), "def": float(row["def"]), "speed": float(row["speed"]),
		"magic": 1.0, "dodge": 0.0, "skills": [],
		"sweep": int(row.get("sweep", 0)), "sweep_power": float(row.get("sweep_power", 0.7)), "sweep_name": String(row.get("sweep_name", "Sweep")),
		"xp": int(row.get("xp", 50)), "coins": int(row.get("coins", 20))}


## A battle of the story (scripts/data/tale.gd BATTLES): {"party", "foes", "look", "tier", "title", "boss"}.
static func scripted(battle_id: String) -> Dictionary:
	var spec: Dictionary = Tale.BATTLES[battle_id]
	var tier := int(spec.get("tier", 0))
	var foes: Array = []
	if spec.has("boss"):
		foes.append(boss(String(spec["boss"])))
	for id: String in spec.get("foes", []):
		foes.append(foe(id, tier))
	return {"id": battle_id, "party": party(spec.get("with", [])), "foes": foes, "look": String(spec.get("look", "forest")), "tier": tier,
		"title": String(spec.get("title", "A fight")), "boss": spec.has("boss"), "xp_bonus": int(spec.get("xp_bonus", 0))}


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
	# (v0.38.0) a party of three or four meets a bigger pack: with both companions a fight in the Sands
	# was over before it started and twelve in a row could be won without a rest (dev/battle_sim --streak)
	var friends := 0
	for row: Dictionary in Allies.LIST:
		if Allies.joined(String(row["id"])):
			friends += 1
	if friends >= 2 and tier > 0:
		count += 1
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
	return {"xp": xp, "coins": coins, "gear": gear, "supply": Supplies.drop(Tale.step())}
