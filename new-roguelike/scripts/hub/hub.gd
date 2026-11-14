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

const Hd = preload("res://scripts/fx/hd.gd")
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
const WalkKit = preload("res://scripts/ui/walk_kit.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Hands = preload("res://scripts/entities/hands.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")
const View3D = preload("res://scripts/hub/view3d.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Supplies = preload("res://scripts/data/supplies.gd")
const Arms = preload("res://scripts/data/arms.gd")
const Errands = preload("res://scripts/data/errands.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Skills = preload("res://scripts/data/skills.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Wounds = preload("res://scripts/data/wounds.gd")
const Interior = preload("res://scripts/hub/arch/interior.gd")
const Travel = preload("res://scripts/data/travel.gd")

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
var _ambushed := {}               ## (v0.43.0) story fights already sprung on this visit
var _talked := {}               ## npc ids spoken to during this visit
var _quests: Control
var _small := false              ## the place fits on the screen: the camera stands still
var _entered := false
var _banner: Control             ## the place banner (scripts/ui/walk_kit.gd Banner): name on arrival, Night / Morning
var _ui: Control                 ## the interface's root on the UI grid (UI.attach): story line, coins, banner, toast, help
var _toast: Control              ## one small card bottom-centre (WalkKit Toast): hub.say(), "The way is shut."
var _coins: Control              ## the coins, top-right (WalkKit Coins)
var _hurt: Label                 ## (v0.38.0) the party's health while somebody is hurt
var _help: Control               ## "[C] Knight  [Esc] Pause" bottom-right
var _walk_t := 0.0               ## seconds the knight has been walking without a stop
var _still_t := 0.0              ## seconds he has stood still
var _sky_node: CanvasModulate
var _lamps: Array = []           ## [PointLight2D, energy by day]
var _flies: CPUParticles2D
var _rain: CPUParticles2D
var _zoom := 1.0                 ## the place's camera zoom (0.5 on the world map: twice as much is seen)
var _k := 1.0                    ## how big the knight is drawn there (2 on the world map)
var _shut_t := 0.0               ## a moment before a shut road says so again
var _doors: Array = []           ## (the dungeon kit) the shut doors of this place: {"row", "near": Rect2 just round its block}
var _quiet := false              ## the place is being built again where he stands (a lever, a chest): no banner, no story
var _view: Node3D                ## the lit 3D look (scripts/hub/view3d.gd): it shows what this file builds. null = the old flat look


func _ready() -> void:
	Arms.ensure()                      # (v0.39.0) old saves: what the level taught stays taught; best arms worn
	for land: String in G.arg("lit").split(",", false):     # test: --lit=elfwood,sands : those beacons burn
		Save.hub_set("tale:lit:" + land, 1)
	for key: String in G.arg("set").split(",", false):     # test: --set=dkey:mine,dlever:a : those save keys are 1 (a key held, a lever pulled, a chest opened)
		Save.hub_set(key, 1)
	if G.arg("lvl") != "":            # test: --lvl=<n> : the knight's level
		Save.hub_set("rpg:lvl", int(G.arg("lvl")))
	if G.arg("coins") != "":          # test: --coins=<n> in the purse
		Save.hub_set("bank:coins", int(G.arg("coins")))
	if G.arg("step") != "":           # test: --step=<n> : the story at that step
		Save.hub_set("tale:step", maxi(Save.hub_get("tale:step"), int(G.arg("step"))))
	if G.arg("buyarms") != "":        # test: --buyarms=<n> : buy the next n tiers of every line the story allows
		for i in int(G.arg("buyarms")):
			for line: String in Arms.LINES:
				Arms.buy(line)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Controls.action_enabled = true
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	# The lit 3D look (the owner, 12 Nov 2026: "for the entire game"). `--flat` keeps the old picture;
	# tests without a screen have nothing to show it on.
	if not G.flag("flat") and bool(Save.setting("look3d")) and DisplayServer.get_name() != "headless":
		_view = View3D.new()
		add_child(_view)
		_view.call("setup", self)
	_prompt = UI.label("", "Small")
	_prompt.set_meta("walk_kind", "tag")         # (the 3D look shows a name tag + "[Q] Talk": view3d.gd _twin)
	_prompt.theme = UI.theme()
	_prompt.z_index = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", UI.C_INK)
	_prompt.add_theme_constant_override("outline_size", 3)
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(0.03, 0.03, 0.05, 0.62)
	tag.set_corner_radius_all(3)
	tag.content_margin_left = 3
	tag.content_margin_right = 3
	tag.content_margin_top = 0
	tag.content_margin_bottom = 1
	_prompt.add_theme_stylebox_override("normal", tag)
	add_child(_prompt)
	Controls.action_pressed.connect(_on_talk_pressed)
	# rain (game px) on the HUD layer; the interface on its own layer on the UI grid (UI px)
	var layer := CanvasLayer.new()
	layer.layer = G.LAYER_HUD
	add_child(layer)
	_build_hud()
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
	var over := CanvasLayer.new()            # (over the interface too, as before)
	over.layer = G.LAYER_HUD
	add_child(over)
	over.add_child(_fade)
	if G.arg("hub") != "":
		start_place = G.arg("hub")       # test: --hub=<place id>
	Story.migrate()
	var begin: Array = [start_place, start_at] if start_place != "" else Places.start()      # Play: the place you were last in
	if start_place == "" and Tale.on() and get_parent() != null and get_parent().get_node_or_null("Battle") != null:
		# main.gd shows "no place" after a LOST fight (its battle is still being put away): he wakes at the
		# last fire or bed he walked past, not always in Wickmere
		begin = Places.wake()
		_woke = true
	var hop := Tale.take_travel() if Tale.on() else {}       # stepping into a beacon's light (scripts/data/travel.gd)
	if not hop.is_empty():
		begin = [String(hop["place"]), hop["at"]]
		Sfx.play("ui_start", -4.0)
	enter(String(begin[0]), begin[1])
	if G.flag("kittest"):            # test: --hub=kit_test --kittest : the kit's pieces are USED one after the other and checked
		_kit_test.call_deferred()
	if G.flag("resumetest"):         # test: --resumetest : where Play and a lost fight would put him, place after place
		_resume_test.call_deferred()
	if G.flag("traveltest"):         # test: --traveltest : every stop of travel.gd is stood on and checked
		_travel_test.call_deferred()
	if G.arg("hubfight") != "":          # test: that roamer touches him after a second (with --autobattle a bot fights)
		get_tree().create_timer(1.0).timeout.connect(func() -> void: action.emit("hub_encounter", int(G.arg("hubfight"))))
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
		if place.has("tour"):
			_tour = (place["tour"] as Array).duplicate()         # the place says where its test pictures are taken
		elif place_id == "village":
			_tour = [Vector2(376, 170), Vector2(180, 276), Vector2(360, 300), Vector2(540, 276), Vector2(150, 176)]
		elif place_id == "world":
			_tour = [Vector2(330, 690), Vector2(730, 700), Vector2(1130, 700), Vector2(1250, 960), Vector2(1580, 570), Vector2(1780, 330), Vector2(1650, 910)]
		elif place.has("fire"):
			_tour = [(place["fire"] as Vector2) + Vector2(0, 40), (place["fire"] as Vector2) + Vector2(60, -60)]
		else:
			_tour = [_hero.position + Vector2(0, 14)]
		if G.arg("tourat") != "":         # test: --tourat=x,y : the knight walks there, one picture (hub_4.png)
			var xy := G.arg("tourat").split(",")
			_tour = [Vector2(float(xy[0]), float(xy[1]))]
			_tour_jump = G.flag("tourjump")      # test: --tourjump : he starts right beside that spot (no walk across the map)
		if G.flag("walkui"):
			# test: --walkui : first a picture of the interface standing still (hub_walkui.png): the place
			# banner, a toast (--hubsay=<words>), the help strip, the story line; then the tour
			var later := _tour
			_tour = []
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				_show_banner(String(place.get("name", "")))
				say(G.arg("hubsay", "Won: +38 XP, 12 coins")))
			get_tree().create_timer(1.3).timeout.connect(func() -> void:
				await G.save_shot("hub_walkui.png")
				_tour = later)


## Things the story shows by itself when you arrive: the opening (once, in your room), the Druid's
## first words (once, in the village), and a scene in the village after each seal.
func _story_moment() -> void:
	var say := {}
	if Tale.on():
		say = Tale.take_scene(place_id)          # the story's own scenes (scripts/data/tale.gd SCENES)
	elif place_id == "village" and Save.hub_get("seen:intro") == 0:
		Save.hub_set("seen:intro", 1)
		say = Story.INTRO.duplicate(true)
	elif place_id == "village":
		var scene := Story.take_scene()
		if not scene.is_empty():
			say = {"name": "Ysolde", "title": "Druid of the Stones", "sprite": "pc_elf_druid", "pages": scene}
	if say.is_empty() and not Tale.on():
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
	Sfx.place(id)                          # its music, ambience and ground underfoot
	_solids.clear()
	_people.clear()
	_near = -1
	_last_talk = -1
	_doors.clear()
	if not _quiet:
		_ambushed.clear()
		if Tale.on():
			Places.remember(id, place, at)      # Play starts here next time; a fire or bed here is where a lost fight wakes him
	_blocks = (place.get("blocks", []) as Array).duplicate()
	if _built_inside():
		_blocks = Interior.blocks(place)          # the 3D look builds the room for real: walls and furniture block (scripts/hub/arch/interior.gd)
	_stage = Node2D.new()
	add_child(_stage)
	move_child(_stage, 0)
	var size: Vector2 = place["size"]
	if bool(place.get("outdoor", false)):
		_build_ground()
	elif not _built_inside():
		var art := Sprite2D.new()
		art.texture = Art.tex(String(place["art"]))
		art.centered = false
		_stage.add_child(art)
	_ysort = Node2D.new()
	_ysort.y_sort_enabled = true
	_stage.add_child(_ysort)
	_zoom = float(place.get("zoom3d" if _built_inside() else "zoom", 1.0))
	_k = float(place.get("hero_scale", 1.0))
	for p: Array in place.get("props", []):
		var s := _prop(String(p[0]), Vector2(p[1], p[2]), float(p[3]), float(p[4]))
		s.flip_h = p.size() > 5 and bool(p[5])          # (field 5: mirrored)
		if p.size() > 6:
			s.modulate = p[6]                             # (field 6: a tint, e.g. the black thorn of the world map)
		if String(p[0]) == "hub_slantern":
			_lantern_glass(s, bool(place.get("iron_lamps", false)) and _view != null)
			if bool(place.get("iron_lamps", false)) and _view != null:
				s.set_meta("no3d", true)            # (the 3D look stands an iron street lamp there: scripts/hub/arch/sites.gd)
		if String(p[0]) == "hub_gfountain" and place.has("fountain") and _view != null:
			s.set_meta("no3d", true)                # (the 3D look builds the fountain in stone: scripts/hub/arch/sites.gd)
	if Tale.on():
		_build_doors()
	# houses and water: the 3D look builds them as real things (scripts/hub/view3d.gd); the old
	# flat look shows a house as the pack's flat pieces and water as a flat shape
	if _view == null:
		for h: Dictionary in place.get("houses", []):
			for p: Array in Tale.house_props(h):
				_prop(String(p[0]), Vector2(p[1], p[2]), float(p[3]), float(p[4]))
	for pond: Dictionary in place.get("water", []):
		var c: Vector2 = pond["at"]
		var r: Vector2 = pond["radius"]
		# (a harbour basin, "quay": true, lists its own stops along its quay wall: scripts/data/places.gd _harbour)
		var n := -1 if bool(pond.get("quay", false)) else maxi(1, int(ceil(r.x / r.y)))
		for i in range(-n, n + 1):                           # nobody walks into it: a row of round stops
			_solids.append([c + Vector2(float(i) / float(n) * (r.x - r.y * 0.7), 0.0), r.y * 0.9])
		for stop: Array in pond.get("stops", []):
			_solids.append(stop)
		if _view == null:
			var shape := Polygon2D.new()
			var ring := PackedVector2Array()
			for k in 28:
				ring.append(c + Vector2(cos(TAU * k / 28.0) * r.x, sin(TAU * k / 28.0) * r.y))
			shape.polygon = ring
			shape.color = Color("1c5560")
			_stage.add_child(shape)
			_stage.move_child(shape, _ysort.get_index())
	_build_groves()
	if place.has("forest"):
		_build_forest()
	if place.has("fire"):
		_build_fire()
	if place.has("beacon"):
		_build_beacon()
	for row: Array in place.get("anims", []):          # things that move by themselves: [id, x, y, fps, solid, turned round]
		var moving := _anim(String(row[0]), float(row[3]))
		var frame := moving.sprite_frames.get_frame_texture("default", 0).get_size()
		moving.position = Vector2(row[1], row[2])
		moving.offset = Vector2(0, -frame.y * 0.5)
		moving.flip_h = row.size() > 5 and bool(row[5])
		_ysort.add_child(moving)
		if float(row[4]) > 0.0:
			_solids.append([Vector2(row[1], row[2]) + Vector2(-8.0 if moving.flip_h else 8.0, -4.0), float(row[4])])
	for spot: Vector2 in place.get("torches", []):     # the lit glass on top of a lamp post (the post is a prop)
		var glass := Sprite2D.new()
		glass.texture = _lamp_glass()
		glass.position = spot + Vector2(0, 1)
		glass.offset = Vector2(0, -51)
		_ysort.add_child(glass)
	for row: Dictionary in place.get("people", []):
		if Tale.on():
			if Tale.here(row):                                  # the story says who stands here at this step
				_add_person(row)
		elif Story.chapter() >= int(row.get("from", 0)):        # some people only come once the story has moved on
			_add_person(row)
	# companions (scripts/data/allies.gd): one who has arrived stands at her post until she travels
	# with the knight; then she walks behind him wherever he goes
	for mate: Dictionary in Allies.LIST:
		if String(mate.get("place", "")) == id and Allies.arrived(mate) and String(Allies.with().get("id", "")) != String(mate["id"]):
			_add_person({"id": "ally_" + String(mate["id"]), "ally": String(mate["id"]), "name": mate["name"], "title": mate["title"], "sprite": mate["sprite"],
				"hands": mate.get("hands", ""), "pos": mate["pos"], "face": mate.get("face", 1), "role": "ally", "text": ""})
	if Tale.on():
		for lever: Dictionary in place.get("levers", []):      # (the dungeon kit) levers: scripts/data/more.gd places
			_add_lever(lever)
		for f: Dictionary in Errands.opened_in(id):     # (the quality pass) an opened chest stays where it stood, open
			var open_tex := Art.tex(Errands.open_sprite(f))
			var open_pic := Sprite2D.new()
			open_pic.texture = open_tex
			open_pic.position = _free_spot(f["pos"])
			open_pic.offset = Vector2(0, -open_tex.get_size().y * 0.5 + 2.0)
			_ysort.add_child(open_pic)
		for f: Dictionary in Errands.finds_in(id, _is_night()):      # (v0.42.0) chests and what side quests send you to find
			_add_find(f)
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
	refresh_hurt()
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
		if _view != null and bool(place.get("outdoor", false)) and size.y > view.y and Hd.on():
			# HD: room above the north edge, so the facades, roofs and the hill behind the town are
			# seen over the square (the 3D camera looks a little past the knight, scripts/hub/view3d.gd)
			_cam.limit_top = -int(view.y * 0.3)
		_cam.limit_right = int(size.x) if size.x > view.x else int((size.x + view.x) / 2.0)
		_cam.limit_bottom = int(size.y) if size.y > view.y else int((size.y + view.y) / 2.0)
		_cam.position = _hero.position.round()
	_cam.reset_smoothing()
	if _entered and not _quiet:
		_show_banner(String(place.get("name", "")))       # the place's name floats up for a moment
	_entered = true
	if Tale.on() and not _quiet:
		var news := Tale.entered(id)                           # walking in here may move the story on
		if news.has("say"):
			say(String(news["say"]))
	if _view != null:
		_view.call("rebuild")
	if G.flag("allfinds") and not _quiet and Tale.on():
		_reach_all.call_deferred()             # test: can everything here be got to? ("[reach] ...")


## Builds the place again round the knight where he stands (a door opened, a lever pulled, a chest
## opened, night fell): no banner, no story moment, the story's ambushes stay sprung.
func _rebuild() -> void:
	_quiet = true
	enter(place_id, _hero.position)
	_quiet = false


# ------------------------------------------------------------------ the dungeon kit (doors, levers)
## DOORS: a place's "doors" [{"id", "rect", "key": key id  or  "lever": lever id, "why", "sprite", "pos"}].
## A shut door is a block (its "rect") with a picture on it ("sprite", default the pack's barred stone
## gate; "pos" = where its foot stands, default the middle of the rect's near edge).
##   "key"    it opens when the knight walks against it carrying that key ("dkey:<id>"; chests and people
##            give keys); once open it stays open ("ddoor:<door id>").
##   "lever"  it is open while that lever is pulled ("dlever:<id>").
## "why" is said when he pushes against it shut. "open": a picture left standing when it is open.
func door_shut(d: Dictionary) -> bool:
	if d.has("lever"):
		return Save.hub_get("dlever:" + String(d["lever"])) <= 0
	return Save.hub_get("ddoor:" + String(d["id"])) <= 0


func _build_doors() -> void:
	for d: Dictionary in place.get("doors", []):
		var rect: Rect2 = d["rect"]
		var foot: Vector2 = d.get("pos", Vector2(rect.get_center().x, rect.end.y))
		if not door_shut(d):
			if String(d.get("open", "")) != "":
				_prop(String(d["open"]), foot, 0.0, 0.0)
			continue
		_blocks.append(rect)
		_doors.append({"row": d, "near": rect.grow(HERO_RADIUS * _k + 2.5)})
		if String(d.get("sprite", "hub_gate_0")) != "":
			_prop(String(d.get("sprite", "hub_gate_0")), foot, 0.0, 0.0)


## The knight pushes against a shut door: with its key it opens (true = the place was built again),
## without, it says why.
func _push_doors() -> bool:
	for door: Dictionary in _doors:
		if not (door["near"] as Rect2).has_point(_hero.position):
			continue
		var d: Dictionary = door["row"]
		var key := String(d.get("key", ""))
		if key != "" and Save.hub_get("dkey:" + key) > 0:
			Save.hub_set("ddoor:" + String(d["id"]), 1)
			Save.flush()
			Sfx.play("door_open", -2.0)
			_toast.call("show_text", String(d.get("opened", Tale.KIT["door_key"])), 2.5)
			print("[door] %s in %s opens with the key %s" % [d["id"], place_id, key])
			_rebuild()
			return true
		if _shut_t <= 0.0:
			_shut_t = 3.0
			_toast.call("show_text", String(d.get("why", Tale.KIT["locked"] if key != "" else Tale.KIT["door_lever"])), 2.5)
			Sfx.play("ui_back")
		return false
	return false


## LEVERS: a place's "levers" [{"id", "pos", "name", "say", "do"}]: a lever of the pack standing there. Pulling
## it sets "dlever:<id>" for good (doors with "lever": id open), says "say", and does "do" (as tale.gd "do":
## e.g. {"all": {"flags": ["dlever:a", "dlever:b"], "do": {...}}} for two levers that open one thing).
func _add_lever(lever: Dictionary) -> void:
	var pulled := Save.hub_get("dlever:" + String(lever["id"])) > 0
	_add_person({"id": "lever:" + String(lever["id"]), "name": String(lever.get("name", Tale.KIT["lever_name"])), "title": "", "ghost": true,
		"pos": lever["pos"], "top": 14, "role": "lever", "lever": String(lever["id"]), "text": "", "solid": 4.0,
		"prop": String(lever.get("sprite_on", "lever_right")) if pulled else String(lever.get("sprite", "lever_left")),
		"say": lever.get("say", Tale.KIT["lever"]), "do": lever.get("do", {})})


func _pull_lever(row: Dictionary) -> void:
	var key := "dlever:" + String(row["lever"])
	if Save.hub_get(key) > 0:
		_toast.call("show_text", Tale.KIT["lever_done"], 2.0)
		Sfx.play("ui_back")
		return
	Save.hub_set(key, 1)
	var fx := Tale.apply(row.get("do", {}))          # (it also writes the save)
	Save.flush()
	Sfx.play("door_close", -2.0)
	print("[lever] %s in %s pulled" % [row["lever"], place_id])
	_rebuild()
	_toast.call("show_text", String(fx.get("say", row.get("say", Tale.KIT["lever"]))), 3.0)


## (v0.38.0) the party's health line under the coins: only while somebody is hurt.
func refresh_hurt() -> void:
	if not is_instance_valid(_hurt):
		return
	if G.flag("hurt") and Save.hub_get("wound:hp:knight") == 0:
		Save.hub_set("wound:hp:knight", 30)        # test: --hurt : the knight comes back from a hard fight
	var bits: Array = []
	var low := false
	if Wounds.any():
		for u: Dictionary in Battles.party():
			bits.append("%s %d/%d" % [String(u["name"]), int(u["start_hp"]), int(u["max_hp"])])
			low = low or float(u["start_hp"]) < float(u["max_hp"]) * 0.35
	_hurt.text = "   ".join(bits)
	_hurt.add_theme_color_override("font_color", UI.C_RED if low else UI.C_PARCH)


## Is this place a room the 3D look builds for real (a place's "inside", scripts/hub/arch/interior.gd)?
## Then its painted picture, its painted people and the picture's blocks are not used.
func _built_inside() -> bool:
	return _view != null and place.has("inside")


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


## What the knight walks on right here, for the sound of his steps: "wood" on a jetty, "stone" on
## paving, "sand" in the dry half of the world map, else the place's own ground ("": sfx.gd PLACES).
func _ground_here() -> String:
	if not is_instance_valid(_hero) or not bool(place.get("outdoor", false)):
		return ""
	var at := _hero.position
	for d: Dictionary in place.get("decks", []):
		if (d["rect"] as Rect2).has_point(at):
			return "wood"
	if place_id == "world":
		if at.x > 1330.0 and at.y < 440.0:
			return "stone"                       # the bare rock of the Cinder Mountains
		return "sand" if _dry_here() else "grass"
	var paved: Variant = place.get("floor", [])
	if paved is Array and not (paved as Array).is_empty():
		for row: Array in paved:
			if (row[1] as Rect2).has_point(at):
				return "stone"
		return "sand" if String(place.get("ground", "")) == "hub_sand" else "grass"
	return ""


func _raining() -> bool:
	return hash(["weather", int(G.world_clock / WEATHER_SLOT)]) % 100 < RAIN_CHANCE


## No rain in the sands: Dustwatch, the Sunwell, and the desert half of the world map (east of x 860).
func _dry_here() -> bool:
	if place_id in ["dustwatch", "suncourt"]:
		return true
	return place_id == "world" and is_instance_valid(_hero) and _hero.position.x > 860.0


## Moves the day on and lays its light over the place (out of doors only).
func _weather(delta: float) -> void:
	G.world_clock += delta
	Sfx.night(_is_night())
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
	var rain := _raining() and not _dry_here()
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


## The interface of a walking place, on its own layer on the UI grid (spec 6.3): the story line
## top-left, the coins top-right, the place banner, the toast card, the help strip bottom-right.
## Sizes and places are UI px (about 800 x 360 on a PC, 400 x 180 on a phone).
func _build_hud() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = G.LAYER_HUD
	add_child(ui_layer)
	_ui = UI.attach(ui_layer)
	_ui.theme = UI.theme()
	var ins := UI.safe_insets(_ui)
	_quests = QuestList.new()
	_quests.in_camp = true
	_quests.position = Vector2(ins.x, ins.y)
	_ui.add_child(_quests)
	_coins = WalkKit.Coins.new()
	_coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var cw := 70.0 if UI.is_phone() else 120.0
	var right := ins.z + (30.0 if UI.is_phone() else 0.0)        # (a phone's pause button has the corner)
	_coins.offset_left = -cw - right
	_coins.offset_right = -right
	_coins.offset_top = ins.y
	_coins.offset_bottom = ins.y + (16.0 if UI.is_phone() else 30.0)
	_ui.add_child(_coins)
	_banner = WalkKit.Banner.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_banner)
	_toast = WalkKit.Toast.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var bottom := (22.0 if UI.is_phone() else 22.0) + ins.w
	_toast.offset_top = -bottom - (16.0 if UI.is_phone() else 24.0) - 8.0
	_toast.offset_bottom = -bottom
	_ui.add_child(_toast)
	# (v0.38.0) the party's health under the coins, only while somebody is hurt
	_hurt = UI.label("", "Small")
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hurt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hurt.offset_left = -(220.0 if UI.is_phone() else 360.0) - right
	_hurt.offset_right = -right - 2.0
	_hurt.offset_top = ins.y + (17.0 if UI.is_phone() else 32.0)
	_hurt.add_theme_color_override("font_outline_color", Color(UI.C_INK, 0.85))
	_hurt.add_theme_constant_override("outline_size", 1 if UI.is_phone() else 3)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hurt)
	_help = UI.help_strip([["knight", "Knight"], ["pause", "Pause"]], "bottom_right")
	_ui.add_child(_help)


