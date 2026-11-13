extends Node
## FIGHTING THAT MOVES (battles): every blow, spell and fall as a short piece of choreography made
## by code round the pack's own pictures. scripts/battle/battle.gd makes one of these and calls it
## with the events of a turn (scripts/battle/fight.gd); it shows them and calls back
## `b.impact(event, opts)` at the very moment each blow lands. Nothing here changes a number.
##
## The shape of every attack:  ANTICIPATION (crouch, lean back, the weapon drawn back)
##   > ACTION (a dash with after-images and dust, a jump, a cast)  > IMPACT (the weapon arc, the
##   hit: flash, freeze, knock-back, shake: battle.gd)  > RECOVERY (a hop back home).
## Who moves how ("style", set by battle.gd _place):
##   blade   the knight: dashes in, swings his real sword (the pack's weapon picture) with a gold arc
##   archer  Thessaly and bow monsters: draws, looses a streak of light, recoils
##   mage    Seraphine: lifts her hands, a charge glow, a bolt of sunlight
##   brute   most monsters: a wind-up (they flash red), a lunge, a claw arc
##   caster  monsters that shoot: a short charge, a bolt
##   bat     flyers with the pack's attack animation
##   boss    a boss: long telegraphs (red rings on the ground under whoever it means), big blows
## Skills have their own: whirl (spin with a ring of light), lunge (a three-blow combo), slam (a
## JUMP attack with a shockwave), cry (rings of sound), and every spell a cast with a charge glow.
## Times are seconds of GAME time: holding the fast-forward button (battle.gd) speeds all of it.

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const Trail = preload("res://scripts/battle/anim_trail.gd")
const Battles = preload("res://scripts/data/battles.gd")
const Hd = preload("res://scripts/fx/hd.gd")
const FxKit = preload("res://scripts/battle/fx_kit.gd")
const PX := 1.0 / 16.0

var b                              ## the battle (scripts/battle/battle.gd; untyped: read by name)
var stage: Node3D
static var _dot: GradientTexture2D


func setup(battle: Node) -> void:
	b = battle
	stage = battle.get("stage")


# ------------------------------------------------------------------ small helpers
func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _act(u: Dictionary) -> Node:
	return u["actor"]


func _dir(u: Dictionary) -> float:
	return 1.0 if String(u["side"]) == "party" else -1.0


func _tw(u: Dictionary) -> Tween:
	return (_act(u) as Node).create_tween()


func _alive(u: Dictionary) -> bool:
	return is_instance_valid(u.get("node")) and int(u["hp"]) > 0


## The spot right in front of `target`, where `who` stands to strike it.
func _front_of(who: Dictionary, target: Dictionary, gap: float = 0.45) -> Vector3:
	var th: Vector3 = target["home"]
	var wh: Vector3 = who["home"]
	var d := signf(th.x - wh.x)
	if d == 0.0:
		d = _dir(who)
	return th + Vector3(-d * (float(target["wide"]) * 0.5 + float(who["wide"]) * 0.45 + gap), 0.0, 0.15)


## The middle of a fighter, where he is now.
func _mid(u: Dictionary, up: float = 0.5) -> Vector3:
	var a: Node = _act(u)
	return (a.get("home") as Vector3) + (a.get("offset") as Vector3) + (a.get("kick") as Vector3) + Vector3(0.0, float(a.get("lift")) + float(u["top"]) * up, 0.0)


static func dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


func _glow_mat(colour: Color, hot: float, prio: int = 12) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot()
	m.albedo_color = Color(colour.r * hot, colour.g * hot, colour.b * hot, 1.0)
	m.disable_fog = true
	m.render_priority = prio
	return m


## A ball of light (the head of a bolt, a charge glow): a billboard, hot enough to bloom in HD.
func _orb(at: Vector3, colour: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = _glow_mat(colour.lerp(Color.WHITE, 0.35), 3.0 if Hd.on() else 1.6)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	stage.add_child(m)
	return m


## A soft puff of dust at someone's feet (a dash starts, a jump lands).
## The stage's own dust (fx_impact.gd: the ground's colour under its light, grains thrown up) does the
## puff; a dash adds a low streak of the same dust blown out behind the runner.
func dust(at: Vector3, power: float = 1.0, side: float = 0.0) -> void:
	if b.get("_speed") > 4.0:
		return
	var tone := Color(0.62, 0.55, 0.46, 0.55) if not Hd.on() else Color(0.42, 0.37, 0.31, 0.55)
	if stage.has_method("dust"):
		stage.call("dust", at, power)
		if side == 0.0:
			return
		var c: Color = (stage.get("fx") as RefCounted).call("dust_colour")
		tone = Color(c.r, c.g, c.b, minf(c.a + 0.1, 0.55))
		if Hd.on():
			tone = Color(c.r * 0.72, c.g * 0.72, c.b * 0.72, minf(c.a, 0.45))   # (a pale streak lit by the moon read as snow)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(10 + 8 * power)
	p.lifetime = 0.55 + 0.15 * power
	p.position = at + Vector3(0.0, 0.12, 0.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35 * power, 0.05, 0.2)
	p.direction = Vector3(-side, 0.6, 0.0) if side != 0.0 else Vector3(0.0, 1.0, 0.0)
	p.spread = 70.0 if side != 0.0 else 85.0
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.initial_velocity_min = 0.6 * power
	p.initial_velocity_max = 2.0 * power
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4 + 0.3 * power
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, tone.a), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.42)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot()
	m.albedo_color = Color(tone.r, tone.g, tone.b)
	m.disable_fog = true
	m.render_priority = 9
	q.material = m
	p.mesh = q
	stage.add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.4, false).timeout.connect(p.queue_free)


