extends Control
## UiRoot: the one root Control of a CanvasLayer on the UI grid (made by UI.attach(layer)).
## It scales its layer so that one UI px = `px` screen px, and is itself as big as the screen in
## UI px, so children anchor to it as usual. Refits on window size changes and on UI.refit_all().
## Do not move or anchor it; never set its layer's scale yourself.

## The layer it scales (set by UI.attach).
var layer: CanvasLayer
## Screen px per UI px (p), and screen px per game px (s).
var px := 1.0
var stretch := 1.0
## Emitted after every refit (size or px changed).
signal refitted


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_root", true)
	add_to_group("ui_root")


func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()


func fit() -> void:
	if not is_inside_tree():
		return
	var ui: GDScript = load("res://scripts/ui/theme.gd")
	var g: Vector2 = ui.call("grid_scale", get_tree())
	px = g.x
	stretch = g.y
	if is_instance_valid(layer):
		layer.scale = Vector2.ONE * (px / stretch)
	# Text is drawn on the UI grid, so its glyphs are made at px (one glyph pixel = one screen
	# pixel). Left to the stretch, they were made at `stretch` and shrunk with nearest sampling,
	# which dropped the hairlines of the Cinzel heads (the E bars, the T crossbar) on PC.
	var vp := get_tree().root
	if vp != null and not bool(ui.call("is_phone")):
		vp.oversampling_override = px
	elif vp != null:
		vp.oversampling_override = 0.0
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = (Vector2(get_tree().root.size) / px).floor()
	refitted.emit()
