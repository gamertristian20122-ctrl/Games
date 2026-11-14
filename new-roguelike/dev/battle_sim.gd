extends Node
## Plays many turn-based battles without a screen and prints how they went, to set the numbers
## in scripts/data/battles.gd and the story battles of scripts/data/tale.gd.
##   godot --headless --path . res://dev/battle_sim.tscn -- --nosave [--fights=200] [--mode=story|normal|hard]
##   ... -- --nosave --chain     each chapter's story battles in a row, wounds carried over
##   ... -- --nosave --streak    wild fights in a row before a fall
##   ... -- --nosave --rules     checks of the rules themselves (the Lantern, statuses, intents,
##                               boss scripts, items, deeds); prints "[rules] n checks, k failed"
## First the roamers of each land, by knight level, alone and with companions; then every battle
## of the story at the levels a player is likely to meet it. For each: wins out of the fights,
## rounds a battle took, and how much of his health the knight had left when he won.

const Fight = preload("res://scripts/battle/fight.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Wounds = preload("res://scripts/data/wounds.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Supplies = preload("res://scripts/data/supplies.gd")

var rng := RandomNumberGenerator.new()


## One whole fight, played by the rules' own bot (fight.gd auto_choice: it reads the monsters'
## intents, guards, passes the Lantern, looses Flares, uses the pack) against the monsters' kits.
func _run(f: RefCounted) -> void:
	var guard := 0
	while String(f.call("result")) == "" and guard < 4000:
		guard += 1
		var who: Dictionary = f.call("next")
		if who.is_empty():
			break
		if bool(f.call("stunned", who)):
			f.call("act", who, {})
		elif String(who["side"]) == "party":
			f.call("act", who, f.call("auto_choice", who))
		else:
			f.call("act", who, f.call("foe_choice", who))


## [won, rounds, knight's health share, party's health share, Flares, how many of yours fell]
func _play(party: Array, foes: Array, boss: bool = false) -> Array:
	var f := Fight.new()
	f.setup(party, foes, rng.randi())
	f.no_flee = boss
	_run(f)
	var have := 0.0
	var full := 0.0
	for u: Dictionary in f.party:
		have += float(u["hp"])
		full += float(u["max_hp"])
	return [f.result() == "win", f.round_no, float(f.party[0]["hp"]) / float(f.party[0]["max_hp"]), have / maxf(full, 1.0),
		int(f.stats["flares"]), int(f.stats["fell"])]


## "wins%  rounds  party health left when won  Flares a fight  falls a fight"
func _line(fights: int, make: Callable, boss: bool = false) -> String:
	var wins := 0
	var rounds := 0
	var left := 0.0
	var flares := 0
	var fell := 0
	for i in fights:
		_pack()
		var made: Array = make.call()
		var got: Array = _play(made[0], made[1], boss)
		if bool(got[0]):
			wins += 1
			left += float(got[3])
		rounds += int(got[1])
		flares += int(got[4])
		fell += int(got[5])
	return "%3d%% %4.1fr %2d%%hp %.1ffl %.1ffell" % [roundi(100.0 * wins / fights), float(rounds) / fights, roundi(100.0 * left / maxf(wins, 1)),
		float(flares) / fights, float(fell) / fights]


## The pack a careful player carries (so the bot's use of supplies is measured too).
func _pack() -> void:
	Save.hub_set("bag:init", 1)
	Save.hub_set("bag:herb", 3)
	Save.hub_set("bag:tonic", 1)
	Save.hub_set("bag:elixir", 0)
	Save.hub_set("bag:ember", 0)
	Save.hub_set("bag:salt", 0)


func _mates(mates: Array) -> void:
	for id: String in ["thessaly", "sera", "grukk"]:
		Save.hub_set("ally:" + id, 1 if mates.has(id) else 0)


## (v0.38.0) --streak: health carries over now. How many roamer battles in a row a party wins
## before it falls, starting rested with the starting pack (3 herbs, 1 tonic), never resting.
## The aim: 3 to 6 on the land of its level, so a player rests (bed, inn) every few fights.
func _streak(level: int, mates: Array, spot: int, tries: int) -> float:
	var total := 0
	Save.hub_set("rpg:lvl", level)
	_mates(mates)
	for t in tries:
		Wounds.rest()
		_pack()
		var won := 0
		while won < 30:
			var party := Battles.party()
			var f := Fight.new()
			f.setup(party, Battles.pack_for(spot, rng), rng.randi())
			_run(f)
			if f.result() != "win":
				break
			Wounds.keep(f.party)
			won += 1
		total += won
	Wounds.rest()
	return float(total) / float(tries)


var _checks := 0
var _failed := 0


func _ok(what: String, good: bool) -> void:
	_checks += 1
	if not good:
		_failed += 1
	print("[rules] %s %s" % ["ok  " if good else "FAIL", what])


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return String(e["type"]))


