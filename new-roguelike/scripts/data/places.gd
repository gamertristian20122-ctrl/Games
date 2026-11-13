extends RefCounted
## Places: every screen the knight can WALK around in outside the hill. scripts/hub/hub.gd shows
## one at a time and moves between them through their exits (a short fade).
##   village   the camp grown into a small village (its things are in scripts/data/hub.gd)
##   elfwood   east of the village: the road through the Elfwood (walk off the village's east edge)
##   glade     east again: the rune glade, where the Warden of the Wood opens the Elfwood's levels
##   hall      the tavern's hall: the barkeep sells items, the stairs lead out to the village
##   room      your room upstairs: the game starts here (bed, looking glass)
## A place is a Dictionary:
##   "name"      shown when you arrive            "size"   Vector2, the whole picture
##   "outdoor"   true = grass, forest wall, lights, fireflies (built from "props", "paths" ...)
##   "art"       indoor: one picture (an Art id) laid down as the whole place
##   "walk"      Rect2 the hero may walk in       "blocks" [Rect2] furniture and walls inside it
##   "spawn"     Vector2 where he stands when nothing else says where
##   "people"    rows like scripts/data/hub.gd NPCS. "ghost": true = someone already painted into
##               the picture: no sprite of ours, only a spot to talk to ("top" = how high the name floats)
##   "exits"     [{"rect": Rect2, "to": place id, "at": Vector2}] walk into the rectangle to go there
## THE WIDE WORLD (v0.10.0): "world" is one giant map shown ZOOMED OUT. The knight is drawn big on it and
## covers ground fast. Camps and fight areas are spots on it. Extra keys a place may have:
##   "zoom"        0.5 = the camera shows twice as much        "hero_scale", "speed"  the knight's size and pace
##   "ground"      the tile laid under everything (default the forest grass)
##   "regions"     [[tile id, [corner points]]] other ground laid over it in big ragged patches
##   "floor"       [[tile id, Rect2]] a paved rectangle        "decals"  [[piece, x, y]] flat things on the ground
##   "shades"      [Rect2] flat dark rectangles (a doorway)
##   "groves"      [{"rect", "ids", "n", "solid"}] pieces scattered at random (the same every time), kept
##                 off the paths and away from the signs
##   "signs"       [{"text", "pos", "sites" or "need"}] a name floating over a spot on the map: gold = open
##                 with work to do, grey = still shut, green = done
##   "camp"        0, 1, 2: walking in makes this the camp the game opens in next time
##   an exit may have "need" (a level id that must be cleared) and "why" (said while it is not)
##   a "gate" person lists "sites": the sites of scripts/data/story.gd whose levels are entered there
##   "as": "smith"  a person who sells what the village smith sells (upgrades, weapons)
##   "forest" may give its own "big", "side", "low", "young" lists (the edge of a desert camp is not trees)
## Interiors are cut from the pack's own tavern picture (tools/import_hub.py, HALVED), so their
## numbers below are pixels of those pictures.

const Hub = preload("res://scripts/data/hub.gd")
const Tale = preload("res://scripts/data/tale.gd")

const START := "room"            ## where Play puts you


## The place with this id. While the story of scripts/data/tale.gd is on, the village is the
## town of Wickmere, the Deepwood and the beacon's hill exist, and the Elfwood's two old places
## are fitted to the story (who stands there, where the roads lead, how light it is).
static func get_place(id: String) -> Dictionary:
	if not Tale.on():
		return _base_place(id)
	match id:
		"village":
			return _dress_town(Tale.town())
		"deepwood":
			return Tale.deepwood()
		"beacon":
			return Tale.beacon()
		"suncourt":
			return Tale.suncourt()
	var place := _base_place(id)
	if id == "dustwatch" or id == "world":
		_fit_sands(id, place)
	if id == "dustwatch":
		# folk round the camp fire on the dais, and two by the trader's awning
		_extras(place, [["pc_bandit_scout", 292, 296, 1], ["pc_npc_tavern_a", 350, 294, -1], ["pc_royal_priest", 296, 318, 1],
			["pc_bandit_tracker", 452, 262, -1], ["pc_npc_peasant_a", 466, 276, -1]])
	# DEPTH (scripts/hub/view3d.gd): where the ground climbs, the hills, the water of each place
	match id:
		"elfwood":
			place["rise"] = {"from": 92.0, "over": 84.0, "height": 44.0}
			place["hills"] = [{"at": Vector2(560, 310), "radius": 110.0, "height": 14.0, "top": 20.0}, {"at": Vector2(120, 150), "radius": 100.0, "height": 14.0}]
			# the pond by the road, and (round two) a still pool behind the clearing with a plank footbridge
			# over it into the deep wood, seen through a gap in the trees (the forest picture's bridge)
			# (round three: the pool is a stream running towards the camera, and the footbridge crosses it
			# side-on, its arch seen from the side as in the forest picture)
			place["water"] = [{"at": Vector2(252, 312), "radius": Vector2(58, 17)}, {"at": Vector2(432, 80), "radius": Vector2(19, 40)}]
			place["bridges"] = [{"x0": 396.0, "x1": 468.0, "z": 92.0, "wide": 14.0, "across": true}]
			# a lantern on a post at the bridge's head, and the pale light over the pool that shows it
			(place["props"] as Array).append(["hub_slantern", 400, 114, 2, 0])
			(place["lights"] as Array).append_array([[Vector2(400 + LANTERN_GLASS.x, 114 + LANTERN_GLASS.y), Color(1.0, 0.78, 0.46), 1.0, 0.5],
				[Vector2(430, 96), Color(0.70, 0.88, 1.0), 1.3, 0.6]])
			(place["forest"] as Dictionary)["open"] = ((place["forest"] as Dictionary)["open"] as Array) + [Rect2(180, 330, 150, 60), Rect2(346, 66, 168, 44)]
			(place["props"] as Array).append_array([["hub_vplant_4", 374, 100, 0, 1], ["hub_vplant_5", 386, 104, 0, 1], ["hub_vplant_8", 402, 104, 0, 1],
				["hub_vplant_6", 470, 104, 0, 1], ["hub_vplant_4", 490, 98, 0, 1], ["hub_vplant_7", 480, 104, 0, 1], ["hub_vbushm_0", 356, 92, 0, 2], ["hub_vbush_4", 506, 90, 0, 2]])
		"glade":
			place["rise"] = {"from": 100.0, "over": 84.0, "height": 48.0}
			place["hills"] = [{"at": Vector2(300, 208), "radius": 128.0, "height": 13.0, "top": 74.0}]      # the rune ring stands on a low rise
			# (nobody walks behind the two big trees at the clearing's back corners)
			place["blocks"] = (place.get("blocks", []) as Array) + [Rect2(140, 100, 52, 22), Rect2(390, 100, 52, 22)]
		"world":
			# Hollow Hill over its gate, the Cinder Mountains in the north-east, dunes in the sands, low wooded hills
			place["hills"] = [{"at": Vector2(300, 462), "radius": 180.0, "height": 76.0}, {"at": Vector2(1700, 150), "radius": 430.0, "height": 112.0},
				{"at": Vector2(1440, 110), "radius": 270.0, "height": 70.0}, {"at": Vector2(1960, 210), "radius": 260.0, "height": 84.0},
				{"at": Vector2(1250, 940), "radius": 210.0, "height": 26.0}, {"at": Vector2(1040, 380), "radius": 190.0, "height": 22.0},
				{"at": Vector2(1500, 730), "radius": 220.0, "height": 22.0}, {"at": Vector2(150, 240), "radius": 270.0, "height": 52.0},
				{"at": Vector2(600, 960), "radius": 250.0, "height": 40.0}]
			place["water"] = [{"at": Vector2(430, 812), "radius": Vector2(92, 40)}, {"at": Vector2(1424, 664), "radius": Vector2(58, 26)}]
			(place["exits"] as Array)[0]["at"] = Vector2(480, 500)          # Wickmere's south gate
	if id == "elfwood" or id == "glade":
		place["tint"] = Color(0.98, 0.93, 0.80) if Tale.lit("elfwood") else place["tint"]
		if id == "elfwood":
			(place["exits"] as Array)[0]["at"] = Vector2(896, 280)        # back to Wickmere's east gate
		else:
			(place["exits"] as Array).append({"rect": Rect2(444, 168, 10, 60), "to": "deepwood", "at": Vector2(50, 230), "tale": 3,
				"why": "Thessaly holds the stones alone. Speak with her."})
			(place["forest"] as Dictionary)["open"] = [Rect2(-30, 140, 70, 120), Rect2(440, 140, 80, 120)]
			(place["paths"] as Array).append([Vector2(300, 206), Vector2(490, 198)])
			for row: Dictionary in place["people"]:
				if String(row["id"]) == "thessaly":
					row["role"] = "chat"
					row["tale_to"] = 2                                    # after that she walks with the knight
	return place


