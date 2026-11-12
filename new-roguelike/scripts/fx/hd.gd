extends RefCounted
## HD: may the PC-only light be used? (Forward+ on a desktop: real shadow maps, soft shadows, SSAO,
## SSIL, volumetric fog, depth of field by the camera, filmic tone.)
## project.godot runs Forward+ on PC and GL Compatibility on Android (rendering_method.mobile), and
## `--rendering-method gl_compatibility` forces the old path on a PC too (a PC without Vulkan falls
## back to it by itself: rendering_device/fallback_to_opengl3). Every HD feature asks `Hd.on()`
## first and keeps the old cheap path when it says no, so the phone build still runs.
##   const Hd = preload("res://scripts/fx/hd.gd")
##   if Hd.on(): ...
## `--nohd` on the command line turns HD off even in Forward+ (to compare the two looks).

static var _known := false
static var _on := false


static func on() -> bool:
	if not _known:
		_known = true
		_on = RenderingServer.get_current_rendering_method() == "forward_plus" \
			and DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--nohd")
	return _on
