#!/usr/bin/env python3
"""Props importer: the SMALL THINGS (pickups, chests, item stands, the bomb, the floor exit).

Run from anywhere:   python3 -I tools/import_props.py [--sheet /abs/dir]
then                 godot --headless --path . --import

Reads  assets_raw/paid_pixel_crawler/x/   the unpacked purchased Pixel Crawler packs
       assets_raw/props/<slug>/*.zip      the free (CC0) packs used; read as images straight out of
                                          the archive, in memory: nothing is unpacked or executed
Writes assets/art/props/                  <id>.png stills, <id>_anim_f<n>.png loops (the naming
                                          scripts/core/art.gd understands) and props.json
       --sheet DIR                        also writes DIR/props_sheet.png (everything x4 beside the knight)
Idempotent: it deletes and rewrites only the prop_* PNGs it owns plus props.json.

It only cuts, crops, pads and (for the armour heart) swaps colour channels. No pixel is drawn.
To add a prop: add one row to STILLS or LOOPS below, run it, look at the sheet.
"""
import glob
import io
import json
import os
import sys
import zipfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
PC_X = os.path.join(GAME, "assets_raw", "paid_pixel_crawler", "x")
RAW = os.path.join(GAME, "assets_raw", "props")
OUT = os.path.join(GAME, "assets", "art", "props")
BG = (26, 26, 36, 255)

PC = "Pixel_Crawler_-_"
PACKS = {
    "hideout": {"pack": "Pixel Crawler - Hideout (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
                "file": PC + "Hideout_1.0/Pixel Crawler - Hideout/Assets/Tiles.png"},
    "sewer": {"pack": "Pixel Crawler - Sewer (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
              "file": PC + "Sewer/Pixel Crawler - Sewer/Assets/Props.png"},
    "forge": {"pack": "Pixel Crawler - Forge (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
              "file": PC + "Forge_1.2/Pixel Crawler - Forge/Assets/Tiles.png"},
    "library": {"pack": "Pixel Crawler - Library (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
                "file": PC + "Library/Pixel Crawler - Library/Assets/Tiles.png"},
    "desert": {"pack": "Pixel Crawler - Desert (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
               "file": PC + "Desert/Pixel Crawler - Desert/Assets/Props.png"},
    "castle": {"pack": "Pixel Crawler - Castle Environment (Anokolisa)", "licence": "purchased; commercial use, no redistribution",
               "file": PC + "Castle_Environment_0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png"},
    "kings": {"pack": "Kings and Pigs (Pixel Frog)", "licence": "CC0 1.0",
              "zip": "pixelfrog_kings_and_pigs/Kings and Pigs.zip"},
    "treasure": {"pack": "Treasure Hunters (Pixel Frog)", "licence": "CC0 1.0",
                 "zip": "pixelfrog_treasure_hunters/Treasure Hunters.zip"},
}

# ---------------------------------------------------------------- what to cut
# STILLS: id, pack, box (x0, y0, x1, y1) on the pack's sheet (or a file inside the zip + box or None).
#         The cut is then trimmed to what is drawn.
STILLS = [
    # chests: one style per floor theme, closed and open; "locked" is the gold one with a padlock
    ("prop_chest_crypt", "hideout", None, (224, 272, 256, 304)),
    ("prop_chest_crypt_open", "hideout", None, (256, 256, 288, 304)),
    ("prop_chest_warrens", "sewer", None, (129, 40, 158, 72)),
    ("prop_chest_warrens_open", "sewer", None, (130, 4, 158, 32)),
    ("prop_chest_ashen", "forge", None, (240, 112, 272, 144)),
    ("prop_chest_ashen_open", "forge", None, (240, 88, 272, 112)),
    ("prop_chest_pit", "library", None, (320, 272, 352, 304)),
    ("prop_chest_pit_open", "library", None, (320, 224, 352, 272)),
    ("prop_chest_locked", "desert", None, (97, 41, 127, 64)),
    ("prop_chest_locked_open", "desert", None, (129, 8, 159, 32)),
    # the item stand: a stone column capital; the way down: a framed stairwell
    ("prop_plinth", "castle", None, (192, 64, 208, 84)),
    ("prop_stairs_down", "castle", None, (48, 320, 96, 368)),
    # the bomb you pick up (fuse not burning)
    ("prop_bomb", "kings", "Sprites/09-Bomb/Bomb Off.png", None),
]

