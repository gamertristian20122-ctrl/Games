class_name BotBrain
extends RefCounted
## The test bot's brain. It looks at the room and decides what to "press".
##
## It only sees what a player could see (enemies, shots, walls) and only
## acts through the same PlayerInput a human uses, so its results say
## something real about how hard the game is.
##
## Three skill levels stand in for three kinds of player:
##   "new"  slow to react, sloppy aim, never dashes
##   "ok"   an average player
##   "pro"  quick, accurate, dashes out of trouble

const SKILLS := {
	# think_every: game ticks between decisions (60 ticks = 1 second), so reaction time
	# aim_error:   how many degrees the aim wobbles
	# see_shots:   how far away it notices enemy shots
	# watch_shots / watch_enemies: how many threats it can keep track of at once
	# look_ahead:  how many seconds ahead it imagines its own movement
	# noise:       how often it misjudges a move (bigger = sloppier)
	# dash:        chance to dash when in trouble
	# lead:        how well it aims ahead of moving enemies (0 = not at all)
	# keep_away:   the distance it likes to keep from enemies
	# lazy:        how much it likes standing still
	# unison:      how much it values standing near its echo
	# smart_picks: chance to choose a reward thoughtfully instead of at random
	"new": {"think_every": 15, "aim_error": 13.0, "see_shots": 44.0, "watch_shots": 3, "watch_enemies": 3,
			"look_ahead": 0.25, "noise": 14.0, "dash": 0.0, "lead": 0.0, "keep_away": 52.0, "lazy": 0.5,
			"unison": 0.0, "smart_picks": 0.0},
	"ok": {"think_every": 9, "aim_error": 6.0, "see_shots": 70.0, "watch_shots": 6, "watch_enemies": 5,
			"look_ahead": 0.38, "noise": 7.0, "dash": 0.5, "lead": 0.5, "keep_away": 72.0, "lazy": 0.1,
			"unison": 2.0, "smart_picks": 0.6},
	"pro": {"think_every": 4, "aim_error": 2.0, "see_shots": 105.0, "watch_shots": 14, "watch_enemies": 9,
			"look_ahead": 0.5, "noise": 1.5, "dash": 1.0, "lead": 1.0, "keep_away": 84.0, "lazy": 0.0,
			"unison": 4.0, "smart_picks": 1.0},
}

const DIRECTIONS := 12

var skill_name := "ok"
var skill: Dictionary = SKILLS["ok"]
var rng := RandomNumberGenerator.new()

var _tick := 0
var _move := Vector2.ZERO
var _aim := Vector2.RIGHT
var _shoot := false
var _blind_time := 0.0          # how long the target has been hidden behind something
var _stuck_time := 0.0
var _last_pos := Vector2.ZERO
var _nudge := Vector2.ZERO
var _nudge_time := 0.0


func setup(level: String, seed_value: int) -> void:
	skill_name = level if SKILLS.has(level) else "ok"
	skill = SKILLS[skill_name]
	rng.seed = seed_value
	# Forget everything from the run before, so a seed always plays out the same way.
	_tick = 0
	_move = Vector2.ZERO
	_aim = Vector2.RIGHT
	_shoot = false
	_blind_time = 0.0
	_stuck_time = 0.0
	_last_pos = Vector2.ZERO
	_nudge = Vector2.ZERO
	_nudge_time = 0.0


## Called every tick by the keeper. Fills in "out" with what to do.
func think(keeper: Player, room: Room, out: PlayerInput) -> void:
	_tick += 1
	out.dash = false
	var every := int(skill["think_every"])
	if _tick % every == 0 or _tick == 1:
		var dt := every / 60.0
		if room.state == "fighting":
			out.dash = _decide_fight(keeper, room, dt)
		else:
			_decide_walk(keeper, room, dt)
	out.move = _move
	out.aim = _aim
	out.shoot = _shoot


# ----------------------------------------------------------------------
# Between fights: fetch the chest, then head for the door
# ----------------------------------------------------------------------

func _decide_walk(keeper: Player, room: Room, dt: float) -> void:
	_shoot = false
	var goal := Room.CENTER
	if room.exit_open:
		goal = room.exit_position() + Vector2(8.0, 0.0)
	elif room.state == "cleared":
		goal = room.chest_position()
	else:
		_move = Vector2.ZERO
		return
	_move = room.dir_toward(keeper.position, goal)
	if _move != Vector2.ZERO:
		_aim = _move

	# If we stop making progress, wiggle free.
	_stuck_time = _stuck_time + dt if keeper.position.distance_to(_last_pos) < 1.5 else 0.0
	_last_pos = keeper.position
	if _stuck_time > 1.0:
		_stuck_time = 0.0
		_nudge = Vector2.from_angle(rng.randf() * TAU)
		_nudge_time = 0.5
	if _nudge_time > 0.0:
		_nudge_time -= dt
		_move = _nudge