## WICKMERE'S DRESSING (v0.24.0): more of the owner's Garden and Castle pieces laid over the town of
## tale.gd town() (that file keeps the story's houses, people and roads; this only adds things that
## stand or lie about). Every row is a prop as in "props": [id, x, y, solid radius, px below base].
##   the south gate   (round two) two stone gate piers in the near balustrade (tale.gd "near"),
##                    the lamps either side of the road
##   the kings' walk  stone busts of the old kings either side of the street to the sealed gate
##   the herb garden  a hedged plot in the open ground south-east of the square
##   flowers          single garden flowers in clumps by doors, fences, benches and the mere
static func _dress_town(t: Dictionary) -> Dictionary:
	var props: Array = (t["props"] as Array).duplicate()
	var blocks: Array = (t["blocks"] as Array).duplicate()
	# the kings' walk: busts of the old kings on the street up to the sealed gate
	props.append_array([["hub_cbust_0", 448, 220, 5, 1], ["hub_cbust_2", 512, 220, 5, 1], ["hub_cbust_4", 448, 186, 5, 1], ["hub_cbust_5", 512, 186, 5, 1]])
	# THE SQUARE IS PAVED down to the south road (round two's fixer: the south half read as a park,
	# lawns and flower confetti round the spawn, the frontage only a strip at the top): cobbles from
	# the square to y 472 and east to the smithy's yard; the garden beds, the young tree and the
	# herb garden that stood on that ground go (urns and planters stay as the square's furniture)
	var floor: Array = (t["floor"] as Array).duplicate()
	floor.append_array([["hub_gcobble", Rect2(368, 376, 400, 96)], ["hub_gcobble", Rect2(592, 316, 208, 60)]])
	t["floor"] = floor
	for i in range(props.size() - 1, -1, -1):
		var row: Array = props[i]
		var at := Vector2(row[1], row[2])
		if Rect2(368, 316, 432, 160).has_point(at) and (String(row[0]).begins_with("hub_gbed") or String(row[0]).begins_with("hub_tree") or String(row[0]).begins_with("hub_bush")):
			props.remove_at(i)
	var paths: Array = []
	for path: Array in t.get("paths", []):
		if (path[0] as Vector2) == Vector2(840, 496):
			paths.append([Vector2(840, 496), Vector2(776, 474)])
		else:
			paths.append(path)
	t["paths"] = paths
	# flowers: clumps of single garden flowers (cut one by one from the Garden pack), only on the
	# grass that is left (by the mere, the west house and the far corners)
	var clumps: Array = [Vector2(160, 420), Vector2(96, 432), Vector2(344, 452), Vector2(170, 452),
		Vector2(822, 512), Vector2(892, 512), Vector2(232, 330)]
	var tints: Array = [[0, 1, 2, 4, 5], [6, 8, 9, 12, 13], [16, 17, 18, 19, 20], [23, 24, 25, 28, 29]]
	for i in clumps.size():
		var at: Vector2 = clumps[i]
		var set: Array = tints[i % tints.size()]
		for k in 5:
			var off := Vector2(float((i * 7 + k * 13) % 23) - 11.0, float((i * 5 + k * 11) % 13) - 6.0)
			props.append(["hub_gflower_%d" % int(set[(i + k) % set.size()]), at.x + off.x, at.y + off.y, 0, 0])
	t["props"] = props
	t["blocks"] = blocks
	# lamps at the south gate and by the herb garden (their glass and glow like the town's others)
	var torches: Array = (t["torches"] as Array).duplicate()
	var lights: Array = (t["lights"] as Array).duplicate()
	for at: Vector2 in [Vector2(428, 506), Vector2(532, 506), Vector2(786, 424)]:
		props.append(["hub_post", at.x, at.y, 3, 0])
		torches.append(at)
		lights.append([at - Vector2(0, 40), Color(1.0, 0.78, 0.46), 1.0, 0.55])
	t["torches"] = torches
	t["lights"] = lights
	_market_town(t)
	# townsfolk in twos and threes at the shop doors and round the square (they only stand about)
	# (those at the doors stand UP on the terrace, never just below its edge: the coping would cross
	# them at the knee)
	_extras(t, [["pc_npc_tavern_b", 170, 170, 1], ["pc_scholar_cataloguer", 184, 172, -1],
		["pc_npc_peasant_a", 614, 168, 1], ["pc_npc_tavern_a_hold", 628, 172, -1],
		["pc_npc_tavern_a", 712, 174, 1], ["pc_scholar_director", 726, 176, -1],
		["pc_royal_archer", 432, 232, 1], ["pc_npc_tavern_b_hold", 448, 236, -1], ["pc_royal_priest", 440, 248, -1],
		["pc_npc_peasant_a", 372, 392, 1], ["pc_npc_tavern_b", 388, 396, -1]])
	# (round two's fixer: no lamps on gibbets round the benches; the square is lit by its corner
	# lamps and the watch-fire)
	_lanterns(t, [Vector2(760, 310), Vector2(514, 474), Vector2(360, 400), Vector2(600, 400)])
	# THE FOUNTAIN is built in stone in the 3D look (scripts/hub/arch/sites.gd _fountain): a low
	# kerb round a basin of water (the "water" row marked "basin"), a short column with a bowl
	t["fountain"] = {"at": Vector2(480, 322), "rx": 34.0, "rz": 22.0, "high": 7.0}
	# and every lantern of the town is an iron street lamp in the 3D look (sites.gd _iron_lamp), not
	# the pack's lantern on a timber arm
	t["iron_lamps"] = true
	# (the bunting hung from the top of the timber posts: it hangs from the iron lamps' caps now, which
	# stand under where the lanterns hung)
	var feet := {}
	for row: Array in t["props"]:
		if String(row[0]) == "hub_slantern":
			feet[Vector2(row[1], row[2])] = -15.0 if (row.size() > 5 and bool(row[5])) else 15.0
	var bunting: Array = []
	for row: Array in t.get("bunting", []):
		var r := row.duplicate()
		for k in 2:
			if feet.has(r[k]):
				r[k] = (r[k] as Vector2) + Vector2(float(feet[r[k]]), 0.0)
				r[2] = 34.0
		bunting.append(r)
	t["bunting"] = bunting
	var water: Array = (t.get("water", []) as Array).duplicate()
	water.append({"at": Vector2(480, 322), "radius": Vector2(30.0, 19.0), "lift": 5.0, "basin": true})
	t["water"] = water
	# the pale statue that poured into the mere beside the square's path goes (it stood up as a
	# white billboard in the middle of the picture); the one at the far end of the mere stays
	var anims: Array = []
	for row: Array in t.get("anims", []):
		if not (String(row[0]) == "hub_gspout" and float(row[1]) == 398.0):
			anims.append(row)
	t["anims"] = anims
	# more kinds of grass and flowers lying in the grass
	var scatter: Dictionary = (t["scatter"] as Dictionary).duplicate()
	scatter["hub_gflower"] = [32, 36]
	scatter["hub_gtuft"] = [4, 60]
	t["scatter"] = scatter
	_harbour(t)
	return t


## WICKMERE'S HARBOUR (round three, like the harbour at dusk of the reference pictures): the mere and
## the gardens of the south-west are a lakeside quay now. The water lies in a round stone basin SUNK
## below the town (a water row with "quay": true: scripts/hub/view3d_build.gd quay_dip): a quay wall
## stands over it with a stone coping, iron bollards and a flight of steps down to the water
## (scripts/hub/arch/sites.gd _quay). A plank jetty on posts runs out over it ("jetty"; people walk
## out on it: its "decks" row lifts them), and a boat lies moored beside the jetty ("boat": a hull of
## the packs' planks built in code, a mast, a sail furled on its boom, a lantern at the stern).
## Lamps stand along the quay's edge so their light falls on the water; crates, barrels, sacks and
## coils of rope lie about on the quay. The quay is paved in big flags (the castle pack's ashlar).
## Nobody walks into the water: the basin lists its own round "stops" along the quay wall (hub.gd).
const HARBOUR_AT := Vector2(205, 606)
const HARBOUR_R := Vector2(260, 142)
const QUAY_IN := 0.93                    ## the quay wall's ellipse, as a share of the water's (as view3d_build.gd QUAY_IN)
const JETTY_X := 318.0                   ## the middle of the jetty
const JETTY_W := 22.0
const BOAT := {"at": Vector2(246, 508), "long": 100.0, "beam": 26.0}


## How far north the quay wall reaches at x (px): `pad` px further out from the water.
static func quay_y(x: float, pad: float = 0.0) -> float:
	var rw := HARBOUR_R * QUAY_IN + Vector2(pad, pad)
	var k := clampf((x - HARBOUR_AT.x) / rw.x, -1.0, 1.0)
	return HARBOUR_AT.y - rw.y * sqrt(1.0 - k * k)


