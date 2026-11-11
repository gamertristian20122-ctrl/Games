extends Node
## Sfx (autoload): sound effects and music by name. A missing file is silent, never an error.
##   Sfx.play("coin_pickup")            plays res://assets/audio/sfx/coin_pickup.ogg,
##                                      or a random one of coin_pickup_1.ogg .. coin_pickup_4.ogg
##   Sfx.music("floor1")                crossfades to res://assets/audio/music/floor1.ogg
## Volumes come from Save settings "sfx_volume" and "music_volume" (0..1).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 14

var _streams := {}          # name -> Array[AudioStream] (empty when missing)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}      # name -> msec, to stop 20 copies of one sound in a frame
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_role := ""
var sfx_volume := 1.0
var music_volume := 0.7


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)


func _load(name: String) -> Array:
	if _streams.has(name):
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


func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
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
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Crossfade to a music track by role name ("" fades to silence). Asking for the track that is
## already playing does nothing.
func music(role: String, fade: float = 1.0) -> void:
	if role == _music_role:
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
		stream.loop = true
	to.stream = stream
	to.volume_db = -60.0
	to.play()
	create_tween().tween_property(to, "volume_db", _music_db(), fade)


func _music_db() -> float:
	return linear_to_db(maxf(music_volume, 0.0001)) - 6.0


func set_volumes(sfx: float, mus: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(mus, 0.0, 1.0)
	if _music_a.playing:
		_music_a.volume_db = _music_db()
