#!/usr/bin/env python3
"""import_assets.py: copies the add-on art the game uses out of assets_raw/ into assets/art/.

It only CUTS, RENAMES and (for one pack) swaps ONE outline colour. It never draws anything.
Run it again any time; it rewrites the same files. Afterwards run:
    godot --headless --path . --import

    python3 tools/import_assets.py                  # do the import
    python3 tools/import_assets.py --sheet /tmp/x   # also write contact sheets there, to LOOK at

What goes where (file names follow scripts/core/art.gd: <id>.png, <id>_anim_f0.png,
<id>_idle_anim_f0.png, <id>_run_anim_f0.png):
  assets/art/niji/     Niji "Dungeon Tileset II Extended" (CC0): keys, torches, flames, keyholes, bags,
                       signs, rugs, carpets, single doors, stairs. Ids start with niji_.
  assets/art/forest/   Superdark "Enchanted Forest Characters": golem, troll, gnolls, wolf, bear, bandit,
                       mushroom folk, fairy. Ids start with sdf_. Outline #1c1117 becomes #222222 so it
                       matches the main pack; frames are trimmed to the character (feet stay on the
                       bottom edge, centred), the same way the main pack's frames are.
  assets/art/fx/       a SMALL set of effects that sits well beside the chunky 16 px art. Ids start with fx_.
                       To add one: add a row to FX below (the frame size is in assets_raw/fx/manifest.json).
The Superdark "fantasy rpg npcs" pack is deliberately NOT imported (its licence was judged doubtful).
"""
import json
import os
import sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RAW = os.path.join(ROOT, "assets_raw")
OUT = os.path.join(ROOT, "assets", "art")

# ---------------------------------------------------------------- Niji
NIJI_PACK = "niji_dungeontileset_ii_extended"
# Carpet blocks are 3x3 tiles: a 2x3 bordered rug on the left, and a column of "middle" pieces.
# (column, row) in the block -> part name. With these nine pieces a carpet of any size can be laid.
CARPET_PARTS = {
    (0, 0): "tl", (1, 0): "tr", (0, 1): "l", (1, 1): "r", (0, 2): "bl", (1, 2): "br",
    (2, 0): "fill", (2, 1): "t", (2, 2): "b",
}

# Pieces only the OLD room look used. Rooms are now drawn from the Pixel Crawler tile sets
# (assets/art/pc_tiles, tools/pc_import_tiles.py), so these are no longer cut out or shipped.
NIJI_SKIP = (
    "niji_bag_brown", "niji_bag_gold", "niji_carpet_", "niji_door_single_a", "niji_floor_plants",
    "niji_floor_torch", "niji_keyhole_light", "niji_wall_grate", "niji_wall_pipe",
    "niji_wall_sign_orange", "niji_wall_torch",
)

# ---------------------------------------------------------------- Superdark forest
FOREST_PACK = "superdark_enchanted_forest"
FOREST_KEEP = [
    "golem", "troll", "gnoll_brute", "gnoll_overseer", "gnoll_scout", "gnoll_shaman",
    "wolf", "bear", "bandit", "mushroom_large", "mushroom_normal", "mushroom_small", "fairy",
]
OUTLINE_FROM = (0x1C, 0x11, 0x17)
OUTLINE_TO = (0x22, 0x22, 0x22)

# ---------------------------------------------------------------- effects
# our id -> (id in assets_raw/fx/manifest.json, frames to keep or None for all non-empty ones)
FX = {
    "fx_bolt_hex": ("dw_arcane_bolt", None),        # the witch's hex bolt (points right)
    "fx_fireball": ("dw_fireball", None),           # enemy shot (points right)
    "fx_firebomb": ("dw_firebomb", None),           # big enemy shot (points right)
    "fx_star": ("dw_pure_bolt_2", None),            # frost shot / wisp shot
    "fx_rock": ("dw_rock_sling", None),             # the lobbed boulder
    "fx_sparkle": ("dw_black_and_white_sparks", None),  # pickup shine (white, tint it)
    "fx_sparkle_magic": ("dw_magic_sparks", None),  # item flourish
    "fx_hit": ("wsf_hits_2", None),                 # a shot hits a monster
    "fx_pop": ("wsf_hits_3", None),                 # a shot dies on a wall / a ward breaks
    "fx_explosion": ("ax_explosion_1_g", None),     # the bomb
    "fx_smoke": ("misc_smoke_puff", None),          # dust and death puffs (white, tint it)
}


def clean(folder):
    """Empties one of OUR output folders of old PNGs (and their .import files)."""
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith(".png"):
            os.remove(os.path.join(folder, f))


def prune_imports(folder):
    for f in os.listdir(folder):
        if f.endswith(".png.import") and not os.path.exists(os.path.join(folder, f[:-7])):
            os.remove(os.path.join(folder, f))


def save(img, folder, name, written):
    img.save(os.path.join(folder, name))
    written.append(name)


