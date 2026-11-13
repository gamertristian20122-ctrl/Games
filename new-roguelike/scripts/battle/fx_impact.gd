extends RefCounted
## ELEMENT IMPACTS on the battle stage (made by stage.gd: `fx = FxImpact.new(self)`; `s` is the
## stage). Every blow and spell lands with a look and a light of its own, all made by code (light,
## streaks, code-built meshes and decals; no art):
##   blade   a white-hot slash, a fan of sword sparks that bounce on the ground, a short white flash
##   fire    a hot core, a flood of embers that rise, flicker and cool to red, dark smoke, a scorch
##   frost   ice crystals that burst out of the ground and shatter, cold mist, glints, a frost patch
##   storm   lightning forks, a flash that lights the WHOLE stage, crackling sparks, a scorch
##   sun     a halo of rays behind the one hit, rising gold motes, rings of light on the ground
##   dark / poison / nature   curling wisps that wind up round the one hit, a stain on the ground
##   heal    soft motes that rise, a ring of light
## Each one flashes a REAL light on the ground and on the fighters for a moment.
## The public calls are on the stage (stage.gd): `impact()`, `dust()`, `flash()`, `mark()`.

const FxKit = preload("res://scripts/battle/fx_kit.gd")

var s                              ## the stage (stage.gd; untyped: its members are read by name)
var _sun_base := -1.0
var _flash_light: OmniLight3D
var _flash_n := 0
var _hz := -1000.0                 ## the one hit's world z (his picture's plane: sparks nearer are thinned over him)

## Which element a skill's look is (battles.gd FX keys). Anything else is told by its colour.
const ID_ELEMENT := {
	"firebolt": "fire", "frost": "frost", "storm": "storm", "sunbolt": "sun", "sunflare": "sun",
	"sunmend": "heal", "mend": "heal", "whirl": "blade", "lunge": "blade", "slam": "blade",
	"cry": "sun", "pierce": "blade", "volley": "blade", "roots": "nature", "sweep": "nature",
}
const ELEMENTS := ["blade", "fire", "frost", "storm", "sun", "dark", "poison", "nature", "heal"]

static var _fx_table := {}


func _init(stage) -> void:
	s = stage


func hd() -> bool:
	return s.hd != null


func spell_k() -> float:
	return float(s.hd.call("num", "spell")) if hd() else 1.0


## Which element a burst of `colour` is: the skill id `style` if it is known, else the colour is
## looked up in battles.gd FX, else read from its hue.
func element_of(colour: Color, style: String = "", rise: float = 0.0) -> String:
	if ID_ELEMENT.has(style):
		return ID_ELEMENT[style]
	if _fx_table.is_empty():
		var b = load("res://scripts/data/battles.gd")
		if b != null:
			_fx_table = b.FX
	for id: String in _fx_table:
		var row: Array = _fx_table[id]
		if (row[0] as Color).is_equal_approx(colour) and ID_ELEMENT.has(id):
			# (several skills share a colour: a rising one is a heal)
			if rise > 0.0 and String(row[1]) == "rise":
				return ID_ELEMENT[id]
			if rise <= 0.0 and String(row[1]) != "rise":
				return ID_ELEMENT[id]
	if rise > 0.0:
		return "heal"
	if colour.s < 0.3:
		return "blade"
	var h := colour.h
	if h < 0.09 or h > 0.95:
		return "fire"
	if h < 0.2:
		return "sun"
	if h < 0.45:
		return "poison"
	if h < 0.62:
		return "frost"
	if h < 0.72:
		return "storm"
	return "dark"


## Where a fighter stands on the screen, 0..1 (sparks in front of him there are thinned).
func screen_box(fighter: Node3D) -> Vector4:
	if fighter == null or not is_instance_valid(fighter) or not fighter.has_method("height"):
		return Vector4(-1.0, -1.0, -1.0, -1.0)
	var cam: Camera3D = s.cam
	var vp: Vector2 = s.get_viewport().get_visible_rect().size
	var h := float(fighter.call("height"))
	var feet := cam.unproject_position(fighter.global_position) / vp
	var head := cam.unproject_position(fighter.global_position + Vector3(0.0, h, 0.0)) / vp
	var half := (feet.y - head.y) * 0.42 * (vp.y / vp.x)
	var mesh := (fighter as MeshInstance3D).mesh as QuadMesh
	if mesh != null:
		half = maxf(half, (cam.unproject_position(fighter.global_position + Vector3(mesh.size.x * 0.5, 0.0, 0.0)) / vp - feet).x)
	return Vector4(feet.x - half, head.y - 0.01, feet.x + half, feet.y + 0.01)


func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, float(s.height_at(at.z)), at.z)