## AFTER-IMAGES: a copy of the picture where it is now, in the mover's colour, thinned out pixel by
## pixel and burning away (the body's own shader, `dissolve`): speed you can see.
func ghost(u: Dictionary) -> void:
	var body: MeshInstance3D = u["node"]
	if not is_instance_valid(body) or b.get("_speed") > 4.0:
		return
	var g := MeshInstance3D.new()
	g.mesh = body.mesh
	var mat := (body.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(g)
	g.global_transform = body.global_transform
	g.position.z -= 0.05
	var c: Color = u["colour"]
	# (HD: a bright self-lit copy dissolving pixel by pixel bloomed into white confetti round the
	# start of a dash; now a dim copy in the mover's deepened colour that fades as it dissolves,
	# so a lone pixel never stays bright)
	var deep := FxKit.deep(c) if Hd.on() else c
	mat.set_shader_parameter("flash", 0.5)
	mat.set_shader_parameter("flash_col", Vector3(deep.r, deep.g, deep.b))
	mat.set_shader_parameter("flash_glow", 0.25 if Hd.on() else 0.4)
	mat.set_shader_parameter("tint", Vector3(0.4, 0.4, 0.4) if Hd.on() else Vector3(0.7, 0.7, 0.7))
	var tw := g.create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("dissolve", v)
		mat.set_shader_parameter("flash_glow", (0.25 if Hd.on() else 0.4) * (1.0 - v))
		mat.set_shader_parameter("tint", Vector3.ONE * (0.4 if Hd.on() else 0.7) * (1.0 - v * 0.8)), 0.35, 1.0, 0.2)
	tw.tween_callback(g.queue_free)


# ------------------------------------------------------------------ poses
## ANTICIPATION: crouch, lean back from the target, a little step back.
func crouch(u: Dictionary, k: float, seconds: float) -> void:
	var d := _dir(u)
	var tw := _tw(u).set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_act(u), "squash", Vector2(1.0 + 0.14 * k, 1.0 - 0.17 * k), seconds)
	tw.tween_property(_act(u), "lean", d * 0.19 * k, seconds)
	tw.tween_property(_act(u), "offset", (_act(u).get("offset") as Vector3) + Vector3(-d * 0.22 * k, 0.0, 0.0), seconds)


## Back to standing straight (squash 1, no lean).
func stand_up(u: Dictionary, seconds: float) -> void:
	var tw := _tw(u).set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_act(u), "squash", Vector2.ONE, seconds)
	tw.tween_property(_act(u), "lean", 0.0, seconds)


## A DASH to `to` (relative to home): stretched, leaning in, after-images and dust behind.
func dash(u: Dictionary, to: Vector3, seconds: float) -> void:
	var d := _dir(u)
	var body: Node = u["node"]
	if Art.has_anim(String(u["sprite"]), "run") and not bool(u.get("boss", false)):
		body.call("play", "run")
	dust((u["home"] as Vector3) + (_act(u).get("offset") as Vector3), 0.8, d)
	Sfx.play("footstep", -12.0)
	var tw := _tw(u).set_parallel(true)
	tw.tween_property(_act(u), "offset", to, seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_act(u), "squash", Vector2(1.17, 0.88), seconds * 0.4)
	tw.tween_property(_act(u), "lean", -d * 0.16, seconds * 0.5)
	tw.tween_property(_act(u), "lift", 0.0, seconds * 0.3)
	for i in 2:
		get_tree().create_timer(seconds * (0.25 + 0.3 * i), false).timeout.connect(func() -> void: ghost(u))
	await _pause(seconds)
	if Art.has_anim(String(u["sprite"]), "run") and _alive(u):
		body.call("play", "idle")


