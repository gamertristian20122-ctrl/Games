extends Node
## LOOK TEST for the turn-based battles (12 Nov 2026). The owner showed a "pixel people in a lit 3D
## world" game and asked for that level of look, then turn-based fights. This screen is the first
## step: ONE battle scene in the new look, to judge on the phone before anything else is changed.
## NOTHING FIGHTS YET: the menu is a picture of where the buttons will be.
## Opened from the title ("Battle look (test)") or with `--look` (and `--shots=<dir>` for a picture).
## When the real battle is built, it takes this file's place and the title button goes.

signal finished

const Stage = preload("res://scripts/battle/stage.gd")
const UI = preload("res://scripts/ui/theme.gd")
const Enemies = preload("res://scripts/data/enemies.gd")

## Who stands where. Words are placeholders the owner may rewrite.
const PARTY := [
	{"name": "Aldous", "sprite": "pc_knight", "at": Vector3(-3.1, 0.0, 0.5), "hp": [46, 52], "mp": [12, 20]},
	{"name": "Seraphine", "sprite": "pc_scholar_censor", "at": Vector3(-4.9, 0.0, -0.9), "hp": [31, 34], "mp": [38, 44]},
]
const FOES := [
	{"id": "thorn_elf", "at": Vector3(2.5, 0.0, 1.0)},
	{"id": "wood_beast", "at": Vector3(4.6, 0.0, -0.5)},
	{"id": "sporeling", "at": Vector3(6.3, 0.0, 0.9)},
]
const COMMANDS := ["Attack", "Skills", "Guard", "Items"]

var stage: Node3D
var _layer: CanvasLayer
var _root: Control
var _tags: Array = []            ## [Control, world point]: name plates that follow a monster
var _fps: Label
var _t := 0.0
var _frames := 0
var _cam_home := Vector3.ZERO


func _ready() -> void:
	stage = Stage.new()
	add_child(stage)
	stage.build("forest")
	_cam_home = stage.cam.position
	for p: Dictionary in PARTY:
		stage.stand(String(p["sprite"]), p["at"])
	for f: Dictionary in FOES:
		stage.stand(String(Enemies.ALL[String(f["id"])]["sprite"]), f["at"], true)
	_build_menu()


func _build_menu() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	var safe := UI.safe_margin(_root, 5)
	_root.add_child(safe)
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(area)

	# who acts next (top left)
	var order := UI.hbox(2)
	order.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	area.add_child(order)
	var turn_ids := ["pc_knight", "pc_elf_base", "pc_scholar_censor", "pc_elf_hunter", "pc_fungus_immature"]
	for i in turn_ids.size():
		var slot := UI.panel("slot_focus" if i == 0 else "slot")
		slot.custom_minimum_size = Vector2(17, 17)
		var face := TextureRect.new()
		face.texture = _face(String(turn_ids[i]))
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.custom_minimum_size = Vector2(13, 13)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
		order.add_child(slot)

	# back, and what this screen is (top right)
	var top := UI.vbox(2)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	area.add_child(top)
	var back := UI.button("Back", func() -> void: finished.emit(), "", "ui_back")
	back.custom_minimum_size = Vector2(46, 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(back)
	var note := UI.label("Look test: nothing fights yet", "Small")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.add_theme_color_override("font_outline_color", UI.C_INK)
	note.add_theme_constant_override("outline_size", 3)
	top.add_child(note)
	_fps = UI.label("", "Small")
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.add_theme_color_override("font_outline_color", UI.C_INK)
	_fps.add_theme_constant_override("outline_size", 3)
	top.add_child(_fps)

	# the party (bottom left)
	var party := UI.panel("panel")
	party.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	party.grow_vertical = Control.GROW_DIRECTION_BEGIN
	area.add_child(party)
	var rows := UI.vbox(3)
	party.add_child(rows)
	for p: Dictionary in PARTY:
		var row := UI.hbox(5)
		var name_label := UI.label(String(p["name"]), "Hud")
		name_label.custom_minimum_size.x = 50
		row.add_child(name_label)
		row.add_child(_bar("HP", p["hp"], UI.C_RED))
		row.add_child(_bar("MP", p["mp"], UI.C_BLUE))
		rows.add_child(row)

	# the orders (bottom right)
	var orders := UI.panel("panel")
	orders.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	orders.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	orders.grow_vertical = Control.GROW_DIRECTION_BEGIN
	area.add_child(orders)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	orders.add_child(grid)
	for i in COMMANDS.size():
		var b := UI.button(String(COMMANDS[i]))
		b.custom_minimum_size = Vector2(52, 19)
		grid.add_child(b)
		if i == 0:
			b.grab_focus.call_deferred()

	# a life bar over each monster, and the name of the one being aimed at (the first)
	for i in FOES.size():
		var f: Dictionary = FOES[i]
		var row: Dictionary = Enemies.ALL[String(f["id"])]
		var tag := UI.vbox(1)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			var l := UI.label(String(row["name"]), "Small")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_color", UI.C_GOLD)
			l.add_theme_color_override("font_outline_color", UI.C_INK)
			l.add_theme_constant_override("outline_size", 3)
			tag.add_child(l)
		var life := ColorRect.new()
		life.color = UI.C_RED
		life.custom_minimum_size = Vector2(22, 2)
		life.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag.add_child(life)
		_root.add_child(tag)
		var m := Art.meta(String(row["sprite"]))
		_tags.append([tag, (f["at"] as Vector3) + Vector3(0.0, (float(m.get("body_height", 30.0)) + 5.0) / 16.0, 0.0)])


## A label and a bar: "HP 46/52".
func _bar(word: String, now_max: Array, colour: Color) -> Control:
	var box := UI.vbox(1)
	var text := UI.label("%s %d/%d" % [word, int(now_max[0]), int(now_max[1])], "Small")
	text.add_theme_color_override("font_color", UI.C_BONE)
	box.add_child(text)
	var back := ColorRect.new()
	back.color = UI.C_PANEL_LOW
	back.custom_minimum_size = Vector2(44, 3)
	box.add_child(back)
	var fill := ColorRect.new()
	fill.color = colour
	fill.size = Vector2(44.0 * float(now_max[0]) / float(now_max[1]), 3)
	back.add_child(fill)
	return box


## The head of a fighter for the turn order: the top of the first frame of the pack art.
func _face(sprite_id: String) -> Texture2D:
	var tex := Art.tex(sprite_id)
	var used := UI.used_rect(sprite_id)
	var side := minf(used.size.x, used.size.y * 0.6)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(used.position.x + (used.size.x - side) * 0.5, used.position.y, side, side)
	return at


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	# the camera breathes a little from side to side: it shows the depth of the place
	if not G.flag("shots"):
		stage.cam.position = _cam_home + Vector3(sin(_t * 0.25) * 0.5, 0.0, 0.0)
		stage.cam.look_at(Vector3(0.0, 1.3, -1.0), Vector3.UP)
	for pair: Array in _tags:
		var tag: Control = pair[0]
		var p: Vector2 = stage.cam.unproject_position(pair[1])
		tag.position = (p - Vector2(tag.size.x * 0.5, tag.size.y)).round()
	if _frames % 20 == 0:
		_fps.text = "%d fps" % int(Engine.get_frames_per_second())
	if _frames == 50 and G.arg("shots", "") != "" and G.flag("look"):
		var dir := G.arg("shots", "")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(dir.path_join("look.png"))
		G.quit(0)
