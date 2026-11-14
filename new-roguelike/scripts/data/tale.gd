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
## CHAPTER TWO (built, steps 7 to 14): the Sands. Dustwatch on the wide world; Seraphine, the Dune
## Queen's daughter, joins after holding the wall with him; the Queen sends the knight after the
## Dune Gorgon of the Bone Dunes, then gives up her shard (and with it her sight); the beacon of
## the Sands stands in the Sunwell under the town (suncourt()).
## Chapters three and four (the Cinder Mountains and Grukk, the Sunken Archive) and the end under
## Hollow Hill are NOT built yet.
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
	# CHAPTER TWO: the Sands
	"Cross the wide world to Dustwatch, in the Sands",    # 7
	"Find the sun-mage on Dustwatch's wall",              # 8
	"Go down the stair to the Dune Queen's Sunwell",      # 9
	"Hunt the Dune Gorgon in the Bone Dunes",             # 10
	"Bring word to the Dune Queen",                       # 11
	"Set the second shard in the beacon of the Sands",    # 12
	"Bring word to Captain Hale in Wickmere",             # 13
	"The Cinder Mountains wait in the next chapter",      # 14
]
const LAST_STEP := 14

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
		], "option": "I will go east", "do": {"step": 1, "coins": 50, "say": "The east road is open. The watch's purse: +50 coins"}},
		{"from": 1, "to": 5, "pages": ["East, knight. The Warden keeps the Rune Glade past the Elfwood Road. Rest at the Flagon if the night is too long."]},
		{"from": 6, "to": 6, "pages": [
			"We saw it from the wall. A light over the Elfwood, the colour of morning. Half the town stood in the square and wept.",
			"And the shard is gone into the stone? Then there will never be a crown again. Good. A light does more than a king.",
			"Three beacons are still dark: the Sands, the Cinder Mountains, the Sunken Archive. Rest first. Take this from the watch's chest.",
		], "option": "Take the watch's thanks", "do": {"step": 7, "coins": 60, "say": "Chapter one is done: +60 coins"}},
		{"from": 7, "to": 7, "pages": [
			"The Sands next. Out of the south gate, across the wide world, east until the grass gives up. Dustwatch is the last town before the dunes.",
			"The Dune Queen holds the second shard. She is no thief, knight. She is a mother with a city to keep, and those are harder to talk round.",
		]},
		{"from": 8, "to": 12, "pages": ["The Sands, knight. Every night we look south-east and count the dark. Bring us one less."]},
		{"from": 13, "to": 13, "pages": [
			"Two lights now. From the wall you can see the Sands burning gold on the edge of the world, like a second sunset that will not go down.",
			"The Queen gave it up herself? ...Then she is worth ten of the lords I have met. Drink to her tonight, all of you.",
			"Two beacons dark: the Cinder Mountains and the Archive. Take the watch's thanks. You have earned more than we have.",
		], "option": "Take the watch's thanks", "do": {"step": 14, "coins": 90, "say": "Chapter two is done: +90 coins"}},
		{"from": 14, "pages": ["The smiths of the Cinder Mountains sent no word in a year. Rest, knight. The mountains are the next chapter, and they will still be there."]},
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
		{"from": 6, "to": 12, "pages": ["One beacon lit, and it ate its shard to burn. I have written that down twice. A crown that cannot be remade: the lords will not like it."]},
		{"from": 13, "pages": ["Two beacons. The Dune Queen gave hers up with her own hand. I have written it in red ink, which I keep for the things that matter."]},
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

	# ---------------------------------------------------------------- CHAPTER TWO: the Sands
	# Dustwatch (the town), the Sunwell under it (the Dune Queen's court and the beacon of the
	# Sands), the Bone Dunes on the wide world (the Dune Gorgon). Seraphine joins on the wall.
	"sefa": [
		{"from": 7, "to": 8, "pages": [
			"Stop there. ...The king's mark? I thought that died with him. Captain Sefa, of the Queen's wall.",
			"If you want the Queen, you want the stair, and nobody goes down it tonight. The dead come out of the dunes at dark, and every sword I have is on the wall.",
			"There is a mage up there who says she knew you were coming. Seraphine. The Queen's own daughter. Talk to her, not me.",
		]},
		{"from": 9, "to": 12, "pages": ["The stair is yours, knight. Go softly. The Queen has not slept since the night the crown broke."]},
		{"from": 13, "pages": ["The dunes are just sand again. My people slept last night, all of them, at once. I did not know I had missed that."]},
	],
	"sera": [
		{"from": 7, "to": 8, "pages": [
			"A knight of the guard. I saw you in the stars three nights running, and I thought the stars were lying again.",
			"I am Seraphine. I studied light at the Sunken Archive until the Archivist stopped answering letters. I came home to find my mother holding a piece of the sun in her hand.",
			"The shard keeps the dark off Dustwatch, and only Dustwatch. And it calls the dead out of the dunes, every night a few more. She will not see it.",
			"Here they come. Hold the wall with me, and I will take you down to her after.",
		], "option": "Hold the wall with her", "do": {"battle": "dustwall"}},
	],
	"queen": [
		{"from": 9, "to": 10, "pages": [
			"Seraphine. You brought me a knight. The king's guard sends a knight, now that the king is past guarding.",
			"I know what you want. Look at it, Aldous. Eleven years I have held this shard, and in eleven years not one child of Dustwatch has died in the dark.",
			"Give it to a cold stone, and what keeps my city? Your word?",
			"...A Gorgon walks the Bone Dunes, older than the town. It comes closer every night, for this. Kill it. Show me the dark can be fought with swords and not only with fire, and I will listen.",
		], "option": "Hunt the Gorgon", "do": {"step": 10, "say": "The Gorgon waits in the Bone Dunes, south of Dustwatch"}},
		{"from": 11, "to": 11, "pages": [
			"The Gorgon is dead? ...Then you did in one night what I could not do in eleven years.",
			"Come close, Aldous. Closer. No, I cannot see you. I have not seen anything but this light for a year. It took my eyes a little at a time, and I let it.",
			"Seraphine, take my hand. Take the shard out of it. I am too much of a coward to open it myself.",
			"There. It is dark. It is very dark. Go and light your beacon, knight, before I ask for it back.",
		], "option": "Take the second shard", "do": {"step": 12, "say": "You carry the shard of the Sands"}},
		{"from": 12, "to": 12, "pages": ["Do not wait for me. The beacon is behind me, where it has always been. I sat with my back to it so I would not have to look."]},
		{"from": 13, "pages": ["I cannot see the beacon. But I can feel it on my face, like the morning used to be. That will do. That will do very well."]},
	],
	"grukk": [
		{"from": 7, "to": 12, "pages": ["Grukk forges for the Queen's wall now. Before that, the mountains. Grukk does not talk about the mountains. Buy something."]},
		{"from": 13, "pages": ["Two lights. The mountains next, yes? ...Grukk has been thinking. Grukk will talk about the mountains soon. Not yet."]},
	],
	"nib": [
		{"from": 7, "to": 12, "pages": ["Charms against the dead, two coins. Do they work? Nobody has come back to complain."]},
		{"from": 13, "pages": ["No dead tonight. Nobody buys a charm. Best night of my life, worst night for trade."]},
	],
	"imre": [
		{"from": 7, "to": 12, "pages": ["These walls were carved by the people who built the beacons. Read them: the fire is not a thing to own. The Queen has not read them in years."]},
		{"from": 13, "pages": ["The carvings are warm. I touched one and it was warm, like a hand. Write that down for me, I am shaking."]},
	],
	"site_dunes": [
		{"from": 10, "to": 10, "pages": [
			"Tusks of things long dead stand out of the sand. Between them, so still you take them for stones, are people. Stone people, mid-step, mid-scream.",
			"Seraphine: \"Do not meet its eyes. Whatever you do, Aldous, watch its hands.\"",
			"Something with a crown of snakes rises out of the dune.",
		], "option": "Fight the Gorgon", "do": {"battle": "gorgon"}},
		{"from": 11, "pages": ["The stone people are still stone. But the dunes are quiet, and the sand is covering them, gently."]},
	],
	"sandbeacon": [
		{"from": 12, "to": 12, "pages": [
			"The beacon of the Sands stands at the bottom of the Sunwell, where the noon sun falls straight down. Its bowl is full of sand.",
			"Seraphine sweeps it clean with her sleeve. \"My mother brought me here when I was small. She said one day it would burn again. I think she forgot she said it.\"",
			"Thessaly: \"Two shards gone into stone. No turning back now, for any of us.\"",
		], "option": "Set the shard in the beacon", "do": {"step": 13, "light": "sands", "say": "The beacon of the Sands burns"}},
		{"from": 13, "pages": ["The beacon burns white and gold. The shard is in the fire, and the fire keeps it."]},
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
	# THE DEMO ENDS HERE (only in a demo build, G.demo()): shown once, right after Hale's thanks
	{"id": "demo_end", "demo": true, "place": "village", "from": 7, "to": 7, "name": "Hollow Hill", "title": "The demo ends here", "sprite": "", "pages": [
		"The first beacon burns. This is the end of the demo. Thank you for playing Hollow Hill.",
		"In the full game: the Sands and the Dune Queen, the Cinder Mountains, the Sunken Archive, and whatever sleeps under the hill.",
		"You can keep walking Wickmere, the Elfwood and the wide world for as long as you like.",
	]},
	{"id": "sisters", "place": "village", "from": 7, "to": 7, "name": "The sisters", "title": "", "sprite": "pc_elf_druid", "pages": [
		"Ysolde is waiting at the edge of the square. She does not run. Elves do not run. She walks very fast.",
		"Ysolde: \"You look terrible.\"   Thessaly: \"You look alive.\"",
		"They stand a long while with their foreheads together, the way elves do, and the whole square finds something else to look at.",
	]},
	# CHAPTER TWO: the Sands
	{"id": "sands", "place": "dustwatch", "from": 8, "to": 8, "name": "Dustwatch", "title": "The last town before the dunes", "sprite": "", "pages": [
		"Dustwatch sits on its wall of baked brick like a cat on a warm step. Every torch on the wall is lit, and every face on the wall looks out.",
		"Thessaly: \"No trees. No roots. I will be honest, Aldous, I do not like it.\"",
	]},
	{"id": "after_wall", "place": "dustwatch", "from": 9, "to": 9, "name": "Seraphine", "title": "Sun-mage of the Archive", "sprite": "pc_scholar_censor", "pages": [
		"They will be back tomorrow night, and more of them. They always are. That is what the shard does: it keeps us, and it calls them.",
		"My mother is not wicked, Aldous. She is frightened, and she has been frightened for eleven years, and it has made her very strong.",
		"I am coming with you, to the end of it. Somebody who loves her has to be there when she lets go.",
	]},
	{"id": "sunwell", "place": "suncourt", "from": 9, "to": 9, "name": "The Sunwell", "title": "The Dune Queen's court", "sprite": "", "pages": [
		"The stair opens into a great round well, open to the sky. In the middle of it stands a beacon, cold, its bowl full of sand.",
		"With her back to it sits the Dune Queen in the old crown of the Sands, her eyes bound in linen, and in her closed hand a light so bright it shows the bones of her fingers.",
	]},
	{"id": "after_gorgon", "place": "world", "from": 11, "to": 11, "name": "Seraphine", "title": "Sun-mage of the Archive", "sprite": "pc_scholar_censor", "pages": [
		"It is dead. It is really dead. Eleven years my mother sat in the dark for fear of that thing.",
		"Back to Dustwatch, Aldous. Before I lose my nerve, or she finds hers.",
	]},
	{"id": "sands_dawn", "place": "suncourt", "from": 13, "to": 13, "name": "Seraphine", "title": "Sun-mage of the Archive", "sprite": "pc_scholar_censor", "pages": [
		"Look up. The light is climbing the walls of the well, and over the top, and out across the dunes.",
		"She is smiling. Do you see? She cannot see it, and she is smiling.",
	]},
	{"id": "two_lights", "place": "village", "from": 13, "to": 13, "name": "Wickmere", "title": "", "sprite": "", "pages": [
		"The lamps of Wickmere are lit as always. But tonight, low in the south-east, there is a second glow on the sky, and the children keep climbing the wall to see it.",
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
	# chapter two: the Sands
	"dustwall": {"title": "The dead come out of the dunes", "look": "desert", "tier": 1,
		"foes": ["dust_mummy", "tomb_blade", "dust_mummy"], "with": ["sera"], "xp_bonus": 30,
		"win": {"step": 9, "join": "sera", "say": "Seraphine, Sun-mage of the Archive, travels with you"}},
	"gorgon": {"title": "The Dune Gorgon", "look": "desert", "tier": 1, "boss": "gorgon",
		"foes": ["dust_mummy"],
		"win": {"step": 11, "say": "The Dune Gorgon falls"}},
}

## Bosses of the story's battles. The numbers are for a knight of about level 4 with one companion.
##   "sweep"  every this-many turns the boss strikes everybody at once, at "sweep_power"
const BOSSES := {
	"bramblejaw": {"name": "Old Bramblejaw", "sprite": "boss_ogre", "tint": Color(0.72, 0.95, 0.70),
		"hp": 185, "atk": 8.8, "def": 2.0, "speed": 8.0, "sweep": 3, "sweep_power": 0.75, "sweep_name": "Briar Sweep",
		"xp": 90, "coins": 40},
	"gorgon": {"name": "The Dune Gorgon", "sprite": "pc_medusa", "tint": Color(1.0, 0.92, 0.78),
		"hp": 240, "atk": 10.0, "def": 3.0, "speed": 11.0, "sweep": 3, "sweep_power": 0.7, "sweep_name": "Stone Gaze",
		"xp": 140, "coins": 70},
}

## Walking into a place at a step: {place: {step: do}}.
const ENTER := {
	"elfwood": {1: {"step": 2}},
	"dustwatch": {7: {"step": 8}},
}

## THE FAIRY DUST (scripts/hub/trail.gd): where the glitter on the ground leads at each step. [place id,
## id of the person to walk up to]. "" = just that place (the story moves on by itself on arriving).
## A step that is not listed has no trail.
const TRAIL := {
	0: ["village", "hale"], 1: ["elfwood", ""], 2: ["glade", "thessaly"], 3: ["deepwood", "thornwatch"],
	4: ["beacon", "giant"], 5: ["beacon", "beacon"], 6: ["village", "hale"],
	7: ["dustwatch", ""], 8: ["dustwatch", "sera"], 9: ["suncourt", "queen"], 10: ["world", "site_dunes"],
	11: ["suncourt", "queen"], 12: ["suncourt", "sandbeacon"], 13: ["village", "hale"],
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


const DEMO_DONE := "The demo ends here. Thank you for playing!"
const DEMO_SHUT := "The Sands open in the full game. Thank you for playing the demo."
const DEMO_LAST := 7             ## the demo's story stops at this step (chapter one done)

static func objective() -> String:
	if G.demo() and step() >= DEMO_LAST:
		return DEMO_DONE
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
		if bool(row.get("demo", false)) and not G.demo():
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
		["hub_bench_long", 262, 171, 10, 2],
		# the square: cobbles (see "floor"), the fountain in the middle, benches, the watch-fire in its
		# north-east corner (see "fire"). Pieces from the Garden and Castle packs (ids hub_g*, hub_c*).
		["hub_gfountain", 480, 338, 36, 0], ["hub_gbench", 400, 372, 12, 1], ["hub_gbench", 560, 372, 12, 1],
		["hub_stonebench", 404, 252, 8, 1], ["hub_planter", 384, 300, 6, 1], ["hub_planter", 576, 326, 6, 1],
		["hub_gurn_0", 372, 372, 5, 1], ["hub_gurn_1", 590, 372, 5, 1],
		# cypresses by the gate and between the houses, potted trees at the doors, flower beds under the windows
		["hub_gcypress_0", 436, 152, 6, 0], ["hub_gcypress_0", 524, 152, 6, 0], ["hub_gcypress_0", 124, 512, 6, 0], ["hub_gcypress_1", 690, 520, 6, 0],
		["hub_cpot_1", 98, 162, 4, 0], ["hub_cpot_2", 150, 162, 4, 0], ["hub_cpot_1", 636, 170, 4, 0], ["hub_cpot_2", 684, 170, 4, 0],
		["hub_gbed_0", 236, 172, 0, 0], ["hub_gbed_5", 340, 172, 0, 0], ["hub_gbed_2", 806, 174, 0, 0], ["hub_gbed_7", 870, 174, 0, 0],
		["hub_gbed_4", 74, 414, 0, 0], ["hub_gbed_1", 134, 414, 0, 0], ["hub_gbed_6", 826, 494, 0, 0], ["hub_gbed_3", 886, 494, 0, 0],
		["hub_gbed_1", 444, 392, 0, 0], ["hub_gbed_4", 516, 392, 0, 0],
		# the smithy's yard, east of the square
		["hub_anvil_0", 716, 258, 16, 4], ["hub_bench_1", 752, 236, 12, 3], ["hub_stone_0", 684, 240, 8, 2],
		# gardens in the south half (the north street is paved: round two)
		["hub_stonebench", 250, 444, 8, 1], ["hub_planter", 330, 446, 6, 1],
		["hub_fence_a", 740, 500, 6, 0], ["hub_fence_a", 780, 500, 6, 0],
		["hub_bush_deep_1", 150, 470, 10, 4],
		["hub_bush_rust_2", 646, 372, 9, 4], ["hub_tree_green_3", 64, 300, 6, 6], ["hub_tree_teal_3", 900, 392, 6, 6],
		["hub_tree_pink_4", 430, 452, 4, 5], ["hub_tree_teal_4", 596, 502, 4, 5],
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
	# ROUND TWO: the north side is ONE frontage of nine houses from the west edge to the gate and on
	# to the east gate (narrow shops fill what were garden gaps), all standing on a raised terrace of
	# flagstones ("terraces") with steps down to a cobbled street: awnings, hanging signs, flower boxes.
	var houses: Array = [
		{"at": Vector2(124, 152), "wide": 128.0, "deep": 60.0, "wall": "hub_wall_plaster", "wall_h": 56.0, "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood",
			"rise": 40.0, "gable": true, "door": "hub_doorway", "windows": "hub_window", "win_dx": 38.0, "win_up": 14.0, "chimney": true,
			"sign": "hub_sjug", "sign_side": -1.0, "boxes": true, "stair": -1.0, "lamp": 1.0, "tint": Color(1.0, 0.84, 0.62), "timber": Color(0.74, 0.62, 0.50)},
		{"at": Vector2(220, 155), "wide": 64.0, "deep": 50.0, "wall": "hub_wall_white", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 26.0, "floors": 3,
			"door": "hub_door_wood", "door_dx": -14.0, "windows": "hub_win_tall", "win_xs": [16.0], "up_xs": [-14.0, 14.0], "shop": "wide", "sign": "hub_ssack_0",
			"bay": [14.0], "tint": Color(0.72, 0.84, 0.70), "timber": Color(1.0, 0.80, 0.62)},
		{"at": Vector2(300, 160), "wall": "hub_wall_brick", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 30.0, "floors": 3,
			"door": "hub_door_arch", "windows": "hub_win_arch", "boxes": true, "bay": [0.0], "lamp": -1.0, "chimney": true, "chimney_dx": -26.0, "tint": Color(0.94, 0.66, 0.58), "timber": Color(0.56, 0.50, 0.50)},
		{"at": Vector2(382, 156), "wide": 66.0, "deep": 50.0, "wall": "hub_wall_plank", "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 24.0,
			"door": "hub_door_arch", "door_dx": 14.0, "windows": "hub_win_shut", "win_xs": [-15.0], "up_xs": [-16.0, 16.0], "shop": "wide",
			"shop_roof": "hub_roof_planks", "sign": "hub_spot", "sign_side": -1.0, "chimney": true, "chimney_dx": -14.0},
		{"at": Vector2(579, 156), "wide": 66.0, "deep": 50.0, "wall": "hub_wall_brick", "upper": "hub_wall_white", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal",
			"rise": 24.0, "door": "hub_door_iron", "door_dx": -14.0, "windows": "hub_win_arch", "win_xs": [15.0], "up_xs": [-15.0, 15.0], "boxes": true,
			"sign": "hub_cbanner_1", "bay": [-15.0], "chimney": true, "tint": Color(0.70, 0.78, 0.92), "timber": Color(0.54, 0.60, 0.70)},
		{"at": Vector2(660, 160), "wall": "hub_wall_dark", "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 34.0, "gable": true, "floors": 3,
			"door": "hub_door_iron", "windows": "hub_win_tall", "chimney": true, "sign": "hub_cshield", "sign_side": -1.0, "win_xs": [-34.0, 34.0], "lamp": 1.0},
		{"at": Vector2(748, 158), "wide": 80.0, "deep": 52.0, "wall": "hub_wall_white", "upper": "hub_wall_plaster", "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal",
			"rise": 26.0, "door": "hub_door_wood", "windows": "hub_win_closed", "win_dx": 26.0, "shop": "wide", "shop_roof": "hub_roof_planks", "boxes": true,
			"bay": [-26.0], "tint": Color(1.0, 0.80, 0.52), "timber": Color(0.74, 0.62, 0.50)},
		{"at": Vector2(836, 162), "wall": "hub_wall_log", "wall_h": 56.0, "roof": "hub_roof_tiles", "flat_roof": "hub_roof_teal", "rise": 30.0,
			"door": "hub_door_wood", "windows": "hub_win_shut", "boxes": true, "chimney": true, "chimney_dx": -20.0},
		{"at": Vector2(916, 160), "wide": 64.0, "deep": 50.0, "wall": "hub_wall_brick", "upper": "hub_wall_plaster", "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood",
			"rise": 26.0, "floors": 3, "door": "hub_door_arch", "door_dx": -13.0, "windows": "hub_win_tall", "win_xs": [16.0], "up_xs": [-14.0, 14.0],
			"stair": 1.0, "chimney": true, "tint": Color(0.94, 0.70, 0.60), "timber": Color(0.56, 0.50, 0.50)},
		{"at": Vector2(104, 400), "wall": "hub_wall_white", "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 32.0, "gable": true,
			"door": "hub_door_wood", "windows": "hub_win_shut", "chimney": true, "lamp": 1.0},
		{"at": Vector2(856, 480), "wall": "hub_wall_plank", "wall_h": 54.0, "roof": "hub_roof_planks", "flat_roof": "hub_roof_wood", "rise": 30.0,
			"door": "hub_door_arch", "windows": "hub_win_closed", "lamp": -1.0},
	]
	var lamp := Color(1.0, 0.78, 0.46)
	var lights: Array = [[Vector2(552, 258), Color(1.0, 0.72, 0.42), 2.3, 0.8]]
	for at: Vector2 in [Vector2(360, 250), Vector2(600, 250), Vector2(360, 400), Vector2(600, 400), Vector2(210, 300), Vector2(760, 310), Vector2(480, 470), Vector2(880, 250)]:
		lights.append([at - Vector2(0, 40), lamp, 1.0, 0.55])
	for at: Vector2 in [Vector2(124, 150), Vector2(300, 158), Vector2(660, 158), Vector2(836, 160), Vector2(104, 398), Vector2(856, 478)]:
		lights.append([at + Vector2(0, 8), lamp, 0.8, 0.4])           # the glow of a house's windows on its doorstep
	lights.append([Vector2(480, 96), Color(0.6, 0.55, 1.0), 1.2, 0.4])    # the cold of the sealed gate
	return {
		"name": "Wickmere", "camp": 0, "size": size, "outdoor": true, "walk": Rect2(40, 150, 880, 380), "spawn": Vector2(480, 404),
		"props": props, "houses": houses,
		"tour": [Vector2(250, 200), Vector2(480, 404), Vector2(720, 270), Vector2(480, 518), Vector2(660, 196)],     # test pictures (--hub=village --shots)
		# the raised pavement along the north frontage, with steps down where the paths come up
		"terraces": [{"rect": Rect2(40, 150, 376, 28), "high": 7.0, "steps": [[140.0, 26.0], [322.0, 24.0]]},
			{"rect": Rect2(544, 150, 404, 28), "high": 7.0, "steps": [[650.0, 26.0], [842.0, 24.0]]}],
		# the near edge: a stone balustrade between the camera and the town, gate piers either side of
		# the south road (scripts/hub/arch/sites.gd "near")
		"near": [{"z": 566.0, "runs": [[30.0, 245.0], [279.0, 432.0], [528.0, 936.0]], "piers": [[436.0, 30.0], [524.0, 30.0]]}],
		# Hollow Hill: behind the north row the ground climbs, and the hill itself swells out of
		# the slope behind the sealed gate (only in the 3D look; nobody walks up there)
		"rise": {"from": 100.0, "over": 96.0, "height": 52.0, "mound": {"at": Vector2(480, 6), "radius": 210.0, "height": 70.0}},
		# the mere the town is named for, in the south-west corner (nobody walks into it)
		"water": [{"at": Vector2(262, 484), "radius": Vector2(116, 36),
			"lilies": [["hub_glily_0", 222, 478], ["hub_glily_1", 306, 494], ["hub_glily_2", 190, 496], ["hub_glily_2", 336, 474]]}],
		# cobbles: the square, and a street to the gate, the south road, the east gate and the west side
		"floor": [["hub_gcobble", Rect2(368, 232, 224, 144)], ["hub_gcobble", Rect2(464, 136, 32, 96)], ["hub_gcobble", Rect2(464, 376, 32, 168)],
			["hub_gcobble", Rect2(592, 268, 352, 48)], ["hub_gcobble", Rect2(144, 268, 224, 48)],
			["hub_gcobble", Rect2(40, 176, 880, 56)], ["hub_gcobble", Rect2(40, 232, 328, 36)], ["hub_gcobble", Rect2(592, 232, 328, 36)]],
		"paths": [[Vector2(160, 268), Vector2(130, 176)],
			[Vector2(300, 176), Vector2(330, 262)], [Vector2(660, 176), Vector2(640, 262)], [Vector2(120, 416), Vector2(360, 412)],
			[Vector2(840, 496), Vector2(610, 420)], [Vector2(836, 186), Vector2(850, 270)]],
		"scatter": {"hub_tuft": [24, 150], "hub_flower": [26, 70], "hub_pebble": [20, 26], "hub_twig": [10, 10]},
		"scatter_rect": Rect2(8, 316, 944, 236),
		"fire": Vector2(552, 270),
		# things that move: [id, x, y, frames a second, solid radius, turned round]: the statues that pour into the mere
		"anims": [["hub_gspout", 398, 478, 6.0, 7.0, false], ["hub_gspout", 126, 478, 6.0, 7.0, true]],
		# a small flame on top of every lamp post (the posts are in "props", their glow in "lights")
		"torches": [Vector2(360, 250), Vector2(600, 250), Vector2(360, 400), Vector2(600, 400), Vector2(210, 300), Vector2(760, 310), Vector2(480, 470), Vector2(880, 250)],
		"forest": {"top_gaps": [[416.0, 544.0], [40.0, 250.0], [236.0, 364.0], [596.0, 724.0], [772.0, 900.0]],
			"behind": [["hub_tree_pink_2", 480, 60], ["hub_tree_green_2", 416, 80], ["hub_tree_teal_2", 546, 80]],
			"open": [Rect2(930, 220, 60, 130), Rect2(60, 520, 840, 140)]},     # (the near edge is the balustrade: no hedge in front of it)
		"blocks": [Rect2(46, 96, 14, 56), Rect2(60, 96, 128, 56), Rect2(188, 104, 64, 51), Rect2(252, 108, 96, 52), Rect2(349, 104, 66, 52), Rect2(546, 104, 66, 52),
			Rect2(612, 108, 96, 52), Rect2(708, 104, 80, 54), Rect2(788, 106, 96, 56), Rect2(884, 108, 64, 52),
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
				"pos": Vector2(318, 176), "face": 1, "role": "chat", "text": ""},
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
			["hub_rune_2", 150, 180, 5, 2], ["hub_rune_0", 560, 300, 9, 3],
			["hub_bloom_5", 660, 300, 0, 2], ["hub_shroom_0", 300, 310, 0, 1], ["hub_shroom_1", 420, 180, 0, 1], ["hub_shroom_2", 540, 220, 0, 1],
			["hub_vine_0", 44, 330, 0, 2], ["hub_vine_1", 500, 160, 0, 2], ["hub_rock_moss_0", 330, 240, 12, 3], ["hub_rock_moss_2", 90, 170, 12, 3],
			["hub_stump_0", 590, 250, 12, 4], ["hub_bush_deep_0", 400, 320, 12, 5], ["hub_bush_deep_1", 180, 240, 10, 4],
			# ROUND TWO: the old giants of the deep wood stand along the back of the road (nobody walks
			# behind them): the Fairy Forest's great roots with their trunks stacked on them, dark leaves
			# low round their feet; a fallen giant's root stump, dead thorn trees where the wardens wait,
			# ferns, foxgloves and toadstools in clumps along the road's edges
			["hub_froots_1", 380, 124, 30, 2], ["hub_ftrunk_1", 380, 124, 0, -102], ["hub_ftrunk_4", 380, 124, 0, -196],
			["hub_froots_2", 96, 120, 26, 2], ["hub_ftrunk_2", 96, 120, 0, -102],
			["hub_fleaf_g_3", 300, 126, 0, 2], ["hub_fleaf_o_2", 462, 128, 0, 2], ["hub_fleaf_g_4", 190, 122, 0, 2],
			["hub_stump_3", 214, 316, 14, 3], ["hub_vdead_0", 520, 196, 0, 2], ["hub_vdead_1", 430, 284, 0, 2], ["hub_vdead_0", 640, 238, 0, 2],
			["hub_vplant_1", 160, 214, 0, 1], ["hub_plant_3", 172, 208, 0, 1], ["hub_vplant_7", 352, 196, 0, 1], ["hub_vplant_8", 362, 200, 0, 1],
			["hub_shroom_3", 312, 316, 0, 1], ["hub_shroom_4", 320, 320, 0, 1], ["hub_shroom_2", 228, 304, 0, 1], ["hub_vplant_1", 520, 276, 0, 1],
			["hub_plant_1", 404, 196, 0, 1], ["hub_shroom_3", 548, 226, 0, 1], ["hub_vplant_4", 120, 300, 0, 1], ["hub_vplant_5", 136, 306, 0, 1]],
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
			["hub_vine_0", 196, 214, 0, 2], ["hub_vine_1", 286, 216, 0, 2],
			["hub_bush_deep_1", 150, 380, 10, 4], ["hub_bush_green_1", 344, 384, 10, 4],
			# ROUND TWO: the old giants of the wood stand behind the hilltop's stones (nobody walks behind
			# them) and frame it; ferns and foxgloves at the foot of the hill instead of the giant blooms
			["hub_froots_0", 64, 132, 26, 2], ["hub_ftrunk_0", 64, 132, 0, -102], ["hub_froots_1", 420, 134, 26, 2], ["hub_ftrunk_1", 420, 134, 0, -102],
			["hub_fleaf_g_4", 120, 126, 0, 2], ["hub_fleaf_o_3", 364, 128, 0, 2],
			["hub_vplant_1", 100, 368, 0, 1], ["hub_vplant_7", 112, 362, 0, 1], ["hub_vplant_1", 388, 370, 0, 1], ["hub_vplant_8", 376, 364, 0, 1],
			# the beacon: a great stone with the fire bowl on top of it
			["hub_stone_1", 240, 190, 16, 3], ["hub_stone_0", 214, 196, 8, 2], ["hub_stone_0", 268, 198, 8, 2]],
		"beacon": {"pos": Vector2(240, 186), "lit": glow, "lift": 30.0},
		"paths": [[Vector2(240, 440), Vector2(240, 230)]],
		"scatter": {"hub_tuft": [24, 60], "hub_flower": [26, 34 if glow else 6], "hub_pebble": [20, 18], "hub_twig": [10, 12]},
		"forest": {"top_gaps": [], "behind": [], "open": [Rect2(180, 400, 120, 80)],
			"low": ["hub_bush_deep_0", "hub_bush_green_1", "hub_bush_deep_1", "hub_bush_green_0", "hub_bush_deep_2", "hub_bush_green_2"]},
		"exits": [{"rect": Rect2(200, 392, 80, 10), "to": "deepwood", "at": Vector2(664, 226)}],
		"people": [
			{"id": "giant", "name": "Old Bramblejaw", "title": "The Bramble Giant", "sprite": "boss_ogre", "pos": Vector2(250, 232), "face": -1,
				"role": "chat", "text": "", "tale_from": 4, "tale_to": 4, "tint": Color(0.72, 0.95, 0.70), "solid": 16.0},
			{"id": "beacon", "name": "The beacon", "title": "", "ghost": true, "pos": Vector2(240, 214), "top": 44, "role": "chat", "text": "",
				"tale_from": 5},
		],
		"lights": lights,
	}


## THE SUNWELL (chapter two): a great round well open to the sky under Dustwatch, down the
## cistern stair. The Dune Queen keeps her court here with her back to the cold beacon of the
## Sands, the shard burning in her closed hand.
static func suncourt() -> Dictionary:
	var glow := lit("sands")
	var held := step() < 12                         # the shard is still in the Queen's hand
	var lights: Array = [[Vector2(150, 176), Color(1.0, 0.74, 0.42), 1.0, 0.5], [Vector2(410, 176), Color(1.0, 0.74, 0.42), 1.0, 0.5]]
	if glow:
		lights.append([Vector2(280, 170), Color(1.0, 0.86, 0.56), 3.6, 1.4])
	else:
		lights.append([Vector2(280, 180), Color(0.5, 0.6, 1.0), 1.2, 0.35])
	if held:
		lights.append([Vector2(206, 250), Color(1.0, 0.9, 0.62), 1.6, 0.9])     # the shard in her fist
	var forest := {"top_gaps": [], "behind": [], "open": [Rect2(220, 390, 120, 90), Rect2(-60, 396, 680, 90), Rect2(120, 30, 320, 80)],
		"big": ["hub_dstone_0", "hub_obelisk_2", "hub_dstone_1", "hub_tusk_1", "hub_dpillar_3", "hub_dbush_0"],
		"side": ["hub_dpillar_0", "hub_dstone_1", "hub_dpillar_2", "hub_cactus_3"],
		"low": ["hub_dshrub", "hub_dbush_2", "hub_dpot_0", "hub_dstone_2", "hub_dpot_1", "hub_dbush_2"],
		"young": ["hub_dpillar_1", "hub_cactus_2", "hub_dbush_1"]}
	return {
		"name": "The Sunwell", "size": Vector2(560, 420), "outdoor": true, "walk": Rect2(30, 110, 500, 280), "spawn": Vector2(280, 376),
		"ground": "hub_sand", "tint": Color(1.0, 0.93, 0.80) if glow else Color(0.64, 0.68, 0.92),
		"rise": {"from": 100.0, "over": 80.0, "height": 34.0},
		"floor": [["hub_paving", Rect2(184, 144, 192, 160)], ["hub_paving", Rect2(250, 304, 60, 100)]],
		# (round three) the beacon on a court of three tiers; a paved way from the road up to it between
		# pairs of obelisks; a portico of columns across the back (scripts/hub/arch/sites.gd _portico)
		"terraces": [{"rect": Rect2(184, 144, 192, 160), "high": 6.0, "steps": [[280.0, 60.0]], "face": "hub_bsandcap", "top": "hub_paving"},
			{"rect": Rect2(220, 154, 120, 88), "high": 12.0, "steps": [[280.0, 40.0]], "face": "hub_bsandcap", "top": "hub_paving"},
			{"rect": Rect2(250, 164, 60, 42), "high": 18.0, "steps": [[280.0, 24.0]], "face": "hub_bsandcap", "top": "hub_paving"}],
		"portico": {"x0": 120.0, "x1": 440.0, "z": 102.0, "deep": 24.0, "tall": 54.0, "cols": 9, "door": "hub_ddoor"},
		"tour": [Vector2(280, 372), Vector2(300, 252)],
		"near": [{"z": 426.0, "style": "sand", "runs": [[-40.0, 226.0], [334.0, 600.0]], "piers": [[236.0, 26.0], [324.0, 26.0]]}],
		"decals": [["hub_sripple_2", 70, 270], ["hub_sripple_3", 470, 280], ["hub_sripple_1", 120, 390], ["hub_sripple_4", 440, 392]],
		"props": [["hub_obelisk_0", 150, 186, 12, 2], ["hub_obelisk_1", 410, 186, 12, 2], ["hub_obelisk_2", 236, 340, 10, 2], ["hub_obelisk_2", 324, 340, 10, 2],
			["hub_dpillar_0", 196, 150, 6, 2], ["hub_dpillar_1", 364, 150, 6, 2], ["hub_dpillar_2", 170, 290, 6, 2], ["hub_dpillar_2", 390, 290, 6, 2],
			["hub_dpot_0", 222, 360, 5, 1], ["hub_dpot_1", 338, 362, 4, 1], ["hub_dchest", 448, 226, 10, 2], ["hub_dpot_1", 470, 236, 4, 1],
			["hub_cactus_4", 70, 214, 8, 2], ["hub_cactus_3", 500, 214, 6, 2], ["hub_dtree_1", 74, 372, 5, 2], ["hub_dbush_1", 486, 372, 8, 3],
			["hub_tusk_2", 120, 150, 6, 2],
			# broken columns half sunk in the sand at the court's sides
			["hub_dpillar_3", 100, 300, 6, 3], ["hub_dpillar_3", 462, 306, 6, 3], ["hub_dblock_1", 112, 308, 0, 1], ["hub_dblock_3", 450, 314, 0, 1],
			["hub_dpillar_3", 62, 160, 6, 3], ["hub_dblock_0", 508, 166, 0, 1],
			# urns along the parapet, past the near edge
			["hub_dpot_0", 150, 432, 0, 1], ["hub_dpot_1", 196, 434, 0, 1], ["hub_dpot_0", 372, 434, 0, 1], ["hub_dpot_1", 420, 432, 0, 1],
			# the beacon: a great stone with the fire bowl on top of it
			["hub_dstone_0", 280, 190, 16, 3]],
		"beacon": {"pos": Vector2(280, 186), "lit": glow, "lift": 24.0},
		"scatter": {"hub_dgrass": [4, 30]},
		"forest": forest,
		"exits": [{"rect": Rect2(230, 392, 100, 10), "to": "dustwatch", "at": Vector2(320, 228)}],
		"people": [
			{"id": "queen", "name": "The Dune Queen", "title": "Lady of the Sands", "sprite": "pc_mummy_mage", "hands": "pc_hand_desert_13", "tint": Color(1.0, 0.95, 0.86),
				"pos": Vector2(206, 262), "face": 1, "role": "chat", "text": "", "tale_from": 9},
			{"id": "sandbeacon", "name": "The beacon", "title": "", "ghost": true, "pos": Vector2(280, 214), "top": 44, "role": "chat", "text": "",
				"tale_from": 12},
		],
		"lights": lights,
	}
