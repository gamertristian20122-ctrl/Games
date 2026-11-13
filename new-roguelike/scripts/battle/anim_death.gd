extends MultiMeshInstance3D
## A FALLEN MONSTER BREAKS INTO ITS OWN PIXELS (battles). The picture on show at the moment it
## falls is read pixel by pixel (computed from the pack's art: nothing new is drawn) and every pixel,
## or every 2 x 2 block of a big picture, becomes a small square of that colour that is flung out,
## glows hot for a moment, falls, bounces once on the ground and fades.
##   var s = Shatter.new(); stage.add_child(s); s.burst(sprite3_node, from_x, power)
## `from_x` is where the blow came from (the pixels fly away from it); `power` 1 = a monster, 2 = a boss.

const Hd = preload("res://scripts/fx/hd.gd")
const PX := 1.0 / 16.0
const MAX_BITS := 520

var _bits: Array = []             ## {"p": Vector3, "v": Vector3, "c": Color, "s": float, "spin": float, "bounced": bool}
var _t := 0.0
var _life := 1.3
var _mat: StandardMaterial3D


func burst(sprite: MeshInstance3D, from_x: float, power: float = 1.0, tall: float = 1.0) -> void:
	var tex: Texture2D = sprite.call("texture_now")
	if tex == null:
		queue_free()
		return
	var img := tex.get_image()
	if img == null:
		queue_free()
		return
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var flipped := bool(sprite.call("is_flipped"))
	var quad := (sprite as MeshInstance3D).mesh as QuadMesh
	# the picture's bottom-left corner in the world (the quad is centred on center_offset)
	var origin: Vector3 = sprite.global_position
	var scale_now: Vector3 = sprite.global_transform.basis.get_scale()
	var c0 := quad.center_offset
	var size := quad.size
	var left := origin.x + (c0.x - size.x * 0.5) * scale_now.x
	var bottom := origin.y + (c0.y - size.y * 0.5) * scale_now.y
	var px_w := size.x / float(w) * scale_now.x
	var px_h := size.y / float(h) * scale_now.y
	# count the solid pixels first, to pick the block size that keeps the count sane
	var solid := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				solid += 1
	var block := 1
	while solid / (block * block) > MAX_BITS:
		block += 1
	var mid := Vector3(left + size.x * scale_now.x * 0.5, bottom + size.y * scale_now.y * 0.45, origin.z)
	var away := signf(mid.x - from_x) if absf(mid.x - from_x) > 0.01 else 1.0
	for y in range(0, h, block):
		for x in range(0, w, block):
			var c := img.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var sx := (w - 1 - x) if flipped else x
			var p := Vector3(left + (float(sx) + block * 0.5) * px_w, bottom + (float(h - y) - block * 0.5) * px_h, origin.z + randf_range(-0.05, 0.05))
			var out := (p - mid)
			out.z = 0.0
			var v := out.normalized() * randf_range(1.2, 3.6) * (0.7 + 0.3 * power) + Vector3(away * randf_range(0.8, 2.6) * power, randf_range(1.5, 4.5), randf_range(-1.2, 1.6))
			_bits.append({"p": p, "v": v, "c": c, "s": px_w * float(block) * randf_range(0.9, 1.25), "bounced": false, "ground": sprite.global_position.y})
	_life = 1.15 + 0.35 * power
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = _bits.size()
	multimesh = mm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_mat.render_priority = 10
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	_update(delta)


func _update(delta: float) -> void:
	var mm := multimesh
	var age := _t / _life
	# hot for a moment (the pixels glow as they break), then their own colours, then fade
	var heat := clampf(1.0 - _t / 0.22, 0.0, 1.0)
	var glow := (2.2 if Hd.on() else 1.3) * heat
	var fade := 1.0 - smoothstep(0.55, 1.0, age)
	for i in _bits.size():
		var b: Dictionary = _bits[i]
		var v: Vector3 = b["v"]
		var p: Vector3 = b["p"]
		v.y -= 13.0 * delta
		v *= 1.0 - 0.9 * delta
		p += v * delta
		var floor_y := float(b["ground"])
		if p.y < floor_y:
			p.y = floor_y
			if not bool(b["bounced"]):
				v.y = -v.y * 0.35
				v.x *= 0.5
				v.z *= 0.5
				b["bounced"] = true
			else:
				v = Vector3(v.x * 0.8, 0.0, v.z * 0.8)
		b["p"] = p
		b["v"] = v
		var s := float(b["s"]) * (1.0 - 0.45 * age)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), p))
		var c: Color = b["c"]
		var hot := c.lerp(Color(1.0, 0.92, 0.75), heat * 0.7)
		mm.set_instance_color(i, Color(hot.r * (1.0 + glow), hot.g * (1.0 + glow), hot.b * (1.0 + glow), fade))
