extends Node2D
## The intro: a short animated cutscene that SHOWS how it began, played the first time you press
## Play (and again from the bed in your room). The owner asked for it on 12 Nov 2026: "an animation
## for the intro showing it", not words on a black screen.
## Seven shots, each a small scene built from pack art and moved by code (people walk, lights come
## on and go out, the picture darkens, rain falls), with one line of words in the bar underneath:
##   feast     the king at his table in the great hall, and the hall turning red
##   seals     the hill's gate: knights arrive and the four rune stones light, one by one
##   forgotten the same gate: the knights leave and the stones go dark
##   dead      the forest at night, the dead walking through it
##   road      rain; the knight walks the forest road
##   flagon    he reaches the tavern door
##   below     in the dark under the hill, the Starved King
## The shots, their words and how long each stays are data: scripts/data/story.gd INTRO_SHOTS.
## A tap goes to the next shot; "Skip" (or Back) ends it. main.gd waits for `finished`.
## No art is drawn here: sprites are the pack's (hub_*, pc_*, boss_demon); code adds flat black
## bars, soft round glows, tints and rain strokes, like the other effects in the game.
## Test: --intro (play it at once), with --shots=<dir> one picture per shot.

const Story = preload("res://scripts/data/story.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Looks = preload("res://scripts/data/looks.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Hands = preload("res://scripts/entities/hands.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")

signal finished

const BAR := 26.0                ## height of the black bars above and below the picture
const FADE := 0.35
const LETTERS_PER_SECOND := 42.0

var _stage: Node2D
var _sort: Node2D
var _sky: CanvasModulate
var _cam: Camera2D
var _actors: Array = []          ## {"node", "body", "hands", "vel": Vector2, "to": Vector2, "walks": bool, "face": float}
var _tick := Callable()          ## what this shot does every frame: func(seconds_into_the_shot, delta)
var _shot := -1
var _t := 0.0
var _len := 6.0
var _switching := false
var _done := false
var _caption: Label
var _fade: ColorRect
var _rain: CPUParticles2D
var _title: Label
var _glow_tex: GradientTexture2D
var _view := Vector2(400, 180)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view = UI.screen_size(self)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 64
	_glow_tex.height = 64
	# over the picture: rain, the two black bars, the words, the Skip button, the fade
	var layer := CanvasLayer.new()
	layer.layer = G.LAYER_MENU
	add_child(layer)
	var drop := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	drop.fill(Color(0.78, 0.88, 1.0, 0.55))
	_rain = CPUParticles2D.new()
	_rain.texture = ImageTexture.create_from_image(drop)
	_rain.position = Vector2(_view.x * 0.5 + 40.0, -8.0)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(_view.x * 0.5 + 60.0, 2.0)
	_rain.amount = 120
	_rain.lifetime = 0.75
	_rain.direction = Vector2(-0.25, 1.0)
	_rain.spread = 2.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 250.0
	_rain.initial_velocity_max = 300.0
	_rain.emitting = false
	layer.add_child(_rain)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_tap)
	layer.add_child(root)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = UI.C_VOID
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = BAR
		else:
			bar.offset_top = -BAR - 14.0
		root.add_child(bar)
	_caption = UI.label("", "")
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -BAR - 12.0
	_caption.offset_left = 10
	_caption.offset_right = -10
	_caption.offset_bottom = -2
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_caption)
	_title = UI.label("Hollow Hill", "Title")
	UI.style_title(_title, UI.C_GOLD, Color("7a4a12"))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.offset_top = 36
	_title.modulate.a = 0.0
	root.add_child(_title)
	var skip := UI.button("Skip", _finish)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.custom_minimum_size = Vector2(40, 18)
	var ins := UI.safe_insets(self)
	skip.offset_right = -4 - ins.z
	skip.offset_left = skip.offset_right - 40
	skip.offset_top = 4
	skip.offset_bottom = 22
	root.add_child(skip)
	_fade = ColorRect.new()
	_fade.color = UI.C_VOID
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	Sfx.music("title")
	_next()


