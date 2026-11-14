extends RefCounted
## HOW A BATTLE IS STAGED (scripts/battle/battle.gd reads this; nothing here changes a rule).
## Use with:  const Looks = preload("res://scripts/data/battle_looks.gd")
##
## BOSS: one row per boss id of scripts/data/tale.gd BOSSES (or of a module's bosses()).
##   "scale"   how many times bigger than its art the boss is drawn (the pack's pixels, made larger)
##   "tint"    the colour its picture is multiplied by (takes the place of the tale row's tint;
##             keep it near white, or it reads as a recolour of a common monster)
##   "rim"     the colour of the edge light on it, "rim_power" how strong (0.5 = an ordinary fighter)
##   "glow"    the colour of the pool of light on the ground under it (alpha = how strong)
##   "at"      where it stands: x to the right, z towards the camera (the party stands at x -3 to -10)
##   "hover"   only for art that floats above its feet point (the Colossus): how much of the art's own
##             air under it is kept (1 = all of it, 0 = it stands on the ground). Default 1.
## A boss that is not listed gets DEFAULT_BOSS. To add a boss: copy a row, then look at it with
##   --battle=story:<battle id> --nosave --shotaim --shots=<dir>
## The camera pulls back by itself until the boss's head is under the top of the screen
## (FRAME_TOP: how far down the screen, 0 to 1, the head may reach; FRAME_BACK: how far back at most).
const BOSS := {
	"bramblejaw": {"scale": 1.5, "tint": Color(0.86, 0.97, 0.80), "rim": Color(0.74, 1.0, 0.46), "rim_power": 0.95,
		"glow": Color(0.45, 0.85, 0.30, 0.34), "at": Vector3(5.6, 0.0, 0.0)},
	"gorgon": {"scale": 2.0, "tint": Color(1.0, 0.96, 0.88), "rim": Color(0.42, 0.95, 0.84), "rim_power": 1.0,
		"glow": Color(0.25, 0.85, 0.75, 0.5), "at": Vector3(5.6, 0.0, 0.0)},
	"colossus": {"scale": 2.0, "tint": Color(1.0, 0.92, 0.86), "rim": Color(1.0, 0.52, 0.20), "rim_power": 1.1,
		"glow": Color(1.0, 0.42, 0.12, 0.40), "at": Vector3(5.6, 0.0, 0.0), "hover": 0.35},
}
const DEFAULT_BOSS := {"scale": 1.6, "tint": Color.WHITE, "rim": Color(1.0, 0.62, 0.30), "rim_power": 0.95,
	"glow": Color(1.0, 0.5, 0.2, 0.32), "at": Vector3(5.6, 0.0, 0.0)}

## Where a boss's helpers stand: behind it and to the sides, never in front of its face.
const MINION_AT := [Vector3(8.6, 0.0, 2.2), Vector3(9.4, 0.0, -2.0), Vector3(10.6, 0.0, 0.4)]

const FRAME_TOP := 0.13            ## a boss's head stays under this share of the screen's height
const FRAME_BACK := 1.5            ## the camera never stands further back than this many times its own distance

## Monsters that wear the same picture as one of your own side: washed with a colour so nobody
## mistakes one for the other (the thorn-sick elves against Thessaly). Multiplied with the row's tint.
const FOE_TINT := {
	"elf_stalker": Color(0.66, 0.78, 0.62),
	"thorn_elf": Color(0.70, 0.80, 0.64),
}

## AIMING: the ring on the ground under the one aimed at, and how far the others sink back.
const AIM_FOE := Color(1.0, 0.80, 0.36, 0.95)
const AIM_FRIEND := Color(0.55, 1.0, 0.62, 0.95)
const AIM_DIM := 0.58              ## everybody who is not aimed at is drawn this dark
const AIM_DIM_ACTING := 0.86       ## (the one who is choosing only a little)

## The speeds the plate beside Auto steps through (kept as the setting "battle_speed").
const SPEEDS := [1, 2, 3]

## The words of the battle screen that were added in the quality pass (placeholders to rewrite).
const WORDS := {
	"auto_tip": "Auto: the party chooses its own moves. Press again to take the fight back.",
	"speed_tip": "How fast blows and spells play out.",
	"try_again": "Try again",
	"try_again_text": "Start this fight over, as you walked into it. Nothing is lost.",
	"rest": "Rest and return",
	"rest_text": "Somebody carries you back to your bed, rested. You lose %d coins on the way.",
	"rest_text_free": "Somebody carries you back to your bed, rested. You have no coins to lose.",
	"fallen": "The fight is lost.",
}


static func boss(id: String) -> Dictionary:
	var row: Dictionary = DEFAULT_BOSS.duplicate()
	row.merge(BOSS.get(id, {}), true)
	return row


static func word(key: String) -> String:
	return String(WORDS.get(key, key))
