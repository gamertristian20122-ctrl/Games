#!/usr/bin/env python3
"""Sound pass P06 (14 Nov 2026): turns human-made CC0 downloads into the game's sound files.

Run from the game folder:   python3 -I assets_raw/audio/build_p06_audio.py [music] [sfx] [amb]
Needs ffmpeg and numpy. Every source is fetched again (URL below) when it is not on disk and its
sha256 is checked, so the big downloads do not have to live in git.

WHAT IT DOES TO A SOUND, and nothing else: cut, fade, change the level, change the speed of a wind
gust (as the game's own pitch setting does), join pieces with a crossfade, encode to Ogg Vorbis.
NOTHING is synthesised or generated. Every file is a recording or a composition by a named person.

It writes assets_raw/audio/manifest_p06.json: every game file, its source, licence and the
loudness measured after encoding.
"""
import hashlib, json, os, subprocess, sys, urllib.parse, zipfile
import numpy as np

OGA = "https://opengameart.org/sites/default/files/"
RAW = "assets_raw/audio"
WORK = os.environ.get("P06_WORK", "/tmp/p06_audio_work")
SR = 44100

# slug -> [folder under assets_raw/audio, file on OpenGameArt, sha256, author, page, licence]
PACKS = {
    "jrpg1": ["music/src_p06/juhani_junkala_jrpg_pack_1_exploration",
        "JRPG%20Music%20Pack%20%231%20%5BExploration%5D%20by%20Juhani%20Junkala.zip",
        "115a36ca3e076e8e4bd6617a205f2b8834ea7bf250f2ba39613a7f1f1834d60a",
        "Juhani Junkala", "https://opengameart.org/content/jrpg-pack-1-exploration", "CC0"],
    "jrpg4": ["music/src_p06/juhani_junkala_jrpg_pack_4_calm",
        "JRPG%20Music%20Pack%20%234%20%5BCalm%5D%20by%20Juhani%20Junkala_0.zip",
        "cfec70dd7ead4f5a4ebc6a1da5ad12906410ad69c43f79ec6e78c6664d6dddac",
        "Juhani Junkala", "https://opengameart.org/content/jrpg-pack-4-calm", "CC0"],
    "jrpg5": ["music_src/juhani_junkala_jrpg_pack_5_action/original",
        "JRPG%20Music%20Pack%20%235%20%5BAction%5D%20by%20Juhani%20Junkala.zip",
        "5a320c6e3d60a8b69700989f84691f6d87eca86e0c2817c3586fb108b64d5ad6",
        "Juhani Junkala", "https://opengameart.org/content/jrpg-pack-5-action", "CC0"],
    "rd_rpg": ["sfx_src/rubberduck_80_cc0_rpg_sfx/original", "80-CC0-RPG-SFX_0.zip",
        "1c2f06ff4e8563b5b8b745b23cf213c1474142a69bb82bd8f5e10d9b3f7a7bbd",
        "rubberduck", "https://opengameart.org/content/80-cc0-rpg-sfx", "CC0"],
    "rd_cre2": ["sfx_src/rubberduck_80_cc0_creature_sfx_2/original", "80-CC0-creature-sfx-2.zip",
        "6d251aeaaaa9c2fffed8fc2f64bab3104725ceabf9259a8441994e7a20cfe22f",
        "rubberduck", "https://opengameart.org/content/80-cc0-creture-sfx-2", "CC0"],
    "rd_bfh": ["sfx_src/rubberduck_75_cc0_breaking_falling_hit_sfx/original", "sfx_breaking_and_falling.zip",
        "e6ee04d91c5f4d30cfda1260d2c9d1faf96fda36319287215fbd07bcb1a80451",
        "rubberduck", "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx", "CC0"],
    "rd_mw": ["sfx_src/rubberduck_100_cc0_metal_and_wood_sfx/original", "100-CC0-wood-metal-SFX.zip",
        "be6eba63b03409ac0c77787a956b1503a7c186403d04aef9725c52644a4b7878",
        "rubberduck", "https://opengameart.org/content/100-cc0-metal-and-wood-sfx", "CC0"],
    "rd_100": ["sfx_src/rubberduck_100_cc0_sfx/original", "100-CC0-SFX_0.zip",
        "a5c135878c132f1c59cca54e60061c296cd0ac27ad031ca2c41b8cd5cab3c706",
        "rubberduck", "https://opengameart.org/content/100-cc0-sfx", "CC0"],
    "rd_bang": ["sfx_src/rubberduck_25_cc0_bang_firework_sfx/original", "25-CC0-bang-sfx.zip",
        "c0c9ecc11e2dc0d190f0cced755569858234b8528286bc83becb6314c663407f",
        "rubberduck", "https://opengameart.org/content/25-cc0-bang-firework-sfx", "CC0"],
    "ad_rpg": ["sfx_src/artisticdude_rpg_sound_pack/original", "rpg_sound_pack.zip",
        "f80754a9c04854e30c9da89d0186540ad097309d98b41387b6e83029e2601421",
        "artisticdude", "https://opengameart.org/content/rpg-sound-pack", "CC0"],
    "ad_swish": ["sfx_src/artisticdude_swishes_sound_pack/original", "swishes.zip",
        "7980215241b739a787dcf26f660ce510bb237900968789395a86911619795693",
        "artisticdude", "https://opengameart.org/content/swishes-sound-pack", "CC0"],
    "k_rpg": ["sfx_src/kenney_rpg_sounds/original", "RPGsounds_Kenney.zip",
        "3ae398ad63e293f9c450bda22d5d81c3af69c74df66fc1400f33c012c0bbc231",
        "Kenney", "https://opengameart.org/content/50-rpg-sound-effects", "CC0"],
    "k_jing": ["sfx_src/kenney_music_jingles/original", "jingleSounds_Kenney.zip",
        "be324b6cf26e35c95c2a344569a2470512819d0246cc81328bef3499de3682e5",
        "Kenney", "https://opengameart.org/content/85-short-music-jingles", "CC0"],
    "k_ui": ["sfx_src/kenney_interface_sounds/original", "kenney_interfaceSounds.zip",
        "f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232",
        "Kenney", "https://opengameart.org/content/interface-sounds", "CC0"],
    "wind": ["ambience_src/p06", "wind.zip",
        "8f6185f6eb836a5c35c492e8dabd276e507ba3e4dca0e7d551d04c689d0c0d63",
        "IgnasD", "https://opengameart.org/content/wind", "CC0"],
    "dungeon": ["ambience_src/p06", "dungeon_ambient_1_0.ogg",
        "df491823e4877371c34dbda4e9321cd83a4a14fa7573cee0ebca1ae423b70e6e",
        "JaggedStone", "https://opengameart.org/content/loopable-dungeon-ambience", "CC0"],
    "crickets": ["ambience_src/p06", "crickets_1.mp3",
        "5b5bd1f744087888c5623543c3ff80be9c2ce106093993e7c8a8492b0280b2c0",
        "Wolfgang_", "https://opengameart.org/content/crickets-ambient-noise-loopable", "CC0"],
    "anvil": ["ambience_src/p06", "forger_0.ogg",
        "c62556be3d4148586100b657c97e5a30499fdc80a917bd1a2e2d1cddf5098f39",
        "themightyglider", "https://opengameart.org/content/hammer-on-anvil", "CC0"],
}

