extends Node2D
## First playable: room-by-room roguelike shooter, drawn with plain shapes.
## Everything lives in this one file for now; it gets split up when real art goes in.

const W := 1280.0
const H := 720.0
const WALL := 72.0
const DOOR_HALF := 58.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const PLAYER_R := 18.0

enum State { TITLE, PLAY, DEAD }

const ITEMS := [
	{"name": "Sour Battery", "desc": "Fire rate up", "col": Color(0.95, 0.9, 0.3)},
	{"name": "Heavy Core", "desc": "Damage up, shots slower", "col": Color(0.8, 0.35, 0.3)},
	{"name": "Twin Lens", "desc": "One extra shot", "col": Color(0.4, 0.8, 0.95)},
	{"name": "Needle Round", "desc": "Shots pierce enemies", "col": Color(0.85, 0.85, 0.9)},
	{"name": "Seeker Moss", "desc": "Shots curve toward enemies", "col": Color(0.45, 0.85, 0.45)},
	{"name": "Quick Boots", "desc": "Move faster", "col": Color(0.95, 0.6, 0.25)},
	{"name": "Glass Heart", "desc": "One more heart, full heal", "col": Color(0.95, 0.4, 0.6)},
	{"name": "Long Barrel", "desc": "Shots fly further", "col": Color(0.6, 0.55, 0.9)},
]

var state: int = State.TITLE
var rng := RandomNumberGenerator.new()
var font: Font
var time := 0.0
var floor_num := 1
var rooms := {}
var cur := Vector2i.ZERO
var item_pool: Array = []

var p := {}
var enemies: Array = []
var shots: Array = []
var eshots: Array = []
var pickups: Array = []
var particles: Array = []

var msg := ""
var msg_sub := ""
var msg_t := 0.0
var shake := 0.0
var kills := 0

# touch sticks
var move_touch := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var aim_touch := -1
var aim_origin := Vector2.ZERO
var aim_vec := Vector2.ZERO

# self-test bot (run with: -- --autotest --shots=/abs/dir)
var autotest := false
var shot_dir := ""
var shot_times := [1.5, 5.0, 10.0, 16.0]
var bot_dir := Vector2.RIGHT
var bot_t := 0.0
var test_len := 40.0


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--time="):
			test_len = float(a.substr(7))
		elif a.begins_with("--speed="):
			Engine.time_scale = float(a.substr(8))
		elif a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
	if autotest:
		_new_run()


# ---------------------------------------------------------------- run / floor

func _new_run() -> void:
	floor_num = 1
	kills = 0
	item_pool.clear()
	p = {
		"pos": Vector2(W / 2, H / 2), "hp": 6, "max_hp": 6, "inv": 0.0, "cool": 0.0,
		"speed": 300.0, "dmg": 1.0, "rate": 2.6, "shot_speed": 540.0, "range": 0.8,
		"count": 1, "pierce": false, "homing": false, "face": Vector2.DOWN, "items": [],
	}
	_gen_floor()
	state = State.PLAY
	_say("Floor 1", "Clear rooms. Find the boss.")


func _new_room(type: String) -> Dictionary:
	return {"type": type, "cleared": type == "start", "visited": false, "item": -1, "item_taken": false}


