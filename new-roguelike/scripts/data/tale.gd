extends RefCounted
## THE STORY (the owner said yes to it on 12 Nov 2026). Everything the story IS lives in this file:
## its steps, what people say at each step, the story's battles, its places, the intro's words.
##
## The story in short: the first king set the Dawnfire in his crown and lit four beacons with it;
## their light keeps the long night out and keeps something asleep under Hollow Hill. The king
## died, the crown was broken in four, four lords carried the shards away and the beacons went
## dark. The nights grow longer. Aldous, last knight of the king's guard, sets out from Wickmere,
## the lantern town under the hill, to bring the shards back and relight the beacons. Each beacon
## SWALLOWS its shard: the crown can never be made again. Three companions join on the way.
##
## CHAPTER ONE (built): the Elfwood. Thessaly the warden joins; the Bramble Giant; the first beacon.
## Chapters two to four (the Sands and Seraphine, the Cinder Mountains and Grukk, the Sunken
## Archive) and the end under Hollow Hill are NOT built yet.
##
## HOW IT WORKS
##   step()        where the story stands: a number kept in the save ("tale:step"). STEPS[step] is
##                 the line in the top left corner ("Next: ...").
##   TALK          who says what at which step: id of a person -> rows
##                   {"from": 0, "to": 0, "pages": [...], "option": "button words", "do": {...}}
##                 ("to" may be left out = from then on). No "option" = just talk.
##   "do"          what choosing the option does: {"step": n}  {"battle": id}  {"light": land}
##                 {"join": companion id}  {"coins": n}  {"say": "banner words"}; several at once is fine.
##   BATTLES       the story's own turn-based battles (scripts/battle/): who is in them, where,
##                 and the "do" of winning.
##   ENTER         walking into a place at a step: {place: {step: do}}.
##   SCENES        words that come by themselves on arriving somewhere at a step (each once).
##   places        town(), deepwood(), beacon() are the story's places (the format is that of
##                 scripts/data/places.gd, which hands them out). An exit may have "tale": the
##                 step it opens at, and "why": what the banner says before. A person may have
##                 "tale_from" / "tale_to": the steps they are there for.
## The OLD story (the hill's seals, scripts/data/story.gd, the real-time levels) is switched off
## while this one is on. `--oldstory` on the command line brings it back (the old tests use it).
## Names and words are placeholders the owner may rewrite.

const Allies = preload("res://scripts/data/allies.gd")

## The line in the corner, by step.
const STEPS := [
	"Find Captain Hale in the square of Wickmere",        # 0
	"Take the east road into the Elfwood",                # 1
	"Find the Warden of the Wood in the Rune Glade",      # 2
	"Go on into the Deepwood with Thessaly",              # 3
	"Climb to the dark beacon of the wood",               # 4
	"Set the shard in the beacon",                        # 5
	"Bring word to Captain Hale in Wickmere",             # 6
	"The road to the Sands opens in the next chapter",    # 7
]
const LAST_STEP := 7

## The words under the intro's seven pictures (scripts/hub/intro.gd; the pictures are the old ones).
const INTRO := [
	"Long ago the first king set the Dawnfire in his crown, and no night could stand before him.",
	"With it he lit four beacons, one in each land. While they burned, the long night stayed away.",
	"The king died. His crown was broken in four, and four lords carried the shards home. One by one the beacons went dark.",
	"Now every night is longer than the last, and things walk in it.",
	"Aldous, last knight of the king's guard, was there when the crown broke. He has walked every night since.",
	"He came to Wickmere, the lantern town under Hollow Hill, where they still keep the lamps lit.",
	"And under the hill, something that has slept since the first dawn opened its eyes.",
]

