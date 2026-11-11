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
- Do NOT make publisher materials (pitch pages, slides, trailers, store text) unless the owner asks:
  on 11 Nov 2026 they said publishers were only a mention. Build the game.
- Usage limits are tight (they have cut work off mid-task many times). The owner asked on 11 Nov 2026:
  "keep the quality and cut down on usage". So: few agents with tight briefs, one light tester rather
  than several heavy ones, no repeated checking of the same thing; spend on building, not re-verifying.

## Hard rules
- **No AI-made art or audio, ever.** The owner sells this as "no AI art or audio; code written with AI
  help". Never generate sprites, icons or pixel art (not from code either). Code-driven EFFECTS are fine:
  square particles, lights, tints, flashes, shakes, and plain geometric shapes (the Curse itself is a
  code-drawn disc).
- Every asset must be human-made with a licence that allows a commercial closed-source game
  (CC0 preferred; CC-BY / OFL only for music and fonts). Record each one in `scripts/data/credits.gd`.
  **CC-BY art is allowed only with its credit row in the game** (the Credits screen is built from
  `credits.gd`). Today that is one boss: the Cinder Tyrant, art by chierit, CC-BY 4.0. It is a spare:
  to drop it, delete its row in `scripts/data/bosses.gd` and its credit row together.
  Raw downloads with their licence evidence live in `assets_raw/` (each pack has a SOURCE.txt; the two
  biggest audio source folders are not in git, their notes are in `assets_raw/licence_notes/`).
- **The GitHub repo must stay PRIVATE.** It holds the purchased "Pixel Crawler" art by Anokolisa
  (`assets_raw/paid_pixel_crawler/zips/`, bought by the owner in Nov 2026: commercial use allowed, no
  reselling or sharing of the art itself; terms are in each pack's Terms.txt). Never copy it anywhere public.
  The release signing key is in `keystore/` (the owner chose this on 11 Nov 2026 after the first key was
  lost with a cloud session): one more reason the repo stays private. Never make a new key.
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
- Installing all of it in a fresh container takes about 5 minutes: Godot and the export templates (only
  the `android*` files are needed) from the godotengine/godot GitHub release, Android command-line
  tools from dl.google.com + `sdkmanager`, `apt-get install openjdk-17-jdk-headless`.
- The APK is 64-bit only (`architectures/arm64-v8a` in `export_presets.cfg`), about 42 MB: the owner's
  phone could not download the 69 MB two-architecture build.
- The signing key is `keystore/cursebait.keystore` (alias and password in `keystore/key.env`, read by
  `tools/build_apk.sh`). Every APK must be signed with this same key or phones refuse to update.

## Everyday commands (run from this folder)
```
godot --headless --path . --import                      # after adding or renaming assets
./tools/check.sh                                        # compile check + 6 seeded bot runs; must print CHECK PASSED
godot --headless --path . -- --autotest --nosave --hero=knight --seed=3 --speed=8 --time=240
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --autotest --nosave --god --goto=shop --speed=2 --time=14 --shots=/abs/dir     # screenshots; LOOK at them
xvfb-run ... -- --uitour --shots=/abs/dir               # every menu and HUD state
./tools/build_apk.sh                                    # signed APK in build/
```
Flags (after `--`): `--autotest` (a bot plays), `--hero=`, `--seed=`, `--speed=`, `--time=<game seconds>`,
`--god`, `--floor=<1-4>`, `--give=id,id`, `--goto=boss|shop|treasure|secret`, `--shots=<dir>`, `--nosave`,
`--uitour`, `--boss=<id>` (see "Bosses"). Software rendering is slow, so drive tests by game time and wrap runs in `timeout`.

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

## The cast (heroes, monsters, bosses, helpers) — Pixel Crawler art
Added by the cast builder. Every character on screen is a purchased Pixel Crawler sprite (ids `pc_*`).

- **Where the art is:** `assets/art/pc/` (cut by `tools/pc_import_cast.py`; do not redo). Measurements
  per id are in `assets/art/pc/pc_cast.json`; which creature suits which floor is in
  `assets/art/pc/pc_roster_proposal.md`.
- **Art (`scripts/core/art.gd`):** `Art.sprite(id)` stands a sprite on its measured feet point.
  `Art.meta(id)` gives `body_height`, `body_width`, `radius`, `feet`. `Art.has_anim(id, "hit" | "death" |
  "attack")` says what the pack really drew (never faked): heroes have no hit animation, only bats
  have an attack animation, shopkeepers only idle. Ask before playing one.
- **Heroes (`scripts/data/heroes.gd`):** `sprite`, `weapon` (a `pc_weapon_*` still, points up), `grip`
  (px from the bottom of the weapon to the hand) and `hand` (a `pc_hand_*` fist drawn on the grip).
  `scripts/entities/hero_look.gd` holds the weapon for the player, the menus and the line-up: it turns
  to the aim, goes behind the body when aiming up, kicks back on a shot. Keep a weapon about as long
  as the hero is tall or shorter; pick another sprite, never scale. Hero ids stay knight / witch / robber.
- **Monsters (`scripts/data/enemies.gd`):** 31 rows, 7 to 8 of their own per floor plus a few shared with
  the next floor. Body circle, shot hit height, hit size and shadow come from the measurements
  (`enemy.gd` `setup()`); a row only needs `radius` / `hit_up` to overrule them. `"idle": "run"` and
  `"hover"` are for flyers. A dead body plays the pack's death animation, then fades (it is already
  out of `room.enemies`). Old row keys kept because tests and other files name them: `bone_archer`
  (shown as Bone Mage), `lantern_head` (Ember Husk).
