extends Node2D
## Pedestal: a stone stand with something floating above it. Walk into it to take it.
## The same script is the SHOP STAND: give it a "price" and it shows a price tag and sells instead.
## desc: {"pos": Vector2, "item": item id  OR  "pickup": pickup id, "price": coins (0 = free), "taken": bool}
## Cursed items glow dark red-purple, and the first time you come close a banner warns you.
## STAND-IN: the pack has no pedestal picture; the stand is the cap of the pack's column sprite.

const Items = preload("res://scripts/data/items.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const BLOCK_RADIUS := 7.0
const WARN_RANGE := 36.0

var kind := "pedestal"
var solid := true
var room: Node
var item := ""
var pickup := ""
var price := 0
var taken := false
var warned := false
var cursed := false
var icon: Sprite2D
var glow: Sprite2D
var light: PointLight2D
var tag: Node2D
var _bob := 0.0
var _deny_cd := 0.0
var _shake := 0.0
var _icon_y := 0.0


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	item = String(desc.get("item", ""))
	pickup = String(desc.get("pickup", ""))
	price = int(desc.get("price", 0))
	taken = desc.get("taken", false)
	warned = desc.get("warned", false)
	add_child(EnemyScript.make_shadow(18.0))
	var base := Sprite2D.new()
	base.texture = Art.tex("column")
	base.region_enabled = true
	base.region_rect = Rect2(0, 4, 16, 11)
	base.centered = false
	base.position = Vector2(-8, -7)
	add_child(base)
	var icon_id := "skull"
	var tint := Color(1, 1, 1)
	var glow_color := Color(1.0, 0.85, 0.45)
	if item != "":
		var info: Dictionary = Items.info(item)
		icon_id = String(info.get("icon", "skull"))
		cursed = info.get("cursed", false)
		if cursed:
			glow_color = Color(0.85, 0.12, 0.45)
	elif pickup != "":
		icon_id = Pickups.sprite_for(pickup)
		tint = Pickups.info(pickup).get("tint", Color(1, 1, 1))
		glow_color = Color(0.9, 0.9, 1.0)
	glow = Sprite2D.new()
	glow.texture = room.run.light_tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = mat
	glow.modulate = glow_color
	glow.scale = Vector2(0.5, 0.5)
	add_child(glow)
	icon = Sprite2D.new()
	icon.texture = Art.tex(icon_id)
	icon.modulate = tint
	add_child(icon)
	_icon_y = -10.0 - icon.texture.get_size().y * 0.5
	glow.position = Vector2(0, _icon_y)
	if room.run.LIGHTING:
		light = PointLight2D.new()
		light.texture = room.run.light_tex
		light.texture_scale = 0.9
		light.energy = 0.6
		light.color = glow_color
		light.position = Vector2(0, -8)
		add_child(light)
	if price > 0:
		_build_tag()
	_bob = randf() * 6.0
	if taken:
		_hide_goods()


func _build_tag() -> void:
	tag = Node2D.new()
	tag.position = Vector2(0, 10)
	tag.z_index = 1
	add_child(tag)
	var coin := Sprite2D.new()
	coin.texture = Art.tex("coin")
	coin.position = Vector2(-5, 0)
	tag.add_child(coin)
	var label := Label.new()
	label.text = str(price)
	label.add_theme_font_override("font", room.run.font())
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.08))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-1, -7)
	tag.add_child(label)


func save() -> Dictionary:
	return {"kind": "pedestal", "pos": position, "item": item, "pickup": pickup, "price": price, "taken": taken, "warned": warned}


func _hide_goods() -> void:
	icon.visible = false
	glow.visible = false
	if light != null:
		light.visible = false
	if tag != null:
		tag.visible = false


func _physics_process(delta: float) -> void:
	_bob += delta
	_deny_cd = maxf(0.0, _deny_cd - delta)
	if not taken:
		icon.position = Vector2(0, _icon_y + sin(_bob * 2.6) * 1.5)
		var pulse := 0.5 + 0.5 * sin(_bob * (5.0 if cursed else 3.0))
		glow.scale = Vector2(0.42, 0.42) * (1.0 + 0.15 * pulse)
		glow.modulate.a = 0.55 + 0.3 * pulse
	if tag != null and _shake > 0.0:
		_shake -= delta
		tag.position.x = sin(_shake * 70.0) * 2.0 if _shake > 0.0 else 0.0
	var player: Node = room.run.player
	if player == null or player.dead:
		return
	var d: Vector2 = player.position - position
	var dist := d.length()
	if cursed and not taken and not warned and dist < WARN_RANGE:
		warned = true
		var info: Dictionary = Items.info(item)
		G.toast.emit("Cursed: " + String(info.get("name", item)), String(info.get("curse", "")))
		Sfx.play("curse_whisper", -4.0)
	var reach: float = BLOCK_RADIUS + player.radius
	if dist < reach:
		player.position = position + (d / dist if dist > 0.1 else Vector2.DOWN) * reach
		if not taken:
			_touched(player)


func _touched(player: Node) -> void:
	if pickup != "" and not player.wants(String(Pickups.info(pickup).get("need", ""))):
		_deny(false)
		return
	if price > 0:
		if not player.spend_coins(price):
			_deny(true)
			return
		G.stat.emit("shop_buy", 1)
		Sfx.play("shop_buy")
	taken = true
	_hide_goods()
	if item != "":
		player.add_item(item)
	elif pickup != "":
		var info: Dictionary = Pickups.info(pickup)
		player.give(info.get("give", {}))
		G.pickup_collected.emit(String(info.get("kind", "coin")), 1)
		Sfx.play(String(info.get("sfx", "coin_pickup")), -6.0)
	room.run.fx.burst(position + Vector2(0, _icon_y), [Color(1, 1, 0.8), Color(1, 0.9, 0.4)], 10, 60.0, 0.4, 2.0)


func _deny(sound: bool) -> void:
	if _deny_cd > 0.0:
		return
	_deny_cd = 0.8
	_shake = 0.3
	if sound:
		Sfx.play("shop_deny")
