extends Node2D
## Shots: every flying shot in the room lives in this ONE node (no node per shot), so 200 shots
## cost almost nothing. Reach it through run.shots.
##   fire(pos, velocity, side, damage, range, type, extra)   a straight shot
##   lob(from, to, time, blast_radius, type, cause)           an arcing rock that lands on a marked spot
## A shot's position is where it is ON THE FLOOR; it is drawn HEIGHT pixels higher, at chest
## height, so it lines up with the feet circles everything else uses for collisions.
## Sides: SIDE_PLAYER shots hurt enemies, SIDE_ENEMY shots hurt the player.
## The look of each shot type comes from scripts/data/shot_types.gd and is drawn in _draw()
## below: that is the one place to change when projectile sprites arrive.

const ShotTypes = preload("res://scripts/data/shot_types.gd")
const ShotLook = preload("res://scripts/run/shot_look.gd")

const HEIGHT := 7.0
const SIDE_PLAYER := 0
const SIDE_ENEMY := 1
const NO_EXTRA := {}

var run: Node
var room: Node

var count := 0
var _cap := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var rad := PackedFloat32Array()
var dmg := PackedFloat32Array()
var left := PackedFloat32Array()
var side := PackedByteArray()
var kind := PackedInt32Array()
var pierce := PackedInt32Array()
var bounce := PackedInt32Array()
var homing := PackedFloat32Array()
var knock := PackedFloat32Array()
var last_hit := PackedInt64Array()
var src := PackedStringArray()

## Arcing shots (few at a time): {from, to, t, dur, radius, kind, cause, peak}
var lobs: Array = []

var _type_index := {}
var _t_color: Array[Color] = []
var _t_edge: Array[Color] = []
var _t_radius: Array[float] = []
var _t_trail: Array[int] = []
var _t_tex: Array = []
var _disc: GradientTexture2D
var _look := ShotLook.new()        ## draws the shots (scripts/run/shot_look.gd)

# scratch lists rebuilt every tick so the inner loops never touch nodes
var _e_nodes: Array = []
var _e_pos := PackedVector2Array()
var _e_rad := PackedFloat32Array()


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	# A plain white disc; every circle shot is this texture, tinted (so they all draw in one batch).
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.96])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_disc = GradientTexture2D.new()
	_disc.gradient = g
	_disc.fill = GradientTexture2D.FILL_RADIAL
	_disc.fill_from = Vector2(0.5, 0.5)
	_disc.fill_to = Vector2(1.0, 0.5)
	_disc.width = 16
	_disc.height = 16
	for id in ShotTypes.ALL:
		_register(id)


func _register(id: String) -> int:
	var row: Dictionary = ShotTypes.info(id)
	_type_index[id] = _t_color.size()
	_t_color.append(row["color"])
	_t_edge.append(row["edge"])
	_t_radius.append(float(row["radius"]))
	_t_trail.append(int(row["trail"]))
	_t_tex.append(null)
	_look.register(id)
	return _t_color.size() - 1


func type_radius(type_name: String) -> float:
	return _t_radius[int(_type_index.get(type_name, 0))]


func clear() -> void:
	count = 0
	lobs.clear()
	queue_redraw()


func _grow() -> void:
	_cap = maxi(64, _cap * 2)
	pos.resize(_cap)
	vel.resize(_cap)
	rad.resize(_cap)
	dmg.resize(_cap)
	left.resize(_cap)
	side.resize(_cap)
	kind.resize(_cap)
	pierce.resize(_cap)
	bounce.resize(_cap)
	homing.resize(_cap)
	knock.resize(_cap)
	last_hit.resize(_cap)
	src.resize(_cap)


