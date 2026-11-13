# Notes for Claude

**Hollow Hill** (the owner picked this name on 11 Nov 2026; it was "Cursebait" before, and the repo
folder, the APK key file and the Android package id `com.cursebait.game` keep the old word so updates
still install) is an original
pixel-art game made in **Godot 4.7.2** (GDScript only, landscape). Since 13 Nov 2026 the target is **PC / Steam**
in **Forward+** (the HD look); Android still exports with GL Compatibility (`rendering_method.mobile`).

## Direction since 13 Nov 2026: PC / STEAM FIRST, the HD look (this overrules older sections below)
The owner sent four pictures from a famous studio game in the "pixel sprites in a lit 3D diorama" style
(lamp-lit town street at dusk, night battle with a big glowing spell, harbour at dusk, forest campfire
clearing) and said: "Don't care about the phone ... get as close to that quality as possible." Then:
"the blurriness is so strong that I can't see the characters, so bring the characters in the background
forward, and do the light blazing that you see in the photos."
- Target is PC/Steam in Forward+. The phone build must still EXPORT and RUN, but its look no longer leads.
- Every character must stay sharp and readable wherever they stand. Blur belongs only to scenery far
  behind the play area and things between the camera and the play area.
- Light should BLAZE: hot lamp and fire cores, warm pools on the ground, deep shade round them.
- Same KIND of look as the references, never their characters, names, maps or UI. Still no AI art/audio.
- See v0.25.0 for how the HD look is built.

## Direction (set by the owner on 11 Nov 2026 — this overrules older sections below)
The game is now a **story adventure in the spirit of old 2D adventure games**, not an endless roguelike:
1. Open the game, press Play, you are in **the camp** (a small map to walk around, people to talk to).
2. Talking is a **dialogue box** along the bottom: picture, name, words letter by letter, tap for the next page.
3. (v0.10.0: now 12 levels across a world map and three camps; see the v0.10.0 section.)
   The story moves on by **one descent through 7 levels** (`scripts/data/story.gd`), 4 areas, each level a
   small dungeon that ends at a boss and is harder than the last. Beat a boss, take the stair, the next
   level begins (owner, 11 Nov 2026: going back to the gate after every level was "redundant").
   **From the pause menu the hero can walk back to the camp whenever no fight is on**: he keeps his items,
   his coins go into the camp chest, cleared levels stay cleared, and the Warden sends him down again at
   the first level not yet cleared. **Dying only repeats the level he fell in** (coins carried are lost).
4. **Aldous the knight is the ONLY hero and SWINGS his sword** (no flying blade). The owner removed the
   wizard and the rogue on 11 Nov 2026 and wants **switchable weapons** for the knight later instead.
   The other two rows still exist in `heroes.gd` because the bot tests use them; nothing in the game shows them.
5. **The Hungry Curse (the black orb) is REMOVED.** The owner did not understand why it was there. Its code
   and tests still exist but are switched off (`G.curse_on()`, only `--withcurse` turns it on). Do not bring
   it back, and do not build on it. Items that only worked with it are no longer offered.
6. Use the purchased Pixel Crawler packs wherever possible; the owner paid for them and wants them seen.
7. The owner wants to be **interviewed**: ask clear multiple-choice questions before big decisions.
8. Answers so far (11 Nov 2026): name **Hollow Hill**; tone **dark but warm** (as the lines in story.gd);
   the sword gets a **shield block** and otherwise stays simple (no roll, no spin); build next, in this
   order of the owner's picks: **a world map with new areas** from the other packs, **more story scenes**
   (before and after bosses, when someone joins), **camp upgrades** bought with coins.
Top-down, one screen per room, twin-stick. Four dungeon looks, seven bosses, three heroes.

## Direction since 12 Nov 2026 (late night): BUILD THE WHOLE GAME BASE (this overrules the sections below)
The owner, with three more pictures of the same reference game (a harbour at dusk, a golden
woodland road, a lamp-lit town square): "now you need to build the entire game base ... like a
legend of Zelda with 2D RPG cuz it's turn-based. The dungeons are only temporary. They're not real
part of the game. We need a real story like something happened that [they have to] stop and save
it and they [meet] a number of companions along the way. Revamp the camp and revamp everything and
make sure to have that very soft light like this." Read as:
- **The game is a turn-based adventure RPG**: a world to walk, towns, a real story with a threat to
  stop, SEVERAL companions met along the way (this overrules "ONE companion at a time").
- **The present dungeons, story levels and camps are PLACEHOLDERS.** Do not polish them; they are
  to be replaced by the real story's places. The old real-time rooms still run behind the story
  gates only because nothing has replaced them yet.
- **Soft warm light everywhere** (golden sun, long soft shadows, gentle glow, blur near and far).
- Still the house rules: an original game (same KIND as the references, nothing copied from
  them), only the purchased / free human-made art, no AI art or audio.
- **Done so far:** the look test (v0.16.1), every walking place in the look (v0.17.0), turn-based
  battles on the map + the soft light pass (v0.18.0).
- **Next, in order:** (1) THE STORY: the owner picks from story ideas (asked at the end of the
  v0.18.0 session; see "The story" below once chosen), (2) the story's first town and its people in
  place of the village camp, (3) companions who join with a scene each and fight in the party
  (battles already seat four), items and an inn so health can carry between battles, (4) dungeons
  as walking places with battles and bosses, retiring `scripts/run/` rooms, (5) title and intro in
  the look, (6) balance. An APK after each.
- The owner has still not said how any of it runs on the phone. Keep Settings > "3D look" working.

## The story (the owner said "yes" to this on 12 Nov 2026; chapter one is BUILT, see v0.19.0)
Asked with three choices (The Stolen Dawn / The Thorn-Sickness / The Broken Crown), the owner
answered: story "I cant decide 1 or 4" (there was no 4; read as torn between 1 and 3, to be
confirmed), companions "3", mood "1 and 2" = hopeful adventure AND dark and serious.
So the proposal MERGES The Stolen Dawn with The Broken Crown:
- **Before:** the first king set the Dawnfire in his crown and lit four beacons with it; their
  light keeps the long night out and keeps something asleep under Hollow Hill.
- **What happened:** the king died, the crown was broken in four, each shard was carried off by a
  lord, and each beacon went dark. The nights grow longer. Under the hill the sleeper stirs.
- **The hero:** Aldous, last knight of the king's guard, who was there when the crown broke.
- **The road:** four lands, each with a town, a lord who holds a shard, and a dark beacon: the
  Elfwood, the Sands, the Cinder Mountains, the Sunken Archive (art for all four is in the game).
  Win the shard (not always by fighting), relight the beacon, and that land's days turn long and
  golden again (the soft light is the reward the player SEES). Then down under Hollow Hill.
- **Companions (3, a party of four, everyone fights):** Seraphine the sun-mage (already in),
  Thessaly the elf warden (a ranger; already an NPC), Grukk the orc smith (heavy blows; already
  an NPC). One joins in each of the first three lands, each with a scene and a reason of their own.
- **Mood:** a warm world worth saving, with real loss in it: not every lord can be saved, and
  relighting a beacon costs something each time. The ending is earned, and it is dawn.
- Added while building: each beacon SWALLOWS its shard when it is lit, so the crown can never be
  remade ("a light does more than a king"). That is the cost the mood asked for.
- Names and words are placeholders the owner may rewrite. All of it lives in `scripts/data/tale.gd`.
- **Built:** chapter one (Wickmere, the Elfwood, Thessaly, the Bramble Giant, the first beacon).
  **Not built:** the Sands and Seraphine, the Cinder Mountains and Grukk, the Sunken Archive,
  the end under Hollow Hill.

## Direction since 12 Nov 2026 (night): the LIT 3D LOOK, then TURN-BASED battles
The owner sent six pictures of a famous "pixel people in a lit 3D world" turn-based RPG and wrote:
"I'm hoping to ... get it to this level and then turn it into turn-based RPG game". This overrules
"Fights stay REAL-TIME" in the section below. Told to the owner, and still true:
- It is the same KIND of look and battle, never a copy: no names, characters, maps, menus or battle
  rules taken from that game (the house rule "original game" stands). The art stays the purchased
  Pixel Crawler packs; code adds only light and effects.
- A big studio's hand-built scenery cannot be matched; the mood (light, blur, glow, depth) can.
- Turn-based REPLACES the real-time fighting of RPG steps 1 to 5. Levels, stats, gear, skills, mana,
  the companion, keys and roamers carry over as data.
- After the look test the owner answered only: **"That needs to be for the entire game."** So the
  look goes EVERYWHERE, walking places first (they are what Play opens).
- Order of work: (1) a LOOK TEST of one battle scene (DONE, v0.16.1), (2) every place you WALK in
  shown in the lit 3D look: camps, world map, tavern rooms (DONE, v0.17.0, `scripts/hub/view3d.gd`),
  (3) the real turn-based battle on the battle stage, started by a roamer's touch (it replaces
  `Roamers.fight` rooms), (4) dungeons as walking places in the same look (monsters stand in the
  rooms, a touch starts a battle; bosses are battles) which retires the flat real-time rooms,
  (5) the title picture and the intro in the look, (6) balance. An APK after each.
