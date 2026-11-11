extends RefCounted
## Floors: the themes a run goes through, top to bottom. Use with:
##   const Floors = preload("res://scripts/data/floors.gd")
## To add or change a floor, edit a row here; nothing else needs to change.
##   name        shown on the floor banner
##   rooms       how many rooms the floor has (start, fights, treasure, shop and boss; the secret room is extra)
##   enemies     ids from enemies.gd that may appear; leave EMPTY to use every enemy whose "floors" lists this floor
##   music / boss_music   names for Sfx.music()
##
## THE LOOK of a floor (read by scripts/run/room_look.gd and scripts/run/fx.gd). Every floor should be
## recognisable at a glance, and enemies must stay readable on all of them, so keep `ambient` from
## getting much darker than these and keep `tile_tint` away from pure colours.
##   ambient      the colour of the darkness (CanvasModulate). Lights add on top of it.
##   tile_tint    a tint for floor and wall tiles only
##   light        colour of the light around the player
##   torch_light  colour of the light a torch throws          flame_tint   tint of the flame sprites
##   torch_power  how strong torch lights are (1.0 = normal)
##   fountain     "blue" or "red": which wall fountain this floor prefers
##   banners      wall banner tiles used as decoration
##   cracks       0..1: how many floor tiles use a cracked variant
##   wall_bits    back-wall decorations and how common each is. Kinds: "hole" (broken bricks), "goo" (green
##                slime), "pipe", "grate" (sewer pieces), "fountain", "banners" (a matching pair)
##   floor_bits   small things lying on the floor, and how many groups a fight room gets at most:
##                "skulls" (bone piles by the walls), "moss" (green growth on tiles)
##   motes        the specks floating in the air: count, colour, size in px, rise (px/s, minus = sinking),
##                drift (px/s sideways), twinkle (0..1 how much they flicker). Embers = fast rise + warm colour.
##   vignette     how dark the screen corners get (0 = off, 0.6 = strong)

const LIST := [
	{
		"id": "crypt", "name": "The Crypt", "rooms": 8, "enemies": [],
		"ambient": Color(0.50, 0.55, 0.74), "tile_tint": Color(0.82, 0.90, 1.06), "light": Color(1.0, 0.88, 0.70),
		"torch_light": Color(1.0, 0.72, 0.42), "flame_tint": Color(1.0, 1.0, 1.0), "torch_power": 1.0,
		"fountain": "blue", "banners": ["wall_banner_blue", "wall_banner_green"],
		"cracks": 0.20,
		"wall_bits": {"hole": 0.5, "goo": 0.1, "pipe": 0.0, "grate": 0.0, "fountain": 0.35, "banners": 0.55},
		"floor_bits": {"skulls": 2, "moss": 0},
		"motes": {"count": 12, "color": Color(0.78, 0.86, 1.0, 0.55), "size": 1.0, "rise": -2.0, "drift": 3.0, "twinkle": 0.5},
		"vignette": 0.46,
		"music": "floor1", "boss_music": "boss",
	},
	{
		"id": "warrens", "name": "The Warrens", "rooms": 10, "enemies": [],
		"ambient": Color(0.50, 0.62, 0.46), "tile_tint": Color(0.80, 0.98, 0.70), "light": Color(1.0, 0.95, 0.66),
		"torch_light": Color(0.90, 0.86, 0.36), "flame_tint": Color(0.92, 1.12, 0.62), "torch_power": 0.95,
		"fountain": "blue", "banners": ["wall_banner_green", "wall_banner_yellow"],
		"cracks": 0.30,
		"wall_bits": {"hole": 0.4, "goo": 0.75, "pipe": 0.6, "grate": 0.6, "fountain": 0.2, "banners": 0.25},
		"floor_bits": {"skulls": 1, "moss": 9},
		"motes": {"count": 16, "color": Color(0.74, 0.95, 0.42, 0.6), "size": 1.0, "rise": 2.5, "drift": 5.0, "twinkle": 0.7},
		"vignette": 0.48,
		"music": "floor2", "boss_music": "boss",
	},
	{
		"id": "ashen", "name": "The Ashen Halls", "rooms": 11, "enemies": [],
		"ambient": Color(0.70, 0.50, 0.42), "tile_tint": Color(1.10, 0.80, 0.66), "light": Color(1.0, 0.80, 0.55),
		"torch_light": Color(1.0, 0.55, 0.22), "flame_tint": Color(1.1, 0.95, 0.85), "torch_power": 1.15,
		"fountain": "red", "banners": ["wall_banner_red", "wall_banner_yellow"],
		"cracks": 0.38,
		"wall_bits": {"hole": 0.7, "goo": 0.0, "pipe": 0.0, "grate": 0.15, "fountain": 0.5, "banners": 0.5},
		"floor_bits": {"skulls": 2, "moss": 0},
		"motes": {"count": 18, "color": Color(1.0, 0.62, 0.22, 0.8), "size": 1.0, "rise": 9.0, "drift": 4.0, "twinkle": 0.8},
		"vignette": 0.50,
		"music": "floor3", "boss_music": "boss",
	},
	{
		"id": "pit", "name": "The Pit", "rooms": 12, "enemies": [],
		"ambient": Color(0.52, 0.42, 0.68), "tile_tint": Color(0.84, 0.68, 1.02), "light": Color(1.0, 0.76, 0.80),
		"torch_light": Color(0.80, 0.40, 1.0), "flame_tint": Color(0.86, 0.62, 1.5), "torch_power": 1.1,
		"fountain": "red", "banners": ["wall_banner_red", "wall_banner_blue"],
		"cracks": 0.45,
		"wall_bits": {"hole": 0.9, "goo": 0.2, "pipe": 0.0, "grate": 0.3, "fountain": 0.25, "banners": 0.35},
		"floor_bits": {"skulls": 4, "moss": 0},
		"motes": {"count": 14, "color": Color(0.86, 0.56, 1.0, 0.6), "size": 1.0, "rise": 4.0, "drift": 2.0, "twinkle": 0.9},
		"vignette": 0.56,
		"music": "floor4", "boss_music": "final_boss",
	},
]


static func count() -> int:
	return LIST.size()


static func get_floor(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
