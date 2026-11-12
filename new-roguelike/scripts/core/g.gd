extends Node
## G (autoload): constants, the event bus, and command-line flags.
## This file is the CONTRACT between the two halves of the game:
##   "world"  = scripts/run, scripts/entities, scripts/data  (rooms, combat, content)
##   "shell"  = scripts/main.gd, scripts/ui                  (menus, HUD, touch controls)
## The world emits these signals and exposes G.run; the shell listens and draws.
## Neither half reaches into the other's nodes beyond what is written here.

# ------------------------------------------------------------------ geometry
const TILE := 16
const ROOM_COLS := 17                    ## floor tiles across
const ROOM_ROWS := 7                     ## floor tiles down
const ROOM_W := ROOM_COLS * TILE         ## 272
const ROOM_H := ROOM_ROWS * TILE         ## 112
## World space: the room FLOOR spans (0,0)..(ROOM_W,ROOM_H). Walls sit outside that rectangle
## (a back wall 48 px tall above, 16 px of wall left, right and below: 304 x 176 in all).
## One room is on screen at a time.
const ROOM_CENTER := Vector2(ROOM_W / 2.0, ROOM_H / 2.0)
## Where the camera looks so floor + walls are centred on a 180 px tall screen.
const CAMERA_CENTER := Vector2(ROOM_W / 2.0, ROOM_H / 2.0 - 16.0)
## The viewport is always 180 game-pixels tall; its width grows with the screen
## (320 on a 16:9 screen, 400 on a 20:9 phone). Never assume 320 wide.
const BASE_H := 180

# Doors sit in the middle tile of each wall: column 8 for up/down, row 3 for left/right.
const DOOR_COL := 8
const DOOR_ROW := 3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# CanvasLayer numbers so overlays stack the same way everywhere.
const QUIT_WAIT := 0.25                  ## real seconds G.quit() waits for the sounds to stop
const LAYER_HUD := 10
const LAYER_TOUCH := 15
const LAYER_MENU := 20
const LAYER_FADE := 30

enum RoomType { START, COMBAT, TREASURE, SHOP, SECRET, BOSS, ALTAR }

# Health is counted in HALF hearts everywhere (6 = three full hearts).

# ------------------------------------------------------------------ the running game
## The current run node (scripts/run/run.gd), or null on the menus. Set by the run itself.
## What the shell may read from it:
##   run.hero_id: String            run.floor_index: int (0-based)     run.floor_name: String
##   run.floor_count: int           run.time_s: float                  run.kills: int
##   run.cur: Vector2i              (map coordinate of the current room)
##   run.rooms: Dictionary          Vector2i -> { "type": RoomType, "visited": bool, "seen": bool, "cleared": bool }
##                                  ("seen" = shown on the minimap because a neighbour was visited)
##   run.player                     .hp .max_hp .armor (all half hearts)  .coins .keys .bombs (ints)
##                                  .items: Array[String] (item ids, in pickup order)
##                                  .familiars: Array (nodes)   .global_position
##   run.boss                       null, or a node with .display_name: String  .hp: float  .max_hp: float
##   run.curse_level: int (0-5)     run.belly: int (coins inside the Curse)    run.belly_cap(): int
##   run.call_fill: float           0..1, how far the CALL cooldown has recovered (1 = ready)
##   run.call_ready: bool           pressing CALL (Controls.action_pressed) would work right now
##   run.call_pulse: bool           the first-run lesson wants the CALL button to pulse
##   run.summary() -> Dictionary    { victory, hero, floor, floor_name, time_s, kills, coins, items, rooms_cleared,
##                                    secrets_found, bosses, damage_taken, cause }
## What the shell may call:
##   var run = load("res://scripts/run/run.gd").new(); parent.add_child(run); run.setup(hero_id, seed)
##   run.queue_free()               ends it (the run cleans up after itself and sets G.run = null)
## Pausing: the shell sets get_tree().paused. World nodes keep the default process mode, so they stop.
var run: Node = null
## What the camp (scripts/hub/hub.gd) asks of the NEXT run; the run reads it once and empties it:
##   "floor": 1-4    the stage to start on (a later stage also hands out STAGE_ITEMS items per skipped floor)
##   "pack": {"coins": n, "bombs": n, "keys": n}    quest rewards the hero sets out with
var next_run := {}


