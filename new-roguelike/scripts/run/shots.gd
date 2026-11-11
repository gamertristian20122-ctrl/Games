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

## What a shot may do, packed into one number per shot (pass it as extra "bits").
## The player builds his from the item flags in his stats (player.gd _stats_changed), so every
## shot he throws, and every item that throws "his own shots", carries the same tricks.
const B_HERO := 1        ## thrown by the hero's own weapon: its end is told to items (hook on_shot_end)
const B_CHILD := 2       ## made by an item (splinter, spit): never starts on_hit / on_shot_end again
const B_RETURN := 4      ## Tethered Sickle: turns round at the end of its flight and flies home
const B_REAP := 8        ## Reaping Hook: a hit that kills does not use the shot up, it grows
const B_GROW := 16       ## Stonebiter: grows at every bounce
const B_EAT := 32        ## Starveling Blade: destroys enemy shots it touches and grows on them
const B_SHOVE := 64      ## Oxbone Cudgel: pushes the Hungry Curse along
const B_ECLIPSE := 128   ## Eclipse Shard: doubled by flying through the Hungry Curse (and never slows it)
const B_BACK := 256      ## (state) on its way home
const B_DARK := 512      ## (state) has already touched the Hungry Curse
const B_HIT := 1024      ## (state) has hit a monster

## The numbers of the shot items (the item rows in scripts/data/items.gd only switch them on).
const RETURN_SPEED := 1.25     ## Tethered Sickle: speed, damage and reach of the flight home
const RETURN_DAMAGE := 0.7
const RETURN_PIERCE := 99      ## ... and on the way home it cuts through every monster in its path
const RETURN_REACH := 1.5
const RETURN_CATCH := 10.0     ## px from the hero at which a returning shot is caught
const GROW_DAMAGE := 1.5       ## Stonebiter, per bounce
const GROW_SIZE := 1.25
const GROW_REACH := 30.0
const REAP_DAMAGE := 1.4       ## Reaping Hook, per kill
const REAP_SIZE := 1.2
const REAP_REACH := 40.0
const REAP_MAX := 4
const REAP_HOMING := 4.0       ## after a kill it curves at the next monster (radians a second)
const EAT_DAMAGE := 1.19       ## Starveling Blade, per enemy shot swallowed (4 times = double)
const EAT_SIZE := 1.125
const EAT_MAX := 4
const SIZE_CAP := 3.0          ## no shot grows past this many times its type's radius
const ECLIPSE_DAMAGE := 2.0    ## Eclipse Shard
const SHOVE_PX := 5.0          ## Oxbone Cudgel: px per shot (times the shot's knockback), at most SHOVE_MAX
const SHOVE_MAX := 10.0
const SHOVE_PER_SEC := 60.0    ## ... and this much in one second, all shots together
const MAX_HERO_SHOTS := 600    ## safety net: past this many live shots the hero's side throws no more (never reached in tests)

var run: Node
var room: Node

var count := 0
var peak := 0                        ## the most shots alive at once this run (tests print it with --shotpeak)
var end_victim := 0                  ## while on_shot_end runs: the monster that shot died on (instance id), else 0
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
var bits := PackedInt32Array()       ## the B_ flags above
var fed := PackedByteArray()         ## how often it grew: kills reaped (low 4 bits), shots eaten (high 4 bits)
var reach := PackedFloat32Array()    ## the range it started with

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
var _e_ids := PackedInt64Array()
var _foe_shots := PackedInt32Array()
var _shove_left := 0.0
var _dark_kind := 0


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
	_dark_kind = int(_type_index.get("eclipse", 0))


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
	bits.resize(_cap)
	fed.resize(_cap)
	reach.resize(_cap)


## Launches a shot. `extra` may hold: pierce (int), bounce (int), homing (rad/s), knock (float),
## size (radius multiplier), src (who fired it, for the death screen), bits (the B_ flags above),
## skip (instance id of a monster it flies through without hitting, until it has hit another).
func fire(p: Vector2, v: Vector2, shot_side: int, damage: float, range_px: float, type_name: String, extra: Dictionary = NO_EXTRA) -> void:
	if count >= MAX_HERO_SHOTS and shot_side == SIDE_PLAYER:
		return
	if count >= _cap:
		_grow()
	var t: int = _type_index.get(type_name, -1)
	if t < 0:
		t = _type_index[ShotTypes.FALLBACK]
	var i := count
	count += 1
	if count > peak:
		peak = count
		if peak % 20 == 0 and G.flag("shotpeak"):
			print("SHOTS peak=%d" % peak)
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
	last_hit[i] = int(extra.get("skip", 0))
	src[i] = String(extra.get("src", ""))
	bits[i] = int(extra.get("bits", 0))
	fed[i] = 0
	reach[i] = range_px


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
		bits[i] = bits[count]
		fed[i] = fed[count]
		reach[i] = reach[count]


