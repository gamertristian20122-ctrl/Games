extends Node2D
## Fake run (testing only): stands in for the real game so the menus, HUD and touch controls
## can be built and photographed without it. It has exactly the fields scripts/core/g.gd
## promises (hero_id, rooms, player, boss, summary() ...) and sends the same signals.
## Used by the UI tour (--uitour) and by --fakerun, never in the real game.
## With --fakerun you can walk around (WASD / stick) and press number keys:
##   1 hurt   2 heal   3 item   4 cursed item   5 boss   6 coin   7 toast   8 next room   9 die   0 win

const Heroes = preload("res://scripts/data/heroes.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const Items = preload("res://scripts/data/items.gd")
const RoomLook = preload("res://scripts/run/room_look.gd")
const SET := "crypt"


class FakePlayer extends Node2D:
	var hp := 6
	var max_hp := 6
	var armor := 0
	var coins := 0
	var keys := 0
	var bombs := 1
	var items: Array[String] = []
	var familiars: Array = []


class FakeBoss extends Node2D:
	var display_name := "Warden of the Test Room"
	var hp := 100.0
	var max_hp := 100.0


var hero_id := "knight"
var floor_index := 0
var floor_name := "The Upper Vaults"
var floor_count := 3
var time_s := 0.0
var kills := 0
var cur := Vector2i.ZERO
var rooms := {}
var player: FakePlayer
var boss: Node = null
var _seed := 0
var _sprite: AnimatedSprite2D
var _over := false
var _coins_total := 0


func setup(hero: String, seed_value: int) -> void:
	hero_id = hero
	_seed = seed_value
	G.run = self
	_build_room()
	var cam := Camera2D.new()
	cam.position = G.CAMERA_CENTER
	add_child(cam)
	cam.make_current()
	var h := Heroes.by_id(hero)
	player = FakePlayer.new()
	player.hp = int(h["hp"])
	player.max_hp = int(h["hp"])
	player.armor = int(h["armor"])
	player.position = G.ROOM_CENTER + Vector2(0, 20)
	add_child(player)
	_sprite = Art.sprite(String(h["sprite"]))
	player.add_child(_sprite)
	var held := HeroLook.make_weapon(h)          # carried at the side, like in a real run
	player.add_child(held)
	HeroLook.rest(held, 1.0)
	_make_map()
	Controls.bomb_pressed.connect(_on_bomb)
	G.run_started.emit(self)
	G.floor_started.emit(floor_index, floor_name)
	G.hud_changed.emit()


func _exit_tree() -> void:
	if G.run == self:
		G.run = null


func summary() -> Dictionary:
	return {
		"victory": false, "hero": hero_id, "floor": floor_index + 1, "floor_name": floor_name,
		"time_s": time_s, "kills": kills, "coins": _coins_total, "items": player.items.duplicate(),
		"rooms_cleared": 7, "secrets_found": 1, "bosses": 0, "damage_taken": 9, "cause": "a goblin",
	}


# ------------------------------------------------------------------ things the tour can do
func set_health(hp: int, max_hp: int, armor: int) -> void:
	player.hp = hp
	player.max_hp = max_hp
	player.armor = armor
	G.hud_changed.emit()


func give_item(id: String) -> void:
	player.items.append(id)
	G.item_acquired.emit(id)
	G.hud_changed.emit()


func add_coins(n: int) -> void:
	player.coins += n
	_coins_total += n
	G.pickup_collected.emit("coin", n)
	G.hud_changed.emit()


func hurt(half_hearts: int = 1) -> void:
	if player.armor > 0:
		player.armor = maxi(player.armor - half_hearts, 0)
	else:
		player.hp = maxi(player.hp - half_hearts, 0)
	G.player_hurt.emit(half_hearts)
	G.hud_changed.emit()
	if player.hp <= 0:
		finish(false)


func start_boss() -> void:
	if boss != null:
		return
	var b := FakeBoss.new()
	b.position = G.ROOM_CENTER + Vector2(60, -10)
	var boss_sprite := Art.sprite("pc_zombie_muscle")      # like a real boss: a floor creature at double size
	boss_sprite.scale = Vector2(2, 2)
	b.add_child(boss_sprite)
	add_child(b)
	boss = b
	G.boss_started.emit(b)


func finish(victory: bool) -> void:
	if _over:
		return
	_over = true
	if not victory:
		G.player_died.emit()
	var s := summary()
	s["victory"] = victory
	if victory:
		s["bosses"] = 3
		s["cause"] = ""
	G.run_ended.emit(victory, s)


func enter_room(coord: Vector2i) -> void:
	if not rooms.has(coord):
		return
	cur = coord
	var first: bool = not rooms[coord]["visited"]
	rooms[coord]["visited"] = true
	for d: Vector2i in G.DIRS:
		if rooms.has(coord + d):
			rooms[coord + d]["seen"] = true
	G.room_entered.emit(coord, rooms[coord]["type"], first)
	G.hud_changed.emit()


# ------------------------------------------------------------------ the pretend world
func _make_map() -> void:
	var layout := {
		Vector2i(0, 0): G.RoomType.START, Vector2i(1, 0): G.RoomType.COMBAT, Vector2i(2, 0): G.RoomType.COMBAT,
		Vector2i(2, -1): G.RoomType.TREASURE, Vector2i(3, 0): G.RoomType.COMBAT, Vector2i(3, 1): G.RoomType.SHOP,
		Vector2i(4, 0): G.RoomType.BOSS, Vector2i(1, 1): G.RoomType.COMBAT, Vector2i(1, 2): G.RoomType.SECRET,
		Vector2i(0, 1): G.RoomType.ALTAR, Vector2i(-1, 0): G.RoomType.COMBAT,
	}
	rooms.clear()
	for c: Vector2i in layout:
		rooms[c] = {"type": layout[c], "visited": false, "seen": false, "cleared": false}
	enter_room(Vector2i(0, 0))


## Walks through most of the map so the minimap has something to show.
func explore() -> void:
	for c: Vector2i in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, -1), Vector2i(2, 0), Vector2i(3, 0)]:
		rooms[cur]["cleared"] = true
		enter_room(c)


