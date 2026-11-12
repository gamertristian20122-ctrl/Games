extends Node2D
## The camp: the place between runs. A small forest clearing the hero walks around in, with
## people to talk to. main.gd shows it after Play and after every run.
##   Warden (gate)    picks the stage to start a run on
##   Druid (quests)   hands out quests and pays supplies for the next run (scripts/data/quests.gd)
##   Chronicler       opens the Collection
##   Cook (pack)      shows the supplies waiting for the next run
##   the other heroes stand by the fire: talk to one to play as them
## The map, the people and their words are data: scripts/data/hub.gd. Art: ids hub_* cut by
## tools/import_hub.py from the purchased packs, plus the pack's characters. Nothing here draws
## art: code only places pieces, a soft shadow blob, and square fireflies.
## The hub never changes the flow itself: it sends requests to main.gd (signal `action`).
##
## Test flags: --hub (open the camp at once), with --shots=<dir> it walks a short tour and saves
## pictures; --hubtalk=<npc id> also opens that person's window; --hublevel=<level id> goes down into
## that story level after a second.

const Hub = preload("res://scripts/data/hub.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const Floors = preload("res://scripts/data/floors.gd")
const Quests = preload("res://scripts/data/quests.gd")
const Gear = preload("res://scripts/data/gear.gd")
const Allies = preload("res://scripts/data/allies.gd")
const Roamers = preload("res://scripts/data/roamers.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Story = preload("res://scripts/data/story.gd")
const Places = preload("res://scripts/data/places.gd")
const Shop = preload("res://scripts/data/shop.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const Items = preload("res://scripts/data/items.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const QuestList = preload("res://scripts/ui/quest_list.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Hands = preload("res://scripts/entities/hands.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")

signal action(what: String, arg: Variant)

const SPEED := 74.0
const HERO_RADIUS := 5.0
const DUSK := Color(0.80, 0.86, 0.92)          ## the forest's evening tint (the fire lights through it)
## DAY AND NIGHT, AND WEATHER (out of doors only). One day lasts DAY_LENGTH seconds of walking about.
## SKY is the colour laid over everything at each part of the day (0 = morning, 1 = the next morning);
## lamps and fires burn brighter and the fireflies come out as it gets dark. Now and then it rains.
const DAY_LENGTH := 360.0
const SKY := [[0.0, Color(1.0, 0.98, 0.93)], [0.42, Color(1.0, 0.98, 0.93)], [0.52, Color(0.96, 0.78, 0.68)], [0.60, Color(0.50, 0.58, 0.82)],
	[0.90, Color(0.48, 0.56, 0.80)], [0.97, Color(0.86, 0.80, 0.88)], [1.0, Color(1.0, 0.98, 0.93)]]
const NIGHT_FROM := 0.56         ## the part of the day when night has fallen (to NIGHT_TO)
const NIGHT_TO := 0.93
const WEATHER_SLOT := 75.0       ## seconds one spell of weather lasts
const RAIN_CHANCE := 28          ## in a hundred
const RAIN_SKY := Color(0.80, 0.85, 0.92)

var frozen := false              ## a window is open: the hero stands still
var start_place := ""            ## main.gd sets these before the scene is added: where to begin ...
var start_at := Vector2.INF      ## ... and where to stand there (INF = the place's own spawn point)
var place_id := ""               ## the place being shown (scripts/data/places.gd)
var place := {}
var _stage: Node2D               ## everything of the current place hangs on this and goes with it
var _blocks: Array = []          ## Rect2 walls and furniture of the place
var _changing := false           ## walking through a door: a short fade is running
var _fade: ColorRect
var _ysort: Node2D
var _hero: Node2D
var _body: AnimatedSprite2D
var _weapon: Sprite2D
var _off_hand: RefCounted
var _face := 1.0
var _cam: Camera2D
var _solids: Array = []          ## [Vector2 centre, float radius]
var _people: Array = []          ## {"row": Dictionary, "node": Node2D, "hands": RefCounted, "mark": Label}
var _near := -1                  ## index into _people of the person in reach, or -1
var _last_talk := -1
var _prompt: Label
var _time := 0.0
var _tour: Array = []
var _tour_t := 0.0
var _news := false              ## a quest is waiting to be handed in
var _talked := {}               ## npc ids spoken to during this visit
var _quests: Control
var _small := false              ## the place fits on the screen: the camera stands still
var _entered := false
var _arrive_t := 0.0
var _banner: Label
var _banner_text := ""
var _sky_node: CanvasModulate
var _lamps: Array = []           ## [PointLight2D, energy by day]
var _flies: CPUParticles2D
var _rain: CPUParticles2D
var _zoom := 1.0                 ## the place's camera zoom (0.5 on the world map: twice as much is seen)
var _k := 1.0                    ## how big the knight is drawn there (2 on the world map)
var _shut_t := 0.0               ## a moment before a shut road says so again


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Controls.action_enabled = true
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_prompt = UI.label("", "Small")
	_prompt.theme = UI.theme()
	_prompt.z_index = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", UI.C_INK)
	_prompt.add_theme_constant_override("outline_size", 3)
	add_child(_prompt)
	Controls.action_pressed.connect(_on_talk_pressed)
	# the quest list in the top-left corner, as in a level
	var layer := CanvasLayer.new()
	layer.layer = G.LAYER_HUD
	add_child(layer)
	_quests = QuestList.new()
	_quests.in_camp = true
	var ins := UI.safe_insets(self)
	_quests.position = Vector2(ins.x + 2.0, ins.y + 2.0)
	_quests.modulate.a = 0.92
	layer.add_child(_quests)
	_banner = UI.label("", "Head")
	_banner.theme = UI.theme()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 8
	_banner.add_theme_color_override("font_outline_color", UI.C_INK)
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.visible = false
	layer.add_child(_banner)
	# rain: thin pale strokes falling across the whole screen (only out of doors, only now and then)
	if G.world_clock < 0.0:
		G.world_clock = float(Save.hub_get("clock"))
	var drop := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	drop.fill(Color(0.78, 0.88, 1.0, 0.55))
	_rain = CPUParticles2D.new()
	_rain.texture = ImageTexture.create_from_image(drop)
	var view0 := UI.screen_size(self)
	_rain.position = Vector2(view0.x * 0.5 + 40.0, -8.0)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(view0.x * 0.5 + 60.0, 2.0)
	_rain.amount = 110
	_rain.lifetime = 0.75
	_rain.direction = Vector2(-0.25, 1.0)
	_rain.spread = 2.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 250.0
	_rain.initial_velocity_max = 300.0
	_rain.emitting = false
	layer.add_child(_rain)
	layer.move_child(_rain, 0)
	_fade = ColorRect.new()
	_fade.color = Color(UI.C_VOID, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	if G.arg("hub") != "":
		start_place = G.arg("hub")       # test: --hub=<place id>
	Story.migrate()
	var begin: Array = [start_place, start_at] if start_place != "" else Places.start()      # Play: the camp you last walked into
	enter(String(begin[0]), begin[1])
	if G.arg("hublevel") != "":          # test: go down into that level after a second
		get_tree().create_timer(1.0).timeout.connect(func() -> void: action.emit("hub_level", G.arg("hublevel")))
	elif (G.arg("shots") == "" and not G.flag("uitour")) or G.flag("story"):
		_story_moment()                  # (--story: also while taking test pictures)
	if G.arg("hubgo") != "":             # test: --hubgo=<place> walks through to that place, takes two pictures, quits
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			await _go(G.arg("hubgo"), Vector2.INF)
			await G.save_shot("hubgo_0.png")
			await get_tree().create_timer(1.6).timeout
			await G.save_shot("hubgo_1.png")
			G.quit(0))
	if G.arg("clock") != "":
		G.world_clock = float(G.arg("clock")) * DAY_LENGTH      # test: --clock=0.7 is deep night
	if G.arg("shots") != "" and G.flag("story"):
		# test: a picture of the story moment, then quit
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			await G.save_shot("hub_story_%s.png" % place_id)
			await get_tree().create_timer(0.3).timeout
			G.quit(0))
	elif G.arg("shots") != "" and G.flag("hub") and G.arg("hubgo") == "":
		if place_id == "village":
			_tour = [Vector2(376, 170), Vector2(180, 276), Vector2(360, 300), Vector2(540, 276), Vector2(150, 176)]
		elif place_id == "world":
			_tour = [Vector2(330, 690), Vector2(730, 700), Vector2(1130, 700), Vector2(1250, 960), Vector2(1580, 570), Vector2(1780, 330), Vector2(1650, 910)]
		elif place.has("fire"):
			_tour = [(place["fire"] as Vector2) + Vector2(0, 40), (place["fire"] as Vector2) + Vector2(60, -60)]
		else:
			_tour = [_hero.position + Vector2(0, 14)]


## Things the story shows by itself when you arrive: the opening (once, in your room), the Druid's
## first words (once, in the village), and a scene in the village after each seal.
func _story_moment() -> void:
	var say := {}
	if place_id == "village" and Save.hub_get("seen:intro") == 0:
		Save.hub_set("seen:intro", 1)
		say = Story.INTRO.duplicate(true)
	elif place_id == "village":
		var scene := Story.take_scene()
		if not scene.is_empty():
			say = {"name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "pages": scene}
	if say.is_empty():
		say = Story.take_arrival(place_id)          # the first time in a new place
	if not say.is_empty():
		if G.flag("story"):
			print("[hub] story moment in %s: %s" % [place_id, String(say["pages"][0])])
		get_tree().create_timer(0.7).timeout.connect(func() -> void: action.emit("talk", say))


## Shows a place (scripts/data/places.gd) with the hero at `at` (or at its own spawn point).
func enter(id: String, at: Vector2 = Vector2.INF) -> void:
	if is_instance_valid(_stage):
		_stage.free()
	place_id = id
	place = Places.get_place(id)
	_solids.clear()
	_people.clear()
	_near = -1
	_last_talk = -1
	_blocks = (place.get("blocks", []) as Array).duplicate()
	_stage = Node2D.new()
	add_child(_stage)
	move_child(_stage, 0)
	var size: Vector2 = place["size"]
	if bool(place.get("outdoor", false)):
		_build_ground()
	else:
		var art := Sprite2D.new()
		art.texture = Art.tex(String(place["art"]))
		art.centered = false
		_stage.add_child(art)
	_ysort = Node2D.new()
	_ysort.y_sort_enabled = true
	_stage.add_child(_ysort)
	_zoom = float(place.get("zoom", 1.0))
	_k = float(place.get("hero_scale", 1.0))
	for p: Array in place.get("props", []):
		_prop(String(p[0]), Vector2(p[1], p[2]), float(p[3]), float(p[4]))
	_build_groves()
	if place.has("forest"):
		_build_forest()
	if place.has("fire"):
		_build_fire()
	for row: Dictionary in place.get("people", []):
		if Story.chapter() >= int(row.get("from", 0)):        # some people only come once the story has moved on
			_add_person(row)
	# companions (scripts/data/allies.gd): one who has arrived stands at her post until she travels
	# with the knight; then she walks behind him wherever he goes
	for mate: Dictionary in Allies.LIST:
		if String(mate.get("place", "")) == id and Allies.arrived(mate) and String(Allies.with().get("id", "")) != String(mate["id"]):
			_add_person({"id": "ally_" + String(mate["id"]), "ally": String(mate["id"]), "name": mate["name"], "title": mate["title"], "sprite": mate["sprite"],
				"hands": mate.get("hands", ""), "pos": mate["pos"], "face": mate.get("face", 1), "role": "ally", "text": ""})
	_build_hero()
	_hero.position = at if at != Vector2.INF else place["spawn"]
	_hero.scale = Vector2(_k, _k)
	refresh_heroes()
	_build_follower()
	_build_roamers()
	if int(place.get("camp", -1)) >= 0 and Save.hub_get("camp") != int(place["camp"]):
		Save.hub_set("camp", int(place["camp"]))      # the next Play opens here
	_build_signs()
	_quests.goal_only = place.has("signs")
	_prompt.scale = Vector2.ONE / _zoom
	if bool(place.get("outdoor", false)):
		_build_light()
	# a place smaller than the screen stands still in the middle; a bigger one scrolls with the hero
	var view := UI.screen_size(self) / _zoom
	_cam.zoom = Vector2(_zoom, _zoom)
	_small = size.x <= view.x and size.y <= view.y
	if _small:
		_cam.limit_left = -100000
		_cam.limit_top = -100000
		_cam.limit_right = 100000
		_cam.limit_bottom = 100000
		_cam.position = (size / 2.0).round()
	else:
		_cam.limit_left = 0 if size.x > view.x else int((size.x - view.x) / 2.0)
		_cam.limit_top = 0 if size.y > view.y else int((size.y - view.y) / 2.0)
		_cam.limit_right = int(size.x) if size.x > view.x else int((size.x + view.x) / 2.0)
		_cam.limit_bottom = int(size.y) if size.y > view.y else int((size.y + view.y) / 2.0)
		_cam.position = _hero.position.round()
	_cam.reset_smoothing()
	if _entered:
		_arrive_t = 2.2                 # the place's name floats up for a moment
	_entered = true


## Through a door or off the edge of the screen: a short fade, then the next place.
func _go(to: String, at: Vector2) -> void:
	if _changing:
		return
	_changing = true
	Sfx.play("door_open", -8.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.12)
	await tw.finished
	enter(to, at)
	_story_moment()
	if _zoom < 1.0:
		# out into the wide world: the camera pulls back and the knight grows with it
		_set_zoom(1.0)
		var pull := create_tween()
		pull.tween_method(_set_zoom, 1.0, _zoom, 1.0).set_delay(0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.16)
	await back.finished
	_changing = false


func _set_zoom(z: float) -> void:
	_cam.zoom = Vector2(z, z)
	var t := 1.0 if _zoom >= 1.0 else clampf((1.0 - z) / (1.0 - _zoom), 0.0, 1.0)
	if is_instance_valid(_hero):
		_hero.scale = Vector2.ONE * lerpf(1.0, _k, t)


## Where the knight stands (main.gd remembers it when he goes into a level, to put him back there).
func hero_pos() -> Vector2:
	return _hero.position if is_instance_valid(_hero) else Vector2.INF


func _exit_tree() -> void:
	G.hub_near = false
	Save.hub_set("clock", int(G.world_clock))


## 0..1 through the day.
func _day_part() -> float:
	return fposmod(G.world_clock, DAY_LENGTH) / DAY_LENGTH


func _is_night() -> bool:
	var t := _day_part()
	return t >= NIGHT_FROM and t < NIGHT_TO


func _raining() -> bool:
	return hash(["weather", int(G.world_clock / WEATHER_SLOT)]) % 100 < RAIN_CHANCE


## Moves the day on and lays its light over the place (out of doors only).
func _weather(delta: float) -> void:
	G.world_clock += delta
	if not bool(place.get("outdoor", false)) or not is_instance_valid(_sky_node):
		_rain.emitting = false
		return
	var t := _day_part()
	var sky: Color = SKY[0][1]
	for i in SKY.size() - 1:
		if t >= float(SKY[i][0]) and t <= float(SKY[i + 1][0]):
			sky = (SKY[i][1] as Color).lerp(SKY[i + 1][1], (t - float(SKY[i][0])) / maxf(float(SKY[i + 1][0]) - float(SKY[i][0]), 0.001))
			break
	var dark := clampf((1.0 - sky.g) / 0.42, 0.0, 1.0)             # 0 by day, 1 in the middle of the night
	var rain := _raining()
	if rain:
		sky *= RAIN_SKY
	var own: Color = place.get("tint", DUSK)                       # a place's own shade (the deep wood is bluer)
	_sky_node.color = sky * Color(own.r / DUSK.r, own.g / DUSK.g, own.b / DUSK.b)
	for lamp: Array in _lamps:
		if is_instance_valid(lamp[0]):
			(lamp[0] as PointLight2D).energy = float(lamp[1]) * lerpf(0.45, 1.5, dark)
	if is_instance_valid(_flies):
		_flies.emitting = dark > 0.3
	_rain.emitting = rain


## The bed in your room: sleep until night falls, or until morning.
func sleep() -> void:
	var to_night := not _is_night()
	var day := floorf(G.world_clock / DAY_LENGTH)
	if to_night:
		G.world_clock = (day + NIGHT_FROM + 0.06) * DAY_LENGTH
	else:
		G.world_clock = (day + 1.0 + 0.02) * DAY_LENGTH
	_banner_text = "Night has fallen" if to_night else "Morning"
	_arrive_t = 2.6
	Sfx.play("door_close", -8.0)


# ------------------------------------------------------------------ building
func _build_ground() -> void:
	var ground := Node2D.new()
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var grass := Art.tex(String(place.get("ground", "hub_grass")))
	ground.draw.connect(func() -> void:
		ground.draw_texture_rect(grass, Rect2(Vector2(-420, -240), (place["size"] as Vector2) + Vector2(840, 480)), true)
		for f: Array in place.get("floor", []):          # a paved rectangle
			ground.draw_texture_rect(Art.tex(String(f[0])), f[1], true))
	_stage.add_child(ground)
	# small flat things on the grass and the trodden paths: the same every time
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	# other ground in big ragged patches (the sands, the bare rock of the mountains)
	for reg: Array in place.get("regions", []):
		var poly := Polygon2D.new()
		poly.texture = Art.tex(String(reg[0]))
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.polygon = _ragged(reg[1], rng)
		_stage.add_child(poly)
	for sh: Rect2 in place.get("shades", []):           # a dark doorway (a flat shape)
		var dark := ColorRect.new()
		dark.color = Color("140c10")
		dark.position = sh.position
		dark.size = sh.size
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(dark)
	for d: Array in place.get("decals", []):            # flat pieces lying on the ground
		var flat := Sprite2D.new()
		flat.texture = Art.tex(String(d[0]))
		flat.position = Vector2(d[1], d[2])
		_stage.add_child(flat)
	var stones := ["hub_dblock_2", "hub_dblock_3", "hub_pebble_3", "hub_dblock_2", "hub_pebble_7"]
	var m := 0
	for trail: Array in place.get("trails", []):        # a road over sand or rock: a line of small stones
		for i in trail.size() - 1:
			var a: Vector2 = trail[i]
			var b: Vector2 = trail[i + 1]
			var count := maxi(1, int(a.distance_to(b) / 22.0))
			for k in count + 1:
				var st := Sprite2D.new()
				st.texture = Art.tex(String(stones[m % stones.size()]))
				st.position = (a.lerp(b, float(k) / float(count)) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))).round()
				_stage.add_child(st)
				m += 1
	var n := 0
	for path: Array in place.get("paths", []):
		for i in path.size() - 1:
			var from: Vector2 = path[i]
			var to: Vector2 = path[i + 1]
			var steps := maxi(1, int(from.distance_to(to) / 30.0))
			for k in steps + 1:
				var s := Sprite2D.new()
				s.texture = Art.tex("hub_patch_%d" % (n % 2))
				s.position = (from.lerp(to, float(k) / float(steps)) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))).round()
				s.flip_h = rng.randf() < 0.5
				_stage.add_child(s)
				n += 1
	var scatter: Dictionary = place.get("scatter", {})
	for id: String in scatter:
		var spec: Array = scatter[id]
		for i in int(spec[1]):
			var s := Sprite2D.new()
			s.texture = Art.tex("%s_%d" % [id, rng.randi() % int(spec[0])])
			var area: Rect2 = place.get("scatter_rect", Rect2(8, 70, (place["size"] as Vector2).x - 16.0, (place["size"] as Vector2).y - 78.0))
			s.position = Vector2(roundf(rng.randf_range(area.position.x, area.end.x)), roundf(rng.randf_range(area.position.y, area.end.y)))
			s.flip_h = rng.randf() < 0.5
			_stage.add_child(s)


