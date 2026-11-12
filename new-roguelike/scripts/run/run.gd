extends Node2D
## Run: one playthrough, from floor 1 down to the last boss. This node owns everything in the
## world half: the current room, the player, the shot and effect managers, the camera and the lights.
## It is what G.run points to (see scripts/core/g.gd for what the menus and HUD may read).
##
##   var run = load("res://scripts/run/run.gd").new(); parent.add_child(run); run.setup("knight", 1234)
##
## The same seed gives the same floors, rooms, items and shop stock.
## Test flags (after "--" on the command line): --autotest --hero= --seed= --speed= --time= --god
##   --floor=<1-4> --give=id,id --goto=boss|shop|treasure|secret --layout=<name> --shots=<dir> --shot_every=<sec>
##   --boss=<id>  this boss (a row key of scripts/data/bosses.gd) guards the floor, whichever floor it is
##   --curse=<0-5> start at this Curse Level   --belly=<n> coins already in its belly   --nocurse no Curse at all
## summary()["floor"] counts from 1 (floor_index counts from 0).

const Heroes = preload("res://scripts/data/heroes.gd")
const Story = preload("res://scripts/data/story.gd")
const Rpg = preload("res://scripts/data/rpg.gd")
const Weapons = preload("res://scripts/data/weapons.gd")
const Floors = preload("res://scripts/data/floors.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Items = preload("res://scripts/data/items.gd")
const FloorGen = preload("res://scripts/run/floor_gen.gd")
const RoomScript = preload("res://scripts/run/room.gd")
const ShotsScript = preload("res://scripts/run/shots.gd")
const FxScript = preload("res://scripts/run/fx.gd")
const ItemEffects = preload("res://scripts/run/item_effects.gd")
const PlayerScript = preload("res://scripts/entities/player.gd")
const Curse = preload("res://scripts/entities/curse.gd")
const CurseTutor = preload("res://scripts/run/curse_tutor.gd")

# ------------------------------------------------------------------ tuning (one place for the big numbers)
## Mood lighting. Set to false if a phone struggles: the game then draws flat and bright.
const LIGHTING := true
## A fight room's enemy budget: BASE + PER_FLOOR x floor_index + PER_ROOM x rooms already cleared on this floor.
const SPAWN_BUDGET_BASE := 6.0      ## 6.5 while the Hungry Curse ate a third of the monsters
const SPAWN_BUDGET_PER_FLOOR := 3.0
const SPAWN_BUDGET_PER_ROOM := 0.5
const MAX_ENEMIES_PER_ROOM := 12
## Chance for each enemy to be an elite (from floor 2). Other systems may raise run.elite_chance.
const ELITE_CHANCE := 0.08
## Bombs (px): blast that hurts enemies / hurts the player / breaks rocks and crates / reveals secret doors.
const BOMB_RADIUS := 30.0
const BOMB_HURT_RADIUS := 24.0
const BOMB_BREAK_RADIUS := 26.0
const BOMB_REVEAL_RADIUS := 22.0
const ROOM_FADE := 0.25
const HITSTOP_MAX := 0.08
const SHAKE_PIXELS := 3.5

const TYPE_NAMES := ["start", "combat", "treasure", "shop", "secret", "boss", "altar"]

# ------------------------------------------------------------------ what the shell may read (see g.gd)
var hero_id := "knight"
var floor_index := 0
var xp_earned := 0               ## XP earned in this run (the end screen shows it)
var scale_floor := 0             ## how strong the monsters are: the floor, or a side level's "tier"
## Story mode (scripts/data/story.gd): the level being played, or {} for the old endless descent.
## A level is ONE small floor that ends when its boss falls. The camp passes it in G.next_run:
##   {"level": <row of Story.LEVELS>, "kit": [item ids the hero carries], "pack": {coins, bombs, keys}}
var level := {}
## The training yard (the Sergeant in the village): one room, a straw dummy, and sparring monsters
## that come back. The hero cannot die here and nothing he does is kept.
var training := false
var _spar_t := 0.0
const SPARRING := ["shambler", "bone_walker", "bone_archer"]
const LEVEL_HEAL := 2             ## half hearts given back when a level's boss falls
const LEVEL_STEP_BUDGET := 0.8    ## extra monster budget for the second level of an area
var floor_name := ""
var floor_count := 4
var time_s := 0.0
var kills := 0
var cur := Vector2i.ZERO
var rooms := {}
var player: Node2D
var boss: Node = null
# ---- the Hungry Curse (rules and numbers: scripts/entities/curse.gd)
var curse_level := 0             ## 0..5; every cursed item taken adds 1, "Starve the Curse" takes 1 off
var belly := 0                   ## coins the Curse has swallowed and still carries (kept from room to room and floor to floor)
var starve_bought := 0           ## how many times "Starve the Curse" was bought this run (the price climbs)
var call_cd := 0.0               ## seconds until the CALL button works again
var call_fill := 1.0             ## 0..1 for the button's cooldown ring
var call_ready := false          ## pressing CALL would work right now
var call_pulse := false          ## the first-run lesson asks the button to pulse
var tutor: Node = null           ## the first-run lesson (scripts/run/curse_tutor.gd), or null

# ------------------------------------------------------------------ world internals
var seed_value := 0
var theme: Dictionary
var room: Node2D
var world: Node2D
var shots: Node2D
var fx: Node2D
var effects: RefCounted
var camera: Camera2D
var ambient: CanvasModulate
var light_tex: GradientTexture2D
var bot: Node
var elite_chance := ELITE_CHANCE
var enemy_pool: Array[String] = []
var boss_id := ""
var rooms_cleared := 0
var rooms_cleared_floor := 0
var secrets_found := 0
var bosses_beaten: Array[String] = []
var used_items := {}
var over := false
var victory := false
var death_cause := ""

var _built := false
var _pending_dir := Vector2i.ZERO
var _has_pending := false
var _floor_change := 0.0       # > 0 while fading out to the next floor
var _end_t := -1.0
var _trauma := 0.0
var _hitstop := 0.0
var _slow_left := 0.0
var _slow_base := 0.0
var _fade: ColorRect
var _fade_alpha := 0.0
var _slide := Vector2.ZERO
var _secret_counted := false
var _shot_queue: Array = []
var _shot_counts := {}
var _shot_every := 0.0
var _shot_every_t := 0.0
var _fight_shot_done := true
static var _font: Font


# =============================================================================== starting
## Starts a run. Call once, right after adding the node to the scene.
func setup(hero: String, run_seed: int) -> void:
	hero_id = hero
	seed_value = run_seed
	G.run = self
	# the second button: BLOCK for a sword hero (player.gd), CALL only with the old Curse switched on
	Controls.action_enabled = G.curse_on() or Heroes.by_id(hero).has("melee")
	floor_count = Floors.count()
	if not _built:
		_build_nodes()
	_begin()
	if G.flag("autotest") and bot == null:
		bot = load("res://scripts/run/bot.gd").new()
		add_child(bot)
		bot.setup(self)


func _build_nodes() -> void:
	_built = true
	light_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.35, 0.35, 0.35, 1), Color(0, 0, 0, 1)])
	light_tex.gradient = g
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	light_tex.width = 64
	light_tex.height = 64
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ambient = CanvasModulate.new()
	add_child(ambient)
	shots = ShotsScript.new()
	shots.run = self
	world.add_child(shots)
	fx = FxScript.new()
	world.add_child(fx)
	camera = Camera2D.new()
	camera.position = G.CAMERA_CENTER
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.04, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_shot_every = float(G.arg("shot_every", "0"))


