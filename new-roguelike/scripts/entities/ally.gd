extends Node2D
## Ally: the companion who walks with the knight through a level and fights beside him.
## Who she is and her numbers: scripts/data/allies.gd. player.gd makes one (`player.ally`) when a
## companion travels with him; run.gd moves her from room to room with him.
## What she does:
##   no monsters   she walks a few steps behind him
##   a fight       she stays near him but away from the nearest monster ("keep"), and shoots the
##                 nearest one in reach ("rate", "range", "damage" x the knight's own blow)
##   hurt          a monster's body or shot that touches her costs half a heart (then a moment of
##                 safety). Monsters do not hunt her: they are after the knight.
##   down          at no health she is knocked down; she gets up, whole, when the room is clear.
## Her hearts show as small pips over her head while a fight is on. All code-drawn.

const Allies = preload("res://scripts/data/allies.gd")
const Shots = preload("res://scripts/run/shots.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const Hands = preload("res://scripts/entities/hands.gd")

const SPEED := 84.0
const RADIUS := 4.5
const SAFE_TIME := 0.9           ## seconds of safety after a hit

var run: Node
var player: Node
var row: Dictionary
var hp := 6
var max_hp := 6
var down := false
var body: AnimatedSprite2D
var hands: RefCounted
var _fire_cd := 0.6
var _safe := 0.0
var _face := 1.0
var _moving := false
var _has_run := false
var _has_death := false
var _mid := 10.0
var _top := 26.0
var _flash := 0.0


func setup(the_run: Node, the_player: Node, ally_row: Dictionary) -> void:
	run = the_run
	player = the_player
	row = ally_row
	max_hp = Allies.max_hp(row)
	hp = max_hp
	var sprite_id := String(row["sprite"])
	var m := Art.meta(sprite_id)
	var bw := float(m.get("body_width", 16.0))
	var bh := float(m.get("body_height", 28.0))
	_mid = bh * 0.4
	_top = bh
	_has_run = Art.has_anim(sprite_id, "run")
	_has_death = Art.has_anim(sprite_id, "death")
	add_child(EnemyScript.make_shadow(clampf(bw * 0.85, 11.0, 18.0)))
	body = Art.sprite(sprite_id)
	body.position = Vector2(0, 2)
	add_child(body)
	if String(row.get("hands", "")) != "":
		hands = Hands.new()
		hands.build(self, body, String(row["hands"]), bw, bh)


## run.gd calls this when the knight walks into a room: she steps in beside him.
func entered_room() -> void:
	position = player.position + Vector2(-10.0 if not player.body.flip_h else 10.0, 3.0)
	_fire_cd = 0.6
	if down:
		_get_up()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or run.room == null:
		return
	var room: Node = run.room
	_safe = maxf(_safe - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	var foes: Array = []
	for e in room.enemies:
		if is_instance_valid(e) and not e.dead and e.hittable:
			foes.append(e)
	if down:
		if foes.is_empty() and not player.dead:
			_get_up()
		queue_redraw()
		return
	if player.dead:
		return
	# ---- where she wants to stand
	var near: Node = null
	var near_d := INF
	for e: Node in foes:
		var d: float = (e.position as Vector2).distance_to(position)
		if d < near_d:
			near_d = d
			near = e
	var goal: Vector2
	if near == null:
		var back := Vector2(-22.0, 4.0)
		if player.body.flip_h:
			back.x = -back.x
		goal = (player.position as Vector2) + back
	else:
		# beside the knight, on the side away from the nearest monster; further off if it comes close
		var away: Vector2 = ((player.position as Vector2) - (near.position as Vector2)).normalized()
		goal = (player.position as Vector2) + away * 24.0
		var keep := float(row.get("keep", 58.0))
		if near_d < keep:
			goal = position + (position - (near.position as Vector2)).normalized() * (keep - near_d + 8.0)
	goal.x = clampf(goal.x, 8.0, G.ROOM_W - 8.0)
	goal.y = clampf(goal.y, 8.0, G.ROOM_H - 8.0)
	var to := goal - position
	_moving = to.length() > 5.0
	if _moving:
		var step := to.normalized() * SPEED * (1.25 if to.length() > 60.0 else 1.0) * delta
		var before := position
		position = room.move_circle(position, RADIUS, step, false, false)
		if absf(position.x - before.x) > 0.05:
			_face = signf(position.x - before.x)
		_moving = position.distance_to(before) > 0.05
	# ---- shooting
	_fire_cd -= delta
	if near != null and _fire_cd <= 0.0 and near_d <= float(row.get("range", 130.0)):
		_fire_cd = 1.0 / maxf(float(row.get("rate", 1.0)), 0.1)
		var from := position - Vector2(0, 2)
		var aim: Vector2 = ((near.position as Vector2) - from).normalized()
		var damage: float = player.stats.v("damage") * float(row.get("damage", 0.55))
		run.shots.fire(from + aim * 6.0, aim * float(row.get("shot_speed", 175.0)), Shots.SIDE_PLAYER, damage,
			float(row.get("range", 130.0)) + 20.0, String(row.get("shot", "hex")), {"knock": 0.5, "bits": Shots.B_HERO})
		_face = 1.0 if aim.x >= 0.0 else -1.0
		Sfx.play("player_shoot_magic", -12.0, 0.08, 1.25)
	# ---- what touches her
	if _safe <= 0.0:
		for e: Node in foes:
			if e.get("harmful") == false or int(e.get("touch")) <= 0:
				continue
			if (e.position as Vector2).distance_to(position) < float(e.radius) + RADIUS:
				_hurt()
				break
	if _safe <= 0.0:
		var shots: Node = run.shots
		for i in shots.count:
			if shots.side[i] != Shots.SIDE_ENEMY or shots.left[i] <= 0.0:
				continue
			if (shots.pos[i] - Vector2(0.0, 7.0)).distance_to(position - Vector2(0, _mid)) < float(shots.rad[i]) + RADIUS + 1.0:
				shots.left[i] = 0.0
				_hurt()
				break
	_look(delta, not foes.is_empty())


func _look(delta: float, fighting: bool) -> void:
	body.flip_h = _face < 0.0
	var anim := "run" if _moving and _has_run else "idle"
	if body.animation != anim:
		body.play(anim)
	body.modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else (Color(1, 1, 1, 0.55) if _safe > 0.0 and fmod(_safe, 0.2) < 0.1 else Color.WHITE)
	if hands != null:
		hands.update(delta, _moving, _face)
	if fighting or hp < max_hp:
		queue_redraw()


func _hurt() -> void:
	hp -= 1
	_safe = SAFE_TIME
	_flash = 0.08
	run.fx.burst(position - Vector2(0, _mid), [Color(1, 1, 1), Color(1.0, 0.9, 0.6)], 5, 60.0, 0.25, 2.0)
	Sfx.play("player_hurt", -9.0, 0.05, 1.3)
	if hp <= 0:
		_fall()
	queue_redraw()


func _fall() -> void:
	down = true
	hp = 0
	_moving = false
	if hands != null:
		hands.hide()
	if _has_death:
		body.play("death")
	else:
		body.rotation = PI * 0.5 * _face
		body.position = Vector2(0, -3)
	body.modulate = Color(0.75, 0.75, 0.8)
	G.toast.emit("%s is down" % String(row["name"]), "She gets up when the room is clear.")


func _get_up() -> void:
	down = false
	hp = max_hp
	_safe = SAFE_TIME
	body.rotation = 0.0
	body.position = Vector2(0, 2)
	body.modulate = Color.WHITE
	body.play("idle")
	run.fx.ring(position - Vector2(0, _mid), 14.0, 3.0, 0.35, Color(1.0, 0.92, 0.55, 0.9), 2.0)
	run.fx.sparkle(position - Vector2(0, _mid), Color(1.0, 0.95, 0.6))
	queue_redraw()


## Her hearts as pips over her head: only while a fight is on or she is hurt.
func _draw() -> void:
	if run == null or run.room == null:
		return
	if hp >= max_hp and run.room.enemies.is_empty():
		return
	@warning_ignore("integer_division")
	var pips := (max_hp + 1) / 2
	var w := pips * 4 - 1
	for k in pips:
		var x := -w / 2.0 + k * 4.0
		var left := hp - k * 2
		draw_rect(Rect2(x - 0.5, -_top - 6.5, 4, 4), Color(0.05, 0.04, 0.07, 0.8))
		if left >= 2:
			draw_rect(Rect2(x, -_top - 6.0, 3, 3), Color(0.95, 0.3, 0.3))
		elif left == 1:
			draw_rect(Rect2(x, -_top - 6.0, 1.5, 3), Color(0.95, 0.3, 0.3))
