extends Control
## Item rack: a row of item pictures in pickup order that wraps onto more rows.
## Item pictures are 16 px (assets/art/icons/) and are shown at their real pixel size, so a row is
## 16 px high; what does not fit in max_rows rows is summed up as "+N".
## Used on the HUD (bottom left), the end screen and the pause screen.
##   rack.set_items(["whetstone", "swift_tonic"], 200.0, 2)

const UI = preload("res://scripts/ui/theme.gd")
const Items = preload("res://scripts/data/items.gd")
const Icon = preload("res://scripts/ui/icon.gd")

const ROW := 16.0       ## height of one row (an item picture is 16 px)
const GAP := 2.0

## true: the first row is at the bottom and later rows stack upwards (HUD).
var grow_up := false
## true: each row is centred in the given width (end screen).
var centred := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows these item ids. Items that do not fit in max_rows rows are summed up as "+N".
func set_items(ids: Array, width: float, max_rows: int) -> void:
	for c in get_children():
		c.queue_free()
	var rows: Array = [[]]
	var x := 0.0
	var shown := 0
	for id: Variant in ids:
		var ic := Icon.new()
		ic.setup(String(Items.info(String(id)).get("icon", "skull")), Vector2.ZERO, ROW)
		if x + ic.size.x > width and x > 0.0:
			if rows.size() >= max_rows:
				ic.free()
				break
			rows.append([])
			x = 0.0
		ic.position.x = x
		rows[rows.size() - 1].append(ic)
		x += ic.size.x + GAP
		shown += 1
	if shown < ids.size():
		# make room for the "+N" at the end of the last row
		var more := UI.label("+%d" % (ids.size() - shown), "Hud")
		var need := more.get_minimum_size().x + 2.0
		var last: Array = rows[rows.size() - 1]
		while not last.is_empty() and (last.back() as Control).position.x + (last.back() as Control).size.x + GAP + need > width:
			(last.pop_back() as Control).free()
			shown -= 1
		more.text = "+%d" % (ids.size() - shown)
		more.size = Vector2(need, ROW)
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.position.x = 0.0 if last.is_empty() else (last.back() as Control).position.x + (last.back() as Control).size.x + GAP
		last.append(more)
	for r in rows.size():
		var row: Array = rows[r]
		var y := -r * (ROW + 1.0) if grow_up else r * (ROW + 1.0)
		var shift := 0.0
		if centred and not row.is_empty():
			var last_c: Control = row.back()
			shift = roundf((width - (last_c.position.x + last_c.size.x)) / 2.0)
		for c: Control in row:
			c.position = Vector2(c.position.x + shift, y)
			add_child(c)
	var height := rows.size() * (ROW + 1.0) - 1.0
	custom_minimum_size = Vector2(0, height)
	size = Vector2(width, height)
