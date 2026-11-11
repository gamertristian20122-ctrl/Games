extends RefCounted
## The story: the levels you clear in order, and what the people in the camp say as it moves on.
## Everything here is plain text the owner may rewrite (names, lines, level names).
##
## THE STORY IN SHORT (an original one): long ago a king wished never to want for anything and was
## cursed with a hunger that never ends. He ate his kingdom bare. Four orders buried him under the
## Hollow Hill behind four seals, each kept by two guardians. Centuries on, the guardians have gone
## hungry and wrong, the seals are cracking and the dead walk in the forest. Aldous, the last knight
## of the order that swore to keep the seals, comes to the camp at the foot of the hill. He goes
## down level by level, puts each fallen guardian to rest and carries its seal shard back to Ysolde
## the Druid, who mends the ward at the rune stones. At the bottom waits the Starved King.
## Aldous is the ONLY hero (the owner removed the other two on 11 Nov 2026; switching WEAPONS is
## planned instead).
##
## LEVELS: one row each, in this order. A level is one small dungeon that ends at its boss. They are
## played as ONE descent: beat a boss, take the stair down, and the next level begins, each harder
## than the last. From the pause menu the hero may walk back to the camp whenever no fight is on;
## the Warden then sends him down again at the first level not yet cleared.
##   "floor"  which dungeon look and monster set (1 Crypt, 2 Warrens, 3 Ashen Halls, 4 Pit)
##   "boss"   a row key of scripts/data/bosses.gd      "rooms"  how many rooms
##   "final"  the last level
## Dying only repeats the level he died in. The items he carries are kept each time a level is cleared
## and when he walks out. Coins are banked at the camp only when he walks out alive (or wins).
##
## CHAPTER = how many levels are cleared (0 to LEVELS.size()). An NPC's "story" gives pages per
## chapter; the newest entry not above the current chapter is spoken. A gold "!" shows over anyone
## whose current pages have not been heard yet.

const LEVELS := [
	{"id": "crypt_1", "area": "The Crypt", "name": "The Burning Chapel", "floor": 1, "boss": "pyre_saint", "rooms": 6},
	{"id": "crypt_2", "area": "The Crypt", "name": "The Sexton's Rows", "floor": 1, "boss": "red_sexton", "rooms": 7},
	{"id": "warrens_1", "area": "The Warrens", "name": "The Ogre's Larder", "floor": 2, "boss": "stonejaw", "rooms": 7},
	{"id": "warrens_2", "area": "The Warrens", "name": "The Drowned Court", "floor": 2, "boss": "gutter_king", "rooms": 8},
	{"id": "ashen_1", "area": "The Ashen Halls", "name": "The Cold Forge", "floor": 3, "boss": "forge_warden", "rooms": 8},
	{"id": "ashen_2", "area": "The Ashen Halls", "name": "The Ember Throne", "floor": 3, "boss": "cinder_tyrant", "rooms": 9},
	{"id": "pit_1", "area": "The Pit", "name": "The Hungry Hall", "floor": 4, "boss": "starved_king", "rooms": 10, "final": true},
]

## Spoken once, the first time the camp opens.
const INTRO := {"name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "pages": [
	"So the order did send someone. One knight. I had hoped for forty.",
	"Listen, then. A king lies under this hill. He wished never to want for anything, and was given a hunger that never ends.",
	"Four seals hold him down. Their guardians have gone hungry too, and the seals are cracking. You have seen the dead in the woods.",
	"Go down. Put each guardian to rest and bring me its seal shard. I will mend the ward here, at the stones.",
	"Warden Hale keeps the gate to the north. Speak to him when you are ready, Aldous.",
]}

