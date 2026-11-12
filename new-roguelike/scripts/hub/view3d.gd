extends Node3D
## The LIT 3D LOOK for every place you walk in (camps, the world map, the tavern rooms).
## The owner asked for it on 12 Nov 2026: "that needs to be for the entire game".
##
## hub.gd still does everything as before, in flat 2D: where things stand, who walks where, what
## you can talk to. This file only SHOWS it differently. After hub.gd has built a place it calls
## rebuild(); from then on, every frame, this file copies what the flat picture holds:
##   the ground       everything painted flat (grass, sand, paths, decals, a room's picture) is
##                    drawn once into one big texture and laid on the floor of a 3D world
##   standing things  every picture under hub.gd's `_ysort` (trees, people, the knight, monsters)
##                    becomes an upright card on that floor, on the same spot. Things that never
##                    move are drawn in batches; people, fires and the knight are followed live
##   light            the day's colour becomes a sky light, every lamp of the place a small light
##   words            labels ("!", names, signs) are shown over the 3D picture on the same spots
## On top: flat shadows, mist, glow, fireflies and the blur away from the knight (as in
## scripts/battle/stage.gd, whose lessons apply here too).
## The flat 2D picture is hidden, not removed: `--flat` on the command line shows the old look.
## One world unit is 16 art pixels: 2D (x, y) is 3D (x / 16, 0, y / 16).

const Stage = preload("res://scripts/battle/stage.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")

const PX := 1.0 / 16.0
const PITCH := 44.0                 ## how steeply the camera looks down out of doors, in degrees
const PITCH_INDOORS := 62.0         ## a room is one painted picture: looked at more from above, it keeps its shape
const TILT := 12.0                  ## how far standing things lean back towards the camera, out of doors ...
const TILT_INDOORS := 45.0          ## ... and in a room (so people are not squashed by the steep view)
const FOV := 30.0
const MARGIN := Vector2(336, 208)   ## how far past the edges of a place the ground is painted, px
const LEAN := Vector2(-0.55, 0.5)   ## which way a shadow falls on the ground, per unit of height
const LAMP_ENERGY := 9.0            ## a 2D lamp of energy 1 is this strong here
const LAMP_REACH := 1.5             ## and reaches this many times as far as its 2D picture

const CARD_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float shine = 0.0;
void fragment() {
	vec4 c = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (c.a < 0.5) { discard; }
	ALBEDO = c.rgb * tint;
	EMISSION = c.rgb * shine;
	ROUGHNESS = 1.0;
}
void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.35);
}
"
const FLOOR_PART := "
uniform sampler2D ground_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float grey = 0.22;
varying vec2 at;
vec3 ground_colour(vec2 where) {
	vec3 c = texture(ground_tex, (where - ground_rect.xy) / ground_rect.zw).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(c, vec3(l) * 1.15, grey);
}
"
const FLOOR_CODE := "
shader_type spatial;
render_mode specular_disabled;
" + FLOOR_PART + "
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = ground_colour(at);
	ROUGHNESS = 1.0;
}
"
const SHADE_CODE := "
shader_type spatial;
render_mode cull_disabled, specular_disabled;
" + FLOOR_PART + "
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float dark = 0.6;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	if (texture(tex, uv_rect.xy + UV * uv_rect.zw).a < 0.5) { discard; }
	ALBEDO = ground_colour(at) * dark;
	ROUGHNESS = 1.0;
}
"

