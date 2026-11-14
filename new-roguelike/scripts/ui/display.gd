extends RefCounted
## Display (PC): window or fullscreen, borderless, the window's size, VSync and the frame cap, from
## the saved settings "display" ("window" / "full"), "borderless", "window_size" ("" or "1600x900"),
## "vsync" and "fps_cap" (0 = no cap). Settings > Display changes them at once; F11 or Alt+Enter
## toggles fullscreen anywhere (main.gd). A phone and the tests without a screen never touch the
## window (the frame cap works on a phone too).

const MODES := [["window", "Window"], ["full", "Fullscreen"]]
## Window sizes offered (only those that fit the screen are shown); "" = the size it has now.
const SIZES := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
## Frame caps offered: [frames a second, the word shown]; 0 = none.
const FPS_CAPS := [[0, "Off"], [30, "30"], [60, "60"], [120, "120"], [144, "144"]]


static func can() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless" and not G.flag("uiphone")


## A test run (--uitour, --shots, --nosave) keeps the window it was given, so its pictures keep their size.
static func _test_run() -> bool:
	return G.flag("uitour") or G.arg("shots") != "" or G.flag("nosave")


static func _flag(key: String, fallback: bool) -> bool:
	var v: Variant = Save.setting(key)
	return bool(v) if v != null else fallback


static func fps_cap() -> int:
	var v: Variant = Save.setting("fps_cap")
	return maxi(int(v), 0) if v != null else 0


## The sizes that fit this screen, as [[id, word], ...], with "As it is" first.
static func size_choices() -> Array:
	var out: Array = [["", "As it is"]]
	var screen := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i(1920, 1080)
	for id: String in SIZES:
		var wh := _wh(id)
		if wh.x <= screen.x and wh.y <= screen.y:
			out.append([id, id.replace("x", " x ")])
	return out


static func _wh(id: String) -> Vector2i:
	var parts := id.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## Puts the window in the saved state (at start and after a change).
static func apply(force := false) -> void:
	if not force and _test_run():
		return
	Engine.max_fps = fps_cap()
	if not can():
		return
	var full := String(Save.setting("display")) == "full"
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	if not full:
		var borderless := _flag("borderless", false)
		if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) != borderless:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)
		var want: Variant = Save.setting("window_size")
		var wh := _wh(String(want)) if want != null else Vector2i.ZERO
		if wh.x > 0 and wh.y > 0 and DisplayServer.window_get_size() != wh:
			DisplayServer.window_set_size(wh)
			# keep it in the middle of the screen it is on
			var screen := DisplayServer.window_get_current_screen()
			var area := DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_position(area.position + (area.size - wh) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _flag("vsync", true) else DisplayServer.VSYNC_DISABLED)


## F11 / Alt+Enter: fullscreen on or off, saved.
static func toggle() -> void:
	if not can():
		return
	Save.set_setting("display", "window" if String(Save.setting("display")) == "full" else "full")
	apply(true)
