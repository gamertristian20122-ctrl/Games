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
## Quality pass P01 (Nov 2026): THE LANTERN, statuses (STATUS), battle modes (MODE), Flares (FLARE),
## deeds (DEED), monster kits (scripts/data/foe_kits.gd) and boss scripts (scripts/data/boss_moves.gd).
## What every new field means: docs/pass/01_rules.md. The screen for them comes with package P08.
## Skill rows may now carry:  "status": [id of STATUS, chance]   "bonus": {"vs": [status ids or "stun"], "mult"}
##   "cleanse": true (takes ills off your side)   "pierce": true (ignores defence)

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
const FoeKits = preload("res://scripts/data/foe_kits.gd")
const BossMoves = preload("res://scripts/data/boss_moves.gd")

const DEF_HALF := 24.0             ## this much defence halves a blow (see fight.gd _blow)
const CRIT_CHANCE := 0.06          ## a blow lands half as hard again this often
const CRIT_MULT := 1.5
const GUARD_TAKES := 0.45          ## a guarding fighter takes this share of a blow ...
const GUARD_MANA := 5              ## ... and gets a little mana back (quality pass P01: was 3)
const FLEE_CHANCE := 0.75          ## running away works this often (never from a boss)
const SPREAD := 0.10               ## blows vary by this much up and down
const LOOT_CHANCE := 0.10          ## a won battle leaves a piece of gear this often
const CRIT_AGI := 0.005            ## the knight's crit chance grows this much per Agility point
const CRIT_EXPOSED := 0.15         ## and anybody's by this much against an "exposed" target
const ROLL_SPREAD := 0.08          ## the speed roll of a round varies by this much (was 0.15)
const REDIRECT_RANDOM := true      ## a blow at somebody who already fell goes to a random other

# ---- THE LANTERN (quality pass P01; the rules are at the top of scripts/battle/fight.gd)
const LANTERN_LIT := 1.25          ## the one who carries it: blows and heals this much stronger
const FLAME_MAX := 3               ## the flame at which the carrier's Flare is ready
const HEAVY_UNGUARDED := 1         ## flame lost when the carrier takes a heavy blow unguarded
const FLAME_ON_KILL := 1           ## flame gained when the carrier fells a monster (once a turn, on top of the blow's)
## monsters' health by how many companions have joined (0 .. 3): four fighters fell a pack too fast
const CROWD_HP := [1.0, 1.05, 1.2, 1.35]
## (quality pass P08, balance) ... and their blows: a party of four ended a rock-land fight with 80%+ of
## its health, so a bigger party now meets harder-hitting monsters too
const CROWD_ATK := [1.0, 1.25, 1.35, 1.3]

## STATUSES: things that stay on a fighter for some of ITS OWN turns (a turn counts at its start).
##   "turns"  how long        "bad"  true = an ill (Cleansing Salt and Sunflare take it off)
##   "tick"   share of full health lost at the start of each own turn ("tick_boss": on a boss)
##   "atk"    multiplier on its blows       "def_to" its defence becomes this
##   "def"    defence added                 "taken"  multiplier on what it takes
##   "crit"   added to the chance of a crit against it
##   "last"   true = it acts LAST in the next round (the screen's order row shows it)
##   "name", "text"  for the screen (placeholders)
const STATUS := {
	"burn": {"name": "Burning", "turns": 3, "bad": true, "tick": 0.06, "tick_boss": 0.02, "text": "Loses a little health at the start of each of its turns."},
	"weak": {"name": "Weak", "turns": 3, "bad": true, "atk": 0.75, "text": "Its blows land a quarter lighter."},
	"exposed": {"name": "Exposed", "turns": 2, "bad": true, "def_to": 0.0, "taken": 1.2, "crit": CRIT_EXPOSED, "text": "No defence, takes a fifth more, easier to crit."},
	"slowed": {"name": "Slowed", "turns": 1, "bad": true, "last": true, "text": "Acts last in the next round."},
	"braced": {"name": "Braced", "turns": 2, "bad": false, "def": 8.0, "taken": 0.8, "text": "Harder to hurt for two turns."},
}

const BOSS_PULL := 0.65            ## how often a boss's (or a kit-less monster's) single blow goes for the Lantern's carrier

