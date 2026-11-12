extends RefCounted
## Familiar behaviour "porter": the Blood Porter. Red hearts the hero has no room for go to the bat
## instead of staying on the floor (player.gd asks can_carry() and hands them over with stash()).
## It arrives carrying all it can hold, and shows what it carries as small hearts hanging under it. When the hero has been short of red
## health for `wait` seconds, it feeds him what he is missing and keeps the rest.
## params:  carry  half hearts it can hold      wait  seconds before it feeds

func start(f) -> void:
	f.mem = {"held": int(f.p.get("carry", 2)), "wait": 0.0, "icons": []}      # it arrives with its hands full
	_show(f)


func can_carry(f, _amount: int) -> bool:
	return int(f.mem.get("held", 0)) < int(f.p.get("carry", 2))


## Takes up to `amount` half hearts. True when it took any.
func stash(f, amount: int) -> bool:
	var room_left := int(f.p.get("carry", 2)) - int(f.mem.get("held", 0))
	var take := mini(amount, room_left)
	if take <= 0:
		return false
	f.mem["held"] = int(f.mem.get("held", 0)) + take
	_show(f)
	Sfx.play("familiar_chirp", -8.0, 0.05, 1.2)
	return true


func tick(f, delta: float) -> void:
	var held := int(f.mem.get("held", 0))
	var missing: int = f.player.max_hp - f.player.hp
	if held <= 0 or missing <= 0:
		f.mem["wait"] = 0.0
		return
	f.mem["wait"] = float(f.mem.get("wait", 0.0)) + delta
	if float(f.mem["wait"]) < float(f.p.get("wait", 1.0)):
		return
	var fed := mini(held, missing)
	f.mem["held"] = held - fed
	f.mem["wait"] = 0.0
	f.player.hp += fed
	_show(f)
	var at: Vector2 = f.player.position - Vector2(0, 8)
	f.run.fx.ring(at, 4.0, 18.0, 0.35, Color(1.0, 0.35, 0.35), 2.0)
	f.run.fx.burst(at, [Color(1.0, 0.3, 0.3), Color(1.0, 0.7, 0.7)], 6, 40.0, 0.4, 2.0)
	Sfx.play("heart_pickup", -3.0)
	G.hud_changed.emit()


## One small heart sprite under the bat for every half heart it carries.
func _show(f) -> void:
	for icon: Variant in f.mem.get("icons", []):
		if is_instance_valid(icon):
			(icon as Node).queue_free()
	var icons: Array = []
	var held := int(f.mem.get("held", 0))
	for k in held:
		var heart: AnimatedSprite2D = Art.sprite("prop_half_heart", "default")
		heart.position = Vector2((float(k) - float(held - 1) * 0.5) * 7.0, -3.0)
		f.add_child(heart)
		icons.append(heart)
	f.mem["icons"] = icons
