extends RefCounted
## Skills: the knight's special sword moves and spells (RPG step 3, v0.13.0). The owner picked
## "two skill buttons + a mana bar, about 8 skills to learn, you choose which 2 to carry".
##
## How it works:
## 1. A skill is LEARNED when the knight reaches its "level" (scripts/data/rpg.gd). Nothing to buy.
## 2. He carries two at a time, on skill button 1 and 2 (save's hub section, "skill:0" and
##    "skill:1" = the skill's place in LIST + 1, 0 = empty). The Skills page of the Knight screen
##    sets them; a newly learned skill drops into an empty button by itself.
## 3. A skill costs MANA and then rests for "cd" seconds. Mana refills by itself.
##    Spirit (a stat) gives more mana, faster refill and stronger spells.
## 4. What each skill DOES is written in scripts/entities/hero_skills.gd (one function per id);
##    the numbers it uses are in the row's "p".
##
## A row:   "kind"  sword (uses his blow's damage) | spell (also grows with Spirit)
##          "icon"  a picture in assets/art/icons (tools/import_icons.py EXTRA; Raven Fantasy Icons)
##          "mana", "cd" (seconds)        "text"  what the player reads
## Every number is a first guess. Names and words are placeholders the owner may rewrite.

const SLOTS := 2
const MANA_BASE := 20.0            ## mana with no Spirit
const MANA_PER_SPIRIT := 4.0
const REGEN_BASE := 1.2            ## mana per second
const REGEN_PER_SPIRIT := 0.08
const SPELL_PER_SPIRIT := 0.06     ## spells are this much stronger per Spirit point

const LIST := [
	{"id": "whirl", "name": "Whirlwind", "kind": "sword", "level": 2, "mana": 8, "cd": 3.0, "icon": "skill_whirl",
		"text": "Spin: hit everything around you for double damage.", "p": {"damage": 2.0, "reach": 12.0}},
	{"id": "firebolt", "name": "Fire Bolt", "kind": "spell", "level": 3, "mana": 6, "cd": 0.7, "icon": "skill_firebolt",
		"text": "Throw a bolt of fire the way you aim. Three times a blow's damage.", "p": {"damage": 3.0, "speed": 230.0, "range": 210.0}},
	{"id": "lunge", "name": "Lunge", "kind": "sword", "level": 5, "mana": 7, "cd": 2.5, "icon": "skill_lunge",
		"text": "Dash the way you aim, cutting through what stands there. Nothing can hurt you on the way.", "p": {"damage": 1.6, "dist": 62.0, "safe": 0.4}},
	{"id": "mend", "name": "Mend", "kind": "spell", "level": 7, "mana": 18, "cd": 9.0, "icon": "skill_mend",
		"text": "Heal one heart.", "p": {"hp": 2}},
	{"id": "cry", "name": "War Cry", "kind": "sword", "level": 9, "mana": 10, "cd": 8.0, "icon": "skill_cry",
		"text": "A shout that shoves monsters back and stuns them. Bosses only flinch.", "p": {"radius": 70.0, "stun": 1.8}},
	{"id": "frost", "name": "Frost Ring", "kind": "spell", "level": 11, "mana": 12, "cd": 6.0, "icon": "skill_frost",
		"text": "A ring of ice bursts from you: it hurts and freezes monsters for a moment.", "p": {"damage": 1.5, "radius": 62.0, "stun": 1.3}},
	{"id": "slam", "name": "Ground Slam", "kind": "sword", "level": 13, "mana": 14, "cd": 6.0, "icon": "skill_slam",
		"text": "Wind up, then smash the ground: a very heavy blow all around you.", "p": {"damage": 3.5, "radius": 46.0, "windup": 0.35}},
	{"id": "storm", "name": "Chain Lightning", "kind": "spell", "level": 15, "mana": 16, "cd": 5.0, "icon": "skill_storm",
		"text": "Lightning leaps to the five nearest monsters.", "p": {"damage": 2.5, "radius": 125.0, "targets": 5}},
]


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


static func known(id: String) -> bool:
	var r := row(id)
	return not r.is_empty() and Rpg.level() >= int(r["level"])


static func any_known() -> bool:
	return Rpg.level() >= int(LIST[0]["level"])


# ------------------------------------------------------------------ the two buttons
## The skill on button 0 or 1 ({} = empty).
static func on_button(slot: int) -> Dictionary:
	var i := Save.hub_get("skill:%d" % slot) - 1
	if i < 0 or i >= LIST.size() or not known(String(LIST[i]["id"])):
		return {}
	return LIST[i]


## Which button carries this skill (-1 = none).
static func button_of(id: String) -> int:
	for slot in SLOTS:
		if String(on_button(slot).get("id", "")) == id:
			return slot
	return -1


## Puts a skill on a button. If it sat on the other button, the two swap places.
static func assign(id: String, slot: int) -> bool:
	if not known(id) or slot < 0 or slot >= SLOTS:
		return false
	var other := button_of(id)
	if other >= 0 and other != slot:
		Save.hub_set("skill:%d" % other, Save.hub_get("skill:%d" % slot))
	Save.hub_set("skill:%d" % slot, index_of(id) + 1)
	Save.flush()
	return true


static func clear(slot: int) -> void:
	Save.hub_set("skill:%d" % slot, 0)
	Save.flush()


## Called when the knight reaches a level: skills learned at exactly that level, each put on an
## empty button if there is one. Returns their rows (for the banner).
static func learn_at(level: int) -> Array:
	var out: Array = []
	for r: Dictionary in LIST:
		if int(r["level"]) != level:
			continue
		out.append(r)
		for slot in SLOTS:
			if on_button(slot).is_empty() and button_of(String(r["id"])) < 0:
				Save.hub_set("skill:%d" % slot, index_of(String(r["id"])) + 1)
				break
	return out


## Fills empty buttons with known skills (old saves, or after "Take points back" changed nothing here).
static func fill_empty() -> void:
	for r: Dictionary in LIST:
		if not known(String(r["id"])) or button_of(String(r["id"])) >= 0:
			continue
		for slot in SLOTS:
			if on_button(slot).is_empty():
				Save.hub_set("skill:%d" % slot, index_of(String(r["id"])) + 1)
				break


# ------------------------------------------------------------------ mana
static func max_mana() -> float:
	return MANA_BASE + MANA_PER_SPIRIT * float(Rpg.stat("spi"))


static func regen() -> float:
	return REGEN_BASE + REGEN_PER_SPIRIT * float(Rpg.stat("spi"))


static func spell_power() -> float:
	return 1.0 + SPELL_PER_SPIRIT * float(Rpg.stat("spi"))


const Rpg = preload("res://scripts/data/rpg.gd")