## A straight-sided outline made ragged: every side is cut into short steps that wander a little.
func _ragged(points: Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var steps := maxi(1, int(a.distance_to(b) / 34.0))
		var side := (b - a).orthogonal().normalized()
		for k in steps:
			var wobble := 0.0 if k == 0 else rng.randf_range(-13.0, 13.0)
			out.append(a.lerp(b, float(k) / float(steps)) + side * wobble)
	return out


## Pieces scattered over big areas of the world map (woods, cacti, crags): the same every time, never
## on a road, never on top of a place, and far enough apart to walk between.
func _build_groves() -> void:
	if not place.has("groves"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + hash(place_id) % 1000
	var keep: Array = []              # spots to stay well away from
	for row: Dictionary in place.get("people", []):
		keep.append(row["pos"])
	for e: Dictionary in place.get("exits", []):
		keep.append((e["rect"] as Rect2).get_center())
	for pr: Array in place.get("props", []):
		keep.append(Vector2(pr[1], pr[2]))
	for d: Array in place.get("decals", []):
		keep.append(Vector2(d[1], d[2]))
	var roads: Array = (place.get("paths", []) as Array) + (place.get("trails", []) as Array)
	var placed: Array = []
	for grove: Dictionary in place["groves"]:
		var rect: Rect2 = grove["rect"]
		var ids: Array = grove["ids"]
		var solid := float(grove.get("solid", 0.0))
		var apart := 40.0 if solid > 0.0 else 14.0
		var made := 0
		var tries := 0
		while made < int(grove["n"]) and tries < int(grove["n"]) * 12:
			tries += 1
			var at := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)).round()
			var ok := true
			for spot: Vector2 in keep:
				if spot.distance_to(at) < 84.0:
					ok = false
					break
			if ok:
				for road: Array in roads:
					for i in road.size() - 1:
						if Geometry2D.get_closest_point_to_segment(at, road[i], road[i + 1]).distance_to(at) < 40.0:
							ok = false
			if ok and solid > 0.0:
				for other: Vector2 in placed:
					if other.distance_to(at) < apart:
						ok = false
						break
			if not ok:
				continue
			var id := String(ids[rng.randi() % ids.size()])
			var s := _prop(id, at, minf(solid, 4.0), 8.0 if id.begins_with("hub_tree_") else 2.0)
			s.flip_h = rng.randf() < 0.5
			if solid > 0.0:
				placed.append(at)
			made += 1


