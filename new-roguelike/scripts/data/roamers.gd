extends RefCounted
## Roamers: monsters that walk the world map (RPG step 5b, v0.16.0). The owner picked "roaming
## monsters" for the open world and, asked how a meeting should work, "touch = quick battle":
## a roamer that touches the knight fades into ONE fight room in that terrain; win and he stands
## on the same spot again with his XP, loot and coins (the coins go into the camp chest).
## Roamers can be dodged: they only chase a little way, and he is faster.
##
## KINDS: one row per terrain.
##   "look"    an outdoor fight look of scripts/data/floors.gd EXTRA (its monster list is used), or
##   "floor"   an indoor floor (1 to 4) when the terrain has no outdoor look yet (the rock: a cave)
##   "tier"    how strong the monsters are (0 like the Crypt .. 3) and which gear may drop
##   "shows"   the monsters (scripts/data/enemies.gd ids) a roamer of this kind may look like
##   "title"   the banner when the fight starts
## SPOTS: where each roamer lives on the map (places.gd "world") and how far it strays ("leash").
##   "from"    the chapter (levels cleared) from which it is there (0 = from the start)
## A beaten roamer comes back after RESPAWN seconds. Which ones are gone is only remembered
## while the game runs (a fresh start of the app brings them all back).
## Every number is a first guess. Words are placeholders the owner may rewrite.
##
## THE QUALITY PASS (package 07). The map stays random, as the owner likes it, but:
##   "shows"   is five monsters a kind, all with art already in the game, so a land is not the same two faces
##   "night"   a second list: who comes after dusk (hub.gd sets `night` before it asks for a fight)
##   robbers   the road band between Wickmere and Dustwatch is theirs (kind_at), from story step 7
##   "from"    is a step of the story (scripts/data/tale.gd) while the story is on, not a chapter of the old one
##   lit land  once a land's beacon burns, fights there are 40% rarer (LIT_EASE) and the map says so once
##   the lead  which of the list leads a random fight changes from fight to fight (`roll`)

const RESPAWN := 240.0             ## seconds until a beaten roamer walks its patch again
const SEE := 120.0                 ## map px: closer than this and it comes for the knight
const LOSE := 190.0                ## further than this and it gives up and walks home
const WALK := 26.0                 ## px/s strolling        (the knight does 190 on the map)
const CHASE := 118.0               ## px/s chasing: slower than the knight, so he can get away
const TOUCH := 20.0                ## map px between their feet that counts as a touch
const GRACE := 3.0                 ## seconds after arriving on the map before any roamer chases
## (13 Nov 2026) The owner: fights should start while you walk, "like in Pokemon", not by going up
## to a monster. RANDOM = true: no monsters stand on the map; walking through the wild starts a
## fight now and then (the terrain under the knight picks which kind). false = the old roamers.
const RANDOM := true
const STEPS_MIN := 520.0           ## map px walked in the wild before a fight may start
const STEPS_MAX := 1100.0          ## ... and at the latest
const SAFE_GATE := Vector2(300, 570)  ## no fights this close to the village gate
const SAFE_R := 200.0

const LIT_EASE := 1.6              ## a land whose beacon burns: this many times the walking between fights
const ROAD := Rect2(700, 560, 550, 180)      ## the road band of the world map: robbers' ground
const ROBBERS_FROM := 7            ## the story step from which robbers work the road (chapter two: the road east matters)

const KINDS := {
	"grass": {"look": "forest", "tier": 0, "shows": ["thorn_elf", "wood_beast", "sporeling", "elf_stalker", "long_cap"],
		"night": ["elf_hexer", "long_cap", "spore_cap", "crypt_bat", "elf_stalker"], "title": "Ambush in the grass", "area": "The wild woods", "land": "elfwood"},
	"robbers": {"look": "road", "tier": 1, "shows": ["bandit_cutter", "bandit_bruiser", "bandit_tracker", "bandit_sorcerer", "orc_grunt"],
		"night": ["bandit_tracker", "bandit_sorcerer", "orc_skulker", "bandit_cutter", "shambler"], "title": "Robbers on the road", "area": "The east road", "land": "sands"},
	"sand": {"look": "desert", "tier": 1, "shows": ["dust_mummy", "tomb_blade", "wrap_leaper", "tomb_seer", "bone_walker"],
		"night": ["bone_walker", "wailer", "tomb_seer", "bone_guard", "crypt_bat"], "title": "Out of the sand", "area": "The eastern sands", "land": "sands"},
	"rock": {"floor": 3, "tier": 2, "shows": ["rubble_walker", "magma_heart", "ash_bat", "lantern_head", "waking_statue"],
		"night": ["ash_bat", "lantern_head", "magma_heart", "grave_lunger", "ash_bat"], "title": "Dragged into a cinder cave", "area": "The Cinder Mountains", "land": "cinder"},
}

