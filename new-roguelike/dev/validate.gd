extends RefCounted
## Data checker: looks through every data table for typos (a sprite that does not exist, an AI
## file that is missing, a broken room layout ...). Run it with:
##   godot --headless --path . res://dev/world_test.tscn -- --validate
## tools/check.sh runs it before the bot tests.

const Layouts = preload("res://scripts/data/room_layouts.gd")
const Items = preload("res://scripts/data/items.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Places = preload("res://scripts/data/places.gd")
const ItemEffects = preload("res://scripts/run/item_effects.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")
## Every item pool must hold at least this many items on a brand-new save (locked ones not counted),
## so a four-floor run never runs dry.
const POOL_MIN := 10
const Heroes = preload("res://scripts/data/heroes.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Familiars = preload("res://scripts/data/familiars.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const Floors = preload("res://scripts/data/floors.gd")
const ShotTypes = preload("res://scripts/data/shot_types.gd")
const Stats = preload("res://scripts/run/stats.gd")
const RoomLook = preload("res://scripts/run/room_look.gd")
const CurseTests = preload("res://dev/curse_tests.gd")

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


## Room layouts. Layouts.all_problems() checks every single layout: its size and letters, that no
## door or door approach is blocked, that no tile is sealed off, and that a 3-tile-wide lane joins
## all four doors (room for the Hungry Curse). Here: that every floor has enough rooms to pick from.
static func layout_checks() -> Array[String]:
	var out: Array[String] = Layouts.all_problems()
	for kind in ["start", "treasure", "shop", "secret", "boss", "combat"]:
		if Layouts.pick_list(kind).is_empty():
			out.append("no room layout of kind '%s'" % kind)
	var real := 0
	for l: Dictionary in Layouts.ALL:
		if l["kind"] != "test":
			real += 1
		for f in l.get("floors", []):
			if int(f) > Floors.count():
				out.append("layout %s: floor %d does not exist" % [l["name"], int(f)])
	if real < 45:
		out.append("only %d room layouts (the game wants at least 45)" % real)
	for i in Floors.count():
		# the same difficulty window scripts/run/room.gd uses when it picks a layout
		var lo := 1
		var hi := 2
		if i == 1:
			hi = 3
		elif i >= 2:
			lo = 2
			hi = 3
		var fights := Layouts.pick_list("combat", lo, hi, i + 1).size()
		if fights < 12:
			out.append("floor %d: only %d fight layouts to pick from (wants 12 or more)" % [i + 1, fights])
		for kind in ["start", "treasure", "shop", "secret", "boss"]:
			if Layouts.pick_list(kind, 1, 3, i + 1).is_empty():
				out.append("floor %d: no '%s' layout" % [i + 1, kind])
	return out


## The Hungry Curse's rules, tested on a real run that hangs on `host` (see dev/curse_tests.gd):
## where it appears, the level table, lunges and meals, bites, shots, bombs, CALL, secret walls,
## cursed items and the Starve stand, the belly being kept, the treasure pair.
static func curse(host: Node) -> Array[String]:
	if not G.curse_on():
		return []          # the Curse is switched off (g.gd curse_on); --withcurse runs its tests
	return CurseTests.run_all(host)


static func all() -> Array[String]:
	var out: Array[String] = layout_checks()
	# ---- gear (scripts/data/gear.gd): a picture, a known slot, and every tier has Common and Rare pieces
	var slots: Array = []
	for sl: Dictionary in Gear.SLOTS:
		slots.append(String(sl["id"]))
	var seen_gear := {}
	for g: Dictionary in Gear.LIST:
		var gid := String(g["id"])
		if seen_gear.has(gid):
			out.append("gear %s: two rows share this id" % gid)
		seen_gear[gid] = true
		if not (String(g.get("slot", "")) in slots):
			out.append("gear %s: unknown slot '%s'" % [gid, String(g.get("slot", ""))])
		if not Art.has(String(g.get("icon", ""))):
			out.append("gear %s: picture '%s' is missing (add it to EXTRA in tools/import_icons.py, run it, then the Godot import)" % [gid, String(g.get("icon", ""))])
		if Gear.text(g) == "":
			out.append("gear %s: it does nothing" % gid)
	# ---- skills (scripts/data/skills.gd): a picture and a cast function each
	var cast_src := FileAccess.get_file_as_string("res://scripts/entities/hero_skills.gd")
	for sk: Dictionary in Skills.LIST:
		if not Art.has(String(sk.get("icon", ""))):
			out.append("skill %s: picture '%s' is missing (EXTRA in tools/import_icons.py)" % [sk["id"], String(sk.get("icon", ""))])
		if not cast_src.contains('"%s": _' % String(sk["id"])):
			out.append("skill %s: scripts/entities/hero_skills.gd _cast() does not know it" % sk["id"])
	# ---- companions (scripts/data/allies.gd): art, a real place, a shot type
	for al: Dictionary in Allies.LIST:
		if not Art.has_anim(String(al.get("sprite", "")), "idle"):
			out.append("ally %s: sprite '%s' has no idle animation" % [al["id"], String(al.get("sprite", ""))])
		if Places.get_place(String(al.get("place", ""))).is_empty():
			out.append("ally %s: unknown place '%s'" % [al["id"], String(al.get("place", ""))])
		if not ShotTypes.ALL.has(String(al.get("shot", ""))):
			out.append("ally %s: unknown shot type '%s'" % [al["id"], String(al.get("shot", ""))])
	for rarity in 2:
		if Gear.roll(0, rarity) == "":
			out.append("gear: the first tier has no piece of rarity %d" % rarity)
	# ---- items
	var pool_sizes := {}
	for id: String in Items.ALL:
		var it: Dictionary = Items.ALL[id]
		for field in ["name", "desc", "icon", "cursed", "pools"]:
			if not it.has(field):
				out.append("item %s: missing '%s'" % [id, field])
		# every item has its own picture: icon_<item id>, copied in by tools/import_icons.py
		if String(it.get("icon", "")) != "icon_" + id:
			out.append("item %s: its icon must be 'icon_%s' (add a row in tools/import_icons.py and run it)" % [id, id])
		elif not Art.has("icon_" + id):
			out.append("item %s: assets/art/icons/icon_%s.png is missing (run tools/import_icons.py, then the Godot import)" % [id, id])
		if bool(it.get("locked", false)) != Unlocks.is_gated("item:" + id):
			out.append("item %s: 'locked' and its row in scripts/data/unlocks.gd do not agree" % id)
		if it.get("cursed", false) and String(it.get("curse", "")) == "":
			out.append("item %s: cursed items need a 'curse' line" % id)
		for pool in it.get("pools", []):
			if not POOLS.has(pool):
				out.append("item %s: unknown pool '%s'" % [id, pool])
			if not bool(it.get("locked", false)):       # count what a brand-new save can be offered
				pool_sizes[pool] = int(pool_sizes.get(pool, 0)) + 1
		var mods: Dictionary = it.get("mods", {})
		for part in ["flat", "pct", "mult"]:
			for stat in mods.get(part, {}):
				if not Stats.DEFAULTS.has(stat):
					out.append("item %s: unknown stat '%s'" % [id, stat])
		if it.has("familiar") and not Familiars.ALL.has(it["familiar"]):
			out.append("item %s: unknown familiar '%s'" % [id, it["familiar"]])
	for pool in POOLS:
		if int(pool_sizes.get(pool, 0)) < POOL_MIN:
			out.append("item pool '%s' has %d items before any unlock; a run needs at least %d" % [pool, int(pool_sizes.get(pool, 0)), POOL_MIN])
	# every smart effect is a function <item id>_<hook> in item_effects.gd: both halves must be real
	for m: Dictionary in (ItemEffects as Script).get_script_method_list():
		var fn := String(m["name"])
		var cut := fn.rfind("_on_")
		if fn.begins_with("_") or cut < 1:
			continue
		if not Items.ALL.has(fn.substr(0, cut)):
			out.append("item_effects.gd: %s() belongs to no item ('%s' is not in items.gd)" % [fn, fn.substr(0, cut)])
		if not ItemEffects.HOOKS.has(fn.substr(cut + 1)):
			out.append("item_effects.gd: %s() uses a hook that does not exist ('%s')" % [fn, fn.substr(cut + 1)])
	# ---- heroes
	for h: Dictionary in Heroes.LIST:
		for field in ["sprite", "weapon"]:
			if not Art.has(String(h.get(field, ""))):
				out.append("hero %s: %s '%s' is not a sprite" % [h["id"], field, h.get(field, "")])
		if not ShotTypes.ALL.has(h.get("shot", "blade")):
			out.append("hero %s: unknown shot type '%s'" % [h["id"], h.get("shot", "")])
		if h.has("familiar") and not Familiars.ALL.has(h["familiar"]):
			out.append("hero %s: unknown familiar '%s'" % [h["id"], h["familiar"]])
		# the Pixel Crawler heroes: measured (so the feet stand right) and with a walking animation
		var hero_sprite := String(h.get("sprite", ""))
		if hero_sprite.begins_with("pc_") and (Art.meta(hero_sprite).is_empty() or not Art.has_anim(hero_sprite, "run")):
			out.append("hero %s: sprite '%s' has no measurements or no run animation" % [h["id"], hero_sprite])
	# ---- enemies, bosses, familiars
	for id: String in Enemies.ALL:
		var e: Dictionary = Enemies.ALL[id]
		if not Art.has(String(e["sprite"])):
			out.append("enemy %s: sprite '%s' does not exist" % [id, e["sprite"]])
		elif not Art.frames(String(e["sprite"])).has_animation(String(e.get("idle", "idle"))):
			out.append("enemy %s: sprite '%s' has no animation '%s'" % [id, e["sprite"], e.get("idle", "idle")])
		if String(e["sprite"]).begins_with("pc_") and Art.meta(String(e["sprite"])).is_empty():
			out.append("enemy %s: sprite '%s' is not in pc_cast.json (no size)" % [id, e["sprite"]])
		if fmod(float(e.get("scale", 1.0)), 1.0) != 0.0:
			out.append("enemy %s: scale must be a whole number (pixel art)" % id)
		if not ResourceLoader.exists("res://scripts/entities/ai/%s.gd" % e["ai"]):
			out.append("enemy %s: no AI file '%s.gd'" % [id, e["ai"]])
		if e.has("shot") and not ShotTypes.ALL.has(e["shot"]):
			out.append("enemy %s: unknown shot type '%s'" % [id, e["shot"]])
		var minion := String((e.get("params", {}) as Dictionary).get("minion", ""))
		if minion != "" and not Enemies.ALL.has(minion):
			out.append("enemy %s: unknown minion '%s'" % [id, minion])
	for id: String in Bosses.ALL:
		var b: Dictionary = Bosses.ALL[id]
		var boss_sprite := String(b["sprite"])
		var boss_file := String(b.get("script", id))
		if not ResourceLoader.exists("res://scripts/entities/bosses/%s.gd" % boss_file):
			out.append("boss %s: no file bosses/%s.gd" % [id, boss_file])
		else:
			var fight: GDScript = load("res://scripts/entities/bosses/%s.gd" % boss_file)
			if fight == null or not fight.new().has_method("tick"):
				out.append("boss %s: bosses/%s.gd does not load or has no tick()" % [id, boss_file])
		if b.has("scale"):
			out.append("boss %s: bosses are drawn at their real size (remove \"scale\")" % id)
		if float(b.get("hp", 0.0)) <= 0.0 or (b.get("floors", []) as Array).is_empty():
			out.append("boss %s: needs hp and floors" % id)
		if b.has("shot") and not ShotTypes.ALL.has(b["shot"]):
			out.append("boss %s: unknown shot type '%s'" % [id, b["shot"]])
		if b.has("layout") and Layouts.by_name(String(b["layout"])).get("kind", "") != "boss":
			out.append("boss %s: layout '%s' is not a boss room layout" % [id, b["layout"]])
		if not Art.has(boss_sprite):
			out.append("boss %s: sprite '%s' does not exist" % [id, boss_sprite])
			continue
		# its art is measured, and every animation the measurements list was really loaded
		var cast: Dictionary = Art.meta(boss_sprite)
		if cast.is_empty() or not cast.has("feet") or not cast.has("radius"):
			out.append("boss %s: sprite '%s' is not in boss_cast.json (no feet point, no size)" % [id, boss_sprite])
			continue
		var boss_frames := Art.frames(boss_sprite)
		var listed: Dictionary = cast.get("frames", {})
		for anim: String in listed:
			if not Art.has_anim(boss_sprite, anim) or boss_frames.get_frame_count(anim) != int(listed[anim]):
				out.append("boss %s: animation '%s' of '%s' is missing frames" % [id, anim, boss_sprite])
		for key: String in ["idle", "run", "enter"]:
			if b.has(key) and not Art.has_anim(boss_sprite, String(b[key])):
				out.append("boss %s: \"%s\" names the animation '%s', which '%s' does not have" % [id, key, b[key], boss_sprite])
		for anim: String in (b.get("hit_frames", {}) as Dictionary):
			if not Art.has_anim(boss_sprite, anim):
				out.append("boss %s: hit_frames names the animation '%s', which '%s' does not have" % [id, anim, boss_sprite])
		for fx_id: String in cast.get("fx", []):
			if Art.frames(fx_id) == null:
				out.append("boss %s: effect sprite '%s' is missing" % [id, fx_id])
		for threshold in b.get("phases", [0.5]):
			if float(threshold) <= 0.0 or float(threshold) >= 1.0:
				out.append("boss %s: phases must be shares of its health between 0 and 1" % id)
	for old_id: String in Bosses.RENAMED:
		if not Bosses.ALL.has(Bosses.RENAMED[old_id]):
			out.append("bosses.gd RENAMED: '%s' points at '%s', which is not a boss" % [old_id, Bosses.RENAMED[old_id]])
	# unlock rules that name one boss must name a boss that exists (or existed: Bosses.RENAMED)
	for rule: Dictionary in Unlocks.RULES:
		var stat := String(rule.get("stat", ""))
		if stat.begins_with("boss_killed:") and not Bosses.known(stat.trim_prefix("boss_killed:")):
			out.append("unlock %s: '%s' names no boss" % [rule.get("id", "?"), stat])
	for id: String in Familiars.ALL:
		var f: Dictionary = Familiars.ALL[id]
		if not Art.has(String(f["sprite"])):
			out.append("familiar %s: sprite '%s' does not exist" % [id, f["sprite"]])
		elif not Art.frames(String(f["sprite"])).has_animation(String(f.get("anim", "idle"))):
			out.append("familiar %s: sprite '%s' has no animation '%s'" % [id, f["sprite"], f.get("anim", "idle")])
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
		var guarded := false
		for boss_key: String in Bosses.ALL:
			if (Bosses.ALL[boss_key]["floors"] as Array).has(i + 1):
				guarded = true
		if not guarded:
			out.append("floor %d: no boss guards it (bosses.gd \"floors\")" % (i + 1))
	# ---- the look of each floor: its tile set exists, is complete, and floors.gd names real pieces
	for i in Floors.count():
		var fl: Dictionary = Floors.get_floor(i)
		var set_id := String(fl.get("tiles", ""))
		var ts: Dictionary = RoomLook.tile_set(set_id)
		if ts.is_empty():
			out.append("floor %d: tile set '%s' is not in assets/art/pc_tiles/tilesets.json" % [i + 1, set_id])
			continue
		for part: String in ["floor", "walls", "doors", "obstacles", "wall_deco", "pieces"]:
			if not ts.has(part):
				out.append("tile set %s: no '%s'" % [set_id, part])
		for piece_name: String in ts.get("pieces", {}):
			if not ResourceLoader.exists(RoomLook.TILES_DIR + set_id + "/" + piece_name + ".png"):
				out.append("tile set %s: picture '%s.png' is missing" % [set_id, piece_name])
		for kind: String in ["rock", "crate", "pillar", "torch", "pit", "spikes"]:
			if not (ts.get("obstacles", {}) as Dictionary).has(kind):
				out.append("tile set %s: no picture for obstacle '%s'" % [set_id, kind])
		for wall: String in ["n", "s", "w", "e"]:
			for state: String in ["open", "shut", "locked", "hidden", "cracked", "boss", "boss_open"]:
				if not ((ts.get("doors", {}) as Dictionary).get(wall, {}) as Dictionary).has(state):
					out.append("tile set %s: door '%s' has no state '%s'" % [set_id, wall, state])
		var dress: Dictionary = fl.get("dress", {})
		for kind: String in dress:
			for row: Dictionary in dress[kind]:
				if not RoomLook.has_piece(set_id, String(row.get("piece", ""))):
					out.append("floor %d: dress '%s' names a piece '%s' the tile set does not have" % [i + 1, kind, row.get("piece", "")])
		for piece_name in fl.get("no_floor_deco", []):
			if not RoomLook.has_piece(set_id, String(piece_name)):
				out.append("floor %d: no_floor_deco names an unknown piece '%s'" % [i + 1, piece_name])
		if bool(fl.get("pit_join", false)) and ((ts.get("obstacles", {}) as Dictionary).get("pit", {}) as Dictionary).has("frames"):
			out.append("floor %d: pit_join only works with a still pit picture" % (i + 1))
	# ---- pickups
	for id: String in Pickups.ALL:
		if not Art.has(Pickups.sprite_for(id)):
			out.append("pickup %s: no sprite found" % id)
	return out
