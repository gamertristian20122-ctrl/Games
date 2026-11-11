# Notes for Claude

**Cursebait** (working title): an original Android-first pixel-art game made in **Godot 4.7.2**
(GL Compatibility, landscape, GDScript only). Top-down, one-screen-per-room, twin-stick dark-fantasy
dungeon shooter roguelike. Four floors, a boss on each, three unlockable heroes.

The twist is **the Hungry Curse**: a black disc that hunts the hero through every locked room and
swallows whatever it touches (monsters, their shots, or the hero). You steer it by where you stand,
call it with the second button, crack it open with bombs for the coins in its belly, and every cursed
item makes it bigger.

## About the owner
- Limited coding experience and works from an Android phone: explain in plain, phone-friendly language,
  short numbered steps, no jargon.
- Send the APK as soon as a build is done, and send screenshots as progress updates.
- Keep the work moving; give a short plan, then do it.

## Hard rules
- **No AI-made art or audio, ever.** The owner sells this as "no AI art or audio; code written with AI
  help". Never generate sprites, icons or pixel art (not from code either). Code-driven EFFECTS are fine:
  square particles, lights, tints, flashes, shakes, and plain geometric shapes (the Curse itself is a
  code-drawn disc).
- Every asset must be human-made with a licence that allows a commercial closed-source game
  (CC0 preferred; CC-BY / OFL only for music and fonts). Record each one in `scripts/data/credits.gd`.
  Raw downloads with their licence evidence live in `assets_raw/` (each pack has a SOURCE.txt; the two
  biggest audio source folders are not in git, their notes are in `assets_raw/licence_notes/`).
