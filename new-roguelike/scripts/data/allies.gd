extends RefCounted
## Allies: companions who join the knight in the story and fight beside him (RPG step 4, v0.14.0).
## The owner's answers (12 Nov 2026): ONE companion at a time; the first is the blonde mage from the
## Library pack (picture "C" of five shown), she fights FROM RANGE, and when she runs out of health
## she is knocked down and GETS BACK UP when the room is clear.
##
## A row:
##   "sprite", "hands"   Pixel Crawler body and its hand pieces (as for the people of the camp)
##   "from"              the chapter (levels cleared) at which she turns up at "place" / "pos"
##   "pages"             what she says when you first meet her (the talk box, one page each)
##   "hp"                half hearts; +1 per "hp_levels" levels of the knight
##   "damage"            her shot's damage as a share of the knight's own blow (so she grows with him)
##   "rate" shots a second    "range" px    "shot", "shot_speed"  (scripts/data/shot_types.gd)
##   "keep"              how far she tries to stay from the nearest monster, px
## Kept in the save's hub section: "ally:<id>" = 1 once she has joined, "ally:with" = her place in
## LIST + 1 while she travels with him (0 = nobody). What she DOES in a level: scripts/entities/ally.gd.
## Names and words are placeholders the owner may rewrite.

const LIST := [
	{"id": "sera", "name": "Seraphine", "title": "Sun-mage of the Archive", "sprite": "pc_scholar_censor", "hands": "pc_hand_library_6",
		"from": 1, "place": "village", "pos": Vector2(392, 236), "face": -1,
		"pages": [
			"So you are the one who went under the hill and came back up. I heard the stones sing when the first seal held.",
			"I kept the forbidden shelf of the Sunken Archive, until my sisters began to read from it. I left before I did.",
			"I know what the old words do, Aldous, and I can throw light a long way. Take me with you. I do not die easily.",
		],
		"about": "She keeps her distance and throws bolts of sunlight. If she falls, she gets up when the room is clear.",
		"hp": 6, "hp_levels": 3, "damage": 0.55, "rate": 1.0, "range": 130.0, "shot": "sunbolt", "shot_speed": 175.0, "keep": 58.0},
	# the new story's companions (scripts/data/tale.gd). They join in a story scene, never by
	# themselves ("from": 99); their battle numbers are in scripts/data/battles.gd ALLY. The
	# real-time numbers below are only there so the old levels do not trip over them.
	{"id": "thessaly", "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "hands": "pc_hand_elf_23",
		"from": 99, "place": "", "pos": Vector2.ZERO, "face": -1, "pages": [],
		"about": "The elf warden of the Rune Glade. Quick with a bow; her roots can hold a monster still.",
		"hp": 6, "hp_levels": 3, "damage": 0.5, "rate": 1.2, "range": 140.0, "shot": "sunbolt", "shot_speed": 190.0, "keep": 62.0},
]


static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return {}


## She has turned up in the world (the story has reached her chapter).
static func arrived(r: Dictionary) -> bool:
	if not G.flag("oldstory"):
		return false                 # the new story (scripts/data/tale.gd) brings companions in itself
	return Story.chapter() >= int(r.get("from", 0))


static func joined(id: String) -> bool:
	return Save.hub_get("ally:" + id) > 0


static func any_joined() -> bool:
	for r: Dictionary in LIST:
		if joined(String(r["id"])):
			return true
	return false


## The companion travelling with the knight now ({} = nobody).
static func with() -> Dictionary:
	var i := Save.hub_get("ally:with") - 1
	if i < 0 or i >= LIST.size() or not joined(String(LIST[i]["id"])):
		return {}
	return LIST[i]


## She joins for good and travels with him from now on.
static func join(id: String) -> void:
	if row(id).is_empty():
		return
	Save.hub_set("ally:" + id, 1)
	set_with(id)


## Who travels with him ("" = nobody: she waits where she was met).
static func set_with(id: String) -> void:
	var n := 0
	for i in LIST.size():
		if String(LIST[i]["id"]) == id and joined(id):
			n = i + 1
	Save.hub_set("ally:with", n)
	Save.flush()


static func max_hp(r: Dictionary) -> int:
	@warning_ignore("integer_division")
	return int(r.get("hp", 6)) + (Rpg.level() - 1) / maxi(int(r.get("hp_levels", 3)), 1)


const Story = preload("res://scripts/data/story.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
