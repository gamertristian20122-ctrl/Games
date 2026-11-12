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
## THE WIDE WORLD (v0.10.0; the owner finished v0.9 in five minutes and asked for a far longer, harder
## game with more story, other camps, and "basic areas" to fight through between them). The four
## seals are ANCHORS spread over the land: Fire under the Hollow Hill (the Crypt), Earth under the
## eastern sands (the Warrens, entered from the camp of DUSTWATCH), Iron in the mountain forge (the
## Ashen Halls, entered from the camp of EMBERFALL) and Root, the king's own door (the Pit, back
## under the hill). Between the camps lie ROAD AREAS that must be fought through before the way on
## opens. The knight walks the world map (scripts/data/places.gd "world") from site to site.
##
## LEVELS: one row each, IN THE ORDER THEY MUST BE CLEARED. A level is one small dungeon that ends at
## its boss (or its champion). Rows that share a "site" are played as ONE descent: beat the boss,
## take the stair, the next level of that site begins. From the pause menu the hero may walk back
## out whenever no fight is on.
##   "site"   where it is entered: a gate in a camp or a spot on the world map (places.gd: a person
##            with "role": "gate" and "sites": [...]). A site only opens once every row above its
##            first level is cleared.
##   "floor"  which dungeon look and monster set (1 Crypt, 2 Warrens, 3 Ashen Halls, 4 Pit)
##   "look"   instead: a theme of scripts/data/floors.gd EXTRA (out of doors)
##   "tier"   how strong its monsters are when it has a "look" (0 = like the Crypt, 1 = the Warrens ...)
##   "hard"   steps of extra monsters per room on top (run.gd LEVEL_STEP_BUDGET each)
##   "boss"   a row key of scripts/data/bosses.gd      "rooms"  how many rooms
##   "champion"  instead of a boss: one monster of this kind, far tougher, with a guard of others
##   "gives"  a weapon id handed over when it is cleared      "final"  the last level
## Dying only repeats the level he died in. The items he carries are kept each time a level is cleared
## and when he walks out. His coins go into the camp chest: all of them when he walks out alive or
## wins, FALLEN_SHARE of them when he falls.
const FALLEN_SHARE := 0.5
##
## CHAPTER = how many levels are cleared, counted in order (0 to LEVELS.size()). An NPC's "story"
## gives pages per chapter; the newest entry not above the current chapter is spoken. A gold "!"
## shows over anyone whose current pages have not been heard yet.

const LEVELS := [
	{"id": "crypt_1", "site": "hill", "area": "The Crypt", "name": "The Burning Chapel", "floor": 1, "boss": "pyre_saint", "rooms": 10},
	{"id": "crypt_2", "site": "hill", "area": "The Crypt", "name": "The Sexton's Rows", "floor": 1, "boss": "red_sexton", "rooms": 11, "hard": 1},
	{"id": "road", "site": "road", "area": "The East Road", "name": "The Robber Road", "floor": 1, "look": "road", "tier": 1,
		"champion": "bandit_chief", "rooms": 10},
	{"id": "dunes", "site": "dunes", "area": "The Eastern Sands", "name": "The Bone Dunes", "floor": 2, "look": "desert", "tier": 1, "hard": 1,
		"champion": "dune_gorgon", "rooms": 11},
	{"id": "warrens_1", "site": "dust", "area": "The Warrens", "name": "The Ogre's Larder", "floor": 2, "boss": "stonejaw", "rooms": 11, "hard": 1, "gives": "hammer"},
	{"id": "warrens_2", "site": "dust", "area": "The Warrens", "name": "The Drowned Court", "floor": 2, "boss": "gutter_king", "rooms": 12, "hard": 2},
	{"id": "pass", "site": "pass", "area": "The Cinder Mountains", "name": "The Cinder Pass", "floor": 3, "hard": 1,
		"champion": "pass_golem", "rooms": 11},
	{"id": "ashen_1", "site": "ember", "area": "The Ashen Halls", "name": "The Cold Forge", "floor": 3, "boss": "forge_warden", "rooms": 12, "hard": 2},
	{"id": "ashen_2", "site": "ember", "area": "The Ashen Halls", "name": "The Ember Throne", "floor": 3, "boss": "cinder_tyrant", "rooms": 12, "hard": 3},
	{"id": "archive", "site": "archive", "area": "The Sunken Archive", "name": "The Sunken Archive", "floor": 4, "hard": 1,
		"champion": "head_archivist", "rooms": 12},
	{"id": "pit_1", "site": "deep", "area": "The Pit", "name": "The Long Stair", "floor": 4, "hard": 2, "champion": "kings_butcher", "rooms": 12},
	{"id": "pit_2", "site": "deep", "area": "The Pit", "name": "The Hungry Hall", "floor": 4, "hard": 3, "boss": "starved_king", "rooms": 13, "final": true},
]