## (Re)starts everything that belongs to one playthrough.
func _begin() -> void:
	time_s = 0.0
	kills = 0
	rooms_cleared = 0
	secrets_found = 0
	bosses_beaten = []
	used_items = {}
	over = false
	victory = false
	death_cause = ""
	boss = null
	curse_level = clampi(int(G.arg("curse", "0")), 0, Curse.MAX_LEVEL)
	belly = clampi(int(G.arg("belly", "0")), 0, Curse.belly_cap(self))
	starve_bought = 0
	call_cd = 0.0
	call_pulse = false
	elite_chance = ELITE_CHANCE
	_end_t = -1.0
	_has_pending = false
	_floor_change = 0.0
	_shot_counts = {}
	var asked: Dictionary = G.next_run          # set by the camp; used once
	G.next_run = {}
	level = asked.get("level", {})
	training = bool(asked.get("training", false))
	if not level.is_empty():
		asked["floor"] = int(level.get("floor", 1))
	floor_index = clampi(int(G.arg("floor", str(asked.get("floor", 1)))) - 1, 0, floor_count - 1)
	theme = _theme()
	effects = ItemEffects.new(self)
	_generate_floor()
	player = PlayerScript.new()
	player.setup(self, hero_id)
	if tutor != null and is_instance_valid(tutor):
		tutor.free()
	tutor = null
	if CurseTutor.wanted():
		tutor = CurseTutor.new()
		add_child(tutor)
		tutor.setup(self)
	G.stat.emit("runs", 1)
	G.run_started.emit(self)
	_enter_floor()
	for item_id in G.arg("give").split(",", false):
		if Items.ALL.has(item_id):
			used_items[item_id] = true
			player.add_item(item_id)
	# from the camp: the hero carries what earlier levels gave him, and the supplies earned from quests
	if not asked.is_empty():
		for item_id: Variant in asked.get("kit", []):
			if Items.ALL.has(String(item_id)) and not used_items.has(String(item_id)):
				used_items[String(item_id)] = true
				player.add_item(String(item_id))
		player.hp = player.max_hp
		var pack: Dictionary = asked.get("pack", {})
		player.coins += int(pack.get("coins", 0))
		player.bombs += int(pack.get("bombs", 0))
		player.keys += int(pack.get("keys", 0))
		G.hud_changed.emit()


