extends Node2D
## Fx: every effect in the room, drawn by ONE node so hundreds of bits stay cheap. Reach it through run.fx.
##
## Plain code effects:
##   burst()        square particles (hits, deaths, bomb blasts, rubble)
##   ring()         an expanding ring
##   warn_circle()  a growing red circle on the floor = "something lands here" (the tell before an attack)
##   warn_line()    a red line on the floor = "something charges along here"
##   flash()        a short full-screen colour flash
## Sprite effects (pictures from assets/art/fx, played once from a small pool; no node per effect):
##   anim(id, at)   any animation by its Art id
##   impact()       a shot hits a monster           pop()         a shot dies on a wall
##   death_puff()   a monster dies, in its own colours
##   explosion()    a bomb: picture + ring + flying square debris
##   sparkle()      a pickup shines                 flourish()    an item is taken
##   dust()         a door slams, something heavy lands
## Atmosphere (set by the room, kept between rooms):
##   set_atmosphere(theme, room_type)   slow specks in the air and a soft dark vignette, per floor
##                                      (the numbers are in scripts/data/floors.gd: "motes", "vignette")
##
## The warn_* calls also fill `hazards`, a list the test bot reads so it can step out of the way.
##
## Boss marks (boss.gd's e.mark_* helpers call these): warn_cone() and warn_ring() besides the
## circle and the line (a line with a big half_width is a lane). Every mark fills up in RED over
## its warning time. A mark can carry a `tag` (its owner's instance id) so the owner can take its
## marks back (drop_warns) or freeze them while it is stunned (hold_warns). zone() draws ground
## that keeps burning for a while (the damage is dealt by whoever made it).
## Everything except the atmosphere is cleared when the room changes.
##
## To add a sprite effect: add its frames with tools/import_assets.py, then write a small function
## like sparkle() below that calls anim().

const MAX_PARTICLES := 700
const MAX_SPRITES := 96
const MAX_MOTES := 28

## The names of the pictures each effect uses (Art ids). Swap them here if better art arrives.
const ANIM_HIT := "fx_hit"
const ANIM_POP := "fx_pop"
const ANIM_SMOKE := "fx_smoke"
const ANIM_EXPLOSION := "fx_explosion"
const ANIM_SPARKLE := "fx_sparkle"
const ANIM_MAGIC := "fx_sparkle_magic"

## Colours of the sparkle a pickup gives off, by what G.pickup_collected calls it.
const PICKUP_COLORS := {
	"coin": Color(1.0, 0.86, 0.35), "key": Color(1.0, 0.86, 0.35), "bomb": Color(0.85, 0.85, 0.92),
	"heart": Color(1.0, 0.45, 0.45), "armor": Color(0.5, 0.75, 1.0),
}
const DUST_COLOR := Color(0.62, 0.56, 0.52, 0.7)

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_col := PackedColorArray()
var p_grav := PackedFloat32Array()
var p_count := 0

## Rings: [pos, r_from, r_to, t, dur, color, width, on_ground]
var rings: Array = []
## Floor warnings: [kind (0 circle, 1 line, 2 cone, 3 ring), a, b, size, t, dur, color, tag, extra]
##   circle: a = centre, size = radius            line: a to b, size = half width
##   cone:   a = tip, b = far end of the middle line, size = half angle (radians)
##   ring:   a = centre, size = outer radius, extra = inner radius (safe inside and outside)
var warns: Array = []
## Ground that keeps burning: [centre, radius, t, dur, color, tag]
var zones: Array = []
var _zone_cd := 0.0
## For the bot: [kind, a, b, size, seconds_left]. kind 0 = circle at a with radius size; 1 = line a-b, half width size.
var hazards: Array = []

var ground: Node2D
var _flash_color := Color(1, 1, 1, 0)
var _flash_t := 0.0
var _flash_dur := 0.001

