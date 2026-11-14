# P02: the battle screen (boss staging, aiming, pause, retry, speed)

Files changed: `scripts/battle/battle.gd`, `scripts/battle/battle_ui.gd`.
New: `scripts/data/battle_looks.gd` (every number, colour and new word of this package).
No rule of the fight was changed (fight.gd, battles.gd and the attack animations are untouched).

## What was built

1. **Bosses look like bosses.** `battle_looks.gd BOSS` has one row per boss: `scale`, `tint`, `rim`
   (edge light), `glow` (a pool of light on the ground), `at` (where it stands), `hover`.
   Old Bramblejaw is drawn 1.5x, the Dune Gorgon 2x, the Ember Colossus 2x; a boss not listed gets
   `DEFAULT_BOSS` (1.6x). The plan said 1.6 / 1.8 / 2.2: I used 1.5 / 2.0 / 2.0 after looking at the
   art (the ogre is already twice the knight's height; 2.0 keeps the Gorgon's pixels even).
   A boss's helpers stand in `MINION_AT` (behind and beside it, pushed further out by a very wide boss).
   - The camera steps back by itself until the boss's head is under the top of the screen
     (`battle.gd _frame_boss`, `FRAME_TOP`, `FRAME_BACK`), and the phone look's sharp band is widened
     so the whole boss stays crisp (it was blurred from the chest up at first).
   - The Colossus's art floats 24 px above its feet point. Made bigger it flew out of the picture, so a
     boss row may say `hover` (how much of that air is kept; the Colossus keeps 35%).
   - A scaled fighter uses `BigActor` (a small class inside battle.gd that extends anim_actor.gd and
     multiplies the scale after it). `unit["top"]`, `unit["wide"]`, `unit["big"]` carry the size.
2. **The thorn-sick elves are not Thessaly's twin any more:** `FOE_TINT` washes `elf_stalker` and
   `thorn_elf` a sickly grey-green (also on their faces in the turn rail).
3. **Auto no longer sits on the help strip.** Auto has the key cap **T** (pad Y), the new speed plate
   **F** (pad X). The help strip sits 12 px left of the plates; when that would run into the boss's
   bar (the long "Target / Strike / Back" strip) it drops to a row of its own under the plates.
   Auto, the speed plate and the faces of the turn rail have tooltips.
4. **Aiming is unmistakable:** a pulsing ring and pool of light on the ground under the one aimed at
   (gold for a monster, green for a friend), its edge light pulses, everybody else is drawn at 58%
   (the one choosing at 86%), and the chevron bobs over its head (the name plate moved up to make
   room). Everything is put back on leaving the page. The mouse over a monster or a friend's card
   moves the aim. Right click is one step back on every page.
5. **Pause.** `battle.frozen` (a property): while true the battle does not process at all (nothing
   moves, no turn begins, no button answers) and the time scale is 1 for the pause screen.
   `on_back()` now returns a bool: `true` = it stepped back in the menu (or the result is up);
   `false` = on the orders page or while others act, so main.gd can open its pause screen.
6. **Try again.** A lost fight now shows two buttons: "Try again" (wounds and supplies are put back
   as they were when the fight began, no coins are taken, the battle emits
   `finished("retry", summary)` with `spot`, `night`, `story`) and "Rest and return" (today's way:
   20% of the coins, wake rested). The coins are only taken when "Rest and return" is pressed
   (they used to go the moment the last fighter fell). The line under the buttons says what the
   focused one costs. The bot (`--autobattle`) still pays at once, as before.
7. **A story win is saved at once.** In `_finish()`'s win branch: `Tale.apply(win)` then
   `Save.flush()`; `summary["applied"] = true`, `summary["say"]`, and any other key apply() returns
   as `summary["do_<key>"]` (for example `do_battle`, `do_screen`). The "win" is read as
   `spec.get("win", Tale.BATTLES.get(story, {}).get("win", {}))`.
