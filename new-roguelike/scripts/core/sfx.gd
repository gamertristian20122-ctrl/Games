extends Node
## Sfx (autoload): sound effects and music by name. A missing file is silent, never an error.
##   Sfx.play("coin_pickup")            plays res://assets/audio/sfx/coin_pickup.ogg,
##                                      or a random one of coin_pickup_1.ogg .. coin_pickup_5.ogg
##   Sfx.music("title")                 crossfades to that music role (and fades out any ambience:
##                                      menus and the old rooms have none)
##   Sfx.place("elfwood")               the music, ambience loop and footstep ground of a walking
##                                      place (table PLACES below); scripts/hub/hub.gd enter() calls it.
##                                      The tune goes on where it stopped when he was last there.
##   Sfx.ambience("woods")              crossfades the looping background of a place ("" = silence)
##   Sfx.walking(moving, delta, pace)   call every frame while walking: steps on the place's ground
##   Sfx.footstep("sand")               one step on grass / stone / sand / wood
##   Sfx.battle_for(story_id, boss)     the music of a fight: a story battle's own (BATTLE_MUSIC),
##                                      else the land's; Sfx.battle(boss) is the old short form
##   Sfx.victory()                      the fanfare once, then a quiet loop while spoils are counted
##   Sfx.sting("level_up")              a short flourish over the music, which dips for its length
##                                      (STINGS: level_up, quest_done, item_get, inn_rest, beacon_lit,
##                                      and "defeat", which ends the battle music with the sad piece)
##   Sfx.duck(8.0, 1.5)                 the music 8 dB quieter for 1.5 seconds (a big moment)
##
## BUSES (default_bus_layout.tres; made here in code too if that file is ever missing):
##   Master (a hard limiter: loud moments never crackle) < Music, SFX, Ambience, UI.
## Volumes are bus volumes: Save settings "sfx_volume" and "music_volume" (0..1), and, when the
## settings have them, "master_volume" and "amb_volume" (missing = 1). Steps follow the sound volume.
## Every file's source and licence: assets_raw/licence_notes/. Titles and composers of the
## music: scripts/data/tracks.gd (the Music room shows them).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 14
const BUSES := ["Music", "SFX", "Ambience", "UI"]
## names asked for that have no file of their own: played with another one
const ALIASES := {"hit": "enemy_hit", "pickup": "heart_pickup"}
## which bus a sound goes to, by how its name begins (anything else: SFX)
const BUS_OF := {"ui_": "UI", "page_turn": "UI", "coins": "UI", "save_done": "UI", "shop_": "UI",
	"anvil": "Ambience"}
## music played once (no loop)
const ONCE := ["victory", "gameover"]
## a music role whose file has another name (one file may serve two roles)
const MUSIC_FILE := {"battle_sand": "floor2", "battle_cinder": "floor3", "cinderpeak": "floor1"}
## a role that sits lower or higher than the rest (dB)
const ROLE_DB := {"results": -6.0}

## a walking place -> [music role, ambience, ground underfoot]. A place not listed uses "_";
## a place whose id begins "in_" (the inside of a house) uses the "room" row's sound with the
## hall's tune. TO ADD A PLACE: one row. Rules that follow from a row:
##   - ground "wood" or ambience "cave" = under a roof or under the ground: the night theme
##     never takes over there;
##   - ambience "birds" and "woods" turn to crickets at night.
const PLACES := {
	"room": ["room", "fire", "wood"],            # your room: the hearth crackles
	"hall": ["hall", "fire", "wood"],            # the tavern hall
	"in_": ["hall", "fire", "wood"],             # the inside of any house
	"village": ["town", "birds", "stone"],       # Wickmere: birds over the roofs, cobbled lanes
	"elfwood": ["road", "woods", "grass"],       # the Elfwood Road: a walking tune
	"glade": ["woods", "woods", "grass"],
	"deepwood": ["deepwood", "woods", "grass"],  # wary and quiet
	"beacon": ["beacon", "wind", "grass"],       # the bare hilltop of the dark beacon
	"world": ["world", "wind", "grass"],
	"dustwatch": ["dustwatch", "wind", "sand"],  # the desert town
	"suncourt": ["suncourt", "cave", "stone"],   # the Sunwell under Dustwatch: drips in old stone
	"emberfall": ["emberfall", "forge", "stone"],   # the forge town: fire, and a hammer now and then
	"cinderpeak": ["cinderpeak", "cave", "stone"],  # the Cinder Stair and the third beacon
	"_": ["town", "birds", "grass"],
}
## each ambience -> [file in SFX_DIR, how loud it sits (dB, before the sound volume)]
const AMBIENCE := {
	"woods": ["amb_woods", -5.0], "birds": ["amb_birds", -8.0], "wind": ["amb_wind", -6.0],
	"fire": ["torch_fire_loop", -16.0], "forge": ["torch_fire_loop", -12.0],
	"cave": ["amb_cave", -3.0], "crickets": ["amb_crickets", -4.0],
}
## an ambience that also has a sound heard now and then: [sound, least and most seconds between, dB]
const AMB_SPOTS := {"forge": ["anvil", 6.0, 15.0, -15.0]}