## Each frame: what the interface shows (hidden while a window is open), the story line at half
## while the knight walks (whole after 1 s still), the help strip gone after 6 s of walking (back
## after 3 s still), the coins.
func _sync_hud(delta: float, moving: bool) -> void:
	if moving:
		_walk_t += delta
		_still_t = 0.0
	else:
		_still_t += delta
		if _still_t > 0.5:
			_walk_t = 0.0
	var outdoor := bool(place.get("outdoor", false))
	_quests.visible = not frozen and outdoor
	var want := 0.7 if _still_t < 1.0 and _walk_t > 0.0 else 1.0
	_quests.modulate.a = move_toward(_quests.modulate.a, want, delta * 2.0)
	_coins.visible = not frozen
	_coins.set("value", Upgrades.coins())
	_hurt.visible = not frozen and _hurt.text != ""
	_banner.visible = _banner.visible and not frozen
	if frozen:
		_toast.call("hide_now")
	if is_instance_valid(_help):
		var help_on := not frozen and not Controls.using_touch and (_walk_t < 6.0 or _still_t >= 3.0)
		_help.modulate.a = move_toward(_help.modulate.a, 1.0 if help_on else 0.0, delta * 3.0)
		_help.visible = _help.modulate.a > 0.0 and not Controls.using_touch and not frozen