## The Easy / Normal / Hard switch in Settings (the owner asked for it on 11 Nov 2026).
##   enemy_hp   every monster's and boss's health x this      budget   monsters more or fewer per room
##   hearts     half hearts the hero starts with on top       block    blows his guard stops before it breaks
##   boss_hp    a boss's health x this, on top               speed    how fast monsters move (not bosses)
const DIFFICULTY := {
	"easy": {"enemy_hp": 0.9, "budget": 1.0, "hearts": 2, "block": 3, "boss_hp": 1.0, "speed": 1.0},
	"normal": {"enemy_hp": 1.25, "budget": 3.0, "hearts": 0, "block": 2, "boss_hp": 1.3, "speed": 1.12},
	"hard": {"enemy_hp": 1.6, "budget": 5.0, "hearts": 0, "block": 2, "boss_hp": 1.7, "speed": 1.22},
}
## (v0.10.0: the owner finished the whole of v0.9 in five minutes, so every row went up: Easy is now
## about what Normal was. "boss_hp" multiplies a boss's health ON TOP of enemy_hp.)
## Monsters also toughen with what the hero carries: +ITEM_HP for each item, up to ITEM_HP_CAP items.
const ITEM_HP := 0.04
const ITEM_HP_CAP := 15
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const DIFFICULTY_IDS := ["easy", "normal", "hard"]


func diff(key: String) -> float:
	var id := "normal" if flag("autotest") else String(Save.setting("difficulty"))
	return float((DIFFICULTY.get(id, DIFFICULTY["normal"]) as Dictionary).get(key, 0.0))


## The Hungry Curse (the black disc) was taken out of the game on 11 Nov 2026 at the owner's request.
## Its code and tests are kept but switched off; --withcurse turns it back on for the old tests.
func curse_on() -> bool:
	return flag("withcurse")
## True while the hero in the camp stands next to someone (the touch TALK button lights up).
var hub_near := false
## The time of day in the world outside the hill, in seconds (scripts/hub/hub.gd turns it into
## morning, dusk and night; kept in the save between sessions).
var world_clock := -1.0

# ------------------------------------------------------------------ event bus (world -> shell)
signal run_started(run: Node)
signal floor_started(floor_index: int, floor_name: String)
signal room_entered(coord: Vector2i, room_type: int, first_visit: bool)
signal room_cleared(coord: Vector2i)
## Anything the HUD shows changed: hearts, coins, keys, bombs, items, familiars, map.
signal hud_changed
signal player_hurt(half_hearts: int)
signal player_died
## The shell shows the item card (name + description from scripts/data/items.gd).
signal item_acquired(item_id: String)
## kind: "coin", "key", "bomb", "heart", "armor". The shell may play a HUD tick.
signal pickup_collected(kind: String, amount: int)
signal boss_started(boss: Node)
signal boss_defeated(boss_id: String)
## A short banner in the middle of the screen (room names, "Secret found", warnings).
signal toast(title: String, subtitle: String)
## The hero picked up a note in a level (scripts/entities/note.gd): the shell shows its words.
signal note_found(index: int)
## The run is over. The shell shows the death or victory screen and records unlocks.
signal run_ended(victory: bool, summary: Dictionary)
## Free-form counters for unlocks and achievements, e.g. ("secret_found", 1), ("boss_killed:gravekeeper", 1).
## The shell adds them to the save file and checks unlock rules.
signal stat(key: String, amount: int)
## RPG (scripts/data/rpg.gd): the knight earned XP / reached a new level (the shell shows the card choice).
signal xp_changed
signal level_up(level: int)
## The world asks for a short vibration (the touch layer does it if the setting allows).
signal buzz(msec: int)

# ------------------------------------------------------------------ command-line flags
## Flags after "--" on the command line, e.g.  godot --path . -- --autotest --hero=witch --seed=7
##   --autotest      skip menus, a bot plays            --hero=<id>     --seed=<n>
##   --speed=<x>     Engine.time_scale                  --time=<sec>    quit after this much game time
##   --shots=<dir>   folder for screenshots (G.save_shot)
## "--flag" becomes args["flag"] = "1"; "--key=value" becomes args["key"] = "value".
var args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if args.has("speed"):
		Engine.time_scale = float(args["speed"])


func flag(name: String) -> bool:
	return args.has(name)


func arg(name: String, default_value: String = "") -> String:
	return String(args.get(name, default_value))


## Closes the game cleanly: use this instead of get_tree().quit(). A sound that is still playing
## at the moment the game closes is never let go ("resources still in use at exit"), so every
## sound is stopped first and the sound system gets a moment of real time to drop it.
var quitting := false
func quit(code: int = 0) -> void:
	if quitting:
		return
	quitting = true
	Sfx.shutdown()
	get_tree().paused = true               # nothing may start a new sound while we wait
	# wait on the real clock, frame by frame (a timer could fire at once after a long first frame)
	var until := Time.get_ticks_msec() + int(QUIT_WAIT * 1000.0)
	var frames := 0
	while Time.get_ticks_msec() < until or frames < 3:
		await get_tree().process_frame
		frames += 1
	get_tree().quit(code)


## Saves a screenshot of the whole screen to the --shots folder (does nothing without --shots).
func save_shot(file_name: String) -> void:
	if not args.has("shots"):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(String(args["shots"]))
	img.save_png(String(args["shots"]).path_join(file_name))


# ------------------------------------------------------------------ small helpers
## Centre of floor tile (col,row) in world space.
func cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE / 2.0, row * TILE + TILE / 2.0)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func in_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < ROOM_COLS and cell.y < ROOM_ROWS