## Small checks of the rules of scripts/battle/fight.gd, each on a fight set up by hand.
func _rules() -> void:
	Save.hub_set("rpg:lvl", 6)
	_mates(["thessaly", "sera", "grukk"])
	_pack()
	Save.hub_set("bag:ember", 1)
	Save.hub_set("bag:salt", 1)
	Wounds.rest()
	var f := Fight.new()
	var party := Battles.party()
	var foes: Array = [Battles.foe("wood_beast", 0), Battles.foe("lantern_head", 0), Battles.foe("elf_stalker", 0), Battles.foe("magma_heart", 0)]
	f.setup(party, foes, 11)
	var knight: Dictionary = party[0]
	var sera: Dictionary = party.filter(func(u: Dictionary) -> bool: return String(u["id"]) == "sera")[0]
	var grukk: Dictionary = party.filter(func(u: Dictionary) -> bool: return String(u["id"]) == "grukk")[0]
	_ok("the knight carries the Lantern at the start, flame 0", f.lantern == knight and f.flame == 0)
	var first: Dictionary = f.next()
	_ok("a round is rolled, and the next one too", f.round_no == 1 and f.upcoming_next().size() == 8 and not first.is_empty())
	_ok("every monster has an intent with an icon and words", foes.all(func(u: Dictionary) -> bool:
		return u.has("intent") and String(u["intent"]["icon"]) != "" and String(u["intent"]["text"]) != ""))
	_ok("a charger draws back first (wind)", String(foes[0]["intent"]["icon"]) == "wind")
	_ok("an exploder hisses first (fuse)", String(foes[1]["intent"]["icon"]) == "fuse")
	# the Lantern: taking it is free and once a round
	_ok("the carrier cannot take it; another can", not f.can_take(knight) and f.can_take(grukk))
	var took: Array = f.take_lantern(grukk)
	_ok("taking gives a lantern event and moves it", took.size() == 1 and String(took[0]["type"]) == "lantern" and f.lantern == grukk)
	_ok("only once a round", not f.can_take(knight) and f.take_lantern(knight).is_empty())
	# lit blows, flame, preview
	var mark: Dictionary = foes[0]
	var lit: Array = f.preview(grukk, mark, 1.0)
	f.lantern = knight
	var unlit: Array = f.preview(grukk, mark, 1.0)
	_ok("the carrier's blow is about a quarter harder (%s against %s)" % [lit, unlit], int(lit[0]) > int(unlit[0]) and int(lit[1]) >= int(lit[0]))
	var ev: Array = f.act(knight, {"do": "attack", "target": foes[2]})
	_ok("the carrier's blow feeds the flame; a known event comes first (%s)" % [_types(ev)], f.flame >= 1 and ["hit", "miss"].has(String(ev[0]["type"])))
	_ok("no Flare before the flame is full", f.flare_for(knight).is_empty())
	f.flame = Battles.FLAME_MAX
	var flare: Dictionary = f.flare_for(knight)
	_ok("a Flare at a full flame, none for the others", not flare.is_empty() and f.flare_for(sera).is_empty())
	var hp0 := int(mark["hp"])
	ev = f.act(knight, {"do": "skill", "skill": flare, "target": mark})
	_ok("the Flare lands, costs no mana, puts the flame out (%s)" % [_types(ev)], int(mark["hp"]) < hp0 and f.flame == 0 and int(f.stats["flares"]) == 1 and String(ev[0]["type"]) == "skill")
	# statuses
	mark["hp"] = int(mark["max_hp"])
	ev = []
	f.add_status(mark, "burn", 0, ev)
	f.add_status(mark, "exposed", 0, ev)
	_ok("statuses go on with events", f.has_status(mark, "burn") and f.has_status(mark, "exposed") and ev.size() == 2 and String(ev[0]["type"]) == "status")
	mark["hp"] = int(mark["max_hp"])
	hp0 = int(mark["hp"])
	ev = f.act(mark, f.foe_choice(mark))
	_ok("burning hurts at the start of its turn and is never the first event (%s)" % [_types(ev)], int(mark["hp"]) < hp0 and String(ev[0]["type"]) != "burn" and _types(ev).has("burn"))
	var exposed_pv: Array = f.preview(sera, mark, 1.0)
	mark["status"] = {}
	_ok("exposed takes more", int(exposed_pv[0]) > int((f.preview(sera, mark, 1.0) as Array)[0]))
	ev = []
	f.add_status(knight, "weak", 0, ev)
	var weak_pv: Array = f.preview(knight, mark, 1.0)
	knight["status"] = {}
	_ok("weak hits lighter", int(weak_pv[1]) < int((f.preview(knight, mark, 1.0) as Array)[1]))
	ev = []
	f.add_status(foes[2], "slowed", 0, ev)
	_ok("slowed acts last next round", f.upcoming_next().back() == foes[2])
	# a stun puts a fuse out
	foes[1]["fuse"] = 1
	ev = []
	f._stun(foes[1], 1, ev)
	_ok("a stun puts the fuse out", int(foes[1]["fuse"]) == 0 and f.stunned(foes[1]))
	# items: not wasted
	var herbs := Supplies.count("herb")
	knight["hp"] = int(knight["max_hp"])
	ev = f.act(sera, {"do": "item", "item": Supplies.row("herb"), "target": knight})
	_ok("a herb on somebody whole is not taken (%s)" % String(ev[0].get("text", "")), Supplies.count("herb") == herbs and String(ev[0]["type"]) == "say")
	_ok("useful() says why", f.useful(sera, {"do": "item", "item": Supplies.row("ember"), "target": knight}) != "")
	grukk["hp"] = 0
	ev = f.act(sera, {"do": "item", "item": Supplies.row("ember"), "target": grukk})
	_ok("a Waking Ember stands the fallen up", int(grukk["hp"]) > 0 and Supplies.count("ember") == 0)
	ev = []
	f.add_status(knight, "burn", 0, ev)
	ev = f.act(sera, {"do": "item", "item": Supplies.row("salt"), "target": sera})
	_ok("Cleansing Salt takes the burning off", not f.has_status(knight, "burn") and Supplies.count("salt") == 0)
	# guarding keeps a monster's status off, and feeds the flame when the carrier is struck
	f.lantern = knight
	f.flame = 0
	knight["guard"] = true
	knight["guard_fed"] = false
	ev = []
	f._blow(foes[3], knight, 1.0, true, ev, {"heavy": true})
	_ok("struck while guarding: flame +1", f.flame == 1)
	knight["guard"] = false
	ev = []
	f._blow(foes[3], knight, 1.0, true, ev, {"heavy": true})
	_ok("a heavy blow unguarded: flame -1", f.flame == 0)
	# the carrier falls: the Lantern passes on
	f.flame = 2
	knight["hp"] = 1
	ev = []
	f._blow(foes[3], knight, 5.0, true, ev, {})
	_ok("the carrier falls: flame out, the Lantern passes on", f.flame == 0 and f.lantern != knight and int(f.lantern["hp"]) > 0 and int(f.stats["fell"]) >= 1)
	# a boss: script, phases, no stun
	Save.hub_set("rpg:lvl", 9)
	var spec := Battles.scripted("colossus")
	var b := Fight.new()
	b.setup(spec["party"], spec["foes"], 5)
	var boss: Dictionary = spec["foes"][0]
	_ok("scripted() hands out the win row and a boss with a script", spec.has("win") and not (boss["moves"] as Array).is_empty())
	b.next()
	ev = []
	b._stun(boss, 1, ev)
	_ok("a boss shrugs a stun off and is slowed instead", not b.stunned(boss) and b.has_status(boss, "slowed") and _types(ev).has("say"))
	boss["hp"] = roundi(float(boss["max_hp"]) * 0.62)
	ev = []
	b._blow(spec["party"][0], boss, 1.0, true, ev, {})
	_ok("under 60%%: a phase event, after the hit (%s)" % [_types(ev)], int(boss["phase"]) == 2 and _types(ev).has("phase") and String(ev[0]["type"]) == "hit")
	var heart: Dictionary = spec["foes"][1]
	var before := int(boss["hp"])
	ev = b.act(boss, b.foe_choice(boss))
	_ok("the Magma Heart heats it again (%d to %d), still a known first event (%s)" % [before, int(boss["hp"]), _types(ev)],
		_types(ev).has("heal") and ["hit", "miss", "skill", "say"].has(String(ev[0]["type"])))
	heart["hp"] = 0
	before = int(boss["hp"])
	b.act(boss, {"do": "wait", "text": ""})
	_ok("no heart, no heat", int(boss["hp"]) == before)
	# modes and deeds
	Battles.mode_force = "story"
	var soft := int(Battles.foe("thorn_elf", 0)["max_hp"])
	Battles.mode_force = "hard"
	var tough := int(Battles.foe("thorn_elf", 0)["max_hp"])
	Battles.mode_force = "normal"
	_ok("modes change the monsters (%d story, %d hard)" % [soft, tough], soft < tough)
	_ok("deeds: swift, unbroken, lit", Battles.deeds({"rounds": 2, "fell": 0, "flares": 1, "boss": false}, 3) == ["swift", "unbroken", "lit"])
	var plain: Dictionary = Battles.reward([{"xp": 100, "coins": 100}], 0)
	var praised: Dictionary = Battles.reward([{"xp": 100, "coins": 100}], 0, {"rounds": 1, "fell": 0, "flares": 1})
	_ok("each deed adds 15%% (%d to %d xp)" % [int(plain["xp"]), int(praised["xp"])], int(praised["xp"]) == roundi(float(plain["xp"]) * 1.45) and (praised["deeds"] as Array).size() == 3)
	_ok("a story row that does not exist is empty, not a crash", Battles._story_row("BOSSES", "nobody").is_empty())
	_mates([])
	Wounds.rest()
	print("[rules] %d checks, %d failed" % [_checks, _failed])
	G.quit(1 if _failed > 0 else 0)


