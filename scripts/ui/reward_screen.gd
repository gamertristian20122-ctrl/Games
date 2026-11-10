class_name RewardScreen
extends Control
## The "pick one of three" screen shown when a chest is opened.
## Works with keyboard (A/D or arrows, then Space/Enter), mouse (point and
## click) and controller (stick or d-pad, then A).

signal chosen(id: String)

const CARD_SIZE := Vector2(144, 156)
const CARD_Y := 62.0
const INPUT_DELAY := 0.35      # ignore presses for a moment so nothing is picked by accident

var _offers: Array[String] = []
var _cards: Array[Control] = []
var _selected := 0
var _open_time := 0.0
var _title: Label
var _footer: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(Pal.INK, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_title = UiKit.label("CHOOSE A KEEPSAKE", 16, Pal.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 34)
	_title.size = Vector2(480, 18)
	add_child(_title)
	_footer = UiKit.label("", 8, Pal.DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.position = Vector2(0, 232)
	_footer.size = Vector2(480, 10)
	add_child(_footer)
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_footer())


func open(offers: Array[String], boss_reward: bool) -> void:
	_offers = offers
	_selected = mini(1, offers.size() - 1)
	_open_time = 0.0
	_title.text = "THE BOSS LEFT SOMETHING BEHIND" if boss_reward else "CHOOSE A KEEPSAKE"
	for card: Control in _cards:
		card.queue_free()
	_cards.clear()
	var gap := 12.0
	var total := offers.size() * CARD_SIZE.x + (offers.size() - 1) * gap
	var x := (480.0 - total) / 2.0
	for i in offers.size():
		var card := _make_card(offers[i], i)
		card.position = Vector2(x + i * (CARD_SIZE.x + gap), CARD_Y)
		add_child(card)
		_cards.append(card)
	_refresh_footer()
	_refresh_selection()
	visible = true


func _refresh_footer() -> void:
	_footer.text = "Left stick: choose     A: take" if Controls.using_pad \
			else "A / D or mouse: choose     Space or click: take"


func _make_card(id: String, index: int) -> Control:
	var item := ItemDB.get_item(id)
	var treat := ItemDB.is_treat(id)
	var tint: Color = Pal.GOOD if treat else Pal.RARITY[int(item.get("rarity", 0))]

	var card := Control.new()
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func() -> void: _select(index))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(index)
			_take())

	var back := UiKit.panel(Pal.INK_SOFT, Pal.FAINT)
	back.name = "Back"
	back.size = CARD_SIZE
	card.add_child(back)

	var picture := UiKit.icon(item["icon"], tint, 2.0)
	picture.position = Vector2((CARD_SIZE.x - 32) / 2.0, 8)
	card.add_child(picture)

	var name_label := UiKit.label(String(item["name"]).to_upper(), 8, tint, UiKit.FONT_SQUARE_PATH)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(4, 44)
	name_label.size = Vector2(CARD_SIZE.x - 8, 10)
	card.add_child(name_label)

	var kind := "Meal" if treat else "%s  -  %s" % [ItemDB.RARITY_NAMES[int(item["rarity"])], String(item["family"]).capitalize()]
	var kind_label := UiKit.label(kind, 8, Pal.DIM)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label.position = Vector2(4, 55)
	kind_label.size = Vector2(CARD_SIZE.x - 8, 10)
	card.add_child(kind_label)

	var text := UiKit.label(item["text"], 8, Pal.PAPER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(8, 70)
	text.size = Vector2(CARD_SIZE.x - 16, 40)
	card.add_child(text)

	if not treat:
		var held := int(Game.items.get(id, 0))
		var held_text := "New" if held == 0 else "You hold %d of %d" % [held, int(item["max"])]
		var held_label := UiKit.label(held_text, 8, Pal.DIM)
		held_label.position = Vector2(8, 112)
		held_label.size = Vector2(CARD_SIZE.x - 16, 10)
		card.add_child(held_label)

		# Combo line: gold if taking this finishes a combo, quiet hint otherwise.
		var finished := ItemDB.combos_completed_by(id, Game.items)
		var combo_label := UiKit.label("", 8, Pal.GOLD)
		combo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		combo_label.position = Vector2(8, 123)
		combo_label.size = Vector2(CARD_SIZE.x - 16, 30)
		if not finished.is_empty():
			var combo: Dictionary = ItemDB.COMBOS[finished[0]]
			combo_label.text = "COMBO! %s: %s" % [combo["name"], combo["text"]]
		else:
			var partners: Array[String] = []
			for combo_id: String in ItemDB.combos_with(id):
				if Game.stats.combos.has(combo_id):
					continue
				for need: String in ItemDB.COMBOS[combo_id]["needs"]:
					if need != id and not partners.has(ItemDB.ITEMS[need]["name"]):
						partners.append(ItemDB.ITEMS[need]["name"])
			if not partners.is_empty():
				combo_label.text = "Pairs with " + ", ".join(partners)
				combo_label.add_theme_color_override("font_color", Pal.DIM)
		card.add_child(combo_label)
	return card


func _process(delta: float) -> void:
	if visible:
		_open_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_select(maxi(_selected - 1, 0))
		Sfx.play("ui_move")
	elif event.is_action_pressed("ui_right"):
		_select(mini(_selected + 1, _offers.size() - 1))
		Sfx.play("ui_move")
	elif event.is_action_pressed("ui_accept"):
		_take()
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_refresh_selection()


func _refresh_selection() -> void:
	for i in _cards.size():
		var on := i == _selected
		var back := _cards[i].get_node("Back") as Panel
		back.add_theme_stylebox_override("panel", UiKit.box(Pal.INK_SOFT, Pal.GOLD if on else Pal.FAINT, 2 if on else 1))
		_cards[i].position.y = CARD_Y - (5.0 if on else 0.0)
		_cards[i].modulate = Color.WHITE if on else Color(0.75, 0.75, 0.8)


func _take() -> void:
	if _open_time < INPUT_DELAY or _offers.is_empty():
		return
	visible = false
	Sfx.play("ui_ok")
	chosen.emit(_offers[_selected])
