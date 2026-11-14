# Pass P06: sound (buses, a tune per place and boss, stingers, real battle sounds)

Built on 14 Nov 2026, branch `pass/P06`.

## The plain statement first

**NOBODY HAS LISTENED TO ANY OF THIS.** The cloud container has no sound device. Every tune, every
stinger and every battle sound was picked from its title, its file name, its licence page and from
measurements (length, loudness, how bright or low it is). The code was tested; the EARS were not.
The **Music room** (below) exists so the owner can listen on the phone and say "keep" or "swap".
A swap is cheap: put another file under the same name.

House rule kept: every sound is human-made, CC0, from OpenGameArt, published 2011 to 2021 by a
named person. Nothing was generated or synthesised. Processing is only: cut, fade, level, speed
(for the wind and the crickets), crossfade, encode. One licence point is NOT verified: see "The
anvil" under "Could not verify".

## What was built

1. **Buses** (`default_bus_layout.tres`, and made in code by `sfx.gd _ensure_buses()` if that file
   is ever lost): Master with a hard limiter (ceiling -0.5 dB) < Music, SFX, Ambience, UI.
   Volumes are bus volumes now, so a tune in the middle of a crossfade follows the slider.
   `Sfx.set_volumes(sfx, music)` is unchanged for callers; it also reads the settings
   `master_volume` and `amb_volume` when they exist (missing = 1.0).
   `Sfx.duck(db, seconds)` dips the Music bus and brings it back.
2. **Engine faults fixed** (`scripts/core/sfx.gd`):
   - the fade tweens are kept and killed when a new change arrives mid-fade (two quick changes
     could stop the wrong player before);
   - a place's tune **goes on where it stopped** after a fight or a visit elsewhere (`_resume`;
     not for battle music, fanfares or the title; the title clears it);
   - after the victory fanfare a quiet loop ("results") plays instead of silence;
   - the loop flag is no longer forced on the shared cached file: every looping file is imported
     with loop = on (`assets/audio/music/*.import`, the ambience loops too), and if one ever
     disagrees a private copy is set right.
3. **Stingers**: `Sfx.sting(name)`: `level_up`, `quest_done`, `item_get`, `inn_rest`, `beacon_lit`
   (Kenney Music Jingles, already licensed) play over the music, which dips 8 dB for their length.
   `Sfx.sting("defeat")` stops the battle music and plays the sad piece (gameover.ogg) once.
4. **Music**: 12 new files, all by Juhani Junkala (the composer of the tunes the game already
   had, so the score stays one voice), all CC0. Table below.
5. **PLACES**: room, hall, the Elfwood Road, the Deepwood, the beacon's hill, Dustwatch, the
   Sunwell, Emberfall and the Cinder Stair have their own tune. The title theme no longer plays
   inside any dungeon. A place id beginning `in_` uses the `"in_"` row (the hall's tune, the
   hearth, wooden floor). `BATTLE_MUSIC` and `Sfx.battle_for(story_id, boss)`: wild fights by land
   (green / Sands / Cinder), Bramblejaw "boss", the Gorgon "boss_gorgon" (Army Approaching), the
   Colossus "final_boss" for now, any other boss "boss". `Sfx.battle(boss)` still works.
6. **battle_start.ogg** re-made from the same Kenney file at a -3 dBFS peak (it peaked at -23:
   nobody could hear it). Measured after encoding: max -2.2 dB.
7. **Ambience**: the wind loop is 33 s (was 5.4 s); a cave loop with drips (the Sunwell, the
   Cinder Stair); crickets at night where birds or the wood are heard by day; in Emberfall the
   forge fire and a hammer on an anvil every 6 to 15 seconds (`AMB_SPOTS`).
8. **Battle sounds**: 52 new files (table below). `scripts/battle/anim_moves.gd`: 21 `Sfx.play`
   lines changed, ONLY the name, level and pitch inside the brackets; no timing, motion or pose
   line was touched (`git diff` shows nothing but those lines).
