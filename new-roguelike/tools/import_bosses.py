#!/usr/bin/env python3
"""Boss importer for Cursebait (free, human-made boss packs).

Run from anywhere:   python3 -I tools/import_bosses.py
Optional previews:   python3 -I tools/import_bosses.py --preview /abs/dir
                     (one contact sheet per boss in <dir>/sheets/ and <dir>/lineup.png)

Reads ONLY the archives in assets_raw/bosses/<slug>/ (read straight from the zips, nothing is extracted or run).
Writes assets/art/boss/:
    boss_<name>_<anim>_anim_f<n>.png    every animation of one boss on ONE shared canvas (feet fixed)
    boss_fx_<name>_anim_f<n>.png        effect sprites that belong to a boss (own canvas each)
    boss_cast.json                      measurements, licences, hit frames, spawn points, notes
Idempotent: deletes and rewrites only boss_*.png and boss_cast.json in that folder; output is byte-identical.

Pixels are only cut, cropped, padded and mirrored. Nothing is drawn or recoloured.
All bosses face RIGHT (like the Pixel Crawler cast): left-facing sources are mirrored as a whole.
"""
import io
import json
import os
import re
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets_raw", "bosses")
OUT = os.path.join(ROOT, "assets", "art", "boss")

# ---------------------------------------------------------------- packs
PACKS = {
    "ansimuz": dict(dir="ansimuz_legacy_collection", zip="Legacy_Collection_bosses_trimmed.zip",
                    pack="ansimuz Legacy Collection (Gothicvania)", licence="CC0 1.0 (no attribution needed)",
                    credit=None),
    "chierit_slime": dict(dir="chierit_free_bosses", zip="boss_demon_slime_FREE_v1.0.zip",
                          pack="chierit Boss: Demon Slime (free)", licence="CC-BY 4.0, do not resell",
                          credit="chierit (https://chierit.itch.io)"),
    "chierit_frost": dict(dir="chierit_free_bosses", zip="Frost_Guardian_FREE_v1.0.zip",
                          pack="chierit Boss: Frost Guardian (free)", licence="CC-BY 4.0, do not resell",
                          credit="chierit (https://chierit.itch.io)"),
    "chierit_mino": dict(dir="chierit_free_bosses", zip="mino_v1.1_free.zip",
                         pack="chierit Boss: Minotaur (free)", licence="CC-BY 4.0, do not resell",
                         credit="chierit (https://chierit.itch.io)"),
    "chierit_cthulu": dict(dir="chierit_free_bosses", zip="free_cthulu_v1.zip",
                           pack="chierit Free Cthulu", licence="CC-BY 4.0, do not resell",
                           credit="chierit (https://chierit.itch.io)"),
    "kronovi": dict(dir="kronovi_mecha_stone_golem", zip="Mecha-stone Golem 0.1.zip",
                    pack="Kronovi Mecha-Stone Golem [FREE]",
                    licence="free, commercial use and editing allowed, no resale/redistribution",
                    credit=None),
    "admurin": dict(dir="admurin_bosses_gollux", zip="Bosses_Gollux.zip", pack="Admurin Bosses - Gollux",
                    licence="free, commercial use and modification allowed, no resale/NFT/AI training",
                    credit=None),
}

GV = "Legacy Collection/Assets/Gothicvania/Characters/"
KR = "Mecha-stone Golem 0.1/"
DS = "boss_demon_slime_FREE_v1.0/individual sprites/"
FG = "Frost_Guardian_FREE_v1.0/PNG files/"
MI = "mino_v1.1_free/animations/"
CT = "free_cthulu/animations/PNG/"
GO = "Gollux/"


# Source kinds:
#   ("files", dir)                         every PNG in dir, natural sort
#   ("strip", path, cw, ch)                horizontal strip, trailing empty cells dropped
#   ("grid", path, cw, ch, row, n)         n cells of one grid row
#   ("gridrows", path, cw, ch, [rows])     all non-empty cells of several rows, row-major
#   ("vstrip", path, cw, ch)               vertical strip, empty cells dropped
# Each anim: (name, source, offset) ; offset = where this anim's cell origin sits in the boss's reference cell
# (measured by pixel matching where cells differ, see notes).
def A(name, src, off=(0, 0)):
    return (name, src, off)