# game file (assets/audio/music/<name>.ogg) -> [pack, file in the zip, title, the role it plays]
MUSIC = {
    "room": ["jrpg4", "Calm1 - A Place I Call Home.ogg", "A Place I Call Home", "your room"],
    "hall": ["jrpg4", "Calm3 - Peaceful Days.ogg", "Peaceful Days", "the tavern hall and other insides"],
    "dustwatch": ["jrpg4", "Calm4 - Sand Castles.ogg", "Sand Castles", "Dustwatch"],
    "results": ["jrpg4", "Calm6 - Innocence.ogg", "Innocence", "the quiet loop after the victory fanfare"],
    "calm_friends": ["jrpg4", "Calm2 - Childhood Friends.ogg", "Childhood Friends", "spare: a warm story cue"],
    "calm_summer": ["jrpg4", "Calm5 - Summer Memories.ogg", "Summer Memories", "spare: a wistful story cue"],
    "road": ["jrpg1", "Exploration1 - Grasslands.ogg", "Grasslands", "the Elfwood Road"],
    "emberfall": ["jrpg1", "Exploration2 - Military Base.ogg", "Military Base", "Emberfall"],
    "suncourt": ["jrpg1", "Exploration3 - Tha'el Mines.ogg", "Tha'el Mines", "the Sunwell"],
    "beacon": ["jrpg1", "Exploration4 - Prairie Nights.ogg", "Prairie Nights", "the beacon's hill"],
    "deepwood": ["jrpg1", "Exploration5 - Sneaking Around.ogg", "Sneaking Around", "the Deepwood"],
    "boss_gorgon": ["jrpg5", "Action2 - Army Approaching.ogg", "Army Approaching", "the Dune Gorgon"],
}

