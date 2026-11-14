extends RefCounted
## The RULES of a turn-based battle, with nothing to look at: who acts when, what a blow does,
## when it is over. scripts/battle/battle.gd shows it; the test bot plays it without a screen.
## Numbers and words come from scripts/data/battles.gd (and foe_kits.gd, boss_moves.gd).
##
##   var f := Fight.new();  f.setup(party, foes, seed)
##   var who := f.next()                      the fighter whose turn it is ({} when it is over)
##   var events := f.act(who, action)         do it; returns what happened, in order, to show
##   f.result()                               "" while it lasts, then "win", "lose" or "fled"
## An action:  {"do": "attack", "target": unit}   {"do": "skill", "skill": row, "target": unit or null}
##             {"do": "guard"}                    {"do": "flee"}
##             {"do": "item", "item": row of supplies.gd, "target": unit}  (taken out of the pack)
## An event:   {"type": "hit" | "heal" | "miss" | "guard" | "stun" | "stunned" | "flee" | "say" | "item", ...}
##
## ---- THE QUALITY PASS (P01, Nov 2026): the Lantern and a real rulebook
## THE LANTERN. One fighter of your side carries it (`lantern`; the first at the start).
##   - The carrier is LIT: blows and heals x Battles.LANTERN_LIT.
##   - Monsters' single blows go for the carrier most of the time (each kit's "pull").
##   - The FLAME (`flame`, 0 to 3) grows by 1 when the carrier lands a blow or a heal (once a
##     turn), when the carrier fells a monster (once a turn) and when the carrier is struck
##     while guarding (once a guard); it shrinks by 1 when
##     the carrier takes a heavy blow unguarded; it goes out when the carrier falls (the Lantern
##     passes to the next who stands).
##   - At a full flame the carrier may use a FLARE (`flare_for(who)`, Battles.FLARE): no mana,
##     the flame goes out.
##   - Once a round anybody else may TAKE the Lantern (`can_take`, `take_lantern`): it is free,
##     the turn is not spent. The flame stays with the Lantern.
## STATUSES (Battles.STATUS): unit["status"] = {id: own turns left}. `add_status`, `has_status`.
##   They count down at the start of the fighter's own turn. Guarding keeps a monster's blow from
##   leaving one on you.
## INTENTS: when a round begins every monster decides what it will do and says so:
##   unit["intent"] = {"do": action, "target": unit or null, "icon": blow | all | heavy | fuse |
##   heal | wind | none, "text": words, "done": bool}. `foe_choice` hands that action back (aimed
##   again if its mark fell). Monster kinds: scripts/data/foe_kits.gd. Bosses: boss_moves.gd.
## TURN ORDER: `upcoming()` = who still acts this round; `upcoming_next()` = the next round,
##   already rolled. `delay(unit, places)` moves somebody back.
## NEW EVENTS (they are NEVER the first of a turn, so a screen that does not know them just
##   skips them):
##   {"type": "status", "target", "id", "turns"}       turns 0 = it was taken off
##   {"type": "burn", "target", "amount", "dead"}      a status' tick
##   {"type": "lantern", "who", "from", "flame"}       it changed hands ("fell": true when the carrier fell)
##   {"type": "flame", "n", "was", "holder"}
##   {"type": "phase", "who", "n"}                     a boss's next phase
##   {"type": "rally", "who"}                          everybody on that side guards
##   "hit" gained "heavy" and "lit"; "heal" gained "raised"; "stun" gained "turns".
## Also: `useful(who, action)` ("" or why not), `preview(who, target, power)` ([least, most]),
##   `stats` (for Battles.deeds), `auto_choice` (the bot and "Auto" play all of the above).

const Battles = preload("res://scripts/data/battles.gd")
const Supplies = preload("res://scripts/data/supplies.gd")

var party: Array = []
var foes: Array = []
var order: Array = []              ## who still acts this round, the next one first
var order_next: Array = []         ## the next round's order, rolled when this round began
var round_no := 0
var fled := false
var no_flee := false               ## a boss: nobody runs
var rng := RandomNumberGenerator.new()

var lantern: Dictionary = {}       ## who carries the Lantern (one of `party`)
var flame := 0                     ## 0 .. Battles.FLAME_MAX
## what the fight was like, for Battles.deeds(): rounds, damage your side took, how many of
## yours fell, Flares used, whether the last order of your side was a Flare, a boss fight?
var stats := {"rounds": 0, "taken": 0, "fell": 0, "flares": 0, "last_flare": false, "boss": false}

## true (the default): a turn that used an item returns ONLY "item" events; whatever else
## happened on it (a burn's tick, a status taken off by Cleansing Salt) is handed out with the next
## turn instead. The battle screen of v0.44 needs that; a screen that skips events it does not
## know in an item's turn (package P08) sets it to false and gets everything at once.
var plain_item_turns := true

var _took_round := false           ## the Lantern already changed hands this round
var _fed_turn := false             ## the flame already grew on this turn
var _fed_kill := false             ## ... and already grew for a monster felled on this turn
var _carry: Array = []             ## events of a free deed (the bot taking the Lantern) for the next act()


func setup(the_party: Array, the_foes: Array, seed_value: int = 0) -> void:
	party = the_party
	foes = the_foes
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for u: Dictionary in party + foes:
		u["hp"] = int(u.get("start_hp", u["max_hp"]))       # (v0.38.0: the party may come in hurt)
		u["mp"] = int(u.get("start_mp", u["max_mp"]))
		u["guard"] = false
		u["stun"] = 0
		u["status"] = {}
		u["turns"] = 0
		u["phase"] = 1
		u.erase("intent")
		u.erase("fuse")
		u.erase("drawn")
	order.clear()
	order_next.clear()
	round_no = 0
	fled = false
	flame = 0
	_took_round = false
	_fed_turn = false
	_carry.clear()
	lantern = {}
	var up := alive(party)
	if not up.is_empty():
		lantern = up[0]
	stats = {"rounds": 0, "taken": 0, "fell": 0, "flares": 0, "last_flare": false,
		"boss": foes.any(func(u: Dictionary) -> bool: return bool(u.get("boss", false)))}


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


