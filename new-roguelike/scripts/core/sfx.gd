extends Node
## Sfx (autoload): sound effects and music by name. A missing file is silent, never an error.
##   Sfx.play("coin_pickup")            plays res://assets/audio/sfx/coin_pickup.ogg,
##                                      or a random one of coin_pickup_1.ogg .. coin_pickup_5.ogg
##   Sfx.music("floor1")                crossfades to res://assets/audio/music/floor1.ogg (and fades
##                                      out any ambience: menus and the old rooms have none)
##   Sfx.place("elfwood")               the music, ambience loop and footstep ground of a walking
##                                      place (table PLACES below); scripts/hub/hub.gd enter() calls it
##   Sfx.ambience("woods")              crossfades the looping background of a place ("" = silence)
##   Sfx.walking(moving, delta, pace)   call every frame while walking: steps on the place's ground
##   Sfx.footstep("sand")               one step on grass / stone / sand / wood
##   Sfx.battle(boss)                   battle or boss music; the ambience fades away
##   Sfx.victory()                      the battle music gives way to the short fanfare, played once
## Volumes come from Save settings "sfx_volume" and "music_volume" (0..1). Ambience and steps
## follow the sound volume. Every file's source and licence: assets_raw/licence_notes/.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 14
## names asked for that have no file of their own: played with another one
const ALIASES := {"hit": "enemy_hit", "pickup": "heart_pickup", "ui_move": "ui_click"}
## music played once (no loop)
const ONCE := ["victory", "gameover"]
## a walking place -> [music, ambience, ground underfoot]. A place not listed uses "_".
const PLACES := {
	"room": ["shop", "fire", "wood"],          # your room and the tavern hall: the hearth crackles
	"hall": ["shop", "fire", "wood"],
	"village": ["town", "birds", "stone"],     # Wickmere: birds over the roofs, cobbled lanes
	"elfwood": ["woods", "woods", "grass"],
	"glade": ["woods", "woods", "grass"],
	"deepwood": ["woods", "woods", "grass"],
	"beacon": ["title", "wind", "grass"],      # the bare hilltop of the dark beacon
	"world": ["world", "wind", "grass"],
	"dustwatch": ["shop", "wind", "sand"],     # the desert camp: a market tune in the wind
	"emberfall": ["town", "fire", "stone"],
	"_": ["town", "birds", "grass"],
}
## each ambience loop -> [file in SFX_DIR, how loud it sits (dB, before the sound volume)]
const AMBIENCE := {
	"woods": ["amb_woods", -5.0], "birds": ["amb_birds", -8.0], "wind": ["amb_wind", -6.0],
	"fire": ["torch_fire_loop", -16.0],
}
const STEP_EVERY := 0.36    ## seconds between steps at a normal pace
const STEP_DB := -19.0

var _streams := {}          # name -> Array[AudioStream] (empty when missing)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}      # name -> msec, to stop 20 copies of one sound in a frame
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_role := ""
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_id := ""
var _amb_db := 0.0          # the level of the ambience playing now, before the sound volume
var _surface := "grass"
var _step_t := 0.0
var sfx_volume := 1.0
var music_volume := 0.7
var _closed := false        # set by shutdown(): the game is closing, stay silent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_amb_a = AudioStreamPlayer.new()
	_amb_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b, _amb_a, _amb_b]:
		add_child(p)


func _load(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]
	if ALIASES.has(name):
		_streams[name] = _load(String(ALIASES[name]))
		return _streams[name]
	var list: Array = []
	if ResourceLoader.exists(SFX_DIR + name + ".ogg"):
		list.append(load(SFX_DIR + name + ".ogg"))
	for i in range(1, 6):
		var path := "%s%s_%d.ogg" % [SFX_DIR, name, i]
		if ResourceLoader.exists(path):
			list.append(load(path))
	_streams[name] = list
	return list


func has(name: String) -> bool:
	return not _load(name).is_empty()


