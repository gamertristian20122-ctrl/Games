extends RefCounted
## WOUNDS (v0.38.0, "make fights matter"): health and mana now CARRY OVER from one battle to the next.
## What is kept is what each fighter has LOST (so a level-up's bigger health is not lost with it).
##   apply(party)   before a battle: everybody starts as hurt as they were
##   keep(party)    after a won or fled battle: write down what is lost. Somebody who fell gets up
##                  after the battle with FALLEN_HP of their health (they are carried, not left).
##   rest()         sleep in a bed, a room at the inn, a level-up, waking after a lost battle: all whole.
## Save keys (hub section): "wound:hp:<id>", "wound:mp:<id>".

const FALLEN_HP := 0.15


static func apply(party: Array) -> void:
	for u: Dictionary in party:
		var id := String(u["id"])
		u["start_hp"] = clampi(int(u["max_hp"]) - Save.hub_get("wound:hp:" + id), 1, int(u["max_hp"]))
		u["start_mp"] = clampi(int(u["max_mp"]) - Save.hub_get("wound:mp:" + id), 0, int(u["max_mp"]))


static func keep(party: Array) -> void:
	for u: Dictionary in party:
		var id := String(u["id"])
		var hp := int(u["hp"])
		if hp <= 0:
			hp = maxi(1, roundi(float(u["max_hp"]) * FALLEN_HP))
		Save.hub_set("wound:hp:" + id, maxi(0, int(u["max_hp"]) - hp))
		Save.hub_set("wound:mp:" + id, maxi(0, int(u["max_mp"]) - int(u["mp"])))


static func rest() -> void:
	var keys: Array = (Save.data["hub"] as Dictionary).keys()
	for k: Variant in keys:
		if String(k).begins_with("wound:"):
			Save.hub_set(String(k), 0)


## Is anybody hurt or short of mana?
static func any() -> bool:
	for k: Variant in (Save.data["hub"] as Dictionary).keys():
		if String(k).begins_with("wound:hp:") and Save.hub_get(String(k)) > 0:
			return true
	return false


## (quality pass P11) Writes down where one fighter stands now, outside a battle (an item used from
## the Items page): health and mana as they are, against their full amounts.
static func set_now(id: String, hp: int, max_hp: int, mp: int, max_mp: int) -> void:
	Save.hub_set("wound:hp:" + id, clampi(max_hp - hp, 0, max_hp))
	Save.hub_set("wound:mp:" + id, clampi(max_mp - mp, 0, max_mp))