## Names floating over the places of the world map: gold = open with work to do, grey = still shut,
## green = done, pale = only a name.
func _build_signs() -> void:
	for row: Dictionary in place.get("signs", []):
		var colour: Color = UI.C_BONE
		var text := String(row["text"])
		if String(row.get("need", "")) != "" and not Story.cleared(String(row["need"])):
			colour = UI.C_FAINT
		elif row.has("sites"):
			var left := 0
			var can := false
			for site: String in row["sites"]:
				var ahead := Story.next_in_site(site)
				if not ahead.is_empty():
					left += 1
					can = can or Story.is_open(String(ahead["id"]))
			colour = UI.C_GREEN if left == 0 else (UI.C_GOLD if can else UI.C_FAINT)
		var l := UI.label(text, "Small")
		l.theme = UI.theme()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(160, 0)
		l.add_theme_color_override("font_color", colour)
		l.add_theme_color_override("font_outline_color", UI.C_INK)
		l.add_theme_constant_override("outline_size", 3)
		l.scale = Vector2.ONE / _zoom
		l.position = (row["pos"] as Vector2) - Vector2(80.0 / _zoom, 0)
		l.z_index = 160
		var unlit := CanvasItemMaterial.new()
		unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		l.material = unlit
		_stage.add_child(l)


