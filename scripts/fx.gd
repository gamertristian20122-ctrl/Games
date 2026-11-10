class_name Fx
## Small visual effects: sparks, rings, lightning and floating words.
## None of these change the game itself, so the test bot turns them off.


## A puff of little square sparks.
static func burst(room: Room, at: Vector2, color: Color, count: int = 8, speed: float = 70.0, life: float = 0.35, size: float = 1.5) -> void:
	if Game.fast_mode or not is_instance_valid(room):
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 1.6
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.7
	p.color = color
	p.emitting = true
	room.fx_layer.add_child(p)
	p.finished.connect(p.queue_free)


## A circle that grows and fades (explosions, the foghorn, Unison).
static func ring(room: Room, at: Vector2, radius: float, color: Color, life: float = 0.3, width: float = 1.5) -> void:
	if Game.fast_mode or not is_instance_valid(room):
		return
	var r := Ring.new()
	r.position = at
	r.radius_to = radius
	r.color = color
	r.life = life
	r.width = width
	r.z_index = 5
	room.fx_layer.add_child(r)


## A jagged line between two points that fades fast.
static func bolt(room: Room, from: Vector2, to: Vector2, color: Color) -> void:
	if Game.fast_mode or not is_instance_valid(room):
		return
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = color
	line.z_index = 5
	var steps := maxi(2, int(from.distance_to(to) / 10.0))
	var side := (to - from).orthogonal().normalized()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var point := from.lerp(to, t)
		if i > 0 and i < steps:
			point += side * randf_range(-5.0, 5.0)
		line.add_point(point)
	room.fx_layer.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)


## Words that drift up and fade ("Blocked", combo names, and so on).
static func words(room: Room, at: Vector2, text: String, color: Color) -> void:
	if Game.fast_mode or not is_instance_valid(room):
		return
	var label := UiKit.label(text, 8, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120.0, 10.0)
	label.position = at - Vector2(60.0, 16.0)
	label.z_index = 7
	room.fx_layer.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 12.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)


## A sprite that pops up for a moment and fades (flames, sparkles).
static func stamp(room: Room, at: Vector2, cell: Vector2i, color: Color, life: float = 0.3, scale: float = 1.0) -> void:
	if Game.fast_mode or not is_instance_valid(room):
		return
	var s := Sprites.sprite(cell, color)
	s.position = at
	s.scale = Vector2(scale, scale)
	s.z_index = 5
	room.fx_layer.add_child(s)
	var tween := s.create_tween()
	tween.tween_property(s, "modulate:a", 0.0, life)
	tween.parallel().tween_property(s, "scale", Vector2(scale, scale) * 1.4, life)
	tween.tween_callback(s.queue_free)


class Ring extends Node2D:
	var radius_to := 30.0
	var life := 0.3
	var width := 1.5
	var color := Color.WHITE
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / life
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		draw_arc(Vector2.ZERO, lerpf(3.0, radius_to, eased), 0.0, TAU, 40, Color(color, 1.0 - t), width)