# ---- sprite effects (a fixed pool)
var s_frames: Array = []                 ## per slot: Array[Texture2D]
var s_pos := PackedVector2Array()
var s_vel := PackedVector2Array()
var s_t := PackedFloat32Array()          ## age; negative = still waiting to start
var s_fps := PackedFloat32Array()
var s_rot := PackedFloat32Array()
var s_scale := PackedFloat32Array()
var s_col := PackedColorArray()
var s_count := 0
var _anims := {}                         ## Art id -> Array[Texture2D] (empty when the art is missing)

# ---- atmosphere
var _mote_pos := PackedVector2Array()
var _mote_phase := PackedFloat32Array()
var _mote_count := 0
var _mote_color := Color(1, 1, 1, 0.5)
var _mote_size := 1.0
var _mote_rise := 0.0
var _mote_drift := 3.0
var _mote_twinkle := 0.5
var _mote_theme := ""
var _time := 0.0
var _vignette: TextureRect
var _vignette_layer: CanvasLayer
var _twinkle_cd := 0.6


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
	p_grav.resize(MAX_PARTICLES)
	s_frames.resize(MAX_SPRITES)
	s_pos.resize(MAX_SPRITES)
	s_vel.resize(MAX_SPRITES)
	s_t.resize(MAX_SPRITES)
	s_fps.resize(MAX_SPRITES)
	s_rot.resize(MAX_SPRITES)
	s_scale.resize(MAX_SPRITES)
	s_col.resize(MAX_SPRITES)
	_mote_pos.resize(MAX_MOTES)
	_mote_phase.resize(MAX_MOTES)
	# A second canvas for things painted ON the floor (under the characters).
	ground = Node2D.new()
	ground.z_as_relative = false
	ground.z_index = -5
	ground.material = mat
	add_child(ground)
	ground.draw.connect(_draw_ground)
	_build_vignette()
	G.item_acquired.connect(_on_item_acquired)
	G.pickup_collected.connect(_on_pickup_collected)


func clear() -> void:
	p_count = 0
	s_count = 0
	rings.clear()
	warns.clear()
	hazards.clear()
	zones.clear()
	queue_redraw()
	ground.queue_redraw()


# =============================================================================== plain code effects
## Square particles flying out from a point. `colors` is any list of Color; one is picked per particle.
## gravity > 0 makes them fall (debris), < 0 makes them float up (embers).
func burst(at: Vector2, colors: Array, amount: int, speed: float = 60.0, life: float = 0.45, size: float = 2.0, dir: Vector2 = Vector2.ZERO, gravity: float = 0.0) -> void:
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
		p_grav[p_count] = gravity
		p_count += 1


func ring(at: Vector2, r_from: float, r_to: float, dur: float, color: Color, width: float = 1.5, on_ground: bool = false) -> void:
	rings.append([at, r_from, r_to, 0.0, dur, color, width, on_ground])


## The tell before an area attack: a circle on the floor that fills up over `dur` seconds.
func warn_circle(at: Vector2, radius: float, dur: float, color: Color = Color(1.0, 0.22, 0.16), tag: int = 0) -> void:
	warns.append([0, at, at, radius, 0.0, dur, color, tag, 0.0])
	hazards.append([0, at, at, radius, dur + 0.1, tag, 0.0])


## The tell before a charge: a line on the floor from a to b.
func warn_line(a: Vector2, b: Vector2, half_width: float, dur: float, color: Color = Color(1.0, 0.22, 0.16), tag: int = 0) -> void:
	warns.append([1, a, b, half_width, 0.0, dur, color, tag, 0.0])
	hazards.append([1, a, b, half_width, dur + 0.35, tag, 0.0])


## The tell before a sweep or a breath: a wedge from `tip` along `dir`, `half_angle` radians to each side.
func warn_cone(tip: Vector2, dir: Vector2, length: float, half_angle: float, dur: float, color: Color = Color(1.0, 0.22, 0.16), tag: int = 0) -> void:
	var far := tip + dir.normalized() * length
	warns.append([2, tip, far, half_angle, 0.0, dur, color, tag, 0.0])
	hazards.append([2, tip, far, half_angle, dur + 0.1, tag, 0.0])


