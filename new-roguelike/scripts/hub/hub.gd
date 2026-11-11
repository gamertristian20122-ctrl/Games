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
const Story = preload("res://scripts/data/story.gd")
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

var frozen := false              ## a window is open: the hero stands still
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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Controls.action_enabled = true
	_build_ground()
	_ysort = Node2D.new()
	_ysort.y_sort_enabled = true
	add_child(_ysort)
	for p: Array in Hub.PROPS:
		_prop(String(p[0]), Vector2(p[1], p[2]), float(p[3]), float(p[4]))
	_build_forest()
	_build_fire()
	for row: Dictionary in Hub.NPCS:
		_add_person(row)
	_build_hero()
	refresh_heroes()
	_build_light()
	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(Hub.MAP.x)
	_cam.limit_bottom = int(Hub.MAP.y)
	_cam.position = _hero.position
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
	if G.arg("hublevel") != "":          # test: go down into that level after a second
		get_tree().create_timer(1.0).timeout.connect(func() -> void: action.emit("hub_level", G.arg("hublevel")))
	elif Save.hub_get("seen:intro") == 0 and G.arg("shots") == "":
		# the very first visit: the Druid speaks first
		Save.hub_set("seen:intro", 1)
		get_tree().create_timer(0.7).timeout.connect(func() -> void: action.emit("talk", Story.INTRO.duplicate(true)))
	if G.arg("shots") != "" and G.flag("hub"):
		_tour = [Vector2(376, 170), Vector2(180, 276), Vector2(360, 300), Vector2(540, 276), Vector2(520, 410)]


func _exit_tree() -> void:
	G.hub_near = false


# ------------------------------------------------------------------ building
func _build_ground() -> void:
	var ground := Node2D.new()
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var grass := Art.tex("hub_grass")
	ground.draw.connect(func() -> void:
		ground.draw_texture_rect(grass, Rect2(Vector2(-64, -64), Hub.MAP + Vector2(128, 128)), true))
	add_child(ground)
	# small flat things on the grass and the trodden paths: the same every time
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	var n := 0
	for path: Array in Hub.PATHS:
		for i in path.size() - 1:
			var from: Vector2 = path[i]
			var to: Vector2 = path[i + 1]
			var steps := maxi(1, int(from.distance_to(to) / 30.0))
			for k in steps + 1:
				var s := Sprite2D.new()
				s.texture = Art.tex("hub_patch_%d" % (n % 2))
				s.position = (from.lerp(to, float(k) / float(steps)) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))).round()
				s.flip_h = rng.randf() < 0.5
				add_child(s)
				n += 1
	for id: String in Hub.SCATTER:
		var spec: Array = Hub.SCATTER[id]
		for i in int(spec[1]):
			var s := Sprite2D.new()
			s.texture = Art.tex("%s_%d" % [id, rng.randi() % int(spec[0])])
			s.position = Vector2(roundf(rng.randf_range(8.0, Hub.MAP.x - 8.0)), roundf(rng.randf_range(70.0, Hub.MAP.y - 8.0)))
			s.flip_h = rng.randf() < 0.5
			add_child(s)