# ----------------------------------------------------------------------
# During a fight
# ----------------------------------------------------------------------

## Picks a target, an aim and a direction to walk. Returns true to dash.
func _decide_fight(keeper: Player, room: Room, dt: float) -> bool:
	var stats := Game.stats
	var here := keeper.position
	var target := _pick_target(here, room)
	if target == null:
		# Nothing to shoot yet: drift toward the middle of the room.
		_shoot = false
		_move = (Room.CENTER - here).limit_length(1.0) if here.distance_to(Room.CENTER) > 30.0 else Vector2.ZERO
		return false

	# --- Aim ---
	var aim_at := target.position
	var lead := float(skill["lead"])
	if lead > 0.0:
		var flight := here.distance_to(target.position) / maxf(stats.shot_speed, 1.0)
		aim_at += target.velocity * flight * lead
	var error := deg_to_rad(float(skill["aim_error"])) * (rng.randf() + rng.randf() - 1.0)
	_aim = (aim_at - here).normalized().rotated(error)
	_shoot = true

	var sees_target := room.clear_line(here, target.position)
	_blind_time = 0.0 if sees_target else _blind_time + dt
	var path_hint := Vector2.ZERO
	if _blind_time > 0.8:
		# The target is hiding behind something: walk to a spot we can shoot it from.
		path_hint = room.dir_toward(here, room.vantage_point(target.position, 56.0))

	# --- Gather what is dangerous nearby ---
	var see := float(skill["see_shots"])
	var shots: Array[Shot] = []
	for shot: Shot in room.enemy_shots():
		if shot.position.distance_squared_to(here) <= see * see:
			shots.append(shot)
	# Nobody can track everything at once: keep only the nearest few threats.
	shots.sort_custom(func(a: Shot, b: Shot) -> bool:
		return a.position.distance_squared_to(here) < b.position.distance_squared_to(here))
	if shots.size() > int(skill["watch_shots"]):
		shots.resize(int(skill["watch_shots"]))
	var foes: Array[Enemy] = []
	for enemy: Enemy in room.enemies:
		if not enemy.dead:
			foes.append(enemy)
	foes.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_squared_to(here) < b.position.distance_squared_to(here))
	if foes.size() > int(skill["watch_enemies"]):
		foes.resize(int(skill["watch_enemies"]))

	# --- Score a ring of directions (and standing still) and pick the best ---
	var look := float(skill["look_ahead"])
	var walk_speed := stats.move_speed
	var best_score := -INF
	var best_dir := Vector2.ZERO
	for i in DIRECTIONS + 1:
		var dir := Vector2.ZERO if i == DIRECTIONS else Vector2.from_angle(TAU * float(i) / float(DIRECTIONS))
		var score := _score_move(dir, here, walk_speed, look, room, target, shots, foes, path_hint)
		score += float(skill["noise"]) * (rng.randf() - 0.5)
		if score > best_score:
			best_score = score
			best_dir = dir
	_move = best_dir

	# --- Dash out of trouble ---
	var dash_skill := float(skill["dash"])
	if dash_skill > 0.0 and keeper.dash_ready() and best_dir != Vector2.ZERO:
		if best_score < -70.0 or _about_to_be_hit(here, shots):
			# Only dash if the landing spot is open floor with nobody standing on it.
			var landing := here + best_dir * 48.0
			if not room.blocks_walk(landing) and room.nearest_enemy(landing, 22.0) == null:
				return rng.randf() < dash_skill
	return false