static func _harbour(t: Dictionary) -> void:
	var zone := Rect2(28, 402, 412, 200)
	var rw := HARBOUR_R * QUAY_IN
	var wide := rw + Vector2(18, 18)
	# the gardens, the mere's statues and its flowers go
	var garden := ["hub_gbed", "hub_gflower", "hub_vplant", "hub_vbush", "hub_bush", "hub_tree", "hub_gcypress", "hub_stonebench",
		"hub_planter", "hub_flower", "hub_tuft", "hub_fence"]
	var props: Array = t["props"]
	for i in range(props.size() - 1, -1, -1):
		var row: Array = props[i]
		var at := Vector2(row[1], row[2])
		var id := String(row[0])
		var is_garden := false
		for g: String in garden:
			if id.begins_with(g):
				is_garden = true
		if (is_garden and zone.has_point(at)) or ((at - HARBOUR_AT) / wide).length() < 1.0:
			props.remove_at(i)
	var anims: Array = []
	for row: Array in t.get("anims", []):
		if String(row[0]) != "hub_gspout":
			anims.append(row)
	t["anims"] = anims
	var paths: Array = []
	for path: Array in t.get("paths", []):
		if not zone.has_point(path[0]) or not zone.has_point(path[1]):
			paths.append(path)
	t["paths"] = paths
	# the quay's flags (the square's cobbles are laid over them where they meet)
	t["floor"] = [["hub_bstone", Rect2(-48, 396, 512, 264)]] + (t["floor"] as Array)
	# THE BASIN: its round stops along the quay wall (a little inside it, reaching 10 px out over the
	# coping), open where the jetty leaves the quay, and along both sides of the jetty
	var stops: Array = []
	var a := PI
	while a <= TAU + 0.001:
		var dir := Vector2(cos(a), sin(a))
		var on := HARBOUR_AT + Vector2(rw.x * dir.x, rw.y * dir.y)
		var n := Vector2(dir.x / rw.x, dir.y / rw.y).normalized()
		if on.y < 548.0 and absf(on.x - JETTY_X) > JETTY_W * 0.5 + 12.0:
			stops.append([on - n * 4.0, 14.0])
		a += 7.0 / maxf(Vector2(-rw.x * sin(a), rw.y * cos(a)).length(), 1.0)
	for side: float in [-1.0, 1.0]:
		var x := JETTY_X + side * (JETTY_W * 0.5 + 10.0)
		var z := quay_y(x) - 2.0
		while z < 560.0:
			stops.append([Vector2(x, z), 10.0])
			z += 7.0
	var water: Array = []
	for pond: Dictionary in t.get("water", []):
		if bool(pond.get("basin", false)):
			water.append(pond)                  # (the fountain's basin stays; the mere goes)
	water.append({"at": HARBOUR_AT, "radius": HARBOUR_R, "quay": true, "depth": 22.0, "lift": 11.0, "stops": stops,
		"steps": [126.0], "bollards": [70.0, 104.0, 176.0, 262.0, 290.0, 352.0, 380.0]})
	t["water"] = water
	# the jetty (people walk out on it) and the boat moored beside it
	var head := quay_y(JETTY_X) - 4.0
	t["jetty"] = {"x": JETTY_X, "z0": head, "z1": 584.0, "wide": JETTY_W, "up": 2.0, "water": 11.0 - 22.0}
	t["boat"] = BOAT.duplicate()
	var bat: Vector2 = BOAT["at"]
	var blong := float(BOAT["long"])
	t["decks"] = [{"rect": Rect2(JETTY_X - JETTY_W * 0.5, head, JETTY_W, 600.0 - head), "up": 2.0},
		{"rect": Rect2(bat.x - blong * 0.5 + 8.0, bat.y - 9.0, blong - 14.0, 18.0), "up": -6.0}]
	# lamps along the quay's edge (iron street lamps in the 3D look), one at the jetty's end, one at the
	# boat's stern: their light lies on the water as long broken streaks
	var lights: Array = t["lights"]
	var amber := Color(1.0, 0.78, 0.46)
	for x: float in [92.0, 200.0, JETTY_X - 16.0, 400.0]:
		var post := Vector2(x, quay_y(x, 15.0))
		props.append(["hub_slantern", post.x - LANTERN_GLASS.x, post.y, 2, 0])
		lights.append([post + Vector2(0, LANTERN_GLASS.y), amber, 1.0, 0.55])
	var end_post := Vector2(JETTY_X + 7.0, 572.0)
	props.append(["hub_slantern", end_post.x - LANTERN_GLASS.x, end_post.y, 0, 0])
	lights.append([end_post + Vector2(0, LANTERN_GLASS.y), amber, 1.0, 0.55])
	lights.append([bat + Vector2(blong * 0.5 - 7.0, -1.0), amber, 0.8, 0.45])         # the boat's stern lantern
	# cargo on the quay: barrels and crates by the harbour house, sacks of grain, crates at the
	# jetty's head (all low, set back from the coping)
	props.append_array([["hub_sbarrel_1", 56, 448, 8, 1], ["hub_sbarrel_f", 76, 456, 4, 1], ["hub_scrate_4", 50, 468, 5, 1],
		["hub_scrate_5", 66, 474, 5, 1], ["hub_sbarrel_f", 168, 412, 4, 1],
		["hub_ssack_1", 140, 448, 0, 1], ["hub_ssack_2", 152, 452, 0, 1], ["hub_scrate_0", 128, 446, 4, 1],
		["hub_sbarrel_f", 282, 460, 4, 1], ["hub_sbarrel_f", 292, 464, 4, 1], ["hub_scrate_2", 344, 472, 4, 1], ["hub_scrate_3", 356, 476, 4, 1],
		["hub_ssack_4", 372, 470, 0, 1],
		# on the boat's deck: a barrel and a crate lashed down
		["hub_sbarrel_f", bat.x + 18.0, bat.y + 2.0, 0, 0], ["hub_scrate_2", bat.x - 14.0, bat.y + 1.0, 0, 0]])
	t["coils"] = [Vector2(110, 470), Vector2(232, 458), Vector2(JETTY_X + 4.0, 548.0), Vector2(384, 486)]
	# folk on the quay: a fisher looking at the boat, a woman with her basket by the sacks
	_extras(t, [["pc_npc_peasant_a", 168, 460, 1], ["pc_npc_tavern_b_hold", 112, 444, 1]])
	# the near balustrade only east of the south road now (west of it lies open water); the gate
	# piers stand at the basin's corner and across the road
	t["near"] = [{"z": 566.0, "runs": [[528.0, 936.0]], "piers": [[452.0, 30.0], [512.0, 30.0]]}]
	var forest: Dictionary = t["forest"]
	forest["open"] = (forest.get("open", []) as Array) + [Rect2(-90, 380, 170, 320)]
	t["tour"] = [Vector2(250, 200), Vector2(480, 404), Vector2(720, 270), Vector2(250, 452), Vector2(660, 196)]


## TOWNSFOLK (round two's fixer): people who only stand about, in twos and threes at doors and
## round a fire, so a street is lived in. Each row: [sprite id, x, y, facing (1 right, -1 left)].
## They are people in the 3D look (sharp, lit like people, seen through what hides them) but have
## nothing to say: the knight is never offered a talk with them ("extra": true, hub.gd).
const EXTRA_HANDS := {"pc_npc": "pc_hand_base_2", "pc_scholar": "pc_hand_library_6", "pc_royal": "pc_hand_castle_17",
	"pc_bandit": "pc_hand_hideout_17", "pc_elf": "pc_hand_elf_23"}
static func _extras(t: Dictionary, rows: Array) -> void:
	var people: Array = t["people"]
	for i in rows.size():
		var r: Array = rows[i]
		var sprite := String(r[0])
		var hands := ""
		if not sprite.ends_with("_hold"):
			for k: String in EXTRA_HANDS:
				if sprite.begins_with(k):
					hands = EXTRA_HANDS[k]
		people.append({"id": "extra_%d" % i, "name": "", "title": "", "sprite": sprite, "hands": hands,
			"pos": Vector2(r[1], r[2]), "face": int(r[3]), "role": "chat", "text": "", "extra": true})


## WICKMERE AS A MARKET TOWN (set dressing): what a lived-in street leaves about, all of it the
## purchased packs' own pieces (ids hub_s*, hub_v*; tools/import_hub.py):
##   the south lamp     moved off the middle of the south road to its east verge
##   market stalls      Mira's stall at the south-east corner of the square, a produce stall on
##                      the west street ("stalls": built in 3D by scripts/hub/arch/sites.gd; the
##                      goods on their counters are props lifted onto the counter)
##   the yards          barrels and sacks at the Hollow Flagon, crates and a water tub in the smithy's yard
##   bunting            pennants strung from lamp post to lamp post round the square and down the streets
##   bushes and ferns   round bushes in four colours in the garden corners
##   the near edge      tall dark shrubs past the south edge, between the camera and the town (the
##                      near blur melts them, as a real lens would)
## Nothing here stands on a road or a doorstep; anything tall stands where nobody walks behind it
## (its "blocks" rectangle keeps people off it and out of the shade behind it).
static func _market_town(t: Dictionary) -> void:
	var props: Array = t["props"]
	var blocks: Array = t["blocks"]
	var torches: Array = t["torches"]
	var lights: Array = t["lights"]
	# the lamp post that stood in the middle of the south road goes to its east verge
	var old := Vector2(480, 470)
	var new := Vector2(514, 474)
	for i in props.size():
		var row: Array = props[i]
		if String(row[0]) == "hub_post" and Vector2(row[1], row[2]) == old:
			props[i] = ["hub_post", new.x, new.y, 3, 0]
	for i in torches.size():
		if torches[i] == old:
			torches[i] = new
	for row: Array in lights:
		if row[0] == old - Vector2(0, 40):
			row[0] = new - Vector2(0, 40)
	# market stalls: their counters face the street, their backs to a hedge or the garden
	# (no stall stands out in the west street any more: its roof hid whoever walked behind it)
	t["stalls"] = [{"at": Vector2(636, 422), "wide": 54.0, "roof": "hub_roof_tiles"}]
	blocks.append_array([Rect2(608, 400, 56, 24)])
	# what Mira sells: pots, a jug, a sack of meal, apples in a crate
	props.append_array([["hub_spot", 620, 423, 0, -12], ["hub_sjug", 632, 423, 0, -12], ["hub_ssack_0", 646, 423, 0, -12], ["hub_sveg_4", 658, 423, 0, -4]])
	# produce on the ground at the corner of the west house: cabbages, leeks and greens in crates,
	# sacks of grain (all low: nobody is hidden behind them)
	props.append_array([["hub_sveg_2", 190, 270, 6, 1], ["hub_sveg_0", 204, 274, 6, 1], ["hub_sveg_5", 196, 284, 6, 1],
		["hub_ssack_1", 214, 266, 5, 1], ["hub_ssack_2", 182, 282, 5, 1]])
	# the Hollow Flagon's barrels and a crate; the smithy's crates, its water tub and buckets
	props.append_array([["hub_sbarrel_1", 74, 172, 8, 1], ["hub_sbarrel_f", 52, 178, 4, 1], ["hub_ssack_4", 92, 182, 0, 1], ["hub_scrate_4", 168, 170, 5, 1],
		["hub_sbarrel_1", 790, 250, 8, 1], ["hub_scrate_5", 808, 254, 5, 1], ["hub_scrate_1", 822, 250, 4, 1], ["hub_sbucket", 742, 262, 0, 0]])
	# bunting from lamp post to lamp post (the posts are 48 px tall)
	# (only where people stand in front of the rope, never behind it: a pennant never hides a face)
	t["bunting"] = [[Vector2(210, 300), Vector2(360, 250), 44.0], [Vector2(360, 250), Vector2(600, 250), 44.0, 12.0],
		[Vector2(600, 250), Vector2(880, 250), 44.0, 14.0]]
	# round bushes in the garden corners, ferns and reeds at the mere's edge
	props.append_array([["hub_vbushm_2", 352, 336, 7, 2], ["hub_vbush_6", 60, 452, 8, 2],
		["hub_vplant_4", 160, 466, 0, 1], ["hub_vplant_5", 372, 462, 0, 1], ["hub_vplant_6", 386, 470, 0, 1],
		["hub_vplant_7", 340, 392, 0, 1]])
	_shopfronts(t)
	# the near edge (round two): behind the balustrade (tale.gd "near") only dark masses of leaves at
	# the corners, where nobody walks in front of them: they frame the view like a lens's near blur
	props.append_array([["hub_fleaf_g_5", 12, 640, 0, 4], ["hub_fleaf_o_4", 84, 662, 0, 4], ["hub_fleaf_g_4", 884, 660, 0, 4],
		["hub_fleaf_g_5", 950, 640, 0, 4]])        # (far enough past the edge: at the 35 degree view a thing hides about 1.7 times its height of ground)


