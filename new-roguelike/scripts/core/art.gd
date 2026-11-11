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
##
## The boss art (ids boss_* and boss_fx_*, cut by tools/import_bosses.py) is described by
## assets/art/boss/boss_cast.json. For a boss id Art loads EVERY animation that file lists under
## "frames" (attack2, cast, buff, block, glow, nofire, idle_unarmed, spawn ...), at the pack's own
## frame rate and frame holds where the file gives them (BOSS_GIFS below says which preview GIF
## times which animation), looping only the stand / walk kind. Art.meta(id) hands out the whole
## entry: "feet", "canvas", "hover_px", "radius", "hit_frames", "projectile_spawn", "fx", "notes".
## Art.frame_time(id, anim, frame) says how long after its start an animation reaches a frame.

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
const BOSS_META_FILE := "res://assets/art/boss/boss_cast.json"
const BOSS_FPS := 10.0                       ## boss animations without a stated rate
const BOSS_LOOPS := ["glow", "fly", "nofire", "walk"]   ## boss animations that loop, besides idle* and run*
## Which preview GIF (the keys of "source_fps" in boss_cast.json) times which animation, where
## the pack has one GIF per animation. Bosses not listed here use "all_gifs" or BOSS_FPS.
const BOSS_GIFS := {
	"boss_ogre": {"attack": "ogre-attack.gif", "idle": "ogre-idle.gif", "idle_unarmed": "ogre-idle-unarmed.gif",
		"run": "ogre-walk.gif", "run_unarmed": "ogre-walk-unarmed.gif"},
	"boss_fire_skull": {"idle": "fire-skull.gif", "nofire": "fire-skull-no-fire.gif"},
	"boss_death": {"spawn": "death-lamp-rise.gif", "run": "death-lamp-walk.gif", "run_nolamp": "death-walk.gif"},
	"boss_demon": {"attack": "demon-attack-no-breath.gif", "attack2": "demon-attack.gif", "idle": "demon-idle.gif"},
}
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
	var pairs: Array = ANIMS
	var boss := id.begins_with("boss_")
	var extras: Array = []                   # boss animations beyond the six standard names
	if boss:
		var listed: Variant = meta(id).get("frames")
		if listed is Dictionary:
			pairs = ANIMS.duplicate()
			for extra_name: String in listed:
				if not FPS.has(extra_name):
					pairs.append([extra_name, "_%s_anim" % extra_name])
					extras.append(extra_name)
	for pair in pairs:
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
		var fallback_name: String = "idle" if found.has("idle") else ("default" if found.has("default") else String(found.keys()[0]))
		var pc := id.begins_with("pc_")
		for anim: String in ["idle", "run", "hit", "default", "death", "attack"] + extras:
			if (EXTRA.has(anim) or extras.has(anim)) and not found.has(anim):
				continue
			var from: String = anim if found.has(anim) else fallback_name
			var source: Array = found[from]
			sf.add_animation(anim)
			if boss:
				var timing := _boss_timing(id, from)
				var fps: float = timing[0]
				var holds: Array = timing[1]
				sf.set_animation_speed(anim, fps)
				sf.set_animation_loop(anim, not ONCE.has(anim) if FPS.has(anim) else (anim.begins_with("idle") or anim.begins_with("run") or BOSS_LOOPS.has(anim)))
				for i in source.size():
					sf.add_frame(anim, source[i], float(holds[i]) * fps / 1000.0 if holds.size() == source.size() else 1.0)
				continue
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
	return frame_time(id, anim, sf.get_frame_count(anim))


## Seconds from the start of an animation until `frame` begins (frame holds counted), at normal
## speed. Boss fights use it to time a floor warning so it fills exactly when the blow lands.
func frame_time(id: String, anim: String, frame: int) -> float:
	var sf := frames(id)
	if sf == null or not sf.has_animation(anim):
		return 0.0
	var total := 0.0
	for i in mini(frame, sf.get_frame_count(anim)):
		total += sf.get_frame_duration(anim, i)
	return total / maxf(sf.get_animation_speed(anim), 0.01)


## [frames per second, the pack's hold of each frame in ms (empty = every frame the same)] for a
## boss animation, from "source_fps" in boss_cast.json.
func _boss_timing(id: String, anim: String) -> Array:
	var src: Variant = meta(id).get("source_fps")
	if not (src is Dictionary):
		return [BOSS_FPS, []]
	var v: Variant = src.get(String((BOSS_GIFS.get(id, {}) as Dictionary).get(anim, "")), src.get("all_gifs"))
	if v is Dictionary:
		return [float(v.get("fps", BOSS_FPS)), v.get("frame_ms", [])]
	if v is float or v is int:
		return [float(v), []]
	return [BOSS_FPS, []]


## Measurements for a Pixel Crawler id or a boss id (see the top of this file). Empty for every
## other id. The two files are read once, the first time anybody asks.
func meta(id: String) -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		for file: String in [META_FILE, BOSS_META_FILE]:
			var f := FileAccess.open(file, FileAccess.READ)
			if f == null:
				push_warning("Art: cannot read %s" % file)
				continue
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for key: String in parsed:
					if parsed[key] is Dictionary and not key.begins_with("_"):
						_meta[key] = parsed[key]
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
