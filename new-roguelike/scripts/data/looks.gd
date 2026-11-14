extends RefCounted
## Looks: how the player's knight is made their own (the mirror in your room, or Settings ->
## Your knight; the screen is scripts/ui/customize.gd). Three things, all kept in Save's settings:
##   hero_name    the knight's name; every "Aldous" in the story is replaced by it (Looks.say)
##   armour       a colour laid over his sprite (a tint: the pack's own picture, multiplied by a colour)
##   sword_look   which of the pack's sword pictures he carries (only a look; all swords fight the same)
## scripts/data/heroes.gd by_id("knight") hands out the knight's row with these applied, so the
## player, the camp, the menus and the end screen all show the same knight.
## To add a colour or a sword: add a row. "grip" is how many px above the bottom of the weapon
## picture the hand holds it. Keep a weapon about as long as the hero is tall, or shorter.

const DEFAULT_NAME := "Aldous"
const NAME_MAX := 12
## Names to pick from when there is no keyboard (a gamepad, a Steam Deck): the "Pick a name" row
## and the "Any name" button of the Your knight screen. Made up for this game; add or change freely.
const NAMES := ["Aldous", "Berrin", "Corwyn", "Davith", "Edda", "Fenwick", "Garrow", "Halvard", "Isolt",
	"Jorund", "Kestrel", "Lowen", "Maren", "Nesta", "Osric", "Perrin", "Quillon", "Rowan", "Sabine",
	"Torvald", "Ulla", "Verena", "Wystan", "Yarrow"]

const ARMOUR := [
	{"id": "steel", "name": "Steel", "tint": Color(1, 1, 1)},
	{"id": "gold", "name": "Gilded", "tint": Color(1.25, 1.05, 0.55)},
	{"id": "crimson", "name": "Crimson", "tint": Color(1.3, 0.62, 0.62)},
	{"id": "forest", "name": "Forest", "tint": Color(0.72, 1.15, 0.72)},
	{"id": "night", "name": "Night", "tint": Color(0.58, 0.58, 0.78)},
	{"id": "bone", "name": "Bone", "tint": Color(1.22, 1.16, 1.0)},
	{"id": "violet", "name": "Violet", "tint": Color(1.02, 0.72, 1.3)},
]

const SWORDS := [
	{"id": "knight", "name": "Knight's sword", "weapon": "pc_weapon_castle_13", "grip": 3},
	{"id": "arming", "name": "Arming sword", "weapon": "pc_weapon_castle_12", "grip": 4},
	{"id": "elven", "name": "Elven blade", "weapon": "pc_weapon_elf_0", "grip": 6},
	{"id": "ember", "name": "Ember blade", "weapon": "pc_weapon_forge_0", "grip": 6},
	{"id": "grave", "name": "Grave blade", "weapon": "pc_weapon_cemetery_0", "grip": 7},
	{"id": "sand", "name": "Sand blade", "weapon": "pc_weapon_desert_11", "grip": 4},
	{"id": "scholar", "name": "Scholar's blade", "weapon": "pc_weapon_library_7", "grip": 4},
	{"id": "wooden", "name": "Training sword", "weapon": "pc_weapon_wood_0", "grip": 5},
]


static func hero_name() -> String:
	var n := String(Save.setting("hero_name")).strip_edges()
	return n if n != "" else DEFAULT_NAME


## Story text with the knight's own name in it.
static func say(text: String) -> String:
	return text.replace(DEFAULT_NAME, hero_name())


static func _pick(list: Array, id: String) -> Dictionary:
	for row: Dictionary in list:
		if String(row["id"]) == id:
			return row
	return list[0]


static func armour() -> Dictionary:
	return _pick(ARMOUR, String(Save.setting("armour")))


static func sword() -> Dictionary:
	return _pick(SWORDS, String(Save.setting("sword_look")))


static func index_of(list: Array, id: String) -> int:
	for i in list.size():
		if String(list[i]["id"]) == id:
			return i
	return 0


## The knight's row from heroes.gd with the player's name, armour colour and sword on it.
static func apply(knight: Dictionary) -> Dictionary:
	var row := knight.duplicate()
	row["name"] = hero_name()
	row["tint"] = armour()["tint"]
	var s := sword()
	row["weapon"] = s["weapon"]
	row["grip"] = s["grip"]
	return (load("res://scripts/data/weapons.gd") as Script).call("apply", row)     # axe, spear, hammer, daggers