8. **Kill counts:** each foe of a won fight adds 1 to the save's `kills:<id>` (bosses too).
9. **Speed:** the x1 / x2 / x3 plate; `static var speed_pick`; saved as the setting `battle_speed`
   (read with a null fallback of 1). It only speeds the fight while it plays out, never while you
   choose or read the result; it multiplies with the hold-to-hurry, capped at 6x (`TIME_CAP`).
   A slow-motion moment (the boss's fall) is not hurried by the plate.
10. **Reduce flashes:** when `Save.setting("flashes") == "reduced"` the hit, heal, kill and victory
    flashes are half as strong and there is no hit-stop. (The settings row is P05's; unset = full.)

## Hooks other packages must add (none of these files are mine)

- **scripts/main.gd (P04)**, already in P04's plan:
  - `_back()`: `if not bool(battle.call("on_back")): open the pause screen; battle.set("frozen", true)`
    and `battle.set("frozen", false)` when it closes. Until then Esc on the orders page does nothing
    (as today).
  - `_on_battle_finished()`: outcome `"retry"` -> `show_battle(int(summary["spot"]),
    bool(summary.get("night", false)), String(summary.get("story", "")))`. **Until this is merged
    "Try again" falls into main.gd's default branch: the banner says "You got away." and the knight
    stands where he was (wounds and supplies restored, nothing lost).**
  - when `summary.get("applied", false)`: do not call `Tale.apply` again; use `summary["say"]`.
    (Today it is applied twice, which is harmless for the rows that exist: a step never goes back.
    A future win row with `coins`, `supply` or `gear` WOULD be given twice until P04 is merged.)
  - P13: a win that returns `battle` is in `summary["do_battle"]`, a `screen` in `summary["do_screen"]`.
- **scripts/core/save.gd (P04):** defaults `battle_speed` 1 and `flashes` "full" (read null-safe here).
- **scripts/core/controls.gd (P05):** if an InputMap action `auto` exists, battle.gd uses it for Auto;
  otherwise the raw key T. The speed plate reads the raw key F (no action is named for it).
- **scripts/battle/stage_hd.gd (nobody's this wave):** its depth of field measures a fighter with
  `sprite.height()`, which does not know a boss is drawn bigger. If a boss's head is soft in HD, widen
  the far band there (FOCUS_ROOM) or read the node's scale.
- **P09 / P13 (new bosses):** add a row to `battle_looks.gd BOSS` only if `DEFAULT_BOSS` looks wrong.

## How to test

```
godot --headless --path . -s <scratchpad>/pass/P02/compile_all.gd        # COMPILE DONE ... bad=0
godot --headless --path . -- --uitour=tale --nosave --speed=6              # 43 checks, 0 failed
godot --headless --path . -s <scratchpad>/pass/P02/t_battle.gd -- --nosave # 28 checks (see below)
xvfb-run ... godot --path . --rendering-driver opengl3 --resolution 1600x720 -- \
    --battle=story:colossus --nosave --shotaim --shotfallen --shots=<dir>
```
- New test flag **`--shotfallen`** (with `--battle=... --shots=<dir>`): also writes
  `battle_fallen.png`, the lost fight's screen with its two buttons (a look only).
- `t_battle.gd` is a scratch test (not in the repo: dev/ is not this package's): it opens the Gorgon
  fight without a screen and checks the boss's spot and size, on_back's answers, the aiming look on
  and off, the speed plate and its setting, frozen / thawed, a lost fight (no coins before the
  choice, Try again restores wounds and supplies and emits "retry", Rest and return takes 20%),
  and that a won story fight moves the story step and counts the kill inside the battle. 28 / 28.

## What was looked at (phone renderer, 1600 x 720, four runs)

- Gorgon: boss big and alone, the mummy aimed at (first run: the ring was too faint and the boss
  blurred; both fixed after it).
- Old Bramblejaw: big, sharp, whole, under its bar.
- Colossus, first run: it hung out of the top of the picture (the hovering art). Fixed, second run:
  it stands whole on the stage; aiming the Magma Heart shows ring, pool, chevron, plate, the others dimmed.
- The Fallen screen with "Try again" / "Rest and return".

## Not done / not verified

- **Not seen in HD (Forward+) or on the phone's small layout** (`--uiphone`): only the four GL
  pictures above. The HD camera frames by the same code, but a boss's head may be soft there (see hooks).
- The pause freeze, Try again and the speed plate were checked by the headless test, not by hand;
  the pause screen itself and the retry restart are P04's.
- The Colossus's helper (a Magma Heart) stood in front of the boss's right side in the last picture;
  helpers are now pushed out past a wide boss's body, checked by numbers only, not by a new picture.
- The Gorgon's teal pool of light hardly shows on orange sand (additive light on a bright ground).
- Tooltips were not seen (they need a resting mouse).
- The new words (tooltips, the Fallen screen's lines) are placeholders in `battle_looks.gd WORDS`.
  The older battle words ("Attack", "Guard", "Victory" ...) are still inside battle.gd.
