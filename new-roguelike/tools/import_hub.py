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
]
# (name, pack, file ending, x, y, w, h): plain rectangles (ground tiles are opaque, islands cannot find them)
RECTS = [
    ("grass", FOREST, "Tiles.png", 0, 224, 112, 48),
    ("dirt", FOREST, "Tiles.png", 16, 280, 32, 32),
    ("patch_0", FOREST, "Tiles.png", 0, 128, 48, 48),
    ("patch_1", FOREST, "Tiles.png", 0, 176, 48, 48),
    # the tavern from outside: a stretch of plastered wall, the wooden gable roof, an open doorway, a window
    ("wall_plaster", BUILD, "Walls.png", 288, 184, 128, 56),
    ("roof_wood", BUILD, "Roofs.png", 0, 6, 128, 89),
    ("doorway", BUILD, "Props.png", 1, 23, 30, 41),
    ("window", BUILD, "Props.png", 132, 99, 24, 25),
    ("bench_long", BUILD, "Props.png", 83, 160, 58, 32),
    ("note", FREE, "Props/Static/Esoteric.png", 35, 130, 9, 11),      # a written page: the notes found in the levels
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