## The place banner (big: a place's name; small: Night / Morning).
func _show_banner(words: String, small := false) -> void:
	if words == "":
		return
	_banner.call("show_text", words, String(place.get("title", "")) if not small else "", small, 2.2)


## The bed in your room: sleep until night falls, or until morning.
func sleep() -> void:
	var to_night := not _is_night()
	var day := floorf(G.world_clock / DAY_LENGTH)
	if to_night:
		G.world_clock = (day + NIGHT_FROM + 0.06) * DAY_LENGTH
	else:
		G.world_clock = (day + 1.0 + 0.02) * DAY_LENGTH
	_show_banner("Night has fallen" if to_night else "Morning", true)
	Sfx.play("door_close", -8.0)
	if Tale.on() and is_instance_valid(_hero):
		_rebuild()                      # (what is only there by night comes and goes)


# ------------------------------------------------------------------ building
func _build_ground() -> void:
	var ground := Node2D.new()
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var grass := Art.tex(String(place.get("ground", "hub_grass")))
	var lit := _view != null
	ground.draw.connect(func() -> void:
		# (the 3D look lays the grass itself, tile by tile turned at random: no rows show.
		# Here, in the old flat look, it is one repeated picture.)
		if not lit:
			ground.draw_texture_rect(grass, Rect2(Vector2(-420, -240), (place["size"] as Vector2) + Vector2(840, 480)), true)
		for f: Array in place.get("floor", []):          # a paved rectangle: every other tile mirrored, so no seam shows
			var four := _mirrored(String(f[0]))
			var ts: Vector2 = (four[0] as Texture2D).get_size()
			var area: Rect2 = f[1]
			var ty := 0
			while ty * ts.y < area.size.y:
				var tx := 0
				while tx * ts.x < area.size.x:
					ground.draw_texture(four[(tx % 2) + 2 * (ty % 2)], area.position + Vector2(tx * ts.x, ty * ts.y))
					tx += 1
				ty += 1)
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
			var paved := false
			for f: Array in place.get("floor", []):
				if (f[1] as Rect2).grow(4.0).has_point(s.position):
					paved = true                                # (no tufts and flowers on cobbles)
			if paved:
				s.free()
				continue
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
## A paving tile four ways: as it is, mirrored left-right, upside down, and both. Laid in turn
## they always meet themselves at every edge, so a tile cut from the middle of a pack's paving
## can cover any area without a seam.
static var _four := {}
func _mirrored(id: String) -> Array:
	if not _four.has(id):
		var out: Array = []
		for k in 4:
			var img := Art.tex(id).get_image()
			if img.is_compressed():
				img.decompress()
			if k % 2 == 1:
				img.flip_x()
			if k >= 2:
				img.flip_y()
			out.append(ImageTexture.create_from_image(img))
		_four[id] = out
	return _four[id]


## Is this spot in (or within `margin` px of) one of the place's ponds?
func _in_water(at: Vector2, margin: float = 0.0) -> bool:
	for pond: Dictionary in place.get("water", []):
		var r: Vector2 = (pond["radius"] as Vector2) + Vector2(margin, margin)
		var d: Vector2 = (at - (pond["at"] as Vector2)) / r
		if d.length_squared() < 1.0:
			return true
	return false


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
			var ok := not _in_water(at, 26.0)
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
		l.set_meta("walk_kind", "sign")          # (the 3D look: Cinzel caps, view3d.gd _twin)
		l.theme = UI.theme()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(160, 0)
		l.add_theme_color_override("font_color", colour)
		l.set_meta("sign_colour", colour)
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
	if id.begins_with("hub_bloom_"):
		s.scale = Vector2(0.5, 0.5)      # (the giant trumpet flowers stood taller than the knight: scale broke)
	elif id.begins_with("hub_shroom_"):
		s.scale = Vector2(0.6, 0.6)      # (toadstools as tall as the knight broke the scale of the glade too)
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
	_solids.append([(place["fire"] as Vector2) - Vector2(0, 4), 16.0])     # (v0.43.0: was 11: he stood in the fire)
	if place.has("grill"):
		var grill := _anim("hub_fire_c", 7.0)        # the cook's fire
		grill.position = (place["grill"] as Vector2)
		grill.offset = Vector2(0, -10)
		_ysort.add_child(grill)
		_solids.append([(place["grill"] as Vector2) - Vector2(0, 4), 10.0])


## The glass of a lamp post: a small flat shape made by code (pale gold, a darker frame), like the
## other flat shapes the code draws. The 3D look makes it glow.
static var _glass_tex: ImageTexture
func _lamp_glass() -> ImageTexture:
	if _glass_tex == null:
		var img := Image.create(6, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color("3a2414"))
		_flame_pane(img, Vector2i(1, 1), 4, 6)
		_glass_tex = ImageTexture.create_from_image(img)
		_glass_tex.resource_name = "hub_lampglass"
	return _glass_tex


## A lamp's glass with a small flame behind it, filled in flat colours by code (like the other flat
## shapes the code draws): a smoky dark top, deep amber sides, an orange flame up the middle and a
## pale one-pixel heart low in it. The 3D look makes it blaze (card_shader.gd set_glow "hot").
static func _flame_pane(img: Image, at: Vector2i, w: int, h: int) -> void:
	var mid := at.x + (w - 1) / 2
	for y in h:
		var t := float(y) / float(maxi(h - 1, 1))          # 0 at the top, 1 at the bottom
		for x in w:
			var c := Color("a04e14")
			var centre := x == mid or (w % 2 == 0 and x == mid + 1)
			if y == 0:
				c = Color("5a2a0c")
			elif y == h - 1:
				c = Color("d07a2a") if centre else Color("6a3010")
			elif centre:
				c = Color("ffd890") if t >= 0.6 and t < 0.78 else (Color("f09a34") if t >= 0.35 else Color("d0701e"))
			elif t >= 0.35:
				c = Color("b85a18")
			img.set_pixel(at.x + x, at.y + y, c)


