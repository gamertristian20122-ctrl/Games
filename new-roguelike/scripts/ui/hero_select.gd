extends "res://scripts/ui/screen.gd"
## Hero select: pick who to play. The chosen hero stands in the lit dungeon picture
## (backdrop.gd); a locked hero is a black shape with a hint about how to unlock it.
## Change hero with the arrows, a swipe, or left / right on keyboard or gamepad.
## The heroes themselves are data: scripts/data/heroes.gd.

const Heroes = preload("res://scripts/data/heroes.gd")
const Pips = preload("res://scripts/ui/pips.gd")
const Arrow = preload("res://scripts/ui/arrow.gd")

## Each stat pip row: label, hero field(s), the value that shows 1 pip and the value that shows 5.
const STATS := [
	["Health", "hp", 4.0, 10.0],
	["Damage", "damage", 2.0, 4.5],
	["Speed", "speed", 80.0, 112.0],
	["Fire rate", "rate", 1.6, 3.2],
]

var backdrop: Control                 ## set by main.gd
var _index := 0
var _panel: PanelContainer
var _name: Label
var _title: Label
var _desc: Label
var _passive: Label
var _stats: GridContainer
var _pips: Array = []
var _locked_box: VBoxContainer
var _hint: Label
var _start: Button
var _dots: Control
var _prev: Button
var _next: Button
var _touch_start := Vector2.ZERO
var _touch_id := -1


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var last := String(Save.setting("last_hero"))
	for i in Heroes.LIST.size():
		if Heroes.LIST[i]["id"] == last and not _is_locked(Heroes.LIST[i]):
			_index = i

	var safe := UI.safe_margin(self, 6)
	add_child(safe)
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(area)

	var back := UI.button("Back", on_back, "", "")
	back.custom_minimum_size = Vector2(40, 19)
	area.add_child(back)

	# the info panel and the Start button fill the right part of the screen
	var right := UI.vbox(4)
	right.name = "Right"
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(right)
	_panel = UI.panel("panel")
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_panel)
	var col := UI.vbox(2)
	_panel.add_child(col)
	_name = UI.label("", "Head")
	col.add_child(_name)
	_title = UI.label("", "Gold")
	col.add_child(_title)
	col.add_child(HSeparator.new())
	_desc = UI.label("", "", 10.0)
	col.add_child(_desc)
	_passive = UI.label("", "Dim", 10.0)
	col.add_child(_passive)
	col.add_child(UI.spacer(0, 0, true))
	_stats = GridContainer.new()
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", 4)
	_stats.add_theme_constant_override("v_separation", 3)
	col.add_child(_stats)
	for row: Array in STATS:
		var l := UI.label(row[0], "Small")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(l)
		var p := Pips.new()
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stats.add_child(p)
		_pips.append(p)
	_locked_box = UI.vbox(3)
	_locked_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_locked_box)
	_locked_box.add_child(UI.label("Locked", "Red"))
	_hint = UI.label("", "", 10.0)
	_locked_box.add_child(_hint)

	_start = UI.button("Start", _on_start, "Big", "")
	_start.custom_minimum_size = Vector2(0, 26)
	right.add_child(_start)
	default_focus = _start

	# arrows either side of the hero, page dots below
	_prev = Arrow.new()
	_prev.direction = -1
	_prev.custom_minimum_size = Vector2(22, 34)
	_prev.focus_mode = Control.FOCUS_NONE
	_prev.pressed.connect(_step.bind(-1))
	add_child(_prev)
	_next = Arrow.new()
	_next.direction = 1
	_next.custom_minimum_size = Vector2(22, 34)
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_step.bind(1))
	add_child(_next)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	add_child(_dots)

	resized.connect(_layout)
	_layout.call_deferred()
	_show_hero(false)
	UI.pop_in(right, Vector2(8, 0))


func _layout() -> void:
	if not is_instance_valid(backdrop) or not is_inside_tree():
		return
	var spot: Vector2 = backdrop.call("hero_spot")
	var insets := UI.safe_insets(self)
	var right: Control = _panel.get_parent()
	# the panel starts a little to the right of the hero's pool of light
	var left_edge := maxf(spot.x + 64.0, size.x * 0.47)
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.offset_left = roundf(left_edge) - 6.0 - insets.x
	right.offset_top = 0
	_prev.size = _prev.custom_minimum_size
	_next.size = _next.custom_minimum_size
	_prev.position = Vector2(maxf(spot.x - 50.0 - _prev.size.x, insets.x + 4.0), spot.y - 46.0)
	_next.position = Vector2(spot.x + 50.0, spot.y - 46.0)
	_dots.position = Vector2(spot.x, spot.y + 16.0)
	_dots.queue_redraw()


func _draw_dots() -> void:
	var n := Heroes.LIST.size()
	var x := -(n * 8 - 4) / 2.0
	for i in n:
		var c := UI.C_GOLD if i == _index else UI.C_FAINT
		_dots.draw_rect(Rect2(roundf(x) + i * 8 - 1, -1, 6, 6), UI.C_INK)
		_dots.draw_rect(Rect2(roundf(x) + i * 8, 0, 4, 4), c)


func _is_locked(hero: Dictionary) -> bool:
	return bool(hero.get("locked", false)) and not Save.is_unlocked("hero:" + String(hero["id"]))


func current() -> Dictionary:
	return Heroes.LIST[_index]


## Used by the UI tour.
func select(index: int) -> void:
	_index = posmod(index, Heroes.LIST.size())
	_show_hero(false)


func _step(by: int) -> void:
	_index = posmod(_index + by, Heroes.LIST.size())
	Sfx.play("ui_click")
	_show_hero(true)


func _show_hero(animate: bool) -> void:
	var hero := current()
	var locked := _is_locked(hero)
	if is_instance_valid(backdrop):
		backdrop.call("set_hero", hero, locked)
	_name.text = String(hero["name"])
	_title.text = String(hero["title"])
	_name.add_theme_color_override("font_color", UI.C_FAINT if locked else UI.C_BONE)
	_title.add_theme_color_override("font_color", UI.C_FAINT if locked else UI.C_GOLD)
	_desc.visible = not locked
	_passive.visible = not locked
	_stats.visible = not locked
	_locked_box.visible = locked
	if locked:
		_hint.text = String(hero.get("unlock_hint", ""))
	else:
		_desc.text = String(hero["desc"])
		_passive.text = String(hero["passive"])
		for i in STATS.size():
			var row: Array = STATS[i]
			var value := float(hero.get(row[1], 0.0))
			if row[1] == "hp":
				value += float(hero.get("armor", 0))
			var t := clampf((value - float(row[2])) / (float(row[3]) - float(row[2])), 0.0, 1.0)
			var colour := UI.C_RED if row[1] == "hp" else UI.C_GOLD
			_pips[i].setup(1 + int(roundf(t * 4.0)), 5, colour)
	_start.text = "Locked" if locked else "Start"
	_start.disabled = locked
	_dots.queue_redraw()
	if animate:
		UI.pop_in(_panel, Vector2(0, 0))


func _on_start() -> void:
	if _is_locked(current()):
		return
	Sfx.play("ui_start")
	send("start", String(current()["id"]))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog):
		return
	if event.is_action_pressed("ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		# a sideways swipe anywhere changes the hero
		if event.pressed:
			_touch_id = event.index
			_touch_start = event.position
		elif event.index == _touch_id:
			_touch_id = -1
			var d: Vector2 = event.position - _touch_start
			if absf(d.x) > 30.0 and absf(d.x) > absf(d.y) * 1.5:
				_step(-1 if d.x > 0.0 else 1)