const TALK := {
	"hale": [
		{"from": 0, "to": 0, "pages": [
			"So you are the one Oswin put up at the Flagon. Aldous, of the king's guard. I thought you were all dead.",
			"Then you know what broke. The crown is in four pieces and the beacons are cold. We burn lamps here from dusk to dawn, and dusk comes earlier every week.",
			"The beacon of the Elfwood went dark first. Lord Caerwyn of the elves carried his shard up to it, and nobody has come down that hill since.",
			"The wood is sick now. Thorns in the roots, thorns in the people. Go east, find the Warden of the Wood. She will know the way up.",
		], "option": "I will go east", "do": {"step": 1, "say": "The east road is open"}},
		{"from": 1, "to": 5, "pages": ["East, knight. The Warden keeps the Rune Glade past the Elfwood Road. Rest at the Flagon if the night is too long."]},
		{"from": 6, "to": 6, "pages": [
			"We saw it from the wall. A light over the Elfwood, the colour of morning. Half the town stood in the square and wept.",
			"And the shard is gone into the stone? Then there will never be a crown again. Good. A light does more than a king.",
			"Three beacons are still dark: the Sands, the Cinder Mountains, the Sunken Archive. Rest first. Take this from the watch's chest.",
		], "option": "Take the watch's thanks", "do": {"step": 7, "coins": 60, "say": "Chapter one is done: +60 coins"}},
		{"from": 7, "pages": ["The road to the Sands is being cleared. Soon, knight. Until then the wild lands south of the gate will keep your sword sharp."]},
	],
	"barkeep": [
		{"from": 0, "pages": ["The Hollow Flagon. Your bed is upstairs and paid for by the watch. Sleep when the night gets too long; the lamps will keep."]},
	],
	"patron": [
		{"from": 0, "pages": ["I was a girl when the king still rode through with the fire on his head. You could read by him at midnight. Nobody believes me."]},
	],
	"tam": [
		{"from": 0, "pages": ["Lamp oil, wicks, and steel when there is time for steel. Helmets and mail are on the shelf, if the watch's coin is good."]},
	],
	"odo": [
		{"from": 0, "to": 5, "pages": [
			"I am writing it all down, in case there is a morning to read it in.",
			"Four lords took four shards: Caerwyn of the Elfwood, the Dune Queen, the Forgemaster, and the Archivist who answers no letters. Each thought the fire would keep their own people safe.",
		]},
		{"from": 6, "pages": ["One beacon lit, and it ate its shard to burn. I have written that down twice. A crown that cannot be remade: the lords will not like it."]},
	],
	"ysolde": [
		{"from": 0, "to": 2, "pages": ["I walked out of the Elfwood with thorns in my hair and my sister's name in my mouth. Thessaly would not leave the stones. If you go east, tell her Ysolde is alive."]},
		{"from": 3, "to": 5, "pages": ["Thessaly is with you? Then the stones are safe for one more night. Mind the Deepwood. It listens."]},
		{"from": 6, "pages": ["I can smell the wood from here. It smells like it did when we were small. Thank you, tin man."]},
	],
	"marta": [
		{"from": 0, "pages": ["Forty lamps on the square and I trim every one. If one goes out, the dark comes to look. Do not stand under a dead lamp, dear."]},
	],
	"mira": [
		{"from": 0, "to": 5, "pages": ["No wagons since the nights got long. I sell what I carried in, and I carried in very little."]},
		{"from": 6, "pages": ["A wagon came through the Elfwood this morning. The first in a month. I could kiss you."]},
	],
	"brandt": [
		{"from": 0, "to": 0, "pages": ["Nobody takes the east road without the Captain's word. He is by the fire in the square."]},
		{"from": 1, "to": 5, "pages": ["East road is yours. The wood starts where the lamps stop."]},
		{"from": 6, "pages": ["I have stood this gate at night for a year. Tonight I could see the trees."]},
	],
	"aelin": [
		{"from": 0, "to": 5, "pages": ["Turn back, tin man. Past the glade our own kin wait with thorns in their eyes. When the beacon died the dark got into the roots."]},
		{"from": 6, "pages": ["The roots are drinking light again. I had forgotten what the road looked like."]},
	],
	"wicker": [
		{"from": 0, "to": 5, "pages": ["The mushrooms walk at night. I counted nine. Mother says do not count them, they count back."]},
		{"from": 6, "pages": ["They went back into the ground when the big light came. All nine. I checked."]},
	],
	"thessaly": [
		{"from": 2, "to": 2, "pages": [
			"Knight. You picked a poor hour. They come for the stones every night now, and tonight there are more of them.",
			"They were my wardens once. The thorn does not kill, it keeps. If we put them down, they sleep, and wake themselves.",
			"Stand with me and I will take you to the beacon after. Lord Caerwyn went up with his shard a year ago. I mean to know why he never came down.",
		], "option": "Stand with her", "do": {"battle": "glade"}},
	],
	"thornwatch": [
		{"from": 3, "to": 3, "pages": [
			"Three of the lost wardens stand in the path, bows half drawn, thorns through their hands. They do not blink.",
			"Thessaly: \"Orrin. Maeve. Little Pell. Forgive me.\"",
		], "option": "Go through them", "do": {"battle": "deepwood"}},
	],
	"giant": [
		{"from": 4, "to": 4, "pages": [
			"Something as big as a house sits against the dead beacon, grown through with briar. On its brow, tangled in thorn, a splinter of gold burns like a held breath.",
			"Thessaly: \"That is Caerwyn's shard. And that is Caerwyn's hound, old Bramblejaw, who was the size of a pony when I was a girl.\"",
			"Thessaly: \"He carried the fire up here to keep the wood safe. It fed the thorns instead. It fed HIM.\"",
			"The giant opens one eye.",
		], "option": "Draw your sword", "do": {"battle": "giant"}},
	],
	"beacon": [
		{"from": 5, "to": 5, "pages": [
			"In the briar where the giant fell lies a silver circlet, an elf lord's, and nothing else of him. Thessaly picks it up and says nothing for a while.",
			"The shard is warm in your hand. The beacon's cold bowl is carved with a hollow its exact shape.",
			"Thessaly: \"It will not come out again once it is in. No crown, after this. Only the light.\"",
		], "option": "Set the shard in the beacon", "do": {"step": 6, "light": "elfwood", "say": "The beacon of the Elfwood burns"}},
		{"from": 6, "pages": ["The beacon burns the colour of morning. The shard is somewhere inside the fire, and the fire does not give it back."]},
	],
}

