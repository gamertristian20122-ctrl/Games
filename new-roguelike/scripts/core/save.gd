extends Node
## Save (autoload): everything that survives between sessions.
##
## FILES (all under user://, see docs/pass/04_shell.md):
##   save_1.json, save_2.json, save_3.json   one per SLOT: the story, levels, coins, gear ...
##   save_<n>.json.bak                       the slot as it was before the last write
##   save_<n>.broken_<date>.json             a slot file that could not be read (kept, never overwritten)
##   settings.json                           the settings, shared by all slots, and the slot played last
##   save.json                               the single file of versions before 0.45: it is COPIED into
##                                           slot 1 the first time and then left alone
## A write is safe: the text goes to "<file>.tmp", its length is checked, the file as it was is copied
## to "<file>.bak", and only then the tmp file takes the real file's place. A file that is cut short
## or garbled is read from its .bak instead (`recovered` is true then, the title says so).
##
## A slot holds:
##   meta      what the slot cards show: step, level, place, play_s, date (written on every flush)
##   unlocks   ids such as "hero:witch", "item:glass_blade", "ach:first_win"
##   stats     lifetime counters (runs, wins, total_kills, "boss_killed:<id>", "secret_found" ...)
##   seen      item ids the player has picked up at least once
##   flags     one-time things this slot has already seen ("taught:curse_intro")
##   hub       every number of the story game: "tale:step", "rpg:lvl", "bank:coins", "gear:<id>" ...
## Settings (DEFAULT_SETTINGS below) live in memory under data["settings"] as before.
## It also keeps score by itself: it listens to the game's events (G.stat, G.run_ended,
## G.item_acquired), adds them to the counters and checks the unlock rules in
## scripts/data/unlocks.gd.
## Nothing is ever written when the game runs with --autotest, --nosave or --uitour (disk = false).

const Unlocks = preload("res://scripts/data/unlocks.gd")
const Items = preload("res://scripts/data/items.gd")

signal unlocked(id: String)
## A slot file was written to the disk just now (scripts/ui/kit/saved_tag.gd shows "Saved").
signal flushed

const SLOTS := 3
const LEGACY_FILE := "save.json"           ## the one save file of versions before the slots
const SETTINGS_FILE := "settings.json"
const VERSION := 2
const DEFAULT_SETTINGS := {
	"sfx_volume": 1.0, "music_volume": 0.7, "vibration": true, "swap_sticks": false, "last_hero": "knight",
	"difficulty": "normal", "hero_name": "Aldous", "armour": "steel", "sword_look": "knight", "weapon": "sword",
	"shake": true,           # the camera shakes on a hit in a battle (off for players it bothers)
	"look3d": true,          # the lit 3D look of the places you walk in (scripts/hub/view3d.gd); off = the old flat picture
	"ui_size": "normal",     # Text size on PC: "small" / "normal" / "large" (scripts/ui/theme.gd TARGET_H; UI.refit_all())
	"display": "window",     # PC: "window" or "full" (scripts/ui/display.gd; F11 / Alt+Enter toggles)
	"fairy_dust": true,      # glittering dust on the ground that leads to the story's next goal (scripts/hub/trail.gd)
	"vsync": true,           # PC: VSync on or off
	# ---- added with the slots (v0.45): each is read by the package named; a missing one reads as its default
	"battle_mode": "normal", # "story" / "normal" / "hard": foe health and attack (scripts/data/battles.gd MODE)
	"text_speed": "normal",  # how fast the talk box types: "slow" / "normal" / "fast" / "instant"
	"battle_speed": 1,       # 1, 2 or 3: how fast a battle plays
	"flashes": "full",       # "full" / "reduced": hit flashes and hit-stop in battles
	"hints": true,           # the first-time lessons
	"master_volume": 1.0,
	"amb_volume": 1.0,
	"mute_bg": true,         # PC: no sound while the window is not in front
	"ff_toggle": false,      # fast-forward is a switch instead of a held key
	"pad_glyphs": "auto",    # which gamepad's button pictures the hints show
	"fps_cap": 0,            # PC: 0 = no cap
	"binds": {},             # rebound keys and pad buttons: action name -> what the rebind screen stores
}
const DEFAULTS := {
	"version": VERSION,
	"meta": {},
	"unlocks": {},
	"stats": {},
	"seen": {},
	"flags": {},
	"hub": {},
	"settings": DEFAULT_SETTINGS,
}
## The parts of `data` that belong to a slot (everything but the settings).
const SLOT_PARTS := ["unlocks", "stats", "seen", "flags", "hub"]