BOSSES = [
    dict(id="fire_skull", pk="ansimuz", mirror=True, floats=True, anims=[
        A("idle", ("files", GV + "Fire-Skull-Files/Sprites/Fire")),
        A("nofire", ("files", GV + "Fire-Skull-Files/Sprites/NoFire"), (16, 32)),
    ], notes="Floating flaming skull: no attack, hit or death animation in the pack (fire on = idle; 'nofire' is the bare "
             "skull, 54x70 cells, placed at (16,32) in the 96x112 fire cell by an exact pixel match). Feet = bottom of "
             "the flames (it floats, no shadow)."),
    dict(id="ogre", pk="ansimuz", mirror=True, anims=[
        A("idle", ("files", GV + "Ogre/Sprites/Idle")),
        A("run", ("files", GV + "Ogre/Sprites/walk")),
        A("attack", ("files", GV + "Ogre/Sprites/Attack")),
        A("idle_unarmed", ("files", GV + "Ogre/Sprites/idle-unarmed")),
        A("run_unarmed", ("files", GV + "Ogre/Sprites/walk-unarmed")),
    ], notes="No hit or death animation in the pack. Club overhead smash."),
    dict(id="demon_slime", pk="chierit_slime", mirror=True, gif=DS.replace("individual sprites/", "gifs/"), anims=[
        A("idle", ("files", DS + "01_demon_idle")),
        A("run", ("files", DS + "02_demon_walk")),
        A("attack", ("files", DS + "03_demon_cleave")),
        A("hit", ("files", DS + "04_demon_take_hit")),
        A("death", ("files", DS + "05_demon_death")),
    ], notes="Free version = demon form only (the slime form is in the paid version)."),
    dict(id="demon", pk="ansimuz", mirror=True, floats=True, anims=[
        A("idle", ("files", GV + "demon-Files/Sprites/Idle"), (56, 44)),
        A("attack", ("files", GV + "demon-Files/Sprites/DemonAttack")),
        A("attack2", ("files", GV + "demon-Files/Sprites/DemonAttackBreath")),
    ], fx=[
        ("demon_fireball", ("strip", GV + "demon-Files/Spritesheets/breath-fire.png", 160, 96)),
        ("demon_fireball_blue", ("strip", GV + "demon-Files/Spritesheets/breath.png", 160, 96)),
    ], notes="Winged demon that hovers. Idle cells are 256x176, attack cells 312x220: idle placed at (56,44) in the "
             "attack cell (exact pixel match, 6487 of 6569 px identical). attack = swipe without breath, attack2 = same "
             "with fire breath drawn in. No walk, hit or death. Feet = lowest pixel of the hovering body (no shadow)."),
    dict(id="minotaur", pk="chierit_mino", mirror=True, anims=[
        A("idle", ("files", MI + "idle")),
        A("run", ("files", MI + "walk")),
        A("attack", ("files", MI + "atk_1")),
    ], notes="Free version has NO hit and NO death animation (paid version has them)."),
    dict(id="mecha_golem", pk="kronovi", mirror=False, floats=True, anims=[
        A("idle", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 0, 4)),
        A("run", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 0, 4)),
        A("glow", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 1, 8)),
        A("attack", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 2, 9)),
        A("block", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 3, 8)),
        A("attack2", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 4, 7)),
        A("cast", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 5, 7)),
        A("buff", ("grid", KR + "PNG sheet/Character_sheet.png", 100, 100, 6, 10)),
        A("death", ("gridrows", KR + "PNG sheet/Character_sheet.png", 100, 100, [7, 8])),
    ], fx=[
        ("mecha_golem_arm", ("strip", KR + "weapon PNG/arm_projectile.png", 100, 100)),
        ("mecha_golem_arm_glow", ("gridrows", KR + "weapon PNG/arm_projectile_glowing.png", 100, 100, [0, 1, 2])),
        ("mecha_golem_laser", ("vstrip", KR + "weapon PNG/Laser_sheet.png", 300, 100)),
    ], notes="One 1000x1000 sheet of 100x100 cells. Rows: 0 idle/move (4; run = the same 4 frames, as the pack says), "
             "1 glow 8, 2 ranged arm shot 9 (attack), 3 block 8 (page says 9), 4 melee 7 (attack2), 5 laser cast 7, "
             "6 armour buff 10 (page says 11), 7+8 defeated 14 (death; played backwards = appearance). No hit "
             "animation. Faces right in the source. Hovers: no legs, feet = bottom of the body. Laser fx: beam starts "
             "at its left end and runs to the right edge of its 300 px cell; frame 0 of the laser sheet was empty and "
             "is dropped (14 frames remain: 8 charge + 6 beam)."),
    dict(id="frost_guardian", pk="chierit_frost", mirror=True, anims=[
        A("idle", ("files", FG + "idle")),
        A("run", ("files", FG + "walk")),
        A("attack", ("files", FG + "1_atk")),
        A("hit", ("files", FG + "take_hit")),
        A("death", ("files", FG + "death")),
    ], notes=""),
    dict(id="cthulu", pk="chierit_cthulu", mirror=False, gif="free_cthulu/animations/gif_samples/", anims=[
        A("idle", ("files", CT + "idle")),
        A("run", ("files", CT + "walk")),
        A("fly", ("files", CT + "fly")),
        A("attack", ("files", CT + "1atk")),
        A("attack2", ("files", CT + "2atk")),
        A("hit", ("files", CT + "hurt")),
        A("death", ("files", CT + "death")),
    ], notes="Faces right in the source. 'fly' lifts off the ground (same feet point, body rises)."),
    dict(id="gollux", pk="admurin", mirror=False, anims=[
        A("idle", ("strip", GO + "gollux_idle.png", 128, 128), (128, 0)),
        A("run", ("strip", GO + "gollux_move.png", 384, 128)),
        A("attack", ("strip", GO + "gollux_attack_A.png", 384, 128)),
        A("attack2", ("strip", GO + "gollux_attack_B.png", 384, 128)),
        A("heal", ("strip", GO + "gollux_healing.png", 384, 128)),
        A("hit", ("strip", GO + "gollux_hit.png", 384, 128)),
    ], notes="Idle cells are 128x128, all others 384x128: idle placed at (128,0) in the 384 cell (exact pixel match "
             "with attack A frame 0). No death animation in the pack."),
    dict(id="hell_beast", pk="ansimuz", mirror=True, anims=[
        A("idle", ("files", GV + "Hell-Beast-Files/Idle/Sprites")),
        A("attack", ("files", GV + "Hell-Beast-Files/Breath/Sprites")),
        A("attack2", ("files", GV + "Hell-Beast-Files/Burn/Sprites")),
    ], fx=[
        ("hell_beast_fireball", ("files", GV + "Hell-Beast-Files/Fireball/Sprites")),
    ], notes="attack = rears up and breathes (spits the fireball fx); attack2 = 'Burn': turns into a tall fire "
             "pillar (canvas is tall because of it). No walk, hit or death. The Burn spritesheet has 74 px cells "
             "while its single sprites are 80 px: the single 80x160 sprites are used."),
    dict(id="nightmare", pk="ansimuz", mirror=True, anims=[
        A("idle", ("files", GV + "Nightmare-Files/Sprites/Idle")),
        A("run", ("files", GV + "Nightmare-Files/Sprites/Run")),
    ], notes="Fire horse. Only idle and run in the pack: no attack, hit or death."),
    dict(id="dragon", pk="ansimuz", mirror=True, anims=[
        A("idle", ("strip", GV + "Grotto-escape-2-boss-dragon/spritesheets/idle.png", 144, 64)),
        A("attack", ("strip", GV + "Grotto-escape-2-boss-dragon/spritesheets/breath.png", 144, 64)),
        A("attack2", ("strip", GV + "Grotto-escape-2-boss-dragon/spritesheets/tail.png", 144, 64)),
    ], notes="Grotto Escape 2 boss dragon (small, low). attack = fire breath (fire drawn into the frames), "
             "attack2 = tail swipe. Spritesheets used (the loose sprites are named in reverse layer order). "
             "No walk, hit or death."),
    dict(id="terrible_knight", pk="ansimuz", mirror=False, anims=[
        A("idle", ("files", GV + "Terrible Knight/Sprites/Idle")),
        A("run", ("files", GV + "Terrible Knight/Sprites/Run")),
        A("hit", ("files", GV + "Terrible Knight/Sprites/Hurt")),
        A("attack", ("files", GV + "Terrible Knight/Sprites/SwordSlash")),
        A("attack2", ("files", GV + "Terrible Knight/Sprites/AttackSide")),
        A("attack3", ("files", GV + "Terrible Knight/Sprites/AttackUp")),
        A("jump", ("files", GV + "Terrible Knight/Sprites/Jump")),
        A("jump_attack", ("files", GV + "Terrible Knight/Sprites/JumpAttack")),
        A("air_slash", ("files", GV + "Terrible Knight/Sprites/AirSwordSlash")),
        A("crouch", ("files", GV + "Terrible Knight/Sprites/Crouch")),
        A("crouch_attack", ("files", GV + "Terrible Knight/Sprites/CrouchSwordSlash")),
    ], fx=[
        ("terrible_knight_dagger", ("strip", GV + "Terrible Knight/Projectiles/dagger.png", 32, 32)),
        ("terrible_knight_dagger_hit", ("files", GV + "Terrible Knight/Projectiles/Hit/Sprites")),
    ], notes="Platformer knight (mini-boss size). AttackSide = throws the dagger fx. ClimbLedge and AttackCrouch "
             "(platformer only) not imported. No death animation."),
    dict(id="death", pk="ansimuz", mirror=True, anims=[
        A("run", ("files", GV + "death/Sprites/walk")),
        A("run_nolamp", ("files", GV + "death/Sprites/No-lamp-walk")),
        A("spawn", ("files", GV + "death/Sprites/rise")),
    ], notes="Small reaper with a lamp. No idle, attack, hit or death: walk (with lamp), walk without lamp, and "
             "'rise' (comes up out of the ground: use as spawn). body size measured on run f0."),
    dict(id="mutant_toad", pk="ansimuz", mirror=False, anims=[
        A("idle", ("files", GV + "mutant-toad/Sprites/idle")),
        A("jump", ("files", GV + "mutant-toad/Sprites/jump")),
        A("attack", ("files", GV + "mutant-toad/Sprites/attack")),
    ], notes="Mini-boss size. attack = tongue lash. No hit or death."),
    dict(id="hell_hound", pk="ansimuz", mirror=True, anims=[
        A("idle", ("files", GV + "Hell-Hound-Files/Sprites/Idle")),
        A("run", ("files", GV + "Hell-Hound-Files/Sprites/Walk")),
        A("dash", ("files", GV + "Hell-Hound-Files/Sprites/Run")),
        A("jump", ("files", GV + "Hell-Hound-Files/Sprites/Jump")),
    ], notes="Mini-boss size. run = walk cycle, dash = gallop. Jump can serve as the pounce attack. No hit or death."),
    dict(id="werewolf", pk="ansimuz", mirror=False, anims=[
        A("idle", ("files", GV + "WereWolf/Sprites/Idle")),
        A("run", ("files", GV + "WereWolf/Sprites/run")),
        A("jump", ("files", GV + "WereWolf/Sprites/jump")),
        A("fall", ("files", GV + "WereWolf/Sprites/fall")),
    ], notes="Mini-boss size. Only idle, run, jump, fall: no attack, hit or death."),
]

