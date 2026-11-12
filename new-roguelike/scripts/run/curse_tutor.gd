extends Node
## The first-run lesson for the Hungry Curse: four short lines (26 words together), each shown
## once per save profile and never again. The run makes this node only while a lesson is still
## owed; with --autotest it is skipped (add --teach to see it anyway).
##   intro    in the start room; then the first fight is staged so the first lunge feeds itself:
##            four Shamblers stand in a row between the disc and the hero, and the disc lunges early
##   call     right after that first lunge; the CALL button pulses
##   shield   the second fight has a Bone Archer; shown when an enemy shot hits the hero
##   bomb     the first time the hero holds a bomb while the belly has coins in it, during a fight
## To change the words, edit LINES. Each lesson is remembered with Save.set_flag("taught:curse_<key>").

const Curse = preload("res://scripts/entities/curse.gd")

## [title, second line] for the banner in the middle of the screen.
const LINES := {
	"intro": ["Your Curse is awake.", "It eats everything."],
	"call": ["Press CALL", "when monsters stand in its way."],
	"shield": ["Stand behind your Curse.", ""],
	"bomb": ["Bomb your Curse.", "It coughs up coins."],
}
const KEYS: Array[String] = ["intro", "call", "shield", "bomb"]
const FLAG := "taught:curse_"

const INTRO_DELAY := 2.4                 ## seconds into the run (the floor's name is shown first)
const LINEUP_ENEMY := "shambler"         ## the staged first fight
const LINEUP_SPOTS: Array[float] = [0.26, 0.37, 0.48, 0.59]   ## how far along the way from the disc to the hero
const LINEUP_STAND := 1.9                ## seconds they stand still after appearing
const LINEUP_FILL := 1.0                 ## the lunge timer of that first fight (normally 3 s)
const SECOND_FIGHT: Array[String] = ["bone_archer", "shambler", "shambler"]
const PULSE_TIME := 6.0                  ## seconds the CALL button pulses
const BOMB_BELLY := 2                    ## coins in the belly before the bomb hint appears

var run: Node
var staged := 0                          ## fights staged so far in this run
var _time := 0.0
var _intro_due := false
var _stage_fights := false               ## this run began before the intro was taught
var _first_room: Node                    ## the staged first fight (the Curse lunges early there)
var _pulse_t := 0.0


## Is there still something to teach on this profile?
static func wanted() -> bool:
	if not G.curse_on():
		return false
	if G.flag("autotest") and not G.flag("teach"):
		return false
	for key in KEYS:
		if not Save.flag(FLAG + key):
			return true
	return false


func setup(the_run: Node) -> void:
	run = the_run
	_intro_due = not _taught("intro") and run.floor_index == 0
	_stage_fights = _intro_due
	G.player_hurt.connect(_on_player_hurt)
	G.stat.connect(_on_stat)


func _taught(key: String) -> bool:
	return Save.flag(FLAG + key)


func _teach(key: String) -> void:
	Save.set_flag(FLAG + key)
	var line: Array = LINES[key]
	G.toast.emit(String(line[0]), String(line[1]))


# =============================================================================== the staged fights
## Called by the room when a fight starts. Returns [] for a normal fight, or rows
## {"id": enemy id, "pos": Vector2 (Vector2.INF = anywhere), "stand": seconds} to spawn instead.
func fight_lineup(room: Node) -> Array:
	if not _stage_fights or room.type != G.RoomType.COMBAT:
		return []
	staged += 1
	var out: Array = []
	if staged == 1:
		_first_room = room
		# the disc will rise at the spawn point farthest from the hero: line them up on the way
		var hero: Vector2 = run.player.position
		var far := Curse.SPAWN_POINTS[0]
		for p in Curse.SPAWN_POINTS:
			if p.distance_squared_to(hero) > far.distance_squared_to(hero):
				far = p
		for k in LINEUP_SPOTS:
			out.append({"id": LINEUP_ENEMY, "pos": room.free_spot_near(far.lerp(hero, k), false), "stand": LINEUP_STAND})
	elif staged == 2:
		for id in SECOND_FIGHT:
			out.append({"id": id, "pos": Vector2.INF, "stand": 0.0})
	else:
		_stage_fights = false
	return out


## The Curse asks how long its first lunge timer should be in this room.
func first_fill(room: Node, normal: float) -> float:
	return LINEUP_FILL if room == _first_room else normal


# =============================================================================== the lines
func _physics_process(delta: float) -> void:
	if run == null or run.player == null or run.over:
		return
	_time += delta
	if _intro_due and _time >= INTRO_DELAY:
		_intro_due = false
		_teach("intro")
	if _pulse_t > 0.0:
		_pulse_t -= delta
		run.call_pulse = _pulse_t > 0.0
	var room: Node = run.room
	if room == null:
		return
	var curse: Node2D = room.curse
	if curse == null or not is_instance_valid(curse) or not curse.solid:
		return
	if not _taught("call") and curse.state == Curse.WINDED:
		_teach_call()                            # its first lunge is over, whatever it caught
	elif not _taught("bomb") and _taught("call") and _pulse_t <= 0.0 and run.belly >= BOMB_BELLY and run.player.bombs > 0 and curse.state == Curse.CREEP:
		_teach("bomb")
	_check_done()


## The Curse's first meal: now explain CALL.
func _on_stat(key: String, _amount: int) -> void:
	if key == "curse_meals" and not _taught("call"):
		_teach_call()


func _teach_call() -> void:
	_teach("call")
	_pulse_t = PULSE_TIME
	run.call_pulse = true


func _on_player_hurt(_half_hearts: int) -> void:
	if _taught("shield") or run.room == null or run.room.curse == null:
		return
	# was it a shot? (the shot that hit is still next to the hero at this moment)
	var shots: Node = run.shots
	var hero: Vector2 = run.player.position
	for i in shots.count:
		if shots.side[i] == 1 and (shots.pos[i] as Vector2).distance_to(hero) < 12.0:
			_teach("shield")
			return


func _check_done() -> void:
	for key in KEYS:
		if not _taught(key):
			return
	queue_free()


func _exit_tree() -> void:
	if run != null and is_instance_valid(run):
		run.call_pulse = false
		if run.tutor == self:
			run.tutor = null
