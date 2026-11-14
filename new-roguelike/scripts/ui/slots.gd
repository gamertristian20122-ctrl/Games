extends "res://scripts/ui/screen.gd"
## Slots: the three saved games (scripts/core/save.gd), each on a glass card: the chapter, the
## knight's level, where he is, how long it was played, when it was saved last.
## Opened from the title:  Load  (mode "load")  and  New Game  when all three slots are taken
## (mode "new": pick the slot the new game goes into).
##   a card            load: go on with that game  /  an empty card: start a new game there
##                     new:  start a new game there (asks first when a game is in it)
##   the row under it  Continue, New Game, Copy, Erase: they act on the card that is marked.
##                     A row that cannot act says why in the line below (never a dead button).
## It only SENDS: ("continue", slot) and ("new_game", slot); main.gd does the rest.
## Every word on the screen is in WORDS (placeholders the owner may rewrite).

const QuestList = preload("res://scripts/ui/quest_list.gd")
const VEIL_GAIN := 2.4

const WORDS := {
	"load": "Load a game", "new": "New game: choose a slot",
	"slot": "Slot %d", "empty": "Empty", "empty_hint": "A new game can start here.",
	"level": "Lv %d", "coins": "%d coins", "played": "Played %s", "last": "Played last",
	"continue": "Continue", "new_game": "New Game", "copy": "Copy", "erase": "Erase",
	"hint_load": "Choose a game to go on with.",
	"hint_new": "All three slots hold a game. Choose the one the new game replaces.",
	"hint_copy": "Copy slot %d: choose the slot it goes into.",
	"why_empty": "Slot %d is empty.",
	"why_same": "That is the slot being copied. Choose another, or go back.",
	"ask_new": "Start a new game in slot %d? The game in it is lost.",
	"ask_copy": "Copy slot %d over slot %d? The game in slot %d is lost.",
	"ask_erase": "Erase the game in slot %d? This cannot be undone.",
	"yes_new": "New game", "yes_copy": "Copy", "yes_erase": "Erase", "no": "Keep",
	"copied": "Slot %d was copied into slot %d.", "erased": "Slot %d is empty now.",
	"copy_failed": "The copy could not be written.",
}

var mode := "load"               ## "load" or "new" (set by main.gd when it opens the screen)
var _cards: Array[Button] = []
var _infos: Array[Dictionary] = []
var _marked := 1                 ## the slot the action row acts on (the card focused last)
var _copy_from := 0              ## above 0 while the player picks where a copy goes
var _row: HBoxContainer
var _card_row: BoxContainer
var _hint: Label
var _actions := {}               ## name -> Button
var _ph := false


## "1 h 20 min", "12 min", "under a minute".
static func played(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m >= 60:
		return "%d h %02d min" % [m / 60, m % 60]
	if m >= 1:
		return "%d min" % m
	return "under a minute"


## [chapter, land] for a story step, from the quest list's CHAPTERS table.
static func chapter(step: int) -> Array:
	var head: Array = QuestList.CHAPTERS[0]
	for row: Array in QuestList.CHAPTERS:
		if step >= int(row[0]):
			head = row
	return [String(head[1]), String(head[2])]


## One line for a slot (the title shows it under Continue).
static func line(info: Dictionary) -> String:
	if not bool(info.get("exists", false)):
		return ""
	var parts: Array = [chapter(int(info["step"]))[0], WORDS["level"] % int(info["level"])]
	if String(info.get("place", "")) != "":
		parts.append(String(info["place"]))
	if float(info.get("play_s", 0.0)) >= 60.0:
		parts.append(played(float(info["play_s"])))
	return "  ·  ".join(parts)


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	_marked = Save.slot
	var outer := UI.safe_margin(self, 6 if _ph else 10)
	add_child(outer)
	var col := UI.vbox(4 if _ph else 8)
	outer.add_child(col)
	col.add_child(top_bar(WORDS["new"] if mode == "new" else WORDS["load"]))
	col.add_child(UI.spacer(0, 0, true))
	_card_row = UI.hbox(6 if _ph else 14)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_card_row)
	_row = UI.hbox(4 if _ph else 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)
	for what: String in ["continue", "new_game", "copy", "erase"]:
		var b := UI.button(WORDS[what], _act.bind(what), "Danger" if what == "erase" else "")
		b.name = "Act_" + what
		b.custom_minimum_size = Vector2(96 if not _ph else 70, UI.row_h + (5.0 if not _ph else 3.0))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_actions[what] = b
		_row.add_child(b)
	_hint = UI.label("", "Small")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size.y = UI.font_body.get_height(UI.size_small) + 2.0
	col.add_child(_hint)
	col.add_child(UI.spacer(0, 0, true))
	_fill()
	default_focus = _cards[_marked - 1]
	UI.pop_in(_card_row)


