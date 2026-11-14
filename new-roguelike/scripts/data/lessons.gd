extends RefCounted
## LESSONS of the battle screen (quality pass P08): one short card each, shown ONCE, the first time
## it matters, and only while Settings > "Tutorial hints" (the setting "hints") is on. Each is
## remembered with Save.set_flag("taught:b_<id>"). scripts/battle/battle.gd decides WHEN; the card is
## scripts/ui/kit/lesson.gd; Pause > "How to play" (scripts/ui/howto.gd) lists the ones seen.
##   "id"     the lesson's name           "title"  the card's head        "text"  what it says
##   In "text": {fast} and {auto} become the key caps of those actions; {teacher} the teacher's line.
## ALL WORDS HERE ARE PLACEHOLDERS for the owner.

const LIST := [
	{"id": "orders", "title": "Your turn",
		"text": "Pick an order for the one whose turn it is. The coins at the top left are the turn order: this round, then the next."},
	{"id": "lantern", "title": "The Lantern",
		"text": "One of you carries the Lantern: lit, they strike and heal harder, and the monsters go for them. 'Lantern' takes it, once a round, and costs no turn. Three flames: a Flare."},
	{"id": "guard", "title": "A heavy blow",
		"text": "A red sign over a monster means a heavy blow or a blow at everybody. Guard, and you take less than half."},
	{"id": "items", "title": "Badly hurt",
		"text": "Items holds the herbs from your pack. A herb that would do nothing is not used up."},
	{"id": "speed", "title": "Faster fights",
		"text": "Hold {fast} to hurry a fight along. {auto} lets your side choose for itself. Flee runs from a wild fight."},
	{"id": "beds", "title": "Wounds stay",
		"text": "Wounds stay after a fight. A bed or an inn makes everybody whole again."},
	{"id": "teach", "title": "A new skill",
		"text": "A new level only opens a skill: {teacher} can teach it to you."},
]

## Who teaches skills, and where (scripts/data/arms.gd TEACHERS). Placeholders.
const TEACHER_LINE := "Brother Odo in Wickmere or Sister Imre in Dustwatch"

## The battle screen's own new words (the Lantern order, the Flare row, intents, deeds ...).
const WORDS := {
	"lantern": "Lantern",
	"lantern_text": "Take the Lantern: free, once a round. Its carrier hits and heals harder; monsters go for them.",
	"lantern_taken": "Lantern",
	"takes": "%s takes the Lantern.",
	"lantern_no": "The Lantern already changed hands this round.",
	"lantern_have": "You carry the Lantern now.",
	"flare_text": "Flare",
	"flare_ready": "Flare ready!",
	"flame": "Flame %d",
	"raised": "Up again!",
	"deed": "Deed: %s",
	"deed_bonus": "+%d%%",
	"unknown_kit": "???",
	"preview": "Hits for %d-%d",
	"heals": "Heals",
	"intent_short": {"blow": "", "all": "ALL", "heavy": "HEAVY", "fuse": "%d", "heal": "MEND", "wind": "DRAWS BACK", "none": "STUNNED"},
	"lesson_ok": "Got it",
	"howto_title": "How to play",
	"howto_none": "No lessons seen yet. They appear in your first battles (Settings > Tutorial hints).",
}


static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return {}


static func word(key: String) -> Variant:
	return WORDS.get(key, key)


## Has this lesson been shown already?
static func seen(id: String) -> bool:
	return Save.flag("taught:b_" + id)
