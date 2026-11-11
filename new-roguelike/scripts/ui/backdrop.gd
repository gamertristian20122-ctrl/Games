extends Control
## Backdrop: the small lit piece of dungeon behind the title screen and the menus.
## It is built from the art pack's own tiles, drawn at double size, with one hero standing in
## a pool of light. main.gd owns one copy and keeps it alive behind every menu screen;
## the hero-select screen swaps the hero that stands in it.

const UI = preload("res://scripts/ui/theme.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")

const ZOOM := 2.0
const HERO_FEET := Vector2(8, 30)        ## where the hero stands, in tile-space pixels
const LIGHT_RADIUS := 62.0               ## where the light has faded to black, in tile-space pixels

var _scene: Node2D
var _hero: AnimatedSprite2D
var _weapon: Sprite2D
var _light: Sprite2D
var _dim: ColorRect
var _time := 0.0
var _hero_id := ""
var _dim_tween: Tween
## Where the hero stands, as a fraction of the screen width.
var hero_x := 0.29


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = UI.C_VOID
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_scene = Node2D.new()
	_scene.scale = Vector2(ZOOM, ZOOM)
	add_child(_scene)
	_build_room()
	_build_light()
	_dim = ColorRect.new()
	_dim.color = Color(UI.C_VOID, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var spot := Vector2(roundf(size.x * hero_x), 134.0)
	_scene.position = (spot - HERO_FEET * ZOOM).round()


## Where the hero's feet are on screen (other screens line things up with it).
func hero_spot() -> Vector2:
	return _scene.position + HERO_FEET * ZOOM


func _tile(id: String, col: int, row: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(id)
	s.centered = false
	s.position = Vector2(col * 16, row * 16)
	_scene.add_child(s)
	return s


func _anim_tile(id: String, col: int, row: int) -> void:
	var s := Art.sprite(id, "default")
	s.position = Vector2(col * 16 + 8, row * 16 + 16)
	_scene.add_child(s)


func _build_room() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for col in range(-9, 16):
		_tile("wall_top_mid", col, -2)
		_tile("wall_mid", col, -1)
		for row in range(0, 5):
			var id := "floor_1"
			if rng.randf() < 0.22:
				id = "floor_%d" % rng.randi_range(2, 8)
			_tile(id, col, row)
	# things on the wall and the floor, placed by hand around the hero
	_tile("wall_banner_red", -2, -1)
	_tile("wall_banner_red", 5, -1)
	_tile("wall_fountain_top_1", 2, -2)
	_anim_tile("wall_fountain_mid_red_anim", 2, -1)
	_anim_tile("wall_fountain_basin_red_anim", 2, 0)
	_tile("wall_hole_1", -4, -1)
	_tile("wall_goo", 7, -1)
	_tile("wall_goo_base", 7, 0)
	_tile("column", -3, -2)
	_tile("column", 4, -2)
	_tile("skull", 2, 2).position += Vector2(3, 2)
	_tile("crate", -2, 0).position += Vector2(2, -2)

	# a soft shadow under the hero, then the hero and the weapon
	var shadow := Node2D.new()
	shadow.position = HERO_FEET
	shadow.draw.connect(func() -> void:
		shadow.draw_rect(Rect2(-8, -2, 16, 3), Color(0, 0, 0, 0.3))
		shadow.draw_rect(Rect2(-6, -3, 12, 5), Color(0, 0, 0, 0.3)))
	_scene.add_child(shadow)
	_hero = Art.sprite("pc_knight")
	_hero.position = HERO_FEET
	_scene.add_child(_hero)
	# the weapon is held in front of the body, the same way the hero carries it in a run
	_weapon = Sprite2D.new()
	_weapon.centered = false
	_scene.add_child(_weapon)

	# slow dust in the light: a few single pixels drifting up
	var dust := CPUParticles2D.new()
	dust.position = HERO_FEET + Vector2(0, -20)
	dust.amount = 14
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(56, 30)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 25.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(UI.C_BONE, 0.0))
	fade.add_point(0.25, Color(UI.C_BONE, 0.3))
	fade.add_point(0.75, Color(UI.C_BONE, 0.3))
	fade.set_color(fade.get_point_count() - 1, Color(UI.C_BONE, 0.0))
	dust.color_ramp = fade
	_scene.add_child(dust)


## The light: a round, stepped fade to black centred on the hero (a code-made effect, not art).
func _build_light() -> void:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var steps := [[0.0, 0.0], [0.40, 0.14], [0.52, 0.30], [0.63, 0.46], [0.73, 0.62], [0.82, 0.77], [0.90, 0.90], [0.97, 1.0]]
	g.set_offset(0, 0.0)
	g.set_color(0, Color(UI.C_VOID, 0.0))
	g.set_offset(1, 1.0)
	g.set_color(1, UI.C_VOID)
	for i in range(1, steps.size()):
		g.add_point(steps[i][0], Color(UI.C_VOID, steps[i][1]))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(LIGHT_RADIUS * 2)
	tex.height = int(LIGHT_RADIUS * 2)
	_light = Sprite2D.new()
	_light.texture = tex
	_light.position = HERO_FEET + Vector2(0, -12)
	_scene.add_child(_light)
	# everything outside the light's square is simply black
	var r := LIGHT_RADIUS - 1.0
	var far := 800.0
	for rect: Rect2 in [Rect2(-far, -far, far - r, far * 2), Rect2(r, -far, far, far * 2), Rect2(-r, -far, r * 2, far - r), Rect2(-r, r, r * 2, far)]:
		var c := ColorRect.new()
		c.color = UI.C_VOID
		c.position = rect.position
		c.size = rect.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_light.add_child(c)


func _process(delta: float) -> void:
	# the light breathes a little, like a torch
	_time += delta
	var s := 1.0 + 0.012 * sin(_time * 2.1) + 0.006 * sin(_time * 7.3)
	_light.scale = Vector2(s, s)


## Puts a hero (a row from scripts/data/heroes.gd) in the light. Locked heroes are a black shape.
func set_hero(hero: Dictionary, locked: bool = false) -> void:
	var sprite_id := String(hero.get("sprite", "pc_knight"))
	if sprite_id != _hero_id:
		_hero_id = sprite_id
		_hero.sprite_frames = Art.frames(sprite_id)
		_hero.offset = Art.feet_offset(sprite_id)      # feet on the same spot whatever the hero
		_hero.play("idle")
	_hero.modulate = Color(0.02, 0.02, 0.04) if locked else Color.WHITE
	var weapon_id := String(hero.get("weapon", ""))
	_weapon.visible = weapon_id != "" and not locked and Art.has(weapon_id)
	if _weapon.visible:
		HeroLook.set_weapon(_weapon, hero)
		HeroLook.rest(_weapon, 1.0)
		_weapon.position += HERO_FEET


## Darkens the whole picture so panels on top are easy to read (collection, settings, ...).
func set_dimmed(on: bool) -> void:
	var target := 0.8 if on else 0.0
	if _dim_tween != null:
		_dim_tween.kill()
	if UI.instant or not is_inside_tree():
		_dim.color.a = target
		return
	_dim_tween = create_tween()
	_dim_tween.tween_property(_dim, "color:a", target, 0.15)