## The tell before a shockwave band: everything between r_inner and r_outer round `at` gets hit.
func warn_ring(at: Vector2, r_inner: float, r_outer: float, dur: float, color: Color = Color(1.0, 0.22, 0.16), tag: int = 0) -> void:
	warns.append([3, at, at, r_outer, 0.0, dur, color, tag, r_inner])
	hazards.append([3, at, at, r_outer, dur + 0.1, tag, r_inner])


## Takes back every mark (and bot hazard, and burning ground) an owner made with its tag.
func drop_warns(tag: int, and_zones: bool = true) -> void:
	for k in range(warns.size() - 1, -1, -1):
		if warns[k][7] == tag:
			warns.remove_at(k)
	for k in range(hazards.size() - 1, -1, -1):
		if hazards[k][5] == tag:
			hazards.remove_at(k)
	if and_zones:
		for k in range(zones.size() - 1, -1, -1):
			if zones[k][5] == tag:
				zones.remove_at(k)


## Freezes an owner's marks for `delta` seconds (call it every frame while the owner is stunned),
## so a mark never runs out before the blow it warns of.
func hold_warns(tag: int, delta: float) -> void:
	for w in warns:
		if w[7] == tag:
			w[4] -= delta
	for h in hazards:
		if h[5] == tag:
			h[4] += delta


## Ground that keeps burning for `dur` seconds: a flickering disc in `color` with embers. Only the
## look and the bot's hazard; whoever calls this deals the damage (boss.gd's e.burn_ground()).
func zone(at: Vector2, radius: float, dur: float, color: Color = Color(1.0, 0.42, 0.12), tag: int = 0) -> void:
	zones.append([at, radius, 0.0, dur, color, tag])
	hazards.append([0, at, at, radius - 6.0, dur, tag, 0.0])


func flash(color: Color, dur: float = 0.12) -> void:
	_flash_color = color
	_flash_t = dur
	_flash_dur = dur


# =============================================================================== sprite effects
func _anim(id: String) -> Array:
	if _anims.has(id):
		return _anims[id]
	var list: Array = []
	var sf := Art.frames(id)
	if sf != null:
		for i in sf.get_frame_count("default"):
			list.append(sf.get_frame_texture("default", i))
	elif Art.has(id):
		list.append(Art.tex(id))
	_anims[id] = list
	return list


## Plays a sprite animation once. Returns false when the art is missing (so callers can fall back).
##   fps      frames per second            delay    seconds before it starts
##   vel      drift in px/s                first/last   play only this part of the animation
func anim(id: String, at: Vector2, color: Color = Color(1, 1, 1), fps: float = 18.0, size: float = 1.0, rot: float = 0.0,
		vel: Vector2 = Vector2.ZERO, delay: float = 0.0, first: int = 0, last: int = -1) -> bool:
	var list := _anim(id)
	if list.is_empty():
		return false
	if first > 0 or last >= 0:
		# a part of an animation is cut out once and remembered
		var key := "%s:%d:%d" % [id, first, last]
		if not _anims.has(key):
			_anims[key] = list.slice(first, list.size() if last < 0 else last + 1)
		list = _anims[key]
		if list.is_empty():
			return false
	var i := s_count
	if s_count >= MAX_SPRITES:
		i = randi() % MAX_SPRITES        # the pool is full: reuse a slot
	else:
		s_count += 1
	s_frames[i] = list
	s_pos[i] = at
	s_vel[i] = vel
	s_t[i] = -delay
	s_fps[i] = fps
	s_rot[i] = rot
	s_scale[i] = size
	s_col[i] = color
	return true


## A shot hits a monster (or the hero): a quick star in the shot's colour and a few sparks.
func impact(at: Vector2, color: Color, dir: Vector2 = Vector2.ZERO) -> void:
	anim(ANIM_HIT, at, color, 30.0, 0.5, randf() * TAU, Vector2.ZERO, 0.0, 0, 4)
	burst(at, [color, Color(1, 1, 1)], 3, 45.0, 0.2, 1.6, dir * 0.5)