9. **credits.gd**: the six music rows now say what each pack really plays; new rows for JRPG
   Pack 1 and 4, Kenney Interface Sounds, the Swishes pack, the cave loop, the crickets, the anvil.
   A licence note per source in `assets_raw/licence_notes/` (new: `juhani_junkala_jrpg_pack_1_exploration.txt`,
   `juhani_junkala_jrpg_pack_4_calm.txt`, `kenney_interface_sounds.txt`,
   `artisticdude_swishes_sound_pack.txt`, `p06_ambience.txt`; nine older notes got an "Added 14 Nov" part).
10. **The Music room** (`scripts/ui/music_room.gd`, extends screen.gd): every tune with its title,
    composer and where the game plays it; press one to hear it through Sfx at the game's own
    level; Stop or Back gives back what was playing. Under them the five stingers.
    Its rows are data: `scripts/data/tracks.gd` (a new data file: titles, composers, roles, the
    room's words). It is NOT reachable in the game until main.gd and Settings get their hooks (below).

## Files

New code and data: `default_bus_layout.tres`, `scripts/ui/music_room.gd`, `scripts/data/tracks.gd`.
Changed: `scripts/core/sfx.gd` (rewritten around the same public functions), `scripts/battle/anim_moves.gd`
(sound names only), `scripts/data/credits.gd`.
Tools: `assets_raw/audio/build_p06_audio.py` (makes every new sound file again from the downloads:
it fetches a missing download, checks its sha256, and writes `assets_raw/audio/manifest_p06.json`
with the measured numbers), `assets_raw/audio/p06_audio_test.gd` (the test).
The big downloads are not in git (the repo skips *.zip; the old sfx_src / music_src folders were
never in git either). The script fetches them again.

### Music (assets/audio/music/)

All loudness numbers are integrated LUFS measured on the game file with ffmpeg ebur128.

| File | Title | Composer | Source pack | Licence | Plays | LUFS | Length |
|---|---|---|---|---|---|---|---|
| room.ogg (NEW) | A Place I Call Home | Juhani Junkala | jrpg-pack-4-calm | CC0 | your room | -16.1 | 46.5 s |
| hall.ogg (NEW) | Peaceful Days | Juhani Junkala | jrpg-pack-4-calm | CC0 | the tavern hall and other insides | -16.1 | 64.0 s |
| dustwatch.ogg (NEW) | Sand Castles | Juhani Junkala | jrpg-pack-4-calm | CC0 | Dustwatch | -17.6 | 71.1 s |
| results.ogg (NEW) | Innocence | Juhani Junkala | jrpg-pack-4-calm | CC0 | the quiet loop after the victory fanfare | -17.5 | 71.1 s |
| calm_friends.ogg (NEW) | Childhood Friends | Juhani Junkala | jrpg-pack-4-calm | CC0 | spare: a warm story cue | -16.6 | 102.9 s |
| calm_summer.ogg (NEW) | Summer Memories | Juhani Junkala | jrpg-pack-4-calm | CC0 | spare: a wistful story cue | -16.0 | 65.5 s |
| road.ogg (NEW) | Grasslands | Juhani Junkala | jrpg-pack-1-exploration | CC0 | the Elfwood Road | -16.1 | 71.5 s |
| emberfall.ogg (NEW) | Military Base | Juhani Junkala | jrpg-pack-1-exploration | CC0 | Emberfall | -16.1 | 88.6 s |
| suncourt.ogg (NEW) | Tha'el Mines | Juhani Junkala | jrpg-pack-1-exploration | CC0 | the Sunwell | -16.0 | 60.0 s |
| beacon.ogg (NEW) | Prairie Nights | Juhani Junkala | jrpg-pack-1-exploration | CC0 | the beacon's hill | -16.0 | 92.9 s |
| deepwood.ogg (NEW) | Sneaking Around | Juhani Junkala | jrpg-pack-1-exploration | CC0 | the Deepwood | -16.0 | 92.0 s |
| boss_gorgon.ogg (NEW) | Army Approaching | Juhani Junkala | jrpg-pack-5-action | CC0 | the Dune Gorgon | -16.2 | 124.2 s |
| title.ogg | Ancient Evil Awakens | Juhani Junkala | JRPG Pack 3 Evil | CC0 | the title screen, the intro | -16.1 | 92.9 s |
| town.ogg | Home Town | Juhani Junkala | JRPG Pack 2 Towns | CC0 | Wickmere (and any place without a row) | -16.1 | 90.0 s |
| woods.ogg | Where Time Stands Still | Juhani Junkala | JRPG Pack 2 Towns | CC0 | the Rune Glade | -16.0 | 75.5 s |
| world.ogg | Sunshine Coast | Juhani Junkala | JRPG Pack 2 Towns | CC0 | the world map | -16.1 | 112.3 s |
| night.ogg | Whispers from Beyond | Juhani Junkala | JRPG Pack 3 Evil | CC0 | out of doors at night | -16.0 | 81.1 s |
| floor1.ogg | Catacombs | Juhani Junkala | JRPG Pack 3 Evil | CC0 | the Cinder Stair (role "cinderpeak") | -16.1 | 81.0 s |
| floor2.ogg | Witch's Lair | Juhani Junkala | JRPG Pack 3 Evil | CC0 | wild fights in the Sands, battle "dustwall" (role "battle_sand") | -16.1 | 80.0 s |
| floor3.ogg | Apocalypse | Juhani Junkala | JRPG Pack 3 Evil | CC0 | wild fights in the Cinder Mountains, battles "pass", "forgedoor", "ashstair" (role "battle_cinder") | -16.1 | 58.5 s |
| battle.ogg | Preparing For Battle | Juhani Junkala | JRPG Pack 5 Action | CC0 | wild fights in the green lands, battles "glade", "deepwood" | -16.1 | 54.9 s |
| boss.ogg | Encounter With The Witches | Juhani Junkala | JRPG Pack 5 Action | CC0 | Old Bramblejaw, and any boss without its own row | -16.1 | 113.5 s |
| final_boss.ogg | Epic Boss Battle | Juhani Junkala | Boss Battle Music | CC0 | the Ember Colossus, for now | -16.1 | 123.4 s |
| victory.ogg | Victory Fanfare Short | cynicmusic | Victory Fanfare Short | CC0 | a fight is won (once) | -16.1 | 11.7 s |
| gameover.ogg | No Hope | Cleyton Kauffman | Game Over Theme | CC0 | Sfx.sting("defeat") (once) | -16.0 | 12.8 s |
| shop.ogg | Bazaar | Juhani Junkala | JRPG Pack 2 Towns | CC0 | spare now (it was the tavern and Dustwatch) | -16.0 | 110.3 s |
| floor4.ogg | Whispers from Beyond | Juhani Junkala | JRPG Pack 3 Evil | CC0 | NOT played by the story: the same bytes as night.ogg, only the old roguelike table names it | -16.0 | 81.1 s |

Two new tracks sit about 1.5 dB under the rest (dustwatch -17.6, results -17.5) and calm_friends
0.6 dB under: reaching -16 would have clipped their peaks, and no limiter or compressor was used
on music. "results" is meant to be quiet anyway (and plays 6 dB lower still).
Every new loop keeps its exact sample count; the jump at each loop seam is far below the track's
usual sample-to-sample jump (numbers in manifest_p06.json, key `loop_seam`). Seams were checked
by measurement, not by ear.

### Sounds (assets/audio/sfx/)

All mono, peak about -3 dBFS, so they are NOT loudness-matched: the level in each `Sfx.play(name, dB)`
call does the mixing. Names with _1.._3 are variants; `Sfx.play("fire")` picks one.

| File | Source (author, file) | Peak dBFS | RMS dBFS | Length |
|---|---|---|---|---|
| sting_level_up.ogg | Kenney: jingles_PIZZA02.ogg | -3.0 | -13.9 | 0.95 s |
| sting_quest_done.ogg | Kenney: jingles_PIZZA10.ogg | -2.9 | -13.7 | 0.797 s |
| sting_item_get.ogg | Kenney: jingles_PIZZA12.ogg | -3.1 | -13.6 | 0.993 s |
| sting_inn_rest.ogg | Kenney: jingles_PIZZA03.ogg | -2.7 | -13.0 | 1.141 s |
| sting_beacon_lit.ogg | Kenney: jingles_HIT15.ogg | -2.8 | -17.4 | 1.163 s |
| slash_light_1.ogg | Kenney: knifeSlice.ogg | -4.1 | -20.8 | 0.404 s |
| slash_light_2.ogg | Kenney: knifeSlice2.ogg | -3.4 | -22.5 | 0.466 s |
| slash_heavy_1.ogg | rubberduck: blade_02.ogg | -3.3 | -24.4 | 0.308 s |
| slash_heavy_2.ogg | rubberduck: blade_03.ogg | -3.4 | -25.8 | 0.3 s |
| slash_heavy_3.ogg | rubberduck: blade_01.ogg | -3.0 | -24.0 | 0.26 s |
| whoosh_1.ogg | artisticdude: swish-7.wav | -3.0 | -15.1 | 0.156 s |
| whoosh_2.ogg | artisticdude: swish-8.wav | -3.4 | -16.8 | 0.129 s |
| whoosh_3.ogg | artisticdude: swish-3.wav | -3.0 | -12.9 | 0.124 s |
| blunt_1.ogg | rubberduck: bfh1_hit_07.ogg | -3.0 | -19.2 | 0.455 s |
| blunt_2.ogg | rubberduck: bfh1_hit_06.ogg | -2.9 | -23.2 | 0.32 s |
| blunt_3.ogg | rubberduck: bfh1_hit_02.ogg | -3.0 | -19.0 | 0.575 s |
| crit.ogg | rubberduck: metal_slam_01.ogg | -3.6 | -24.6 | 0.396 s |
| guard_1.ogg | rubberduck: metal_hit_01.ogg | -3.5 | -22.4 | 0.187 s |
| guard_2.ogg | rubberduck: metal_hit_04.ogg | -3.5 | -25.2 | 0.307 s |
| miss_1.ogg | artisticdude: swish-11.wav | -3.1 | -16.1 | 0.1 s |
| miss_2.ogg | artisticdude: swish-12.wav | -3.2 | -16.9 | 0.071 s |
| bow_1.ogg | artisticdude: swish-10.wav | -3.1 | -18.6 | 0.12 s |
| bow_2.ogg | artisticdude: swish-13.wav | -2.9 | -15.6 | 0.066 s |
| fire_1.ogg | rubberduck: spell_fire_06.ogg | -3.4 | -24.1 | 0.897 s |
| fire_2.ogg | rubberduck: spell_fire_03.ogg | -3.7 | -26.0 | 1.62 s |
| fire_3.ogg | rubberduck: spell_fire_04.ogg | -3.4 | -26.9 | 1.279 s |
| frost_1.ogg | rubberduck: bfh1_glass_breaking_02.ogg | -3.5 | -24.1 | 0.37 s |
| frost_2.ogg | rubberduck: bfh1_glass_breaking_05.ogg | -3.3 | -27.1 | 0.419 s |
| bolt_1.ogg | rubberduck: shot_02.ogg | -3.5 | -28.9 | 0.324 s |
| bolt_2.ogg | rubberduck: cannon_03.ogg | -3.6 | -29.8 | 0.786 s |
| earth_1.ogg | rubberduck: bfh1_rock_falling_01.ogg | -3.1 | -31.0 | 0.799 s |
| earth_2.ogg | rubberduck: bfh1_rock_falling_02.ogg | -3.7 | -28.2 | 0.329 s |
| heal.ogg | artisticdude: spell.wav | -2.9 | -20.3 | 2.554 s |
| buff.ogg | artisticdude: magic1.wav | -3.1 | -17.5 | 0.646 s |
| debuff.ogg | rubberduck: chain_03.ogg | -3.0 | -22.0 | 0.776 s |
| status_on.ogg | rubberduck: slime_02.ogg | -3.0 | -22.7 | 0.438 s |
| potion.ogg | artisticdude: bottle.wav | -3.1 | -19.3 | 0.397 s |
| revive.ogg | rubberduck: bell_03.ogg | -3.3 | -19.1 | 1.243 s |
| lantern_pass.ogg | rubberduck: spell_fire_07.ogg | -2.6 | -17.1 | 0.543 s |
| flare.ogg | rubberduck: spell_fire_05.ogg | -3.0 | -20.8 | 1.216 s |
| ui_move.ogg | Kenney: select_002.ogg | -3.0 | -20.7 | 0.04 s |
| ui_tab.ogg | Kenney: drop_002.ogg | -2.9 | -20.0 | 0.188 s |
| ui_equip.ogg | Kenney: clothBelt.ogg | -3.3 | -30.3 | 0.723 s |
| coins.ogg | Kenney: handleCoins.ogg | -3.1 | -32.0 | 0.736 s |
| page_turn_1.ogg | Kenney: bookFlip1.ogg | -2.8 | -33.4 | 0.66 s |
| page_turn_2.ogg | Kenney: bookFlip2.ogg | -3.9 | -30.8 | 0.416 s |
| page_turn_3.ogg | Kenney: bookFlip3.ogg | -3.0 | -29.9 | 0.231 s |
| save_done.ogg | Kenney: confirmation_002.ogg | -3.1 | -16.8 | 0.539 s |
| battle_start.ogg | Kenney: drawKnife2.ogg | -2.2 | -20.2 | 0.396 s |
| anvil_1.ogg | themightyglider: forger_0.ogg | -3.9 | -19.0 | 0.307 s |
| anvil_2.ogg | themightyglider: forger_0.ogg | -3.2 | -18.4 | 0.276 s |
| anvil_3.ogg | themightyglider: forger_0.ogg | -2.9 | -22.1 | 1.797 s |

### Ambience (assets/audio/sfx/amb_*.ogg)

| File | Source | How it was made | LUFS | Length |
|---|---|---|---|---|
| amb_wind.ogg | IgnasD, https://opengameart.org/content/wind | Wind.ogg and Wind2.ogg in a row, each again at 0.84 / 1.12 / 0.78 / 1.07 speed, 1.4 s equal-power crossfades, tail crossfaded into the head | -25.0 | 33.466 s |
| amb_cave.ogg | JaggedStone, https://opengameart.org/content/loopable-dungeon-ambience | the whole published loop; level only | -27.0 | 94.31 s |
| amb_crickets.ogg | Wolfgang_, https://opengameart.org/content/crickets-ambient-noise-loopable | the recording at 1.0, 0.93 and 1.06 speed in a row, 1 s crossfades, tail into head | -30.0 | 31.57 s |

## Who gets which sound (the tables in sfx.gd)

- `PLACES` place -> [music role, ambience, ground]. Rules: ground "wood" or ambience "cave" = under
  a roof or under the ground, so the night theme never takes over there; "birds" and "woods" turn
  to "crickets" at night. Ambience ids: woods, birds, wind, fire, forge, cave, crickets.
- `MUSIC_FILE` a role whose file has another name (battle_sand = floor2, battle_cinder = floor3,
  cinderpeak = floor1), so later packages can still use floor1 to floor3 by name.
- `BATTLE_MUSIC` story battle id -> role. `WILD_PLACE` / `WILD_GROUND` the wild fight music by the
  place he is in, and on the world map by the ground under him (hub.gd already says it).
- `STINGS`, `AMB_SPOTS`, `BUS_OF` (which bus a sound goes to by how its name begins), `ROLE_DB`.

anim_moves.gd now uses: whoosh (wind-ups, a brute's swing, the leap of a slam), slash_light (the
knight's swings), slash_heavy (whirl, lunge), bow (arrows, pierce, volley), guard, blunt (the slam
landing, a boss's club), buff (the gathering of a spell, the war cry), fire (firebolt), earth
(roots, the boss's crash), flare (sunbolt, sunflare), bolt (storm), frost, heal.
Not called by anything yet (made for the other packages): miss, crit, potion, revive, debuff,
status_on, lantern_pass, ui_tab, ui_equip, coins, page_turn, save_done.
`ui_move` was an alias of ui_click; it is a real, very short tick now (hub_talk.gd uses it at
-20 dB as the letter blip: listen to that first).

## How to test

```
cd new-roguelike
godot --headless --path . --import
godot --headless --path . -s assets_raw/audio/p06_audio_test.gd 2>&1 | grep -E "FAIL|failed"
      # 227 checks: buses and limiter, every role in PLACES / BATTLE_MUSIC / WILD_* has a file,
      # every name anim_moves.gd plays exists, loop flags, duck and return, resume after a fight,
      # night, in_ places, defeat, results after the fanfare, the Music room builds and plays
for f in assets/audio/music/*.ogg; do ffmpeg -hide_banner -i "$f" -af ebur128 -f null - 2>&1 | grep -m1 "I:"; done
ffmpeg -hide_banner -i assets/audio/sfx/battle_start.ogg -af volumedetect -f null - 2>&1 | grep max_volume
timeout 400 godot --headless --path . -- --uitour=tale --nosave --speed=6 2>&1 | grep -E "\[tale\]|SCRIPT ERROR"
python3 -I assets_raw/audio/build_p06_audio.py [music] [sfx] [amb]     # make the files again
```
No test flag was added.

Results on 14 Nov 2026: import clean; full compile `COMPILE DONE files=165 bad=0`; the audio test
227 checks, 0 failed; music -16.0 to -16.2 LUFS except dustwatch -17.6, results -17.5, calm_friends -16.6;
battle_start max -2.2 dB; `--uitour=tale` 43 checks, 0 failed, no SCRIPT ERROR; `./tools/check.sh` CHECK PASSED.

Pictures of the Music room (my own small test scene, gl_compatibility, 1600x720): PC and phone
layouts both fit the screen. Two small phone changes were made AFTER the last picture and not
photographed again (the "Playing" line shows only the title on a phone; shorter stinger names).

## Hooks other packages must add (I did not edit their files)

1. **scripts/main.gd** (P04) `show_battle()`: replace the `Sfx.battle(...)` line by
   `var boss: bool = story != "" and Tale.BATTLES.has(story) and Tale.BATTLES[story].has("boss")`
   `if Sfx.has_method("battle_for"): Sfx.call("battle_for", story, boss)`  `else: Sfx.battle(boss)`.
   Until then every fight still gets "battle" or "boss" by land (battle() calls battle_for("", boss)),
   but the Gorgon and the Colossus do not get their own themes and story fights use the land's.
2. **scripts/main.gd** (P04) `SCREENS`: `"music_room": "res://scripts/ui/music_room.gd"`, opened by the
   action `open_screen` / `music_room`; it sends `back` like every screen. **scripts/ui/settings.gd**
   (P05): a "Music room" button.
3. **scripts/core/save.gd** (P04): `master_volume` and `amb_volume` (default 1.0) in DEFAULT_SETTINGS,
   and `set_setting()` calls `Sfx.set_volumes(sfx, music)` for ANY key ending `_volume`
   (Sfx reads the two new ones itself).
4. **scripts/battle/battle.gd** (P08): level-up: `Sfx.sting("level_up")` in place of
   `Sfx.play("ui_start", -10.0)`; the lose branch of `_finish()`: `Sfx.sting("defeat")`;
   a heal: `Sfx.play("heal", -6.0)`; an item: `Sfx.play("potion", -5.0)`; a raise: `Sfx.play("revive", -4.0)`;
   a blow taken while guarding: `Sfx.play("guard", -5.0)`; a miss: `Sfx.play("miss", -6.0)`;
   a crit: `Sfx.play("crit", -3.0)` with the hit; a buff / debuff / status put on:
   `"buff"` / `"debuff"` / `"status_on"`; the Lantern: `"lantern_pass"`, `"flare"`.
5. **scripts/hub/hub.gd** (P10): `Sfx.sting("item_get")` where a chest opens (the "find" branch of `_talk()`).
   **scripts/main.gd** (P09): `Sfx.sting("quest_done")` at `errand_done` (it plays `victory_sting` today),
   `Sfx.sting("inn_rest")` at `hub_inn` / `hub_sleep`, `Sfx.sting("beacon_lit")` when a `do` with
   `"light"` is applied.
6. **Menus** (P05 and whoever owns each screen): `Sfx.play("ui_tab", -10.0)` on a tab change,
   `"ui_equip"` when gear or arms are put on, `"coins"` on a purchase or a reward, `"page_turn"` for the
   journal / lore pages, `"save_done"` after a save.
7. **New places and bosses** (P09, P10, P13): one row each in `sfx.gd PLACES` and `BATTLE_MUSIC`
   (sfx.gd is theirs in wave 2 and 3). A dungeon wants ambience "cave".
8. **scripts/data/floors.gd** (old roguelike, whoever retires it): point "floor4" at "night", then
   delete `assets/audio/music/floor4.ogg` (1 MB, the same bytes as night.ogg). I left it because the
   old table still names it.

## Left undone

- Jonathan Shaw's two CC-BY 3.0 tracks ("Heated Lands", "A Bitter Hope"), which the plan called
  optional: not added. They are MP3 (loop seams need an ear), a second composer's style, and they
  would add the first CC-BY music credit. Emberfall got Junkala's "Military Base" instead.
- No tune of their own yet: wild fights by night, story scenes (sad / hope cues: two spare calm
  tracks are in the build for that, `calm_friends`, `calm_summer`), a boss's entrance.
- From the review, not in this package's steps: reverb in stone places, a low-pass on the music
  while paused, creature voices by family, a heartbeat at low health.
- The remaining re-pitched sounds in anim_moves.gd: `boss_roar` (two lines, at 1.0 and 1.1) and
  the foes' `enemy_shoot` were left: they are creature sounds and no better file was picked blind.
- `assets_raw/audio/music/manifest.json` (the older tracks' manifest) was not rewritten; the new
  numbers are in `manifest_p06.json`.

## Could not verify

- **Whether anything sounds right.** Every role is a guess. The riskiest guesses: "Grasslands"
  on the Elfwood Road (it may be too bright for the dark-road scene), "Military Base" for Emberfall,
  "Witch's Lair" / "Apocalypse" as wild fight music (they were written as dungeon loops), the five
  jingles (1 second each, picked by their shape, not by ear: the beacon may deserve something
  grander), bow = a light swish (the packs have no bowstring), bolt = a gunshot-like crack,
  frost = breaking glass, the anvil's level.
- **The anvil's licence chain.** The OpenGameArt page is CC0 but says the sound is "derivated from"
  a freesound.org recording (Duasun, sound 321889). freesound.org is blocked from the container, so
  that recording's own licence was not read. The owner should open that page once; if it is not
  "Creative Commons 0", delete `anvil_1..3.ogg`, the `AMB_SPOTS` row and the credit row
  (assets_raw/licence_notes/p06_ambience.txt says the same).
- The mix as a whole (levels between music, ambience, steps, blows), the limiter's sound, and the
  duck's depth: numbers only.
- The Music room inside the real game (it needs hook 2); it was built and pressed in a test scene.
- Seen while testing, in a file I do not own: `UI.pop_in()` can pin a panel at the place it had
  BEFORE a deferred resize (in my test scene the Credits screen sat 125 px too low for that
  reason; I did not check it in the real game). The Music room sizes its panel before it is placed.
