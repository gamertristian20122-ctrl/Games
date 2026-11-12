extends RefCounted
## AI "dummy": stands where it was put and does nothing (the straw dummy in the training yard).
## Blows do not move it.

func start(e) -> void:
	e.set_meta("home", e.position)


func tick(e, _delta: float) -> void:
	e.knock = Vector2.ZERO
	e.position = e.get_meta("home", e.position)