## SCENES: words that come by themselves when the knight arrives somewhere at a step of the story
## (a narrator, or somebody calling out). Each plays ONCE, in the order written here, one per
## arrival. "sprite" is the speaker's picture ("" = none). Keep them short: two or three pages.
const SCENES := [
	{"id": "wake", "place": "room", "from": 0, "to": 0, "name": "Oswin", "title": "Barkeep of the Hollow Flagon", "sprite": "", "pages": [
		"Knight! You are awake. Good. You slept a night and a day, and the night was the longer of the two.",
		"Captain Hale wants a word with you. He is in the square, by the watch-fire. The looking glass by your bed is yours to use.",
	]},
	{"id": "town", "place": "village", "from": 0, "to": 0, "name": "Wickmere", "title": "The lantern town under Hollow Hill", "sprite": "", "pages": [
		"Forty lamps burn round the square, though the sun is not yet down. Nobody in Wickmere waits for the dark any more.",
		"Behind the roofs the hill stands black against the sky, and in its side the old gate, shut since before anybody here was born.",
	]},
	{"id": "road", "place": "elfwood", "from": 2, "to": 2, "name": "The Elfwood Road", "title": "", "sprite": "", "pages": [
		"The lamps of Wickmere end at the gate. Ten steps on, the wood is darker than any evening has a right to be.",
		"Something has been at the trees. Black thorn, thick as a wrist, grown clean through the bark.",
	]},
	{"id": "hail", "place": "glade", "from": 2, "to": 2, "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "pages": [
		"Hold there! Hands where the stones can see them.",
		"...A knight. A real one, with the king's mark on his shield. Then come up to the ring, and quickly. They are close.",
	]},
	{"id": "after_glade", "place": "glade", "from": 3, "to": 3, "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "pages": [
		"They will sleep until moonrise. That one is Orrin. He taught me to string a bow, and I have just put an arrow through his shoulder.",
		"My sister is alive? In your town? ...Then there is one thing in this wood I have not failed at.",
		"Enough. The beacon stands past the Deepwood. Keep to the path, knight. The wood listens now.",
	]},
	{"id": "deep", "place": "deepwood", "from": 3, "to": 3, "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "pages": [
		"This was the heart of the wood. We sang here at midsummer, every one of us. Listen to it now.",
		"Nothing. Not a bird. The thorn drinks sound as well as light.",
	]},
	{"id": "after_deep", "place": "deepwood", "from": 4, "to": 4, "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "pages": [
		"Little Pell is breathing. They all are. When the beacon burns the thorn will let them go. I have to believe that.",
	]},
	{"id": "hilltop", "place": "beacon", "from": 4, "to": 4, "name": "The Beacon of the Wood", "title": "", "sprite": "", "pages": [
		"The path climbs out of the trees. On the bare hilltop stands the beacon, cold for a year, in its ring of stones.",
		"Something vast is asleep against it.",
	]},
	{"id": "dawn", "place": "beacon", "from": 6, "to": 6, "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "pages": [
		"Look at it, Aldous. Look at the wood.",
		"The light is running down the hill like water, and where it goes the thorn is letting go of the trees.",
		"Caerwyn was wrong to keep the fire and right to carry it here. I will take his circlet to my sister. And then I am coming with you. Three beacons are still dark.",
	]},
	{"id": "gate_open", "place": "village", "from": 6, "to": 6, "name": "Wickmere", "title": "", "sprite": "", "pages": [
		"The east gate stands open. For the first time in a year there are people on the wall looking out, and not in.",
	]},
	{"id": "sisters", "place": "village", "from": 7, "to": 7, "name": "The sisters", "title": "", "sprite": "pc_elf_druid", "pages": [
		"Ysolde is waiting at the edge of the square. She does not run. Elves do not run. She walks very fast.",
		"Ysolde: \"You look terrible.\"   Thessaly: \"You look alive.\"",
		"They stand a long while with their foreheads together, the way elves do, and the whole square finds something else to look at.",
	]},
]

## The story's own battles. "foes": ids of scripts/data/enemies.gd, or "boss": a row of BOSSES.
## "look": a stage of scripts/battle/stage.gd.  "tier": how hard the monsters hit (see battles.gd).
## "xp_bonus": XP on top of the monsters' own (the two battles before the giant are set so that a
## knight who fights only the story's battles meets the giant at level 3; dev/battle_sim.tscn).
const BATTLES := {
	"glade": {"title": "The thorn-sick come for the stones", "look": "forest_night", "tier": 0,
		"foes": ["thorn_elf", "elf_stalker", "sporeling"], "with": ["thessaly"], "xp_bonus": 15,
		"win": {"step": 3, "join": "thessaly", "say": "Thessaly, Warden of the Wood, travels with you"}},
	"deepwood": {"title": "The lost wardens", "look": "forest_night", "tier": 0,
		"foes": ["elf_stalker", "wood_beast", "elf_stalker", "long_cap"], "xp_bonus": 26,
		"win": {"step": 4, "say": "The path to the beacon is open"}},
	"giant": {"title": "Old Bramblejaw", "look": "forest_night", "tier": 0, "boss": "bramblejaw",
		"win": {"step": 5, "say": "The Bramble Giant falls"}},
}

