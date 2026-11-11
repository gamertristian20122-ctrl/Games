#!/usr/bin/env python3
"""Cut the room tile sets out of the purchased "Pixel Crawler" packs (art by Anokolisa).

    python3 -I tools/pc_import_tiles.py [--sheet DIR] [theme ...]

Reads   assets_raw/paid_pixel_crawler/x/<pack>/...        (unzips zips/ there if x/ is missing)
Writes  assets/art/pc_tiles/<theme>/<piece>.png           (one PNG per piece)
        assets/art/pc_tiles/tilesets.json                 (how a room is built from them)
--sheet DIR also writes a labelled x4 contact sheet per theme, to LOOK at.

It only cuts, crops, pads, mirrors and swaps listed palette colours. It never draws a pixel.
Safe to run again: it rewrites every file it owns and removes pieces that no longer exist.

A piece is described by one of:
    cut(src, x, y, w, h)                      a rectangle of a sheet
    pad((W, H), (src, x, y, w, h, dx, dy)..)  rectangles pasted on an empty WxH canvas
    flip(name)                                mirror of another piece (left <-> right)
    swap(name, {"rrggbb": "rrggbb"})          another piece with palette colours replaced
All coordinates were measured from the sheets (see the preview tool to check them).
"""
import json
import os
import sys
import zipfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "assets_raw", "paid_pixel_crawler")
OUT = os.path.join(ROOT, "assets", "art", "pc_tiles")

SRC = {
    "cem_walls": "Pixel_Crawler_-_Cemetery_0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png",
    "cem_props": "Pixel_Crawler_-_Cemetery_0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png",
    "cem_graves": "Pixel_Crawler_-_Cemetery_0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png",
    "free_dungeon": "Pixel_Crawler_-_Free_Pack_Exterior_0.1/Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png",
    "free_dprops": "Pixel_Crawler_-_Free_Pack_Exterior_0.1/Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png",
    "free_fire": "Pixel_Crawler_-_Free_Pack_Exterior_0.1/Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Fire_02-Sheet.png",
    "sewer": "Pixel_Crawler_-_Sewer/Pixel Crawler - Sewer/Assets/Tiles.png",
    "sewer_props": "Pixel_Crawler_-_Sewer/Pixel Crawler - Sewer/Assets/Props.png",
    "sewer_water": "Pixel_Crawler_-_Sewer/Pixel Crawler - Sewer/Assets/Water.png",
    "forge": "Pixel_Crawler_-_Forge_1.2/Pixel Crawler - Forge/Assets/Tiles.png",
    "free_rocks": "Pixel_Crawler_-_Free_Pack_Exterior_0.1/Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png",
    "castle": "Pixel_Crawler_-_Castle_Environment_0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png",
}

# The room every theme has to fill (fixed by the game). All numbers are game pixels.
ROOM = {
    "tile": 16, "cols": 17, "rows": 7, "side_w": 16, "bottom_h": 16, "door_col": 8, "door_row": 3,
    "how_to_read": [
        "Room origin (0,0) is the top-left corner of the wall frame. The floor starts at (side_w, back_wall_h).",
        "walls.back_rows: each row is drawn across the 17 floor columns from x=side_w; column i uses repeat[i % len].",
        "walls.left / right repeat down from y=16 to the bottom strip; corners sit at the four ends.",
        "walls.bottom is the 16 px strip under the floor; draw it IN FRONT of characters.",
        "doors.<dir>.<state> is a list of draw ops {piece, dx, dy, front}. dx/dy are relative to the door cell:",
        "  n: (side_w + 8*16, 0)   s: (side_w + 8*16, back_wall_h + 112)   w: (0, back_wall_h + 48)   e: (side_w + 272, back_wall_h + 48)",
        "  Each state is {gap, ops}. 'gap' lists the wall-strip cells (relative to the door cell, in tiles) that the ops replace:",
        "  do not draw the bottom / side strip there. Back-wall doors are drawn over the wall, so their gap is empty.",
        "  An op with 'code' instead of 'piece' is something the game must draw itself (only the boss mark is left).",
        "obstacles.<kind>.variants: draw at cell top-left + (dx, dy); 'up' is how many px overlap the tile above.",
        "  flat = lies on the floor (draw under characters); otherwise y-sort with characters by the cell's bottom edge.",
        "wall_deco: x = side_w + column*16 + dx, y from the room top; never use the columns in 'keep_clear'.",
        "  A back row may name 'first' / 'last': pieces for the two end columns instead of the repeat.",
        "  Door ops are drawn in list order; ops with front=true are drawn after the characters (they hide feet).",
        "  boss_open = the boss door after the fight. cracked (s/w/e) replaces only the door cell itself.",
        "  An animated thing lists 'frames' (+ 'fps'); a torch has 'variants' (the stand) plus 'flame' frames drawn on top.",
        "  obstacles.pit.autotile9 names nine tiles x four frames to use instead when pit cells touch (sludge, lava).",
        "lights: colour + radius for a Light2D / additive glow; (lx, ly) is relative to the piece's cell (obstacles) or draw position (wall_deco).",
        "void_color fills the screen outside the floor; pieces are transparent where the wall mass shows it.",
    ],
}


def cut(src, x, y, w, h):
    return ("pad", (w, h), [(src, x, y, w, h, 0, 0)])


def pad(size, *parts):
    return ("pad", size, list(parts))


def flip(name):
    return ("flip", name)


def swap(name, table):
    return ("swap", name, table)


def tile(src, c, r, w=1, h=1):
    return cut(src, c * 16, r * 16, w * 16, h * 16)


def op(piece, dx=0, dy=0, front=False):
    d = {"piece": piece, "dx": dx, "dy": dy}
    if front:
        d["front"] = True
    return d


def code(what, dx, dy, note):
    return {"code": what, "dx": dx, "dy": dy, "note": note}


# Palette swaps use colours that are already in the packs (Forge brick reds).
RED_FROM_GREEN = {"14140c": "291013", "242414": "411418", "32321b": "6a171d", "3f3f1f": "7b1a21"}
RED_FROM_WOOD = {"281818": "291013", "332520": "411418", "523d2a": "6a171d", "6e4b2c": "7b1a21"}


# ----------------------------------------------------------------------------------------------
# Shared pieces (Free Pack dungeon sheet): floor traps and the barrier used in side/bottom doors.
# ----------------------------------------------------------------------------------------------
def shared_pieces():
    D = "free_dungeon"
    return {
        "spikes_f0": tile(D, 4, 10),                 # plate with four holes (spikes down)
        "spikes_f1": tile(D, 4, 9),                  # tips showing
        "spikes_f2": cut(D, 64, 112, 16, 32),        # spikes up (16x32, overlaps the tile above)
        "door_bars": cut(D, 144, 64, 16, 16),        # top of the narrow portcullis: bars for a 1-tile gap
        "door_hatch": tile(D, 8, 4),                 # small wooden door with hinges (side/bottom doors)
        "door_hatch_boss": swap("door_hatch", RED_FROM_WOOD),
        "door_lock": cut("sewer_props", 21, 10, 6, 12),   # copper keyhole plate (Sewer pack): the lock on every locked door
        # small flame, 4 frames (16x24, the flame stands on the bottom row): sits on a theme's torch stand
        "flame_f0": cut("free_fire", 8, 10, 16, 24), "flame_f1": cut("free_fire", 40, 10, 16, 24),
        "flame_f2": cut("free_fire", 72, 10, 16, 24), "flame_f3": cut("free_fire", 104, 10, 16, 24),
    }


