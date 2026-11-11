extends CanvasLayer
## HUD: everything drawn on top of the game while you play.
##   top left      hearts (half-heart steps, armour in blue), then coins / keys / bombs, then the
##                 Hungry Curse: five skull sockets (Curse Level) and its belly, e.g. "3/5" (curse_meter.gd)
##   top right     minimap (the touch pause button sits in the very corner, see touch.gd)
##   top middle    boss health bar with the boss's name
##   bottom left   the items you carry, lying in a row
##   bottom middle the card that pops up when you pick up an item
##   middle        short banners: floor name, toasts, "Unlocked: ..."
## It listens to the event bus in scripts/core/g.gd and only redraws when G.hud_changed
## says something changed. Nothing here sits on the room's floor: the top 42 and the
## bottom 26 pixels of the screen are walls on every screen shape.

const UI = preload("res://scripts/ui/theme.gd")
const Items = preload("res://scripts/data/items.gd")
const Unlocks = preload("res://scripts/data/unlocks.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Hearts = preload("res://scripts/ui/hearts.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
const ItemRack = preload("res://scripts/ui/item_rack.gd")
const CurseMeter = preload("res://scripts/ui/curse_meter.gd")

const CARD_TIME := 2.5           ## seconds an item card stays up
const PAUSE_GAP := 23.0          ## room kept free in the top right corner for the pause button
const RACK_ROWS := 2              ## the carried items wrap into at most this many rows
const BOSS_MAX_W := 132.0        ## the boss bar is at most this wide
const BOSS_BAR_H := 7.0

var run: Node
var _root: Control
var _flash: ColorRect
var _hearts: Control
var _counters: HBoxContainer
var _count_labels := {}
var _count_icons := {}
var _curse_meter: Control
var _coins_shown := 0
var _coins_target := 0
var _coin_clock := 0.0
var _minimap: Control
var _rack: Control
var _rack_ids: Array = []
var _rack_width := 300.0
var _boss_box: Control
var _boss_name: Label
var _boss_bar: Control
var _boss: Node
var _boss_frac := 1.0
var _boss_ghost := 1.0
var _banner: VBoxContainer
var _banner_over: Label
var _banner_title: Label
var _banner_rule: Control
var _banner_sub: Label
var _banner_queue: Array = []
var _banner_tween: Tween
var _card: PanelContainer
var _card_queue: Array[String] = []
var _card_tween: Tween
var _dirty := false
var _fresh := false               ## begin() was called and nothing has been drawn since


func _ready() -> void:
	layer = G.LAYER_HUD
	# the HUD freezes with the game when it is paused (main.gd itself never pauses)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	_flash = ColorRect.new()
	_flash.color = Color(UI.C_RED, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_hearts = Hearts.new()
	_root.add_child(_hearts)

	_counters = UI.hbox(6)
	_counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_counters)
	for kind: String in ["coin", "key", "bomb"]:
		var pair := UI.hbox(1)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := UI.hud_icon(kind)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		var num := UI.label("0", "Hud")
		pair.add_child(num)
		_counters.add_child(pair)
		_count_labels[kind] = num
		_count_icons[kind] = icon
	_curse_meter = CurseMeter.new()
	_curse_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_counters.add_child(_curse_meter)
	_counters.resized.connect(func() -> void:
		if _boss_box != null:
			_place_boss_bar())

	_minimap = Minimap.new()
	_root.add_child(_minimap)

	_rack = ItemRack.new()
	_rack.set("grow_up", true)
	_root.add_child(_rack)

	_build_boss_bar()
	_build_banner()

	G.hud_changed.connect(func() -> void: _dirty = true)
	G.room_entered.connect(func(_c: Vector2i, _t: int, _f: bool) -> void: _dirty = true)
	G.run_started.connect(begin)
	G.floor_started.connect(_on_floor_started)
	G.player_hurt.connect(_on_player_hurt)
	G.pickup_collected.connect(_on_pickup)
	G.item_acquired.connect(_on_item_acquired)
	G.boss_started.connect(_on_boss_started)
	G.boss_defeated.connect(func(_id: String) -> void: _hide_boss())
	G.toast.connect(_on_toast)
	Save.unlocked.connect(_on_unlocked)
	Controls.device_changed.connect(func(_t: bool) -> void: _layout())
	get_viewport().size_changed.connect(_layout)
	visible = false


# ------------------------------------------------------------------ start / stop
## main.gd calls this right after it created a run.
func begin(r: Node) -> void:
	if r == run and _fresh:
		return                    # main.gd and G.run_started both call this for a new run
	_fresh = true
	run = r
	_boss = null
	_boss_box.visible = false
	_rack_ids = [-1]            # forces the item row to be rebuilt
	_coins_shown = -1
	_minimap.call("set_run", r)
	clear_popups()
	_dirty = true
	_layout()


func end() -> void:
	run = null
	_boss = null
	clear_popups()


## Removes banners and item cards at once (used when a run ends, and by the UI tour).
func clear_popups() -> void:
	_banner_queue.clear()
	_card_queue.clear()
	if _banner_tween != null:
		_banner_tween.kill()
		_banner_tween = null
	if _card_tween != null:
		_card_tween.kill()
		_card_tween = null
	_banner.visible = false
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null
	_flash.color.a = 0.0


# ------------------------------------------------------------------ layout
func _layout() -> void:
	if not is_inside_tree():
		return
	var s := UI.screen_size(self)
	var ins := UI.safe_insets(self)
	var left := ins.x + 3.0
	var top := ins.y + 3.0
	var right := s.x - ins.z - 3.0
	var bottom := s.y - ins.w - 1.0
	# On 16:9 the room's walls reach almost to the screen edge, so the HUD lies over them:
	# keep it a little see-through there. On wider phones it has dark space of its own.
	var narrow := (s.x - 304.0) / 2.0 - maxf(ins.x, ins.z) < 40.0
	var alpha := 0.88 if narrow else 1.0
	_hearts.set("per_row", 8 if narrow else 10)
	_hearts.position = Vector2(left, top)
	_hearts.modulate.a = alpha
	_counters.position = Vector2(left + 1.0, top + _hearts.size.y + 1.0)
	_counters.modulate.a = alpha
	var gap := PAUSE_GAP if Controls.using_touch else 0.0
	_minimap.position = Vector2(right - _minimap.size.x - gap, top - 1.0)
	_minimap.modulate.a = alpha
	_rack.position = Vector2(left, bottom - ItemRack.ROW)
	_rack.modulate.a = alpha
	if absf(_rack_width - (right - left)) > 0.5:
		_rack_width = right - left
		_rack_ids = [-1]
		_dirty = true
	_place_boss_bar()
	_place_card()


## The boss bar sits in the middle of the top edge. If the hearts or the minimap reach that
## far in, it moves (and shrinks) into the free gap between them.
func _place_boss_bar() -> void:
	var s := UI.screen_size(self)
	var gap_left := maxf(_hearts.position.x + _hearts.size.x, _counters.position.x + _counters.size.x) + 4.0
	if _hearts.size.y > 14.0:
		gap_left = _hearts.position.x + float(_hearts.get("per_row")) * 13.0 + 4.0
	var gap_right := _minimap.position.x - 4.0
	var w := clampf(gap_right - gap_left, 60.0, BOSS_MAX_W)
	var x := clampf(roundf((s.x - w) / 2.0), gap_left, maxf(gap_right - w, gap_left))
	_boss_box.position = Vector2(x, _hearts.position.y - 2.0)
	_boss_box.size.x = w
	_boss_bar.size.x = w
	_boss_bar.queue_redraw()


# ------------------------------------------------------------------ redraw when told
func _process(delta: float) -> void:
	if not is_instance_valid(run):
		return
	if _dirty:
		_dirty = false
		_fresh = false
		_refresh()
	# the coin counter ticks towards its real value
	if _coins_shown != _coins_target:
		_coin_clock -= delta
		if _coin_clock <= 0.0:
			_coin_clock = 0.03
			var diff := _coins_target - _coins_shown
			_coins_shown += signi(diff) * maxi(absi(diff) / 6, 1)
			(_count_labels["coin"] as Label).text = str(_coins_shown)
	if _boss != null:
		_track_boss(delta)


func _num(obj: Object, field: String) -> int:
	var v: Variant = obj.get(field)
	return int(v) if (v is int or v is float) else 0


func _refresh() -> void:
	var p: Variant = run.get("player")
	if not is_instance_valid(p):
		return
	if _hearts.call("set_values", _num(p, "hp"), _num(p, "max_hp"), _num(p, "armor")):
		_counters.position.y = _hearts.position.y + _hearts.size.y + 1.0
		_place_boss_bar()
	_coins_target = _num(p, "coins")
	if _coins_shown < 0:
		_coins_shown = _coins_target
		(_count_labels["coin"] as Label).text = str(_coins_shown)
	(_count_labels["key"] as Label).text = str(_num(p, "keys"))
	(_count_labels["bomb"] as Label).text = str(_num(p, "bombs"))
	_curse_meter.call("set_values", _num(run, "curse_level"), _num(run, "belly"), int(run.call("belly_cap")) if run.has_method("belly_cap") else 5)
	var items: Variant = p.get("items")
	if items is Array and items != _rack_ids:
		_rack_ids = (items as Array).duplicate()
		_rack.call("set_items", _rack_ids, _rack_width, RACK_ROWS)
	_minimap.call("refresh")


# ------------------------------------------------------------------ small reactions
func _on_player_hurt(_half_hearts: int) -> void:
	_dirty = true
	if UI.instant:
		return
	_flash.color.a = 0.2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_flash, "color:a", 0.0, 0.3)
	_hearts.pivot_offset = Vector2(0, _hearts.size.y / 2.0)
	_hearts.scale = Vector2(1.25, 1.25)
	_hearts.modulate = Color(2.0, 2.0, 2.0, _hearts.modulate.a)
	tw.tween_property(_hearts, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hearts, "modulate", Color(1, 1, 1, _hearts.modulate.a), 0.25)


