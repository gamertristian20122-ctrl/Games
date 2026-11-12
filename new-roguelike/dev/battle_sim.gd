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


func _ready() -> void:
	var fights := int(G.arg("fights", "200"))
	rng.seed = 7
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