## A standing piece: its base on `at`, `below` px of the picture hanging under the base line.
func _prop(id: String, at: Vector2, solid: float, below: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(id)
	s.centered = false
	var sz := s.texture.get_size()
	s.offset = Vector2(-floorf(sz.x * 0.5), -sz.y + below)        # a negative `below` lifts the picture above its base
	s.position = at
	_ysort.add_child(s)
	if solid > 0.0:
		_solids.append([at - Vector2(0, solid * 0.4), solid])
	return s


func _anim(id: String, fps: float) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	var i := 0
	while Art.has("%s_f%d" % [id, i]):
		sf.add_frame("default", Art.tex("%s_f%d" % [id, i]))
		i += 1
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.play("default")
	return a


func _build_fire() -> void:
	var pit := _anim("hub_fire_a", 7.0)
	pit.position = (place["fire"] as Vector2)
	pit.offset = Vector2(0, -8)
	_ysort.add_child(pit)
	var flame := _anim("hub_flame", 9.0)
	flame.offset = Vector2(0, -16)
	pit.add_child(flame)
	_solids.append([(place["fire"] as Vector2) - Vector2(0, 6), 11.0])
	if place.has("grill"):
		var grill := _anim("hub_fire_c", 7.0)        # the cook's fire
		grill.position = (place["grill"] as Vector2)
		grill.offset = Vector2(0, -10)
		_ysort.add_child(grill)
		_solids.append([(place["grill"] as Vector2) - Vector2(0, 4), 10.0])


## The forest wall round the clearing, fitted to the size of the map.
func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7071 + hash(place_id) % 1000
	var spec: Dictionary = place["forest"]
	var size: Vector2 = place["size"]
	var open: Array = spec.get("open", [])          # Rect2 areas kept free of trees (ways out)
	var f_big: Array = spec.get("big", Hub.FOREST_BIG)            # a place may plant its own edge (a desert camp has no trees)
	var f_side: Array = spec.get("side", Hub.FOREST_SIDE)
	var f_low: Array = spec.get("low", Hub.FOREST_LOW)
	var f_young: Array = spec.get("young", Hub.FOREST_YOUNG)
	var sink := 8.0 if not spec.has("big") else 2.0
	for p: Array in spec.get("behind", []):
		_prop(String(p[0]), Vector2(p[1], p[2]), 0.0, 8.0)
	var i := 0
	var x := 24.0
	while x < size.x:
		var free := true
		for gap: Array in spec.get("top_gaps", []):
			if x >= float(gap[0]) and x <= float(gap[1]):
				free = false
		if free and not _in_any(open, Vector2(x, 94.0)):
			_prop(String(f_big[i % f_big.size()]), Vector2(x, 94.0 + rng.randf_range(-6, 6)).round(), 0.0, sink)
			i += 1
		x += 78.0
	var y := 176.0
	while y < size.y - 10.0:
		if not _in_any(open, Vector2(4.0, y)):
			_prop(String(f_side[i % f_side.size()]), Vector2(4.0 + rng.randf_range(-4, 4), y).round(), 0.0, sink)
		if not _in_any(open, Vector2(size.x - 4.0, y + 30.0)):
			_prop(String(f_side[(i + 1) % f_side.size()]), Vector2(size.x - 4.0 + rng.randf_range(-4, 4), y + 30.0).round(), 0.0, sink)
		i += 1
		y += 84.0
	x = 22.0
	while x < size.x:
		if not _in_any(open, Vector2(x, size.y - 6.0)):
			_prop(String(f_low[i % f_low.size()]), Vector2(x, size.y - 6.0 + rng.randf_range(-5, 3)).round(), 0.0, minf(sink, 5.0))
		i += 1
		x += 58.0
	x = 70.0
	while x < size.x:
		if not _in_any(open, Vector2(x, size.y - 6.0)):
			_prop(String(f_young[i % f_young.size()]), Vector2(x, size.y + 34.0).round(), 0.0, sink)
		i += 1
		x += 104.0


func _in_any(rects: Array, at: Vector2) -> bool:
	for r: Rect2 in rects:
		if r.has_point(at):
			return true
	return false


func _build_light() -> void:
	_sky_node = CanvasModulate.new()
	_sky_node.color = place.get("tint", DUSK)
	_stage.add_child(_sky_node)
	_lamps.clear()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	for spec: Array in place.get("lights", []):
		var l := PointLight2D.new()
		l.texture = tex
		l.position = spec[0]
		l.color = spec[1]
		l.texture_scale = spec[2]
		l.energy = spec[3]
		l.name = "light%d" % get_child_count()
		_stage.add_child(l)
		_lamps.append([l, float(spec[3])])
	# fireflies: single pale squares drifting over the clearing
	var flies := CPUParticles2D.new()
	flies.position = (place["size"] as Vector2) * 0.5
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = (place["size"] as Vector2) * 0.5
	flies.amount = 40
	flies.lifetime = 7.0
	flies.preprocess = 7.0
	flies.direction = Vector2(0, -1)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 2.0
	flies.initial_velocity_max = 7.0
	flies.scale_amount_min = 1.0
	flies.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(0.8, 1.0, 0.6, 0.0), Color(0.8, 1.0, 0.6, 0.9), Color(0.8, 1.0, 0.6, 0.9), Color(0.8, 1.0, 0.6, 0.0)])
	flies.color_ramp = fade
	flies.z_index = 150
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flies.material = unlit
	_stage.add_child(flies)
	_flies = flies
	_weather(0.0)