func _neighbor_count(c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if rooms.has(c + d):
			n += 1
	return n


func _gen_floor() -> void:
	rooms.clear()
	rooms[Vector2i.ZERO] = _new_room("start")
	var target: int = mini(7 + floor_num * 2, 16)
	var guard := 0
	while rooms.size() < target and guard < 4000:
		guard += 1
		var keys: Array = rooms.keys()
		var base: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var c: Vector2i = base + DIRS[rng.randi_range(0, 3)]
		if rooms.has(c) or _neighbor_count(c) > 1:
			continue
		rooms[c] = _new_room("normal")
	# distance from the start room
	var dist := {Vector2i.ZERO: 0}
	var queue: Array = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if rooms.has(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	var ends: Array = []
	var others: Array = []
	for c in rooms.keys():
		if c == Vector2i.ZERO:
			continue
		if _neighbor_count(c) == 1:
			ends.append(c)
		else:
			others.append(c)
	var by_dist := func(a: Vector2i, b: Vector2i) -> bool: return int(dist[a]) > int(dist[b])
	ends.sort_custom(by_dist)
	others.sort_custom(by_dist)
	var boss: Vector2i = ends[0]
	rooms[boss]["type"] = "boss"
	rooms[boss]["item"] = _draw_item()
	var item_room: Vector2i = ends[1] if ends.size() > 1 else others[0]
	rooms[item_room]["type"] = "item"
	rooms[item_room]["item"] = _draw_item()
	_enter_room(Vector2i.ZERO, Vector2i.ZERO)


func _draw_item() -> int:
	if item_pool.is_empty():
		for i in ITEMS.size():
			item_pool.append(i)
	var k := rng.randi_range(0, item_pool.size() - 1)
	var id: int = item_pool[k]
	item_pool.remove_at(k)
	return id


func _play_rect() -> Rect2:
	return Rect2(WALL, WALL, W - WALL * 2, H - WALL * 2)


func _door_pos(d: Vector2i) -> Vector2:
	return Vector2(W / 2 + d.x * (W / 2 - WALL), H / 2 + d.y * (H / 2 - WALL))


func _enter_room(c: Vector2i, from_dir: Vector2i) -> void:
	cur = c
	enemies.clear()
	shots.clear()
	eshots.clear()
	pickups.clear()
	var room: Dictionary = rooms[c]
	if from_dir != Vector2i.ZERO:
		# we walked in direction from_dir, so we appear at the opposite door
		p["pos"] = _door_pos(-from_dir) + Vector2(from_dir) * (PLAYER_R + 14.0)
	else:
		p["pos"] = Vector2(W / 2, H / 2)
	var first: bool = not room["visited"]
	room["visited"] = true
	match String(room["type"]):
		"item":
			room["cleared"] = true
			if not room["item_taken"]:
				pickups.append({"kind": "item", "pos": Vector2(W / 2, H / 2), "item": room["item"]})
			if first:
				_say("Item room", "")
		"boss":
			if room["cleared"]:
				_boss_rewards(room)
			else:
				_spawn_enemy("boss", Vector2(W / 2, H / 2 - 60))
				_say("BOSS", "")
		"normal":
			if not room["cleared"]:
				var n: int = rng.randi_range(2, 4) + int(floor_num / 2.0)
				for i in n:
					_spawn_enemy(_pick_type(), _free_spot())


func _boss_rewards(room: Dictionary) -> void:
	pickups.append({"kind": "trapdoor", "pos": Vector2(W / 2, H / 2 - 40)})
	if not room["item_taken"]:
		pickups.append({"kind": "item", "pos": Vector2(W / 2, H / 2 + 110), "item": room["item"]})


func _pick_type() -> String:
	var r := rng.randf()
	if floor_num == 1:
		return "chaser" if r < 0.6 else ("shooter" if r < 0.85 else "dasher")
	return "chaser" if r < 0.4 else ("shooter" if r < 0.7 else "dasher")


func _free_spot() -> Vector2:
	var area := _play_rect().grow(-70.0)
	var pos := Vector2.ZERO
	for i in 30:
		pos = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if pos.distance_to(p["pos"]) > 300.0:
			break
	return pos


func _spawn_enemy(type: String, pos: Vector2) -> void:
	var scale_hp: float = 1.0 + 0.3 * (floor_num - 1)
	var e := {"type": type, "pos": pos, "vel": Vector2.ZERO, "t": rng.randf_range(0.6, 1.6),
		"spawn": 0.7, "flash": 0.0, "mode": 0, "dir": Vector2.ZERO, "phase": 0}
	match type:
		"chaser":
			e["r"] = 17.0
			e["hp"] = 3.0 * scale_hp
		"shooter":
			e["r"] = 19.0
			e["hp"] = 4.0 * scale_hp
		"dasher":
			e["r"] = 21.0
			e["hp"] = 5.0 * scale_hp
		"boss":
			e["r"] = 56.0
			e["hp"] = 55.0 * scale_hp
			e["spawn"] = 1.2
			e["t"] = 1.5
	e["max_hp"] = e["hp"]
	enemies.append(e)


func _say(text: String, sub: String) -> void:
	msg = text
	msg_sub = sub
	msg_t = 2.4


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if state != State.PLAY:
				_new_run()
				return
			if event.position.x < get_viewport_rect().size.x / 2:
				if move_touch == -1:
					move_touch = event.index
					move_origin = event.position
					move_vec = Vector2.ZERO
			elif aim_touch == -1:
				aim_touch = event.index
				aim_origin = event.position
				aim_vec = Vector2.ZERO
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vec = Vector2.ZERO
			if event.index == aim_touch:
				aim_touch = -1
				aim_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			move_vec = ((event.position - move_origin) / 70.0).limit_length(1.0)
		elif event.index == aim_touch:
			aim_vec = ((event.position - aim_origin) / 70.0).limit_length(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if state != State.PLAY and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
			_new_run()
	elif event is InputEventJoypadButton and event.pressed and state != State.PLAY:
		_new_run()


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D): v.x += 1
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S): v.y += 1
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() > 0.25: v = joy
	if move_touch != -1: v = move_vec
	return v.limit_length(1.0)


func _read_aim() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() > 0.35: v = joy
	if aim_touch != -1: v = aim_vec
	return v


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	time += delta
	msg_t = maxf(0.0, msg_t - delta)
	shake = maxf(0.0, shake - delta * 30.0)
	if autotest:
		_autotest_tick(delta)
	if state == State.PLAY:
		_update_player(delta)
		_update_shots(delta)
		_update_enemies(delta)
		_update_eshots(delta)
		_update_pickups()
		_check_room_clear()
	_update_particles(delta)
	queue_redraw()


func _doors_open() -> bool:
	return bool(rooms[cur]["cleared"])


func _update_player(delta: float) -> void:
	var mv := _read_move()
	var aim := _read_aim()
	if autotest:
		mv = bot_dir
		aim = _bot_aim()
	var pos: Vector2 = p["pos"]
	pos += mv * float(p["speed"]) * delta
	var area := _play_rect().grow(-PLAYER_R)
	# walking through an open door
	if _doors_open():
		for d in DIRS:
			if not rooms.has(cur + d):
				continue
			var door := _door_pos(d)
			var lined_up: bool = absf(pos.y - door.y) < DOOR_HALF - 8.0 if d.x != 0 else absf(pos.x - door.x) < DOOR_HALF - 8.0
			var pushing: bool = mv.dot(Vector2(d)) > 0.3
			var past: bool = (d.x > 0 and pos.x > area.end.x) or (d.x < 0 and pos.x < area.position.x) \
				or (d.y > 0 and pos.y > area.end.y) or (d.y < 0 and pos.y < area.position.y)
			if lined_up and pushing and past:
				_enter_room(cur + d, d)
				return
	pos.x = clampf(pos.x, area.position.x, area.end.x)
	pos.y = clampf(pos.y, area.position.y, area.end.y)
	p["pos"] = pos
	if mv.length() > 0.2:
		p["face"] = mv.normalized()
	p["inv"] = maxf(0.0, float(p["inv"]) - delta)
	p["cool"] = maxf(0.0, float(p["cool"]) - delta)
	if aim.length() > 0.35:
		p["face"] = aim.normalized()
		if float(p["cool"]) <= 0.0:
			p["cool"] = 1.0 / float(p["rate"])
			_fire(aim.normalized(), mv)


func _fire(dir: Vector2, mv: Vector2) -> void:
	var n: int = p["count"]
	for i in n:
		var spread: float = (i - (n - 1) / 2.0) * 0.16
		var v := dir.rotated(spread) * float(p["shot_speed"]) + mv * float(p["speed"]) * 0.25
		shots.append({"pos": p["pos"] + dir * 16.0, "vel": v, "life": float(p["range"]), "hit": []})


func _update_shots(delta: float) -> void:
	var area := _play_rect()
	for s in shots:
		if p["homing"] and not enemies.is_empty():
			var best: Variant = null
			var best_d := 320.0
			for e in enemies:
				var dd: float = (e["pos"] as Vector2).distance_to(s["pos"])
				if dd < best_d and float(e["spawn"]) <= 0.0:
					best_d = dd
					best = e
			if best != null:
				var want: Vector2 = ((best["pos"] as Vector2) - (s["pos"] as Vector2)).normalized()
				var vel: Vector2 = s["vel"]
				s["vel"] = vel.normalized().slerp(want, minf(1.0, 5.0 * delta)) * vel.length()
		s["pos"] += s["vel"] * delta
		s["life"] -= delta
		if not area.has_point(s["pos"]):
			s["life"] = 0.0
			_burst(s["pos"], Color(0.6, 0.9, 1.0), 3)
			continue
		for e in enemies:
			if float(e["spawn"]) > 0.0 or s["hit"].has(e):
				continue
			if (e["pos"] as Vector2).distance_to(s["pos"]) < float(e["r"]) + 8.0:
				e["hp"] -= float(p["dmg"])
				e["flash"] = 0.1
				e["pos"] += (s["vel"] as Vector2).normalized() * (2.0 if e["type"] == "boss" else 7.0)
				_burst(s["pos"], Color(0.6, 0.9, 1.0), 4)
				if p["pierce"]:
					s["hit"].append(e)
				else:
					s["life"] = 0.0
					break
	shots = shots.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	var dead: Array = enemies.filter(func(e: Dictionary) -> bool: return float(e["hp"]) <= 0.0)
	for e in dead:
		kills += 1
		shake = 10.0 if e["type"] == "boss" else 4.0
		_burst(e["pos"], _enemy_col(e["type"]), 40 if e["type"] == "boss" else 12)
	if not dead.is_empty():
		enemies = enemies.filter(func(e: Dictionary) -> bool: return float(e["hp"]) > 0.0)
		# the boss takes its helpers with it
		if dead.any(func(e: Dictionary) -> bool: return e["type"] == "boss"):
			for e in enemies:
				_burst(e["pos"], _enemy_col(e["type"]), 10)
			enemies.clear()
			eshots.clear()


func _update_enemies(delta: float) -> void:
	var ppos: Vector2 = p["pos"]
	var area := _play_rect()
	var spd_scale: float = 1.0 + 0.06 * (floor_num - 1)
	for e in enemies:
		e["flash"] = maxf(0.0, float(e["flash"]) - delta)
		if float(e["spawn"]) > 0.0:
			e["spawn"] -= delta
			continue
		var pos: Vector2 = e["pos"]
		var to_p: Vector2 = ppos - pos
		var dist := to_p.length()
		var dir: Vector2 = to_p / maxf(dist, 0.001)
		var vel := Vector2.ZERO
		e["t"] -= delta
		match String(e["type"]):
			"chaser":
				vel = dir * 125.0 * spd_scale
			"shooter":
				if dist < 250.0:
					vel = -dir * 95.0
				elif dist > 400.0:
					vel = dir * 95.0
				else:
					vel = dir.orthogonal() * 60.0
				if float(e["t"]) <= 0.0:
					e["t"] = 1.9
					eshots.append({"pos": pos + dir * 18.0, "vel": dir * 250.0 * spd_scale, "life": 4.0})
			"dasher":
				match int(e["mode"]):
					0:  # drift, then pick a line
						vel = dir * 45.0
						if float(e["t"]) <= 0.0:
							e["mode"] = 1
							e["t"] = 0.55
							e["dir"] = dir
					1:  # wind-up: stands still and flashes so the dash can be dodged
						if float(e["t"]) <= 0.0:
							e["mode"] = 2
							e["t"] = 0.45
					2:
						vel = (e["dir"] as Vector2) * 640.0
						if float(e["t"]) <= 0.0:
							e["mode"] = 0
							e["t"] = rng.randf_range(0.9, 1.5)
			"boss":
				vel = dir * 55.0 * spd_scale
				if float(e["t"]) <= 0.0:
					var hurt: bool = float(e["hp"]) < float(e["max_hp"]) * 0.5
					e["t"] = 1.5 if hurt else 2.1
					e["phase"] = int(e["phase"]) + 1
					if int(e["phase"]) % 2 == 0:
						var n := 14 if hurt else 10
						var off := rng.randf() * TAU
						for i in n:
							eshots.append({"pos": pos, "vel": Vector2.RIGHT.rotated(off + TAU * i / n) * 210.0, "life": 5.0})
					else:
						for a in [-0.28, 0.0, 0.28]:
							eshots.append({"pos": pos + dir * 40.0, "vel": dir.rotated(a) * 300.0, "life": 5.0})
						if hurt and enemies.size() < 4:
							_spawn_enemy("chaser", pos + dir.orthogonal() * 110.0)
		pos += vel * delta
		pos.x = clampf(pos.x, area.position.x + float(e["r"]), area.end.x - float(e["r"]))
		pos.y = clampf(pos.y, area.position.y + float(e["r"]), area.end.y - float(e["r"]))
		e["pos"] = pos
		if dist < float(e["r"]) + PLAYER_R - 4.0:
			_hurt_player()
	# keep enemies from stacking on top of each other
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var a: Dictionary = enemies[i]
			var b: Dictionary = enemies[j]
			var d: Vector2 = (b["pos"] as Vector2) - (a["pos"] as Vector2)
			var min_d: float = float(a["r"]) + float(b["r"])
			if d.length() < min_d and d.length() > 0.01:
				var push := d.normalized() * (min_d - d.length()) * 0.5
				if a["type"] != "boss": a["pos"] -= push
				if b["type"] != "boss": b["pos"] += push


func _update_eshots(delta: float) -> void:
	var area := _play_rect()
	for s in eshots:
		s["pos"] += s["vel"] * delta
		s["life"] -= delta
		if not area.has_point(s["pos"]):
			s["life"] = 0.0
		elif (s["pos"] as Vector2).distance_to(p["pos"]) < PLAYER_R + 5.0:
			s["life"] = 0.0
			_hurt_player()
	eshots = eshots.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)