## The glass of the pack's hanging lantern (hub_slantern, 43 x 46): a small glowing pane laid
## between the posts of its cage (art pixels 35-37 x 15-19), a pixel in front of it so it is drawn over it. The 3D look
## makes it blaze (scripts/fx/card_shader.gd shine_of) and puts the lamp's light on it.
## `iron`: the 3D look's iron street lamp stands there instead (scripts/hub/arch/sites.gd
## _iron_lamp): its pane fills the whole cage, 5 x 8, with a hot core (round three: a 3 x 5 pane in
## a dark cage read as a dim lamp under a cream halo; in the references the glass is the hottest
## thing in the picture).
static var _lantern_tex: ImageTexture
static var _iron_tex: ImageTexture
func _lantern_glass(lantern: Sprite2D, iron: bool = false) -> void:
	if _lantern_tex == null:
		var img := Image.create(3, 5, false, Image.FORMAT_RGBA8)
		_flame_pane(img, Vector2i(0, 0), 3, 5)
		_lantern_tex = ImageTexture.create_from_image(img)
		_lantern_tex.resource_name = "hub_lampglass"
	if _iron_tex == null:
		var big := Image.create(5, 8, false, Image.FORMAT_RGBA8)
		_iron_pane(big)
		_iron_tex = ImageTexture.create_from_image(big)
		_iron_tex.resource_name = "hub_lampglass"
	var glass := Sprite2D.new()
	glass.texture = _iron_tex if iron else _lantern_tex
	glass.centered = false
	glass.position = lantern.position + Vector2(0, 1)
	if iron:
		glass.offset = lantern.offset + Vector2(34.0 if not lantern.flip_h else 4.0, IRON_PANE_Y)
	else:
		var left := 35.0 if not lantern.flip_h else 43.0 - 38.0
		glass.offset = lantern.offset + Vector2(left, 16.0 - 1.0)
	_ysort.add_child(glass)


const IRON_PANE_Y := 10.0            ## the iron lamp's pane, art pixels down from the lantern picture's top


## The iron street lamp's glass, 5 x 8, in flat colours by code: a smoky top row, saturated orange
## glass with deeper edges, and a small yellow-white heart (2 x 3 px) low in the middle.
static func _iron_pane(img: Image) -> void:
	for y in 8:
		for x in 5:
			var edge := x == 0 or x == 4
			var c := Color("9a3e0c") if edge else Color("e0741a")
			if y == 0:
				c = Color("4a200a")
			elif y == 1:
				c = Color("7a3410") if edge else Color("c45a14")
			elif y == 7:
				c = Color("6a2c0c") if edge else Color("b8561a")
			img.set_pixel(x, y, c)
	# the flame and its heart
	for p: Array in [[2, 2, "f8a040"], [2, 3, "ffd070"], [1, 4, "ffb850"], [3, 4, "ffb850"], [2, 4, "fff4c8"], [2, 5, "fff0b8"], [1, 5, "ffc860"], [3, 5, "ffc860"], [2, 6, "f8a040"]]:
		img.set_pixel(int(p[0]), int(p[1]), Color(String(p[2])))


## A beacon of the story (scripts/data/tale.gd): the fire bowl on its stone. Dark, it is cold
## embers; lit, the flame stands on it (the place's "lights" hold its glow).
func _build_beacon() -> void:
	var spec: Dictionary = place["beacon"]
	var lift := float(spec.get("lift", 24.0))
	_solids.append([(spec["pos"] as Vector2) + Vector2(0, 8), 20.0])        # (v0.43.0) nobody walks into the beacon's stones
	var bowl := _anim("hub_fire_a", 7.0)
	bowl.position = spec["pos"]
	bowl.offset = Vector2(0, -8.0 - lift)
	_ysort.add_child(bowl)
	if bool(spec.get("lit", false)):
		var flame := _anim("hub_flame", 9.0)
		flame.offset = Vector2(0, -18.0 - lift)
		bowl.add_child(flame)
	else:
		bowl.stop()
		bowl.modulate = Color(0.42, 0.46, 0.58)


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
	if place.has("rise") and _view != null:
		# the ground climbs behind this place (the 3D look): more wood up the slope, row behind row
		var row_y := 62.0
		while row_y > -150.0:
			var tx := -60.0 + rng.randf() * 40.0
			while tx < size.x + 60.0:
				var ids: Array = f_big if rng.randf() < 0.6 else f_side
				_prop(String(ids[rng.randi() % ids.size()]), Vector2(tx, row_y + rng.randf_range(-8, 8)).round(), 0.0, 6.0)
				tx += rng.randf_range(40.0, 66.0)
			row_y -= 42.0
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
	var specs: Array = place.get("lights", [])
	if G.flag("pondlamps"):
		# test: three lamps along the far bank of every pond (to look at their columns in the water)
		specs = specs.duplicate()
		for pond: Dictionary in place.get("water", []):
			var c: Vector2 = pond["at"]
			var r: Vector2 = pond["radius"]
			for k: float in [-0.55, 0.0, 0.55]:
				specs.append([c + Vector2(r.x * k, -r.y * sqrt(1.0 - k * k) - 6.0), Color(1.0, 0.78, 0.46), 1.0, 0.55])
	for spec: Array in specs:
		var l := PointLight2D.new()
		l.texture = tex
		l.position = spec[0]
		l.color = spec[1]
		l.texture_scale = spec[2]
		l.energy = spec[3]
		if spec.size() > 4 and String(spec[4]) == "held":
			l.set_meta("no_halo", true)          # (v0.43.0) a light held by somebody: no glowing ball over them
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
	if bool(row.get("ghost", false)) and row.has("body") and _built_inside():
		# someone painted into the room's picture: in a room built for real they stand there themselves
		row = row.duplicate()
		row.erase("ghost")
		row["sprite"] = row["body"]
		row["pos"] = row.get("at3d", row["pos"])        # (the barkeep stands behind his counter)
	var node := Node2D.new()
	node.position = row["pos"]
	_ysort.add_child(node)
	var mark := UI.label("!", "Head")
	mark.set_meta("walk_kind", "news")         # (the 3D look shows it as a gold "!" coin: view3d.gd _twin)
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
		if String(row.get("prop", "")) != "":
			# (the quality pass) a thing of the pack standing on the spot: a sign, a lever, a plaque
			var thing_tex := Art.tex(String(row["prop"]))
			var thing := Sprite2D.new()
			thing.texture = thing_tex
			thing.offset = Vector2(0, -thing_tex.get_size().y * 0.5 + float(row.get("prop_below", 1.0)))
			thing.flip_h = bool(row.get("prop_flip", false))
			node.add_child(thing)
			node.move_child(thing, 0)
			if not row.has("top"):
				top = thing_tex.get_size().y + 2.0
				mark.position = Vector2(-2, -top - 16)
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
	body.modulate = row.get("tint", Color.WHITE)
	var face := float(row.get("face", 1))
	body.flip_h = face < 0.0
	node.add_child(body)
	var hands: RefCounted = null
	if String(row.get("hands", "")) != "":
		hands = Hands.new()
		hands.build(node, body, String(row["hands"]), bw, bh)
	mark.position = Vector2(-2, -bh - 16)
	node.move_child(mark, node.get_child_count() - 1)
	_solids.append([row["pos"] - Vector2(0, 2), maxf(7.0, bw * 0.45)])     # (v0.43.0: was 6: the knight stood inside wide people)
	var person := {"row": row, "node": node, "hands": hands, "mark": mark, "face": face, "top": bh, "solid": _solids.size() - 1,
		"body": body, "post": row["pos"], "goal": row["pos"], "wait": randf_range(1.0, 4.0), "walks": Art.has_anim(sprite_id, "run")}
	_people.append(person)
	return person


## (v0.42.0) A thing lying in the place (scripts/data/errands.gd FINDS): its pack picture standing on the
## spot (it moves with its holder, so the 3D look drops it the moment it is taken) and a spot to "talk" to.
func _add_find(f: Dictionary) -> void:
	var row := {"id": "find:" + String(f["id"]), "name": String(f["name"]), "title": "", "ghost": true, "pos": _free_spot(f["pos"]),
		"top": 14, "role": "find", "find": String(f["id"]), "text": ""}
	var p := _add_person(row)
	if G.flag("allfinds"):
		print("[finds] %s in %s: asked %s, stands at %s" % [f["id"], place_id, f["pos"], row["pos"]])
	var tex := Art.tex(String(f["sprite"]))
	var pic := Sprite2D.new()
	pic.texture = tex
	pic.offset = Vector2(0, -tex.get_size().y * 0.5 + 2.0)
	(p["node"] as Node2D).add_child(pic)


## Test (--allfinds): can the knight walk from where he came in to this spot? (8 px cells)
func _reach_test(fid: String, to: Vector2) -> void:
	print("[reach] %s in %s: %s" % [fid, place_id, "OK" if _reached(_flood([]), to) else "CANNOT REACH"])


## Every 8 px cell the knight can walk to from the place's way in. `open`: rects of doors taken as open.
func _flood(open: Array) -> Dictionary:
	var walk: Rect2 = place["walk"]
	var cell := 8.0
	var start := Vector2i((Vector2(place["spawn"]) / cell).floor())
	var free := func(c: Vector2i) -> bool:
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * cell
		if not walk.has_point(p):
			return false
		for b: Rect2 in _blocks:
			if b.grow(HERO_RADIUS * _k).has_point(p) and not open.has(b):
				return false
		for sol: Array in _solids:
			if (sol[0] as Vector2).distance_to(p) < float(sol[1]) + HERO_RADIUS * _k - 2.0:
				return false
		return true
	var seen := {start: true}
	var queue: Array = [start]
	var at := 0
	while at < queue.size() and seen.size() < 60000:
		var c: Vector2i = queue[at]
		at += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and free.call(n):
				seen[n] = true
				queue.append(n)
	return seen


## Is a spot within `reach` px of a cell he can stand on?
func _reached(seen: Dictionary, to: Vector2, reach: float = 20.0) -> bool:
	var goal := Vector2i((to / 8.0).floor())
	var r := int(ceil(reach / 8.0))
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if seen.has(goal + Vector2i(dx, dy)) and Vector2(dx, dy).length() * 8.0 <= reach:
				return true
	return false


