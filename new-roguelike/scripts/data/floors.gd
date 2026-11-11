extends RefCounted
## Floors: the themes a run goes through, top to bottom. Use with:
##   const Floors = preload("res://scripts/data/floors.gd")
## To add or change a floor, edit a row here; nothing else needs to change.
##   name        shown on the floor banner
##   rooms       how many rooms the floor has (start, fights, treasure, shop and boss; the secret room is extra)
##   enemies     ids from enemies.gd that may appear; leave EMPTY to use every enemy whose "floors" lists this floor
##   ambient     the colour of the darkness (CanvasModulate); keep it fairly bright so enemies stay readable
##   tile_tint   a tint for floor and wall tiles only (gives each floor its own mood)
##   light       colour of the light around the player
##   fountain    "blue" or "red": which wall fountain this floor prefers
##   banners     wall banner tiles used as decoration
##   music / boss_music   names for Sfx.music()

const LIST := [
	{
		"id": "crypt", "name": "The Crypt", "rooms": 8, "enemies": [],
		"ambient": Color(0.66, 0.70, 0.86), "tile_tint": Color(0.90, 0.94, 1.0), "light": Color(1.0, 0.86, 0.66),
		"fountain": "blue", "banners": ["wall_banner_blue", "wall_banner_green"],
		"music": "floor1", "boss_music": "boss",
	},
	{
		"id": "warrens", "name": "The Warrens", "rooms": 10, "enemies": [],
		"ambient": Color(0.68, 0.78, 0.64), "tile_tint": Color(0.88, 1.0, 0.84), "light": Color(1.0, 0.92, 0.62),
		"fountain": "blue", "banners": ["wall_banner_green", "wall_banner_yellow"],
		"music": "floor2", "boss_music": "boss",
	},
	{
		"id": "ashen", "name": "The Ashen Halls", "rooms": 11, "enemies": [],
		"ambient": Color(0.86, 0.66, 0.58), "tile_tint": Color(1.0, 0.84, 0.76), "light": Color(1.0, 0.78, 0.52),
		"fountain": "red", "banners": ["wall_banner_red", "wall_banner_yellow"],
		"music": "floor3", "boss_music": "boss",
	},
	{
		"id": "pit", "name": "The Pit", "rooms": 12, "enemies": [],
		"ambient": Color(0.70, 0.56, 0.78), "tile_tint": Color(0.92, 0.76, 0.96), "light": Color(1.0, 0.72, 0.72),
		"fountain": "red", "banners": ["wall_banner_red", "wall_banner_blue"],
		"music": "floor4", "boss_music": "boss",
	},
]


static func count() -> int:
	return LIST.size()


static func get_floor(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