func _hurt_player() -> void:
	if float(p["inv"]) > 0.0 or state != State.PLAY:
		return
	p["hp"] = int(p["hp"]) - 1
	p["inv"] = 1.0
	shake = 8.0
	_burst(p["pos"], Color(1, 0.3, 0.3), 10)
	if int(p["hp"]) <= 0:
		state = State.DEAD
		_burst(p["pos"], Color(0.9, 0.9, 1.0), 30)


func _update_pickups() -> void:
	var ppos: Vector2 = p["pos"]
	for pk in pickups:
		if (pk["pos"] as Vector2).distance_to(ppos) > PLAYER_R + 22.0:
			continue
		match String(pk["kind"]):
			"heart":
				if int(p["hp"]) < int(p["max_hp"]):
					p["hp"] = mini(int(p["max_hp"]), int(p["hp"]) + 2)
					pk["gone"] = true
			"item":
				_take_item(int(pk["item"]))
				if autotest: print("AUTOTEST item ", ITEMS[int(pk["item"])]["name"])
				rooms[cur]["item_taken"] = true
				pk["gone"] = true
			"trapdoor":
				floor_num += 1
				if autotest: print("AUTOTEST reached floor ", floor_num)
				_gen_floor()
				_say("Floor %d" % floor_num, "")
				return
	pickups = pickups.filter(func(pk: Dictionary) -> bool: return not pk.has("gone"))