## A shot runs out or dies on a wall: a small spiky pop.
func pop(at: Vector2, color: Color, edge: Color = Color(1, 1, 1)) -> void:
	if not anim(ANIM_POP, at, color, 24.0, 0.5, randf() * TAU, Vector2.ZERO, 0.0, 0, 2):
		burst(at, [color, edge], 3, 30.0, 0.22, 1.6)
		return
	burst(at, [color, edge], 2, 26.0, 0.2, 1.4)


## A monster dies: a puff of smoke in its main colour, bits in all its colours, a white ring.
## `colors` is Art.palette(sprite); `size` is the monster's radius.
func death_puff(at: Vector2, colors: Array, size: float = 5.0) -> void:
	var main: Color = colors[0] if not colors.is_empty() else Color(0.8, 0.8, 0.8)
	var big := 2.0 if size >= 8.0 else 1.0
	var smoke := main.lerp(Color(0.12, 0.1, 0.12), 0.35)      # darker than the body: a pale monster no longer leaves a white cloud
	smoke.a = 0.6
	anim(ANIM_SMOKE, at, smoke, 22.0, big * 0.75, randf() * TAU, Vector2(0, -6))
	burst(at, colors, 10 + int(size * 2.0), 75.0, 0.5, 2.6, Vector2.ZERO, 70.0)
	ring(at + Vector2(0, 1), 2.0, size * 2.4, 0.22, Color(1, 1, 1, 0.8), 1.5)


## A bomb goes off: the explosion picture, a shock ring as wide as the blast, a scorch ring on the
## floor and square debris that flies out and falls.
func explosion(at: Vector2, radius: float = 30.0) -> void:
	var up := at - Vector2(0, 5)
	if not anim(ANIM_EXPLOSION, up, Color(1, 1, 1), 14.0, 2.0 if radius >= 24.0 else 1.0):
		burst(up, [Color(1, 0.95, 0.7), Color(1, 0.6, 0.2)], 24, 120.0, 0.5, 3.0)
	ring(at, 4.0, radius, 0.28, Color(1.0, 0.9, 0.6), 3.0)
	ring(at, 2.0, radius * 0.7, 0.4, Color(1.0, 0.5, 0.2), 2.0, true)
	burst(up, [Color(1, 0.95, 0.7), Color(1, 0.6, 0.2), Color(0.9, 0.25, 0.1)], 16, 130.0, 0.45, 2.6)
	burst(up, [Color(0.30, 0.28, 0.28), Color(0.46, 0.40, 0.36), Color(0.2, 0.18, 0.2)], 18, 110.0, 0.8, 3.0, Vector2(0, -0.5), 260.0)
	anim(ANIM_SMOKE, up + Vector2(-9, -4), Color(0.35, 0.32, 0.32, 0.7), 9.0, 1.0, 0.0, Vector2(-8, -10), 0.22)
	anim(ANIM_SMOKE, up + Vector2(10, -2), Color(0.30, 0.27, 0.28, 0.7), 8.0, 1.0, 1.6, Vector2(9, -12), 0.30)
	flash(Color(1, 0.9, 0.7, 0.22), 0.12)


## A pickup shines: tiny plus-shaped twinkles that drift up.
func sparkle(at: Vector2, color: Color = Color(1, 0.95, 0.6), delay: float = 0.0) -> void:
	if not anim(ANIM_SPARKLE, at, color, 11.0, 1.0, 0.0, Vector2(0, -7), delay):
		burst(at, [color], 2, 20.0, 0.3, 1.2)


## An item is taken: a ring, a spray of twinkles and rising bits. Cursed items glow sickly red.
func flourish(at: Vector2, color: Color = Color(1.0, 0.86, 0.4)) -> void:
	ring(at, 3.0, 22.0, 0.4, color, 2.0)
	ring(at + Vector2(0, 8), 2.0, 16.0, 0.5, Color(color.r, color.g, color.b, 0.6), 1.5, true)
	for k in 5:
		var a := TAU * float(k) / 5.0 + randf() * 0.6
		var off := Vector2(cos(a), sin(a) * 0.7) * randf_range(7.0, 15.0)
		anim(ANIM_MAGIC if k % 2 == 0 else ANIM_SPARKLE, at + off, color.lerp(Color(1, 1, 1), 0.35), 10.0, 1.0, 0.0, Vector2(0, -12), 0.05 * k)
	burst(at, [color, Color(1, 1, 1)], 12, 55.0, 0.6, 1.8, Vector2(0, -0.6), -40.0)


