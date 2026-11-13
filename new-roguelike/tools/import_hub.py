#!/usr/bin/env python3
"""Hub art importer: cuts pieces for the camp (scripts/hub/) out of the purchased Pixel Crawler packs.

    python3 -I tools/import_hub.py [--sheet /abs/dir]     then: godot --headless --path . --import

It ONLY cuts: every piece is an untouched rectangle of a pack sheet (the two earth patches also
lose the grass painted round them: pixels removed, none changed) (found as an "island" of
non-transparent pixels inside a region named below). Output: assets/art/hub/hub_*.png and
assets/art/hub/hub_pieces.json (size and source of every piece). --sheet writes a labelled
contact sheet to LOOK at. Packs: Fairy Forest, Cemetery, Free Pack Exterior (zips in
assets_raw/paid_pixel_crawler/zips/; the repo is private because of them).
"""
import io, json, os, sys, zipfile
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIPS = os.path.join(ROOT, "assets_raw", "paid_pixel_crawler", "zips")
OUT = os.path.join(ROOT, "assets", "art", "hub")
FOREST = ("Pixel_Crawler_-_Fairy_Forest_1.7.zip", "Assets/")
CEM = ("Pixel_Crawler_-_Cemetery_0.4.zip", "Environment/Props/")
FREE = ("Pixel_Crawler_-_Free_Pack_Exterior_0.1.zip", "Environment/")
BUILD = ("Pixel_Crawler_-_Free_Pack_Exterior_0.1.zip", "Environment/Structures/Buildings/")
MOCK = ("Pixel_Crawler_-_Free_Pack_Exterior_0.1.zip", "MockUps/")
DESERT = ("Pixel_Crawler_-_Desert.zip", "Assets/")        # the desert camp and the sands of the world map
FORGE = ("Pixel_Crawler_-_Forge_1.2.zip", "Assets/")     # the mountain camp
GARDEN = ("Pixel_Crawler_-_Garden_Environment.zip", "Assets/")           # the town: cobbles, fountain, statues, cypresses, flowers
CASTLE = ("Pixel_Crawler_-_Castle_Environment_0.3.zip", "Assets/")       # the town: potted trees, banners, busts
HIDE = ("Pixel_Crawler_-_Hideout_1.0.zip", "Assets/")                    # street dressing: barrels, a sack, a notice board

