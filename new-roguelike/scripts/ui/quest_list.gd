extends PanelContainer
## The quest list in the top-left corner: what to do next in the story, then the Druid's quests
## with how far each one is. The HUD shows it in a level (under the hearts) and the camp shows it
## too (scripts/hub/hub.gd), where it also says how many coins are in the camp chest.
## It reads everything itself, twice a second: scripts/data/story.gd and scripts/data/quests.gd.

const UI = preload("res://scripts/ui/theme.gd")
const Quests = preload("res://scripts/data/quests.gd")
const Story = preload("res://scripts/data/story.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const WIDTH := 126.0

var in_camp := false
var _box: VBoxContainer
var _shown := ""
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.04, 0.04, 0.07, 0.45)
	plate.content_margin_left = 3
	plate.content_margin_right = 3
	plate.content_margin_top = 1
	plate.content_margin_bottom = 2
	add_theme_stylebox_override("panel", plate)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", -2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.5:
		_t = 0.0
		refresh()


func refresh() -> void:
	var lines: Array = []          # [text, colour]
	var run: Node = G.run
	var level: Dictionary = {}
	if is_instance_valid(run) and run.get("level") is Dictionary:
		level = run.get("level")
	if is_instance_valid(run) and run.get("training") == true:
		lines.append(["Train. Pause to go back.", UI.C_GOLD])
	elif not level.is_empty():
		if level.has("champion"):
			lines.append(["Beat the champion of " + String(level.get("name", "the grove")), UI.C_GOLD])
		else:
			var boss := String(Bosses.info(String(level.get("boss", ""))).get("name", "the guardian"))
			lines.append(["Beat " + boss, UI.C_GOLD])
	elif in_camp:
		var next := Story.next_level()
		lines.append(["Go down: " + String(next["name"]) if not next.is_empty() else "The hill is quiet", UI.C_GOLD])
	# in the middle of a fight only the goal is shown, so the list never hides a monster
	var room: Variant = run.get("room") if is_instance_valid(run) else null
	var fighting: bool = is_instance_valid(room) and room.get("fighting") == true
	for q: Dictionary in ([] if fighting else Quests.offered() + Quests.side_active()):
		if Quests.complete(q):
			lines.append([String(q["name"]) + ": done!", UI.C_GREEN])
		else:
			lines.append(["%s %d/%d" % [q["name"], Quests.progress(q), int(q["need"])], UI.C_BONE])
	if in_camp:
		lines.append(["Camp chest: %d coins" % Upgrades.coins(), UI.C_DIM])
	var key := str(lines)
	if key == _shown:
		return
	_shown = key
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head := UI.label("Quests", "Small")
	head.add_theme_color_override("font_color", UI.C_FAINT)
	_box.add_child(head)
	for line: Array in lines:
		var lab := UI.label(String(line[0]), "Small")
		lab.add_theme_color_override("font_color", line[1])
		lab.custom_minimum_size.x = WIDTH
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART       # a long line folds, it is never cut off
		_box.add_child(lab)
	visible = not lines.is_empty()
	size = Vector2.ZERO               # shrink to what is shown now
	reset_size.call_deferred()