## Bosses of the story's battles. The numbers are for a knight of about level 4 with one companion.
##   "sweep"  every this-many turns the boss strikes everybody at once, at "sweep_power"
const BOSSES := {
	"bramblejaw": {"name": "Old Bramblejaw", "sprite": "boss_ogre", "tint": Color(0.72, 0.95, 0.70),
		"hp": 185, "atk": 8.8, "def": 2.0, "speed": 8.0, "sweep": 3, "sweep_power": 0.75, "sweep_name": "Briar Sweep",
		"xp": 90, "coins": 40},
}

## Walking into a place at a step: {place: {step: do}}.
const ENTER := {
	"elfwood": {1: {"step": 2}},
}

## What people of the old story do (open the hill's levels, hand out its quests, sell its
## items ...) has no part in this one: with the story on they only talk.
const RETIRED := ["gate", "quests", "collection", "side", "train", "pack", "hero", "shop", "ally"]
const LATER := "This road belongs to a later chapter of the story."


# ------------------------------------------------------------------ state
static func on() -> bool:
	return not G.flag("oldstory")


static func step() -> int:
	return clampi(Save.hub_get("tale:step"), 0, LAST_STEP)


static func objective() -> String:
	return STEPS[step()]


static func lit(land: String) -> bool:
	return Save.hub_get("tale:lit:" + land) > 0


## How many beacons burn (0 to 4).
static func beacons() -> int:
	var n := 0
	for land: String in ["elfwood", "sands", "cinder", "archive"]:
		if lit(land):
			n += 1
	return n


## The scene that should play on arriving in this place now (see SCENES), as the talk window
## takes it: {"name", "title", "sprite", "pages"}. It is marked as seen. {} = none.
static func take_scene(place_id: String) -> Dictionary:
	var at := step()
	for row: Dictionary in SCENES:
		if String(row["place"]) != place_id or at < int(row.get("from", 0)) or at > int(row.get("to", 999)):
			continue
		if Save.hub_get("tale:seen:" + String(row["id"])) > 0:
			continue
		Save.hub_set("tale:seen:" + String(row["id"]), 1)
		return {"name": row["name"], "title": row.get("title", ""), "sprite": row.get("sprite", ""), "pages": (row["pages"] as Array).duplicate()}
	return {}


## The row of TALK that fits this person now, or {}.
static func beat(npc_id: String) -> Dictionary:
	var s := step()
	for row: Dictionary in TALK.get(npc_id, []):
		if s >= int(row.get("from", 0)) and s <= int(row.get("to", 999)):
			return row
	return {}


## Is this person (a row of a place's "people") there at this step?
static func here(row: Dictionary) -> bool:
	var s := step()
	return s >= int(row.get("tale_from", 0)) and s <= int(row.get("tale_to", 999))


## Does what a "do" says. Returns {"battle": id} when a battle must start, {"say": words} for
## the banner, or {}. A step never goes backwards.
static func apply(what: Dictionary) -> Dictionary:
	var out := {}
	if what.has("step") and int(what["step"]) > step():
		Save.hub_set("tale:step", int(what["step"]))
	if what.has("light"):
		Save.hub_set("tale:lit:" + String(what["light"]), 1)
	if what.has("join"):
		Allies.join(String(what["join"]))
	if what.has("coins"):
		Save.hub_set("bank:coins", Save.hub_get("bank:coins") + int(what["coins"]))
	if what.has("say"):
		out["say"] = String(what["say"])
	if what.has("battle"):
		out["battle"] = String(what["battle"])
	Save.flush()
	return out


## Walking into a place: does what ENTER says for this step. Returns as apply() does.
static func entered(place_id: String) -> Dictionary:
	var by: Dictionary = ENTER.get(place_id, {})
	if by.has(step()):
		return apply(by[step()])
	return {}


# ------------------------------------------------------------------ places
## A house (a row of a place's "houses") as the flat pieces the old 2D look shows it with: a wall
## under the pack's drawn roof, a door, a window either side. Rows for hub.gd's _prop().
## (The 3D look builds a real house from the same row: scripts/hub/view3d.gd _build_house.)
static func house_props(h: Dictionary) -> Array:
	var at: Vector2 = h["at"]
	var wall := String(h["wall"])
	var wall_h := float(h.get("wall_h", 51.0))
	var dx := float(h.get("win_dx", 30.0))
	var up := float(h.get("win_up", 12.0))
	var out: Array = [[wall, at.x, at.y, 0, 0], [String(h.get("flat_roof", "hub_roof_wood")), at.x, at.y + 1.0, 0, -(wall_h - 6.0)],
		[String(h.get("door", "hub_door_wood")), at.x, at.y + 2.0, 0, 0]]
	if String(h.get("windows", "")) != "":
		out.append([String(h["windows"]), at.x - dx, at.y + 2.0, 0, -up])
		out.append([String(h["windows"]), at.x + dx, at.y + 2.0, 0, -up])
	if bool(h.get("chimney", false)):
		out.append(["hub_chimney", at.x + 34.0, at.y - 1.0, 0, -(wall_h + 46.0)])
	return out