func _take_item(id: int) -> void:
	var it: Dictionary = ITEMS[id]
	p["items"].append(id)
	_say(it["name"], it["desc"])
	_burst(p["pos"], it["col"], 20)
	match String(it["name"]):
		"Sour Battery": p["rate"] = float(p["rate"]) * 1.35
		"Heavy Core":
			p["dmg"] = float(p["dmg"]) + 1.0
			p["shot_speed"] = float(p["shot_speed"]) * 0.9
		"Twin Lens": p["count"] = int(p["count"]) + 1
		"Needle Round": p["pierce"] = true
		"Seeker Moss": p["homing"] = true
		"Quick Boots": p["speed"] = float(p["speed"]) * 1.15
		"Glass Heart":
			p["max_hp"] = int(p["max_hp"]) + 2
			p["hp"] = p["max_hp"]
		"Long Barrel": p["range"] = float(p["range"]) * 1.4


func _check_room_clear() -> void:
	var room: Dictionary = rooms[cur]
	if room["cleared"] or not enemies.is_empty():
		return
	room["cleared"] = true
	if room["type"] == "boss":
		_boss_rewards(room)
		_say("Boss down", "Take the item, then the hatch")
	elif rng.randf() < 0.22:
		pickups.append({"kind": "heart", "pos": Vector2(W / 2, H / 2)})