func help_pairs() -> Array:
	return [["confirm", "Choose"], ["back", "Back"]]


## (Re)builds the three cards from what is saved now.
func _fill() -> void:
	for c: Button in _cards:
		_card_row.remove_child(c)
		c.queue_free()
	_cards.clear()
	_infos.clear()
	for n: int in range(1, Save.SLOTS + 1):
		var info: Dictionary = Save.slot_info(n)
		_infos.append(info)
		var card := _card(n, info)
		_cards.append(card)
		_card_row.add_child(card)
	# left and right run through the cards and stop at the ends; down goes to the row under them
	for i: int in _cards.size():
		var c := _cards[i]
		c.focus_neighbor_left = c.get_path_to(_cards[maxi(i - 1, 0)])
		c.focus_neighbor_right = c.get_path_to(_cards[mini(i + 1, _cards.size() - 1)])
		c.focus_neighbor_top = c.get_path_to(c)
	_mark(_marked, false)
	_say_hint()


func _card(n: int, info: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Slot%d" % n
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(118, 94) if _ph else Vector2(206, 172)
	b.clip_contents = true
	UI.juice(b)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, UI.box("card"))
	b.add_theme_stylebox_override("focus", UI.box("plate"))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, 7 if _ph else 12)
	pad.add_theme_constant_override("margin_top", 5 if _ph else 9)
	pad.add_theme_constant_override("margin_bottom", 4 if _ph else 8)
	b.add_child(pad)
	var col := UI.vbox(1 if _ph else 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	var top := UI.hbox(4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var slot_label := UI.label(WORDS["slot"] % n, "Small")
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(slot_label)
	if n == Save.slot and bool(info["exists"]):
		var last := UI.label(WORDS["last"], "Small")
		last.add_theme_color_override("font_color", UI.C_EMBER)
		top.add_child(last)
	var rule := UI.rule(60, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 4 if _ph else 6)
	col.add_child(rule)
	if not bool(info["exists"]):
		col.add_child(UI.spacer(0, 0, true))
		var empty := UI.label(WORDS["empty"], "Head")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", UI.C_DIM)
		col.add_child(empty)
		var hint := UI.label(WORDS["empty_hint"], "Small", (b.custom_minimum_size.x - 20.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", UI.C_FAINT)
		col.add_child(hint)
		col.add_child(UI.spacer(0, 0, true))
	else:
		var ch := chapter(int(info["step"]))
		var head := UI.label(ch[0], "Head")
		head.add_theme_color_override("font_color", UI.C_GOLD)
		head.clip_text = true
		col.add_child(head)
		var land := UI.label(ch[1], "" if not _ph else "Small")
		land.clip_text = true
		col.add_child(land)
		col.add_child(UI.spacer(0, 1 if _ph else 4))
		var nums := UI.hbox(8)
		nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nums)
		nums.add_child(UI.label(WORDS["level"] % int(info["level"]), "Num"))
		var coins := UI.label(WORDS["coins"] % int(info["coins"]), "Small")
		coins.add_theme_color_override("font_color", UI.C_GOLD)
		coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nums.add_child(coins)
		if String(info["place"]) != "":
			var place := UI.label(String(info["place"]), "Small")
			place.add_theme_color_override("font_color", UI.C_PARCH)
			place.clip_text = true
			col.add_child(place)
		col.add_child(UI.spacer(0, 0, true))
		var time := UI.label(WORDS["played"] % played(float(info["play_s"])), "Small")
		time.clip_text = true
		col.add_child(time)
		if String(info["date"]) != "":
			var date := UI.label(String(info["date"]), "Small")
			date.add_theme_color_override("font_color", UI.C_FAINT)
			col.add_child(date)
	for child: Node in col.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_entered.connect(_mark.bind(n, true))
	b.pressed.connect(_press_card.bind(n))
	return b


## The card the action row acts on keeps its brass edge when the focus goes down to the row.
func _mark(n: int, say: bool) -> void:
	_marked = n
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("normal", UI.box("plate" if i == n - 1 else "card"))
		_cards[i].add_theme_stylebox_override("hover", UI.box("plate" if i == n - 1 else "card"))
		# down from any card lands on the row; up from the row comes back to the marked card
	for what: String in _actions:
		var a: Button = _actions[what]
		a.focus_neighbor_top = a.get_path_to(_cards[n - 1])
		a.focus_neighbor_bottom = a.get_path_to(a)
	var has := bool(_infos[n - 1]["exists"])
	# a row that cannot act on this card is dim, but still answers (it says why)
	for what: String in ["continue", "copy", "erase"]:
		var a: Button = _actions[what]
		if has:
			a.remove_theme_color_override("font_color")
		else:
			a.add_theme_color_override("font_color", UI.C_FAINT)
	if say:
		_say_hint()


func _say_hint(text: String = "", colour: Color = UI.C_DIM) -> void:
	if text == "":
		if _copy_from > 0:
			text = WORDS["hint_copy"] % _copy_from
			colour = UI.C_GOLD
		else:
			text = WORDS["hint_new"] if mode == "new" else WORDS["hint_load"]
	_hint.text = text
	_hint.add_theme_color_override("font_color", colour)


func _press_card(n: int) -> void:
	_mark(n, false)
	if _copy_from > 0:
		_copy_to(n)
		return
	var has := bool(_infos[n - 1]["exists"])
	if mode == "new" or not has:
		_new(n)
	else:
		send("continue", n)


func _act(what: String) -> void:
	var n := _marked
	var has := bool(_infos[n - 1]["exists"])
	if what != "copy":
		_copy_from = 0
	match what:
		"continue":
			if has:
				send("continue", n)
			else:
				_say_hint(WORDS["why_empty"] % n, UI.C_BAD)
		"new_game":
			_new(n)
		"copy":
			if not has:
				_copy_from = 0
				_say_hint(WORDS["why_empty"] % n, UI.C_BAD)
			else:
				_copy_from = n
				_say_hint()
				# the focus goes to the first other card, so one press copies there
				_cards[n % Save.SLOTS].grab_focus()
				_say_hint()
		"erase":
			if not has:
				_say_hint(WORDS["why_empty"] % n, UI.C_BAD)
			else:
				ask(WORDS["ask_erase"] % n, WORDS["yes_erase"], WORDS["no"], _erase.bind(n))


func _new(n: int) -> void:
	if bool(_infos[n - 1]["exists"]):
		ask(WORDS["ask_new"] % n, WORDS["yes_new"], WORDS["no"], func() -> void: send("new_game", n))
	else:
		send("new_game", n)


func _copy_to(n: int) -> void:
	var from := _copy_from
	if n == from:
		_say_hint(WORDS["why_same"], UI.C_BAD)
		return
	if bool(_infos[n - 1]["exists"]):
		ask(WORDS["ask_copy"] % [from, n, n], WORDS["yes_copy"], WORDS["no"], _copy.bind(from, n))
	else:
		_copy(from, n)


func _copy(from: int, to: int) -> void:
	_copy_from = 0
	var ok: bool = Save.copy_slot(from, to)
	_marked = to
	_fill()
	_cards[to - 1].grab_focus.call_deferred()
	_say_hint(WORDS["copied"] % [from, to] if ok else WORDS["copy_failed"], UI.C_GOOD if ok else UI.C_BAD)
	Sfx.play("ui_start" if ok else "ui_back")


func _erase(n: int) -> void:
	Save.erase_slot(n)
	_marked = n
	_fill()
	_cards[n - 1].grab_focus.call_deferred()
	_say_hint(WORDS["erased"] % n)


## Back while picking where a copy goes only drops the copy.
func on_back() -> void:
	if close_dialog():
		return
	if _copy_from > 0:
		_copy_from = 0
		Sfx.play("ui_back")
		_say_hint()
		return
	super.on_back()


## The focus comes back to the marked card after a question is closed.
func _focus_default() -> void:
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree():
		super._focus_default()
	elif not _cards.is_empty() and is_inside_tree() and visible:
		_cards[clampi(_marked, 1, _cards.size()) - 1].grab_focus()
