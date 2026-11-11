extends RefCounted
## Floors: the themes a run goes through, top to bottom. Use with:
##   const Floors = preload("res://scripts/data/floors.gd")
## To add or change a floor, edit a row here; nothing else needs to change.
##   name        shown on the floor banner
##   rooms       how many rooms the floor has (start, fights, treasure, shop and boss; the secret room is extra)
##   enemies     ids from enemies.gd that may appear; leave EMPTY to use every enemy whose "floors" lists this floor
##   music / boss_music   names for Sfx.music()
##
## THE LOOK of a floor (read by scripts/run/room_look.gd and scripts/run/fx.gd). Walls, floor, doors,
## obstacles and decoration all come from ONE tile set of the purchased Pixel Crawler art; what a tile
## set holds is listed in assets/art/pc_tiles/tilesets.json (written by tools/pc_import_tiles.py).
##   tiles        the tile set: "crypt", "warrens", "ashen" or "pit" (a folder in assets/art/pc_tiles)
##   ambient      the colour of the darkness (CanvasModulate) on EVERYTHING: the tile set's own "ambient".
##                Keep it bright: monsters and heroes must stay easy to see. Lights add on top of it.
##   light        colour of the light around the player
##   torch_power  how strong torch and wall-light lights are (1.0 = normal)
##   wall_lights  [fewest, most] PAIRS of lit wall lights in a fight room (the set has four places = 2 pairs)
##   wall_deco    [fewest, most] loose wall decorations in a fight room (picked by the set's weights)
##   floor_deco   [fewest, most] small things lying on the floor of a fight room (kept dim)
##   no_floor_deco  pieces of the set's floor decoration this floor does not use
##   pit_depth    0..1: a shadow along the top inside edge of every pit (for pit tiles that have no rim)
##   secret_hole  dark rectangles (x, y, w, h in px inside the piece door_n_cracked): the opening of a
##                blown-open secret door in the back wall. Not drawn in a fight, so the wall reads shut.
##   debris       colours of the bits that fly off a broken "rock" / "crate"
##   dress        what each kind of room stands against or hangs on its back wall, so a shop, a treasure
##                room, a secret room and a boss room are told apart at a glance. Per room kind a list of
##                {piece, col (floor column 0-16), dx, y (px from the top of the wall; the wall is 48 tall),
##                flip (mirror it)}. A piece that would cover the back door is left out by itself.
##   motes        the specks floating in the air: count, colour, size in px, rise (px/s, minus = sinking),
##                drift (px/s sideways), twinkle (0..1 how much they flicker). Embers = fast rise + warm colour.
##   vignette     how dark the screen corners get (0 = off, 0.6 = strong)