## Autotest only: throws the finished run away and starts a fresh one in the same node.
func restart(new_seed: int) -> void:
	seed_value = new_seed
	_leave_room()
	for f in player.familiars:
		if is_instance_valid(f):
			f.free()
	player.free()
	player = null
	shots.clear()
	fx.clear()
	_begin()


func _exit_tree() -> void:
	if _slow_base > 0.0:
		Engine.time_scale = _slow_base
		_slow_base = 0.0
	if G.run == self:
		G.run = null
		Controls.action_enabled = false


## The font for the few numbers the world draws itself (shop prices). Uses the first font file
## in res://assets/fonts/ if there is one.
func font() -> Font:
	if _font == null:
		var dir := DirAccess.open("res://assets/fonts")
		if dir != null:
			for f in dir.get_files():
				var file := f.trim_suffix(".import").trim_suffix(".remap")
				if file.get_extension() in ["ttf", "otf", "fnt"] and ResourceLoader.exists("res://assets/fonts/" + file):
					_font = load("res://assets/fonts/" + file)
					break
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


# =============================================================================== floors
func _start_floor() -> void:
	_generate_floor()
	_enter_floor()


## Builds the map of the current floor (no signals yet, nothing on screen).
func _generate_floor() -> void:
	cur = Vector2i.ZERO
	theme = _theme()
	floor_name = String(theme["name"])
	scale_floor = int(level.get("tier", floor_index))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, floor_index, "floor"])
	# a story level's boss lies deep: at least half its rooms away, so the way to it is a real fight
	var room_count := int(level.get("rooms", theme["rooms"]))
	rooms = FloorGen.generate(rng, room_count, 3 if level.is_empty() else maxi(3, room_count / 2))
	if training:
		rooms = {Vector2i.ZERO: FloorGen._record(G.RoomType.START, rng, 0)}
		FloorGen._link(rooms)
		floor_name = "The Training Yard"
	var listed: Array = theme.get("enemies", [])
	enemy_pool = Enemies.pool_for_floor(floor_index + 1)
	if not listed.is_empty():
		enemy_pool.clear()
		for id in listed:
			enemy_pool.append(String(id))
	var guards := Bosses.for_floor(floor_index + 1)
	boss_id = guards[rng.randi() % guards.size()]
	if not level.is_empty() and Bosses.known(String(level.get("boss", ""))):
		boss_id = String(level["boss"])
	if not level.is_empty():
		floor_name = String(level.get("name", floor_name))
	# --boss=<id>: this boss guards the floor, whichever floor it is (for tests and screenshots)
	var forced_boss := G.arg("boss")
	if forced_boss != "" and Bosses.known(forced_boss):
		boss_id = Bosses.real_id(forced_boss)
	# a boss too big for pillars brings its own room (the row's "layout")
	var arena := String(Bosses.info(boss_id).get("layout", ""))
	if arena != "":
		for c: Vector2i in rooms:
			if rooms[c]["type"] == G.RoomType.BOSS:
				rooms[c]["layout"] = arena
	rooms_cleared_floor = 0
	_secret_counted = false
	boss = null