## `pitch` shifts the whole sound (0.5 = an octave lower, 2.0 = an octave higher); the Hungry Curse
## reuses existing effects this way instead of adding new recordings.
func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.06, pitch: float = 1.0) -> void:
	if _closed:
		return
	var list := _load(name)
	if list.is_empty() or sfx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 35:
		return
	_last_played[name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db + linear_to_db(sfx_volume)
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.play()


## Crossfade to a music track by role name ("" fades to silence) and fade out any ambience.
## Asking for the track that is already playing does nothing.
func music(role: String, fade: float = 1.0) -> void:
	ambience("", fade)
	_music(role, fade)


func _music(role: String, fade: float = 1.0) -> void:
	if role == _music_role or _closed:
		return
	_music_role = role
	var from := _music_a
	var to := _music_b
	_music_a = to
	_music_b = from
	var tw := create_tween().set_parallel(true)
	tw.tween_property(from, "volume_db", -60.0, fade)
	tw.chain().tween_callback(from.stop)
	var path := MUSIC_DIR + role + ".ogg"
	if role == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = not ONCE.has(role)
	to.stream = stream
	to.volume_db = -60.0
	to.play()
	create_tween().tween_property(to, "volume_db", _music_db(), fade)


## The sound of a walking place (PLACES): its music, its ambience loop and its ground.
func place(id: String) -> void:
	var row: Array = PLACES.get(id, PLACES["_"])
	_surface = String(row[2])
	_music(String(row[0]), 1.6)
	ambience(String(row[1]), 1.6)


## Crossfades the ambience loop ("" fades it out). Asking for the one playing does nothing.
func ambience(id: String, fade: float = 1.2) -> void:
	if id == _amb_id or _closed:
		return
	_amb_id = id
	var from := _amb_a
	var to := _amb_b
	_amb_a = to
	_amb_b = from
	var tw := create_tween().set_parallel(true)
	tw.tween_property(from, "volume_db", -60.0, fade)
	tw.chain().tween_callback(from.stop)
	if not AMBIENCE.has(id):
		return
	var path := SFX_DIR + String(AMBIENCE[id][0]) + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_amb_db = float(AMBIENCE[id][1])
	to.stream = stream
	to.volume_db = -60.0
	to.play(randf() * maxf(stream.get_length() - 1.0, 0.0))     # not always the same bird first
	create_tween().tween_property(to, "volume_db", _amb_level(), fade)


func _amb_level() -> float:
	return _amb_db + linear_to_db(maxf(sfx_volume, 0.0001))


## One footstep on "grass", "stone", "sand" or "wood" ("" = the ground of the place).
func footstep(surface: String = "") -> void:
	var s := surface if surface != "" else _surface
	play("step_" + s if has("step_" + s) else "footstep", STEP_DB, 0.1)


## Called every frame by whoever walks the hero: steps at a walking pace while `moving`.
## `pace` above 1 walks faster (the world map), so the steps come quicker.
func walking(moving: bool, delta: float, pace: float = 1.0) -> void:
	if not moving:
		_step_t = STEP_EVERY * 0.5          # the first step comes soon after he sets off
		return
	_step_t -= delta * clampf(pace, 0.5, 1.6)
	if _step_t <= 0.0:
		_step_t += STEP_EVERY
		footstep()


## Battle music (a boss has its own); the place's ambience fades away.
func battle(boss: bool = false) -> void:
	ambience("", 0.6)
	_music("boss" if boss else "battle", 0.6)


## A battle is won: the battle music gives way to the short fanfare, played once.
func victory() -> void:
	play("victory_sting", -10.0, 0.0)
	_music("victory", 0.5)


## Stops every sound and lets go of every loaded sound file. G.quit() calls this before the
## game closes; after it nothing plays any more.
func shutdown() -> void:
	_closed = true
	for tw in get_tree().get_processed_tweens():
		if tw.is_valid() and tw.is_running():
			tw.kill()
	for p in _players + [_music_a, _music_b, _amb_a, _amb_b]:
		p.stop()
		p.stream = null
	_streams.clear()
	_music_role = ""
	_amb_id = ""


func _music_db() -> float:
	return linear_to_db(maxf(music_volume, 0.0001)) - 6.0


func set_volumes(sfx: float, mus: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(mus, 0.0, 1.0)
	if _music_a.playing:
		_music_a.volume_db = _music_db()
	if _amb_a.playing:
		_amb_a.volume_db = _amb_level()
