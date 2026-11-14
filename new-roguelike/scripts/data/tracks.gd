extends RefCounted
## Tracks: every piece of music and every stinger in the game, with its title and composer.
## Use with:  const Tracks = preload("res://scripts/data/tracks.gd")
## The Music room (scripts/ui/music_room.gd) is built from these lists, top to bottom, so the
## owner can listen to each one and say which to keep or swap.
##
## MUSIC row:  file     the file in assets/audio/music/ without ".ogg" (what Sfx plays)
##             title    the piece's own name
##             by       who composed it
##             licence  CC0 = no credit needed (they are credited anyway)
##             plays    where the game plays it today (plain words; change when sfx.gd changes)
## To swap a track: put the new .ogg in assets/audio/music/ under the SAME file name (and loop =
## true in its import settings), then correct title / by here and its row in credits.gd.
## STINGS row: name (what Sfx.sting() is called with), title, by, plays.
## Nobody has listened to any of this in the game yet: every role is a guess from titles.

const MUSIC := [
	{"file": "title", "title": "Ancient Evil Awakens", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The title screen and the intro"},
	{"file": "room", "title": "A Place I Call Home", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Your room at the Hollow Flagon"},
	{"file": "hall", "title": "Peaceful Days", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The tavern hall, and inside any house"},
	{"file": "town", "title": "Home Town", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Wickmere"},
	{"file": "road", "title": "Grasslands", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Elfwood Road"},
	{"file": "woods", "title": "Where Time Stands Still", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Rune Glade"},
	{"file": "deepwood", "title": "Sneaking Around", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Deepwood"},
	{"file": "beacon", "title": "Prairie Nights", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The beacon's hill"},
	{"file": "world", "title": "Sunshine Coast", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The world map"},
	{"file": "night", "title": "Whispers from Beyond", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Out of doors at night"},
	{"file": "dustwatch", "title": "Sand Castles", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Dustwatch"},
	{"file": "suncourt", "title": "Tha'el Mines", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Sunwell"},
	{"file": "emberfall", "title": "Military Base", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Emberfall"},
	{"file": "floor1", "title": "Catacombs", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Cinder Stair"},
	{"file": "shop", "title": "Bazaar", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Spare (it was the tavern and Dustwatch before)"},
	{"file": "battle", "title": "Preparing For Battle", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Fights in the green lands"},
	{"file": "floor2", "title": "Witch's Lair", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Fights in the Sands"},
	{"file": "floor3", "title": "Apocalypse", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Fights in the Cinder Mountains"},
	{"file": "boss", "title": "Encounter With The Witches", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Old Bramblejaw, and any boss without a theme of its own"},
	{"file": "boss_gorgon", "title": "Army Approaching", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Dune Gorgon"},
	{"file": "final_boss", "title": "Epic Boss Battle", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "The Ember Colossus (for now: it is meant for the last boss)"},
	{"file": "victory", "title": "Victory Fanfare Short", "by": "cynicmusic", "licence": "CC0",
		"plays": "A fight is won (once)"},
	{"file": "results", "title": "Innocence", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Quietly after the fanfare, while the spoils are counted"},
	{"file": "gameover", "title": "No Hope", "by": "Cleyton Kauffman", "licence": "CC0",
		"plays": "A fight is lost (once)"},
	{"file": "calm_friends", "title": "Childhood Friends", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Spare: a warm story cue, not used yet"},
	{"file": "calm_summer", "title": "Summer Memories", "by": "Juhani Junkala", "licence": "CC0",
		"plays": "Spare: a wistful story cue, not used yet"},
]

const STINGS := [
	{"name": "level_up", "title": "Jingle 02, strings", "by": "Kenney", "plays": "A level is gained"},
	{"name": "quest_done", "title": "Jingle 10, strings", "by": "Kenney", "plays": "A side quest is handed in"},
	{"name": "item_get", "title": "Jingle 12, strings", "by": "Kenney", "plays": "A chest is opened"},
	{"name": "inn_rest", "title": "Jingle 03, strings", "by": "Kenney", "plays": "A night at the inn"},
	{"name": "beacon_lit", "title": "Jingle 15, orchestra", "by": "Kenney", "plays": "A beacon is lit"},
]

## The words of the Music room itself.
const WORDS := {
	"title": "Music room",
	"about": "Every tune in the game. Pick one to hear it; tell us which to keep.",
	"stings": "Short flourishes",
	"playing": "Playing",
	"stop": "Stop",
	"back": "Back",
	"listen": "Listen",
	"by": "by %s",
}


## The row of a music file ("" when it has none).
static func row(file: String) -> Dictionary:
	for r: Dictionary in MUSIC:
		if String(r["file"]) == file:
			return r
	return {}