# (name, pack, file ending, region x0 y0 x1 y1, gap px that still joins two islands, smallest piece px)
ISLANDS = [
    ("bush_green", FOREST, "Props.png", (0, 0, 192, 48), 1, 60),
    ("bush_orange", FOREST, "Props.png", (0, 48, 192, 96), 1, 60),
    ("bush_deep", FOREST, "Props.png", (0, 96, 192, 144), 1, 60),
    ("bush_rust", FOREST, "Props.png", (0, 144, 192, 192), 1, 60),
    ("tuft", FOREST, "Props.png", (192, 0, 256, 96), 0, 6),
    ("twig", FOREST, "Props.png", (256, 0, 290, 96), 0, 6),
    ("plant", FOREST, "Props.png", (192, 96, 292, 128), 0, 12),
    ("flower", FOREST, "Props.png", (192, 128, 272, 224), 0, 6),
    ("bloom", FOREST, "Props.png", (290, 0, 448, 96), 1, 40),
    ("vine", FOREST, "Props.png", (290, 96, 448, 160), 1, 30),
    ("shroom", FOREST, "Props.png", (290, 160, 448, 192), 1, 12),
    ("rock", FOREST, "Props.png", (0, 220, 160, 272), 1, 40),
    ("rock_moss", FOREST, "Props.png", (0, 272, 160, 320), 1, 40),
    ("stone", FOREST, "Props.png", (160, 224, 256, 272), 1, 40),
    ("rune", FOREST, "Props.png", (160, 272, 256, 320), 1, 40),
    ("pebble", FOREST, "Props.png", (0, 320, 160, 352), 0, 4),
    ("tree_green", FOREST, "Tree.png", (0, 0, 624, 224), 2, 200),
    ("tree_pink", FOREST, "Tree.png", (0, 672, 624, 896), 2, 200),
    ("tree_teal", FOREST, "Tree.png", (624, 672, 1248, 896), 2, 200),
    ("stump", FOREST, "Tree.png", (0, 1568, 220, 1640), 1, 40),
    ("gate", CEM, "Props.png", (0, 0, 64, 86), 1, 400),
    ("arch", CEM, "Props.png", (0, 184, 64, 260), 1, 400),
    ("cross", CEM, "Graves.png", (0, 0, 170, 66), 1, 30),
    ("tomb", CEM, "Graves.png", (0, 92, 215, 194), 1, 100),
    ("statue", CEM, "Graves.png", (0, 194, 120, 240), 1, 100),
    ("anvil", FREE, "Structures/Stations/Anvil/Anvil.png", (0, 32, 80, 96), 3, 200),
    ("bench", FREE, "Structures/Stations/Workbench/Workbench.png", (0, 64, 64, 116), 3, 200),
    ("farm", FREE, "Props/Static/Farm.png", (250, 0, 400, 130), 1, 60),
    # world dressing (v0.24.0): single garden flowers, garden stones and grass, castle busts and wall candles
    ("gflower", GARDEN, "Tiles.png", (224, 288, 288, 416), 0, 4),
    ("gstone", GARDEN, "Tiles.png", (352, 330, 384, 384), 0, 4),
    ("gtuft", GARDEN, "Tiles.png", (0, 380, 64, 400), 0, 4),
    ("cbust", CASTLE, "Tiles.png", (272, 72, 368, 160), 1, 60),
    ("ccandle", CASTLE, "Tiles.png", (336, 160, 400, 192), 1, 10),
    # SET DRESSING (dense streets, woods and the desert town): round bushes in four colours, ferns,
    # reeds and foxgloves, bare dead trees, the hideout's barrels, the wind's ripples on the sand
    ("vbush", FREE, "Props/Static/Vegetation.png", (192, 0, 384, 144), 1, 60),
    ("vbig", FREE, "Props/Static/Vegetation.png", (0, 97, 192, 144), 1, 60),
    ("vplant", FREE, "Props/Static/Vegetation.png", (64, 146, 240, 190), 0, 20),
    ("vdead", FREE, "Props/Static/Vegetation.png", (160, 296, 252, 337), 1, 30),
    ("sbarrel", HIDE, "Tiles.png", (182, 306, 290, 400), 1, 200),
    ("sripple", DESERT, "Sand.png", (0, 0, 288, 160), 2, 40),
    # ROUND TWO (places like the reference pictures): the Fairy Forest's giant trunk in three lights (its
    # top and middle pieces stack on the root piece) and its leaf masses in six shades, the darkest near
    # black: dark leaves and trunks frame the near edge of the woods, lit ones crown the clearing's trees
    ("ftrunk", FOREST, "Tree.png", (720, 1370, 1210, 1540), 1, 400),
    ("froots", FOREST, "Tree.png", (670, 1545, 1248, 1664), 1, 400),
    ("fleaf_g", FOREST, "Tree.png", (240, 1340, 720, 1420), 1, 200),
    ("fleaf_o", FOREST, "Tree.png", (240, 1500, 640, 1580), 1, 200),
]
# (name, pack, file ending, x, y, w, h): plain rectangles (ground tiles are opaque, islands cannot find them)
RECTS = [
    ("grass", FOREST, "Tiles.png", 0, 224, 112, 48),
    ("dirt", FOREST, "Tiles.png", 16, 280, 32, 32),
    ("patch_0", FOREST, "Tiles.png", 0, 128, 48, 48),
    ("patch_1", FOREST, "Tiles.png", 0, 176, 48, 48),
    ("sand", DESERT, "Ground.png", 32, 20, 32, 32),          # ground tiles: the sands, sandstone paving, forge flagstones
    ("paving", DESERT, "Ground.png", 160, 144, 32, 32),
    ("fflag", FORGE, "Tiles.png", 32, 112, 32, 32),
    ("drock", DESERT, "Ground.png", 184, 24, 32, 32),         # bare mountain rock
    # the tavern from outside: a stretch of plastered wall, the wooden gable roof, an open doorway, a window
    ("wall_plaster", BUILD, "Walls.png", 288, 184, 128, 56),
    ("roof_wood", BUILD, "Roofs.png", 0, 6, 128, 89),
    ("doorway", BUILD, "Props.png", 1, 23, 30, 41),
    ("window", BUILD, "Props.png", 132, 99, 24, 25),
    ("bench_long", BUILD, "Props.png", 83, 160, 58, 32),
    # the town of the new story (v0.19.0): more walls and a second roof, doors, windows, a chimney, fences
    ("wall_log", BUILD, "Walls.png", 0, 184, 96, 56),
    ("wall_plank", BUILD, "Walls.png", 96, 186, 96, 54),
    ("wall_dark", BUILD, "Walls.png", 192, 189, 96, 51),
    ("wall_white", BUILD, "Walls.png", 384, 189, 96, 51),
    ("wall_brick", BUILD, "Walls.png", 480, 189, 96, 51),
    ("roof_teal", BUILD, "Roofs.png", 128, 6, 128, 89),
    # the town's dressing from the Garden and Castle packs (v0.22.0)
    ("gcobble", GARDEN, "Tiles.png", 136, 12, 32, 24),             # cobblestones (laid tile by tile, each turned at random)
    ("gfountain", GARDEN, "Tiles.png", 400, 2, 80, 94),
    ("gbasin", GARDEN, "Tiles.png", 336, 32, 48, 40),
    ("gpool", GARDEN, "Tiles.png", 320, 80, 80, 78),
    ("gspout_f0", GARDEN, "Tiles.png", 432, 100, 48, 68), ("gspout_f1", GARDEN, "Tiles.png", 432, 180, 48, 68),
    ("gspout_f2", GARDEN, "Tiles.png", 432, 260, 48, 68), ("gspout_f3", GARDEN, "Tiles.png", 432, 340, 48, 68),
    ("gcypress_0", GARDEN, "Tiles.png", 152, 269, 31, 98), ("gcypress_1", GARDEN, "Tiles.png", 194, 270, 28, 97),
    ("gbench", GARDEN, "Tiles.png", 67, 368, 74, 32),
    ("glily_0", GARDEN, "Tiles.png", 304, 244, 31, 23), ("glily_1", GARDEN, "Tiles.png", 320, 274, 34, 28), ("glily_2", GARDEN, "Tiles.png", 336, 240, 16, 32),
    ("gbed_0", GARDEN, "Tiles.png", 144, 379, 16, 22), ("gbed_1", GARDEN, "Tiles.png", 160, 375, 16, 23), ("gbed_2", GARDEN, "Tiles.png", 176, 379, 16, 22),
    ("gbed_3", GARDEN, "Tiles.png", 192, 375, 16, 23), ("gbed_4", GARDEN, "Tiles.png", 144, 427, 16, 22), ("gbed_5", GARDEN, "Tiles.png", 160, 423, 16, 23),
    ("gbed_6", GARDEN, "Tiles.png", 176, 427, 16, 22), ("gbed_7", GARDEN, "Tiles.png", 192, 423, 16, 23),
    ("gurn_0", GARDEN, "Tiles.png", 400, 331, 16, 21), ("gurn_1", GARDEN, "Tiles.png", 417, 328, 14, 24),
    ("gstatue_0", GARDEN, "Tiles.png", 418, 420, 28, 54), ("gstatue_1", GARDEN, "Tiles.png", 453, 432, 25, 42),
    ("cpot_0", CASTLE, "Tiles.png", 341, 208, 23, 64), ("cpot_1", CASTLE, "Tiles.png", 272, 225, 16, 47), ("cpot_2", CASTLE, "Tiles.png", 288, 225, 15, 47),
    ("cbanner_0", CASTLE, "Tiles.png", 278, 172, 36, 46), ("cbanner_1", CASTLE, "Tiles.png", 320, 172, 16, 30),
    # flat stretches of roof, for the real 3D houses (v0.20.0): they repeat sideways, plank by plank
    ("roof_planks", BUILD, "Roofs.png", 36, 166, 56, 38),
    ("roof_tiles", BUILD, "Roofs.png", 164, 166, 56, 38),
    ("door_wood", BUILD, "Props.png", 102, 29, 20, 36),
    ("door_iron", BUILD, "Props.png", 134, 27, 20, 38),
    ("door_arch", BUILD, "Props.png", 166, 25, 20, 40),
    ("win_arch", BUILD, "Props.png", 67, 62, 26, 35),
    ("win_shut", BUILD, "Props.png", 128, 62, 32, 34),
    ("win_closed", BUILD, "Props.png", 197, 64, 22, 32),
    ("win_tall", BUILD, "Props.png", 35, 94, 26, 35),
    ("chimney", BUILD, "Props.png", 4, 73, 24, 55),
    ("post", BUILD, "Props.png", 4, 128, 8, 48),
    ("stonebench", BUILD, "Props.png", 17, 132, 30, 12),
    ("flowerbox", BUILD, "Props.png", 18, 160, 28, 11),
    ("planter", BUILD, "Props.png", 50, 154, 28, 17),
    ("fence_a", BUILD, "Props.png", 20, 176, 40, 18),
    ("fence_b", BUILD, "Props.png", 20, 236, 40, 20),
    ("note", FREE, "Props/Static/Esoteric.png", 35, 130, 9, 11),      # a written page: the notes found in the levels
    # ARCHITECTURE (scripts/hub/view3d_build.gd, scripts/hub/arch/): surfaces laid on real 3D blocks at
    # their true pixel size, so each must repeat without a seam (checked by laying them 3 x 2)
    ("bstone", CASTLE, "Tiles.png", 80, 16, 48, 32),         # grey ashlar: plinths, garden walls, chimneys, kerbs, the bridge
    ("bplank", CASTLE, "Tiles.png", 96, 272, 48, 48),        # dark upright boards: gable ends, decks, the jetty
    ("brail", CASTLE, "Tiles.png", 128, 54, 48, 18),         # a stone balustrade (see-through between the balusters)
    ("bbeam", BUILD, "Roofs.png", 1, 239, 46, 6),            # a timber beam lying along (storey bands, fascias, ridges)
    ("bpost", BUILD, "Roofs.png", 5, 103, 6, 52),            # a timber post standing up (corner posts, jetty posts)
    ("bfringe", BUILD, "Roofs.png", 3, 255, 43, 8),          # the carved trim that hangs under an eave
    ("bsandwall", DESERT, "Ground.png", 20, 198, 56, 38),    # sandstone wall with its blue band: Dustwatch's houses and wall
    ("bsandcap", DESERT, "Ground.png", 16, 112, 64, 12),     # a sandstone coping slab: parapets, merlons, kerbs in the Sands
    ("bsandbrick", DESERT, "Ground.png", 22, 212, 48, 14),   # plain sandstone courses (two, they repeat): the houses of Dustwatch
    ("bcloth", HIDE, "Tiles.png", 323, 341, 10, 26),         # (round three) plain canvas with its folds, from the Hideout's hanging cloth: a furled sail
]
# (name, pack, file ending, x, y, w, h) in NATIVE pixels of a picture the pack ships at twice its
# size (every pixel doubled; halving it by taking every second pixel gives the artist's own pixels
# back). The tavern picture is the pack's own finished tavern: your room and the hall are cut from it.
HALVED = [
    ("in_room", MOCK, "Tavern.png", 488, 470, 144, 164),
    ("in_hall", MOCK, "Tavern.png", 168, 88, 464, 262),
]
# (name, pack, file ending, frame w, frame h): animation strips, cut into frames hub_<name>_f<n>.png
STRIPS = [
    ("fire_a", FREE, "Structures/Stations/Bonfire/Bonfire_01-Sheet.png", 32, 32),
    ("fire_b", FREE, "Structures/Stations/Bonfire/Bonfire_05-Sheet.png", 32, 32),
    ("fire_c", FREE, "Structures/Stations/Bonfire/Bonfire_09-Sheet.png", 64, 32),
    ("flame", FREE, "Structures/Stations/Bonfire/Fire_01-Sheet.png", 32, 48),
]
_cache = {}
# (name, pack, file ending, x, y, w, h, (hole x0, y0, x1, y1) inside the piece): a rectangle with a hole cleared
OPENED = [
    ("ghedge_arch", GARDEN, "Tiles.png", 96, 100, 80, 80, (16, 40, 64, 80)),
    # the lamp post with a lantern on its arm: a second lantern stands on the ground beside its foot (removed)
    ("slantern", FREE, "Props/Static/Furniture.png", 144, 446, 48, 50, (33, 35, 48, 50)),
]