## The music of a fight. A story battle's id (tale.gd BATTLES) -> music role; a battle not listed
## plays "boss" if it is a boss, else the wild music of the land he stands in (WILD_*).
const BATTLE_MUSIC := {
	"glade": "battle", "deepwood": "battle", "giant": "boss",
	"dustwall": "battle_sand", "gorgon": "boss_gorgon",
	"pass": "battle_cinder", "forgedoor": "battle_cinder", "ashstair": "battle_cinder",
	"colossus": "final_boss",       # for now: this piece is meant for the last boss of the game
}
## wild fights: the walking place he is in -> music role ...
const WILD_PLACE := {"dustwatch": "battle_sand", "suncourt": "battle_sand",
	"emberfall": "battle_cinder", "cinderpeak": "battle_cinder"}
## ... and on the world map, the ground under his feet
const WILD_GROUND := {"sand": "battle_sand", "stone": "battle_cinder"}
const WILD_DEFAULT := "battle"

## Sfx.sting(name): name -> [file in SFX_DIR, dB]. The music dips DUCK_DB for the file's length.
const STINGS := {
	"level_up": ["sting_level_up", -4.0], "quest_done": ["sting_quest_done", -4.0],
	"item_get": ["sting_item_get", -5.0], "inn_rest": ["sting_inn_rest", -5.0],
	"beacon_lit": ["sting_beacon_lit", -2.0],
}
const DUCK_DB := 8.0
const MUSIC_DB := -6.0         ## where music sits under the sounds, before the music volume
const STEP_EVERY := 0.36       ## seconds between steps at a normal pace
const STEP_DB := -13.0         ## (v0.35.0: was -19; the owner could not hear the ground change)

var _streams := {}          # name -> Array[AudioStream] (empty when missing)
var _music_streams := {}    # role -> AudioStream with its loop setting
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}      # name -> msec, to stop 20 copies of one sound in a frame
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_role := ""
var _music_out: Tween       # the fade of the tune going
var _music_in: Tween        # the fade of the tune coming
var _resume := {}           # place music role -> seconds it had played when he left
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_id := ""
var _amb_db := 0.0          # the level of the ambience playing now
var _amb_out: Tween
var _amb_in: Tween
var _spot_t := 0.0          # seconds to the next now-and-then sound of the ambience
var _sting: AudioStreamPlayer
var _duck_tw: Tween
var _duck_db := 0.0         # how far the music is dipped just now (0 or below)
var _surface := "grass"
var _ground := ""            # the ground under the walker just now (ground()); "" = the place's own
var _place_id := ""
var _night := false
var _step_t := 0.0
var _before := []           # audition(): what was playing before [music role, ambience]
var sfx_volume := 1.0
var music_volume := 0.7
var master_volume := 1.0
var amb_volume := 1.0
var _closed := false        # set by shutdown(): the game is closing, stay silent


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_amb_a = AudioStreamPlayer.new()
	_amb_b = AudioStreamPlayer.new()
	_sting = AudioStreamPlayer.new()
	for p: AudioStreamPlayer in [_music_a, _music_b]:
		p.bus = "Music"
		p.finished.connect(_on_music_finished.bind(p))
	_amb_a.bus = "Ambience"
	_amb_b.bus = "Ambience"
	_sting.bus = "SFX"
	for p in [_music_a, _music_b, _amb_a, _amb_b, _sting]:
		add_child(p)
	_apply_volumes()


