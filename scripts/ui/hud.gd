class_name Hud
extends Control
## The strip along the top of the screen: hearts, dashes, where you are,
## the items you hold, plus pop-up banners and the boss's health bar.

const MAX_ICONS_WIDTH := 176.0

var _hearts: Array[TextureRect] = []
var _dash_pips: Array[ColorRect] = []
var _place: Label
var _unison: Label
var _items_box: Control
var _banner_title: Label
var _banner_text: Label
var _banner_time := 0.0
var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _boss: Enemy = null
var _keeper: Player = null
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in Game.HP_CAP:
		var heart := UiKit.icon(Sprites.HEART_FULL, Pal.HEART)
		heart.position = Vector2(5 + i * 13, 2)
		add_child(heart)
		_hearts.append(heart)

	for i in 4:
		var pip := ColorRect.new()
		pip.size = Vector2(9, 3)
		pip.position = Vector2(7 + i * 12, 21)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		_dash_pips.append(pip)

	_unison = UiKit.label("UNISON", 8, Pal.ECHO)
	_unison.position = Vector2(60, 17)
	_unison.visible = false
	add_child(_unison)

	_place = UiKit.label("", 8, Pal.DIM)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.position = Vector2(140, 3)
	_place.size = Vector2(200, 10)
	add_child(_place)

	_items_box = Control.new()
	_items_box.position = Vector2(298, 6)
	_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items_box)

	_banner_title = UiKit.label("", 16, Pal.PAPER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.position = Vector2(0, 70)
	_banner_title.size = Vector2(480, 18)
	_banner_title.modulate.a = 0.0
	add_child(_banner_title)
	_banner_text = UiKit.label("", 8, Pal.DIM)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.position = Vector2(40, 90)
	_banner_text.size = Vector2(400, 10)
	_banner_text.modulate.a = 0.0
	add_child(_banner_text)

	_hint = UiKit.label("", 8, Pal.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 232)
	_hint.size = Vector2(480, 10)
	add_child(_hint)

	# Boss bar, drawn over the bottom wall.
	_boss_box = Control.new()
	_boss_box.position = Vector2(90, 257)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_box)
	var back := ColorRect.new()
	back.color = Pal.INK
	back.size = Vector2(300, 9)
	_boss_box.add_child(back)
	var rim := UiKit.panel(Color(0, 0, 0, 0), Pal.DANGER)
	rim.size = Vector2(300, 9)
	_boss_box.add_child(rim)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Pal.DANGER
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(296, 5)
	_boss_box.add_child(_boss_fill)
	_boss_name = UiKit.label("", 8, Pal.PAPER)
	_boss_name.position = Vector2(0, -11)
	_boss_name.size = Vector2(300, 10)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)

	Game.hp_changed.connect(_refresh_hearts)
	Game.items_changed.connect(_refresh_items)
	_refresh_hearts()
	_refresh_items()


func set_keeper(keeper: Player) -> void:
	_keeper = keeper


func set_place(floor_name: String, room_number: int, rooms_total: int, boss: bool) -> void:
	_place.text = "%s   %s" % [floor_name.to_upper(), "BOSS" if boss else "%d / %d" % [room_number, rooms_total]]


func show_hint(text: String) -> void:
	_hint.text = text


## Shows big words in the middle of the screen for a moment.
func banner(title: String, text: String = "", color: Color = Pal.PAPER, seconds: float = 2.4) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_text.text = text
	_banner_time = seconds


func watch_boss(boss: Enemy) -> void:
	_boss = boss
	_boss_box.visible = boss != null
	if boss != null:
		_boss_name.text = boss.display_name.to_upper()


func _process(delta: float) -> void:
	# Banner fades in and out.
	_banner_time = maxf(_banner_time - delta, 0.0)
	var want := 1.0 if _banner_time > 0.4 else _banner_time / 0.4
	_banner_title.modulate.a = move_toward(_banner_title.modulate.a, want, delta * 4.0)
	_banner_text.modulate.a = _banner_title.modulate.a

	if _boss != null:
		if is_instance_valid(_boss) and not _boss.dead:
			_boss_fill.size.x = 296.0 * clampf(_boss.hp / _boss.max_hp, 0.0, 1.0)
		else:
			watch_boss(null)

	if _keeper != null and is_instance_valid(_keeper):
		var total := Game.stats.dash_charges
		var ready := _keeper.dash_charges()
		for i in _dash_pips.size():
			_dash_pips[i].visible = i < total
			_dash_pips[i].color = Pal.PAPER if i < ready else Pal.FAINT
		_unison.visible = _keeper.in_unison and _keeper.active
		_unison.position.x = 9 + mini(total, 4) * 12


func _refresh_hearts() -> void:
	for i in _hearts.size():
		_hearts[i].visible = i < Game.max_hp
		var full := i < Game.hp
		_hearts[i].texture = Sprites.atlas(Sprites.HEART_FULL if full else Sprites.HEART_EMPTY)
		_hearts[i].modulate = Pal.HEART if full else Pal.FAINT


func _refresh_items() -> void:
	for child: Node in _items_box.get_children():
		child.queue_free()
	var count := Game.item_order.size()
	if count == 0:
		return
	var step := minf(16.0, MAX_ICONS_WIDTH / float(count))
	for i in count:
		var id := Game.item_order[i]
		var item: Dictionary = ItemDB.ITEMS[id]
		var picture := UiKit.icon(item["icon"], Pal.RARITY[int(item["rarity"])])
		picture.position = Vector2(MAX_ICONS_WIDTH - (count - i) * step, 0)
		_items_box.add_child(picture)
		var stacks := int(Game.items.get(id, 0))
		if stacks > 1:
			var number := UiKit.label(str(stacks), 8, Pal.PAPER)
			number.position = picture.position + Vector2(10, 9)
			_items_box.add_child(number)