# Desert and Forge pieces (the world map, Dustwatch, Emberfall, desert fights). Same as RECTS, and the
# empty border round each piece is cut off.
TRIMMED = [
    ("dcave", DESERT, "Ground.png", 96, 64, 64, 64), ("dspire_0", DESERT, "Ground.png", 96, 24, 16, 32), ("dspire_1", DESERT, "Ground.png", 136, 24, 24, 40),
    ("dgrass_0", DESERT, "Ground.png", 160, 80, 16, 16), ("dgrass_1", DESERT, "Ground.png", 176, 80, 16, 16),
    ("dgrass_2", DESERT, "Ground.png", 192, 80, 16, 16), ("dgrass_3", DESERT, "Ground.png", 208, 80, 16, 16),
    ("dboulder_0", DESERT, "Ground.png", 162, 100, 46, 44), ("dboulder_1", DESERT, "Ground.png", 210, 112, 30, 32),
    ("dstairs", DESERT, "Ground.png", 96, 128, 64, 50), ("ddoor", DESERT, "Ground.png", 96, 176, 64, 48),
    ("dblock_0", DESERT, "Ground.png", 160, 178, 16, 12), ("dblock_1", DESERT, "Ground.png", 176, 176, 16, 16),
    ("dblock_2", DESERT, "Ground.png", 162, 196, 12, 8), ("dblock_3", DESERT, "Ground.png", 180, 196, 10, 12),
    ("dpillar_0", DESERT, "Ground.png", 0, 240, 16, 56), ("dpillar_1", DESERT, "Ground.png", 16, 240, 16, 56),
    ("dpillar_2", DESERT, "Ground.png", 32, 250, 16, 46), ("dpillar_3", DESERT, "Ground.png", 48, 268, 14, 28),
    ("dbush_0", DESERT, "Ground.png", 64, 240, 46, 64), ("dbush_1", DESERT, "Ground.png", 112, 256, 32, 48), ("dbush_2", DESERT, "Ground.png", 144, 272, 16, 32),
    ("cactus_0", DESERT, "Ground.png", 112, 224, 14, 32), ("cactus_1", DESERT, "Ground.png", 128, 228, 16, 28), ("cactus_2", DESERT, "Ground.png", 146, 230, 12, 40),
    ("cactus_3", DESERT, "Ground.png", 160, 218, 16, 42), ("cactus_4", DESERT, "Ground.png", 184, 218, 32, 42), ("cactus_5", DESERT, "Ground.png", 160, 272, 12, 16),
    ("dshrub", DESERT, "Ground.png", 176, 274, 32, 30), ("drockbed", DESERT, "Ground.png", 160, 0, 80, 80),
    ("dpebble_0", DESERT, "Ground.png", 112, 0, 16, 14), ("dpebble_1", DESERT, "Ground.png", 128, 2, 14, 12),
    ("obelisk_0", DESERT, "Props.png", 0, 4, 32, 124), ("obelisk_1", DESERT, "Props.png", 32, 44, 32, 84), ("obelisk_2", DESERT, "Props.png", 64, 62, 32, 66),
    ("dstone_0", DESERT, "Props.png", 2, 128, 28, 46), ("dstone_1", DESERT, "Props.png", 34, 138, 28, 36), ("dstone_2", DESERT, "Props.png", 66, 146, 28, 28),
    ("tusk_0", DESERT, "Props.png", 2, 176, 56, 74), ("tusk_1", DESERT, "Props.png", 66, 176, 42, 48), ("tusk_2", DESERT, "Props.png", 112, 176, 30, 34),
    ("dtree_0", DESERT, "Props.png", 0, 260, 64, 76), ("dtree_1", DESERT, "Props.png", 64, 254, 28, 32),
    ("dchest", DESERT, "Props.png", 96, 8, 32, 24), ("dpot_0", DESERT, "Props.png", 96, 74, 16, 20), ("dpot_1", DESERT, "Props.png", 112, 72, 16, 22),
    ("farch", FORGE, "Tiles.png", 224, 0, 48, 76), ("fbust", FORGE, "Tiles.png", 192, 146, 32, 60), ("fbroken", FORGE, "Tiles.png", 224, 160, 32, 48),
    ("flava", FORGE, "Tiles.png", 304, 208, 48, 48), ("fbanner", FORGE, "Tiles.png", 280, 6, 32, 62),
    ("fbarrel_0", FORGE, "Tiles.png", 112, 250, 16, 22), ("fbarrel_1", FORGE, "Tiles.png", 128, 250, 16, 22), ("fbarrel_2", FORGE, "Tiles.png", 112, 282, 16, 22),
    ("fcrate_0", FORGE, "Tiles.png", 160, 248, 16, 24), ("fcrate_1", FORGE, "Tiles.png", 176, 248, 32, 24), ("fchest", FORGE, "Tiles.png", 240, 88, 32, 24),
    # world dressing (v0.24.0) from the Garden pack: a clipped hedge and the hedge arch (the pergola reads
    # wrong as an upright card, so it is not cut)
    ("ghedge", GARDEN, "Tiles.png", 16, 320, 64, 32),
    # SET DRESSING: what a market street and a desert town leave about (Free Pack farm and furniture,
    # Castle crates and table, Hideout sack and boards, Dungeon pennants)
    ("ssack_0", FREE, "Props/Static/Farm.png", 256, 0, 16, 16), ("ssack_1", FREE, "Props/Static/Farm.png", 272, 0, 16, 16),
    ("ssack_2", FREE, "Props/Static/Farm.png", 256, 16, 16, 16), ("ssack_3", FREE, "Props/Static/Farm.png", 272, 16, 16, 16),
    ("scrate_0", FREE, "Props/Static/Farm.png", 288, 8, 16, 24), ("scrate_1", FREE, "Props/Static/Farm.png", 304, 8, 16, 24),
    ("sveg_0", FREE, "Props/Static/Farm.png", 160, 0, 16, 32), ("sveg_1", FREE, "Props/Static/Farm.png", 160, 32, 16, 32),
    ("sveg_2", FREE, "Props/Static/Farm.png", 160, 64, 16, 32), ("sveg_3", FREE, "Props/Static/Farm.png", 160, 96, 16, 32),
    ("sveg_4", FREE, "Props/Static/Farm.png", 160, 128, 16, 32), ("sveg_5", FREE, "Props/Static/Farm.png", 160, 160, 16, 32),
    ("sveg_6", FREE, "Props/Static/Farm.png", 160, 192, 16, 32),
    ("strough", FREE, "Props/Static/Farm.png", 320, 16, 48, 16), ("sbox", FREE, "Props/Static/Farm.png", 352, 32, 16, 16),
    ("scrate_2", FREE, "Props/Static/Furniture.png", 720, 72, 16, 24), ("scrate_3", FREE, "Props/Static/Furniture.png", 736, 72, 16, 24),
    ("sbarrel_f", FREE, "Props/Static/Furniture.png", 752, 72, 16, 24), ("spot", FREE, "Props/Static/Furniture.png", 768, 72, 16, 24),
    ("sjug", FREE, "Props/Static/Furniture.png", 784, 72, 16, 24), ("sbucket", FREE, "Props/Static/Furniture.png", 768, 8, 16, 24),
    ("sposts", FREE, "Props/Static/Furniture.png", 176, 420, 64, 26), ("spost", FREE, "Props/Static/Furniture.png", 144, 420, 14, 26),
    ("scrate_4", CASTLE, "Tiles.png", 334, 4, 18, 30), ("scrate_5", CASTLE, "Tiles.png", 351, 0, 17, 34),
    ("stable", CASTLE, "Tiles.png", 366, 10, 52, 40),
    ("ssack_4", HIDE, "Tiles.png", 270, 104, 22, 26), ("snotice", HIDE, "Tiles.png", 350, 182, 36, 62), ("ssign", HIDE, "Tiles.png", 383, 182, 18, 62),
    ("sbanner_0", FREE, "Props/Static/Dungeon_Props.png", 64, 68, 16, 26), ("sbanner_1", FREE, "Props/Static/Dungeon_Props.png", 80, 68, 16, 26),
    ("sbanner_2", FREE, "Props/Static/Dungeon_Props.png", 96, 68, 16, 26),
    # a desert camp's bedrolls, a cushion, a ring of fire stones, a shelf of crates, a work table (Hideout)
    ("sbed_0", HIDE, "Tiles.png", 278, 57, 20, 34), ("sbed_1", HIDE, "Tiles.png", 310, 57, 20, 34), ("scush", HIDE, "Tiles.png", 293, 97, 22, 15),
    ("sring", HIDE, "Tiles.png", 276, 166, 38, 36), ("sshelf", HIDE, "Tiles.png", 290, 119, 44, 41), ("sbench", HIDE, "Tiles.png", 356, 133, 40, 40),
    # the round bushes' three smaller sizes stand touching in the sheet: cut row by row
    ("vbushs_0", FREE, "Props/Static/Vegetation.png", 0, 0, 48, 32), ("vbushs_1", FREE, "Props/Static/Vegetation.png", 48, 0, 48, 32),
    ("vbushs_2", FREE, "Props/Static/Vegetation.png", 96, 0, 48, 32), ("vbushs_3", FREE, "Props/Static/Vegetation.png", 144, 0, 48, 32),
    ("vbushm_0", FREE, "Props/Static/Vegetation.png", 0, 33, 48, 31), ("vbushm_1", FREE, "Props/Static/Vegetation.png", 48, 33, 48, 31),
    ("vbushm_2", FREE, "Props/Static/Vegetation.png", 96, 33, 48, 31), ("vbushm_3", FREE, "Props/Static/Vegetation.png", 144, 33, 48, 31),
    ("vbushl_0", FREE, "Props/Static/Vegetation.png", 0, 65, 48, 31), ("vbushl_1", FREE, "Props/Static/Vegetation.png", 48, 65, 48, 31),
    ("vbushl_2", FREE, "Props/Static/Vegetation.png", 96, 65, 48, 31), ("vbushl_3", FREE, "Props/Static/Vegetation.png", 144, 65, 48, 31),
    # ROUND TWO: a camp fire's ring of stones with its logs laid in, a log to sit on, a sawn round, a
    # short log (the Free Pack's bonfire sheet); a painted shield for a shop's hanging sign (Castle)
    ("sfirering", FREE, "Structures/Stations/Bonfire/Bonfire.png", 0, 62, 32, 36),
    ("slog", FREE, "Structures/Stations/Bonfire/Bonfire.png", 0, 118, 32, 20),
    ("sround", FREE, "Structures/Stations/Bonfire/Bonfire.png", 0, 164, 32, 26),
    ("slog_s", FREE, "Structures/Stations/Bonfire/Bonfire.png", 0, 264, 32, 16),
    ("cshield", CASTLE, "Tiles.png", 336, 190, 16, 18),
]


