#!/usr/bin/env python3
"""Item icon importer: one picture per item, straight out of the "Raven Fantasy Icons" pack.

Run from anywhere:   python3 -I tools/import_icons.py [--sheet /abs/dir]
then                 godot --headless --path . --import

Reads  assets_raw/icons/raven_fantasy_icons/Free - Raven Fantasy Icons.zip   (by Clockwork Raven;
       free, commercial use allowed, human-made: see SOURCE.txt and the licence PDF beside it).
       The archive is read in memory: nothing is unpacked and nothing in it is executed.
Writes assets/art/icons/icon_<item id>.png   the pack's 16x16 file, byte for byte (no pixel is
                                             drawn, recoloured or scaled)
       assets/art/icons/icons.json           item id -> the file it came from
       --sheet DIR                           also writes DIR/icons_sheet.png (every icon x4 with its
                                             item id, cursed items on the bottom rows) to LOOK at
Idempotent: it rewrites only icon_*.png and icons.json, and removes icon_*.png no row names.

Why the 16 px set: the game shows one sprite pixel as one screen pixel beside 16 px tiles
(scripts/ui/icon.gd only ever draws whole multiples), and the pack's 16 px files are its originals.

TO GIVE AN ITEM ANOTHER PICTURE: change its number below (the pack names its files fa1.png ..
fa2192.png; number = position in the pack's sheet, 16 a row), run this, run the Godot import.
Every item in scripts/data/items.gd needs a row here and "icon": "icon_<item id>" there
(./tools/check.sh says so if one is missing). No two items share a picture.
Cursed items lean on the pack's purple, dark and skull pictures where it has a fitting one.
"""
import io
import json
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
ZIP = os.path.join(GAME, "assets_raw", "icons", "raven_fantasy_icons", "Free - Raven Fantasy Icons.zip")
INSIDE = "Free - Raven Fantasy Icons/Separated Files/16x16/fa%d.png"
OUT = os.path.join(GAME, "assets", "art", "icons")

# item id: (number in the pack, what the picture shows)
ICONS = {
    # ---- plain stat items
    "whetstone": (219, "grey whetstone bar"),
    "swift_tonic": (121, "green bottle"),
    "sparking_tonic": (1025, "lightning bolt"),
    "longbow_string": (1484, "wooden longbow"),
    "crimson_draught": (281, "round red potion"),
    # ---- shot changers
    "twin_hatchets": (1467, "double-bladed axe"),
    "needle_spear": (1461, "spear"),
    "ricochet_mallet": (1477, "mallet"),
    "seeker_staff": (1690, "staff with a blue orb"),
    "wardwater": (123, "blue bottle"),
    "grave_cleaver": (1442, "cleaver"),
    "bone_thistle": (234, "three bone spikes"),
    "tethered_sickle": (1474, "blade on a chain"),
    "stonebiter": (1458, "pickaxe"),
    "reaping_hook": (1682, "reaping hook"),
    "starveling_blade": (1714, "dark blade with a bone edge"),
    "winter_nail": (1017, "icicle"),
    # ---- the Hungry Curse, not cursed
    "spiked_goad": (1506, "spiked mace head"),
    "iron_leash": (128, "iron shackles"),
    "tithe_imp": (131, "gold coin"),
    "oxbone_cudgel": (239, "heavy horn bone"),
    "cry_of_knives": (1796, "crossed knives"),
    "bitter_marrow": (231, "marrow bone"),
    "sour_gullet": (59, "cup of green bile"),
    "fasting_vow": (54, "empty wooden cup"),
    # ---- staying alive, coins, helpers
    "ransom_plate": (1927, "golden breastplate"),
    "sextons_satchel": (158, "leather pouch"),
    "sinners_locket": (2181, "locket on a chain"),
    "undertakers_due": (1471, "gravedigger's shovel"),
    "knocker_bat": (116, "iron door knocker"),
    "blood_porter": (659, "red heart"),
    "carrion_bat": (852, "rotting meat"),
    # ---- cursed (purple, dark or a skull where the pack has one that fits)
    "glass_blade": (1716, "purple glass blade"),
    "frenzy_saw": (1755, "pink saw-toothed sword"),
    "gilded_blade": (1708, "golden sword"),
    "leaden_maul": (1707, "dark maul with a purple head"),
    "storm_axes": (1702, "blue storm axe"),
    "misers_flask": (136, "golden flask"),
    "hollow_bolt": (2155, "bolt"),
    "gilded_fang": (1693, "golden fang on a purple grip"),
    "eclipse_shard": (335, "dark orb with a glowing rim"),
    "breaking_wheel": (2125, "purple spoked wheel"),
    "barrow_stone": (314, "cracked grave stone"),
    "pyre_kindling": (911, "small pyre"),
    "moth_mantle": (1954, "purple hooded mantle"),
    "ossuary_chain": (2067, "ring of bone beads"),
    "howling_scar": (863, "scarred skull"),
}


