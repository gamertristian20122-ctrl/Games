extends RefCounted
## Data checker: looks through every data table for typos (a sprite that does not exist, an AI
## file that is missing, a broken room layout ...). Run it with:
##   godot --headless --path . res://dev/world_test.tscn -- --validate
## tools/check.sh runs it before the bot tests.

const Layouts = preload("res://scripts/data/room_layouts.gd")
const Items = preload("res://scripts/data/items.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Familiars = preload("res://scripts/data/familiars.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const Floors = preload("res://scripts/data/floors.gd")
const ShotTypes = preload("res://scripts/data/shot_types.gd")
const Stats = preload("res://scripts/run/stats.gd")

const POOLS := ["treasure", "boss", "shop", "secret", "cursed"]


## Loads every script of the world half so typos show up at once (flag --checkscripts).
static func check_scripts(folders: Array = ["res://scripts/run", "res://scripts/entities", "res://scripts/data", "res://dev"]) -> Array[String]:
	var out: Array[String] = []
	var todo: Array = folders.duplicate()
	while not todo.is_empty():
		var folder: String = todo.pop_back()
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for sub in dir.get_directories():
			todo.append(folder.path_join(sub))
		for f in dir.get_files():
			if f.get_extension() != "gd":
				continue
			var script: GDScript = load(folder.path_join(f))
			if script == null or not script.can_instantiate():
				out.append("script does not compile: " + folder.path_join(f))
	return out


static func all() -> Array[String]:
	var out: Array[String] = Layouts.all_problems()
	for kind in ["start", "treasure", "shop", "secret", "boss", "combat"]:
		if Layouts.pick_list(kind).is_empty():
			out.append("no room layout of kind '%s'" % kind)
	# ---- items
	var pool_sizes := {}
	for id: String in Items.ALL:
		var it: Dictionary = Items.ALL[id]
		for field in ["name", "desc", "icon", "cursed", "pools"]:
			if not it.has(field):
				out.append("item %s: missing '%s'" % [id, field])
		if not Art.has(String(it.get("icon", ""))):
			out.append("item %s: icon '%s' is not a sprite" % [id, it.get("icon", "")])
		if it.get("cursed", false) and String(it.get("curse", "")) == "":
			out.append("item %s: cursed items need a 'curse' line" % id)
		for pool in it.get("pools", []):
			if not POOLS.has(pool):
				out.append("item %s: unknown pool '%s'" % [id, pool])
			pool_sizes[pool] = int(pool_sizes.get(pool, 0)) + 1
		var mods: Dictionary = it.get("mods", {})
		for part in ["flat", "pct", "mult"]:
			for stat in mods.get(part, {}):
				if not Stats.DEFAULTS.has(stat):
					out.append("item %s: unknown stat '%s'" % [id, stat])
		if it.has("familiar") and not Familiars.ALL.has(it["familiar"]):
			out.append("item %s: unknown familiar '%s'" % [id, it["familiar"]])
	for pool in POOLS:
		if int(pool_sizes.get(pool, 0)) == 0:
			out.append("item pool '%s' is empty" % pool)
	# ---- heroes
	for h: Dictionary in Heroes.LIST:
		for field in ["sprite", "weapon"]:
			if not Art.has(String(h.get(field, ""))):
				out.append("hero %s: %s '%s' is not a sprite" % [h["id"], field, h.get(field, "")])
		if not ShotTypes.ALL.has(h.get("shot", "blade")):
			out.append("hero %s: unknown shot type '%s'" % [h["id"], h.get("shot", "")])
		if h.has("familiar") and not Familiars.ALL.has(h["familiar"]):
			out.append("hero %s: unknown familiar '%s'" % [h["id"], h["familiar"]])
	# ---- enemies, bosses, familiars
	for id: String in Enemies.ALL:
		var e: Dictionary = Enemies.ALL[id]
		if not Art.has(String(e["sprite"])):
			out.append("enemy %s: sprite '%s' does not exist" % [id, e["sprite"]])
		if not ResourceLoader.exists("res://scripts/entities/ai/%s.gd" % e["ai"]):
			out.append("enemy %s: no AI file '%s.gd'" % [id, e["ai"]])
		if e.has("shot") and not ShotTypes.ALL.has(e["shot"]):
			out.append("enemy %s: unknown shot type '%s'" % [id, e["shot"]])
		var minion := String((e.get("params", {}) as Dictionary).get("minion", ""))
		if minion != "" and not Enemies.ALL.has(minion):
			out.append("enemy %s: unknown minion '%s'" % [id, minion])
	for id: String in Bosses.ALL:
		var b: Dictionary = Bosses.ALL[id]
		if not Art.has(String(b["sprite"])):
			out.append("boss %s: sprite '%s' does not exist" % [id, b["sprite"]])
		if not ResourceLoader.exists("res://scripts/entities/bosses/%s.gd" % b["script"]):
			out.append("boss %s: no file bosses/%s.gd" % [id, b["script"]])
	for id: String in Familiars.ALL:
		var f: Dictionary = Familiars.ALL[id]
		if not Art.has(String(f["sprite"])):
			out.append("familiar %s: sprite '%s' does not exist" % [id, f["sprite"]])
		if not ResourceLoader.exists("res://scripts/entities/familiars/%s.gd" % f["behaviour"]):
			out.append("familiar %s: no file familiars/%s.gd" % [id, f["behaviour"]])
	# ---- floors: every floor needs enemies and a boss
	for i in Floors.count():
		var fl: Dictionary = Floors.get_floor(i)
		var pool: Array = fl.get("enemies", [])
		if pool.is_empty():
			pool = Enemies.pool_for_floor(i + 1)
		if pool.is_empty():
			out.append("floor %d: no enemies appear here" % (i + 1))
		for id in pool:
			if not Enemies.ALL.has(id):
				out.append("floor %d: unknown enemy '%s'" % [i + 1, id])
	# ---- pickups
	for id: String in Pickups.ALL:
		if not Art.has(Pickups.sprite_for(id)):
			out.append("pickup %s: no sprite found" % id)
	return out
