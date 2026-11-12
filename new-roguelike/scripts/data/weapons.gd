extends RefCounted
## Weapons: what the knight can carry instead of his sword. He switches at the smith's anvil.
## The owner asked for these four on 11 Nov 2026, got "by a mix": one from a boss, one from the
## Elfwood, one forged at the smith, one hidden in a secret room.
##   "sprite", "grip"   the pack's picture and where the hand holds it (the sword's come from looks.gd)
##   "melee"            the swing (see _swing() in scripts/entities/player.gd): reach px, arc radians,
##                      knock, and two extras: "stun" seconds a blow stuns, "break" true = it smashes
##                      rocks and logs inside the swing
##   "damage", "rate"   x the knight's own damage and swings per second
##   "twin"             a second one in the other hand (only a look)
##   "how"              where it comes from, in words          "price"  coins at the smith ("forge")
## Owned weapons are kept in the save's hub section as "wpn:<id>"; the one carried is the setting
## "weapon". Story levels hand one out with "gives" (scripts/data/story.gd).

const LIST := [
	{"id": "sword", "name": "Sword", "text": "Even reach and speed.", "how": "yours from the start"},
	{"id": "axe", "name": "Great axe", "sprite": "pc_weapon_castle_8", "grip": 6, "text": "Slow, wide, heavy blows that shove monsters back.",
		"melee": {"reach": 37.0, "arc": 3.0, "knock": 2.8}, "damage": 1.7, "rate": 0.62, "how": "forged by the smith", "price": 60},
	{"id": "spear", "name": "Spear", "sprite": "pc_weapon_wood_4", "grip": 14, "text": "Long, narrow thrusts that keep monsters away.",
		"melee": {"reach": 54.0, "arc": 0.7, "knock": 1.3}, "damage": 1.05, "rate": 1.0, "how": "free the Singing Glade in the Elfwood"},
	{"id": "hammer", "name": "War hammer", "sprite": "pc_weapon_wood_1", "grip": 9, "text": "Very slow. Stuns what it hits and smashes rocks.",
		"melee": {"reach": 33.0, "arc": 2.2, "knock": 2.2, "stun": 0.9, "break": true}, "damage": 2.3, "rate": 0.48, "how": "beat Stonejaw in the Warrens"},
	{"id": "daggers", "name": "Twin daggers", "sprite": "pc_weapon_castle_26", "grip": 3, "text": "Very fast, very short, light cuts.",
		"melee": {"reach": 25.0, "arc": 1.7, "knock": 0.8}, "damage": 0.62, "rate": 2.0, "twin": true, "how": "hidden in a secret room of the Warrens"},
]


static func row(id: String) -> Dictionary:
	for r: Dictionary in LIST:
		if String(r["id"]) == id:
			return r
	return LIST[0]


static func owned(id: String) -> bool:
	return id == "sword" or Save.hub_get("wpn:" + id) > 0


## Hands the weapon over. Returns true when it is new.
static func grant(id: String) -> bool:
	if owned(id):
		return false
	Save.hub_set("wpn:" + id, 1)
	Save.flush()
	return true


static func current() -> Dictionary:
	if G.arg("weapon") != "":
		return row(G.arg("weapon"))        # test flag --weapon=<id>
	var id := String(Save.setting("weapon"))
	return row(id) if owned(id) else LIST[0]


## Puts the carried weapon on the knight's row (after looks.gd has put the sword look on it).
static func apply(knight: Dictionary) -> Dictionary:
	var w := current()
	if String(w["id"]) == "sword":
		return knight
	knight["weapon"] = w["sprite"]
	knight["grip"] = w["grip"]
	var melee: Dictionary = (knight.get("melee", {}) as Dictionary).duplicate()
	for key: String in w["melee"]:
		melee[key] = w["melee"][key]
	knight["melee"] = melee
	knight["damage"] = float(knight["damage"]) * float(w.get("damage", 1.0))
	knight["rate"] = float(knight["rate"]) * float(w.get("rate", 1.0))
	knight["twin"] = bool(w.get("twin", false))
	knight["weapon_name"] = w["name"]
	return knight
