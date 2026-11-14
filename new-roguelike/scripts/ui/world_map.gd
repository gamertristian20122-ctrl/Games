extends "res://scripts/ui/screen.gd"
## THE WORLD MAP SCREEN (quality pass P11), opened with M or the pause menu's Map row. Drawn only with
## plain code shapes in the Lantern Glass style, from the wide world's own place row
## (Places.get_place("world")): its "regions" as three muted land colours, its "paths" and "trails" as
## dotted brass lines, "water" ellipses (when a place has them), the woods as soft dark clumps, and every
## "signs" row as a lozenge with its name: gold = work to do, grey = still shut, green = done (the
## colours of the names floating over the walking map, hub.gd _build_signs), "?" until the place has
## been seen. On top: a pulsing ember for the knight (on the name of the place he is in when indoors), a
## brass ring on the place the story's next step is at, ember marks where taken errands lead, and the
## secrets found per place.
## Zoom: the mouse wheel, page_prev / page_next (Q / E, LB / RB) or +/-. Look around: arrows / stick / drag.
## Every word is in scripts/data/journal_text.gd.

const Places = preload("res://scripts/data/places.gd")
const Story = preload("res://scripts/data/story.gd")
const Tale = preload("res://scripts/data/tale.gd")
const Errands = preload("res://scripts/data/errands.gd")
const Txt = preload("res://scripts/data/journal_text.gd")

const ZOOMS := [1.0, 1.7, 2.6]
const PAN_SPEED := 520.0          ## world px a second at zoom 1 (arrows / stick)

var _ph := false
var _world := {}
var _map: Control
var _legend: Label
var _zoom_i := 0
var _centre := Vector2.ZERO       ## the world point at the middle of the map
var _knight := Vector2.ZERO       ## where the ember is (world px)
var _inside := ""                 ## the place he is in when it is not the wide world
var _t := 0.0
var _dots: Array = []             ## [Vector2 world, radius, shade] the woods' clumps (made once)
var _drag := false


func build() -> void:
	_ph = UI.is_phone()
	veil().call("set_gain", 2.4)
	_world = Places.get_place("world")
	_find_knight()
	_make_woods()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := UI.safe_insets(self) if is_inside_tree() else Vector4.ZERO
	var side := 6.0 if _ph else 24.0
	margin.add_theme_constant_override("margin_left", int(side + ins.x))
	margin.add_theme_constant_override("margin_right", int(side + ins.z))
	margin.add_theme_constant_override("margin_top", int((4.0 if _ph else 12.0) + ins.y))
	margin.add_theme_constant_override("margin_bottom", int((4.0 if _ph else 30.0) + ins.w))
	add_child(margin)
	var col := UI.vbox(2)
	margin.add_child(col)
	if _ph:
		var head := UI.hbox(4)
		var back := UI.button("Back", on_back, "", "")
		back.focus_mode = Control.FOCUS_NONE
		back.custom_minimum_size = Vector2(38, 20)
		head.add_child(back)
		head.add_child(UI.label(String(Txt.WORDS["map_title"]), "Head"))
		col.add_child(head)
	else:
		col.add_child(top_bar(String(Txt.WORDS["map_title"])))
	var frame := UI.panel("panel" if not _ph else "card")
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(frame)
	_map = Control.new()
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_map.focus_mode = Control.FOCUS_ALL
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	frame.add_child(_map)
	default_focus = _map
	_legend = UI.label(_legend_text(), "Small")
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.add_theme_color_override("font_color", UI.C_DIM)
	col.add_child(_legend)
	_centre = (_world.get("size", Vector2(2000, 1400)) as Vector2) * 0.5
	if _ph:                               # a phone's whole-world view is too small to read: start closer, on the knight
		_zoom_i = 1
		_centre = _knight
	UI.pop_in(frame, Vector2(0, 6))


func help_pairs() -> Array:
	return [["page", String(Txt.WORDS["map_zoom"])], ["back", "Close"]]