## The four buses exist even if default_bus_layout.tres was lost; Master always has its limiter.
func _ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	if AudioServer.get_bus_effect_count(0) == 0 and ClassDB.class_exists("AudioEffectHardLimiter"):
		var lim: AudioEffect = ClassDB.instantiate("AudioEffectHardLimiter")
		lim.set("ceiling_db", -0.5)
		AudioServer.add_bus_effect(0, lim)


func _process(delta: float) -> void:
	if _closed or not AMB_SPOTS.has(_amb_id):
		return
	_spot_t -= delta
	if _spot_t <= 0.0:
		var row: Array = AMB_SPOTS[_amb_id]
		_spot_t = randf_range(float(row[1]), float(row[2]))
		play(String(row[0]), float(row[3]) + randf_range(-4.0, 0.0), 0.04)


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
	if list.is_empty() and ALIASES.has(name):
		list = _load(String(ALIASES[name]))
	_streams[name] = list
	return list


func has(name: String) -> bool:
	return not _load(name).is_empty()


## True when a music role has a file (BATTLE_MUSIC and PLACES roles; tests ask this).
func has_music(role: String) -> bool:
	return ResourceLoader.exists(_music_path(role))


func _music_path(role: String) -> String:
	return MUSIC_DIR + String(MUSIC_FILE.get(role, role)) + ".ogg"


func _bus_of(name: String) -> String:
	for head: String in BUS_OF:
		if name.begins_with(head):
			return String(BUS_OF[head])
	return "SFX"


## `pitch` shifts the whole sound (0.5 = an octave lower, 2.0 = an octave higher).
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
	p.bus = _bus_of(name)
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.play()


## Crossfade to a music track by role name ("" fades to silence) and fade out any ambience.
## Asking for the track that is already playing does nothing.
func music(role: String, fade: float = 1.0) -> void:
	if role == "title":
		_resume.clear()         # back at the title: every place starts its tune afresh
		_place_id = ""
	ambience("", fade)
	_music(role, fade)


func _music(role: String, fade: float = 1.0) -> void:
	if role == _music_role or _closed:
		return
	# a fade still running belongs to the change before this one: end it cleanly first
	_kill(_music_out)
	_kill(_music_in)
	if _music_b.playing:
		_music_b.stop()         # (it was fading out; it is the player the new tune needs)
	if _resumes(_music_role) and _music_a.playing:
		_resume[_music_role] = _music_a.get_playback_position()
	_music_role = role
	var from := _music_a
	var to := _music_b
	_music_a = to
	_music_b = from
	if from.playing:
		_music_out = create_tween()
		_music_out.tween_property(from, "volume_db", -60.0, fade)
		_music_out.tween_callback(from.stop)
	var stream := _music_stream(role)
	if stream == null:
		return
	var level := MUSIC_DB + float(ROLE_DB.get(role, 0.0))
	var at := 0.0
	if _resumes(role):
		at = float(_resume.get(role, 0.0))
		if at > stream.get_length() - 2.0:
			at = 0.0
	to.stream = stream
	to.volume_db = -60.0
	to.play(at)
	_music_in = create_tween()
	_music_in.tween_property(to, "volume_db", level, fade)


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


## The stream of a role, looping or not as the role wants. The imported file says "loop" already
## (assets/audio/music/*.import); if one ever disagrees, a private copy is set right, so the
## shared file in the cache is never changed.
func _music_stream(role: String) -> AudioStream:
	if role == "":
		return null
	if _music_streams.has(role):
		return _music_streams[role]
	var path := _music_path(role)
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
		var want := not ONCE.has(role)
		if stream is AudioStreamOggVorbis and stream.loop != want:
			stream = stream.duplicate()
			stream.loop = want
	_music_streams[role] = stream
	return stream


## A place's tune goes on where it stopped; battle music, fanfares and the title start afresh.
func _resumes(role: String) -> bool:
	if role == "" or role == "title" or ONCE.has(role):
		return false
	if role == "night":
		return true
	for id: String in PLACES:
		if String(PLACES[id][0]) == role:
			return true
	return false


