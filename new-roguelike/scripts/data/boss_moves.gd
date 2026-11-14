extends RefCounted
## BOSS SCRIPTS: what each boss of the story does, turn by turn and phase by phase.
## Use with:  const BossMoves = preload("res://scripts/data/boss_moves.gd")
## scripts/data/battles.gd boss() puts a boss's rows on the fighter ("moves", "phases", "regen");
## scripts/battle/fight.gd _boss_plan() reads them. A boss with no row here keeps the old rule
## (its "sweep" of scripts/data/tale.gd BOSSES: everybody, every few turns).
##
## A boss:
##   "hp", "atk" multipliers on the numbers of its row in tale.gd BOSSES (the story file is not
##              touched by the rules pass; tune a boss here)
##   "phases"   health shares at which the next phase begins: [0.6, 0.3] = phase 2 under 60%,
##              phase 3 under 30%
##   "phase_say" what the screen says when phase 2, 3 .. begins (one line each)
##   "regen"    {"while": monster id, "share": 0.08, "say": words}: as long as one of those stands
##              beside it, the boss gets that share of its health back at each of its turns
##   "moves"    rows tried from the top on each of its turns; the first that fits is used, and when
##              none fits it strikes one of you (the Lantern's holder most often):
##       "from", "until"   the phases it is used in (1 = the start; left out = always)
##       "every", "at"     on every "every"-th turn of the boss (counted from "at", default 0)
##       "once"            only one time (the first turn it fits)
##       "skill"           what it does: a skill row as in battles.gd SKILL, plus
##                           "aim": "holder"   whoever carries the Lantern WHEN IT LANDS
##                           "hold": turns     the one hit loses that many turns, unless guarding
##                           "status": [id, chance]   as for the party's skills
##                         its "id" must be a move the screen can already show ("sweep" = the red
##                         rings on everybody, "gaze" / anything else = a cast at one fighter)
##       "say"             a line shown as it does it
##       "intent"          {"icon", "text"}: what the player is told at the start of the round.
##                         icons: blow | all | heavy | fuse | heal | wind
## No boss calls helpers in the middle of a fight: the screen cannot seat a new fighter.
## Words are placeholders the owner may rewrite; the numbers are bot-measured first guesses.

const MOVES := {
	# Old Bramblejaw: the lesson boss. Guard the sweep; in phase 2 keep the Lantern with somebody
	# who guards when the briars reach.
	"bramblejaw": {
		"phases": [0.5],
		"phase_say": ["Bramblejaw tears its roots out of the ground."],
		"moves": [
			{"every": 3, "skill": {"id": "sweep", "name": "Briar Sweep", "kind": "sword", "mana": 0, "aim": "foes", "power": 0.75, "heavy": true},
				"intent": {"icon": "all", "text": "Briar Sweep: everybody. Guard!"}},
			{"from": 2, "every": 3, "at": 1, "skill": {"id": "grasp", "name": "Briar Grasp", "kind": "spell", "mana": 0, "aim": "holder", "power": 0.8, "hold": 1, "heavy": true},
				"say": "Briars reach for the light.",
				"intent": {"icon": "heavy", "text": "Briar Grasp: holds the Lantern's bearer a turn, unless they guard."}},
		]},
	# The Dune Gorgon: the Lantern boss. Her gaze goes to whoever holds the light when it lands.
	"gorgon": {
		"hp": 1.15,
		"phases": [0.5],
		"phase_say": ["The Gorgon's eyes open wide."],
		"moves": [
			{"until": 1, "every": 3, "skill": {"id": "gaze", "name": "Stone Gaze", "kind": "spell", "mana": 0, "aim": "holder", "power": 0.7, "hold": 2, "heavy": true},
				"say": "The Gorgon looks into the light.",
				"intent": {"icon": "heavy", "text": "Stone Gaze: turns the Lantern's bearer to stone for two turns, unless they guard."}},
			{"from": 2, "every": 2, "skill": {"id": "gaze", "name": "Stone Gaze", "kind": "spell", "mana": 0, "aim": "holder", "power": 0.8, "hold": 2, "heavy": true},
				"say": "The Gorgon looks into the light.",
				"intent": {"icon": "heavy", "text": "Stone Gaze: turns the Lantern's bearer to stone for two turns, unless they guard."}},
			{"from": 2, "every": 4, "at": 1, "skill": {"id": "sweep", "name": "Serpent Lash", "kind": "sword", "mana": 0, "aim": "foes", "power": 0.6, "heavy": true},
				"intent": {"icon": "all", "text": "Serpent Lash: everybody. Guard!"}},
		]},
	# The Ember Colossus: fell the Magma Heart first or it heats itself whole again; its wave
	# burns in phase 2; at a third of its health it must vent, and stands open for a turn.
	"colossus": {
		"hp": 1.45, "atk": 1.1,
		"phases": [0.6, 0.3],
		"phase_say": ["The Colossus glows white at the seams.", "The Colossus is cracking. It must vent."],
		"regen": {"while": "magma_heart", "share": 0.08, "say": "The Magma Heart heats the Colossus again."},
		"moves": [
			{"from": 3, "once": true, "skill": {"id": "vent", "name": "Vent", "kind": "spell", "mana": 0, "aim": "self", "power": 0.0, "status": ["exposed", 1.0], "status_turns": 1},
				"say": "The Colossus vents. Its plates stand open!",
				"intent": {"icon": "wind", "text": "Venting: it does nothing, and stands open. Strike now!"}},
			{"until": 1, "every": 3, "skill": {"id": "sweep", "name": "Slag Wave", "kind": "sword", "mana": 0, "aim": "foes", "power": 0.7, "heavy": true},
				"intent": {"icon": "all", "text": "Slag Wave: everybody. Guard!"}},
			{"from": 2, "every": 3, "skill": {"id": "sweep", "name": "Slag Wave", "kind": "sword", "mana": 0, "aim": "foes", "power": 0.7, "heavy": true, "status": ["burn", 0.6]},
				"intent": {"icon": "all", "text": "Slag Wave: everybody, and it burns. Guard!"}},
		]},
}