func _burst(pos: Vector2, col: Color, n: int) -> void:
	for i in n:
		particles.append({"pos": pos, "vel": Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(60, 260),
			"life": rng.randf_range(0.2, 0.5), "col": col})


func _update_particles(delta: float) -> void:
	for q in particles:
		q["pos"] += q["vel"] * delta
		q["vel"] *= 0.9
		q["life"] -= delta
	particles = particles.filter(func(q: Dictionary) -> bool: return float(q["life"]) > 0.0)


# ---------------------------------------------------------------- drawing

func _enemy_col(type: String) -> Color:
	match type:
		"chaser": return Color(0.85, 0.3, 0.35)
		"shooter": return Color(0.75, 0.45, 0.9)
		"dasher": return Color(0.95, 0.6, 0.2)
	return Color(0.7, 0.15, 0.25)


func _draw() -> void:
	var vp := get_viewport_rect().size
	var off := (vp - Vector2(W, H)) / 2.0
	var jitter := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	draw_set_transform(off + jitter)
	if state == State.TITLE:
		_text(Vector2(0, 300), W, "ROGUELIKE PROTOTYPE", 64, Color.WHITE)
		_text(Vector2(0, 370), W, "Left side of screen: move.  Right side: shoot.", 26, Color(0.7, 0.75, 0.85))
		_text(Vector2(0, 410), W, "Keyboard: WASD to move, arrow keys to shoot.", 22, Color(0.5, 0.55, 0.65))
		_text(Vector2(0, 500), W, "Tap to start", 34, Color(0.6, 0.9, 1.0, 0.6 + 0.4 * sin(time * 4.0)))
		return
	_draw_room()
	for pk in pickups:
		_draw_pickup(pk)
	for e in enemies:
		_draw_enemy(e)
	for s in eshots:
		draw_circle(s["pos"], 9.0, Color(1.0, 0.35, 0.3))
		draw_circle(s["pos"], 4.5, Color(1.0, 0.85, 0.7))
	for s in shots:
		draw_circle(s["pos"], 8.0, Color(0.35, 0.75, 1.0))
		draw_circle(s["pos"], 4.0, Color(0.9, 1.0, 1.0))
	if state == State.PLAY:
		_draw_player()
	for q in particles:
		var c: Color = q["col"]
		c.a = clampf(float(q["life"]) * 3.0, 0.0, 1.0)
		draw_rect(Rect2((q["pos"] as Vector2) - Vector2(3, 3), Vector2(6, 6)), c)
	_draw_hud()
	if state == State.DEAD:
		draw_rect(Rect2(-off, vp), Color(0, 0, 0, 0.6))
		_text(Vector2(0, 310), W, "YOU DIED", 72, Color(0.95, 0.3, 0.3))
		_text(Vector2(0, 370), W, "Floor %d   -   %d defeated" % [floor_num, kills], 28, Color(0.8, 0.8, 0.85))
		_text(Vector2(0, 470), W, "Tap to try again", 32, Color(0.6, 0.9, 1.0, 0.6 + 0.4 * sin(time * 4.0)))
	draw_set_transform(Vector2.ZERO)
	_draw_sticks()