## A person standing in the camp: body, both hands, a shadow, and a gold "!" when they have news.
func _add_person(row: Dictionary) -> Dictionary:
	var node := Node2D.new()
	node.position = row["pos"]
	_ysort.add_child(node)
	var mark := UI.label("!", "Head")
	mark.theme = UI.theme()
	mark.add_theme_color_override("font_color", UI.C_GOLD)
	mark.add_theme_color_override("font_outline_color", UI.C_INK)
	mark.add_theme_constant_override("outline_size", 3)
	mark.visible = false
	mark.z_index = 100
	node.add_child(mark)
	if bool(row.get("ghost", false)):
		# someone (or something) already painted into the place's picture: only a spot to talk to
		var top := float(row.get("top", 20.0))
		mark.position = Vector2(-2, -top - 16)
		mark.scale = Vector2.ONE / _zoom
		if float(row.get("solid", 0.0)) > 0.0:
			_solids.append([row["pos"], float(row["solid"])])
		var ghost := {"row": row, "node": node, "hands": null, "mark": mark, "face": 1.0, "top": top, "solid": -1,
			"body": null, "post": row["pos"], "goal": row["pos"], "wait": 0.0, "walks": false, "ghost": true}
		_people.append(ghost)
		return ghost
	var sprite_id := String(row["sprite"])
	var m := Art.meta(sprite_id)
	var bw := float(m.get("body_width", 16.0))
	var bh := float(m.get("body_height", 28.0))
	node.add_child(EnemyScript.make_shadow(clampf(bw * 0.85, 11.0, 18.0)))
	var body := Art.sprite(sprite_id)
	body.position = Vector2(0, 2)
	var face := float(row.get("face", 1))
	body.flip_h = face < 0.0
	node.add_child(body)
	var hands: RefCounted = null
	if String(row.get("hands", "")) != "":
		hands = Hands.new()
		hands.build(node, body, String(row["hands"]), bw, bh)
	mark.position = Vector2(-2, -bh - 16)
	node.move_child(mark, node.get_child_count() - 1)
	_solids.append([row["pos"] - Vector2(0, 2), 6.0])
	var person := {"row": row, "node": node, "hands": hands, "mark": mark, "face": face, "top": bh, "solid": _solids.size() - 1,
		"body": body, "post": row["pos"], "goal": row["pos"], "wait": randf_range(1.0, 4.0), "walks": Art.has_anim(sprite_id, "run")}
	_people.append(person)
	return person


## The companion who travels with the knight walks a few steps behind him in every camp and on
## the world map (only a look: you talk to her on the Party page of the Knight screen).
var _mate: Node2D
var _mate_body: AnimatedSprite2D
var _mate_hands: RefCounted
var _mate_face := 1.0
func _build_follower() -> void:
	_mate = null
	var mate := Allies.with()
	if mate.is_empty():
		return
	_mate = Node2D.new()
	_mate.position = _hero.position + Vector2(-16, 4) * _k
	_mate.scale = Vector2(_k, _k)
	_ysort.add_child(_mate)
	var sprite_id := String(mate["sprite"])
	var m := Art.meta(sprite_id)
	_mate.add_child(EnemyScript.make_shadow(clampf(float(m.get("body_width", 16.0)) * 0.85, 11.0, 18.0)))
	_mate_body = Art.sprite(sprite_id)
	_mate_body.position = Vector2(0, 2)
	_mate.add_child(_mate_body)
	_mate_hands = null
	if String(mate.get("hands", "")) != "":
		_mate_hands = Hands.new()
		_mate_hands.build(_mate, _mate_body, String(mate["hands"]), float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)))


func _move_follower(delta: float) -> void:
	if not is_instance_valid(_mate):
		return
	var to: Vector2 = _hero.position - _mate.position
	var gap := 22.0 * _k
	var walking := to.length() > gap
	if walking:
		var before := _mate.position
		_mate.position += to.normalized() * minf((to.length() - gap) * 6.0, SPEED * float(place.get("speed", 1.0)) * 1.2) * delta
		if absf(_mate.position.x - before.x) > 0.02:
			_mate_face = signf(_mate.position.x - before.x)
	_mate_body.flip_h = _mate_face < 0.0
	var anim := "run" if walking and Art.has_anim(String(Allies.with().get("sprite", "")), "run") else "idle"
	if _mate_body.animation != anim:
		_mate_body.play(anim)
	if _mate_hands != null:
		_mate_hands.update(delta, walking, _mate_face)


func _build_hero() -> void:
	_hero = Node2D.new()
	_ysort.add_child(_hero)


## Puts the hero you play in your hands and the other two by the fire (after a change of hero).
func refresh_heroes() -> void:
	var mine: Dictionary = Heroes.by_id("knight")
	for c in _hero.get_children():
		c.queue_free()
	var m := Art.meta(String(mine["sprite"]))
	_hero.add_child(EnemyScript.make_shadow(clampf(float(m.get("body_width", 16.0)) * 0.85, 13.0, 18.0)))
	_weapon = HeroLook.make_weapon(mine)
	_hero.add_child(_weapon)
	_body = Art.sprite(String(mine["sprite"]))
	_body.position = Vector2(0, 2)
	_body.modulate = mine.get("tint", Color.WHITE)
	_hero.add_child(_body)
	HeroLook.rest(_weapon, _face)
	HeroLook.layer(_weapon, _body, true)
	_off_hand = Hands.new()
	if String(mine.get("hand", "")) != "":
		_off_hand.build(_hero, _body, String(mine["hand"]), float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)), true)
	_near = -1


# ------------------------------------------------------------------ every frame
func _physics_process(delta: float) -> void:
	_time += delta
	_move_follower(delta)
	_move_roamers(delta)
	var move := Vector2.ZERO
	if not frozen and not _changing:
		move = Controls.move
		if not _tour.is_empty():
			move = _tour_step(delta)
	var moving := move.length() > 0.12
	if moving:
		var was := _hero.position
		var to := _hero.position + move.limit_length(1.0) * SPEED * float(place.get("speed", 1.0)) * delta
		var walk: Rect2 = place["walk"]
		var body_r := HERO_RADIUS * _k
		to = to.clamp(walk.position, walk.end)
		for s: Array in _solids:
			var d: Vector2 = to - (s[0] as Vector2)
			var reach: float = float(s[1]) + body_r
			if d.length_squared() < reach * reach and d.length_squared() > 0.0001:
				to = (s[0] as Vector2) + d.normalized() * reach
		for b: Rect2 in _blocks:
			var g := b.grow(body_r)
			if not g.has_point(to):
				continue
			# out through the nearest side
			var gaps := [to.x - g.position.x, g.end.x - to.x, to.y - g.position.y, g.end.y - to.y]
			var least: float = gaps.min()
			if least == gaps[0]:
				to.x = g.position.x
			elif least == gaps[1]:
				to.x = g.end.x
			elif least == gaps[2]:
				to.y = g.position.y
			else:
				to.y = g.end.y
		_hero.position = to.clamp(walk.position, walk.end)
		for e: Dictionary in place.get("exits", []):
			if (e["rect"] as Rect2).has_point(_hero.position) and _tour.is_empty():
				var need := String(e.get("need", ""))
				if need != "" and not Story.cleared(need):
					# the road is still shut: he is turned back and told why
					_hero.position = was
					if _shut_t <= 0.0:
						_shut_t = 3.0
						_banner_text = String(e.get("why", "The way is shut."))
						_arrive_t = 3.0
						Sfx.play("ui_back")
				else:
					_go(String(e["to"]), e["at"])
				break
		if absf(move.x) > 0.1:
			_face = signf(move.x)
	var want := "run" if moving else "idle"
	if _body.animation != want:
		_body.play(want)
	_body.flip_h = _face < 0.0
	HeroLook.rest(_weapon, _face, delta)
	_off_hand.update(delta, moving, _face)
	_shut_t = maxf(0.0, _shut_t - delta)
	if not _small:
		# (zoomed out, the camera moves in steps of two map pixels so the small trees do not shimmer)
		_cam.position = _hero.position.round() if _zoom >= 1.0 else (_hero.position * _zoom).round() / _zoom
	if _arrive_t > 0.0:
		_arrive_t -= delta
		_banner.text = _banner_text if _banner_text != "" else String(place.get("name", ""))
		_banner.visible = not frozen
		_banner.modulate.a = clampf(_arrive_t / 0.6, 0.0, 1.0)
	elif _banner.visible:
		_banner.visible = false
		_banner_text = ""
	_weather(delta)
	_update_people(delta)