var hub: Node2D
var cam: Camera3D
var _world: Node3D                 ## everything of the current place; freed and rebuilt on rebuild()
var _port: SubViewport             ## paints the flat ground once
var _env: Environment
var _sun: DirectionalLight3D
var _post: MeshInstance3D
var _words: Control                ## the labels shown over the 3D picture
var _card_shader: Shader
var _shade_shader: Shader
var _floor_shader: Shader
var _unit := QuadMesh.new()
var _ground_params := {}
var _live := {}                    ## holder id -> {"node": Node2D, "cards": {sprite id -> card}}
var _known := 0                    ## how many children `_ysort` had when last looked at
var _still := {}                   ## holder id -> true: things already drawn in a batch
var _twins: Array = []             ## [Label in the flat picture, its copy here, holder or null]
var _lamps: Array = []             ## [PointLight2D, OmniLight3D]
var _flies: CPUParticles3D
var _outdoor := false
var _dist := 21.0
var _pitch := PITCH
var _lift := 0.0                   ## how much the darks are lifted towards a warm haze (soft light)
var _up := Vector3.UP              ## "up" for a standing card: straight up, leaned back by the tilt


func setup(the_hub: Node2D) -> void:
	hub = the_hub
	process_priority = 100             # after hub.gd has moved everybody
	_unit.size = Vector2.ONE
	_card_shader = Shader.new()
	_card_shader.code = CARD_CODE
	_shade_shader = Shader.new()
	_shade_shader.code = SHADE_CODE
	_floor_shader = Shader.new()
	_floor_shader.code = FLOOR_CODE
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 260.0
	add_child(cam)
	cam.current = true
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR       # the pack's colours as they were painted
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_strength = 1.05
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.2            # fires and glowing stones bloom, bright sand only a breath
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false        # shadows are flat pictures (see scripts/battle/stage.gd)
	# the light comes from behind and to the right, the way the shadows lean
	_sun.look_at_from_position(Vector3.ZERO, Vector3(LEAN.x, -1.0, LEAN.y), Vector3.UP)
	add_child(_sun)
	# the last pass: blur away from the knight, warm lights, cool shade, dark corners
	var sh := Shader.new()
	sh.code = Stage.POST_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_post = MeshInstance3D.new()
	_post.mesh = q
	_post.material_override = mat
	_post.extra_cull_margin = 16000.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(_post)
	_post.position = Vector3(0.0, 0.0, -1.0)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_words = Control.new()
	_words.theme = UI.theme()
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_words)


# ------------------------------------------------------------------ building a place
## Called by hub.gd at the end of enter(): shows the place it has just built.
func rebuild() -> void:
	if is_instance_valid(_world):
		_world.free()
	if is_instance_valid(_port):
		_port.free()
	for pair: Array in _twins:
		if is_instance_valid(pair[1]):
			(pair[1] as Node).free()
	_twins.clear()
	_live.clear()
	_still.clear()
	_lamps.clear()
	_known = 0
	_flies = null
	_world = Node3D.new()
	add_child(_world)
	var place: Dictionary = hub.place
	var stage: Node2D = hub._stage
	var ysort: Node2D = hub._ysort
	_outdoor = bool(place.get("outdoor", false))
	_pitch = PITCH if _outdoor else PITCH_INDOORS
	var tilt := deg_to_rad(TILT if _outdoor else TILT_INDOORS)
	_up = Vector3(0.0, cos(tilt), -sin(tilt))
	_paint_ground(stage, ysort, place)
	stage.visible = false
	hub._prompt.modulate.a = 0.0
	# standing things: the ones that never move go into batches, the rest are followed live
	var moving := {}
	if is_instance_valid(hub._hero):
		moving[hub._hero.get_instance_id()] = true
	for p: Dictionary in hub._people:
		moving[(p["node"] as Node).get_instance_id()] = true
	for r: Dictionary in hub._roamers:
		moving[(r["node"] as Node).get_instance_id()] = true
	var batches := {}
	for holder in ysort.get_children():
		if not (holder is Node2D):
			continue
		if moving.has(holder.get_instance_id()) or _has_animation(holder):
			_live[holder.get_instance_id()] = {"node": holder, "cards": {}}
		else:
			_still[holder.get_instance_id()] = true
			_batch_holder(holder, ysort, batches)
	_known = ysort.get_child_count()
	_flush(batches)
	# words: signs on the ground, the "!" over people, the name of whoever is in reach
	for l in _labels_under(stage):
		_twin(l, _holder_of(l, ysort))
	_twin(hub._prompt, null)
	# light
	for pair: Array in hub._lamps if _outdoor else []:
		var two: PointLight2D = pair[0]
		var three := OmniLight3D.new()
		three.position = Vector3(two.position.x * PX, 1.1, two.position.y * PX + 0.4)
		three.light_color = two.color
		three.omni_range = 64.0 * two.texture_scale * PX * LAMP_REACH
		three.omni_attenuation = 1.4
		three.shadow_enabled = false
		_world.add_child(three)
		_lamps.append([two, three])
	if _outdoor:
		_build_flies(place)
	_sync_light()
	_sync(0.0)


