extends Node
## Player options (sound volume, fullscreen, screen shake) and saving them.
## Saved in the player's user folder, so they survive closing the game.

signal changed

const SAVE_PATH := "user://settings.cfg"

var master_volume := 0.8
var sfx_volume := 0.9
var music_volume := 0.6
var fullscreen := false
var screen_shake := 1.0      # 0 turns shake off
var pixel_perfect := false   # only scale the picture by whole numbers
var aim_assist := true       # gentle help when aiming with a controller

var _headless := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_make_audio_buses()
	load_settings()
	apply()
	_fit_window_to_screen()


func _unhandled_input(event: InputEvent) -> void:
	var alt_enter := false
	var key := event as InputEventKey
	if key != null:
		alt_enter = key.pressed and not key.echo and key.keycode == KEY_ENTER and key.alt_pressed
	if event.is_action_pressed("fullscreen") or alt_enter:
		fullscreen = not fullscreen
		apply()
		save_settings()
		get_viewport().set_input_as_handled()


## Sound is split into channels so the options menu can turn each up or down.
func _make_audio_buses() -> void:
	for bus_name: String in ["Sfx", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func apply() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Sfx", sfx_volume)
	_set_bus_volume("Music", music_volume)
	if not _headless:
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect \
				else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	changed.emit()


func _set_bus_volume(bus_name: String, amount: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, amount <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(amount, 0.001)))


## If the monitor is too small for the default window, shrink the window.
func _fit_window_to_screen() -> void:
	if _headless or fullscreen:
		return
	var screen := DisplayServer.screen_get_usable_rect().size
	var window := DisplayServer.window_get_size()
	if screen.x > 0 and (window.x > screen.x or window.y > screen.y):
		DisplayServer.window_set_size(Vector2i(960, 540))


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	master_volume = float(file.get_value("audio", "master", master_volume))
	sfx_volume = float(file.get_value("audio", "sfx", sfx_volume))
	music_volume = float(file.get_value("audio", "music", music_volume))
	fullscreen = bool(file.get_value("video", "fullscreen", fullscreen))
	pixel_perfect = bool(file.get_value("video", "pixel_perfect", pixel_perfect))
	screen_shake = float(file.get_value("game", "screen_shake", screen_shake))
	aim_assist = bool(file.get_value("game", "aim_assist", aim_assist))


func save_settings() -> void:
	if Game.bot_mode:
		return
	var file := ConfigFile.new()
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("audio", "music", music_volume)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("video", "pixel_perfect", pixel_perfect)
	file.set_value("game", "screen_shake", screen_shake)
	file.set_value("game", "aim_assist", aim_assist)
	file.save(SAVE_PATH)