func _update_people(delta: float) -> void:
	var best := -1
	var best_d := Hub.TALK_REACH * _k
	var news := _news
	if int(_time * 2.0) != int((_time - delta) * 2.0) or _time < 0.1:
		news = Quests.any_complete()
		for q: Dictionary in _people:
			q["news"] = Story.has_news(String(q["row"]["id"]))
	_news = news
	for i in _people.size():
		var p: Dictionary = _people[i]
		var node: Node2D = p["node"]
		var d := node.position.distance_to(_hero.position)
		var walking := _stroll(p, delta, d)
		if p["hands"] != null:
			(p["hands"] as RefCounted).update(delta, walking, float(p["face"]))
		if d < best_d:
			best_d = d
			best = i
		var mark: Label = p["mark"]
		mark.visible = (news and String(p["row"].get("role", "")) == "quests") or bool(p.get("news", false)) or (String(p["row"].get("role", "")) == "ally" and not Allies.joined(String(p["row"].get("ally", ""))))
		mark.position.y = -float(p["top"]) - 16.0 + roundf(sin(_time * 5.0) * 1.5)
	_near = best
	_quests.visible = not frozen and bool(place.get("outdoor", false))
	G.hub_near = best >= 0 and not frozen
	if best >= 0 and not frozen:
		var p: Dictionary = _people[best]
		_prompt.text = String(p["row"]["name"])
		_prompt.reset_size()
		_prompt.position = ((p["node"] as Node2D).position + Vector2(-_prompt.size.x * 0.5, -float(p["top"]) - 12.0) / _zoom).round()
		_prompt.visible = not place.has("signs")        # on the world map the name already floats over the place
	else:
		_prompt.visible = false



## People are not statues: they turn to the hero when he comes close, and those the pack drew
## walking wander a few steps round their post now and then. Returns true while walking.
func _stroll(p: Dictionary, delta: float, hero_dist: float) -> bool:
	var node: Node2D = p["node"]
	if p["body"] == null:
		return false
	var body: AnimatedSprite2D = p["body"]
	if hero_dist < 44.0 or frozen:
		if absf(_hero.position.x - node.position.x) > 3.0:
			p["face"] = signf(_hero.position.x - node.position.x)
		body.flip_h = float(p["face"]) < 0.0
		if body.animation != "idle":
			body.play("idle")
		return false
	if not bool(p["walks"]):
		return false
	var goal: Vector2 = p["goal"]
	if node.position.distance_to(goal) < 1.0:
		p["wait"] = float(p["wait"]) - delta
		if body.animation != "idle":
			body.play("idle")
		if float(p["wait"]) <= 0.0:
			p["wait"] = randf_range(2.5, 6.0)
			var post: Vector2 = p["post"]
			p["goal"] = (post + Vector2(randf_range(-Hub.STROLL, Hub.STROLL), randf_range(-Hub.STROLL * 0.6, Hub.STROLL * 0.6))).round()
		return false
	var step := (goal - node.position).limit_length(18.0 * delta)
	node.position += step
	if absf(step.x) > 0.001:
		p["face"] = signf(step.x)
	body.flip_h = float(p["face"]) < 0.0
	if body.animation != "run":
		body.play("run")
	if int(p["solid"]) >= 0:
		_solids[int(p["solid"])] = [node.position - Vector2(0, 2), 6.0]
	return true


func _on_talk_pressed() -> void:
	if frozen or _near < 0:
		return
	_talk(_near)


## main.gd calls this after a quest was claimed, so the same window opens again with the news.
func retalk() -> void:
	if _last_talk >= 0 and _last_talk < _people.size():
		_talk(_last_talk)


func talk_to(npc_id: String) -> void:
	for i in _people.size():
		if String(_people[i]["row"]["id"]) == npc_id:
			_talk(i)