# stingers and sounds: game file (assets/audio/sfx/<name>.ogg) -> [pack, file in the zip]
SFX = {
    # stingers (Kenney Music Jingles: plucked strings; the beacon gets the orchestra hits)
    "sting_level_up": ["k_jing", "OGG/jingles_PIZZA/jingles_PIZZA02.ogg"],
    "sting_quest_done": ["k_jing", "OGG/jingles_PIZZA/jingles_PIZZA10.ogg"],
    "sting_item_get": ["k_jing", "OGG/jingles_PIZZA/jingles_PIZZA12.ogg"],
    "sting_inn_rest": ["k_jing", "OGG/jingles_PIZZA/jingles_PIZZA03.ogg"],
    "sting_beacon_lit": ["k_jing", "OGG/jingles_HIT/jingles_HIT15.ogg"],
    # blades and blows
    "slash_light_1": ["k_rpg", "OGG/knifeSlice.ogg"],
    "slash_light_2": ["k_rpg", "OGG/knifeSlice2.ogg"],
    "slash_heavy_1": ["rd_rpg", "blade_02.ogg"],
    "slash_heavy_2": ["rd_rpg", "blade_03.ogg"],
    "slash_heavy_3": ["rd_rpg", "blade_01.ogg"],
    "whoosh_1": ["ad_swish", "swishes/swish-7.wav"],
    "whoosh_2": ["ad_swish", "swishes/swish-8.wav"],
    "whoosh_3": ["ad_swish", "swishes/swish-3.wav"],
    "blunt_1": ["rd_bfh", "bfh1_hit_07.ogg"],
    "blunt_2": ["rd_bfh", "bfh1_hit_06.ogg"],
    "blunt_3": ["rd_bfh", "bfh1_hit_02.ogg"],
    "crit": ["rd_mw", "metal_slam_01.ogg"],
    "guard_1": ["rd_mw", "metal_hit_01.ogg"],
    "guard_2": ["rd_mw", "metal_hit_04.ogg"],
    "miss_1": ["ad_swish", "swishes/swish-11.wav"],
    "miss_2": ["ad_swish", "swishes/swish-12.wav"],
    "bow_1": ["ad_swish", "swishes/swish-10.wav"],
    "bow_2": ["ad_swish", "swishes/swish-13.wav"],
    # spells
    "fire_1": ["rd_rpg", "spell_fire_06.ogg"],
    "fire_2": ["rd_rpg", "spell_fire_03.ogg"],
    "fire_3": ["rd_rpg", "spell_fire_04.ogg"],
    "frost_1": ["rd_bfh", "bfh1_glass_breaking_02.ogg"],
    "frost_2": ["rd_bfh", "bfh1_glass_breaking_05.ogg"],
    "bolt_1": ["rd_bang", "shot_02.ogg"],
    "bolt_2": ["rd_bang", "cannon_03.ogg"],
    "earth_1": ["rd_bfh", "bfh1_rock_falling_01.ogg"],
    "earth_2": ["rd_bfh", "bfh1_rock_falling_02.ogg"],
    "heal": ["ad_rpg", "RPG Sound Pack/battle/spell.wav"],
    "buff": ["ad_rpg", "RPG Sound Pack/battle/magic1.wav"],
    "debuff": ["rd_rpg", "chain_03.ogg"],
    "status_on": ["rd_cre2", "slime_02.ogg"],
    "potion": ["ad_rpg", "RPG Sound Pack/inventory/bottle.wav"],
    "revive": ["rd_100", "bell_03.ogg"],
    "lantern_pass": ["rd_rpg", "spell_fire_07.ogg"],
    "flare": ["rd_rpg", "spell_fire_05.ogg"],
    # menus
    "ui_move": ["k_ui", "Audio/select_002.ogg"],
    "ui_tab": ["k_ui", "Audio/drop_002.ogg"],
    "ui_equip": ["k_rpg", "OGG/clothBelt.ogg"],
    "coins": ["k_rpg", "OGG/handleCoins.ogg"],
    "page_turn_1": ["k_rpg", "OGG/bookFlip1.ogg"],
    "page_turn_2": ["k_rpg", "OGG/bookFlip2.ogg"],
    "page_turn_3": ["k_rpg", "OGG/bookFlip3.ogg"],
    "save_done": ["k_ui", "Audio/confirmation_002.ogg"],
    # the fight-start blade, loud enough to hear this time (it peaked at -23 dBFS)
    "battle_start": ["k_rpg", "OGG/drawKnife2.ogg"],
    # one ring of a hammer on an anvil, heard now and then in Emberfall (cut out of three)
    "anvil_1": ["anvil", "forger_0.ogg", 0],
    "anvil_2": ["anvil", "forger_0.ogg", 1],
    "anvil_3": ["anvil", "forger_0.ogg", 2],
}