var data: Dictionary = DEFAULTS.duplicate(true)
var _dirty := false
var _dirty_settings := false
## Tests pass --nosave so they never touch the real save file.
var disk := true
## The folder the files live in. Only the save test (--uitour=save) points it somewhere else.
var root := "user://"
## The slot being played (1..SLOTS).
var slot := 1
## True when the slot (or the settings) had to be read from a .bak file this session.
var recovered := false
## True once a game has begun in the slot being played (New Game, or a file that was loaded). Until
## then nothing of the slot is written: opening Settings on a fresh title must not leave a "game".
var _started := false
var _legacy_done := false        ## the old single save.json was already looked at (it is taken over only once)
## Where the knight is and how long this slot was played (the slot cards show them). main.gd keeps
## both up to date; they are written with every flush.
var place_name := ""
var play_s := 0.0
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
		boot()
	Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))
	G.stat.connect(_on_stat)
	G.run_started.connect(_on_run_started)
	G.run_ended.connect(_on_run_ended)
	G.item_acquired.connect(_on_item_acquired)
	G.room_cleared.connect(_on_room_cleared)


## Reads the settings and the slot played last from the disk (called once at the start; the save
## test calls it again after pointing `root` at its own folder).
func boot() -> void:
	data = DEFAULTS.duplicate(true)
	_dirty = false
	_dirty_settings = false
	recovered = false
	slot = 1
	_legacy_done = false
	var had_settings := FileAccess.file_exists(root + SETTINGS_FILE) or FileAccess.file_exists(root + SETTINGS_FILE + ".bak")
	var shared := _read(root + SETTINGS_FILE)
	if not shared.is_empty():
		_absorb_settings(shared.get("settings"))
		slot = clampi(int(shared.get("last_slot", 1)), 1, SLOTS)
		_legacy_done = shared.get("legacy_done") == true
	_adopt_legacy(not had_settings)
	_load_slot(slot)
	flush()                          # (only writes when the old save was just taken over)


func slot_path(n: int) -> String:
	return "%ssave_%d.json" % [root, n]


## A save from before the slots (user://save.json) becomes slot 1 by COPY, once: only while slot 1
## has no file of its own. The old file is left exactly as it is. Its settings are taken over when
## there is no settings file yet.
func _adopt_legacy(take_settings: bool) -> void:
	var old := root + LEGACY_FILE
	if _legacy_done or not FileAccess.file_exists(old):
		return
	_legacy_done = true            # (remembered in settings.json: a slot 1 erased later stays erased)
	_dirty_settings = true
	if take_settings:
		var loaded := _parse(FileAccess.get_file_as_string(old))
		if not loaded.is_empty():
			_absorb_settings(loaded.get("settings"))
			_dirty_settings = true
	if not FileAccess.file_exists(slot_path(1)) and not FileAccess.file_exists(slot_path(1) + ".bak"):
		if DirAccess.copy_absolute(old, slot_path(1)) == OK:
			print("Save: the old save.json was copied into slot 1 (the old file is left as it was).")
			slot = 1