## RECOVERY: a hop back home.
func back_home(u: Dictionary, seconds: float) -> void:
	var tw := _tw(u).set_parallel(true)
	tw.tween_property(_act(u), "offset", Vector3.ZERO, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void: _act(u).set("lift", 0.42 * 4.0 * t * (1.0 - t)), 0.0, 1.0, seconds)
	tw.tween_property(_act(u), "lean", 0.0, seconds * 0.6)
	tw.tween_property(_act(u), "squash", Vector2(0.94, 1.07), seconds * 0.5)
	tw.chain().tween_property(_act(u), "squash", Vector2(1.1, 0.9), 0.05)
	tw.chain().tween_property(_act(u), "squash", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if u.get("sword") != null:
		sword_to(u, -28.0, seconds)
	await _pause(seconds)
	if _alive(u) and String(u.get("style", "")) != "bat":
		dust(u["home"], 0.5)                 # (a step's worth of dust where he lands)


## The knight's sword, turned to `deg` (0 = pointing up; - = forward, to the right).
func sword_to(u: Dictionary, deg: float, seconds: float, trans: Tween.TransitionType = Tween.TRANS_QUAD) -> void:
	var s: Node3D = u.get("sword")
	if s == null or not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.tween_property(s, "rotation:z", deg_to_rad(deg), seconds).set_trans(trans).set_ease(Tween.EASE_OUT)


## Where the knight's sword is (for its arc of light): pivot, angle, reach.
func _blade_pose(u: Dictionary) -> Dictionary:
	var s: Node3D = u.get("sword")
	if s == null or not is_instance_valid(s):
		return {"p": _mid(u), "a": 0.0, "r0": 0.0, "r1": 0.0}
	var reach := float(u.get("blade", 1.0))
	var p := s.global_position
	var tip := s.global_transform * Vector3(0.0, reach, 0.0)
	var v := tip - p
	return {"p": p, "a": atan2(v.y, v.x), "r0": v.length() * 0.3, "r1": v.length()}


## A weapon arc that follows the knight's real sword.
func blade_trail(u: Dictionary, seconds: float, fade: float = 0.17) -> void:
	if b.get("_speed") > 4.0:
		return
	var t := Trail.new()
	stage.add_child(t)
	t.start(u["colour"], func() -> Dictionary: return _blade_pose(u), seconds, fade)


## A weapon arc where there is no weapon picture (a claw, a club, a spin): a blade of light
## sweeping from angle a0 to a1 round `pivot`.
func arc(pivot: Vector3, a0: float, a1: float, r0: float, r1: float, colour: Color, seconds: float, fade: float = 0.16) -> void:
	if b.get("_speed") > 4.0:
		return
	var st := {"k": 0.0}
	var t := Trail.new()
	stage.add_child(t)
	t.start(colour, func() -> Dictionary: return {"p": pivot, "a": lerpf(a0, a1, float(st["k"])), "r0": r0, "r1": r1}, seconds + 0.02, fade)
	var tw := t.create_tween()
	tw.tween_method(func(k: float) -> void: st["k"] = k, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## THE WARNING UNDER ONE ABOUT TO BE HIT: hot red rings that pulse in time with the boss's tell
## (at night the plain rings were almost invisible, so nobody could tell who the blow was for).
func _warn(target: Dictionary, red: Color, times: int, seconds: float) -> void:
	var hot := 1.7 if Hd.on() else 1.2
	for i in times:
		get_tree().create_timer(seconds / times * i, false).timeout.connect(func() -> void:
			stage.call("ground_glow", target["home"], Color(red.r * hot, red.g * hot + 0.12, red.b * hot, 0.95), 1.9 if Hd.on() else 1.6, seconds / times * 1.3, true)
			stage.call("ground_glow", target["home"], Color(red.r * hot, red.g * hot, red.b * hot, 0.6), 1.25, seconds / times))


## A flash of red on a monster as it winds up (the "tell"), `times` pulses.
func tell(u: Dictionary, seconds: float, times: int = 1, colour: Color = Color(1.0, 0.25, 0.15)) -> void:
	var body: Node = u["node"]
	if not is_instance_valid(body):
		return
	# (a tint, not a flash: the old whitening flash turned a boss inside a spell's light into a pale
	# pink ghost; the threat stays a dark figure in its own pixels, darkened red, with a red rim)
	var tw := body.create_tween()
	for i in times:
		tw.tween_method(func(v: float) -> void: body.call("set_tint_flash", v, colour), 0.0, 0.75, seconds / times * 0.5)
		tw.tween_method(func(v: float) -> void: body.call("set_tint_flash", v, colour), 0.75, 0.0, seconds / times * 0.5)


# ------------------------------------------------------------------ a turn
## Shows one fighter's whole turn. `events` are fight.gd's, in order; the first says what it is.
func turn(who: Dictionary, events: Array) -> void:
	if events.is_empty():
		return
	var first: Dictionary = events[0]
	match String(first["type"]):
		"hit", "miss":
			await attack(who, events)
		"skill":
			await skill(who, first["skill"], events.slice(1))
		"guard":
			await guard(who)
		_:
			pass


## A plain Attack.
func attack(who: Dictionary, events: Array) -> void:
	var e: Dictionary = events[0]
	match String(who.get("style", "brute")):
		"blade":
			await blade_attack(who, e, 2 if bool(e.get("crit", false)) else 1)
		"archer":
			await shoot(who, e, "arrow")
		"mage", "caster":
			await shoot(who, e, "bolt")
		"bat":
			await bat_attack(who, e)
		"boss":
			await boss_attack(who, e)
		_:
			await brute_attack(who, e)


## The knight's sword: wind-up, dash, one swing (two on a crit), hop home.
func blade_attack(who: Dictionary, e: Dictionary, swings: int) -> void:
	var target: Dictionary = e["target"]
	Sfx.play("player_shoot_blade", -8.0, 0.08, 0.8)
	crouch(who, 1.0, 0.13)
	sword_to(who, 78.0, 0.13, Tween.TRANS_BACK)
	await _pause(0.13)
	await dash(who, _front_of(who, target) - (who["home"] as Vector3), 0.15)
	# (every other attack starts with a rising cut instead of a falling one: no two look the same)
	var first := int(who.get("cuts", 0))
	who["cuts"] = first + 1
	if first % 2 == 1:
		var s: Node3D = who.get("sword")
		if s != null:
			sword_to(who, -128.0, 0.06)
	for i in swings:
		await swing(who, e, i, swings, first % 2)
	await _pause(0.12)
	await back_home(who, 0.24)


## One swing of the knight's sword, the blow landing in the middle of it. A combo's swings go
## down and up by turns; `n` swings share the blow (battle.gd counts its number up).
func swing(who: Dictionary, e: Dictionary, i: int, n: int, flip: int = 0) -> void:
	var d := _dir(who)
	var down := (i + flip) % 2 == 0
	var from := 78.0 if down else -128.0
	var to := -128.0 if down else 62.0
	var s: Node3D = who.get("sword")
	if s != null and is_instance_valid(s):
		s.rotation.z = deg_to_rad(from)
	Sfx.play("player_shoot_blade", -5.0, 0.1, 1.0 + 0.08 * i)
	blade_trail(who, 0.1)
	sword_to(who, to, 0.09, Tween.TRANS_SINE)
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "squash", Vector2(1.12, 0.92), 0.05)
	tw.tween_property(_act(who), "lean", -d * 0.2, 0.05)
	tw.tween_property(_act(who), "offset", (_act(who).get("offset") as Vector3) + Vector3(d * 0.25, 0.0, 0.0), 0.06)
	await _pause(0.045)
	b.impact(e, {"from": who, "part": i, "parts": n})
	await _pause(0.06)
	stand_up(who, 0.12)


## A monster's lunge: it flashes red as it rears back, lunges, rakes with an arc, hops home.
func brute_attack(who: Dictionary, e: Dictionary) -> void:
	var target: Dictionary = e["target"]
	var d := _dir(who)
	tell(who, 0.24)
	crouch(who, 1.1, 0.22)
	await _pause(0.22)
	await dash(who, _front_of(who, target, 0.35) - (who["home"] as Vector3), 0.15)
	var pivot := _mid(who, 0.55) + Vector3(d * float(who["wide"]) * 0.35, 0.0, 0.12)
	var reach := maxf(float(who["top"]) * 0.55, 0.9)
	# a downward rake towards the target (mirrored for the side it faces)
	var a0 := PI * 0.5 - d * 0.35
	var a1 := PI * 0.5 - d * 2.6
	arc(pivot, a0, a1, reach * 0.25, reach, who["colour"], 0.1)
	Sfx.play("enemy_shoot", -12.0, 0.1, 0.7)
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "squash", Vector2(1.15, 0.9), 0.05)
	tw.tween_property(_act(who), "lean", -d * 0.24, 0.05)
	await _pause(0.05)
	b.impact(e, {"from": who})
	await _pause(0.14)
	stand_up(who, 0.1)
	await back_home(who, 0.24)


## A bat: the pack's own attack animation, flown at the target.
func bat_attack(who: Dictionary, e: Dictionary) -> void:
	var target: Dictionary = e["target"]
	var body: Node = who["node"]
	tell(who, 0.2)
	crouch(who, 0.6, 0.18)
	await _pause(0.18)
	await dash(who, _front_of(who, target, 0.2) - (who["home"] as Vector3) + Vector3(0.0, 0.0, 0.0), 0.14)
	body.call("play", "attack")
	var hit_at := minf(float(body.call("anim_length", "attack")) * 0.5, 0.25)
	await _pause(hit_at)
	b.impact(e, {"from": who})
	await _pause(0.16)
	if _alive(who):
		body.call("play", "idle")
	await back_home(who, 0.24)