func _on_tap(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if _t > 0.4 and not _switching:
			_next()


## The phone's Back button, Esc: main.gd calls this.
func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


# ------------------------------------------------------------------ shots
func _next() -> void:
	if _switching or _done:
		return
	_switching = true
	if _shot >= 0:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, FADE)
		await out.finished
	_shot += 1
	if _shot >= Story.INTRO_SHOTS.size():
		_finish()
		return
	_build(Story.INTRO_SHOTS[_shot])
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE)
	_switching = false
	if G.arg("shots") != "" and G.flag("intro"):
		await get_tree().create_timer(_len * 0.4).timeout
		await G.save_shot("intro_%d_%s.png" % [_shot, String(Story.INTRO_SHOTS[_shot]["scene"])])
		_next.call_deferred()


func _build(shot: Dictionary) -> void:
	if is_instance_valid(_stage):
		_stage.free()
	_actors.clear()
	_tick = Callable()
	_t = 0.0
	_len = float(shot.get("time", 6.0))
	_caption.text = Looks.say(String(shot.get("text", "")))
	_caption.visible_characters = 0
	_rain.emitting = false
	_title.modulate.a = 0.0
	_cam.position = Vector2.ZERO
	_stage = Node2D.new()
	add_child(_stage)
	move_child(_stage, 0)
	_sky = CanvasModulate.new()
	_sky.color = Color(1, 1, 1)
	_stage.add_child(_sky)
	_sort = Node2D.new()
	_sort.y_sort_enabled = true
	match String(shot.get("scene", "")):
		"feast": _feast()
		"seals": _seals(false)
		"forgotten": _seals(true)
		"dead": _dead()
		"road": _road()
		"flagon": _flagon()
		"below": _below()
	_stage.add_child(_sort)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_caption.visible_characters = int(_t * LETTERS_PER_SECOND)
	for a: Dictionary in _actors:
		_move(a, delta)
	if _tick.is_valid():
		_tick.call(_t, delta)
	if _t >= _len and not _switching and not (G.arg("shots") != "" and G.flag("intro")):
		_next()


# ------------------------------------------------------------------ pieces of a scene
func _grass() -> void:
	var ground := Node2D.new()
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var tex := Art.tex("hub_grass")
	ground.draw.connect(func() -> void: ground.draw_texture_rect(tex, Rect2(-448, -288, 896, 576), true))
	_stage.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + _shot
	for i in 40:
		var s := Sprite2D.new()
		s.texture = Art.tex("hub_tuft_%d" % (rng.randi() % 24) if rng.randf() < 0.7 else "hub_flower_%d" % (rng.randi() % 26))
		s.position = Vector2(rng.randf_range(-260, 260), rng.randf_range(-60, 80)).round()
		_stage.add_child(s)


## A standing piece with its base on `at` (a negative `below` lifts it).
func _prop(id: String, at: Vector2, below: float = 2.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(id)
	s.centered = false
	var sz := s.texture.get_size()
	s.offset = Vector2(-floorf(sz.x * 0.5), -sz.y + below)
	s.position = at
	_sort.add_child(s)
	return s


func _trees(y: float, ids: Array, step: float = 70.0, clear: float = 0.0) -> void:
	var i := 0
	var x := -280.0
	while x < 290.0:
		_prop(String(ids[i % ids.size()]), Vector2(x + (17 * i) % 13, y + (11 * i) % 7), 8.0)
		# a young tree or a bush between the big trunks (the big crowns are above the picture)
		var small: String = ["hub_tree_green_4", "hub_bush_deep_0", "hub_tree_teal_4", "hub_bush_green_0", "hub_tree_pink_4", "hub_bush_orange_0"][i % 6]
		if absf(x + step * 0.5) >= clear:              # (nothing small in front of what stands in the middle)
			_prop(small, Vector2(x + step * 0.5 + (13 * i) % 9, y + 14.0 + (7 * i) % 6), 5.0)
		i += 1
		x += step


func _path(from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, int(from.distance_to(to) / 30.0))
	for k in steps + 1:
		var s := Sprite2D.new()
		s.texture = Art.tex("hub_patch_%d" % (k % 2))
		s.position = from.lerp(to, float(k) / float(steps)).round()
		_stage.add_child(s)


## A soft round light (it brightens what is under it).
func _glow(at: Vector2, colour: Color, size: float, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.position = at
	s.scale = Vector2(size, size)
	s.modulate = colour
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	s.z_index = 50
	(parent if parent != null else _stage).add_child(s)
	return s


## Someone in the scene: a pack character with both hands, who can be told to walk somewhere.
func _actor(sprite_id: String, hands_id: String, at: Vector2, face: float = 1.0, tint: Color = Color(1, 1, 1)) -> Dictionary:
	var node := Node2D.new()
	node.position = at
	_sort.add_child(node)
	var m := Art.meta(sprite_id)
	node.add_child(EnemyScript.make_shadow(clampf(float(m.get("body_width", 16.0)) * 0.85, 11.0, 18.0)))
	var body := Art.sprite(sprite_id)
	body.position = Vector2(0, 2)
	body.modulate = tint
	body.flip_h = face < 0.0
	node.add_child(body)
	var hands: RefCounted = null
	if hands_id != "":
		hands = Hands.new()
		hands.build(node, body, hands_id, float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)))
	var a := {"node": node, "body": body, "hands": hands, "to": at, "speed": 0.0, "face": face, "tint": tint}
	_actors.append(a)
	return a