## Announces the floor and puts the player into its first room.
func _enter_floor() -> void:
	ambient.color = theme["ambient"] if LIGHTING else Color(1, 1, 1)
	Sfx.music(String(theme.get("music", "")))
	G.floor_started.emit(floor_index, floor_name)
	G.stat.emit("floor_reached:%d" % (floor_index + 1), 1)
	effects.fire("on_floor_start", [])
	var start := Vector2i.ZERO
	var from := Vector2i.ZERO
	var goto := G.arg("goto")
	if goto != "":
		var want: int = TYPE_NAMES.find(goto)
		for c: Vector2i in rooms:
			if rooms[c]["type"] != want:
				continue
			start = c
			if want == G.RoomType.BOSS:
				# stand in the room next door, facing the boss door
				for d: Vector2i in rooms[c]["doors"]:
					var n: Vector2i = rooms[c]["doors"][d]["to"]
					if rooms[n]["type"] != G.RoomType.SECRET:
						start = n
						from = -d
						rooms[n]["cleared"] = true
			elif want == G.RoomType.TREASURE:
				for d2: Vector2i in rooms[c]["doors"]:
					rooms[c]["doors"][d2]["locked"] = false
					var back: Dictionary = rooms[rooms[c]["doors"][d2]["to"]]["doors"]
					if back.has(-d2):
						back[-d2]["locked"] = false
			break
	_enter_room(start, from)
	if from != Vector2i.ZERO:
		# --goto=boss: stand in front of the boss door instead of at the opposite one
		player.position = room.door_pos(from) - Vector2(from) * 22.0
	if training:
		G.toast.emit(floor_name, "Nobody dies here")
	elif level.is_empty():
		G.toast.emit(floor_name, "Floor %d" % (floor_index + 1))
	else:
		var nth := Story.LEVELS.find(level)
		G.toast.emit(floor_name, "%s · level %d of %d" % [String(level.get("area", "")), nth + 1, Story.LEVELS.size()] if nth >= 0 else String(level.get("area", "")))


## Walk onto the exit: fade out, then build the next floor.
## The look and the monsters of what is being played: one of the hill's floors, or a level's own "look".
func _theme() -> Dictionary:
	if not level.is_empty() and level.has("look"):
		return Floors.extra(String(level["look"]))
	return Floors.get_floor(floor_index)


## A side level's champion fell (room.gd tells us when its glade is cleared).
func champion_fell() -> void:
	bosses_beaten.append(String(level.get("champion", "")))
	G.stat.emit("champions", 1)
	_level_done()


## The next unfound note for a room to lay out (-1 = none). A note is handed to one room only.
var _notes_out := {}
func take_note() -> int:
	for i in Story.NOTES.size():
		if Save.hub_get("note:%d" % i) == 0 and not _notes_out.has(i):
			_notes_out[i] = true
			return i
	return -1


## Story: is there a level below the one being played?
func has_next_level() -> bool:
	return not level.is_empty() and not bool(level.get("final", false)) and not Story.after(String(level["id"])).is_empty()


## Story: how much harder this level is than the first one with the same look (room.gd adds it to the budget).
func level_bonus() -> float:
	return 0.0 if level.is_empty() else LEVEL_STEP_BUDGET * float(Story.step_in_area(String(level["id"])))


func next_floor() -> void:
	if _floor_change > 0.0 or over:
		return
	_floor_change = 0.4
	Sfx.play("stairs_descend")


func treasure_locked() -> bool:
	for c in rooms:
		if rooms[c]["type"] == G.RoomType.TREASURE:
			for d in rooms[c]["doors"]:
				if rooms[c]["doors"][d]["locked"]:
					return true
	return false


# =============================================================================== rooms
## The player walked through the door on side `dir`. The change happens at the start of the next frame.
func go(dir: Vector2i) -> void:
	if _has_pending or over:
		return
	_has_pending = true
	_pending_dir = dir


## True while the world should leave the player alone (changing rooms or floors, run finished).
func busy() -> bool:
	return _has_pending or _floor_change > 0.0 or over


func _leave_room() -> void:
	if room == null:
		return
	room.save_state()
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	for f in player.familiars:
		if is_instance_valid(f) and f.get_parent() != null:
			f.get_parent().remove_child(f)
	world.remove_child(room)
	room.queue_free()
	room = null


