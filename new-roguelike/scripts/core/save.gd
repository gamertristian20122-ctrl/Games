extends Node
## Save (autoload): everything that survives between runs, in user://save.json.
##   unlocks   ids such as "hero:witch", "item:glass_blade", "ach:first_win"
##   stats     lifetime counters (runs, wins, total_kills, "boss_killed:<id>", "secret_found" ...)
##   seen      item ids the player has picked up at least once (for the collection screen)
##   flags     one-time things this profile has already seen, e.g. the first-run lessons ("taught:curse_intro")
##   hub       numbers the camp keeps: quest progress ("q:<id>:base", "q:<id>:done") and the supplies
##             waiting for the next run ("boon:coins" ...). See scripts/data/quests.gd.
##   settings  sfx_volume, music_volume, vibration, swap_sticks, last_hero
## It also keeps score by itself: it listens to the game's events (G.stat, G.run_ended,
## G.item_acquired), adds them to the counters and checks the unlock rules in
## scripts/data/unlocks.gd. Content that is NOT listed there is available from the start.
## The file is never written when the game runs with --autotest, --nosave or --uitour.

const Unlocks = preload("res://scripts/data/unlocks.gd")
const Items = preload("res://scripts/data/items.gd")

signal unlocked(id: String)

const PATH := "user://save.json"
const BAD_PATH := "user://save.bad.json"
const VERSION := 1
const DEFAULT_SETTINGS := {
	"sfx_volume": 1.0, "music_volume": 0.7, "vibration": true, "swap_sticks": false, "last_hero": "knight",
	"difficulty": "normal", "hero_name": "Aldous", "armour": "steel", "sword_look": "knight", "weapon": "sword",
	"shake": true,           # the camera shakes on a hit in a battle (off for players it bothers)
	"look3d": true,          # the lit 3D look of the places you walk in (scripts/hub/view3d.gd); off = the old flat picture
	"ui_size": "normal",     # Text size on PC: "small" / "normal" / "large" (scripts/ui/theme.gd TARGET_H; UI.refit_all())
}
const DEFAULTS := {
	"version": VERSION,
	"unlocks": {},
	"stats": {},
	"seen": {},
	"flags": {},
	"hub": {},
	"settings": DEFAULT_SETTINGS,
}

var data: Dictionary = DEFAULTS.duplicate(true)
var _dirty := false
## Tests pass --nosave so they never touch the real save file.
var disk := true
## Ids unlocked since the current run started (the end screen lists them).
var run_unlocks: Array[String] = []
var _run_recorded := false
## Kills and coins already added to the lifetime totals during the current run.
var _live_kills := 0
var _live_coins := 0
## Counters this file keeps by itself. If the world also sends them with G.stat they are
## ignored, so nothing is ever counted twice.
const OWN_KEYS := ["runs", "deaths", "wins", "best_floor", "fastest_win", "total_kills", "total_coins", "items_taken", "cursed_taken"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	disk = not G.flag("nosave") and not G.flag("autotest") and not G.flag("uitour")
	if disk:
		_load()
	Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))
	G.stat.connect(_on_stat)
	G.run_started.connect(_on_run_started)
	G.run_ended.connect(_on_run_ended)
	G.item_acquired.connect(_on_item_acquired)
	G.room_cleared.connect(_on_room_cleared)


