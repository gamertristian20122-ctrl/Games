extends RefCounted
## MONSTER KITS: what each KIND of monster does in a turn-based battle, so a pack is something to
## read and answer instead of a row of health bars. The kind is the "ai" field of the monster's row
## in scripts/data/enemies.gd (it named its real-time behaviour once; the battle gives it the same
## character). Use with:  const FoeKits = preload("res://scripts/data/foe_kits.gd")
##
## scripts/data/battles.gd foe() folds a kit into the monster; scripts/battle/fight.gd plays it
## (see _plan there). The player SEES what every monster means to do this round (its "intent").
##
## A kit row:
##   "atk", "hp"   multipliers on the monster's battle attack and health
##   "def"         defence added          "dodge"  chance a blow misses it
##   "pull"        how often its single blows go for whoever carries the Lantern (0 to 1; the rest
##                 go for "aim")
##   "aim"         who it goes for otherwise: "any" | "weak" (lowest health) | "open" (somebody who
##                 is not guarding; it changes its mind when its mark guards)
##   "move"        its special move (all optional):
##       "kind"    "heavy"  every "every"-th turn a blow of "power" (the turn before it shows)
##                 "charge" turn about: draws back (does nothing), then a blow of "power"
##                 "fuse"   hisses for "fuse" turns, then bursts: "power" on everybody, and it dies.
##                          A kill stops it; a stun puts the fuse out (it starts again).
##                 "spread" every "every"-th turn: "power" on everybody, "status" [id, chance]
##                 "heal"   every "every"-th turn gives a hurt friend "heal" of its health back
##       "name"    what the move is called on the screen
##   "line"        one line for the screen's inspect plate (a rule, in plain words)
## BY_ID overrules single keys for one monster id (a kit row laid over its kind's).
## All numbers are first guesses measured with dev/battle_sim.tscn. Words are placeholders.

const DEFAULT := {"atk": 1.0, "hp": 1.0, "def": 0.0, "dodge": 0.0, "pull": 0.65, "aim": "any", "move": {},
	"line": "Strikes one of you each turn."}

const KIT := {
	"chaser": {"atk": 1.0, "hp": 1.0, "pull": 0.35, "aim": "weak",
		"line": "Hunts whoever is weakest. The Lantern draws it less than most."},
	"shooter": {"atk": 0.95, "hp": 0.9, "pull": 0.0, "aim": "open",
		"line": "Ignores the Lantern. Shoots somebody who is not guarding."},
	"charger": {"atk": 1.0, "hp": 1.05, "pull": 0.65, "aim": "any",
		"move": {"kind": "charge", "power": 2.1, "name": "Charge"},
		"line": "Draws back one turn, then charges for double. Guard, or stun it first."},
	"flyer": {"atk": 0.9, "hp": 0.85, "dodge": 0.25, "pull": 0.5, "aim": "any",
		"line": "Hard to hit: one blow in four misses it. Skills never miss."},
	"brute": {"atk": 1.0, "hp": 1.0, "def": 6.0, "pull": 0.75, "aim": "any",
		"move": {"kind": "heavy", "every": 3, "power": 1.7, "name": "Crushing Blow"},
		"line": "Thick hide. Every third turn a crushing blow at one of you."},
	"exploder": {"atk": 0.8, "hp": 0.9, "pull": 0.5, "aim": "any",
		"move": {"kind": "fuse", "fuse": 1, "power": 1.4, "name": "Burst"},
		"line": "Hisses for a turn, then bursts on everybody. Fell it, or stun it to put the fuse out."},
	"spreader": {"atk": 0.9, "hp": 1.0, "pull": 0.5, "aim": "any",
		"move": {"kind": "spread", "every": 2, "power": 0.55, "status": ["burn", 0.5], "name": "Cinder Spray"},
		"line": "Every other turn sprays everybody, and may set you burning."},
}

## One monster that differs from its kind.
const BY_ID := {
	# the Long Cap tends its own: the pack lasts until it is felled
	"long_cap": {"move": {"kind": "heal", "every": 3, "heal": 0.2, "name": "Spore Balm"},
		"line": "Ignores the Lantern. Every third turn it mends a hurt friend."},
	# (v0.23.0 found the rock land's monsters took 7 to 18 blows: far too long. The real-time
	# game's "hp" rows stay as they are; the battle takes a share.)
	"rubble_walker": {"hp": 0.5, "def": 4.0},
	"old_cap": {"hp": 0.7},
	"magma_heart": {"hp": 0.8},
	"lantern_head": {"hp": 1.0},
}


## The kit of one monster: its kind's row laid over DEFAULT, then its own row of BY_ID.
static func of(enemy_id: String, ai: String) -> Dictionary:
	var out: Dictionary = DEFAULT.duplicate(true)
	for src: Dictionary in [KIT.get(ai, {}), BY_ID.get(enemy_id, {})]:
		for k: String in src:
			out[k] = (src[k] as Dictionary).duplicate(true) if src[k] is Dictionary else src[k]
	return out