report = {"made": "2026-11-14", "by": "assets_raw/audio/build_p06_audio.py",
    "not_listened": "Nobody has listened to any of these files yet: there is no sound device in the "
        "cloud container. Every choice was made from titles, licences and measurements.",
    "music": [], "sfx": [], "ambience": []}


def sh(*a, **k):
    return subprocess.run(a, capture_output=True, **k)


def fetch(slug):
    """The pack's download on disk (fetched when missing, sha256 checked); zips are unpacked."""
    folder, name, sha, _a, _p, _l = PACKS[slug]
    local = os.path.join(RAW, folder, name)
    if not os.path.exists(local):
        os.makedirs(os.path.dirname(local), exist_ok=True)
        r = sh("curl", "-sS", "-L", "--fail", "-o", local, OGA + name)
        if r.returncode != 0:
            sys.exit("download failed: " + name + " " + r.stderr.decode())
    got = hashlib.sha256(open(local, "rb").read()).hexdigest()
    if got != sha:
        sys.exit("sha256 of %s is %s, expected %s" % (local, got, sha))
    if not name.endswith(".zip"):
        return local
    out = os.path.join(WORK, slug)
    if not os.path.isdir(out):
        zipfile.ZipFile(local).extractall(out)
    return out


def src(slug, inner=""):
    base = fetch(slug)
    return os.path.join(base, inner) if inner else base


def decode(path, channels):
    raw = sh("ffmpeg", "-v", "error", "-i", path, "-ac", str(channels), "-ar", str(SR),
        "-f", "f32le", "-").stdout
    x = np.frombuffer(raw, dtype=np.float32)
    return x.reshape(-1, channels).copy()


def encode(x, out, quality=None, bitrate=None):
    args = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]),
        "-i", "-", "-map_metadata", "-1", "-fflags", "+bitexact", "-c:a", "libvorbis"]
    args += ["-b:a", bitrate] if bitrate else ["-q:a", str(quality)]
    r = subprocess.run(args + [out], input=x.astype(np.float32).tobytes(), capture_output=True)
    if r.returncode != 0:
        sys.exit("encode failed: " + out + " " + r.stderr.decode())


def measure(path):
    """Integrated loudness (LUFS), true peak (dBFS) and length of a file."""
    r = sh("ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-")
    text = r.stderr.decode(errors="ignore")
    lufs, peak = None, None
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("I:"):
            lufs = float(s.split()[1])
        if s.startswith("Peak:"):
            peak = float(s.split()[1])
    d = float(sh("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
        path).stdout.decode().strip())
    return lufs, peak, round(d, 3)


def db(v):
    return 20.0 * np.log10(max(float(v), 1e-9))


def seam(path):
    """How well a loop's end meets its start: the jump across the seam against the usual jump."""
    x = decode(path, 2).mean(axis=1)
    step = abs(float(x[0]) - float(x[-1]))
    usual = float(np.percentile(np.abs(np.diff(x)), 99.9))
    return {"step_at_seam": round(step, 4), "typical_large_step_p999": round(usual, 4),
        "head_50ms_dbfs": round(db(np.sqrt((x[:2205] ** 2).mean())), 1),
        "tail_50ms_dbfs": round(db(np.sqrt((x[-2205:] ** 2).mean())), 1)}


