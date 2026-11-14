extends Node
## Plays many turn-based battles without a screen and prints how they went, to set the numbers
## in scripts/data/battles.gd and the story battles of scripts/data/tale.gd.
##   godot --headless --path . res://dev/battle_sim.tscn -- --nosave [--fights=200]
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

var rng := RandomNumberGenerator.new()


func _play(party: Array, foes: Array) -> Array:
	var f := Fight.new()
	f.setup(party, foes, rng.randi())
	while f.result() == "":
		var who := f.next()
		if who.is_empty():
			break
		if f.stunned(who):
			f.act(who, {})
		elif String(who["side"]) == "party":
			# the bot guards when a boss is about to sweep, like a player who reads the warning
			var sweeping := false
			for foe: Dictionary in f.alive(f.foes):
				sweeping = sweeping or f.sweep_next(foe)
			f.act(who, {"do": "guard"} if sweeping and float(who["hp"]) < float(who["max_hp"]) * 0.6 else f.auto_choice(who))
		else:
			f.act(who, f.foe_choice(who))
	return [f.result() == "win", f.round_no, float(f.party[0]["hp"]) / float(f.party[0]["max_hp"])]


func _line(fights: int, make: Callable) -> String:
	var wins := 0
	var rounds := 0
	var left := 0.0
	for i in fights:
		var got: Array = _play(make.call()[0], make.call()[1])
		if bool(got[0]):
			wins += 1
			left += float(got[2])
		rounds += int(got[1])
	return "%3d%% %.1fr %2d%%hp" % [roundi(100.0 * wins / fights), float(rounds) / fights, roundi(100.0 * left / maxf(wins, 1))]


## (v0.38.0) --streak: health carries over now. How many roamer battles in a row a party wins
## before it falls, starting rested with the starting pack (3 herbs, 1 tonic), never resting.
## The aim: 3 to 6 on the land of its level, so a player rests (bed, inn) every few fights.
func _streak(level: int, mates: Array, spot: int, tries: int) -> float:
	var total := 0
	Save.hub_set("rpg:lvl", level)
	for id: String in ["thessaly", "sera"]:
		Save.hub_set("ally:" + id, 1 if mates.has(id) else 0)
	for t in tries:
		Wounds.rest()
		Save.hub_set("bag:init", 1)
		Save.hub_set("bag:herb", 3)
		Save.hub_set("bag:tonic", 1)
		var won := 0
		while won < 30:
			var party := Battles.party()
			var f := Fight.new()
			f.setup(party, Battles.pack_for(spot, rng), rng.randi())
			while f.result() == "":
				var who := f.next()
				if who.is_empty():
					break
				if f.stunned(who):
					f.act(who, {})
				elif String(who["side"]) == "party":
					f.act(who, f.auto_choice(who))
				else:
					f.act(who, f.foe_choice(who))
			if f.result() != "win":
				break
			Wounds.keep(f.party)
			won += 1
		total += won
	Wounds.rest()
	return float(total) / float(tries)