# ------------------------------------------------------------------ turn order
func _roll() -> Array:
	var list: Array = alive(party) + alive(foes)
	for u: Dictionary in list:
		u["roll"] = float(u["speed"]) * rng.randf_range(1.0 - Battles.ROLL_SPREAD, 1.0 + Battles.ROLL_SPREAD)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["roll"]) > float(b["roll"]))
	return list


func _new_round() -> void:
	round_no += 1
	stats["rounds"] = round_no
	if order_next.is_empty():
		order = _roll()
	else:
		order = alive(order_next)
		for u: Dictionary in alive(party) + alive(foes):      # (somebody stood up again since it was rolled)
			if not order.has(u):
				order.append(u)
	order_next = _roll()
	_took_round = false
	for f: Dictionary in alive(foes):
		f["intent"] = _plan(f)


## The fighter whose turn it is now. Starts a new round when everybody has acted.
func next() -> Dictionary:
	if result() != "":
		return {}
	while true:
		if order.is_empty():
			_new_round()
		var who: Dictionary = order.pop_front()
		if int(who["hp"]) > 0:
			who["guard"] = false           # a guard lasts until your next turn
			who["guard_fed"] = false
			_fed_turn = false
			_fed_kill = false
			return who
	return {}


## Who acts after the current fighter, for the row of faces at the top.
func upcoming() -> Array:
	return alive(order)


## The round after this one (already rolled; a slowed fighter stands at its end).
func upcoming_next() -> Array:
	return alive(order_next)


## Moves a fighter `places` back: in this round if it has not acted yet, else in the next.
func delay(unit: Dictionary, places: int) -> void:
	var list: Array = order if order.has(unit) else order_next
	var at := list.find(unit)
	if at < 0:
		return
	list.remove_at(at)
	list.insert(mini(at + maxi(places, 0), list.size()), unit)


## Has this fighter lost the turn (stunned)? Then call act(who, {}) and show what comes back.
func stunned(unit: Dictionary) -> bool:
	return int(unit["stun"]) > 0


func can_use(unit: Dictionary, skill: Dictionary) -> bool:
	if bool(skill.get("flare", false)) and (unit != lantern or flame < Battles.FLAME_MAX):
		return false
	return int(unit["mp"]) >= int(skill.get("mana", 0))


# ------------------------------------------------------------------ statuses
func has_status(u: Dictionary, id: String) -> bool:
	return int((u.get("status", {}) as Dictionary).get(id, 0)) > 0


## Puts a status of Battles.STATUS on a fighter (turns 0 = the table's length). A longer one
## already there stays.
func add_status(u: Dictionary, id: String, turns: int, events: Array) -> void:
	if int(u["hp"]) <= 0 or not Battles.STATUS.has(id):
		return
	var row: Dictionary = Battles.STATUS[id]
	var t := turns if turns > 0 else int(row.get("turns", 1))
	if bool(row.get("last", false)):
		# it acts last next round; the mark must still be on it then
		if order.has(u):
			t += 1
		order_next.erase(u)
		order_next.append(u)
	var st: Dictionary = u["status"]
	st[id] = maxi(int(st.get(id, 0)), t)
	events.append({"type": "status", "target": u, "id": id, "turns": int(st[id])})


## Takes every ill off a fighter.
func clear_bad(u: Dictionary, events: Array) -> void:
	var st: Dictionary = u.get("status", {})
	for id: String in st.keys():
		if bool((Battles.STATUS.get(id, {}) as Dictionary).get("bad", false)):
			st.erase(id)
			events.append({"type": "status", "target": u, "id": id, "turns": 0})


func _has_bad(u: Dictionary) -> bool:
	for id: String in (u.get("status", {}) as Dictionary):
		if bool((Battles.STATUS.get(id, {}) as Dictionary).get("bad", false)):
			return true
	return false


## The start of a fighter's own turn: what its statuses do, then they count down.
func _tick_status(who: Dictionary, events: Array) -> void:
	var st: Dictionary = who["status"]
	for id: String in st.keys():
		var row: Dictionary = Battles.STATUS.get(id, {})
		var share := float(row.get("tick_boss" if bool(who.get("boss", false)) else "tick", row.get("tick", 0.0)))
		if share > 0.0 and int(who["hp"]) > 0:
			var amount := mini(int(who["hp"]), maxi(1, roundi(float(who["max_hp"]) * share)))
			who["hp"] = int(who["hp"]) - amount
			if String(who["side"]) == "party":
				stats["taken"] = int(stats["taken"]) + amount
			events.append({"type": "burn", "target": who, "id": id, "amount": amount, "dead": int(who["hp"]) <= 0})
			if int(who["hp"]) <= 0:
				_fell(who, events)
			else:
				_phase_check(who, events)
		st[id] = int(st[id]) - 1
		if int(st[id]) <= 0:
			st.erase(id)
			if int(who["hp"]) > 0:
				events.append({"type": "status", "target": who, "id": id, "turns": 0})


# ------------------------------------------------------------------ the Lantern
## May this fighter take the Lantern now? (Once a round, never the one who has it.)
func can_take(who: Dictionary) -> bool:
	return result() == "" and not _took_round and String(who.get("side", "")) == "party" \
		and int(who["hp"]) > 0 and who != lantern


## Takes the Lantern: free, the turn is NOT spent. Returns the events to show ([] = not allowed).
func take_lantern(who: Dictionary) -> Array:
	if not can_take(who):
		return []
	var was := lantern
	lantern = who
	_took_round = true
	return [{"type": "lantern", "who": who, "from": was, "flame": flame}]


