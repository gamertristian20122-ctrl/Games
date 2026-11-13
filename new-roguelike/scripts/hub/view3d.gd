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
## REAL DEPTH (v0.20.0, the owner: "depth first and graphics and quality"). Three things in a
## place's data are built here as true 3D instead of flat cards:
##   "houses"  [{"at", "wide", "deep", "wall", "roof", "rise", "gable", "door", "windows", ...}]
##             a box of walls with a sloped roof, a chimney that smokes, a door and windows on
##             the front, and a shadow of its true shape (_build_house)
##   "rise"    {"from", "over", "height", "mound"}  the ground climbs behind the place, and
##   "hills"   [{"at", "radius", "height", "top"}]  hills you walk on: the floor is a mesh with
##             height and everything standing on it stands that high (_height)
##   "water"   [{"at", "radius"}]  a pond: ripples, the sky in it, glints of sun (WATER_CODE)
## Plants sway in the wind. (hub.gd shows houses as flat pieces and water as a flat shape when
## the 3D look is off.)
## On top: flat shadows, mist, glow, fireflies and the blur away from the knight (as in
## scripts/battle/stage.gd, whose lessons apply here too).
## The flat 2D picture is hidden, not removed: `--flat` on the command line shows the old look.
## THE FILES (split on 12 Nov 2026 so that people can work on them side by side):
##   scripts/hub/view3d.gd         this file: setup, rebuild, the cards that follow hub.gd, words, camera
##   scripts/hub/view3d_build.gd   ground, height, houses, roofs, flat shadows (`build`)
##   scripts/hub/view3d_water.gd   ponds (`water`)
##   scripts/fx/card_shader.gd     how a standing picture and its flat shadow are drawn and lit
##   scripts/fx/hd_light.gd        environment, sun, lamps, the last pass, sky effects (`light`)
## One world unit is 16 art pixels: 2D (x, y) is 3D (x / 16, 0, y / 16).