## Everything flat in the place is moved into a small picture of its own and painted once;
## that picture is the floor of the 3D world.
func _paint_ground(stage: Node2D, ysort: Node2D, place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	var margin := MARGIN if _outdoor else Vector2.ZERO
	_port = SubViewport.new()
	_port.size = Vector2i(size + margin * 2.0)
	_port.transparent_bg = not _outdoor
	_port.disable_3d = true
	_port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_port.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_port)
	_port.canvas_transform = Transform2D(0.0, margin)
	for c in stage.get_children():
		if c == ysort or c is Label or c is CanvasModulate or c is PointLight2D or c is CPUParticles2D:
			continue
		c.reparent(_port, false)
	_ground_params = {
		"ground_tex": _port.get_texture(),
		"ground_rect": Vector4(-margin.x * PX, -margin.y * PX, (size.x + margin.x * 2.0) * PX, (size.y + margin.y * 2.0) * PX),
		"grey": 0.12 if _outdoor else 0.0,
	}
	var mat := ShaderMaterial.new()
	mat.shader = _floor_shader
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	var plane := PlaneMesh.new()
	plane.size = (size + margin * 2.0) * PX
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = mat
	floor_mesh.position = Vector3(size.x * 0.5 * PX, 0.0, size.y * 0.5 * PX)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(floor_mesh)
	if _outdoor:
		# the same ground far beyond the painted part, so no edge of the world shows
		var far_mat := ShaderMaterial.new()
		var far_shader := Shader.new()
		far_shader.code = Stage.GROUND_CODE
		far_mat.shader = far_shader
		var img := Art.tex(String(place.get("ground", "hub_grass"))).get_image()
		if img.is_compressed():
			img.decompress()
		far_mat.set_shader_parameter("ground_tex", ImageTexture.create_from_image(img))
		far_mat.set_shader_parameter("cell", Vector2(img.get_width() * PX, img.get_height() * PX))
		far_mat.set_shader_parameter("texel", Vector2(0.5 / img.get_width(), 0.5 / img.get_height()))
		far_mat.set_shader_parameter("grey", 0.12)
		var far_plane := PlaneMesh.new()
		far_plane.size = Vector2(size.x * PX + 400.0, size.y * PX + 400.0)
		var far := MeshInstance3D.new()
		far.mesh = far_plane
		far.material_override = far_mat
		far.position = Vector3(size.x * 0.5 * PX, -0.03, size.y * 0.5 * PX)
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(far)


func _has_animation(node: Node) -> bool:
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.get_frame_count(a.animation) > 1:
			return true
	for c in node.get_children():
		if _has_animation(c):
			return true
	return false


func _labels_under(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels_under(c))
	return out


func _holder_of(node: Node, ysort: Node) -> Node2D:
	var n := node
	while n != null and n.get_parent() != ysort:
		n = n.get_parent()
	return n as Node2D