# Manually read off the contact sheets (output coordinates: facing right, relative to the feet point, +x forward,
# -y up). hit = frames where the blow lands / the shot leaves. Filled in after looking; None = use the measured
# "reach" frame.
HITS = {
    "ogre": {"attack": [4]},                      # club hits the ground (swoosh frame)
    "mecha_golem": {"attack": [8]},               # arm is launched: the forearm is gone from frame 8
    "gollux": {"attack": [4], "attack2": [5]},    # A: ground spikes rise at 4 (to 6); B: shock wave at 5
    "demon": {"attack": [], "attack2": [6]},      # breath leaves the mouth at 6 and lasts to 15; 'attack' has no blow
    "hell_beast": {"attack": [3], "attack2": [4, 5]},  # spits the fireball fx at 3; fire pillar at 4-5
    "terrible_knight": {"attack2": [1], "attack3": [2], "air_slash": [4], "crouch_attack": [1], "jump_attack": [2]},
    "dragon": {"attack": [3, 4, 5, 6]},           # fire stream frames
}
# Projectile spawn points, measured on the frames named here (see spawn_point()):
#   beyond_idle = pixels of that frame lying right of the idle body: x = idle right edge, y = their mean row
#   rightmost   = the frame's most forward opaque pixel (hand / fist / mouth)
#   diff_attack = where the pixels that differ from the same frame of 'attack' begin (the breath's root)
#   cyan        = centre of the bright cyan crystal pixels (golem laser eye)
SPAWN = {
    "demon": {"attack2": ("diff_attack", 6)},
    "dragon": {"attack": ("beyond_idle", 3)},
    "cthulu": {"attack": ("beyond_idle", 2)},
    "mecha_golem": {"attack": ("rightmost", 7), "cast": ("cyan", 6)},
    "hell_beast": {"attack": ("rightmost", 3)},
    "terrible_knight": {"attack2": ("rightmost", 1)},
}
FPS = {}