## The carrier's Flare when the flame is full ({} otherwise).
func flare_for(who: Dictionary) -> Dictionary:
	if who != lantern or flame < Battles.FLAME_MAX:
		return {}
	return Battles.FLARE.get(String(who.get("id", "")), {})


func _set_flame(n: int, events: Array) -> void:
	n = clampi(n, 0, Battles.FLAME_MAX)
	if n == flame:
		return
	var was := flame
	flame = n
	events.append({"type": "flame", "n": n, "was": was, "holder": lantern})


func _feed(events: Array) -> void:
	if _fed_turn:
		return
	_fed_turn = true
	_set_flame(flame + 1, events)


## Somebody's health reached nothing.
func _fell(u: Dictionary, events: Array) -> void:
	u["status"] = {}
	u["stun"] = 0
	if String(u["side"]) != "party":
		return
	stats["fell"] = int(stats["fell"]) + 1
	if u == lantern:
		_set_flame(0, events)
		var up := alive(party)
		if not up.is_empty():
			lantern = up[0]
			events.append({"type": "lantern", "who": lantern, "from": u, "flame": flame, "fell": true})


# ------------------------------------------------------------------ what an order is worth
## "" when the order would do something, else the reason it would be wasted (shown instead;
## nothing is taken from the pack and no mana is spent).
func useful(who: Dictionary, action: Dictionary) -> String:
	var friends: Array = party if String(who["side"]) == "party" else foes
	match String(action.get("do", "guard")):
		"skill":
			var skill: Dictionary = action["skill"]
			if bool(skill.get("flare", false)) and (who != lantern or flame < Battles.FLAME_MAX):
				return String(Battles.SAY["no_flame"])
			if int(who["mp"]) < int(skill.get("mana", 0)):
				return String(Battles.SAY["no_mana"])
			if skill.has("heal") and float(skill.get("power", 0.0)) <= 0.0 and not skill.has("status") and not bool(skill.get("safe", false)):
				if String(skill.get("aim", "friend")) == "party":
					for f: Dictionary in friends:
						if int(f["hp"]) < int(f["max_hp"]) and (int(f["hp"]) > 0 or skill.has("raise")):
							return ""
					return String(Battles.SAY["nobody_hurt"])
				var t: Dictionary = action.get("target", who) if action.get("target") != null else who
				if int(t["hp"]) <= 0:
					return "" if skill.has("raise") else String(Battles.SAY["fallen"])
				if int(t["hp"]) >= int(t["max_hp"]):
					return String(Battles.SAY["whole"])
		"item":
			var item: Dictionary = action["item"]
			if Supplies.count(String(item["id"])) <= 0:
				return String(Battles.SAY["none_left"])
			var whole_party := String(item.get("aim", "friend")) == "party"
			var t: Dictionary = action.get("target", who) if action.get("target") != null else who
			if item.has("raise"):
				return "" if not _fallen_for(t, friends).is_empty() else String(Battles.SAY["standing"])
			if bool(item.get("cure", false)):
				for f: Dictionary in alive(friends):
					if _has_bad(f):
						return ""
				return String(Battles.SAY["no_ill"])
			var key := "mp" if item.has("mana") else "hp"
			if whole_party:
				for f: Dictionary in alive(friends):
					if int(f[key]) < int(f["max_" + key]):
						return ""
				return String(Battles.SAY["mana_full" if key == "mp" else "nobody_hurt"])
			if int(t["hp"]) <= 0:
				return String(Battles.SAY["fallen"])
			if int(t[key]) >= int(t["max_" + key]):
				return String(Battles.SAY["mana_full" if key == "mp" else "whole"])
	return ""


## Who a waking item stands up: the one aimed at when fallen, else the first of that side who
## has fallen ({} = nobody; a screen that can only aim at the standing still works).
func _fallen_for(t: Dictionary, friends: Array) -> Dictionary:
	if int(t.get("hp", 1)) <= 0:
		return t
	for f: Dictionary in friends:
		if int(f["hp"]) <= 0:
			return f
	return {}


## What a blow of `power` from `who` would take off `target`: [least, most], no luck in it
## (no crit, no miss). The screen shows it while the player aims.
func preview(who: Dictionary, target: Dictionary, power: float = 1.0, opts: Dictionary = {}) -> Array:
	var base := _weight(who, target, power, opts)
	if bool(target.get("guard", false)):
		base *= Battles.GUARD_TAKES
	return [maxi(1, roundi(base * (1.0 - Battles.SPREAD))), maxi(1, roundi(base * (1.0 + Battles.SPREAD)))]


## A blow before luck and guard: attack x power, the Lantern's light, statuses, defence's share.
func _weight(who: Dictionary, target: Dictionary, power: float, opts: Dictionary) -> float:
	var def := maxf(float(target["def"]), 0.0)
	var taken := 1.0
	for id: String in (target.get("status", {}) as Dictionary):
		var row: Dictionary = Battles.STATUS.get(id, {})
		if row.has("def_to"):
			def = float(row["def_to"])
		taken *= float(row.get("taken", 1.0))
	for id: String in (target.get("status", {}) as Dictionary):
		def += float((Battles.STATUS.get(id, {}) as Dictionary).get("def", 0.0))
	if bool(opts.get("pierce", false)):
		def = 0.0
	var amount := float(who["atk"]) * power
	for id: String in (who.get("status", {}) as Dictionary):
		amount *= float((Battles.STATUS.get(id, {}) as Dictionary).get("atk", 1.0))
	if who == lantern:
		amount *= Battles.LANTERN_LIT
	var bonus: Dictionary = opts.get("bonus", {})
	if not bonus.is_empty():
		for id: String in bonus.get("vs", []):
			if has_status(target, id) or (id == "stun" and int(target.get("stun", 0)) > 0):
				amount *= float(bonus.get("mult", 1.0))
				break
	# defence takes a SHARE of a blow (never all of it): DEF_HALF defence halves it, twice that
	# takes two thirds. Nobody can ever be made immune by stacking defence.
	return amount * taken * Battles.DEF_HALF / (Battles.DEF_HALF + def)


