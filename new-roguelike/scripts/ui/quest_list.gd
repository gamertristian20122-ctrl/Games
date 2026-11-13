extends PanelContainer
## The story line / quest list in the top-left corner.
## IN A WALKING PLACE (in_camp = true; scripts/hub/hub.gd, on its UI grid): the HD "story line"
## (spec 6.3): no box, a wash fading out to the right, "CHAPTER ONE · THE ELFWOOD" in small brass
## Cinzel with a rule, then a gold lozenge and the story's next step (Tale.STEPS, body 13, two lines,
## ink outline). Under it, small and dim: beacons lit, or (old story) where the level is and the
## Druid's quests. hub.gd fades it to half while the knight walks (`modulate`).
## IN A LEVEL (old runs; scripts/ui/hud.gd): the old list under the hearts: the goal, then the
## Druid's quests with how far each one is.
## It reads everything itself, twice a second: scripts/data/tale.gd, story.gd and quests.gd.
## The chapter heading words are CHAPTERS below (from the step the chapter starts at).

const UI = preload("res://scripts/ui/theme.gd")
const Quests = preload("res://scripts/data/quests.gd")
const Story = preload("res://scripts/data/story.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Upgrades = preload("res://scripts/data/upgrades.gd")
const Tale = preload("res://scripts/data/tale.gd")
const WIDTH := 126.0
## The heading over the story line: [first step of the chapter, "Chapter ...", "The land"].
const CHAPTERS := [[0, "Chapter One", "The Elfwood"], [7, "Chapter Two", "The Sands"]]

var in_camp := false
var goal_only := false           ## the world map: only where to go next, so the list hides little of the map
var _box: VBoxContainer
var _story: Control              ## the walking places' story line (in_camp)
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
	if in_camp:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_box.visible = false
		_story = StoryLine.new()
		add_child(_story)
	refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.5:
		_t = 0.0
		refresh()


## The heading for the step the story is at: "CHAPTER ONE  ·  THE ELFWOOD".
static func chapter_heading(step: int) -> String:
	var head: Array = CHAPTERS[0]
	for row: Array in CHAPTERS:
		if step >= int(row[0]):
			head = row
	return "%s  ·  %s" % [head[1], head[2]]


func refresh() -> void:
	var lines: Array = []          # [text, colour]
	var run: Node = G.run
	var level: Dictionary = {}
	if is_instance_valid(run) and run.get("level") is Dictionary:
		level = run.get("level")
	var head := ""
	var goal := ""
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
		head = chapter_heading(Tale.step())
		goal = Tale.objective()                                   # the story's next step (scripts/data/tale.gd)
		lines.append(["Next: " + goal, UI.C_GOLD])
		if Tale.beacons() > 0 and not goal_only:
			lines.append(["Beacons lit: %d of 4" % Tale.beacons(), UI.C_DIM])
	elif in_camp:
		head = "The hill"
		var next := Story.next_level()
		# the goal names the place to go to: the next level and where its gate is
		if next.is_empty():
			goal = "The land is quiet"
			lines.append([goal, UI.C_GOLD])
		else:
			goal = "Next: " + String(next["name"])
			lines.append([goal, UI.C_GOLD])
			var at := "at " + String((Story.SITES.get(String(next.get("site", "hill")), {}) as Dictionary).get("name", ""))
			lines.append([at, UI.C_DIM])
			goal += ", " + at
	# in the middle of a fight only the goal is shown, so the list never hides a monster
	var room: Variant = run.get("room") if is_instance_valid(run) else null
	var fighting: bool = is_instance_valid(room) and room.get("fighting") == true
	for q: Dictionary in ([] if fighting or goal_only or (in_camp and Tale.on()) else Quests.offered() + Quests.side_active()):
		if Quests.complete(q):
			lines.append([String(q["name"]) + ": done!", UI.C_GREEN])
		else:
			lines.append(["%s %d/%d" % [q["name"], Quests.progress(q), int(q["need"])], UI.C_BONE])
	# (the coins of a walking place are in the top-right corner: hub.gd)
	var key := str(lines) + head
	if key == _shown:
		return
	_shown = key
	if in_camp:
		# the story line: the goal big, the rest (lines after the first) small and dim
		var extra: Array = []
		for i in range(1, lines.size()):
			if not (not Tale.on() and i == 1):          # (old story: "at <site>" is already in the goal)
				extra.append(lines[i])
		_story.call("set_text", head, goal, extra)
		visible = goal != ""
		custom_minimum_size = _story.custom_minimum_size
		size = custom_minimum_size
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head_label := UI.label("Quests", "Small")
	head_label.add_theme_color_override("font_color", UI.C_FAINT)
	_box.add_child(head_label)
	for line: Array in lines:
		var lab := UI.label(String(line[0]), "Small")
		lab.add_theme_color_override("font_color", line[1])
		lab.custom_minimum_size.x = WIDTH
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART       # a long line folds, it is never cut off
		_box.add_child(lab)
	visible = not lines.is_empty()
	size = Vector2.ZERO               # shrink to what is shown now
	reset_size.call_deferred()


## The story line itself (UI px; spec 6.3, phone sizes in _sizes()).
class StoryLine extends Control:
	const UI = preload("res://scripts/ui/theme.gd")
	var head := ""
	var goal := ""
	var extra: Array = []
	var _goal_lines: PackedStringArray = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _sizes() -> Dictionary:
		if UI.is_phone():
			return {"head": 7, "body": 9, "line": 10, "small": 7, "x": 6.0, "head_y": 9.0, "rule_y": 12.0, "rule_w": 92.0,
				"text_y": 21.0, "wrap": 150.0, "wash": Vector2(190, 36), "loz": 2.0, "outline": 2}
		return {"head": 11, "body": 13, "line": 14, "small": 10, "x": 18.0, "head_y": 20.0, "rule_y": 26.0, "rule_w": 200.0,
			"text_y": 42.0, "wrap": 262.0, "wash": Vector2(360, 70), "loz": 2.5, "outline": 3}

	func set_text(h: String, g: String, more: Array) -> void:
		UI._load_fonts()
		var news := goal != "" and g != goal
		head = h.to_upper()
		goal = g
		if news and is_inside_tree() and not UI.instant:
			# a new step of the story: the line fades in again, with a short gold glint
			modulate = Color(1.6, 1.35, 0.9, 0.0)
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color(1.6, 1.35, 0.9, 1.0), 0.25)
			tw.tween_property(self, "modulate", Color.WHITE, 0.6)
		extra = more
		var s := _sizes()
		_goal_lines = _wrap(goal, int(s["body"]), float(s["wrap"]))
		var h_total := float(s["text_y"]) + float(s["line"]) * float(_goal_lines.size() - 1) + float(s["line"]) * 0.45 * float(extra.size() + 1)
		var wash: Vector2 = s["wash"]
		custom_minimum_size = Vector2(wash.x, maxf(wash.y, h_total + 8.0))
		size = custom_minimum_size
		queue_redraw()

	## Splits words into lines no wider than `w` (at most two; the second is trimmed with an ellipsis).
	func _wrap(words: String, fs: int, w: float) -> PackedStringArray:
		var out := PackedStringArray()
		var line := ""
		for word in words.split(" ", false):
			var tryit := word if line == "" else line + " " + word
			if UI.font_body.get_string_size(tryit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w or line == "":
				line = tryit
			else:
				out.append(line)
				line = word
		if line != "":
			out.append(line)
		if out.size() > 2:
			var rest := " ".join(out.slice(1))
			out = PackedStringArray([out[0], rest])
		return out

	func _draw() -> void:
		var s := _sizes()
		var ci := get_canvas_item()
		var wash: Vector2 = s["wash"]
		# the scrim: a soft dark corner, strong at the top left and fading out to the right AND down,
		# so the words read on a bright square as well as in the dark wood
		var strips := 10
		var tall := size.y + (10.0 if UI.is_phone() else 18.0)
		for i in strips:
			var k := float(i) / float(strips)
			var a := 0.86 * (1.0 - k * k)
			UI.rs_hgrad(ci, Rect2(Vector2(0.0, tall * k), Vector2(wash.x * (1.0 - 0.25 * k), tall / strips)), Color(UI.C_WASH, a), Color(UI.C_WASH, 0.0))
		var x: float = s["x"]
		# a brass tick down the left of the words
		var tick_top: float = float(s["rule_y"]) + (3.0 if UI.is_phone() else 5.0)
		var tick_bot: float = size.y - (2.0 if UI.is_phone() else 4.0)
		UI.rs_rule(ci, Vector2(x - (4.0 if UI.is_phone() else 8.0), tick_top), Vector2(x - (4.0 if UI.is_phone() else 8.0), tick_bot), Color(UI.C_BRASS, 0.8), Color(UI.C_BRASS, 0.0), 1.0)
		var ol: int = s["outline"]
		if head != "":
			var hs := int(s["head"])
			draw_string_outline(UI.font_head, Vector2(x, s["head_y"]), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, 3, Color(UI.C_INK, 0.85))
			draw_string(UI.font_head, Vector2(x, s["head_y"]), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, UI.C_GOLD.lerp(UI.C_BRASS, 0.35))
			var ry: float = s["rule_y"]
			UI.rs_rule(ci, Vector2(x, ry + 0.5), Vector2(x + float(s["rule_w"]), ry + 0.5), Color(UI.C_BRASS, 0.6), Color(UI.C_BRASS, 0.0))
		var y: float = s["text_y"]
		var bs := int(s["body"])
		var tx := x + (4.0 if UI.is_phone() else 4.0)
		UI.rs_lozenge(ci, Vector2(x, roundf(y - UI.font_body.get_ascent(bs) * 0.36)), s["loz"], UI.C_GOLD, 0.0)
		for i in _goal_lines.size():
			var line: String = _goal_lines[i]
			var w := -1.0
			if i == _goal_lines.size() - 1 and i > 0:
				w = float(s["wrap"])
			draw_string_outline(UI.font_body, Vector2(tx, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, bs, ol, Color(UI.C_INK, 0.85))
			draw_string(UI.font_body, Vector2(tx, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, bs, UI.C_PARCH)
			y += float(s["line"])
		var ss := int(s["small"])
		for row: Variant in extra:
			var words := String(row[0])
			var col: Color = row[1]
			y += 0.0 if UI.is_phone() else -1.0
			draw_string_outline(UI.font_body, Vector2(tx, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 2, Color(UI.C_INK, 0.8))
			draw_string(UI.font_body, Vector2(tx, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, col)
			y += float(ss) + 2.0