## A bolt or an arrow from where it stands.
func shoot(who: Dictionary, e: Dictionary, kind: String) -> void:
	var target: Dictionary = e["target"]
	var d := _dir(who)
	var c: Color = who["colour"]
	var hand := _mid(who, 0.55) + Vector3(d * (float(who["wide"]) * 0.5 + 0.2), 0.0, 0.2)
	if kind == "arrow":
		Sfx.play("player_shoot_knife", -10.0, 0.08, 0.7)
		crouch(who, 0.7, 0.18)
		hands_to(who, 0.1, -0.2, 0.18)
		await _pause(0.18)
		Sfx.play("player_shoot_knife", -5.0)
		hands_to(who, 0.0, 0.0, 0.1)
		stand_up(who, 0.12)
		(_act(who) as Node).set("kick", Vector3(-d * 0.18, 0.0, 0.0))
		kick_back(who, 0.2)
		await projectile(hand, _mid(target, 0.55), c, 0.06, 0.55, 0.12, "arrow")
	else:
		var glow := await charge(who, c, 0.22, 0.45, false)
		Sfx.play("enemy_shoot" if String(who["side"]) == "foes" else "player_shoot_magic", -7.0)
		if is_instance_valid(glow):
			glow.queue_free()
		stand_up(who, 0.12)
		hands_to(who, 0.0, 0.0, 0.12)
		await projectile(hand, _mid(target, 0.55), c, 0.28, 0.4, 0.22, "bolt")
	b.impact(e, {"from": who})
	await _pause(0.12)


## Lets a kick (a recoil, a knock-back) spring back to nothing.
func kick_back(u: Dictionary, seconds: float) -> void:
	var tw := _tw(u)
	tw.tween_property(_act(u), "kick", Vector3.ZERO, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Moves a fighter's two hand pieces: `up` world units higher, `fwd` towards the other side.
func hands_to(u: Dictionary, up: float, fwd: float, seconds: float) -> void:
	var d := _dir(u)
	for h: Node3D in u.get("hands", []):
		if not is_instance_valid(h):
			continue
		var rest: Vector3 = h.get_meta("rest", h.position)
		var tw := h.create_tween()
		tw.tween_property(h, "position", rest + Vector3(d * fwd + (0.0 if up == 0.0 else -signf(rest.x) * 0.06), up, 0.0), seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A thing that flies from `from` to `to`: a hot head and a comet tail of light (an arrow: thin and
## fast; a bolt: a ball). `arc_up` lifts the middle of its path.
func projectile(from: Vector3, to: Vector3, colour: Color, width: float, arc_up: float, seconds: float, kind: String) -> void:
	if b.get("_speed") > 4.0:
		return
	# (an arrow: a 3-4 px hot head and a short streak; a 1 px line could not be seen. A bolt's ball
	# keeps its own deep colour: a white-hot one read as a lilac-white blob)
	if kind == "arrow":
		width = maxf(width, 0.11)
	var head := _orb(from, colour, 0.36 if kind == "arrow" else 0.75)
	if kind != "arrow" and Hd.on():
		var deep := FxKit.deep(colour, 1.4)
		(head.material_override as StandardMaterial3D).albedo_color = Color(deep.r * 2.4 + 0.25, deep.g * 2.4 + 0.25, deep.b * 2.4 + 0.25, 1.0)
	var st := {"k": 0.0}
	var path := func(k: float) -> Vector3:
		return from.lerp(to, k) + Vector3(0.0, arc_up * 4.0 * k * (1.0 - k), 0.0)
	var t := Trail.new()
	t.whiten = 0.4 if kind == "arrow" else 0.12
	t.edge = false
	stage.add_child(t)
	t.start(colour, func() -> Dictionary:
		var k := float(st["k"])
		var p: Vector3 = path.call(k)
		var ahead: Vector3 = path.call(minf(k + 0.05, 1.0))
		var v := ahead - p
		var a := atan2(v.y, v.x) + PI * 0.5
		return {"p": p, "a": a, "r0": -width * 0.5, "r1": width * 0.5}, seconds + 0.02, 0.12 if kind == "arrow" else 0.2)
	var tw := head.create_tween()
	tw.tween_method(func(k: float) -> void:
		st["k"] = k
		head.position = path.call(k), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(head.queue_free)
	await _pause(seconds)
	if is_instance_valid(t):
		t.cut(0.05)


## A CHARGE GLOW: the caster lifts a little and raises the hands; a magic ring lies under the feet;
## a ball of light grows in front of the hands (the knight: at his raised sword's tip) while
## sparks are drawn into it. Returns the glow, still lit, for the release to throw or put out.
func charge(who: Dictionary, colour: Color, seconds: float, size: float, ring: bool = true) -> MeshInstance3D:
	var d := _dir(who)
	var home := (who["home"] as Vector3) + (_act(who).get("offset") as Vector3)
	if ring:
		stage.call("ground_glow", home, Color(colour.r, colour.g, colour.b, 0.85), 1.3, seconds + 0.35, true)
		stage.call("ground_glow", home, Color(colour.r, colour.g, colour.b, 0.5), 1.1, seconds + 0.25)
	var tw := _tw(who).set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_act(who), "lift", 0.18 if ring else 0.05, seconds)
	tw.tween_property(_act(who), "squash", Vector2(0.95, 1.07), seconds)
	tw.tween_property(_act(who), "lean", d * 0.06, seconds)
	var at := _mid(who, 0.82) + Vector3(d * (float(who["wide"]) * 0.5 + 0.25), 0.18 if ring else 0.0, 0.25)
	if who.get("sword") != null:
		sword_to(who, 6.0, seconds * 0.6, Tween.TRANS_BACK)
		var s: Node3D = who["sword"]
		at = s.global_position + Vector3(0.0, float(who.get("blade", 1.0)) + 0.35 + (0.18 if ring else 0.0), 0.0)
	else:
		hands_to(who, float(who["top"]) * 0.28, 0.12, seconds * 0.6)
	var glow := _orb(at, colour, 0.15)
	var light: OmniLight3D = stage.call("lamp", at + Vector3(0.0, 0.0, 0.6), colour, 0.0, 5.0)
	var gt := glow.create_tween().set_parallel(true)
	gt.tween_property(glow, "scale", Vector3.ONE * (size / 0.15), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gt.tween_property(light, "light_energy", (3.5 if Hd.on() else 2.5) * (0.6 + 0.5 * size), seconds)
	glow.tree_exiting.connect(light.queue_free)
	if b.get("_speed") <= 4.0:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.explosiveness = 0.2
		p.amount = 28
		p.lifetime = minf(seconds, 0.45)
		p.position = at
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 1.1
		p.gravity = Vector3.ZERO
		p.radial_accel_min = -9.0
		p.radial_accel_max = -6.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.2
		p.scale_amount_min = 0.4
		p.scale_amount_max = 0.9
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2)])
		p.color_ramp = ramp
		var q := QuadMesh.new()
		q.size = Vector2(0.12, 0.12)
		var m := _glow_mat(colour.lerp(Color.WHITE, 0.3), 2.6 if Hd.on() else 1.5, 12)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		q.material = m
		p.mesh = q
		stage.add_child(p)
		p.emitting = true
		get_tree().create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)
	Sfx.play("player_shoot_magic", -14.0, 0.05, 0.6)
	await _pause(seconds)
	return glow