## SIDE LEVELS: areas off the main road, each its own short descent (the Elfwood is entered at the
## glade east of the village). Same rows as LEVELS; they are never needed and never counted in the chapter.
const SIDE := [
	{"id": "wood_1", "side": "forest", "site": "forest", "area": "The Elfwood", "name": "The Thornwood", "floor": 1, "look": "forest", "tier": 0,
		"champion": "wood_beast", "rooms": 9},
	{"id": "wood_2", "side": "forest", "site": "forest", "area": "The Elfwood", "name": "The Singing Glade", "floor": 1, "look": "forest", "tier": 1,
		"champion": "elf_hexer", "rooms": 10, "gives": "spear"},
]

## Where each site is and what its gate says while it is still shut. "home" = the place and spot the
## hero is put back at after a run when the game does not know where he went in (a fresh start).
const SITES := {
	"hill": {"name": "the crypt gate at Hollow Hill", "home": ["village", Vector2(360, 150)]},
	"deep": {"name": "the crypt gate at Hollow Hill", "home": ["village", Vector2(360, 150)]},
	"road": {"name": "the Robber Road, east of the village", "home": ["world", Vector2(720, 700)]},
	"dunes": {"name": "the Bone Dunes, south of Dustwatch", "home": ["world", Vector2(1250, 960)]},
	"dust": {"name": "the cistern stair at Dustwatch", "home": ["dustwatch", Vector2(340, 226)]},
	"pass": {"name": "the Cinder Pass, north-east of Dustwatch", "home": ["world", Vector2(1570, 570)]},
	"ember": {"name": "the forge door at Emberfall", "home": ["emberfall", Vector2(318, 206)]},
	"archive": {"name": "the Sunken Archive, in the far sands", "home": ["world", Vector2(1650, 910)]},
	"forest": {"name": "the rune glade in the Elfwood", "home": ["glade", Vector2(300, 236)]},
}

## What each guardian says when the fight begins and as it falls (shown as a banner over the fight).
const BOSS_SAYS := {
	"pyre_saint": {"start": "Come closer, child. Be warm.", "end": "At last... the cold."},
	"red_sexton": {"start": "One more for the rows. I dig deep.", "end": "Who... will bury me?"},
	"stonejaw": {"start": "MEAT. THE KING SAID GUARD THE MEAT.", "end": "Still... hungry..."},
	"gutter_king": {"start": "Bow! This is MY court. MY flies.", "end": "A king... should not... sink."},
	"forge_warden": {"start": "NO SEAL LEAVES THE FORGE.", "end": "FIRES... OUT."},
	"cinder_tyrant": {"start": "I made the seals. I can unmake a knight.", "end": "Tell the Druid... the last one holds."},
	"starved_king": {"start": "I only wished never to want. Feed me.", "end": "Enough... at last... enough."},
}