# ------------------------------------------------------------------ the impacts
## `at` = where it lands (the middle of the one hit), `power` 1 = a plain blow, 2 to 3 a big spell.
func impact(at: Vector3, element: String, power: float = 1.0, fighter: Node3D = null) -> void:
	if not ELEMENTS.has(element):
		element = "blade"
	var hold := screen_box(fighter)
	_hz = fighter.global_position.z if fighter != null and is_instance_valid(fighter) else at.z
	match element:
		"blade":
			_blade(at, power, hold)
		"fire":
			_fire(at, power, hold)
		"frost":
			_frost(at, power, hold)
		"storm":
			_storm(at, power, hold)
		"sun":
			_sun(at, power, hold)
		"heal":
			_heal(at, power, hold)
		_:
			_wisps(at, element, power, hold)


func _blade(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	var lite := 1.0 if hd() else 0.6
	# the slash: a crescent of white-hot light that sweeps across the one hit in a blink
	# (just BEHIND the one hit, so his body cuts it and it flares round him: drawn in front at full
	# heat it bloomed into a white blob over both fighters on every plain blow)
	slash(at + Vector3(0.0, 0.1, -0.3), Color(1.0, 0.92, 0.75), 0.85 + 0.18 * power, power, 0.55)
	# sword sparks: a fan of hot streaks that fly out, fall and skip on the ground
	var n := int((14.0 + 14.0 * power) * lite)
	var sp := _streaks(at, 9.0 + 2.5 * power, Color(1.0, 0.8, 0.4))
	sp.grav = Vector3(0.0, -16.0, 0.0)
	sp.drag = 1.0
	sp.trail = 0.045
	sp.width = 0.055
	sp.floor_y = g.y + 0.02
	sp.bounce = 0.35
	sp.cool = Color(0.9, 0.2, 0.02)
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var side := -1.0 if randf() < 0.5 else 1.0
		var dir := Vector3(side * randf_range(0.4, 1.0), randf_range(0.1, 1.0), randf_range(-0.5, 0.4)).normalized()
		var c := Color(1.0, 0.85, 0.5).lerp(Color(1.0, 0.45, 0.08), randf())
		sp.add(i, at + Vector3(randf_range(-0.15, 0.15), randf_range(-0.2, 0.3), 0.0), dir * randf_range(4.0, 9.0 + 2.0 * power), randf() * 0.04, randf_range(0.25, 0.6), c)
	s.add_child(sp)
	_light(at + Vector3(0.0, 0.3, 0.9), Color(1.0, 0.9, 0.75), 2.5 + 2.0 * power, 6.0 + 1.5 * power, 0.16, false, 0.3)
	if power >= 1.4:
		s.dust(g, power * 0.55)


func _fire(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	var lite := 1.0 if hd() else 0.5
	# embers: a flood of hot streaks rising in the heat, flickering, cooling from yellow to red
	var n := int((40.0 + 34.0 * power) * lite)
	var sp := _streaks(at, 5.0 + 0.8 * power, Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.55))
	sp.grav = Vector3(0.0, 2.2, 0.0)
	sp.drag = 1.4
	sp.trail = 0.06
	sp.width = 0.05
	sp.wobble = 7.0
	sp.flicker = 0.45
	sp.cool = Color(0.55, 0.03, 0.0)
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var a := randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a) * 0.6)
		var v := out * randf_range(1.5, 5.0 + power) + Vector3(0.0, randf_range(2.0, 7.0), 0.0)
		var c := Color(1.0, 0.75, 0.3).lerp(Color(1.0, 0.3, 0.03), randf())
		var from := at + out * randf_range(0.5, 1.3) + Vector3(0.0, randf_range(-0.7, 0.5), 0.0)
		sp.add(i, from, v, randf() * 0.25, randf_range(0.6, 1.5), c)
	s.add_child(sp)
	# heat: a short-lived column of dark smoke over the fire (behind the one hit, above his head)
	smoke(at + Vector3(0.0, 0.9, -0.5), Color(0.07, 0.04, 0.03, 0.55), power)
	_light(at + Vector3(0.0, 0.5, 1.0), Color(1.0, 0.45, 0.1), 5.0 + 2.5 * power, 9.0 + 3.0 * power, 0.95, power >= 2.0, 0.5, 0.35)
	s.mark(g, "scorch", 0.9 + 0.35 * power, 3.2)


func _frost(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	# ice crystals out of the ground round the one hit (at his sides and behind him, never in front)
	var count := int(6 + 2 * power) if hd() else 5
	for i in count:
		var a := lerpf(-0.15, PI + 0.15, randf()) if randf() < 0.85 else randf() * TAU
		var r := randf_range(0.45, 1.25)
		var where := g + Vector3(cos(a) * r, 0.0, -absf(sin(a)) * r * 0.7 - 0.12)
		crystal(where, randf_range(0.5, 1.1) * (0.8 + 0.2 * power), Vector3(cos(a) * 0.5, 1.0, -0.2).normalized(), randf() * 0.12)
	# cold mist that rolls out low over the ground
	mist(g + Vector3(0.0, 0.08, -0.5), Color(0.62, 0.82, 1.0, 0.2), power)
	# glints: slow white-blue sparkles that drift down
	var n := int((20.0 + 12.0 * power) * (1.0 if hd() else 0.5))
	var sp := _streaks(at, 4.0, Color(0.55, 0.85, 1.0), Color(0.9, 0.97, 1.0))
	sp.grav = Vector3(0.0, -1.6, 0.0)
	sp.drag = 2.5
	sp.trail = 0.05
	sp.width = 0.04
	sp.min_len = 0.06
	sp.flicker = 0.6
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, -0.1)).normalized()
		sp.add(i, at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.6), -0.3), dir * randf_range(2.0, 6.5), randf() * 0.2, randf_range(0.5, 1.2), Color(0.5, 0.85, 1.0).lerp(Color(0.9, 0.97, 1.0), randf()))
	s.add_child(sp)
	_light(at + Vector3(0.0, 0.6, 1.0), Color(0.55, 0.85, 1.0), 6.0 + 3.0 * power, 9.0 + 2.5 * power, 0.7, false, 0.6)
	s.mark(g, "frost", 1.1 + 0.4 * power, 3.6)