func _on_pickup(kind: String, _amount: int) -> void:
	_dirty = true
	if UI.instant:
		return
	var target: Control = _count_icons.get(kind, null)
	if kind == "heart" or kind == "armor":
		target = _hearts
	if target == null:
		return
	target.pivot_offset = target.size / 2.0 if target != _hearts else Vector2(0, target.size.y / 2.0)
	target.scale = Vector2(1.35, 1.35) if target != _hearts else Vector2(1.12, 1.12)
	create_tween().tween_property(target, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ boss bar
func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.size = Vector2(BOSS_MAX_W, 22)
	_boss_box.visible = false
	_root.add_child(_boss_box)
	_boss_name = UI.label("", "Hud")
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_name.grow_horizontal = Control.GROW_DIRECTION_BOTH      # a long name may be wider than the bar
	_boss_box.add_child(_boss_name)
	_boss_bar = Control.new()
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.size = Vector2(BOSS_MAX_W, BOSS_BAR_H)
	_boss_bar.position = Vector2(0, _boss_box.size.y - BOSS_BAR_H - 1.0)
	_boss_bar.draw.connect(_draw_boss_bar)
	_boss_box.add_child(_boss_bar)


func _draw_boss_bar() -> void:
	var w := _boss_bar.size.x
	var h := BOSS_BAR_H
	_boss_bar.draw_rect(Rect2(1, 0, w - 2, h), UI.C_INK)
	_boss_bar.draw_rect(Rect2(0, 1, w, h - 2), UI.C_INK)
	_boss_bar.draw_rect(Rect2(1, 1, w - 2, h - 2), Color("3a1620"))
	var inner := w - 2.0
	var ghost := roundf(inner * _boss_ghost)
	var fill := roundf(inner * _boss_frac)
	if _boss_frac > 0.0:
		fill = maxf(fill, 1.0)
	if ghost > fill:
		_boss_bar.draw_rect(Rect2(1, 1, ghost, h - 2), UI.C_BONE)
	if fill > 0.0:
		_boss_bar.draw_rect(Rect2(1, 1, fill, h - 2), UI.C_RED)
		_boss_bar.draw_rect(Rect2(1, 1, fill, 1), Color("f08a6e"))
		_boss_bar.draw_rect(Rect2(1, h - 2, fill, 1), UI.C_BLOOD)
	# a notch where each later phase of the boss begins
	if _boss != null and is_instance_valid(_boss) and "phase_marks" in _boss:
		for share in _boss.phase_marks:
			_boss_bar.draw_rect(Rect2(1.0 + roundf(inner * float(share)), 1, 1, h - 2), UI.C_INK)


func _on_boss_started(boss: Node) -> void:
	_boss = boss
	_boss_frac = 1.0
	_boss_ghost = 1.0
	var shown_name: Variant = boss.get("display_name")
	_boss_name.text = String(shown_name) if shown_name != null else ""
	_boss_box.visible = true
	_boss_box.modulate.a = 1.0
	_boss_bar.queue_redraw()
	if not UI.instant:
		_boss_box.modulate.a = 0.0
		create_tween().tween_property(_boss_box, "modulate:a", 1.0, 0.3)


func _track_boss(delta: float) -> void:
	if not is_instance_valid(_boss):
		_hide_boss()
		return
	var max_hp := float(_boss.get("max_hp")) if _boss.get("max_hp") != null else 1.0
	var hp := float(_boss.get("hp")) if _boss.get("hp") != null else 0.0
	var frac := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var changed := false
	if not is_equal_approx(frac, _boss_frac):
		_boss_frac = frac
		changed = true
	if _boss_ghost > _boss_frac:
		_boss_ghost = maxf(_boss_ghost - delta * 0.35, _boss_frac)     # the pale part drains after a hit
		changed = true
	elif _boss_ghost < _boss_frac:
		_boss_ghost = _boss_frac
	if changed:
		_boss_bar.queue_redraw()


func _hide_boss() -> void:
	_boss = null
	if not _boss_box.visible:
		return
	if UI.instant:
		_boss_box.visible = false
		return
	var tw := create_tween()
	tw.tween_property(_boss_box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _boss_box.visible = false)


# ------------------------------------------------------------------ banners (floor, toast, unlock)
func _build_banner() -> void:
	_banner = UI.vbox(0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 48
	_banner.visible = false
	_root.add_child(_banner)
	_banner_over = UI.label("", "Hud")
	_banner_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_over.add_theme_color_override("font_color", UI.C_GOLD)
	_banner.add_child(_banner_over)
	_banner_title = UI.label("", "HudHead")
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_rule = Control.new()
	_banner_rule.custom_minimum_size = Vector2(0, 7)
	_banner_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_rule.draw.connect(_draw_rule)
	_banner.add_child(_banner_rule)
	_banner_sub = UI.label("", "Hud")
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)


## A thin line with a diamond in the middle, under the floor name.
func _draw_rule() -> void:
	var c := Vector2(roundf(_banner_rule.size.x / 2.0), 3)
	for side: int in [-1, 1]:
		var x := c.x + side * 6.0 if side > 0 else c.x - 6.0 - 46.0
		_banner_rule.draw_rect(Rect2(x - 1, c.y - 1, 48, 3), UI.C_INK)
		_banner_rule.draw_rect(Rect2(x, c.y, 46, 1), UI.C_GOLD)
	for i in 3:
		_banner_rule.draw_rect(Rect2(c.x - i - 1, c.y - 3 + i, i * 2 + 3, 7 - i * 2), UI.C_INK)
	for i in 3:
		_banner_rule.draw_rect(Rect2(c.x - i, c.y - 2 + i, i * 2 + 1, 5 - i * 2), UI.C_GOLD)


func _on_floor_started(floor_index: int, floor_name: String) -> void:
	_dirty = true
	_queue_banner({"style": "floor", "over": "Floor %d" % (floor_index + 1), "title": floor_name, "sub": ""})


func _on_toast(title: String, subtitle: String) -> void:
	# the floor's name already gets the big banner from G.floor_started; do not show it twice
	if is_instance_valid(run) and title == String(run.get("floor_name")) and title != "":
		return
	_queue_banner({"style": "toast", "title": title, "sub": subtitle})


func _on_unlocked(id: String) -> void:
	if not is_instance_valid(run):
		return
	var rule := Unlocks.by_id(id)
	_queue_banner({"style": "unlock", "over": "Unlocked", "title": String(rule.get("name", id)), "sub": ""})


func _queue_banner(b: Dictionary) -> void:
	if _banner_queue.size() >= 4:
		return
	_banner_queue.append(b)
	if _banner_tween == null or not _banner_tween.is_valid():
		_next_banner()


func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner.visible = false
		_banner_tween = null
		return
	var b: Dictionary = _banner_queue.pop_front()
	var style := String(b.get("style", "toast"))
	_banner_over.text = String(b.get("over", ""))
	_banner_over.visible = _banner_over.text != ""
	_banner_title.text = String(b.get("title", ""))
	_banner_sub.text = String(b.get("sub", ""))
	_banner_sub.visible = _banner_sub.text != ""
	_banner_rule.visible = style == "floor"
	_banner_title.remove_theme_font_size_override("font_size")
	_banner_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner_title.add_theme_color_override("font_color", UI.C_GOLD if style == "unlock" else UI.C_BONE)
	if style == "floor":
		# the floor name is the big moment: as large as fits
		UI.fit_title(_banner_title, UI.screen_size(self).x - 60.0)
	_banner.visible = true
	_banner.modulate.a = 1.0
	var hold := 2.0 if style != "toast" else 1.6
	if not _banner_queue.is_empty():
		hold *= 0.6
	_banner_tween = create_tween()
	if not UI.instant:
		_banner.modulate.a = 0.0
		_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_callback(_next_banner)


# ------------------------------------------------------------------ item card
func _on_item_acquired(item_id: String) -> void:
	_dirty = true
	_card_queue.append(item_id)
	if not is_instance_valid(_card):
		_next_card()


func _next_card() -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null
	if _card_queue.is_empty():
		return
	var id: String = _card_queue.pop_front()
	var info := Items.info(id)
	var cursed := bool(info.get("cursed", false))
	_card = UI.panel("curse" if cursed else "card")
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(6)
	_card.add_child(row)
	var icon := Icon.new()
	icon.setup(String(info.get("icon", "skull")), Vector2(20, 24), 0.0, 2.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := UI.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var name_label := UI.label(String(info.get("name", id)), "Curse" if cursed else "Gold")
	col.add_child(name_label)
	var max_text := minf(UI.screen_size(self).x - 110.0, 230.0)
	for line: Array in [[String(info.get("desc", "")), ""], [String(info.get("curse", "")) if cursed else "", "Red"]]:
		if line[0] == "":
			continue
		var l := UI.label(line[0], line[1])
		if l.get_minimum_size().x > max_text:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = max_text
		col.add_child(l)
	_root.add_child(_card)
	_card.reset_size()
	_place_card()
	var rest := _card.position
	_card_tween = create_tween()
	if not UI.instant:
		_card.position = rest + Vector2(0, _card.size.y + 6.0)
		_card_tween.tween_property(_card, "position", rest, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if cursed:
			# a cursed item makes the card shudder
			for i in 4:
				_card_tween.tween_property(_card, "position", rest + Vector2(2 if i % 2 == 0 else -2, 0), 0.04)
			_card_tween.tween_property(_card, "position", rest, 0.04)
	_card_tween.tween_interval(CARD_TIME if _card_queue.is_empty() else CARD_TIME * 0.5)
	if not UI.instant:
		_card_tween.tween_property(_card, "position", rest + Vector2(0, _card.size.y + 6.0), 0.14)
	_card_tween.tween_callback(_next_card)


func _place_card() -> void:
	if not is_instance_valid(_card):
		return
	var s := UI.screen_size(self)
	var ins := UI.safe_insets(self)
	_card.position = Vector2(roundf((s.x - _card.size.x) / 2.0), s.y - ins.w - _card.size.y - 2.0)