## What a champion says as its fight begins (a banner, like the guardians' lines).
const CHAMPION_SAYS := {
	"bandit_chief": "Toll's gone up, tin man. It's everything you've got.",
	"dune_gorgon": "Sssstay. I have ssso few ssstatues left.",
	"pass_golem": "NONE... PASS.",
	"head_archivist": "Shh. You are overdue, knight. Centuries overdue.",
	"kings_butcher": "The king is hungry. You will do.",
	"wood_beast": "The wood remembers iron.",
	"elf_hexer": "Sing with us, or be sung over.",
}

## THE INTRO: an animated cutscene (scripts/hub/intro.gd) played the first time you press Play, and
## again from the bed in your room. One row per shot: which scene the cutscene builds, the words in
## the bar under it, and how many seconds it stays (a tap moves on sooner).
const INTRO_SHOTS := [
	{"scene": "feast", "time": 7.0, "text": "Long ago a king asked for one thing: never to want again. He was given a hunger without end."},
	{"scene": "seals", "time": 7.5, "text": "He ate his kingdom bare. Four orders buried him under the Hollow Hill, behind four seals."},
	{"scene": "forgotten", "time": 7.5, "text": "Forty knights swore to bring the keepers bread each spring. One spring nobody came."},
	{"scene": "dead", "time": 6.5, "text": "Now the seals are cracking, and the dead walk in the forest."},
	{"scene": "road", "time": 7.5, "text": "Night. Rain on the forest road. One knight, one sword: Aldous, the last of the order."},
	{"scene": "flagon", "time": 7.0, "text": "The village under the hill gave him a room at the Hollow Flagon and asked no questions."},
	{"scene": "below", "time": 8.0, "text": "And somewhere below, something very old is hungry."},
]

## SCENES AT THE CAMP: spoken by the Druid the first time the hero is back in the village with
## that many levels cleared (2 = the Crypt's seal, 6 = the Warrens', 9 = the Ashen Halls', 10 = the
## Archive's answer, 12 = the end).
const SCENES := {
	2: ["Hold the shards up, Aldous. There. Do you see the stones answer?", "The first seal is whole. The dead in the Crypt lie down again. One of four.",
		"The other anchors are not under this hill. Earth lies under the eastern sands, Iron in the mountain forge.",
		"Take the south road out of the village and follow it east. Robbers hold it now. They will not ask you nicely."],
	6: ["The second seal. I felt it close from here, like a door in another house.", "Half the ward is mended. Sit by the fire tonight. You look like the hill.",
		"The Iron seal is past the Cinder Pass, north-east of the sands. The folk at Emberfall will know the way in."],
	9: ["Three. The forge is cold and its smith is at rest.", "Now hear the hard part. The fourth seal had two keepers. He ate them both, long ago.",
		"I do not know how to mend a seal with no keepers. The orders wrote it down once, in the Archive under the far sands. Find what they wrote."],
	10: ["So that is what they wrote. A seal with no keeper needs someone to stand where it stood.", "Not for ever. Only long enough to end his hunger.",
		"The gate here goes deeper than the Crypt now. Warden Hale will open the long stair. Rest first, Aldous. Then go down."],
	12: ["It is over. I felt him go quiet, like a child who has finally eaten.", "The hill is a hill. The wood is a wood. And you, last knight, are done.",
		"Stay as long as you like. There is stew."],
}

## ARRIVALS: spoken once, the first time the hero walks into a place.
const ARRIVALS := {
	"world": {"name": "The wide world", "title": "", "sprite": "hub_note", "pages": [
		"Beyond the village the land opens wide. Aldous covers ground quickly out here.",
		"Walk up to a place and press TALK to go in. A place that is still shut says what must be done first."]},
	"dustwatch": {"name": "Captain Sefa", "title": "Keeper of the Cistern Stair", "sprite": "pc_royal_archer", "pages": [
		"Stop there. Armour, a real sword... and you walked the Robber Road. Then the road is open. Good.",
		"This is Dustwatch. We dig for the old king's larders: the Warrens run under these sands, and the Earth seal with them.",
		"But my diggers will not go near the stair. Something in the Bone Dunes, south of here, turns people to stone.",
		"Put an end to it, knight, and I will open the cistern stair for you myself."]},
	"emberfall": {"name": "Forgemaster Bryn", "title": "Keeper of the Forge Door", "sprite": "pc_royal_soldier", "pages": [
		"Somebody came through the pass alive. Then the golem is rubble. I owe you a drink I do not have.",
		"Emberfall. What is left of it. The Iron seal was forged behind that arch, and its makers are still in there, still working.",
		"The Forge Warden turns shots back at whoever throws them. Good thing you carry a sword.",
		"Speak to me when you are ready and I will lift the bar."]},
}

