extends "res://scripts/ui/screen.gd"
## Settings, in five tabs: Game / Display / Sound / Controls / Accessibility (Q / E or LB / RB turn
## the tab, or click one). Every change is stored with Save.set_setting and works at once.
## The rows are the table TABS below; the line under the list explains the row in focus.
## To add a setting: add a row to TABS (and a default in scripts/core/save.gd DEFAULT_SETTINGS; a
## setting with no default there still works, its "def" here is used). A row that must DO something
## when it changes gets a branch in _after().
## HD GUI: the veil and one centred glass panel (440 UI px on a PC, the whole width on a phone).
## Test flag: --settingstab=<0..4 or a tab id> opens on that tab (for pictures).

const SettingRow = preload("res://scripts/ui/setting_row.gd")
const Display = preload("res://scripts/ui/display.gd")
const UI_SIZES := [["small", "Small"], ["normal", "Normal"], ["large", "Large"]]
const VEIL_GAIN := 2.4
const MUSIC_ROOM := "res://scripts/ui/music_room.gd"      ## made by the sound package; the button shows only when it exists
const REBIND := "res://scripts/ui/rebind.gd"

## Row keys:  key = the setting's name; title; kind = "steps" (0..1 in five steps), "toggle",
## "choice" (options = [[value, word], ...]) or "button" (does = the request sent to main.gd);
## def = the value used while the save has none; hint = the line shown while the row has the focus;
## on = "pc" / "phone" (only there); half = on a phone two such switches share one line.
## (All words here are placeholders: the owner rewrites the game's words.)
const TABS := [
	{"id": "game", "name": "Game", "rows": [
		{"key": "battle_mode", "title": "Battles", "kind": "choice", "def": "normal",
			"options": [["story", "Story"], ["normal", "Normal"], ["hard", "Hard"]],
			"hint": "How hard the fights are. Story: for the tale, foes are weaker. Hard: foes are tougher and hit harder. Counts from the next fight."},
		{"key": "battle_speed", "title": "Battle speed", "kind": "choice", "def": 1,
			"options": [[1, "Normal"], [2, "Fast"], [3, "Faster"]],
			"hint": "How fast a fight plays. The same as the speed plate beside Auto in a battle."},
		{"key": "text_speed", "title": "Text speed", "kind": "choice", "def": "normal",
			"options": [["slow", "Slow"], ["normal", "Normal"], ["fast", "Fast"], ["instant", "At once"]],
			"hint": "How fast the words appear when someone talks."},
		{"key": "hints", "title": "Tutorial hints", "kind": "toggle", "def": true, "half": true,
			"hint": "Short lessons the first time something new happens in a fight."},
		{"key": "fairy_dust", "title": "Fairy dust", "kind": "toggle", "def": true, "half": true,
			"hint": "Glittering dust on the ground that leads to the next step of the story."},
		{"kind": "buttons", "buttons": [
			{"title": "Your knight", "does": "customize"},
			{"title": "Erase this save", "does": "_erase", "danger": true}]},
	]},
	{"id": "display", "name": "Display", "rows": [
		{"key": "look3d", "title": "3D look", "kind": "toggle", "def": true,
			"hint": "The lit 3D look of the places you walk in. Off: the flat picture, for a device that runs it slowly. Counts from the next place."},
		{"key": "display", "title": "Display", "kind": "choice", "def": "window", "on": "pc", "options": "display",
			"hint": "A window or the whole screen. F11 or Alt + Enter also switch."},
		{"key": "borderless", "title": "Borderless window", "kind": "toggle", "def": false, "on": "pc",
			"hint": "The window without its frame and title bar."},
		{"key": "window_size", "title": "Window size", "kind": "choice", "def": "", "on": "pc", "options": "sizes",
			"hint": "The size of the window. Only sizes that fit this screen are listed."},
		{"key": "vsync", "title": "VSync", "kind": "toggle", "def": true, "on": "pc",
			"hint": "Draws in step with the screen, so the picture does not tear."},
		{"key": "fps_cap", "title": "Frame limit", "kind": "choice", "def": 0, "options": "fps",
			"hint": "The most pictures drawn each second. A lower number keeps a laptop or a phone cooler."},
	]},
	{"id": "sound", "name": "Sound", "rows": [
		{"key": "master_volume", "title": "Master volume", "kind": "steps", "def": 1.0,
			"hint": "The loudness of the whole game."},
		{"key": "music_volume", "title": "Music", "kind": "steps", "def": 0.7, "hint": "The loudness of the music."},
		{"key": "sfx_volume", "title": "Sound effects", "kind": "steps", "def": 1.0, "hint": "The loudness of blows, steps and buttons."},
		{"key": "amb_volume", "title": "Ambience", "kind": "steps", "def": 1.0,
			"hint": "The loudness of wind, birds, water and fire in the places you walk in."},
		{"key": "mute_bg", "title": "Quiet in the background", "kind": "toggle", "def": true, "on": "pc",
			"hint": "No sound while another window is in use."},
		{"kind": "buttons", "buttons": [{"title": "Music room", "does": "open_screen", "arg": "music_room", "needs": MUSIC_ROOM}]},
	]},
	{"id": "controls", "name": "Controls", "rows": [
		{"key": "pad_glyphs", "title": "Button icons", "kind": "choice", "def": "auto", "options": "pads",
			"hint": "Which gamepad's button names the prompts show. Auto: from the gamepad in use."},
		{"key": "ff_toggle", "title": "Fast-forward", "kind": "choice", "def": false,
			"options": [[false, "Hold"], [true, "Press once"]],
			"hint": "Speeding up a fight: hold the button down, or press it once to switch it on and again to switch it off."},
		{"key": "vibration", "title": "Vibration", "kind": "toggle", "def": true, "on": "phone", "half": true, "hint": ""},
		{"key": "swap_sticks", "title": "Left-handed", "kind": "toggle", "def": false, "on": "phone", "half": true, "hint": ""},
		{"kind": "buttons", "buttons": [{"title": "Change keys and buttons", "does": "open_screen", "arg": "rebind", "needs": REBIND}]},
	]},
	{"id": "access", "name": "Accessibility", "short": "Access", "rows": [
		{"key": "ui_size", "title": "Text size", "kind": "choice", "def": "normal", "on": "pc", "options": "ui_sizes",
			"hint": "How big the words and menus are drawn."},
		{"key": "flashes", "title": "Reduce flashes", "kind": "choice", "def": "full",
			"options": [["full", "Off"], ["reduced", "On"]],
			"hint": "On: the bright flashes of blows and spells are much weaker, and the short freeze on a hit is skipped."},
		{"key": "shake", "title": "Screen shake", "kind": "toggle", "def": true, "half": true,
			"hint": "The camera shakes when a blow lands."},
		{"key": "ff_toggle", "title": "Fast-forward", "kind": "choice", "def": false,
			"options": [[false, "Hold"], [true, "Press once"]],
			"hint": "Speeding up a fight: hold the button down, or press it once to switch it on and again to switch it off."},
	]},
]

