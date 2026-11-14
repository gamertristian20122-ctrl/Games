extends RefCounted
## SIDE QUESTS AND SECRETS (v0.42.0). Everything the story does not ask for: errands people give,
## and things hidden in the places (chests, and what an errand sends you to find).
## Words are placeholders the owner may rewrite (keep the ids).
##
## ERRANDS: one row each.
##   "id", "giver" (a person's id), "name" (short, for the story line), "from" / "to" (story steps it is offered)
##   "ask"   the giver's words when offering it; "thanks" when it is handed in
##   "goal"  {"wins": land, "n": count}  win that many battles on the world map ("grass", "robbers",
##                                        "sand", "rock"; "any" = anywhere)
##           {"finds": [find ids]}       pick up those things (rows of FINDS with "errand": this id)
##           {"talk": person id}         take something to that person
##   "reward" {"coins": n, "supply": {id: n}, "gear": tier}   (gear: a piece of that tier not owned yet)
## FINDS: things lying in a place. "id", "place", "pos", "sprite" (pack art), "name", "reward" (as above),
##   "errand": only there while that errand is taken. Opened once ("find:<id>" in the save).
## Save: "errand:<id>" = 0 not taken, 1 taken, 2 done; "errand:<id>:n" = battles won for it.

const Supplies = preload("res://scripts/data/supplies.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Tale = preload("res://scripts/data/tale.gd")

const ERRANDS := [
	{"id": "wenna_satchel", "giver": "patron", "name": "Old Wenna's satchel", "from": 1,
		"ask": "I dropped my satchel on the Elfwood Road the night the lamps went out. My late husband's pipe is in it. Would you look, knight?",
		"thanks": "My Edric's pipe! It still smells of him. Take this, and do not argue with an old woman.",
		"goal": {"finds": ["satchel"]}, "reward": {"coins": 30, "supply": {"herb": 2}}},
	{"id": "ysolde_bundle", "giver": "ysolde", "name": "Ysolde's bundle", "from": 1, "to": 5,
		"ask": "There is an elf on the Elfwood Road called Aelin. Stubborn. Give him these roots from me: they keep the thorn out of the blood.",
		"thanks": "He took them? Then he is less stubborn than I feared. Here, for your trouble.",
		"goal": {"talk": "aelin"}, "reward": {"coins": 25, "gear": 0},
		"given": "Ysolde's roots? ...Tell her I will chew them. Tell her nothing else."},
	{"id": "marta_oil", "giver": "marta", "name": "Oil for the lamps", "from": 1,
		"ask": "Every wagon of lamp oil is stopped by something in the wild. Clear the beasts off the roads near town, three fights' worth, and the oil can come through.",
		"thanks": "A wagon came in this morning, full! Forty lamps say thank you. So do I.",
		"goal": {"wins": "grass", "n": 3}, "reward": {"coins": 45, "supply": {"tonic": 1}}},
	{"id": "brandt_drill", "giver": "brandt", "name": "Brandt's drill", "from": 1,
		"ask": "A knight who sits in a tavern is a knight who forgets. Win five fights out in the wide world and come back to me.",
		"thanks": "Five, and still standing. The guard's purse is yours. Keep your guard up.",
		"goal": {"wins": "any", "n": 5}, "reward": {"coins": 60, "supply": {"herb": 2}}},
	{"id": "wicker_count", "giver": "wicker", "name": "Counting mushrooms", "from": 2,
		"ask": "I need to know how many mushroom rings there are. One on this road, one in the Rune Glade, one in the Deepwood. Go and look. Do not count them out loud.",
		"thanks": "Three! That is the right number. Good. You can have my lucky coins.",
		"goal": {"finds": ["ring_road", "ring_glade", "ring_deep"]}, "reward": {"coins": 35, "supply": {"herb": 2}}},
	{"id": "odo_pages", "giver": "odo", "name": "Brother Odo's pages", "from": 7,
		"ask": "The wind took two pages of my chronicle out over the wall. One went west into the woods, one south toward the old king's wall. I would be grateful.",
		"thanks": "Both! And only a little muddy. The chronicle is whole again. Take this from the scriptorium's box.",
		"goal": {"finds": ["page_west", "page_south"]}, "reward": {"coins": 70, "supply": {"tonic": 2}}},
	{"id": "nib_crates", "giver": "nib", "name": "Nib's lost crates", "from": 8,
		"ask": "The dead in the sand keep eating my caravans. Well. Not eating. Breaking. Win three fights in the sands and I can send one out again.",
		"thanks": "A caravan went and came back! With all its camels! Here, the best thing I have.",
		"goal": {"wins": "sand", "n": 3}, "reward": {"coins": 80, "supply": {"elixir": 1}}},
	{"id": "imre_carvings", "giver": "imre", "name": "The old carvings", "from": 8,
		"ask": "The beacon-builders carved their words in two more places I know of: in the Sunwell, and out on the sands east of here. Copy them for me.",
		"thanks": "\"The fire is lent, never given.\" So that is how it ends. Thank you, knight. Take this.",
		"goal": {"finds": ["carving_well", "carving_sand"]}, "reward": {"coins": 90, "gear": 1}},
]

const FINDS := [
	# what errands send you to find
	{"id": "satchel", "place": "elfwood", "pos": Vector2(470, 300), "sprite": "hub_ssack_0", "name": "A satchel", "errand": "wenna_satchel",
		"say": "An old leather satchel, half under the ferns. A pipe inside."},
	{"id": "ring_road", "place": "elfwood", "pos": Vector2(140, 290), "sprite": "hub_shroom_3", "name": "A mushroom ring", "errand": "wicker_count",
		"say": "A ring of small red mushrooms. You count them. They do not count back."},
	{"id": "ring_glade", "place": "glade", "pos": Vector2(90, 280), "sprite": "hub_shroom_3", "name": "A mushroom ring", "errand": "wicker_count",
		"say": "Another ring, by the stones. Smaller. Watchful."},
	{"id": "ring_deep", "place": "deepwood", "pos": Vector2(600, 320), "sprite": "hub_shroom_3", "name": "A mushroom ring", "errand": "wicker_count",
		"say": "The third ring, deep in the wood. One mushroom is missing. You decide not to tell Wicker."},
	{"id": "page_west", "place": "world", "pos": Vector2(120, 700), "sprite": "hub_note", "name": "A page", "errand": "odo_pages",
		"say": "A page in Brother Odo's small careful hand, caught in a bramble."},
	{"id": "page_south", "place": "world", "pos": Vector2(1060, 1070), "sprite": "hub_note", "name": "A page", "errand": "odo_pages",
		"say": "The second page, pinned against the old king's wall by the wind."},
	{"id": "carving_well", "place": "suncourt", "pos": Vector2(470, 300), "sprite": "hub_note", "name": "A carving", "errand": "imre_carvings",
		"say": "Old words cut in the stone. You copy them onto a page: \"The fire is lent...\""},
	{"id": "carving_sand", "place": "world", "pos": Vector2(1380, 1040), "sprite": "hub_note", "name": "A carving", "errand": "imre_carvings",
		"say": "A half-buried stone with the rest of the words: \"...never given.\" You copy them."},
	# SECRETS: chests nobody tells you about
	{"id": "chest_town_ne", "place": "village", "pos": Vector2(900, 200), "sprite": "hub_fchest", "name": "An old chest", "reward": {"coins": 20, "supply": {"herb": 1}}},
	{"id": "chest_town_se", "place": "village", "pos": Vector2(900, 510), "sprite": "hub_fchest", "name": "An old chest", "reward": {"coins": 15, "supply": {"tonic": 1}}},
	{"id": "chest_room", "place": "room", "pos": Vector2(24, 140), "sprite": "hub_fchest", "name": "Your old chest", "reward": {"coins": 10, "supply": {"herb": 1}}},
	{"id": "chest_elf_ne", "place": "elfwood", "pos": Vector2(590, 120), "sprite": "hub_fchest", "name": "A mossy chest", "reward": {"coins": 25, "supply": {"herb": 2}}},
	{"id": "chest_elf_sw", "place": "elfwood", "pos": Vector2(44, 320), "sprite": "hub_fchest", "name": "A mossy chest", "reward": {"gear": 0}},
	{"id": "chest_glade", "place": "glade", "pos": Vector2(430, 290), "sprite": "hub_fchest", "name": "A warden's cache", "reward": {"coins": 30, "supply": {"tonic": 1}}},
	{"id": "chest_deep_ne", "place": "deepwood", "pos": Vector2(670, 130), "sprite": "hub_fchest", "name": "A rotted chest", "reward": {"coins": 35, "supply": {"herb": 2}}},
	{"id": "chest_deep_sw", "place": "deepwood", "pos": Vector2(50, 330), "sprite": "hub_fchest", "name": "A rotted chest", "reward": {"gear": 0}},
	{"id": "chest_beacon", "place": "beacon", "pos": Vector2(50, 380), "sprite": "hub_fchest", "name": "A pilgrim's chest", "reward": {"coins": 40, "supply": {"tonic": 1, "herb": 1}}},
	{"id": "chest_world_w", "place": "world", "pos": Vector2(80, 1000), "sprite": "hub_fchest", "name": "A buried chest", "reward": {"coins": 50, "supply": {"herb": 2}}},
	{"id": "chest_world_ne", "place": "world", "pos": Vector2(1900, 130), "sprite": "hub_fchest", "name": "A miner's chest", "reward": {"gear": 1}},
	{"id": "chest_world_se", "place": "world", "pos": Vector2(1890, 1080), "sprite": "hub_dchest", "name": "A sand-scoured chest", "reward": {"coins": 70, "supply": {"elixir": 1}}},
	{"id": "chest_world_dunes", "place": "world", "pos": Vector2(980, 980), "sprite": "hub_dchest", "name": "A sand-scoured chest", "reward": {"coins": 45, "supply": {"tonic": 1}}},
	{"id": "chest_dust", "place": "dustwatch", "pos": Vector2(40, 380), "sprite": "hub_dchest", "name": "A trader's strongbox", "reward": {"coins": 55, "supply": {"herb": 2}}},
	{"id": "chest_well", "place": "suncourt", "pos": Vector2(60, 380), "sprite": "hub_dchest", "name": "An offering box", "reward": {"gear": 1}},
	{"id": "chest_hall", "place": "hall", "pos": Vector2(420, 230), "sprite": "hub_fchest", "name": "A forgotten chest", "reward": {"coins": 15, "supply": {"herb": 1}}},
]


# ------------------------------------------------------------------ state
static func state(id: String) -> int:
	return Save.hub_get("errand:" + id)


static func row(id: String) -> Dictionary:
	for r: Dictionary in ERRANDS:
		if String(r["id"]) == id:
			return r
	return {}


## The errand this person has for the knight now ({} = none): one not done, offered at this step.
static func for_giver(person: String) -> Dictionary:
	var s := Tale.step()
	for r: Dictionary in ERRANDS:
		if String(r["giver"]) != person or state(String(r["id"])) == 2:
			continue
		if state(String(r["id"])) == 1 or (s >= int(r.get("from", 0)) and s <= int(r.get("to", 999))):
			return r
	return {}


static func take(id: String) -> void:
	if state(id) == 0:
		Save.hub_set("errand:" + id, 1)
		Save.flush()


## How far along a taken errand is: [done, needed].
static func progress(r: Dictionary) -> Array:
	var goal: Dictionary = r["goal"]
	if goal.has("wins"):
		return [mini(Save.hub_get("errand:%s:n" % r["id"]), int(goal["n"])), int(goal["n"])]
	if goal.has("finds"):
		var n := 0
		for f: String in goal["finds"]:
			if Save.hub_get("find:" + f) > 0:
				n += 1
		return [n, (goal["finds"] as Array).size()]
	return [1 if Save.hub_get("errand:%s:n" % r["id"]) > 0 else 0, 1]


static func complete(r: Dictionary) -> bool:
	var p := progress(r)
	return state(String(r["id"])) == 1 and int(p[0]) >= int(p[1])


## The errands taken and not yet handed in.
static func active() -> Array:
	return ERRANDS.filter(func(r: Dictionary) -> bool: return state(String(r["id"])) == 1)


## A battle won on the world map, in this land ("grass", "robbers", "sand", "rock").
static func won(land: String) -> void:
	for r: Dictionary in active():
		var goal: Dictionary = r["goal"]
		if goal.has("wins") and (String(goal["wins"]) == "any" or String(goal["wins"]) == land):
			Save.hub_set("errand:%s:n" % r["id"], Save.hub_get("errand:%s:n" % r["id"]) + 1)


## Somebody was spoken to: an errand that asked for it is done. Returns their words for it ("" = none).
static func talked(person: String) -> String:
	for r: Dictionary in active():
		var goal: Dictionary = r["goal"]
		if goal.has("talk") and String(goal["talk"]) == person and Save.hub_get("errand:%s:n" % r["id"]) == 0:
			Save.hub_set("errand:%s:n" % r["id"], 1)
			Save.flush()
			return String(r.get("given", "Thank you."))
	return ""


## Hands an errand in: the reward. Returns what was given, in words.
static func hand_in(id: String) -> String:
	var r := row(id)
	if r.is_empty() or not complete(r):
		return ""
	Save.hub_set("errand:" + id, 2)
	var got := give(r.get("reward", {}))
	Save.flush()
	return got


# ------------------------------------------------------------------ finds
## The finds lying in this place now (not opened; an errand's only while it is taken).
static func finds_in(place_id: String) -> Array:
	return FINDS.filter(func(f: Dictionary) -> bool:
		if String(f["place"]) != place_id or Save.hub_get("find:" + String(f["id"])) > 0:
			return false
		return not f.has("errand") or state(String(f["errand"])) == 1 or G.flag("allfinds"))      # (--allfinds: test)


static func find_row(id: String) -> Dictionary:
	for f: Dictionary in FINDS:
		if String(f["id"]) == id:
			return f
	return {}


## Opens a find: its reward. Returns the words to show.
static func open(id: String) -> String:
	var f := find_row(id)
	if f.is_empty() or Save.hub_get("find:" + id) > 0:
		return ""
	Save.hub_set("find:" + id, 1)
	var words := String(f.get("say", ""))
	var got := give(f.get("reward", {}))
	Save.flush()
	if got != "":
		words = (words + " " if words != "" else "") + "Inside: " + got + "."
	return words


## Gives a reward ({"coins", "supply", "gear"}); returns it in words.
static func give(reward: Dictionary) -> String:
	var bits: Array = []
	if int(reward.get("coins", 0)) > 0:
		Save.hub_set("bank:coins", Save.hub_get("bank:coins") + int(reward["coins"]))
		bits.append("%d coins" % int(reward["coins"]))
	var supplies: Dictionary = reward.get("supply", {})
	for id: String in supplies:
		var n := Supplies.give(id, int(supplies[id]))
		if n > 0:
			bits.append("%d %s" % [n, String(Supplies.row(id)["name"]) + ("s" if n > 1 else "")])
	if reward.has("gear"):
		var g := Gear.roll_common(int(reward["gear"]))
		if g != "" and not Gear.owned(g) and Gear.grant(g):
			bits.append(String(Gear.row(g)["name"]))
		else:
			Save.hub_set("bank:coins", Save.hub_get("bank:coins") + 30)
			bits.append("30 coins")
	return ", ".join(bits)
