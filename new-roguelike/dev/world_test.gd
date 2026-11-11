extends Node
## World test scene: starts a run straight away (no menus) so rooms, fights and content can be
## tested without the menu half of the game. Run it with:
##   godot --path . res://dev/world_test.tscn -- --hero=knight --seed=7
## Add --autotest to let the bot play (see scripts/run/bot.gd), --validate to only check the data
## tables (layouts, items, enemies ...) and quit. The text at the top is a debug read-out, not
## the real HUD (that lives in scripts/ui).

const Validate = preload("res://dev/validate.gd")

var run: Node
var info: Label
var toast: Label
var _toast_t := 0.0
var _quit_at := 0.0


func _ready() -> void:
	if G.flag("validate") or G.flag("checkscripts"):
		var problems := Validate.check_scripts()
		if G.flag("validate"):
			problems.append_array(Validate.all())
		for p in problems:
			print("ERROR: data check: " + p)
		print("VALIDATE %s (%d problems)" % ["OK" if problems.is_empty() else "FAILED", problems.size()])
		get_tree().quit(0 if problems.is_empty() else 1)
		return
	_build_hud()
	G.hud_changed.connect(_refresh)
	G.room_entered.connect(func(_c: Vector2i, _t: int, _f: bool) -> void: _refresh())
	G.toast.connect(_on_toast)
	G.item_acquired.connect(func(id: String) -> void:
		var item: Dictionary = load("res://scripts/data/items.gd").info(id)
		_on_toast(String(item["name"]), String(item["desc"])))
	G.run_ended.connect(_on_run_ended)
	_start_run(int(G.arg("seed", "1")))
	if not G.flag("autotest") and G.arg("time") != "":
		_quit_at = float(G.arg("time"))


func _start_run(run_seed: int) -> void:
	run = load("res://scripts/run/run.gd").new()
	add_child(run)
	run.setup(G.arg("hero", "knight"), run_seed)
	_refresh()


func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	print("RUN ENDED victory=%s %s" % [victory, summary])
	if G.flag("autotest"):
		return      # the bot restarts the run by itself
	_on_toast("VICTORY" if victory else "YOU DIED", "a new run starts in a moment")
	await get_tree().create_timer(2.5).timeout
	var next_seed: int = run.seed_value + 1
	run.queue_free()
	await get_tree().process_frame
	_start_run(next_seed)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = G.LAYER_HUD
	add_child(layer)
	info = Label.new()
	info.position = Vector2(4, 1)
	info.add_theme_font_size_override("font_size", 8)
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	info.add_theme_constant_override("outline_size", 3)
	layer.add_child(info)
	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.position.y = 14
	toast.add_theme_font_size_override("font_size", 8)
	toast.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	toast.add_theme_constant_override("outline_size", 3)
	layer.add_child(toast)


func _on_toast(title: String, subtitle: String) -> void:
	toast.text = title if subtitle == "" else "%s\n%s" % [title, subtitle]
	_toast_t = 2.5


func _refresh() -> void:
	if run == null or not is_instance_valid(run) or run.player == null:
		return
	var p: Node = run.player
	var text := "HP %d/%d" % [p.hp, p.max_hp]
	if p.armor > 0:
		text += " +%d" % p.armor
	var here: Dictionary = run.rooms.get(run.cur, {})
	text += "   coins %d   keys %d   bombs %d   floor %d %s   %s" % [p.coins, p.keys, p.bombs, run.floor_index + 1, run.floor_name,
		run.TYPE_NAMES[int(here.get("type", 0))]]
	if not p.items.is_empty():
		text += "\n" + ", ".join(p.items)
	info.text = text


func _process(delta: float) -> void:
	if toast != null and _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.text = ""
	if _quit_at > 0.0 and run != null and is_instance_valid(run) and run.time_s >= _quit_at:
		get_tree().quit(0)