func _text(pos: Vector2, width: float, text: String, size: int, col: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _draw_room() -> void:
	var room: Dictionary = rooms[cur]
	var tint := Color(0.16, 0.17, 0.22)
	if room["type"] == "boss": tint = Color(0.22, 0.14, 0.16)
	elif room["type"] == "item": tint = Color(0.21, 0.2, 0.13)
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.09, 0.12))
	var area := _play_rect()
	draw_rect(area, tint)
	# floor tiles
	var x := area.position.x + 71.0
	while x < area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(1, 1, 1, 0.03), 2.0)
		x += 71.0
	var y := area.position.y + 72.0
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(1, 1, 1, 0.03), 2.0)
		y += 72.0
	draw_rect(area, Color(0.35, 0.37, 0.45), false, 4.0)
	for d in DIRS:
		if not rooms.has(cur + d):
			continue
		var c := _door_pos(d)
		var size := Vector2(WALL * 0.6, DOOR_HALF * 2) if d.x != 0 else Vector2(DOOR_HALF * 2, WALL * 0.6)
		var r := Rect2(c + Vector2(d) * WALL * 0.3 - size / 2, size)
		var frame := Color(0.5, 0.52, 0.6)
		var other: String = rooms[cur + d]["type"]
		if other == "boss": frame = Color(0.9, 0.25, 0.3)
		elif other == "item": frame = Color(0.95, 0.8, 0.3)
		draw_rect(r, tint if _doors_open() else Color(0.05, 0.05, 0.07))
		draw_rect(r, frame, false, 4.0)
		if not _doors_open():
			draw_line(r.position, r.end, frame, 3.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), frame, 3.0)


