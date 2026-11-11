extends Node
## Save (autoload): everything that survives between runs, in user://save.json.
##   unlocks   ids such as "hero:witch", "item:glass_blade", "ach:first_win"
##   stats     lifetime counters (runs, wins, kills, coins, "boss_killed:<id>", "secret_found" ...)
##   seen      item ids the player has picked up at least once (for the collection screen)
##   settings  sfx_volume, music_volume, vibration, ...
## Content that is NOT listed in scripts/data/unlocks.gd is available from the start.

signal unlocked(id: String)

const PATH := "user://save.json"
const DEFAULTS := {
	"version": 1,
	"unlocks": {},
	"stats": {},
	"seen": {},
	"settings": {"sfx_volume": 1.0, "music_volume": 0.7, "vibration": true},
}

var data: Dictionary = DEFAULTS.duplicate(true)
var _dirty := false
## Tests pass --nosave so they never touch the real save file.
var disk := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	disk = not G.flag("nosave") and not G.flag("autotest")
	if disk and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key in DEFAULTS:
				if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
					if parsed[key] is Dictionary:
						(data[key] as Dictionary).merge(parsed[key], true)
					else:
						data[key] = parsed[key]
	Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))


func is_unlocked(id: String) -> bool:
	return data["unlocks"].has(id)


func unlock(id: String) -> void:
	if is_unlocked(id):
		return
	data["unlocks"][id] = true
	_dirty = true
	unlocked.emit(id)


func stat_get(key: String) -> int:
	return int(data["stats"].get(key, 0))


func stat_add(key: String, amount: int = 1) -> void:
	data["stats"][key] = stat_get(key) + amount
	_dirty = true


func stat_max(key: String, value: int) -> void:
	if value > stat_get(key):
		data["stats"][key] = value
		_dirty = true


func mark_seen(item_id: String) -> void:
	if not data["seen"].has(item_id):
		data["seen"][item_id] = true
		_dirty = true


func has_seen(item_id: String) -> bool:
	return data["seen"].has(item_id)


func setting(key: String) -> Variant:
	return data["settings"].get(key, DEFAULTS["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	_dirty = true
	if key == "sfx_volume" or key == "music_volume":
		Sfx.set_volumes(float(setting("sfx_volume")), float(setting("music_volume")))


## Writes the file if anything changed. Call at natural pauses (room cleared, run ended, settings closed).
func flush() -> void:
	if not _dirty or not disk:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		_dirty = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush()
