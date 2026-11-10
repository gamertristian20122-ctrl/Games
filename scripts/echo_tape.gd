class_name EchoTape
extends RefCounted
## A recording of what the keeper did in one room.
##
## 60 times a second we store where the keeper stood, where they aimed, and
## whether they were shooting or dashing. In the next room an Echo plays the
## tape back.

const SHOOTING := 1
const DASHING := 2
const MAX_TICKS := 60 * 90   # stop recording after 90 seconds

var pos := PackedVector2Array()
var aim := PackedFloat32Array()
var flags := PackedByteArray()
var from_past_run := false   # true for the echo of the run before this one


func add(where: Vector2, aim_angle: float, shooting: bool, dashing: bool) -> void:
	if pos.size() >= MAX_TICKS:
		return
	pos.append(where)
	aim.append(aim_angle)
	var f := 0
	if shooting:
		f |= SHOOTING
	if dashing:
		f |= DASHING
	flags.append(f)


func size() -> int:
	return pos.size()


## Seconds of recording.
func length() -> float:
	return pos.size() / 60.0


func to_dict() -> Dictionary:
	return {"pos": pos, "aim": aim, "flags": flags}


static func from_dict(d: Dictionary) -> EchoTape:
	var t := EchoTape.new()
	if d.get("pos") is PackedVector2Array and d.get("aim") is PackedFloat32Array and d.get("flags") is PackedByteArray:
		var n: int = mini(d["pos"].size(), mini(d["aim"].size(), d["flags"].size()))
		t.pos = d["pos"].slice(0, n)
		t.aim = d["aim"].slice(0, n)
		t.flags = d["flags"].slice(0, n)
	return t