const SPOTS := [
	# (none within about 200 px of the village gate at 300, 570: a new knight gets a quiet first step)
	{"kind": "grass", "at": Vector2(560, 720), "leash": 50.0},
	{"kind": "grass", "at": Vector2(640, 540), "leash": 60.0},
	{"kind": "grass", "at": Vector2(800, 520), "leash": 60.0},
	{"kind": "grass", "at": Vector2(500, 470), "leash": 40.0},
	{"kind": "robbers", "at": Vector2(820, 720), "leash": 60.0, "from": 1, "tale": ROBBERS_FROM},
	{"kind": "sand", "at": Vector2(1000, 580), "leash": 70.0},
	{"kind": "sand", "at": Vector2(1010, 760), "leash": 80.0},
	{"kind": "sand", "at": Vector2(1300, 700), "leash": 90.0},
	{"kind": "sand", "at": Vector2(1460, 800), "leash": 80.0},
	{"kind": "robbers", "at": Vector2(1230, 580), "leash": 70.0, "from": 3, "tale": ROBBERS_FROM},
	{"kind": "rock", "at": Vector2(1470, 300), "leash": 60.0},
	{"kind": "rock", "at": Vector2(1620, 250), "leash": 60.0},
	{"kind": "rock", "at": Vector2(1880, 240), "leash": 50.0},
]

## Which roamers are beaten: spot number -> the moment (msec since the game started) it returns.
static var gone := {}


## It is night on the map (hub.gd says so before it asks for a fight; battles.gd then gets the night list).
static var night := false
## Which of the list leads the next random fight (hub.gd rolls it; 0 = the spot's own, for roamers that are seen).
static var roll := 0


## The kind of this spot. By night its "shows" is its night list (so whoever builds the pack needs no change).
static func kind_of(spot: int) -> Dictionary:
	var kind: Dictionary = KINDS[String(SPOTS[spot]["kind"])]
	if night and kind.has("night"):
		kind = kind.duplicate()
		kind["shows"] = kind["night"]
	return kind


## Is this spot open at this point of the game? The story counts its steps ("tale", 0 = from the start);
## the old story counts chapters ("from").
static func open(spot: int) -> bool:
	if Tale.on():
		return Tale.step() >= int(SPOTS[spot].get("tale", 0))
	return Story.chapter() >= int(SPOTS[spot].get("from", 0))


## Does the beacon of this kind's land burn?
static func lit_at(at: Vector2) -> bool:
	return Tale.on() and Tale.lit(land_at(at))


## The land a point of the world map belongs to ("elfwood", "sands", "cinder"): whose beacon makes it safer.
static func land_at(at: Vector2) -> String:
	if at.x > 1330.0 and at.y < 440.0:
		return "cinder"
	return "sands" if at.x > 870.0 else "elfwood"


## Is this roamer on the map right now?
static func here(spot: int) -> bool:
	if spot < 0 or spot >= SPOTS.size():
		return false
	if not open(spot):
		return false
	return not gone.has(spot) or Time.get_ticks_msec() >= int(gone[spot])


static func beaten(spot: int) -> void:
	gone[spot] = Time.get_ticks_msec() + int(RESPAWN * 1000.0)


## The monster a roamer looks like (always the same for a spot, so it does not change by itself).
static func shows(spot: int) -> String:
	var list: Array = kind_of(spot)["shows"]
	return String(list[(spot + roll) % list.size()])


## The one-room fight a roamer starts, in the form run.gd takes as a level (G.next_run "level").
## "encounter" marks it: one fight room, no boss, and winning the room ends it (run.gd).
static func fight(spot: int) -> Dictionary:
	var k := kind_of(spot)
	var out := {"id": "enc_%d" % spot, "encounter": true, "spot": spot, "name": String(k["title"]), "area": String(k["area"]),
		"floor": int(k.get("floor", 1)), "tier": int(k["tier"]), "rooms": 1}
	if k.has("look"):
		out["look"] = String(k["look"])
	return out


const Story = preload("res://scripts/data/story.gd")
const Tale = preload("res://scripts/data/tale.gd")


## The terrain at a point of the world map (places.gd "world": sand east of about x 870, the Cinder
## rock in the north-east corner), and one roamer spot of that kind whose fight to start.
## (the quality pass) The road band between Wickmere and Dustwatch is the robbers' (they were in the game
## and never met: with random fights nothing ever asked for their kind).
static func kind_at(at: Vector2) -> String:
	if at.x > 1330.0 and at.y < 440.0:
		return "rock"
	if ROAD.has_point(at):
		return "robbers"
	return ground_at(at)


## The ground alone: sand or grass (what the road band falls back on while no robbers work it).
static func ground_at(at: Vector2) -> String:
	if at.x > 1330.0 and at.y < 440.0:
		return "rock"
	return "sand" if at.x > 870.0 else "grass"


static func spot_for(at: Vector2) -> int:
	var best := _nearest(kind_at(at), at)
	return best if best >= 0 else _nearest(ground_at(at), at)


static func _nearest(want: String, at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in SPOTS.size():
		if String(SPOTS[i]["kind"]) != want or not open(i):
			continue
		var d := (SPOTS[i]["at"] as Vector2).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best