- **Flashes:** a hit = a bright flash that keeps the drawing, `HIT_FLASH` (0.05 s) then at least `FLASH_GAP`
  (0.1 s) unflashed. A wind-up (`tell()`) blinks PALE, not white
  (`TELL_SHADER`), so tall sprites never turn into a blank white shape.
- **Bosses:** no longer Pixel Crawler creatures at double size. See the "Bosses" section.
- **Helpers:** familiars are tinted `pc_bat_small` using the flying loop (`scripts/data/familiars.gd`;
  row keys `wisp`, `tithe_imp` must stay). The shopkeeper is `pc_npc_tavern_a` (`shopkeeper.gd`).
- **Look at it:** `xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3
  --resolution 1600x720 res://dev/cast_lineup.tscn -- --shots=/abs/dir [--anim=run|death|hit]`
  writes one picture with every hero aiming in 8 directions, every monster, both bosses, the
  familiars and the shopkeeper on floor lines.

## Rooms in the Pixel Crawler art (room builder, Nov 2026)
This replaces what "Look, effects and layouts" says about walls, floors, doors, obstacles and room
decoration (`tile_tint`, niji / forest wall pieces and carpets are gone). Shots, effects and the
layout letters in that section still hold.

- Every room picture comes from one tile set per floor: `assets/art/pc_tiles/<crypt|warrens|ashen|pit>/`
  described by `assets/art/pc_tiles/tilesets.json` (written by `tools/pc_import_tiles.py`; never edit
  it by hand). `scripts/run/room_look.gd` reads the json once, loads pieces when first needed and
  keeps them. `tools/pc_preview_room.py` is the reference for draw order.
- Sizes: back wall 48 px, side walls 16, bottom strip 16, so a room is 304 x 176 on the 180 px tall
  screen. The floor is still (0,0)..(272,112); the json counts from the wall frame's top-left corner
  (game x = json x - 16, game y = json y - 48). `G.CAMERA_CENTER` centres the whole frame.
- Layers (`room.gd`): `tiles` (floor, floor bits, walls, doors, wall pieces) < `spikes_node` (pits and
  spikes, flat) < `ysort` (obstacles and characters, sorted by their feet) < `front` (bottom wall and
  door parts marked "front") < `door_fx` (the code-drawn boss mark).
- `scripts/data/floors.gd` picks the set (`tiles`) and holds what the json does not: how much
  decoration, `dress` (what a shop, treasure, secret and boss room put on the back wall), `debris`
  colours, `pit_depth`, `pit_join` (the Pit's one-hole-per-tile shaft is joined into big shafts by
  cutting that picture into quarters) and `secret_hole`.
- Obstacle letters map to json kinds: `#` rock, `c` crate, `I` pillar, `T` torch, `o` pit, `^` spikes.
  Which variant a tile gets is hashed from the room's seed and mirrored left to right.
- Door states come straight from the json (`doors.<n|s|w|e>.<state>`): open, shut, locked, hidden,
  cracked, boss, boss_open. Made by code: the red skull boss mark and a thin gold rim round the
  keyhole plate of a locked back-wall door.
- Lights: wall lights sit at the json's columns; `RoomLook.MAX_LIGHTS` (6) real lights per room,
  the rest only glow. A secret room has no wall lights.
- Test flags: `--doorlook=<state>` draws a door in that state in all four walls (look only),
  `--floor=N`, `--goto=shop|treasure|secret|boss`, `--layout=<name>`.
- `./tools/check.sh` (dev/validate.gd) checks that each floor's tile set is complete and that
  `dress` / `no_floor_deco` name real pieces.