func _talk(index: int) -> void:
	_last_talk = index
	var row: Dictionary = _people[index]["row"]
	var id := String(row["id"])
	var said: Array = Story.pages_for(id)[0]
	var pages: Array = said.duplicate()
	if pages.is_empty() and String(row.get("text", "")) != "":
		pages = [String(row["text"])]
	if String(row.get("role", "")) == "mirror":
		action.emit("customize", null)             # the looking glass opens "Your knight"
		return
	var info := {"name": row["name"], "title": row.get("title", ""), "sprite": row.get("sprite", ""), "pages": pages, "heard": id,
		"lines": [], "options": []}
	match String(row.get("role", "chat")):
		"gate":
			# every site this gate opens (scripts/data/story.gd): go in at the first level not cleared,
			# or again from the start; a site that is still shut says what must be done first
			var cleared_here := 0
			var total_here := 0
			for site: String in row.get("sites", ["hill"]):
				var rows := Story.site_levels(site)
				total_here += rows.size()
				var done := 0
				for lv: Dictionary in rows:
					if Story.cleared(String(lv["id"])):
						done += 1
				cleared_here += done
				var ahead := Story.next_in_site(site)
				if not ahead.is_empty():
					if Story.is_open(String(ahead["id"])):
						info["options"].append({"text": "Go in: %s" % String(ahead["name"]), "what": "hub_level", "arg": ahead["id"]})
					else:
						var first := Story.next_level()
						info["lines"].append(["%s is still shut. First: %s, at %s." % [String(ahead["name"]), String(first.get("name", "")),
							String((Story.SITES.get(String(first.get("site", "hill")), {}) as Dictionary).get("name", ""))], UI.C_RED])
				if done > 0 and (rows.size() > 1 or ahead.is_empty()):
					info["options"].append({"text": "Again from the start: %s" % String(rows[0]["name"]), "what": "hub_level", "arg": rows[0]["id"]})
			if Story.next_level().is_empty():
				info["lines"].append(["Every seal is mended.", UI.C_GOLD])
			info["lines"].append(["Cleared here: %d of %d. In all: %d of %d. Walk out from the pause menu when no fight is on." % [cleared_here, total_here,
				Story.chapter(), Story.LEVELS.size()], UI.C_DIM])
			info["lines"].append([_pack_line(), UI.C_GOLD])
		"quests":
			var offered := Quests.offered()
			if offered.is_empty():
				info["lines"].append(["The stones are quiet. You have done all they asked.", UI.C_GOLD])
			for q: Dictionary in offered:
				var reward := Quests.reward_text(q["reward"])
				if Quests.complete(q):
					info["options"].append({"text": "%s: take %s" % [q["name"], reward], "what": "hub_claim", "arg": q["id"]})
				else:
					info["lines"].append("%s: %s  %d/%d  (pays %s)" % [q["name"], q["text"], Quests.progress(q), int(q["need"]), reward])
			info["lines"].append(["Quests done: %d of %d" % [Quests.done_count(), Quests.LIST.size()], UI.C_FAINT])
		"collection":
			info["options"].append({"text": "Open the Collection", "what": "collection"})
			var found := Story.notes_found()
			info["lines"].append(["Notes from the hill: %d of %d" % [found.size(), Story.NOTES.size()], UI.C_DIM])
			if not found.is_empty():
				info["options"].append({"text": "Read the notes", "what": "hub_notes"})
		"side":
			var sq := Quests.from_giver(id)
			if not sq.is_empty():
				var pay := Quests.reward_text(sq["reward"])
				if Quests.is_done(String(sq["id"])):
					info["lines"].append(["%s: done. Thank you, knight." % sq["name"], UI.C_GREEN])
				elif Quests.complete(sq):
					info["options"].append({"text": "%s: take %s" % [sq["name"], pay], "what": "hub_claim", "arg": sq["id"]})
				else:
					info["lines"].append("%s: %s  %d/%d  (pays %s)" % [sq["name"], sq["text"], Quests.progress(sq), int(sq["need"]), pay])
		"ally":
			# a companion at her post (scripts/data/allies.gd): the first time she tells her story and
			# asks to come; later she can be asked along again
			var mate := Allies.row(String(row.get("ally", "")))
			info["heard"] = ""
			info["lines"].append([String(mate.get("about", "")), UI.C_DIM])
			if Allies.joined(String(mate["id"])):
				info["pages"] = ["Ready when you are, Aldous."]
				info["options"].append({"text": "Come with me", "what": "hub_ally", "arg": String(mate["id"])})
			else:
				info["pages"] = (mate.get("pages", []) as Array).duplicate()
				info["options"].append({"text": "Travel with me, %s" % String(mate["name"]), "what": "hub_ally", "arg": String(mate["id"])})
			info["lines"].append(["To send her back here later: tap Lv, then Party.", UI.C_FAINT])
		"train":
			info["options"].append({"text": "Train in the yard", "what": "hub_train"})
		"bed":
			var carried := Story.kit()
			if place_id == "room":
				info["lines"].append(["Your room at the Hollow Flagon. The looking glass by the bed changes your name, armour and sword.", UI.C_DIM])
			else:
				info["lines"].append(["A place to rest. The game opens here next time, at the camp you last walked into.", UI.C_DIM])
			info["lines"].append(["You carry %d item%s. Camp chest: %d coins." % [carried.size(), "" if carried.size() == 1 else "s", Upgrades.coins()], UI.C_GOLD])
			info["options"].append({"text": "Sleep until morning" if _is_night() else "Sleep until nightfall", "what": "hub_sleep"})
			info["options"].append({"text": "Remember how it began (the intro)", "what": "hub_intro"})
		"shop":
			for entry: Array in Shop.stock():
				var item: Dictionary = Items.ALL[String(entry[0])]
				info["lines"].append(["%s: %s" % [item["name"], item["desc"]], UI.C_DIM])
				info["options"].append({"text": "%s: %d coins" % [item["name"], int(entry[1])], "what": "hub_shop", "arg": {"slot": int(entry[2])},
					"off": Upgrades.coins() < int(entry[1]), "why": _poor(int(entry[1]))})
			for row2: Dictionary in Shop.SUPPLIES:
				info["options"].append({"text": "%s: %d coins" % [row2["name"], int(row2["price"])], "what": "hub_shop", "arg": {"supply": row2["id"]},
					"off": Upgrades.coins() < int(row2["price"]), "why": _poor(int(row2["price"]))})
			info["lines"].append(["Camp chest: %d coins. The shelf changes each time you go down." % Upgrades.coins(), UI.C_GOLD])
		"pack":
			info["lines"].append([_pack_line(), UI.C_GOLD])
			var kit := Story.kit()
			info["lines"].append(["You carry %d item%s from the hill." % [kit.size(), "" if kit.size() == 1 else "s"], UI.C_DIM])
			info["lines"].append(["Coins in the camp chest: %d" % Save.hub_get("bank:coins"), UI.C_DIM])
		"hero":
			var h: Dictionary = row["hero"]
			info["lines"].append([String(h.get("desc", "")), UI.C_DIM])
			info["lines"].append([String(h.get("passive", "")), UI.C_DIM])
			info["options"].append({"text": "Play as %s" % String(h["name"]), "what": "hub_hero", "arg": h["id"]})
	# what this person sells for coins from the camp chest (scripts/data/upgrades.gd)
	var sell := String(row.get("as", id))          # "as": "smith" = sells what the village smith sells
	var sells := false
	for up: Dictionary in Upgrades.LIST:
		if String(up["at"]) != sell:
			continue
		sells = true
		var t := Upgrades.tier(String(up["id"]))
		var price := Upgrades.cost(up)
		info["lines"].append(["%s %d/%d: %s" % [up["name"], t, Upgrades.steps(up), up["text"]], UI.C_DIM if price >= 0 else UI.C_FAINT])
		if price >= 0:
			info["options"].append({"text": "%s: %d coins" % [up["name"], price], "what": "hub_buy", "arg": up["id"], "off": Upgrades.coins() < price, "why": _poor(price)})
	if sell == "smith":
		# the weapons he can fit: carried, owned, forged here, or still out in the world
		var carried := Weapons.current()
		info["lines"].append(["You carry the %s: %s" % [String(carried["name"]).to_lower(), carried["text"]], UI.C_BONE])
		for w: Dictionary in Weapons.LIST:
			var wid := String(w["id"])
			if wid == String(carried["id"]):
				continue
			if Weapons.owned(wid):
				info["options"].append({"text": "Carry the %s" % String(w["name"]).to_lower(), "what": "hub_weapon", "arg": wid})
			elif w.has("price"):
				info["options"].append({"text": "Forge the %s: %d coins" % [String(w["name"]).to_lower(), int(w["price"])], "what": "hub_forge", "arg": wid,
					"off": Upgrades.coins() < int(w["price"]), "why": _poor(int(w["price"]))})
			else:
				info["lines"].append(["%s: %s." % [w["name"], w["how"]], UI.C_FAINT])
		# helmets, armour and rings (scripts/data/gear.gd) have a window of their own: shelf_info()
		info["options"].append({"text": "Helmets, armour and rings", "what": "hub_shelf", "arg": String(row.get("name", "The smith"))})
	if sells:
		info["lines"].append(["Camp chest: %d coins. What you carry out of the hill goes in (half if you fall)." % Upgrades.coins(), UI.C_GOLD])
	# heard it already this visit and nothing new: straight to the choices
	if not Story.has_news(id) and _talked.has(id) and not ((info["options"] as Array).is_empty() and (info["lines"] as Array).is_empty()):
		info["pages"] = []
	_talked[id] = true
	action.emit("talk", info)