## The fanfare has ended: a quiet loop while the spoils are counted.
func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p == _music_a and _music_role == "victory" and not _closed:
		_music("results", 1.5)


## The sound of a walking place (PLACES): its music, its ambience loop and its ground.
func place(id: String) -> void:
	_place_id = id
	_before = []
	var row := _row(id)
	_surface = String(row[2])
	_music(_place_music(row), 1.6)
	ambience(_place_amb(row), 1.6)


func _row(id: String) -> Array:
	if PLACES.has(id):
		return PLACES[id]
	return PLACES["in_"] if id.begins_with("in_") else PLACES["_"]


## NIGHT (v0.35.0): out of doors the place's tune gives way to the quiet, uneasy night theme
## ("night": Whispers from Beyond, Juhani Junkala, CC0) and the birds to crickets. Rooms and
## the places under the ground keep theirs.
## hub.gd calls night(true / false) as the day turns; it only does something when that changes.
func night(on: bool) -> void:
	if on == _night:
		return
	_night = on
	if _place_id == "" or _closed:
		return
	var row := _row(_place_id)
	if _music_role == String(row[0]) or _music_role == "night":       # (not over battle music)
		_music(_place_music(row), 4.0)
		ambience(_place_amb(row), 4.0)


func _roofed(row: Array) -> bool:
	return String(row[2]) == "wood" or String(row[1]) == "cave"


func _place_music(row: Array) -> String:
	return "night" if _night and not _roofed(row) else String(row[0])


func _place_amb(row: Array) -> String:
	var amb := String(row[1])
	return "crickets" if _night and (amb == "birds" or amb == "woods") else amb


## The ground under the walker just now ("" = the place's own): hub.gd says it as he walks, so the
## steps change from cobbles to grass to the planks of the jetty inside one place.
func ground(surface: String) -> void:
	_ground = surface


## Crossfades the ambience loop ("" fades it out). Asking for the one playing does nothing.
func ambience(id: String, fade: float = 1.2) -> void:
	if id == _amb_id or _closed:
		return
	_kill(_amb_out)
	_kill(_amb_in)
	if _amb_b.playing:
		_amb_b.stop()
	_amb_id = id
	_spot_t = randf_range(3.0, 8.0)
	var from := _amb_a
	var to := _amb_b
	_amb_a = to
	_amb_b = from
	if from.playing:
		_amb_out = create_tween()
		_amb_out.tween_property(from, "volume_db", -60.0, fade)
		_amb_out.tween_callback(from.stop)
	if not AMBIENCE.has(id):
		return
	var path := SFX_DIR + String(AMBIENCE[id][0]) + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis and not stream.loop:
		stream = stream.duplicate()
		stream.loop = true
	_amb_db = float(AMBIENCE[id][1])
	to.stream = stream
	to.volume_db = -60.0
	to.play(randf() * maxf(stream.get_length() - 1.0, 0.0))     # not always the same bird first
	_amb_in = create_tween()
	_amb_in.tween_property(to, "volume_db", _amb_db, fade)


## One footstep on "grass", "stone", "sand" or "wood" ("" = the ground of the place).
func footstep(surface: String = "") -> void:
	var s := surface if surface != "" else (_ground if _ground != "" else _surface)
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


## The music role of a fight: a story battle's own, a boss's, or the land's wild music.
func battle_role(story_id: String = "", boss: bool = false) -> String:
	if story_id != "" and BATTLE_MUSIC.has(story_id):
		return String(BATTLE_MUSIC[story_id])
	if boss:
		return "boss"
	if WILD_PLACE.has(_place_id):
		return String(WILD_PLACE[_place_id])
	if _place_id == "world" and WILD_GROUND.has(_ground):
		return String(WILD_GROUND[_ground])
	return WILD_DEFAULT


## A fight begins: the blade is drawn, the place's ambience fades and the fight's music starts.
## `story_id` is the story battle's id in tale.gd BATTLES ("" = a wild fight).
func battle_for(story_id: String = "", boss: bool = false) -> void:
	play("battle_start", -1.0, 0.04)             # a blade drawn (Kenney, CC0), and a heavy thud under it
	play("door_close", -7.0, 0.0, 0.6)
	ambience("", 0.6)
	var role := battle_role(story_id, boss)
	_music(role if has_music(role) else ("boss" if boss else WILD_DEFAULT), 0.6)