# ------------------------------------------------------------------ a turn
func act(who: Dictionary, action: Dictionary) -> Array:
	var events: Array = []
	var extra: Array = []              # what the turn's start did; shown after the turn's first event
	_tick_status(who, extra)
	if int(who["hp"]) <= 0:
		# the burning took it before it could move
		_done(who)
		return [{"type": "say", "text": String(Battles.SAY["burned"]) % String(who["name"])}] + extra
	var is_party := String(who["side"]) == "party"
	if int(who["stun"]) > 0:
		who["stun"] = int(who["stun"]) - 1
		who["fuse"] = 0                # a stun puts a fuse out and breaks a charge
		who["drawn"] = false
		events.append({"type": "stunned", "who": who})
		_done(who)
		return _join(events, extra)
	_regen(who, extra)
	if is_party:
		stats["last_flare"] = false
	match String(action.get("do", "guard")):
		"attack":
			var hit := _blow(who, action["target"], float(action.get("power", 1.0)), false, events, {"heavy": bool(action.get("heavy", false))})
			if not hit.is_empty() and who == lantern:
				_feed(events)
		"skill":
			_skill(who, action, events)
		"item":
			_item(who, action, events)
		"flee":
			if not no_flee and rng.randf() < Battles.FLEE_CHANCE:
				fled = true
				events.append({"type": "flee", "who": who, "ok": true})
			else:
				events.append({"type": "flee", "who": who, "ok": false})
		"wait":
			# a monster gathering itself (a charge drawn back, a fuse hissing)
			events.append({"type": "say", "text": String(action.get("text", "")), "who": who})
		"burst":
			_burst(who, action, events)
		_:
			who["guard"] = true
			who["mp"] = mini(int(who["max_mp"]), int(who["mp"]) + Battles.GUARD_MANA)
			events.append({"type": "guard", "who": who})
	# what a monster's move leaves behind for its next one (a charge drawn back, a fuse burning)
	var then: Dictionary = action.get("then", {})
	for k: String in then:
		who[k] = then[k]
	_done(who)
	return _join(events, extra)


## The turn's events with the turn-start events (and a free deed's) after the first one, so the
## first event always says what kind of turn it was.
func _join(events: Array, extra: Array) -> Array:
	extra = _carry + extra
	_carry = []
	if plain_item_turns and not events.is_empty() and String(events[0]["type"]) == "item":
		# (the screen of v0.44 reads EVERY event of an item's turn as an item: the others wait for
		# the next turn, where they come after its first event)
		_carry = extra + events.filter(func(e: Dictionary) -> bool: return String(e["type"]) != "item")
		return events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "item")
	if extra.is_empty():
		return events
	if events.is_empty():
		events.append({"type": "say", "text": ""})
	return [events[0]] + extra + events.slice(1)


func _done(who: Dictionary) -> void:
	if who.has("intent"):
		(who["intent"] as Dictionary)["done"] = true


## A boss that is fed by somebody beside it (boss_moves.gd "regen").
func _regen(who: Dictionary, events: Array) -> void:
	var regen: Dictionary = who.get("regen", {})
	if regen.is_empty() or int(who["hp"]) >= int(who["max_hp"]):
		return
	var friends: Array = party if String(who["side"]) == "party" else foes
	for f: Dictionary in alive(friends):
		if f != who and String(f["id"]) == String(regen.get("while", "")):
			var amount := mini(roundi(float(who["max_hp"]) * float(regen.get("share", 0.0))), int(who["max_hp"]) - int(who["hp"]))
			if amount > 0:
				who["hp"] = int(who["hp"]) + amount
				if String(regen.get("say", "")) != "":
					events.append({"type": "say", "text": String(regen["say"])})
				events.append({"type": "heal", "who": f, "target": who, "amount": amount})
			return


