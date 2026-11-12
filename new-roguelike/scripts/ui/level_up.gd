extends "res://scripts/ui/screen.gd"
## Level up: the knight reached a new level. It says what he gained by himself and offers three
## cards; the player takes one (scripts/data/rpg.gd). main.gd opens it when a card is waiting and
## no fight is on, so it never covers a fight. If more than one level was gained, it asks again.
## There is no way out without choosing: Back only reminds the player to pick.

const Rpg = preload("res://scripts/data/rpg.gd")
const Looks = preload("res://scripts/data/looks.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const CARD_W := 96.0
const CARD_H := 100.0
const LOCK := 0.55               ## seconds the cards ignore taps, so a thumb still fighting picks nothing

var _hint: Label
var _cards: Array = []
var _lock := LOCK
var _root_box: Control


func build() -> void:
	_fill()


func _fill() -> void:
	if is_instance_valid(_root_box):
		_root_box.queue_free()
	_cards.clear()
	_lock = LOCK
	var safe := UI.safe_margin(self, 6)
	_root_box = safe
	add_child(safe)
	var col := UI.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var lvl := Rpg.level() - Rpg.picks() + 1          # the level this choice belongs to
	var head := UI.label("Level %d" % lvl, "Head")
	head.add_theme_color_override("font_color", UI.C_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var grow := UI.label("%s grows stronger: %s" % [Looks.hero_name(), Rpg.growth_text(lvl)], "Small")
	grow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(grow)
	var row := UI.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var ids := Rpg.offer()
	for id: String in ids:
		var b := _card(id)
		row.add_child(b)
		_cards.append(b)
	if ids.is_empty():
		# every card is full: the level pays coins instead
		var b := UI.button("Every card is full: take %d coins for the camp chest" % Rpg.FULL_COINS, func() -> void:
			if _lock > 0.0:
				return
			Rpg.pick_coins()
			_after())
		b.custom_minimum_size = Vector2(220, 30)
		row.add_child(b)
		_cards.append(b)
	_hint = UI.label("Choose one. It is yours for good.", "Small")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", UI.C_DIM)
	col.add_child(_hint)
	default_focus = _cards[0]
	_focus_default.call_deferred()
	UI.pop_in(col)


func _card(id: String) -> Button:
	var r := Rpg.row(id)
	var b := Button.new()
	b.name = "Card_" + id
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_ALL
	UI.juice(b)
	var box := UI.vbox(1)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_right = -4
	box.offset_top = 5
	box.offset_bottom = -4
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var slot := CenterContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(0, 34)
	box.add_child(slot)
	var ic := Icon.new()
	ic.setup(String(r.get("icon", "icon_whetstone")), Vector2(32, 32), 0.0, 2.0)
	slot.add_child(ic)
	var name_label := UI.label(String(r["name"]), "Gold")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var text := UI.label(String(r["text"]), "Small", CARD_W - 10.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var have := UI.label("taken %d of %d" % [Rpg.taken(id), int(r["max"])], "Small")
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	have.add_theme_color_override("font_color", UI.C_FAINT)
	box.add_child(have)
	b.pressed.connect(_take.bind(id))
	return b


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta


func _take(id: String) -> void:
	if _lock > 0.0:
		return
	if not Rpg.pick(id):
		return
	Sfx.play("ui_start")
	_after()


func _after() -> void:
	if Rpg.picks() > 0:
		_fill()                   # more than one level was gained: the next choice
	else:
		send("levelup_done")


func on_back() -> void:
	Sfx.play("ui_back")
	if is_instance_valid(_hint):
		_hint.text = "Pick one of the cards to carry on."
		_hint.add_theme_color_override("font_color", UI.C_GOLD)
