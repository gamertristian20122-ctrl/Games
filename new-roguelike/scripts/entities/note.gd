extends Node2D
## A note lying in a treasure or secret room: a page of the king's story (scripts/data/story.gd
## NOTES). Walk onto it to read it; the game stops while you read. Found notes are kept (the
## Chronicler in the village has them all). The picture is the pack's written page (hub_note).
## desc: {"pos": Vector2, "note": int}

const Story = preload("res://scripts/data/story.gd")

var kind := "note"
var solid := false
var room: Node
var index := 0
var _t := 0.0
var _taken := false
var _page: Sprite2D


func setup(the_room: Node, desc: Dictionary) -> void:
	room = the_room
	position = desc.get("pos", G.ROOM_CENTER)
	index = int(desc.get("note", 0))
	_page = Sprite2D.new()
	_page.texture = Art.tex("hub_note")
	_page.position = Vector2(0, -6)
	add_child(_page)


func save() -> Dictionary:
	return {"kind": "note", "pos": position, "note": index}


func _physics_process(delta: float) -> void:
	_t += delta
	_page.position.y = -6.0 + roundf(sin(_t * 3.0) * 1.5)
	var player: Node = room.run.player
	if _taken or player == null or player.dead or room.run.busy() or room.fighting:
		return
	if (player.position as Vector2).distance_to(position) < 9.0:
		_taken = true
		Story.find_note(index)
		G.stat.emit("notes_found", 1)
		Sfx.play("ui_start", -4.0)
		room.run.fx.ring(position, 2.0, 16.0, 0.35, Color(1, 1, 0.8), 1.5, true)
		G.note_found.emit(index)
		room.remove_thing(self)
		queue_free()