## The player's own knight, with his sword and armour colour.
func _knight(at: Vector2) -> Dictionary:
	var hero := Heroes.by_id("knight")
	var a := _actor(String(hero["sprite"]), "", at, 1.0, hero.get("tint", Color.WHITE))
	var node: Node2D = a["node"]
	var body: AnimatedSprite2D = a["body"]
	var weapon := HeroLook.make_weapon(hero)
	node.add_child(weapon)
	HeroLook.rest(weapon, 1.0)
	HeroLook.layer(weapon, body, true)
	a["weapon"] = weapon
	if String(hero.get("hand", "")) != "":
		var m := Art.meta(String(hero["sprite"]))
		var off: RefCounted = Hands.new()
		off.build(node, body, String(hero["hand"]), float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)), true)
		a["hands"] = off
	return a


func _walk(a: Dictionary, to: Vector2, speed: float) -> void:
	a["to"] = to
	a["speed"] = speed


func _move(a: Dictionary, delta: float) -> void:
	var node: Node2D = a["node"]
	var body: AnimatedSprite2D = a["body"]
	var to: Vector2 = a["to"]
	var step := (to - node.position).limit_length(float(a["speed"]) * delta)
	var walking := step.length() > 0.001
	node.position += step
	if absf(step.x) > 0.001:
		a["face"] = signf(step.x)
	body.flip_h = float(a["face"]) < 0.0
	var want := "run" if walking else "idle"
	if body.animation != want:
		body.play(want)
	if a["hands"] != null:
		(a["hands"] as RefCounted).update(delta, walking, float(a["face"]), 0.0, node.visible, null, a["tint"])
	if a.has("weapon"):
		HeroLook.rest(a["weapon"], float(a["face"]), delta)


# ------------------------------------------------------------------ the seven scenes
## The great hall: the king stands at the head of a laden table while the hall turns red.
func _feast() -> void:
	var hall := Sprite2D.new()
	hall.texture = Art.tex("hub_in_hall")
	hall.centered = false
	hall.position = -Vector2(357, 150)             # the long table sits in the middle of the picture
	_stage.add_child(hall)
	var king := _actor("pc_royal_knight", "pc_hand_castle_17", Vector2(0, -74), 1.0, Color(1.25, 1.05, 0.6))
	var cam_x := minf(0.0, 107.0 - _view.x * 0.5)       # the hall picture ends 107 px right of the table: never look past it
	_cam.position = Vector2(cam_x, -44)
	_tick = func(t: float, _delta: float) -> void:
		var k := clampf(t / _len, 0.0, 1.0)
		_cam.position = Vector2(cam_x, lerpf(-44.0, 30.0, k)).round()
		_sky.color = Color(1.0, 0.94, 0.84).lerp(Color(0.62, 0.2, 0.2), clampf((k - 0.35) / 0.65, 0.0, 1.0))
		(king["node"] as Node2D).position.y = -74.0 + roundf(sin(t * 9.0) * minf(k * 2.0, 1.0))      # he shakes with it