# ------------------------------------------------------------------ reading a file safely
## The dictionary in `text`, or {} when it is not one (cut short, garbled, empty).
func _parse(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data


## Reads `path`; if it is broken, keeps a dated copy of it and reads "<path>.bak" instead (and puts
## that good copy back in the file's place). {} = nothing readable is there.
func _read(path: String) -> Dictionary:
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		var loaded := _parse(FileAccess.get_file_as_string(path))
		if not loaded.is_empty():
			return loaded
		# A broken file must never crash the game and must never be thrown away.
		var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
		var kept := "%s.broken_%s.json" % [path.trim_suffix(".json"), stamp]
		DirAccess.copy_absolute(path, kept)
		push_warning("Save: %s could not be read. It is kept as %s." % [path.get_file(), kept.get_file()])
	elif not FileAccess.file_exists(bak):
		return {}
	if FileAccess.file_exists(bak):
		var older := _parse(FileAccess.get_file_as_string(bak))
		if not older.is_empty():
			recovered = true
			DirAccess.copy_absolute(bak, path)
			push_warning("Save: %s was read from its backup copy." % path.get_file())
			return older
	return {}


## Brings a file of an older version up to this one. One step per version, so each stays small.
func _migrate(loaded: Dictionary) -> Dictionary:
	var v := int(loaded.get("version", 1)) if (loaded.get("version") is float or loaded.get("version") is int) else 1
	if v < 2:
		# version 1 was the single save.json: the settings were inside it (they are their own file
		# now, see _adopt_legacy) and it had no "meta" block (it is written new on the next flush)
		loaded.erase("settings")
		v = 2
	loaded["version"] = v
	return loaded


func _clear_slot_data() -> void:
	for part: String in SLOT_PARTS:
		data[part] = {}
	data["meta"] = {}
	place_name = ""
	play_s = 0.0
	_started = false
	run_unlocks.clear()


func _load_slot(n: int) -> void:
	_clear_slot_data()
	slot = clampi(n, 1, SLOTS)
	_dirty = false
	if not disk:
		return
	var loaded := _read(slot_path(slot))
	if loaded.is_empty():
		return
	loaded = _migrate(loaded)
	_absorb(loaded)
	_started = true
	var meta: Variant = loaded.get("meta")
	if meta is Dictionary:
		place_name = String(meta.get("place", "")) if meta.get("place") is String else ""
		var secs: Variant = meta.get("play_s", 0)
		play_s = maxf(float(secs), 0.0) if (secs is float or secs is int) else 0.0


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
	_absorb_settings(loaded.get("settings"))


func _absorb_settings(settings: Variant) -> void:
	if not (settings is Dictionary):
		return
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
		elif def is int:
			if (v is float or v is int) and is_finite(float(v)):
				data["settings"][k] = int(v)
		elif def is String:
			if v is String:
				data["settings"][k] = v
		elif def is Dictionary:
			if v is Dictionary:
				data["settings"][k] = _plain(v)      # "binds": action name -> keys and buttons
		elif v is bool or v is float or v is int or v is String:
			data["settings"][k] = v      # a setting this version does not know: keep it


## A copy of a dictionary from a file with only plain things in it (text keys; numbers, words,
## yes / no, and lists or dictionaries of those), at most four levels deep.
func _plain(v: Variant, depth: int = 0) -> Variant:
	if v is bool or v is String or v is int:
		return v
	if v is float:
		return v if is_finite(v) else 0.0
	if depth >= 4:
		return null
	if v is Array:
		var list: Array = []
		for item: Variant in v:
			var p: Variant = _plain(item, depth + 1)
			if p != null:
				list.append(p)
		return list
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			var p: Variant = _plain(v[k], depth + 1)
			if k is String and p != null:
				out[k] = p
		return out
	return null


# ------------------------------------------------------------------ slots
## What a slot card shows: {exists, step, level, place, play_s, date, coins, recovered}. An empty
## slot is {exists = false, ...} with the numbers of a new game.
func slot_info(n: int) -> Dictionary:
	var info := {"exists": false, "step": 0, "level": 1, "place": "", "play_s": 0.0, "date": "", "coins": 0}
	if n == slot:
		# the slot being played: what is in memory is newer than the file
		info["exists"] = _started
		info.merge(_meta(), true)
		if not info["exists"]:
			info["date"] = ""
		return info
	if not disk:
		return info
	var path := slot_path(n)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return info
	var was := recovered
	var loaded := _read(path)
	recovered = was                    # (looking at another slot's card is not "this game was recovered")
	if loaded.is_empty():
		return info
	info["exists"] = true
	var hub: Variant = loaded.get("hub")
	if hub is Dictionary:
		info["step"] = int(hub.get("tale:step", 0))
		info["level"] = maxi(int(hub.get("rpg:lvl", 1)), 1)
		info["coins"] = int(hub.get("bank:coins", 0))
	var meta: Variant = loaded.get("meta")
	if meta is Dictionary:
		for key: String in ["place", "date"]:
			if meta.get(key) is String:
				info[key] = meta[key]
		if meta.get("play_s") is float or meta.get("play_s") is int:
			info["play_s"] = float(meta["play_s"])
	return info


## True when at least one slot holds a game.
func any_slot() -> bool:
	for n: int in range(1, SLOTS + 1):
		if bool(slot_info(n)["exists"]):
			return true
	return false


## The first slot with no game in it, or 0 when all are taken.
func free_slot() -> int:
	for n: int in range(1, SLOTS + 1):
		if not bool(slot_info(n)["exists"]):
			return n
	return 0


## Plays slot n from now on (what was being played is written first).
func use_slot(n: int) -> void:
	n = clampi(n, 1, SLOTS)
	if n == slot:
		return
	flush()
	_load_slot(n)
	_dirty_settings = true             # (the settings file remembers the slot played last)
	flush()


## Starts slot n from nothing (a game that was in it is gone, its files too) and plays it.
func new_game(n: int) -> void:
	n = clampi(n, 1, SLOTS)
	if n != slot:
		flush()
	_remove_slot_files(n)
	slot = n
	_clear_slot_data()
	_started = true
	_dirty = true
	_dirty_settings = true
	flush()


## A game is being played in this slot from now on (main.gd calls it when a place opens), so it
## is written from now on. New Game and a loaded file do this by themselves.
func begin() -> void:
	if not _started:
		_started = true
		_dirty = true


## Copies slot a over slot b (the one being played is written first). False if a holds nothing.
func copy_slot(a: int, b: int) -> bool:
	a = clampi(a, 1, SLOTS)
	b = clampi(b, 1, SLOTS)
	if a == b or not bool(slot_info(a)["exists"]):
		return false
	if a == slot:
		_dirty = true
		flush()                        # what is in memory is newer than the file
	if not disk:
		return false
	if not FileAccess.file_exists(slot_path(a)):
		return false
	_remove_slot_files(b)
	var ok := DirAccess.copy_absolute(slot_path(a), slot_path(b)) == OK
	if ok and b == slot:
		_load_slot(b)
	return ok


## Empties slot n: its file and its backup are deleted. If it is the slot being played, the game in
## memory starts over too (settings are kept).
func erase_slot(n: int) -> void:
	n = clampi(n, 1, SLOTS)
	_remove_slot_files(n)
	if n == slot:
		_clear_slot_data()
		_dirty = false


func _remove_slot_files(n: int) -> void:
	if not disk:
		return
	for path: String in [slot_path(n), slot_path(n) + ".bak", slot_path(n) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Adds real seconds to the slot's play time (main.gd, while a place or a battle is on screen).
func add_play(seconds: float) -> void:
	play_s += maxf(seconds, 0.0)


## Marks the slot as changed, so the next flush() writes it (the play time alone does not).
func touch() -> void:
	_dirty = true


func _meta() -> Dictionary:
	return {
		"step": int(data["hub"].get("tale:step", 0)),
		"level": maxi(int(data["hub"].get("rpg:lvl", 1)), 1),
		"coins": int(data["hub"].get("bank:coins", 0)),
		"place": place_name,
		"play_s": snappedf(play_s, 0.1),
		"date": Time.get_datetime_string_from_system(false, true).left(16),
	}


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
	_dirty_settings = true
	if key.ends_with("_volume"):
		Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))