func _draw_pickup(pk: Dictionary) -> void:
	var pos: Vector2 = pk["pos"]
	match String(pk["kind"]):
		"heart":
			_draw_heart(pos + Vector2(0, sin(time * 4.0) * 3.0), 14.0, 2)
		"item":
			var it: Dictionary = ITEMS[int(pk["item"])]
			draw_rect(Rect2(pos + Vector2(-26, 8), Vector2(52, 22)), Color(0.4, 0.4, 0.46))
			var bob := Vector2(0, -16 + sin(time * 3.0) * 4.0)
			draw_circle(pos + bob, 22.0, Color(it["col"], 0.25))
			draw_circle(pos + bob, 14.0, it["col"])
		"trapdoor":
			draw_rect(Rect2(pos - Vector2(34, 34), Vector2(68, 68)), Color(0.02, 0.02, 0.03))
			draw_rect(Rect2(pos - Vector2(34, 34), Vector2(68, 68)), Color(0.6, 0.9, 1.0, 0.5 + 0.3 * sin(time * 4.0)), false, 4.0)


func _draw_enemy(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var r: float = e["r"]
	var col := _enemy_col(e["type"])
	if float(e["spawn"]) > 0.0:
		# warning ring so nothing appears on top of the player without notice
		draw_arc(pos, r + 6.0, 0, TAU, 24, Color(col, 0.7), 3.0)
		return
	if e["type"] == "dasher" and int(e["mode"]) == 1:
		draw_line(pos, pos + (e["dir"] as Vector2) * 300.0, Color(1, 0.7, 0.2, 0.35), 6.0)
		if fmod(time, 0.14) < 0.07: col = Color.WHITE
	if float(e["flash"]) > 0.0:
		col = Color.WHITE
	draw_circle(pos + Vector2(0, r * 0.7), r * 0.8, Color(0, 0, 0, 0.25))
	if e["type"] == "shooter":
		draw_rect(Rect2(pos - Vector2(r, r), Vector2(r * 2, r * 2)), col)
	else:
		draw_circle(pos, r, col)
	var look: Vector2 = ((p["pos"] as Vector2) - pos).normalized() * r * 0.25
	draw_circle(pos + look + Vector2(-r * 0.35, -r * 0.15), r * 0.2, Color(0.08, 0.05, 0.08))
	draw_circle(pos + look + Vector2(r * 0.35, -r * 0.15), r * 0.2, Color(0.08, 0.05, 0.08))
	if e["type"] == "boss":
		var frac: float = clampf(float(e["hp"]) / float(e["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(W / 2 - 250, H - 52, 500, 16), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(W / 2 - 250, H - 52, 500 * frac, 16), Color(0.9, 0.25, 0.3))
		draw_rect(Rect2(W / 2 - 250, H - 52, 500, 16), Color(1, 1, 1, 0.6), false, 2.0)


func _draw_player() -> void:
	var pos: Vector2 = p["pos"]
	if float(p["inv"]) > 0.0 and fmod(time, 0.16) < 0.08:
		return
	draw_circle(pos + Vector2(0, 13), 15.0, Color(0, 0, 0, 0.25))
	draw_circle(pos, PLAYER_R, Color(0.9, 0.92, 1.0))
	var face: Vector2 = p["face"]
	draw_circle(pos + face * 7.0 + face.orthogonal() * 6.0, 3.5, Color(0.1, 0.1, 0.18))
	draw_circle(pos + face * 7.0 - face.orthogonal() * 6.0, 3.5, Color(0.1, 0.1, 0.18))


func _draw_heart(pos: Vector2, s: float, halves: int) -> void:
	var empty := Color(0.25, 0.1, 0.14)
	var full := Color(0.95, 0.25, 0.35)
	for side in [-1, 1]:
		var c: Color = empty
		if halves >= 2 or (halves == 1 and side == -1):
			c = full
		draw_circle(pos + Vector2(side * s * 0.45, -s * 0.2), s * 0.5, c)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s * 0.25), pos + Vector2(side * s * 0.93, -s * 0.05), pos + Vector2(0, s * 0.85)]), c)