FLAME = ["flame_f0", "flame_f1", "flame_f2", "flame_f3"]


def torch(stand, w, h, color="#ff9a4a"):
    """Standing torch for the layout letter T: a stand from the theme with the shared flame on top."""
    return {"what": "standing torch", "variants": [v(stand, w, h)],
            "flame": {"frames": FLAME, "fps": 8, "dx": 0, "dy": 16 - h - 22},
            "light": {"lx": 8, "ly": 16 - h - 8, "color": color, "radius": 56}}


# ----------------------------------------------------------------------------------------------
# 1. CRYPT: Cemetery mausoleum walls (olive stone), Cemetery doors, tombs and statues,
#    on the Free Pack's dark teal flagstones (the Cemetery pack has no indoor floor, pit or spikes).
# ----------------------------------------------------------------------------------------------
def crypt():
    W, P, G, D, DP, C = "cem_walls", "cem_props", "cem_graves", "free_dungeon", "free_dprops", "castle"
    p = shared_pieces()
    p.update({
        # --- walls: the coping (wall top) is a 6 px stone line; the face repeats every 32 px
        "wall_top_a": cut(W, 28, 0, 16, 16), "wall_top_b": cut(W, 44, 0, 16, 16),
        "wall_face_a": cut(W, 28, 48, 16, 32), "wall_face_b": cut(W, 44, 48, 16, 32),
        "corner_tl": pad((16, 16), (W, 16, 0, 6, 16, 10, 0)), "corner_tr": flip("corner_tl"),
        "wall_side_left": pad((16, 16), (W, 0, 96, 6, 16, 10, 0)), "wall_side_right": flip("wall_side_left"),
        "wall_bottom_a": pad((16, 16), (W, 28, 134, 16, 10, 0, 0)), "wall_bottom_b": pad((16, 16), (W, 44, 134, 16, 10, 0, 0)),
        "corner_bl": pad((16, 16), (W, 0, 118, 6, 10, 10, 0)), "corner_br": flip("corner_bl"),
        # --- door jambs: coping ends that turn the corner at a gap in the bottom / side walls
        "door_s_jamb_left": pad((16, 16), (W, 64, 6, 16, 10, 0, 0), (W, 74, 16, 6, 6, 10, 10)),
        "door_s_jamb_right": flip("door_s_jamb_left"),
        "door_w_jamb_top": cut(W, 80, 112, 16, 16),
        "door_w_jamb_bottom": pad((16, 16), (W, 80, 22, 16, 10, 0, 0), (W, 90, 32, 6, 6, 10, 10)),
        "door_e_jamb_top": flip("door_w_jamb_top"), "door_e_jamb_bottom": flip("door_w_jamb_bottom"),
        # --- back-wall door (32x48 stone doorway, black inside) and what goes in it
        "door_n_frame": cut(P, 0, 80, 32, 48),
        "door_n_leaf": cut(P, 37, 84, 22, 44),
        "door_n_leaf_boss": swap("door_n_leaf", RED_FROM_GREEN),
        "door_n_cracked": cut(P, 4, 131, 24, 38),     # bricked-up arch: a found hidden door
        # --- floor (Free Pack flagstones)
        "floor_a": tile(D, 5, 1), "floor_b": tile(D, 7, 0), "floor_c": tile(D, 9, 0), "floor_d": tile(D, 7, 2),
        "floor_e": tile(D, 9, 2), "floor_f": tile(D, 8, 0), "floor_g": tile(D, 8, 2), "floor_h": tile(D, 5, 2),
        "floor_shade_top": tile(D, 5, 0), "floor_shade_left": tile(D, 4, 1), "floor_shade_corner": tile(D, 4, 0),
        # --- obstacles
        "prop_tomb_a": cut(G, 0, 37, 16, 27), "prop_tomb_b": cut(G, 16, 33, 16, 31), "prop_tomb_c": cut(G, 32, 38, 16, 26),
        "prop_statue": cut(G, 8, 200, 16, 34),
        "prop_urn_a": cut(C, 304, 219, 16, 21), "prop_urn_b": cut(C, 321, 216, 14, 24),
        "prop_pit": tile(D, 8, 1),
        # --- decoration
        "deco_sconce_f0": cut(C, 336, 160, 16, 32), "deco_sconce_f1": cut(C, 352, 160, 16, 32),
        "deco_sconce_f2": cut(C, 368, 160, 16, 32), "deco_sconce_f3": cut(C, 384, 160, 16, 32),
        "deco_shackle_a": cut(DP, 19, 42, 10, 22), "deco_shackle_b": cut(DP, 35, 44, 10, 20), "deco_shackle_c": cut(DP, 83, 41, 10, 14),
        "deco_cross": cut(G, 49, 13, 14, 19),
        "deco_grate": cut(DP, 97, 1, 14, 21),
        "deco_banner_red": cut(DP, 67, 70, 10, 21),
        "deco_coffin": cut(P, 118, 7, 20, 35), "deco_coffin_open": cut(P, 150, 7, 20, 35),
        "deco_reaper": cut(G, 65, 192, 30, 43), "deco_gargoyle": cut(G, 32, 201, 32, 33),
        "floor_blood_a": tile(D, 9, 11), "floor_blood_b": tile(D, 10, 11), "floor_drain": tile(D, 8, 3),
        "floor_stone_a": cut(P, 148, 84, 10, 8), "floor_stone_b": cut(P, 116, 99, 10, 9), "floor_stone_c": cut(P, 166, 102, 6, 5),
        "prop_torch_stand": cut(P, 64, 14, 16, 25),   # stone block with a short pole (the pole is cropped)
    })
    frame, leaf = op("door_n_frame", -8, 0), op("door_n_leaf", -3, 4)
    banners = [op("deco_banner_red", -22, 20), op("deco_banner_red", 28, 20)]
    s_open = [op("floor_a", 0, 0), op("door_s_jamb_left", -16, 0, True), op("door_s_jamb_right", 16, 0, True)]
    w_open = [op("floor_a", 0, 0), op("door_w_jamb_top", 0, -16), op("door_w_jamb_bottom", 0, 16)]
    e_open = [op("floor_a", 0, 0), op("door_e_jamb_top", 0, -16), op("door_e_jamb_bottom", 0, 16)]

    doors = door_table(
        n={"open": [frame], "shut": [frame, leaf],
           "locked": [frame, leaf, op("door_lock", 5, 24)],
           "hidden": [], "cracked": [op("door_n_cracked", -4, 10)],
           "boss": [frame, op("door_n_leaf_boss", -3, 4)] + banners + [code("boss_mark", 8, 1, "skull over the lintel (old art)")],
           "boss_open": [frame] + banners},
        s_open=s_open, w_open=w_open, e_open=e_open, floor="floor_a",
        rubble=[op("floor_stone_a", 1, 7), op("floor_stone_b", 6, 1)])
    data = {
        "name": "crypt", "floor": 1,
        "source": "Cemetery pack (walls, doors, tombs, statues) on Free Pack dungeon flagstones; sconces and urns from Castle",
        "back_wall_h": 48, "void_color": "#000000",
        "walls": {
            "back_rows": [{"y": 0, "repeat": ["wall_top_a", "wall_top_b"]}, {"y": 16, "repeat": ["wall_face_a", "wall_face_b"]}],
            "corner_tl": "corner_tl", "corner_tr": "corner_tr", "corner_bl": "corner_bl", "corner_br": "corner_br",
            "left": ["wall_side_left"], "right": ["wall_side_right"], "bottom": ["wall_bottom_a", "wall_bottom_b"],
        },
        "floor": {
            "variants": [["floor_a", 40], ["floor_b", 10], ["floor_c", 10], ["floor_d", 10], ["floor_e", 10], ["floor_f", 7], ["floor_g", 7], ["floor_h", 6]],
            "shade_top": "floor_shade_top", "shade_left": "floor_shade_left", "shade_corner": "floor_shade_corner",
        },
        "doors": doors,
        "obstacles": {
            "rock": {"what": "tombstone", "variants": [v("prop_tomb_a", 16, 27), v("prop_tomb_b", 16, 31), v("prop_tomb_c", 16, 26)]},
            "pillar": {"what": "stone statue", "variants": [v("prop_statue", 16, 34)]},
            "crate": {"what": "burial urn", "variants": [v("prop_urn_a", 16, 21), v("prop_urn_b", 14, 24)]},
            "pit": {"what": "dark shaft in the flagstones", "flat": True, "variants": [v("prop_pit", 16, 16)]},
            "spikes": {"what": "spike plate", "flat": True, "animated": True,
                       "frames": [v("spikes_f0", 16, 16), v("spikes_f1", 16, 16), v("spikes_f2", 16, 32)],
                       "note": "f0 down (safe), f1 warning, f2 up; f2 is 32 px tall and overlaps the tile above"},
            "torch": torch("prop_torch_stand", 16, 25),
        },
        "wall_deco": {
            "keep_clear": [7, 8, 9],
            "pieces": [
                {"piece": "deco_sconce", "frames": 4, "fps": 8, "dx": 0, "y": 12, "weight": 0, "columns": [2, 5, 11, 14],
                 "light": {"lx": 8, "ly": 12, "color": "#ffb060", "radius": 64}},
                {"piece": "deco_shackle_a", "dx": 3, "y": 20, "weight": 3}, {"piece": "deco_shackle_b", "dx": 3, "y": 20, "weight": 3},
                {"piece": "deco_shackle_c", "dx": 3, "y": 20, "weight": 2}, {"piece": "deco_cross", "dx": 1, "y": 20, "weight": 3},
                {"piece": "deco_grate", "dx": 1, "y": 27, "weight": 2},
            ],
            "set_pieces": [
                {"piece": "deco_coffin", "note": "32x35 lying on the floor against the back wall in peaceful rooms; blocks nothing by itself"},
                {"piece": "deco_coffin_open"}, {"piece": "deco_reaper", "note": "30x43 statue for boss or treasure rooms"},
                {"piece": "deco_gargoyle"},
            ],
        },
        "floor_deco": [
            {"piece": "floor_blood_a", "tile": True, "weight": 2}, {"piece": "floor_blood_b", "tile": True, "weight": 2},
            {"piece": "floor_drain", "tile": True, "weight": 1}, {"piece": "floor_stone_a", "weight": 3},
            {"piece": "floor_stone_b", "weight": 3}, {"piece": "floor_stone_c", "weight": 3},
        ],
        "ambient": "#b9c4c9", "light_color": "#ffb060",
        "gaps": [
            "No boss emblem in the pack: the 'code' ops mark where the game draws it. The lock is the Sewer pack's keyhole plate.",
            "Side and bottom doors use the Free Pack portcullis top (bars) and small hatch; the pack has no side-view door.",
            "No ragged hole for a blown-open secret door: 'cracked' shows the gap with rubble stones (back wall: a bricked-up arch).",
            "Boss door = the green leaf palette-swapped to the Forge brick reds, with two red banners.",
        ],
    }
    return p, data


