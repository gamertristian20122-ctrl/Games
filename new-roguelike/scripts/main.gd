extends Node
## Placeholder entry point (the shell replaces this): prints that the foundation loads.

func _ready() -> void:
	print("FOUNDATION OK  knight frames=", Art.frames("knight_m").get_frame_count("idle"),
		" coin=", Art.tex("coin").get_size(), " big_demon=", Art.size("big_demon"),
		" floor=", Art.has("floor_1"), " nothing=", Art.has("nothing_here"))
	get_tree().quit()
