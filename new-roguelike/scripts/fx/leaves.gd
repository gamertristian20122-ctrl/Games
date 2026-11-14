extends Node3D
## DRIFTING LEAVES AND PETALS (v0.29.0): a few leaves tumble down through the light of the wild places
## and pink petals blow across Wickmere's square. Code-made (a leaf is an ellipse with a vein drawn
## into a small picture; no art, nothing from an AI). view3d.gd makes one per place; it is freed with it.
## Tint follows the day: bright by day, dim at night (a lit leaf in the dark looked like a lamp).

const PX := 1.0 / 16.0

## place id -> [kind, count]. A place not listed has none (the sands, the rooms, the world map).
const WHERE := {
	"village": ["petal", 26], "elfwood": ["leaf", 40], "glade": ["leaf", 34], "deepwood": ["dark", 34], "beacon": ["leaf", 22],
}
const COLOURS := {
	"leaf": [Color(0.55, 0.72, 0.26), Color(0.86, 0.66, 0.22), Color(0.74, 0.44, 0.18)],
	"dark": [Color(0.30, 0.50, 0.46), Color(0.42, 0.36, 0.60), Color(0.26, 0.44, 0.30)],
	"petal": [Color(1.0, 0.80, 0.84), Color(1.0, 0.92, 0.90), Color(0.96, 0.66, 0.76)],
}

var hub: Node2D
var _mat: StandardMaterial3D
var _kind := ""


## Is there anything to show in this place?
static func has(place_id: String) -> bool:
	return WHERE.has(place_id)


func setup(the_hub: Node2D) -> void:
	hub = the_hub
	var row: Array = WHERE[hub.place_id]
	_kind = String(row[0])
	var size: Vector2 = hub.place["size"]
	var p := CPUParticles3D.new()
	p.amount = int(row[1])
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.5 * PX, 0.5, size.y * 0.5 * PX)
	p.position = Vector3(size.x * 0.5 * PX, 5.0, size.y * 0.5 * PX)       # they start up in the air and drift down
	p.direction = Vector3(1.0, -0.2, 0.3)
	p.spread = 40.0
	p.initial_velocity_min = 0.25                                           # a breeze from the west
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.0, -0.32, 0.0)
	p.damping_min = 0.15
	p.damping_max = 0.35
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -140.0
	p.angular_velocity_max = 140.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.25
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = _shape(_kind == "petal")
	_mat.disable_fog = true
	_mat.render_priority = 10
	var q := QuadMesh.new()
	q.size = Vector2(0.30, 0.30) if _kind != "petal" else Vector2(0.20, 0.20)
	q.material = _mat
	p.mesh = q
	# each particle takes one of the kind's colours at random
	var tint := Gradient.new()
	var cols: Array = COLOURS[_kind]
	tint.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	tint.colors = PackedColorArray([cols[0], cols[1], cols[2]])
	p.color_initial_ramp = tint
	add_child(p)


## A leaf (an ellipse with a vein and a stalk) or a petal (a soft teardrop), drawn by code.
static func _shape(petal: bool) -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var a := 0.0
			if petal:
				# teardrop: wide at the top, pointed at the bottom
				var w := clampf(1.0 - (dy + 1.0) * 0.5, 0.0, 1.0) * 0.75 + 0.18
				var d := (dx / maxf(w, 0.05)) * (dx / maxf(w, 0.05)) + dy * dy * 0.85
				a = clampf((1.0 - d) * 4.0, 0.0, 1.0)
				a *= 0.88 + 0.12 * (1.0 - absf(dx))
			else:
				var d := dx * dx / 0.20 + dy * dy / 0.95
				a = clampf((1.0 - d) * 4.0, 0.0, 1.0)
				var vein := 1.0 - 0.38 * exp(-absf(dx) * 26.0) * (1.0 if absf(dy) < 0.85 else 0.0)
				a *= 1.0
				img.set_pixel(x, y, Color(vein, vein, vein, a))
				continue
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if hub == null or _mat == null:
		return
	# by day full colour, in the middle of the night a dim third
	var sky := Color.WHITE
	if is_instance_valid(hub._sky_node):
		sky = (hub._sky_node as CanvasModulate).color
	var bright := clampf((sky.g - 0.55) / 0.45, 0.0, 1.0)
	var k := lerpf(0.3, 1.0, bright)
	_mat.albedo_color = Color(k, k, k, 1.0)