# ----------------------------------------------------------------------------------------------
# The Sewer, Forge and Castle sheets share one wall system: a 6x6-tile "plus" of trim around a dark
# wall mass. Its straight edges are our wall strips, its inside corners are the room's corners and
# its outside corners are the jambs of a gap (a side or bottom door).  t = the plus's top-left tile.
# ----------------------------------------------------------------------------------------------
def plus_walls(S, tx=0, ty=0):
    def t(c, r):
        return tile(S, tx + c, ty + r)
    return {
        "wall_top_a": t(2, 5), "wall_top_b": t(3, 5),                    # bottom edge of the mass = top of our back wall
        "wall_bottom_a": t(2, 0), "wall_bottom_b": t(3, 0),              # top edge of the mass = our bottom wall
        "wall_side_left": t(5, 2), "wall_side_right": t(0, 2),
        "corner_tl": t(4, 4), "corner_tr": t(1, 4), "corner_bl": t(4, 1), "corner_br": t(1, 1),
        "door_s_jamb_left": t(4, 0), "door_s_jamb_right": t(1, 0),
        "door_w_jamb_top": t(5, 4), "door_w_jamb_bottom": t(5, 1),
        "door_e_jamb_top": t(0, 4), "door_e_jamb_bottom": t(0, 1),
    }


def plus_wall_data(face_rows):
    return {
        "back_rows": [{"y": 0, "repeat": ["wall_top_a", "wall_top_b"]}] + face_rows,
        "corner_tl": "corner_tl", "corner_tr": "corner_tr", "corner_bl": "corner_bl", "corner_br": "corner_br",
        "left": ["wall_side_left"], "right": ["wall_side_right"], "bottom": ["wall_bottom_a", "wall_bottom_b"],
    }


def swe_open(floor):
    return {
        "s_open": [op(floor, 0, 0), op("door_s_jamb_left", -16, 0, True), op("door_s_jamb_right", 16, 0, True)],
        "w_open": [op(floor, 0, 0), op("door_w_jamb_top", 0, -16), op("door_w_jamb_bottom", 0, 16)],
        "e_open": [op(floor, 0, 0), op("door_e_jamb_top", 0, -16), op("door_e_jamb_bottom", 0, 16)],
    }