## Erases the game in the slot being played: story, levels, coins, gear, counters. Settings are kept.
func reset_progress() -> void:
	erase_slot(slot)


# ------------------------------------------------------------------ the camp's numbers
func hub_get(key: String) -> int:
	return int(data["hub"].get(key, 0))


func hub_set(key: String, value: int) -> void:
	if not data.has("hub"):
		data["hub"] = {}
	data["hub"][key] = value
	_dirty = true


# ------------------------------------------------------------------ writing the files
## Writes what changed: the slot being played and / or the settings. Call at natural pauses (a
## battle won, a night slept, a menu closed). Does nothing when nothing changed.
func flush() -> void:
	if not disk:
		return
	if _dirty_settings:
		var shared := {"version": VERSION, "last_slot": slot, "legacy_done": _legacy_done, "settings": data["settings"]}
		if _write(root + SETTINGS_FILE, JSON.stringify(shared, "\t")):
			_dirty_settings = false
	if _dirty and _started:
		var out := {"version": VERSION, "meta": _meta()}
		for part: String in SLOT_PARTS:
			out[part] = data[part]
		data["meta"] = out["meta"]
		if _write(slot_path(slot), JSON.stringify(out, "\t")):
			_dirty = false
			flushed.emit()


## The safe write: tmp file, length check, the old file kept as .bak, then the swap.
func _write(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s (error %d)." % [tmp.get_file(), FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	var want := text.to_utf8_buffer().size()
	var check := FileAccess.open(tmp, FileAccess.READ)
	var got := int(check.get_length()) if check != null else -1
	if check != null:
		check.close()
	if got != want:
		# the disk is full or the write was cut off: the real file is not touched
		push_warning("Save: %s came out %d bytes long, %d were written. The save is left as it was." % [tmp.get_file(), got, want])
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path) and not _parse(FileAccess.get_file_as_string(path)).is_empty():
		DirAccess.copy_absolute(path, path + ".bak")       # (a broken file never replaces a good backup)
	if DirAccess.rename_absolute(tmp, path) != OK:
		# some systems will not rename over a file that exists: take it away first
		DirAccess.remove_absolute(path)
		if DirAccess.rename_absolute(tmp, path) != OK:
			push_warning("Save: could not put %s in place." % path.get_file())
			return false
	return true


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
