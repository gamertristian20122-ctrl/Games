extends Node
## Plays sound effects and music.
##
## HOW TO EDIT
##  Each line in SOUNDS reads:  "name": [list of files, volume in dB, pitch wobble]
##  When a sound has several files, one is picked at random each time.
##  Every file is listed in CREDITS.md with its author and licence.

const DIR := "res://assets/sfx/"

const SOUNDS := {
	"shoot": [["shoot_1.ogg", "shoot_2.ogg", "shoot_3.ogg"], -13.0, 0.10],
	"echo_shoot": [["shoot_1.ogg", "shoot_2.ogg"], -20.0, 0.10],
	"flare": [["flare.ogg"], -8.0, 0.05],
	"hit": [["hit_1.ogg", "hit_2.ogg", "hit_3.ogg"], -12.0, 0.12],
	"crit": [["crit.ogg"], -9.0, 0.08],
	"kill": [["kill_1.ogg", "kill_2.ogg", "kill_3.ogg"], -8.0, 0.10],
	"explode": [["explode_1.ogg", "explode_2.ogg"], -7.0, 0.08],
	"zap": [["zap.ogg"], -9.0, 0.08],
	"enemy_shoot": [["enemy_shoot_1.ogg", "enemy_shoot_2.ogg"], -15.0, 0.10],
	"warn": [["warn.ogg"], -14.0, 0.05],
	"hurt": [["hurt.ogg"], -4.0, 0.04],
	"blocked": [["blocked.ogg"], -6.0, 0.04],
	"dash": [["dash.ogg"], -11.0, 0.08],
	"foghorn": [["foghorn.ogg"], -7.0, 0.04],
	"spawn": [["spawn.ogg"], -16.0, 0.10],
	"clear": [["clear.ogg"], -7.0, 0.0],
	"chest": [["chest.ogg"], -8.0, 0.0],
	"pickup": [["pickup.ogg"], -7.0, 0.03],
	"combo": [["combo.ogg"], -5.0, 0.0],
	"heal": [["heal.ogg"], -8.0, 0.0],
	"door": [["door.ogg"], -8.0, 0.04],
	"unison": [["unison.ogg"], -12.0, 0.0],
	"echo_in": [["echo_in.ogg"], -12.0, 0.04],
	"boss_in": [["boss_in.ogg"], -4.0, 0.0],
	"boss_down": [["boss_down.ogg"], -4.0, 0.0],
	"death": [["death.ogg"], -5.0, 0.0],
	"win": [["win.ogg"], -5.0, 0.0],
	"ui_move": [["ui_move.ogg"], -14.0, 0.04],
	"ui_ok": [["ui_ok.ogg"], -10.0, 0.0],
	"ui_back": [["ui_back.ogg"], -12.0, 0.0],
}

const VOICES := 14            # how many sounds can overlap
const MIN_GAP := 0.045        # seconds before the same sound may play again
const MUSIC_DB := -15.0       # music sits under the sound effects

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name := ""
var _music_fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for sound_name: String in SOUNDS:
		var list: Array[AudioStream] = []
		for file: String in SOUNDS[sound_name][0]:
			var path := DIR + file
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[sound_name] = list


## Plays a sound by name. Unknown names and missing files are just skipped.
func play(sound_name: String, pitch: float = 1.0, volume_offset: float = 0.0) -> void:
	if Game.fast_mode:
		return
	var list: Array = _streams.get(sound_name, [])
	if list.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_name, -10.0)) < MIN_GAP:
		return
	_last_played[sound_name] = now
	var info: Array = SOUNDS[sound_name]
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[randi() % list.size()]
	p.volume_db = float(info[1]) + volume_offset
	p.pitch_scale = pitch * (1.0 + randf_range(-1.0, 1.0) * float(info[2]))
	p.play()


## Starts a music track from assets/music/ (or stops music with "").
## The same track asked for twice just keeps playing.
func music(track: String) -> void:
	if Game.fast_mode or track == _music_name:
		return
	_music_name = track
	if _music_fade != null:
		_music_fade.kill()
	_music_fade = create_tween()
	if _music.playing:
		_music_fade.tween_property(_music, "volume_db", -50.0, 0.35)
	_music_fade.tween_callback(_start_music.bind(track))


func _start_music(track: String) -> void:
	_music.stop()
	if track == "":
		return
	var path := "res://assets/music/" + track
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB
	_music.play()
