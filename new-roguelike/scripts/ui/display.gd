extends RefCounted
## Display (PC): window or fullscreen, and VSync, from the saved settings "display" ("window" /
## "full") and "vsync". Settings > Display / VSync change them at once; F11 or Alt+Enter toggles
## fullscreen anywhere (main.gd). A phone and the tests without a screen never touch the window.

const MODES := [["window", "Window"], ["full", "Fullscreen"]]


static func can() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless" and not G.flag("uiphone")


## Puts the window in the saved state (at start and after a change). A test run (--uitour,
## --shots, --nosave) keeps the window it was given, so its pictures keep their size.
static func apply(force := false) -> void:
	if not can():
		return
	if not force and (G.flag("uitour") or G.arg("shots") != "" or G.flag("nosave")):
		return
	var full := String(Save.setting("display")) == "full"
	var now := DisplayServer.window_get_mode()
	var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Save.setting("vsync")) else DisplayServer.VSYNC_DISABLED)


## F11 / Alt+Enter: fullscreen on or off, saved.
static func toggle() -> void:
	if not can():
		return
	Save.set_setting("display", "window" if String(Save.setting("display")) == "full" else "full")
	apply(true)
