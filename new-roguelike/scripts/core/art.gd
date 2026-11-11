extends Node
## Art (autoload): turns a sprite id like "knight_m" or "coin" into textures and animations.
## It finds files by name, so adding art is just dropping PNGs into a folder in DIRS
## and running `godot --headless --path . --import` once.
##
## File naming it understands (the 0x72 pack's own naming):
##   <id>.png                         a still image
##   <id>_idle_anim_f0.png ...        animation "idle"
##   <id>_run_anim_f0.png ...         animation "run"
##   <id>_hit_anim_f0.png ...         animation "hit"
##   <id>_anim_f0.png or <id>_f0.png  animation "default"
##   <id>_death_anim_f0.png ...       animation "death"  (plays once; only where the pack has one)
##   <id>_attack_anim_f0.png ...      animation "attack" (plays once; only where the pack has one)
## Every SpriteFrames it returns has the first four names; missing ones reuse what exists.
## "death" and "attack" are never faked: ask Art.has_anim(id, "death") before playing them
## (the same question works for "hit": true only when the pack really drew one).
##
## The purchased Pixel Crawler cast (ids pc_*, written by tools/pc_import_cast.py) also comes with
## measurements in assets/art/pc/pc_cast.json. Art.meta(id) hands them out: "feet" (where the
## feet are on the canvas; Art.sprite() stands the sprite on that point), "body_height",
## "body_width", "radius", "frames". Ids without measurements get an empty Dictionary.

## dungeon = the main pack (0x72). niji, forest and fx are written by tools/import_assets.py.
## pc = the purchased Pixel Crawler cast and weapons (tools/pc_import_cast.py).
const DIRS: Array[String] = [
	"res://assets/art/dungeon/", "res://assets/art/niji/", "res://assets/art/forest/", "res://assets/art/fx/",
	"res://assets/art/pc/", "res://assets/art/props/", "res://assets/art/boss/", "res://assets/art/icons/",
]
const ANIMS := [["idle", "_idle_anim"], ["run", "_run_anim"], ["hit", "_hit_anim"], ["default", "_anim"], ["default", ""],
	["death", "_death_anim"], ["attack", "_attack_anim"]]
const FPS := {"idle": 6.0, "run": 10.0, "hit": 8.0, "default": 8.0, "death": 10.0, "attack": 12.0}
const PC_FPS := {"hit": 14.0}                 ## the Pixel Crawler hit animations are 4 frames: play them quickly
const ONCE := ["hit", "death", "attack"]       ## these never loop
const EXTRA := ["death", "attack"]             ## only added when the pack has them
const META_FILE := "res://assets/art/pc/pc_cast.json"
const NO_META := {}

var _tex := {}
var _frames := {}
var _real := {}          ## id -> the animation names the pack really has
var _palette := {}
var _meta := {}
var _meta_loaded := false
var _missing: Texture2D


func _find(file_name: String) -> String:
	for d in DIRS:
		if ResourceLoader.exists(d + file_name):
			return d + file_name
	return ""


func has(id: String) -> bool:
	return _find(id + ".png") != "" or frames(id) != null