func _pick_target(here: Vector2, room: Room) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for enemy: Enemy in room.enemies:
		if enemy.dead or not enemy.targetable:
			continue
		var score := here.distance_to(enemy.position)
		if not room.clear_line(here, enemy.position):
			score += 80.0
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _score_move(dir: Vector2, here: Vector2, walk_speed: float, look: float,
		room: Room, target: Enemy, shots: Array[Shot], foes: Array[Enemy], path_hint: Vector2) -> float:
	var end := here + dir * walk_speed * look
	var mid := here + dir * walk_speed * look * 0.5
	if dir != Vector2.ZERO and (room.blocks_walk(end) or room.blocks_walk(mid)):
		return -1000.0
	var score := 0.0

	# Enemy shots: where will each be when we get there?
	var parts := maxi(2, int(ceil(look / 0.13)))
	for shot: Shot in shots:
		for part in parts:
			var t := look * float(part + 1) / float(parts)
			var me := here + dir * walk_speed * t
			var d := me.distance_to(shot.position + shot.velocity * t)
			if d < 9.0:
				score -= 100.0
			elif d < 20.0:
				score -= (20.0 - d) * 3.0

	# Enemies: do not get touched, and keep a comfortable distance.
	var keep := float(skill["keep_away"])
	for enemy: Enemy in foes:
		var touch := enemy.radius + 11.0
		if not enemy.targetable:
			touch += 14.0      # something is about to come up out of the floor
		# Would we bump into it anywhere along the way?
		var bumped := false
		for part in parts:
			var t := look * float(part + 1) / float(parts)
			if (here + dir * walk_speed * t).distance_to(enemy.position + enemy.velocity * t) < touch:
				bumped = true
				break
		var d := end.distance_to(enemy.position + enemy.velocity * look)
		if bumped:
			score -= 85.0
		elif d < keep:
			score -= (keep - d) * 0.8
		# Stay out of the line of anything winding up a charge.
		if enemy.state == "windup" or enemy.state == "rush":
			var tip := enemy.position + enemy.facing * 190.0
			var closest := Geometry2D.get_closest_point_to_segment(end, enemy.position, tip)
			var gap := closest.distance_to(end)
			if gap < 16.0:
				score -= 60.0 - gap * 2.0

	# Do not drift too far from the target, and prefer a clear line to it.
	var to_target := end.distance_to(target.position)
	if to_target > 115.0:
		score -= (to_target - 115.0) * 0.35
	# Our shots must actually reach it.
	var reach := Game.stats.shot_speed * Game.stats.shot_life * 0.85
	if to_target > reach:
		score -= (to_target - reach) * 2.0
	if room.clear_line(end, target.position):
		score += 9.0
	if path_hint != Vector2.ZERO:
		score += 24.0 * dir.dot(path_hint)

	# Stay off the walls, where it is easy to get cornered.
	var edge := minf(minf(end.x - 16.0, 464.0 - end.x), minf(end.y - 16.0, 224.0 - end.y))
	if edge < 22.0:
		score -= (22.0 - edge) * 0.9

	# Use the twist: stand near the echo when it is safe to.
	var unison := float(skill["unison"])
	if unison > 0.0:
		for echo: Echo in room.echoes:
			if echo.solid and end.distance_to(echo.position) <= Game.stats.unison_radius:
				score += unison
				break

	score += 2.5 * dir.dot(_move)                      # keep going the way we were going
	if dir == Vector2.ZERO:
		score += 18.0 * float(skill["lazy"])           # beginners stand still a lot
	return score


## True if an enemy shot will reach the keeper within a moment.
func _about_to_be_hit(here: Vector2, shots: Array[Shot]) -> bool:
	for shot: Shot in shots:
		var future := shot.position + shot.velocity * 0.16
		var closest := Geometry2D.get_closest_point_to_segment(here, shot.position, future)
		if closest.distance_to(here) < 7.5:
			return true
	return false


# ----------------------------------------------------------------------
# Choosing a reward
# ----------------------------------------------------------------------

## Picks one of the offered rewards. Beginners pick at random; better
## players take healing when hurt and go for combos and stacks.
func choose_reward(offers: Array[String]) -> String:
	if offers.is_empty():
		return ""
	if rng.randf() >= float(skill["smart_picks"]):
		return offers[rng.randi() % offers.size()]
	var best := offers[0]
	var best_score := -INF
	for id: String in offers:
		var score := rng.randf() * 4.0
		if ItemDB.is_treat(id):
			var missing := Game.max_hp - Game.hp
			score += 40.0 if Game.hp <= 2 else (12.0 if missing >= 2 else -20.0)
		else:
			var item: Dictionary = ItemDB.ITEMS[id]
			score += 10.0 + 4.0 * int(item["rarity"])
			if not ItemDB.combos_completed_by(id, Game.items).is_empty():
				score += 12.0
			if int(Game.items.get(id, 0)) > 0:
				score += 3.0
			if id == "driftwood_charm" and Game.hp <= 3:
				score += 8.0
		if score > best_score:
			best_score = score
			best = id
	return best