static var last_tab := 0         ## the tab shown last (it opens there again in the same session)

var tab := 0
var _ph := false
var _tabs: Array = []            ## the tab buttons
var _pages: Array = []           ## one Control per tab
var _firsts: Array = []          ## the first row of each tab (takes the focus when the tab turns)
var _hint: Label
var _twins := {}                 ## setting key -> its rows (a setting may stand on two tabs: they stay alike)
var _panel: Control


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", VEIL_GAIN)
	var outer: Control
	if _ph:
		outer = UI.safe_margin(self, 4)
	else:
		outer = CenterContainer.new()
		outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var panel := UI.panel("panel")
	if not _ph:
		panel.custom_minimum_size.x = 440
	outer.add_child(panel)
	_panel = panel
	var list := UI.vbox(0)
	panel.add_child(list)
	list.add_child(_header())

	var stack := Control.new()                # the pages lie on top of each other; one is shown
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(stack)
	var tallest := 0.0
	for t: Dictionary in TABS:
		var page := _page(t)
		_pages.append(page)
		stack.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inner: Control = page.get_child(0) if page is ScrollContainer else page
		tallest = maxf(tallest, inner.get_combined_minimum_size().y)
	if _ph:
		# a phone screen is 180 UI px tall: the list scrolls inside what is left under the header
		var room := UI.screen_size(self).y - UI.safe_insets(self).y - UI.safe_insets(self).w - 8.0 - 23.0 - 12.0
		stack.custom_minimum_size.y = minf(tallest, maxf(room, 80.0))
	else:
		stack.custom_minimum_size.y = tallest
		list.add_child(UI.spacer(0, 3))
		var rule := UI.rule(200, UI.C_BRASS_DIM, "both")
		rule.custom_minimum_size = Vector2(0, 3)
		list.add_child(rule)
		_hint = UI.label("", "Small", 400.0)
		_hint.custom_minimum_size.y = UI.size_small * 2 + 8
		_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_color_override("font_color", UI.C_DIM)
		list.add_child(_hint)
	var start := last_tab
	var asked := G.arg("settingstab")
	if asked != "":
		start = int(asked) if asked.is_valid_int() else _tab_index(asked)
	show_tab(start, false)
	if not _ph:
		_add_back_button()
	UI.pop_in(panel)