- STILL FLAT after v0.17.0 (say so to the owner, do not pretend): every fight (dungeon rooms, the
  roamer's one-room fights, the training yard), the title backdrop, the intro cutscene.
- The owner has NOT yet said how it runs on the phone (the look test shows an fps number). Until
  they do, keep Settings > "3D look" (off = the old flat places) working.
- Not yet asked (ask with multiple choice before building step 2): how many fight at once (the
  knight and ONE companion today), and how deep the battle rules should be.

## Direction since 12 Nov 2026 (evening): Hollow Hill becomes a ZELDA-STYLE ACTION RPG
The owner: "turn it into an RPG ... like a 2D Zelda, slightly open world". It stays the same game
(knight, world map, camps, story); RPG systems go on top. Interview answers (multiple choice):
- **Fights stay REAL-TIME** (the owner was unsure about turn-based and took the recommendation).
- **Open world = roaming monsters**: monsters walk the world map and outdoor areas and are fought
  there; camps and dungeons are doors on the map; the main story keeps its order, side areas are free.
- **Dungeons = a mix**: a fixed map per dungeon with locked doors, small keys, a boss key and one
  treasure; the rooms themselves reuse the layouts already made.
- **Level-up = stat points** (Strength, Vitality, Spirit, Agility).
- **Skills = two skill buttons + a mana bar**, about 8 skills to learn, the player picks which to carry.
- **Party = ONE companion at a time.** The owner does NOT want Ozric and Tobin back: they asked for a
  new sidekick, an attractive, stylish adult woman fighter ("a baddie ... sexi"), from a free
  human-made pack that matches the Pixel Crawler look (or from the purchased packs). Show the owner
  pictures to choose from BEFORE wiring her in. Tasteful, adult, never AI-made.
- **Gear = all three ways**: monster drops, chests and bosses, shops; Common / Rare / Epic.
- **Size: medium.** Build in steps, an APK after each: 1 levels and XP (DONE, v0.11.0), 2 gear and an
  inventory screen (DONE, v0.12.0), 3 skills and mana (DONE, v0.13.0), 4 the companion (DONE, v0.14.0: the owner picked the blonde mage of
  the Library pack, ranged, "gets back up"), 4 the companion, 5 roaming monsters and the Zelda-style
  dungeons (keys, boss key: DONE, v0.15.0; roaming monsters: DONE, v0.16.0, as "touch = quick battle"), then a
  balance pass. ALL FIVE STEPS ARE BUILT; nobody has played any of it by hand yet. Next: the owner
  plays, then balance and polish from their notes.
- The owner's standing rules: few agents, one light tester, no re-checking what already passed; small
  64-bit APK sent in a message BY ITSELF, screenshots in a separate message; never a greyed-out
  button without the reason on screen; nothing for publishers.

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

## The Hungry Curse (SWITCHED OFF since v0.5.0, see "Direction"; kept only as a record)
It was the game's twist (built by the twist builder). Rules and EVERY number: `scripts/entities/curse.gd`
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
- **Hands (`scripts/entities/hands.gd`, v0.3.1):** the pack draws every body WITHOUT arms and ships the
  hands as separate pieces (`pc_hand_*`, one colour set per creature family). The owner said "nothing has
  arms" on 11 Nov 2026, so every monster with a `"hands"` id in `enemies.gd` gets one at each side
  (swinging while it walks, hidden during the pack's own hit / attack frames and on death), and a hero's
  free hand uses his `"hand"` piece. Bats have none; bosses are other packs' art, drawn with arms.
  Pieces were picked by matching colours with the body sprite; nothing is drawn or recoloured.
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

## The camp (hub) — v0.4.0
The owner asked on 11 Nov 2026 for a hub after Play: a small map to walk around, NPCs, stages and quests,
built from the purchased packs. Flow now: title -> Play -> CAMP -> (Warden at the gate) -> run -> end
screen -> "Camp" (or "Try again"). Back / pause in the camp goes to the title.

- **Files:** `scripts/hub/hub.gd` (the scene: ground, props, people, hero, camera, lights, fireflies),
  `scripts/data/hub.gd` (the map, every prop position, the people and their words),
  `scripts/data/quests.gd` (quests and the pack), `scripts/ui/hub_talk.gd` (the talk window),
  `tools/import_hub.py` (cuts `assets/art/hub/hub_*.png`; `--sheet <dir>` writes a labelled sheet to look at).
- **Art used:** Fairy Forest (grass, earth patches, trees, bushes, flowers, rune stones, rocks), Cemetery
  (crypt gate, graves, statues), Free Pack Exterior (fire pit, flame, grill, anvil, bench, scarecrow), and
  the pack's characters with their hand pieces. Many cut pieces are not placed yet (see the sheet).
- **People (`role` in `scripts/data/hub.gd`):** Warden `gate` (pick a stage), Druid `quests`, Chronicler
  `collection`, Cook `pack` (what waits for the next run), Smith and two elves `chat` (a tip each). The
  heroes who have joined (and are not being played) stand by the fire: talk to one to play as them. The hero-select screen is no longer in the flow (the UI tour still shows it).
- **Stages:** replaced in v0.5.0 by story levels (see "Story, levels and dialogue").
- **Quests:** 13 rows; the Druid offers the first 3 not done. Each counts a `Save` counter from the moment
  it is first offered. Rewards are supplies (coins, bombs, keys) that wait in the save (`hub` section,
  keys `boon:*`, capped by `Quests.BOON_CAP`) and are all taken on the next run. A gold "!" over the
  Druid means a quest can be handed in.
- **Controls:** left stick walks; the second touch button says TALK and lights up next to someone
  (`touch.hub_mode`, `G.hub_near`). Keyboard / gamepad: the CALL key.
- **Test flags:** `--hub` (open the camp at once), `--hub --shots=<dir>` (a short walk, five pictures),
  `--hubtalk=<npc id>` (also a picture of that talk window; heroes are `hero:witch` ...),
  `--hubstage=<n>` (start that stage after a second), `--allstages`.
- **Not done yet:** no stage or quest has been played end to end by a person; quest rewards are a first
  guess; NPCs stand still; the camp has no music of its own (it plays the title music).

## Story, levels and dialogue — v0.5.0
- **`scripts/data/story.gd`** holds all of it: the story in short (top of the file), `LEVELS` (id, area, name,
  floor look, boss, rooms, who joins), `INTRO` (spoken once on the first camp visit) and `TALK` (what each
  camp person says, by chapter). Chapter = number of levels cleared. All words are placeholders to rewrite.
- **Progress is in the save's `hub` section:** `lvl:<id>` (cleared), `kit:<item id>` (items carried, in
  order), `heard:<npc id>` (which lines were heard; a gold "!" marks unheard ones), `seen:intro`.
- **The descent (v0.6.0):** `G.next_run = {"level": row, "kit": [...], "pack": {...}}` starts at that level.
  When its boss falls `run.gd` `boss_killed()` calls `Story.clear()` (level cleared, items kept), heals
  `LEVEL_HEAL`, and the room gets the stair; `next_floor()` then loads `Story.after(level)`. The second
  level of an area gets `LEVEL_STEP_BUDGET` more monsters. Only the final boss ends the run (Victory).
  Pause menu in a level: "Back to camp" (greyed out during a fight) -> `main.leave_run()` ->
  `Story.walk_out()` (kit kept, coins to `bank:coins`). On death: "Try again" (the level he fell in,
  with the kit as of the last cleared level) or "Camp". The camp chest's coins are not spent on
  anything yet (camp upgrades are planned).
- **The gate (Warden):** "Go down: <first level not cleared>" and, once any is cleared, "Go down from the top".
- **v0.5.1 bug, fixed:** "Leave" in a talk window did nothing (main.gd only closed a screen when another
  was under it). `--uitour=flow` now checks Leave, Back, the gate and walking out (41 checks).
- **Dialogue box:** `scripts/ui/hub_talk.gd` (pages first, then the person's choices as buttons).
- **Sword swing:** `"melee"` in the knight's row of `heroes.gd`, `player.gd` `_swing()`: an arc in front of
  him hits everything at once and cuts enemy shots down; a boss's guard (`shielded`) stops it. Shot items
  still help: extra shots = harder swings, extra range = a little reach. The white crescent is code-drawn.
- **Block:** rebuilt in v0.7.0 (see the next section). Keys Q / Shift, gamepad left shoulder. The bot never
  blocks; `--holdblock` holds it up for tests. The guard is code-drawn half-rings (no shield art yet).
- **Test flags:** `--autotest --level=<id>` (the bot plays that level; add `--goto=boss --bosshp=40` to
  finish it fast; prints the chapter and kit), `--hub --hublevel=<id>`, `--hub --hubtalk=<npc id>`.
- **Not balanced yet:** the knight's sword against all seven bosses, level length, and how strong a kit of
  kept items makes the later levels. The bot swings at air a lot; judge by playing.

## Sword items, block, camp upgrades, quest list — v0.7.0
Asked for by the owner on 11 Nov 2026 ("make the upgrades work with the sword realistically ... make the
camp better and more open ... a quest list on the top left ... a compact and better GUI ... block easier
to use but only 2 attacks then a cooldown").
- **Items fit the sword.** Every stat and flag the items set has a meaning for a swing; the table is the
  comment above `_swing()` in `scripts/entities/player.gd` (`melee_reach()`, `swing_rate()`, `_cut()`), the
  words are the `desc` / `curse` lines in `scripts/data/items.gd`. Names and icons are unchanged (they read
  as relics he carries). The 13 items that needed the Hungry Curse are marked `"needs_curse": true`, never
  offered, and hidden in the Collection (`Items.ids()`). "Cursed" items are called RISKY in the game now.
  The knight's `range` (100) and `shot_speed` (150) in `heroes.gd` are only the base those items scale.
- **Block:** tap or hold the second button. The guard covers ALL sides (nothing to aim), stops
  `BLOCK_HITS` (2) blows, then breaks; it is whole again after `BLOCK_COOLDOWN` (5 s; a blow taken starts
  the same rest). Guard up = walking at 60%, no swinging. The touch button shows two pips and the ring.
- **Camp upgrades (`scripts/data/upgrades.gd`):** the smith sells Sharpen (+10% damage x3), Balance (+7%
  swing speed x3), Draw out (+reach x2), Mend the guard (block 1 s sooner x2); the cook sells A proper meal
  (+1 heart x3). Paid from the camp chest (`bank:coins`, filled only by walking out alive). Kept as
  `up:<id>` in the save's hub section; `player.gd setup()` applies them (stats layer "camp").
- **Quest list (`scripts/ui/quest_list.gd`):** top-left, under the hearts in a level and in the camp. First
  line is the goal ("Beat <boss>" / "Go down: <level>"), then the Druid's three quests with progress; in
  the camp also the chest's coins. During a fight it shows the goal only, so it never hides a monster.
- **GUI:** smaller minimap (5 x 4 rooms, it scrolls), smaller dialogue box and choice windows.
- **Camp:** 720 x 464 now (was 576 x 368), open ground round the fire, six trodden paths (`Hub.PATHS`), the
  forest wall plants itself to fit the map (`hub.gd _build_forest()`), people turn to the hero, and those
  the pack drew walking stroll round their post (`_stroll()`). The Free Pack NPCs have no walk frames.
- **Not checked by a person:** how strong stacked sword items are (bot fights were about twice as fast
  with five of them), upgrade prices, and whether 5 s of block rest feels right.

## The owner's interview answers (11 Nov 2026, after v0.7.0) — the roadmap
Twelve questions, asked with multiple choice. These are decisions; build toward them in the order below.
- **The camp becomes a small village with exits into a wider world** ("all of these": bigger clearing,
  buildings you can enter, and walking out into other areas).
- **You spawn in your home: a room in the tavern** (the tavern is a building in the village; the cook and
  others are downstairs). A bed, a chest and a mirror for customizing belong there.
- **Travel is walking screen to screen** (areas join edge to edge, the next screen slides in). No map menu.
- **First new area: the Fairy Forest** (elves, druids, hunters, outdoors). The others come later.
- **Camp life, all four:** a shop for items (chest coins), people with side stories who arrive as the
  story moves on, a training yard (dummy and safe monsters), day and night and weather.
- **Attack stays on the right stick** (no attack button).
- **Weapons to switch between, all four:** great axe (slow, wide, shoves), spear (long, narrow), war hammer
  (very slow, stuns, breaks rocks), twin daggers (very fast, short). **Got by a mix:** some from bosses,
  some bought at the smith, some hidden in secret rooms.
- **Difficulty: an Easy / Normal / Hard switch in Settings.**
- **Customizing:** name your knight (people in the story use it), armour colour (a tint), weapon look
  (which pack picture he carries). NOT a choice of body.
- **Story, all four:** bosses speak before the fight and as they fall; scenes at the camp after each seal;
  an opening scene (the knight arrives at the village at night); notes and carvings to find in the levels.
- **Text and button size on the phone: good as it is.** Do not enlarge or shrink them.
ALL SIX STEPS ARE BUILT (see "The roadmap, built" below). The order was: 1 difficulty switch + naming + armour colour +
bosses speak (small, quick); 2 the village with the tavern home, shop and training yard; 3 screen-to-screen
walking and the Fairy Forest; 4 the four weapons; 5 camp scenes, opening scene, notes, side stories;
6 day and night, weather.

## The roadmap, built — v0.8.0 and v0.9.0 (12 Nov 2026)
The owner said "start from 1 to 6"; all six steps of the interview roadmap are in. Nothing here has been
played by a person yet: every number is a first guess.
- **1 Difficulty, your knight, bosses speak.** `G.DIFFICULTY` (enemy health, monsters per room, extra
  hearts, block hits) and the Difficulty row in Settings. `scripts/data/looks.gd` + `scripts/ui/customize.gd`:
  name (every "Aldous" in story text is replaced, `Looks.say`), armour colour (a tint), sword look.
  `Heroes.by_id("knight")` hands out the row with all of that applied. `Story.BOSS_SAYS`: a line when a
  boss fight starts and one when it ends (shown as banners).
- **2 The village.** `scripts/data/places.gd`: every walkable place. `scripts/hub/hub.gd` shows one at a
  time (`enter()`), with walls (`blocks`), doors and screen edges (`exits`, a short fade) and people.
  "ghost" people are figures already painted into a picture. Play starts in `room` (your room at the
  tavern: bed, looking glass = customize), then `hall` (barkeep = `scripts/data/shop.gd`, restocked each
  descent), then `village`. Interiors are cut from the pack's own finished tavern picture
  (`tools/import_hub.py` HALVED). The tavern outside is wall + roof + doorway pieces. The training yard
  (Sergeant Brandt) is a run with `G.next_run = {"training": true}`: one room, a straw dummy, sparring
  monsters that come back, no death, nothing counted or kept.
- **3 Walking out, the Elfwood.** Village east edge -> `elfwood` -> `glade`. The glade's Warden opens the
  side levels `Story.SIDE` (wood_1, wood_2). Side levels use `Floors.EXTRA["forest"]` and
  `scripts/run/forest_look.gd` (grass, tree walls, bramble / boulder / rune-stone doors, sinkholes) and
  end with a CHAMPION (`"champion"`: one monster with 5x health and a guard) instead of a boss.
  `run.scale_floor` (a level's `"tier"`) sets monster strength. Seven forest monsters in `enemies.gd`
  (thorn-sick elves, mushroom folk). The owner picked "walk screen to screen": places join at their edges,
  but the change is a fade, not a slide.
- **4 Weapons.** `scripts/data/weapons.gd`: sword, great axe (forge at the smith, 60 coins), spear (clear
  the Singing Glade), war hammer (beat Stonejaw; stuns, smashes rocks), twin daggers (first secret room
  found in a Warrens level). Switch at the smith. `--weapon=<id>` forces one for tests.
- **5 Story.** `Story.OPENING` (once, in your room), `Story.SCENES` (the Druid, in the village, after the
  2nd, 4th, 6th and 7th level), `Story.NOTES` (8 pages; `scripts/entities/note.gd` lies in treasure and
  secret rooms of story levels; the Chronicler keeps them), side-quest people who arrive (`"from"` in
  `hub.gd` NPCS, `Quests.SIDE`: Mira, Brother Halm, Captain Rusk).
- **6 Day, night, rain.** `hub.gd` `_weather()`: `G.world_clock` runs out of doors (a day = `DAY_LENGTH`
  360 s), `SKY` colours, lamps brighter and fireflies at night, rain about a quarter of the time. The bed
  in your room sleeps to nightfall or to morning. `--clock=<0..1>` sets the time for tests.
- **Test flags added:** `--hub=<place>`, `--story` (story moments also while taking pictures), `--yard`
  (with `--autotest`: the bot spars), `--level=wood_1`, `--weapon=`, `--clock=`.
- **Known rough edges:** the hero walks over tables' shadows and chandeliers in the hall (they are part of
  one flat picture); forest rooms use the hill's room layouts; the champion is a tough normal monster,
  not a written boss fight (a werewolf and nine other spare bosses are cut and unused); weapons other
  than the sword have no "look" choice; rain has no sound; prices and rewards are untested.

## v0.9.1 (12 Nov 2026): "your buttons for menus keep not working", and the intro
- **Most likely cause, fixed:** every buy button in the camp (smith, cook, barkeep, forge) was DISABLED
  while the camp chest was empty, and the chest only filled when the hero walked out alive. A player who
  died or never used "Back to camp" had 0 coins for ever and a camp full of dead buttons. Now: a choice
  you cannot take is greyed but still answers (it says why: `hub_talk.gd _say_why`, option key `"why"`),
  and HALF the coins carried reach the chest on death (`Story.fall`, `FALLEN_SHARE`); the end screen
  shows "To chest". NEVER ship a disabled button without a reason on screen.
- **Checked and ruled out:** a second finger tapping a button while the first rests on the walking
  stick. The flow test does exactly that and passes with the engine's own touch handling.
- **Story moments could be lost** when they fired during a fade on a slow phone (and were still marked
  seen). `main.gd` now keeps the words (`_waiting_talk`) and shows them when the fade or the open window
  is done.
- **The intro** (`Story.OPENING`): seven pages on a black screen under the game's name, right after Play
  the first time (save key `seen:opening2`, so players of v0.9.0 see it once too). The bed in your room
  has "Remember how it began" to watch it again. `--hub=room --story --shots=<dir>` photographs it.
- A tap on the talk box is counted once (a phone sends a touch and a click for one tap).
- Still NOT confirmed on the owner's phone: which buttons they meant. If it comes up again, ask which
  screen, which button, and what they see.

## v0.9.2 (12 Nov 2026): the animated intro
The owner, after seeing v0.9.1's words on a black screen: "No, an animation for the intro showing it."
- **`scripts/hub/intro.gd`**: a cutscene of seven shots built from pack art and moved by code (people
  walk, rune stones light and die, the hall turns red, rain, the Starved King rising out of the dark),
  with one caption per shot in a black bar. Shots, words and seconds are `Story.INTRO_SHOTS`.
  Tap = next shot; Skip button or Back = end. `main.gd show_intro()` plays it the first time Play is
  pressed (save key `seen:cutscene`), then you wake in your room; the bed's "Remember how it began"
  plays it again.
- To add a shot: a row in `INTRO_SHOTS` and a function in intro.gd named in the `match` of `_build()`.
  Helpers: `_grass()`, `_trees()`, `_prop()`, `_path()`, `_glow()`, `_actor()`, `_knight()`, `_walk()`;
  a shot's own motion is a lambda put in `_tick`.
- Test: `--intro` (plays at once; `--speed=8` to run it fast; prints "[main] intro finished"),
  `--intro --shots=<dir>` (one picture per shot). The flow test skips the intro (`--uitour`).
- The text-only `Story.OPENING` of v0.9.1 is gone. When the owner says "intro" they mean something to
  WATCH. Prefer showing over telling for story beats.

## v0.10.0 (12 Nov 2026): the wide world, three camps, a far longer and harder story
The owner finished ALL of v0.9 in about five minutes and asked: "make the game a lot longer ... harder ...
story development ... go to a different camp ... it zooms outside of the giant map. But you're bigger so
you can travel faster." What was built:
- **The world map** (`Places` id `world`, 2000 x 1120): leave the village by its new SOUTH road and the
  camera pulls back to half size while the knight grows to double (`"zoom": 0.5`, `"hero_scale": 2`,
  `"speed": 2.5`; `hub.gd _go()` + `_set_zoom()`). Grass and woods in the west, sands in the middle and
  south-east, bare rock in the north-east (`"regions"`: ragged textured polygons). Places on it carry a
  floating name (`"signs"`: gold = work to do, grey = shut, green = done). A fight area is a "ghost"
  person with `"role": "gate"`; a camp is an exit with `"need"` (the level that opens the road) and
  `"why"` (the banner shown while it is shut; the knight is turned back).
- **Two more camps**: `dustwatch` (Desert pack: sand, obelisks, the cistern stair) and `emberfall`
  (Forge pack: rock, flagstones, lava pools, the forge arch). Each has a gate keeper, a smith
  (`"as": "smith"` sells the village smith's upgrades and weapons), a trader (`role` shop), a quest
  giver, and a fire to rest at (`role` bed). Walking into a camp saves `hub:camp`; Play opens there
  next time (`Places.start()`).
- **The story is 12 levels in a fixed order** (`Story.LEVELS`, was 7): Crypt x2 (village gate) -> the
  Robber Road (world map) -> the Bone Dunes (world map) -> Warrens x2 (Dustwatch) -> the Cinder Pass
  (world map) -> Ashen Halls x2 (Emberfall) -> the Sunken Archive (world map) -> the Pit x2 (village
  gate again; the last is the Starved King). Plus the two Elfwood side levels. Every row has a `"site"`;
  rows of one site are one descent (`Story.after`). A site opens when every row above it is cleared
  (`Story.is_open`). One generic gate in `hub.gd _talk()` serves every gate keeper and map spot
  (`"sites": [...]`). `Story.SITES` names each site for the quest list ("Next: X, at Y") and says where
  a run puts the hero back (`main.gd` remembers the exact place and spot he went in by).
- **Road areas end with a CHAMPION**, not a boss: Red Marrow the Road King (bandits, new monsters from
  the Hideout pack's bandit sprites), the Dune Gorgon (`pc_medusa`), the Keeper of the Pass
  (`pc_stone_golem`), the Head Archivist, the King's Butcher. Rows are at the end of `enemies.gd`;
  their opening lines are `Story.CHAMPION_SAYS`. `Floors.EXTRA` has `road` (forest look) and `desert`
  (`"dress": "desert"`: `forest_look.gd` builds the room from Desert pieces; add a dress = a row in its
  `DRESS` table).
- **Longer**: 10 to 13 rooms a level (were 6 to 10) and the boss room is at least half the rooms away
  from the start (`FloorGen.generate(rng, rooms, boss_far)`). The bot needs about 3.5 minutes a level,
  so roughly an hour for the story without the camps and the walking.
- **Harder** (`G.DIFFICULTY`): every row went up (Easy is about the old Normal), plus `boss_hp` and
  `speed` (monsters move 12% faster on Normal). Bosses 2 to 6 got more base health (`bosses.gd`).
  Champions have 8x health (was 5x). The knight's sword does 5 (was 6). Up to 12 monsters a room.
  Monsters and bosses gain 4% health per item the hero carries, up to 15 items (`G.ITEM_HP`).
  Bot, bare kit, Normal: the two Crypt levels cost 8 to 11 half hearts (was 1 to 2); it dies about once
  in the Warrens and the Ashen Halls. Nobody has played it by hand.
- **Story**: the seals are now anchors spread over the land (top of `story.gd`). New: `Story.ARRIVALS`
  (spoken once on first entering the world map, Dustwatch, Emberfall), scenes after the 2nd, 6th, 9th,
  10th and 12th level, lines for nine new people, four more notes (12 in all), `TALK` re-keyed to the
  new chapter numbers (0 to 12; the table is above `TALK`).
- **Old saves** (`Story.migrate()`, once): the Crypt stays cleared, every later level is to play again
  in the new order; items, coins, weapons and upgrades are kept; everyone has new lines.
- **Art**: `tools/import_hub.py` `TRIMMED` cuts 57 Desert and Forge pieces, plus four ground tiles
  (`hub_sand`, `hub_paving`, `hub_fflag`, `hub_drock`). Pieces with sand painted round them
  (`hub_dcave`, `hub_dboulder_*`, `hub_dspire_*`, `hub_dpebble_*`) only sit right on sand.
- **Test flags**: `--hub=world|dustwatch|emberfall` (with `--shots=<dir>` a tour of pictures),
  `--hubgo=<place>` (walk through to that place: two pictures, the zoom-out), `--level=road|dunes|pass|
  archive|pit_1|pit_2`, `--hubtalk=site_road` (a map spot's window).
- **Rough edges**: the edge between grass, sand and rock is a plain ragged line; roads on sand are a
  line of small stones; the world map has no wandering monsters (fights are only inside areas); the
  Cinder Pass, the Archive and the Long Stair reuse the hill's indoor looks; champions use ordinary
  monster behaviour with more health; there is no music change between camps.

## v0.11.0 (12 Nov 2026): RPG step 1, levels, XP and stat points
- **`scripts/data/rpg.gd`** holds every rule and number: `need(level)` (XP per level: 30, 53, 82 ...),
  `POINTS_PER_LEVEL` (3), `MAX_LEVEL` (30), `STAT_CAP` (20), the four `STATS` and what one point does
  (Strength +5% damage, Vitality +half a heart, Spirit guard back 4% sooner, Agility +2% walk and +3%
  swing). Spirit is meant to give MANA too once step 3 (skills) is built: change its "each" text then.
- **Saved for ever** in the save's hub section: `rpg:lvl`, `rpg:xp`, `rpg:pts`, `rpg:str|vit|spi|agi`.
  Dying loses nothing. "Reset progress" in Settings wipes it with the rest of the hub section.
- **Earning:** `run.gd gain_xp()` (called from `enemy_killed` and `boss_killed`). A monster gives its
  health / 4, a boss its health / 8, a boss's or summoner's helpers nothing, the training yard nothing.
  A new level refills the hearts, shows a banner and gives 3 points.
- **Monsters keep up:** `Rpg.FOE_HP_PER_LEVEL` (3% more monster and boss health per knight level;
  `enemy.gd _level_scale()`), next to the older `G.ITEM_HP`.
- **Spending:** the Knight screen `scripts/ui/knight.gd` (main.gd screen "knight"). Opened by the new
  **Lv button** under the pause button (`touch.gd`, role "menu"; it glows gold while points wait), by
  C / Tab / gamepad Y (`Controls.menu_pressed` -> `main.open_knight()`), or by the Knight button of
  the pause menu. A stat that cannot take a point says why in the box below. "Take points back" (free)
  shows only in a camp. `player.gd apply_rpg()` turns points into a stats layer "rpg" at once.
- **HUD:** "Lv n" and a blue XP bar after the coin / key / bomb counters. The action and bomb touch
  buttons moved 6 px down to make room for the Lv button; `hud.gd PAUSE_GAP` is 29.
- **Test flags:** `--autolevel` (the bot spends its points evenly), `--touch` (show the phone buttons
  in test pictures). The bot prints `[rpg] level n at t s` on each level-up.
- **Measured (bot, crypt_1 onward, autolevel):** level 2 after 8 kills, level 4 after the first
  boss. Everything else is a guess; nobody has played it by hand.
- The flow test (`--uitour=flow`) now has **57 checks** (9 new ones for the Knight screen).
- Removed five stale `hub_fire_c_f5..9.png.import` files (their pictures were deleted long ago and
  every camp visit printed load errors).

## v0.12.0 (12 Nov 2026): RPG step 2, gear and the Gear page
- **`scripts/data/gear.gd`**: 23 pieces in three slots (helmet, armour, ring) and three rarities
  (Common white, Rare blue, Epic purple). Every key of a row is explained at the top of the file.
  A piece is found ONCE and owned for ever (`gear:<id>`), one is worn per slot (`worn:<slot>`); a
  second copy is sold for coins on the spot. The first piece found for an empty slot is put on at once.
- **What gear can do:** `hp` (hearts), `shield` (blue hearts at the start of each level), `ward`
  (chance a blow glances off; hits are whole half hearts, so "less damage" would do nothing; capped
  at `WARD_CAP` 50%), `mods` (damage, swing speed, walking speed, coins, luck), `xp`, `guard`.
  `player.gd apply_rpg()` applies it together with the stat points (stats layer "gear", `glance`).
- **Where it comes from:** monsters (`DROP_MONSTER` 1.2%, elites 10%), chests (12%, rich 35%), every
  boss and champion (always one piece: Rare, 40% Epic; `run.gd _boss_gear()`), and the smiths
  ("Helmets, armour and rings" -> `hub.gd shelf_info()`, the 3 cheapest pieces not owned, priced
  rows only, by camp: `Gear.CAMP_TIER`). A piece on the floor is a pickup with the id `gear:<id>`
  (`pickup.gd`); `run.gd found_gear()` hands it over and shows the banner. A row's `"tier"` says how
  deep in the world it first turns up (`run.gear_tier()` = the level's monster strength, 0 to 3).
- **Pictures:** Raven Fantasy Icons again (the pack the item icons come from), listed in `EXTRA` of
  `tools/import_icons.py` and written as `assets/art/icons/gear_*.png`, byte for byte. The pack's zip
  is in git now (`assets_raw/icons/raven_fantasy_icons/`; it was lost with a cloud session once). To
  browse the pack for more pictures (skills: spell icons are numbers 737 to 1060) draw a numbered
  sheet from the zip's `Separated Files/16x16/fa<n>.png`.
- **The Gear page** of the Knight screen (`knight.gd`, buttons Stats / Gear in the top bar): weapons
  (carried one marked; they can only be changed in a camp, and the row says so inside a level), then
  each slot's pieces. Tap = wear, tap again = take off; the box below says what it does.
- **Test flags:** `--gearrain` (half the monsters drop a piece). The bot prints `[rpg] gear <id>`.
- The flow test has **64 checks** now. `dev/validate.gd` checks every gear row (slot, picture, effect).
- **Guesses to check by playing:** drop rates (the bot found about one piece per level plus the
  boss's), prices against how many coins a level pays, how strong `ward` feels.

## v0.13.0 (12 Nov 2026): RPG step 3, skills, magic and mana
- **`scripts/data/skills.gd`**: the 8 skills (4 sword moves, 4 spells), the level each is learned at
  (2, 3, 5, 7, 9, 11, 13, 15), mana cost, rest ("cd") and the numbers each uses ("p"). Two are carried,
  on skill button 1 and 2 (`skill:0`, `skill:1` in the save's hub section). A newly learned skill
  drops into an empty button by itself (`learn_at`, called from `run.gd gain_xp()`).
- **`scripts/entities/hero_skills.gd`**: mana and what each skill does (one function per id, named
  in `_cast()`). `player.skills` holds it; `player._on_skill()` casts on `Controls.skill_pressed`.
  Sword skills use the blow's damage and respect a boss's guard; spells also grow with Spirit and
  pass a guard. Stuns on bosses are cut to a flinch. Effects are code-drawn: `fx.ring`, `fx.burst`,
  and the new `fx.bolt()` (a jagged line). Fire Bolt is a shot of the new type `firebolt`.
- **Mana:** 20 + 4 per Spirit point, refills 1.2 a second (+0.08 per Spirit); spells +6% per Spirit
  (`Skills.MANA_*`, `REGEN_*`, `SPELL_PER_SPIRIT`). Spirit still shortens the guard's rest.
- **Buttons:** touch: two round buttons left of BLOCK and the bomb (`touch.gd`, roles `skill0` /
  `skill1`; a button with no skill is NOT drawn). Keys 1 / 2 (also F / R), gamepad X / B.
  A press that does nothing says why in orange near the bottom (`G.skill_refused` -> `hud.gd _note`).
- **HUD:** a blue mana bar under the hearts once the first skill is known, with a tick at each
  carried skill's cost (`hud.gd _stack_left()` places hearts, mana, counters, quests).
- **Skills page** of the Knight screen: tap a skill, then "On button 1 / 2". A skill not learned
  yet says at which level it comes.
- **Pictures:** `skill_*.png`, Raven Fantasy Icons, in `EXTRA` of `tools/import_icons.py`.
- The bot presses a ready skill about once a second when a monster is close. Flow test: **70 checks**.
- **Guesses to check by playing:** every cost, rest and damage number; whether two more buttons
  crowd the right thumb; whether 20 mana is too little before any Spirit.

## v0.14.0 (12 Nov 2026): RPG step 4, the companion
The owner was shown five women from the purchased packs and picked **C, the blonde mage**
(`pc_scholar_censor`); she fights **from range**; out of health she **gets back up** when the room is clear.
- **`scripts/data/allies.gd`**: one row per companion (today one: Seraphine, "Sun-mage of the
  Archive"; name, title and her three pages of talk are placeholders). `"from"` = the chapter she
  turns up at (1: after the first level), `"place"` / `"pos"` = her post (the village, by the fire).
  Save: `ally:<id>` (joined), `ally:with` (who travels with him; one at a time).
- **`scripts/entities/ally.gd`**: what she does in a level. Follows the knight, keeps `"keep"` px from
  the nearest monster, shoots the nearest one in `"range"` (`"damage"` 0.55 x the knight's own blow,
  one `sunbolt` a second), loses half a heart to a monster's body or shot (monsters do not hunt
  her), is knocked down at 0 and gets up whole when the room is clear. Her hearts are pips over
  her head. `player.ally` holds her; `run.gd` moves her between rooms like the familiars.
- **In the camps:** `hub.gd enter()` puts her at her post (role "ally", a gold "!" until she has
  joined); "Travel with me" -> main.gd `hub_ally`. While she travels she walks behind the knight in
  every camp and on the world map (`_build_follower`, `_move_follower`: a look only).
- **Party page** of the Knight screen (4th button): who she is, her numbers, and a button to send
  her back or call her along (`party_set`); inside a level the button says why it changes nothing.
  The Knight screen's top bar has no title any more (four buttons); his name is under his picture.
- **The monster "Censor"** of the Pit / Archive wears the same body, so it is washed violet now.
- **Test flag:** `--ally=sera` (she comes along without having joined). Flow test: **75 checks**.
- **Measured:** bot fights were about a third shorter with her (6.6 s against 10.3 s). If she makes
  the game too easy, lower `"damage"` or `"rate"` in her row.
- **Not built:** she does not come to the training yard; she has no skills of her own, no gear, no
  lines during levels or after bosses; there is only one companion.

## v0.15.0 (12 Nov 2026): RPG step 5a, Zelda-style dungeons (fixed maps, boss key, small key)
The owner picked "a mix": a fixed map per dungeon with locked doors, small keys, a boss key and
one treasure, the rooms themselves from the layouts already made. All of it is in `run.gd` under
the heading "keys" (read the comment there first).
- **Fixed maps:** a story level's floor is generated from its ID, not from the run's seed
  (`_generate_floor`), so each dungeon is the same on every visit. `--randommap` shuffles again.
- **Boss key:** in a level that ends at a BOSS (`run.uses_keys()`; not the outdoor champion levels,
  not the yard) the boss door is SEALED (door record `"sealed"`). The boss key drops when the
  deepest fight room that is not next to the boss room is cleared (room record `"boss_key"`,
  pickup id `boss_key`, picture `key_boss` = a red key from the Raven icons). Picking it up breaks
  every seal (`take_boss_key`). The HUD shows the key beside the counters; the quest list says
  "Find the boss key" until then; pushing the sealed door says what it needs.
- **The seal's look:** code-drawn (`room_look.gd _seal_mark`): an iron bar with a gold keyhole
  under the red skull.
- **Small key:** one other fight room always drops a key (`"small_key"`), so the locked treasure
  room can always be opened. That room now also holds a Rare piece of gear.
- **Bot:** treats a sealed door as a wall until the key is found; it found the key and reached the
  boss in crypt_1, crypt_2, warrens_1 and warrens_2.
- **IMPORTANT for tests:** a story level is only played through the MAIN scene:
  `godot --headless --path . -- --autotest --nosave --level=crypt_1 ...`. With
  `res://dev/world_test.tscn` the `--level` flag is ignored and an old-style run starts.
- **Test flags:** `--nokeys`, `--randommap`, `--sealtest` (with `--goto=boss`: keep the seal, to
  photograph the door). The bot prints `[rpg] boss key at t s`. Flow test: **77 checks**.
- **Measured (bot with Seraphine, autolevel):** boss key after about 75 to 100 s, level 6 after
  the two Crypt levels.
- (The roaming-monsters question raised here was answered: see v0.16.0.)

## v0.16.0 (12 Nov 2026): RPG step 5b, monsters roam the world map
The world map (`hub.gd`) has no fighting code; fights only exist in the one-screen rooms. Asked how
a meeting should work, the owner picked **"touch = quick battle"** (not fights on the map itself).
- **`scripts/data/roamers.gd`**: `KINDS` (one per terrain: grass = the forest look, robbers = the
  road look, sand = the desert look, rock = floor 3 indoors, "a cinder cave", because there is no
  outdoor rock look), `SPOTS` (13 roamers: where each lives, how far it strays, from which chapter),
  and the numbers (`SEE`, `LOSE`, `WALK`, `CHASE`, `TOUCH`, `GRACE`, `RESPAWN` 240 s). Which roamers
  are beaten is a static table: it lasts while the app runs.
- **On the map** (`hub.gd _build_roamers`, `_move_roamers`): each strolls round its spot, comes for
  the knight inside `SEE` (a red "!"), is slower than he is, gives up past `LOSE`, and on a touch
  sends `hub_encounter`. Nothing chases for `GRACE` seconds after he arrives, nor during a picture tour.
- **The fight** is a run whose "level" is `Roamers.fight(spot)`: `"encounter": true`, one COMBAT
  room in that terrain's look and tier (`run.is_encounter()`; `_generate_floor` builds the single
  room). When the room is cleared everything on the floor flies to him, he gets a few coins, and
  1.6 s later the run ends as a win. `main.gd _on_run_ended` then skips the end screen: coins to
  the camp chest (`Story.walk_out`), the roamer marked beaten, back to the exact spot
  (`_back_to_world`), and a banner "Won: +XP, coins" (`hub.say`). A death shows the usual end
  screen; "Try again" repeats the fight, "Camp" puts him back on the map.
- XP, gear drops, skills and the companion all work in these fights (they are ordinary rooms).
  The pause menu cannot leave one ("No way out: win the fight").
- **Test flags:** `--encounter=<spot number>` (main scene; the bot fights that pack),
  `--hub=world --shots=<dir>` (the map with its roamers). Flow test: **81 checks**.
- **Rough edges:** roamers walk through trees and props (no collision); the rock region's fight
  is an indoor Ashen room; roamers do not scale with the knight beyond the usual level scaling;
  beaten roamers come back when the app restarts.

## v0.16.1 (12 Nov 2026): the look test of the lit 3D battle stage
One battle scene to LOOK at; nothing fights. Title > "Battle look (test)", or `--look` (with
`--shots=<dir>` it writes `look.png` and quits). The button and `preview.gd` go when battles are real.
- **`scripts/battle/stage.gd`**: the stage. `LOOKS` has one row per place (only "forest" so far:
  colours, lights, which pack pieces). `build()` makes the camera (fixed, 30 degrees, looking a
  little down), the sky light, the ground, the scenery, drifting sparks, light beams and the last
  pass. `stand(id, at, faces_left)` puts a fighter on it, `prop()` a piece of scenery, `lamp()` a
  small light. One world unit = 16 art pixels; x right, y up, z towards the camera.
- **`scripts/battle/sprite3.gd`**: a pack sprite as a flat picture in 3D (animated from
  `Art.frames`). Its shader lights it by every light near it without caring which way it faces.
- **`scripts/battle/preview.gd`**: the look test: places the knight, Seraphine and three wood
  monsters, and a MOCK battle menu (turn order, party bars, four orders, an fps counter).
- **The ground** is ONE tile of the pack's ground sheet (`ground_tile`), laid by a shader that turns
  each tile at random (`hub_grass.png` is two different tiles side by side, not a repeating one).
- **Shadows are flat pictures, not shadow maps**: each standing thing gets its own picture laid
  on the ground, leaning away from the sky light, painted as darker ground (`SHADOW_CODE`).
- **The last pass** (`POST_CODE`, a quad in front of the camera): blur by distance from the
  fighters (22 samples), warm lights and cool shade, dark corners. Glow, mist and tone are the
  Environment's.
- **Lessons paid for (do not repeat):**
  1. Real shadow maps are OFF on purpose. In the Compatibility renderer a shadowed sky light is
     drawn as a second pass over everything, and as the scene grew (about 118 separate things, or
     the batched scenery) that pass came out with no shadows and washed-out light. It was never
     explained; the flat shadows are cheaper on a phone anyway.
  2. Scenery must be BATCHED: `prop()` only collects, `_flush()` makes one MultiMesh per kind.
     Only things that animate or change (`stand()`) are their own node.
  3. The last pass reads the picture BEFORE see-through things are drawn. Anything drawn with
     blending (sparks, beams) needs `render_priority` above 0 or it disappears under the blur;
     anything that must be blurred must be solid (cut-out, not see-through). That is why shadows
     are solid darker ground instead of a see-through black.
  4. Green grass barely shows warm light. The ground is drawn 30% greyer (`grey`) and the fire is
     strong (`fire_energy`); lamps are turned down for sprites in `sprite3.gd` so they do not burn out.
  5. Screenshots here use a software renderer (about 5 fps for this scene): that says NOTHING about
     the phone. The fps counter on the look test is there so the owner can report the real number.
     If it is slow: fewer blur samples (`TAPS`), then no blur on low settings.
- **Not done:** weapons and hands on the fighters (the pack draws bodies without arms; the 2D game
  adds them in `hero_look.gd` / `hands.gd`), other places than the forest, any battle rules.

## v0.17.0 (12 Nov 2026): every place you walk in, in the lit 3D look
`hub.gd` is UNCHANGED in what it does: it still builds each place as a flat 2D picture and moves
everybody in it. `scripts/hub/view3d.gd` shows that picture as a lit 3D place instead:
- **How:** `hub.gd` makes the view in `_ready` and calls `rebuild()` at the end of `enter()`. The
  view hides `_stage` and copies it every frame:
  - everything flat on `_stage` (ground, regions, paths, decals, a room's art) is MOVED into a
    SubViewport, painted once, and used as the floor texture;
  - every child of `_ysort` becomes upright cards on the same spot (2D x, y = 3D x / 16, z / 16;
    a sprite's own offset, turn, size and flip carry over, so the knight's sword and hands just
    work). Still things are batched (MultiMesh per texture); anything animated, the knight, people
    and roamers are followed live (`_sync_holder`);
  - the day's `CanvasModulate` colour becomes the sky light and mist; each `PointLight2D` an
    `OmniLight3D`; fireflies follow `_flies.emitting`;
  - every `Label` (signs, "!", the name prompt) gets a copy drawn over the 3D picture.
- **So: to add things to a place, keep adding them in `hub.gd` / `places.gd` as before.** A flat
  thing goes on `_stage`, a standing thing in `_ysort`; the view picks both up. Anything drawn by
  a `_draw()` on a STANDING node is not copied (only Sprite2D and AnimatedSprite2D are).
- **Camera:** stands where the 2D camera is and shows the same width of ground; looks down 44
  degrees outdoors, 62 in rooms (a room is one painted picture; seen flatter it looks like a
  leaning board). Cards lean back 12 degrees outdoors, 45 in rooms, so people are not squashed.
- **Colours:** tone mapping is LINEAR here so the pack's colours stay as painted (the battle stage
  uses filmic for its night mood); glow only on things with `shine` (flames, lava, rune stones).
- **Settings > "3D look"** (`look3d` in the save, default on) and `--flat` give the old picture.
  Tests without a screen (`check.sh`) never make the view.
- **Checked:** the flow test (81 checks) runs through it; pictures of the village by day and
  night, the world map, both rooms, Dustwatch, Emberfall, and the walk from village to world.
- **Not done / rough:** rain is still the flat 2D rain over the picture; rooms are lit evenly (no
  lamps of their own); the far ground past a place's edge is plain grass; nothing is known about
  speed on a real phone (the world map paints a 2672 x 1536 floor texture once per visit).

## v0.18.0 (12 Nov 2026): turn-based battles, and soft light
**A roamer's touch on the world map now starts a turn-based battle** (it used to start a
one-room real-time fight). Three files, kept apart on purpose:
- **`scripts/data/battles.gd`**: every number and word. `knight()` and `party()` turn the knight's
  level, stat points, worn gear and learned skills (and the companion who travels with him) into
  battle fighters; `foe()` scales a row of `enemies.gd`; `pack_for(spot)` is a roamer's pack;
  `SKILL` says what each skill of `skills.gd` does in a battle; `ALLY` is a companion's numbers
  and skills; `reward()` is XP, coins and sometimes gear.
- **`scripts/battle/fight.gd`**: the rules with nothing to look at. A round = everybody acts once,
  quickest first. Actions: attack, skill, guard, flee. It returns a list of events to show.
- **`scripts/battle/battle.gd`**: the screen on the 3D stage: fighters (the knight gets his sword
  and hands, others their hand pieces), turn order faces, party bars, the menu (Attack / Skills /
  Guard / Flee; tap a monster or a friend to aim), floating numbers, the result. All Buttons, so
  touch, keys and a pad work. `main.gd show_battle()` / `_on_battle_finished()`: win = back on
  the same spot, that roamer gone for a while; fled = same spot; lost = wake in bed, nothing lost.
- **Rules chosen for now (tell the owner; all easy to change):** everybody starts every battle
  with full health and mana (no potions or inns exist yet); no "Items" order yet; every learned
  skill is offered (the two skill buttons were for real-time); nobody is raised by a heal.
- **Stage** (`stage.gd`): `LOOKS` now has `forest` (late golden day), `forest_night` (the fire),
  `desert`, `rock`; scenery is data (`features`, `glowers`, optional `fire`). The camera looks low
  (`AIM`) so fighters stand above the menus.
- **Soft light:** the last pass got `lift` + `haze` (darks lifted towards a warm colour); day
  looks use a low warm sun, long shadows (never longer than 1.15 x height), gentle bloom. The
  first try was a brown fog: keep `mist_density` near 0.004 and `lift` near 0.03 by day.
  `view3d.gd` got the same warm sun by day.
- **Tests:** `dev/battle_sim.tscn` plays hundreds of battles without a screen and prints win
  rates per level and land (use it before changing numbers). `--battle=<spot>` opens a battle
  (`--knight=<level> --with=sera --night --autotest`). `--hub=world --hubfight=<spot>
  --autobattle` runs touch > battle > back on the map. The flow test (82 checks) fights a whole
  battle with the Enter key.
- **Measured (bot, grass land):** level 1 alone wins always with about half his health left;
  the sands and the road are too hard alone before level 4 (he can flee, 75%).
- **Gone:** `scripts/battle/preview.gd`, the title's test button, `--look`.
- **Not done:** bosses and story dungeons as battles; items; more than one companion in the data;
  attack effects (blows are a step, a flash and a number); battle music of its own.

## v0.19.0 (12 Nov 2026): the story begins (chapter one), and the look of the reference picture
**The story is `scripts/data/tale.gd`** and nothing else needs touching to write more of it:
`STEPS` (the line in the corner), `TALK` (who says what at which step, and the one button that
moves the story on), `BATTLES` and `BOSSES` (its turn-based battles), `ENTER` (walking into a
place), and the places `town()`, `deepwood()`, `beacon()`. Its header explains every key.
- **Chapter one, step by step:** 0 Captain Hale in Wickmere's square > 1 the east road > 2 the
  Rune Glade, Thessaly, a battle beside her > 3 she joins; the Deepwood, the lost wardens (battle)
  > 4 the beacon's hill, Old Bramblejaw (boss) > 5 set the shard in the beacon > 6 the Elfwood
  turns golden; back to Hale > 7 done (60 coins; "the Sands open in the next chapter").
- **Wickmere** takes the old village's place (same id "village"): the Hollow Flagon, four more
  houses built from new pack pieces (`tools/import_hub.py`: walls, a teal roof, doors, windows,
  chimney, fences, post), a paved square with the watch-fire, lamp posts with flames (`"torches"`),
  the sealed gate of Hollow Hill. A house hides the ground behind it as high as its roof: houses
  stand on the north row or at the edges, and that ground is in `"blocks"`.
- **The old story is OFF** while the tale is on: gates, quests, the shop's run items, upgrades,
  the yard only talk (`Tale.RETIRED`); roads with an old `"need"` are shut. The smith sells gear.
  `--oldstory` brings it all back; the old flow test must be run with it.
- **Battles of the story:** `Battles.scripted(id)`; a boss cannot be fled from and every third
  turn strikes everybody (the menu warns: "Guard!"). Every companion who has joined fights
  (`Battles.party()`); Thessaly's numbers are in `battles.gd ALLY`, her row in `allies.gd`.
- **How hard (dev/battle_sim.tscn, bot play):** a knight who fights only the story's battles
  reaches the giant at level 3 (the two battles before it carry `xp_bonus` for that): there he
  wins nearly always with about half his health; at level 2 about 8 in 10.
- **The intro** keeps its seven pictures; its words are `Tale.INTRO`. It plays again once for
  everybody (save key `tale:intro`).
- **Tests:** `--uitour=tale` plays the whole chapter (a bot fights) and prints 16 checks.
  `--battle=story:<id>` opens one story battle. Old flow test: `--uitour=flow --oldstory` (82).
**The look, after the owner sent the golden camp picture and wrote "this is the reference that
is off"** (read as: my look was off from it):
- `sprite3.gd SUN_PART`: the sky light falls in soft drifting PATCHES with a pool of light on
  the spot the camera looks at; every lit shader includes it; the settings are global shader
  uniforms set by `Sprite3.set_sun()` (never call `global_shader_parameter_get_list`: editor only).
- The last pass got `warm`, `shade`, `punch`, `rich`: amber light, brown shade, more contrast.
- Out of doors by day: camera pitch 35 (was 44), stronger blur, darker rim. Night and rooms keep
  the cool even light. First try was too dark and too orange: shade share 0.44, ambient 0.42.
- **Still not done:** the title picture and the intro's pictures are the old flat ones; rain is flat.

## v0.19.1 (12 Nov 2026): "the characters look squished", and spell effects
The owner sent four more pictures of the same reference game (a town street, a spell in a
battle, a harbour, the golden camp) and wrote: "This is a company that I'm trying to make a game
to be like". They are the look to aim for; the house rule stands (same KIND, nothing copied).
- **Squish:** a camera that looks down makes standing pictures shorter. Now they are drawn
  taller by exactly that much: `view3d.gd` divides `_up` by cos(pitch - tilt); in battles
  `Sprite3.tall` (set in `stage.gd _camera`) stretches every standing picture and batch.
  If the camera's angle changes, these follow by themselves. Never "fix" it by scaling sprites.
- **Blow and spell effects** (light and particles only): `stage.gd burst()` and `pillar()`;
  `battles.gd FX` says what each skill looks like; `battle.gd _show_fx()` plays it and shakes the
  camera a little. `--shotfx` (with `--autotest --shots`) writes `battle_fx.png` mid-spell.
- **What the reference has that this game still lacks** (in order of how much it would add):
  real 3D buildings and ground with height (ours are flat cards on a flat floor); water;
  hand-made scenery per place; bigger, layered spell effects; a battle HUD with portraits.

## v0.20.0 (12 Nov 2026): real depth (the owner: "Depth first and grafix and quality")
Asked "depth first or story first", the owner chose depth. Built in `scripts/hub/view3d.gd`
(its header lists the three data keys); Wickmere (`tale.gd town()`) is the first place to use them.
- **`"houses"`**: real 3D houses from one data row each: walls on three sides with the pack's
  wall art (stretched by the camera's slant like the cards), a roof of two slopes covered with
  `hub_roof_planks` / `hub_roof_tiles` (flat stretches cut from the pack's roof sheet;
  `"gable": true` turns the pointed end to the street), a chimney that smokes, a door, two
  windows that glow at night, and a shadow of the house's true outline (`_cast`: the convex
  outline of its corners thrown along `LEAN`). Faces are lit by how they face (`SOLID_CODE`).
  The old flat look shows the same row as flat pieces (`Tale.house_props`).
- **`"rise"`**: the ground climbs behind the place and a mound swells out of the slope (Hollow
  Hill). `_height()` is the one function for it; the floor and the far ground are grid meshes
  (`_grid`); everything standing stands that high; things on the slope throw no flat shadow.
  `hub.gd` plants extra rows of wood up the slope. NOBODY WALKS on raised ground: walking is
  still flat 2D. Do not put a path, a door or a person where `_height()` is not 0.
- **`"water"`**: a pond (`WATER_CODE`: two sliding layers of noise, the sky in it, twinkling
  one-pixel glints, a wet bank; drawn in steps of one art pixel). `hub.gd` blocks it with a
  row of round stops. Wickmere has its mere in the south-west.
- **Also:** plants sway (`_sway_of`); lamp posts carry a glowing glass (a 6 x 8 flat shape made
  by code, `hub.gd _lamp_glass`); out of doors the camera stands 1.3 x further back (`WIDE`)
  and looks a little past the knight, so whole houses fit and people are smaller.
- **Test pictures:** a place may give `"tour"` (where `--hub=<place> --shots` stops).
- **Checked:** `--uitour=tale` 16/16, `--uitour=flow --oldstory` 82/82, `check.sh`; pictures by
  day, by night and with `--flat`.
- **Not done:** the other places have no houses, rise or water yet (the camps, the world map,
  the Elfwood are still cards on a flat floor); houses throw no shade ON people; no steps or
  raised ground you can walk on; the tavern's rooms are still one painted picture each.

## v0.21.0 (12 Nov 2026): depth for the rest of what can be reached
The owner: "ok do that for the rest of the game also I'm letting you [increase] the game [file]
amount to max 5gb and you can use tools and anything to make it more [graphically] better and
cleaner for the entire game".
- **SIZE IS NOT A LIMIT ANY MORE.** The owner, same evening: "no i had no internet you can go up
  to 5gb". The old 69 MB download failed because their internet was down, not because of size.
  So the "small 64-bit APK, about 42 MB" rule in Toolchain is OFF: more art, bigger textures,
  both architectures are all allowed, up to 5 GB. (Bigger is not better by itself: add size
  only where it buys something the player sees or hears.)
- **Read as, and told to the owner:** "use tools and anything" does NOT lift "no AI art or audio,
  ever" (the Credits screen says so to players). They were asked to say plainly if they want that rule lifted.
  Until they do: only the purchased packs, free human-made art with a fit licence, and code.
- **Hills you walk on** (`view3d.gd` `"hills"`, `_height`, `_slope`, `_shadow_ok`): people are
  drawn as high as the ground under them; walking itself is still flat 2D. A hill with a `"top"`
  is a plateau. Flat shadows are dropped for tall things on slopes and for anything on a steep one.
- **Places given depth:** the Elfwood Road (the wood climbs behind, two low rises, a pond), the
  Rune Glade (the ring stands on a low rise), the Deepwood (climbs, two rises), the Beacon of the
  Wood (bigger place now; the knight comes in at the foot and CLIMBS to the stones and the
  beacon on a plateau), the world map (Hollow Hill over its gate, the Cinder Mountains as real
  mounds, dunes, wooded hills, a lake and an oasis; groves keep out of water: `hub.gd _in_water`).
  The Elfwood's and the world's depth is added in `places.gd get_place()` (the story's fitting
  of the old places); the Deepwood's and the beacon's is in `tale.gd`.
- **Battles:** the ground climbs behind the fighters (`stage.gd height_at`), the wood stands
  row above row.
- **Title screen:** `scripts/ui/title_scene.gd`, the battle stage with the knight alone in the
  golden wood and a drifting camera, in place of the flat backdrop (`main.gd _refresh_layers`);
  the tagline is the new story's. Sub-menus dim it with the shade.
- **Checked:** `--uitour=tale` 16/16, `--uitour=flow --oldstory` 82/82, `check.sh`.
- **Still flat:** the two old camps (Dustwatch, Emberfall: not reachable in the story; rebuild
  them with houses and height when chapters two and three are written), the tavern's two rooms
  (one painted picture each), the intro's seven pictures, rain.

## v0.22.0 (12 Nov 2026): "it look weird in my opinion": cleaner look, more art, more story
The owner: "you go in more [graphics] and [increase] the story and assets it look [weird] in my
opinion". They did not say WHAT looked weird, and did not answer the AI-art question (so the
no-AI rule stands). Looking at my own pictures against theirs, I fixed what I judged weird:
- **A grid in the grass.** `hub_grass.png` is two tiles side by side; repeated whole it showed
  rows. The 3D floor now lays ONE tile cell by cell, each turned at random (`FLOOR_PART`), and
  hub.gd's painted picture (paths, paving, sand, decals) goes OVER it by its alpha: in the 3D
  look hub.gd no longer paints the base ground, and the SubViewport is see-through.
- **Orange desert paving in a forest town.** Wickmere's square and streets are cobbles
  (`hub_gcobble`, Garden pack). A paved rectangle is laid with every other tile mirrored
  (`hub.gd _mirrored`), so a tile cut from the middle of a pack's paving never shows a seam.
- **Colours too strong.** By day: less amber, less contrast, a lighter dark rim, gentler patches
  of sun (0.62 to 1.14 of the light instead of 0.44 to 1.22), a little less blur.
**More of the owner's purchased art in use** (`tools/import_hub.py`, ids `hub_g*` Garden,
`hub_c*` Castle): cobbles, a tiered fountain, cypresses, flower beds, garden benches, urns, a
statue that pours water (4 frames; a place's `"anims"` rows: [id, x, y, fps, solid, turned
round]), lily pads (a pond's `"lilies"`: flat on the water), potted trees. Cut but not placed
yet: a basin, a pool, two statues, two banners. NOT yet imported and worth it for later towns:
the Garden pack's hedges, hedge arch and pergola; the Castle pack's walls, stairs, busts, stained
glass, wall candles; the Cave, Sewer, Library and Hideout environment tiles.
**More story:** `Tale.SCENES`: eleven short scenes that play by themselves on arriving
somewhere at a step (Oswin waking you, the town at dusk, the dark road, Thessaly hailing you,
after each battle, the hilltop, the dawn, the open gate, the sisters). Each once (`tale:seen:<id>`).
`hub.gd _story_moment` plays them; with the tale on it no longer plays the OLD story's moments
(it did until now: a real bug nobody had seen because tests skip story moments).
- **Checked:** `--uitour=tale` 16/16, `--uitour=flow --oldstory` 82/82, `check.sh`.
- **Honest limits to tell the owner:** standing things are still flat cards (a fountain or a
  statue drawn from above stands upright like a signboard); the packs hold no town buildings
  beyond the one house kit, no bridges, ships or market stalls. Matching the reference further
  needs either more hand-made packs (the owner would choose or buy them) or lifting the no-AI rule.

## v0.23.0 (12 Nov 2026): skills looked up, game feel, safer combat numbers
The owner: "you can look for assets [or] /find-skills to find skills that can help you upgrade
this game to the next level".
- **Skills found** (`npx skills find ...`): the collection `gamedev-skills/awesome-gamedev-agent-skills`
  (Apache 2.0, 11 to 13 thousand installs a skill) fits this game best: `rpg`, `game-feel`,
  `game-ui-ux`, `level-design`, `camera-systems`, `dialogue-systems`, `create-game-assets`,
  `audio-design`, `performance-optimization`, `save-systems`, `godot-shaders`,
  `godot-3d-essentials`, `godot-animation`, `godot-ui-control`, `godot-audio`,
  `godot-gdscript-headless-testing`. **Installing them was REFUSED by the session's safety
  settings** (third-party code); do not copy them in by hand. The owner can install them
  (`npx skills add gamedev-skills/awesome-gamedev-agent-skills@<name>`) or allow it. Their
  advice was read as reference and applied:
- **Game feel in battles** (`battle.gd _feel`): two tiers (a normal blow; a crit, kill, boss's
  blow or big spell). Each hit adds "trauma" that decays in real time and moves the camera by
  trauma squared along smooth waves (the old shake was a random jitter every frame, which reads
  as static); a freeze of a few hundredths of a second (`_hit_stop`: only the newest freeze may
  end it; `_exit_tree` always restores the time scale); the one hit squashes and springs back
  (`_pop`). The test bot (speed above 4) plays without any of it. Settings > "Screen shake".
- **Combat numbers** (`fight.gd _blow`, `battles.gd`): defence now takes a SHARE of a blow
  (`DEF_HALF` 24 = halved) instead of being subtracted, so nothing can ever be made immune;
  blows vary by 10%; crits 6%. `dev/battle_sim.tscn` prints a targets table: blows to fell a
  common monster (aim 2 to 4) and blows the knight can take (aim 5 to 9), "!" where it misses.
  **Finding for chapter three:** the rock land's monsters take 7 blows even at level 12: too
  tanky; fix their `hp` rows (or `FOE_HP_TIER`) when the Cinder Mountains are written.
- **Assets looked for:** the artist of the owner's packs (Anokolisa) has no Pixel Crawler TOWN
  pack. Same artist, other series, free: "Legacy Adventure Pack - Village" (check the view: the
  Legacy series may be side-on, which would not fit). Other artists: "Fantasy Town" (16x16
  top-down, about 5 dollars), "Era of Fantasy: Village Props". Nothing was downloaded: itch.io
  downloads need the owner, and any pack must be LOOKED at beside the Pixel Crawler art first
  (the house rule: one art style).
- **Checked:** `--uitour=tale` 16/16, `--uitour=flow --oldstory` 82/82, `check.sh`, one battle
  at normal speed with the new feel.

## v0.24.0 (12 Nov 2026): the big polish pass (light, battles, chapter two, towns, UI, sound)
The owner: "make the game fully polished ... revamp graphics and story and everything ... like an old
top-down adventure game or a 2D RPG with really really good graphics, mainly the lighting. Use free
assets and the pack I paid for. It still needs to pass the 'no AI' box on Steam." Six agents worked
in parallel, one area each, then were merged.
- **Steam "no AI":** all art is the purchased Pixel Crawler packs or human-made CC0/CC-BY packs; all
  sound is human-made CC0/CC-BY (licence notes in assets_raw/licence_notes). Light and effects are code.
  BUT the story words in tale.gd were written with AI help: tell the owner to rewrite them in their own
  words before release, or disclose it. Code written with AI help is noted on the Credits screen.
- **Lighting (walking places):** `scripts/fx/walk_light.gd` (new) holds `GRADES` (colours per place:
  "<id>", "<id>:night", "<id>:lit" after its land's beacon, "default", "default:night", "indoors"), `LAND`
  (place -> land for "lit"; the Sands are dustwatch and suncourt), `POST_CODE` (the walking last pass:
  distance haze, bright spill, low-sun glow), and `pool()`, `halo()`, `shafts()`, `motes()`, `flicker()`.
  In view3d.gd every lamp, fire and window gets its light, a warm pool on the ground and a glow in the air,
  all flickering, faint by day; sprites are lit from the side the light is on; sun beams and dust by day.
  A light 20-60 px north of a "torches" spot is moved onto the lamp's glass. Additive things need
  render_priority above 0 (pool 4, beams 5, glow 6, specks 10). `--lightstats` prints draw calls and fps.
  Limits: glows ignore depth (can show through a tree), no real shadow maps, phone speed not measured.
- **Battles:** rim light on fighters (`stage.gd LOOKS[*]["key"]`, `sprite3.gd set_rim`), soft contact
  shadows, lit ground under spells and the turn marker (`ground_glow`), pack FX art played lit
  (`fx_anim`), a boss bar, health bars that drain, whose-turn arrow, enter fade and camera glide,
  victory flash and hop / red defeat fade (`battle.gd _enter`, `_closing`). Rules and numbers unchanged.
- **Story, chapter two BUILT** (steps 7-14 in tale.gd): Dustwatch (the Sands' town, fitted in places.gd
  `_fit_sands()`), the Sunwell (place "suncourt", by the cistern stair) with the Dune Queen and the
  second beacon, the Dune Gorgon boss (world-map ghost "site_dunes"), Seraphine joins after battle
  "dustwall" (the Queen is her mother). Chapter one's lines were polished. A person who must be there
  at an ENTER step needs tale_from = the step BEFORE it. `--uitour=tale` now prints 28 checks.
  allies.gd still has Seraphine's OLD-story text (never shown in the tale). Balance only bot-checked.
- **World dressing:** import_hub.py cuts more of the purchased Garden and Castle pieces (hedges, hedge
  arch, pergola, walls, busts, banners, wall candles). Wickmere's extra dressing is in places.gd
  `_dress_town()`; a hedge's blocking is a Rect2 in "blocks". Dustwatch is NOT dressed yet (bare sand).
- **UI:** StoneBox (theme.gd) gained `trim`, `studs`, `top_light`; new boxes "talk", "plate",
  "portrait"; colour C_BRASS. hub_talk.gd: name plate, `PAUSES` after punctuation, bobbing NextArrow,
  whole-pixel portrait. title.gd: drifting light motes, vignette and name glow. Quick dialogue
  picture: `-- --hub=village --nosave --hubtalk=hale --shots=<dir>`.
- **Sound:** sfx.gd `PLACES` gives each walking place [music, ambience, ground]; a new place needs a row.
  `Sfx.place(id)` (hub.gd enter), `Sfx.walking(...)` (footsteps), `Sfx.battle(boss)` (battles had NO music
  before: "run" had no file), `Sfx.victory()`. New CC-BY footsteps (congusbongus) MUST stay credited.
  Rebuild with assets_raw/audio/ambience_src/build_place_audio.sh (edit its /tmp paths first).
- **Checked after the merge:** check.sh CHECK PASSED, `--uitour=tale` 28/28. Not run: `--uitour=flow
  --oldstory`, APK build.
- **Next, most useful first:** dress Dustwatch with the Desert pieces; move the lamp post that stands in
  the middle of Wickmere's south path; the owner plays a build on the phone (speed with the new light);
  chapter three (Cinder Mountains, Grukk; fix the rock monsters' hp, see v0.23.0).

## v0.25.0 (13 Nov 2026): the HD look on PC (Forward+), round one
Ten agents (foundation, 3 specialists in worktrees, merge, set dresser, 3 judges, fixer). Judges scored
the look 4/10 for lighting, composition and defects BEFORE the fixer's pass. Everything HD asks `Hd.on()`.
- **Renderer:** project.godot `rendering_method="forward_plus"`, `.mobile="gl_compatibility"`,
  `rendering_device/fallback_to_opengl3=true`. `Hd.on()` (scripts/fx/hd.gd) is true only in forward_plus,
  not headless, and not with `--nohd` (to compare looks). Phone / compatibility look is unchanged.
- **Pictures:** `./tools/shot.sh <place> <dir> [--clock=0.7] [--nohd]` (`GL=1` for the phone renderer).
  Forward+ on this container uses software Vulkan (lavapipe) under xvfb: about 80-150 s a run.
  Battle flags: `--battle=story:<id> --shotspell=storm|firebolt|sunbolt|sunflare|frost`, `--shotintro`.
- **Module map (view3d.gd was split):**
  - `scripts/hub/view3d.gd` core: setup, rebuild, cards, words, camera, `_is_person()`, `_person_row()`,
    `_contact_blob` (soft shadow under people). Holds `build`, `water`, `light`.
  - `scripts/hub/view3d_build.gd` ground, height, `build_houses()` (runs `scripts/hub/arch/`), `_cast`, `_smoke`.
  - `scripts/hub/arch/` (NOT `build/`: build folders are git-ignored): `kit.gd` mesh kit (pack pieces at
    true pixel size, `_tri` fixes winding from the wanted normal), `house.gd` (one `"houses"` row; keys
    `floors` 1-3, `upper`, `balcony`, `awning`), `sites.gd` (kerbs, walls, bridge, stalls, bunting per place
    id; positions tied to the current layouts). Tall things only where nobody walks behind them.
  - `scripts/hub/view3d_water.gd` `HD_WATER_CODE` (ripples, glitter and lamp streaks in `SPECULAR_LIGHT`;
    ripple `chop` about 0.02 or the pond turns to frost). No SSR yet.
  - `scripts/fx/card_shader.gd` how sprites are drawn: `CARD_CODE` (phone), `HD_CARD_BODY` (normals worked
    out from the sprite's own pixels: `bevel`, `relief`, `round_body`), HERO block for people (no fog, rim on
    the sun's side, pale pixels held under bloom), `hot`/`hot_col`/`by_night` glow. Call
    `CardShader.set_glow(mat, tex, hero)` whenever a card's texture changes.
  - `scripts/fx/hd_light.gd` all HD light: `HD_*` constants at the top (HD_LEAN low sun, HD_SUN_COLOUR,
    HD_FOG_LENGTH, HD_EXPOSURE_DAY/NIGHT, HD_LAMP_REACH, HD_POOL_REACH, HD_DAPPLE, HD_DOF), `build_lamps`,
    `build_air`, `_sync_hd`, `sync_view` / `_focus_band` (depth of field). `_sync_hd` resets glow_bloom,
    glow_hdr_threshold and fog_enabled every frame because `sync_light` writes the phone values first.
  - `scripts/fx/walk_light.gd` GRADES gained `"dapple"` (leaf patches; 0 = none) and `"exposure"` (HD
    multiplier). POST_CODE only grades in HD (no blur), with `fore_z` darkening what is nearer than the
    walk area's bottom edge. `shafts(..., wide_back)` gives the soft HD beams.
  - `scripts/battle/stage_hd.gd` battles in HD: `LOOK` table per stage look (sun, ambient, fog, fog_aniso,
    exposure, sky, wet, top_rim, fire_boost, spell, tame; missing keys fall back to "forest"), `AIM_HD`
    camera further back. `sprite3.gd hd_code()` holds the fighters' HD shader.
- **What HD does:** AgX tone (white 14), SSAO, SSIL 0.5, glow over a hot threshold (no bloom veil), thin
  volumetric fog, low amber sun with soft PCSS shadows, real shadows from every card, house and roof (cards
  pushed away from the light in the shadow pass, scaled by 1-UV.y so feet stay planted), the 4 nearest lamps
  cast shadows, iron lanterns (`hub_slantern`) with gold glass that blazes after dusk (`hh_lamp_on` 0.3 by
  day, 1 at night), camera DOF whose sharp band holds every visible person. Scenery in front of a person
  drops to a screen-door of about 34% (`hh_people`, `hh_people_n` set by `Sprite3.set_people`).
- **Global shader uniforms** (registered in `Sprite3.ensure_sun`): `hh_lamp_on`, `hh_people`, `hh_people_n`.
- **Props:** a 6th prop field means mirrored. Every `hub_slantern` gets a glowing glass pane (hub.gd
  `_lantern_glass`); its light sits at foot + (16, -33). places.gd `_lanterns()` turns hub_post torches into
  lanterns. Set-dressing pieces: `hub_s*` props (sacks, crates, barrels, `sveg_*`, tables, pennants,
  bedrolls, fire ring), `hub_v*` plants (colours 0 green, 1 olive, 2 amber, 3 rust). Place keys `"stalls"`
  and `"bunting"`; a stall needs a `"blocks"` Rect2. A place's `"tour"` sets where test pictures are taken.
- **Lessons:** custom post shaders read depth 0..1 in Forward+ and -1..1 in Compatibility (branch on
  `CURRENT_RENDERER`; this was the "everything is blurred" bug). A card with an OmniLight inside it needs a
  full light wrap. Additive spell art in FRONT of a target washes it out: put it just behind. Strong forward
  fog looking into a low sun becomes a brown wall (fog_aniso about 0.2 by day). `LIGHT_COLOR` already
  includes pi. A double quote inside a shader string in a .gd file breaks the parse.
- **Limits after round one:** Wickmere is a park with gaps, not a wall of facades; Dustwatch has no houses
  inside its wall; Elfwood has no set piece; no terraces; battle fighters small (about 65 px) and no sky;
  the screen-door dither is visible; only tuned on software Vulkan, never on a real GPU.

## What's next (written 11 Nov 2026, after v0.4.0)
Everything on the v0.3.0 fix list is done and the camp exists. Ideas for the next passes, most useful first:
0. Grow the camp: more quests and rewards worth wanting, walking NPCs, more of the unused cut pieces
   (Sewer, Desert, Library, Garden and Hideout tiles are still only used in dungeon rooms or not at all).
1. The owner plays the newest build on the phone and says what feels wrong (bosses above all). Their notes come first.
2. Grave Robber against floors 2 and 3 bosses: still the weakest hero (see the Bosses table).
3. Forge Warden: the lanes (arm throw, beam) hit the bot most; maybe a longer warning.
4. Starved King: only measured with one 7-item kit; needs a real play-through from floor 1.
5. Tile gaps: a second pillar picture for the crypt and the ashen halls; a ragged hole for blown-open side doors.
6. Still old art: HUD hearts, explosions, the 6 px Curse skull badge.
7. Sound pass for the seven bosses (they reuse monster and door sounds).
8. Boss names are placeholders the owner may want to rename (`scripts/data/bosses.gd`).
Not planned unless the owner asks: anything for publishers (pitch, slides, trailer, store text).