## THE NORTH STREET'S SHOPFRONTS (round two): what stands at the doors of the frontage (tale.gd
## town() "houses"), on the terrace or at its foot: the greengrocer's crates under its awning, the
## potter's pots and jugs, the chandler's barrels, a notice board, benches, lanterns at the steps.
## Nothing stands on a step or in front of a door (doors are at x 124, 206, 300, 396, 565, 660, 748,
## 836, 903; steps at 140, 322, 650, 842).
static func _shopfronts(t: Dictionary) -> void:
	var props: Array = t["props"]
	var lights: Array = t["lights"]
	props.append_array([
		# the greengrocer (220): crates of greens under the awning, sacks by the door
		["hub_sveg_2", 226, 167, 0, 0], ["hub_sveg_5", 240, 168, 0, 0], ["hub_sveg_0", 248, 172, 0, 0], ["hub_ssack_1", 190, 168, 0, 0],
		# the potter (382): pots and a jug on a bench under the awning, a crate
		["hub_spot", 360, 166, 0, 0], ["hub_sjug", 370, 168, 0, 0], ["hub_spot", 356, 174, 0, 0], ["hub_scrate_0", 412, 170, 0, 0],
		# the chandler (579): barrels and a crate either side of the door
		["hub_sbarrel_f", 592, 168, 4, 0], ["hub_sbarrel_f", 604, 172, 4, 0], ["hub_scrate_3", 548, 170, 4, 0],
		# the smithy (660): a crate of iron and a bucket at the corners
		["hub_scrate_4", 700, 169, 4, 0], ["hub_sbucket", 620, 172, 0, 0],
		# the weaver (748): sacks, a crate of wool under the awning
		["hub_ssack_4", 724, 170, 0, 0], ["hub_scrate_1", 776, 168, 0, 0], ["hub_ssack_3", 786, 173, 0, 0],
		# the end house (916): firewood and a barrel
		["hub_slog", 928, 172, 0, 0], ["hub_sbarrel_f", 940, 168, 0, 0],
		# lanterns at the foot of the steps, either side of the frontage
		["hub_slantern", 116, 196, 2, 0], ["hub_slantern", 868, 196, 2, 0, true],
	])
	for at: Vector2 in [Vector2(116, 196), Vector2(868, 196)]:
		var flip := at.x > 480.0
		lights.append([at + Vector2(-LANTERN_GLASS.x if flip else LANTERN_GLASS.x, LANTERN_GLASS.y), Color(1.0, 0.78, 0.46), 1.0, 0.55])


## IRON LANTERNS (fixer pass, 13 Nov 2026): every bare lamp post of the town (a wooden stick with
## a glowing square on top) becomes the pack's lantern on an arm (hub_slantern); the lantern hangs
## towards the middle of the town (row field 5: mirrored). The flat glass of a "torches" spot goes;
## hub.gd lays a glowing glass over the lantern of every hub_slantern instead, and the light moves
## onto that glass (LANTERN_GLASS). Lamps at `drop` are taken away (the ones that stood alone in grass).
const LANTERN_GLASS := Vector2(15, -33)      ## the light of a hub_slantern, from its foot (x mirrored with it)
static func _lanterns(t: Dictionary, drop: Array) -> void:
	var props: Array = t["props"]
	var torches: Array = t["torches"]
	var lights: Array = t["lights"]
	var mid := float((t["size"] as Vector2).x) * 0.5
	for i in range(props.size() - 1, -1, -1):
		var row: Array = props[i]
		var at := Vector2(row[1], row[2])
		if String(row[0]) != "hub_post" or not torches.has(at):
			continue
		torches.erase(at)
		var flip := at.x > mid
		var light_at := at + Vector2(-LANTERN_GLASS.x if flip else LANTERN_GLASS.x, LANTERN_GLASS.y)
		for k in range(lights.size() - 1, -1, -1):
			if (lights[k] as Array)[0] == at - Vector2(0, 40):
				if drop.has(at):
					lights.remove_at(k)
				else:
					(lights[k] as Array)[0] = light_at
		if drop.has(at):
			props.remove_at(i)
		else:
			props[i] = ["hub_slantern", at.x, at.y, 2, 0, flip]


