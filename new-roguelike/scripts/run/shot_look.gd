extends RefCounted
## ShotLook: how every flying shot is DRAWN. The shot manager (scripts/run/shots.gd) owns the
## shots and what they hit; it calls draw() here from its own _draw(), so all shots are still
## painted by that ONE node (no node per shot).
## What each shot type looks like is a row in scripts/data/shot_types.gd.
##
## How it stays cheap with 200 shots on screen:
##   - shots are drawn type by type, and every shot of a type shows the same animation frame,
##     so the renderer can batch a whole type into one draw call
##   - only hero shots have a trail (a few fading copies); enemy shots are a dark disc, one sprite
##     and a bright dot, each drawn for the whole type in one go

const ShotTypes = preload("res://scripts/data/shot_types.gd")

const HEIGHT := 7.0          ## shots are drawn this far above their floor position (chest height)

var ids: Array[String] = []
var _frames: Array = []                  ## per type: Array[Texture2D], empty = plain round shot
var _fps := PackedFloat32Array()
var _angle := PackedFloat32Array()       ## turn added so the art points along the flight
var _spin := PackedFloat32Array()        ## radians per second; 0 = points where it flies
var _origin := PackedVector2Array()      ## where to draw the art so its anchor sits on the shot
var _back := PackedVector2Array()        ## the direction of the tail, in the art's own space
var _gap := PackedFloat32Array()
var _trail := PackedInt32Array()
var _tint := PackedColorArray()
var _under := PackedColorArray()         ## alpha 0 = no disc under the head
var _dot := PackedColorArray()           ## alpha 0 = no bright dot on the head
var _core := PackedColorArray()
var _edge := PackedColorArray()
var _radius := PackedFloat32Array()
var _counts := PackedInt32Array()
var _time := 0.0


## Reads one row of shot_types.gd. Types must be registered in the same order as in shots.gd.
func register(id: String) -> void:
	var row: Dictionary = ShotTypes.info(id)
	ids.append(id)
	var list: Array = []
	var sprite_id := String(row.get("sprite", ""))
	var size := Vector2(16, 16)
	if sprite_id != "" and Art.has(sprite_id):
		var sf := Art.frames(sprite_id)
		if sf != null:
			for i in sf.get_frame_count("default"):
				list.append(sf.get_frame_texture("default", i))
		else:
			list.append(Art.tex(sprite_id))
		size = (list[0] as Texture2D).get_size()
	_frames.append(list)
	_fps.append(float(row.get("fps", 12.0)))
	var up := String(row.get("points", "up")) == "up"
	_angle.append(PI * 0.5 if up else 0.0)
	_back.append(Vector2(0, 1) if up else Vector2(-1, 0))
	_spin.append(float(row.get("spin", 0.0)) * TAU)
	var anchor: Vector2 = row.get("anchor", size * 0.5)
	_origin.append(-anchor)
	_gap.append(float(row.get("gap", 4.0)))
	_trail.append(int(row.get("trail", 0)))
	_tint.append(row.get("tint", Color(1, 1, 1)))
	_under.append(row.get("under", Color(0, 0, 0, 0)))
	_dot.append(row.get("dot", Color(0, 0, 0, 0)))
	_core.append(row["color"])
	_edge.append(row["edge"])
	_radius.append(float(row["radius"]))
	_counts.append(0)


func tick(delta: float) -> void:
	_time += delta


