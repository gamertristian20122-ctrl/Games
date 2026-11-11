extends Node2D
## Pedestal: a stone stand with something floating above it. Walk into it to take it.
## The same script is the SHOP STAND: give it a "price" and it shows a price tag and sells instead.
## desc: {"pos": Vector2, "item": item id  OR  "pickup": pickup id, "price": coins (0 = free), "taken": bool}
## Cursed items glow dark red-purple, and the first time you come close a banner warns you.
## They also wear a small badge, "+1" and a skull: taking one raises the Curse Level (the Hungry
## Curse grows). At Curse Level 2 the badge adds teeth: the next level makes its bite a full heart.
## Two more desc fields:
##   "pair": n        two pedestals with the same number are a choice: take one and the other crumbles
##   "service": "starve"   the shop's "Starve the Curse" stand: no goods, it takes one Curse Level
##                    off for coins (prices in scripts/data/pickups.gd). It only shows from Curse
##                    Level 1 and can be used again while its price list lasts.
## The stand is "prop_plinth": a stone column capital from the purchased Pixel Crawler Castle pack.
## The coin on the price tag is "prop_coin" and the skull on the Starve stand is "prop_skull_mark"
## (the golden skull): all three are cut by tools/import_props.py. The tiny skull in the "+1" badge
## stays the HUD's own skull, so the badge reads as "+1 on the Curse meter" at the top of the screen.

const Items = preload("res://scripts/data/items.gd")
const Pickups = preload("res://scripts/data/pickups.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const Curse = preload("res://scripts/entities/curse.gd")

const BLOCK_RADIUS := 7.0
const WARN_RANGE := 36.0
## Words the player sees (the Starve stand and the badges).
const STARVE_NAME := "Starve the Curse"
const STARVE_HINT := "One Curse Level less."
const STARVE_DONE := "Your Curse shrinks."
const BADGE_GROW := "+1"
const BADGE_SHRINK := "-1"
const BADGE_GROW_COLOR := Color(1.0, 0.62, 0.50)
const BADGE_SHRINK_COLOR := Color(0.66, 0.96, 0.62)
const CURSE_GOLD := Color(0.98, 0.90, 0.58)      ## the Hungry Curse's own pale gold
const STAND := "prop_plinth"
const STAND_TOP := 11.0          ## how far the top edge of the stand is above the spot it stands on
const COIN := "prop_coin"
const TAG_PLATE := Color(0.07, 0.06, 0.09, 0.72)     ## the dark plate behind a price
const SKULL := "prop_skull_mark"
const BADGE_SKULL := "skull"     ## the same small skull the HUD's Curse meter is made of

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
var service := ""
var pair := 0
var crumbled := false
var badge: Node2D
var _price_label: Label
var _away := true                ## the hero stepped away since the last purchase (service stands)
var _badge_level := -1
static var _skull_rect := Rect2()
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
	service = String(desc.get("service", ""))
	pair = int(desc.get("pair", 0))
	add_child(EnemyScript.make_shadow(18.0))
	var base := Sprite2D.new()
	base.texture = Art.tex(STAND)
	base.centered = false
	base.position = Vector2(-roundf(base.texture.get_size().x / 2.0), -STAND_TOP)
	add_child(base)
	var icon_id := SKULL
	var tint := Color(1, 1, 1)
	var glow_color := Color(1.0, 0.85, 0.45)
	if item != "":
		var info: Dictionary = Items.info(item)
		icon_id = String(info.get("icon", SKULL))
		cursed = info.get("cursed", false)
		if cursed:
			glow_color = Color(0.85, 0.12, 0.45)
	elif pickup != "":
		icon_id = Pickups.sprite_for(pickup)
		tint = Pickups.info(pickup).get("tint", Color(1, 1, 1))
		glow_color = Color(0.9, 0.9, 1.0)
	elif service != "":
		glow_color = CURSE_GOLD      # the golden skull is already the Curse's colour
		price = _service_price()
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
	_icon_y = -STAND_TOP - 2.0 - icon.texture.get_size().y * 0.5
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
	if cursed or service != "":
		_build_badge()
	_bob = randf() * 6.0
	if taken:
		_hide_goods()
	if service != "":
		_refresh_service()


func _build_tag() -> void:
	tag = Node2D.new()
	tag.position = Vector2(0, 12)
	tag.z_index = 1
	add_child(tag)
	tag.draw.connect(_draw_tag_plate)
	var coin := Sprite2D.new()
	coin.texture = Art.tex(COIN)
	coin.position = Vector2(-6, 0)
	tag.add_child(coin)
	var label := Label.new()
	label.text = str(price)
	label.add_theme_font_override("font", room.run.font())
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.08))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(1, -7)
	tag.add_child(label)
	_price_label = label


## A dark plate behind the coin and the number, so the price reads as a label on the stand and
## its coin is never taken for a coin lying on the floor. A flat shape with its corners cut.
func _draw_tag_plate() -> void:
	var w := 18.0 + 5.0 * str(price).length()
	var r := Rect2(-13, -7, w, 14)
	tag.draw_rect(r.grow_individual(-1, 0, -1, 0), TAG_PLATE)
	tag.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), TAG_PLATE)
	tag.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), TAG_PLATE)