const Sprite3 = preload("res://scripts/battle/sprite3.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const UI = preload("res://scripts/ui/theme.gd")
const CardShader = preload("res://scripts/fx/card_shader.gd")
const HdLight = preload("res://scripts/fx/hd_light.gd")
const Build = preload("res://scripts/hub/view3d_build.gd")
const Water = preload("res://scripts/hub/view3d_water.gd")
const Hd = preload("res://scripts/fx/hd.gd")

const PX := 1.0 / 16.0
const PITCH := 35.0                 ## how steeply the camera looks down out of doors, in degrees (low, like a stage)
const PITCH_INDOORS := 62.0         ## a room is one painted picture: looked at more from above, it keeps its shape
const TILT := 8.0                   ## how far standing things lean back towards the camera, out of doors ...
const TILT_INDOORS := 45.0          ## ... and in a room (so people are not squashed by the steep view)
const FOV := 30.0
const WIDE := 1.3                   ## out of doors the camera stands this much further back than the flat one: whole houses fit, people are smaller
const LEAN := HdLight.LEAN          ## which way a shadow falls on the ground, per unit of height

var hub: Node2D
var cam: Camera3D
var build: Build                   ## scripts/hub/view3d_build.gd: ground, height, houses
var water: Water                   ## scripts/hub/view3d_water.gd: ponds
var light: HdLight                 ## scripts/fx/hd_light.gd: environment, sun, lamps, the last pass
var _world: Node3D                 ## everything of the current place; freed and rebuilt on rebuild()
var _words: Control                ## the labels shown over the 3D picture
var _unit := QuadMesh.new()
var _live := {}                    ## holder id -> {"node": Node2D, "cards": {sprite id -> card}}
var _known := 0                    ## how many children `_ysort` had when last looked at
var _still := {}                   ## holder id -> true: things already drawn in a batch
var _twins: Array = []             ## [Label in the flat picture, its copy here, holder or null]
var _outdoor := false
var _dist := 21.0
var _pitch := PITCH
var _up := Vector3.UP              ## "up" for a standing card: straight up, leaned back by the tilt


func setup(the_hub: Node2D) -> void:
	hub = the_hub
	process_priority = 100             # after hub.gd has moved everybody
	Sprite3.ensure_sun()
	_unit.size = Vector2.ONE
	build = Build.new(self)
	water = Water.new(self)
	light = HdLight.new(self)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.5
	cam.far = 260.0
	add_child(cam)
	cam.current = true
	light.setup()
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
	var place: Dictionary = hub.place
	build.reset(place)
	water.reset()
	light.reset()
	for pair: Array in _twins:
		if is_instance_valid(pair[1]):
			(pair[1] as Node).free()
	_twins.clear()
	_live.clear()
	_still.clear()
	_known = 0
	_world = Node3D.new()
	add_child(_world)
	var stage: Node2D = hub._stage
	var ysort: Node2D = hub._ysort
	_outdoor = bool(place.get("outdoor", false))
	_pitch = PITCH if _outdoor else PITCH_INDOORS
	var tilt := deg_to_rad(TILT if _outdoor else TILT_INDOORS)
	# Standing things are drawn taller by exactly what the camera's slant takes away, so on the
	# screen they keep the shape the artist gave them (they looked squashed before: the owner).
	_up = Vector3(0.0, cos(tilt), -sin(tilt)) / cos(deg_to_rad(_pitch) - tilt)
	build.paint_ground(stage, ysort, place)
	stage.visible = false
	hub._prompt.modulate.a = 0.0
	# standing things: the ones that never move go into batches, the rest are followed live
	var moving := {}
	if is_instance_valid(hub._hero):
		moving[hub._hero.get_instance_id()] = true
	var mate: Variant = hub.get("_mate")
	if mate is Node and is_instance_valid(mate):
		moving[(mate as Node).get_instance_id()] = true
	for p: Dictionary in hub._people:
		moving[(p["node"] as Node).get_instance_id()] = true
	for r: Dictionary in hub._roamers:
		moving[(r["node"] as Node).get_instance_id()] = true
	var batches := {}
	for holder in ysort.get_children():
		if not (holder is Node2D):
			continue
		if moving.has(holder.get_instance_id()) or _has_animation(holder):
			_live[holder.get_instance_id()] = {"node": holder, "cards": {}, "person": moving.has(holder.get_instance_id())}
		else:
			_still[holder.get_instance_id()] = true
			_batch_holder(holder, ysort, batches)
	_known = ysort.get_child_count()
	_flush(batches)
	build.build_houses(place)
	water.build(place)
	# words: signs on the ground, the "!" over people, the name of whoever is in reach
	for l in _labels_under(stage):
		_twin(l, _holder_of(l, ysort))
	_twin(hub._prompt, null)
	light.build_lamps(place)
	if _outdoor:
		light.build_air(place)
	light.sync_light()
	_sync(0.0)


## Is this holder somebody (the knight, the one who walks with him, a person, a roaming monster)?
func _is_person(holder: Node) -> bool:
	if holder == hub._hero or holder == hub.get("_mate"):
		return true
	for p: Dictionary in hub._people:
		if p["node"] == holder:
			return true
	for r: Dictionary in hub._roamers:
		if r["node"] == holder:
			return true
	return false


## The ground's height under a spot of the flat picture (scripts/hub/view3d_build.gd).
func _height(at: Vector2) -> float:
	return build.height(at)


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


func _where(holder: Node2D) -> Vector3:
	return Vector3(holder.position.x * PX, _height(holder.position), holder.position.y * PX)


func _where_at(at: Vector2) -> Vector3:
	return Vector3(at.x * PX, _height(at), at.y * PX)


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
		var ok := build.shadow_ok(holder.position, (card["y"] as Vector3).length())
		(batches[key]["shade"] as Array).append(_shade_transform(card, foot if ok else foot + Vector3(0, -50, 0), lift))


## A card laid down on the ground along the shadow's lean.
func _shade_transform(card: Dictionary, foot: Vector3, lift: float) -> Transform3D:
	var x: Vector3 = card["x"]
	var y: Vector3 = card["y"]
	var c: Vector3 = (card["at"] as Vector3) + _up * (lift * PX)
	return Transform3D(Basis(_laid(x), _laid(y), Vector3(0, 1, 0)), foot + _laid(c) + Vector3(0.0, 0.02, 0.0))


func _laid(v: Vector3) -> Vector3:
	return Vector3(v.x + LEAN.x * v.y, 0.0, v.z + LEAN.y * v.y)


func _flush(batches: Dictionary) -> void:
	for key: String in batches:
		var b: Dictionary = batches[key]
		for pass_name: String in (["at"] if Hd.on() else ["at", "shade"]):     # HD: real shadows instead of flat copies
			var list: Array = b[pass_name]
			var quad := _unit.duplicate() as QuadMesh
			quad.material = CardShader.card(b["tex"], b["uv"], b["tint"]) if pass_name == "at" else CardShader.shade(build.ground_params, b["tex"], b["uv"])
			if pass_name == "at":
				(quad.material as ShaderMaterial).set_shader_parameter("sway", CardShader.sway_of(b["tex"]))
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = CardShader.casts() if pass_name == "at" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(node)


# ------------------------------------------------------------------ things that move
## A card that follows a moving picture. `person`: somebody (HD keeps them readable: CardShader).
func _new_card(person := false) -> Dictionary:
	var body := MeshInstance3D.new()
	body.mesh = _unit
	body.cast_shadow = CardShader.casts()
	body.material_override = CardShader.card(null, Vector4(0, 0, 1, 1), Color.WHITE, person)
	_world.add_child(body)
	var shade := MeshInstance3D.new()
	shade.mesh = _unit
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.material_override = CardShader.shade(build.ground_params, null, Vector4(0, 0, 1, 1))
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
			cards[id] = _new_card(bool(entry.get("person", false)))
		var mine: Dictionary = cards[id]
		mine["stamp"] = stamp
		var body: MeshInstance3D = mine["body"]
		var shade: MeshInstance3D = mine["shade"]
		var tint: Color = card["tint"]
		var show := bool(card["seen"]) and tint.a >= 0.4
		body.visible = show
		shade.visible = show and not Hd.on()
		if not show:
			continue
		var tex: Texture2D = card["tex"]
		var bm: ShaderMaterial = body.material_override
		var sm: ShaderMaterial = shade.material_override
		if mine["tex"] != tex:
			mine["tex"] = tex
			bm.set_shader_parameter("tex", tex)
			CardShader.set_glow(bm, tex, bool(entry.get("person", false)))
			sm.set_shader_parameter("tex", tex)
		bm.set_shader_parameter("uv_rect", card["uv"])
		sm.set_shader_parameter("uv_rect", card["uv"])
		bm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		body.transform = Transform3D(Basis(card["x"], card["y"], Vector3(0, 0, 1)), foot + (card["at"] as Vector3) + _up * (lift * PX) + Vector3(0.0, 0.0, i * 0.004))
		shade.transform = _shade_transform(card, foot, lift)
		if build.has_height and not build.shadow_ok(holder.position, (card["y"] as Vector3).length()):
			shade.visible = false
	if Hd.on() and bool(entry.get("person", false)):
		# a soft dark spot where the feet meet the ground (ambient shade: never floating)
		if not entry.has("blob"):
			entry["blob"] = _contact_blob()
		var blob: MeshInstance3D = entry["blob"]
		blob.visible = holder.visible and not found.is_empty()
		blob.position = foot + Vector3(0.0, 0.03, 0.06)
	for id: int in cards.keys():
		if int(cards[id]["stamp"]) != stamp:
			(cards[id]["body"] as Node).queue_free()
			(cards[id]["shade"] as Node).queue_free()
			cards.erase(id)


static var _blob_mat: StandardMaterial3D
func _contact_blob() -> MeshInstance3D:
	if _blob_mat == null:
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = HdLight.dot()
		_blob_mat.albedo_color = Color(0.03, 0.02, 0.02, 0.55)
		_blob_mat.disable_fog = true
		_blob_mat.render_priority = 3
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.95, 0.42)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = _blob_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(m)
	return m