func _skill(who: Dictionary, action: Dictionary, events: Array) -> void:
	var skill: Dictionary = action["skill"]
	var why := useful(who, action)
	if why != "":
		events.append({"type": "say", "text": why})
		return
	var flare := bool(skill.get("flare", false))
	who["mp"] = int(who["mp"]) - int(skill.get("mana", 0))
	events.append({"type": "skill", "who": who, "skill": skill})
	if String(action.get("say", "")) != "":
		events.append({"type": "say", "text": String(action["say"])})
	var lit := who == lantern
	if flare:
		stats["flares"] = int(stats["flares"]) + 1
		stats["last_flare"] = true
		_fed_turn = true               # a Flare empties the flame; its own blow does not feed it again
		_fed_kill = true
		_set_flame(0, events)
	var spell := String(skill.get("kind", "sword")) == "spell"
	var magic := float(who["magic"]) if spell else 1.0
	var aim := String(skill.get("aim", "foe"))
	var others: Array = foes if String(who["side"]) == "party" else party
	var friends: Array = party if String(who["side"]) == "party" else foes
	var targets: Array = []
	match aim:
		"foes":
			targets = alive(others)
		"party":
			targets = friends.duplicate()
		"friend":
			targets = [action.get("target", who) if action.get("target") != null else who]
		"self":
			targets = [who]
		"holder":
			# whoever carries the Lantern WHEN IT LANDS (a monster's move)
			var mark: Dictionary = lantern if others.has(lantern) and int(lantern.get("hp", 0)) > 0 else {}
			if mark.is_empty():
				var up := alive(others)
				if not up.is_empty():
					mark = up[rng.randi() % up.size()]
			if not mark.is_empty():
				targets = [mark]
		_:
			targets = [action["target"]]
	var landed := false
	var opts := {"pierce": bool(skill.get("pierce", false)), "heavy": bool(skill.get("heavy", false)), "bonus": skill.get("bonus", {})}
	for t: Dictionary in targets:
		if skill.has("heal"):
			if not friends.has(t):
				continue
			if int(t["hp"]) <= 0:
				if not skill.has("raise"):
					continue               # nobody is raised from a fall by a plain heal
				var up_with := maxi(1, roundi(float(t["max_hp"]) * float(skill["raise"])))
				t["hp"] = up_with
				events.append({"type": "heal", "who": who, "target": t, "amount": up_with, "raised": true})
				landed = true
				continue
			var amount := roundi(float(t["max_hp"]) * float(skill["heal"]) * magic * (Battles.LANTERN_LIT if lit else 1.0))
			amount = mini(amount, int(t["max_hp"]) - int(t["hp"]))
			t["hp"] = int(t["hp"]) + amount
			events.append({"type": "heal", "who": who, "target": t, "amount": amount})
			landed = landed or amount > 0
		var real: Dictionary = t
		if float(skill.get("power", 0.0)) > 0.0:
			real = _blow(who, t, float(skill["power"]) * magic, true, events, opts)
			if real.is_empty():
				continue
			landed = true
		elif skill.has("heal"):
			pass
		if int(real["hp"]) <= 0:
			continue
		# guarding keeps what a monster's blow would leave on you from sticking
		var shut := bool(real["guard"]) and String(real["side"]) != String(who["side"])
		if skill.has("stun") and others.has(real) and rng.randf() < float(skill["stun"]):
			_stun(real, 1, events)
		if skill.has("hold") and others.has(real):
			if shut:
				events.append({"type": "say", "text": String(Battles.SAY["held_off"]) % String(real["name"])})
			else:
				_stun(real, int(skill["hold"]), events)
		if skill.has("status") and not shut and (others.has(real) or real == who):
			var st: Array = skill["status"]
			if rng.randf() < float(st[1]):
				add_status(real, String(st[0]), int(skill.get("status_turns", 0)), events)
	if bool(skill.get("cleanse", false)):
		for f: Dictionary in alive(friends):
			clear_bad(f, events)
	if bool(skill.get("rally", false)):
		for f: Dictionary in alive(friends):
			f["guard"] = true
		events.append({"type": "rally", "who": who})
	if bool(skill.get("safe", false)):
		who["guard"] = true
	if lit and landed and not flare:
		_feed(events)


func _item(who: Dictionary, action: Dictionary, events: Array) -> void:
	var item: Dictionary = action["item"]
	var why := useful(who, action)
	if why != "":
		events.append({"type": "say", "text": why})
		return
	if not Supplies.take(String(item["id"])):
		events.append({"type": "say", "text": String(Battles.SAY["none_left"])})
		return
	var whole_party := String(item.get("aim", "friend")) == "party"
	var aimed: Array = alive(party) if whole_party else [action.get("target", who) if action.get("target") != null else who]
	if item.has("raise"):
		aimed = [_fallen_for(aimed[0], party if String(who["side"]) == "party" else foes)]
	var first := true
	for t: Dictionary in aimed:
		var amount := 0
		var mana := item.has("mana")
		if item.has("raise"):
			if int(t["hp"]) > 0:
				continue
			amount = maxi(1, roundi(float(t["max_hp"]) * float(item["raise"])))
			t["hp"] = amount
		elif int(t["hp"]) <= 0:
			continue
		elif bool(item.get("cure", false)):
			pass
		elif mana:
			amount = mini(roundi(float(t["max_mp"]) * float(item["mana"])), int(t["max_mp"]) - int(t["mp"]))
			t["mp"] = int(t["mp"]) + amount
		else:
			amount = mini(maxi(1, roundi(float(t["max_hp"]) * float(item["heal"]))), int(t["max_hp"]) - int(t["hp"]))
			t["hp"] = int(t["hp"]) + amount
		events.append({"type": "item", "who": who, "item": item, "target": t, "amount": amount, "mana": mana, "first": first,
			"raised": item.has("raise"), "cure": bool(item.get("cure", false))})
		first = false
		if bool(item.get("cure", false)):
			clear_bad(t, events)


## An exploder goes off: everybody on the other side, and it is gone.
func _burst(who: Dictionary, action: Dictionary, events: Array) -> void:
	var skill := {"id": "sweep", "name": String(action.get("name", "Burst")), "kind": "sword", "mana": 0, "aim": "foes",
		"power": float(action.get("power", 1.0)), "heavy": true}
	events.append({"type": "skill", "who": who, "skill": skill})
	var others: Array = foes if String(who["side"]) == "party" else party
	for t: Dictionary in alive(others):
		_blow(who, t, float(skill["power"]), true, events, {"heavy": true})
	var left := int(who["hp"])
	who["hp"] = 0
	events.append({"type": "hit", "who": who, "target": who, "amount": left, "crit": false, "dead": true, "guarded": false, "heavy": false, "lit": false, "burst": true})
	_fell(who, events)


## Makes somebody lose turns. A boss only slows down and shrugs.
func _stun(t: Dictionary, turns: int, events: Array) -> void:
	if int(t["hp"]) <= 0:
		return
	if bool(t.get("boss", false)):
		add_status(t, "slowed", 0, events)
		events.append({"type": "say", "text": String(Battles.SAY["shrug"]) % String(t["name"])})
		return
	t["stun"] = maxi(int(t["stun"]), turns)
	t["fuse"] = 0
	t["drawn"] = false
	events.append({"type": "stun", "target": t, "turns": turns})
	if order.has(t) and t.has("intent"):
		t["intent"] = {"do": {}, "target": null, "icon": "none", "text": String(Battles.SAY["intent_stunned"]), "done": false}


