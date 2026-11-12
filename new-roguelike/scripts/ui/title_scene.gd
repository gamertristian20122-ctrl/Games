extends Node3D
## The picture behind the title screen and its menus, in the lit 3D look (v0.21.0): the knight
## standing in the golden wood, the camera drifting slowly. It is the battle stage
## (scripts/battle/stage.gd) with nobody to fight. main.gd makes it whenever the old flat
## backdrop would show and the story and the 3D look are on, and frees it when a place, a
## battle or the intro takes over.

const Stage = preload("res://scripts/battle/stage.gd")
const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const Heroes = preload("res://scripts/data/heroes.gd")
const PX := 1.0 / 16.0

var stage: Node3D
var _home := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = Stage.new()
	add_child(stage)
	stage.call("build", "forest", 4)
	# closer than a battle, and aimed so the knight stands left of the menu
	stage.cam.position = Vector3(1.6, 5.2, 12.5)
	_home = stage.cam.position
	var hero: Dictionary = Heroes.by_id("knight")
	var at := Vector3(-2.4, 0.0, 0.6)
	# this camera stands lower and nearer than a battle's: keep the knight sharp and unsquashed
	(stage.post.material_override as ShaderMaterial).set_shader_parameter("focus", _home.distance_to(at + Vector3(0, 1, 0)))
	var slant := (Vector3(1.4, 0.6, 0.0) - _home).normalized()
	Sprite3.tall = 1.0 / maxf(Vector2(slant.x, slant.z).length(), 0.5)
	var body: MeshInstance3D = stage.call("stand", String(hero["sprite"]), at, false)
	var m := Art.meta(String(hero["sprite"]))
	var bw := float(m.get("body_width", 16.0)) * PX
	var bh := float(m.get("body_height", 28.0)) * PX * Sprite3.tall
	var sword := Node3D.new()
	sword.position = Vector3(bw * 0.5 + 0.02, bh * 0.36, 0.03)
	sword.rotation.z = deg_to_rad(-28.0)
	body.add_child(sword)
	var blade := Sprite3.make(String(hero["weapon"]))
	blade.position = Vector3(0.0, -float(hero.get("grip", 3)) * PX, 0.0)
	sword.add_child(blade)
	if String(hero.get("hand", "")) != "" and Art.has(String(hero["hand"])):
		for side: float in [-1.0, 1.0]:
			var hand := Sprite3.make(String(hero["hand"]))
			hand.position = Vector3(side * (bw * 0.5 + 0.02), bh * 0.3, 0.035)
			body.add_child(hand)
	_aim()


func _aim() -> void:
	stage.cam.position = _home + Vector3(sin(_t * 0.18) * 0.5, sin(_t * 0.11) * 0.12, 0.0)
	stage.cam.look_at(Vector3(1.4, 0.6, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_aim()
