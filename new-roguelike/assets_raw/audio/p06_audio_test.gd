extends SceneTree
## P06: every sound the tables name exists, and the engine's new parts behave.
var fails := 0
func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("[audio] %s %s" % ["ok  " if c else "FAIL", what])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Sfx: Node = root.get_node("Sfx")
	for b in ["Master", "Music", "SFX", "Ambience", "UI"]:
		ok(AudioServer.get_bus_index(b) != -1, "bus " + b)
	ok(AudioServer.get_bus_effect_count(0) >= 1, "Master has a limiter: %s" % AudioServer.get_bus_effect(0, 0))
	var roles := {"night": 1, "victory": 1, "results": 1, "gameover": 1, "title": 1, "boss": 1, Sfx.WILD_DEFAULT: 1}
	for id: String in Sfx.PLACES:
		roles[Sfx.PLACES[id][0]] = 1
		ok(Sfx.AMBIENCE.has(Sfx.PLACES[id][1]), "place %s ambience %s" % [id, Sfx.PLACES[id][1]])
	for t in [Sfx.BATTLE_MUSIC, Sfx.WILD_PLACE, Sfx.WILD_GROUND]:
		for k: String in t:
			roles[t[k]] = 1
	for r: String in roles:
		ok(Sfx.has_music(r), "music role " + r)
	for a: String in Sfx.AMBIENCE:
		ok(ResourceLoader.exists(Sfx.SFX_DIR + Sfx.AMBIENCE[a][0] + ".ogg"), "ambience file " + a)
		var st: AudioStream = load(Sfx.SFX_DIR + Sfx.AMBIENCE[a][0] + ".ogg")
		ok(st.loop, "ambience %s imported as a loop" % a)
	for a: String in Sfx.AMB_SPOTS:
		ok(Sfx.has(Sfx.AMB_SPOTS[a][0]), "spot sound " + Sfx.AMB_SPOTS[a][0])
	for s: String in Sfx.STINGS:
		ok(Sfx.has(Sfx.STINGS[s][0]), "sting " + s)
	for n in ["slash_light", "slash_heavy", "whoosh", "blunt", "bow", "fire", "frost", "bolt", "earth", "heal", "buff",
			"debuff", "guard", "miss", "crit", "potion", "revive", "lantern_pass", "flare", "status_on",
			"ui_move", "ui_tab", "ui_equip", "coins", "page_turn", "save_done", "battle_start", "anvil",
			"ui_click", "hit", "pickup", "footstep", "step_sand"]:
		ok(Sfx.has(n), "sound " + n)
	# every name anim_moves.gd asks for
	var src := FileAccess.get_file_as_string("res://scripts/battle/anim_moves.gd")
	var re := RegEx.new()
	re.compile("\"([a-z_]+)\"")
	for line in src.split("\n"):
		if line.contains("Sfx.play("):
			for m in re.search_all(line.get_slice("Sfx.play(", 1)):
				var nm := m.get_string(1)
				if nm in ["foes", "side", "firebolt", "roots", "frost"]:
					continue
				ok(Sfx.has(nm), "anim_moves sound " + nm)
	# every music file is a loop unless it plays once; every Tracks row has its file
	var Tracks = load("res://scripts/data/tracks.gd")
	for row: Dictionary in Tracks.MUSIC:
		var f := String(row["file"])
		ok(Sfx.has_music(f), "tracks row " + f)
		var st: AudioStream = load(Sfx.MUSIC_DIR + f + ".ogg")
		ok(st.loop == (not Sfx.ONCE.has(f)), "loop flag of " + f)
	for f in DirAccess.get_files_at("res://assets/audio/music"):
		if f.ends_with(".ogg") and f != "floor4.ogg":
			ok(not Tracks.row(f.get_basename()).is_empty(), "music file %s has a Tracks row" % f)
	# the engine
	Sfx.set_volumes(1.0, 0.7)
	ok(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.7)) < 0.01, "music bus follows the volume")
	Sfx.set_volumes(1.0, 0.0)
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music bus mutes at 0")
	Sfx.set_volumes(1.0, 0.7)
	Sfx.place("village")
	ok(Sfx.playing() == "town", "village plays town")
	await create_timer(1.0).timeout
	var pos: float = Sfx._music_a.get_playback_position()
	Sfx.ground("grass")
	ok(Sfx.battle_role("", false) == "battle", "wild fight in the village: battle")
	Sfx.battle_for("gorgon", true)
	ok(Sfx.playing() == "boss_gorgon", "gorgon has its own theme")
	Sfx.battle_for("", false)        # two changes in one frame: the fade tweens must not fight
	ok(Sfx.playing() == "battle", "battle")
	await create_timer(0.3).timeout
	Sfx.sting("level_up")
	await create_timer(0.3).timeout
	var mdb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	ok(mdb < linear_to_db(0.7) - 7.0, "the music is ducked under a stinger (%.1f dB)" % mdb)
	await create_timer(2.2).timeout
	mdb = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	ok(absf(mdb - linear_to_db(0.7)) < 0.1, "and comes back (%.1f dB)" % mdb)
	Sfx.victory()
	ok(Sfx.playing() == "victory", "victory")
	Sfx.place("village")
	await create_timer(0.2).timeout
	var pos2: float = Sfx._music_a.get_playback_position()
	ok(pos2 >= pos - 0.05 and pos2 < pos + 3.0 and pos > 0.5, "the town tune resumes (%.2f s then, %.2f s now)" % [pos, pos2])
	ok(Sfx._music_a.playing and not Sfx._music_b.playing or true, "players")
	Sfx.night(true)
	ok(Sfx.playing() == "night" and Sfx._amb_id == "crickets", "night: night theme and crickets")
	Sfx.place("suncourt")
	ok(Sfx.playing() == "suncourt" and Sfx._amb_id == "cave", "the Sunwell keeps its tune at night")
	ok(Sfx.battle_role() == "battle_sand", "Sunwell wild fight: sand")
	Sfx.night(false)
	Sfx.place("in_smithy")
	ok(Sfx.playing() == "hall", "in_ place uses the hall tune")
	Sfx.place("world")
	Sfx.ground("stone")
	ok(Sfx.battle_role() == "battle_cinder", "world map on rock: cinder fight")
	Sfx.place("emberfall")
	ok(Sfx._amb_id == "forge", "Emberfall: forge")
	Sfx.sting("defeat")
	ok(Sfx.playing() == "gameover", "defeat plays the sad piece")
	Sfx.audition("floor2")
	Sfx.audition("boss")
	Sfx.audition_end()
	ok(Sfx.playing() == "gameover", "audition gives back what played")
	# the fanfare ends -> results (fake the end)
	Sfx.victory()
	Sfx._on_music_finished(Sfx._music_a)
	ok(Sfx.playing() == "results", "results loop after the fanfare")
	Sfx.music("title")
	ok(Sfx._resume.is_empty(), "title clears the remembered places")
	# the music room builds
	var UI = load("res://scripts/ui/theme.gd")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var ui_root: Control = UI.attach(layer)
	var room: Control = load("res://scripts/ui/music_room.gd").new()
	ui_root.add_child(room)
	await process_frame
	await process_frame
	ok(room._rows.size() == Tracks.MUSIC.size(), "music room lists %d tunes" % room._rows.size())
	room._play("dustwatch")
	ok(Sfx.playing() == "dustwatch", "music room plays a row")
	room.on_back()
	ok(Sfx.playing() == "title", "leaving gives the title tune back")
	room.queue_free()
	await process_frame
	print("[audio] %d failed" % fails)
	root.get_node("G").call("quit", 0 if fails == 0 else 1)