## Test (--allfinds): the whole place is PLAYED on paper: from the way in, whatever can be walked to is
## taken (a chest's key, a lever), whatever that opens is opened (a key door he can walk up to, a lever
## door), and so on until nothing changes. Then every find, lever, door, sign and foe says whether the
## knight can get to it: "[reach] <thing> in <place>: OK" or "CANNOT REACH" / "NO KEY".
func _reach_all() -> void:
	var keys := {}
	var pulled := {}
	var open: Array = []
	var seen := {}
	for d: Dictionary in place.get("doors", []):
		if not door_shut(d):
			pulled[String(d.get("lever", ""))] = true
	for turn in 20:
		seen = _flood(open)
		var changed := false
		for p: Dictionary in _people:
			var row: Dictionary = p["row"]
			if not _reached(seen, row["pos"]):
				continue
			if String(row.get("role", "")) == "lever" and not pulled.has(String(row["lever"])):
				pulled[String(row["lever"])] = true
				changed = true
			if String(row.get("role", "")) == "find":
				var f := Errands.find_row(String(row["find"]))
				var need := String(f.get("locked", ""))
				var key := String((f.get("reward", {}) as Dictionary).get("key", ""))
				if key != "" and not keys.has(key) and (need == "" or keys.has(need) or Save.hub_get("dkey:" + need) > 0):
					keys[key] = true
					changed = true
		for door: Dictionary in _doors:
			var d: Dictionary = door["row"]
			if open.has(d["rect"]):
				continue
			var key := String(d.get("key", ""))
			var by_key := key != "" and (keys.has(key) or Save.hub_get("dkey:" + key) > 0) and _reached(seen, (d["rect"] as Rect2).get_center(), 24.0)
			if by_key or (d.has("lever") and pulled.has(String(d["lever"]))):
				open.append(d["rect"])
				changed = true
		if not changed:
			break
	for p: Dictionary in _people:
		var row: Dictionary = p["row"]
		var role := String(row.get("role", ""))
		if not ["find", "lever", "read", "bed"].has(role) and not bool(row.get("travel", false)):
			continue
		var ok := _reached(seen, row["pos"])
		var word := "OK" if ok else "CANNOT REACH"
		if ok and role == "find":
			var need := String(Errands.find_row(String(row["find"])).get("locked", ""))
			if need != "" and not keys.has(need) and Save.hub_get("dkey:" + need) <= 0:
				word = "NO KEY (%s)" % need
		print("[reach] %s in %s: %s" % [String(row["find"]) if role == "find" else String(row["id"]), place_id, word])
	for door: Dictionary in _doors:
		print("[reach] door:%s in %s: %s" % [door["row"]["id"], place_id, "OK" if open.has(door["row"]["rect"]) else "CANNOT OPEN"])
	for r: Dictionary in _roamers:
		if r.has("key"):
			print("[reach] foe:%s: %s" % [r["key"], "OK" if _reached(seen, r["home"]) else "CANNOT REACH"])
	for e: Dictionary in place.get("exits", []):
		print("[reach] exit to %s in %s: %s" % [e["to"], place_id, "OK" if _reached(seen, (e["rect"] as Rect2).get_center(), 24.0) else "CANNOT REACH"])


## The nearest spot to `at` where nothing stands (walls, furniture, trees, water) inside the walk.
func _free_spot(at: Vector2) -> Vector2:
	var walk: Rect2 = place["walk"]
	for ring in 12:
		for k in maxi(1, ring * 8):
			var p := at + Vector2.RIGHT.rotated(TAU * float(k) / float(maxi(1, ring * 8))) * float(ring) * 8.0
			if not walk.grow(-6.0).has_point(p):
				continue
			var ok := true
			for b: Rect2 in _blocks:
				if b.grow(8.0).has_point(p):
					ok = false
					break
			if ok:
				for sol: Array in _solids:
					if (sol[0] as Vector2).distance_to(p) < float(sol[1]) + 8.0:
						ok = false
						break
			if ok:
				return p
	return at


## The companion who travels with the knight walks a few steps behind him in every camp and on
## the world map (only a look: you talk to her on the Party page of the Knight screen).
var _mate: Node2D
var _mate_body: AnimatedSprite2D
var _mate_hands: RefCounted
var _mate_face := 1.0
func _build_follower() -> void:
	_mate = null
	var mate := Allies.with() if G.arg("ally") == "" else Allies.row(G.arg("ally"))      # (--ally=<id>: a test, she walks behind him)
	if mate.is_empty():
		return
	_mate = Node2D.new()
	_mate.position = _hero.position + Vector2(-16, 4) * _k
	if place.has("inside"):
		_mate.position = _clear_of_blocks(_mate.position, HERO_RADIUS * _k)
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
		if place.has("inside"):
			_mate.position = _clear_of_blocks(_mate.position, HERO_RADIUS * _k)      # never on a table or the counter
			if _mate.position.distance_to(_hero.position) > 70.0:
				_mate.position = _clear_of_blocks(_hero.position + Vector2(-12, 6), HERO_RADIUS * _k)     # (caught behind furniture: she catches up)
		if absf(_mate.position.x - before.x) > 0.02:
			_mate_face = signf(_mate.position.x - before.x)
	_mate_body.flip_h = _mate_face < 0.0
	var anim := "run" if walking and Art.has_anim(String(Allies.with().get("sprite", "")), "run") else "idle"
	if _mate_body.animation != anim:
		_mate_body.play(anim)
	if _mate_hands != null:
		_mate_hands.update(delta, walking, _mate_face)


## A spot pushed out of every block (walls and furniture) through its nearest side.
func _clear_of_blocks(to: Vector2, body_r: float) -> Vector2:
	for b: Rect2 in _blocks:
		var g := b.grow(body_r)
		if not g.has_point(to):
			continue
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
	var walk: Rect2 = place["walk"]
	return to.clamp(walk.position, walk.end)


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
## (the quality pass) Walking ran on the 60-a-second physics tick while the picture is drawn every frame,
## so on a 144 Hz screen the knight moved in little jumps. Now it runs every drawn frame. A long frame is
## cut to a thirtieth of a second (of game time) and walked in steps of a sixtieth at most, so nobody
## steps through a wall or over a doorway on a slow machine or in a speeded-up test.
func _process(delta: float) -> void:
	delta = minf(delta, Engine.time_scale / 30.0)
	var steps := clampi(ceili(delta * 60.0 - 0.01), 1, 16)
	for i in steps:
		_tick(delta / float(steps))
		if not is_inside_tree():
			return


func _tick(delta: float) -> void:
	_time += delta
	_move_follower(delta)
	_move_roamers(delta)
	_wild_steps(delta)
	var move := Vector2.ZERO
	if not frozen and not _changing:
		move = Controls.move
		if G.flag("wildtest"):           # test: --wildtest walks him east across the map
			move = Vector2(1.0, 0.1)
			if G.arg("wildtest").contains(","):      # test: --wildtest=x,y : he walks in a ring round that spot of the map
				var ring := G.arg("wildtest").split(",")
				var mid := Vector2(float(ring[0]), float(ring[1]))
				if _hero.position.distance_to(mid) > 90.0:
					_hero.position = mid
				move = Vector2.RIGHT.rotated(_time * 2.4)
		if not _tour.is_empty():
			move = _tour_step(delta)
	var moving := move.length() > 0.12
	if moving:
		Sfx.ground(_ground_here())
	Sfx.walking(moving and not _changing, delta, float(place.get("speed", 1.0)))
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
				var shut := need != "" and not Story.cleared(need)
				if Tale.on():
					# the story: a road opens at its step ("tale"); roads of the old story stay shut
					shut = need != "" or Tale.step() < int(e.get("tale", 0))
					if need != "":
						e = e.duplicate()
						e["why"] = Tale.LATER
				if shut:
					# the road is still shut: he is turned back and told why
					_hero.position = was
					if _shut_t <= 0.0:
						_shut_t = 3.0
						_toast.call("show_text", String(e.get("why", "The way is shut.")), 2.5)
						Sfx.play("ui_back")
				else:
					_go(String(e["to"]), e["at"])
				break
		if not _doors.is_empty() and _push_doors():
			return                      # (a door opened: the place was built again round him)
		# a locked place of the world map (places.gd _lock_world): pushing against it says why
		if _shut_t <= 0.0:
			for row: Dictionary in place.get("shut", []):
				if (row["rect"] as Rect2).has_point(_hero.position):
					_shut_t = 4.0
					_toast.call("show_text", String(row["why"]), 3.0)
					Sfx.play("ui_back")
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
	_weather(delta)
	_sync_hud(delta, moving)
	_update_people(delta)


func _update_people(delta: float) -> void:
	var best := -1
	var best_d := Hub.TALK_REACH * _k
	var news := _news
	if int(_time * 2.0) != int((_time - delta) * 2.0) or _time < 0.1:
		news = Quests.any_complete()
		for q: Dictionary in _people:
			q["news"] = Story.has_news(String(q["row"]["id"]))
			if Tale.on():
				# (v0.42.0) a gold "!" over somebody with a side quest to give or to hand in
				var er := Errands.for_giver(String(q["row"]["id"]))
				q["news"] = not er.is_empty() and (Errands.state(String(er["id"])) == 0 or Errands.complete(er))
	_news = news
	for i in _people.size():
		var p: Dictionary = _people[i]
		var node: Node2D = p["node"]
		var d := node.position.distance_to(_hero.position)
		var walking := _stroll(p, delta, d)
		if p["hands"] != null:
			(p["hands"] as RefCounted).update(delta, walking, float(p["face"]))
		if d < best_d and not bool(p["row"].get("extra", false)):       # (townsfolk who only stand about: nothing to say)
			best_d = d
			best = i
		var mark: Label = p["mark"]
		mark.visible = (news and String(p["row"].get("role", "")) == "quests") or bool(p.get("news", false)) or (String(p["row"].get("role", "")) == "ally" and not Allies.joined(String(p["row"].get("ally", ""))))
		# (the 3D look draws its own bobbing coin from this anchor: scripts/ui/walk_kit.gd NewsMark)
		mark.position.y = -float(p["top"]) - 16.0 + (roundf(sin(_time * 5.0) * 1.5) if _view == null else 0.0)
		mark.set_meta("under_tag", false)
	_near = best
	G.hub_near = best >= 0 and not frozen
	# (v0.43.0, the owner: story fights start BY THEMSELVES, a surprise, no button): walking up to whoever
	# the story's next battle is with opens their words, and the battle follows them
	if best >= 0 and not frozen and not _changing and Tale.on() and (_tour.is_empty() or G.flag("ambushtest")) and not G.flag("uitour"):
		var rid := String(_people[best]["row"]["id"])
		var beat := Tale.beat(rid)
		if (beat.get("do", {}) as Dictionary).has("battle") and not _ambushed.has(rid):
			_ambushed[rid] = true
			print("[hub] a story fight springs: %s" % rid)
			_talk(best)
			return
	if best >= 0 and not frozen:
		var p: Dictionary = _people[best]
		_prompt.text = String(p["row"]["name"])
		_prompt.reset_size()
		# (above the tallest head near it with clearance: a name over the knight's sword arm, in a grey
		# outline, merged with both sprites)
		var at := (p["node"] as Node2D).position
		var up := float(p["top"]) + 18.0
		if _hero != null and absf(_hero.position.x - at.x) < 30.0:
			up = maxf(up, at.y - _hero.position.y + 34.0 * _k + 18.0)
		_prompt.position = (at + Vector2(-_prompt.size.x * 0.5, -up) / _zoom).round()
		_prompt.visible = not place.has("signs")        # on the world map the name already floats over the place
		# with news, the name tag carries the gold "!" itself and the mark over the head steps aside
		var mark: Label = p["mark"]
		_prompt.set_meta("news", mark.visible)
		mark.set_meta("under_tag", _prompt.visible)
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
	if not bool(p["walks"]) or bool(p["row"].get("extra", false)):
		return false
	var goal: Vector2 = p["goal"]
	if node.position.distance_to(goal) < 1.0:
		p["wait"] = float(p["wait"]) - delta
		if body.animation != "idle":
			body.play("idle")
		if float(p["wait"]) <= 0.0:
			p["wait"] = randf_range(2.5, 6.0)
			var post: Vector2 = p["post"]
			# (round three: never a goal within 16 px of another person or of where another is going:
			# two strollers ended in one spot and melted into one figure)
			for attempt in 6:
				var g := (post + Vector2(randf_range(-Hub.STROLL, Hub.STROLL), randf_range(-Hub.STROLL * 0.6, Hub.STROLL * 0.6))).round()
				if _clear_spot(g, p):
					p["goal"] = g
					break
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