## WICKMERE, the lantern town under Hollow Hill: where the story starts and comes back to.
## (It takes the old village's place: the id is still "village", so every door that led there does.)
static func town() -> Dictionary:
	var size := Vector2(960, 560)
	var props: Array = [
		# the sealed gate of Hollow Hill in the rocks, north: nobody goes in until four beacons burn
		["hub_rock_2", 438, 104, 0, 2], ["hub_rock_moss_2", 524, 105, 0, 2], ["hub_rock_moss_1", 408, 108, 0, 2], ["hub_rock_1", 554, 108, 0, 2],
		["hub_gate_0", 480, 108, 0, 0], ["hub_statue_1", 436, 134, 9, 2], ["hub_statue_0", 526, 134, 7, 2],
		["hub_bench_long", 206, 168, 10, 2],
		# the square: cobbles (see "floor"), the fountain in the middle, benches, the watch-fire in its
		# north-east corner (see "fire"). Pieces from the Garden and Castle packs (ids hub_g*, hub_c*).
		["hub_gfountain", 480, 338, 36, 0], ["hub_gbench", 400, 372, 12, 1], ["hub_gbench", 560, 372, 12, 1],
		["hub_stonebench", 404, 252, 8, 1], ["hub_planter", 384, 300, 6, 1], ["hub_planter", 576, 326, 6, 1],
		["hub_gurn_0", 372, 372, 5, 1], ["hub_gurn_1", 590, 372, 5, 1],
		# cypresses by the gate and between the houses, potted trees at the doors, flower beds under the windows
		["hub_gcypress_0", 436, 152, 6, 0], ["hub_gcypress_0", 524, 152, 6, 0], ["hub_gcypress_1", 228, 178, 6, 0], ["hub_gcypress_1", 734, 180, 6, 0],
		["hub_gcypress_0", 566, 168, 6, 0], ["hub_gcypress_1", 394, 170, 6, 0], ["hub_gcypress_0", 124, 512, 6, 0], ["hub_gcypress_1", 690, 520, 6, 0],
		["hub_cpot_1", 98, 162, 4, 0], ["hub_cpot_2", 150, 162, 4, 0], ["hub_cpot_1", 636, 170, 4, 0], ["hub_cpot_2", 684, 170, 4, 0],
		["hub_gbed_0", 270, 174, 0, 0], ["hub_gbed_5", 330, 174, 0, 0], ["hub_gbed_2", 806, 186, 0, 0], ["hub_gbed_7", 866, 186, 0, 0],
		["hub_gbed_4", 74, 414, 0, 0], ["hub_gbed_1", 134, 414, 0, 0], ["hub_gbed_6", 826, 494, 0, 0], ["hub_gbed_3", 886, 494, 0, 0],
		["hub_gbed_1", 444, 392, 0, 0], ["hub_gbed_4", 516, 392, 0, 0],
		# the smithy's yard, east of the square
		["hub_anvil_0", 716, 258, 16, 4], ["hub_bench_1", 752, 236, 12, 3], ["hub_stone_0", 684, 240, 8, 2],
		# garden fences and green
		["hub_fence_a", 296, 196, 6, 0], ["hub_fence_a", 336, 196, 6, 0], ["hub_stonebench", 250, 444, 8, 1], ["hub_planter", 330, 446, 6, 1],
		["hub_fence_a", 740, 500, 6, 0], ["hub_fence_a", 780, 500, 6, 0], ["hub_fence_b", 860, 208, 6, 0], ["hub_fence_b", 820, 208, 6, 0],
		["hub_bush_green_1", 232, 236, 10, 4], ["hub_bush_orange_2", 618, 220, 9, 4], ["hub_bush_deep_1", 150, 470, 10, 4],
		["hub_bush_rust_2", 646, 372, 9, 4], ["hub_tree_green_3", 64, 300, 6, 6], ["hub_tree_teal_3", 900, 392, 6, 6],
		["hub_tree_pink_4", 430, 452, 4, 5], ["hub_tree_teal_4", 596, 502, 4, 5], ["hub_bloom_1", 250, 300, 0, 2], ["hub_bloom_5", 720, 330, 0, 2],
		# lamp posts: the town keeps them lit from dusk to dawn (each has a light, see "lights")
		["hub_post", 360, 250, 3, 0], ["hub_post", 600, 250, 3, 0], ["hub_post", 360, 400, 3, 0], ["hub_post", 600, 400, 3, 0],
		["hub_post", 210, 300, 3, 0], ["hub_post", 760, 310, 3, 0], ["hub_post", 480, 470, 3, 0], ["hub_post", 880, 250, 3, 0],
	]
	# The houses ("houses": real 3D in the 3D look, flat pieces in the old one). The Hollow Flagon
	# first (its door leads into the hall); two more on the north row; the watch house; one at
	# each of the west and east edges. A house hides the ground behind it as high as its roof, so
	# none stands in the middle of the town, and the ground behind each is in "blocks".
	#   "gable": true = the pointed end faces the street     "rise" = how high the roof stands, px
	#   "roof" = the 3D roof's cover (hub_roof_planks / hub_roof_tiles); "flat_roof" = the old look's drawn roof
	var houses: Array = [
		{"at": Vector2(124, 152), "wide": 128.0, "deep": 60.0, "wall": "hub_wall_plaster", "wall_h": 56.0, "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood",
			"rise": 40.0, "gable": true, "door": "hub_doorway", "windows": "hub_window", "win_dx": 38.0, "win_up": 14.0, "chimney": true},
		{"at": Vector2(300, 160), "wall": "hub_wall_brick", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 30.0,
			"door": "hub_door_arch", "windows": "hub_win_arch"},
		{"at": Vector2(660, 160), "wall": "hub_wall_dark", "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 34.0, "gable": true,
			"door": "hub_door_iron", "windows": "hub_win_tall", "chimney": true},
		{"at": Vector2(836, 172), "wall": "hub_wall_log", "wall_h": 56.0, "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 30.0,
			"door": "hub_door_wood", "windows": "hub_win_shut"},
		{"at": Vector2(104, 400), "wall": "hub_wall_white", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 32.0, "gable": true,
			"door": "hub_door_wood", "windows": "hub_win_shut", "chimney": true},
		{"at": Vector2(856, 480), "wall": "hub_wall_plank", "wall_h": 54.0, "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 30.0,
			"door": "hub_door_arch", "windows": "hub_win_closed"},
	]
	var lamp := Color(1.0, 0.78, 0.46)
	var lights: Array = [[Vector2(552, 258), Color(1.0, 0.72, 0.42), 2.3, 0.8]]
	for at: Vector2 in [Vector2(360, 250), Vector2(600, 250), Vector2(360, 400), Vector2(600, 400), Vector2(210, 300), Vector2(760, 310), Vector2(480, 470), Vector2(880, 250)]:
		lights.append([at - Vector2(0, 40), lamp, 1.0, 0.55])
	for at: Vector2 in [Vector2(124, 150), Vector2(300, 158), Vector2(660, 158), Vector2(836, 170), Vector2(104, 398), Vector2(856, 478)]:
		lights.append([at + Vector2(0, 8), lamp, 0.8, 0.4])           # the glow of a house's windows on its doorstep
	lights.append([Vector2(480, 96), Color(0.6, 0.55, 1.0), 1.2, 0.4])    # the cold of the sealed gate
	return {
		"name": "Wickmere", "camp": 0, "size": size, "outdoor": true, "walk": Rect2(40, 150, 880, 380), "spawn": Vector2(480, 404),
		"props": props, "houses": houses,
		"tour": [Vector2(480, 200), Vector2(300, 436), Vector2(480, 404), Vector2(720, 270), Vector2(170, 210)],     # test pictures (--hub=village --shots)
		# Hollow Hill: behind the north row the ground climbs, and the hill itself swells out of
		# the slope behind the sealed gate (only in the 3D look; nobody walks up there)
		"rise": {"from": 100.0, "over": 96.0, "height": 52.0, "mound": {"at": Vector2(480, 6), "radius": 210.0, "height": 70.0}},
		# the mere the town is named for, in the south-west corner (nobody walks into it)
		"water": [{"at": Vector2(262, 484), "radius": Vector2(116, 36),
			"lilies": [["hub_glily_0", 222, 478], ["hub_glily_1", 306, 494], ["hub_glily_2", 190, 496], ["hub_glily_2", 336, 474]]}],
		# cobbles: the square, and a street to the gate, the south road, the east gate and the west side
		"floor": [["hub_gcobble", Rect2(368, 232, 224, 144)], ["hub_gcobble", Rect2(464, 136, 32, 96)], ["hub_gcobble", Rect2(464, 376, 32, 168)],
			["hub_gcobble", Rect2(592, 268, 352, 48)], ["hub_gcobble", Rect2(144, 268, 224, 48)]],
		"paths": [[Vector2(160, 268), Vector2(130, 176)],
			[Vector2(300, 176), Vector2(330, 262)], [Vector2(660, 176), Vector2(640, 262)], [Vector2(120, 416), Vector2(360, 412)],
			[Vector2(840, 496), Vector2(610, 420)], [Vector2(836, 186), Vector2(850, 270)]],
		"scatter": {"hub_tuft": [24, 150], "hub_flower": [26, 70], "hub_pebble": [20, 26], "hub_twig": [10, 10]},
		"scatter_rect": Rect2(8, 180, 944, 372),
		"fire": Vector2(552, 270),
		# things that move: [id, x, y, frames a second, solid radius, turned round]: the statues that pour into the mere
		"anims": [["hub_gspout", 398, 478, 6.0, 7.0, false], ["hub_gspout", 126, 478, 6.0, 7.0, true]],
		# a small flame on top of every lamp post (the posts are in "props", their glow in "lights")
		"torches": [Vector2(360, 250), Vector2(600, 250), Vector2(360, 400), Vector2(600, 400), Vector2(210, 300), Vector2(760, 310), Vector2(480, 470), Vector2(880, 250)],
		"forest": {"top_gaps": [[416.0, 544.0], [40.0, 250.0], [236.0, 364.0], [596.0, 724.0], [772.0, 900.0]],
			"behind": [["hub_tree_pink_2", 480, 60], ["hub_tree_green_2", 416, 80], ["hub_tree_teal_2", 546, 80]],
			"open": [Rect2(930, 220, 60, 130), Rect2(420, 520, 120, 90), Rect2(130, 500, 270, 110)]},     # (the last: no hedge in front of the mere)
		"blocks": [Rect2(60, 96, 128, 56), Rect2(252, 108, 96, 52), Rect2(612, 108, 96, 52), Rect2(788, 116, 96, 56),
			Rect2(40, 262, 128, 138), Rect2(792, 340, 128, 140), Rect2(384, 96, 192, 34)],
		"exits": [{"rect": Rect2(112, 150, 24, 12), "to": "hall", "at": Vector2(30, 232)},
			{"rect": Rect2(912, 240, 10, 80), "to": "elfwood", "at": Vector2(52, 204), "tale": 1, "why": "Nobody takes the east road without the Captain's word."},
			{"rect": Rect2(440, 522, 80, 10), "to": "world", "at": Vector2(300, 650), "tale": 1, "why": "Speak with Captain Hale first. He is by the fire."}],
		"people": [
			{"id": "hale", "name": "Captain Hale", "title": "Captain of the Lantern Watch", "sprite": "pc_royal_knight", "hands": "pc_hand_castle_17",
				"pos": Vector2(592, 292), "face": -1, "role": "chat", "text": ""},
			{"id": "tam", "name": "Tam", "title": "Smith and Lampwright", "sprite": "pc_npc_peasant_a", "hands": "pc_hand_base_2",
				"pos": Vector2(690, 262), "face": 1, "role": "chat", "as": "smith", "text": ""},
			{"id": "odo", "name": "Brother Odo", "title": "Chronicler", "sprite": "pc_scholar_researcher", "hands": "pc_hand_library_6",
				"pos": Vector2(300, 186), "face": 1, "role": "chat", "text": ""},
			{"id": "ysolde", "name": "Ysolde", "title": "Elf of the Wood", "sprite": "pc_elf_druid", "hands": "pc_hand_elf_23",
				"pos": Vector2(250, 330), "face": 1, "role": "chat", "text": ""},
			{"id": "marta", "name": "Marta", "title": "Lamp Trimmer", "sprite": "pc_npc_tavern_a", "hands": "pc_hand_base_2",
				"pos": Vector2(378, 262), "face": 1, "role": "chat", "text": ""},
			{"id": "mira", "name": "Mira", "title": "Pedlar", "sprite": "pc_npc_tavern_b", "hands": "pc_hand_base_2",
				"pos": Vector2(600, 430), "face": -1, "role": "chat", "text": ""},
			{"id": "brandt", "name": "Sergeant Brandt", "title": "Watch of the East Gate", "sprite": "pc_royal_soldier", "hands": "pc_hand_castle_17",
				"pos": Vector2(884, 300), "face": -1, "role": "chat", "text": ""},
		],
		"lights": lights,
	}


