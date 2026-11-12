extends RefCounted
## The RULES of a turn-based battle, with nothing to look at: who acts when, what a blow does,
## when it is over. scripts/battle/battle.gd shows it; the test bot plays it without a screen.
## Numbers and words come from scripts/data/battles.gd.
##
##   var f := Fight.new();  f.setup(party, foes, seed)
##   var who := f.next()                      the fighter whose turn it is ({} when it is over)
##   var events := f.act(who, action)         do it; returns what happened, in order, to show
##   f.result()                               "" while it lasts, then "win", "lose" or "fled"
## An action:  {"do": "attack", "target": unit}   {"do": "skill", "skill": row, "target": unit or null}
##             {"do": "guard"}                    {"do": "flee"}
## An event:   {"type": "hit" | "heal" | "miss" | "guard" | "stun" | "stunned" | "flee" | "say", ...}

const Battles = preload("res://scripts/data/battles.gd")

var party: Array = []
var foes: Array = []
var order: Array = []              ## who still acts this round, the next one first
var round_no := 0
var fled := false
var no_flee := false               ## a boss: nobody runs
var rng := RandomNumberGenerator.new()


func setup(the_party: Array, the_foes: Array, seed_value: int = 0) -> void:
	party = the_party
	foes = the_foes
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for u: Dictionary in party + foes:
		u["hp"] = int(u["max_hp"])
		u["mp"] = int(u["max_mp"])
		u["guard"] = false
		u["stun"] = 0
	order.clear()
	round_no = 0


func alive(list: Array) -> Array:
	return list.filter(func(u: Dictionary) -> bool: return int(u["hp"]) > 0)


func result() -> String:
	if fled:
		return "fled"
	if alive(foes).is_empty():
		return "win"
	if alive(party).is_empty():
		return "lose"
	return ""


## The fighter whose turn it is now. Starts a new round when everybody has acted.
func next() -> Dictionary:
	if result() != "":
		return {}
	while true:
		if order.is_empty():
			round_no += 1
			order = alive(party) + alive(foes)
			for u: Dictionary in order:
				u["roll"] = float(u["speed"]) * rng.randf_range(0.85, 1.15)
			order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["roll"]) > float(b["roll"]))
		var who: Dictionary = order.pop_front()
		if int(who["hp"]) > 0:
			who["guard"] = false           # a guard lasts until your next turn
			return who
	return {}


## Who acts after the current fighter, for the row of faces at the top.
func upcoming() -> Array:
	return alive(order)


## Has this fighter lost the turn (stunned)? Then call act(who, {}) and show what comes back.
func stunned(unit: Dictionary) -> bool:
	return int(unit["stun"]) > 0


func can_use(unit: Dictionary, skill: Dictionary) -> bool:
	return int(unit["mp"]) >= int(skill.get("mana", 0))


func act(who: Dictionary, action: Dictionary) -> Array:
	var events: Array = []
	if int(who["stun"]) > 0:
		who["stun"] = int(who["stun"]) - 1
		events.append({"type": "stunned", "who": who})
		return events
	match String(action.get("do", "guard")):
		"attack":
			_blow(who, action["target"], 1.0, false, events)
		"skill":
			var skill: Dictionary = action["skill"]
			if not can_use(who, skill):
				events.append({"type": "say", "text": "Not enough mana."})
				return events
			who["mp"] = int(who["mp"]) - int(skill.get("mana", 0))
			events.append({"type": "skill", "who": who, "skill": skill})
			var spell := String(skill.get("kind", "sword")) == "spell"
			var aim := String(skill.get("aim", "foe"))
			var targets: Array = []
			var others: Array = foes if String(who["side"]) == "party" else party
			var friends: Array = party if String(who["side"]) == "party" else foes
			match aim:
				"foes":
					targets = alive(others)
				"friend":
					targets = [action.get("target", who)]
				"self":
					targets = [who]
				_:
					targets = [action["target"]]
			for t: Dictionary in targets:
				if skill.has("heal"):
					if int(t["hp"]) <= 0 or not friends.has(t):
						continue           # nobody is raised from a fall by a heal
					var amount := roundi(float(t["max_hp"]) * float(skill["heal"]) * (float(who["magic"]) if spell else 1.0))
					amount = mini(amount, int(t["max_hp"]) - int(t["hp"]))
					t["hp"] = int(t["hp"]) + amount
					events.append({"type": "heal", "who": who, "target": t, "amount": amount})
					continue
				if float(skill.get("power", 0.0)) > 0.0:
					_blow(who, t, float(skill["power"]) * (float(who["magic"]) if spell else 1.0), true, events)
				if skill.has("stun") and int(t["hp"]) > 0 and not bool(t.get("boss", false)) and rng.randf() < float(skill["stun"]):
					t["stun"] = 1
					events.append({"type": "stun", "target": t})
			if bool(skill.get("safe", false)):
				who["guard"] = true
		"flee":
			if not no_flee and rng.randf() < Battles.FLEE_CHANCE:
				fled = true
				events.append({"type": "flee", "who": who, "ok": true})
			else:
				events.append({"type": "flee", "who": who, "ok": false})
		_:
			who["guard"] = true
			who["mp"] = mini(int(who["max_mp"]), int(who["mp"]) + Battles.GUARD_MANA)
			events.append({"type": "guard", "who": who})
	return events