## HD: where a person is on the screen (for Sprite3.set_people): the rect round all their cards,
## a few px wider, and the view distance of their feet and of their head.
func _person_row(entry: Dictionary, rows: Array) -> void:
	var vp := get_viewport().get_visible_rect().size
	var to_view := cam.global_transform.affine_inverse()
	var lo := Vector2.INF
	var hi := -Vector2.INF
	var foot_z := -INF
	var head_z := INF
	var any := false
	for card: Dictionary in (entry["cards"] as Dictionary).values():
		var body: MeshInstance3D = card["body"]
		if not body.visible:
			continue
		var b := body.global_transform.basis
		var o := body.global_transform.origin
		for k: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			var p := o + b.x * k.x + b.y * k.y
			if cam.is_position_behind(p):
				continue
			var at := cam.unproject_position(p)
			lo = lo.min(at)
			hi = hi.max(at)
			any = true
		foot_z = maxf(foot_z, -(to_view * (o - b.y * 0.5)).z)
		head_z = minf(head_z, -(to_view * (o + b.y * 0.5)).z)
	if not any or lo.x > vp.x or lo.y > vp.y or hi.x < 0.0 or hi.y < 0.0:
		return
	var pad := Vector2(4.0, 4.0)
	rows.append([Rect2((lo - pad) / vp, (hi - lo + pad * 2.0) / vp), foot_z, head_z])


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
				_live[holder.get_instance_id()] = {"node": holder, "cards": {}, "person": _is_person(holder)}
	var stamp := Engine.get_process_frames() + 1
	for id: int in _live.keys():
		var entry: Dictionary = _live[id]
		if not is_instance_valid(entry["node"]):
			for card: Dictionary in (entry["cards"] as Dictionary).values():
				(card["body"] as Node).queue_free()
				(card["shade"] as Node).queue_free()
			if entry.has("blob") and is_instance_valid(entry["blob"]):
				(entry["blob"] as Node).queue_free()
			_live.erase(id)
			continue
		_sync_holder(entry, ysort, stamp)
	light.sync_light()
	# the camera stands where the flat one does, looking down at the same spot
	var flat_cam: Camera2D = hub._cam
	var zoom := maxf(flat_cam.zoom.x, 0.05)
	var centre := flat_cam.get_screen_center_position()
	var view_h := UI.screen_size(hub).y / zoom * PX
	_dist = view_h / (2.0 * tan(deg_to_rad(FOV * 0.5))) * (WIDE if _outdoor else 1.0)
	var target := Vector3(centre.x * PX, 0.6 + _height(centre), centre.y * PX)
	var pool_at := Vector2(target.x, target.z)
	if _outdoor:
		# look a little past the knight: more of the distance, where the depth is (HD: further, so the
		# facades and roofs of the north side stand over the play and the knight is low in the middle)
		target.z -= view_h * (0.27 if Hd.on() else 0.14)
	var pitch := deg_to_rad(_pitch)
	cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * _dist
	cam.look_at(target, Vector3.UP)
	var people: Array = []
	if Hd.on():
		var rows: Array = []
		for id: int in _live:
			if bool(_live[id].get("person", false)) and is_instance_valid(_live[id]["node"]):
				people.append(_where(_live[id]["node"]))
				_person_row(_live[id], rows)
		Sprite3.set_people(rows)
	light.sync_view(_delta, _dist, target, centre, pool_at, people)
	_sync_words(zoom)