func _puff(i: int) -> void:
	_look.puff(self, i)


## A hero shot ran out of range, hit a wall with no bounce left, was used up on a monster
## (`victim` = that monster's instance id) or came home. Tethered Sickle turns it round once.
## Items hear about the FIRST end of every shot (hook on_shot_end): for a shot that flies back
## that is the turning point, not the catch.
func _finish(i: int, at: Vector2, dir: Vector2, victim: int = 0) -> void:
	var b := bits[i]
	var damage := dmg[i]
	var first := b & B_BACK == 0
	pos[i] = at
	if b & B_RETURN != 0 and first:
		bits[i] = b | B_BACK
		vel[i] = -dir * vel[i].length() * RETURN_SPEED      # re-aimed at the hero every frame
		dmg[i] *= RETURN_DAMAGE
		left[i] = reach[i] * RETURN_REACH
		homing[i] = 0.0
		pierce[i] = RETURN_PIERCE
		last_hit[i] = victim                                 # it never cuts the same monster twice in a row
	else:
		if victim == 0:
			_puff(i)                                         # (a hit already showed its own effect)
		_kill(i)
	if first and b & B_HERO != 0 and b & B_CHILD == 0:
		end_victim = victim
		run.effects.fire("on_shot_end", [at, dir, damage, b & B_HIT != 0])
		end_victim = 0


func _swell(i: int, damage_mult: float, size_mult: float, more_reach: float) -> void:
	dmg[i] *= damage_mult
	rad[i] = minf(rad[i] * size_mult, _t_radius[kind[i]] * SIZE_CAP)
	left[i] += more_reach


## Starveling Blade: hero shots that carry B_EAT destroy the enemy shots they touch.
func _eat_pass() -> void:
	_foe_shots.clear()
	for j in count:
		if side[j] == SIDE_ENEMY:
			_foe_shots.append(j)
	if _foe_shots.is_empty():
		return
	for i in count:
		if side[i] != SIDE_PLAYER or bits[i] & B_EAT == 0:
			continue
		var p := pos[i]
		for j in _foe_shots:
			var rr := rad[i] + rad[j] + 1.0
			if left[j] > 0.0 and p.distance_squared_to(pos[j]) < rr * rr:
				left[j] = 0.0                 # it dies with its usual puff on its own step, below
				if int(fed[i]) >> 4 < EAT_MAX:
					fed[i] += 16
					_swell(i, EAT_DAMAGE, EAT_SIZE, 0.0)
				run.fx.burst(pos[j] - Vector2(0, HEIGHT), [Color(0.95, 0.97, 1.0), Color(0.6, 0.75, 1.0)], 4, 40.0, 0.25, 2.0)


## Oxbone Cudgel: a hero shot pushes the creeping (or resting) Curse a little along its flight.
func _shove(curse: Node2D, dir: Vector2, strength: float) -> void:
	if curse.state != curse.CREEP and curse.state != curse.WINDED:
		return
	var push := minf(minf(SHOVE_PX * strength, SHOVE_MAX), _shove_left)
	if push <= 0.0:
		return
	_shove_left -= push
	var to: Vector2 = curse.position + dir * push
	curse.position = Vector2(clampf(to.x, curse.radius, G.ROOM_W - curse.radius), clampf(to.y, curse.radius, G.ROOM_H - curse.radius))