## Short lines the rules themselves say (scripts/battle/fight.gd). %s = a name. Placeholders.
const SAY := {
	"no_mana": "Not enough mana.", "no_flame": "The flame is not full yet.", "none_left": "None left.",
	"whole": "Already whole.", "nobody_hurt": "Nobody is hurt.", "mana_full": "Mana is already full.",
	"fallen": "Fallen: only a Waking Ember can help now.", "standing": "Still standing: nothing to wake.",
	"no_ill": "Nothing to cleanse.",
	"burned": "%s is burned away.", "shrug": "%s shrugs it off.", "held_off": "%s guards against it.",
	"draws_back": "%s draws back.", "hisses": "%s hisses and glows.", "somebody": "somebody",
	# what a monster means to do this round (the screen's intent plates)
	"intent_blow": "Strikes %s.", "intent_heavy": "%s at %s. Guard!", "intent_draw": "Draws back. Next turn: %s.",
	"intent_fuse": "Hissing: bursts in %d.", "intent_burst": "%s: everybody. Guard!", "intent_all": "%s: everybody. Guard!",
	"intent_heal": "%s: mends %s.", "intent_stunned": "Cannot move.",
}

## HOW HARD (Settings > battle mode; Save.setting("battle_mode"), nothing set = "normal"):
## a multiplier on every monster's and boss's health and attack.
const MODE := {"story": 0.75, "normal": 1.0, "hard": 1.18}   ## (P08 balance: hard was 1.3; monsters grow with the party and the level now)
## tests and the battle sim force a mode with this ("" = read the setting)
static var mode_force := ""

## THE FLARE of each fighter: the big move the Lantern's carrier may use when the flame is full
## (it costs no mana and puts the flame out). Each "id" is a move the screen already shows.
##   "pierce" the blow ignores defence        "stun": 1.0 a sure stun (never on a boss)
##   "aim": "party" everybody on your side     "raise" share of health a FALLEN friend stands up with
##   "rally" everybody on your side guards
const FLARE := {
	"knight": {"id": "lunge", "name": "Dawnbreaker", "kind": "sword", "mana": 0, "flare": true, "aim": "foe", "power": 2.6, "pierce": true,
		"text": "Flare: one blow, more than twice as hard, straight through any defence."},
	"thessaly": {"id": "volley", "name": "Warden's Rain", "kind": "sword", "mana": 0, "flare": true, "aim": "foes", "power": 1.0, "stun": 1.0,
		"text": "Flare: arrows on every monster, and each loses its next turn (a boss is only slowed)."},
	"sera": {"id": "sunmend", "name": "Second Dawn", "kind": "spell", "mana": 0, "flare": true, "aim": "party", "heal": 0.3, "raise": 0.25,
		"text": "Flare: heals everybody three tenths and stands the fallen up."},
	"grukk": {"id": "quake", "name": "Anvil Wall", "kind": "sword", "mana": 0, "flare": true, "aim": "foes", "power": 1.5, "rally": true,
		"text": "Flare: a great blow on every monster, and your whole side guards."},
}

## DEEDS: what a won battle is praised for (each adds DEED_BONUS to its XP and coins).
##   swift     won within SWIFT_ROUNDS + one round per monster (a boss: SWIFT_BOSS)
##   unbroken  nobody on your side fell          lit  a Flare was used
const DEED := {
	"swift": {"name": "Swift", "text": "Won in few rounds."},
	"unbroken": {"name": "Unbroken", "text": "Nobody fell."},
	"lit": {"name": "Lit", "text": "A Flare was loosed."},
}
const DEED_BONUS := 0.15
const SWIFT_ROUNDS := 1
const SWIFT_BOSS := 7

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
const FOE_ATK := 5.0                ## (quality pass P01: was 4.6; the knight stood 11 blows in the woods)
#const FOE_ATK := 4.6
const FOE_ATK_TIER := 1.8
const FOE_ATK_LEVEL := 0.12        ## monsters hit this much harder per level of the knight (P08 balance: was 0.07)
const BOSS_ATK_LEVEL := 0.08       ## (P08 balance) a boss grows less per level (it was FOE_ATK_LEVEL, 0.07)
const FOE_HP_LEVEL := 0.03         ## (P08 balance) and have this much more health per level, on top of Rpg.foe_scale()
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
	"cleave": [Color(1.0, 0.7, 0.4), "burst", 2.0], "quake": [Color(1.0, 0.6, 0.3), "burst", 2.4], "temper": [Color(1.0, 0.75, 0.45), "rise", 1.4],
}