## THE DEEPWOOD: the old wood between the Rune Glade and the beacon's hill.
static func deepwood() -> Dictionary:
	var glow := lit("elfwood")
	return {
		"name": "The Deepwood", "size": Vector2(720, 380), "outdoor": true, "walk": Rect2(30, 110, 660, 236), "spawn": Vector2(50, 230),
		"rise": {"from": 100.0, "over": 84.0, "height": 52.0},
		"hills": [{"at": Vector2(330, 250), "radius": 120.0, "height": 18.0, "top": 20.0}, {"at": Vector2(600, 300), "radius": 110.0, "height": 14.0}],
		"tint": Color(0.98, 0.92, 0.78) if glow else Color(0.56, 0.70, 0.90),
		"props": [["hub_tree_teal_1", 250, 200, 8, 8], ["hub_tree_green_1", 470, 320, 8, 8], ["hub_tree_pink_2", 610, 190, 7, 7],
			["hub_rune_2", 150, 180, 5, 2], ["hub_rune_0", 560, 300, 9, 3], ["hub_bloom_0", 130, 300, 0, 2], ["hub_bloom_6", 360, 170, 0, 2],
			["hub_bloom_5", 640, 290, 0, 2], ["hub_shroom_0", 300, 310, 0, 1], ["hub_shroom_1", 420, 180, 0, 1], ["hub_shroom_2", 540, 220, 0, 1],
			["hub_vine_0", 200, 300, 0, 2], ["hub_vine_1", 500, 160, 0, 2], ["hub_rock_moss_0", 330, 240, 12, 3], ["hub_rock_moss_2", 90, 170, 12, 3],
			["hub_stump_0", 590, 250, 12, 4], ["hub_bush_deep_0", 400, 320, 12, 5], ["hub_bush_deep_1", 180, 240, 10, 4]],
		"paths": [[Vector2(-10, 230), Vector2(150, 236), Vector2(300, 210), Vector2(440, 250), Vector2(600, 230), Vector2(730, 226)]],
		"scatter": {"hub_tuft": [24, 100], "hub_flower": [26, 40], "hub_pebble": [20, 12], "hub_twig": [10, 22]},
		"forest": {"top_gaps": [], "behind": [], "open": [Rect2(-30, 170, 70, 120), Rect2(680, 170, 80, 120)]},
		"exits": [{"rect": Rect2(26, 200, 10, 60), "to": "glade", "at": Vector2(430, 200)},
			{"rect": Rect2(684, 196, 10, 60), "to": "beacon", "at": Vector2(240, 378), "tale": 4, "why": "The lost wardens bar the path."}],
		"people": [
			{"id": "thornwatch", "name": "The lost wardens", "title": "Thorn-sick", "sprite": "pc_elf_hunter", "hands": "pc_hand_elf_23",
				"pos": Vector2(470, 240), "face": -1, "role": "chat", "text": "", "tale_from": 3, "tale_to": 3, "tint": Color(0.75, 0.6, 0.85)},
		],
		"lights": [[Vector2(150, 170), Color(0.45, 0.85, 1.0), 1.0, 0.45], [Vector2(420, 170), Color(0.5, 1.0, 0.85), 0.9, 0.5],
			[Vector2(560, 290), Color(0.45, 0.85, 1.0), 1.0, 0.45], [Vector2(300, 300), Color(0.5, 1.0, 0.85), 0.8, 0.45]],
	}