## One blow. Returns the fighter it LANDED on ({} = nobody stood, or it missed).
func _blow(who: Dictionary, target: Dictionary, power: float, sure: bool, events: Array, opts: Dictionary = {}) -> Dictionary:
	if int(target["hp"]) <= 0:
		# the one aimed at fell before this turn came: the blow goes to another who still stands
		var rest := alive(foes if foes.has(target) else party)
		if rest.is_empty():
			return {}
		target = rest[rng.randi() % rest.size()] if Battles.REDIRECT_RANDOM else rest[0]
	if not sure and rng.randf() < float(target.get("dodge", 0.0)):
		events.append({"type": "miss", "who": who, "target": target})
		return {}
	var crit_chance := float(who.get("crit", Battles.CRIT_CHANCE))
	for id: String in (target.get("status", {}) as Dictionary):
		crit_chance += float((Battles.STATUS.get(id, {}) as Dictionary).get("crit", 0.0))
	var crit := rng.randf() < crit_chance
	var amount := _weight(who, target, power, opts) * rng.randf_range(1.0 - Battles.SPREAD, 1.0 + Battles.SPREAD)
	if crit:
		amount *= Battles.CRIT_MULT
	var guarded := bool(target["guard"])
	if guarded:
		amount *= Battles.GUARD_TAKES
	var heavy := bool(opts.get("heavy", false))
	var dealt := mini(int(target["hp"]), maxi(1, roundi(amount)))
	target["hp"] = int(target["hp"]) - dealt
	if String(target["side"]) == "party":
		stats["taken"] = int(stats["taken"]) + dealt
	events.append({"type": "hit", "who": who, "target": target, "amount": dealt, "crit": crit, "dead": int(target["hp"]) <= 0,
		"guarded": guarded, "heavy": heavy, "lit": who == lantern})
	if target == lantern and int(target["hp"]) > 0:
		if guarded:
			if not bool(target.get("guard_fed", false)):
				target["guard_fed"] = true
				_set_flame(flame + 1, events)
		elif heavy:
			_set_flame(flame - Battles.HEAVY_UNGUARDED, events)
	if int(target["hp"]) <= 0:
		_fell(target, events)
		if who == lantern and not _fed_kill and String(target["side"]) != String(who["side"]):
			_fed_kill = true
			_set_flame(flame + Battles.FLAME_ON_KILL, events)
	else:
		_phase_check(target, events)
	return target


## A boss whose health has dropped under the next mark of its "phases" changes its ways.
func _phase_check(u: Dictionary, events: Array) -> void:
	var marks: Array = u.get("phases", [])
	if marks.is_empty() or int(u["hp"]) <= 0:
		return
	var share := float(u["hp"]) / maxf(float(u["max_hp"]), 1.0)
	var n := 1
	for m: Variant in marks:
		if share < float(m):
			n += 1
	while int(u.get("phase", 1)) < n:
		u["phase"] = int(u.get("phase", 1)) + 1
		var lines: Array = u.get("phase_say", [])
		var at := int(u["phase"]) - 2
		if at >= 0 and at < lines.size() and String(lines[at]) != "":
			events.append({"type": "say", "text": String(lines[at])})
		events.append({"type": "phase", "who": u, "n": int(u["phase"])})


# ------------------------------------------------------------------ what the monsters mean to do
## Will this monster strike EVERYBODY (or a boss land its heavy move) on its turn this round?
## (The screen warns the player: "Guard!")
func sweep_next(who: Dictionary) -> bool:
	var it: Dictionary = who.get("intent", {})
	if it.is_empty() or bool(it.get("done", false)) or int(who["hp"]) <= 0:
		return false
	var icon := String(it.get("icon", ""))
	return icon == "all" or (icon == "heavy" and bool(who.get("boss", false)))


## The intents of every monster that has not acted yet this round, the next to act first.
func intents() -> Array:
	var out: Array = []
	for u: Dictionary in alive(order):
		if String(u["side"]) == "foes" and u.has("intent"):
			out.append(u)
	return out


## Who a monster's single blow goes for: the Lantern's carrier as often as its kit says ("pull"),
## else by its kit's "aim".
func _aim(who: Dictionary) -> Dictionary:
	var standing := alive(party)
	if standing.is_empty():
		return {}
	var kit: Dictionary = who.get("kit", {})
	if int(lantern.get("hp", 0)) > 0 and standing.size() > 1 and rng.randf() < float(kit.get("pull", Battles.BOSS_PULL)):
		return lantern
	match String(kit.get("aim", "any")):
		"weak":
			var low: Dictionary = standing[0]
			for p: Dictionary in standing:
				if int(p["hp"]) < int(low["hp"]):
					low = p
			return low
		"open":
			var open := standing.filter(func(p: Dictionary) -> bool: return not bool(p["guard"]))
			if not open.is_empty():
				return open[rng.randi() % open.size()]
	return standing[rng.randi() % standing.size()]


func _intent(action: Dictionary, icon: String, text: String) -> Dictionary:
	return {"do": action, "target": action.get("target"), "icon": icon, "text": text, "done": false}


func _name(u: Variant) -> String:
	return String((u as Dictionary).get("name", "")) if u is Dictionary and not (u as Dictionary).is_empty() else String(Battles.SAY["somebody"])