def sheet(pack, ending):
    key = (pack[0], ending)
    if key not in _cache:
        z = zipfile.ZipFile(os.path.join(ZIPS, pack[0]))
        names = [n for n in z.namelist() if n.endswith(pack[1] + ending) and "__MACOSX" not in n]
        assert len(names) == 1, (pack, ending, names)
        _cache[key] = (Image.open(io.BytesIO(z.read(names[0]))).convert("RGBA"), names[0])
    return _cache[key]


def islands(im, region, gap, smallest):
    x0, y0, x1, y1 = region
    x1, y1 = min(x1, im.width), min(y1, im.height)
    a = im.getchannel("A").load()
    seen, boxes = set(), []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if a[x, y] < 16 or (x, y) in seen:
                continue
            stack, n = [(x, y)], 0
            seen.add((x, y))
            bx0, by0, bx1, by1 = x, y, x, y
            while stack:
                cx, cy = stack.pop()
                n += 1
                bx0, by0, bx1, by1 = min(bx0, cx), min(by0, cy), max(bx1, cx), max(by1, cy)
                for dx in range(-1 - gap, 2 + gap):
                    for dy in range(-1 - gap, 2 + gap):
                        p = (cx + dx, cy + dy)
                        if x0 <= p[0] < x1 and y0 <= p[1] < y1 and p not in seen and a[p[0], p[1]] >= 16:
                            seen.add(p)
                            stack.append(p)
            if n >= smallest:
                boxes.append((bx0, by0, bx1 + 1, by1 + 1))
    boxes.sort(key=lambda b: (round(b[1] / 24.0), b[0]))
    return boxes


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("hub_") and f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    pieces = {}

    def save(name, im, src, box):
        im.save(os.path.join(OUT, "hub_%s.png" % name))
        pieces["hub_" + name] = {"size": list(im.size), "source": src, "box": list(box)}

    for name, pack, ending, region, gap, smallest in ISLANDS:
        im, src = sheet(pack, ending)
        for i, b in enumerate(islands(im, region, gap, smallest)):
            save("%s_%d" % (name, i), im.crop(b), src, b)
    for name, pack, ending, x, y, w, h in RECTS:
        im, src = sheet(pack, ending)
        piece = im.crop((x, y, x + w, y + h))
        if name.startswith("patch"):
            # keep only the bare earth: the grass the pack painted round it is cut away (pixels are
            # removed, never changed), so the patch lies on the camp's own grass without a square edge
            px = piece.load()
            for yy in range(h):
                for xx in range(w):
                    r, g, b, a = px[xx, yy]
                    if g > r + 12:
                        px[xx, yy] = (r, g, b, 0)
        save(name, piece, src, (x, y, x + w, y + h))
    for name, pack, ending, x, y, w, h, hole in OPENED:
        # the hedge arch: the pack fills its opening with loose leaves; those pixels are removed (none
        # changed), so the knight can be seen walking through it
        im, src = sheet(pack, ending)
        piece = im.crop((x, y, x + w, y + h))
        px = piece.load()
        for yy in range(hole[1], hole[3]):
            for xx in range(hole[0], hole[2]):
                px[xx, yy] = (0, 0, 0, 0)
        box = piece.getbbox()
        save(name, piece.crop(box), src, (x + box[0], y + box[1], x + box[2], y + box[3]))
    for name, pack, ending, x, y, w, h in TRIMMED:
        im, src = sheet(pack, ending)
        piece = im.crop((x, y, x + w, y + h))
        box = piece.getbbox()
        save(name, piece.crop(box), src, (x + box[0], y + box[1], x + box[2], y + box[3]))
    for name, pack, ending, x, y, w, h in HALVED:
        im, src = sheet(pack, ending)
        small = im.resize((im.width // 2, im.height // 2), Image.NEAREST)
        save(name, small.crop((x, y, x + w, y + h)), src, (x, y, x + w, y + h))
    for name, pack, ending, fw, fh in STRIPS:
        im, src = sheet(pack, ending)
        for i in range(im.width // fw):
            save("%s_f%d" % (name, i), im.crop((i * fw, 0, i * fw + fw, fh)), src, (i * fw, 0, i * fw + fw, fh))
    # the training dummy: the scarecrow again, under a name the game reads as a one-frame animation
    Image.open(os.path.join(OUT, "hub_farm_2.png")).save(os.path.join(OUT, "hub_dummy_idle_anim_f0.png"))
    with open(os.path.join(OUT, "hub_pieces.json"), "w") as f:
        json.dump(pieces, f, indent=1, sort_keys=True)
    print("%d pieces written to %s" % (len(pieces), OUT))
    if "--sheet" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out_dir, exist_ok=True)
        names = sorted(pieces)
        s, x, y, row_h, W = 2, 4, 4, 0, 2400
        canvas = Image.new("RGB", (W, 4000), (52, 60, 72))
        d = ImageDraw.Draw(canvas)
        for n in names:
            im = Image.open(os.path.join(OUT, n + ".png"))
            w, h = im.width * s, im.height * s
            cell = max(w, 7 * len(n) - 20) + 8
            if x + cell > W:
                x, y, row_h = 4, y + row_h + 16, 0
            big = im.resize((w, h), Image.NEAREST)
            canvas.paste(big, (x, y), big)
            d.text((x, y + h + 2), n[4:], fill=(240, 240, 140))
            x += cell
            row_h = max(row_h, h)
        canvas.crop((0, 0, W, y + row_h + 20)).save(os.path.join(out_dir, "hub_sheet.png"))


if __name__ == "__main__":
    main()