## Dust kicked up at `at`, drifting along `dir` (a door slamming, a heavy landing). power 0..1.
func dust(at: Vector2, dir: Vector2 = Vector2.ZERO, power: float = 1.0) -> void:
	var side := Vector2(-dir.y, dir.x)
	for s: float in [-1.0, 1.0]:
		var c := DUST_COLOR
		c.a *= power
		anim(ANIM_SMOKE, at + side * s * 7.0 + dir * 2.0, c, 13.0, 0.5, randf() * TAU, dir * 14.0 + side * s * 10.0 + Vector2(0, -4), 0.0, 1)
	burst(at, [Color(0.55, 0.50, 0.47), Color(0.36, 0.33, 0.33)], int(5.0 * power) + 1, 34.0, 0.4, 1.6, dir * 0.6)


func _on_item_acquired(item_id: String) -> void:
	if G.run == null or G.run.player == null:
		return
	var at: Vector2 = G.run.player.position - Vector2(0, 12)
	var color := Color(1.0, 0.86, 0.4)
	var items: GDScript = load("res://scripts/data/items.gd")
	if items != null and (items.ALL as Dictionary).has(item_id) and items.ALL[item_id].get("cursed", false):
		color = Color(0.95, 0.25, 0.5)
	flourish(at, color)


func _on_pickup_collected(kind: String, _amount: int) -> void:
	if G.run == null or G.run.player == null:
		return
	var at: Vector2 = G.run.player.position - Vector2(0, 9)
	sparkle(at + Vector2(randf_range(-3, 3), randf_range(-3, 2)), PICKUP_COLORS.get(kind, Color(1, 1, 0.8)))


# =============================================================================== atmosphere
func _build_vignette() -> void:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	g.offsets = PackedFloat32Array([0.0, 0.52, 0.80, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.42), Color(0, 0, 0, 1)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.2, 0.5)
	tex.width = 128
	tex.height = 72
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.layer = 4          # above the world, under the room fade (5) and the HUD (10)
	add_child(_vignette_layer)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.modulate = Color(0.02, 0.01, 0.04, 0.0)
	_vignette_layer.add_child(_vignette)


## Sets the floating specks and the vignette for a floor theme (a row of scripts/data/floors.gd).
## Called by every room; the specks keep drifting from room to room on the same floor.
func set_atmosphere(theme: Dictionary, room_type: int = G.RoomType.COMBAT) -> void:
	var strength := float(theme.get("vignette", 0.45))
	if room_type == G.RoomType.BOSS or room_type == G.RoomType.SECRET:
		strength = minf(0.75, strength + 0.12)
	_vignette.modulate.a = strength
	var m: Dictionary = theme.get("motes", {})
	_mote_color = m.get("color", Color(1, 1, 1, 0.4))
	_mote_size = float(m.get("size", 1.0))
	_mote_rise = float(m.get("rise", 0.0))
	_mote_drift = float(m.get("drift", 3.0))
	_mote_twinkle = float(m.get("twinkle", 0.5))
	var want := mini(int(m.get("count", 0)), MAX_MOTES)
	var id := String(theme.get("id", ""))
	if id != _mote_theme or want != _mote_count:
		_mote_theme = id
		_mote_count = want
		for i in want:
			_mote_pos[i] = Vector2(randf_range(-10.0, G.ROOM_W + 10.0), randf_range(-44.0, G.ROOM_H + 8.0))
			_mote_phase[i] = randf() * 40.0