## Decides, as the round begins, what this monster will do on its turn.
func _plan(who: Dictionary) -> Dictionary:
	if int(who["stun"]) > 0:
		return _intent({}, "none", String(Battles.SAY["intent_stunned"]))
	if bool(who.get("boss", false)) or not (who.get("moves", []) as Array).is_empty() or int(who.get("sweep", 0)) > 0:
		return _boss_plan(who)
	who["turns"] = int(who.get("turns", 0)) + 1
	var move: Dictionary = (who.get("kit", {}) as Dictionary).get("move", {})
	var move_name := String(move.get("name", ""))
	match String(move.get("kind", "")):
		"charge":
			if not bool(who.get("drawn", false)):
				return _intent({"do": "wait", "text": String(Battles.SAY["draws_back"]) % String(who["name"]), "then": {"drawn": true}},
					"wind", String(Battles.SAY["intent_draw"]) % move_name)
			var mark := _aim(who)
			return _intent({"do": "attack", "target": mark, "power": float(move.get("power", 1.5)), "heavy": true, "then": {"drawn": false}},
				"heavy", String(Battles.SAY["intent_heavy"]) % [move_name, _name(mark)])
		"heavy":
			if int(who["turns"]) % maxi(int(move.get("every", 3)), 1) == 0:
				var mark := _aim(who)
				return _intent({"do": "attack", "target": mark, "power": float(move.get("power", 1.5)), "heavy": true},
					"heavy", String(Battles.SAY["intent_heavy"]) % [move_name, _name(mark)])
		"fuse":
			var lit_for := int(who.get("fuse", 0))
			var need := int(move.get("fuse", 2))
			if lit_for < need:
				return _intent({"do": "wait", "text": String(Battles.SAY["hisses"]) % String(who["name"]), "then": {"fuse": lit_for + 1}},
					"fuse", String(Battles.SAY["intent_fuse"]) % (need - lit_for))
			return _intent({"do": "burst", "power": float(move.get("power", 1.4)), "name": move_name},
				"all", String(Battles.SAY["intent_burst"]) % move_name)
		"spread":
			if int(who["turns"]) % maxi(int(move.get("every", 2)), 1) == 0:
				var sk := {"id": "sweep", "name": move_name, "kind": "sword", "mana": 0, "aim": "foes", "power": float(move.get("power", 0.5))}
				if move.has("status"):
					sk["status"] = move["status"]
				return _intent({"do": "skill", "skill": sk, "target": null}, "all", String(Battles.SAY["intent_all"]) % move_name)
		"heal":
			if int(who["turns"]) % maxi(int(move.get("every", 3)), 1) == 0:
				var worst := {}
				for f: Dictionary in alive(foes):
					if float(f["hp"]) < float(f["max_hp"]) * 0.85 and (worst.is_empty() or float(f["hp"]) / float(f["max_hp"]) < float(worst["hp"]) / float(worst["max_hp"])):
						worst = f
				if not worst.is_empty():
					var sk := {"id": "mend", "name": move_name, "kind": "spell", "mana": 0, "aim": "friend", "heal": float(move.get("heal", 0.2))}
					return _intent({"do": "skill", "skill": sk, "target": worst}, "heal", String(Battles.SAY["intent_heal"]) % [move_name, _name(worst)])
	var target := _aim(who)
	return _intent({"do": "attack", "target": target}, "blow", String(Battles.SAY["intent_blow"]) % _name(target))


## A boss's turn from its script (scripts/data/boss_moves.gd); with no script, the old rule: its
## "sweep" on everybody every few turns.
func _boss_plan(who: Dictionary) -> Dictionary:
	who["turns"] = int(who.get("turns", 0)) + 1
	var turn := int(who["turns"])
	var phase := int(who.get("phase", 1))
	var rows: Array = who.get("moves", [])
	if rows.is_empty() and int(who.get("sweep", 0)) > 0:
		rows = [{"every": int(who["sweep"]), "skill": {"id": "sweep", "name": String(who.get("sweep_name", "Sweep")), "kind": "sword", "mana": 0,
			"aim": "foes", "power": float(who.get("sweep_power", 0.7)), "heavy": true},
			"intent": {"icon": "all", "text": String(Battles.SAY["intent_all"]) % String(who.get("sweep_name", "Sweep"))}}]
	for i in rows.size():
		var row: Dictionary = rows[i]
		if phase < int(row.get("from", 1)) or phase > int(row.get("until", 99)):
			continue
		if row.has("every"):
			var at := int(row.get("at", 0))
			if turn <= at or (turn - at) % maxi(int(row["every"]), 1) != 0:
				continue
		if bool(row.get("once", false)):
			if bool(who.get("used_%d" % i, false)):
				continue
			who["used_%d" % i] = true
		var skill: Dictionary = row["skill"]
		var shown: Dictionary = row.get("intent", {})
		var it := _intent({"do": "skill", "skill": skill, "target": null, "say": String(row.get("say", ""))},
			String(shown.get("icon", "heavy")), String(shown.get("text", String(skill.get("name", "")))))
		if String(skill.get("aim", "")) == "holder":
			it["target"] = lantern
		elif String(skill.get("aim", "")) == "foe":
			var mark := _aim(who)
			(it["do"] as Dictionary)["target"] = mark
			it["target"] = mark
		return it
	var target := _aim(who)
	return _intent({"do": "attack", "target": target}, "blow", String(Battles.SAY["intent_blow"]) % _name(target))


## What a monster does on its turn: what it said it would (its intent), aimed again when the one
## it meant has fallen (or, for a monster that picks the unguarded, has put a guard up).
func foe_choice(who: Dictionary) -> Dictionary:
	var it: Dictionary = who.get("intent", {})
	if it.is_empty() or bool(it.get("done", false)):
		it = _plan(who)                # (a caller that never used next(): decide now)
		who["intent"] = it
	var action: Dictionary = (it.get("do", {}) as Dictionary).duplicate()
	if action.is_empty() or not action.has("do"):
		action = {"do": "attack", "target": _aim(who)}
	if String(action["do"]) == "attack" or (String(action["do"]) == "skill" and action.get("target") != null):
		var mark: Variant = action.get("target")
		var again := not (mark is Dictionary) or (mark as Dictionary).is_empty() or int((mark as Dictionary)["hp"]) <= 0
		var friendly := mark is Dictionary and foes.has(mark)
		if not again and not friendly and String((who.get("kit", {}) as Dictionary).get("aim", "")) == "open" and bool((mark as Dictionary)["guard"]):
			again = alive(party).any(func(p: Dictionary) -> bool: return not bool(p["guard"]))
		if again:
			if friendly:
				action["target"] = who
			else:
				var mark2 := _aim(who)
				if mark2.is_empty():
					return {"do": "guard"}
				action["target"] = mark2
			it["target"] = action["target"]
	return action