# ------------------------------------------------------------------ reading the file safely
func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text := FileAccess.get_file_as_string(PATH)
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		# A broken file must never crash the game: keep a copy for rescue and start fresh.
		push_warning("Save: save.json could not be read. Starting fresh; the old file is kept as save.bad.json.")
		var f := FileAccess.open(BAD_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
		return
	_absorb(json.data)


## Copies only the parts of a loaded file that have the right shape. Anything odd is skipped,
## so files from older versions (or edited by hand) still load.
func _absorb(loaded: Dictionary) -> void:
	for section: String in ["unlocks", "seen", "flags"]:
		var src: Variant = loaded.get(section)
		var keys: Array = []
		if src is Dictionary:
			for k: Variant in src:
				if src[k]:
					keys.append(k)
		elif src is Array:
			keys = src
		for k: Variant in keys:
			if k is String and k != "":
				data[section][k] = true
	for section: String in ["stats", "hub"]:
		var stats: Variant = loaded.get(section)
		if stats is Dictionary:
			for k: Variant in stats:
				var v: Variant = stats[k]
				if k is String and (v is float or v is int) and is_finite(float(v)):
					data[section][k] = int(v)
	var settings: Variant = loaded.get("settings")
	if settings is Dictionary:
		for k: Variant in settings:
			if not (k is String):
				continue
			var v: Variant = settings[k]
			var def: Variant = DEFAULT_SETTINGS.get(k)
			if def is float:
				if v is float or v is int:
					data["settings"][k] = clampf(float(v), 0.0, 1.0)
			elif def is bool:
				if v is bool:
					data["settings"][k] = v
			elif def is String:
				if v is String:
					data["settings"][k] = v
			elif v is bool or v is float or v is int or v is String:
				data["settings"][k] = v      # a setting this version does not know: keep it


# ------------------------------------------------------------------ unlocks
func is_unlocked(id: String) -> bool:
	return data["unlocks"].has(id)


func unlock(id: String) -> void:
	if is_unlocked(id):
		return
	data["unlocks"][id] = true
	_dirty = true
	run_unlocks.append(id)
	unlocked.emit(id)


## Looks at every rule in scripts/data/unlocks.gd and unlocks the ones whose counter is high enough.
## Pass a counter name to only look at rules that watch it.
func check_unlocks(changed_key: String = "") -> void:
	for rule: Dictionary in Unlocks.RULES:
		var id: String = rule["id"]
		if is_unlocked(id):
			continue
		var key: String = rule["stat"]
		if changed_key != "" and changed_key != key and not changed_key.begins_with(key + ":"):
			continue
		if stat_total(key) >= int(rule["at_least"]):
			unlock(id)


# ------------------------------------------------------------------ counters
func stat_get(key: String) -> int:
	return int(data["stats"].get(key, 0))


## A counter plus all its "key:<detail>" variants, e.g. "boss_killed" also counts
## "boss_killed:gravekeeper". (Whichever is bigger, so nothing is counted twice.)
func stat_total(key: String) -> int:
	var prefix := key + ":"
	var sum := 0
	for k: String in data["stats"]:
		if k.begins_with(prefix):
			sum += int(data["stats"][k])
	return maxi(stat_get(key), sum)


func stat_add(key: String, amount: int = 1) -> void:
	if amount == 0:
		return
	data["stats"][key] = stat_get(key) + amount
	_dirty = true


func stat_max(key: String, value: int) -> void:
	if value > stat_get(key):
		data["stats"][key] = value
		_dirty = true


## Keeps the smallest value seen (0 means "never set").
func stat_min(key: String, value: int) -> void:
	if value > 0 and (stat_get(key) == 0 or value < stat_get(key)):
		data["stats"][key] = value
		_dirty = true


# ------------------------------------------------------------------ collection
func mark_seen(item_id: String) -> void:
	if not data["seen"].has(item_id):
		data["seen"][item_id] = true
		_dirty = true


func has_seen(item_id: String) -> bool:
	return data["seen"].has(item_id)


# ------------------------------------------------------------------ one-time flags
## True once set_flag(key) was called on this save profile (first-run lessons use it).
func flag(key: String) -> bool:
	return (data.get("flags", {}) as Dictionary).has(key)


func set_flag(key: String) -> void:
	if not data.has("flags"):
		data["flags"] = {}
	if not data["flags"].has(key):
		data["flags"][key] = true
		_dirty = true


# ------------------------------------------------------------------ settings
func setting(key: String) -> Variant:
	return data["settings"].get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if data["settings"].get(key) == value:
		return
	data["settings"][key] = value
	_dirty = true
	if key == "sfx_volume" or key == "music_volume":
		Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))


## Forgets unlocks, counters and the collection. Settings are kept.
func reset_progress() -> void:
	data["unlocks"] = {}
	data["stats"] = {}
	data["seen"] = {}
	data["flags"] = {}
	data["hub"] = {}
	run_unlocks.clear()
	_dirty = true
	flush()


# ------------------------------------------------------------------ the camp's numbers
func hub_get(key: String) -> int:
	return int(data["hub"].get(key, 0))


func hub_set(key: String, value: int) -> void:
	if not data.has("hub"):
		data["hub"] = {}
	data["hub"][key] = value
	_dirty = true


# ------------------------------------------------------------------ writing the file
## Writes the file if anything changed. Call at natural pauses (room cleared, run ended, settings closed).
func flush() -> void:
	if not _dirty or not disk:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		data["version"] = VERSION
		f.store_string(JSON.stringify(data, "\t"))
		_dirty = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush()


# ------------------------------------------------------------------ keeping score
func _on_run_started(_run: Node) -> void:
	run_unlocks.clear()
	_run_recorded = false
	_live_kills = 0
	_live_coins = 0


func _on_stat(key: String, amount: int) -> void:
	if is_instance_valid(G.run) and G.run.get("training") == true:
		return                                  # nothing done in the training yard is counted
	if key in OWN_KEYS or key.begins_with("wins:"):
		return                                  # counted by record_run() / _on_item_acquired()
	stat_add(key, amount)
	check_unlocks(key)
	# a few of the world's counters also feed the totals straight away, so unlocks pop mid-run
	if key == "kills":
		_live_kills += amount
		stat_add("total_kills", amount)
		check_unlocks("total_kills")
	elif key == "coins":
		_live_coins += amount
		stat_add("total_coins", amount)
		check_unlocks("total_coins")
	elif key.begins_with("floor_reached:"):
		stat_max("best_floor", int(key.get_slice(":", 1)))
		check_unlocks("best_floor")


func _on_item_acquired(item_id: String) -> void:
	mark_seen(item_id)
	stat_add("items_taken")
	if bool(Items.info(item_id).get("cursed", false)):
		stat_add("cursed_taken")
		check_unlocks("cursed_taken")


func _on_room_cleared(_coord: Vector2i) -> void:
	flush()


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	record_run(victory, summary)


## Adds a finished run to the lifetime counters. The world's G.run_ended lands here; the shell
## also calls it directly when the player gives up from the pause menu. Counted once per run.
func record_run(victory: bool, summary: Dictionary) -> void:
	if _run_recorded:
		return
	_run_recorded = true
	var hero := String(summary.get("hero", ""))
	stat_add("runs")
	if victory:
		stat_add("wins")
		if hero != "":
			stat_add("wins:" + hero)
		stat_min("fastest_win", int(ceilf(float(summary.get("time_s", 0.0)))))
	else:
		stat_add("deaths")
	stat_max("best_floor", int(summary.get("floor", 1)))
	# whatever was not already counted live during the run
	stat_add("total_kills", maxi(int(summary.get("kills", 0)) - _live_kills, 0))
	stat_add("total_coins", maxi(int(summary.get("coins", 0)) - _live_coins, 0))
	check_unlocks()
	flush()