# =============================================================================== every frame
func _physics_process(delta: float) -> void:
	_time += delta
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
			p_grav[i] = p_grav[p_count]
			continue
		p_life[i] = l
		var v := p_vel[i] * (1.0 - 4.0 * delta)
		v.y += p_grav[i] * delta
		p_vel[i] = v
		p_pos[i] += v * delta
		i += 1
	i = 0
	while i < s_count:
		var t := s_t[i] + delta
		if t >= 0.0 and int(t * s_fps[i]) >= (s_frames[i] as Array).size():
			s_count -= 1
			s_frames[i] = s_frames[s_count]
			s_pos[i] = s_pos[s_count]
			s_vel[i] = s_vel[s_count]
			s_t[i] = s_t[s_count]
			s_fps[i] = s_fps[s_count]
			s_rot[i] = s_rot[s_count]
			s_scale[i] = s_scale[s_count]
			s_col[i] = s_col[s_count]
			continue
		s_t[i] = t
		if t >= 0.0:
			s_pos[i] += s_vel[i] * delta
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
	_zone_cd -= delta
	var embers := _zone_cd <= 0.0
	if embers:
		_zone_cd = 0.09
	for k in range(zones.size() - 1, -1, -1):
		var z: Array = zones[k]
		z[2] += delta
		if z[2] >= z[3]:
			zones.remove_at(k)
		elif embers:
			var zc: Color = z[4]
			burst(z[0] + Vector2.RIGHT.rotated(randf() * TAU) * randf() * float(z[1]) * 0.85, [zc, zc.lightened(0.4), Color(1.0, 0.85, 0.35)], 2, 10.0, 0.55, 2.0, Vector2.UP, -45.0)
	if _flash_t > 0.0:
		_flash_t -= delta
	_step_motes(delta)
	_twinkle_cd -= delta
	if _twinkle_cd <= 0.0:
		_twinkle_cd = randf_range(0.35, 0.8)
		_twinkle_a_pickup()
	queue_redraw()
	ground.queue_redraw()


func _step_motes(delta: float) -> void:
	var w := float(G.ROOM_W)
	var h := float(G.ROOM_H)
	for i in _mote_count:
		var p := _mote_pos[i]
		var ph := _mote_phase[i]
		p.x += sin(_time * 0.45 + ph) * _mote_drift * delta
		p.y -= _mote_rise * (0.6 + 0.4 * sin(ph * 3.1)) * delta + cos(_time * 0.3 + ph * 1.3) * 1.2 * delta
		if p.y < -46.0:
			p.y = h + 8.0
			p.x = randf_range(-10.0, w + 10.0)
		elif p.y > h + 10.0:
			p.y = -44.0
			p.x = randf_range(-10.0, w + 10.0)
		if p.x < -14.0:
			p.x = w + 12.0
		elif p.x > w + 14.0:
			p.x = -12.0
		_mote_pos[i] = p


## Now and then a coin, key or heart lying on the floor gives off a little shine.
func _twinkle_a_pickup() -> void:
	if G.run == null or G.run.room == null or not is_instance_valid(G.run.room):
		return
	var things: Array = G.run.room.things
	if things.is_empty():
		return
	var t: Variant = things[randi() % things.size()]
	if not is_instance_valid(t) or String(t.get("kind")) != "pickup":
		return
	var info: Dictionary = t.get("info")
	var color: Color = PICKUP_COLORS.get(String(info.get("kind", "coin")), Color(1, 1, 0.8))
	sparkle((t.position as Vector2) + Vector2(randf_range(-3, 3), randf_range(-9, -4)), color)