## One picture of the crypt's Pixel Crawler tile set, through the same loader the real rooms use.
func _put(piece_name: String, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = RoomLook.piece(SET, piece_name)
	s.centered = false
	s.position = pos
	add_child(s)


## A still crypt room in the new look (cheap: plain sprites, no lights): walls, floor, the top door.
func _build_room() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for col in G.ROOM_COLS:
		var ab := "a" if col % 2 == 0 else "b"
		_put("wall_top_" + ab, Vector2(col * 16, -48))
		_put("wall_face_" + ab, Vector2(col * 16, -32))
		_put("wall_bottom_" + ab, Vector2(col * 16, G.ROOM_H))
		for row in G.ROOM_ROWS:
			var r := rng.randf()
			var pick := "floor_a" if r < 0.45 else "floor_" + "bcdefgh"[rng.randi_range(0, 6)]
			_put(pick, Vector2(col * 16, row * 16))
		_put("floor_shade_top", Vector2(col * 16, 0))
	_put("corner_tl", Vector2(-16, -48))
	_put("corner_tr", Vector2(G.ROOM_W, -48))
	_put("corner_bl", Vector2(-16, G.ROOM_H))
	_put("corner_br", Vector2(G.ROOM_W, G.ROOM_H))
	for y in range(-32, G.ROOM_H, 16):
		_put("wall_side_left", Vector2(-16, y))
		_put("wall_side_right", Vector2(G.ROOM_W, y))
	for col: int in [2, 5, 11, 14]:
		_put("deco_sconce_f0", Vector2(col * 16, -36))
	_put("door_n_frame", Vector2(G.DOOR_COL * 16 - 8, -48))
	_put("door_n_leaf", Vector2(G.DOOR_COL * 16 - 3, -44))
	_put("prop_urn_a", Vector2(3 * 16, 1 * 16 - 5))
	_put("floor_stone_a", Vector2(12 * 16 + 3, 5 * 16 + 4))


func _on_bomb() -> void:
	if player.bombs > 0 and not _over:
		player.bombs -= 1
		G.hud_changed.emit()


func _process(delta: float) -> void:
	if _over:
		return
	time_s += delta
	if G.flag("uitour"):
		return
	var v := Controls.move
	player.position = (player.position + v * 90.0 * delta).clamp(Vector2(8, 8), Vector2(G.ROOM_W - 8, G.ROOM_H))
	_sprite.play("run" if v.length() > 0.1 else "idle")
	if absf(v.x) > 0.1:
		_sprite.flip_h = v.x < 0.0
	if is_instance_valid(boss):
		boss.set("hp", maxf(float(boss.get("hp")) - delta * 6.0, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _over:
		return
	var ids: Array = Items.ALL.keys()
	match event.physical_keycode:
		KEY_1: hurt(1)
		KEY_2: set_health(mini(player.hp + 2, player.max_hp), player.max_hp, player.armor + 1)
		KEY_3:
			for id: String in ids:
				if not Items.ALL[id].get("cursed", false) and not player.items.has(id):
					give_item(id)
					break
		KEY_4:
			for id: String in ids:
				if Items.ALL[id].get("cursed", false):
					give_item(id)
					break
		KEY_5: start_boss()
		KEY_6:
			add_coins(7)
			kills += 3
		KEY_7: G.toast.emit("Secret found", "The wall gives way.")
		KEY_8:
			for d: Vector2i in G.DIRS:
				if rooms.has(cur + d) and not rooms[cur + d]["visited"]:
					rooms[cur]["cleared"] = true
					enter_room(cur + d)
					G.stat.emit("secret_found", 1)
					break
		KEY_9: finish(false)
		KEY_0: finish(true)
