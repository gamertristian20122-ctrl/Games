#!/usr/bin/env python3
"""Pixel Crawler cast importer (characters, creatures, NPCs, hands, weapons).

Run from anywhere:  python3 -I tools/pc_import_cast.py
Reads  assets_raw/paid_pixel_crawler/x/  (the unpacked purchased packs; never executed, only read as images)
Writes assets/art/pc/  (<id>_<anim>_anim_f<n>.png, stills <id>.png, pc_cast.json)
and contact sheets to the scratchpad folder given by PC_SCRATCH (default below).
Idempotent: it deletes and rewrites only the pc_* PNGs it owns plus pc_cast.json.

Only cuts, crops, pads, flips and 90-degree rotations: no pixel is drawn or changed.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
X = os.path.join(GAME, "assets_raw", "paid_pixel_crawler", "x")
OUT = os.path.join(GAME, "assets", "art", "pc")
SCR = os.environ.get("PC_SCRATCH", "/tmp/claude-0/-home-user/5364784e-e756-5c67-b396-0f57c4c58bac/scratchpad/pc/cast")
BG = (26, 26, 36, 255)

FP = "Pixel_Crawler_-_Free_Pack_Exterior_0.1/Pixel Crawler - Free Pack"
CEM = "Pixel_Crawler_-_Cemetery_0.4/Pixel Crawler - Cemetery"

# ---------------------------------------------------------------- roster
# (id, pack label, folder relative to X, style)
#  style "plain": <Anim>-Sheet.png somewhere under the folder (Idle, Run, Hit, Death)
#  style "side":  <Anim>_<Side|Down|Up>-Sheet.png (bats, Body_A, Hunter): side = main id, others _down/_up
CAST = []
def add(i, pack, folder, style="plain", role="enemy", extra=None):
    CAST.append(dict(id=i, pack=pack, folder=folder, style=style, role=role, extra=extra or {}))

add("pc_knight", "Free Pack", FP + "/Entities/Npc's/Knight", role="hero")
add("pc_rogue", "Free Pack", FP + "/Entities/Npc's/Rogue", role="hero")
add("pc_wizard", "Free Pack", FP + "/Entities/Npc's/Wizzard", role="hero")
add("pc_hunter", "Cemetery", CEM + "/Entities/Characters/A_Hunter", "side", role="hero",
    extra={"attack": "Attack_01_Base/Slice", "pierce": "Attack_02_Base/Pierce", "crush": "Attack_03_Base/Crush"})
add("pc_body_a", "Free Pack", FP + "/Entities/Characters/Body_A/Animations", "side", role="hero",
    extra={"attack": "Slice_Base/Slice", "pierce": "Pierce_Base/Pierce", "crush": "Crush_Base/Crush"})
for k in ("Base", "Warrior", "Rogue", "Mage"):
    add("pc_skeleton_" + k.lower(), "Free Pack", FP + "/Entities/Mobs/Skeleton Crew/Skeleton - " + k)
for k, n in (("Orc", "pc_orc_base"), ("Orc - Warrior", "pc_orc_warrior"), ("Orc - Rogue", "pc_orc_rogue"), ("Orc - Shaman", "pc_orc_shaman")):
    add(n, "Free Pack", FP + "/Entities/Mobs/Orc Crew/" + k)
for k in ("Base", "Overweight", "Banshee", "Muscle"):
    add("pc_zombie_" + k.lower(), "Cemetery", CEM + "/Entities/Mobs/Zombie - " + k)
for k in ("Soldier", "Knight", "Archer", "Priest"):
    add("pc_royal_" + k.lower(), "Castle", "Pixel_Crawler_-_Castle_Environment_0.3/Pixel Crawler - Castle Environment 0.3/Enemies/Royal Crew/" + k)
for k in ("Base", "Broken", "Lava", "Golem"):
    add("pc_stone_" + k.lower(), "Forge", "Pixel_Crawler_-_Forge_1.2/Pixel Crawler - Forge/Enemy/Stone - " + k)
for k in ("Immature", "Old", "Heavy", "Long"):
    add("pc_fungus_" + k.lower(), "Cave", "Pixel_Crawler_-_Cave/Pixel Crawler - Cave/Enemies/" + k + " Fungus")
for k in ("Base", "Warrior", "Rogue", "Mage"):
    add("pc_rat_" + k.lower(), "Sewer", "Pixel_Crawler_-_Sewer/Pixel Crawler - Sewer/Enemy/Rat - " + k)
for k in ("Base", "Warrior", "Rogue", "Mage"):
    add("pc_mummy_" + k.lower(), "Desert", "Pixel_Crawler_-_Desert/Pixel Crawler - Desert/Enemy/Mummy - " + k)
for k in ("Researcher", "Cataloguer", "Censor", "Director"):
    add("pc_scholar_" + k.lower(), "Library", "Pixel_Crawler_-_Library/Pixel Crawler - Library/Enemies/Scholars/" + k)
for k in ("Fighter", "Scout", "Sorcerer", "Tracker"):
    add("pc_bandit_" + k.lower(), "Hideout", "Pixel_Crawler_-_Hideout_1.0/Pixel Crawler - Hideout/Enemies/Baldits/" + k)
for k, n in (("Medusa", "pc_medusa"), ("Feminine", "pc_statue_feminine"), ("Masculine", "pc_statue_masculine"), ("Old", "pc_statue_old")):
    add(n, "Garden", "Pixel_Crawler_-_Garden_Environment/Pixel Crawler - Garden Environment/Enemies/" + k)
for k in ("Base", "Druid", "Hunter", "Ranger"):
    add("pc_elf_" + k.lower(), "Fairy Forest", "Pixel_Crawler_-_Fairy_Forest_1.7/Pixel Crawler - Fairy Forest 1.7/Enemies/Elf - " + k)
add("pc_bat_fur", "Bat_Fur", "Bat_Fur/Bat_Fur", "side", extra={"attack": "Attack_01/Attack"})
add("pc_bat_small", "Small_Bat", "Small_Bat/Small_Bat", "side", extra={"attack": "Attack_01/Attack_01"})
# shopkeeper candidates: idle only
NPC = FP + "/Entities/Npc's/Citizen_F/"
add("pc_npc_peasant_a", "Free Pack", NPC + "Peasant_A", role="npc")
for t in ("A", "B"):
    add("pc_npc_tavern_" + t.lower(), "Free Pack", NPC + "Tavern_" + t, role="npc", extra={"idle": "Idle/Idle_Side"})
    add("pc_npc_tavern_" + t.lower() + "_hold", "Free Pack", NPC + "Tavern_" + t, role="npc", extra={"idle": "Idle_Hold/Idle_Side"})

# Sources that face LEFT and must be mirrored (checked on the contact sheets).
FLIP = set()
# Frame widths that the automatic search must not guess (path suffix -> frame width). Verified by eye.
FW_OVERRIDE = {}

# ---------------------------------------------------------------- helpers
def find_sheet(folder, name):
    """name like 'Idle' (plain) or 'Idle_Base/Idle_Side' (explicit). Case-insensitive search."""
    base = os.path.join(X, folder)
    want = (name.split("/")[-1] + "-Sheet.png").lower()
    sub = "/".join(name.split("/")[:-1]).lower()
    hits = []
    for p in glob.glob(os.path.join(glob.escape(base), "**", "*.png"), recursive=True):
        rel = os.path.relpath(p, base)
        if os.path.basename(p).lower() == want and (not sub or os.path.dirname(rel).lower() == sub):
            hits.append(p)
    hits.sort(key=len)
    return hits[0] if hits else None


def frame_width(img, path):
    for k, v in FW_OVERRIDE.items():
        if path.endswith(k):
            return v
    W, H = img.size
    a = np.array(img)[:, :, 3] > 0
    cands = [H] + sorted(c for c in range(16, 2 * H + 1, 8) if c != H)
    for fw in cands:
        if W % fw:
            continue
        n = W // fw
        ok = all(a[:, i * fw:(i + 1) * fw].any() for i in range(n))
        # a pose must never straddle a frame boundary
        for i in range(1, n):
            if (a[:, i * fw - 1] & a[:, i * fw]).any():
                ok = False
        if ok:
            return fw
    raise SystemExit("no frame width for " + path)


def cut(path, flip):
    img = Image.open(path).convert("RGBA")
    fw = frame_width(img, path)
    fr = [img.crop((i * fw, 0, (i + 1) * fw, img.height)) for i in range(img.width // fw)]
    if flip:
        fr = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in fr]
    return fr, fw


def anchor0(fr):
    """Rough anchor of a frame: centroid x of the upper 60 % of the body, lowest opaque row + 1."""
    a = np.array(fr)[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    top, bot = ys.min(), ys.max() + 1
    m = ys < top + 0.6 * (bot - top)
    return float(xs[m].mean()), int(bot)


def refine(ref, refpos, fr, pos, r=10):
    """Shift fr (placed at pos) by up to r px so its colours overlap ref best."""
    A = np.array(ref).astype(int)
    B = np.array(fr).astype(int)
    best, bs = (0, 0), -1
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            ox, oy = pos[0] + dx - refpos[0], pos[1] + dy - refpos[1]
            x0, y0 = max(0, ox), max(0, oy)
            x1, y1 = min(A.shape[1], ox + B.shape[1]), min(A.shape[0], oy + B.shape[0])
            if x1 <= x0 or y1 <= y0:
                continue
            a = A[y0:y1, x0:x1]
            b = B[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
            both = (a[:, :, 3] > 0) & (b[:, :, 3] > 0)
            same = both & (np.abs(a[:, :, :3] - b[:, :, :3]).sum(2) < 40)
            s = same.sum() * 2 - ((a[:, :, 3] > 0) ^ (b[:, :, 3] > 0)).sum() * 0.25 - (abs(dx) + abs(dy)) * 0.1
            if s > bs:
                bs, best = s, (dx, dy)
    return pos[0] + best[0], pos[1] + best[1]


def clean_out():
    os.makedirs(OUT, exist_ok=True)
    for p in glob.glob(os.path.join(OUT, "pc_*.png")):
        os.remove(p)


# ---------------------------------------------------------------- characters
def anims_for(c, view):
    """-> list of (anim name, sheet path)"""
    f, st, ex = c["folder"], c["style"], c["extra"]
    out = []
    if c["role"] == "npc":
        out.append(("idle", find_sheet(f, ex.get("idle", "Idle"))))
        return [o for o in out if o[1]]
    if st == "plain":
        for a in ("Idle", "Run", "Hit", "Death", "Attack"):
            p = find_sheet(f, a)
            if p:
                out.append((a.lower(), p))
        return out
    V = {"side": "Side", "down": "Down", "up": "Up"}[view]
    names = [("idle", "Idle"), ("run", "Run"), ("run", "Move"), ("hit", "Hit"), ("death", "Death")]
    for an, a in names:
        if any(o[0] == an for o in out):
            continue
        p = find_sheet(f, a + "_" + V)
        if p is None:
            p = find_sheet(f, a + "_Base/" + a + "_" + V)
        if p:
            out.append((an, p))
    for an in ("attack", "pierce", "crush"):
        if an in ex:
            v = V
            p = find_sheet(f, ex[an] + "_" + v) or (find_sheet(f, ex[an] + "_Top") if v == "Up" else None)
            if p:
                out.append((an, p))
    return out


def build_char(cid, c, anims):
    flip = cid in FLIP or c["id"] in FLIP
    cuts = {}
    for an, p in anims:
        fr, fw = cut(p, flip)
        cuts[an] = (fr, fw, p)
    ref = cuts["idle"][0][0]
    rx, rb = anchor0(ref)
    BIG = 400
    AX, AY = BIG // 2, 300                      # anchor (feet) on the work canvas
    refpos = (int(round(AX - rx)), AY - rb)
    placed = {}
    for an, (fr, fw, p) in cuts.items():
        if an == "idle":
            pos = refpos
        else:
            x, b = anchor0(fr[0])
            pos = refine(ref, refpos, fr[0], (int(round(AX - x)), AY - b))
        placed[an] = [(f, pos) for f in fr]
    # union bbox
    xs0, ys0, xs1, ys1 = [], [], [], []
    for lst in placed.values():
        for f, (px, py) in lst:
            bb = f.getbbox()
            if bb:
                xs0.append(px + bb[0]); ys0.append(py + bb[1]); xs1.append(px + bb[2]); ys1.append(py + bb[3])
    half = int(max(AX - min(xs0), max(xs1) - AX) + 1)
    top = int(min(ys0) - 1)
    bottom = int(max(AY, max(ys1)) + 1)
    W, H = 2 * half, bottom - top
    feet = (half, AY - top)
    counts, written = {}, []
    for an, lst in placed.items():
        for i, (f, (px, py)) in enumerate(lst):
            cv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            cv.paste(f, (px - (AX - half), py - top), f)
            fn = "%s_%s_anim_f%d.png" % (cid, an, i)
            cv.save(os.path.join(OUT, fn))
            written.append((an, i, cv))
        counts[an] = len(lst)
    # visible body from idle
    ib = [f.getbbox() for f, _ in placed["idle"]]
    bh = max(b[3] - b[1] for b in ib if b)
    bw = max(b[2] - b[0] for b in ib if b)
    info = dict(pack=c["pack"], role=c["role"],
                sources={an: os.path.relpath(p, X) for an, (fr, fw, p) in cuts.items()},
                source_frame_px={an: [fw, fr[0].height] for an, (fr, fw, p) in cuts.items()},
                canvas=[W, H], feet=list(feet), frames=counts, body_height=int(bh), body_width=int(bw),
                radius=int(max(3, round(min(bw, bh) * 0.38))), flipped=bool(flip), notes="")
    return info, written


def contact(title, rows, path, scale=3):
    """rows: list of (label, [images]) all same canvas per char"""
    lab_w = 150
    cw = max(sum(im.width for im in ims) + 4 * len(ims) for _, ims in rows) * scale + lab_w
    ch = sum(max(im.height for im in ims) * scale + 6 for _, ims in rows) + 16
    sheet = Image.new("RGBA", (cw, ch), BG)
    d = ImageDraw.Draw(sheet)
    d.text((4, 2), title, fill=(255, 255, 255))
    y = 16
    for label, ims in rows:
        d.text((4, y + 2), label, fill=(220, 220, 120))
        x = lab_w
        h = max(im.height for im in ims)
        for im in ims:
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            d.rectangle([x - 1, y - 1, x + big.width, y + big.height], outline=(60, 60, 80))
            sheet.alpha_composite(big, (x, y))
            x += big.width + 4 * scale
        y += h * scale + 6
    sheet.save(path)


def do_cast(meta):
    by_pack = {}
    for c in CAST:
        views = ["side", "down", "up"] if c["style"] == "side" else ["side"]
        for v in views:
            cid = c["id"] if v == "side" else c["id"] + "_" + v
            anims = anims_for(c, v)
            if not anims or anims[0][0] != "idle":
                print("MISSING idle", cid); continue
            info, written = build_char(cid, c, anims)
            meta[cid] = info
            by_pack.setdefault(c["pack"], []).append((cid, info, written))
            print("%-26s %-9s canvas %3dx%-3d %s" % (cid, c["pack"][:9], info["canvas"][0], info["canvas"][1],
                  " ".join("%s:%d/%dpx" % (a, n, info["source_frame_px"][a][0]) for a, n in info["frames"].items())))
    for pack, lst in by_pack.items():
        rows = []
        for cid, info, written in lst:
            for an in info["frames"]:
                ims = [cv for a, i, cv in written if a == an]
                # baseline: mark feet row on a copy
                marked = []
                for im in ims:
                    m = Image.new("RGBA", im.size, (0, 0, 0, 0))
                    md = ImageDraw.Draw(m)
                    md.line([0, info["feet"][1] - 1 + 1, im.width, info["feet"][1]], fill=(70, 140, 70, 255))
                    m.alpha_composite(im)
                    marked.append(m)
                rows.append(("%s %s" % (cid.replace("pc_", ""), an), marked))
        contact(pack, rows, os.path.join(SCR, "cast_" + pack.replace(" ", "_") + ".png"))
    return by_pack


def lineup(meta, ids, path, scale=4):
    ims = []
    for cid in ids:
        ims.append((cid, Image.open(os.path.join(OUT, cid + "_idle_anim_f0.png")), meta[cid]["feet"]))
    above = max(f[1] for _, _, f in ims)
    below = max(im.height - f[1] for _, im, f in ims)
    W = sum(im.width + 6 for _, im, _ in ims) + 6
    H = above + below + 14
    sh = Image.new("RGBA", (W, H), BG)
    x = 6
    for cid, im, f in ims:
        sh.alpha_composite(im, (x, above - f[1] + 2))
        x += im.width + 6
    sh = sh.resize((W * scale, H * scale), Image.NEAREST)
    d = ImageDraw.Draw(sh)
    d.line([0, (above + 2) * scale, W * scale, (above + 2) * scale], fill=(80, 200, 80))
    x = 6
    for cid, im, f in ims:
        d.text((x * scale, (H - 10) * scale + 4), cid.replace("pc_", ""), fill=(230, 230, 230))
        x += im.width + 6
    sh.save(path)



HAND_NOTE = ("Hero idle/run sheets carry no weapon. The pack's own attack sheets (Body_A / Hunter pierce, "
             "frame 0) hold the weapon grip about 2 px in front of the body centre and 9-10 px above the feet "
             "(about 1/3 of body height), blade along the aim; draw a pc_hand_* piece on the grip. "
             "Free Pack heroes are 29-32 px tall, so use the same offset.")
NOTES = {
    "pc_knight": "Free Pack hero. No hit animation in the pack (flash the idle). Death 6 frames (48 px source frames).",
    "pc_rogue": "Free Pack hero. No hit animation in the pack. Death 6 frames.",
    "pc_wizard": "Free Pack hero ('Wizzard' in the pack). No hit animation. Death 6 frames (64x32 source frames).",
    "pc_hunter": "Cemetery character on the Body_A body. No death animation in the pack. attack = Slice (has a big white slash arc baked in), extra pierce/crush sets with weapons baked in.",
    "pc_body_a": "Bare base body (meant to be dressed with clothes layers the pack does not include here). attack = Slice with white slash arc baked in.",
    "pc_bat_small": "Idle = hanging upside down (roosting); run (Move) is the flying loop: use run as the idle while flying.",
    "pc_bat_fur": "Idle is a hovering pose; run = Move. Side view.",
    "pc_stone_base": "Forge: no hit animation. Death starts with a short crouch, then a bigger rising frame (as drawn).",
    "pc_skeleton_base": "No hit animation in the pack (all Free Pack mobs). Death 8 frames from 96 px source frames.",
}
for _k in ("pc_stone_broken", "pc_stone_lava", "pc_stone_golem", "pc_rat_base", "pc_rat_warrior", "pc_rat_rogue",
           "pc_rat_mage", "pc_mummy_base", "pc_mummy_warrior", "pc_mummy_rogue", "pc_mummy_mage",
           "pc_skeleton_warrior", "pc_skeleton_rogue", "pc_skeleton_mage", "pc_orc_base", "pc_orc_warrior",
           "pc_orc_rogue", "pc_orc_shaman"):
    NOTES.setdefault(_k, "No hit animation in the pack: flash/tint the idle frame instead.")

def main():
    os.makedirs(SCR, exist_ok=True)
    clean_out()
    meta = {}
    do_cast(meta)
    do_weapons(meta)
    for cid, info in meta.items():
        base = cid.replace("_down", "").replace("_up", "")
        if cid in NOTES:
            info["notes"] = NOTES[cid]
        elif base in NOTES:
            info["notes"] = NOTES[base]
        if info.get("role") == "hero":
            info["hand_and_weapon"] = HAND_NOTE
        if cid.endswith("_down") or cid.endswith("_up"):
            info["notes"] = (info.get("notes", "") + " Facing " + cid.rsplit("_", 1)[1] + " (front/back view).").strip()
    with open(os.path.join(OUT, "pc_cast.json"), "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)
    lineup(meta, ["pc_knight", "pc_rogue", "pc_wizard", "pc_hunter", "pc_skeleton_base", "pc_orc_base",
                  "pc_zombie_base", "pc_royal_knight", "pc_stone_golem", "pc_fungus_heavy", "pc_rat_base",
                  "pc_mummy_base", "pc_scholar_director", "pc_bandit_fighter", "pc_medusa", "pc_elf_base",
                  "pc_bat_fur", "pc_bat_small"], os.path.join(SCR, "lineup_x4.png"))
    print("ids:", len(meta), "pngs:", len(glob.glob(os.path.join(OUT, "pc_*.png"))))


# ---------------------------------------------------------------- weapons
# set name -> (sheet path under X, horizontal cut lines [(y, x0, x1)], vertical cut lines [(x, y0, y1)])
# The sheets stack items in bands that touch (a sword's pommel touches the hammer below it), so the
# band lines were read off labelled overviews and are cut before finding the separate pieces.
def _full(ys, w=999):
    return [(y, 0, w) for y in ys]

WEAPON_SHEETS = [
    ("castle", "Pixel_Crawler_-_Castle_Environment_0.3/Pixel Crawler - Castle Environment 0.3/Weapons/Weapons.png", _full([64, 128]), []),
    ("cemetery", "Pixel_Crawler_-_Cemetery_0.4/Pixel Crawler - Cemetery/Weapons/Cursed Weapons.png", _full([48]), []),
    ("garden", "Pixel_Crawler_-_Garden_Environment/Pixel Crawler - Garden Environment/Weapons/Weapons.png", _full([64, 128, 160, 224, 288]) + [(274, 128, 160)], [(146, 224, 288)]),
    ("cave", "Pixel_Crawler_-_Cave/Pixel Crawler - Cave/Weapons/Spore_Roots/Spore_Roots.png", _full([64, 128]), []),
    ("desert", "Pixel_Crawler_-_Desert/Pixel Crawler - Desert/Weapons/Desert - gold/Desert-Gold.png", _full([48]), [(112, 48, 80), (128, 48, 80)]),
    ("library", "Pixel_Crawler_-_Library/Pixel Crawler - Library/Weapons/Weapons.png", _full([112]) + [(96, 128, 160)], []),
    ("sewer", "Pixel_Crawler_-_Sewer/Pixel Crawler - Sewer/Weapons/Poison Weapons/Poison Weapons.png", _full([48]) + [(16, 112, 144)], []),
    ("elf", "Pixel_Crawler_-_Fairy_Forest_1.7/Pixel Crawler - Fairy Forest 1.7/Weapon/Elf_Weapon.png", _full([48]), []),
    ("forge", "Pixel_Crawler_-_Forge_1.2/Pixel Crawler - Forge/Weapons/Fire Weapons/Fire Weapons.png", _full([48]), [(128, 0, 48)]),
    ("wood", FP + "/Weapons/Wood/Wood.png", _full([48]), []),
    ("bone", FP + "/Weapons/Bone/Bone.png", [(48, 16, 224)], []),
    ("hideout", "Pixel_Crawler_-_Hideout_1.0/Pixel Crawler - Hideout/Weapons/Rustic.png", _full([64, 128]), [(144, 96, 112), (160, 96, 112)]),
]
HANDS = FP + "/Weapons/Hands/Hands.png"


def components(a):
    """8-connected pieces of a bool mask -> list of (x0, y0, x1, y1, mask)."""
    H, W = a.shape
    lab = -np.ones((H, W), int)
    out = []
    for y in range(H):
        for x in range(W):
            if a[y, x] and lab[y, x] < 0:
                k = len(out)
                st = [(y, x)]
                lab[y, x] = k
                pts = []
                while st:
                    cy, cx = st.pop()
                    pts.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and lab[ny, nx] < 0:
                                lab[ny, nx] = k
                                st.append((ny, nx))
                ys = [p[0] for p in pts]; xs = [p[1] for p in pts]
                out.append([min(xs), min(ys), max(xs) + 1, max(ys) + 1, k])
    return out, lab


def is_bow_right(m):
    """An upright bow drawn facing right: hollow and mirror-symmetric top/bottom (scythes, rods and
    staves are not symmetric; round shields are not hollow). Misses are listed in BOWS_EXTRA."""
    h, w = m.shape
    if h < 24 or w < 8 or h < 1.3 * w:
        return False
    if m.sum() > 0.6 * h * w:
        return False
    f = m[::-1]
    return (m & f).sum() / max(1, (m | f).sum()) >= 0.85


# upright bows (facing right) that the symmetry test misses, by output id; checked on the weapons sheet
BOWS_EXTRA = set()


def kind_guess(m, rotated_from):
    h, w = m.shape
    if rotated_from == "arrow":
        return "arrow"
    if rotated_from == "bow":
        return "bow"
    if rotated_from == "crossbow":
        return "crossbow"
    if max(w, h) <= 9:
        return "hand"
    if w <= 7 and h <= 16:
        return "grip"
    rows = m.sum(1)
    if w >= 12 and h <= 2.2 * w and rows[h // 3: 2 * h // 3].mean() >= 0.6 * w:
        return "shield_or_book"
    top = rows[: max(1, int(h * 0.35))]
    bottom = rows[h // 2:]
    head, shaft = top.max(), np.median(bottom)
    if h >= 56:
        return "polearm (axe/hammer head)" if head >= 10 else "spear_or_staff"
    if head >= 10 and head >= 2.5 * shaft:
        return "axe_hammer_or_tool"
    if np.median(rows[: int(h * 0.6)]) >= 4:
        return "sword" if h >= 30 else "dagger"
    return "staff_or_wand"


def do_weapons(meta):
    pieces = []
    for setname, rel, hcuts, vcuts in WEAPON_SHEETS + [("hands", HANDS, [], [])]:
        img = Image.open(os.path.join(X, rel)).convert("RGBA")
        A = np.array(img)
        mask = A[:, :, 3] > 0
        comps, lab = components_with_cuts(mask, hcuts, vcuts)
        items = []
        for x0, y0, x1, y1, k in comps:
            m = lab[y0:y1, x0:x1] == k
            if m.sum() < 6:
                continue
            # two bows drawn side by side and touching: split at the thinnest middle column
            h, w = m.shape
            if w >= 26 and h >= 24:
                cnt = m.sum(0)
                lo, hi = w // 3, 2 * w // 3
                c = lo + int(np.argmin(cnt[lo:hi]))
                if m[:, :c].sum() > 0.3 * m.sum() and m[:, c:].sum() > 0.3 * m.sum():
                    items.append((x0, y0, x0 + c, y1, k)); items.append((x0 + c, y0, x1, y1, k))
                    continue
            items.append((x0, y0, x1, y1, k))
        items.sort(key=lambda b: (b[1] // 16, b[0]))
        n = 0
        for x0, y0, x1, y1, k in items:
            m = lab[y0:y1, x0:x1] == k
            crop = A[y0:y1, x0:x1].copy()
            crop[~m] = 0
            im = Image.fromarray(crop)
            bb = im.getbbox()
            im = im.crop(bb)
            m = np.array(im)[:, :, 3] > 0
            h, w = m.shape
            rot = None
            if setname != "hands":
                if w > 1.3 * h and m.sum() < 0.6 * h * w:   # arrow / crossbow lying sideways, tip right -> up
                    rot = "arrow" if h <= 8 else "crossbow"
                    im = im.transpose(Image.ROTATE_90)
                elif is_bow_right(m) or ("pc_weapon_%s_%d" % (setname, n)) in BOWS_EXTRA:
                    rot = "bow"
                    im = im.transpose(Image.ROTATE_90)
            m = np.array(im)[:, :, 3] > 0
            kind = kind_guess(m, rot)
            if setname == "hands" or kind == "hand":
                cid = "pc_hand_%s_%d" % (setname if setname != "hands" else "base", n)
            else:
                cid = "pc_weapon_%s_%d" % (setname, n)
            n += 1
            im.save(os.path.join(OUT, cid + ".png"))
            meta[cid] = dict(pack=rel.split("/")[0], role="hand" if cid.startswith("pc_hand") else "weapon",
                             sources={"still": rel}, source_rect=[int(x0), int(y0), int(x1), int(y1)],
                             size=[im.width, im.height], kind=kind,
                             rotated="90 ccw (was pointing right)" if rot else "none",
                             notes="kind is guessed from the shape; check the weapons sheet")
            pieces.append((cid, im))
        print("weapons %-9s %d pieces" % (setname, n))
    # contact sheet
    s = 3
    cols = 24
    cell = 34
    rows = (len(pieces) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell * s, rows * (cell + 10) * s), BG)
    d = ImageDraw.Draw(sheet)
    for i, (cid, im) in enumerate(pieces):
        cx, cy = (i % cols) * cell * s, (i // cols) * (cell + 10) * s
        sc = s if max(im.size) <= cell else max(1, s * cell // max(im.size))
        big = im.resize((im.width * sc, im.height * sc), Image.NEAREST)
        sheet.alpha_composite(big, (cx + (cell * s - big.width) // 2, cy + (cell * s - big.height)))
        d.text((cx + 2, cy + cell * s + 2), cid.replace("pc_weapon_", "").replace("pc_hand_", "h:"), fill=(220, 220, 120))
    sheet.save(os.path.join(SCR, "weapons.png"))


def components_with_cuts(mask, hcuts, vcuts):
    """Label pieces, never linking across a cut line."""
    H, W = mask.shape
    blockv = np.zeros((H + 1, W), bool)   # blockv[y, x]: no link between row y-1 and y at column x
    blockh = np.zeros((H, W + 1), bool)   # blockh[y, x]: no link between col x-1 and x at row y
    for y, x0, x1 in hcuts:
        if 0 < y < H:
            blockv[y, max(0, x0 - 1):min(W, x1 + 1)] = True
    for x, y0, y1 in vcuts:
        if 0 < x < W:
            blockh[max(0, y0):min(H, y1), x] = True
    lab = -np.ones((H, W), int)
    out = []
    for y in range(H):
        for x in range(W):
            if mask[y, x] and lab[y, x] < 0:
                k = len(out)
                st = [(y, x)]
                lab[y, x] = k
                b = [x, y, x + 1, y + 1]
                while st:
                    cy, cx = st.pop()
                    b = [min(b[0], cx), min(b[1], cy), max(b[2], cx + 1), max(b[3], cy + 1)]
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if not (0 <= ny < H and 0 <= nx < W) or not mask[ny, nx] or lab[ny, nx] >= 0:
                                continue
                            if dy == 1 and blockv[ny, cx] or dy == -1 and blockv[cy, cx]:
                                continue
                            if dx == 1 and blockh[cy, nx] or dx == -1 and blockh[cy, cx]:
                                continue
                            lab[ny, nx] = k
                            st.append((ny, nx))
                b.append(k)
                out.append(b)
    return out, lab


if __name__ == "__main__":
    main()