func _draw() -> void:
	# specks in the air
	for i in _mote_count:
		var c := _mote_color
		c.a *= 1.0 - _mote_twinkle * (0.5 + 0.5 * sin(_time * 1.7 + _mote_phase[i] * 2.0))
		var p := _mote_pos[i].floor()
		draw_rect(Rect2(p.x, p.y, _mote_size, _mote_size), c)
	# sprite effects
	for i in s_count:
		var t := s_t[i]
		if t < 0.0:
			continue
		var list: Array = s_frames[i]
		var f := mini(int(t * s_fps[i]), list.size() - 1)
		var tex: Texture2D = list[f]
		var sc := s_scale[i]
		draw_set_transform(s_pos[i].floor(), s_rot[i], Vector2(sc, sc))
		draw_texture(tex, -tex.get_size() * 0.5, s_col[i])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# square particles
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
	for z in zones:
		var zc: Color = z[4]
		var zr: float = z[1]
		var fade := clampf((float(z[3]) - float(z[2])) / 0.5, 0.0, 1.0) * clampf(float(z[2]) / 0.12, 0.0, 1.0)
		var flick := 0.8 + 0.2 * sin(float(z[2]) * 19.0 + zr)
		# fire, not a warning and not the Curse: no rim, a ragged patch of overlapping blobs that flicker
		for n in 6:
			var lobe: Vector2 = (z[0] as Vector2) + Vector2.RIGHT.rotated(TAU * float(n) / 6.0 + zr) * zr * 0.5
			ground.draw_circle(lobe, zr * 0.5, Color(zc.r * 0.4, zc.g * 0.15, zc.b * 0.15, 0.34 * fade))
		for n in 5:
			var wob := 0.75 + 0.25 * sin(float(z[2]) * (13.0 + 3.0 * float(n)) + float(n) * 2.1)
			var blob: Vector2 = (z[0] as Vector2) + Vector2.RIGHT.rotated(TAU * float(n) / 5.0 + zr * 2.0) * zr * 0.42
			ground.draw_circle(blob, zr * 0.36 * wob, Color(zc.r, zc.g, zc.b, 0.40 * fade))
		ground.draw_circle(z[0], zr * 0.34 * flick, Color(1.0, 0.82, 0.3, 0.45 * fade))
	for w in warns:
		var k: float = clampf(w[4] / w[5], 0.0, 1.0)
		var col: Color = w[6]
		var pulse := 0.75 + 0.25 * sin(w[4] * 26.0)
		if w[0] == 2:
			var tip: Vector2 = w[1]
			var mid: Vector2 = (w[2] as Vector2) - tip
			var reach := mid.length()
			var a0 := mid.angle() - float(w[3])
			var full := PackedVector2Array([tip])
			var part := PackedVector2Array([tip])
			for n in 13:
				var d := Vector2.RIGHT.rotated(a0 + float(w[3]) * 2.0 * float(n) / 12.0)
				var seen := _reach_in_room(tip, d, reach)       # the wedge stops at the walls
				full.append(tip + d * seen)
				part.append(tip + d * minf(reach * k, seen))
			ground.draw_colored_polygon(full, Color(col.r, col.g, col.b, 0.12))
			if k > 0.04:
				ground.draw_colored_polygon(part, Color(col.r, col.g, col.b, 0.24 * pulse))
			full.append(tip)
			ground.draw_polyline(full, Color(col.r, col.g, col.b, 0.85 * pulse), 1.0)
		elif w[0] == 3:
			# boss marks are clipped to the floor rectangle (they never spill over the walls)
			var r_in: float = w[8]
			var r_out: float = w[3]
			var band := r_out - r_in
			_clip_band(w[1], r_in, r_out, Color(col.r, col.g, col.b, 0.12))
			if k > 0.04:
				_clip_band(w[1], r_in, r_in + band * k, Color(col.r, col.g, col.b, 0.24 * pulse))
			_clip_line(_circle_pts(w[1], r_in, 32, true), Color(col.r, col.g, col.b, 0.85 * pulse), 1.0)
			_clip_line(_circle_pts(w[1], r_out, 40, true), Color(col.r, col.g, col.b, 0.85 * pulse), 1.0)
		elif w[0] == 0:
			var rad: float = w[3]
			_clip_fill(_circle_pts(w[1], rad, 28, false), Color(col.r, col.g, col.b, 0.10))
			if k > 0.02:
				_clip_fill(_circle_pts(w[1], rad * k, 28, false), Color(col.r, col.g, col.b, 0.22 * pulse))
			_clip_line(_circle_pts(w[1], rad, 28, true), Color(col.r, col.g, col.b, 0.85 * pulse), 1.0)
		else:
			var a: Vector2 = w[1]
			var b: Vector2 = w[2]
			if a.distance_to(b) > 1.0:
				b = a + (b - a).normalized() * _reach_in_room(a, (b - a).normalized(), a.distance_to(b))   # a lane stops at the walls
			_clip_fill(_lane_pts(a, b, w[3]), Color(col.r, col.g, col.b, 0.16))
			_clip_fill(_lane_pts(a, a.lerp(b, k), w[3]), Color(col.r, col.g, col.b, 0.30 * pulse))
			_clip_line(PackedVector2Array([a, b]), Color(col.r, col.g, col.b, 0.9 * pulse), 1.0)
	for r in rings:
		if r[7]:
			_ring(ground, r)