## Launches a shot. `extra` may hold: pierce (int), bounce (int), homing (rad/s), knock (float),
## size (radius multiplier), src (who fired it, for the death screen).
func fire(p: Vector2, v: Vector2, shot_side: int, damage: float, range_px: float, type_name: String, extra: Dictionary = NO_EXTRA) -> void:
	if count >= _cap:
		_grow()
	var t: int = _type_index.get(type_name, -1)
	if t < 0:
		t = _type_index[ShotTypes.FALLBACK]
	var i := count
	count += 1
	pos[i] = p
	vel[i] = v
	rad[i] = _t_radius[t] * float(extra.get("size", 1.0))
	dmg[i] = damage
	left[i] = range_px
	side[i] = shot_side
	kind[i] = t
	pierce[i] = int(extra.get("pierce", 0))
	bounce[i] = int(extra.get("bounce", 0))
	homing[i] = float(extra.get("homing", 0.0))
	knock[i] = float(extra.get("knock", 1.0))
	last_hit[i] = 0
	src[i] = String(extra.get("src", ""))


## A ring of `amount` enemy shots flying outward (used by many attacks).
func ring_of(p: Vector2, amount: int, speed: float, type_name: String, range_px: float = 150.0, cause: String = "", angle_offset: float = 0.0) -> void:
	var extra := {"src": cause}
	for k in amount:
		var a := angle_offset + TAU * float(k) / float(amount)
		fire(p, Vector2(cos(a), sin(a)) * speed, SIDE_ENEMY, 1.0, range_px, type_name, extra)


## An arcing shot: a warning circle appears at `to`, and `dur` seconds later the rock lands there
## and hurts the player if they are still inside `blast_radius`.
func lob(from: Vector2, to: Vector2, dur: float, blast_radius: float, type_name: String = "rock", cause: String = "") -> void:
	var t: int = _type_index.get(type_name, 0)
	lobs.append({"from": from, "to": to, "t": 0.0, "dur": dur, "radius": blast_radius, "kind": t, "cause": cause,
		"peak": 26.0 + from.distance_to(to) * 0.18})
	run.fx.warn_circle(to, blast_radius, dur)


func _kill(i: int) -> void:
	count -= 1
	if i != count:
		pos[i] = pos[count]
		vel[i] = vel[count]
		rad[i] = rad[count]
		dmg[i] = dmg[count]
		left[i] = left[count]
		side[i] = side[count]
		kind[i] = kind[count]
		pierce[i] = pierce[count]
		bounce[i] = bounce[count]
		homing[i] = homing[count]
		knock[i] = knock[count]
		last_hit[i] = last_hit[count]
		src[i] = src[count]


func _puff(i: int) -> void:
	_look.puff(self, i)


func _physics_process(delta: float) -> void:
	if room == null or not is_instance_valid(room):
		return
	if count > 0:
		_step_shots(delta)
	if not lobs.is_empty():
		_step_lobs(delta)
	queue_redraw()