## What each person says, by chapter. Keys are npc ids from scripts/data/hub.gd.
const TALK := {
	"druid": {
		0: ["The first seal is the Burning Chapel. Its saint was the kindest of the eight. Fire is all that is left of her.", "Her body only burns you when she dives. Watch the red on the floor and step aside."],
		1: ["The Pyre Saint's shard. It is still warm.", "One more guardian keeps the Crypt: the Red Sexton, who buried the king's dead and never stopped digging."],
		2: ["The first seal holds again. Do you feel it? The woods are quieter.", "Below the Crypt lie the Warrens, the king's old larders. Stonejaw the ogre was set to guard the meat. He ate it."],
		3: ["Two shards from the Warrens and the second seal is whole. One is still down there, with a thing that calls itself a king.", "Rest if you must. The stair is still open, and the hill does not sleep."],
		4: ["Half the hill is sealed. I did not think I would live to say that.", "Next are the Ashen Halls, where the seals were forged. The Forge Warden turns shots back at whoever throws them. Lucky you carry a sword."],
		5: ["The forge is cold. One guardian left before the Pit: the Cinder Tyrant, on the Ember Throne.", "It was a man once, the smith who made the seals. Be quick, and be kind."],
		6: ["Three seals mended. The fourth cannot be: the king has eaten its guardians.", "So the last seal must be you. Go down into the Pit and end his hunger, Aldous. We will keep the fire lit."],
		7: ["It is done. The hill is only a hill.", "Stay by the fire a while, last knight. You have earned the quiet."],
	},
	"warden": {
		0: ["Hale. I keep the gate. Nothing has come up through it in my time, and I mean to keep it so.", "Tell me where you are bound and I will open it. Fall, and I will drag you back out. Once."],
		2: ["The Crypt is quiet. I had forgotten what that sounds like.", "The stair to the Warrens is open to you now."],
		4: ["Warm air comes up the stair these days. That will be the Ashen Halls.", "Mind the forge fires. They remember being stoked."],
		6: ["Only the Pit is left. I will not pretend the gate will open twice for that one.", "Go well, knight."],
		7: ["I have kept this gate thirty years. Tonight I may sleep."],
	},
	"cook": {
		0: ["Sit, eat. A knight with an empty belly is just a man in a tin pot.", "Whatever the Druid pays you for your work goes in your pack. I keep it by the fire till you go down."],
		3: ["Folk are coming back up the forest road. I have had to water the stew.", "Your pack is by the fire, same as always."],
		7: ["A feast tonight. For once there is enough, and nobody under the hill to mind."],
	},
	"chronicler": {
		0: ["Brother Odo. I write down what comes out of the hill, so the next fool knows what is in it.", "Show me what you carry and I will put a name to it."],
		4: ["The Druid says my account of the seals is wrong in eleven places. I have corrected two.", "The book is open, if you would look."],
		7: ["The last page is written. I find I do not know what to do with my hands."],
	},
	"smith": {
		0: ["That sword is older than I am. Good steel. A swing cuts a shot clean out of the air, did you know?", "Keep close to what you fight. You are no archer."],
		5: ["They say the Tyrant below was a smith once. Made the seals himself.", "If you find his hammer, leave it be."],
		7: ["Hang the sword up, if you like. I will keep it oiled."],
	},
	"hunter": {
		0: ["The deer left these woods when the dead came. We stayed. Someone must count them.", "Bombs open cracked walls. There is always something behind a cracked wall."],
		2: ["Fewer walkers on the road since you went down. Keep going."],
		7: ["The deer are back. I saw six at dawn."],
	},
	"ranger": {
		0: ["Strong things in the hill often cost you something. Read what a thing asks before you pick it up.", "A key opens a gold chest or a locked room. Never both."],
		6: ["The trees lean away from the hill tonight. They know what is left down there."],
		7: ["Listen. Birds."],
	},
}


static func chapter() -> int:
	var n := 0
	for lv: Dictionary in LEVELS:
		if Save.hub_get("lvl:" + String(lv["id"])) <= 0:
			break
		n += 1
	return n


static func level(id: String) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if String(lv["id"]) == id:
			return lv
	return {}


## The level to play next, or {} when the story is finished.
static func next_level() -> Dictionary:
	var c := chapter()
	return LEVELS[c] if c < LEVELS.size() else {}


static func cleared(id: String) -> bool:
	return Save.hub_get("lvl:" + id) > 0


## The items the hero carries from level to level (saved in pickup order).
static func kit() -> Array[String]:
	var pairs: Array = []
	for key: String in Save.data.get("hub", {}):
		if key.begins_with("kit:") and Save.hub_get(key) > 0:
			pairs.append([Save.hub_get(key), key.substr(4)])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[String] = []
	for p: Array in pairs:
		out.append(String(p[1]))
	return out


## A level was won: remember it, keep the items, let a rescued hero join. Returns the hero id that
## joined just now ("" for nobody).
static func clear(id: String, items: Array) -> String:
	var lv := level(id)
	if lv.is_empty():
		return ""
	var first := not cleared(id)
	Save.hub_set("lvl:" + id, 1)
	for key: String in Save.data.get("hub", {}).keys():
		if key.begins_with("kit:"):
			Save.hub_set(key, 0)
	var n := 0
	for item_id: Variant in items:
		n += 1
		Save.hub_set("kit:" + String(item_id), n)
	if first:
		Save.stat_add("levels_cleared")
	Save.flush()
	return ""


## The level after `id` in the descent, or {} after the last one.
static func after(id: String) -> Dictionary:
	for i in LEVELS.size() - 1:
		if String(LEVELS[i]["id"]) == id:
			return LEVELS[i + 1]
	return {}


## How far into its area a level is (0 = the first level with that look): later ones are a bit harder.
static func step_in_area(id: String) -> int:
	var lv := level(id)
	var n := 0
	for other: Dictionary in LEVELS:
		if String(other["id"]) == id:
			break
		if int(other["floor"]) == int(lv.get("floor", 0)):
			n += 1
	return n


## The hero walked out alive: his items are kept and his coins go into the camp's chest.
static func walk_out(items: Array, coins: int) -> void:
	for key: String in Save.data.get("hub", {}).keys():
		if key.begins_with("kit:"):
			Save.hub_set(key, 0)
	var n := 0
	for item_id: Variant in items:
		n += 1
		Save.hub_set("kit:" + String(item_id), n)
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") + maxi(coins, 0))
	Save.flush()


## The pages `npc_id` speaks now and the chapter they belong to: [pages, chapter key], or [[], -1].
static func pages_for(npc_id: String) -> Array:
	var by: Dictionary = TALK.get(npc_id, {})
	var c := chapter()
	var best := -1
	for k: int in by:
		if k <= c and k > best:
			best = k
	return [by[best], best] if best >= 0 else [[], -1]


static func has_news(npc_id: String) -> bool:
	var got := pages_for(npc_id)
	return int(got[1]) >= 0 and Save.hub_get("heard:" + npc_id) < int(got[1]) + 1


static func heard(npc_id: String) -> void:
	var got := pages_for(npc_id)
	if int(got[1]) >= 0:
		Save.hub_set("heard:" + npc_id, int(got[1]) + 1)