## The gate under the hill and its four rune stones. Arriving: knights walk in and the stones
## light one by one. Leaving: the knights walk away and the stones go dark.
func _seals(leaving: bool) -> void:
	_grass()
	_trees(-34, ["hub_tree_green_2", "hub_tree_teal_2", "hub_tree_pink_2", "hub_tree_green_1"], 84.0, 100.0)
	_prop("hub_rock_2", Vector2(-44, -24))
	_prop("hub_rock_moss_2", Vector2(44, -23))
	_prop("hub_gate_0", Vector2(0, -20), 0.0)
	var glows: Array = []
	for i in 4:
		var x := -57.0 + 38.0 * i
		_prop("hub_rune_0", Vector2(x, 18), 3.0)
		glows.append(_glow(Vector2(x, 4), Color(0.45, 0.9, 1.0, 1.0 if leaving else 0.0), 1.1))
	var gate_glow := _glow(Vector2(0, -50), Color(0.8, 0.6, 1.0, 0.7 if leaving else 0.0), 1.6)
	var men: Array = []
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var stand := Vector2(side * (84.0 + 17.0 * (i / 2)), 40.0 + 6.0 * (i / 2))
		var far := Vector2(side * (_view.x * 0.5 + 24.0 + 20.0 * (i / 2)), stand.y)
		var man := _actor("pc_royal_soldier", "pc_hand_castle_17", stand if leaving else far, -side)
		men.append([man, stand, far])
		if not leaving:
			_walk(man, stand, 46.0)
	_sky.color = Color(0.92, 0.94, 1.0)
	_tick = func(t: float, _delta: float) -> void:
		for i in 4:
			var glow: Sprite2D = glows[i]
			if leaving:
				# they flicker and die, one after the other
				var k := clampf((t - 1.6 - 0.9 * i) / 0.8, 0.0, 1.0)
				glow.modulate.a = (1.0 - k) * (0.75 + 0.25 * sin(t * 23.0 + i))
			else:
				glow.modulate.a = clampf((t - 2.2 - 0.6 * i) / 0.5, 0.0, 1.0)
		if leaving:
			gate_glow.modulate.a = 0.7 * (1.0 - clampf((t - 4.6) / 1.0, 0.0, 1.0))
			_sky.color = Color(0.92, 0.94, 1.0).lerp(Color(0.5, 0.56, 0.8), clampf(t / _len, 0.0, 1.0))
			for i in men.size():
				if t > 0.6 + 0.35 * i:
					_walk(men[i][0], men[i][2], 34.0)
		else:
			gate_glow.modulate.a = 0.7 * clampf((t - 4.4) / 0.8, 0.0, 1.0)


## The forest at night, and the dead walking through it.
func _dead() -> void:
	_grass()
	_trees(-30, ["hub_tree_teal_2", "hub_tree_green_2", "hub_tree_pink_2", "hub_tree_teal_1"], 76.0)
	_prop("hub_cross_2", Vector2(-120, 6))
	_prop("hub_tomb_1", Vector2(96, 2))
	_prop("hub_statue_1", Vector2(-30, -6))
	_prop("hub_bush_deep_1", Vector2(150, 62), 4.0)
	_prop("hub_bush_rust_1", Vector2(-170, 66), 4.0)
	_sky.color = Color(0.42, 0.5, 0.8)
	var who := [["pc_zombie_base", "pc_hand_cemetery_30"], ["pc_skeleton_base", "pc_hand_base_7"], ["pc_zombie_banshee", "pc_hand_cemetery_30"],
		["pc_skeleton_warrior", "pc_hand_base_7"], ["pc_zombie_base", "pc_hand_cemetery_30"], ["pc_skeleton_mage", "pc_hand_base_7"]]
	for i in who.size():
		var at := Vector2(_view.x * 0.5 + 20.0 + 46.0 * i, 14.0 + 13.0 * (i % 3) + 4.0 * (i % 2))
		var a := _actor(String(who[i][0]), String(who[i][1]), at, -1.0)
		_walk(a, Vector2(-_view.x * 0.5 - 60.0, at.y), 20.0 + 3.0 * (i % 3))
	_glow(Vector2(-30, -20), Color(0.5, 0.9, 1.0, 0.25), 2.4)
	_tick = func(t: float, _delta: float) -> void:
		_cam.position = Vector2(roundf(12.0 - t * 3.0), 0)


