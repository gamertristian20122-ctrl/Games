class_name BotRunner
extends Node
## Plays many runs in a row with the test bot and saves what happened.
##
## Started from the command line (see tools/run_bot.sh and tools/run_bot.bat):
##   godot --headless --fixed-fps 60 --path . -- --bot --skill=ok --runs=30 --out=bot_out/ok.json
##
## Options (all after the "--"):
##   --skill=new|ok|pro   how well the bot plays (default ok)
##   --runs=30            how many runs to play (default 10)
##   --seed=1             the first run's seed; later runs count up from it
##   --out=file.json      where to save the results
##   --difficulty=1       0 = Calm, 1 = Standard, 2 = Stormy
##   --watch              keep sound and effects on (for watching in a window)

const STALL_SECONDS := 480.0     # give up on a room after this long

var brain := BotBrain.new()
var skill := "ok"
var runs_wanted := 10
var first_seed := 1
var out_path := ""
var watch := false

var _main: Node
var _run_number := 0
var _results: Array = []
var _room_clock := 0.0
var _room_marker := -1
var _started_at := 0


func begin(main: Node, args: Dictionary) -> void:
	_main = main
	skill = args.get("skill", "ok")
	runs_wanted = int(args.get("runs", "10"))
	first_seed = int(args.get("seed", "1"))
	out_path = args.get("out", "")
	watch = args.has("watch")
	Game.bot_mode = true
	Game.fast_mode = not watch
	Game.difficulty = clampi(int(args.get("difficulty", "1")), 0, 2)
	_main.run_ended.connect(_on_run_ended)
	_started_at = Time.get_ticks_msec()
	print("Bot: %d runs at skill '%s', seeds from %d." % [runs_wanted, skill, first_seed])
	_next_run.call_deferred()


func _next_run() -> void:
	if _run_number >= runs_wanted:
		_finish()
		return
	var seed_value := first_seed + _run_number
	_run_number += 1
	brain.setup(skill, seed_value * 31 + 7)
	_room_clock = 0.0
	_room_marker = -1
	_main.begin_run(seed_value)


func _physics_process(delta: float) -> void:
	if not Game.run_active:
		return
	# Notice if the bot has been in the same room for far too long.
	var marker := Game.floor_index * 100 + Game.room_index
	if marker != _room_marker:
		_room_marker = marker
		_room_clock = 0.0
	_room_clock += delta
	if _room_clock > STALL_SECONDS:
		_room_clock = 0.0
		_describe_stall()
		_main.abort_run("stalled")


## Prints what the room looked like when the bot gave up, to help find the cause.
func _describe_stall() -> void:
	var room: Room = _main.room
	var keeper: Player = _main.keeper
	if room == null or keeper == null:
		return
	print("  STALLED on floor %d room %d (%s). Keeper at %s, room state '%s', wave %d of %d." % [
		Game.floor_index + 1, Game.room_index + 1, room.kind, keeper.position.round(), room.state,
		room.wave_index + 1, room.waves.size()])
	for enemy: Enemy in room.enemies:
		print("    %s at %s  hp %.0f/%.0f  state '%s'  targetable %s  clear line %s" % [
			enemy.id, enemy.position.round(), enemy.hp, enemy.max_hp, enemy.state, enemy.targetable,
			room.clear_line(keeper.position, enemy.position)])
	# A little map of the room: K = keeper, E = enemy, # = tall, ~ = low, W = wall.
	for y in Room.ROWS:
		var line := "    "
		for x in Room.COLS:
			var here := Vector2(x * 16.0 + 8.0, y * 16.0 + 8.0)
			var mark := [".", "W", "#", "~"][room.cell_at(here)] as String
			if here.distance_to(keeper.position) < 9.0:
				mark = "K"
			for enemy: Enemy in room.enemies:
				if here.distance_to(enemy.position) < 9.0:
					mark = "E"
			line += mark
		print(line)


func _on_run_ended(_result: String) -> void:
	var record: Dictionary = Game.metrics.duplicate(true)
	record["skill"] = skill
	_results.append(record)
	print("  run %d/%d  seed %d  %s  rooms %d  floor %d  %s" % [
		_run_number, runs_wanted, int(record["seed"]), record["result"],
		int(record["rooms_cleared"]), int(record["floor"]) + 1, record["killer"]])
	_next_run.call_deferred()


func _finish() -> void:
	var seconds := (Time.get_ticks_msec() - _started_at) / 1000.0
	print("Bot finished %d runs in %.1f seconds." % [_results.size(), seconds])
	if out_path != "":
		var dir := out_path.get_base_dir()
		if dir != "":
			DirAccess.make_dir_recursive_absolute(dir)
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_results, "  "))
			print("Saved results to " + out_path)
		else:
			push_error("Could not write " + out_path)
	print(BotReport.summary_line(skill, _results))
	get_tree().quit()
