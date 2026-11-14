extends RefCounted
## MORE OF THE WORLD (the quality pass, package 07): the registry of MODULES. A module is one file under
## scripts/data/more/ that ADDS places, people's words, scenes, battles, finds and side quests, so a new
## dungeon or town is a new file and nobody has to edit hub.gd, places.gd or tale.gd for it.
## The full contract with examples: docs/pass/07_world_kit.md.
##
## THE RULE (it keeps the scripts from loading each other in a circle): a module NEVER preloads tale.gd,
## places.gd, battles.gd, errands.gd or more.gd. It reads the story from the save:
##     Save.hub_get("tale:step")          where the story stands
##     Save.hub_get("tale:lit:<land>")    1 = that beacon burns   (elfwood, sands, cinder, archive)
##     Save.hub_get("dkey:<id>")  Save.hub_get("dlever:<id>")  Save.hub_get("find:<id>")  any flag it set
##
## A module is loaded with load() only if its file exists (so the list below may name files that a later
## package brings), and each function is used only if the module has it. All are static, all optional:
##     on() -> bool              false = leave this module out (kit_test.gd: only when asked for)
##     places() -> Array         the place ids it builds
##     build(id) -> Dictionary   one of those places (the format of scripts/data/places.gd)
##     fit(id, place)            called for EVERY place of the game after it is built: change it in place
##                               (add an exit to your dungeon, a person, a sign ...)
##     talk() -> Dictionary      {person id: rows}     as tale.gd TALK     (asked first, then tale.gd)
##     scenes() -> Array         rows as tale.gd SCENES
##     battles() -> Dictionary   {id: row} as tale.gd BATTLES              bosses() the same for BOSSES
##     enter() -> Dictionary     {place id: {step: do}} as tale.gd ENTER
##     finds() -> Array          rows as errands.gd FINDS                  errands() as ERRANDS
##     stops() -> Array          rows as travel.gd STOPS (a light to travel to)
## talk / scenes / battles / bosses / enter / finds / errands / stops are asked ONCE and kept: they are tables. What
## changes with the story is written with "from" / "to" / "flag_on" / "flag_off", or done in build() / fit().

const DIR := "res://scripts/data/more/"
const MODULES := ["kit_test.gd", "archive.gd", "dungeons.gd", "towns.gd", "underhill.gd"]

static var _mods: Array = []          ## [{"script": GDScript, "has": {function name: true}}]
static var _done := false
static var _owner := {}               ## place id -> index into _mods
static var _kept := {}                ## table name -> merged table


static func _load() -> void:
	if _done:
		return
	_done = true
	for file: String in MODULES:
		var path := DIR + file
		if not ResourceLoader.exists(path):
			continue
		var script: Variant = load(path)
		if not (script is Script):
			continue
		var fns := {}
		for m: Dictionary in (script as Script).get_script_method_list():
			fns[String(m["name"])] = true
		if fns.has("on") and not bool(script.call("on")):
			continue
		_mods.append({"script": script, "has": fns})
		if fns.has("places"):
			for id: Variant in script.call("places"):
				if not _owner.has(String(id)):
					_owner[String(id)] = _mods.size() - 1


## Test help: forget everything (a test that changes what on() says).
static func reload() -> void:
	_mods.clear()
	_owner.clear()
	_kept.clear()
	_done = false


## Every module's answer to one of the table functions, in MODULES order.
static func _each(fn: String) -> Array:
	_load()
	var out: Array = []
	for m: Dictionary in _mods:
		if (m["has"] as Dictionary).has(fn):
			out.append(m["script"].call(fn))
	return out


static func _dict(fn: String) -> Dictionary:
	if not _kept.has(fn):
		var all := {}
		for part: Variant in _each(fn):
			if part is Dictionary:
				for k: Variant in part:
					if fn == "enter" and all.has(k):
						(all[k] as Dictionary).merge(part[k])        # two modules, one place: both count
					elif not all.has(k):
						all[k] = (part[k] as Dictionary).duplicate() if fn == "enter" else part[k]
		_kept[fn] = all
	return _kept[fn]


static func _list(fn: String) -> Array:
	if not _kept.has(fn):
		var all: Array = []
		for part: Variant in _each(fn):
			if part is Array:
				all.append_array(part)
		_kept[fn] = all
	return _kept[fn]


# ------------------------------------------------------------------ places
## Does a module build this place?
static func has(id: String) -> bool:
	_load()
	return _owner.has(id)


## Every place id the modules build.
static func ids() -> Array:
	_load()
	return _owner.keys()


static func build(id: String) -> Dictionary:
	_load()
	if not _owner.has(id):
		return {}
	var m: Dictionary = _mods[int(_owner[id])]
	if not (m["has"] as Dictionary).has("build"):
		return {}
	var place: Variant = m["script"].call("build", id)
	return place if place is Dictionary else {}


## Every module may change every place (in MODULES order).
static func fit(id: String, place: Dictionary) -> void:
	_load()
	for m: Dictionary in _mods:
		if (m["has"] as Dictionary).has("fit"):
			m["script"].call("fit", id, place)


# ------------------------------------------------------------------ the story's tables
## The rows of words of this person (as tale.gd TALK), [] = the modules say nothing about them.
static func talk(npc_id: String) -> Array:
	return _dict("talk").get(npc_id, [])


static func scenes() -> Array:
	return _list("scenes")


## A battle row (as tale.gd BATTLES), {} = not a module's battle.
static func battle(id: String) -> Dictionary:
	return _dict("battles").get(id, {})


static func boss(id: String) -> Dictionary:
	return _dict("bosses").get(id, {})


## {step: do} for walking into this place (as tale.gd ENTER).
static func enter(place_id: String) -> Dictionary:
	return _dict("enter").get(place_id, {})


static func finds() -> Array:
	return _list("finds")


static func errands() -> Array:
	return _list("errands")


static func stops() -> Array:
	return _list("stops")