- Known gaps (need the tile importer, not code): the crypt has ONE pillar picture (the hooded
  statue), the ashen halls one; blown-open side doors are a floor tile with rubble (no ragged hole).

## Props and pickups (ids "prop_*")
- Pictures in `assets/art/props/`, cut by `python3 -I tools/import_props.py` (re-run after changing it, then
  `godot --headless --path . --import`; output is byte-identical on re-runs). Never reuse the old ids `coin`, `bomb`, `key`.
- Sources: chests from Pixel Crawler (crypt Hideout, warrens Sewer, ashen Forge, pit Library; locked = Desert gold),
  stand = Pixel Crawler column capital, exit = Pixel Crawler stairwell (48x48, placed on 3x3 free tiles).
  Free CC0 packs, archives + SOURCE.txt in `assets_raw/props/<slug>/`: Kings and Pigs (hearts, armour, bomb + lit fuse),
  Treasure Hunters (key, gem = 5 coins, golden skull), ArMM1998 Zelda-like (coin, warmed to gold).
- Still old: HUD hearts (0x72, the only full/half/empty set), explosions (ansimuz), the 6 px Curse skull badge.
- Pickup rows: `scripts/data/pickups.gd` (sprite list: the first id that exists wins). HUD icons: `UI.hud_icon` in theme.gd.
- Test flag `--lockchests`: every chest is locked (to look at the locked chest).

## Bosses
Seven bosses drawn from their own art at real size (never scaled). Names are placeholders the owner
may change (`"name"` in `scripts/data/bosses.gd`; the row KEY is what saves and unlocks remember).

| Floor | Row key | Name | Sprite | State | Bot wins (knight / witch / robber) |
| --- | --- | --- | --- | --- | --- |
| 1 | `pyre_saint` | The Pyre Saint | `boss_fire_skull` | full fight | 7/10, 5/9, 7/10 |
| 1 | `red_sexton` | The Red Sexton | `boss_death` | full fight | 7/9, 7/9, 4/9 |
| 2 | `stonejaw` | Stonejaw | `boss_ogre` | full fight | 4/10, 4/11, 2/10 |
| 2 | `gutter_king` | The Gutter King | `boss_mutant_toad` | full fight | 4/9, 2/12, 2/10 |
| 3 | `forge_warden` | The Forge Warden | `boss_mecha_golem` | full fight | 4/9, 1/8, 2/9 |
| 3 | `cinder_tyrant` | The Cinder Tyrant | `boss_demon_slime` (CC-BY, chierit) | full fight | 7/10, 4/11, 2/10 |
| 4 | `starved_king` | The Starved King (FINAL) | `boss_demon` | full fight | 2/5, 0/6, 1/6 (with 7 items) |

"Bot wins" is the fairness sweep of v0.3.0 (11 Nov 2026): the bot, a BARE hero with no items, 2 seeds,
240 game seconds each at `--speed=8` (the King was measured with a 7-item kit, since nobody reaches
floor 4 bare). The bot ignores a lot, so people do better. The Grave Robber is still the weakest hero
against floors 2 and 3; the Forge Warden and the Starved King are the hardest fights.

A floor with two bosses picks one per run (seeded). Killing the row with `"final": true` wins the run
(`run.boss_killed`); its death is longer. A row's `"layout"` forces the boss room layout (the King
and the Tyrant are too big for pillars).

- **Art:** `assets/art/boss/` (cut by `tools/import_bosses.py`), described by
  `assets/art/boss/boss_cast.json` (read its `_about` key): canvas, feet point, hover height, body
  size, radius, frames per animation, frame rates, hit frames, shot spawn points, effect sprites,
  notes. `Art` loads every animation that file lists and `Art.meta(id)` hands the entry out.
  17 bosses are cut; ten are unused spares.
- **Files:** `scripts/data/bosses.gd` (rows; every key is explained at its top),
  `scripts/entities/boss.gd` (the base and THE TOOLKIT, listed at its top),
  `scripts/entities/bosses/<row key>.gd` (one fight each).