# ----------------------------------------------------------------------------------------------
# 2. WARRENS: the Sewer pack. Chosen over Cave and Hideout because it is the only one of the three
#    with straight indoor walls, its own spikes, bars, crates and a pit (sludge), and a calm dark
#    brick floor. The Cave is organic (no straight walls or doors); the Hideout is wood and looks like a house.
# ----------------------------------------------------------------------------------------------
def warrens():
    S, P, WA = "sewer", "sewer_props", "sewer_water"
    p = shared_pieces()
    p.update(plus_walls(S))
    p.update({
        # --- mossy wall face, the 32 px tall version (rows 10-11 of the sheet)
        "wall_face_a": tile(S, 6, 10, 1, 2), "wall_face_b": tile(S, 8, 10, 1, 2), "wall_face_c": tile(S, 7, 10, 1, 2),
        "wall_face_left": tile(S, 0, 10, 1, 2), "wall_face_right": tile(S, 5, 10, 1, 2),
        # --- back-wall door: a dark tunnel mouth (64x39, sits 9 px below the room top)
        "door_n_frame": cut(S, 192, 201, 64, 39),
        "door_n_bars": pad((24, 32), *[(P, 0, 208, 8, 16, x, y) for x in (0, 8, 16) for y in (0, 16)]),
        "door_n_boss": cut(S, 199, 240, 50, 32),      # big barred drain ring
        "door_n_cracked": cut(S, 200, 273, 32, 15),   # low drain arch at the foot of the wall
        "door_bars": cut(P, 0, 208, 16, 16),          # two copper bars (overrides the shared steel bars)
        # --- floor: dark brick
        "floor_a": tile(S, 10, 7), "floor_b": tile(S, 10, 8), "floor_c": tile(S, 10, 9), "floor_d": tile(S, 9, 9),
        "floor_e": tile(S, 11, 9), "floor_f": tile(S, 9, 11), "floor_g": tile(S, 11, 11), "floor_h": tile(S, 9, 7),
        "floor_shade_top": tile(S, 10, 13),
        # --- obstacles
        "prop_block_a": cut(S, 208, 26, 16, 22), "prop_block_b": cut(S, 224, 26, 16, 22),
        "prop_pillar_a": cut(S, 224, 84, 16, 36), "prop_pillar_b": cut(S, 208, 64, 16, 56),
        "prop_crate": cut(P, 32, 7, 16, 25), "prop_barrel": cut(P, 48, 8, 16, 24),
        "prop_pit_dark": tile(S, 10, 10),
        "spikes_f0": cut(P, 64, 224, 16, 16),
        "spikes_f1": pad((16, 20), (P, 64, 224, 16, 16, 0, 4), (P, 48, 144, 16, 6, 0, 2), (P, 48, 144, 16, 6, 0, 10)),
        "spikes_f2": pad((16, 28), (P, 64, 224, 16, 16, 0, 12), (P, 48, 144, 16, 16, 0, 0), (P, 48, 144, 16, 16, 0, 8)),
        "prop_torch_stand": cut(S, 224, 26, 16, 22),
        # --- decoration
        "deco_lamp": cut(P, 100, 5, 9, 20), "deco_lamp_off": cut(P, 116, 5, 9, 20),
        "deco_porthole": cut(P, 112, 39, 16, 18), "deco_keyhook": cut(P, 5, 10, 6, 15),
        "deco_chain": cut(P, 163, 0, 10, 30), "deco_pipe": cut(S, 260, 8, 8, 40),
        "floor_bit_a": cut(P, 68, 149, 8, 4), "floor_bit_b": cut(P, 84, 147, 7, 9), "floor_bit_c": cut(P, 69, 197, 7, 5),
        "floor_bit_d": cut(P, 84, 196, 7, 9),
    })
    pool_pieces(p, WA, 0, 0)                         # sludge pool, 4 frames
    back = [op("floor_shade_top", -16, 32), op("floor_shade_top", 0, 32), op("floor_shade_top", 16, 32)]
    frame = back + [op("door_n_frame", -24, 9)]
    lamps = [op("deco_lamp", -26, 20), op("deco_lamp", 33, 20)]
    doors = door_table(
        n={"open": frame, "shut": frame + [op("door_n_bars", -4, 16)],
           "locked": frame + [op("door_n_bars", -4, 16), op("door_lock", 5, 24)],
           "hidden": [], "cracked": [op("door_n_cracked", -8, 33)],
           "boss": [op("door_n_boss", -17, 16)] + lamps + [code("boss_mark", 8, 12, "boss mark over the drain ring (old skull art)")],
           "boss_open": frame + lamps},
        floor="floor_a", rubble=[op("floor_bit_b", 1, 6), op("floor_bit_d", 8, 1)], **swe_open("floor_a"))
    data = {
        "name": "warrens", "floor": 2,
        "source": "Sewer pack (walls, brick floor, tunnel door, copper bars and spikes, sludge, crates); hatch and flame from the Free Pack",
        "why": "Sewer beats Cave and Hideout: straight indoor walls with corners, a calm dark brick floor, and its own spikes, bars, pit and crates.",
        "back_wall_h": 48, "void_color": "#0e1113",
        "walls": plus_wall_data([{"y": 16, "first": "wall_face_left", "last": "wall_face_right",
                                  "repeat": ["wall_face_a", "wall_face_b", "wall_face_a", "wall_face_c", "wall_face_b"]}]),
        "floor": {"variants": [["floor_a", 30], ["floor_b", 20], ["floor_c", 20], ["floor_d", 10], ["floor_e", 10], ["floor_f", 4], ["floor_g", 3], ["floor_h", 3]],
                  "shade_top": "floor_shade_top", "note": "the cracked tiles (f, g, h) are kept rare so the floor stays calm"},
        "doors": doors,
        "obstacles": {
            "rock": {"what": "stone block", "variants": [v("prop_block_a", 16, 22)]},
            "pillar": {"what": "broken stone pillar", "variants": [v("prop_pillar_a", 16, 36), v("prop_pillar_b", 16, 56)]},
            "crate": {"what": "crate or barrel", "variants": [v("prop_crate", 16, 25), v("prop_barrel", 16, 24)]},
            "pit": {"what": "sludge well", "flat": True, "animated": True, "fps": 4,
                    "frames": [v("prop_pit_f%d" % f, 16, 16) for f in range(4)],
                    "autotile9": PIT9,
                    "alt": "prop_pit_dark is a dark broken-floor tile if the green reads too loud under the Curse"},
            "spikes": {"what": "copper spikes", "flat": True, "animated": True,
                       "frames": [v("spikes_f0", 16, 16), v("spikes_f1", 16, 20), v("spikes_f2", 16, 28)],
                       "note": "f0 holes only (safe), f1 tips, f2 up; taller frames overlap the tile above"},
            "torch": torch("prop_torch_stand", 16, 22, "#ffb347"),
        },
        "wall_deco": {
            "keep_clear": [6, 7, 8, 9, 10],
            "pieces": [
                {"piece": "deco_lamp", "dx": 3, "y": 20, "weight": 0, "columns": [2, 5, 11, 14],
                 "light": {"lx": 4, "ly": 4, "color": "#ffd070", "radius": 60}},
                {"piece": "deco_porthole", "dx": 0, "y": 22, "weight": 3}, {"piece": "deco_pipe", "dx": 4, "y": 0, "weight": 3},
                {"piece": "deco_chain", "dx": 3, "y": 12, "weight": 2}, {"piece": "deco_keyhook", "dx": 5, "y": 20, "weight": 1},
                {"piece": "deco_lamp_off", "dx": 3, "y": 20, "weight": 1},
            ],
            "set_pieces": [],
        },
        "floor_deco": [
            {"piece": "floor_bit_a", "weight": 3}, {"piece": "floor_bit_b", "weight": 2}, {"piece": "floor_bit_c", "weight": 3},
            {"piece": "floor_bit_d", "weight": 2}, {"piece": "prop_pit_dark", "tile": True, "weight": 2},
        ],
        "ambient": "#c4c2b4", "light_color": "#ffd070",
        "gaps": [
            "Tunnel door is 64 px wide: keep back-wall decoration out of columns 6-10.",
            "Sludge is bright green; if it fights the Curse stripe use prop_pit_dark instead.",
            "Locked = copper bars + the pack's own keyhole plate (door_lock).",
            "Boss door = the big barred drain ring; a boss emblem must come from the old art or code.",
        ],
    }
    return p, data