func _enter_room(coord: Vector2i, from_dir: Vector2i) -> void:
	_leave_room()
	shots.clear()
	fx.clear()
	cur = coord
	var rs: Dictionary = rooms[coord]
	room = RoomScript.new()
	world.add_child(room)
	world.move_child(room, 0)
	room.setup(self, coord)
	shots.room = room
	room.ysort.add_child(player)
	if from_dir == Vector2i.ZERO:
		player.position = G.ROOM_CENTER + Vector2(0, 14)
	else:
		player.position = room.door_pos(-from_dir) + Vector2(from_dir) * 11.0
	player.entered_room(room)
	for f in player.familiars:
		if is_instance_valid(f):
			room.ysort.add_child(f)
			f.entered_room()
	var first: bool = not rs["visited"]
	rs["visited"] = true
	rs["seen"] = true
	for d: Vector2i in rs["doors"]:
		var door: Dictionary = rs["doors"][d]
		if not door["hidden"] or door["revealed"]:
			rooms[door["to"]]["seen"] = true
	G.room_entered.emit(coord, rs["type"], first)
	room.begin(first)
	effects.fire("on_room_enter", [room])
	G.hud_changed.emit()
	_fade_alpha = 1.0
	_slide = Vector2(from_dir) * 26.0
	_fight_shot_done = not room.fighting
	if first and G.flag("shots"):
		var key := "floor%d_%s" % [floor_index + 1, TYPE_NAMES[rs["type"]]]
		_shot_counts[key] = int(_shot_counts.get(key, 0)) + 1
		_shot_queue.append([0.45, "%s_%d.png" % [key, _shot_counts[key]]])


func on_room_cleared(the_room: Node) -> void:
	rooms_cleared += 1
	rooms_cleared_floor += 1
	G.room_cleared.emit(the_room.coord)
	G.stat.emit("rooms_cleared", 1)
	effects.fire("on_room_clear", [the_room])
	Save.flush()
	G.hud_changed.emit()


## A hidden door was blown open. Counts once per floor.
func secret_revealed() -> void:
	if _secret_counted:
		return
	_secret_counted = true
	secrets_found += 1
	G.stat.emit("secret_found", 1)
	G.toast.emit("Secret found!", "")


## Picks an item for a pedestal or shop stand from a pool ("treasure", "boss", "shop", "secret",
## "cursed"). An item is offered only once per run. Returns "" when nothing is left.
func take_item(pool: String, rng: RandomNumberGenerator) -> String:
	var options: Array[String] = []
	for id: String in Items.ALL:
		var info: Dictionary = Items.ALL[id]
		if used_items.has(id) or not (info.get("pools", []) as Array).has(pool) or _needs_curse(info):
			continue
		if info.get("locked", false) and not Save.is_unlocked("item:" + id):
			continue
		options.append(id)
	if options.is_empty() and pool != "cursed":
		# the pool ran dry: any normal item that is still unused
		for id: String in Items.ALL:
			var info2: Dictionary = Items.ALL[id]
			if used_items.has(id) or info2.get("cursed", false) or _needs_curse(info2):
				continue
			if info2.get("locked", false) and not Save.is_unlocked("item:" + id):
				continue
			options.append(id)
	if options.is_empty():
		return ""
	var pick: String = options[rng.randi() % options.size()]
	used_items[pick] = true
	return pick


## Items that only do something with the Hungry Curse are not offered while it is switched off.
func _needs_curse(info: Dictionary) -> bool:
	if G.curse_on():
		return false
	return bool(info.get("needs_curse", false))


# =============================================================================== kills, death, victory
func enemy_killed(e: Node) -> void:
	kills += 1
	gain_xp(Rpg.xp_of(e, scale_floor))
	G.stat.emit("kills", 1)
	effects.fire("on_kill", [e])


## RPG: XP for the knight (never in the training yard, never for the two old test heroes).
## A new level mends LEVEL_HEAL, makes him stronger at once and asks the shell for the card choice.
func gain_xp(amount: int) -> void:
	if amount <= 0 or training or not is_instance_valid(player) or not player.hero.has("melee"):
		return
	xp_earned += amount
	var ups := Rpg.gain(amount)
	G.xp_changed.emit()
	if ups <= 0:
		return
	player.apply_rpg(Rpg.LEVEL_HEAL * ups)
	fx.flourish(player.global_position - Vector2(0, 10))
	Sfx.play("victory_sting", -8.0, 0.0, 1.5)
	G.toast.emit("Level %d" % Rpg.level(), Rpg.growth_text(Rpg.level()))
	if G.flag("autotest") and not G.flag("uitour"):
		# the bot takes the first card offered, so its fights are as strong as a player's
		while Rpg.picks() > 0:
			var cards := Rpg.offer()
			if cards.is_empty():
				Rpg.pick_coins()
			else:
				Rpg.pick(String(cards[0]))
		player.apply_rpg()
		print("[rpg] level %d" % Rpg.level())
	G.level_up.emit(Rpg.level())
	G.hud_changed.emit()