- **Writing a fight:** copy `stonejaw.gd` or `cinder_tyrant.gd`. A fight is a small state machine
  (`start`, `tick`, optional `phase_changed`) whose attacks are: put a red mark on the floor
  (`e.mark_circle / mark_lane / mark_charge / mark_cone / mark_ring`), play the animation so its
  hit frame lands when the mark is full (`e.strike(anim, seconds, on_hit, on_end)`), and in the
  callback hurt what is inside (`e.strike_circle / _lane / _cone / _ring`) and fire shots
  (`e.shoot_from / fan_from / ring_from` from `e.muzzle(anim)`). `e.after(seconds, callback)` is the
  timer, `e.stagger(seconds)` the breather, `e.burn_ground()` fire that stays, `e.fx_sprite()` a
  `boss_fx_*` animation, `e.cut_sprite()` a piece of one of its own frames (Stonejaw's thrown club),
  `e.summon_minions()` helpers on marked spots. Numbers go in the row's `params`.
- **Rules of a fight:** every blow has a wind-up and a red floor mark of at least 0.5 s on floor 1
  and never under 0.35 s; there is always somewhere safe to stand; 3 to 4 attacks, a breather, and
  a phase 2 under half health that changes the pattern (`"phases": [0.5, 0.2]` adds a phase 3);
  45 to 90 s (final boss 90 to 150 s); under about 120 shots on screen (`e.shoot_from` and friends
  stop at `SHOT_CAP`). Marks are RED: pale-gold rings and stripes on the floor belong to the Curse.
  Burning ground is a ragged orange patch without a rim, so it is neither a mark nor the Curse.
- **Made by code where the pack drew nothing:** the hit flash (a pale flash, not pure white), the
  phase roar, the dazed look of a stagger, and the death (shake, bursts in the boss's own colours,
  fade, slow motion). The pack's `hit` and `death` frames are used where they exist.
- **Test flags:** `--goto=boss --floor=N --boss=<row key>` (that boss on any floor; the bot walks
  straight in), `--bosshp=<n>` (to reach phase 2 or the death quickly), `--bosslog` (prints phases,
  staggers, the fight time and WHAT hurt the hero: which mark, its body, a shot, a helper, the Curse).
  Example: `godot --headless --path . res://dev/world_test.tscn -- --autotest --nosave --bosslog
  --hero=witch --seed=5 --speed=8 --time=130 --goto=boss --floor=3 --boss=cinder_tyrant`.
- **The bot in a boss room** (`scripts/run/bot.gd`): steps out of circles, lanes, cones and rings
  (`run.fx.hazards`), keeps its distance from a boss's SIDE, never walks into its body, and shoots
  a helper that is right on top of it.
- **Measured (bot, no items, `--speed=8`):** won fights last 31 to 76 s (Starved King 92 to 109 s with
  items). What was tuned in the sweep: Pyre Saint's body hurts only during a swoop and it calls 1 helper
  (was 2); Gutter King 360 hp (was 410), 4 hop shots, globs bounce once; Starved King 2300 hp (was 2500);
  Grave Robber damage 3.3 (was 3.0) and range 108 (was 85).
- **Flashes:** a boss flickers for `HIT_FLICK` (0.05 s) at most once per `HIT_GAP` (0.3 s) when hit, and
  once for `TELL_PULSE` (0.12 s) at the start of a wind-up; the red floor marks do the warning.
- **Guards:** `e.shielded = true` (Forge Warden) stops hero SHOTS only (`shots.gd` skips it); bombs,
  burns and Curse bites still land. `e.harmful = false` makes a body safe to touch.
- **Marks stay on the floor:** `fx.gd` clips circles, lanes, rings and shockwaves to the floor rectangle.
- `--tonguetest` makes the Gutter King only lick (to look at the tongue).
- **Old saves:** `Bosses.RENAMED` maps a retired boss id (`gravekeeper`) to the boss that took its
  place, so `boss_killed:<id>` counters and rules stay true. `./tools/check.sh` checks every row:
  its file loads, every listed animation exists, every floor has a boss.
- **Licences:** ansimuz "Legacy Collection" CC0; Kronovi "Mecha-Stone Golem" free for commercial use
  (no redistribution: one more reason the repo stays private); chierit "Demon Slime" CC-BY 4.0
  (credit required). Evidence: `assets_raw/bosses/*/SOURCE.txt`.

## What's next (written 11 Nov 2026, after v0.3.0)
Everything on the v0.3.0 fix list is done. Ideas for the next passes, most useful first:
1. The owner plays v0.3.0 on the phone and says what feels wrong (bosses above all). Their notes come first.
2. Grave Robber against floors 2 and 3 bosses: still the weakest hero (see the Bosses table).
3. Forge Warden: the lanes (arm throw, beam) hit the bot most; maybe a longer warning.
4. Starved King: only measured with one 7-item kit; needs a real play-through from floor 1.
5. Tile gaps: a second pillar picture for the crypt and the ashen halls; a ragged hole for blown-open side doors.
6. Still old art: HUD hearts, explosions, the 6 px Curse skull badge.
7. Sound pass for the seven bosses (they reuse monster and door sounds).
8. Boss names are placeholders the owner may want to rename (`scripts/data/bosses.gd`).
Not planned unless the owner asks: anything for publishers (pitch, slides, trailer, store text).
