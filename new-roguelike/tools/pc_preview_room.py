#!/usr/bin/env python3
"""Render one room from assets/art/pc_tiles/tilesets.json, to check a theme by LOOKING at it.

    python3 -I tools/pc_preview_room.py THEME OUT.png [--doors n=open,s=shut,w=locked,e=boss]
                                        [--fight] [--strip] [--scale 4] [--seed 1] [--nolight]

--fight  adds one obstacle of each kind, wall and floor decoration and a few characters.
--strip  writes every door state for all four walls instead of one room.

This file is also the reference for the game's room drawing: it uses nothing but tilesets.json.
The draw order below is the order the game must use.
"""
import json
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "art", "pc_tiles")
SCREEN = (320, 180)
STATES = ["open", "shut", "locked", "hidden", "cracked", "boss"]
CAST = {"crypt": ["pc_knight", "pc_skeleton_warrior", "pc_zombie_base", "pc_skeleton_mage"],
        "warrens": ["pc_rogue", "pc_rat_warrior", "pc_fungus_heavy", "pc_rat_mage"],
        "ashen": ["pc_wizard", "pc_stone_lava", "pc_orc_warrior", "pc_stone_golem"],
        "pit": ["pc_knight", "pc_royal_knight", "pc_royal_priest", "pc_royal_archer"]}
# The --fight room: letters as in scripts/data/room_layouts.gd, plus one frame number per spike.
FIGHT = ["..T..............",
         "...##.....^^..I..",
         ".................",
         ".................",
         "......oo.........",
         "...I........cc...",
         "................."]


