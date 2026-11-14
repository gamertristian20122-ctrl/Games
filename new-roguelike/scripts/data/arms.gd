extends RefCounted
## ARMS AND LORE (v0.39.0, the owner: "weapons and armor types are upgrades ... the knight's look
## changes, new sword, armor color ... add upgrades for the other characters too ... you have to also
## upgrade new spells"). Everything a party member gets stronger by, besides levels and gear:
##
## ARMS  bought from a smith (Tam in Wickmere, Grukk in Dustwatch), one tier after the other. The best
##       one owned is always the one carried. The knight's sword and armour CHANGE HOW HE LOOKS (the
##       sword picture and armour colour of scripts/data/looks.gd); his companions' bows and staffs only
##       change their numbers (their pack pictures have no weapon of their own to swap).
##   tier row: "id", "name", "price", "from" (story step it is sold from), and what it gives:
##             "atk" (share more damage), "def" (defence), "hp" (health)
##       knight swords: "look" = an id of Looks.SWORDS; knight armour: "look" = an id of Looks.ARMOUR
##       save: "arm:<line>:<tier id>" = 1 (owned)
##
## LORE  skills are no longer learned by themselves: a level only OPENS a skill; a teacher (Brother
##       Odo in Wickmere, Sister Imre in Dustwatch) teaches it for coins, and teaches it again to make
##       it stronger (ranks 1 to 3). The same for the companions' skills.
##       save: "lore:<who>:<skill id>" = rank (0 = not learned). <who> = "knight" or a companion id.
##       A rank adds RANK_POWER to its blow, RANK_HEAL to its healing, RANK_STUN to its stun chance.
## Prices and numbers are first guesses (dev/battle_sim.tscn). Names are placeholders to rewrite.