# ------------------------------------------------------------------ one picture -> one card
## What a flat sprite looks like as an upright card: its texture, the part of it shown, and where
## its four corners go, measured from the foot point of the thing it belongs to (its holder).
## Returns {} for things that are not pictures (or are the round 2D shadow, which is not needed).
func _card_of(sprite: Node, holder: Node2D, ysort: Node2D) -> Dictionary:
	var tex: Texture2D = null
	var rect := Rect2()
	var flip_h := false
	var flip_v := false
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		tex = s.texture
		if tex == null or tex == EnemyScript.shadow_texture():
			return {}
		rect = s.get_rect()
		flip_h = s.flip_h
		flip_v = s.flip_v
	elif sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return {}
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return {}
		var sz := tex.get_size()
		rect = Rect2(a.offset - (sz * 0.5 if a.centered else Vector2.ZERO), sz)
		flip_h = a.flip_h
		flip_v = a.flip_v
	else:
		return {}
	var uv := Vector4(0.0, 0.0, 1.0, 1.0)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var whole := at.atlas.get_size()
		uv = Vector4(at.region.position.x / whole.x, at.region.position.y / whole.y, at.region.size.x / whole.x, at.region.size.y / whole.y)
		tex = at.atlas
	elif sprite is Sprite2D and (sprite as Sprite2D).region_enabled:
		var rr := (sprite as Sprite2D).region_rect
		var whole2 := tex.get_size()
		uv = Vector4(rr.position.x / whole2.x, rr.position.y / whole2.y, rr.size.x / whole2.x, rr.size.y / whole2.y)
	# where the sprite is, seen from its holder's foot point (the holder's own size counts too)
	var rel: Transform2D = ysort.global_transform.affine_inverse() * (sprite as Node2D).global_transform
	rel.origin -= holder.position
	var across := rel.x * rect.size.x
	var down := rel.y * rect.size.y
	if flip_h:
		across = -across
	if flip_v:
		down = -down
	var centre := rel * rect.get_center()
	var low := centre.y + absf(rel.y.y * rect.size.y) * 0.5 + absf(rel.x.y * rect.size.x) * 0.5      # the lowest point, px below the foot
	return {"tex": tex, "uv": uv, "x": _stood(across), "y": _stood(-down), "at": _stood(centre), "low": low,
		"tint": _tint_of(sprite, holder), "seen": _seen(sprite, holder)}


## A step on the flat picture (px; y down) as a step on a standing card (y up, leaned back).
func _stood(v: Vector2) -> Vector3:
	return (Vector3(v.x, 0.0, 0.0) + _up * -v.y) * PX


## Colour and see-through-ness handed down from the holder to this sprite.
func _tint_of(node: Node, holder: Node) -> Color:
	var c := Color.WHITE
	var n := node
	while n != null:
		if n is CanvasItem:
			c *= (n as CanvasItem).modulate
			if n == node:
				c *= (n as CanvasItem).self_modulate
		if n == holder:
			break
		n = n.get_parent()
	return c


## Is this sprite shown? (The whole flat picture is hidden, so each step is asked by hand.)
func _seen(node: Node, holder: Node) -> bool:
	var n := node
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		if n == holder:
			break
		n = n.get_parent()
	return true


func _sprites_under(node: Node, out: Array) -> void:
	if node is Sprite2D or node is AnimatedSprite2D:
		out.append(node)
	for c in node.get_children():
		_sprites_under(c, out)