## Rain on the forest road: the knight walks it alone.
func _road() -> void:
	_grass()
	_path(Vector2(-320, 26), Vector2(320, 22))
	_trees(-28, ["hub_tree_green_2", "hub_tree_teal_1", "hub_tree_pink_2", "hub_tree_green_1"], 80.0)
	_prop("hub_rune_2", Vector2(60, 4))
	_prop("hub_stump_1", Vector2(-80, 52), 3.0)
	_prop("hub_bush_green_1", Vector2(170, 70), 5.0)
	_prop("hub_bush_deep_1", Vector2(-190, 72), 4.0)
	_sky.color = Color(0.44, 0.5, 0.72)
	_rain.emitting = true
	var hero := _knight(Vector2(-_view.x * 0.5 - 16.0, 30))
	_walk(hero, Vector2(_view.x * 0.5 + 40.0, 28), 36.0)


## He reaches the tavern: a lit window in the rain, an open door.
func _flagon() -> void:
	_grass()
	_path(Vector2(-240, 44), Vector2(0, 34))
	_trees(-44, ["hub_tree_teal_2", "hub_tree_green_2", "hub_tree_pink_2"], 96.0, 90.0)
	_prop("hub_wall_plaster", Vector2(0, 14), 0.0)
	_prop("hub_roof_wood", Vector2(0, 15), -50.0)
	_prop("hub_doorway", Vector2(0, 16), 0.0)
	_prop("hub_window", Vector2(-36, 16), -14.0)
	_prop("hub_window", Vector2(36, 16), -14.0)
	_prop("hub_bench_long", Vector2(92, 30))
	_sky.color = Color(0.44, 0.5, 0.72)
	_rain.emitting = true
	var lights: Array = [_glow(Vector2(-36, -12), Color(1.0, 0.8, 0.45, 0.9), 1.3), _glow(Vector2(36, -12), Color(1.0, 0.8, 0.45, 0.9), 1.3),
		_glow(Vector2(0, 2), Color(1.0, 0.75, 0.4, 0.8), 1.6)]
	var hero := _knight(Vector2(-_view.x * 0.5 - 16.0, 46))
	_walk(hero, Vector2(0, 22), 40.0)
	_tick = func(t: float, _delta: float) -> void:
		for i in lights.size():
			(lights[i] as Sprite2D).scale = Vector2.ONE * ((1.3 if i < 2 else 1.6) * (1.0 + 0.05 * sin(t * 8.0 + i)))
		var node: Node2D = hero["node"]
		if node.position.distance_to(Vector2(0, 22)) < 2.0:
			node.modulate.a = maxf(node.modulate.a - 0.03, 0.0)      # in through the door


## In the dark under the hill: the Starved King, and the game's name.
func _below() -> void:
	_sky.color = Color(1, 1, 1)
	var king := Art.sprite("boss_demon", "idle")
	king.position = Vector2(0, 78)
	king.modulate = Color(0, 0, 0)
	_stage.add_child(king)
	var ember := _glow(Vector2(0, 10), Color(1.0, 0.25, 0.15, 0.0), 4.0)
	_tick = func(t: float, _delta: float) -> void:
		# he comes out of the dark, then sinks back into it, and the game's name stands alone
		var up := clampf(t / (_len * 0.45), 0.0, 1.0)
		var down := clampf((t - _len * 0.58) / (_len * 0.16), 0.0, 1.0)
		var k := up * up * (1.0 - down)
		king.modulate = Color(0, 0, 0).lerp(Color(0.95, 0.38, 0.3), k)
		ember.modulate.a = 0.4 * k
		var shake := 1.5 * k
		_cam.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).round()
		_title.modulate.a = clampf((t - _len * 0.74) / 0.8, 0.0, 1.0)