# ---------------------------------------------------------------- helpers
_zips = {}


def zf(pk):
    p = PACKS[pk]
    path = os.path.join(RAW, p["dir"], p["zip"])
    if path not in _zips:
        _zips[path] = zipfile.ZipFile(path)
    return _zips[path]


def nkey(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def load(pk, path):
    return Image.open(io.BytesIO(zf(pk).read(path))).convert("RGBA")


def bbox(im):
    return im.getchannel("A").getbbox()


def cells(im, cw, ch, row, n=None):
    out = []
    cols = im.width // cw
    for c in range(cols if n is None else n):
        out.append(im.crop((c * cw, row * ch, c * cw + cw, row * ch + ch)))
    return out


def drop_trailing_empty(fr):
    while fr and bbox(fr[-1]) is None:
        fr.pop()
    return fr


def frames_of(pk, src):
    kind = src[0]
    if kind == "files":
        d = src[1].rstrip("/") + "/"
        names = [n for n in zf(pk).namelist() if n.startswith(d) and n.lower().endswith(".png")
                 and "/" not in n[len(d):] and not os.path.basename(n).startswith("._") and "__MACOSX" not in n]
        names.sort(key=nkey)
        return [load(pk, n) for n in names], names
    im = load(pk, src[1])
    if kind == "strip":
        return drop_trailing_empty(cells(im, src[2], src[3], 0)), [src[1]]
    if kind == "grid":
        return cells(im, src[2], src[3], src[4], src[5]), [src[1]]
    if kind == "gridrows":
        fr = []
        for r in src[4]:
            fr += [c for c in cells(im, src[2], src[3], r) if bbox(c)]
        return fr, [src[1]]
    if kind == "vstrip":
        fr = [im.crop((0, r * src[3], src[2], r * src[3] + src[3])) for r in range(im.height // src[3])]
        return [f for f in fr if bbox(f)], [src[1]]
    raise ValueError(kind)


def union(boxes):
    boxes = [b for b in boxes if b]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def spawn_point(out, anim, method, frame, feet):
    im = out[anim][frame]
    px = im.load()
    W, H = im.size
    ib = union([bbox(f) for f in out["idle"]]) if "idle" in out else bbox(out[anim][0])
    pts = []
    if method == "beyond_idle":
        pts = [(ib[2], y) for y in range(H) for x in range(ib[2], W) if px[x, y][3]]
        if not pts:
            raise SystemExit("spawn %s f%d: nothing right of the idle body" % (anim, frame))
        pt = (ib[2], round(sum(p[1] for p in pts) / len(pts)))
    elif method == "rightmost":
        bb = bbox(im)
        ys = [y for y in range(H) if px[bb[2] - 1, y][3]]
        pt = (bb[2] - 1, round(sum(ys) / len(ys)))
    elif method == "diff_attack":  # pixels added versus the same frame of 'attack' (the breath): its back end
        o = out["attack"][frame].load()
        pts = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] and px[x, y] != o[x, y]]
        x0 = min(p[0] for p in pts)
        near = [p[1] for p in pts if p[0] <= x0 + 2]
        pt = (x0, round(sum(near) / len(near)))
    else:  # cyan
        pts = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] and px[x, y][2] > 180 and px[x, y][0] < 120]
        pt = (round(sum(p[0] for p in pts) / len(pts)), round(sum(p[1] for p in pts) / len(pts)))
    return dict(frame=frame, method=method, from_feet=[pt[0] - feet[0], pt[1] - feet[1]], canvas_px=list(pt))


