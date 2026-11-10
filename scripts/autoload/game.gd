extends Node
## The current run: which floor and room we are in, the keeper's hearts and
## items, and the tapes the echoes play back. Everything here is thrown away
## and rebuilt when a new run starts.

signal hp_changed
signal items_changed
signal combo_found(combo_id: String)

# --- Sizes (in pixels). A room is 30 tiles wide and 15 tall. ---
const TILE := 16
const COLS := 30
const ROWS := 15
const ROOM_W := 480.0
const ROOM_H := 240.0
const HUD_H := 30.0

const START_HP := 5

## The three difficulty settings. Each one changes:
##   danger  - how fast enemy shots fly and how often enemies fire
##   crowd   - how many enemies each room sends
##   hearts  - extra hearts the keeper starts with
const DIFFICULTIES := [
	{"name": "Calm", "danger": 0.85, "crowd": 0.8, "hearts": 2},
	{"name": "Standard", "danger": 1.0, "crowd": 1.0, "hearts": 0},
	{"name": "Stormy", "danger": 1.15, "crowd": 1.25, "hearts": 0},
]
const HP_CAP := 10
const BOSS_HEAL := 2
const DEATH_ECHO_PATH := "user://last_echo.dat"
const RECORDS_PATH := "user://records.cfg"

# --- The run ---
var rng := RandomNumberGenerator.new()          # rooms and reward offers
var combat_rng := RandomNumberGenerator.new()   # dice rolled during fights
var run_seed := 0
var run_active := false
var floor_index := 0        # 0 = Lamp Tower, 1 = Cliff Cellars, 2 = Tide Caves
var room_index := 0         # room number inside the floor (the last one is the boss)
var rooms_cleared := 0
var run_time := 0.0

# --- The keeper ---
var hp := START_HP
var max_hp := START_HP
var items: Dictionary = {}              # item id -> how many copies
var item_order: Array[String] = []      # in the order they were picked
var stats := PlayerStats.new()
var unhurt_streak := 0                  # rooms in a row without being hit
var hit_this_room := false
var shots_fired := 0
var hits_landed := 0
var dashes_done := 0

# --- Echo tapes, oldest first ---
var tapes: Array[EchoTape] = []

# --- Modes ---
var bot_mode := false       # the test bot is playing
var fast_mode := false      # no sound or effects (bot batches)
var god_mode := false       # the keeper cannot be hurt (for testing, "--god")
var difficulty := 1         # 0 = Calm, 1 = Standard, 2 = Stormy (copied from Settings when a run starts)

# --- Numbers collected for the balance report ---
var metrics: Dictionary = {}

# --- Screen shake asked for by the game (the camera in main.gd reads it) ---
var shake_amount := 0.0

# --- Lifetime records ---
var total_runs := 0
var total_wins := 0
var best_rooms := 0


func _ready() -> void:
	_load_records()


## Starts a fresh run. The same seed always gives the same rooms and offers.
func new_run(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	combat_rng.seed = seed_value + 7919
	run_active = true
	floor_index = 0
	room_index = 0
	rooms_cleared = 0
	run_time = 0.0
	items = {}
	item_order = []
	stats = PlayerStats.build(items)
	if not bot_mode:
		difficulty = Settings.difficulty
	max_hp = START_HP + int(difficulty_def()["hearts"])
	hp = max_hp
	unhurt_streak = 0
	hit_this_room = false
	shots_fired = 0
	hits_landed = 0
	dashes_done = 0
	tapes = []
	if not bot_mode:
		var old := _load_death_echo()
		if old != null:
			tapes.append(old)
	metrics = {
		"seed": seed_value, "difficulty": difficulty, "result": "", "killer": "", "floor": 0, "room": 0,
		"rooms_cleared": 0, "time": 0.0, "items": [], "combos": [],
		"damage_by": {}, "hits_by": {}, "rooms": [], "final_hp": 0,
	}
	hp_changed.emit()
	items_changed.emit()


## Asks for a screen shake. Bigger numbers shake harder.
func shake(amount: float) -> void:
	if not fast_mode:
		shake_amount = maxf(shake_amount, amount)


func difficulty_def() -> Dictionary:
	return DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)]


## How dangerous enemies are right now: the floor's number times the difficulty's.
func danger() -> float:
	return float(floor_def().get("danger", 1.0)) * float(difficulty_def()["danger"])


func floor_def() -> Dictionary:
	return FloorDB.get_floor(floor_index)


func is_boss_room() -> bool:
	return room_index >= int(floor_def()["rooms"])


## Moves on to the next room. Returns false when the run has been won.
func advance_room() -> bool:
	room_index += 1
	if room_index > int(floor_def()["rooms"]):
		room_index = 0
		floor_index += 1
		if floor_index >= FloorDB.count():
			floor_index = FloorDB.count() - 1
			return false
	return true


## How far through the run we are, from 0 to 1.
func progress() -> float:
	return float(rooms_cleared) / float(FloorDB.total_rooms())


# ----------------------------------------------------------------------
# Items
# ----------------------------------------------------------------------