func _ready() -> void:
	var fights := int(G.arg("fights", "200"))
	rng.seed = 7
	# --mode=story|normal|hard: how hard the monsters are (Battles.MODE); nothing = normal
	Battles.mode_force = G.arg("mode", "normal")
	print("=== battle sim, mode %s (x%.2f monster health and attack)" % [Battles.mode(), Battles.mode_mult()])
	if G.flag("rules"):
		_rules()
		return
	if G.flag("chain"):
		# the story's battles of each chapter one after the other, hurt as the last left them, with the
		# starting pack and the bot's use of it; levels as the tale tour reaches them. A new level
		# makes everybody whole, as in the game.
		var chapters := [
			["chapter one", [1, 2], [], [["glade", ["thessaly"]], ["deepwood", ["thessaly"]], ["giant", ["thessaly"]]]],
			["chapter two", [4, 5], ["thessaly"], [["dustwall", ["thessaly", "sera"]], ["gorgon", ["thessaly", "sera"]]]],
			["chapter three", [7, 8], ["thessaly", "sera", "grukk"], [["pass", ["thessaly", "sera", "grukk"]], ["forgedoor", ["thessaly", "sera", "grukk"]],
				["ashstair", ["thessaly", "sera", "grukk"]], ["colossus", ["thessaly", "sera", "grukk"]]]],
		]
		for ch: Array in chapters:
			for start: int in ch[1]:
				var whole := 0
				var left := 0.0
				var rounds := {}
				var tries := 200
				var end_level := 0
				for t in tries:
					Wounds.rest()
					_pack()
					_mates(ch[2])
					var ok := true
					var at := 0.0
					Save.hub_set("rpg:lvl", start)
					Save.hub_set("rpg:xp", 0)
					for row: Array in ch[3]:
						var spec := Battles.scripted(String(row[0]))
						var f := Fight.new()
						f.setup(spec["party"], spec["foes"], rng.randi())
						f.no_flee = true
						_run(f)
						rounds[row[0]] = int(rounds.get(row[0], 0)) + int(f.round_no)
						if f.result() != "win":
							ok = false
							break
						at = float(f.party[0]["hp"]) / float(f.party[0]["max_hp"])
						Wounds.keep(f.party)
						_mates(row[1])               # who has joined after this battle
						var gain := Battles.reward(f.foes, int(spec["tier"]), f.stats)
						if Rpg.add_xp(int(gain["xp"]) + int(spec["xp_bonus"])) > 0:
							Wounds.rest()                   # a new level makes everybody whole (as in the game)
					end_level += Rpg.level()
					if ok:
						whole += 1
						left += at
				var per := ""
				for id: String in rounds:
					per += " %s %.1fr" % [id, float(rounds[id]) / tries]
				print("%s in a row from level %d: %d%% win all, knight ends at %d%% hp, level %.1f at the end; %s" % [String(ch[0]), start,
					roundi(100.0 * whole / tries), roundi(100.0 * left / maxf(whole, 1)), float(end_level) / tries, per])
		_mates([])
		G.quit(0)
		return
	if G.flag("streak"):
		var lands := {"grass": 0, "robbers": 4, "sand": 5, "rock": 10}
		for row: Array in [[1, []], [2, []], [3, ["thessaly"]], [5, ["thessaly"]], [7, ["thessaly"]], [9, ["thessaly", "sera"]], [12, ["thessaly", "sera", "grukk"]]]:
			var line := "level %2d +%d:" % [int(row[0]), (row[1] as Array).size()]
			for kind: String in lands:
				line += "  %s %4.1f" % [kind, _streak(int(row[0]), row[1], int(lands[kind]), 60)]
			print(line)
		G.quit(0)
		return
	print("--- wild packs: wins, rounds, party health left when won, Flares a fight, falls a fight (aim: 3 to 5 rounds)")
	var spots := {"grass": 0, "robbers": 4, "sand": 5, "rock": 10}
	for level: int in [1, 2, 4, 7, 10, 14]:
		Save.hub_set("rpg:lvl", level)
		for mates: Array in [[], ["thessaly"], ["thessaly", "sera"], ["thessaly", "sera", "grukk"]]:
			_mates(mates)
			var line := "level %2d +%d:" % [level, mates.size()]
			for kind: String in spots:
				line += "  %s %s" % [kind, _line(fights, func() -> Array: return [Battles.party(), Battles.pack_for(int(spots[kind]), rng)])]
			print(line)
	# TARGETS (the rule of thumb for RPG numbers): at his own level the knight should fell a
	# common monster in 2 to 4 blows and stand 5 to 9 of its blows. "!" marks a row outside that.
	print("--- blows to fell a common monster / blows the knight can take, by level and land (tier)")
	_mates([])
	for level: int in [1, 3, 5, 8, 12]:
		Save.hub_set("rpg:lvl", level)
		var k := Battles.knight()
		var line := "level %2d:" % level
		for row: Array in [["thorn_elf", 0], ["bandit_cutter", 1], ["dust_mummy", 1], ["rubble_walker", 2]]:
			var f := Battles.foe(String(row[0]), int(row[1]))
			var to_fell := float(f["max_hp"]) / maxf(float(k["atk"]) * Battles.DEF_HALF / (Battles.DEF_HALF + float(f["def"])), 1.0)
			var to_fall := float(k["max_hp"]) / maxf(float(f["atk"]) * Battles.DEF_HALF / (Battles.DEF_HALF + float(k["def"])), 1.0)
			var odd := to_fell < 1.5 or to_fell > 4.5 or to_fall < 4.5 or to_fall > 10.0
			line += "  tier%d %.1f/%.1f%s" % [int(row[1]), to_fell, to_fall, "!" if odd else ""]
		print(line)
	print("--- the story's battles, rested, at the levels a player meets them (aim: bosses 8 to 12 rounds)")
	var three := ["thessaly", "sera", "grukk"]
	for row: Array in [["glade", [1, 2, 3], []], ["deepwood", [1, 2, 3, 4], ["thessaly"]], ["giant", [2, 3, 4, 5], ["thessaly"]],
			["dustwall", [4, 5, 6], ["thessaly"]], ["gorgon", [5, 6, 7], ["thessaly", "sera"]],
			["pass", [7, 8, 9], three], ["forgedoor", [7, 8, 9], three], ["ashstair", [8, 9, 10], three], ["colossus", [8, 9, 10], three]]:
		var line := "%-9s" % String(row[0])
		_mates(row[2])
		for level: int in row[1]:
			Save.hub_set("rpg:lvl", level)
			line += "  L%d %s" % [level, _line(fights, func() -> Array:
				var spec := Battles.scripted(String(row[0]))
				return [spec["party"], spec["foes"]], true)]
		print(line)
	_mates([])
	G.quit(0)