# ------------------------------------------------------------------ the bot
## How much punishment a fighter can still take (health weighed by defence).
func _sturdy(u: Dictionary) -> float:
	return float(u["hp"]) * (1.0 + maxf(float(u["def"]), 0.0) / Battles.DEF_HALF)


## What the test bot (and "Auto") does for a fighter of your side. It reads the monsters'
## intents like a careful player: guards a heavy or sweeping blow when hurt or carrying the
## Lantern, hands the Lantern to the sturdiest before a heavy blow, looses a Flare at a full
## flame, raises and heals, and otherwise uses its best skill on the monster to fell first.
func auto_choice(who: Dictionary) -> Dictionary:
	var standing := alive(foes)
	if standing.is_empty():
		return {"do": "guard"}
	# what is still coming this round
	var all_coming := false
	var heavy_on_holder := false
	var heavy_on_me := false
	var must_fell := {}
	for f: Dictionary in standing:
		var it: Dictionary = f.get("intent", {})
		if (f.get("kit", {}) as Dictionary).get("move", {}).get("kind", "") == "fuse" and (must_fell.is_empty() or int(f["hp"]) < int(must_fell["hp"])):
			must_fell = f
		if it.is_empty() or bool(it.get("done", false)) or not order.has(f):
			continue
		match String(it.get("icon", "")):
			"all":
				all_coming = true
			"heavy":
				var sk: Dictionary = (it.get("do", {}) as Dictionary).get("skill", {})
				if String(sk.get("aim", "")) == "holder" or it.get("target") == lantern:
					heavy_on_holder = true
				if it.get("target") == who:
					heavy_on_me = true
	# the Lantern goes to the sturdiest before a heavy blow meant for its carrier
	if heavy_on_holder and can_take(who) and _sturdy(who) > _sturdy(lantern) * 1.15:
		var top := true
		for p: Dictionary in alive(party):
			if p != who and _sturdy(p) > _sturdy(who):
				top = false
		if top:
			_carry.append_array(take_lantern(who))
	if who == lantern and heavy_on_holder:
		heavy_on_me = true
	var hurt := 0
	var badly := 0
	var fallen := {}
	for p: Dictionary in party:
		if int(p["hp"]) <= 0:
			fallen = p
		elif float(p["hp"]) < float(p["max_hp"]) * 0.6:
			hurt += 1
			if float(p["hp"]) < float(p["max_hp"]) * 0.35:
				badly += 1
	# a Flare at a full flame
	var flare := flare_for(who)
	if not flare.is_empty():
		if flare.has("heal"):
			if not fallen.is_empty() or hurt >= 2 or badly >= 1:
				return {"do": "skill", "skill": flare, "target": who}
		else:
			var big: Dictionary = standing[0]
			for f: Dictionary in standing:
				if int(f["hp"]) > int(big["hp"]):
					big = f
			return {"do": "skill", "skill": flare, "target": big}
	# stand the fallen up
	if not fallen.is_empty() and Supplies.count("ember") > 0:
		return {"do": "item", "item": Supplies.row("ember"), "target": fallen}
	# heal who is badly hurt
	for s: Dictionary in who["skills"]:
		if s.has("heal") and can_use(who, s) and String(s.get("aim", "")) == "friend":
			for p: Dictionary in alive(party):
				if float(p["hp"]) < float(p["max_hp"]) * 0.4:
					return {"do": "skill", "skill": s, "target": p}
	if hurt >= 2 and badly >= 1 and Supplies.count("elixir") > 0:
		return {"do": "item", "item": Supplies.row("elixir"), "target": who}
	# (v0.38.0) a herb for somebody badly hurt when no spell can do it
	if Supplies.count("herb") > 0:
		for p: Dictionary in alive(party):
			if float(p["hp"]) < float(p["max_hp"]) * 0.3:
				return {"do": "item", "item": Supplies.row("herb"), "target": p}
	# guard what is coming
	if (all_coming or heavy_on_me) and (who == lantern or float(who["hp"]) < float(who["max_hp"]) * 0.6):
		return {"do": "guard"}
	# ills on two or more: salt
	if Supplies.count("salt") > 0:
		var ill := 0
		for p: Dictionary in alive(party):
			if _has_bad(p):
				ill += 1
		if ill >= 2:
			return {"do": "item", "item": Supplies.row("salt"), "target": who}
	var weakest: Dictionary = standing[0]
	for f: Dictionary in standing:
		if int(f["hp"]) < int(weakest["hp"]):
			weakest = f
	if not must_fell.is_empty():
		weakest = must_fell
	var best := {}
	var cheapest := 9999
	for s: Dictionary in who["skills"]:
		if float(s.get("power", 0.0)) <= 0.0:
			continue
		cheapest = mini(cheapest, int(s.get("mana", 0)))
		if not can_use(who, s):
			continue
		var worth := float(s["power"]) * (standing.size() if String(s["aim"]) == "foes" else 1)
		if worth > 1.3 and (best.is_empty() or worth > float(best["worth"])):
			best = {"skill": s, "worth": worth}
	if not best.is_empty():
		return {"do": "skill", "skill": best["skill"], "target": weakest}
	# out of mana with skills to use: a tonic
	if cheapest < 9999 and int(who["mp"]) < cheapest and float(who["mp"]) < float(who["max_mp"]) * 0.3 and Supplies.count("tonic") > 0:
		return {"do": "item", "item": Supplies.row("tonic"), "target": who}
	return {"do": "attack", "target": weakest}
