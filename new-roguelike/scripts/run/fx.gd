extends Node2D
## Fx: every code-drawn effect in the room, drawn by ONE node so hundreds of bits stay cheap:
##   burst()        square particles (hits, deaths, bomb blasts, rubble)
##   ring()         an expanding ring
##   warn_circle()  a growing red circle on the floor = "something lands here" (the tell before an attack)
##   warn_line()    a red line on the floor = "something charges along here"
##   flash()        a short full-screen colour flash
## The warn_* calls also fill `hazards`, a list the test bot reads so it can step out of the way.
## Reach it through run.fx. Everything is cleared when the room changes.

const MAX_PARTICLES := 700

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_col := PackedColorArray()
var p_count := 0

## Rings: [pos, r_from, r_to, t, dur, color, width, on_ground]
var rings: Array = []
## Floor warnings: [kind (0 circle, 1 line), a, b, size, t, dur, color]
var warns: Array = []
## For the bot: [kind, a, b, size, seconds_left]. kind 0 = circle at a with radius size; 1 = line a-b, half width size.
var hazards: Array = []

var ground: Node2D
var _flash_color := Color(1, 1, 1, 0)
var _flash_t := 0.0
var _flash_dur := 0.001


func _ready() -> void:
	z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	p_pos.resize(MAX_PARTICLES)
	p_vel.resize(MAX_PARTICLES)
	p_life.resize(MAX_PARTICLES)
	p_max.resize(MAX_PARTICLES)
	p_size.resize(MAX_PARTICLES)
	p_col.resize(MAX_PARTICLES)
	# A second canvas for things painted ON the floor (under the characters).
	ground = Node2D.new()
	ground.z_as_relative = false
	ground.z_index = -5
	ground.material = mat
	add_child(ground)
	ground.draw.connect(_draw_ground)


func clear() -> void:
	p_count = 0
	rings.clear()
	warns.clear()
	hazards.clear()
	queue_redraw()
	ground.queue_redraw()


## Square particles flying out from a point. `colors` is any list of Color; one is picked per particle.
func burst(at: Vector2, colors: Array, amount: int, speed: float = 60.0, life: float = 0.45, size: float = 2.0, dir: Vector2 = Vector2.ZERO) -> void:
	if colors.is_empty():
		return
	for i in amount:
		if p_count >= MAX_PARTICLES:
			return
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * speed * randf_range(0.35, 1.0) + dir * speed * 0.8
		p_pos[p_count] = at + v * 0.02
		p_vel[p_count] = v
		var l := life * randf_range(0.6, 1.0)
		p_life[p_count] = l
		p_max[p_count] = l
		p_size[p_count] = size * randf_range(0.7, 1.2)
		p_col[p_count] = colors[randi() % colors.size()]
		p_count += 1


func ring(at: Vector2, r_from: float, r_to: float, dur: float, color: Color, width: float = 1.5, on_ground: bool = false) -> void:
	rings.append([at, r_from, r_to, 0.0, dur, color, width, on_ground])


## The tell before an area attack: a circle on the floor that fills up over `dur` seconds.
func warn_circle(at: Vector2, radius: float, dur: float, color: Color = Color(1.0, 0.22, 0.16)) -> void:
	warns.append([0, at, at, radius, 0.0, dur, color])
	hazards.append([0, at, at, radius, dur + 0.1])


## The tell before a charge: a line on the floor from a to b.
func warn_line(a: Vector2, b: Vector2, half_width: float, dur: float, color: Color = Color(1.0, 0.22, 0.16)) -> void:
	warns.append([1, a, b, half_width, 0.0, dur, color])
	hazards.append([1, a, b, half_width, dur + 0.35])


func flash(color: Color, dur: float = 0.12) -> void:
	_flash_color = color
	_flash_t = dur
	_flash_dur = dur


func _physics_process(delta: float) -> void:
	var i := 0
	while i < p_count:
		var l := p_life[i] - delta
		if l <= 0.0:
			p_count -= 1
			p_pos[i] = p_pos[p_count]
			p_vel[i] = p_vel[p_count]
			p_life[i] = p_life[p_count]
			p_max[i] = p_max[p_count]
			p_size[i] = p_size[p_count]
			p_col[i] = p_col[p_count]
			continue
		p_life[i] = l
		var v := p_vel[i] * (1.0 - 4.0 * delta)
		p_vel[i] = v
		p_pos[i] += v * delta
		i += 1
	for k in range(rings.size() - 1, -1, -1):
		rings[k][3] += delta
		if rings[k][3] >= rings[k][4]:
			rings.remove_at(k)
	for k in range(warns.size() - 1, -1, -1):
		warns[k][4] += delta
		if warns[k][4] >= warns[k][5]:
			warns.remove_at(k)
	for k in range(hazards.size() - 1, -1, -1):
		hazards[k][4] -= delta
		if hazards[k][4] <= 0.0:
			hazards.remove_at(k)
	if _flash_t > 0.0:
		_flash_t -= delta
	queue_redraw()
	ground.queue_redraw()


func _draw() -> void:
	for i in p_count:
		var k := p_life[i] / p_max[i]
		var s := maxf(p_size[i] * (0.4 + 0.6 * k), 0.75)
		var c := p_col[i]
		c.a *= minf(1.0, k * 2.5)
		draw_rect(Rect2(p_pos[i].x - s * 0.5, p_pos[i].y - s * 0.5, s, s), c)
	for r in rings:
		if r[7]:
			continue
		_ring(self, r)
	if _flash_t > 0.0:
		var c := _flash_color
		c.a *= clampf(_flash_t / _flash_dur, 0.0, 1.0)
		draw_rect(Rect2(-400, -300, 1100, 800), c)


func _draw_ground() -> void:
	for w in warns:
		var k: float = clampf(w[4] / w[5], 0.0, 1.0)
		var col: Color = w[6]
		var pulse := 0.75 + 0.25 * sin(w[4] * 26.0)
		if w[0] == 0:
			var rad: float = w[3]
			ground.draw_circle(w[1], rad, Color(col.r, col.g, col.b, 0.10))
			ground.draw_circle(w[1], rad * k, Color(col.r, col.g, col.b, 0.22 * pulse))
			ground.draw_arc(w[1], rad, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.85 * pulse), 1.0)
		else:
			var a: Vector2 = w[1]
			var b: Vector2 = w[2]
			ground.draw_line(a, b, Color(col.r, col.g, col.b, 0.16), w[3] * 2.0)
			ground.draw_line(a, a.lerp(b, k), Color(col.r, col.g, col.b, 0.30 * pulse), w[3] * 2.0)
			ground.draw_line(a, b, Color(col.r, col.g, col.b, 0.9 * pulse), 1.0)
	for r in rings:
		if r[7]:
			_ring(ground, r)


func _ring(canvas: Node2D, r: Array) -> void:
	var k: float = clampf(r[3] / r[4], 0.0, 1.0)
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var rad: float = lerpf(r[1], r[2], e)
	var col: Color = r[5]
	col.a *= 1.0 - k
	canvas.draw_arc(r[0], maxf(rad, 0.5), 0.0, TAU, 28, col, r[6] * (1.0 - 0.5 * k))