## THE BEACON OF THE WOOD: a bare hilltop, a ring of rune stones, the beacon in the middle.
static func beacon() -> Dictionary:
	var glow := lit("elfwood")
	var lights: Array = [[Vector2(140, 196), Color(0.45, 0.85, 1.0), 0.9, 0.4], [Vector2(340, 196), Color(0.45, 0.85, 1.0), 0.9, 0.4]]
	if glow:
		lights.append([Vector2(240, 170), Color(1.0, 0.82, 0.5), 3.4, 1.3])
	else:
		lights.append([Vector2(240, 180), Color(0.5, 0.6, 1.0), 1.4, 0.35])
	return {
		# the knight comes in at the foot (south) and climbs: the stones and the beacon stand on
		# the flat top of a real hill (scripts/hub/view3d.gd "hills")
		"name": "The Beacon of the Wood", "size": Vector2(480, 430), "outdoor": true, "walk": Rect2(30, 120, 420, 280), "spawn": Vector2(240, 378),
		"tint": Color(1.0, 0.94, 0.78) if glow else Color(0.52, 0.64, 0.90),
		"rise": {"from": 96.0, "over": 80.0, "height": 30.0},
		"hills": [{"at": Vector2(240, 204), "radius": 182.0, "height": 46.0, "top": 104.0}],
		"props": [["hub_rune_1", 150, 200, 12, 3], ["hub_rune_1", 330, 200, 12, 3], ["hub_rune_0", 150, 262, 9, 3], ["hub_rune_0", 330, 262, 9, 3],
			["hub_rune_2", 190, 150, 5, 2], ["hub_rune_2", 290, 150, 5, 2], ["hub_rock_moss_1", 70, 300, 12, 3], ["hub_rock_moss_0", 410, 310, 12, 3],
			["hub_vine_0", 196, 214, 0, 2], ["hub_vine_1", 286, 216, 0, 2], ["hub_bloom_0", 100, 372, 0, 2], ["hub_bloom_5", 390, 374, 0, 2],
			["hub_bush_deep_1", 150, 380, 10, 4], ["hub_bush_green_1", 344, 384, 10, 4],
			# the beacon: a great stone with the fire bowl on top of it
			["hub_stone_1", 240, 190, 16, 3], ["hub_stone_0", 214, 196, 8, 2], ["hub_stone_0", 268, 198, 8, 2]],
		"beacon": {"pos": Vector2(240, 186), "lit": glow, "lift": 30.0},
		"paths": [[Vector2(240, 440), Vector2(240, 230)]],
		"scatter": {"hub_tuft": [24, 60], "hub_flower": [26, 34 if glow else 6], "hub_pebble": [20, 18], "hub_twig": [10, 12]},
		"forest": {"top_gaps": [], "behind": [], "open": [Rect2(180, 400, 120, 80)]},
		"exits": [{"rect": Rect2(200, 392, 80, 10), "to": "deepwood", "at": Vector2(664, 226)}],
		"people": [
			{"id": "giant", "name": "Old Bramblejaw", "title": "The Bramble Giant", "sprite": "boss_ogre", "pos": Vector2(250, 232), "face": -1,
				"role": "chat", "text": "", "tale_from": 4, "tale_to": 4, "tint": Color(0.72, 0.95, 0.70), "solid": 16.0},
			{"id": "beacon", "name": "The beacon", "title": "", "ghost": true, "pos": Vector2(240, 214), "top": 44, "role": "chat", "text": "",
				"tale_from": 5},
		],
		"lights": lights,
	}