## The Hungry Curse swallowed an enemy whole. It counts as a kill, but nothing died the usual
## way: "on kill" item effects do not fire.
func enemy_devoured(_e: Node) -> void:
	kills += 1
	G.stat.emit("kills", 1)


## The most coins the Curse's belly holds right now (it grows with the Curse Level).
func belly_cap() -> int:
	return Curse.belly_cap(self)


func boss_killed(b: Node) -> void:
	kills += 1
	var id: String = b.boss_id
	bosses_beaten.append(id)
	boss = null
	G.stat.emit("kills", 1)
	G.stat.emit("boss_killed", 1)
	G.stat.emit("boss_killed:" + id, 1)
	G.boss_defeated.emit(id)
	gain_xp(Rpg.xp_of_boss(scale_floor))
	var says: Dictionary = Story.BOSS_SAYS.get(id, {})
	if says.has("end"):
		G.toast.emit(String(Bosses.info(id).get("name", "")), "\"%s\"" % String(says["end"]))
	Sfx.music(String(theme.get("music", "")))
	# the run is won when the final boss falls (the row's "final"), or whatever boss guards the last floor
	if not level.is_empty():
		_level_done()
		return
	if floor_index >= floor_count - 1 or Bosses.info(id).get("final", false):
		victory = true
		over = true
		_end_t = 2.6
		Sfx.play("victory_sting")


## Story: the level is cleared for good and what he carries is kept; the stair leads on, or it is over.
func _level_done() -> void:
	var gift := Story.clear(String(level["id"]), player.items)
	G.stat.emit("levels_cleared_live", 1)
	if gift != "":
		G.toast.emit("New weapon: " + String(Weapons.row(gift)["name"]), "Tam the Smith will fit it for you")
	if not has_next_level():
		victory = true
		over = true
		_end_t = 2.6
		Sfx.play("victory_sting")
	else:
		player.hp = mini(player.max_hp, player.hp + LEVEL_HEAL)
		G.hud_changed.emit()
		G.toast.emit("Seal shard taken" if level.has("boss") else "The way is clear", "The stair leads deeper" if level.has("boss") else "The path leads on")


func player_died(cause: String) -> void:
	if over:
		return
	over = true
	victory = false
	death_cause = cause if cause != "" else "the dark"
	_end_t = 1.4
	Sfx.play("death_sting")


func _finish() -> void:
	if victory and (level.is_empty() or bool(level.get("final", false))):
		G.stat.emit("wins", 1)
		G.stat.emit("wins:" + hero_id, 1)
		if curse_level <= 0:
			G.stat.emit("win_curse_0", 1)
		elif curse_level >= Curse.MAX_LEVEL:
			G.stat.emit("win_curse_5", 1)
	Save.flush()
	G.run_ended.emit(victory, summary())


## What the death / victory screen shows.
func summary() -> Dictionary:
	return {
		"victory": victory, "hero": hero_id, "floor": floor_index + 1, "floor_name": floor_name,
		"time_s": time_s, "kills": kills, "coins": player.coins_collected if player != null else 0,
		"items": player.items.duplicate() if player != null else [],
		"rooms_cleared": rooms_cleared, "secrets_found": secrets_found, "bosses": bosses_beaten.duplicate(),
		"damage_taken": player.damage_taken if player != null else 0, "cause": "" if victory else death_cause,
		"curse_level": curse_level, "level": String(level.get("id", "")), "level_name": String(level.get("name", "")), "side": String(level.get("side", "")), "final": bool(level.get("final", false)), "champion": String(level.get("champion", "")),
		"coins_held": player.coins if player != null else 0,
		"xp": xp_earned, "rpg_level": Rpg.level(),
	}