func _step_shots(delta: float) -> void:
	# Snapshot the enemies once so the inner loop only reads plain arrays.
	_e_nodes.clear()
	_e_pos.clear()
	_e_rad.clear()
	for e in room.enemies:
		if e.hittable:
			_e_nodes.append(e)
			_e_pos.append(e.position - Vector2(0.0, e.hit_up))
			_e_rad.append(e.radius + e.hit_grow)
	var e_count := _e_nodes.size()
	var player: Node = run.player
	var p_pos: Vector2 = player.position
	var p_rad: float = player.hit_radius
	var p_open: bool = player.can_be_hit()
	var blockers: Array = room.blockers
	# the Hungry Curse: hero shots pass through it, and each one makes it flinch
	var curse: Node2D = room.curse
	var c_on: bool = curse != null and is_instance_valid(curse) and curse.solid
	var c_pos: Vector2 = curse.position if c_on else Vector2.ZERO
	var c_rad: float = curse.radius if c_on else 0.0
	var i := count - 1
	while i >= 0:
		var p := pos[i]
		var v := vel[i]
		# gentle homing (player shots only)
		if homing[i] > 0.0 and e_count > 0:
			var best := -1
			var best_d := 90.0 * 90.0
			for k in e_count:
				var d2 := p.distance_squared_to(_e_pos[k])
				if d2 < best_d and v.dot(_e_pos[k] - p) > 0.0:
					best_d = d2
					best = k
			if best >= 0:
				var want := (_e_pos[best] - p).angle()
				var cur := v.angle()
				var turn := clampf(angle_difference(cur, want), -homing[i] * delta, homing[i] * delta)
				v = v.rotated(turn)
				vel[i] = v
		var step := v * delta
		var np := p + step
		left[i] -= step.length()
		if left[i] <= 0.0:
			_puff(i)
			_kill(i)
			i -= 1
			continue
		# walls and solid obstacles
		if room.shot_blocked(np):
			room.shot_hit_solid(np, dmg[i], side[i] == SIDE_PLAYER)
			if bounce[i] > 0:
				bounce[i] -= 1
				var bx: bool = room.shot_blocked(Vector2(np.x, p.y))
				var by: bool = room.shot_blocked(Vector2(p.x, np.y))
				if bx or not by:
					v.x = -v.x
				if by or not bx:
					v.y = -v.y
				vel[i] = v
				last_hit[i] = 0
				i -= 1
				continue
			pos[i] = np
			_puff(i)
			if side[i] == SIDE_PLAYER:
				Sfx.play("shot_hit_wall", -14.0)
			_kill(i)
			i -= 1
			continue
		pos[i] = np
		var r := rad[i]
		if side[i] == SIDE_PLAYER:
			if c_on and np.distance_squared_to(c_pos) < (r + c_rad) * (r + c_rad):
				curse.flinch()
			var dead := false
			for k in e_count:
				var rr := r + _e_rad[k]
				if np.distance_squared_to(_e_pos[k]) < rr * rr:
					var e: Node = _e_nodes[k]
					var eid := e.get_instance_id()
					if eid == last_hit[i] or not e.hittable:
						continue
					last_hit[i] = eid
					e.hurt(dmg[i], v.normalized(), knock[i])
					run.effects.fire("on_hit", [e, dmg[i], np])
					_look.hit(self, i, np, v.normalized())
					if pierce[i] > 0:
						pierce[i] -= 1
					else:
						dead = true
						break
			if dead:
				_kill(i)
		else:
			var hit := false
			for b in blockers:
				if is_instance_valid(b) and np.distance_squared_to(b.position) < (r + b.block_radius) * (r + b.block_radius):
					hit = true
					b.blocked_shot()
					break
			if not hit and p_open:
				var rr2 := r + p_rad
				if np.distance_squared_to(p_pos) < rr2 * rr2:
					hit = true
					player.hurt(int(dmg[i]), np - v.normalized() * 4.0, src[i])
					p_open = player.can_be_hit()
			if hit:
				_puff(i)
				_kill(i)
		i -= 1


func _step_lobs(delta: float) -> void:
	for k in range(lobs.size() - 1, -1, -1):
		var l: Dictionary = lobs[k]
		l["t"] += delta
		if l["t"] >= l["dur"]:
			var at: Vector2 = l["to"]
			var radius: float = l["radius"]
			run.fx.ring(at, 3.0, radius, 0.3, Color(1.0, 0.75, 0.4), 2.0, true)
			run.fx.burst(at, [_t_color[l["kind"]], _t_edge[l["kind"]], Color(0.5, 0.45, 0.4)], 10, 70.0, 0.4, 2.2)
			run.shake(0.25)
			Sfx.play("rock_break", -6.0)
			var player: Node = run.player
			if player.can_be_hit() and player.position.distance_to(at) < radius + player.hit_radius - 2.0:
				player.hurt(1, at, l["cause"])
			lobs.remove_at(k)


## Every shot is painted here, by this one node; HOW is in scripts/run/shot_look.gd.
func _draw() -> void:
	_look.tick(get_physics_process_delta_time())
	_look.draw(self)