- **The GitHub repo must stay PRIVATE.** It holds the purchased "Pixel Crawler" art by Anokolisa
  (`assets_raw/paid_pixel_crawler/zips/`, bought by the owner in Nov 2026: commercial use allowed, no
  reselling or sharing of the art itself; terms are in each pack's Terms.txt). Never copy it anywhere public.
  The signing key is not in the repo.
- Original game: no names, items, enemies, bosses, layouts or text copied from existing games.
  Do not reuse ideas from the owner's older games in this repo (no "echo", no recorded past self).
- No `class_name`; use `const X = preload("res://...")`.
- The in-game words (names, descriptions) should stay easy for the owner to rewrite: keep them in the
  data files under `scripts/data/`.

## Toolchain (a fresh cloud container needs these)
- Godot 4.7.2 as `godot` on PATH, Android export templates in
  `~/.local/share/godot/export_templates/4.7.2.stable/`
- Android SDK at `/usr/lib/android-sdk` (platform-tools, build-tools 35, platform 35), JDK 17 at
  `/usr/lib/jvm/java-17-openjdk-amd64`, both set in `~/.config/godot/editor_settings-4.7.tres`
- `xvfb-run` for screenshots, `ffmpeg`, Python 3 with Pillow
- The signing key is NOT in the repo: `tools/build_apk.sh` reads `KEYSTORE`, `KEY_ALIAS`, `KEY_PASS`.
  Every APK must be signed with the same key or phones refuse to update.

## Everyday commands (run from this folder)
```
godot --headless --path . --import                      # after adding or renaming assets
./tools/check.sh                                        # compile check + 6 seeded bot runs; must print CHECK PASSED
godot --headless --path . -- --autotest --nosave --hero=knight --seed=3 --speed=8 --time=240
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --nosave --god --goto=shop --speed=2 --time=14 --shots=/abs/dir     # screenshots; LOOK at them
xvfb-run ... -- --uitour --shots=/abs/dir               # every menu and HUD state
KEY_PASS=... ./tools/build_apk.sh                       # signed APK in build/
```
Flags (after `--`): `--autotest` (a bot plays), `--hero=`, `--seed=`, `--speed=`, `--time=<game seconds>`,
`--god`, `--floor=<1-4>`, `--give=id,id`, `--goto=boss|shop|treasure|secret`, `--shots=<dir>`, `--nosave`,
`--uitour`. Software rendering is slow, so drive tests by game time and wrap runs in `timeout`.

## Where things are
- `scripts/core/` autoloads: `G` (constants, event bus, flags), `Art` (sprite lookup by file name),
  `Controls` (touch, keys, gamepad, bot), `Sfx` (sounds and music by name), `Save` (unlocks, stats, settings)
- `scripts/run/` the run: floors, rooms, shots, effects, stats, the test bot
- `scripts/entities/` player, enemies (+ `ai/` one file per behaviour), bosses (+ `bosses/` one file each),
  familiars, pickups, pedestals, chests, bombs
- `scripts/data/` every table: heroes, enemies, bosses, items, familiars, floors, room layouts, pickups,
  shot types, unlocks, credits
- `scripts/ui/` menus, HUD, touch controls, theme (`theme.gd` holds all colours, fonts and styles)
- `dev/` test scene and data validation; `tools/` check and build scripts
- The top of each data file explains how to add a row. Sections below are added by whoever built each part.

## Look, effects and layouts
How the game is dressed. None of it changes the rules; all of it is data plus four small files.

**Who draws what**
- `scripts/run/room_look.gd` draws a room: floor, walls, the four doors in every state, torches and
  their lights, wall and floor decoration. `room.gd` only calls it (`look.draw_tiles()` and friends).
- `scripts/run/shot_look.gd` draws every shot from the rows in `scripts/data/shot_types.gd`
  (still one node for all shots; shots of one type share an animation frame so they batch).
- `scripts/run/fx.gd` is the one node for effects: square particles, rings, floor warnings, pooled
  sprite animations (`impact`, `pop`, `death_puff`, `explosion`, `sparkle`, `flourish`, `dust`),
  the drifting specks in the air and the vignette. Item and pickup sparkles hook `G.item_acquired`
  and `G.pickup_collected` by themselves.
- `scripts/data/floors.gd` holds each floor's look: `tile_tint` (dark tiles = mood), `ambient`
  (keep it bright so monsters read), torch and flame colours, wall and floor bits, specks, vignette.

**Recipes**
- *Import art:* `python3 tools/import_assets.py` cuts the add-on art out of `assets_raw/` into
  `assets/art/niji/` (ids `niji_*`), `assets/art/forest/` (ids `sdf_*`, outline recoloured to match)
  and `assets/art/fx/` (ids `fx_*`), then run `godot --headless --path . --import`. It only cuts,
  renames and swaps one outline colour; it never draws. `--sheet /tmp/dir` writes contact sheets to
  LOOK at. A new folder must be added to `Art.DIRS` (`scripts/core/art.gd`) and a pack that ships
  in the game needs a row in `scripts/data/credits.gd`.
- *Add an effect:* add a row to `FX` at the top of `tools/import_assets.py` (frame sizes are in
  `assets_raw/fx/manifest.json`), import, then write a small function in `fx.gd` that calls `anim()`.
- *Change a shot:* edit its row in `scripts/data/shot_types.gd` (sprite, which way the art points,
  anchor pixel, tint, trail). Enemy shots always get `under` (dark rim) and `dot` (bright core).
- *Add a wall decoration:* give it a kind name, roll it in `_roll_walls()` and draw it in
  `_draw_back_wall()` (a still) or `build()` (animated or lit), all in `room_look.gd`.
  *Floor decoration:* append to `decals` in `_roll_floor_bits()`; keep it dim.
- *Add a room layout:* copy a block in `scripts/data/room_layouts.gd`, redraw it, rename it.
  Letters: `.` floor `#` rock `o` pit `^` spikes `c` crate `I` column `T` standing torch `e` enemy spot.
  Tag set pieces with `"floors": [3]`. `./tools/check.sh` rejects a layout that blocks a door, seals
  off a tile or leaves no 3-tile-wide lane between the four doors. `--layout=<name>` forces one.
- *Add or retune a floor theme:* edit its row in `scripts/data/floors.gd`; every field is explained there.

**Rules of the look**
- No AI art: decoration is pack sprites; code only draws flat shapes (door jambs seen from above,
  bars, discs, squares) in the pack's own colours (constants at the top of `room_look.gd`).
- The floor must stay readable for the Hungry Curse: no pale-gold rings and no pale stripes on the
  floor, floor decoration dim, carpets only in rooms without fights (shop, treasure, start).
- Lights cost on phones: `RoomLook.MAX_LIGHTS` (6) caps real lights per room, torches past it only
  get an additive glow. `run.LIGHTING = false` still turns all real lights off.
- Doors read the same in all four walls: open = dark doorway in a frame, shut = wooden door,
  locked = golden keyhole plate, boss = red wood + skulls, blown-open secret = ragged hole.
- Screenshots to judge it: `--goto=shop|treasure|secret|boss`, `--floor=N`, `--shot_every=<sec>`.

## The Hungry Curse
The game's twist (built by the twist builder). Rules and EVERY number: `scripts/entities/curse.gd`
(one block of consts at the top). How it is drawn: `scripts/entities/curse_look.gd`.

The rules in ten lines:
1. It exists only in locked rooms (fights and bosses). It rises 1 s after the doors lock, at the
   spawn point farthest from the hero, and sinks when the last enemy dies. While it rises it is
   harmless and shoulders aside any monster standing on the spot (no free meals).
2. It creeps straight at the hero (22 px/s, through rocks and pits). Its lunge timer fills while it
   creeps (4 s for the first lunge in a room, then 6 s); the rim shows the timer filling clockwise.
3. Lunge: a pale hatched stripe runs from the disc through the hero to the wall, follows for 0.5 s,
   locks and flashes for 0.5 s, then the disc dashes along it (260 px/s) to the wall and rests 1.5 s.
4. CALL (the second button, `Controls.action_pressed`) locks the stripe at once. 4 s cooldown, only
   while it creeps.
5. Lit rim (pale gold) = it bites. Dark rim (ash grey) = safe (rising, sated for 3 s after biting
   the hero, stunned).
6. It swallows normal enemies whole (no death effect, no loot). Elites and "big" enemies lose half
   their health per bite. A boss loses (5 + level)% per bite, never below 10%, and knocks it back.
7. Enemy shots die on it. Hero and familiar shots pass through and slow it to 8 px/s for 0.4 s.
8. Curse Level 0-5: each cursed item taken adds 1 (bigger disc, bigger belly; a full-heart bite and
   teeth from Level 3). The shop's "Starve the Curse" stand takes 1 off for 15 / 25 / 35 coins.
9. The belly: +1 coin per enemy swallowed (elite 3, summoned minion 0) up to the level's cap
   (5, 7, 9, 11, 13, 15); kept all run. A bomb blast within 30 px of the rim stuns it for 4 s and
   it coughs every coin out. A bomb it touches goes off at once.
10. A lunge that ends at a hidden door cracks the wall (it shows on the minimap); a second one, or
    a bomb, opens it. (The game counts one found secret per floor.)

Where the numbers live:
- `scripts/entities/curse.gd`: level table, speeds, timers, bite sizes, belly pay, bomb and crack reach.
- `scripts/run/stats.gd`: `call_cooldown`, `curse_creep`, `belly_mult` (so items can change them).
- `scripts/run/run.gd`: `SPAWN_BUDGET_BASE` is 6.5 (was 6.0 before the Curse: it eats about a third
  of the monsters, so rooms got one cheap monster more). 7.0 was tried and is too hard on the Grave Robber.
- `scripts/data/pickups.gd`: `PRICE_STARVE`. `scripts/data/enemies.gd`: `"big": true` rows.
- `scripts/data/items.gd`: Iron Leash is `curse_creep` x 0.73 (22 to 16 px/s), Spiked Goad is
  `call_cooldown` - 1.5 (4 to 2.5 s).
- Run state (`scripts/run/run.gd`): `curse_level`, `belly`, `starve_bought`, `call_cd`.
- First-run teaching (four lines, 26 words): `scripts/run/curse_tutor.gd`.
- Test flags: `--curse=<0-5>`, `--belly=<n>`, `--nocurse`, `--botstyle=dodge|feeder|caller`,
  `--budget=<n>` (overrides SPAWN_BUDGET_BASE), `--teach` (the bot sees the first-run lesson).
- Tests: `dev/curse_tests.gd` (run by `./tools/check.sh`). The tests share one run, so a test must
  not rely on a room being untouched by the tests before it.

Two traps found while finishing it:
- The hero leaves the scene tree at every room change. Anything he connects to an autoload signal
  must be hooked up in `_enter_tree()`, not once in `setup()` (the bomb button was dead after the
  first room because of this).
- Close the game with `G.quit(code)`, never `get_tree().quit()`: a sound still playing at the
  moment of exit is not released and Godot prints "resources still in use at exit".

How the bot plays it (`scripts/run/bot.gd`), and the numbers it measured
(300 game seconds x 6 seeds per row, `--speed=8`, floor 1 mostly; "before" = `--nocurse --budget=6`):
```
hero    style   deaths/room  fight s  first boss  Curse kills  belly coins  bites/run
knight  before     0.10       15.8      6/9          -            -           -
knight  dodge      0.11       13.1      6/7         43%           0%         0.8
knight  feeder     0.13       12.5      7/9         32%          20%         0.5
knight  caller     0.12       10.0      6/11        57%          22%         0.8
witch   before     0.17       12.3      4/10         -            -           -
witch   dodge      0.15       10.0     10/12        25%           0%         0.3
witch   feeder     0.13        9.8      8/10        31%          12%         0.4
witch   caller     0.09        9.0      8/13        44%          22%         1.0
robber  before     0.34       20.7      2/5          -            -           -
robber  dodge      0.24       14.5      4/7         49%           0%         0.4
robber  feeder     0.32       14.8      3/7         49%          19%         0.6
robber  caller     0.17       11.1      7/9         68%          32%         0.8
```
- `dodge` steps off a locked stripe (the short way out), never walks into a lit rim and slips
  sideways instead of backing into a corner. `feeder` also walks to the spot that puts the most
  monsters on the line (only while nothing presses it, never around a boss) and bombs the disc
  when its belly is full. `caller` also presses CALL with 2+ monsters on the line (or the boss).
- A bot run lasts 1 to 2 minutes, so "bites/run" is per short run: about 0.2 to 0.5 bites a minute.
  Bites are 2 to 14% of all damage taken; a boss loses 8 to 16% of its health to bites (most 30%).
- Still off the spec's targets: fights are 17 to 30% shorter than before the Curse (target 15%),
  the caller's Curse makes 44 to 68% of the kills (target 25 to 40%), the Grave Robber's Curse
  about half (he kills slowly; the bot plays him worst with or without the Curse), and `feeder`
  beats `dodge` on coins only, not on survival. One seed batch swings deaths/room by about 0.07.

To add a curse-related item: add a row in `scripts/data/items.gd`. `"cursed": true` alone already
gives +1 Curse Level. Use `mods` with `call_cooldown`, `curse_creep`, `belly_mult` or the flag
`curse_eats_coins`; anything smarter is a hook function in `scripts/run/item_effects.gd`. A locked
item also needs `"locked": true` and a row in `scripts/data/unlocks.gd`.
