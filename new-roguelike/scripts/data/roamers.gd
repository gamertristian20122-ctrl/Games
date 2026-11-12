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

const RESPAWN := 240.0             ## seconds until a beaten roamer walks its patch again
const SEE := 120.0                 ## map px: closer than this and it comes for the knight
const LOSE := 190.0                ## further than this and it gives up and walks home
const WALK := 26.0                 ## px/s strolling        (the knight does 190 on the map)
const CHASE := 118.0               ## px/s chasing: slower than the knight, so he can get away
const TOUCH := 20.0                ## map px between their feet that counts as a touch
const GRACE := 3.0                 ## seconds after arriving on the map before any roamer chases

const KINDS := {
	"grass": {"look": "forest", "tier": 0, "shows": ["thorn_elf", "wood_beast", "sporeling"], "title": "Ambush in the grass", "area": "The wild woods"},
	"robbers": {"look": "road", "tier": 1, "shows": ["bandit_cutter", "bandit_bruiser"], "title": "Robbers on the road", "area": "The east road"},
	"sand": {"look": "desert", "tier": 1, "shows": ["dust_mummy", "tomb_blade"], "title": "Out of the sand", "area": "The eastern sands"},
	"rock": {"floor": 3, "tier": 2, "shows": ["rubble_walker", "magma_heart"], "title": "Dragged into a cinder cave", "area": "The Cinder Mountains"},
}

const SPOTS := [
	# (none within about 200 px of the village gate at 300, 570: a new knight gets a quiet first step)
	{"kind": "grass", "at": Vector2(560, 720), "leash": 50.0},
	{"kind": "grass", "at": Vector2(640, 540), "leash": 60.0},
	{"kind": "grass", "at": Vector2(800, 520), "leash": 60.0},
	{"kind": "grass", "at": Vector2(500, 470), "leash": 40.0},
	{"kind": "robbers", "at": Vector2(820, 720), "leash": 60.0, "from": 1},
	{"kind": "sand", "at": Vector2(1000, 580), "leash": 70.0},
	{"kind": "sand", "at": Vector2(1010, 760), "leash": 80.0},
	{"kind": "sand", "at": Vector2(1300, 700), "leash": 90.0},
	{"kind": "sand", "at": Vector2(1460, 800), "leash": 80.0},
	{"kind": "robbers", "at": Vector2(1230, 580), "leash": 70.0, "from": 3},
	{"kind": "rock", "at": Vector2(1470, 300), "leash": 60.0},
	{"kind": "rock", "at": Vector2(1620, 250), "leash": 60.0},
	{"kind": "rock", "at": Vector2(1880, 240), "leash": 50.0},
]

## Which roamers are beaten: spot number -> the moment (msec since the game started) it returns.
static var gone := {}


static func kind_of(spot: int) -> Dictionary:
	return KINDS[String(SPOTS[spot]["kind"])]


## Is this roamer on the map right now?
static func here(spot: int) -> bool:
	if spot < 0 or spot >= SPOTS.size():
		return false
	if Story.chapter() < int(SPOTS[spot].get("from", 0)):
		return false
	return not gone.has(spot) or Time.get_ticks_msec() >= int(gone[spot])


static func beaten(spot: int) -> void:
	gone[spot] = Time.get_ticks_msec() + int(RESPAWN * 1000.0)


## The monster a roamer looks like (always the same for a spot, so it does not change by itself).
static func shows(spot: int) -> String:
	var list: Array = kind_of(spot)["shows"]
	return String(list[spot % list.size()])


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