## What each of the knight's skills (scripts/data/skills.gd) does in a battle.
##   "aim"    foe = one monster | foes = all of them | friend = one of your side | self
##   "power"  the blow, as a share of a plain Attack ("spell" skills also grow with Spirit)
##   "heal"   share of the target's health given back      "stun" chance to make a monster miss its next turn
##   "safe"   the knight guards as well this round          "text"  what the player reads in the list
const SKILL := {
	"whirl": {"aim": "foes", "power": 0.95, "text": "A spin that cuts every monster."},
	"firebolt": {"aim": "foe", "power": 2.1, "status": ["burn", 0.85], "text": "A bolt of fire at one monster. It keeps burning for three turns."},
	"lunge": {"aim": "foe", "power": 1.5, "safe": true, "text": "A quick thrust; you guard as you land."},
	"mend": {"aim": "friend", "heal": 0.4, "text": "Give back a good part of a friend's health."},
	"cry": {"aim": "foes", "power": 0.0, "stun": 0.25, "status": ["weak", 1.0], "text": "A shout: every monster hits a quarter lighter for two blows; some lose a turn."},
	"frost": {"aim": "foes", "power": 0.8, "status": ["slowed", 0.9], "text": "Ice on every monster: they act last next round."},
	"slam": {"aim": "foes", "power": 1.1, "status": ["exposed", 0.8], "text": "A heavy blow on every monster that leaves them exposed: no defence, and they take more."},
	"storm": {"aim": "foes", "power": 1.35, "bonus": {"vs": ["slowed", "stun"], "mult": 1.8}, "text": "Lightning on every monster; far harder on the slowed and the stunned."},
}