## No other person (nor the knight) stands at, or is walking to, within 16 px of `at`.
func _clear_spot(at: Vector2, me: Dictionary) -> bool:
	if _hero != null and _hero.position.distance_to(at) < 16.0:
		return false
	for q: Dictionary in _people:
		if is_same(q, me):
			continue
		if (q["node"] as Node2D).position.distance_to(at) < 16.0:
			return false
		if q.has("goal") and (q["goal"] as Vector2).distance_to(at) < 16.0:
			return false
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
			return              # (a chest is taken out of the list while it is opened)


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
	var role := String(row.get("role", "chat"))
	if role == "find":
		# (v0.42.0) a chest or a thing a side quest asked for: taken, gone from the place
		# (the quality pass) a locked one says so and stays; an opened chest stays where it stood, open
		var shut := Errands.locked(Errands.find_row(String(row["find"])))
		var words := Errands.open(String(row["find"]))
		_near = -1
		_last_talk = -1
		Sfx.play("ui_back" if shut else "chest_open", -4.0)
		if not shut and words != "":
			Sfx.sting("item_get")
		if G.flag("allfinds"):
			print("[finds] %s: %s" % [row["find"], "LOCKED" if shut else "opened"])
		action.emit("talk", {"name": row["name"], "title": "", "sprite": "", "pages": [words if words != "" else Tale.KIT["empty"]], "heard": "", "lines": [], "options": []})
		if not shut:
			_rebuild()
		return
	if role == "lever":
		_pull_lever(row)
		return
	if role == "read" and Tale.on():
		# (the dungeon kit) a sign, a plaque, a letter: its "pages" in the talk box, no face beside them.
		# "do" (as tale.gd "do") happens on reading: at once when it only sets flags, hands over a key or a
		# thing; after the words when it starts a battle, moves the story or opens a screen.
		var read := {"name": row["name"], "title": row.get("title", ""), "sprite": "", "pages": (row.get("pages", [String(row.get("text", ""))]) as Array).duplicate(),
			"heard": "", "lines": [], "options": []}
		var todo: Dictionary = row.get("do", {})
		if todo.has("battle") or todo.has("step") or todo.has("screen") or todo.has("light") or todo.has("all"):
			read["auto_do"] = todo
		elif not todo.is_empty():
			var got := Tale.apply(todo)
			if got.has("say"):
				say(String(got["say"]))
		action.emit("talk", read)
		return
	if Tale.on():
		# the story (scripts/data/tale.gd): what this person says at this step, and the one thing
		# the player may choose to do about it. What people did in the old story is switched off.
		var said_now := Tale.beat(id)
		info["heard"] = ""
		info["pages"] = (said_now.get("pages", []) as Array).duplicate()
		if said_now.has("option") and (said_now.get("do", {}) as Dictionary).has("battle"):
			info["auto_do"] = said_now["do"]          # (v0.43.0) no button: the fight starts when the words end
		elif said_now.has("option"):
			info["options"].append({"text": String(said_now["option"]), "what": "tale_do", "arg": said_now["do"]})
		if Supplies.SELLERS.has(id):
			role = "supplies"                # (v0.38.0) sells herbs and tonics; the barkeep also lets rooms
			if said_now.is_empty() and String(row.get("text", "")) != "":
				info["pages"] = [String(row["text"])]
		elif Tale.RETIRED.has(role):
			if said_now.is_empty():
				info["pages"] = [Tale.LATER]
			role = "chat"
		elif said_now.is_empty() and String(row.get("text", "")) != "":
			info["pages"] = [String(row["text"])]
		# (v0.42.0) side quests: something taken to this person, one this person gives, or hands in
		var brought := Errands.talked(id)
		if brought != "":
			info["pages"] = [brought] + (info["pages"] as Array)
		var er := Errands.for_giver(id)
		if not er.is_empty():
			var eid := String(er["id"])
			match Errands.state(eid):
				0:
					info["pages"] = (info["pages"] as Array) + [String(er["ask"])]
					info["options"].append({"text": "Side quest: %s" % String(er["name"]), "what": "errand_take", "arg": eid})
				1:
					if Errands.complete(er):
						info["pages"] = (info["pages"] as Array) + [String(er["thanks"])]
						info["options"].append({"text": "Hand in: %s" % String(er["name"]), "what": "errand_done", "arg": eid})
					else:
						var pr := Errands.progress(er)
						info["lines"].append(["%s: %d of %d" % [er["name"], int(pr[0]), int(pr[1])], UI.C_DIM])
		if bool(row.get("travel", false)):
			# (the quality pass) a burning beacon, or Wickmere's watch-fire: step into the light and out at
			# any other light that burns (scripts/data/travel.gd). The place is shown anew by main.gd "tale_do".
			var stop_here := Travel.stop_at(place_id, id)
			var ways := Travel.from(stop_here)
			for stop: Dictionary in ways:
				info["options"].append({"text": Travel.OFFER % String(stop["name"]), "what": "tale_do", "arg": {"travel": String(stop["id"])}})
			if not ways.is_empty():
				info["lines"].append([Travel.HINT, UI.C_DIM])
			elif stop_here.has("add") and not Travel.any_lit():
				info["pages"] = (info["pages"] as Array) + [Travel.FIRE_DARK]
	match role:
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
		"supplies":
			if Supplies.INN.has(id):
				var room := Supplies.inn_price()
				info["options"].append({"text": "A room for the night: %d coins (everybody rested)" % room, "what": "hub_inn",
					"off": Upgrades.coins() < room, "why": _poor(room)})
			for item: Dictionary in Supplies.on_sale(Tale.step()):
				var price := int(item["price"])
				var full := Supplies.count(String(item["id"])) >= Supplies.cap_of(String(item["id"]))
				info["options"].append({"text": "%s: %d coins (you have %d)" % [item["name"], price, Supplies.count(String(item["id"]))], "what": "hub_supply",
					"arg": item["id"], "off": full or Upgrades.coins() < price, "why": "Your pack holds no more of those." if full else _poor(price)})
				info["lines"].append(["%s: %s" % [item["name"], item["text"]], UI.C_DIM])
			info["lines"].append(["Coins: %d" % Upgrades.coins(), UI.C_GOLD])
		"train":
			info["options"].append({"text": "Train in the yard", "what": "hub_train"})
		"bed":
			var carried := Story.kit()
			if place_id == "room":
				info["lines"].append(["Your room at the Hollow Flagon. The looking glass by the bed changes your name, armour and sword.", UI.C_DIM])
			else:
				# (the quality pass: the old line promised the game would open here, which the story never did)
				info["lines"].append([Tale.KIT["rest"] if Tale.on() else "A place to rest. The game opens here next time, at the camp you last walked into.", UI.C_DIM])
			info["lines"].append(["You carry %d item%s. Camp chest: %d coins." % [carried.size(), "" if carried.size() == 1 else "s", Upgrades.coins()], UI.C_GOLD])
			info["options"].append({"text": ("Sleep until morning" if _is_night() else "Sleep until nightfall") + (" (everybody rested)" if Wounds.any() else ""), "what": "hub_sleep"})
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
	if Tale.on():
		# the story: a smith sells helmets, armour and rings (they count in battles); the old
		# upgrades and the real-time weapons are not part of it
		if sell == "smith":
			# (v0.39.0) the next sword, armour, bow and staff: one tier after the other
			for line: String in Arms.LINES:
				var who_for := String(Arms.LINES[line]["who"])
				if who_for != "knight" and not Allies.joined(who_for):
					continue
				var t := Arms.next(line)
				var owner_name := Looks.hero_name() if who_for == "knight" else String(Allies.row(who_for)["name"])
				if t.is_empty():
					info["lines"].append(["%s's %s: the best there is (%s)." % [owner_name, Arms.LINES[line]["label"], Arms.current(line)["name"]], UI.C_DIM])
					continue
				var gives := _arm_text(t)
				if Tale.step() < int(t["from"]):
					info["lines"].append(["%s for %s: later in the story." % [t["name"], owner_name], UI.C_FAINT])
					continue
				var cost := int(t["price"])
				info["options"].append({"text": "%s for %s: %d coins" % [t["name"], owner_name, cost], "what": "hub_arm", "arg": line,
					"off": Upgrades.coins() < cost, "why": _poor(cost)})
				info["lines"].append(["%s: %s (now: %s)" % [t["name"], gives, Arms.current(line)["name"]], UI.C_DIM])
			info["options"].append({"text": "Helmets, armour and rings", "what": "hub_shelf", "arg": String(row.get("name", "The smith"))})
			info["lines"].append(["Coins: %d" % Upgrades.coins(), UI.C_GOLD])
		if Arms.TEACHERS.has(id):
			# (v0.39.0) a teacher: skills for the knight and each companion
			info["options"].append({"text": "Teach %s" % Looks.hero_name(), "what": "hub_lore", "arg": "knight"})
			for mate: Dictionary in Allies.LIST:
				if Allies.joined(String(mate["id"])):
					info["options"].append({"text": "Teach %s" % String(mate["name"]), "what": "hub_lore", "arg": String(mate["id"])})
			info["lines"].append(["A new level opens a skill; I teach it, and teach it again to make it stronger.", UI.C_DIM])
		sell = ""
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
	if not Tale.on() and not Story.has_news(id) and _talked.has(id) and not ((info["options"] as Array).is_empty() and (info["lines"] as Array).is_empty()):
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
var _woke := false               ## this place was opened after a lost fight
func _build_roamers() -> void:
	_roamers.clear()
	_caught = false
	_roam_grace = Roamers.GRACE
	_wild_left = randf_range(Roamers.STEPS_MIN, Roamers.STEPS_MAX)
	_wild_last = Vector2.INF
	Roamers.roll = 0
	Roamers.night = false
	if place_id == "world" and not Roamers.RANDOM:
		for i in Roamers.SPOTS.size():
			if not Roamers.here(i):
				continue
			var spot: Dictionary = Roamers.SPOTS[i]
			var r := _add_roamer(Enemies.info(Roamers.shows(i)), spot["at"], float(spot.get("leash", 60.0)))
			r["spot"] = i
	# (the dungeon kit) FOES: a place's "foes" [{"id", "sprite" or "enemy", "pos", "leash", "battle"}]: a monster
	# that stands in the place, comes for the knight when he steps inside its leash and starts that battle of
	# the story (tale.gd BATTLES or a module's) on a touch. Beaten, it is gone for Tale.FOE_RESPAWN seconds.
	# "enemy": a row of scripts/data/enemies.gd to look like; "sprite" (+ "tint", "hands"): pack art by id.
	# "tale_from" / "tale_to" / "flag_on" / "flag_off" as for people. "spot": the roamer spot whose fight
	# is fought instead while main.gd cannot start a module's battle yet (see docs/pass/07_world_kit.md).
	if Tale.on():
		for foe: Dictionary in place.get("foes", []):
			var key := place_id + ":" + String(foe["id"])
			if not Tale.here(foe) or not Tale.foe_here(key):
				continue
			var look: Dictionary = Enemies.info(String(foe["enemy"])).duplicate() if foe.has("enemy") else {}
			for k: String in ["sprite", "tint", "hands"]:
				if foe.has(k):
					look[k] = foe[k]
			var r := _add_roamer(look, foe["pos"], float(foe.get("leash", 70.0)))
			r["battle"] = String(foe["battle"])
			r["key"] = key
			r["spot"] = int(foe.get("spot", 0))