# Pictures that are not items of scripts/data/items.gd: written as <key>.png (same pack, same rules).
# GEAR (scripts/data/gear.gd, v0.12.0): helmets, armour and rings. The key is the row's "icon".
EXTRA = {
    "gear_cap_iron": (2052, "open grey helm"),
    "gear_helm_soldier": (1905, "steel helm"),
    "gear_helm_bronze": (1906, "bronze helm"),
    "gear_helm_warden": (1908, "green helm"),
    "gear_helm_ember": (1909, "orange helm"),
    "gear_helm_visor": (2053, "grey visored helm"),
    "gear_helm_gilded": (1911, "golden helm"),
    "gear_vest_padded": (2049, "grey vest"),
    "gear_plate_steel": (1921, "steel breastplate"),
    "gear_plate_bronze": (1922, "bronze breastplate"),
    "gear_mail_chain": (2050, "grey harness"),
    "gear_plate_warden": (1924, "green breastplate"),
    "gear_plate_ember": (1925, "orange breastplate"),
    "gear_plate_gilded": (1934, "golden breastplate"),
    "gear_plate_knight": (1935, "heavy steel plate"),
    "gear_ring_silver": (1843, "silver band"),
    "gear_ring_gold": (1844, "gold band"),
    "gear_ring_iron": (2061, "iron ring"),
    "gear_ring_ruby": (1845, "gold ring, red stone"),
    "gear_ring_emerald": (1846, "ring, green stone"),
    "gear_ring_sapphire": (1847, "ring, blue stone"),
    "gear_ring_jade": (2062, "iron ring, big green stone"),
    "gear_ring_ember": (2186, "ring of red and gold"),
    # SKILLS (scripts/data/skills.gd, v0.13.0). The key is the row's "icon".
    "skill_whirl": (725, "a pale swirl"),
    "skill_firebolt": (1002, "a bolt of fire"),
    "skill_lunge": (839, "a burning strike downward"),
    "skill_mend": (1042, "a golden heart"),
    "skill_cry": (987, "golden rings"),
    "skill_frost": (1014, "ice spikes"),
    "skill_slam": (1044, "a golden hammer"),
    "skill_storm": (1029, "forked lightning"),
}


def main() -> None:
    numbers = [n for n, _ in ICONS.values()] + [n for n, _ in EXTRA.values()]
    twice = sorted({n for n in numbers if numbers.count(n) > 1})
    if twice:
        sys.exit("two items share picture(s) %s" % twice)
    os.makedirs(OUT, exist_ok=True)
    wanted = {"icon_%s.png" % item for item in ICONS}
    for name in os.listdir(OUT):
        if name.startswith("icon_") and name.endswith(".png") and name not in wanted:
            os.remove(os.path.join(OUT, name))
            if os.path.exists(os.path.join(OUT, name + ".import")):
                os.remove(os.path.join(OUT, name + ".import"))
    table = {}
    data = {}
    with zipfile.ZipFile(ZIP) as z:
        for item in sorted(ICONS):
            number, what = ICONS[item]
            inside = INSIDE % number
            data[item] = z.read(inside)
            path = os.path.join(OUT, "icon_%s.png" % item)
            old = open(path, "rb").read() if os.path.exists(path) else None
            if old != data[item]:
                with open(path, "wb") as f:
                    f.write(data[item])
            table[item] = {"file": inside, "shows": what}
    extra = {}
    with zipfile.ZipFile(ZIP) as z:
        for key in sorted(EXTRA):
            number, what = EXTRA[key]
            blob = z.read(INSIDE % number)
            path = os.path.join(OUT, "%s.png" % key)
            if not os.path.exists(path) or open(path, "rb").read() != blob:
                with open(path, "wb") as f:
                    f.write(blob)
            extra[key] = {"file": INSIDE % number, "shows": what}
    out = {"pack": "Raven Fantasy Icons (free version) by Clockwork Raven",
           "url": "https://clockworkraven.itch.io/raven-fantasy-icons",
           "archive": "assets_raw/icons/raven_fantasy_icons/Free - Raven Fantasy Icons.zip",
           "icons": table, "extra": extra}
    with open(os.path.join(OUT, "icons.json"), "w", newline="\n") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print("%d item icons and %d other pictures written to %s" % (len(table), len(extra), OUT))
    if "--sheet" in sys.argv:
        from PIL import Image, ImageDraw
        sheet_dir = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(sheet_dir, exist_ok=True)
        cols, cw, ch = 8, 132, 84
        ids = list(ICONS)
        im = Image.new("RGB", (cols * cw, ((len(ids) + cols - 1) // cols) * ch), (26, 26, 36))
        d = ImageDraw.Draw(im)
        for k, item in enumerate(ids):
            r, c = divmod(k, cols)
            ic = Image.open(io.BytesIO(data[item])).convert("RGBA").resize((64, 64), Image.NEAREST)
            im.paste(ic, (c * cw + 34, r * ch + 2), ic)
            d.text((c * cw + 4, r * ch + 68), item, fill=(230, 230, 200))
        im.save(os.path.join(sheet_dir, "icons_sheet.png"))
        print("sheet:", os.path.join(sheet_dir, "icons_sheet.png"))


if __name__ == "__main__":
    main()