## A standing piece: its base on `at`, `below` px of the picture hanging under the base line.
func _prop(id: String, at: Vector2, solid: float, below: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(id)
	s.centered = false
	var sz := s.texture.get_size()
	s.offset = Vector2(-floorf(sz.x * 0.5), -sz.y + below)
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
	pit.position = Hub.FIRE
	pit.offset = Vector2(0, -8)
	_ysort.add_child(pit)
	var flame := _anim("hub_flame", 9.0)
	flame.offset = Vector2(0, -16)
	pit.add_child(flame)
	_solids.append([Hub.FIRE - Vector2(0, 6), 11.0])
	var grill := _anim("hub_fire_c", 7.0)        # the cook's fire
	grill.position = Hub.GRILL
	grill.offset = Vector2(0, -10)
	_ysort.add_child(grill)
	_solids.append([Hub.GRILL - Vector2(0, 4), 10.0])


## The forest wall round the clearing, fitted to the size of the map.
func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7071
	for p: Array in Hub.BEHIND_GATE:
		_prop(String(p[0]), Vector2(p[1], p[2]), 0.0, 8.0)
	var i := 0
	var x := 24.0
	while x < Hub.MAP.x:
		if x < float(Hub.GATE_GAP[0]) or x > float(Hub.GATE_GAP[1]):
			_prop(String(Hub.FOREST_BIG[i % Hub.FOREST_BIG.size()]), Vector2(x, 94.0 + rng.randf_range(-6, 6)).round(), 0.0, 8.0)
			i += 1
		x += 78.0
	var y := 176.0
	while y < Hub.MAP.y - 10.0:
		_prop(String(Hub.FOREST_SIDE[i % Hub.FOREST_SIDE.size()]), Vector2(4.0 + rng.randf_range(-4, 4), y).round(), 0.0, 8.0)
		_prop(String(Hub.FOREST_SIDE[(i + 1) % Hub.FOREST_SIDE.size()]), Vector2(Hub.MAP.x - 4.0 + rng.randf_range(-4, 4), y + 30.0).round(), 0.0, 8.0)
		i += 1
		y += 84.0
	x = 22.0
	while x < Hub.MAP.x:
		_prop(String(Hub.FOREST_LOW[i % Hub.FOREST_LOW.size()]), Vector2(x, Hub.MAP.y - 6.0 + rng.randf_range(-5, 3)).round(), 0.0, 5.0)
		i += 1
		x += 58.0
	x = 70.0
	while x < Hub.MAP.x:
		_prop(String(Hub.FOREST_YOUNG[i % Hub.FOREST_YOUNG.size()]), Vector2(x, Hub.MAP.y + 34.0).round(), 0.0, 8.0)
		i += 1
		x += 104.0


func _build_light() -> void:
	var dusk := CanvasModulate.new()
	dusk.color = DUSK
	add_child(dusk)
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
	for spec: Array in [[Hub.FIRE - Vector2(0, 10), Color(1.0, 0.72, 0.42), 2.1, 0.7], [Hub.GRILL - Vector2(0, 10), Color(1.0, 0.7, 0.45), 1.1, 0.5],
			[Vector2(146, 216), Color(0.45, 0.85, 1.0), 1.3, 0.5], [Vector2(360, 88), Color(0.75, 0.6, 1.0), 1.1, 0.4],
			[Vector2(590, 236), Color(1.0, 0.75, 0.5), 0.9, 0.35]]:
		var l := PointLight2D.new()
		l.texture = tex
		l.position = spec[0]
		l.color = spec[1]
		l.texture_scale = spec[2]
		l.energy = spec[3]
		l.name = "light%d" % get_child_count()
		add_child(l)
	# fireflies: single pale squares drifting over the clearing
	var flies := CPUParticles2D.new()
	flies.position = Hub.MAP * 0.5
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Hub.MAP * 0.5
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
	add_child(flies)


## A person standing in the camp: body, both hands, a shadow, and a gold "!" when they have news.
func _add_person(row: Dictionary) -> Dictionary:
	var node := Node2D.new()
	node.position = row["pos"]
	_ysort.add_child(node)
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
	if row.has("weapon"):
		var w := HeroLook.make_weapon(row)
		node.add_child(w)
		HeroLook.rest(w, face)
		if hands != null and hands.near != null:
			hands.near.queue_free()            # that hand holds the weapon
			hands.near = null
	var mark := UI.label("!", "Head")
	mark.theme = UI.theme()
	mark.add_theme_color_override("font_color", UI.C_GOLD)
	mark.add_theme_color_override("font_outline_color", UI.C_INK)
	mark.add_theme_constant_override("outline_size", 3)
	mark.position = Vector2(-2, -bh - 16)
	mark.visible = false
	mark.z_index = 100
	node.add_child(mark)
	_solids.append([row["pos"] - Vector2(0, 2), 6.0])
	var person := {"row": row, "node": node, "hands": hands, "mark": mark, "face": face, "top": bh, "solid": _solids.size() - 1,
		"body": body, "post": row["pos"], "goal": row["pos"], "wait": randf_range(1.0, 4.0), "walks": Art.has_anim(sprite_id, "run") and not row.has("weapon")}
	_people.append(person)
	return person


func _build_hero() -> void:
	_hero = Node2D.new()
	_hero.position = Hub.SPAWN
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
	var move := Vector2.ZERO
	if not frozen:
		move = Controls.move
		if not _tour.is_empty():
			move = _tour_step(delta)
	var moving := move.length() > 0.12
	if moving:
		var to := _hero.position + move.limit_length(1.0) * SPEED * delta
		to = to.clamp(Hub.WALK.position, Hub.WALK.end)
		for s: Array in _solids:
			var d: Vector2 = to - (s[0] as Vector2)
			var reach: float = float(s[1]) + HERO_RADIUS
			if d.length_squared() < reach * reach and d.length_squared() > 0.0001:
				to = (s[0] as Vector2) + d.normalized() * reach
		_hero.position = to.clamp(Hub.WALK.position, Hub.WALK.end)
		if absf(move.x) > 0.1:
			_face = signf(move.x)
	var want := "run" if moving else "idle"
	if _body.animation != want:
		_body.play(want)
	_body.flip_h = _face < 0.0
	HeroLook.rest(_weapon, _face, delta)
	_off_hand.update(delta, moving, _face)
	_cam.position = _hero.position.round()
	_update_people(delta)


func _update_people(delta: float) -> void:
	var best := -1
	var best_d := Hub.TALK_REACH
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
		mark.visible = (news and String(p["row"].get("role", "")) == "quests") or bool(p.get("news", false))
		mark.position.y = -float(p["top"]) - 16.0 + roundf(sin(_time * 5.0) * 1.5)
	_near = best
	_quests.visible = not frozen
	G.hub_near = best >= 0 and not frozen
	if best >= 0 and not frozen:
		var p: Dictionary = _people[best]
		_prompt.text = String(p["row"]["name"])
		_prompt.reset_size()
		_prompt.position = ((p["node"] as Node2D).position + Vector2(-_prompt.size.x * 0.5, -float(p["top"]) - 12.0)).round()
		_prompt.visible = true
	else:
		_prompt.visible = false



## People are not statues: they turn to the hero when he comes close, and those the pack drew
## walking wander a few steps round their post now and then. Returns true while walking.
func _stroll(p: Dictionary, delta: float, hero_dist: float) -> bool:
	var node: Node2D = p["node"]
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
	var info := {"name": row["name"], "title": row.get("title", ""), "sprite": row["sprite"], "pages": pages, "heard": id,
		"lines": [], "options": []}
	match String(row.get("role", "chat")):
		"gate":
			var next := Story.next_level()
			if next.is_empty():
				info["lines"].append(["Every seal is mended.", UI.C_GOLD])
			else:
				info["options"].append({"text": "Go down: %s" % String(next["name"]), "what": "hub_level", "arg": next["id"]})
			var c := Story.chapter()
			if c > 0:
				info["options"].append({"text": "Go down from the top", "what": "hub_level", "arg": Story.LEVELS[0]["id"]})
			info["lines"].append(["Levels cleared: %d of %d. One descent runs through them all; walk out from the pause menu when no fight is on." % [c, Story.LEVELS.size()], UI.C_DIM])
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
	var sells := false
	for up: Dictionary in Upgrades.LIST:
		if String(up["at"]) != id:
			continue
		sells = true
		var t := Upgrades.tier(String(up["id"]))
		var price := Upgrades.cost(up)
		info["lines"].append(["%s %d/%d: %s" % [up["name"], t, Upgrades.steps(up), up["text"]], UI.C_DIM if price >= 0 else UI.C_FAINT])
		if price >= 0:
			info["options"].append({"text": "%s: %d coins" % [up["name"], price], "what": "hub_buy", "arg": up["id"], "off": Upgrades.coins() < price})
	if sells:
		info["lines"].append(["Camp chest: %d coins. Walk out of the hill alive to fill it." % Upgrades.coins(), UI.C_GOLD])
	# heard it already this visit and nothing new: straight to the choices
	if not Story.has_news(id) and _talked.has(id) and not ((info["options"] as Array).is_empty() and (info["lines"] as Array).is_empty()):
		info["pages"] = []
	_talked[id] = true
	action.emit("talk", info)


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