class Room:
    def __init__(self, theme, seed=1):
        with open(os.path.join(TILES, "tilesets.json")) as f:
            data = json.load(f)
        self.r, self.t, self.name = data["room"], data["themes"][theme], theme
        self.h = self.t["back_wall_h"]
        self.fx, self.fy = self.r["side_w"], self.h                    # floor origin inside the room
        self.w = self.fx * 2 + self.r["cols"] * 16
        self.height = self.h + self.r["rows"] * 16 + self.r["bottom_h"]
        self.ox, self.oy = (SCREEN[0] - self.w) // 2, (SCREEN[1] - self.height) // 2
        self.img = Image.new("RGBA", SCREEN, self.t["void_color"])
        self.rng = random.Random(seed)
        self.cache, self.lights = {}, []

    def piece(self, name):
        if name not in self.cache:
            self.cache[name] = Image.open(os.path.join(TILES, self.name, name + ".png")).convert("RGBA")
        return self.cache[name]

    def put(self, name, x, y):                       # x, y in room pixels
        self.img.alpha_composite(self.piece(name), (self.ox + x, self.oy + y))

    def door_cell(self, d):
        mid_x, mid_y = self.fx + self.r["door_col"] * 16, self.fy + self.r["door_row"] * 16
        return {"n": (mid_x, 0), "s": (mid_x, self.fy + self.r["rows"] * 16), "w": (0, mid_y), "e": (self.fx + self.r["cols"] * 16, mid_y)}[d]

    def door_ops(self, d, state, front):
        x, y = self.door_cell(d)
        for o in self.t["doors"][d][state]["ops"]:
            if bool(o.get("front")) != front:
                continue
            if "piece" in o:
                self.put(o["piece"], x + o["dx"], y + o["dy"])
            else:                                    # 'code': the game draws this; the preview only marks the spot
                c = (214, 170, 60, 255) if o["code"] == "lock" else (190, 40, 40, 255)
                px, py = self.ox + x + o["dx"], self.oy + y + o["dy"]
                ImageDraw.Draw(self.img).rectangle([px - 2, py - 2, px + 1, py + 1], fill=c, outline=(0, 0, 0, 255))

    def gap(self, d, state):
        """Wall-strip cells (in room pixels) that a side or bottom door replaces."""
        x, y = self.door_cell(d)
        return {(x + gx * 16, y + gy * 16) for gx, gy in self.t["doors"][d][state]["gap"]}

    def render(self, doors, layout=None, chars=(), deco=False, light=True):
        t, r, rng = self.t, self.r, self.rng
        cols, rows = r["cols"], r["rows"]
        fl = t["floor"]
        # 1. floor: weighted random variants, optional shaded tiles under the back wall / beside the left wall
        names, weights = zip(*fl["variants"])
        for cy in range(rows):
            for cx in range(cols):
                name = rng.choices(names, weights)[0]
                if cy == 0 and fl.get("shade_top"):
                    name = fl["shade_corner"] if cx == 0 and fl.get("shade_corner") else fl["shade_top"]
                elif cx == 0 and fl.get("shade_left"):
                    name = fl["shade_left"]
                self.put(name, self.fx + cx * 16, self.fy + cy * 16)
        cells = {(cx, cy): ch for cy, line in enumerate(layout or []) for cx, ch in enumerate(line) if ch != "."}
        # 2. floor decoration (never on a blocked cell, never pale)
        if deco:
            free = [(cx, cy) for cy in range(rows) for cx in range(cols) if (cx, cy) not in cells]
            for d in rng.choices(t["floor_deco"], [d["weight"] for d in t["floor_deco"]], k=6):
                cx, cy = free.pop(rng.randrange(len(free)))
                im = self.piece(d["piece"])
                off = (0, 0) if d.get("tile") else (rng.randrange(17 - im.width), rng.randrange(17 - im.height))
                self.put(d["piece"], self.fx + cx * 16 + off[0], self.fy + cy * 16 + off[1])
        # 3. flat obstacles (pits, spikes) lie under everything that stands
        kinds = {"#": "rock", "o": "pit", "^": "spikes", "c": "crate", "I": "pillar", "T": "torch"}
        standing = []
        for (cx, cy), ch in sorted(cells.items()):
            ob = t["obstacles"][kinds[ch]]
            if "frames" in ob:                       # animated: the preview shows a different frame per cell
                var = ob["frames"][(cx * 2 + cy) % len(ob["frames"])] if kinds[ch] != "spikes" else ob["frames"][2 if cx % 2 == 0 else 0]
            else:
                var = ob["variants"][(cx + cy) % len(ob["variants"])]
            x, y = self.fx + cx * 16 + var["dx"], self.fy + cy * 16 + var["dy"]
            if ob.get("flat"):
                self.put(var["piece"], x, y)
            else:
                standing.append((self.fy + cy * 16 + 16, var["piece"], x, y))
                if "flame" in ob:                    # animated flame drawn on top of the stand
                    fl2 = ob["flame"]
                    standing.append((self.fy + cy * 16 + 16.5, fl2["frames"][0], self.fx + cx * 16 + fl2["dx"], self.fy + cy * 16 + fl2["dy"]))
            if "light" in ob:
                self.lights.append((self.fx + cx * 16 + ob["light"]["lx"], self.fy + cy * 16 + ob["light"]["ly"], ob["light"]))
        # 4. walls: back rows, side strips, corners (the bottom strip comes last, in front)
        w = t["walls"]
        for row in w["back_rows"]:
            for cx in range(cols):                   # optional 'first' / 'last' pieces end the row at the side walls
                name = row["repeat"][cx % len(row["repeat"])]
                name = row.get("first", name) if cx == 0 else row.get("last", name) if cx == cols - 1 else name
                self.put(name, self.fx + cx * 16, row["y"])
        right_x, bottom_y = self.fx + cols * 16, self.fy + rows * 16
        skip = self.gap("w", doors["w"]) | self.gap("e", doors["e"])
        for i, y in enumerate(range(16, bottom_y, 16)):
            if (0, y) not in skip:
                self.put(w["left"][i % len(w["left"])], 0, y)
            if (right_x, y) not in skip:
                self.put(w["right"][i % len(w["right"])], right_x, y)
        self.put(w["corner_tl"], 0, 0)
        self.put(w["corner_tr"], right_x, 0)
        # 5. doors that sit behind characters, then wall decoration
        for d in "nwe":
            self.door_ops(d, doors[d], False)
        self.door_ops("s", doors["s"], False)
        if deco:
            wd = t["wall_deco"]
            free = [c for c in range(cols) if c not in wd["keep_clear"]]
            for d in wd["pieces"]:
                if d.get("columns"):                 # fixed columns: torches
                    for c in d["columns"]:
                        free.remove(c)
                        self.wall_piece(d, c)
            loose = [d for d in wd["pieces"] if not d.get("columns")]
            for d in rng.choices(loose, [d["weight"] for d in loose], k=min(5, len(loose) + 2)) if loose else []:
                self.wall_piece(d, free.pop(rng.randrange(len(free))))
        # 6. everything that stands, sorted by its feet: obstacles and characters
        for i, (name, cx, cy) in enumerate(chars):
            im = self.character(name)
            if im:
                foot = self.fy + cy * 16 + 14
                standing.append((foot, im, self.fx + cx * 16 + 8 - im.width // 2, foot - im.height))
        for _, what, x, y in sorted(standing, key=lambda s: s[0]):
            if isinstance(what, str):
                self.put(what, x, y)
            else:
                self.img.alpha_composite(what, (self.ox + x, self.oy + y))
        # 7. the bottom wall and anything marked 'front' hide the feet of whoever stands behind them
        skip = self.gap("s", doors["s"])
        for cx in range(cols):
            if (self.fx + cx * 16, bottom_y) not in skip:
                self.put(w["bottom"][cx % len(w["bottom"])], self.fx + cx * 16, bottom_y)
        self.put(w["corner_bl"], 0, bottom_y)
        self.put(w["corner_br"], right_x, bottom_y)
        for d in "nswe":
            self.door_ops(d, doors[d], True)
        # 8. mood: multiply by the ambient colour, add a soft glow per light (a code effect, not art)
        if light:
            self.light()
        return self.img

    def wall_piece(self, d, col):
        name = d["piece"] + ("_f0" if d.get("frames") else "")
        x, y = self.fx + col * 16 + d["dx"], d["y"]
        self.put(name, x, y)
        if "light" in d:
            self.lights.append((x + d["light"]["lx"], y + d["light"]["ly"], d["light"]))

    def character(self, name):
        for folder, file in (("pc", name), ("pc", "pc_" + name), ("dungeon", name)):
            path = os.path.join(ROOT, "assets", "art", folder, file + "_idle_anim_f0.png")
            if os.path.exists(path):
                im = Image.open(path).convert("RGBA")
                return im.crop(im.getchannel("A").getbbox())
        return None

    def light(self):
        """out = picture * (ambient + sum of light colour * falloff): what CanvasModulate + Light2D give.
        The light map is kept at half scale so a torch can push a pixel above its own colour."""
        amb = tuple(int(self.t["ambient"][i:i + 2], 16) // 2 for i in (1, 3, 5))
        lum = Image.new("RGB", SCREEN, amb)
        px = lum.load()
        for lx, ly, l in self.lights:
            col = tuple(int(l["color"][i:i + 2], 16) for i in (1, 3, 5))
            rad, cx, cy = l["radius"], self.ox + lx, self.oy + ly
            for y in range(max(0, cy - rad), min(SCREEN[1], cy + rad)):
                for x in range(max(0, cx - rad), min(SCREEN[0], cx + rad)):
                    k = 1.0 - ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / rad
                    if k > 0:
                        px[x, y] = tuple(min(255, px[x, y][i] + int(col[i] * k * k * 0.3)) for i in range(3))
        half = ImageChops.multiply(self.img.convert("RGB"), lum)
        self.img = ImageChops.add(half, half).convert("RGBA")


def upscale(im, scale):
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST).convert("RGB")


def strip(theme, scale):
    """Every door state, four walls each: columns = states, rows = back, bottom, left, right wall."""
    crops, cw, ch = [], 96, 60
    for state in STATES:
        room = Room(theme)
        room.render({d: state for d in "nswe"}, light=False)
        boxes = []
        for d in "nswe":
            x, y = room.door_cell(d)
            cx, cy = room.ox + x + 8, room.oy + y + (room.h // 2 if d == "n" else 8)
            bx = min(max(cx - cw // 2, 0), SCREEN[0] - cw)
            by = min(max(cy - ch // 2, 0), SCREEN[1] - ch)
            boxes.append(room.img.crop((bx, by, bx + cw, by + ch)))
        crops.append(boxes)
    out = Image.new("RGB", ((cw * scale + 8) * len(STATES) + 8, (ch * scale + 8) * 4 + 24), (26, 26, 36))
    d = ImageDraw.Draw(out)
    for i, state in enumerate(STATES):
        d.text((8 + i * (cw * scale + 8), 6), "%s: %s" % (theme, state), fill=(230, 230, 120))
        for j, im in enumerate(crops[i]):
            out.paste(upscale(im, scale), (8 + i * (cw * scale + 8), 24 + j * (ch * scale + 8)))
    return out


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    theme, out = a[0], a[1]

    def opt(flag, default):
        return a[a.index(flag) + 1] if flag in a else default
    scale = int(opt("--scale", 4))
    if "--strip" in a:
        strip(theme, scale).save(out)
    else:
        doors = {d: "open" for d in "nswe"}
        doors.update(kv.split("=") for kv in opt("--doors", "").split(",") if kv)
        fight = "--fight" in a
        room = Room(theme, int(opt("--seed", 1)))
        chars = [(n, x, y) for n, (x, y) in zip(CAST.get(theme, CAST["crypt"]), [(7, 3), (11, 3), (5, 5), (13, 2)])] if fight else []
        im = room.render(doors, FIGHT if fight else None, chars, deco=fight, light="--nolight" not in a)
        upscale(im, scale).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