func _storm(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	if hd() and not bool(s._pillar_now):
		# (with a column the whirl brings its own bolts)
		for i in 2:
			var top := g + Vector3(randf_range(-3.0, 3.0), 11.0, randf_range(-4.0, -2.5))
			s.hd.call("bolt", top, g + Vector3(randf_range(-0.3, 0.3), 0.05, -0.9), Color(0.75, 0.88, 1.0), randf_range(0.14, 0.22), 0.45, i * 0.08, 3, 6.0)
	if hd():
		# small arcs crawling round the one hit, behind him
		for i in 4:
			var p0 := at + Vector3(randf_range(-0.9, 0.9), randf_range(-0.8, 0.8), -0.45)
			s.hd.call("bolt", p0, p0 + Vector3(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8), 0.0), Color(0.7, 0.85, 1.0), 0.06, 0.25, 0.05 + randf() * 0.25, 1, 5.0)
	# the flash: the whole stage is lit white-blue for a moment, stuttering like real lightning
	flash(Color(0.78, 0.86, 1.0), 0.9 + 0.35 * power, 0.55, true)
	# crackling sparks: fast, short and hard-braked
	var n := int((30.0 + 20.0 * power) * (1.0 if hd() else 0.5))
	var sp := _streaks(at, 6.0, Color(0.45, 0.7, 1.0), Color(0.92, 0.96, 1.0))
	sp.grav = Vector3(0.0, -6.0, 0.0)
	sp.drag = 3.0
	sp.trail = 0.035
	sp.width = 0.04
	sp.floor_y = g.y + 0.02
	sp.bounce = 0.4
	sp.flicker = 0.5
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-0.7, 0.4)).normalized()
		sp.add(i, at + Vector3(randf_range(-0.4, 0.4), randf_range(-0.7, 0.5), 0.0), dir * randf_range(6.0, 14.0), randf() * 0.45, randf_range(0.2, 0.55), Color(0.5, 0.75, 1.0).lerp(Color(0.9, 0.95, 1.0), randf()))
	s.add_child(sp)
	_light(at + Vector3(0.0, 0.6, 1.0), Color(0.6, 0.78, 1.0), 9.0 + 3.0 * power, 10.0 + 3.0 * power, 0.45, power >= 2.0, 0.5)
	s.mark(g, "scorch", 0.75 + 0.25 * power, 2.6, Color(0.35, 0.6, 1.0))


func _sun(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	# a halo of rays standing behind the one hit: his body hides their foot, they shine round him
	rays(at + Vector3(0.0, 0.15, -0.7), Color(1.0, 0.78, 0.3), 1.6 + 0.6 * power, int(10 + 2 * power), 0.9)
	# gold motes that rise slowly
	var n := int((26.0 + 16.0 * power) * (1.0 if hd() else 0.5))
	var sp := _streaks(at, 4.0, Color(1.0, 0.75, 0.25), Color(1.0, 0.95, 0.75))
	sp.grav = Vector3(0.0, 1.4, 0.0)
	sp.drag = 1.8
	sp.trail = 0.07
	sp.width = 0.05
	sp.min_len = 0.07
	sp.wobble = 2.0
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var a := randf() * TAU
		var p := g + Vector3(cos(a) * randf_range(0.3, 1.6), randf_range(0.1, 2.2), sin(a) * randf_range(0.2, 1.0) - 0.3)
		sp.add(i, p, Vector3(randf_range(-0.6, 0.6), randf_range(0.8, 2.6), 0.0), randf() * 0.3, randf_range(0.8, 1.6), Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.93, 0.65), randf()))
	s.add_child(sp)
	s.ground_glow(g, Color(1.0, 0.8, 0.35, 0.9), 1.0 + 0.5 * power, 0.7, true)
	s.ground_glow(g, Color(1.0, 0.85, 0.45, 0.7), 1.8 + 0.7 * power, 0.95, true)
	_light(at + Vector3(0.0, 0.8, 1.0), Color(1.0, 0.82, 0.45), 7.0 + 3.0 * power, 10.0 + 3.0 * power, 0.85, false, 0.5)