## NOTES found in treasure and secret rooms, in this order: the king's story, piece by piece.
const NOTES := [
	"...the king asked the well for one thing: never to want again. The well kept its word. It took away the having, not the wanting.",
	"Third winter. He has eaten the granaries of four towns and weeps at table. We bring him more. What else can we do?",
	"The orders met at the Hollow Hill. Fire, Earth, Iron and Root: four seals, two keepers for each. I am to keep the first. I am glad.",
	"Do not pity the keepers, the abbess said. But we fed them from our own bowls, and when our bowls were empty they grew thin.",
	"Stonejaw was a cook once. He sang while he salted the meat. Now he guards the larder and does not sing.",
	"I forged the seals to last a thousand years. I did not think to ask who would feed the fire for a thousand years.",
	"Forty knights swore to come back each spring with bread for the keepers. One spring nobody came.",
	"If you read this, knight: he is not wicked. He is only hungry. End it gently.",
	"Dustwatch was a garden once. Then the larders under it were filled, and filled, and the wells went to salt.",
	"The Gutter King was the steward. He counted every sack. When the sacks ran out he went on counting flies.",
	"To the Archive: copy this and hide it. A seal without a keeper can be held by anyone willing. It need not be for ever.",
	"We chose the hill because nothing grew there. Something grows there now. I think it is a village.",
]

## Spoken once, the first time the camp opens.
const INTRO := {"name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "pages": [
	"So the order did send someone. One knight. I had hoped for forty.",
	"Listen, then. A king lies under this hill. He wished never to want for anything, and was given a hunger that never ends.",
	"Four seals hold him down. Their guardians have gone hungry too, and the seals are cracking. You have seen the dead in the woods.",
	"Go down. Put each guardian to rest and bring me its seal shard. I will mend the ward here, at the stones.",
	"Warden Hale keeps the gate to the north. Speak to him when you are ready, Aldous.",
]}