func _tab_index(id: String) -> int:
	for i in TABS.size():
		if String(TABS[i]["id"]) == id:
			return i
	return 0


## "SETTINGS" in Cinzel, then the tab bar over a brass rule (a phone: Back and the tabs on one line).
func _header() -> Control:
	var head := UI.vbox(0)
	if not _ph:
		var line := Control.new()
		line.custom_minimum_size.y = 22
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(line)
		var t := UI.label("Settings", "Head")
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(t)
	var bar := UI.hbox(8 if not _ph else 1)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.custom_minimum_size.y = 22 if not _ph else 20
	head.add_child(bar)
	if _ph:
		var back := UI.button("Back", on_back, "", "")
		back.name = "Back"
		back.focus_mode = Control.FOCUS_NONE
		back.custom_minimum_size = Vector2(36, 20)
		bar.add_child(back)
		bar.add_child(UI.spacer(0, 0, true))
	else:
		var q := UI.prompt("page_prev")
		q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(q)
	for i in TABS.size():
		var row: Dictionary = TABS[i]
		var tb := UI.button(String(row.get("short", row["name"])) if _ph else String(row["name"]), show_tab.bind(i), "Tab", "")
		tb.name = "tab_" + String(row["id"])
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE       # Q / E (LB / RB) turn the tab; the arrows stay in the list
		tb.custom_minimum_size = Vector2(0, 22) if not _ph else Vector2(58, 20)
		if _ph:
			tb.add_theme_font_size_override("font_size", 8)
		bar.add_child(tb)
		_tabs.append(tb)
	if _ph:
		bar.add_child(UI.spacer(0, 0, true))
	else:
		var e := UI.prompt("page_next")
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(e)
	var rule := UI.rule(200, UI.C_BRASS, "both")
	rule.custom_minimum_size = Vector2(0, 5 if not _ph else 3)
	head.add_child(rule)
	return head


## A Back button for the mouse at the bottom left (keys and pads have Esc / B).
func _add_back_button() -> void:
	add_child(UI.mouse_back(on_back))


func help_pairs() -> Array:
	return [["target", "Change"], ["page", "Tab"], ["back", "Back"]]


# ------------------------------------------------------------------ the pages
## One tab's rows (on a phone inside a scroll box: the screen is short).
func _page(t: Dictionary) -> Control:
	var col := UI.vbox(0)
	var first: Control = null
	var half: Control = null              # a phone: the switch waiting for a partner on its line
	for spec: Dictionary in t["rows"]:
		var where := String(spec.get("on", ""))
		if (where == "pc" and _ph) or (where == "phone" and not _ph):
			continue
		var made: Control
		if String(spec["kind"]) == "buttons":
			made = _buttons(spec["buttons"])
			if made == null:
				continue
			col.add_child(UI.spacer(0, 5 if not _ph else 2))
			col.add_child(made)
			if first == null:
				first = made.get_child(0)
			half = null
			continue
		made = _row(spec)
		if first == null:
			first = made
		if _ph and bool(spec.get("half", false)):
			made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if half != null:
				half.get_parent().add_child(made)
				half = null
			else:
				var line := UI.hbox(6)
				col.add_child(line)
				line.add_child(made)
				half = made
		else:
			half = null
			col.add_child(made)
	_firsts.append(first)
	if not _ph:
		return col
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return scroll


## The value a setting has now (the row's "def" while the save knows none).
static func value_of(spec: Dictionary) -> Variant:
	var v: Variant = Save.setting(String(spec["key"]))
	return v if v != null else spec.get("def")


func _options(spec: Dictionary) -> Array:
	var o: Variant = spec.get("options", [])
	if o is Array:
		return o
	match String(o):
		"display":
			return Display.MODES
		"sizes":
			return Display.size_choices()
		"fps":
			return Display.FPS_CAPS
		"pads":
			return UI.PAD_STYLES
		"ui_sizes":
			return UI_SIZES
	return []


static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))        # (a number comes back from the file as 2.0)
	return typeof(a) == typeof(b) and a == b