# =============================================================================== juice
## Screen shake. amount 0..1 (0.2 a tap, 0.5 a hit, 1.0 an explosion). It adds up and fades by itself.
func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## Freezes the action for a few frames on a big hit (never more than 0.08 s).
func hitstop(seconds: float) -> void:
	_hitstop = maxf(_hitstop, minf(seconds, HITSTOP_MAX))


## Slow motion for a dramatic beat (boss deaths). `seconds` is game time.
func slowmo(scale: float, seconds: float) -> void:
	if _slow_base <= 0.0:
		_slow_base = Engine.time_scale
	Engine.time_scale = _slow_base * scale
	_slow_left = seconds


func _physics_process(delta: float) -> void:
	if player == null:
		return
	# ---- slow motion and hit-stop
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0 and _slow_base > 0.0:
			Engine.time_scale = _slow_base
			_slow_base = 0.0
	if _hitstop > 0.0:
		_hitstop -= delta
		world.process_mode = Node.PROCESS_MODE_DISABLED
	elif world.process_mode != Node.PROCESS_MODE_INHERIT:
		world.process_mode = Node.PROCESS_MODE_INHERIT
	# ---- the training yard: the dummy stands, sparring monsters come back
	if training and not over and is_instance_valid(room):
		_spar_t -= delta
		if _spar_t <= 0.0:
			_spar_t = 1.5
			var dummy := false
			var live := 0
			for e in room.enemies:
				if is_instance_valid(e) and not e.dead:
					if String(e.id) == "training_dummy":
						dummy = true
					else:
						live += 1
			if not dummy:
				room.spawn_enemy("training_dummy", G.ROOM_CENTER + Vector2(-70, -10), {"delay": 0.2})
			if live < 2:
				var who: String = SPARRING[randi() % SPARRING.size()]
				room.spawn_enemy(who, G.ROOM_CENTER + Vector2(randf_range(40, 110), randf_range(-36, 36)), {"delay": 0.6, "minion": true})
	# ---- room and floor changes
	if _has_pending:
		_has_pending = false
		var door: Dictionary = rooms[cur]["doors"].get(_pending_dir, {})
		if not door.is_empty():
			_enter_room(door["to"], _pending_dir)
	if _floor_change > 0.0:
		_floor_change -= delta
		_fade_alpha = clampf(1.0 - _floor_change / 0.4, 0.0, 1.0)
		if _floor_change <= 0.0:
			_floor_change = 0.0
			if level.is_empty():
				floor_index += 1
			else:
				level = Story.after(String(level["id"]))        # the descent goes on with the next level
				floor_index = clampi(int(level.get("floor", 1)) - 1, 0, floor_count - 1)
			_start_floor()
	else:
		_fade_alpha = maxf(0.0, _fade_alpha - delta / ROOM_FADE)
	_fade.color.a = _fade_alpha
	_slide = _slide.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))
	# ---- camera
	_trauma = maxf(0.0, _trauma - delta * 1.7)
	var s := _trauma * _trauma * SHAKE_PIXELS
	camera.position = G.CAMERA_CENTER - _slide + Vector2(randf_range(-s, s), randf_range(-s, s))
	# ---- the CALL button's cooldown
	call_cd = maxf(0.0, call_cd - delta)
	call_fill = 1.0 - clampf(call_cd / maxf(player.stats.v("call_cooldown"), 0.01), 0.0, 1.0)
	call_ready = room != null and room.curse != null and room.curse.can_call()
	# ---- the clock, the end of the run
	if not over:
		time_s += delta
	elif _end_t > 0.0:
		_end_t -= delta
		if _end_t <= 0.0:
			_finish()
	# ---- screenshots for tests
	if room != null and room.fighting and not _fight_shot_done and room.fight_time >= 1.5:
		_fight_shot_done = true
		if G.flag("shots"):
			var key := "floor%d_%s" % [floor_index + 1, TYPE_NAMES[room.type]]
			G.save_shot("%s_%d_fight.png" % [key, int(_shot_counts.get(key, 1))])
	for i in range(_shot_queue.size() - 1, -1, -1):
		_shot_queue[i][0] -= delta
		if _shot_queue[i][0] <= 0.0:
			G.save_shot(_shot_queue[i][1])
			_shot_queue.remove_at(i)
	if _shot_every > 0.0:
		_shot_every_t -= delta
		if _shot_every_t <= 0.0:
			_shot_every_t = _shot_every
			G.save_shot("t_%06.1f.png" % time_s)
