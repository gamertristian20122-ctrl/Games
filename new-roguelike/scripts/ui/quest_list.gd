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
const Tale = preload("res://scripts/data/tale.gd")
const WIDTH := 126.0
## PC (not a phone): the story panel of the places you walk in is small and quiet, so it never
## covers a quarter of the scene: no heading, letters at a smaller whole multiple of the pixel font
## (`compact_scale`), a soft shade that fades out to the right instead of a box. On a phone it stays
## as it was (the owner: text size on the phone is good as it is).
const PC_WIDTH := 168.0
const PC_TEXT := 0.72          ## the letters are about this much of their phone size (rounded to whole screen pixels)

var in_camp := false
var goal_only := false           ## the world map: only where to go next, so the list hides little of the map
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
	if _compact():
		var shade := Gradient.new()
		# (a solid backing behind the letters, so they read over a bright square; it only fades in
		# the last few pixels past the longest line)
		shade.offsets = PackedFloat32Array([0.0, 0.86, 1.0])
		shade.colors = PackedColorArray([Color(0.03, 0.03, 0.05, 0.76), Color(0.03, 0.03, 0.05, 0.7), Color(0.03, 0.03, 0.05, 0.0)])
		var grad := GradientTexture2D.new()
		grad.gradient = shade
		grad.width = 64
		grad.height = 4
		var plate := StyleBoxTexture.new()
		plate.texture = grad
		plate.content_margin_left = 4
		plate.content_margin_right = 14
		plate.content_margin_top = 2
		plate.content_margin_bottom = 3
		add_theme_stylebox_override("panel", plate)
		get_viewport().size_changed.connect(_fit_scale)
		_fit_scale()
	refresh()


## The walking places' panel on a PC (see PC_WIDTH).
func _compact() -> bool:
	return in_camp and not OS.has_feature("mobile") and not G.flag("touch")


## Letters stay crisp: each pixel of the font covers a whole number of screen pixels.
func _fit_scale() -> void:
	var cs := get_viewport().get_final_transform().x.x if is_inside_tree() else 1.0
	if cs <= 0.0:
		return
	var px := maxf(2.0, roundf(cs * PC_TEXT))
	var k := minf(px / cs, 1.0)
	scale = Vector2(k, k)


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
	elif bool(level.get("encounter", false)):
		lines.append(["Win the fight", UI.C_GOLD])
	elif not level.is_empty():
		if level.has("champion"):
			lines.append(["Beat the champion of " + String(level.get("name", "the grove")), UI.C_GOLD])
		else:
			var boss := String(Bosses.info(String(level.get("boss", ""))).get("name", "the guardian"))
			if run.has_method("needs_boss_key") and run.call("needs_boss_key"):
				lines.append(["Find the boss key", UI.C_GOLD])       # the boss door is sealed (run.gd "keys")
			else:
				lines.append(["Beat " + boss, UI.C_GOLD])
	elif in_camp and Tale.on():
		lines.append(["Next: " + Tale.objective(), UI.C_GOLD])      # the story's next step (scripts/data/tale.gd)
		if Tale.beacons() > 0:
			lines.append(["Beacons lit: %d of 4" % Tale.beacons(), UI.C_BONE])
	elif in_camp:
		var next := Story.next_level()
		# the goal names the place to go to: the next level and where its gate is
		if next.is_empty():
			lines.append(["The land is quiet", UI.C_GOLD])
		else:
			lines.append(["Next: " + String(next["name"]), UI.C_GOLD])
			lines.append(["at " + String((Story.SITES.get(String(next.get("site", "hill")), {}) as Dictionary).get("name", "")), UI.C_DIM])
	# in the middle of a fight only the goal is shown, so the list never hides a monster
	var room: Variant = run.get("room") if is_instance_valid(run) else null
	var fighting: bool = is_instance_valid(room) and room.get("fighting") == true
	for q: Dictionary in ([] if fighting or goal_only or (in_camp and Tale.on()) else Quests.offered() + Quests.side_active()):
		if Quests.complete(q):
			lines.append([String(q["name"]) + ": done!", UI.C_GREEN])
		else:
			lines.append(["%s %d/%d" % [q["name"], Quests.progress(q), int(q["need"])], UI.C_BONE])
	if in_camp and not goal_only:
		lines.append([("Coins: %d" if Tale.on() else "Camp chest: %d coins") % Upgrades.coins(), UI.C_GOLD])
	var key := str(lines)
	if key == _shown:
		return
	_shown = key
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var compact := _compact()
	if not compact:
		var head := UI.label("Story" if in_camp and Tale.on() else "Quests", "Small")
		head.add_theme_color_override("font_color", UI.C_FAINT)
		_box.add_child(head)
	for line: Array in lines:
		var lab := UI.label(String(line[0]), "Small")
		lab.add_theme_color_override("font_color", line[1])
		lab.custom_minimum_size.x = PC_WIDTH if compact else WIDTH
		if compact:
			# a thin dark outline instead of a box: it reads on bright ground and dark alike
			lab.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
			lab.add_theme_constant_override("outline_size", 2)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART       # a long line folds, it is never cut off
		_box.add_child(lab)
	visible = not lines.is_empty()
	size = Vector2.ZERO               # shrink to what is shown now
	reset_size.call_deferred()