func _blow(who: Dictionary, target: Dictionary, power: float, sure: bool, events: Array) -> void:
	if int(target["hp"]) <= 0:
		# the one aimed at fell before this turn came: the blow goes to another who still stands
		var rest := alive(foes if foes.has(target) else party)
		if rest.is_empty():
			return
		target = rest[0]
	if not sure and rng.randf() < float(target.get("dodge", 0.0)):
		events.append({"type": "miss", "who": who, "target": target})
		return
	var crit := rng.randf() < Battles.CRIT_CHANCE
	var amount := float(who["atk"]) * power * rng.randf_range(1.0 - Battles.SPREAD, 1.0 + Battles.SPREAD) - float(target["def"]) * 0.5
	if crit:
		amount *= Battles.CRIT_MULT
	if bool(target["guard"]):
		amount *= Battles.GUARD_TAKES
	var dealt := maxi(1, roundi(amount))
	target["hp"] = maxi(0, int(target["hp"]) - dealt)
	events.append({"type": "hit", "who": who, "target": target, "amount": dealt, "crit": crit, "dead": int(target["hp"]) <= 0, "guarded": bool(target["guard"])})


## Will this boss sweep everybody on its NEXT turn? (The screen warns the player.)
func sweep_next(who: Dictionary) -> bool:
	return int(who.get("sweep", 0)) > 0 and (int(who.get("turns", 0)) + 1) % int(who["sweep"]) == 0


## What a monster does on its turn: a blow at somebody who still stands (the knight more often).
func foe_choice(who: Dictionary) -> Dictionary:
	var standing := alive(party)
	if int(who.get("sweep", 0)) > 0:
		who["turns"] = int(who.get("turns", 0)) + 1
		if int(who["turns"]) % int(who["sweep"]) == 0:
			# a boss's heavy move: everybody on your side at once (Guard on the turn before helps)
			return {"do": "skill", "skill": {"id": "sweep", "name": String(who.get("sweep_name", "Sweep")), "kind": "sword", "mana": 0,
				"aim": "foes", "power": float(who.get("sweep_power", 0.7))}, "target": null}
	var target: Dictionary = standing[rng.randi() % standing.size()]
	if standing.size() > 1 and rng.randf() < 0.3:
		target = standing[0]
	return {"do": "attack", "target": target}


## What the test bot (and "Auto") does for a fighter of your side: heal who is badly hurt, use a
## strong skill while there is mana, else attack the weakest monster.
func auto_choice(who: Dictionary) -> Dictionary:
	var standing := alive(foes)
	var weakest: Dictionary = standing[0]
	for f: Dictionary in standing:
		if int(f["hp"]) < int(weakest["hp"]):
			weakest = f
	for s: Dictionary in who["skills"]:
		if s.has("heal") and can_use(who, s):
			for p: Dictionary in alive(party):
				if float(p["hp"]) < float(p["max_hp"]) * 0.4:
					return {"do": "skill", "skill": s, "target": p}
	var best := {}
	for s: Dictionary in who["skills"]:
		if not can_use(who, s) or float(s.get("power", 0.0)) <= 0.0:
			continue
		var worth := float(s["power"]) * (standing.size() if String(s["aim"]) == "foes" else 1)
		if worth > 1.3 and (best.is_empty() or worth > float(best["worth"])):
			best = {"skill": s, "worth": worth}
	if not best.is_empty():
		return {"do": "skill", "skill": best["skill"], "target": weakest}
	return {"do": "attack", "target": weakest}
