extends Node2D
## Cast line-up: every hero (with the weapon aimed in 8 directions), every enemy row, the bosses,
## the familiars and the shopkeeper, standing on lines, for LOOKING at after an art change.
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
##       res://dev/cast_lineup.tscn -- --shots=/abs/dir [--anim=run|death|hit]
## It writes <dir>/cast_lineup.png and quits. Nothing in the game uses this scene.

const Heroes = preload("res://scripts/data/heroes.gd")
const Enemies = preload("res://scripts/data/enemies.gd")
const Bosses = preload("res://scripts/data/bosses.gd")
const Familiars = preload("res://scripts/data/familiars.gd")
const HeroLook = preload("res://scripts/entities/hero_look.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")

const FLOOR_COLOR := Color(0.16, 0.20, 0.24)
const LINE_COLOR := Color(0.30, 0.36, 0.40)

var _lines: Array[float] = []
var _frames := 0
var _anim := "idle"


func _ready() -> void:
	scale = Vector2(0.5, 0.5)            # the window shows 800 x 360 game pixels
	_anim = G.arg("anim", "idle")
	var y := 46.0
	var x := 16.0
	for hero: Dictionary in Heroes.LIST:
		for k in 9:
			var at := Vector2(x, y)
			x += 29.0
			var body := Art.sprite(String(hero["sprite"]), _anim if Art.has_anim(String(hero["sprite"]), _anim) else "idle")
			var holder := Node2D.new()
			holder.position = at
			add_child(holder)
			holder.add_child(EnemyScript.make_shadow(16.0))
			var weapon := HeroLook.make_weapon(hero)
			holder.add_child(body)
			holder.add_child(weapon)
			body.position = Vector2(0, 2)
			if k == 8:
				HeroLook.rest(weapon, 1.0)
			else:
				var dir := Vector2.RIGHT.rotated(TAU * k / 8.0)
				body.flip_h = dir.x < -0.15
				HeroLook.layer(weapon, body, HeroLook.aim(weapon, dir, 0.0))
	_lines.append(y)
	for floor_number in [1, 2, 3, 4]:
		if floor_number % 2 == 1:
			y += 62.0
			x = 20.0
		for id: String in Enemies.ALL:
			var row: Dictionary = Enemies.ALL[id]
			if int((row["floors"] as Array)[0]) != floor_number:
				continue
			_stand(String(row["sprite"]), Vector2(x, y), 1.0, row.get("tint", Color.WHITE), float(row.get("hover", 0.0)), String(row.get("idle", "idle")))
			x += 44.0
		x += 16.0
		if floor_number % 2 == 1:
			_lines.append(y)
	y += 96.0
	x = 50.0
	for id: String in Bosses.ALL:
		var b: Dictionary = Bosses.ALL[id]
		_stand(String(b["sprite"]), Vector2(x, y), float(b.get("scale", 1.0)), Color.WHITE, 0.0, "idle")
		x += 110.0
	for id: String in Familiars.ALL:
		var f: Dictionary = Familiars.ALL[id]
		_stand(String(f["sprite"]), Vector2(x, y), 1.0, f.get("tint", Color.WHITE), float(f.get("hover", 0.0)), String(f.get("anim", "idle")))
		x += 50.0
	_stand("pc_npc_tavern_a", Vector2(x, y), 1.0, Color.WHITE, 0.0, "idle")
	_lines.append(y)
	queue_redraw()


func _stand(sprite_id: String, at: Vector2, size: float, tint: Color, hover: float, idle: String) -> void:
	var m := Art.meta(sprite_id)
	var holder := Node2D.new()
	holder.position = at
	add_child(holder)
	holder.add_child(EnemyScript.make_shadow(clampf(float(m.get("body_width", 12.0)) * 0.85 * size, 11.0, 54.0)))
	var want := _anim if _anim != "idle" and Art.has_anim(sprite_id, _anim) else idle
	var s := Art.sprite(sprite_id, want)
	s.position = Vector2(0, 2.0 - hover)
	s.scale = Vector2(size, size)
	s.modulate = tint
	holder.add_child(s)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 800, 360), FLOOR_COLOR)
	for y in _lines:
		draw_line(Vector2(0, y + 2.0), Vector2(800, y + 2.0), LINE_COLOR, 1.0)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 20:
		var dir := G.arg("shots", "")
		if dir != "":
			DirAccess.make_dir_recursive_absolute(dir)
			get_viewport().get_texture().get_image().save_png(dir.path_join("cast_lineup.png"))
		G.quit(0)