# ------------------------------------------------------------------ roamers (the world map's monsters)
## Monsters that walk the world map (scripts/data/roamers.gd). Each strolls round its own patch,
## comes for the knight when he is near (a red "!" over it), gives up when he gets away, and on a
## touch asks main.gd for its fight ("hub_encounter"). Only on the world map.
var _roamers: Array = []
var _roam_grace := 0.0
var _caught := false
func _build_roamers() -> void:
	_roamers.clear()
	_caught = false
	_roam_grace = Roamers.GRACE
	if place_id != "world":
		return
	for i in Roamers.SPOTS.size():
		if not Roamers.here(i):
			continue
		var spot: Dictionary = Roamers.SPOTS[i]
		var row := Enemies.info(Roamers.shows(i))
		var sprite_id := String(row.get("sprite", "pc_skeleton_base"))
		var m := Art.meta(sprite_id)
		var node := Node2D.new()
		node.position = spot["at"]
		node.scale = Vector2(_k, _k)
		_ysort.add_child(node)
		node.add_child(EnemyScript.make_shadow(clampf(float(m.get("body_width", 16.0)) * 0.85, 11.0, 18.0)))
		var body := Art.sprite(sprite_id)
		body.position = Vector2(0, 2)
		body.modulate = row.get("tint", Color.WHITE)
		node.add_child(body)
		var hands: RefCounted = null
		if String(row.get("hands", "")) != "":
			hands = Hands.new()
			hands.build(node, body, String(row["hands"]), float(m.get("body_width", 16.0)), float(m.get("body_height", 28.0)))
		var mark := UI.label("!", "Head")
		mark.theme = UI.theme()
		mark.add_theme_color_override("font_color", UI.C_RED)
		mark.add_theme_color_override("font_outline_color", UI.C_INK)
		mark.add_theme_constant_override("outline_size", 3)
		mark.position = Vector2(-2, -float(m.get("body_height", 28.0)) - 16.0)
		mark.visible = false
		node.add_child(mark)
		_roamers.append({"spot": i, "node": node, "body": body, "hands": hands, "mark": mark, "home": spot["at"], "leash": float(spot.get("leash", 60.0)),
			"goal": spot["at"], "wait": randf_range(0.5, 3.0), "chasing": false, "face": 1.0, "runs": Art.has_anim(sprite_id, "run"), "tint": row.get("tint", Color.WHITE)})


func _move_roamers(delta: float) -> void:
	if _roamers.is_empty() or frozen or _changing or _caught:
		return
	_roam_grace -= delta
	var walk: Rect2 = place["walk"]
	for r: Dictionary in _roamers:
		var node: Node2D = r["node"]
		var to_hero: Vector2 = _hero.position - node.position
		var far := to_hero.length()
		var home: Vector2 = r["home"]
		if not r["chasing"] and _roam_grace <= 0.0 and _tour.is_empty() and far < Roamers.SEE:
			r["chasing"] = true
			Sfx.play("enemy_shoot", -10.0, 0.05, 0.7)
		elif r["chasing"] and (far > Roamers.LOSE or node.position.distance_to(home) > float(r["leash"]) + 220.0):
			r["chasing"] = false
			r["goal"] = home
		var step := Vector2.ZERO
		if r["chasing"]:
			if far < Roamers.TOUCH:
				_caught = true
				Sfx.play("door_close", -4.0)
				action.emit("hub_encounter", int(r["spot"]))
				return
			step = to_hero.normalized() * Roamers.CHASE * delta
		else:
			var to_goal: Vector2 = (r["goal"] as Vector2) - node.position
			if to_goal.length() < 3.0:
				r["wait"] = float(r["wait"]) - delta
				if float(r["wait"]) <= 0.0:
					r["wait"] = randf_range(1.0, 4.0)
					r["goal"] = home + Vector2.RIGHT.rotated(randf() * TAU) * randf() * float(r["leash"])
			else:
				step = to_goal.normalized() * Roamers.WALK * delta
		var moving := step.length() > 0.001
		if moving:
			node.position = (node.position + step).clamp(walk.position, walk.end)
			if absf(step.x) > 0.01:
				r["face"] = signf(step.x)
		var body: AnimatedSprite2D = r["body"]
		body.flip_h = float(r["face"]) < 0.0
		var anim := "run" if moving and r["runs"] else "idle"
		if body.animation != anim:
			body.play(anim)
		if r["hands"] != null:
			(r["hands"] as RefCounted).update(delta, moving, float(r["face"]), 0.0, true, null, r["tint"])
		var mark: Label = r["mark"]
		mark.visible = r["chasing"]
		mark.position.y = -float(Art.meta(String(Enemies.info(Roamers.shows(int(r["spot"]))).get("sprite", ""))).get("body_height", 28.0)) - 16.0 + roundf(sin(_time * 8.0) * 1.5)


## A line in the place's banner for a few seconds (main.gd: what a won roamer fight paid).
func say(text: String) -> void:
	_banner_text = text
	_arrive_t = 3.5


## Who travels with the knight changed (main.gd): build the place again around him, where he stands.
func refresh_party() -> void:
	enter(place_id, _hero.position)


## The smith's shelf of gear: the cheapest few pieces he can make here that the knight does not
## own yet (scripts/data/gear.gd shelf(); a camp further out has better ones).
func shelf_info(who: String) -> Dictionary:
	var info := {"name": who, "title": "helmets, armour, rings", "pages": [], "lines": [], "options": []}
	var shelf := Gear.shelf(int(Gear.CAMP_TIER.get(place_id, 0)))
	shelf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) < int(b["price"]))
	for g: Dictionary in shelf.slice(0, Gear.SHELF_SIZE):
		var cost := int(g["price"])
		info["lines"].append(["%s, %s: %s" % [g["name"], Gear.rarity_name(g).to_lower(), Gear.text(g)], Gear.color(g)])
		info["options"].append({"text": "%s: %d coins" % [g["name"], cost], "what": "hub_gear", "arg": g["id"], "off": Upgrades.coins() < cost, "why": _poor(cost)})
	if shelf.is_empty():
		info["lines"].append(["The shelf is bare: you own every piece made here. Monsters, chests and bosses carry others.", UI.C_DIM])
	else:
		info["lines"].append(["Camp chest: %d coins. Wear what you buy: tap Lv, then Gear." % Upgrades.coins(), UI.C_GOLD])
	return info


## Why a thing cannot be bought, and where coins come from.
func _poor(price: int) -> String:
	return "It costs %d coins and the camp chest holds %d. Coins you carry out of the hill go into the chest: all of them when you walk out or win, half when you fall." % [price, Upgrades.coins()]


func _pack_line() -> String:
	var pack := Quests.pack()
	if pack.is_empty():
		return "Your pack is empty. Quests fill it."
	return "In your pack for the next run: " + Quests.reward_text(pack)


## --hub --shots: walk to a few spots and save a picture at each.
func _tour_step(delta: float) -> Vector2:
	var target: Vector2 = _tour[0]
	var d := target - _hero.position
	_tour_t += delta
	if d.length() < 3.0 or _tour_t > 9.0:
		_tour_t = 0.0
		G.save_shot("hub_%d.png" % (5 - _tour.size()))
		_tour.pop_front()
		if _tour.is_empty():
			_tour_end()
		return Vector2.ZERO
	return d.normalized()


func _tour_end() -> void:
	await get_tree().create_timer(0.3).timeout
	if G.arg("hubtalk") != "":
		talk_to(G.arg("hubtalk"))
		await get_tree().create_timer(0.8).timeout
		G.save_shot("hub_talk_%s.png" % G.arg("hubtalk"))
		await get_tree().create_timer(0.3).timeout
	G.quit(0)