def gif_fps(pk, prefix):
    """Frame rate stated by the pack's own GIF previews (ms per frame), per GIF name."""
    res = {}
    for n in sorted(zf(pk).namelist()):
        if n.startswith(prefix) and n.lower().endswith(".gif") and "__MACOSX" not in n:
            g = Image.open(io.BytesIO(zf(pk).read(n)))
            d = g.info.get("duration")
            if d:
                res[os.path.basename(n)] = round(1000.0 / d, 2)
    return res


def save(im, name):
    im.save(os.path.join(OUT, name), optimize=False)


# ---------------------------------------------------------------- main import
def import_boss(b, cast):
    pk = b["pk"]
    anims = []  # (name, [frames], offset, sources, cellsize)
    for name, src, off in b["anims"]:
        fr, srcs = frames_of(pk, src)
        anims.append((name, fr, off, srcs, list(fr[0].size)))
    U = union([(bb[0] + off[0], bb[1] + off[1], bb[2] + off[0], bb[3] + off[1])
               for _, fr, off, _, _ in anims for bb in map(bbox, fr) if bb])
    x0, y0 = U[0] - 1, U[1] - 1
    W, H = U[2] - U[0] + 2, U[3] - U[1] + 2
    out = {}
    for name, fr, off, _, _ in anims:
        lst = []
        for f in fr:
            c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            c.paste(f, (off[0] - x0, off[1] - y0))
            if b["mirror"]:
                c = c.transpose(Image.FLIP_LEFT_RIGHT)
            lst.append(c)
        out[name] = lst
    ref = "idle" if "idle" in out else anims[0][0]
    ib = union([bbox(f) for f in out[ref]])
    feet = [(ib[0] + ib[2]) // 2, ib[3] - 1]
    b0 = bbox(out[ref][0])
    bw, bh = b0[2] - b0[0], b0[3] - b0[1]
    for name, lst in out.items():
        for i, f in enumerate(lst):
            save(f, "boss_%s_%s_anim_f%d.png" % (b["id"], name, i))
    # measured reach per attack-like anim: frame whose pixels reach furthest forward (right)
    reach = {}
    for name, lst in out.items():
        if name.startswith(("attack", "jump_attack", "air_slash", "crouch_attack")):
            r = [bbox(f)[2] - 1 - feet[0] if bbox(f) else -999 for f in lst]
            m = max(r)
            reach[name] = dict(frames=[i for i, v in enumerate(r) if v >= m - 1], forward_px=m)
    hit = {}
    for name in reach:
        hit[name] = HITS.get(b["id"], {}).get(name, reach[name]["frames"])
    fps = FPS.get(b["id"], {})
    if b.get("gif"):
        g = gif_fps(pk, b["gif"])
        vals = sorted(set(g.values()))
        fps = dict({"all_gifs": vals[0]} if len(vals) == 1 else g, **fps)
    P = PACKS[pk]
    cast["boss_" + b["id"]] = dict(
        pack=P["pack"], licence=P["licence"], credit=P["credit"], archive="assets_raw/bosses/%s/%s" % (P["dir"], P["zip"]),
        sources={n: s for n, _, _, s, _ in anims}, source_frame_px={n: c for n, _, _, _, c in anims},
        source_offsets={n: list(o) for n, _, o, _, _ in anims if o != (0, 0)},
        mirrored=b["mirror"], canvas=[W, H], feet=feet, floats=bool(b.get("floats")),
        body_width=bw, body_height=bh, radius=max(4, round(bw * 0.35)),
        frames={n: len(l) for n, l in out.items()}, source_fps=fps or None,
        hit_frames=hit, hit_frames_how="hand-picked from the contact sheet where listed in HITS, else the measured "
        "furthest-forward frame(s)", reach_measured=reach, projectile_spawn={a: spawn_point(out, a, m, f, feet) for a, (m, f) in SPAWN.get(b["id"], {}).items()},
        fx=["boss_fx_" + f[0] for f in b.get("fx", [])], notes=b["notes"])
    for fxid, src in b.get("fx", []):
        fr, srcs = frames_of(pk, src)
        u = union([bbox(f) for f in fr])
        lst = []
        for f in fr:
            c = f.crop((u[0] - 1, u[1] - 1, u[2] + 1, u[3] + 1))
            if b["mirror"]:
                c = c.transpose(Image.FLIP_LEFT_RIGHT)
            lst.append(c)
            save(c, "boss_fx_%s_anim_f%d.png" % (fxid, len(lst) - 1))
        cast["boss_fx_" + fxid] = dict(
            pack=P["pack"], licence=P["licence"], credit=P["credit"], owner="boss_" + b["id"], sources=srcs,
            source_frame_px=list(fr[0].size), mirrored=b["mirror"], canvas=list(lst[0].size), frames=len(lst),
            source_crop=[u[0] - 1, u[1] - 1, u[2] + 1, u[3] + 1], notes=FXNOTES.get(fxid, ""))
    return out, feet


FXNOTES = {
    "demon_fireball_blue": "Blue = the colour of the breath drawn into boss_demon attack2 (source file breath.png).",
    "demon_fireball": "Orange version of the same burst (source breath-fire.png). f0 = falling fireball, f1-4 = burst.",
    "hell_beast_fireball": "Points forward (right after mirroring). Loop all 3 frames in flight.",
    "mecha_golem_arm": "The launched forearm, fist pointing right, same art as the arm in attack f7.",
    "mecha_golem_arm_glow": "Glowing version of the forearm, 6 frames (3x3 grid of 100 px cells, empty cells dropped).",
    "mecha_golem_laser": "f0-7 charge spark, f8-13 beam. Emitter = left end at the vertical middle; the beam runs to "
                         "the right edge (272 px), so stretch or tile it in code for a longer beam.",
    "terrible_knight_dagger": "Thrown dagger, still image, pointing right.",
    "terrible_knight_dagger_hit": "Dagger impact burst, 3 frames.",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("boss_") and (f.endswith(".png") or f == "boss_cast.json"):
            os.remove(os.path.join(OUT, f))
    cast = {}
    results = {}
    for b in BOSSES:
        results[b["id"]] = import_boss(b, cast)
        print("boss_%s %s" % (b["id"], cast["boss_" + b["id"]]["canvas"]))
    with open(os.path.join(OUT, "boss_cast.json"), "w") as fh:
        json.dump(cast, fh, indent=1, sort_keys=True)
        fh.write("\n")
    if "--preview" in sys.argv:
        previews(sys.argv[sys.argv.index("--preview") + 1], results, cast)


# ---------------------------------------------------------------- previews (scratch only)
BG = (26, 26, 36, 255)


def previews(pdir, results, cast):
    sd = os.path.join(pdir, "sheets")
    os.makedirs(sd, exist_ok=True)
    font = ImageFont.load_default()
    S = 3
    for bid, (out, feet) in results.items():
        c = cast["boss_" + bid]
        W, H = c["canvas"]
        per = max(1, min(10, 2400 // (W * S + 4)))
        rows = []
        for name, lst in out.items():
            for k in range(0, len(lst), per):
                rows.append((name if k == 0 else "", lst[k:k + per], k))
        sw = 110 + per * (W * S + 4)
        sh = 16 + sum(H * S + 14 for _ in rows)
        sheet = Image.new("RGBA", (sw, sh), BG)
        d = ImageDraw.Draw(sheet)
        d.text((4, 2), "boss_%s  canvas %dx%d  feet %s  body %dx%d  mirrored=%s" % (
            bid, W, H, feet, c["body_width"], c["body_height"], c["mirrored"]), fill=(255, 255, 255, 255), font=font)
        y = 16
        for name, lst, k in rows:
            d.text((4, y + 4), "%s %d" % (name, len(out[name])) if name else "", fill=(255, 220, 120, 255), font=font)
            for i, f in enumerate(lst):
                x = 110 + i * (W * S + 4)
                d.rectangle((x, y, x + W * S - 1, y + H * S - 1), fill=(34, 34, 48, 255))
                sheet.alpha_composite(f.resize((W * S, H * S), Image.NEAREST), (x, y))
                fy = y + feet[1] * S + S - 1
                d.line((x, fy, x + W * S - 1, fy), fill=(255, 60, 60, 255))
                fx = x + feet[0] * S + 1
                d.line((fx, fy - 6, fx, fy + 2), fill=(60, 255, 60, 255))
                d.text((x + 2, y + 1), str(k + i), fill=(150, 150, 170, 255), font=font)
            y += H * S + 14
        sheet.save(os.path.join(sd, "boss_%s.png" % bid))
    # line-up
    S = 4
    pc = os.path.join(ROOT, "assets", "art", "pc")
    items = []
    for pid in ("pc_knight", "pc_skeleton_base"):
        p = os.path.join(pc, pid + "_idle_anim_f0.png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            bb = bbox(im)
            items.append((pid, im, bb[3] - 1, "%dx%d" % (bb[2] - bb[0], bb[3] - bb[1])))
    for bid, (out, feet) in results.items():
        c = cast["boss_" + bid]
        ref = "idle" if "idle" in out else next(iter(out))
        items.append((bid, out[ref][0], feet[1], "%dx%d" % (c["body_width"], c["body_height"])))
    base = max(f for _, _, f, _ in items) + 1
    tw = sum(im.width * S + 12 for _, im, _, _ in items) + 12
    lw = 2600
    lines, cur, x = [], [], 0
    for it in items:
        w = it[1].width * S + 12
        if cur and x + w > lw:
            lines.append(cur)
            cur, x = [], 0
        cur.append(it)
        x += w
    lines.append(cur)
    lh = base * S + 40
    img = Image.new("RGBA", (min(tw, lw + 24), lh * len(lines)), BG)
    d = ImageDraw.Draw(img)
    for li, line in enumerate(lines):
        x = 12
        by = li * lh + base * S
        d.line((0, by, img.width, by), fill=(90, 90, 110, 255))
        for name, im, fy, size in line:
            img.alpha_composite(im.resize((im.width * S, im.height * S), Image.NEAREST), (x, by - (fy + 1) * S))
            d.text((x, by + 4), name, fill=(255, 255, 255, 255), font=font)
            d.text((x, by + 16), size, fill=(255, 220, 120, 255), font=font)
            x += im.width * S + 12
    img.save(os.path.join(pdir, "lineup.png"))


if __name__ == "__main__":
    main()