func _legend_text() -> String:
	var w: Dictionary = Txt.WORDS
	var bits: Array = [String(w["map_gold"]), String(w["map_grey"]), String(w["map_green"]), String(w["map_goal"]), String(w["map_you"])]
	if _inside != "":
		bits.append(String(w["map_inside"]) % String(Txt.PLACE_NAME.get(_inside, _inside.capitalize())))
	return "    ".join(bits)


# ------------------------------------------------------------------ where things are
func _find_knight() -> void:
	var wsize: Vector2 = _world.get("size", Vector2(2000, 1400))
	_knight = _world.get("spawn", wsize * 0.5)
	var place := Places.last_place("at:place")
	var main: Node = get_tree().current_scene if is_inside_tree() else null
	var hub: Variant = main.get("hub") if main != null else null
	if hub is Node and is_instance_valid(hub) and String((hub as Node).get("place_id")) != "":
		place = String((hub as Node).get("place_id"))
		var hero: Variant = (hub as Node).get("_hero")
		if place == "world" and hero is Node2D and is_instance_valid(hero):
			_knight = (hero as Node2D).position
			return
	if place == "world" or place == "":
		if Save.hub_get("at:x") > 0:
			_knight = Vector2(Save.hub_get("at:x"), Save.hub_get("at:y"))
		return
	_inside = place
	var sg := _sign(String(Txt.PLACE_SIGN.get(place, "")))
	if not sg.is_empty():
		_knight = sg["pos"]


func _sign(text: String) -> Dictionary:
	for s: Dictionary in _world.get("signs", []):
		if String(s["text"]) == text:
			return s
	return {}


## Has the knight seen this name's place? Signs that stand for a place are known once it is seen; the
## rest (the dunes, the pass ...) once he has walked the wide world and its way is not shut.
func _known(s: Dictionary) -> bool:
	var text := String(s["text"])
	for place: String in Txt.PLACE_SIGN:
		if String(Txt.PLACE_SIGN[place]) == text and Save.hub_get("seen:place:" + place) > 0:
			return true
	if Txt.PLACE_SIGN.values().has(text):
		return false
	return Save.hub_get("seen:place:world") > 0 and (String(s.get("need", "")) == "" or Story.cleared(String(s["need"])))


## The name's colour: as the walking map shows it (hub.gd _build_signs).
func _sign_colour(s: Dictionary) -> Color:
	if String(s.get("need", "")) != "" and not Story.cleared(String(s["need"])):
		return UI.C_FAINT
	if s.has("sites"):
		var left := 0
		var can := false
		for site: String in s["sites"]:
			var ahead := Story.next_in_site(site)
			if not ahead.is_empty():
				left += 1
				can = can or Story.is_open(String(ahead["id"]))
		return UI.C_GREEN if left == 0 else (UI.C_GOLD if can else UI.C_FAINT)
	return UI.C_BONE


## Secrets per name: [found, all] of the finds (without an errand) of the places it stands for.
func _secrets(text: String) -> Array:
	var found := 0
	var all := 0
	for f: Dictionary in Errands.all_finds():
		if f.has("errand") or String(Txt.PLACE_SIGN.get(String(f["place"]), "")) != text:
			continue
		all += 1
		if Save.hub_get("find:" + String(f["id"])) > 0:
			found += 1
	return [found, all]


## Where taken errands send him: world points (finds lying on the wide world) and names (finds elsewhere).
func _errand_marks() -> Array:
	var points: Array = []
	var names := {}
	for r: Dictionary in Errands.active():
		var goal: Dictionary = r.get("goal", {})
		for fid: String in goal.get("finds", []):
			if Save.hub_get("find:" + fid) > 0:
				continue
			var f := Errands.find_row(fid)
			if f.is_empty():
				continue
			if String(f["place"]) == "world":
				points.append(f["pos"])
			elif Txt.PLACE_SIGN.has(String(f["place"])):
				names[String(Txt.PLACE_SIGN[String(f["place"])])] = true
	return [points, names]


func _make_woods() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for g: Dictionary in _world.get("groves", []):
		if float(g.get("solid", 0.0)) <= 0.0:
			continue
		var r: Rect2 = g["rect"]
		var n := mini(int(g.get("n", 10)), 60)
		for i in n:
			_dots.append([r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), rng.randf_range(10.0, 22.0), rng.randf_range(0.0, 1.0)])


