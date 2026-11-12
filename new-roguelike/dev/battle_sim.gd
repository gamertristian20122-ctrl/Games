extends Node
## Plays many turn-based battles without a screen and prints how they went, to set the numbers
## in scripts/data/battles.gd.
##   godot --headless --path . res://dev/battle_sim.tscn -- --nosave [--fights=200]
## For each knight level it prints: wins out of the fights, rounds a battle took, and how much
## of his health the knight had left, alone and with Seraphine, against each land's monsters.

const Fight = preload("res://scripts/battle/fight.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Allies = preload("res://scripts/data/allies.gd")


func _ready() -> void:
	var fights := int(G.arg("fights", "200"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := {"grass": 0, "robbers": 4, "sand": 5, "rock": 10}
	for level: int in [1, 2, 4, 7, 10, 14]:
		Save.hub_set("rpg:lvl", level)
		for with_ally: bool in [false, true]:
			if with_ally:
				Allies.join("sera")
				Allies.set_with("sera")
			else:
				Allies.set_with("")
			var line := "level %2d %s:" % [level, "with Sera" if with_ally else "alone    "]
			for kind: String in spots:
				var wins := 0
				var rounds := 0
				var left := 0.0
				for i in fights:
					var f := Fight.new()
					f.setup(Battles.party(), Battles.pack_for(int(spots[kind]), rng), rng.randi())
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
					if f.result() == "win":
						wins += 1
						left += float(f.party[0]["hp"]) / float(f.party[0]["max_hp"])
					rounds += f.round_no
				line += "  %s %3d%% %.1fr %2d%%hp" % [kind, roundi(100.0 * wins / fights), float(rounds) / fights, roundi(100.0 * left / maxf(wins, 1))]
			print(line)
	G.quit(0)