def build_music():
    for name, (slug, inner, title, role) in MUSIC.items():
        source = src(slug, inner)
        x = decode(source, 2)
        lufs0, _p, _d = measure(source)
        gain = round(-16.0 - lufs0, 1)
        y = x * (10.0 ** (gain / 20.0))
        peak = db(np.abs(y).max())
        if peak > -1.0:                       # never clip: take the gain back to leave 1 dB
            gain = round(gain - (peak + 1.0), 1)
            y = x * (10.0 ** (gain / 20.0))
        # the loop seam: a 128-sample (2.9 ms) raised-cosine ramp so the end meets the first sample
        n = 128
        ramp = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, n))[:, None]
        y[-n:] = y[-n:] * (1.0 - ramp) + y[0][None, :] * ramp
        out = "assets/audio/music/%s.ogg" % name
        encode(y, out, bitrate="96k")
        lufs, tp, dur = measure(out)
        report["music"].append({"file": name + ".ogg", "title": title, "composer": PACKS[slug][3],
            "licence": PACKS[slug][5], "page": PACKS[slug][4], "source_file": inner, "role": role,
            "gain_db": gain, "lufs": lufs, "true_peak_dbfs": tp, "seconds": dur,
            "samples_source": int(len(x)), "samples_out": int(len(decode(out, 2))), "loop_seam": seam(out)})
        print("music", name, "gain", gain, "->", lufs, "LUFS", tp, "dBTP", dur, "s")


def trim(x, floor_db=-48.0):
    """Cuts the silence off both ends (keeping 4 ms before the first sound)."""
    level = np.abs(x).max(axis=1)
    loud = np.where(level > 10.0 ** (floor_db / 20.0) * max(level.max(), 1e-9))[0]
    if len(loud) == 0:
        return x
    a = max(0, loud[0] - int(0.004 * SR))
    b = min(len(x), loud[-1] + int(0.03 * SR))
    return x[a:b]