## Puts a charge glow out with a pop (the spell has gone).
func release(glow: MeshInstance3D, who: Dictionary) -> void:
	if is_instance_valid(glow):
		var tw := glow.create_tween()
		tw.tween_property(glow, "scale", glow.scale * 1.8, 0.06)
		tw.tween_property(glow, "scale", Vector3.ONE * 0.01, 0.1)
		tw.tween_callback(glow.queue_free)
	var d := _dir(who)
	(_act(who) as Node).set("kick", Vector3(-d * 0.16, 0.0, 0.0))
	kick_back(who, 0.22)
	var tw2 := _tw(who).set_parallel(true)
	tw2.tween_property(_act(who), "lift", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(_act(who), "squash", Vector2.ONE, 0.2)
	tw2.tween_property(_act(who), "lean", 0.0, 0.2)
	hands_to(who, 0.0, 0.0, 0.2)
	if who.get("sword") != null:
		sword_to(who, -28.0, 0.25)


## Guard: a step back behind the guard, a ring of pale light round the feet.
func guard(who: Dictionary) -> void:
	var d := _dir(who)
	Sfx.play("ui_click", -6.0, 0.05, 0.6)
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "squash", Vector2(1.1, 0.92), 0.08)
	tw.tween_property(_act(who), "offset", Vector3(-d * 0.25, 0.0, 0.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if who.get("sword") != null:
		sword_to(who, 32.0, 0.1, Tween.TRANS_BACK)
	stage.call("ground_glow", who["home"], Color(0.55, 0.8, 1.0, 0.85), 1.25, 0.6, true)
	stage.call("ground_glow", who["home"], Color(0.55, 0.8, 1.0, 0.45), 1.0, 0.5)
	await _pause(0.24)
	var t2 := _tw(who).set_parallel(true)
	t2.tween_property(_act(who), "squash", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_act(who), "offset", Vector3.ZERO, 0.22)
	if who.get("sword") != null:
		sword_to(who, -28.0, 0.25)


# ------------------------------------------------------------------ skills
func skill(who: Dictionary, sk: Dictionary, events: Array) -> void:
	var id := String(sk.get("id", ""))
	var fx: Array = Battles.FX.get(id, [])
	var colour: Color = fx[0] if not fx.is_empty() else (who["colour"] as Color)
	var impacts := events.filter(func(e: Dictionary) -> bool: return ["hit", "miss", "heal", "stun"].has(String(e["type"])))
	match id:
		"whirl":
			await whirl(who, impacts)
		"lunge":
			await lunge(who, impacts)
		"slam":
			await slam(who, impacts)
		"cry":
			await war_cry(who, impacts)
		"sweep":
			await boss_sweep(who, impacts)
		"pierce":
			await pierce(who, impacts, colour)
		"volley":
			await volley(who, impacts, colour)
		_:
			await spell(who, id, impacts, colour)


## WHIRLWIND: into the middle of the monsters and round and round, a ring of light, every one hit.
func whirl(who: Dictionary, impacts: Array) -> void:
	var foes := impacts.map(func(e: Dictionary) -> Dictionary: return e["target"])
	var mid := Vector3.ZERO
	for f: Dictionary in foes:
		mid += f["home"]
	mid = mid / maxf(foes.size(), 1.0) if not foes.is_empty() else Vector3(3.0, 0.0, 0.5)
	crouch(who, 1.2, 0.15)
	sword_to(who, 95.0, 0.15)
	await _pause(0.15)
	var spot := Vector3(mid.x - _dir(who) * 1.6, 0.0, mid.z + 0.6)
	await dash(who, spot - (who["home"] as Vector3), 0.17)
	Sfx.play("player_shoot_blade", -4.0, 0.05, 0.75)
	# two turns: the sword round and round, the picture turned by flipping, an arc of light
	var body: Node = who["node"]
	var s: Node3D = who.get("sword")
	var spin_time := 0.42
	blade_trail(who, spin_time, 0.22)
	var tw := _tw(who)
	tw.tween_method(func(v: float) -> void:
		if s != null and is_instance_valid(s):
			s.rotation.z = deg_to_rad(95.0) - v * TAU * 2.0
		if is_instance_valid(body):
			body.call("set_flip", int(v * 8.0) % 2 == 1), 0.0, 1.0, spin_time)
	var st := _tw(who).set_parallel(true)
	st.tween_property(_act(who), "squash", Vector2(1.08, 0.94), 0.08)
	st.tween_property(_act(who), "lean", 0.0, 0.08)
	stage.call("ground_glow", spot, Color(1.0, 0.9, 0.6, 0.7), 2.6, 0.5, true)
	dust(spot, 1.4)
	for i in impacts.size():
		await _pause(spin_time / float(impacts.size() + 1))
		b.impact(impacts[i], {"from": who})
	await _pause(spin_time / float(impacts.size() + 1))
	if is_instance_valid(body):
		body.call("set_flip", false)
	if s != null:
		s.rotation.z = deg_to_rad(-28.0)
	stand_up(who, 0.1)
	await _pause(0.08)
	await back_home(who, 0.26)


## LUNGE: a three-blow combo: two quick cuts and a thrust, one number counting up.
func lunge(who: Dictionary, impacts: Array) -> void:
	if impacts.is_empty():
		return
	var e: Dictionary = impacts[0]
	var target: Dictionary = e["target"]
	var d := _dir(who)
	crouch(who, 1.3, 0.14)
	sword_to(who, 78.0, 0.14)
	await _pause(0.14)
	await dash(who, _front_of(who, target, 0.3) - (who["home"] as Vector3), 0.12)
	await swing(who, e, 0, 3)
	await swing(who, e, 1, 3)
	# the thrust: the sword level, the knight stretched long, a straight streak of light
	var s: Node3D = who.get("sword")
	if s != null:
		s.rotation.z = deg_to_rad(-90.0)
	crouch(who, 0.8, 0.07)
	await _pause(0.07)
	blade_trail(who, 0.1, 0.14)
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "offset", (_act(who).get("offset") as Vector3) + Vector3(d * 0.75, 0.0, 0.0), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_act(who), "squash", Vector2(1.25, 0.85), 0.05)
	tw.tween_property(_act(who), "lean", -d * 0.1, 0.05)
	Sfx.play("player_shoot_blade", -3.0, 0.05, 1.25)
	ghost(who)
	await _pause(0.05)
	b.impact(e, {"from": who, "part": 2, "parts": 3})
	for extra: Dictionary in impacts.slice(1):
		b.impact(extra, {"from": who})
	await _pause(0.16)
	stand_up(who, 0.1)
	await back_home(who, 0.24)


## GROUND SLAM, the JUMP ATTACK: a deep crouch, a leap high over the monsters, the sword overhead,
## a crash down with a shockwave that throws every one of them.
func slam(who: Dictionary, impacts: Array) -> void:
	var foes := impacts.map(func(e: Dictionary) -> Dictionary: return e["target"])
	var mid := Vector3(3.5, 0.0, 0.6)
	if not foes.is_empty():
		mid = Vector3.ZERO
		for f: Dictionary in foes:
			mid += f["home"]
		mid /= float(foes.size())
	var land := Vector3(mid.x - _dir(who) * 1.7, 0.0, mid.z + 0.8)
	crouch(who, 1.6, 0.2)
	sword_to(who, 40.0, 0.2)
	await _pause(0.2)
	dust((who["home"] as Vector3), 1.3)
	Sfx.play("player_shoot_blade", -8.0, 0.05, 0.6)
	var to := land - (who["home"] as Vector3)
	var air := 0.46
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "offset", to, air).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void: _act(who).set("lift", 3.6 * 4.0 * t * (1.0 - t) * (1.0 - 0.25 * t)), 0.0, 1.0, air)
	tw.tween_property(_act(who), "squash", Vector2(0.84, 1.2), air * 0.3)
	tw.tween_property(_act(who), "lean", 0.0, air * 0.3)
	sword_to(who, 105.0, air * 0.55)       # (raised back over his shoulder: + turns it back, towards his own side)
	b.call("track", land + Vector3(0.0, 1.4, 0.0), air + 0.5)
	await _pause(air * 0.62)
	# the downstroke: the sword over and down
	blade_trail(who, air * 0.38, 0.25)
	sword_to(who, -150.0, air * 0.38, Tween.TRANS_EXPO)
	await _pause(air * 0.38)
	(_act(who) as Node).set("lift", 0.0)
	var land_tw := _tw(who)
	land_tw.tween_property(_act(who), "squash", Vector2(1.3, 0.7), 0.04)
	land_tw.tween_property(_act(who), "squash", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("rock_break", -2.0)
	Sfx.play("explosion", -10.0)
	dust(land, 2.2)
	stage.call("flash", Color(1.0, 0.85, 0.6), 0.7, 0.35)       # (the crash lights the clearing)
	var colour := Color(1.0, 0.82, 0.5)
	stage.call("ground_glow", land, Color(colour.r, colour.g, colour.b, 0.9), 2.4, 0.45, true)
	stage.call("ground_glow", land, Color(colour.r, colour.g, colour.b, 0.7), 4.5, 0.65, true)
	stage.call("ground_glow", land, Color(colour.r, colour.g, colour.b, 0.6), 2.0, 0.4)
	b.call("shake", 0.9)
	for e: Dictionary in impacts:
		var dist := ((e["target"]["home"] as Vector3) - land).length()
		get_tree().create_timer(0.02 + dist * 0.025, false).timeout.connect(func() -> void: b.impact(e, {"from": who, "launch": 1.0}))
	await _pause(0.32)
	await back_home(who, 0.3)


## WAR CRY: the sword raised, rings of sound rolling out over the monsters.
func war_cry(who: Dictionary, impacts: Array) -> void:
	var d := _dir(who)
	crouch(who, 0.8, 0.12)
	await _pause(0.12)
	sword_to(who, 4.0, 0.1, Tween.TRANS_BACK)
	var tw := _tw(who).set_parallel(true)
	tw.tween_property(_act(who), "squash", Vector2(0.9, 1.16), 0.1)
	tw.tween_property(_act(who), "lift", 0.25, 0.1)
	tw.tween_property(_act(who), "lean", -d * 0.05, 0.1)
	Sfx.play("boss_roar", -8.0, 0.05, 1.35)
	b.call("shake", 0.45)
	var at: Vector3 = who["home"]
	for i in 3:
		get_tree().create_timer(0.09 * i, false).timeout.connect(func() -> void:
			stage.call("ground_glow", at + Vector3(d * 1.5 * i, 0.0, 0.0), Color(1.0, 0.85, 0.5, 0.8 - 0.2 * i), 2.6 + 1.6 * i, 0.55, true))
	await _pause(0.22)
	for e: Dictionary in impacts:
		b.impact(e, {"from": who})
	await _pause(0.2)
	release(null, who)
	await _pause(0.2)


## PIERCING SHOT: a long draw with the arrow glowing, a straight streak, a heavy hit.
func pierce(who: Dictionary, impacts: Array, colour: Color) -> void:
	if impacts.is_empty():
		return
	var e: Dictionary = impacts[0]
	var d := _dir(who)
	crouch(who, 1.0, 0.18)
	hands_to(who, 0.05, -0.25, 0.2)
	var glow := await charge(who, colour, 0.34, 0.5, false)
	Sfx.play("player_shoot_knife", -3.0, 0.05, 0.8)
	release(glow, who)
	var hand := _mid(who, 0.55) + Vector3(d * (float(who["wide"]) * 0.5 + 0.2), 0.0, 0.2)
	await projectile(hand, _mid(e["target"], 0.55), colour, 0.12, 0.1, 0.09, "arrow")
	b.impact(e, {"from": who, "launch": 0.5})
	await _pause(0.22)


## VOLLEY: arrows loosed high, falling on every monster one after another.
func volley(who: Dictionary, impacts: Array, colour: Color) -> void:
	var d := _dir(who)
	crouch(who, 0.8, 0.15)
	hands_to(who, 0.25, -0.1, 0.15)
	await _pause(0.15)
	var hand := _mid(who, 0.7) + Vector3(d * 0.4, 0.0, 0.2)
	for i in 4:
		Sfx.play("player_shoot_knife", -9.0, 0.12)
		var up := hand + Vector3(d * (1.0 + i * 0.4), 6.0, -0.5)
		projectile(hand, up, colour, 0.05, 0.4, 0.16, "arrow")
		await _pause(0.05)
	release(null, who)
	await _pause(0.12)
	for e: Dictionary in impacts:
		var t: Dictionary = e["target"]
		var at := _mid(t, 0.55)
		projectile(at + Vector3(-d * 1.2, 6.0, 0.2), at, colour, 0.06, 0.0, 0.14, "arrow")
		get_tree().create_timer(0.14, false).timeout.connect(func() -> void: b.impact(e, {"from": who}))
		await _pause(0.09)
	await _pause(0.22)


## Every other spell: a CAST with a charge glow, then what that spell does.
func spell(who: Dictionary, id: String, impacts: Array, colour: Color) -> void:
	var heal := not impacts.is_empty() and String(impacts[0]["type"]) == "heal"
	var glow := await charge(who, colour, 0.42, 1.25)
	var from := glow.global_position if is_instance_valid(glow) else _mid(who, 0.8)
	match id:
		"firebolt", "sunbolt", "roots":
			release(glow, who)
			Sfx.play("player_shoot_magic", -4.0, 0.05, 0.8 if id == "firebolt" else 1.1)
			for e: Dictionary in impacts:
				if String(e["type"]) == "stun":
					b.impact(e, {"from": who})
					continue
				if id == "roots":
					await projectile(from, _mid(e["target"], 0.1), colour, 0.18, 1.2, 0.24, "bolt")
				else:
					await projectile(from, _mid(e["target"], 0.55), colour, 0.42, 0.9, 0.24, "bolt")
				b.impact(e, {"from": who, "fx": true})
		"storm":
			# the charge leaps into the sky; the lightning comes down on each in turn
			release(glow, who)
			Sfx.play("explosion", -8.0, 0.05, 1.4)
			await projectile(from, from + Vector3(0.0, 7.0, -1.0), colour, 0.3, 0.0, 0.12, "bolt")
			for e: Dictionary in impacts:
				b.impact(e, {"from": who, "fx": true})
				await _pause(0.11)
		"frost", "sunflare":
			# a wave of light rolls out over the ground and every monster is hit as it reaches them
			release(glow, who)
			Sfx.play("explosion", -9.0, 0.05, 1.2 if id == "frost" else 0.9)
			var at: Vector3 = who["home"]
			for i in 3:
				get_tree().create_timer(0.07 * i, false).timeout.connect(func() -> void:
					stage.call("ground_glow", at, Color(colour.r, colour.g, colour.b, 0.55 - 0.15 * i), 4.0 + 3.0 * i, 0.6, true))
			b.call("shake", 0.4)
			for e: Dictionary in impacts:
				var dist := ((e["target"]["home"] as Vector3) - at).length()
				get_tree().create_timer(0.04 + dist * 0.03, false).timeout.connect(func() -> void: b.impact(e, {"from": who, "fx": true}))
			await _pause(0.45)
		_:
			# a heal (mend, sun's mercy) and anything else: the light drifts to the one it is for
			release(glow, who)
			Sfx.play("player_shoot_magic", -8.0, 0.05, 1.3)
			for e: Dictionary in impacts:
				if heal and e.get("target") != null and e["target"] != who:
					await projectile(from, _mid(e["target"], 0.6), colour, 0.3, 0.8, 0.28, "bolt")
				b.impact(e, {"from": who, "fx": true})
				await _pause(0.08)
	await _pause(0.18)


# ------------------------------------------------------------------ monsters' big moves
## A BOSS'S BLOW: a long telegraph (a red ring under the one it means, the boss flashing red), a
## heavy step in, the pack's own attack animation timed so its blow lands on its hit frame.
func boss_attack(who: Dictionary, e: Dictionary) -> void:
	var target: Dictionary = e["target"]
	var body: Node = who["node"]
	var red := Color(1.0, 0.18, 0.1)
	Sfx.play("boss_roar", -10.0, 0.05, 1.1)
	stage.call("ground_glow", target["home"], Color(red.r, red.g, red.b, 0.9), 1.4, 0.75, true)
	stage.call("ground_glow", target["home"], Color(red.r, red.g, red.b, 0.5), 1.2, 0.7)
	_warn(target, red, 2, 0.5)
	tell(who, 0.5, 2, red)
	crouch(who, 0.9, 0.45)
	b.call("track", (target["home"] as Vector3).lerp(who["home"], 0.5) + Vector3(0.0, 1.5, 0.0), 1.4)
	await _pause(0.45)
	var has_swing := Art.has_anim(String(who["sprite"]), "attack")
	var reach := 3.0 if has_swing else 0.3
	var spot := _front_of(who, target, reach)
	await dash(who, spot - (who["home"] as Vector3), 0.2)
	stand_up(who, 0.08)
	if has_swing:
		body.call("play", "attack")
		var hit_frame := 4
		var meta := Art.meta(String(who["sprite"]))
		var hits: Dictionary = meta.get("hit_frames", {})
		if hits.has("attack") and not (hits["attack"] as Array).is_empty():
			hit_frame = int(hits["attack"][0])
		await _pause(float(hit_frame) / maxf(float(body.call("anim_fps", "attack")), 1.0))
	else:
		var d := _dir(who)
		var pivot := _mid(who, 0.6) + Vector3(d * float(who["wide"]) * 0.3, 0.0, 0.15)
		arc(pivot, PI * 0.5 - d * 0.2, PI * 0.5 - d * 2.7, 0.5, float(who["top"]) * 0.6, who["colour"], 0.12, 0.22)
		await _pause(0.06)
	Sfx.play("rock_break", -6.0, 0.05, 0.8)
	dust(target["home"], 1.2)
	b.impact(e, {"from": who, "launch": 0.6})
	await _pause(0.3)
	if _alive(who):
		body.call("play", "idle")
	await back_home(who, 0.3)


## A BOSS'S SWEEP (every few turns, fight.gd): the boss rears up and glows red, red rings grow
## under every one of your side, the camera pulls back, then it leaps and crashes down: a shockwave
## rolls over the whole party.
func boss_sweep(who: Dictionary, impacts: Array) -> void:
	var body: Node = who["node"]
	var red := Color(1.0, 0.16, 0.08)
	var d := _dir(who)
	Sfx.play("boss_roar", -2.0)
	for e: Dictionary in impacts:
		stage.call("ground_glow", e["target"]["home"], Color(red.r, red.g, red.b, 0.95), 1.6, 1.0, true)
		stage.call("ground_glow", e["target"]["home"], Color(red.r, red.g, red.b, 0.55), 1.3, 0.95)
		_warn(e["target"], red, 3, 0.8)
	tell(who, 0.8, 3, red)
	var tw := _tw(who).set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_act(who), "squash", Vector2(0.9, 1.14), 0.35)
	tw.tween_property(_act(who), "lean", d * 0.18, 0.35)
	b.call("track", Vector3(0.0, 1.8, 0.4), 1.6, -0.6)
	b.call("shake", 0.35)
	await _pause(0.4)
	crouch(who, 1.4, 0.3)
	await _pause(0.3)
	# the leap: up and towards the middle of the stage
	var home: Vector3 = who["home"]
	var land := Vector3(home.x * 0.4, 0.0, 0.9) - home
	var air := 0.4
	var lt := _tw(who).set_parallel(true)
	lt.tween_property(_act(who), "offset", land, air).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lt.tween_method(func(t: float) -> void: _act(who).set("lift", 2.6 * 4.0 * t * (1.0 - t)), 0.0, 1.0, air)
	lt.tween_property(_act(who), "squash", Vector2(0.85, 1.2), air * 0.4)
	lt.tween_property(_act(who), "lean", 0.0, air * 0.4)
	if Art.has_anim(String(who["sprite"]), "attack"):
		body.call("play", "attack")
	await _pause(air)
	(_act(who) as Node).set("lift", 0.0)
	var land_tw := _tw(who)
	land_tw.tween_property(_act(who), "squash", Vector2(1.35, 0.68), 0.05)
	land_tw.tween_property(_act(who), "squash", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var at := (who["home"] as Vector3) + land
	Sfx.play("explosion", -2.0, 0.05, 0.7)
	Sfx.play("rock_break", 0.0, 0.05, 0.6)
	dust(at, 2.6)
	stage.call("flash", Color(1.0, 0.5, 0.35), 0.6, 0.4)
	b.call("shake", 1.0)
	for i in 3:
		get_tree().create_timer(0.08 * i, false).timeout.connect(func() -> void:
			stage.call("ground_glow", at, Color(red.r, red.g * 2.5, red.b * 2.0, 0.85 - 0.2 * i), 3.0 + 3.5 * i, 0.7, true))
	for e: Dictionary in impacts:
		var dist := ((e["target"]["home"] as Vector3) - at).length()
		get_tree().create_timer(0.05 + dist * 0.04, false).timeout.connect(func() -> void: b.impact(e, {"from": who, "launch": 1.0}))
	await _pause(0.55)
	if _alive(who):
		body.call("play", "idle")
	await back_home(who, 0.35)


# ------------------------------------------------------------------ the ends of the fight
## VICTORY: the knight throws his sword up overhead and leaps; the others hop and turn for joy.
func victory(party: Array) -> void:
	for u: Dictionary in party:
		if not _alive(u):
			continue
		var a: Node = _act(u)
		var hop := u.get("sword") != null
		var tw := a.create_tween()
		tw.tween_property(a, "squash", Vector2(1.15, 0.85), 0.1)
		tw.tween_property(a, "squash", Vector2(0.88, 1.15), 0.08)
		tw.parallel().tween_method(func(t: float) -> void: a.set("lift", (1.2 if hop else 0.6) * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.42)
		tw.tween_property(a, "squash", Vector2(1.12, 0.88), 0.05)
		tw.tween_property(a, "squash", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if hop:
			sword_to(u, 8.0, 0.18, Tween.TRANS_BACK)
			var s: Node3D = u["sword"]
			get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
				if is_instance_valid(s):
					stage.call("burst", s.global_position + Vector3(0.0, float(u.get("blade", 1.0)), 0.2), Color(1.0, 0.9, 0.55), 0.9, 1.0))
		else:
			var body: Node = u["node"]
			var flip := body.create_tween()
			for i in 3:
				flip.tween_callback(func() -> void: body.call("set_flip", i % 2 == 0))
				flip.tween_interval(0.12)
			flip.tween_callback(func() -> void: body.call("set_flip", false))
			hands_to(u, float(u["top"]) * 0.3, 0.0, 0.2)


## A fighter of your side falls: his own death animation where the pack has one, else he topples
## back; he stays down (fallen friends are not shattered).
func collapse(u: Dictionary) -> void:
	var a: Node = _act(u)
	a.set("breath", 0.0)
	var body: Node = u["node"]
	var d := _dir(u)
	if Art.has_anim(String(u["sprite"]), "death"):
		body.call("play", "death")
		var tw := a.create_tween().set_parallel(true)
		tw.tween_property(a, "kick", Vector3(-d * 0.4, 0.0, 0.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(a, "squash", Vector2.ONE, 0.2)
	else:
		var tw := a.create_tween().set_parallel(true)
		tw.tween_property(a, "lean", d * 1.45, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(a, "kick", Vector3(-d * 0.5, 0.0, 0.0), 0.3)
	dust(u["home"], 1.0)