## One monster that walks its patch (a roamer of the world map, or a place's foe).
func _add_roamer(row: Dictionary, at: Vector2, leash: float) -> Dictionary:
	var sprite_id := String(row.get("sprite", "pc_skeleton_base"))
	var m := Art.meta(sprite_id)
	var node := Node2D.new()
	node.position = at
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
	mark.set_meta("walk_kind", "foe")      # (the 3D look shows it as a red "!" coin)
	mark.theme = UI.theme()
	mark.add_theme_color_override("font_color", UI.C_RED)
	mark.add_theme_color_override("font_outline_color", UI.C_INK)
	mark.add_theme_constant_override("outline_size", 3)
	mark.position = Vector2(-2, -float(m.get("body_height", 28.0)) - 16.0)
	mark.visible = false
	node.add_child(mark)
	var r := {"spot": -1, "node": node, "body": body, "hands": hands, "mark": mark, "home": at, "leash": leash, "top": float(m.get("body_height", 28.0)),
		"goal": at, "wait": randf_range(0.5, 3.0), "chasing": false, "face": 1.0, "runs": Art.has_anim(sprite_id, "run"), "tint": row.get("tint", Color.WHITE)}
	_roamers.append(r)
	return r


## Asks main.gd for a fight, and makes sure the place cannot be left stuck: the knight stands still
## from the moment the fight is announced (he walked on through a door or opened the pause menu in
## that third of a second), and if main.gd was busy with a fade and dropped the request, the place
## lets go of him again after a moment (the review: roamers stood frozen and no fights came).
func _ask_fight(what: String, arg: Variant, wait: float = 0.0) -> void:
	_caught = true
	frozen = true
	var ask := func() -> void:
		action.emit(what, arg)
		get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void:
			# still here a second and a half later (real time): no battle came
			_caught = false
			_roam_grace = Roamers.GRACE
			Tale.foe_fight = {}
			var main: Node = get_parent().get_parent() if get_parent() != null else null
			frozen = main != null and main.has_method("top_name") and String(main.call("top_name")) != "")
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(ask)
	else:
		ask.call()


## Can main.gd and battles.gd start a battle that is not in tale.gd's own table (a module's)? They can once
## they ask Tale.battle_row(); main.gd says so with a constant MORE_BATTLES (docs/pass/07_world_kit.md).
static var _wired := -1
func _module_battles() -> bool:
	if _wired < 0:
		var main: Variant = load("res://scripts/main.gd")
		_wired = 1 if main is Script and (main as Script).get_script_constant_map().has("MORE_BATTLES") else 0
	return _wired == 1


## A foe of the place touched the knight: its battle.
func _foe_touch(r: Dictionary) -> void:
	var battle := String(r["battle"])
	print("[foe] %s touches the knight: battle %s" % [r["key"], battle])
	if Tale.BATTLES.has(battle) or _module_battles():
		Tale.foe_fight = {"key": String(r["key"]), "battle": battle}
		_ask_fight("tale_do", {"battle": battle})
	else:
		push_warning("hub.gd: main.gd cannot start the module battle '%s' yet (no MORE_BATTLES): a wild fight instead" % battle)
		_ask_fight("hub_encounter", int(r["spot"]))


var _wild_left := 800.0
var _wild_last := Vector2.INF


## Pokemon-style meetings: on the world map every bit of walking in the wild counts down, and at
## zero a fight starts by itself (a "!" sound, a beat, then the battle) with the monsters of the
## ground he is on. Never near the village gate, never during a test tour, never right after arriving.
func _wild_steps(_delta: float) -> void:
	if not Roamers.RANDOM or place_id != "world" or not is_instance_valid(_hero):
		return
	if not frozen and not _changing:
		_roam_grace -= _delta
	if frozen or _changing or _caught or not _tour.is_empty() or _roam_grace > 0.0:
		_wild_last = _hero.position
		return
	if _wild_last == Vector2.INF:
		_wild_last = _hero.position
		return
	var walked := _hero.position.distance_to(_wild_last)
	_wild_last = _hero.position
	if G.flag("wildtest") and int(_time) != int(_time - _delta):
		print("[wild] at %s, %d px to go, %s%s" % [_hero.position.round(), int(_wild_left), Roamers.kind_at(_hero.position), ", lit" if Roamers.lit_at(_hero.position) else ""])
	if walked <= 0.0 or walked > 40.0 or _hero.position.distance_to(Roamers.SAFE_GATE) < Roamers.SAFE_R:
		return
	# (the quality pass) a land whose beacon burns is safer: fights are 40% rarer there (he covers 1.6 times
	# the ground for each), and the first time he walks in it after the lighting the map says so
	var safer := Roamers.lit_at(_hero.position)
	if safer and Tale.on() and Save.hub_get("seen:safer:" + Roamers.land_at(_hero.position)) == 0:
		Save.hub_set("seen:safer:" + Roamers.land_at(_hero.position), 1)
		say(Tale.KIT["safer"])
	_wild_left -= walked / (Roamers.LIT_EASE if safer else 1.0)
	if _wild_left > 0.0:
		return
	Roamers.night = _is_night()             # (who comes depends on the hour: scripts/data/roamers.gd "night")
	Roamers.roll = randi() % 60             # (and which of them leads changes from fight to fight)
	var spot := Roamers.spot_for(_hero.position)
	_wild_left = randf_range(Roamers.STEPS_MIN, Roamers.STEPS_MAX)
	if spot < 0:
		return
	print("[wild] a fight starts: spot %d (%s%s) at %s" % [spot, Roamers.SPOTS[spot]["kind"], ", by night" if Roamers.night else "", _hero.position])
	Sfx.play("enemy_shoot", -6.0, 0.05, 0.7)
	_ask_fight("hub_encounter", spot, 0.35)


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
		var foe: bool = r.has("battle")              # a place's own monster: it guards its patch (the leash round its home)
		var pace := float(place.get("speed", 1.0)) * SPEED / 190.0       # (the roamers' numbers are for the world map, where he does 190)
		var sees := _hero.position.distance_to(home) < float(r["leash"]) if foe else far < Roamers.SEE
		var loses := _hero.position.distance_to(home) > float(r["leash"]) * 1.5 if foe else (far > Roamers.LOSE or node.position.distance_to(home) > float(r["leash"]) + 220.0)
		if not r["chasing"] and _roam_grace <= 0.0 and (_tour.is_empty() or G.flag("foetest")) and sees:
			r["chasing"] = true
			Sfx.play("enemy_shoot", -10.0, 0.05, 0.7)
		elif r["chasing"] and loses:
			r["chasing"] = false
			r["goal"] = home
		var step := Vector2.ZERO
		if r["chasing"]:
			if far < Roamers.TOUCH * _k * 0.5:
				Sfx.play("door_close", -4.0)
				if foe:
					_foe_touch(r)
				else:
					_ask_fight("hub_encounter", int(r["spot"]))
				return
			step = to_hero.normalized() * Roamers.CHASE * pace * delta
		else:
			var to_goal: Vector2 = (r["goal"] as Vector2) - node.position
			if to_goal.length() < 3.0:
				r["wait"] = float(r["wait"]) - delta
				if float(r["wait"]) <= 0.0:
					r["wait"] = randf_range(1.0, 4.0)
					r["goal"] = home + Vector2.RIGHT.rotated(randf() * TAU) * randf() * float(r["leash"]) * (0.4 if foe else 1.0)
			else:
				step = to_goal.normalized() * Roamers.WALK * pace * delta
		var moving := step.length() > 0.001
		if moving:
			var before := node.position
			node.position = (node.position + step).clamp(walk.position, walk.end)
			if foe:
				node.position = _clear_of_blocks(node.position, 5.0 * _k)      # (it does not walk through walls and shut doors)
				if not r["chasing"] and node.position.distance_to(before) < step.length() * 0.3:
					r["goal"] = node.position                                   # (its stroll ran into something: pick another)
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
		mark.position.y = -float(r["top"]) - 16.0 + (roundf(sin(_time * 8.0) * 1.5) if _view == null else 0.0)


## A line in the place's banner for a few seconds (main.gd: what a won roamer fight paid).
func say(text: String) -> void:
	if _woke and place_id != Places.START and text.begins_with("You wake in your bed."):
		# (main.gd's words for a lost fight; he woke by a fire far from his bed: say what is true)
		text = Tale.KIT["wake"] + text.trim_prefix("You wake in your bed.")
	_toast.call("show_text", text, 2.5)