const Looks = preload("res://scripts/data/looks.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Skills = preload("res://scripts/data/skills.gd")

const LINES := {
	"sword": {"who": "knight", "label": "sword", "tiers": [
		{"id": "knight", "name": "Knight's sword", "price": 0, "from": 0, "atk": 0.0, "look": "knight"},
		{"id": "arming", "name": "Arming sword", "price": 40, "from": 0, "atk": 0.12, "look": "arming"},
		{"id": "elven", "name": "Elven blade", "price": 110, "from": 3, "atk": 0.25, "look": "elven"},
		{"id": "sand", "name": "Sand blade", "price": 220, "from": 8, "atk": 0.40, "look": "sand"},
		{"id": "ember", "name": "Ember blade", "price": 380, "from": 14, "atk": 0.58, "look": "ember"},
		{"id": "grave", "name": "Grave blade", "price": 600, "from": 20, "atk": 0.78, "look": "grave"},
	]},
	"armour": {"who": "knight", "label": "armour", "tiers": [
		{"id": "steel", "name": "Steel armour", "price": 0, "from": 0, "def": 0.0, "hp": 0, "look": "steel"},
		{"id": "forest", "name": "Wardens' green", "price": 50, "from": 1, "def": 2.0, "hp": 6, "look": "forest"},
		{"id": "crimson", "name": "Crimson plate", "price": 140, "from": 4, "def": 4.0, "hp": 14, "look": "crimson"},
		{"id": "gold", "name": "Gilded plate", "price": 260, "from": 9, "def": 6.0, "hp": 24, "look": "gold"},
		{"id": "night", "name": "Nightsteel", "price": 420, "from": 14, "def": 8.0, "hp": 36, "look": "night"},
		{"id": "violet", "name": "Dawnfire plate", "price": 650, "from": 20, "def": 10.0, "hp": 50, "look": "violet"},
	]},
	"bow": {"who": "thessaly", "label": "bow", "tiers": [
		{"id": "warden", "name": "Warden's bow", "price": 0, "from": 0, "atk": 0.0, "hp": 0},
		{"id": "ash", "name": "Ashwood bow", "price": 70, "from": 3, "atk": 0.15, "hp": 4},
		{"id": "thorn", "name": "Thornheart bow", "price": 200, "from": 7, "atk": 0.32, "hp": 10},
		{"id": "sun", "name": "Sunstring bow", "price": 400, "from": 14, "atk": 0.52, "hp": 18},
	]},
	"hammer": {"who": "grukk", "label": "hammer", "tiers": [
		{"id": "forge", "name": "Forge hammer", "price": 0, "from": 0, "atk": 0.0, "hp": 0},
		{"id": "maul", "name": "Cinder maul", "price": 260, "from": 15, "atk": 0.2, "hp": 10},
		{"id": "thane", "name": "The Thane's hammer", "price": 480, "from": 21, "atk": 0.42, "hp": 20},
	]},
	"staff": {"who": "sera", "label": "staff", "tiers": [
		{"id": "archive", "name": "Archive staff", "price": 0, "from": 0, "atk": 0.0, "hp": 0},
		{"id": "glass", "name": "Sunglass staff", "price": 150, "from": 9, "atk": 0.18, "hp": 6},
		{"id": "dawn", "name": "Dawnspire staff", "price": 380, "from": 14, "atk": 0.38, "hp": 14},
	]},
}

const TEACHERS := ["odo", "imre"]      ## who teaches skills (ids of people)
const RANK_MAX := 3
const RANK_POWER := 0.22          ## each rank past the first: +22% to the skill's blow
const RANK_HEAL := 0.18           ## ... +18% to its healing
const RANK_STUN := 0.1            ## ... +10 points to its stun chance
const TEACH_BASE := 20            ## learning a skill: this + TEACH_LEVEL per level it opens at
const TEACH_LEVEL := 6
const RANK_COST := [0, 1.0, 2.0, 3.5]   ## price of rank n = the learning price x this
## the level each companion skill opens at, by its place in battles.gd ALLY skills (the first is
## known when she joins)
const ALLY_LEVELS := [0, 4, 8]


# ------------------------------------------------------------------ arms
static func owned(line: String, tier_id: String) -> bool:
	return Save.hub_get("arm:%s:%s" % [line, tier_id]) > 0


## The best tier of a line owned (the first tier is always owned).
static func current(line: String) -> Dictionary:
	var tiers: Array = LINES[line]["tiers"]
	var best: Dictionary = tiers[0]
	for t: Dictionary in tiers:
		if owned(line, String(t["id"])):
			best = t
	return best


## The next tier of a line ({} = the last one is owned).
static func next(line: String) -> Dictionary:
	var tiers: Array = LINES[line]["tiers"]
	var at := tiers.find(current(line))
	return tiers[at + 1] if at + 1 < tiers.size() else {}


static func buy(line: String) -> bool:
	var t := next(line)
	if t.is_empty() or Save.hub_get("bank:coins") < int(t["price"]) or Tale.step() < int(t["from"]):
		return false
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") - int(t["price"]))
	Save.hub_set("arm:%s:%s" % [line, String(t["id"])], 1)
	_dress()
	Save.flush()
	return true


## The knight wears his best sword and armour (the look the menus, the places and battles show).
static func _dress() -> void:
	Save.set_setting("sword_look", String(current("sword")["look"]))
	Save.set_setting("armour", String(current("armour")["look"]))


## What a party member's arms add: {"atk": share, "def": points, "hp": points}.
static func bonus(who: String) -> Dictionary:
	var out := {"atk": 0.0, "def": 0.0, "hp": 0}
	for line: String in LINES:
		if String(LINES[line]["who"]) != who:
			continue
		var t := current(line)
		out["atk"] = float(out["atk"]) + float(t.get("atk", 0.0))
		out["def"] = float(out["def"]) + float(t.get("def", 0.0))
		out["hp"] = int(out["hp"]) + int(t.get("hp", 0))
	return out


# ------------------------------------------------------------------ lore
static func rank(who: String, skill_id: String) -> int:
	return Save.hub_get("lore:%s:%s" % [who, skill_id])


## The level a skill opens at: the knight's from skills.gd, a companion's from ALLY_LEVELS.
static func opens_at(who: String, skill_id: String, index: int) -> int:
	if who == "knight":
		return int(Skills.row(skill_id).get("level", 99))
	return int(ALLY_LEVELS[mini(index, ALLY_LEVELS.size() - 1)])


## Coins to teach the next rank (-1 = already at RANK_MAX).
static func price(who: String, skill_id: String, index: int) -> int:
	var r := rank(who, skill_id)
	if r >= RANK_MAX:
		return -1
	return roundi(float(TEACH_BASE + TEACH_LEVEL * opens_at(who, skill_id, index)) * float(RANK_COST[r + 1]))


static func teach(who: String, skill_id: String, index: int) -> bool:
	var cost := price(who, skill_id, index)
	if cost < 0 or Save.hub_get("bank:coins") < cost or Rpg.level() < opens_at(who, skill_id, index):
		return false
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") - cost)
	Save.hub_set("lore:%s:%s" % [who, skill_id], rank(who, skill_id) + 1)
	Save.flush()
	return true


## Does this party member know this skill? (A companion always knows her first one.)
static func knows(who: String, skill_id: String, index: int) -> bool:
	return rank(who, skill_id) > 0 or (who != "knight" and index == 0)


## A battle skill row made stronger by its rank (a copy).
static func ranked(who: String, skill: Dictionary) -> Dictionary:
	var s := skill.duplicate()
	var r := maxi(1, rank(who, String(s["id"])))
	s["rank"] = r
	if s.has("power"):
		s["power"] = float(s["power"]) * (1.0 + RANK_POWER * (r - 1))
	if s.has("heal"):
		s["heal"] = float(s["heal"]) * (1.0 + RANK_HEAL * (r - 1))
	if s.has("stun"):
		s["stun"] = minf(0.95, float(s["stun"]) + RANK_STUN * (r - 1))
	if r > 1:
		s["name"] = "%s %s" % [String(s["name"]), ["", "", "II", "III"][r]]
	return s


## Old saves and new games: the knight carries his best arms; what the knight's level had already
## taught him (before skills had to be learned) stays learned; a companion knows her first skill.
static func ensure() -> void:
	if Save.hub_get("arms:init") > 0:
		return
	Save.hub_set("arms:init", 1)
	for r: Dictionary in Skills.LIST:
		if Rpg.level() >= int(r["level"]) and rank("knight", String(r["id"])) == 0:
			Save.hub_set("lore:knight:" + String(r["id"]), 1)
	_dress()