static func _base_place(id: String) -> Dictionary:
	match id:
		"room":
			return {
				"name": "Your room", "size": Vector2(144, 164), "art": "hub_in_room",
				"walk": Rect2(10, 64, 124, 90), "spawn": Vector2(72, 100),
				"blocks": [Rect2(8, 50, 48, 86), Rect2(8, 122, 44, 40), Rect2(90, 118, 46, 40), Rect2(62, 42, 24, 26)],
				"exits": [{"rect": Rect2(100, 56, 24, 12), "to": "hall", "at": Vector2(192, 80)}],
				"people": [
					{"id": "bed", "name": "Your bed", "title": "", "ghost": true, "pos": Vector2(62, 96), "top": 4, "role": "bed", "text": ""},
					{"id": "mirror", "name": "Looking glass", "title": "", "ghost": true, "pos": Vector2(76, 72), "top": 22, "role": "mirror", "text": ""},
				],
			}
		"hall":
			return {
				"name": "The Hollow Flagon", "size": Vector2(464, 262), "art": "hub_in_hall",
				"walk": Rect2(10, 64, 440, 182), "spawn": Vector2(192, 80),
				"blocks": [Rect2(0, 56, 62, 92), Rect2(88, 62, 80, 76), Rect2(56, 102, 32, 20), Rect2(210, 72, 74, 40),
					Rect2(210, 134, 74, 40), Rect2(320, 88, 74, 130), Rect2(98, 198, 74, 36), Rect2(210, 198, 74, 36),
					Rect2(74, 202, 12, 14), Rect2(186, 202, 12, 14), Rect2(298, 202, 12, 14), Rect2(410, 202, 12, 14)],
				"exits": [{"rect": Rect2(180, 56, 24, 12), "to": "room", "at": Vector2(112, 76)},
					{"rect": Rect2(8, 240, 50, 10), "to": "village", "at": Vector2(124, 172)}],
				"people": [
					{"id": "barkeep", "name": "Oswin", "title": "Barkeep", "ghost": true, "pos": Vector2(130, 146), "top": 62, "role": "shop",
						"text": "The Hollow Flagon. Beds upstairs, stew in the pot, and a few things from the hill under the counter, if you have coin."},
					{"id": "patron", "name": "Old Wenna", "title": "Regular", "ghost": true, "solid": 7.0, "pos": Vector2(160, 192), "top": 30, "role": "chat",
						"text": "I was a girl when the hill last shook. We left bread at the gate, then. Nobody does now."},
				],
			}
		"elfwood":
			# the road through the Elfwood: quiet, a few elves who have not gone thorn-sick
			return {
				"name": "The Elfwood Road", "size": Vector2(640, 368), "outdoor": true, "walk": Rect2(30, 108, 580, 226), "spawn": Vector2(52, 204),
				"tint": Color(0.72, 0.84, 0.92),
				"props": [["hub_tree_teal_1", 320, 196, 8, 8], ["hub_rune_0", 214, 250, 9, 3], ["hub_rune_2", 250, 270, 5, 2], ["hub_bloom_0", 196, 160, 0, 2],
					["hub_shroom_0", 150, 292, 0, 1], ["hub_shroom_1", 526, 262, 0, 1],
					["hub_rock_moss_2", 110, 300, 14, 3], ["hub_bush_deep_1", 352, 304, 10, 4],
					["hub_bush_green_1", 150, 150, 12, 5], ["hub_vine_0", 606, 322, 0, 2], ["hub_tree_pink_4", 500, 140, 4, 5],
					# v0.24.0: the road's edges: ferns, toadstools, mossy stones, flowers in the light under the trees
					["hub_plant_3", 182, 178, 0, 1], ["hub_plant_4", 120, 232, 0, 1], ["hub_plant_1", 352, 168, 0, 1], ["hub_plant_5", 548, 222, 0, 1],
					["hub_plant_0", 236, 236, 0, 1], ["hub_plant_6", 470, 214, 0, 1], ["hub_shroom_3", 330, 250, 0, 1], ["hub_shroom_4", 344, 258, 0, 1],
					["hub_shroom_2", 584, 280, 0, 1], ["hub_shroom_0", 92, 160, 0, 1], ["hub_rock_moss_0", 62, 254, 12, 3], ["hub_stone_1", 556, 136, 10, 3],
					["hub_rock_1", 600, 300, 12, 3], ["hub_bush_orange_1", 560, 150, 9, 4], ["hub_bush_green_0", 96, 136, 10, 4],
					["hub_bloom_7", 80, 320, 0, 2],
					# two rune stones mark the way on to the glade
					["hub_rune_0", 592, 172, 9, 3], ["hub_rune_2", 592, 236, 5, 2],
					# flowers in clumps beside the road
					["hub_gflower_0", 160, 226, 0, 0], ["hub_gflower_4", 168, 230, 0, 0], ["hub_gflower_1", 154, 233, 0, 0], ["hub_gflower_24", 362, 222, 0, 0],
					["hub_gflower_28", 370, 226, 0, 0], ["hub_gflower_25", 356, 229, 0, 0], ["hub_gflower_12", 300, 176, 0, 0], ["hub_gflower_13", 309, 172, 0, 0],
					["hub_gflower_8", 294, 170, 0, 0], ["hub_gflower_17", 520, 176, 0, 0], ["hub_gflower_18", 528, 181, 0, 0], ["hub_gflower_20", 514, 183, 0, 0],
					["hub_gflower_29", 204, 288, 0, 0], ["hub_gflower_23", 212, 292, 0, 0],
					# set dressing: reeds and ferns round the pond, foxgloves in the light, round bushes in
					# layers along both edges, a dead tree and old stumps where the thorn-sickness passed
					["hub_vplant_4", 184, 304, 0, 1], ["hub_vplant_5", 316, 300, 0, 1], ["hub_vplant_6", 326, 308, 0, 1], ["hub_vplant_3", 300, 296, 0, 1],
					["hub_vplant_0", 206, 296, 0, 1], ["hub_vplant_7", 158, 268, 0, 1], ["hub_vplant_8", 168, 274, 0, 1], ["hub_vplant_9", 376, 302, 0, 1],
					["hub_vplant_7", 500, 286, 0, 1], ["hub_vplant_1", 112, 186, 0, 1],
					["hub_vbushm_0", 226, 126, 8, 2], ["hub_vbushl_2", 610, 120, 0, 2], ["hub_vbushs_0", 46, 120, 0, 2],
					["hub_bush_deep_1", 524, 336, 8, 2], ["hub_bush_deep_2", 408, 338, 8, 2], ["hub_vbushl_0", 52, 332, 0, 2],
					["hub_vdead_0", 560, 116, 0, 2], ["hub_vdead_2", 140, 252, 0, 1], ["hub_vdead_2", 470, 120, 0, 1],
					# THE CAMP IN THE CLEARING (round two, like the forest-campfire picture): the fire (see "fire")
					# with logs and a sawn round to sit on, bedrolls (see "decals"), packs, the cook's pot, a crate,
					# firewood and a lantern on a post; the elf child warms her hands at it
					["hub_slog", 428, 226, 0, 1], ["hub_slog", 470, 250, 0, 1], ["hub_sround", 396, 244, 5, 1],
					["hub_ssack_2", 380, 236, 0, 1], ["hub_ssack_4", 482, 232, 0, 1], ["hub_spot", 414, 262, 0, 0], ["hub_scrate_1", 494, 238, 4, 1],
					["hub_slog_s", 494, 258, 0, 0], ["hub_slog_s", 498, 263, 0, 0], ["hub_slantern", 504, 226, 2, 0],
					# the near edge (round two): the camera looks down at 35 degrees, so a thing past the walk's
					# bottom edge hides the ground about 1.7 times its own height behind it: only LOW dark bushes,
					# ferns and reeds there (they melt in the near blur), the tall dark leaves outside the walk
					["hub_bush_deep_2", 70, 384, 0, 2], ["hub_vplant_4", 112, 380, 0, 1], ["hub_bush_green_3", 150, 388, 0, 2],
					["hub_bush_deep_2", 404, 386, 0, 2], ["hub_vplant_5", 432, 380, 0, 1], ["hub_bush_green_3", 472, 390, 0, 2],
					["hub_bush_deep_1", 540, 392, 0, 2], ["hub_vplant_4", 584, 382, 0, 1],
					["hub_fleaf_g_5", -16, 380, 0, 4], ["hub_fleaf_g_4", 656, 376, 0, 4]],
				"tour": [Vector2(430, 196), Vector2(140, 230), Vector2(410, 290), Vector2(300, 260), Vector2(560, 200)],     # test pictures (--hub=elfwood --shots)
				"fire": Vector2(430, 248),
				"decals": [["hub_sbed_0", 404, 272], ["hub_sbed_1", 380, 262]],
				"paths": [[Vector2(-10, 204), Vector2(250, 210), Vector2(400, 190), Vector2(650, 196)]],
				"scatter": {"hub_tuft": [24, 90], "hub_flower": [26, 60], "hub_pebble": [20, 10], "hub_twig": [10, 14], "hub_gtuft": [4, 50], "hub_gflower": [32, 30]},
				"forest": {"top_gaps": [], "behind": [], "open": [Rect2(-30, 150, 70, 120), Rect2(600, 140, 80, 120), Rect2(-40, 340, 720, 60)]},
				"exits": [{"rect": Rect2(26, 176, 10, 60), "to": "village", "at": Vector2(660, 204)},
					{"rect": Rect2(604, 168, 10, 60), "to": "glade", "at": Vector2(50, 196)}],
				"people": [
					{"id": "aelin", "name": "Aelin", "title": "Elf of the Road", "sprite": "pc_elf_base", "hands": "pc_hand_elf_23",
						"pos": Vector2(270, 180), "face": -1, "role": "chat",
						"text": "Turn back, tin man. Past the glade our own kin wait with thorns in their eyes. The hunger under your hill is in the roots now."},
					{"id": "wicker", "name": "Wicker", "title": "Elf Child", "sprite": "pc_elf_druid", "hands": "pc_hand_elf_23",
						"pos": Vector2(458, 272), "face": -1, "role": "chat",
						"text": "The mushrooms walk at night. I counted nine. Mother says do not count them, they count back."},
				],
				"lights": [[Vector2(214, 236), Color(0.45, 0.85, 1.0), 1.2, 0.5], [Vector2(320, 150), Color(0.6, 1.0, 0.7), 1.6, 0.35],
					[Vector2(592, 200), Color(0.45, 0.85, 1.0), 1.0, 0.45],
					[Vector2(430, 238), Color(1.0, 0.62, 0.32), 2.4, 0.8], [Vector2(504 + LANTERN_GLASS.x, 226 + LANTERN_GLASS.y), Color(1.0, 0.78, 0.46), 0.9, 0.5]],
			}
		"glade":
			return {
				"name": "The Rune Glade", "size": Vector2(480, 330), "outdoor": true, "walk": Rect2(30, 108, 420, 190), "spawn": Vector2(50, 196),
				"tint": Color(0.66, 0.80, 0.92),
				"props": [["hub_rune_1", 300, 170, 12, 3], ["hub_rune_0", 250, 214, 9, 3], ["hub_rune_0", 352, 214, 9, 3], ["hub_rune_2", 276, 244, 5, 2],
					["hub_rune_2", 328, 244, 5, 2], ["hub_bloom_0", 120, 150, 0, 2], ["hub_bloom_5", 440, 136, 0, 2],
					["hub_rock_moss_1", 420, 150, 14, 3], ["hub_vine_1", 150, 150, 0, 2],
					# (round two) a fairy ring of toadstools round the stones, ferns and foxgloves behind them,
					# old giants' roots at the back of the clearing (nobody walks behind them)
					["hub_shroom_0", 396, 214, 0, 1], ["hub_shroom_3", 392, 228, 0, 1], ["hub_shroom_2", 381, 240, 0, 1], ["hub_shroom_4", 363, 250, 0, 1], ["hub_shroom_1", 340, 258, 0, 1], ["hub_shroom_3", 314, 262, 0, 1],
					["hub_shroom_2", 286, 262, 0, 1], ["hub_shroom_4", 260, 258, 0, 1], ["hub_shroom_0", 237, 250, 0, 1], ["hub_shroom_3", 219, 240, 0, 1], ["hub_shroom_2", 208, 228, 0, 1], ["hub_shroom_2", 237, 178, 0, 1],
					["hub_shroom_4", 260, 170, 0, 1], ["hub_shroom_2", 340, 170, 0, 1], ["hub_shroom_4", 363, 178, 0, 1], ["hub_shroom_1", 381, 188, 0, 1], ["hub_shroom_3", 392, 200, 0, 1],
					["hub_vplant_7", 226, 160, 0, 1], ["hub_vplant_8", 236, 164, 0, 1], ["hub_vplant_1", 370, 158, 0, 1], ["hub_plant_3", 384, 162, 0, 1],
					["hub_froots_2", 300, 116, 24, 2], ["hub_ftrunk_2", 300, 116, 0, -102], ["hub_fleaf_g_3", 214, 118, 0, 2], ["hub_fleaf_o_2", 392, 120, 0, 2],
					# (round two's fixer) two big trees inside the clearing's back corners frame the ring, and a
					# fallen log with stumps to sit on in the open west half (nobody is hidden behind them)
					["hub_tree_green_2", 166, 122, 10, 6], ["hub_tree_teal_2", 416, 122, 10, 6],
					["hub_slog", 132, 256, 0, 1], ["hub_sround", 160, 266, 5, 1], ["hub_stump_1", 104, 262, 6, 3]],
				"paths": [[Vector2(-10, 196), Vector2(160, 200), Vector2(270, 206)]],
				"scatter": {"hub_tuft": [24, 60], "hub_flower": [26, 50], "hub_pebble": [20, 8], "hub_twig": [10, 8]},
				"forest": {"top_gaps": [], "behind": [], "open": [Rect2(-30, 140, 70, 120)]},
				"exits": [{"rect": Rect2(26, 168, 10, 60), "to": "elfwood", "at": Vector2(588, 198)}],
				"people": [
					{"id": "thessaly", "name": "Thessaly", "title": "Warden of the Wood", "sprite": "pc_elf_ranger", "hands": "pc_hand_elf_23",
						"pos": Vector2(300, 206), "face": -1, "role": "gate", "sites": ["forest"],
						"text": "These stones open the deep wood. Two groves lie beyond, and a champion in each. Free them and the wood will remember you, knight."},
				],
				"lights": [[Vector2(300, 150), Color(0.45, 0.85, 1.0), 1.8, 0.7], [Vector2(250, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4],
					[Vector2(352, 204), Color(0.45, 0.85, 1.0), 0.8, 0.4]],
			}
	if id == "world":
		return _world()
	if id == "dustwatch":
		return _dustwatch()
	if id == "emberfall":
		return _emberfall()
	return {
		"name": "The Village", "camp": 0, "size": Hub.MAP, "outdoor": true, "walk": Hub.WALK, "spawn": Hub.SPAWN,
		"props": Hub.PROPS, "paths": Hub.PATHS, "scatter": Hub.SCATTER, "fire": Hub.FIRE, "grill": Hub.GRILL,
		"forest": {"top_gaps": [Hub.GATE_GAP, Hub.TAVERN_GAP], "behind": Hub.BEHIND_GATE, "open": Hub.OPEN},
		"blocks": Hub.BLOCKS, "exits": Hub.EXITS, "people": Hub.NPCS,
		"lights": [[Hub.FIRE - Vector2(0, 10), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Hub.GRILL - Vector2(0, 10), Color(1.0, 0.7, 0.45), 1.1, 0.5],
			[Vector2(146, 216), Color(0.45, 0.85, 1.0), 1.3, 0.5], [Vector2(360, 88), Color(0.75, 0.6, 1.0), 1.1, 0.4],
			[Vector2(590, 236), Color(1.0, 0.75, 0.5), 0.9, 0.35], [Vector2(124, 140), Color(1.0, 0.8, 0.5), 0.9, 0.45]],
	}


## Where Play puts you: your room at the Hollow Flagon, or by the fire of the camp you last walked into.
static func start() -> Array:
	if Tale.on():
		return [START, Vector2.INF]            # the story: always your room at the Hollow Flagon
	match Save.hub_get("camp"):
		1:
			return ["dustwatch", Vector2(320, 300)]
		2:
			return ["emberfall", Vector2(300, 292)]
	return [START, Vector2.INF]


## The giant map. West: the woods round Hollow Hill. Middle and south-east: the sands. North-east: the
## Cinder Mountains. Everything is in map pixels; the camera shows it at half size.
static func _world() -> Dictionary:
	var trees := ["hub_tree_green_1", "hub_tree_green_2", "hub_tree_teal_2", "hub_tree_green_3", "hub_tree_pink_2", "hub_tree_teal_3", "hub_bush_green_1", "hub_tree_green_2"]
	var elf := ["hub_tree_teal_1", "hub_tree_pink_1", "hub_tree_teal_2", "hub_tree_pink_2", "hub_bloom_0", "hub_tree_teal_3", "hub_rune_2"]
	# (round two: no broken sandstone stubs among them: spread evenly they read as rows of gravestones)
	var dry := ["hub_cactus_4", "hub_cactus_3", "hub_dbush_0", "hub_dbush_1", "hub_dshrub", "hub_cactus_2", "hub_dtree_1", "hub_dbush_2", "hub_dshrub", "hub_tusk_2", "hub_cactus_0", "hub_dtree_0"]
	var crag := ["hub_rock_2", "hub_rock_1", "hub_dtree_0", "hub_rock_0", "hub_rock_3", "hub_dtree_1", "hub_stone_2", "hub_rock_2"]
	return {
		"name": "The Wide World", "size": Vector2(2000, 1120), "outdoor": true, "walk": Rect2(40, 70, 1920, 1010), "spawn": Vector2(300, 650),
		"zoom": 0.5, "hero_scale": 2.0, "speed": 2.5, "tint": Color(0.86, 0.90, 0.94),
		"regions": [
			["hub_sand", [Vector2(880, -80), Vector2(920, 140), Vector2(850, 320), Vector2(910, 480), Vector2(840, 660), Vector2(890, 840), Vector2(830, 1010), Vector2(870, 1200),
				Vector2(2080, 1200), Vector2(2080, -80)]],
			["hub_drock", [Vector2(1330, -80), Vector2(1310, 110), Vector2(1390, 240), Vector2(1400, 380), Vector2(1500, 450), Vector2(1640, 410), Vector2(1770, 460),
				Vector2(1900, 420), Vector2(2080, 460), Vector2(2080, -80)]],
		],
		"paths": [
			[Vector2(300, 610), Vector2(310, 660), Vector2(480, 676), Vector2(720, 668), Vector2(860, 660)],
		],
		"trails": [      # on sand and rock a road is a line of small stones
			[Vector2(900, 660), Vector2(1120, 660)], [Vector2(1140, 680), Vector2(1190, 800), Vector2(1250, 930)],
			[Vector2(1150, 640), Vector2(1340, 580), Vector2(1570, 540)], [Vector2(1590, 480), Vector2(1650, 370), Vector2(1780, 300)],
			[Vector2(1150, 670), Vector2(1400, 770), Vector2(1650, 890)],
		],
		"scatter": {"hub_tuft": [24, 150], "hub_flower": [26, 90], "hub_pebble": [20, 26], "hub_twig": [10, 20], "hub_gflower": [32, 140], "hub_gtuft": [4, 120]},
		"scatter_rect": Rect2(20, 60, 800, 1040),
		"groves": [
			{"rect": Rect2(40, 70, 760, 420), "ids": trees, "n": 46, "solid": 7.0},
			{"rect": Rect2(420, 110, 360, 330), "ids": elf, "n": 30, "solid": 7.0},
			{"rect": Rect2(40, 740, 760, 330), "ids": trees, "n": 42, "solid": 7.0},
			# the Sands: (round two) clumps of desert growth with open sand between them, not one even spread
			{"rect": Rect2(950, 80, 160, 150), "ids": dry, "n": 9, "solid": 6.0}, {"rect": Rect2(1120, 300, 160, 170), "ids": dry, "n": 9, "solid": 6.0},
			{"rect": Rect2(950, 730, 190, 150), "ids": dry, "n": 9, "solid": 6.0}, {"rect": Rect2(1320, 960, 240, 110), "ids": dry, "n": 9, "solid": 6.0},
			{"rect": Rect2(1440, 700, 170, 120), "ids": dry, "n": 7, "solid": 6.0}, {"rect": Rect2(1760, 900, 180, 170), "ids": dry, "n": 9, "solid": 6.0},
			{"rect": Rect2(1320, 590, 160, 110), "ids": dry, "n": 6, "solid": 6.0}, {"rect": Rect2(1720, 520, 220, 170), "ids": dry, "n": 9, "solid": 6.0},
			{"rect": Rect2(940, 70, 1000, 1000), "ids": ["hub_dgrass_0", "hub_dgrass_1", "hub_dgrass_2", "hub_dgrass_3", "hub_dblock_2", "hub_dblock_3"], "n": 150, "solid": 0.0, "poly": 0},
			{"rect": Rect2(1420, 70, 520, 300), "ids": crag, "n": 34, "solid": 7.0},
			# v0.24.0: meadows of ferns, blooms and toadstools between the woods of the west
			{"rect": Rect2(40, 480, 800, 300), "ids": ["hub_plant_3", "hub_bloom_1", "hub_plant_4", "hub_shroom_0", "hub_bloom_2", "hub_plant_1", "hub_bush_orange_1", "hub_shroom_3"], "n": 40, "solid": 0.0},
		],
		"props": [
			# Hollow Hill: the crypt gate in its rocks, the tavern below it
			["hub_rock_2", 258, 548, 0, 2], ["hub_rock_moss_2", 344, 549, 0, 2], ["hub_gate_0", 300, 552, 0, 0],
			["hub_wall_plaster", 196, 620, 0, 0], ["hub_roof_wood", 196, 621, 0, -50], ["hub_doorway", 196, 622, 0, 0],
			["hub_rune_1", 400, 612, 10, 3], ["hub_rune_0", 428, 632, 8, 3],
			# v0.24.0: the tavern's yard: a clipped hedge, lamps along the road east, busts of the old kings by the gate
			["hub_ghedge", 150, 640, 0, 0], ["hub_ghedge", 240, 640, 0, 0], ["hub_post", 330, 670, 3, 0], ["hub_post", 540, 690, 3, 0],
			["hub_cbust_0", 248, 584, 5, 1], ["hub_cbust_4", 352, 584, 5, 1],
			["hub_gflower_0", 172, 648, 0, 0], ["hub_gflower_12", 182, 650, 0, 0], ["hub_gflower_24", 218, 648, 0, 0], ["hub_gflower_17", 226, 652, 0, 0],
			# the Robber Road: a barricade of stumps and a scarecrow in stolen mail
			["hub_farm_2", 700, 640, 5, 1], ["hub_stump_0", 742, 650, 10, 4], ["hub_stump_1", 690, 690, 7, 3], ["hub_bench_long", 752, 694, 10, 2],
			# Dustwatch: two obelisks either side of the dig
			["hub_obelisk_0", 1076, 634, 12, 2], ["hub_obelisk_1", 1166, 634, 12, 2], ["hub_dstairs", 1120, 628, 0, 0], ["hub_dpot_0", 1090, 650, 0, 1], ["hub_dchest", 1152, 652, 0, 1],
			# the Bone Dunes
			["hub_tusk_0", 1206, 912, 10, 3], ["hub_tusk_1", 1296, 904, 8, 3], ["hub_tusk_2", 1262, 880, 6, 2], ["hub_tusk_1", 1180, 950, 8, 3],
			# the Cinder Pass: a cave mouth where the sand meets the rock
			["hub_dcave", 1570, 520, 0, 0], ["hub_dboulder_0", 1516, 524, 14, 2], ["hub_dboulder_1", 1622, 522, 10, 2],
			# Emberfall: the forge arch and its makers in stone
			["hub_farch", 1780, 268, 0, 0], ["hub_fbust", 1736, 274, 9, 2], ["hub_fbroken", 1824, 274, 9, 2], ["hub_fbarrel_1", 1716, 290, 0, 1], ["hub_fcrate_1", 1846, 292, 0, 1],
			# the Sunken Archive
			["hub_ddoor", 1650, 862, 0, 0], ["hub_dpillar_0", 1606, 868, 6, 2], ["hub_dpillar_2", 1694, 868, 6, 2], ["hub_dpillar_3", 1590, 884, 5, 2], ["hub_dpillar_1", 1716, 890, 6, 2],
			["hub_dstone_0", 1740, 850, 9, 2],
		],
		"decals": [["hub_flava", 1690, 330], ["hub_flava", 1870, 330], ["hub_drockbed", 1570, 470], ["hub_drockbed", 1500, 500], ["hub_drockbed", 1640, 490]],
		"shades": [Rect2(1764, 206, 32, 60)],
		"blocks": [Rect2(268, 500, 64, 50), Rect2(132, 566, 128, 54), Rect2(1088, 580, 64, 48), Rect2(1540, 462, 60, 56), Rect2(1756, 196, 48, 70), Rect2(1618, 816, 64, 44),
			Rect2(1666, 306, 48, 48), Rect2(1846, 306, 48, 48)],
		"exits": [
			{"rect": Rect2(270, 552, 60, 40), "to": "village", "at": Vector2(360, 400)},
			{"rect": Rect2(1094, 628, 52, 18), "to": "dustwatch", "at": Vector2(320, 366), "need": "road",
				"why": "Robbers hold the road east. Clear the Robber Road first."},
			{"rect": Rect2(1756, 266, 48, 18), "to": "emberfall", "at": Vector2(300, 350), "need": "pass",
				"why": "Nobody gets through the Cinder Pass alive. Clear it first."},
		],
		"signs": [
			{"text": "Hollow Hill", "pos": Vector2(300, 470), "sites": ["hill", "deep"]},
			{"text": "The Elfwood", "pos": Vector2(600, 130)},
			{"text": "The Robber Road", "pos": Vector2(720, 590), "sites": ["road"]},
			{"text": "Dustwatch", "pos": Vector2(1120, 490), "need": "road", "sites": ["dust"]},
			{"text": "The Bone Dunes", "pos": Vector2(1250, 826), "sites": ["dunes"]},
			{"text": "The Cinder Pass", "pos": Vector2(1570, 436), "sites": ["pass"]},
			{"text": "Emberfall", "pos": Vector2(1780, 170), "need": "pass", "sites": ["ember"]},
			{"text": "The Sunken Archive", "pos": Vector2(1650, 790), "sites": ["archive"]},
		],
		"people": [
			{"id": "site_road", "name": "The Robber Road", "title": "A barricade across the east road", "ghost": true, "pos": Vector2(720, 668), "top": 30, "role": "gate", "sites": ["road"],
				"text": "A barricade of stumps across the east road. Beyond it the woods are full of robbers, and somewhere among them the one they call the Road King."},
			{"id": "site_dunes", "name": "The Bone Dunes", "title": "Tusks in the sand", "ghost": true, "pos": Vector2(1250, 934), "top": 30, "role": "gate", "sites": ["dunes"],
				"text": "Great tusks stand out of the sand, and between them shapes that were people once. Whatever made them is still in there."},
			{"id": "site_pass", "name": "The Cinder Pass", "title": "A way under the mountain", "ghost": true, "pos": Vector2(1570, 544), "top": 30, "role": "gate", "sites": ["pass"],
				"text": "The old mine road runs under the mountain here. Warm air comes out of it, and the slow sound of something heavy walking."},
			{"id": "site_archive", "name": "The Sunken Archive", "title": "A door half under the sand", "ghost": true, "pos": Vector2(1650, 884), "top": 30, "role": "gate", "sites": ["archive"],
				"text": "A sandstone door, half buried. The orders kept their writings here. Something inside is still keeping them."},
			{"id": "site_elfwood", "name": "The Elfwood", "title": "", "ghost": true, "pos": Vector2(600, 470), "top": 30, "role": "chat",
				"text": "The Elfwood. The road into it leaves the village by its east side."},
		],
		"torches": [Vector2(330, 670), Vector2(540, 690)],
		"lights": [[Vector2(330, 630), Color(1.0, 0.78, 0.46), 1.4, 0.55], [Vector2(540, 650), Color(1.0, 0.78, 0.46), 1.4, 0.55],
			[Vector2(300, 600), Color(1.0, 0.8, 0.5), 2.2, 0.5], [Vector2(1120, 640), Color(1.0, 0.8, 0.5), 2.2, 0.5], [Vector2(1780, 280), Color(1.0, 0.55, 0.3), 2.6, 0.7],
			[Vector2(1690, 330), Color(1.0, 0.5, 0.2), 1.6, 0.8], [Vector2(1870, 330), Color(1.0, 0.5, 0.2), 1.6, 0.8], [Vector2(414, 610), Color(0.45, 0.85, 1.0), 1.4, 0.5]],
	}


## Dustwatch: the diggers' camp in the eastern sands, over the stair down to the Warrens. Since the
## set dressing it is a real town of the Sands, all of it the purchased Desert, Hideout and Free pieces:
##   the street         (round two) four flat-roofed sandstone houses INSIDE the wall (house rows
##                      with "style": "sand", scripts/hub/arch/house.gd): two low shops either side of
##                      the cistern gate, two tall ones brought forward either side of the plaza so it
##                      is enclosed; shop awnings, hanging signs, their goods at the doors
##   the plaza          a dais of sandstone paving, a step up all round, a flight of steps at the front
##   Nib's stall        on the east side of the plaza, pots and a chest of things the sand gave up
##   Grukk's smithy     the anvil, a work table, the forge's barrels and a crate
##   the caravan camp   bedrolls round a cook fire in the south-west corner
##   the yard           crates, barrels and sacks stacked in the south-east corner
##   lanterns           lanterns on arms at the plaza's corners and by the houses (warm pools at night)
##   bunting            pennants from tower to tower over the cistern door, and across the street
##   the near edge      cacti and a dead tree past the low wall, between the camera and the town
static func _dustwatch() -> Dictionary:
	var warm := Color(1.0, 0.74, 0.44)
	var lanterns := [[Vector2(204, 346), false], [Vector2(428, 346), false], [Vector2(150, 252), false], [Vector2(612, 250), true]]
	var props: Array = [
		["hub_ddoor", 320, 152, 0, 0], ["hub_dstairs", 320, 200, 0, 0],
		["hub_obelisk_0", 132, 196, 12, 2], ["hub_obelisk_1", 504, 196, 12, 2], ["hub_obelisk_2", 606, 336, 12, 2],
		["hub_dpillar_0", 262, 204, 6, 2], ["hub_dpillar_1", 378, 204, 6, 2],
		["hub_dpot_1", 118, 312, 4, 1], ["hub_dpot_0", 102, 318, 5, 1],
		["hub_anvil_0", 160, 300, 16, 4], ["hub_dstone_2", 50, 264, 10, 2],
		["hub_dbush_1", 566, 366, 8, 3], ["hub_tusk_2", 600, 290, 6, 2],
		# (no lone sandstone blocks standing about in the open: they read as dropped sponges)
		# the street's shops (the houses are in "houses"): goods at their doors and under their awnings
		["hub_dpot_0", 196, 158, 0, 0], ["hub_dpot_1", 206, 160, 0, 0], ["hub_spot", 214, 157, 0, 0], ["hub_sjug", 152, 158, 0, 0],
		["hub_sbarrel_f", 222, 162, 4, 1],
		["hub_ssack_0", 422, 158, 0, 0], ["hub_ssack_1", 434, 159, 0, 0], ["hub_sveg_6", 444, 158, 0, 0], ["hub_scrate_3", 486, 160, 4, 1],
		["hub_sveg_3", 48, 244, 0, 0], ["hub_sveg_1", 62, 246, 0, 0], ["hub_ssack_3", 76, 244, 0, 0], ["hub_sbarrel_f", 40, 250, 4, 1],
		["hub_sjug", 578, 244, 0, 0], ["hub_sbucket", 590, 245, 0, 0], ["hub_spot", 600, 243, 0, 0], ["hub_ssack_4", 524, 246, 0, 0],
		# Nib's stall: pots and a jug on the counter, his chest beside it
		["hub_dpot_1", 472, 265, 0, -12], ["hub_dpot_0", 486, 265, 0, -12], ["hub_sjug", 500, 265, 0, -12], ["hub_dchest", 532, 274, 10, 2],
		# Grukk's smithy: the forge's barrels and a crate
		["hub_fbarrel_0", 120, 286, 5, 1], ["hub_fbarrel_1", 134, 280, 5, 1], ["hub_fcrate_1", 104, 298, 8, 2],
		# the caravan camp: sacks and a crate by the bedrolls
		["hub_ssack_2", 56, 344, 0, 1], ["hub_ssack_4", 70, 340, 0, 1], ["hub_scrate_2", 186, 356, 4, 1], ["hub_strough", 176, 384, 6, 1],
		# the yard: crates, barrels and sacks
		["hub_scrate_4", 456, 362, 5, 1], ["hub_scrate_5", 472, 358, 5, 1], ["hub_sbarrel_1", 498, 368, 8, 1], ["hub_ssack_2", 482, 374, 0, 1],
		["hub_scrate_0", 520, 372, 4, 1],
		# on the dais: cushions round the fire, urns at its front corners
		["hub_scush", 338, 312, 0, 0], ["hub_scush", 302, 266, 0, 0], ["hub_dpot_1", 234, 328, 4, 0], ["hub_dpot_0", 406, 328, 4, 0],
		# the near edge: past the low wall, nearer the camera than anyone
		["hub_cactus_4", 110, 470, 0, 2], ["hub_dtree_0", 596, 520, 0, 2], ["hub_cactus_2", 470, 466, 0, 2], ["hub_dbush_0", 170, 506, 0, 3],
	]
	var lights: Array = [[Vector2(320, 276), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Vector2(320, 150), Color(0.45, 0.75, 1.0), 1.2, 0.4],
		[Vector2(150, 348), Color(1.0, 0.68, 0.40), 1.4, 0.6]]                    # the caravan's cook fire
	for row: Array in lanterns:
		var at: Vector2 = row[0]
		props.append(["hub_slantern", at.x, at.y, 0, 0, row[1]])
		lights.append([at + Vector2(-LANTERN_GLASS.x if row[1] else LANTERN_GLASS.x, LANTERN_GLASS.y), warm, 1.1, 0.55])
	for at: Vector2 in [Vector2(184, 160), Vector2(452, 160)]:
		lights.append([at, warm, 0.7, 0.45])                                      # a lamp under each low shop's awning
	# THE HOUSES OF THE STREET (round two): sandstone, flat roofs behind a parapet ("style": "sand")
	var sand := {"style": "sand", "wall": "hub_bsandwall", "wall_h": 38.0, "flat_roof": "hub_bsandcap", "door": "hub_doorway",
		"windows": "hub_win_closed", "win_up": 10.0, "shop_roof": "hub_roof_planks"}
	var houses: Array = []
	for row: Dictionary in [
			{"at": Vector2(86, 236), "wide": 104.0, "deep": 84.0, "floors": 2, "door_dx": 26.0, "win_xs": [-24.0], "up_xs": [-30.0, 0.0, 30.0],
				"shop": "wide", "sign": "hub_sjug", "sign_side": 1.0},
			{"at": Vector2(184, 150), "wide": 76.0, "deep": 46.0, "floors": 1, "door_dx": -16.0, "win_xs": [18.0], "shop": "wide", "sign": "hub_dpot_1", "sign_side": -1.0},
			{"at": Vector2(452, 150), "wide": 76.0, "deep": 46.0, "floors": 1, "door_dx": 16.0, "win_xs": [-18.0], "shop": "wide",
				"shop_roof": "hub_roof_tiles", "sign": "hub_cshield", "sign_side": 1.0},
			{"at": Vector2(564, 236), "wide": 92.0, "deep": 84.0, "floors": 2, "door_dx": -22.0, "win_xs": [20.0], "up_xs": [-22.0, 22.0], "boxes": true}]:
		var h: Dictionary = sand.duplicate()
		h.merge(row, true)
		houses.append(h)
	return {
		"iron_lamps": true,          # (round three: iron street lamps, as in Wickmere, not lanterns on timber gallows)
		"name": "Dustwatch", "camp": 1, "size": Vector2(640, 430), "outdoor": true, "walk": Rect2(30, 104, 580, 290), "spawn": Vector2(320, 366),
		"ground": "hub_sand", "tint": Color(0.96, 0.88, 0.78), "fire": Vector2(320, 286),
		"floor": [["hub_paving", Rect2(224, 208, 192, 128)]],
		# the plaza is a low dais of the same paving, a step up, with a flight at the front
		"terraces": [{"rect": Rect2(224, 208, 192, 128), "high": 5.0, "steps": [[320.0, 52.0]], "face": "hub_bsandcap", "top": "hub_paving"}],
		"tour": [Vector2(320, 330), Vector2(190, 196), Vector2(470, 196), Vector2(150, 330), Vector2(470, 320)],     # test pictures (--hub=dustwatch --shots)
		"props": props, "houses": houses,
		"stalls": [{"at": Vector2(488, 264), "wide": 56.0, "roof": "hub_roof_tiles"}],
		# (round three) the dais is a place to sit: a sandstone ring round the fire, rugs, cushions, urns
		# at its front corners, a striped canvas shade on poles over the foot of the cistern stair
		"hearths": [{"at": Vector2(320, 288), "rx": 17.0, "rz": 11.0, "high": 4.0}],
		"rugs": [["hub_sbed_0", 282, 262], ["hub_sbed_1", 358, 262], ["hub_sbed_0", 262, 318]],
		"canopies": [{"x0": 272.0, "x1": 368.0, "z0": 210.0, "z1": 228.0, "low": 42.0, "high": 50.0,
			"stripes": [Color(0.95, 0.42, 0.30), Color(1.0, 0.92, 0.80), Color(0.38, 0.62, 0.78), Color(1.0, 0.92, 0.80)]}],
		"bunting": [[Vector2(258, 92), Vector2(382, 92), 64.0, 10.0], [Vector2(222, 152), Vector2(414, 152), 66.0, 14.0]],
		"decals": [["hub_sbed_0", 72, 360], ["hub_sbed_1", 96, 364], ["hub_scush", 122, 374], ["hub_sring", 150, 362],
			["hub_sripple_3", 560, 392], ["hub_sripple_4", 404, 386], ["hub_sripple_2", 232, 392], ["hub_sripple_1", 470, 222]],
		"anims": [["hub_fire_c", 150, 364, 7.0, 9.0, false]],
		"scatter": {"hub_dgrass": [4, 46]},
		"forest": {"top_gaps": [[250.0, 390.0]], "behind": [], "open": [Rect2(250, 390, 140, 90)],
			"big": ["hub_dstone_0", "hub_dtree_0", "hub_dstone_1", "hub_tusk_1", "hub_obelisk_2", "hub_dbush_0"],
			"side": ["hub_cactus_4", "hub_dbush_0", "hub_cactus_3", "hub_dstone_1"],
			"low": ["hub_dshrub", "hub_dbush_2", "hub_cactus_1", "hub_cactus_0", "hub_dstone_2", "hub_dbush_2"],
			"young": ["hub_dtree_1", "hub_cactus_2", "hub_dbush_1"]},
		"blocks": [Rect2(288, 104, 64, 96), Rect2(30, 104, 110, 134), Rect2(144, 104, 82, 48), Rect2(410, 104, 84, 48), Rect2(516, 104, 96, 134),
			Rect2(458, 236, 60, 30), Rect2(56, 350, 80, 22)],
		"exits": [{"rect": Rect2(270, 386, 100, 10), "to": "world", "at": Vector2(1120, 690)}],
		"people": [
			{"id": "sefa", "name": "Captain Sefa", "title": "Keeper of the Cistern Stair", "sprite": "pc_royal_archer", "hands": "pc_hand_castle_17",
				"pos": Vector2(374, 214), "face": -1, "role": "gate", "sites": ["dust"],
				"text": "The cistern stair goes down into the Warrens. When the dunes are quiet, it is yours."},
			{"id": "grukk", "name": "Grukk", "title": "Smith, late of the Warrens", "sprite": "pc_orc_warrior", "hands": "pc_hand_base_9",
				"pos": Vector2(196, 306), "face": 1, "role": "chat", "as": "smith", "text": ""},
			{"id": "nib", "name": "Nib", "title": "Sand Trader", "sprite": "pc_npc_tavern_b", "hands": "pc_hand_base_2",
				"pos": Vector2(430, 276), "face": -1, "role": "shop", "text": "Pots, charms, things the sand gave up. All honest. Mostly honest."},
			{"id": "imre", "name": "Sister Imre", "title": "Reader of Walls", "sprite": "pc_scholar_cataloguer", "hands": "pc_hand_library_6",
				"pos": Vector2(226, 214), "face": 1, "role": "quests", "text": "I keep the camp's list of work. Do it, and your pack will be heavier."},
			{"id": "dustfire", "name": "The camp fire", "title": "A place to rest", "ghost": true, "pos": Vector2(320, 300), "top": 22, "role": "bed", "text": ""},
		],
		"lights": lights,
	}


## Emberfall: what is left of the smiths' town in the Cinder Mountains, at the door of the forge.
static func _emberfall() -> Dictionary:
	return {
		"name": "Emberfall", "camp": 2, "size": Vector2(600, 420), "outdoor": true, "walk": Rect2(30, 104, 540, 280), "spawn": Vector2(300, 350),
		"ground": "hub_drock", "tint": Color(0.80, 0.74, 0.80), "fire": Vector2(300, 276),
		"floor": [["hub_fflag", Rect2(204, 150, 192, 192)]],
		"decals": [["hub_flava", 110, 200], ["hub_flava", 490, 200]],
		"shades": [Rect2(284, 92, 32, 58)],
		"props": [
			["hub_farch", 300, 152, 0, 0], ["hub_fbust", 246, 158, 9, 2], ["hub_fbust", 354, 158, 9, 2], ["hub_fbroken", 430, 176, 9, 2],
			["hub_fbarrel_0", 160, 262, 5, 1], ["hub_fbarrel_1", 176, 268, 5, 1], ["hub_fbarrel_2", 128, 330, 5, 1],
			["hub_fcrate_1", 452, 286, 10, 2], ["hub_fcrate_0", 480, 294, 6, 2], ["hub_fchest", 428, 316, 10, 2],
			["hub_anvil_0", 190, 318, 16, 4], ["hub_bench_1", 150, 300, 12, 3],
			["hub_dtree_1", 70, 360, 5, 2], ["hub_rock_1", 540, 350, 12, 3], ["hub_rock_3", 70, 250, 8, 2],
		],
		"scatter": {"hub_pebble": [20, 30], "hub_dblock": [4, 8]},
		"forest": {"top_gaps": [[236.0, 364.0]], "behind": [], "open": [Rect2(230, 380, 140, 90)],
			"big": ["hub_rock_2", "hub_dtree_0", "hub_rock_1", "hub_fbroken", "hub_rock_moss_2", "hub_dtree_0"],
			"side": ["hub_dtree_1", "hub_rock_0", "hub_rock_2"],
			"low": ["hub_rock_3", "hub_stone_2", "hub_fbarrel_1", "hub_rock_0", "hub_fcrate_0", "hub_stone_1"],
			"young": ["hub_dtree_1"]},
		"blocks": [Rect2(272, 96, 56, 54), Rect2(86, 176, 48, 48), Rect2(466, 176, 48, 48)],
		"exits": [{"rect": Rect2(250, 376, 100, 10), "to": "world", "at": Vector2(1780, 318)}],
		"people": [
			{"id": "bryn", "name": "Forgemaster Bryn", "title": "Keeper of the Forge Door", "sprite": "pc_royal_soldier", "hands": "pc_hand_castle_17",
				"pos": Vector2(346, 196), "face": -1, "role": "gate", "sites": ["ember"],
				"text": "The Iron seal was forged behind this arch. Its makers are still in there."},
			{"id": "kessa", "name": "Old Kessa", "title": "Farrier", "sprite": "pc_npc_tavern_a", "hands": "pc_hand_base_2",
				"pos": Vector2(226, 322), "face": -1, "role": "chat", "as": "smith", "text": ""},
			{"id": "aurel", "name": "Brother Aurel", "title": "Pilgrim", "sprite": "pc_royal_priest", "hands": "pc_hand_castle_17",
				"pos": Vector2(394, 232), "face": -1, "role": "quests", "text": "I keep a list of what needs doing. It is long."},
			{"id": "pell", "name": "Pell", "title": "Scavenger", "sprite": "pc_npc_peasant_a", "hands": "pc_hand_base_2",
				"pos": Vector2(404, 312), "face": 1, "role": "shop", "text": "I sell what the miners left when they ran."},
			{"id": "emberfire", "name": "The brazier", "title": "A place to rest", "ghost": true, "pos": Vector2(300, 290), "top": 22, "role": "bed", "text": ""},
		],
		"lights": [[Vector2(300, 266), Color(1.0, 0.6, 0.35), 2.1, 0.8], [Vector2(110, 200), Color(1.0, 0.5, 0.2), 1.6, 0.9], [Vector2(490, 200), Color(1.0, 0.5, 0.2), 1.6, 0.9],
			[Vector2(300, 130), Color(1.0, 0.45, 0.25), 1.2, 0.6]],
	}


## CHAPTER TWO of the story (scripts/data/tale.gd): the road to Dustwatch opens once the Elfwood
## burns, Dustwatch's people speak for the story, Seraphine waits on its wall, and the cistern
## stair leads down to the Sunwell (Tale.suncourt()). Only while the story is on.
static func _fit_sands(id: String, place: Dictionary) -> void:
	if id == "world":
		for e: Dictionary in place["exits"]:
			if String(e["to"]) == "dustwatch":
				e.erase("need")
				e["tale"] = 7
				e["why"] = "The Sands come after the Elfwood. Captain Hale will send you."
		for sg: Dictionary in place["signs"]:
			if String(sg["text"]) == "Dustwatch":
				sg.erase("need")
		return
	place["tint"] = Color(1.0, 0.92, 0.80) if Tale.lit("sands") else Color(0.72, 0.74, 0.92)
	for row: Dictionary in place["people"]:
		if ["sefa", "nib", "imre"].has(String(row["id"])):
			row["role"] = "chat"
	(place["people"] as Array).append({"id": "sera", "name": "Seraphine", "title": "Sun-mage of the Archive", "sprite": "pc_scholar_censor",
		"hands": "pc_hand_library_6", "pos": Vector2(446, 200), "face": -1, "role": "chat", "text": "", "tale_from": 7, "tale_to": 8})
	(place["exits"] as Array).append({"rect": Rect2(296, 200, 48, 10), "to": "suncourt", "at": Vector2(280, 372), "tale": 9,
		"why": "Nobody goes down the stair tonight. Captain Sefa's orders."})
	if Tale.lit("sands"):
		(place["lights"] as Array).append([Vector2(320, 190), Color(1.0, 0.84, 0.52), 2.2, 0.8])     # the beacon's light up the stair
