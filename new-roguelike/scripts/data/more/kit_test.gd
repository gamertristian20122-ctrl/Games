extends RefCounted
## THE KIT'S PROOF PLACE (the quality pass, package 07): a small yard that uses every piece of the world kit
## once, so one headless run proves they work and can all be reached:
##     godot --headless --path . -- --hub=kit_test --allfinds --nosave --time=8
## It is also the smallest example of a MODULE (scripts/data/more.gd; docs/pass/07_world_kit.md).
## It is only part of the game when asked for (--hub=kit_test or --kit), so its chests never show in
## a player's journal. Words are test words.
##
## The yard: a wall across the middle with two gates. South (the way in): a sign to read, a chest with
## the brass key, a camp fire to rest at, a thing that only lies there by night, a guard that comes for
## the knight. The left gate opens with the key: behind it a lever. The lever opens the right gate:
## behind that a locked chest (the same key) and a light to travel from.

const ID := "kit_test"


static func on() -> bool:
	return G.arg("hub") == ID or G.flag("kit")


static func places() -> Array:
	return [ID]


static func build(_id: String) -> Dictionary:
	var props: Array = []
	for x: int in [40, 58, 76, 94, 112, 168, 186, 204, 222, 240, 258, 276, 294, 312, 368, 386, 404, 422, 440]:
		props.append(["hub_rock_moss_%d" % (x % 3), x, 206, 0, 2])              # the wall across the yard (the blocks stop him)
	for y: int in [124, 142, 160, 178]:
		props.append(["hub_rock_%d" % (y % 3), 240, y, 0, 2])                   # the wall between the two back rooms
	props.append_array([["hub_bush_green_1", 60, 130, 6, 3], ["hub_bush_deep_1", 440, 280, 6, 3]])
	return {
		"name": "The Test Yard", "size": Vector2(480, 330), "outdoor": true, "walk": Rect2(30, 108, 420, 190), "spawn": Vector2(60, 240),
		"pass": true,                                    # (never where Play starts)
		"tint": Color(0.98, 0.95, 0.88),
		"props": props,
		"blocks": [Rect2(30, 194, 88, 12), Rect2(162, 194, 156, 12), Rect2(362, 194, 88, 12), Rect2(234, 108, 12, 86)],
		# DOORS: the left gate wants the brass key, the right one the lever
		"doors": [
			{"id": "kit_key", "rect": Rect2(118, 194, 44, 12), "key": "kit", "why": "A barred gate. The lock is brass."},
			{"id": "kit_lever", "rect": Rect2(318, 194, 44, 12), "lever": "kit", "why": "A barred gate with no lock at all."},
		],
		# LEVERS
		"levers": [{"id": "kit", "pos": Vector2(180, 150), "name": "A rusted lever", "say": "The lever grinds down. The other gate rattles open."}],
		# FOES: a guard that comes for the knight and starts the battle "kit_guard" (battles() below)
		"foes": [{"id": "guard", "enemy": "thorn_elf", "pos": Vector2(400, 262), "leash": 56.0, "battle": "kit_guard"}],
		"fire": Vector2(250, 258),
		"paths": [[Vector2(30, 240), Vector2(140, 240)], [Vector2(140, 240), Vector2(140, 150)], [Vector2(140, 240), Vector2(340, 240)], [Vector2(340, 240), Vector2(340, 150)]],
		"scatter": {"hub_tuft": [24, 30], "hub_flower": [26, 12], "hub_pebble": [20, 10]},
		"forest": {"top_gaps": [], "behind": [], "open": [],
			"low": ["hub_bush_deep_0", "hub_bush_green_1", "hub_bush_deep_1", "hub_bush_green_0"]},
		"exits": [],
		"people": [
			# READ: a sign (role "read": its pages in the talk box, no face)
			{"id": "kit_sign", "name": "A weathered sign", "title": "", "ghost": true, "pos": Vector2(96, 232), "role": "read", "prop": "hub_ssign", "solid": 3.0,
				"pages": ["THE TEST YARD. Key in the chest, lever behind the left gate, light behind the right.", "Mind the guard."]},
			# REST: a fire with the role "bed" (a lost fight wakes him at the last one he walked past)
			{"id": "kit_fire", "name": "The camp fire", "title": "A place to rest", "ghost": true, "pos": Vector2(250, 272), "top": 22, "role": "bed", "text": ""},
		],
		"lights": [[Vector2(250, 248), Color(1.0, 0.72, 0.42), 1.6, 0.6], [Vector2(400, 140), Color(1.0, 0.86, 0.55), 1.4, 0.5]],
	}


## fit(): every place of the game passes through here after it is built. A real module adds its doorway
## to an old place like this (here: nothing, the yard is only reached with --hub=kit_test).
static func fit(_id: String, _place: Dictionary) -> void:
	pass


static func finds() -> Array:
	return [
		{"id": "kit_keychest", "place": ID, "pos": Vector2(56, 284), "sprite": "hub_fchest", "name": "A small chest",
			"reward": {"key": "kit", "key_name": "a brass key"}},
		{"id": "kit_locked", "place": ID, "pos": Vector2(424, 130), "sprite": "hub_dchest", "name": "A locked chest", "locked": "kit",
			"why": "Locked. The keyhole is brass.", "reward": {"coins": 10}},
		{"id": "kit_night", "place": ID, "pos": Vector2(190, 284), "sprite": "hub_shroom_3", "name": "A night-cap", "night": true, "kept": false,
			"say": "A pale mushroom that was not here by day.", "reward": {"supply": {"herb": 1}}},
	]


static func battles() -> Dictionary:
	return {"kit_guard": {"title": "The guard of the yard", "look": "forest_night", "tier": 0, "foes": ["thorn_elf", "sporeling"],
		"win": {"flag": "kit:guard", "say": "The guard of the yard falls"}}}


static func scenes() -> Array:
	return [{"id": "kit_arrive", "place": ID, "from": 0, "name": "The Test Yard", "title": "", "sprite": "", "pages": ["A yard built to try every lock, lever and light."]}]


static func enter() -> Dictionary:
	return {ID: {0: {"flag": "kit:entered"}}}


static func stops() -> Array:
	return [{"id": "kit", "land": "", "place": ID, "at": Vector2(400, 166), "name": "The test light", "person": "kit_light",
		"add": {"id": "kit_light", "name": "A standing light", "title": "", "ghost": true, "pos": Vector2(400, 150), "role": "chat", "prop": "hub_rune_2", "solid": 5.0,
			"text": "A rune stone with a steady light in it."}}]