## The small "+1 skull" (or "-1 skull") under a cursed item or the Starve stand.
func _build_badge() -> void:
	if _skull_rect.size == Vector2.ZERO:
		var img := Art.tex(BADGE_SKULL).get_image()
		_skull_rect = Rect2(img.get_used_rect()) if img != null else Rect2(0, 0, 16, 16)
	badge = Node2D.new()
	badge.position = Vector2(0, 23 if price > 0 else 11)
	badge.z_index = 1
	add_child(badge)
	badge.draw.connect(_draw_badge)


func _draw_badge() -> void:
	var run: Node = room.run
	var font: Font = run.font()
	var grow := service == ""
	var text := BADGE_GROW if grow else BADGE_SHRINK
	# the teeth warning: taking this item makes the Curse's bite a full heart
	var teeth: bool = grow and run.curse_level == Curse.TEETH_LEVEL - 1
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var total := w + 1.0 + _skull_rect.size.x + (11.0 if teeth else 0.0)
	var x := -roundf(total / 2.0)
	badge.draw_string_outline(font, Vector2(x, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.08, 0.06, 0.08))
	badge.draw_string(font, Vector2(x, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BADGE_GROW_COLOR if grow else BADGE_SHRINK_COLOR)
	x += w + 1.0
	badge.draw_texture_rect_region(Art.tex(BADGE_SKULL), Rect2(Vector2(x, 3.0 - _skull_rect.size.y), _skull_rect.size), _skull_rect)
	x += _skull_rect.size.x + 2.0
	if teeth:
		badge.draw_rect(Rect2(x - 1, -4, 11, 6), Color(0.08, 0.06, 0.08))
		for k in 3:
			badge.draw_rect(Rect2(x + k * 3, -3, 3, 1), CURSE_GOLD)
			badge.draw_rect(Rect2(x + k * 3 + 1, -2, 1, 2), CURSE_GOLD)


# ------------------------------------------------------------------ the "Starve the Curse" stand
func _service_price() -> int:
	var prices: Array = Pickups.PRICE_STARVE
	return int(prices[clampi(room.run.starve_bought, 0, prices.size() - 1)])


## Open from Curse Level 1, until every price on the list has been paid in this run.
func _service_open() -> bool:
	return room.run.curse_level >= 1 and room.run.starve_bought < (Pickups.PRICE_STARVE as Array).size()


func _refresh_service() -> void:
	var open := _service_open()
	visible = open
	solid = open
	price = _service_price()
	if _price_label != null:
		_price_label.text = str(price)
		tag.queue_redraw()


func _use_service(player: Node) -> void:
	if not _away:
		return
	if not player.spend_coins(price):
		_deny(true)
		return
	_away = false
	room.run.starve_bought += 1
	Curse.change_level(room.run, -1)
	G.stat.emit("shop_buy", 1)
	G.stat.emit("curse_starved", 1)
	Sfx.play("shop_buy")
	Sfx.play("curse_whisper", -5.0, 0.03, 1.7)
	G.toast.emit(STARVE_DONE, "")
	room.run.fx.burst(position + Vector2(0, _icon_y), [CURSE_GOLD, Color(1, 1, 0.9)], 12, 60.0, 0.45, 2.0)
	room.run.fx.ring(position + Vector2(0, _icon_y), 12.0, 3.0, 0.35, CURSE_GOLD, 1.5)
	_refresh_service()


## The other half of a pair was taken: this one falls to rubble and is gone for good.
func crumble() -> void:
	if taken or crumbled:
		return
	crumbled = true
	taken = true
	room.run.fx.burst(position - Vector2(0, 4), Art.palette(STAND), 16, 70.0, 0.55, 2.6)
	room.run.fx.burst(position + Vector2(0, _icon_y), [Color(0.5, 0.45, 0.5), Color(0.25, 0.22, 0.25)], 8, 50.0, 0.4, 2.0)
	Sfx.play("rock_break", -5.0)
	room.remove_thing(self)


func save() -> Dictionary:
	if crumbled:
		return {}
	return {"kind": "pedestal", "pos": position, "item": item, "pickup": pickup, "price": price, "taken": taken, "warned": warned,
		"service": service, "pair": pair}


func _hide_goods() -> void:
	icon.visible = false
	glow.visible = false
	if light != null:
		light.visible = false
	if tag != null:
		tag.visible = false
	if badge != null:
		badge.visible = false


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
	if badge != null and _badge_level != room.run.curse_level:
		_badge_level = room.run.curse_level
		badge.queue_redraw()
		if service != "":
			_refresh_service()
	var player: Node = room.run.player
	if player == null or player.dead:
		return
	var d: Vector2 = player.position - position
	var dist := d.length()
	if service != "":
		if not visible:
			return
		if not warned and dist < WARN_RANGE:
			warned = true
			G.toast.emit(STARVE_NAME, STARVE_HINT)
		if dist > BLOCK_RADIUS + player.radius + 5.0:
			_away = true
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
	if service != "":
		_use_service(player)
		return
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
	if pair != 0:
		# a choice of two: the one left behind crumbles
		for other in room.things.duplicate():
			if other != self and is_instance_valid(other) and other.kind == "pedestal" and other.pair == pair:
				other.crumble()
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