## Draws every shot and every arcing rock onto `c` (the shot manager node). `s` is the manager.
func draw(c: Node2D, s: Node) -> void:
	var count: int = s.count
	var disc: Texture2D = s._disc
	var up := Vector2(0.0, HEIGHT)
	if count > 0:
		var kind: PackedInt32Array = s.kind
		var pos: PackedVector2Array = s.pos
		var vel: PackedVector2Array = s.vel
		var rad: PackedFloat32Array = s.rad
		var types := _counts.size()
		for t in types:
			_counts[t] = 0
		for i in count:
			_counts[kind[i]] += 1
		for t in types:
			if _counts[t] == 0:
				continue
			var list: Array = _frames[t]
			if list.is_empty():
				_draw_round(c, disc, t, count, kind, pos, vel, rad)
				continue
			var under := _under[t]
			if under.a > 0.0:
				# pass 1: the dark rim under every head (one texture, so one batch)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for i in count:
					if kind[i] != t:
						continue
					var q := pos[i] - up
					var o := rad[i] + 2.5
					c.draw_texture_rect(disc, Rect2(q.x - o, q.y - o, o * 2.0, o * 2.0), false, under)
			# pass 2: the sprites, all on the same frame
			var tex: Texture2D = list[int(_time * _fps[t]) % list.size()]
			var origin := _origin[t]
			var tint := _tint[t]
			var trail := _trail[t]
			var back := _back[t] * _gap[t]
			var base_r := _radius[t]
			var turn := _angle[t]
			var spin := _spin[t]
			for i in count:
				if kind[i] != t:
					continue
				var p := pos[i] - up
				var a := vel[i].angle() + turn
				if spin != 0.0:
					a = _time * spin + float(i)
				var sc := rad[i] / base_r
				c.draw_set_transform(p, a, Vector2(sc, sc))
				for k in range(trail, 0, -1):
					var tc := tint
					tc.a *= 0.46 - 0.12 * k
					c.draw_texture(tex, origin + back * k, tc)
				c.draw_texture(tex, origin, tint)
			var dot := _dot[t]
			if dot.a > 0.0:
				# pass 3: the bright core on every head
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for i in count:
					if kind[i] != t:
						continue
					var q2 := pos[i] - up
					var o3 := rad[i] * 0.62
					c.draw_texture_rect(disc, Rect2(q2.x - o3, q2.y - o3, o3 * 2.0, o3 * 2.0), false, dot)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for l: Dictionary in s.lobs:
		var u: float = clampf(l["t"] / l["dur"], 0.0, 1.0)
		var g: Vector2 = (l["from"] as Vector2).lerp(l["to"], u)
		var h: float = float(l["peak"]) * 4.0 * u * (1.0 - u) + HEIGHT * (1.0 - u)
		var t2: int = l["kind"]
		var r2 := _radius[t2]
		c.draw_texture_rect(disc, Rect2(g.x - r2, g.y - r2 * 0.5, r2 * 2.0, r2), false, Color(0, 0, 0, 0.35))
		var p2 := g - Vector2(0.0, h)
		var list2: Array = _frames[t2]
		if list2.is_empty():
			var o2 := r2 + 1.2
			c.draw_texture_rect(disc, Rect2(p2.x - o2, p2.y - o2, o2 * 2.0, o2 * 2.0), false, _edge[t2])
			c.draw_texture_rect(disc, Rect2(p2.x - r2 * 0.75, p2.y - r2 * 0.85, r2 * 1.5, r2 * 1.5), false, _core[t2])
		else:
			var tex2: Texture2D = list2[0]
			c.draw_set_transform(p2, float(l["t"]) * maxf(_spin[t2], 3.0), Vector2.ONE)
			c.draw_texture(tex2, -tex2.get_size() * 0.5, _tint[t2])
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A plain round shot: dark rim, bright centre, a few fading discs behind it.
func _draw_round(c: Node2D, disc: Texture2D, t: int, count: int, kind: PackedInt32Array, pos: PackedVector2Array,
		vel: PackedVector2Array, rad: PackedFloat32Array) -> void:
	var up := Vector2(0.0, HEIGHT)
	var core := _core[t]
	var edge := _edge[t]
	var trail := _trail[t]
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in count:
		if kind[i] != t:
			continue
		var p := pos[i] - up
		var r := rad[i]
		if trail > 0:
			var back := vel[i] * 0.022
			for k in range(trail, 0, -1):
				var tr := r * (1.0 - 0.22 * k)
				var tc := edge
				tc.a = 0.5 - 0.13 * k
				var tp := p - back * k
				c.draw_texture_rect(disc, Rect2(tp.x - tr, tp.y - tr, tr * 2.0, tr * 2.0), false, tc)
		var o := r + 1.2
		c.draw_texture_rect(disc, Rect2(p.x - o, p.y - o, o * 2.0, o * 2.0), false, edge)
		var cr := r * 0.72
		c.draw_texture_rect(disc, Rect2(p.x - cr, p.y - cr, cr * 2.0, cr * 2.0), false, core)


## The small effect when shot i of manager `s` runs out or dies on a wall.
func puff(s: Node, i: int) -> void:
	var t: int = s.kind[i]
	var at: Vector2 = s.pos[i] - Vector2(0, HEIGHT)
	var fx: Node = s.run.fx
	if fx.has_method("pop"):
		fx.pop(at, _core[t], _edge[t])
	else:
		fx.burst(at, [_core[t], _edge[t]], 3, 30.0, 0.22, 1.6)


## The effect when a hero's shot i hits a monster.
func hit(s: Node, i: int, at: Vector2, dir: Vector2) -> void:
	var t: int = s.kind[i]
	var fx: Node = s.run.fx
	if fx.has_method("impact"):
		fx.impact(at - Vector2(0, HEIGHT), _core[t], dir)
	else:
		fx.burst(at - Vector2(0, HEIGHT), [_core[t], Color(1, 1, 1)], 3, 40.0, 0.2, 1.6)