func add_item(id: String) -> void:
	if ItemDB.is_treat(id):
		heal(int(ItemDB.TREATS[id].get("heal", 0)))
		metrics["items"].append(id)
		return
	if not ItemDB.ITEMS.has(id):
		return
	var before := stats.combos.duplicate()
	items[id] = int(items.get(id, 0)) + 1
	if not item_order.has(id):
		item_order.append(id)
	metrics["items"].append(id)
	_rebuild_stats()
	var healing := int(ItemDB.ITEMS[id].get("heal_on_pick", 0))
	if healing > 0:
		heal(healing)
	items_changed.emit()
	for combo_id: String in stats.combos:
		if not before.has(combo_id):
			metrics["combos"].append(combo_id)
			combo_found.emit(combo_id)


func _rebuild_stats() -> void:
	stats = PlayerStats.build(items)
	var new_max := mini(START_HP + int(difficulty_def()["hearts"]) + stats.max_hp_bonus, HP_CAP)
	if new_max != max_hp:
		max_hp = new_max
		hp = mini(hp, max_hp)
		hp_changed.emit()


# ----------------------------------------------------------------------
# Hearts
# ----------------------------------------------------------------------

func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit()


## Takes hearts away. Returns true if the keeper has none left.
func lose_hp(amount: int, source: String) -> bool:
	hp = maxi(hp - amount, 0)
	hit_this_room = true
	unhurt_streak = 0
	metrics["hits_by"][source] = int(metrics["hits_by"].get(source, 0)) + amount
	hp_changed.emit()
	return hp <= 0


# ----------------------------------------------------------------------
# Rooms
# ----------------------------------------------------------------------

func room_started() -> void:
	hit_this_room = false


## Called when the last enemy in a room falls.
func room_cleared(seconds: float, hits_taken: int, kind: String) -> void:
	rooms_cleared += 1
	if not hit_this_room:
		unhurt_streak += 1
	metrics["rooms"].append({
		"floor": floor_index, "room": room_index, "kind": kind,
		"time": snappedf(seconds, 0.1), "hits": hits_taken,
	})
	var every := stats.tide_every()
	if every > 0 and rooms_cleared % every == 0:
		heal(1)
	if kind == "boss":
		heal(BOSS_HEAL)


## Extra damage from Keeper's Log (1.0 = none).
func log_bonus() -> float:
	return 1.0 + 0.05 * stats.logbook * minf(unhurt_streak, 10.0)


func note_damage(amount: float, source: String) -> void:
	metrics["damage_by"][source] = float(metrics["damage_by"].get(source, 0.0)) + amount


# ----------------------------------------------------------------------
# Echo tapes
# ----------------------------------------------------------------------

func push_tape(tape: EchoTape) -> void:
	if tape == null or tape.size() < 30:
		return   # too short to be worth replaying
	tapes.append(tape)
	while tapes.size() > 3:
		tapes.pop_front()


## The tapes that play in the next room, newest first.
func tapes_to_play() -> Array[EchoTape]:
	var out: Array[EchoTape] = []
	var want := stats.echo_count
	var i := tapes.size() - 1
	while i >= 0 and out.size() < want:
		out.append(tapes[i])
		i -= 1
	return out


# ----------------------------------------------------------------------
# End of a run
# ----------------------------------------------------------------------

func end_run(won: bool, killer: String, last_tape: EchoTape) -> void:
	if not run_active:
		return
	run_active = false
	metrics["result"] = "win" if won else "death"
	metrics["killer"] = killer
	metrics["floor"] = floor_index
	metrics["room"] = room_index
	metrics["rooms_cleared"] = rooms_cleared
	metrics["time"] = snappedf(run_time, 0.1)
	metrics["final_hp"] = hp
	metrics["held"] = items.duplicate()
	if bot_mode:
		return
	total_runs += 1
	if won:
		total_wins += 1
	best_rooms = maxi(best_rooms, rooms_cleared)
	_save_records()
	# Your last moments echo into the first room of your next run.
	if not won and last_tape != null and last_tape.size() >= 30:
		_save_death_echo(last_tape)


func _save_death_echo(tape: EchoTape) -> void:
	var file := FileAccess.open(DEATH_ECHO_PATH, FileAccess.WRITE)
	if file != null:
		file.store_var(tape.to_dict())


func _load_death_echo() -> EchoTape:
	if not FileAccess.file_exists(DEATH_ECHO_PATH):
		return null
	var file := FileAccess.open(DEATH_ECHO_PATH, FileAccess.READ)
	if file == null:
		return null
	var data: Variant = file.get_var()
	if not (data is Dictionary):
		return null
	var tape := EchoTape.from_dict(data)
	if tape.size() < 30:
		return null
	tape.from_past_run = true
	return tape


func _load_records() -> void:
	var file := ConfigFile.new()
	if file.load(RECORDS_PATH) != OK:
		return
	total_runs = int(file.get_value("records", "runs", 0))
	total_wins = int(file.get_value("records", "wins", 0))
	best_rooms = int(file.get_value("records", "best_rooms", 0))


func _save_records() -> void:
	var file := ConfigFile.new()
	file.set_value("records", "runs", total_runs)
	file.set_value("records", "wins", total_wins)
	file.set_value("records", "best_rooms", best_rooms)
	file.save(RECORDS_PATH)