## Test (--hub=kit_test --kittest --nosave): the dungeon kit is used for real, piece by piece, in the
## order a player would: the locked chest refuses, the key chest gives the key, the key door opens on a
## push, the lever opens the other door, the locked chest opens and stays (open), the sign reads, the
## light offers travel, and the guard comes and starts its fight. One "[kit] ..." line each; "[kit] ALL OK".
func _kit_test() -> void:
	var bad: Array = []
	var heard: Array = []
	action.connect(func(what: String, arg: Variant) -> void: heard.append([what, arg]))
	var main: Node = get_parent().get_parent() if get_parent() != null else null
	var shut := func() -> void:
		await get_tree().create_timer(0.15).timeout          # (a moment, as a player takes: the window opens, then is closed)
		if main != null and main.has_method("close_all"):
			main.call("close_all")
		frozen = false
	var check := func(what: String, ok: bool) -> void:
		print("[kit] %s: %s" % [what, "OK" if ok else "BAD"])
		if not ok:
			bad.append(what)
	await get_tree().create_timer(1.0).timeout
	await shut.call()
	check.call("two doors stand shut", _doors.size() == 2 and _blocks.size() == 6)
	talk_to("find:kit_locked")
	check.call("the locked chest stays shut without the key", Save.hub_get("find:kit_locked") == 0 and String((heard.back()[1] as Dictionary)["pages"][0]).begins_with("Locked"))
	await shut.call()
	talk_to("find:kit_keychest")
	check.call("the key chest gives the key", Save.hub_get("dkey:kit") == 1 and Save.hub_get("find:kit_keychest") == 1)
	check.call("the opened chest stays, open", Errands.opened_in(place_id).size() == 1 and Errands.finds_in(place_id, false).size() == 1)
	await shut.call()
	_hero.position = Vector2(140, 212)
	check.call("the key door opens on a push", _push_doors() and Save.hub_get("ddoor:kit_key") == 1 and _doors.size() == 1)
	_hero.position = Vector2(340, 212)
	check.call("the lever door does not", not _push_doors() and _doors.size() == 1)
	talk_to("lever:kit")
	check.call("the lever opens the lever door", Save.hub_get("dlever:kit") == 1 and _doors.is_empty() and _blocks.size() == 4)
	talk_to("find:kit_locked")
	check.call("the locked chest opens with the key", Save.hub_get("find:kit_locked") == 1 and Save.hub_get("bank:coins") >= 10)
	await shut.call()
	heard.clear()
	talk_to("kit_sign")
	check.call("the sign is read without a face", heard.size() == 1 and String(heard[0][0]) == "talk" and String(heard[0][1]["sprite"]) == "" and (heard[0][1]["pages"] as Array).size() == 2)
	await shut.call()
	heard.clear()
	talk_to("kit_light")
	check.call("no beacon burns: the light offers nothing", heard.size() == 1 and ((heard[0][1] as Dictionary)["options"] as Array).is_empty())
	await shut.call()
	Save.hub_set("tale:lit:elfwood", 1)
	heard.clear()
	talk_to("kit_light")
	var offers: Array = (heard[0][1] as Dictionary)["options"] if heard.size() == 1 else []
	check.call("a beacon burns: it offers the watch-fire and that beacon", offers.size() == 2 and String(offers[0]["what"]) == "tale_do" and String(offers[0]["arg"]["travel"]) == "wickmere")
	await shut.call()
	var fx := Tale.apply({"travel": "elfwood"})
	check.call("stepping into the light names the next place", String(Tale.travel_to.get("place", "")) == "beacon" and fx.has("say"))
	Tale.take_travel()
	check.call("\"all\" waits for every flag", Tale.apply({"all": {"flags": ["dlever:kit", "kit:other"], "do": {"flag": "kit:both"}}}).is_empty() and Save.hub_get("kit:both") == 0)
	Save.hub_set("kit:other", 1)
	Tale.apply({"all": {"flags": ["dlever:kit", "kit:other"], "do": {"flag": "kit:both"}}})
	check.call("... and then happens once", Save.hub_get("kit:both") == 1)
	check.call("walking in set the module's flag, its scene was taken", Save.hub_get("kit:entered") == 1 and Save.hub_get("tale:seen:kit_arrive") == 1)
	check.call("the module's battle is found", not Tale.battle_row("kit_guard").is_empty() and Tale.battle_row("glade").has("foes") and Tale.boss_row("gorgon").has("hp"))
	check.call("the yard is not where Play starts, Wickmere would be", Save.hub_get("at:place") == 0 and Places.place_of(Places.place_number("village")) == "village"
		and Places.place_of(Places.place_number("kit_test")) == "kit_test")
	# the guard: stand at the edge of its patch and wait for it
	heard.clear()
	_roam_grace = 0.0
	_hero.position = Vector2(360, 262)
	var waited := 0.0
	while waited < 6.0 and not _caught:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if G.flag("verbose"):
			print("[kit] frozen %s changing %s roamers %d grace %.1f foe at %s" % [frozen, _changing, _roamers.size(), _roam_grace, (_roamers[0]["node"] as Node2D).position if not _roamers.is_empty() else Vector2.ZERO])
	check.call("the guard comes and touches him (%.1f s)" % waited, _caught and frozen)
	check.call("... and asks for a fight", heard.size() >= 1 and ["tale_do", "hub_encounter"].has(String(heard[0][0])))
	print("[kit] ALL OK" if bad.is_empty() else "[kit] %d BAD" % bad.size())
	G.quit(0 if bad.is_empty() else 1)


## Test (--resumetest --nosave): he walks into place after place; after each, where would Play start and
## where would a lost fight wake him? "[resume] ..." lines, then "[resume] ALL OK".
func _resume_test() -> void:
	Save.hub_set("tale:step", Tale.LAST_STEP)
	var bad := 0
	# [place walked into, where Play starts, where a lost fight wakes him]
	for row: Array in [["room", "room", "room"], ["village", "village", "room"], ["elfwood", "elfwood", "room"], ["deepwood", "deepwood", "room"],
			["world", "world", "room"], ["dustwatch", "dustwatch", "dustwatch"], ["suncourt", "suncourt", "dustwatch"], ["world", "world", "dustwatch"],
			["emberfall", "emberfall", "emberfall"], ["cinderpeak", "cinderpeak", "emberfall"], ["village", "village", "room"]]:
		enter(String(row[0]))
		var play := Places.start()
		var wake := Places.wake()
		var spot_ok := true
		for got: Array in [play, wake]:
			if got[1] != Vector2.INF:
				var there := Places.get_place(String(got[0]))
				spot_ok = spot_ok and (there["walk"] as Rect2).has_point(got[1])
				if String(got[0]) == place_id:
					spot_ok = spot_ok and _free_spot(got[1]).distance_to(got[1]) < 0.5
		var ok := String(play[0]) == String(row[1]) and String(wake[0]) == String(row[2]) and spot_ok and Save.hub_get("seen:place:" + String(row[0])) == 1
		print("[resume] in %s: Play -> %s %s, a lost fight -> %s %s: %s" % [row[0], play[0], play[1] if play[1] != Vector2.INF else "(its way in)",
			wake[0], wake[1] if wake[1] != Vector2.INF else "(its way in)", "OK" if ok else "BAD"])
		bad += 0 if ok else 1
	enter("world", Vector2(1500, 800))
	var out := Places.start()
	print("[resume] on the wide world at (1500, 800): Play -> %s %s: %s" % [out[0], out[1], "OK" if String(out[0]) == "world" and out[1] == Vector2(1500, 800) else "BAD"])
	bad += 0 if String(out[0]) == "world" and out[1] == Vector2(1500, 800) else 1
	Save.hub_set("at:place", 999)          # a save that names a place this build does not have
	var lost := Places.start()
	print("[resume] an unknown place -> %s: %s" % [lost[0], "OK" if String(lost[0]) == Places.START else "BAD"])
	bad += 0 if String(lost[0]) == Places.START else 1
	print("[resume] ALL OK" if bad == 0 else "[resume] %d BAD" % bad)
	G.quit(0 if bad == 0 else 1)


## Test (--traveltest): every stop of scripts/data/travel.gd is stood on: the place exists, the spot is
## free, the thing to speak to is in reach, and the spot can be walked to from the place's way in.
func _travel_test() -> void:
	for l: String in ["elfwood", "sands", "cinder", "archive"]:
		Save.hub_set("tale:lit:" + l, 1)
	Save.hub_set("tale:step", Tale.LAST_STEP)
	for stop: Dictionary in Travel.all():
		var pid := String(stop["place"])
		if not Places.exists(pid):
			print("[travel] %s: NO SUCH PLACE %s" % [stop["id"], pid])
			continue
		enter(pid, stop["at"])
		var free := _free_spot(stop["at"]).distance_to(stop["at"]) < 0.5
		var reach := false
		var marked := false
		for p: Dictionary in _people:
			if String(p["row"]["id"]) == String(stop["person"]):
				marked = bool(p["row"].get("travel", false))
				reach = (p["node"] as Node2D).position.distance_to(stop["at"]) < Hub.TALK_REACH * _k
		print("[travel] %s in %s: %s, %d ways on" % [stop["id"], pid, "OK" if free and reach and marked else "BAD (free %s, in reach %s, marked %s)" % [free, reach, marked],
			Travel.from(stop).size()])
		_reach_test("travel:" + String(stop["id"]), stop["at"])
	G.quit(0)


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


## What a tier of arms gives, in words.
func _arm_text(t: Dictionary) -> String:
	var bits: Array = []
	if float(t.get("atk", 0.0)) > 0.0:
		bits.append("+%d%% damage" % roundi(float(t["atk"]) * 100.0))
	if float(t.get("def", 0.0)) > 0.0:
		bits.append("+%d defence" % roundi(float(t["def"])))
	if int(t.get("hp", 0)) > 0:
		bits.append("+%d health" % int(t["hp"]))
	if t.has("look"):
		bits.append("a new look")
	return ", ".join(bits)


## (v0.39.0) A teacher's window for one member of the party: every skill, what it costs to learn
## or to raise, and when the ones still shut open.
func lore_info(who: String) -> Dictionary:
	var person := Looks.hero_name() if who == "knight" else String(Allies.row(who)["name"])
	var info := {"name": person, "title": "skills", "pages": [], "lines": [], "options": []}
	var rows: Array = []
	if who == "knight":
		for r: Dictionary in Skills.LIST:
			rows.append(r)
	else:
		rows = Battles.ALLY[who]["skills"]
	var shut_shown := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var sid := String(r["id"])
		var rk := Arms.rank(who, sid)
		var knows := Arms.knows(who, sid, i)
		var cost := Arms.price(who, sid, i)
		var opens := Arms.opens_at(who, sid, i)
		if cost < 0:
			info["lines"].append(["%s: rank %d, the most I can teach." % [r["name"], rk], UI.C_GREEN])
		elif Rpg.level() < opens:
			if shut_shown < 2:
				info["lines"].append(["%s: opens at level %d." % [r["name"], opens], UI.C_FAINT])
			shut_shown += 1
		else:
			var what := ("Raise %s to rank %d" % [r["name"], maxi(rk, 1) + 1]) if knows else ("Learn %s" % r["name"])
			info["options"].append({"text": "%s: %d coins" % [what, cost], "what": "hub_teach", "arg": {"who": who, "id": sid, "i": i},
				"off": Upgrades.coins() < cost, "why": _poor(cost)})
	info["lines"].append(["Each rank: about a fifth stronger. Coins: %d" % Upgrades.coins(), UI.C_GOLD])
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
var _tour_jump := false
func _tour_step(delta: float) -> Vector2:
	var target: Vector2 = _tour[0]
	if _tour_jump:
		_tour_jump = false
		_hero.position = target + Vector2(-10, 0)
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
		if G.arg("hubtalk").begins_with("lore:"):
			action.emit("hub_lore", G.arg("hubtalk").substr(5))      # test: --hubtalk=lore:knight opens the teacher's list
		elif G.arg("hubtalk") == "shelf":
			action.emit("hub_shelf", "Tam")      # test: --hubtalk=shelf opens the smith's shelf of gear
		else:
			talk_to(G.arg("hubtalk"))
		if G.flag("talkend"):            # test: --talkend : skip to the choices at the end of the talk
			await get_tree().create_timer(0.6).timeout
			var main_node := get_tree().root.get_node_or_null("Main")
			for i in 8:
				var top: Variant = main_node.call("top_screen") if main_node != null else null
				if is_instance_valid(top) and top is Node and (top as Node).has_method("_advance"):
					(top as Node).call("_finish_words")
					(top as Node).call("_advance")
					await get_tree().create_timer(0.15).timeout
		await get_tree().create_timer(0.8).timeout
		G.save_shot("hub_talk_%s.png" % G.arg("hubtalk"))
		await get_tree().create_timer(0.3).timeout
	G.quit(0)