TH = "Treasure Hunters/Pirate Treasure/Sprites/"
# LOOPS: id, pack, how to get the frames, options.
#   ("strip", file, cell_w, cell_h, count)   one sheet, frames side by side
#   ("files", folder, count)                 01.png, 02.png ... inside the folder
# options: "center_x": keep this x of the cell in the middle of the cut (the bomb's sparks fly to one side)
#          "blue": swap red and blue (the armour heart is the red heart recoloured, like the HUD's)
LOOPS = [
    ("prop_coin", "treasure", ("files", TH + "Gold Coin/", 4), {}),
    ("prop_gem", "treasure", ("files", TH + "Green Diamond/", 4), {}),
    ("prop_key", "treasure", ("files", "Treasure Hunters/Merchant Ship/Sprites/Chest Key/Idle/", 8), {}),
    ("prop_skull", "treasure", ("files", TH + "Golden Skull/", 8), {}),
    ("prop_heart", "kings", ("strip", "Sprites/12-Live and Coins/Big Heart Idle (18x14).png", 18, 14, 8), {}),
    ("prop_half_heart", "kings", ("strip", "Sprites/12-Live and Coins/Small Heart Idle (18x14).png", 18, 14, 8), {}),
    ("prop_armor", "kings", ("strip", "Sprites/12-Live and Coins/Big Heart Idle (18x14).png", 18, 14, 8), {"blue": True}),
    ("prop_bomb_lit", "kings", ("strip", "Sprites/09-Bomb/Bomb On (52x56).png", 52, 56, 4), {"center_x": 26.5}),
]

_zips = {}
_sheets = {}


def _zip_image(pack, member):
    z = _zips.get(pack)
    if z is None:
        z = zipfile.ZipFile(os.path.join(RAW, PACKS[pack]["zip"]))
        _zips[pack] = z
    names = [n for n in z.namelist() if n.endswith(member)]
    if not names:
        raise SystemExit("import_props: '%s' is not in %s" % (member, PACKS[pack]["zip"]))
    return Image.open(io.BytesIO(z.read(names[0]))).convert("RGBA")


def _sheet(pack):
    if pack not in _sheets:
        _sheets[pack] = Image.open(os.path.join(PC_X, PACKS[pack]["file"])).convert("RGBA")
    return _sheets[pack]


def _union_box(frames):
    box = None
    for f in frames:
        b = f.getbbox()
        if b is None:
            continue
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box