## A single image: the still, or the first frame of the animation. Never null (a pink square if missing).
func tex(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var t: Texture2D = null
	var path := _find(id + ".png")
	if path != "":
		t = load(path)
	else:
		var sf := frames(id)
		if sf != null:
			t = sf.get_frame_texture("idle", 0)
	if t == null:
		push_warning("Art: no sprite called '%s'" % id)
		t = _placeholder()
	_tex[id] = t
	return t


## Animations for an id, or null when the id has no animation frames.
func frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var found := {}
	for pair in ANIMS:
		var anim: String = pair[0]
		if found.has(anim):
			continue
		var list: Array[Texture2D] = []
		while true:
			var path := _find("%s%s_f%d.png" % [id, pair[1], list.size()])
			if path == "" and list.is_empty():
				# pack quirk: the plain zombie's first frame is called "_f10" instead of "_f0"
				path = _find("%s%s_f10.png" % [id, pair[1]])
			if path == "":
				break
			list.append(load(path))
		if not list.is_empty():
			found[anim] = list
	var sf: SpriteFrames = null
	if not found.is_empty():
		sf = SpriteFrames.new()
		sf.remove_animation("default")
		var fallback: Array = found.values()[0]
		var pc := id.begins_with("pc_")
		for anim in ["idle", "run", "hit", "default", "death", "attack"]:
			if EXTRA.has(anim) and not found.has(anim):
				continue
			var source: Array = found.get(anim, found.get("idle", found.get("default", fallback)))
			sf.add_animation(anim)
			sf.set_animation_speed(anim, PC_FPS.get(anim, FPS[anim]) if pc else FPS[anim])
			sf.set_animation_loop(anim, not ONCE.has(anim))
			for t in source:
				sf.add_frame(anim, t)
	_frames[id] = sf
	_real[id] = found.keys()
	return sf


## True when the pack really has this animation for the id ("hit", "death", "attack", ...).
func has_anim(id: String, anim: String) -> bool:
	if not _real.has(id):
		frames(id)
	return (_real[id] as Array).has(anim)


## How long one play of an animation lasts, in seconds (0 when the id does not have it).
func anim_time(id: String, anim: String) -> float:
	var sf := frames(id)
	if sf == null or not sf.has_animation(anim):
		return 0.0
	return float(sf.get_frame_count(anim)) / maxf(sf.get_animation_speed(anim), 0.01)


## Measurements for a Pixel Crawler id (see the top of this file). Empty for every other id.
## The file is read once, the first time anybody asks.
func meta(id: String) -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		var f := FileAccess.open(META_FILE, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_meta = parsed
		else:
			push_warning("Art: cannot read %s" % META_FILE)
	return _meta.get(id, NO_META)


## Where the top-left corner of the image goes so that the FEET sit on the node's origin.
## Measured ids use their "feet" point; everything else stands on the bottom-centre of the image.
func feet_offset(id: String) -> Vector2:
	var m := meta(id)
	if m.has("feet"):
		return Vector2(-float(m["feet"][0]), -float(m["feet"][1]))
	var sz := size(id)
	return Vector2(-sz.x / 2.0, -sz.y)


## A ready-to-use sprite node whose origin is the FEET (bottom-centre of the image, or the
## measured "feet" point of a Pixel Crawler id), so entities can be y-sorted by position.
## Animated ids play `anim`; stills just show.
func sprite(id: String, anim: String = "idle") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	var sf := frames(id)
	if sf == null:
		sf = SpriteFrames.new()
		sf.add_frame("default", tex(id))
		for a in ["idle", "run", "hit"]:
			sf.add_animation(a)
			sf.add_frame(a, tex(id))
	s.sprite_frames = sf
	s.centered = false
	s.offset = feet_offset(id)
	s.play(anim)
	return s


func size(id: String) -> Vector2:
	return tex(id).get_size()


## The main colours of a sprite (most used first, outlines left out). Used for death particles,
## so every enemy bursts into bits of its own colours.
func palette(id: String, max_colors: int = 5) -> Array:
	if _palette.has(id):
		return _palette[id]
	var out: Array = []
	var img := tex(id).get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var counts := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.9 or c.v < 0.22:
					continue
				var key := c.to_rgba32()
				counts[key] = int(counts.get(key, 0)) + 1
		var keys := counts.keys()
		keys.sort_custom(func(a, b): return counts[a] > counts[b])
		for i in mini(max_colors, keys.size()):
			out.append(Color.hex(keys[i]))
	if out.is_empty():
		out.append(Color(0.8, 0.8, 0.8))
	_palette[id] = out
	return out


func _placeholder() -> Texture2D:
	if _missing == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, Color(1, 0, 1) if (x / 4 + y / 4) % 2 == 0 else Color(0.1, 0, 0.1))
		_missing = ImageTexture.create_from_image(img)
	return _missing