## Floor clipping for boss marks (Geometry2D against the floor rectangle).
func _floor_rect() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(G.ROOM_W, 0), Vector2(G.ROOM_W, G.ROOM_H), Vector2(0, G.ROOM_H)])


func _circle_pts(c: Vector2, r: float, n: int, closed: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in (n + 1 if closed else n):
		pts.append(c + Vector2.RIGHT.rotated(TAU * float(i) / float(n)) * r)
	return pts


func _lane_pts(a: Vector2, b: Vector2, hw: float) -> PackedVector2Array:
	var d := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector2.RIGHT
	var n := d.orthogonal() * hw
	return PackedVector2Array([a + n, b + n, b - n, a - n])


func _clip_fill(poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3:
		return
	for part in Geometry2D.intersect_polygons(poly, _floor_rect()):
		if part.size() >= 3:
			ground.draw_colored_polygon(part, col)


func _clip_line(pts: PackedVector2Array, col: Color, width: float) -> void:
	for part in Geometry2D.intersect_polyline_with_polygon(pts, _floor_rect()):
		if part.size() >= 2:
			ground.draw_polyline(part, col, width)


## A filled band between two radii, as small quads so each can be clipped on its own.
func _clip_band(c: Vector2, r_in: float, r_out: float, col: Color) -> void:
	if r_out - r_in < 0.3:
		return
	var n := 36
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var u0 := Vector2.RIGHT.rotated(a0)
		var u1 := Vector2.RIGHT.rotated(a1)
		_clip_fill(PackedVector2Array([c + u0 * r_in, c + u0 * r_out, c + u1 * r_out, c + u1 * r_in]), col)


## How far a mark may run from `from` along the unit vector `d` before it leaves the floor.
func _reach_in_room(from: Vector2, d: Vector2, max_len: float) -> float:
	var k := max_len
	if d.x > 0.001:
		k = minf(k, (G.ROOM_W - from.x) / d.x)
	elif d.x < -0.001:
		k = minf(k, -from.x / d.x)
	if d.y > 0.001:
		k = minf(k, (G.ROOM_H - from.y) / d.y)
	elif d.y < -0.001:
		k = minf(k, -from.y / d.y)
	return maxf(k, 0.0)


func _ring(canvas: Node2D, r: Array) -> void:
	var k: float = clampf(r[3] / r[4], 0.0, 1.0)
	var col: Color = r[5]
	if r[1] > r[2]:
		# a ring that closes in is a warning: it gets stronger until it lands
		col.a *= 0.3 + 0.7 * k
		canvas.draw_arc(r[0], maxf(lerpf(r[1], r[2], k), 0.5), 0.0, TAU, 28, col, r[6])
		return
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	col.a *= 1.0 - k
	if canvas == ground:
		# a shockwave on the floor stops at the walls
		_clip_line(_circle_pts(r[0], maxf(lerpf(r[1], r[2], e), 0.5), 28, true), col, r[6] * (1.0 - 0.5 * k))
		return
	canvas.draw_arc(r[0], maxf(lerpf(r[1], r[2], e), 0.5), 0.0, TAU, 28, col, r[6] * (1.0 - 0.5 * k))