func _draw_hud() -> void:
	var hp: int = p["hp"]
	for i in int(int(p["max_hp"]) / 2.0):
		_draw_heart(Vector2(40 + i * 38, 36), 15.0, clampi(hp - i * 2, 0, 2))
	draw_string(font, Vector2(24, H - 22), "Floor %d" % floor_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.72, 0.8))
	# items collected
	var items: Array = p["items"]
	for i in items.size():
		draw_circle(Vector2(150 + i * 26, H - 29), 9.0, ITEMS[int(items[i])]["col"])
	# minimap: rooms you have seen, plus the ones next to them
	var cell := Vector2(22, 14)
	var origin := Vector2(W - 150, 50)
	for c in rooms.keys():
		var room: Dictionary = rooms[c]
		var known: bool = room["visited"]
		if not known:
			for d in DIRS:
				if rooms.has(c + d) and rooms[c + d]["visited"]:
					known = true
		if not known:
			continue
		var col := Color(0.55, 0.57, 0.65) if room["visited"] else Color(0.28, 0.29, 0.34)
		if room["type"] == "boss": col = Color(0.9, 0.25, 0.3)
		elif room["type"] == "item": col = Color(0.95, 0.8, 0.3)
		if c == cur: col = Color.WHITE
		var rel: Vector2i = c - cur
		var pos := origin + Vector2(rel.x * (cell.x + 3), rel.y * (cell.y + 3))
		if absf(pos.x - origin.x) > 120 or absf(pos.y - origin.y) > 44:
			continue
		draw_rect(Rect2(pos - cell / 2, cell), col)
	if msg_t > 0.0:
		var a := clampf(msg_t, 0.0, 1.0)
		_text(Vector2(0, 190), W, msg, 46, Color(1, 1, 1, a))
		_text(Vector2(0, 228), W, msg_sub, 24, Color(0.8, 0.85, 0.95, a))


func _draw_sticks() -> void:
	if move_touch != -1:
		draw_arc(move_origin, 70.0, 0, TAU, 32, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(move_origin + move_vec * 70.0, 26.0, Color(1, 1, 1, 0.3))
	if aim_touch != -1:
		draw_arc(aim_origin, 70.0, 0, TAU, 32, Color(0.5, 0.85, 1.0, 0.3), 3.0)
		draw_circle(aim_origin + aim_vec * 70.0, 26.0, Color(0.5, 0.85, 1.0, 0.35))


# ---------------------------------------------------------------- self-test bot

func _bot_aim() -> Vector2:
	var best := Vector2.ZERO
	var best_d := 99999.0
	for e in enemies:
		var d: float = (e["pos"] as Vector2).distance_to(p["pos"])
		if d < best_d and float(e["spawn"]) <= 0.0:
			best_d = d
			best = ((e["pos"] as Vector2) - (p["pos"] as Vector2)).normalized()
	return best


func _autotest_tick(delta: float) -> void:
	if state == State.DEAD:
		print("AUTOTEST died floor=%d kills=%d t=%.1f" % [floor_num, kills, time])
		_new_run()
	bot_t -= delta
	var ppos: Vector2 = p["pos"]
	if enemies.is_empty():
		# head for a pickup, else a door (unvisited rooms first)
		var goal := Vector2.ZERO
		if not pickups.is_empty():
			goal = pickups[pickups.size() - 1]["pos"]
		else:
			var pick := Vector2i.ZERO
			for d in DIRS:
				if rooms.has(cur + d) and (pick == Vector2i.ZERO or not rooms[cur + d]["visited"]):
					pick = d
			if bot_t <= 0.0:
				bot_t = 4.0
				var opts: Array = DIRS.filter(func(d: Vector2i) -> bool: return rooms.has(cur + d))
				set_meta("bot_door", opts[rng.randi_range(0, opts.size() - 1)] if rooms[cur + pick]["visited"] else pick)
			var door: Vector2i = get_meta("bot_door", pick)
			if not rooms.has(cur + door):
				door = pick
			goal = _door_pos(door) + Vector2(door) * 60.0
		bot_dir = (goal - ppos).normalized()
	elif bot_t <= 0.0:
		bot_t = 0.5
		var away := Vector2.ZERO
		for e in enemies:
			var d: Vector2 = ppos - (e["pos"] as Vector2)
			away += d.normalized() * (300.0 / maxf(d.length(), 40.0))
		away += (Vector2(W / 2, H / 2) - ppos) / 260.0
		bot_dir = away.normalized().rotated(rng.randf_range(-0.6, 0.6))
	if not shot_times.is_empty() and time >= float(shot_times[0]):
		var n := 5 - shot_times.size()
		shot_times.pop_front()
		if shot_dir != "":
			_save_shot("shot%d.png" % n)
	if shot_times.is_empty() and time > test_len:
		print("AUTOTEST done floor=%d kills=%d rooms_seen=%d items=%d" % [floor_num, kills,
			rooms.values().filter(func(r: Dictionary) -> bool: return r["visited"]).size(), (p["items"] as Array).size()])
		get_tree().quit()


func _save_shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(file))