## The old short form: battle music by a yes / no (a boss has its own).
func battle(boss: bool = false) -> void:
	battle_for("", boss)


## A battle is won: the battle music gives way to the short fanfare, played once; when it ends
## a quiet loop plays until the place's own tune comes back.
func victory() -> void:
	play("victory_sting", -10.0, 0.0)
	_music("victory", 0.5)


## A short flourish over the music (STINGS); the music dips for as long as it lasts.
## "defeat" is different: the battle music stops and the sad piece plays once.
func sting(name: String) -> void:
	if _closed:
		return
	if name == "defeat":
		ambience("", 0.4)
		_music("gameover", 0.4)
		return
	if not STINGS.has(name):
		play(name)                               # not a stinger: an ordinary sound of that name
		return
	var list := _load(String(STINGS[name][0]))
	if list.is_empty() or sfx_volume <= 0.001:
		return
	var stream: AudioStream = list[0]
	_sting.stream = stream
	_sting.volume_db = float(STINGS[name][1])
	_sting.pitch_scale = 1.0
	_sting.play()
	duck(DUCK_DB, stream.get_length())


## The music `db` quieter for `seconds` (down quickly, back gently). For stingers and big moments.
func duck(db: float, seconds: float) -> void:
	if _closed:
		return
	_kill(_duck_tw)
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck, _duck_db, -absf(db), 0.12)
	_duck_tw.tween_interval(maxf(seconds, 0.0))
	_duck_tw.tween_method(_set_duck, -absf(db), 0.0, 0.7)


func _set_duck(db: float) -> void:
	_duck_db = db
	_bus_volume("Music", music_volume, db)


## THE MUSIC ROOM: plays any music file by name over whatever was playing ...
func audition(file: String) -> void:
	if _before.is_empty():
		_before = [_music_role, _amb_id]
	ambience("", 0.5)
	_music(file, 0.5)


## ... and gives back what was playing before (the Music room closes, or its Stop button).
func audition_end() -> void:
	if _before.is_empty():
		return
	var was: Array = _before
	_before = []
	_music(String(was[0]), 0.8)
	ambience(String(was[1]), 0.8)


## The music role playing now ("" = none): the Music room marks it.
func playing() -> String:
	return _music_role


## Stops every sound and lets go of every loaded sound file. G.quit() calls this before the
## game closes; after it nothing plays any more.
func shutdown() -> void:
	_closed = true
	for tw in get_tree().get_processed_tweens():
		if tw.is_valid() and tw.is_running():
			tw.kill()
	for p in _players + [_music_a, _music_b, _amb_a, _amb_b, _sting]:
		p.stop()
		p.stream = null
	_streams.clear()
	_music_streams.clear()
	_resume.clear()
	_music_role = ""
	_amb_id = ""


## The sound and music volumes (0..1), as the settings screen sets them. The master and ambience
## volumes are read from the settings too when they exist there ("master_volume", "amb_volume").
## Everything is a bus volume, so a tune in the middle of a crossfade follows the slider as well.
func set_volumes(sfx: float, mus: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(mus, 0.0, 1.0)
	master_volume = _extra_setting("master_volume")
	amb_volume = _extra_setting("amb_volume")
	_apply_volumes()


func _extra_setting(key: String) -> float:
	var save := get_node_or_null("/root/Save")
	if save == null or not save.has_method("setting") or not (save.get("data") is Dictionary):
		return 1.0
	if not (save.get("data") as Dictionary).has("settings"):
		return 1.0          # (the save is still loading: it calls set_volumes again when it has)
	var v: Variant = save.call("setting", key)
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return 1.0


func _apply_volumes() -> void:
	_bus_volume("Master", master_volume, 0.0)
	_bus_volume("Music", music_volume, _duck_db)
	_bus_volume("SFX", sfx_volume, 0.0)
	_bus_volume("UI", sfx_volume, 0.0)
	_bus_volume("Ambience", sfx_volume * amb_volume, 0.0)


func _bus_volume(bus: String, linear: float, extra_db: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)) + extra_db)