def fades(x, head=0.002, tail=0.025):
    h, t = min(int(head * SR), len(x) // 4), min(int(tail * SR), len(x) // 2)
    if h > 0:
        x[:h] *= np.linspace(0.0, 1.0, h)[:, None]
    if t > 0:
        x[-t:] *= np.linspace(1.0, 0.0, t)[:, None]
    return x


def hits(x, n):
    """Cuts a recording of several strokes into n pieces at its quietest gaps."""
    env = np.abs(x).max(axis=1)
    win = int(0.02 * SR)
    smooth = np.convolve(env, np.ones(win) / win, mode="same")
    on = np.where((smooth[1:] > 0.25 * smooth.max()) & (smooth[:-1] <= 0.25 * smooth.max()))[0]
    starts = [on[0]]
    for i in on[1:]:
        if i - starts[-1] > int(0.25 * SR):
            starts.append(i)
    starts = starts[:n]
    cuts = [max(0, s - int(0.01 * SR)) for s in starts] + [len(x)]
    return [x[cuts[i]:cuts[i + 1]].copy() for i in range(len(starts))]


def build_sfx():
    for name, row in SFX.items():
        slug, inner = row[0], row[1]
        source = src(slug, inner) if PACKS[slug][1].endswith(".zip") else src(slug)
        x = decode(source, 1)
        if len(row) > 2:
            x = fades(trim(hits(x, 3)[row[2]]), 0.002, 0.09)     # a longer tail: the ring is cut short
        else:
            x = fades(trim(x))
        gain = -3.0 - db(np.abs(x).max())
        x *= 10.0 ** (gain / 20.0)
        out = "assets/audio/sfx/%s.ogg" % name
        encode(x, out, quality=4)
        _l, _tp, dur = measure(out)
        y = decode(out, 1)
        report["sfx"].append({"file": name + ".ogg", "author": PACKS[slug][3], "licence": PACKS[slug][5],
            "page": PACKS[slug][4], "source_file": inner, "gain_db": round(float(gain), 1),
            "peak_dbfs": round(db(np.abs(y).max()), 1), "rms_dbfs": round(db(np.sqrt((y ** 2).mean())), 1),
            "seconds": dur})
    print("sfx", len(SFX), "files")


def crossfade_join(parts, fade_s):
    """Joins pieces end to start with an equal-power crossfade."""
    n = int(fade_s * SR)
    t = np.linspace(0.0, np.pi / 2.0, n)[:, None]
    out = parts[0]
    for p in parts[1:]:
        mix = out[-n:] * np.cos(t) + p[:n] * np.sin(t)
        out = np.concatenate([out[:-n], mix, p[n:]])
    return out


def loop_seam(x, fade_s):
    """Makes a loop out of a stretch: its tail is crossfaded into its head."""
    n = int(fade_s * SR)
    t = np.linspace(0.0, np.pi / 2.0, n)[:, None]
    head = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
    return np.concatenate([head, x[n:-n]])


def speed(x, rate):
    """The same recording played slower or faster (as the game's pitch setting does)."""
    idx = np.arange(0, len(x) - 1, rate)
    lo = idx.astype(int)
    frac = (idx - lo)[:, None]
    return x[lo] * (1.0 - frac) + x[lo + 1] * frac


def to_lufs(x, target, tmp):
    encode(x, tmp, quality=6)
    lufs, _p, _d = measure(tmp)
    os.remove(tmp)
    gain = target - lufs
    return x * (10.0 ** (gain / 20.0)), round(gain, 1)


def amb_out(name, x, slug, how, target):
    x, gain = to_lufs(x, target, os.path.join(WORK, name + "_tmp.ogg"))
    out = "assets/audio/sfx/amb_%s.ogg" % name
    encode(x, out, quality=3)
    lufs, tp, dur = measure(out)
    report["ambience"].append({"file": "amb_%s.ogg" % name, "author": PACKS[slug][3],
        "licence": PACKS[slug][5], "page": PACKS[slug][4], "how": how, "gain_db": gain, "lufs": lufs,
        "true_peak_dbfs": tp, "seconds": dur, "loop_seam": seam(out)})
    print("amb", name, lufs, "LUFS", dur, "s")


def build_amb():
    # WIND: the two gusts of IgnasD's download (6.6 s each) in a row, each also once slower and
    # once faster so no two gusts are alike, crossfaded: 5.4 s of loop becomes about 29 s
    base = src("wind")
    a = decode(os.path.join(base, "wind", "Wind.ogg"), 2)
    b = decode(os.path.join(base, "wind", "Wind2.ogg"), 2)
    parts = [a, b, speed(a, 0.84), speed(b, 1.12), speed(b, 0.78), speed(a, 1.07)]
    amb_out("wind", loop_seam(crossfade_join(parts, 1.4), 1.4), "wind",
        "Wind.ogg and Wind2.ogg in a row, each again at 0.84 / 1.12 / 0.78 / 1.07 speed, "
        "1.4 s equal-power crossfades, tail crossfaded into the head", -25.0)
    # DUNGEON: the whole 94 s loop as published (the page: loopable); level only
    amb_out("cave", decode(src("dungeon"), 2), "dungeon",
        "the whole published loop; level only", -27.0)
    # CRICKETS: the 11.5 s recording three times over (1.0 / 0.93 / 1.06 speed) so the night does
    # not tick like a clock, crossfaded; the MP3's padding is cut off first
    c = trim(decode(src("crickets"), 2), -40.0)
    parts = [c, speed(c, 0.93), speed(c, 1.06)]
    amb_out("crickets", loop_seam(crossfade_join(parts, 1.0), 1.0), "crickets",
        "the recording at 1.0, 0.93 and 1.06 speed in a row, 1 s crossfades, tail into head", -30.0)


def main():
    os.makedirs(WORK, exist_ok=True)
    what = sys.argv[1:] or ["music", "sfx", "amb"]
    old = {}
    path = os.path.join(RAW, "manifest_p06.json")
    if os.path.exists(path):
        old = json.load(open(path))
    if "music" in what:
        build_music()
    if "sfx" in what:
        build_sfx()
    if "amb" in what:
        build_amb()
    for key in ["music", "sfx", "ambience"]:
        if not report[key] and key in old:
            report[key] = old[key]
    json.dump(report, open(path, "w"), indent=1)
    print("wrote", path)


if __name__ == "__main__":
    main()