func _shine_of(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var path := tex.resource_path
	if path.contains("hub_flame"):
		return 2.4
	if path.contains("hub_fire") or path.contains("hub_flava") or path.contains("hub_rune"):
		return 0.5
	return 0.0


func _where(holder: Node2D) -> Vector3:
	return Vector3(holder.position.x * PX, 0.0, holder.position.y * PX)


# ------------------------------------------------------------------ things that never move
func _batch_holder(holder: Node2D, ysort: Node2D, batches: Dictionary) -> void:
	var sprites: Array = []
	_sprites_under(holder, sprites)
	var cards: Array = []
	var lift := 0.0
	for s: Node in sprites:
		var card := _card_of(s, holder, ysort)
		if card.is_empty() or not bool(card["seen"]) or (card["tint"] as Color).a < 0.4:
			continue
		cards.append(card)
		lift = maxf(lift, float(card["low"]))
	var foot := _where(holder)
	for i in cards.size():
		var card: Dictionary = cards[i]
		var tex: Texture2D = card["tex"]
		var key := "%d|%s|%s" % [tex.get_rid().get_id(), card["uv"], (card["tint"] as Color).to_html(false)]
		if not batches.has(key):
			batches[key] = {"tex": tex, "uv": card["uv"], "tint": card["tint"], "at": [], "shade": []}
		var origin := foot + (card["at"] as Vector3) + _up * (lift * PX) + Vector3(0.0, 0.0, i * 0.004)
		(batches[key]["at"] as Array).append(Transform3D(Basis(card["x"], card["y"], Vector3(0, 0, 1)), origin))
		(batches[key]["shade"] as Array).append(_shade_transform(card, foot, lift))


## A card laid down on the ground along the shadow's lean.
func _shade_transform(card: Dictionary, foot: Vector3, lift: float) -> Transform3D:
	var x: Vector3 = card["x"]
	var y: Vector3 = card["y"]
	var c: Vector3 = (card["at"] as Vector3) + _up * (lift * PX)
	return Transform3D(Basis(_laid(x), _laid(y), Vector3(0, 1, 0)), foot + _laid(c) + Vector3(0.0, 0.02, 0.0))


func _laid(v: Vector3) -> Vector3:
	return Vector3(v.x + LEAN.x * v.y, 0.0, v.z + LEAN.y * v.y)


func _material(tex: Texture2D, uv: Vector4, tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _card_shader
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("shine", _shine_of(tex))
	return mat


func _shade_material(tex: Texture2D, uv: Vector4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shade_shader
	for k: String in _ground_params:
		mat.set_shader_parameter(k, _ground_params[k])
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("uv_rect", uv)
	return mat


func _flush(batches: Dictionary) -> void:
	for key: String in batches:
		var b: Dictionary = batches[key]
		for pass_name: String in ["at", "shade"]:
			var list: Array = b[pass_name]
			var quad := _unit.duplicate() as QuadMesh
			quad.material = _material(b["tex"], b["uv"], b["tint"]) if pass_name == "at" else _shade_material(b["tex"], b["uv"])
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(node)


# ------------------------------------------------------------------ things that move
func _new_card() -> Dictionary:
	var body := MeshInstance3D.new()
	body.mesh = _unit
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.material_override = _material(null, Vector4(0, 0, 1, 1), Color.WHITE)
	_world.add_child(body)
	var shade := MeshInstance3D.new()
	shade.mesh = _unit
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.material_override = _shade_material(null, Vector4(0, 0, 1, 1))
	_world.add_child(shade)
	return {"body": body, "shade": shade, "tex": null, "stamp": 0}


func _sync_holder(entry: Dictionary, ysort: Node2D, stamp: int) -> void:
	var holder: Node2D = entry["node"]
	var cards: Dictionary = entry["cards"]
	var sprites: Array = []
	_sprites_under(holder, sprites)
	var found: Array = []
	var lift := 0.0
	for s: Node in sprites:
		if s.is_queued_for_deletion():
			continue
		var card := _card_of(s, holder, ysort)
		if card.is_empty():
			continue
		card["id"] = s.get_instance_id()
		found.append(card)
		if bool(card["seen"]):
			lift = maxf(lift, float(card["low"]))
	var foot := _where(holder)
	for i in found.size():
		var card: Dictionary = found[i]
		var id: int = card["id"]
		if not cards.has(id):
			cards[id] = _new_card()
		var mine: Dictionary = cards[id]
		mine["stamp"] = stamp
		var body: MeshInstance3D = mine["body"]
		var shade: MeshInstance3D = mine["shade"]
		var tint: Color = card["tint"]
		var show := bool(card["seen"]) and tint.a >= 0.4
		body.visible = show
		shade.visible = show
		if not show:
			continue
		var tex: Texture2D = card["tex"]
		var bm: ShaderMaterial = body.material_override
		var sm: ShaderMaterial = shade.material_override
		if mine["tex"] != tex:
			mine["tex"] = tex
			bm.set_shader_parameter("tex", tex)
			bm.set_shader_parameter("shine", _shine_of(tex))
			sm.set_shader_parameter("tex", tex)
		bm.set_shader_parameter("uv_rect", card["uv"])
		sm.set_shader_parameter("uv_rect", card["uv"])
		bm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		body.transform = Transform3D(Basis(card["x"], card["y"], Vector3(0, 0, 1)), foot + (card["at"] as Vector3) + _up * (lift * PX) + Vector3(0.0, 0.0, i * 0.004))
		shade.transform = _shade_transform(card, foot, lift)
	for id: int in cards.keys():
		if int(cards[id]["stamp"]) != stamp:
			(cards[id]["body"] as Node).queue_free()
			(cards[id]["shade"] as Node).queue_free()
			cards.erase(id)


# ------------------------------------------------------------------ words
func _twin(label: Label, holder: Node2D) -> void:
	var copy := label.duplicate() as Label
	copy.visible = false
	copy.modulate = Color.WHITE
	copy.material = null
	copy.z_index = 0
	_words.add_child(copy)
	_twins.append([label, copy, holder])


func _sync_words(zoom: float) -> void:
	var ysort: Node2D = hub._ysort
	for trio: Array in _twins:
		var label: Label = trio[0]
		var copy: Label = trio[1]
		if not is_instance_valid(label) or not is_instance_valid(copy):
			continue
		var holder: Node2D = trio[2]
		var shown := label.visible and label.text != "" and (holder == null or _seen(label, holder))
		copy.visible = shown
		if not shown:
			continue
		copy.text = label.text
		var rel: Transform2D = ysort.global_transform.affine_inverse() * label.get_global_transform()
		var foot2 := rel * Vector2(label.size.x * 0.5, label.size.y)       # the middle of its bottom edge
		var p := Vector3(foot2.x * PX, 0.0, foot2.y * PX)
		if holder != null and is_instance_valid(holder):
			p = _where(holder) + _stood(foot2 - holder.position)
		copy.scale = rel.get_scale() * zoom
		copy.visible = not cam.is_position_behind(p)
		var at := cam.unproject_position(p)
		copy.position = (at - Vector2(copy.size.x * 0.5, copy.size.y) * copy.scale).round()


# ------------------------------------------------------------------ light and air
func _build_flies(place: Dictionary) -> void:
	var size: Vector2 = place["size"]
	_flies = CPUParticles3D.new()
	_flies.amount = clampi(int(size.x * size.y / 5000.0), 30, 160)
	_flies.lifetime = 7.0
	_flies.preprocess = 7.0
	_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flies.emission_box_extents = Vector3(size.x * 0.5 * PX, 1.2, size.y * 0.5 * PX)
	_flies.position = Vector3(size.x * 0.5 * PX, 1.6, size.y * 0.5 * PX)
	_flies.gravity = Vector3(0.0, 0.03, 0.0)
	_flies.direction = Vector3(1.0, 0.2, 0.0)
	_flies.spread = 180.0
	_flies.initial_velocity_min = 0.08
	_flies.initial_velocity_max = 0.3
	_flies.scale_amount_min = 0.5
	_flies.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	_flies.color_ramp = ramp
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = g
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = dot
	m.albedo_color = Color(0.85, 1.0, 0.45) * 1.6
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.render_priority = 10             # after the blur pass (see stage.gd, lesson 3)
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = m
	_flies.mesh = q
	_world.add_child(_flies)


## The colour of the day (hub.gd's CanvasModulate) becomes the sky light, the dark and the mist.
func _sync_light() -> void:
	var sky := Color.WHITE
	if _outdoor and is_instance_valid(hub._sky_node):
		sky = (hub._sky_node as CanvasModulate).color
	var bright := clampf((sky.g - 0.55) / 0.45, 0.0, 1.0)           # 1 by day, 0 in the middle of the night
	if _outdoor:
		# soft, warm light by day (the owner: "very soft light"): a golden sun, cooler shade
		_sun.light_color = (sky * Color(1.0, 0.88, 0.68)).lerp(sky, 1.0 - bright)
		_sun.light_energy = lerpf(0.30, 0.86, bright)
		_env.ambient_light_color = sky.lerp(Color(0.55, 0.65, 1.0), 0.35 * (1.0 - bright)) * Color(0.86, 0.9, 1.0)
		_env.ambient_light_energy = lerpf(0.36, 0.54, bright)
		var mist := Color(0.06, 0.10, 0.18).lerp(Color(0.66, 0.60, 0.46), bright) * sky
		_env.background_color = mist
		_env.fog_enabled = true
		_env.fog_light_color = mist
		_env.fog_density = 0.003
		_env.fog_sky_affect = 1.0
		_lift = 0.03 * bright
	else:
		_sun.light_color = Color(1.0, 0.96, 0.9)
		_sun.light_energy = 0.6
		_env.ambient_light_color = Color(1.0, 0.95, 0.88)
		_env.ambient_light_energy = 0.55
		_env.background_color = Color("07060a")
		_env.fog_enabled = false
		_lift = 0.02
	for pair: Array in _lamps:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			(pair[1] as OmniLight3D).light_energy = (pair[0] as PointLight2D).energy * LAMP_ENERGY
	if is_instance_valid(_flies) and is_instance_valid(hub._flies):
		_flies.emitting = (hub._flies as CPUParticles2D).emitting


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if hub == null or not is_instance_valid(hub._stage) or not is_instance_valid(_world):
		return
	_sync(delta)


func _sync(_delta: float) -> void:
	var ysort: Node2D = hub._ysort
	# somebody new has walked in since the place was built
	if ysort.get_child_count() != _known:
		_known = ysort.get_child_count()
		for holder in ysort.get_children():
			if holder is Node2D and not _live.has(holder.get_instance_id()) and not _still.has(holder.get_instance_id()):
				_live[holder.get_instance_id()] = {"node": holder, "cards": {}}
	var stamp := Engine.get_process_frames() + 1
	for id: int in _live.keys():
		var entry: Dictionary = _live[id]
		if not is_instance_valid(entry["node"]):
			for card: Dictionary in (entry["cards"] as Dictionary).values():
				(card["body"] as Node).queue_free()
				(card["shade"] as Node).queue_free()
			_live.erase(id)
			continue
		_sync_holder(entry, ysort, stamp)
	_sync_light()
	# the camera stands where the flat one does, looking down at the same spot
	var flat_cam: Camera2D = hub._cam
	var zoom := maxf(flat_cam.zoom.x, 0.05)
	var centre := flat_cam.get_screen_center_position()
	var view_h := UI.screen_size(hub).y / zoom * PX
	_dist = view_h / (2.0 * tan(deg_to_rad(FOV * 0.5)))
	var target := Vector3(centre.x * PX, 0.6, centre.y * PX)
	var pitch := deg_to_rad(_pitch)
	cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * _dist
	cam.look_at(target, Vector3.UP)
	var mat: ShaderMaterial = _post.material_override
	mat.set_shader_parameter("focus", _dist)
	mat.set_shader_parameter("sharp", _dist * 0.24)
	mat.set_shader_parameter("falloff", _dist * 0.9)
	mat.set_shader_parameter("blur_px", 5.0)
	mat.set_shader_parameter("rim", 0.38)
	mat.set_shader_parameter("lift", _lift)
	mat.set_shader_parameter("haze", Vector3(1.0, 0.85, 0.63))
	_sync_words(zoom)