func _heal(at: Vector3, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	var n := int((22.0 + 12.0 * power) * (1.0 if hd() else 0.5))
	var sp := _streaks(at, 3.0, Color(0.45, 1.0, 0.55), Color(0.92, 1.0, 0.85))
	sp.grav = Vector3(0.0, 1.8, 0.0)
	sp.drag = 1.5
	sp.trail = 0.08
	sp.width = 0.05
	sp.min_len = 0.07
	sp.wobble = 1.5
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var a := randf() * TAU
		var p := g + Vector3(cos(a) * randf_range(0.2, 0.9), randf_range(0.0, 0.8), sin(a) * randf_range(0.2, 0.6) - 0.2)
		sp.add(i, p, Vector3(0.0, randf_range(1.0, 2.6), 0.0), randf() * 0.5, randf_range(0.8, 1.5), Color(0.45, 1.0, 0.55).lerp(Color(1.0, 0.95, 0.6), randf() * 0.5))
	s.add_child(sp)
	s.ground_glow(g, Color(0.5, 1.0, 0.6, 0.8), 1.2 + 0.4 * power, 1.0, true)
	_light(at + Vector3(0.0, 0.6, 0.9), Color(0.6, 1.0, 0.65), 4.0 + 2.0 * power, 7.0, 0.9, false, 0.3)


## dark, poison and nature: curling wisps that wind up round the one hit, and a stain on the ground
func _wisps(at: Vector3, element: String, power: float, hold: Vector4) -> void:
	var g := _ground(at)
	var col := {"dark": Color(0.55, 0.15, 1.0), "poison": Color(0.45, 1.0, 0.1), "nature": Color(0.6, 1.0, 0.3)}[element] as Color
	var tip := {"dark": Color(0.9, 0.7, 1.0), "poison": Color(0.85, 1.0, 0.6), "nature": Color(1.0, 0.95, 0.55)}[element] as Color
	var n := int((26.0 + 14.0 * power) * (1.0 if hd() else 0.5))
	var sp := _streaks(at, 3.0, col, tip)
	sp.centre = g
	sp.spin = 9.0
	sp.pull = -1.2
	sp.grav = Vector3(0.0, 1.0, 0.0)
	sp.drag = 0.8
	sp.trail = 0.22
	sp.width = 0.07
	sp.max_len = 1.0
	sp.wobble = 3.0
	_hold(sp, hold, at.z)
	sp.start(n, sp.get_meta("mat"))
	for i in n:
		var a := randf() * TAU
		var r := randf_range(0.6, 1.2)
		var p := g + Vector3(cos(a) * r, randf_range(0.0, 0.6), sin(a) * r * 0.7)
		var v := Vector3(-sin(a), 0.0, cos(a)) * randf_range(1.5, 3.0) + Vector3(0.0, randf_range(1.2, 3.0), 0.0)
		sp.add(i, p, v, randf() * 0.35, randf_range(0.7, 1.3), col.lerp(tip, randf() * 0.4))
	s.add_child(sp)
	if element != "nature":
		smoke(at + Vector3(0.0, 0.3, -0.5), Color(0.05, 0.02, 0.06, 0.5) if element == "dark" else Color(0.06, 0.09, 0.02, 0.45), power * 0.8)
		s.mark(g, "blight", 0.9 + 0.3 * power, 3.0, col)
	else:
		s.dust(g, power * 0.6)
	_light(at + Vector3(0.0, 0.6, 1.0), col.lerp(Color.WHITE, 0.2), 5.0 + 2.0 * power, 8.0, 0.7, false, 0.4)


# ------------------------------------------------------------------ pieces
## A Streaks system with its material made (s.get_meta("mat")); `colour` and `core` are sRGB.
func _streaks(at: Vector3, heat: float, colour: Color, core: Color = Color(1.0, 0.92, 0.75)) -> FxKit.Streaks:
	var sp := FxKit.Streaks.new()
	sp.centre = at
	var k := heat * (0.6 + 0.4 * spell_k()) * (1.0 if hd() else 0.55)
	var mat := FxKit.streak_material(k, FxKit.deep(core, 1.0), 0.8)
	sp.set_meta("mat", mat)
	sp.set_meta("tint", colour)
	return sp


func _hold(sp: FxKit.Streaks, hold: Vector4, z: float) -> void:
	var mat := sp.get_meta("mat") as ShaderMaterial
	mat.set_shader_parameter("hold", hold)
	mat.set_shader_parameter("hold_z", _hz if _hz > -999.0 else z)


## A short real light that flares and fades on the ground and the fighters. `air` = how much it
## glows in the HD fog; `flick` makes it flicker like fire. In HD the full light falls on the
## ground and the scenery only; the fighters get a gentler share of it (they keep their own colours).
func _light(at: Vector3, colour: Color, peak: float, reach: float, life: float, shadows: bool = false, air: float = 0.5, flick: float = 0.0) -> void:
	if hd():
		_one_light(at, colour, peak, reach, life, false, air * 0.4, flick, ~int(s.FIGHTER_LAYER) & 0xFFFFF)
		_one_light(at, colour, peak * 0.32, reach, life, shadows, 0.0, flick, 0xFFFFF)
	else:
		_one_light(at, colour, peak, reach, life, false, 0.0, flick, 0xFFFFF)


func _one_light(at: Vector3, colour: Color, peak: float, reach: float, life: float, shadows: bool, air: float, flick: float, mask: int) -> void:
	var l := OmniLight3D.new()
	l.light_cull_mask = mask
	l.position = at
	l.light_color = FxKit.deep(colour, 1.3).linear_to_srgb()
	l.light_energy = 0.0
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows and hd()
	if hd():
		l.light_size = 0.4
		l.light_volumetric_fog_energy = air * spell_k()
		l.shadow_bias = 0.06
		l.shadow_normal_bias = 1.0
		l.shadow_blur = 1.4
	s.add_child(l)
	peak *= spell_k() if hd() else 0.8
	var tw: Tween = s.create_tween()
	tw.tween_property(l, "light_energy", peak, 0.04)
	if flick > 0.0:
		tw.tween_method(func(t: float) -> void:
			l.light_energy = peak * (1.0 - t) * (1.0 - flick * (0.5 + 0.5 * sin(t * 61.0) * sin(t * 23.0 + 1.0))), 0.0, 1.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## THE FLASH: the whole stage lit for a moment (lightning, a huge blow): the key light (sun or moon)
## flares and a wide light high over the clearing flashes; `stutter` = on, off, on like lightning.
func flash(colour: Color, power: float = 1.0, life: float = 0.5, stutter: bool = false) -> void:
	var sun: DirectionalLight3D = s._sun
	if sun != null and is_instance_valid(sun):
		if _sun_base < 0.0:
			_sun_base = sun.light_energy
		var top := _sun_base * (1.0 + 1.6 * power)
		var ts: Tween = s.create_tween()
		if stutter:
			for v: float in [1.0, 0.3, 0.9, 0.5]:
				ts.tween_property(sun, "light_energy", lerpf(_sun_base, top, v), 0.035)
		else:
			ts.tween_property(sun, "light_energy", top, 0.04)
		ts.tween_property(sun, "light_energy", _sun_base, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _flash_light == null or not is_instance_valid(_flash_light):
		_flash_light = OmniLight3D.new()
		_flash_light.position = Vector3(0.0, 9.0, 5.0)
		_flash_light.omni_range = 40.0
		_flash_light.omni_attenuation = 0.6
		_flash_light.light_energy = 0.0
		_flash_light.shadow_enabled = false
		if hd():
			_flash_light.light_volumetric_fog_energy = 0.15
		s.add_child(_flash_light)
	_flash_light.light_color = colour
	var l := _flash_light
	var peak := (2.2 + 1.4 * power) * (spell_k() if hd() else 0.7)
	_flash_n += 1
	var me := _flash_n
	var tw: Tween = s.create_tween()
	if stutter:
		for v: float in [1.0, 0.15, 0.85, 0.35, 0.7]:
			tw.tween_callback(func() -> void:
				if me == _flash_n:
					l.light_energy = peak * v)
			tw.tween_interval(0.035)
	else:
		tw.tween_property(l, "light_energy", peak, 0.04)
	tw.tween_method(func(v: float) -> void:
		if me == _flash_n:
			l.light_energy = v, peak * 0.7, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ------------------------------------------------------------------ code-built shapes
## A glowing strip along a curve, drawn by STRIP_CODE. `kind` 0 = a slash that sweeps along its
## length (`sweep` 0..1.6), 1 = a ray, brightest at its foot.
const STRIP_CODE := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 col = vec3(1.0, 0.8, 0.5);
uniform vec3 hot = vec3(1.0, 0.95, 0.85);
uniform float heat = 4.0;
uniform float alpha = 1.0;
uniform float sweep = 1.0;
uniform float kind = 0.0;
void fragment() {
	float across = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float v;
	float core;
	if (kind < 0.5) {
		float behind = sweep - UV.y;
		v = step(0.0, behind) * (1.0 - smoothstep(0.0, 0.55, behind)) * pow(across, 1.4);
		core = pow(across, 6.0) * (1.0 - smoothstep(0.0, 0.25, behind));
	} else {
		v = pow(across, 1.6) * pow(1.0 - UV.y, 1.3) * smoothstep(0.0, 0.12, UV.y);
		core = pow(across, 6.0) * pow(1.0 - UV.y, 3.0);
	}
	ALBEDO = mix(col, hot, clamp(core, 0.0, 1.0)) * heat;
	ALPHA = clamp((v + core * 0.6) * alpha, 0.0, 1.0);
}
"
static var _strip_shader: Shader


func _strip_mat(colour: Color, heat: float, kind: float) -> ShaderMaterial:
	if _strip_shader == null:
		_strip_shader = Shader.new()
		_strip_shader.code = STRIP_CODE
	var m := ShaderMaterial.new()
	m.shader = _strip_shader
	var d := FxKit.deep(colour, 1.2)
	m.set_shader_parameter("col", FxKit.vec(d))
	m.set_shader_parameter("hot", FxKit.vec(FxKit.deep(colour.lerp(Color.WHITE, 0.75), 1.0)))
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("kind", kind)
	m.render_priority = 12
	return m


## A strip along `pts` (in the node's space), `widths` per point, UV.x across, UV.y along.
func _strip_mesh(pts: PackedVector3Array, widths: PackedFloat32Array, normal: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var l := PackedVector3Array()
	var r := PackedVector3Array()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := d.cross(normal).normalized()
		l.append(pts[i] - side * widths[i] * 0.5)
		r.append(pts[i] + side * widths[i] * 0.5)
	for i in n - 1:
		var v0 := float(i) / float(n - 1)
		var v1 := float(i + 1) / float(n - 1)
		for q: Array in [[l[i], 0.0, v0], [r[i], 1.0, v0], [r[i + 1], 1.0, v1], [l[i], 0.0, v0], [r[i + 1], 1.0, v1], [l[i + 1], 0.0, v1]]:
			st.set_uv(Vector2(float(q[1]), float(q[2])))
			st.add_vertex(q[0])
	return st.commit()


## THE SLASH: a crescent of light across `at`, turned to the camera, that sweeps from one end to
## the other in a blink and fades.
func slash(at: Vector3, colour: Color, radius: float, power: float = 1.0, heat_k: float = 1.0) -> void:
	var cb: Basis = (s.cam as Camera3D).global_transform.basis
	var right := cb.x
	var up := cb.y
	var tilt := randf_range(-0.5, 0.5)
	var a0 := 2.5 + tilt
	var a1 := -0.5 + tilt
	if randf() < 0.5:
		var t := a0
		a0 = PI - a1
		a1 = PI - t
	var pts := PackedVector3Array()
	var ws := PackedFloat32Array()
	var steps := 18
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := lerpf(a0, a1, t)
		pts.append((right * cos(a) + up * sin(a) * 0.62) * radius)
		ws.append((0.06 + 0.22 * (0.6 + 0.2 * power)) * sin(PI * clampf(t * 0.9 + 0.08, 0.0, 1.0)))
	var m := _strip_mat(colour, (3.2 + 0.6 * power) * heat_k, 0.0)
	m.set_shader_parameter("sweep", 0.0)
	var node := MeshInstance3D.new()
	node.mesh = _strip_mesh(pts, ws, cb.z)
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	s.add_child(node)
	var tw: Tween = s.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("sweep", v), 0.0, 1.6, 0.16)
	tw.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 1.0, 0.0, 0.12).set_delay(0.12)
	tw.tween_callback(node.queue_free)


## RAYS: a halo of thin rays of light round a spot, turned to the camera, turning slowly.
func rays(at: Vector3, colour: Color, length: float, count: int, life: float) -> void:
	var cb: Basis = (s.cam as Camera3D).global_transform.basis
	var node := Node3D.new()
	node.position = at
	s.add_child(node)
	var m := _strip_mat(colour, 3.0 * spell_k() + 0.6, 1.0)
	m.set_shader_parameter("alpha", 0.0)
	var st := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	for i in count:
		var a := TAU * (float(i) + randf_range(-0.3, 0.3)) / float(count)
		var dir := cb.x * cos(a) + cb.y * sin(a)
		var len := length * randf_range(0.55, 1.15)
		var pts := PackedVector3Array([dir * 0.25, dir * (0.25 + len * 0.35), dir * (0.25 + len)])
		var ws := PackedFloat32Array([0.02, randf_range(0.12, 0.28), 0.0])
		var one := _strip_mesh(pts, ws, cb.z)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, one.surface_get_arrays(0))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	node.scale = Vector3(0.4, 0.4, 0.4)
	var tw: Tween = s.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 0.0, 1.0, 0.06)
	tw.parallel().tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 1.0, 0.0, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## An ICE CRYSTAL: a six-sided spike built by code that shoots out of the ground, glints, and
## shatters into glints.
static var _crystal_mesh: ArrayMesh
static var _crystal_mat: StandardMaterial3D


func crystal(at: Vector3, height: float, lean: Vector3, delay: float) -> void:
	if _crystal_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		var ring: Array[Vector3] = []
		for k in 6:
			var a := TAU * k / 6.0
			ring.append(Vector3(cos(a) * 0.16, 0.22, sin(a) * 0.16))
		var tip := Vector3(0.0, 1.0, 0.0)
		var foot := Vector3(0.0, -0.08, 0.0)
		for k in 6:
			var a: Vector3 = ring[k]
			var b: Vector3 = ring[(k + 1) % 6]
			for p: Vector3 in [a, b, tip, b, a, foot]:
				st.add_vertex(p)
		st.generate_normals()
		_crystal_mesh = st.commit()
		_crystal_mat = StandardMaterial3D.new()
		_crystal_mat.albedo_color = Color(0.62, 0.86, 1.0)
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission = Color(0.3, 0.7, 1.0)
		_crystal_mat.emission_energy_multiplier = 1.3
		_crystal_mat.roughness = 0.12
		_crystal_mat.metallic_specular = 1.0
		_crystal_mat.rim_enabled = true
		_crystal_mat.rim = 0.8
		_crystal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := MeshInstance3D.new()
	c.mesh = _crystal_mesh
	c.material_override = _crystal_mat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.position = at
	var up := lean.normalized()
	var side := up.cross(Vector3(0.0, 0.0, 1.0))
	if side.length() < 0.1:
		side = Vector3(1.0, 0.0, 0.0)
	side = side.normalized()
	var basis := Basis(side, up, side.cross(up)).orthonormalized()
	c.basis = basis.scaled(Vector3(0.0, 0.0, 0.0))
	s.add_child(c)
	var full := Vector3(height * 0.9, height, height * 0.9)
	var tw: Tween = s.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		c.basis = basis.scaled(full * Vector3(1.0, t, 1.0) * clampf(t * 3.0, 0.0, 1.0)), 0.0, 1.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_callback(_shatter.bind(c, up, height))
	tw.tween_method(func(t: float) -> void:
		c.basis = basis.scaled(full * (1.0 - t)), 0.0, 1.0, 0.12)
	tw.tween_callback(c.queue_free)


## The crystal shatters: glints fly off it.
func _shatter(c: Node3D, up: Vector3, height: float) -> void:
	if not is_instance_valid(c):
		return
	var sp := _streaks(c.global_position + up * height * 0.5, 4.0, Color(0.6, 0.88, 1.0), Color(0.95, 1.0, 1.0))
	sp.grav = Vector3(0.0, -9.0, 0.0)
	sp.drag = 1.5
	sp.trail = 0.04
	sp.width = 0.04
	sp.start(6, sp.get_meta("mat"))
	for i in 6:
		sp.add(i, c.global_position + up * height * randf_range(0.2, 0.9), Vector3(randf_range(-2.5, 2.5), randf_range(0.5, 3.0), randf_range(-1.5, 0.5)), 0.0, randf_range(0.25, 0.5), Color(0.6, 0.88, 1.0))
	s.add_child(sp)


static var _puff_tex: GradientTexture2D


static func puff_tex() -> GradientTexture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_puff_tex = GradientTexture2D.new()
		_puff_tex.gradient = g
		_puff_tex.fill = GradientTexture2D.FILL_RADIAL
		_puff_tex.fill_from = Vector2(0.5, 0.5)
		_puff_tex.fill_to = Vector2(1.0, 0.5)
		_puff_tex.width = 64
		_puff_tex.height = 64
	return _puff_tex


func _puff_material(colour: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = puff_tex()
	m.albedo_color = colour
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 9
	return m


func _grow_curve(from: float, to: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(to, from) + 0.01
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	return c


func _ramp(peak_at: float = 0.15) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, peak_at, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return g


func _puffs(at: Vector3, colour: Color, amount: int, life: float, size: float, grow: float, setup: Callable) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.lifetime_randomness = 0.35
	p.position = at
	p.scale_amount_curve = _grow_curve(1.0, grow)
	p.color_ramp = _ramp()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _puff_material(colour)
	p.mesh = q
	setup.call(p)
	s.add_child(p)
	p.emitting = true
	s.get_tree().create_timer(life * 1.4 + 0.3).timeout.connect(p.queue_free)


## SMOKE: dark puffs that rise and spread (over a fire, after a dark spell).
func smoke(at: Vector3, colour: Color, power: float = 1.0) -> void:
	_puffs(at, colour, int(8 + 4 * power), 1.5, 0.7, 2.6, func(p: CPUParticles3D) -> void:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.35
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 25.0
		p.gravity = Vector3(0.0, 0.6, 0.0)
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.8
		p.damping_min = 0.6
		p.damping_max = 1.2)


## MIST: soft cold puffs that roll out low over the ground.
func mist(at: Vector3, colour: Color, power: float = 1.0) -> void:
	_puffs(at, colour, int(10 + 5 * power), 1.6, 0.6, 2.4, func(p: CPUParticles3D) -> void:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.6
		p.emission_ring_inner_radius = 0.1
		p.emission_ring_height = 0.05
		p.direction = Vector3(1.0, 0.0, 0.0)
		p.spread = 180.0
		p.flatness = 0.95
		p.gravity = Vector3(0.0, -0.3, 0.0)
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.8 + power * 0.3
		p.damping_min = 1.5
		p.damping_max = 2.5)


## DUST kicked up from the ground: puffs in the colour of the ground and the light that is on it
## (pale blue-grey under the moon, gold in the evening sun), and a few grains thrown up.
func dust(at: Vector3, power: float = 1.0) -> void:
	var g := _ground(at)
	var tone := dust_colour()
	_puffs(g + Vector3(0.0, 0.15, 0.0), tone, int(8 + 8 * power), 1.1 + 0.2 * power, 0.55, 2.4 + 0.6 * power, func(p: CPUParticles3D) -> void:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.35 + 0.15 * power
		p.emission_ring_inner_radius = 0.0
		p.emission_ring_height = 0.05
		p.direction = Vector3(1.0, 0.25, 0.0)
		p.spread = 180.0
		p.flatness = 0.75
		p.gravity = Vector3(0.0, 0.25, 0.0)
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.6 + 1.3 * power
		p.damping_min = 2.0
		p.damping_max = 3.2)
	# grains: small dark specks flung up that fall back
	var grains := Color(tone.r * 0.45, tone.g * 0.42, tone.b * 0.4, 0.9)
	_puffs(g + Vector3(0.0, 0.1, 0.0), grains, int(6 + 6 * power), 0.55, 0.07, 1.0, func(p: CPUParticles3D) -> void:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 55.0
		p.gravity = Vector3(0.0, -14.0, 0.0)
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 3.5 + power
		p.color_ramp = _ramp(0.05))


## The colour of dust on this stage: the ground's colour in the light that falls on it.
func dust_colour() -> Color:
	var night := hd() and float(s.hd.call("num", "stars")) > 0.5
	var ground := String(s.look.get("ground", "hub_grass"))
	if ground == "hub_sand":
		return Color(0.95, 0.8, 0.58, 0.42)
	if ground == "hub_drock":
		return Color(0.5, 0.38, 0.34, 0.4)
	if night or s.look.has("fire"):
		return Color(0.48, 0.52, 0.63, 0.3)
	return Color(0.85, 0.7, 0.48, 0.4)


# ------------------------------------------------------------------ marks on the ground
## A MARK that lingers where a spell landed: "scorch" (burnt black with glowing cracks that cool),
## "frost" (a pale crust of ice that glints) or "blight" (a dark stain with a sickly glow). Drawn
## in art pixels (16 a world unit) so it sits with the pack's ground.
const MARK_CODE := "
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
uniform float kind = 0.0;
uniform float alpha = 1.0;
uniform float glow = 1.0;
uniform float size = 2.0;
uniform float seed = 0.0;
uniform vec3 glow_col = vec3(1.0, 0.3, 0.02);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 px = floor(UV * size * 16.0) / (size * 16.0);
	vec2 q = px * 2.0 - 1.0;
	float r = length(q);
	float n = noise(px * size * 3.0) * 0.6 + noise(px * size * 7.0) * 0.4;
	float shape = 1.0 - smoothstep(0.45, 0.95, r + (n - 0.5) * 0.55);
	if (shape < 0.02) { discard; }
	float cracks = 1.0 - smoothstep(0.0, 0.09, abs(noise(px * size * 5.0 + 3.0) - 0.5));
	if (kind < 0.5) {
		ALBEDO = vec3(0.025, 0.018, 0.014);
		ROUGHNESS = 1.0;
		EMISSION = glow_col * cracks * glow * (1.0 - smoothstep(0.1, 0.8, r)) * 3.0;
		ALPHA = shape * 0.85 * alpha;
	} else if (kind < 1.5) {
		float crust = smoothstep(0.35, 0.75, n);
		ALBEDO = mix(vec3(0.55, 0.72, 0.85), vec3(0.85, 0.95, 1.0), crust);
		ROUGHNESS = mix(0.35, 0.12, crust);
		SPECULAR = 0.9;
		float tw = step(0.985, hash(floor(px * size * 16.0)));
		EMISSION = vec3(0.25, 0.55, 0.85) * glow * 0.35 + vec3(0.8, 0.95, 1.0) * tw * glow * 3.0;
		ALPHA = shape * (0.55 + 0.35 * crust) * alpha;
	} else {
		ALBEDO = vec3(0.03, 0.02, 0.035);
		ROUGHNESS = 0.9;
		EMISSION = glow_col * (cracks * 0.6 + 0.15) * glow * (1.0 - smoothstep(0.2, 0.9, r)) * 1.5;
		ALPHA = shape * 0.75 * alpha;
	}
}
"
static var _mark_shader: Shader


func mark(at: Vector3, kind: String, radius: float, life: float = 3.0, glow_colour: Color = Color(-1, 0, 0)) -> void:
	if _mark_shader == null:
		_mark_shader = Shader.new()
		_mark_shader.code = MARK_CODE
	var m := ShaderMaterial.new()
	m.shader = _mark_shader
	var k := {"scorch": 0.0, "frost": 1.0, "blight": 2.0}.get(kind, 0.0) as float
	m.set_shader_parameter("kind", k)
	m.set_shader_parameter("size", radius * 2.0)
	m.set_shader_parameter("seed", randf() * 100.0)
	var gc := Color(1.0, 0.35, 0.05) if glow_colour.r < 0.0 else glow_colour
	m.set_shader_parameter("glow_col", FxKit.vec(FxKit.deep(gc, 1.2)))
	m.render_priority = 3                 # (after the last pass: see-through; under the spells' light)
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var node := MeshInstance3D.new()
	node.mesh = q
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g := _ground(at)
	node.position = g + Vector3(0.0, 0.03, 0.0)
	node.rotation.y = randf() * TAU
	s.add_child(node)
	m.set_shader_parameter("alpha", 0.0)
	var tw: Tween = s.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 0.0, 1.0, 0.12)
	tw.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter("glow", v), 1.0, 0.0, life * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.35)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("alpha", v), 1.0, 0.0, life * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