def pool_pieces(p, src, x0, y0, frames=4):
    """A 3x3 animated pool (48x48 per frame, frames stacked downwards) becomes:
    prop_pit_f<n>: one small 16x16 pool made of the four corner quarters, for a single pit cell, and
    pit9_<tl|t|tr|l|c|r|bl|b|br>_f<n>: the nine tiles, so touching pit cells can merge into one pool."""
    for f in range(frames):
        y = y0 + f * 48
        p["prop_pit_f%d" % f] = pad((16, 16), (src, x0, y, 8, 8, 0, 0), (src, x0 + 40, y, 8, 8, 8, 0),
                                    (src, x0, y + 40, 8, 8, 0, 8), (src, x0 + 40, y + 40, 8, 8, 8, 8))
        for i, pos in enumerate(["tl", "t", "tr", "l", "c", "r", "bl", "b", "br"]):
            p["pit9_%s_f%d" % (pos, f)] = cut(src, x0 + (i % 3) * 16, y + (i // 3) * 16, 16, 16)


PIT9 = "pit9_<tl|t|tr|l|c|r|bl|b|br>_f<0-3>: use these instead when pits touch, so they merge into one pool"


# ----------------------------------------------------------------------------------------------
# 3. ASHEN: the Forge pack. Dark maroon mass, red brick with a glowing seam, lava, purple-black floor.
# ----------------------------------------------------------------------------------------------
def ashen():
    S, R = "forge", "free_rocks"
    p = shared_pieces()
    p.update({
        # --- walls. The Forge "plus" is 5 tiles wide and not on a 16 px grid vertically, so each piece is cut by pixel.
        #     The 48 px wall under it (trim, glowing seam, brick, stone base) repeats every 16 px.
        "wall_top_a": cut(S, 24, 64, 16, 16), "wall_mid_a": cut(S, 24, 80, 16, 16), "wall_base_a": cut(S, 24, 96, 16, 16),
        "wall_base_b": tile(S, 5, 5),                 # base with a small arched drain
        "wall_side_left": cut(S, 64, 24, 16, 16), "wall_side_right": cut(S, 0, 24, 16, 16),
        "wall_bottom_a": pad((16, 16), (S, 64, 16, 8, 16, 0, 0), (S, 64, 16, 8, 16, 8, 0)),
        "corner_tl": cut(S, 48, 48, 16, 16), "corner_tr": cut(S, 16, 48, 16, 16),
        "corner_bl": cut(S, 48, 16, 16, 16), "corner_br": cut(S, 16, 16, 16, 16),
        "door_s_jamb_left": cut(S, 64, 16, 16, 16), "door_s_jamb_right": cut(S, 0, 16, 16, 16),
        "door_w_jamb_top": cut(S, 64, 36, 16, 16), "door_w_jamb_bottom": cut(S, 64, 16, 16, 16),
        "door_e_jamb_top": cut(S, 0, 36, 16, 16), "door_e_jamb_bottom": cut(S, 0, 16, 16, 16),
        # --- back-wall door: the big arch shortened from 80 to 48 px (its top 32 rows + its bottom 16 rows)
        "door_n_frame": pad((48, 48), (S, 224, 0, 48, 32, 0, 0), (S, 224, 64, 48, 16, 0, 32)),
        "door_n_dark": pad((28, 40), (S, 24, 21, 28, 26, 0, 0), (S, 24, 21, 28, 14, 0, 26)),   # wall-mass colour behind the open arch
        "door_n_leaf": cut(S, 282, 8, 28, 40),        # chevron door, cropped to its two upper chevrons
        "door_n_cracked": cut(S, 97, 219, 14, 29),    # small sealed chevron niche
        "deco_ring": cut(S, 195, 33, 10, 13),
        "door_bars": cut("sewer_props", 0, 208, 16, 16),   # copper bars from the Sewer pack: warmer than the steel ones
        # --- floor: purple-black stone
        "floor_a": tile(S, 0, 7), "floor_b": tile(S, 0, 8), "floor_c": tile(S, 0, 9), "floor_d": tile(S, 4, 7),
        "floor_e": tile(S, 6, 7), "floor_f": tile(S, 4, 9), "floor_g": tile(S, 6, 9), "floor_h": tile(S, 2, 8),
        "floor_shade_top": tile(S, 0, 6),
        # --- obstacles
        "prop_rock_a": tile(R, 4, 7), "prop_rock_b": tile(R, 5, 7),
        "prop_pillar": cut(S, 112, 56, 16, 40),
        "prop_barrel_a": cut(S, 128, 250, 16, 22), "prop_barrel_b": cut(S, 144, 249, 16, 23), "prop_barrel_skull": cut(S, 112, 250, 16, 22),
        "prop_brazier": cut(S, 226, 212, 28, 28),     # broken statue base with lava in it: the standing light
        # --- decoration
        "deco_pilaster_lit": cut(S, 144, 0, 16, 48), "deco_pilaster": cut(S, 160, 0, 16, 48),
        "deco_niche": cut(S, 97, 219, 14, 29), "deco_vent": cut(S, 212, 243, 8, 13),
        "deco_statue": cut(S, 194, 150, 28, 58), "deco_statue_broken": cut(S, 226, 164, 28, 44),
        "floor_bit_a": cut(S, 67, 101, 10, 6), "floor_bit_b": cut(S, 83, 99, 9, 11), "floor_bit_c": cut(S, 100, 100, 7, 9),
        "floor_bit_d": cut(S, 116, 115, 10, 8), "item_key": cut(S, 98, 260, 12, 7),          # a key: not decoration, here for the pickup art
    })
    pool_pieces(p, S, 304, 208)                      # lava pool, 4 frames
    frame = op("door_n_frame", -16, 0)
    leaf = op("door_n_leaf", -6, 8)
    gems = [op("deco_pilaster_lit", -32, 0), op("deco_pilaster_lit", 32, 0)]
    doors = door_table(
        n={"open": [op("door_n_dark", -6, 8), frame], "shut": [leaf, frame],
           "locked": [leaf, frame, op("door_lock", 5, 26)],
           "hidden": [], "cracked": [op("door_n_cracked", 1, 19)],
           "boss": [leaf, frame] + gems + [code("boss_mark", 8, 3, "boss mark on the keystone (old skull art)")],
           "boss_open": [op("door_n_dark", -6, 8), frame] + gems},
        floor="floor_a", rubble=[op("floor_bit_b", 1, 4), op("floor_bit_c", 9, 1)], **swe_open("floor_a"))
    data = {
        "name": "ashen", "floor": 3,
        "source": "Forge pack (walls, arch door, floor, lava, barrels, statues); rocks, spikes, hatch from the Free Pack; copper bars from Sewer",
        "back_wall_h": 48, "void_color": "#291013",
        "walls": {
            "back_rows": [{"y": 0, "repeat": ["wall_top_a"]}, {"y": 16, "repeat": ["wall_mid_a"]},
                          {"y": 32, "repeat": ["wall_base_a", "wall_base_a", "wall_base_b", "wall_base_a"]}],
            "corner_tl": "corner_tl", "corner_tr": "corner_tr", "corner_bl": "corner_bl", "corner_br": "corner_br",
            "left": ["wall_side_left"], "right": ["wall_side_right"], "bottom": ["wall_bottom_a"],
        },
        "floor": {"variants": [["floor_a", 20], ["floor_b", 20], ["floor_c", 15], ["floor_d", 10], ["floor_e", 10], ["floor_f", 10], ["floor_g", 10], ["floor_h", 5]],
                  "shade_top": "floor_shade_top"},
        "doors": doors,
        "obstacles": {
            "rock": {"what": "dark rock", "variants": [v("prop_rock_a", 16, 16), v("prop_rock_b", 16, 16)]},
            "pillar": {"what": "brick pillar", "variants": [v("prop_pillar", 16, 40)]},
            "crate": {"what": "barrel", "variants": [v("prop_barrel_a", 16, 22), v("prop_barrel_b", 16, 23)],
                      "alt": "prop_barrel_skull for an explosive barrel"},
            "pit": {"what": "lava well", "flat": True, "animated": True, "fps": 4,
                    "frames": [v("prop_pit_f%d" % f, 16, 16) for f in range(4)], "autotile9": PIT9,
                    "light": {"lx": 8, "ly": 8, "color": "#ff6a20", "radius": 30}},
            "spikes": {"what": "spike plate (Free Pack steel, no Forge version)", "flat": True, "animated": True,
                       "frames": [v("spikes_f0", 16, 16), v("spikes_f1", 16, 16), v("spikes_f2", 16, 32)]},
            "torch": {"what": "lava bowl (glows by itself, no flame)", "variants": [v("prop_brazier", 28, 28)],
                      "light": {"lx": 8, "ly": 4, "color": "#ff7a30", "radius": 56}},
        },
        "wall_deco": {
            "keep_clear": [6, 7, 8, 9, 10],
            "pieces": [
                {"piece": "deco_niche", "dx": 1, "y": 9, "weight": 0, "columns": [2, 5, 11, 14],
                 "light": {"lx": 7, "ly": 14, "color": "#ff7a30", "radius": 52}},
                {"piece": "deco_pilaster", "dx": 0, "y": 0, "weight": 4}, {"piece": "deco_pilaster_lit", "dx": 0, "y": 0, "weight": 2},
                {"piece": "deco_vent", "dx": 4, "y": 35, "weight": 2}, {"piece": "deco_ring", "dx": 3, "y": 16, "weight": 1},
            ],
            "set_pieces": [{"piece": "deco_statue", "note": "28x58 bearded statue for boss or treasure rooms"}, {"piece": "deco_statue_broken"}],
        },
        "floor_deco": [
            {"piece": "floor_bit_a", "weight": 3}, {"piece": "floor_bit_b", "weight": 2}, {"piece": "floor_bit_c", "weight": 3},
            {"piece": "floor_bit_d", "weight": 3},
        ],
        "ambient": "#d0b8b0", "light_color": "#ff7a30",
        "gaps": [
            "The Forge pack has no spikes: the Free Pack steel spike plate is used (cool grey on a purple floor).",
            "Lava is very bright: keep lava pits few, away from the lanes the Curse stripe needs.",
            "The arch door is the pack's 80 px arch with 32 rows cut out of its pillars to fit a 48 px wall.",
            "Lock = the Sewer keyhole plate. Boss door = arch flanked by two lit gem pilasters + a mark from code. item_key is a 12x7 key sprite.",
        ],
    }
    return p, data


# ----------------------------------------------------------------------------------------------
# 4. PIT: the Castle pack (chosen over Library: cold stone, dark cornice, purple banners and stained
#    glass read as the ominous heart of the dungeon; the Library is warm wood and teal, a cosy place).
# ----------------------------------------------------------------------------------------------
def pit():
    K, R = "castle", "free_rocks"
    p = shared_pieces()
    p.update({
        # --- walls: same layout as the Forge plus. The artist's wall is 63 px tall (trim, dark cornice, five block
        #     courses, base); ours keeps trim + cornice, the first two courses and the last course + base = 48 px.
        "wall_top_a": cut(K, 24, 64, 16, 16), "wall_top_b": cut(K, 40, 64, 16, 16),
        "wall_mid_a": cut(K, 24, 80, 16, 16), "wall_mid_b": cut(K, 40, 80, 16, 16),
        "wall_base_a": cut(K, 24, 112, 16, 16), "wall_base_b": cut(K, 40, 112, 16, 16),
        "wall_side_left": cut(K, 64, 24, 16, 16), "wall_side_right": cut(K, 0, 24, 16, 16),
        "wall_bottom_a": pad((16, 16), (K, 64, 16, 8, 16, 0, 0), (K, 64, 16, 8, 16, 8, 0)),
        "corner_tl": cut(K, 48, 48, 16, 16), "corner_tr": cut(K, 16, 48, 16, 16),
        "corner_bl": cut(K, 48, 16, 16, 16), "corner_br": cut(K, 16, 16, 16, 16),
        "door_s_jamb_left": cut(K, 64, 16, 16, 16), "door_s_jamb_right": cut(K, 0, 16, 16, 16),
        "door_w_jamb_top": cut(K, 64, 36, 16, 16), "door_w_jamb_bottom": cut(K, 64, 16, 16, 16),
        "door_e_jamb_top": cut(K, 0, 36, 16, 16), "door_e_jamb_bottom": cut(K, 0, 16, 16, 16),
        # --- back-wall door: the stone-framed arch (24x42). Open = its arch top and its two jambs, cut apart,
        #     over a patch of the dark wall mass; the stone leaf below the arch is left out.
        "door_n_leaf": cut(K, 244, 6, 24, 42),
        "door_n_open": pad((24, 42), (K, 244, 6, 24, 12, 0, 0), (K, 244, 18, 6, 30, 0, 12), (K, 262, 18, 6, 30, 18, 12)),
        "door_n_dark": pad((12, 30), (K, 24, 24, 12, 16, 0, 0), (K, 24, 24, 12, 14, 0, 16)),
        "door_n_leaf_boss": swap("door_n_leaf", {"352533": "291013", "49403b": "6a171d"}),
        "door_n_cracked": cut(K, 194, 133, 12, 22),   # narrow dark slit window at the foot of the wall
        # --- floor: indigo diamonds, very low contrast
        "floor_a": tile(K, 13, 18),
        "floor_shade_top": tile(K, 12, 22),
        # --- obstacles
        "prop_bust_a": cut(K, 280, 75, 17, 32), "prop_bust_b": cut(K, 312, 74, 16, 33), "prop_bust_c": cut(K, 345, 124, 14, 31),
        "prop_column_a": cut(K, 192, 0, 16, 52), "prop_column_b": cut(K, 208, 0, 16, 52),
        "prop_crate_a": cut(K, 336, 7, 16, 25), "prop_crate_b": cut(K, 352, 1, 16, 31),
        # a one-tile shaft: the four outer corner quarters of the wall plus (stone rim around the dark wall mass)
        "prop_pit": pad((16, 16), (K, 16, 0, 8, 8, 0, 0), (K, 56, 0, 8, 8, 8, 0), (K, 16, 61, 8, 8, 0, 8), (K, 56, 61, 8, 8, 8, 8)),
        "prop_torch_stand": cut("cem_props", 64, 14, 16, 25),
        # --- decoration
        "deco_sconce_f0": cut(K, 336, 160, 16, 32), "deco_sconce_f1": cut(K, 352, 160, 16, 32),
        "deco_sconce_f2": cut(K, 368, 160, 16, 32), "deco_sconce_f3": cut(K, 384, 160, 16, 32),
        "deco_banner": cut(K, 320, 172, 16, 30), "deco_banner_triple": cut(K, 280, 172, 34, 46),
        "deco_window_lit": cut(K, 192, 96, 16, 32), "deco_window_dark": cut(K, 240, 96, 16, 32),
        "deco_slit": cut(K, 194, 160, 12, 16), "deco_shield": cut(K, 339, 193, 10, 14),
        "deco_niche": cut(K, 176, 0, 16, 52), "deco_lightbeam": cut(K, 372, 192, 8, 23),
        "floor_bit_a": cut(R, 180, 37, 8, 6), "floor_bit_b": cut(R, 165, 54, 7, 6), "floor_bit_c": cut(R, 181, 54, 8, 6),
    })
    opened = [op("door_n_dark", 2, 18), op("door_n_open", -4, 6)]
    flank = [op("deco_banner", -24, 12), op("deco_banner", 24, 12), op("deco_window_lit", -42, 12), op("deco_window_lit", 42, 12)]
    doors = door_table(
        n={"open": opened, "shut": [op("door_n_leaf", -4, 6)],
           "locked": [op("door_n_leaf", -4, 6), op("door_lock", 5, 26)],
           "hidden": [], "cracked": [op("door_n_cracked", 2, 22)],
           "boss": [op("door_n_leaf_boss", -4, 6)] + flank + [code("boss_mark", 8, 4, "boss mark over the arch (old skull art)")],
           "boss_open": opened + flank},
        floor="floor_a", rubble=[op("floor_bit_a", 1, 8), op("floor_bit_c", 7, 2)], **swe_open("floor_a"))
    data = {
        "name": "pit", "floor": 4,
        "source": "Castle pack (walls, stone door, floor, busts, columns, crates, banners, windows, sconces); rocks, spikes, bars, hatch from the Free Pack",
        "why": "Castle beats Library: cold stone under a dark cornice, purple banners and glowing stained glass look like the heart of the dungeon; the Library is warm and cosy.",
        "back_wall_h": 48, "void_color": "#1c172c",
        "walls": {
            "back_rows": [{"y": 0, "repeat": ["wall_top_a", "wall_top_b"]}, {"y": 16, "repeat": ["wall_mid_a", "wall_mid_b"]},
                          {"y": 32, "repeat": ["wall_base_a", "wall_base_b"]}],
            "corner_tl": "corner_tl", "corner_tr": "corner_tr", "corner_bl": "corner_bl", "corner_br": "corner_br",
            "left": ["wall_side_left"], "right": ["wall_side_right"], "bottom": ["wall_bottom_a"],
        },
        "floor": {"variants": [["floor_a", 100]], "shade_top": "floor_shade_top",
                  "note": "one tile only: the diamonds must stay a regular checker"},
        "doors": doors,
        "obstacles": {
            "rock": {"what": "stone bust (breaks)", "variants": [v("prop_bust_a", 17, 32), v("prop_bust_b", 16, 33), v("prop_bust_c", 14, 31)]},
            "pillar": {"what": "stone column", "variants": [v("prop_column_a", 16, 52), v("prop_column_b", 16, 52)]},
            "crate": {"what": "wooden crate", "variants": [v("prop_crate_a", 16, 25), v("prop_crate_b", 16, 31)]},
            "pit": {"what": "stone-rimmed shaft", "flat": True, "variants": [v("prop_pit", 16, 16)]},
            "spikes": {"what": "spike plate (Free Pack)", "flat": True, "animated": True,
                       "frames": [v("spikes_f0", 16, 16), v("spikes_f1", 16, 16), v("spikes_f2", 16, 32)]},
            "torch": torch("prop_torch_stand", 16, 25),
        },
        "wall_deco": {
            "keep_clear": [7, 8, 9],
            "pieces": [
                {"piece": "deco_sconce", "frames": 4, "fps": 8, "dx": 0, "y": 10, "weight": 0, "columns": [2, 5, 11, 14],
                 "light": {"lx": 8, "ly": 12, "color": "#ffb060", "radius": 64}},
                {"piece": "deco_banner", "dx": 0, "y": 12, "weight": 4}, {"piece": "deco_window_dark", "dx": 0, "y": 12, "weight": 3},
                {"piece": "deco_window_lit", "dx": 0, "y": 12, "weight": 2, "light": {"lx": 8, "ly": 16, "color": "#ff9a30", "radius": 44}},
                {"piece": "deco_slit", "dx": 2, "y": 20, "weight": 2}, {"piece": "deco_shield", "dx": 3, "y": 20, "weight": 2},
            ],
            "set_pieces": [{"piece": "deco_banner_triple", "note": "34x46, for the boss room wall"},
                           {"piece": "deco_niche", "note": "16x52 dark niche between two shafts: 4 px taller than the wall, let it rise above it"},
                           {"piece": "deco_lightbeam", "note": "8x23 shaft of light under a lit window (additive)"}],
        },
        "floor_deco": [{"piece": "floor_bit_a", "weight": 3}, {"piece": "floor_bit_b", "weight": 3}, {"piece": "floor_bit_c", "weight": 3}],
        "ambient": "#bdb8d6", "light_color": "#ffb060",
        "gaps": [
            "The Castle pack has no pit, spikes, bars or open door: the pit is built from the wall trim's four corner quarters,",
            "spikes/bars/hatch come from the Free Pack, and the open door is the stone door's arch top and jambs over a patch of the dark wall mass.",
            "Boss door = the leaf swapped to Forge reds, flanked by purple banners and lit stained glass + a mark from code.",
            "The pack's light paving and red carpet are too pale/loud for fight rooms; the indigo diamonds are used instead.",
        ],
    }
    return p, data


def door_table(n, s_open, w_open, e_open, floor, rubble, bars="door_bars", hatch="door_hatch", hatch_boss="door_hatch_boss"):
    """All door states for the four walls. Side and bottom doors share one recipe:
    open = floor in the gap between two jambs, shut = bars across it, locked = a wooden hatch with the keyhole plate,
    boss = the red hatch (+ boss mark by code), cracked = the bare gap with rubble, hidden = nothing (plain wall)."""
    mark = code("boss_mark", 8, 8, "boss mark (old skull art) centred on the red hatch")
    out = {"n": {state: {"gap": [], "ops": ops} for state, ops in n.items()}}
    for d, open_ops, gap in (("s", s_open, [[-1, 0], [0, 0], [1, 0]]), ("w", w_open, [[0, -1], [0, 0], [0, 1]]), ("e", e_open, [[0, -1], [0, 0], [0, 1]])):
        front = d == "s"
        out[d] = {
            "open": {"gap": gap, "ops": open_ops},
            "shut": {"gap": gap, "ops": open_ops + [op(bars, 0, 0, front)]},
            "locked": {"gap": gap, "ops": open_ops + [op(hatch, 0, 0, front), op("door_lock", 5, 2, front)]},
            "hidden": {"gap": [], "ops": []},
            "cracked": {"gap": [[0, 0]], "ops": [op(floor, 0, 0)] + [dict(r, front=True) if front else r for r in rubble]},
            "boss": {"gap": gap, "ops": open_ops + [op(hatch_boss, 0, 0, front), mark]},
            "boss_open": {"gap": gap, "ops": open_ops},
        }
    return out


def v(piece, w, h):
    """Obstacle variant: centred on its cell, standing on the cell's bottom edge."""
    return {"piece": piece, "dx": (16 - w) // 2, "dy": 16 - h, "up": max(0, h - 16)}




THEMES = [("crypt", crypt), ("warrens", warrens), ("ashen", ashen), ("pit", pit)]


# ----------------------------------------------------------------------------------------------
def load_sheets():
    x = os.path.join(PACK, "x")
    if not os.path.isdir(x):                       # first run on a fresh checkout: unpack the zips
        for z in sorted(os.listdir(os.path.join(PACK, "zips"))):
            if z.lower().endswith(".zip"):
                dest = os.path.join(x, os.path.splitext(z)[0].replace(" ", "_"))
                os.makedirs(dest, exist_ok=True)
                with zipfile.ZipFile(os.path.join(PACK, "zips", z)) as f:
                    f.extractall(dest)
    cache = {}

    def get(key):
        if key not in cache:
            cache[key] = Image.open(os.path.join(x, SRC[key])).convert("RGBA")
        return cache[key]
    return get


def build(spec, pieces, done, sheet):
    kind = spec[0]
    if kind == "pad":
        im = Image.new("RGBA", spec[1], (0, 0, 0, 0))
        for src, x, y, w, h, dx, dy in spec[2]:
            im.paste(sheet(src).crop((x, y, x + w, y + h)), (dx, dy))
        return im
    base = done.get(spec[1]) or build(pieces[spec[1]], pieces, done, sheet)
    if kind == "flip":
        return base.transpose(Image.FLIP_LEFT_RIGHT)
    table = {tuple(bytes.fromhex(k)): tuple(bytes.fromhex(val)) for k, val in spec[2].items()}
    im = base.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                px[x, y] = table[(r, g, b)] + (a,)
    return im


def contact_sheet(name, images, path, scale=4):
    """Every piece of a theme on #1a1a24, nearest-neighbour x4, with its name and size."""
    cell_w, x, y, row_h, pos = 150, 6, 6, 0, []
    for key in sorted(images):
        im = images[key]
        w = max(cell_w, im.width * scale + 8)
        if x + w > 1500:
            x, y, row_h = 6, y + row_h + 26, 0
        pos.append((key, x, y))
        x += w
        row_h = max(row_h, im.height * scale)
    out = Image.new("RGBA", (1500, y + row_h + 26), (26, 26, 36, 255))
    d = ImageDraw.Draw(out)
    for key, x, y in pos:
        im = images[key]
        out.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, y))
        d.text((x, y + im.height * scale + 2), "%s %dx%d" % (key, im.width, im.height), fill=(230, 230, 120, 255))
    out.convert("RGB").save(path)


def main():
    args = sys.argv[1:]
    sheet_dir = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet_dir = args[i + 1]
        del args[i:i + 2]
        os.makedirs(sheet_dir, exist_ok=True)
    sheet = load_sheets()
    json_path = os.path.join(OUT, "tilesets.json")
    result = {"about": "Room tile sets cut from the purchased Pixel Crawler packs by tools/pc_import_tiles.py. Do not edit by hand.",
              "room": ROOM, "themes": {}}
    if os.path.exists(json_path):                  # keep themes that are not being re-imported
        with open(json_path) as f:
            result["themes"] = json.load(f).get("themes", {})
    for name, fn in THEMES:
        if args and name not in args:
            continue
        pieces, data = fn()
        folder = os.path.join(OUT, name)
        os.makedirs(folder, exist_ok=True)
        done = {}
        for key, spec in pieces.items():
            done[key] = build(spec, pieces, done, sheet)
        for key, im in done.items():
            if im.getchannel("A").getbbox() is None:
                sys.exit("%s/%s is empty: wrong rectangle" % (name, key))
            im.save(os.path.join(folder, key + ".png"))
        for old in os.listdir(folder):               # drop pieces this script no longer makes
            if old.endswith(".png") and old[:-4] not in done:
                os.remove(os.path.join(folder, old))
                if os.path.exists(os.path.join(folder, old + ".import")):
                    os.remove(os.path.join(folder, old + ".import"))
        data["pieces"] = {key: [im.width, im.height] for key, im in sorted(done.items())}
        result["themes"][name] = data
        if sheet_dir:
            contact_sheet(name, done, os.path.join(sheet_dir, "sheet_%s.png" % name))
        print("%-8s %3d pieces -> %s" % (name, len(done), os.path.relpath(folder, ROOT)))
    order = [n for n, _ in THEMES]
    result["themes"] = {n: result["themes"][n] for n in order if n in result["themes"]}
    with open(json_path, "w") as f:
        json.dump(result, f, indent=1)
        f.write("\n")
    print("wrote", os.path.relpath(json_path, ROOT))


if __name__ == "__main__":
    main()