func _ready() -> void:
	var fights := int(G.arg("fights", "200"))
	rng.seed = 7
	if G.flag("chain"):
		# (v0.38.0) chapter one's story battles one after the other, hurt as the last left them, with the
		# starting pack and the auto bot's use of herbs; levels as the tale tour reaches them
		for start: int in [1, 2]:
			var whole := 0
			var left := 0.0
			for t in 200:
				Wounds.rest()
				Save.hub_set("bag:init", 1)
				Save.hub_set("bag:herb", 3)
				Save.hub_set("bag:tonic", 1)
				Save.hub_set("ally:sera", 0)
				Save.hub_set("ally:thessaly", 0)
				var ok := true
				var at := 0.0
				Save.hub_set("rpg:lvl", start)
				Save.hub_set("rpg:xp", 0)
				for row: Array in [["glade", start, false], ["deepwood", start, true], ["giant", start, true]]:
					Save.hub_set("ally:thessaly", 1 if bool(row[2]) else 0)
					var spec := Battles.scripted(String(row[0]))
					var f := Fight.new()
					f.setup(spec["party"], spec["foes"], rng.randi())
					f.no_flee = true
					while f.result() == "":
						var who := f.next()
						if who.is_empty():
							break
						if f.stunned(who):
							f.act(who, {})
						elif String(who["side"]) == "party":
							var sweeping := false
							for foe: Dictionary in f.alive(f.foes):
								sweeping = sweeping or f.sweep_next(foe)
							f.act(who, {"do": "guard"} if sweeping and float(who["hp"]) < float(who["max_hp"]) * 0.6 else f.auto_choice(who))
						else:
							f.act(who, f.foe_choice(who))
					if f.result() != "win":
						ok = false
						break
					at = float(f.party[0]["hp"]) / float(f.party[0]["max_hp"])
					Wounds.keep(f.party)
					var gain := Battles.reward(f.foes, int(spec["tier"]))
					if Rpg.add_xp(int(gain["xp"]) + int(spec["xp_bonus"])) > 0:
						Wounds.rest()                   # a new level makes everybody whole (as in the game)
				if ok:
					whole += 1
					left += at
			print("(giant met at level %d) " % Rpg.level() + "chapter one in a row from level %d: %d%% win all three, knight ends at %d%% hp" % [start, whole / 2, roundi(100.0 * left / maxf(whole, 1))])
		G.quit(0)
		return
	if G.flag("streak"):
		var lands := {"grass": 0, "robbers": 4, "sand": 5, "rock": 10}
		for row: Array in [[1, []], [2, []], [3, ["thessaly"]], [5, ["thessaly"]], [7, ["thessaly"]], [9, ["thessaly", "sera"]], [12, ["thessaly", "sera"]]]:
			var line := "level %2d +%d:" % [int(row[0]), (row[1] as Array).size()]
			for kind: String in lands:
				line += "  %s %4.1f" % [kind, _streak(int(row[0]), row[1], int(lands[kind]), 60)]
			print(line)
		G.quit(0)
		return
	var spots := {"grass": 0, "robbers": 4, "sand": 5, "rock": 10}
	for level: int in [1, 2, 4, 7, 10, 14]:
		Save.hub_set("rpg:lvl", level)
		for mates: Array in [[], ["thessaly"], ["thessaly", "sera"]]:
			for id: String in ["thessaly", "sera"]:
				Save.hub_set("ally:" + id, 1 if mates.has(id) else 0)
			var line := "level %2d +%d:" % [level, mates.size()]
			for kind: String in spots:
				line += "  %s %s" % [kind, _line(fights, func() -> Array: return [Battles.party(), Battles.pack_for(int(spots[kind]), rng)])]
			print(line)
	# TARGETS (the rule of thumb for RPG numbers): at his own level the knight should fell a
	# common monster in 2 to 4 blows and stand 5 to 9 of its blows. "!" marks a row outside that.
	print("--- blows to fell a common monster / blows the knight can take, by level and land (tier)")
	Save.hub_set("ally:sera", 0)
	Save.hub_set("ally:thessaly", 0)
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
	print("--- the story's battles")
	for row: Array in [["glade", [1, 2, 3], []], ["deepwood", [1, 2, 3, 4], ["thessaly"]], ["giant", [2, 3, 4, 5, 6], ["thessaly"]]]:
		var line := "%-9s" % String(row[0])
		Save.hub_set("ally:sera", 0)
		Save.hub_set("ally:thessaly", 1 if (row[2] as Array).has("thessaly") else 0)
		for level: int in row[1]:
			Save.hub_set("rpg:lvl", level)
			line += "  L%d %s" % [level, _line(fights, func() -> Array:
				var spec := Battles.scripted(String(row[0]))
				return [spec["party"], spec["foes"]])]
		print(line)
	G.quit(0)