## What a companion brings to a battle, by her id in allies.gd.
const ALLY := {
	"sera": {"hp": 34, "hp_level": 5, "mp": 26, "mp_level": 3, "atk": 6.0, "atk_level": 1.5, "def": 1.0, "def_level": 0.3, "speed": 12.0,
		"skills": [
			{"id": "sunbolt", "name": "Sunbolt", "kind": "spell", "mana": 5, "aim": "foe", "power": 1.9, "text": "A bolt of sunlight at one monster."},
			{"id": "sunmend", "name": "Sun's Mercy", "kind": "spell", "mana": 9, "aim": "friend", "heal": 0.38, "text": "Light that closes a friend's wounds."},
			{"id": "sunflare", "name": "Sunflare", "kind": "spell", "mana": 12, "aim": "foes", "power": 1.1, "cleanse": true, "text": "A burst of light over every monster; it burns every ill off your side."},
		]},
	"thessaly": {"hp": 38, "hp_level": 5, "mp": 18, "mp_level": 2, "atk": 7.5, "atk_level": 1.7, "def": 1.5, "def_level": 0.35, "speed": 15.0,
		"skills": [
			{"id": "pierce", "name": "Piercing Shot", "kind": "sword", "mana": 4, "aim": "foe", "power": 1.8, "text": "One arrow, drawn to the ear."},
			{"id": "volley", "name": "Volley", "kind": "sword", "mana": 8, "aim": "foes", "power": 0.9, "text": "Arrows over every monster."},
			{"id": "roots", "name": "Binding Roots", "kind": "spell", "mana": 6, "aim": "foe", "power": 0.6, "stun": 0.8, "status": ["exposed", 1.0], "text": "Roots hold one monster: it may lose its next turn, and it stands exposed."},
		]},
	"grukk": {"hp": 52, "hp_level": 7, "mp": 14, "mp_level": 2, "atk": 9.0, "atk_level": 2.0, "def": 3.0, "def_level": 0.5, "speed": 8.0,
		"skills": [
			{"id": "cleave", "name": "Cleave", "kind": "sword", "mana": 5, "aim": "foe", "power": 2.0, "text": "One great swing of the hammer."},
			{"id": "quake", "name": "Hammerfall", "kind": "sword", "mana": 9, "aim": "foes", "power": 0.85, "stun": 0.35, "text": "The ground shakes under every monster; some fall over."},
			{"id": "temper", "name": "Temper", "kind": "spell", "mana": 8, "aim": "self", "heal": 0.35, "safe": true, "status": ["braced", 1.0], "text": "Grukk breathes like a bellows: he heals, guards, and is braced for two turns."},
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
		"speed": KNIGHT_SPEED + KNIGHT_SPEED_AGI * Rpg.stat("agi"), "magic": Skills.spell_power(), "dodge": Gear.ward(), "skills": skills,
		"crit": CRIT_CHANCE + CRIT_AGI * Rpg.stat("agi")}


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


## How hard the monsters are: MODE's multiplier for the chosen battle mode.
static func mode() -> String:
	var m := mode_force
	if m == "":
		var set_to: Variant = Save.setting("battle_mode")        # (null until the settings row exists)
		m = String(set_to) if set_to != null else "normal"
	return m if MODE.has(m) else "normal"


static func mode_mult() -> float:
	return float(MODE[mode()])


## A row of the story's tables by id: scripts/data/tale.gd first ("BATTLES" or "BOSSES"), then
## scripts/data/more.gd when that file exists (later chapters; it answers battle(id) / boss(id)).
static func _story_row(table: String, id: String) -> Dictionary:
	var from_tale: Dictionary = Tale.BATTLES if table == "BATTLES" else Tale.BOSSES
	if from_tale.has(id):
		return from_tale[id]
	if ResourceLoader.exists("res://scripts/data/more.gd"):
		var more: Variant = load("res://scripts/data/more.gd")     # (untyped on purpose: the file comes later)
		var fn := "battle" if table == "BATTLES" else "boss"
		if more is Script:
			for m: Dictionary in (more as Script).get_script_method_list():
				if String(m["name"]) == fn:
					var got: Variant = more.call(fn, id)
					if got is Dictionary:
						return got
	return {}


## A boss of the story (scripts/data/tale.gd BOSSES) ready for a battle. It grows a little with
## the knight, so coming back stronger helps but never makes it nothing. Its script (what it does
## turn by turn) is the row's own "moves" or scripts/data/boss_moves.gd.
static func boss(boss_id: String) -> Dictionary:
	var row := _story_row("BOSSES", boss_id)
	var lvl := Rpg.level()
	var plan: Dictionary = BossMoves.MOVES.get(boss_id, {})
	var hard := mode_mult()
	var more_hp := float(plan.get("hp", 1.0))
	var more_atk := float(plan.get("atk", 1.0))
	return {"id": boss_id, "name": String(row.get("name", boss_id)), "sprite": String(row.get("sprite", "boss_ogre")), "side": "foes", "boss": true,
		"tint": row.get("tint", Color.WHITE),
		"max_hp": roundi(float(row.get("hp", 150)) * (1.0 + 0.09 * (lvl - 1)) * hard * more_hp), "max_mp": 0,
		"atk": float(row.get("atk", 8.0)) * (1.0 + BOSS_ATK_LEVEL * (lvl - 1)) * hard * more_atk, "def": float(row.get("def", 0.0)), "speed": float(row.get("speed", 9.0)),
		"magic": 1.0, "dodge": 0.0, "skills": [],
		"sweep": int(row.get("sweep", 0)), "sweep_power": float(row.get("sweep_power", 0.7)), "sweep_name": String(row.get("sweep_name", "Sweep")),
		"moves": row.get("moves", plan.get("moves", [])), "phases": row.get("phases", plan.get("phases", [])),
		"phase_say": row.get("phase_say", plan.get("phase_say", [])), "regen": row.get("regen", plan.get("regen", {})),
		"line": String(row.get("line", "")),
		"xp": int(row.get("xp", 50)), "coins": int(row.get("coins", 20))}


## A battle of the story (scripts/data/tale.gd BATTLES): {"party", "foes", "look", "tier", "title", "boss",
## "win" (what winning it does in the story)}.
static func scripted(battle_id: String) -> Dictionary:
	var spec := _story_row("BATTLES", battle_id)
	var tier := int(spec.get("tier", 0))
	var foes: Array = []
	if spec.has("boss"):
		foes.append(boss(String(spec["boss"])))
	for id: String in spec.get("foes", []):
		foes.append(foe(id, tier))
	return {"id": battle_id, "party": party(spec.get("with", [])), "foes": foes, "look": String(spec.get("look", "forest")), "tier": tier,
		"title": String(spec.get("title", "A fight")), "boss": spec.has("boss"), "xp_bonus": int(spec.get("xp_bonus", 0)),
		"win": spec.get("win", {})}


## One monster ready for a battle. `tier` is how dangerous the land is (0 = the woods .. 3).
## Its KIND (the row's "ai") gives it a kit of scripts/data/foe_kits.gd: multipliers, a special
## move and the line the screen shows about it.
static func foe(enemy_id: String, tier: int) -> Dictionary:
	var row := Enemies.info(enemy_id)
	var lvl := Rpg.level()
	var base := float(row.get("hp", 8.0))
	var kind := String(row.get("ai", ""))
	var kit := FoeKits.of(enemy_id, kind)
	var hard := mode_mult()
	var friends := 0
	for a: Dictionary in Allies.LIST:
		if Allies.joined(String(a["id"])):
			friends += 1
	var crowd := float(CROWD_HP[clampi(friends, 0, CROWD_HP.size() - 1)])
	var crowd_atk := float(CROWD_ATK[clampi(friends, 0, CROWD_ATK.size() - 1)])
	return {"id": enemy_id, "name": String(row.get("name", enemy_id)), "sprite": String(row.get("sprite", "pc_skeleton_base")), "side": "foes",
		"tint": row.get("tint", Color.WHITE),
		"max_hp": maxi(6, roundi(base * FOE_HP * (1.0 + FOE_HP_TIER * tier) * Rpg.foe_scale() * (1.0 + FOE_HP_LEVEL * (lvl - 1)) * float(kit["hp"]) * hard * crowd)), "max_mp": 0,
		"atk": (FOE_ATK + FOE_ATK_TIER * tier) * (1.0 + FOE_ATK_LEVEL * (lvl - 1)) * float(kit["atk"]) * hard * crowd_atk, "def": FOE_DEF_TIER * tier + float(kit["def"]),
		"speed": 5.0 + float(row.get("speed", 40.0)) / 9.0, "magic": 1.0, "dodge": float(kit["dodge"]), "skills": [],
		"kind": kind, "kit": kit, "line": String(kit["line"]),
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


## The deeds a won battle earned (ids of DEED, at most three). `stats` is fight.gd's `stats`;
## `pack_size` how many monsters there were.
static func deeds(stats: Dictionary, pack_size: int) -> Array:
	var out: Array = []
	if stats.is_empty():
		return out
	var limit := SWIFT_BOSS if bool(stats.get("boss", false)) else SWIFT_ROUNDS + pack_size
	if int(stats.get("rounds", 99)) <= limit:
		out.append("swift")
	if int(stats.get("fell", 1)) == 0:
		out.append("unbroken")
	if int(stats.get("flares", 0)) > 0:
		out.append("lit")
	return out


## What a won battle gives: {"xp", "coins", "gear" (an id of gear.gd, or ""), "supply", "deeds"}.
## With the fight's `stats` every deed adds DEED_BONUS to the XP and the coins.
static func reward(foes: Array, tier: int, stats: Dictionary = {}) -> Dictionary:
	var xp := 0
	var coins := 0
	for f: Dictionary in foes:
		xp += int(f.get("xp", 0))
		coins += int(f.get("coins", 0))
	xp = roundi(float(xp) * Gear.xp_mult())
	var done := deeds(stats, foes.size())
	var bonus := 1.0 + DEED_BONUS * done.size()
	xp = roundi(float(xp) * bonus)
	coins = roundi(float(coins) * bonus)
	var gear := ""
	if randf() < LOOT_CHANCE:
		gear = Gear.roll_common(tier)
		if gear != "" and Gear.owned(gear):
			gear = ""
	return {"xp": xp, "coins": coins, "gear": gear, "supply": Supplies.drop(Tale.step()), "deeds": done}