func _physics_process(delta: float) -> void:
	if room == null or not is_instance_valid(room):
		return
	_shove_left = minf(SHOVE_MAX * 2.0, _shove_left + SHOVE_PER_SEC * delta)
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
	_e_ids.clear()
	for e in room.enemies:
		if e.hittable:
			_e_nodes.append(e)
			_e_ids.append(e.get_instance_id())
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
	if player.stats.has_flag("eat_shots"):
		_eat_pass()
	var i := count - 1
	while i >= 0:
		var p := pos[i]
		var v := vel[i]
		var b := bits[i]
		if b & B_BACK != 0:
			# Tethered Sickle: fly to where the hero is NOW
			var home := p_pos - p
			if home.length_squared() < RETURN_CATCH * RETURN_CATCH:
				_finish(i, p, v.normalized())
				i -= 1
				continue
			v = home.normalized() * v.length()
			vel[i] = v
		# gentle homing (player shots only)
		if homing[i] > 0.0 and e_count > 0:
			var best := -1
			var best_d := 90.0 * 90.0
			var skip := last_hit[i]            # never curve back at the monster it has just hit (or must fly past)
			for k in e_count:
				var d2 := p.distance_squared_to(_e_pos[k])
				if d2 < best_d and _e_ids[k] != skip and v.dot(_e_pos[k] - p) > 0.0:
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
			if side[i] == SIDE_PLAYER:
				_finish(i, p, v.normalized())
			else:
				_puff(i)
				_kill(i)
			i -= 1
			continue
		# walls and solid obstacles
		if room.shot_blocked(np):
			room.shot_hit_solid(np, dmg[i], side[i] == SIDE_PLAYER)
			var bx: bool = room.shot_blocked(Vector2(np.x, p.y))
			var by: bool = room.shot_blocked(Vector2(p.x, np.y))
			if bx or not by:
				v.x = -v.x
			if by or not bx:
				v.y = -v.y
			if bounce[i] > 0:
				bounce[i] -= 1
				vel[i] = v
				last_hit[i] = 0
				if b & B_GROW != 0:
					_swell(i, GROW_DAMAGE, GROW_SIZE, GROW_REACH)
				i -= 1
				continue
			if side[i] == SIDE_PLAYER:
				Sfx.play("shot_hit_wall", -14.0)
				_finish(i, p, v.normalized())      # v is already turned the way it would bounce
			else:
				pos[i] = np
				_puff(i)
				_kill(i)
			i -= 1
			continue
		pos[i] = np
		var r := rad[i]
		if side[i] == SIDE_PLAYER:
			if c_on and np.distance_squared_to(c_pos) < (r + c_rad) * (r + c_rad):
				var fresh := b & B_DARK == 0
				if b & B_ECLIPSE != 0:
					if fresh:
						# Eclipse Shard: through the Curse once = double damage, one more pierce, a dark shot
						dmg[i] *= ECLIPSE_DAMAGE
						pierce[i] += 1
						kind[i] = _dark_kind
						run.fx.burst(np - Vector2(0, HEIGHT), [Color(0.75, 0.45, 1.0), Color(0.2, 0.05, 0.3)], 5, 50.0, 0.3, 2.0)
				else:
					curse.flinch()
				if fresh and b & (B_SHOVE | B_ECLIPSE) != 0:
					b |= B_DARK
					if b & B_SHOVE != 0:
						_shove(curse, v.normalized(), knock[i])
				bits[i] = b
			var dead := false
			for k in e_count:
				var rr := r + _e_rad[k]
				if np.distance_squared_to(_e_pos[k]) < rr * rr:
					var e: Node = _e_nodes[k]
					var eid := _e_ids[k]
					if eid == last_hit[i] or not e.hittable:
						continue
					last_hit[i] = eid
					e.hurt(dmg[i], v.normalized(), knock[i])
					bits[i] = bits[i] | B_HIT
					if b & B_CHILD == 0:
						run.effects.fire("on_hit", [e, dmg[i], np])
					_look.hit(self, i, np, v.normalized())
					if b & B_REAP != 0 and e.dead and int(fed[i]) & 15 < REAP_MAX:
						fed[i] += 1                   # Reaping Hook: the kill feeds the shot and it flies on
						_swell(i, REAP_DAMAGE, REAP_SIZE, REAP_REACH)
						homing[i] = maxf(homing[i], REAP_HOMING)
						continue
					if pierce[i] > 0:
						pierce[i] -= 1
					else:
						dead = true
						break
			if dead:
				if b & B_HERO != 0 and b & B_CHILD == 0:
					_finish(i, np, v.normalized(), last_hit[i])     # Tethered Sickle turns it round; items hear of its end
				else:
					_kill(i)
		else:
			var hit := false
			for wall in blockers:
				if is_instance_valid(wall) and np.distance_squared_to(wall.position) < (r + wall.block_radius) * (r + wall.block_radius):
					hit = true
					wall.blocked_shot()
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
	_look.draw(self, self)