const LIST := [
	{
		"id": "crypt", "name": "The Crypt", "rooms": 8, "enemies": [],
		"tiles": "crypt", "ambient": Color("b9c4c9"), "light": Color(1.0, 0.88, 0.70), "torch_power": 1.0,
		"wall_lights": [1, 2], "wall_deco": [2, 4], "floor_deco": [3, 6], "no_floor_deco": [],
		"pit_depth": 0.55, "secret_hole": [Rect2(4, 9, 16, 28), Rect2(5, 6, 14, 3), Rect2(7, 4, 10, 2)],
		"debris": {"rock": [Color("656256"), Color("32322b"), Color("8a8676")], "crate": [Color("62402e"), Color("3b2c22"), Color("8a5a3c")]},
		"dress": {
			"shop": [{"piece": "prop_urn_a", "col": 3, "y": 32}, {"piece": "prop_urn_b", "col": 4, "dx": 1, "y": 29}, {"piece": "prop_urn_a", "col": 13, "y": 32}],
			"treasure": [{"piece": "deco_reaper", "col": 3, "dx": 1, "y": 9}, {"piece": "deco_reaper", "col": 12, "dx": 1, "y": 9, "flip": true}],
			"secret": [{"piece": "deco_coffin_open", "col": 3, "y": 16}, {"piece": "deco_coffin", "col": 12, "dx": -2, "y": 16}],
			"boss": [{"piece": "deco_gargoyle", "col": 3, "y": 15}, {"piece": "deco_gargoyle", "col": 12, "y": 15, "flip": true}],
		},
		"motes": {"count": 12, "color": Color(0.78, 0.86, 1.0, 0.55), "size": 1.0, "rise": -2.0, "drift": 3.0, "twinkle": 0.5},
		"vignette": 0.46,
		"music": "floor1", "boss_music": "boss",
	},
	{
		"id": "warrens", "name": "The Warrens", "rooms": 10, "enemies": [],
		"tiles": "warrens", "ambient": Color("c4c2b4"), "light": Color(1.0, 0.95, 0.66), "torch_power": 0.9,
		"wall_lights": [1, 2], "wall_deco": [3, 5], "floor_deco": [3, 6], "no_floor_deco": ["prop_pit_dark"],
		"pit_depth": 0.0, "secret_hole": [],
		"debris": {"rock": [Color("404945"), Color("303734"), Color("5a6660")], "crate": [Color("8d6734"), Color("3d2514"), Color("b1924e")]},
		"dress": {
			"shop": [{"piece": "prop_crate", "col": 3, "y": 29}, {"piece": "prop_barrel", "col": 4, "y": 30}, {"piece": "prop_barrel", "col": 12, "y": 30}, {"piece": "prop_crate", "col": 13, "y": 29}],
			"treasure": [{"piece": "deco_chain", "col": 1, "dx": 3, "y": 12}, {"piece": "deco_keyhook", "col": 3, "dx": 5, "y": 20}, {"piece": "deco_keyhook", "col": 4, "dx": 5, "y": 20},
				{"piece": "deco_keyhook", "col": 12, "dx": 5, "y": 20}, {"piece": "deco_keyhook", "col": 13, "dx": 5, "y": 20}, {"piece": "deco_chain", "col": 15, "dx": 3, "y": 12}],
			"secret": [{"piece": "deco_lamp_off", "col": 2, "dx": 3, "y": 20}, {"piece": "deco_pipe", "col": 4, "dx": 4, "y": 0}, {"piece": "deco_pipe", "col": 12, "dx": 4, "y": 0}, {"piece": "deco_lamp_off", "col": 14, "dx": 3, "y": 20}],
			"boss": [{"piece": "deco_pipe", "col": 1, "dx": 4, "y": 0}, {"piece": "deco_chain", "col": 3, "dx": 3, "y": 12}, {"piece": "deco_pipe", "col": 4, "dx": 4, "y": 0},
				{"piece": "deco_pipe", "col": 12, "dx": 4, "y": 0}, {"piece": "deco_chain", "col": 13, "dx": 3, "y": 12}, {"piece": "deco_pipe", "col": 15, "dx": 4, "y": 0}],
		},
		"motes": {"count": 16, "color": Color(0.74, 0.95, 0.42, 0.6), "size": 1.0, "rise": 2.5, "drift": 5.0, "twinkle": 0.7},
		"vignette": 0.48,
		"music": "floor2", "boss_music": "boss",
	},
	{
		"id": "ashen", "name": "The Ashen Halls", "rooms": 11, "enemies": [],
		"tiles": "ashen", "ambient": Color("d0b8b0"), "light": Color(1.0, 0.80, 0.55), "torch_power": 1.1,
		"wall_lights": [1, 2], "wall_deco": [2, 4], "floor_deco": [3, 6], "no_floor_deco": [],
		"pit_depth": 0.0, "secret_hole": [Rect2(3, 5, 8, 22)],
		"debris": {"rock": [Color("614010"), Color("4f340e"), Color("301d0e")], "crate": [Color("6e2c2e"), Color("522a2b"), Color("281820")]},
		"dress": {
			"shop": [{"piece": "prop_barrel_a", "col": 3, "y": 32}, {"piece": "prop_barrel_b", "col": 4, "y": 31}, {"piece": "prop_barrel_a", "col": 13, "y": 32}],
			"treasure": [{"piece": "deco_statue", "col": 3, "dx": 2, "y": -2}, {"piece": "deco_statue", "col": 12, "dx": 2, "y": -2, "flip": true}],
			"secret": [{"piece": "deco_statue_broken", "col": 3, "dx": 2, "y": 10}, {"piece": "deco_statue_broken", "col": 12, "dx": 2, "y": 10, "flip": true}],
			"boss": [{"piece": "deco_pilaster_lit", "col": 1, "y": 0}, {"piece": "deco_pilaster_lit", "col": 4, "y": 0}, {"piece": "deco_pilaster_lit", "col": 12, "y": 0}, {"piece": "deco_pilaster_lit", "col": 15, "y": 0}],
		},
		"motes": {"count": 18, "color": Color(1.0, 0.62, 0.22, 0.8), "size": 1.0, "rise": 9.0, "drift": 4.0, "twinkle": 0.8},
		"vignette": 0.50,
		"music": "floor3", "boss_music": "boss",
	},
	{
		"id": "pit", "name": "The Pit", "rooms": 12, "enemies": [],
		"tiles": "pit", "ambient": Color("bdb8d6"), "light": Color(1.0, 0.76, 0.80), "torch_power": 1.0,
		"wall_lights": [1, 2], "wall_deco": [3, 5], "floor_deco": [2, 5], "no_floor_deco": [],
		"pit_depth": 0.0, "secret_hole": [Rect2(3, 3, 6, 17)],
		"debris": {"rock": [Color("8f8671"), Color("686151"), Color("4a4438")], "crate": [Color("7b513b"), Color("3b2c22"), Color("a06a48")]},
		"dress": {
			"shop": [{"piece": "prop_crate_a", "col": 3, "y": 29}, {"piece": "prop_crate_b", "col": 4, "y": 23}, {"piece": "prop_crate_a", "col": 13, "y": 29}],
			"treasure": [{"piece": "deco_banner_triple", "col": 3, "dx": -1, "y": 2}, {"piece": "deco_banner_triple", "col": 12, "dx": -1, "y": 2}],
			"secret": [{"piece": "deco_niche", "col": 3, "y": -2}, {"piece": "deco_window_dark", "col": 5, "y": 12}, {"piece": "deco_window_dark", "col": 11, "y": 12}, {"piece": "deco_niche", "col": 13, "y": -2}],
			"boss": [{"piece": "deco_window_lit", "col": 1, "y": 12}, {"piece": "deco_banner_triple", "col": 3, "dx": -1, "y": 2}, {"piece": "deco_banner_triple", "col": 12, "dx": -1, "y": 2}, {"piece": "deco_window_lit", "col": 15, "y": 12}],
		},
		"motes": {"count": 14, "color": Color(0.86, 0.56, 1.0, 0.6), "size": 1.0, "rise": 4.0, "drift": 2.0, "twinkle": 0.9},
		"vignette": 0.56,
		"music": "floor4", "boss_music": "final_boss",
	},
]


static func count() -> int:
	return LIST.size()


static func get_floor(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]