def import_niji(manifest, written):
    folder = os.path.join(OUT, "niji")
    clean(folder)
    atlases = {}
    for s in manifest["sprites"]:
        if s["pack"] != NIJI_PACK or s["id"].startswith(NIJI_SKIP):
            continue
        path = os.path.join(RAW, "art", s["atlas"])
        if path not in atlases:
            atlases[path] = Image.open(path).convert("RGBA")
        atlas = atlases[path]
        sid = s["id"]
        rects = s["rects"]
        if sid.endswith("_block"):
            base = sid[: -len("_block")]
            x, y, w, h = rects[0]
            block = atlas.crop((x, y, x + w, y + h))
            save(block, folder, base + ".png", written)
            for row in range(h // 16):
                for col in range(w // 16):
                    tile = block.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))
                    if tile.getbbox() is None:
                        continue
                    if "carpet" in base and "stairs" not in base:
                        part = CARPET_PARTS.get((col, row))
                        if part is not None:
                            save(tile, folder, "%s_%s.png" % (base, part), written)
                    else:
                        save(tile, folder, "%s_r%dc%d.png" % (base, row, col), written)
        elif len(rects) > 1:
            for i, (x, y, w, h) in enumerate(rects):
                save(atlas.crop((x, y, x + w, y + h)), folder, "%s_f%d.png" % (sid, i), written)
        else:
            x, y, w, h = rects[0]
            save(atlas.crop((x, y, x + w, y + h)), folder, sid + ".png", written)
    prune_imports(folder)


def remap_outline(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) == OUTLINE_FROM:
                px[x, y] = OUTLINE_TO + (a,)
    return img


def import_forest(manifest, written):
    folder = os.path.join(OUT, "forest")
    clean(folder)
    by_char = {}
    for s in manifest["sprites"]:
        if s["pack"] == FOREST_PACK and s.get("character") in FOREST_KEEP:
            by_char.setdefault(s["character"], []).append(s)
    for char, anims in sorted(by_char.items()):
        loaded = []
        for s in anims:
            frames = [remap_outline(Image.open(os.path.join(RAW, "art", f)).convert("RGBA")) for f in s["files"]]
            sid = s["id"]
            if sid.endswith("_idle_walk"):
                name = "sdf_%s_idle_anim" % char
            elif sid.endswith("_walk"):
                name = "sdf_%s_run_anim" % char
            else:
                name = "sdf_%s_idle_anim" % char
            loaded.append((name, frames))
        # one trim box for every frame of the character: feet stay on the bottom edge, centred
        w, h = loaded[0][1][0].size
        top, half = h, 1
        for _, frames in loaded:
            for fr in frames:
                box = fr.getbbox()
                if box is None:
                    continue
                top = min(top, box[1])
                half = max(half, w // 2 - box[0], box[2] - w // 2)
        crop = (w // 2 - half, top, w // 2 + half, h)
        for name, frames in loaded:
            for i, fr in enumerate(frames):
                save(fr.crop(crop), folder, "%s_f%d.png" % (name, i), written)
    prune_imports(folder)


def fx_frames(entry):
    base = os.path.join(RAW, "fx", entry["file"])
    fw, fh = entry["frame_w"], entry["frame_h"]
    frames = []
    if entry.get("layout") == "loose":
        for f in entry["frame_files"]:
            frames.append(Image.open(os.path.join(base, f)).convert("RGBA"))
    else:
        sheet = Image.open(base).convert("RGBA")
        cols = entry.get("cols", sheet.width // fw)
        rows = entry.get("rows", sheet.height // fh)
        for i in range(entry["frames"]):
            col, row = i % cols, i // cols
            if row >= rows:
                break
            frames.append(sheet.crop((col * fw, row * fh, col * fw + fw, row * fh + fh)))
    return [f for f in frames if f.getbbox() is not None]


def import_fx(written):
    folder = os.path.join(OUT, "fx")
    clean(folder)
    entries = {e["id"]: e for e in json.load(open(os.path.join(RAW, "fx", "manifest.json")))}
    for our_id, (src_id, keep) in FX.items():
        frames = fx_frames(entries[src_id])
        if keep is not None:
            frames = [frames[i] for i in keep]
        if len(frames) == 1:
            save(frames[0], folder, our_id + ".png", written)
        else:
            for i, fr in enumerate(frames):
                save(fr, folder, "%s_anim_f%d.png" % (our_id, i), written)
    prune_imports(folder)


def contact_sheet(folder, path, scale=4):
    names = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    imgs = [(n, Image.open(os.path.join(folder, n)).convert("RGBA")) for n in names]
    if not imgs:
        return
    from PIL import ImageDraw
    cell_w = max(i.width for _, i in imgs) * scale + 8
    cell_w = max(cell_w, 150)
    cell_h = max(i.height for _, i in imgs) * scale + 20
    cols = max(1, 1500 // cell_w)
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (34, 34, 46, 255))
    draw = ImageDraw.Draw(sheet)
    for k, (n, im) in enumerate(imgs):
        x, y = (k % cols) * cell_w, (k // cols) * cell_h
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        sheet.alpha_composite(big, (x + 4, y + 2))
        draw.text((x + 2, y + cell_h - 14), n[:-4][-26:], fill=(200, 200, 210, 255))
    sheet.save(path)


def main():
    manifest = json.load(open(os.path.join(RAW, "art", "manifest.json")))
    written = []
    import_niji(manifest, written)
    n1 = len(written)
    import_forest(manifest, written)
    n2 = len(written)
    import_fx(written)
    print("niji: %d files   forest: %d files   fx: %d files" % (n1, n2 - n1, len(written) - n2))
    if "--sheet" in sys.argv:
        where = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(where, exist_ok=True)
        for sub in ["niji", "forest", "fx"]:
            contact_sheet(os.path.join(OUT, sub), os.path.join(where, sub + ".png"))
        print("contact sheets in", where)
    print("now run:  godot --headless --path . --import")


if __name__ == "__main__":
    main()