# ------------------------------------------------------------------ drawing
func _scale() -> float:
	var wsize: Vector2 = _world.get("size", Vector2(2000, 1400))
	return minf(_map.size.x / wsize.x, _map.size.y / wsize.y) * float(ZOOMS[_zoom_i])


func _to_map(p: Vector2) -> Vector2:
	return (p - _centre) * _scale() + _map.size * 0.5


func _clamp_centre() -> void:
	var wsize: Vector2 = _world.get("size", Vector2(2000, 1400))
	var half := _map.size * 0.5 / maxf(_scale(), 0.001)
	_centre.x = clampf(_centre.x, minf(half.x, wsize.x * 0.5), maxf(wsize.x - half.x, wsize.x * 0.5))
	_centre.y = clampf(_centre.y, minf(half.y, wsize.y * 0.5), maxf(wsize.y - half.y, wsize.y * 0.5))


func _draw_map() -> void:
	if _map.size.x < 8.0:
		return
	_clamp_centre()
	var ci := _map.get_canvas_item()
	var k := _scale()
	var wsize: Vector2 = _world.get("size", Vector2(2000, 1400))
	var lands: Array = UI.C_LAND
	# the land: grass under everything, then the sand and rock regions
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.03, 0.035, 0.05, 1.0))
	_map.draw_rect(Rect2(_to_map(Vector2.ZERO), wsize * k), lands[0])
	for reg: Array in _world.get("regions", []):
		var art := String(reg[0])
		var col: Color = lands[2] if art.contains("rock") else (lands[1] if art.contains("sand") else lands[0].darkened(0.1))
		var pts := PackedVector2Array()
		for p: Vector2 in reg[1]:
			pts.append(_to_map(Vector2(clampf(p.x, 0, wsize.x), clampf(p.y, 0, wsize.y))))
		if pts.size() >= 3:
			_map.draw_colored_polygon(pts, col)
	for w: Variant in _world.get("water", []):
		# water: {"at": centre, "radius": radii} (places.gd)
		if not (w is Dictionary and (w as Dictionary).has("at")):
			continue
		var c: Vector2 = w["at"]
		var rad: Vector2 = w.get("radius", Vector2(20, 10))
		_map.draw_set_transform(_to_map(c), 0.0, Vector2(1.0, rad.y / maxf(rad.x, 1.0)))
		_map.draw_circle(Vector2.ZERO, rad.x * k, Color(0.22, 0.34, 0.46))
		_map.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the woods: soft dark clumps
	for d: Array in _dots:
		_map.draw_circle(_to_map(d[0]), float(d[1]) * k, Color(0.12, 0.2, 0.12, 0.35 + 0.25 * float(d[2])))
	# a soft vignette inside the edge of the world
	var edge := Rect2(_to_map(Vector2.ZERO), wsize * k)
	for i in 6:
		_map.draw_rect(edge.grow(-i * 3.0 * k * 4.0), Color(0, 0, 0, 0.06), false, 6.0 * k * 4.0)
	_map.draw_rect(edge, Color(UI.C_BRASS, 0.6), false, 1.0)
	# roads: dotted brass
	for line: Array in (_world.get("paths", []) as Array) + (_world.get("trails", []) as Array):
		_dotted(line, k)
	# errand marks, names, the story ring, the knight
	var marks := _errand_marks()
	for p: Vector2 in marks[0]:
		var at := _to_map(p)
		_map.draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), UI.C_EMBER, 2.0, true)
		_map.draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), UI.C_EMBER, 2.0, true)
	var goal := String(Txt.STEP_SIGN[mini(Tale.step(), Txt.STEP_SIGN.size() - 1)]) if Tale.on() else ""
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var fsize := 8 if not _ph else 7
	for s: Dictionary in _world.get("signs", []):
		var text := String(s["text"])
		var at := _to_map(s["pos"])
		var known := _known(s)
		var col := _sign_colour(s) if known else UI.C_FAINT
		var r := UI.rs_map_tag(ci, at, text if known else String(Txt.WORDS["map_unknown"]), col, fsize, true)
		if text == goal:                 # the brass ring round the marker of the place the story goes to
			var mk := Vector2(r.position.x + 6.0, at.y)
			_map.draw_arc(mk, 9.0 + 2.0 * pulse, 0.0, TAU, 40, Color(UI.C_GOLD, 0.6 + 0.4 * pulse), 2.0, true)
			_map.draw_arc(mk, 13.0 + 3.0 * pulse, 0.0, TAU, 40, Color(UI.C_BRASS, 0.3), 1.0, true)
		var sec := _secrets(text)
		if known and int(sec[1]) > 0:
			# the secrets found there, on a small wash under the plate's middle
			var st := String(Txt.WORDS["map_secrets"]) % [int(sec[0]), int(sec[1])]
			var sw := UI.font_body.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			var sp := Vector2(roundf(r.get_center().x - sw * 0.5), r.end.y + fsize + 1.0)
			_map.draw_rect(Rect2(sp + Vector2(-3, -fsize), Vector2(sw + 6, fsize + 3)), Color(UI.C_WASH, 0.55))
			UI.font_body.draw_string(ci, sp, st, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
				UI.C_GOOD if int(sec[0]) >= int(sec[1]) else UI.C_DIM)
		if (marks[1] as Dictionary).has(text):
			UI.rs_flame(ci, Vector2(r.end.x + 6.0, at.y), 1.0)
	# the knight: a pulsing ember
	var kat := _to_map(_knight)
	for i in 5:
		_map.draw_circle(kat, (9.0 - i * 1.5) * (0.8 + 0.4 * pulse), Color(1.0, 0.6, 0.25, 0.08 + i * 0.03))
	_map.draw_circle(kat, 3.2, UI.C_INK)
	_map.draw_circle(kat, 2.4, UI.C_EMBER)
	_map.draw_circle(kat, 1.0, Color(1, 0.95, 0.75))