func _row(spec: Dictionary) -> Control:
	var row := SettingRow.new()
	var key := String(spec["key"])
	var kind := String(spec["kind"])
	var now: Variant = value_of(spec)
	var opts := _options(spec)
	if kind == "choice":
		var at := 0
		for i in opts.size():
			if _same(opts[i][0], spec.get("def")):
				at = i
		for i in opts.size():
			if _same(opts[i][0], now):
				at = i
		if key == "ui_size":
			at = maxi(["small", "normal", "large"].find(UI.ui_size_name()), 0)     # (what is really shown: --uisize, a small screen)
		row.options = opts.map(func(o: Array) -> String: return String(o[1]))
		row.setup("choice", String(spec["title"]), at)
	else:
		row.setup(kind, String(spec["title"]), now)
	row.name = "row_" + key
	if not _twins.has(key):
		_twins[key] = []
	(_twins[key] as Array).append(row)
	row.changed.connect(func(v: Variant) -> void:
		var value: Variant = opts[int(v)][0] if kind == "choice" else v
		Save.set_setting(key, value)
		Sfx.play("ui_click")
		for twin: Control in _twins[key]:
			if twin != row:
				twin.call("setup", kind, String(twin.get("title")), v)
		_after(key, value))
	var hint := String(spec.get("hint", ""))
	row.focus_entered.connect(func() -> void: _say(hint))
	return row


## What a change has to DO besides being saved.
func _after(key: String, value: Variant) -> void:
	match key:
		"ui_size":
			Save.set_setting("ui_size_set", true)      # the player chose: the small-screen rule stops (theme.gd)
			UI.refit_all()
		"display", "borderless", "window_size", "vsync", "fps_cap":
			Display.apply(true)
		"vibration":
			if bool(value):
				Input.vibrate_handheld(40)
		"pad_glyphs":
			Controls.device_changed.emit(Controls.using_touch)       # every prompt reads its cap again
		"master_volume", "amb_volume":
			# (save.gd passes every "..._volume" on to Sfx after this pass; this covers the time before)
			if Sfx.has_method("set_volumes"):
				Sfx.set_volumes(float(Save.setting("sfx_volume")), float(Save.setting("music_volume")))


## A line of buttons under a tab's rows (a button whose "needs" file is missing is left out).
func _buttons(specs: Array) -> Control:
	var line := UI.hbox(8 if not _ph else 4)
	for spec: Dictionary in specs:
		if spec.has("needs") and not ResourceLoader.exists(String(spec["needs"])):
			continue
		var does := String(spec["does"])
		var arg: Variant = spec.get("arg")
		var b := UI.button(String(spec["title"]), _ask_reset if does == "_erase" else (func() -> void: send(does, arg)),
			"Danger" if bool(spec.get("danger", false)) else "")
		b.custom_minimum_size.y = UI.row_h + (3.0 if not _ph else 1.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_entered.connect(func() -> void: _say(""))
		line.add_child(b)
	if line.get_child_count() == 0:
		line.free()
		return null
	return line


func _say(words: String) -> void:
	if is_instance_valid(_hint):
		_hint.text = words


## Shows tab `i` (0..4); `focus` puts the focus on its first row.
func show_tab(i: int, focus: bool = true) -> void:
	var turned := i != tab
	tab = clampi(i, 0, TABS.size() - 1)
	last_tab = tab
	for k in _pages.size():
		(_pages[k] as Control).visible = k == tab
		(_tabs[k] as Button).set_pressed_no_signal(k == tab)
	default_focus = _firsts[tab]
	_last_focus = null
	if focus:
		if turned:
			Sfx.play("ui_click")
		_focus_default.call_deferred()


## Q / E and LB / RB (the page_prev / page_next actions) turn the tab.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog) or event.is_echo():
		return
	var dir := 0
	if event.is_action_pressed("page_prev"):
		dir = -1
	elif event.is_action_pressed("page_next"):
		dir = 1
	if dir != 0:
		get_viewport().set_input_as_handled()
		show_tab(posmod(tab + dir, TABS.size()))


# ------------------------------------------------------------------ erasing the save
func _ask_reset() -> void:
	ask("Erase this save? The story, levels, coins and gear start over. Settings are kept.", "Erase", "Keep", func() -> void:
		ask("Really erase it? This cannot be undone.", "Erase it", "Keep", func() -> void:
			Save.reset_progress()
			Save.flush()
			Sfx.play("ui_back")
			send("title")))


## A right click goes back (the mouse's Back).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_back()


func on_back() -> void:
	if close_dialog():
		return
	Save.flush()
	Sfx.play("ui_back")
	send("back")