def _blue(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (b, min(int(g * 0.9 + r * 0.25), 255), r, a)
    return im


def build():
    made = {}   # file name -> image
    info = {}   # id -> props.json row
    for pid, pack, member, box in STILLS:
        if member is None:
            im = _sheet(pack).crop(box)
            src = PACKS[pack]["file"]
        else:
            im = _zip_image(pack, member)
            if box:
                im = im.crop(box)
            src = PACKS[pack]["zip"] + " :: " + member
        b = im.getbbox()
        im = im.crop(b)
        made[pid + ".png"] = im
        info[pid] = {"pack": PACKS[pack]["pack"], "licence": PACKS[pack]["licence"], "source": src,
                     "box": list(box) if box else None, "size": list(im.size), "frames": 1}
    for pid, pack, how, opt in LOOPS:
        if how[0] == "strip":
            sheet = _zip_image(pack, how[1])
            frames = [sheet.crop((i * how[2], 0, (i + 1) * how[2], how[3])) for i in range(how[4])]
            src = PACKS[pack]["zip"] + " :: " + how[1]
        else:
            frames = [_zip_image(pack, "%s%02d.png" % (how[1], i + 1)) for i in range(how[2])]
            src = PACKS[pack]["zip"] + " :: " + how[1] + "01.png ..."
        x0, y0, x1, y1 = _union_box(frames)
        if "center_x" in opt:
            half = max(opt["center_x"] - x0, x1 - opt["center_x"])
            x0, x1 = int(opt["center_x"] - half), int(opt["center_x"] + half + 0.5)
        frames = [f.crop((x0, y0, x1, y1)) for f in frames]
        if opt.get("blue"):
            frames = [_blue(f) for f in frames]
        for i, f in enumerate(frames):
            made["%s_anim_f%d.png" % (pid, i)] = f
        info[pid] = {"pack": PACKS[pack]["pack"], "licence": PACKS[pack]["licence"], "source": src,
                     "box": [x0, y0, x1, y1], "size": list(frames[0].size), "frames": len(frames)}
        if opt.get("blue"):
            info[pid]["note"] = "red and blue channels swapped by the importer"
    return made, info


def write(made, info):
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "prop_*.png")):
        if os.path.basename(old) not in made:
            os.remove(old)
            if os.path.exists(old + ".import"):
                os.remove(old + ".import")
    for name, im in made.items():
        path = os.path.join(OUT, name)
        if os.path.exists(path) and Image.open(path).convert("RGBA").tobytes() == im.tobytes() \
                and Image.open(path).size == im.size:
            continue   # unchanged: leave the file (and Godot's import of it) alone
        im.save(path)
    with open(os.path.join(OUT, "props.json"), "w") as f:
        json.dump({"about": "Small things cut by tools/import_props.py. Do not edit by hand.", "props": info}, f, indent=1, sort_keys=True)
        f.write("\n")


def sheet(made, info, folder):
    sc = 4
    knight = Image.open(os.path.join(GAME, "assets", "art", "pc", "pc_knight_idle_anim_f0.png")).convert("RGBA")
    knight = knight.crop(knight.getbbox())
    rows = [[], [], [], []]
    for pid in info:
        n = info[pid]["frames"]
        names = [pid + ".png"] if n == 1 and (pid + ".png") in made else ["%s_anim_f%d.png" % (pid, i) for i in range(n)]
        row = 0 if "chest" in pid else (1 if pid in ("prop_plinth", "prop_stairs_down", "prop_bomb") else (2 if n <= 4 else 3))
        rows[row].append((pid, [made[x] for x in names]))
    W = 1900
    out = Image.new("RGBA", (W, 1400), BG)
    d = ImageDraw.Draw(out)
    y = 6
    for row in rows:
        hmax = max([knight.height] + [im.height for _, ims in row for im in ims]) * sc
        x = 6
        out.alpha_composite(knight.resize((knight.width * sc, knight.height * sc), Image.NEAREST), (x, y + hmax - knight.height * sc))
        x += knight.width * sc + 16
        for pid, ims in row:
            x_start = x
            for im in ims:
                out.alpha_composite(im.resize((im.width * sc, im.height * sc), Image.NEAREST), (x, y + hmax - im.height * sc))
                x += im.width * sc + 4
            d.text((x_start, y + hmax + 2), "%s %dx%d" % (pid.replace("prop_", ""), ims[0].width, ims[0].height), fill=(220, 220, 220, 255))
            x = max(x, x_start + 100) + 12
        y += hmax + 22
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "props_sheet.png")
    out.crop((0, 0, W, y)).save(path)
    print("sheet:", path)


def main():
    made, info = build()
    write(made, info)
    print("import_props: %d ids, %d PNGs in %s" % (len(info), len(made), OUT))
    if "--sheet" in sys.argv:
        sheet(made, info, sys.argv[sys.argv.index("--sheet") + 1])


if __name__ == "__main__":
    main()