## What each person says, by chapter (the number of levels cleared, 0 to 12). Keys are npc ids from
## scripts/data/hub.gd and scripts/data/places.gd.
##   0 start   1 Pyre Saint down   2 Crypt sealed   3 Robber Road open   4 Bone Dunes quiet
##   5 Stonejaw down   6 Warrens sealed   7 Cinder Pass open   8 Forge Warden down   9 Ashen Halls sealed
##   10 the Archive read   11 the Long Stair cleared   12 the end
const TALK := {
	"druid": {
		0: ["The first seal is the Burning Chapel. Its saint was the kindest of the eight. Fire is all that is left of her.", "Her body only burns you when she dives. Watch the red on the floor and step aside."],
		1: ["The Pyre Saint's shard. It is still warm.", "One more guardian keeps the Crypt: the Red Sexton, who buried the king's dead and never stopped digging."],
		2: ["The first seal holds again. Do you feel it? The woods are quieter.", "The Earth seal lies under the eastern sands. Take the south road out of the village, then east. The diggers at Dustwatch can show you the stair."],
		3: ["The road is open? Then Dustwatch can send word again. Go on east, Aldous.", "The stones tell me the sands are restless. Something old woke when the seals cracked."],
		5: ["One shard from the Warrens. One is still down there, with a thing that calls itself a king.", "Rest if you must. The stair is still open, and the hill does not sleep."],
		6: ["Half the land is sealed. I did not think I would live to say that.", "Next is the Iron seal, in the mountain forge past the Cinder Pass. The pass has a keeper of its own. It does not let people through."],
		8: ["The forge is cold. One guardian left there: the Cinder Tyrant, on the Ember Throne.", "It was a man once, the smith who made the seals. Be quick, and be kind."],
		9: ["Three seals mended. The fourth cannot be: the king has eaten its guardians.", "The orders wrote down what to do if a seal lost its keepers. The Sunken Archive, in the far sands. Find it."],
		10: ["So the last seal must be you. I am sorry. I would go myself if these knees could manage a stair.", "Warden Hale will open the long stair. We will keep the fire lit."],
		11: ["You came back up to breathe. Good. Even he must be tired of waiting by now.", "One hall is left. Go and end his hunger, Aldous."],
		12: ["It is done. The hill is only a hill.", "Stay by the fire a while, last knight. You have earned the quiet."],
	},
	"warden": {
		0: ["Hale. I keep the gate. Nothing has come up through it in my time, and I mean to keep it so.", "Tell me where you are bound and I will open it. Fall, and I will drag you back out. Once."],
		2: ["The Crypt is quiet. I had forgotten what that sounds like.", "Nothing more for you behind this gate, for now. The Druid says the other seals are out east. The south road is yours."],
		10: ["The Druid told me. There is a stair under the Crypt I have never opened. I oiled the lock anyway, every year.", "It is open. I will not pretend it will open twice."],
		11: ["Only the Hungry Hall is left. Go well, knight."],
		12: ["I have kept this gate thirty years. Tonight I may sleep."],
	},
	"cook": {
		0: ["Sit, eat. A knight with an empty belly is just a man in a tin pot.", "Whatever the Druid pays you for your work goes in your pack. I keep it by the fire till you go down."],
		3: ["Carts on the east road again! I have had to water the stew.", "Your pack is by the fire, same as always."],
		6: ["They say you ate with the diggers at Dustwatch. Was the stew better? Lie to me."],
		12: ["A feast tonight. For once there is enough, and nobody under the hill to mind."],
	},
	"chronicler": {
		0: ["Brother Odo. I write down what comes out of the hill, so the next fool knows what is in it.", "Show me what you carry and I will put a name to it."],
		6: ["The Druid says my account of the seals is wrong in eleven places. I have corrected two.", "The book is open, if you would look."],
		10: ["You have SEEN the Archive? The shelves? Tell me there were shelves.", "No. Do not tell me. I will only be jealous."],
		12: ["The last page is written. I find I do not know what to do with my hands."],
	},
	"smith": {
		0: ["That sword is older than I am. Good steel. A swing cuts a shot clean out of the air, did you know?", "Keep close to what you fight. You are no archer."],
		3: ["Things out east hit harder than our dead do. Bring coin and I will put a better edge on that."],
		8: ["They say the Tyrant in the forge was a smith once. Made the seals himself.", "If you find his hammer, leave it be."],
		12: ["Hang the sword up, if you like. I will keep it oiled."],
	},
	"hunter": {
		0: ["The deer left these woods when the dead came. We stayed. Someone must count them.", "Bombs open cracked walls. There is always something behind a cracked wall."],
		2: ["Fewer walkers on the road since you went down. Keep going."],
		12: ["The deer are back. I saw six at dawn."],
	},
	"ranger": {
		0: ["Strong things in the hill often cost you something. Read what a thing asks before you pick it up.", "A key opens a gold chest or a locked room. Never both."],
		2: ["The things you fight grow tougher the more you carry. The hill smells its own relics on you."],
		10: ["The trees lean away from the hill tonight. They know what is left down there."],
		12: ["Listen. Birds."],
	},
	# ---- Dustwatch (the desert camp)
	"sefa": {
		3: ["The Bone Dunes are south of the camp. You will know them by the tusks. And by the statues.", "Come back when it is done and the cistern stair is yours."],
		4: ["It is dead? Truly? Then I keep my word.", "The stair goes down into the Warrens. Stonejaw the ogre keeps the first larder. He was set to guard the meat, and he ate it."],
		5: ["One of the two is down. The other calls itself a king and holds court in the flooded halls.", "Mind the water. And mind what he spits."],
		6: ["The ground has stopped shaking at night. My diggers slept. All of them. At once.", "The mountain road runs north-east from here, to the Cinder Pass. Nobody has come back down it this year."],
	},
	"grukk": {
		3: ["Yes, an orc. Look your fill. I walked out of the Warrens when the others started eating each other.", "I can sharpen that, balance it, or draw it out. Coin first."],
		6: ["You put the big one down. He was my cousin. He was also going to eat me. Thank you, I think."],
	},
	"nib": {
		3: ["Pots, charms, things the sand gave up. All honest. Mostly honest.", "The shelf changes whenever you go underground."],
	},
	"imre": {
		3: ["Sister Imre. I read the walls here. This was a garden once, before the larders were filled.", "The king's cooks carried the food down. The stair is older than the camp."],
		4: ["The thing in the dunes was a keeper's pet, I think. Left unfed, like everything else."],
		6: ["The orders kept an Archive, far out in the sands, south-east. Half sunk now. If the Druid ever asks: that is where the old answers are."],
		9: ["So she did ask. Follow the ruined pillars south-east of here. Take water."],
	},
	"dustfire": {
		3: ["The fire at Dustwatch. Dry wood burns fast; somebody always keeps it fed."],
	},
	# ---- Emberfall (the mountain camp)
	"bryn": {
		7: ["Two keepers in there. The Forge Warden first: all plate, no mercy. Then the one on the throne.", "Say the word and I lift the bar."],
		8: ["The hammers have stopped. First quiet night in my life.", "The Tyrant is deeper. He made the seals. He will know how to break a knight."],
		9: ["Cold. The whole forge, cold. My grandmother said it would never happen.", "You will want the Druid now. Go home, knight."],
	},
	"kessa": {
		7: ["Old Kessa. I shoe mules and mend picks, but I know a blade. Let me see it.", "Ha. Hill steel. I can do better by it than that boy Tam."],
		9: ["I knew the Tyrant's name once. All of Emberfall did. We stopped saying it."],
	},
	"aurel": {
		7: ["Brother Aurel. I came to pray for the smiths inside. I have been praying eleven years.", "Does it help? The door is still shut. So something is working."],
		9: ["Eleven years. And then one man with a sword. I shall have words with someone about that."],
	},
	"pell": {
		7: ["I sell what the miners left when they ran. They ran fast, so there is plenty.", "Coin from your chest, same as anywhere."],
	},
	"emberfire": {
		7: ["A brazier fire, banked low. Nobody at Emberfall wastes coal."],
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
	for lv: Dictionary in LEVELS + SIDE:
		if String(lv["id"]) == id:
			return lv
	return {}


## The rows of a side area, in order.
static func side_levels(area: String) -> Array:
	var out: Array = []
	for lv: Dictionary in SIDE:
		if String(lv.get("side", "")) == area:
			out.append(lv)
	return out


## The first level of a side area not cleared yet, or {} when all are.
static func next_side(area: String) -> Dictionary:
	for lv: Dictionary in side_levels(area):
		if not cleared(String(lv["id"])):
			return lv
	return {}


## The rows entered at a site, in order.
static func site_levels(site: String) -> Array:
	var out: Array = []
	for lv: Dictionary in LEVELS + SIDE:
		if String(lv.get("site", "")) == site:
			out.append(lv)
	return out


## The first level of a site not cleared yet, or {} when all are.
static func next_in_site(site: String) -> Dictionary:
	for lv: Dictionary in site_levels(site):
		if not cleared(String(lv["id"])):
			return lv
	return {}


## May the hero go into this level yet? (A side level always; a story level once all before it are cleared.)
static func is_open(id: String) -> bool:
	var lv := level(id)
	if lv.is_empty():
		return false
	if lv.has("side"):
		return true
	return LEVELS.find(lv) <= chapter()


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


## Something bought or found outside a level joins what he carries.
static func add_to_kit(item_id: String) -> void:
	var top := 0
	for key: String in Save.data.get("hub", {}):
		if key.begins_with("kit:"):
			top = maxi(top, Save.hub_get(key))
	if Save.hub_get("kit:" + item_id) == 0:
		Save.hub_set("kit:" + item_id, top + 1)


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
	var gift := ""
	if first:
		Save.stat_add("levels_cleared")
	# a weapon this level hands over (scripts/data/weapons.gd); returned so the game can say so
	var what := String(lv.get("gives", ""))
	if what != "" and Save.hub_get("wpn:" + what) == 0:
		Save.hub_set("wpn:" + what, 1)
		gift = what
	Save.flush()
	return gift


## The level after `id` in the same descent (the next row of the same site), or {}.
static func after(id: String) -> Dictionary:
	var mine := level(id)
	if mine.is_empty():
		return {}
	var rows := site_levels(String(mine.get("site", "")))
	for i in rows.size() - 1:
		if String(rows[i]["id"]) == id:
			return rows[i + 1]
	return {}


## Steps of extra monsters per room this level asks for (its "hard").
static func step_in_area(id: String) -> int:
	return int(level(id).get("hard", 0))


## Where a run that began at this level's site puts the hero back: [place id, spot].
static func home_of(id: String) -> Array:
	var site := String(level(id).get("site", "hill"))
	return (SITES.get(site, SITES["hill"]) as Dictionary)["home"]


## Old saves (before v0.10.0, when the story had seven levels under one hill): the Crypt stays
## cleared, everything after it is played again in the new, longer order. Items, coins, weapons and
## upgrades are kept. Called once when a place is first shown.
static func migrate() -> void:
	if Save.hub_get("story_ver") >= 10:
		return
	for key: String in Save.data.get("hub", {}).keys():
		if key.begins_with("lvl:") and not ["lvl:crypt_1", "lvl:crypt_2", "lvl:wood_1", "lvl:wood_2"].has(key):
			Save.hub_set(key, 0)
		if key.begins_with("heard:"):
			Save.hub_set(key, 0)
	Save.hub_set("seen:scene", mini(Save.hub_get("seen:scene"), 2))
	Save.hub_set("story_ver", 10)
	Save.flush()


## The words for walking into `place` the first time ({} when there are none or they were heard).
static func take_arrival(place: String) -> Dictionary:
	if not ARRIVALS.has(place) or Save.hub_get("seen:arrive:" + place) > 0:
		return {}
	Save.hub_set("seen:arrive:" + place, 1)
	return (ARRIVALS[place] as Dictionary).duplicate(true)


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


## He fell: part of his purse still reaches the chest. Returns how many coins that was.
static func fall(coins: int) -> int:
	var saved := int(floor(maxi(coins, 0) * FALLEN_SHARE))
	Save.hub_set("bank:coins", Save.hub_get("bank:coins") + saved)
	Save.flush()
	return saved


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


## The first note not found yet (an index into NOTES), or -1 when all are found.
static func next_note() -> int:
	for i in NOTES.size():
		if Save.hub_get("note:%d" % i) == 0:
			return i
	return -1


static func find_note(i: int) -> void:
	Save.hub_set("note:%d" % i, 1)
	Save.flush()


static func notes_found() -> Array:
	var out: Array = []
	for i in NOTES.size():
		if Save.hub_get("note:%d" % i) > 0:
			out.append(i)
	return out


## The camp scene waiting to be shown ([] when there is none): the newest one at or below the chapter
## that has not been seen. Marks it seen.
static func take_scene() -> Array:
	var c := chapter()
	var best := -1
	for k: int in SCENES:
		if k <= c and k > best:
			best = k
	if best < 0 or Save.hub_get("seen:scene") >= best:
		return []
	Save.hub_set("seen:scene", best)
	return SCENES[best]