func _dotted(line: Array, k: float) -> void:
	var step := 14.0
	var carry := 0.0
	for i in range(1, line.size()):
		var a: Vector2 = line[i - 1]
		var b: Vector2 = line[i]
		var seg := a.distance_to(b)
		var d := carry
		while d < seg:
			var p := _to_map(a.lerp(b, d / seg))
			_map.draw_circle(p, maxf(1.2, 3.0 * k), Color(UI.C_BRASS, 0.85))
			d += step
		carry = d - seg


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _map == null:
		return
	_t += delta
	var dir := Vector2.ZERO
	for pair: Array in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if InputMap.has_action(String(pair[0])) and Input.is_action_pressed(String(pair[0])):
			dir += pair[1]
	if dir != Vector2.ZERO:
		_centre += dir.normalized() * PAN_SPEED * delta / float(ZOOMS[_zoom_i])
	_map.queue_redraw()


# ------------------------------------------------------------------ input
func _zoom(by: int, around := Vector2.INF) -> void:
	var was := _zoom_i
	_zoom_i = clampi(_zoom_i + by, 0, ZOOMS.size() - 1)
	if was == _zoom_i:
		return
	Sfx.play("ui_click")
	if _zoom_i > 0 and was == 0:
		_centre = _knight if around == Vector2.INF else around
	elif around != Vector2.INF:
		_centre = around


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_instance_valid(_dialog):
		return
	var by := 0
	if InputMap.has_action("page_next") and event.is_action_pressed("page_next"):
		by = 1
	elif InputMap.has_action("page_prev") and event.is_action_pressed("page_prev"):
		by = -1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			by = 1
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			by = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		on_back()
		return
	if by != 0:
		get_viewport().set_input_as_handled()
		_zoom(by)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var at := (mb.position - _map.size * 0.5) / _scale() + _centre
			_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, at)
			_map.accept_event()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _drag:
		_centre -= (event as InputEventMouseMotion).relative / _scale()
	elif event is InputEventScreenDrag:
		_centre -= (event as InputEventScreenDrag).relative / _scale()
