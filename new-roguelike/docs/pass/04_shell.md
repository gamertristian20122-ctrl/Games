# P04, the shell: safe saves with three slots, title, pause, main hooks, a check that tests the live game

Built on branch `pass/P04` (wave 1). Everything below is in the game now unless it says "hook".

## What was built

1. **The Quit bug.** `title.gd _ask_quit()` called itself for ever (the game froze when Quit was
   pressed). It now asks "Quit the game?" like the Back key does. The save check presses every row
   of the title and expects the question for Quit.
2. **Safe writing** (`scripts/core/save.gd`). A write goes to `<file>.tmp`, its length is checked,
   the file as it was is copied to `<file>.bak`, then the tmp file takes the real file's place.
   A file that is cut short or garbled is read from its `.bak`; the broken file is kept as
   `<name>.broken_<date>.json` and never overwritten; `Save.recovered` is true and the title says
   "A save file was damaged. Its backup copy was loaded." A broken file never replaces a good backup.
   `VERSION` is 2, `_migrate(loaded)` is keyed on the file's version, `signal flushed` fires on
   every slot write.
3. **Three slots.** Files in `user://`:
   - `save_1.json`, `save_2.json`, `save_3.json` (+ `.bak`): one game each. Parts: `version`,
     `meta` {step, level, coins, place, play_s, date}, `unlocks`, `stats`, `seen`, `flags`, `hub`.
   - `settings.json` (+ `.bak`): `settings`, `last_slot`, `legacy_done`. Shared by all slots.
   - `save.json` (the single file of v0.44 and before): COPIED into slot 1 once, its settings
     taken over, and the old file is left exactly as it is (checked byte for byte). Once looked at
     it is never taken over again (`legacy_done`), so an erased slot 1 stays erased.
   - API: `slot_info(n)` -> {exists, step, level, coins, place, play_s, date}, `use_slot(n)`,
     `new_game(n)`, `copy_slot(a, b)`, `erase_slot(n)`, `any_slot()`, `free_slot()`, `begin()`,
     `touch()`, `add_play(seconds)`, `place_name`, `play_s`, `slot`, `recovered`, `root`.
   - `reset_progress()` now means "erase the slot being played" (its file and backup are deleted,
     settings kept).
   - Nothing of a slot is written until a game has begun in it (`begin()`: New Game, a loaded file,
     or main.gd opening a place). Opening Settings on a fresh title no longer leaves a "game".
   - `--nosave`, `--autotest`, `--uitour` still write nothing (`disk = false`).
4. **New settings** in `DEFAULT_SETTINGS` (only the defaults; the packages named read them):
   `battle_mode` "normal", `text_speed` "normal", `battle_speed` 1, `flashes` "full", `hints` true,
   `master_volume` 1.0, `amb_volume` 1.0, `mute_bg` true, `ff_toggle` false, `pad_glyphs` "auto",
   `fps_cap` 0, `binds` {}. Whole numbers and dictionaries (binds) load and save. Any key ending
   in `_volume` calls `Sfx.set_volumes(sfx, music)` as before.
5. **Slots screen** `scripts/ui/slots.gd`: three glass cards (chapter and land from
   `quest_list.gd CHAPTERS`, "Lv n", coins, place, time played, date; "Played last" on the slot in
   use), and a row Continue / New Game / Copy / Erase that acts on the marked card. New Game over a
   game, Copy over a game and Erase ask first. A row that cannot act says why (no dead buttons).
   All its words are in `WORDS` at the top of the file.
6. **Title**: Continue (gold, has the focus, with a line under it: chapter, level, place, time),
   New Game, Load, Settings, Credits, Quit. Continue and Load only show once a game is saved. New
   Game takes the first free slot without a question; with all three full it opens the slots screen
   to pick the one to replace. On a phone six rows go in two columns (they ran off the screen).
7. **main.gd, screens.** `open(name)` falls back to `res://scripts/ui/<name>.gd`, so a new screen
   is a new file only. Action `open_screen` (arg: a name, or `[name, {setup}]`). Keys: while
   walking with no window open, the InputMap actions `open_journal`, `open_map`, `open_items` open
   `journal`, `world_map`, `knight` with `{page: "items"}`, each only when the action and the
   screen exist (Items also needs `"items"` in knight.gd's `PAGES`).
8. **main.gd, battles.** Back in a battle steps back in its menu; with nothing to step back from
   it opens the pause menu (`pause` with `in_battle = true`: Resume, Settings, Give up the fight,
   which asks first). The battle is shaded and `battle.frozen` is set while a window is over it.
   `battle_give_up` ends the fight as lost (same price as a lost fight). Outcome `retry` starts the
   same battle again. A summary with `applied = true` is not applied a second time; `say`,
   `screen` and `battle` are read from it. A story `do` (or win) that returns `screen` opens that
   screen once the place is back; one that returns `battle` goes straight into that battle.
   Battle music goes through `Sfx.battle_for(story, boss)` when it exists.
9. **main.gd, safety.** One `hub_encounter` / `tale_do` asked for during a fade is kept and run when
   the fade ends (it used to be dropped). Play time is counted in real seconds; the game is written
   every 60 s while walking, on leaving for the title and on quitting. When the window loses the
   focus or the gamepad is unplugged the pause menu opens (walking or battle); never in a test.
   `scripts/ui/kit/saved_tag.gd`: a small brass "Saved" tag bottom left for 1.2 s, at most once
   every 20 s, only in walking places (after a battle it shows once he walks again).
10. **Pause menu (walking)**: after Knight come Journal, Map, Items, How to play, each only when
    its screen exists; the Title question reads "Back to the title? Your game is saved."
11. **The check.** `dev/compile_all.gd` loads every .gd under scripts/ and dev/. `tools/check.sh`
    now: import, compile_all (fails unless `bad=0`), the data tables, the save check, the whole
    story played by a bot (headless), `battle_sim --chain`. `--old` adds the six bot runs of the
    retired roguelike rooms, `--quick` stops after the save check. About 2 minutes.
    `dev/validate.gd` got `shell_checks()`.

## How to test

```
./tools/check.sh                                         # must print CHECK PASSED
godot --headless --path . -- --uitour=save               # 46 checks, last line "[save] ok: ..."
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
    -- --uitour=shell --shots=/abs/dir [--uiphone]       # 9 pictures: title, slots, pause menus, Saved tag (16 s)
```

## Flags added

- `--uitour=save` the save check (works in its own folder `user://_savetest_<pid>/`, removed after).
- `--uitour=shell` only the shell's pictures. The plain `--uitour` takes them too, at its end.
- `--openscreen=<name>[:page]` walks into a place (`--openat=<place>`, default the village), opens
  that screen 2 s later; with `--shots=<dir>` saves `screen_<name>.png` and quits.
- `--battlepause` with `--battle=...`: the battle's pause menu after 6 s (`battle_pause.png`).
- `./tools/check.sh --old`, `--quick`.

## What other packages rely on / must do (hooks)

- **P02 battle.gd**: `on_back()` returns a bool (false = "open the pause"), `var frozen`, outcome
  `retry` with spot / night / story in the summary, `applied` + `say` on a story win. All are read
  defensively; until then Back opens the pause only on the orders page and the battle is not held.
  Optional: `func give_up()` in battle.gd; if it exists main.gd calls it instead of paying the
  price itself. If the win's `Tale.apply` returns `screen` or `battle`, copy them into the summary.
- **P05 controls.gd / settings.gd**: make the InputMap actions `open_journal`, `open_map`,
  `open_items`. After an erase send `"title"`. `Save.reset_progress()` erases the slot being played.
- **P06 sfx.gd**: `battle_for(story, boss)`; `set_volumes()` is still called with (sfx, music).
- **P11 knight.gd**: list `["items", "..."]` in `PAGES` and take `page = "items"`; then the pause
  row "Items" and the I key appear by themselves. `journal.gd`, `world_map.gd`, `howto.gd`: just
  create the files.
- **P13**: `Tale.apply()` returning `{"screen": "ending"}` opens `scripts/ui/ending.gd`.
- **P14 (CLAUDE.md)**: Everyday commands: check.sh tests the live game now; `--old` for the bot runs.
- Nobody needs to edit main.gd to add a screen: `send("open_screen", "<file name>")`.

## Left undone / not verified

- The save test proves the take-over with a made-up version 1 file and one real-disk run in a
  scratch folder. No save file from a real phone was available.
- `DirAccess.rename` over an existing file was only run on Linux. If a system refuses it the code
  removes the old file first (the backup is already written by then). Not run on Windows or Android.
- Focus-out and pad-unplug pausing could not be tried here (no window manager, no pad).
- The hotkeys do nothing until P05 makes the actions and P11 the screens.
- The settings are shared by all slots, and that includes the knight's name (`hero_name`): two
  slots cannot have differently named knights. Moving it into the slot needs looks.gd (not mine).
- Beaten roamers and other things kept only in memory are not cleared when the slot changes.
- The old flow test (`--uitour=flow --oldstory`, under xvfb): 82 of 85. The three that fail are
  about skill buttons in the old real-time rooms; they fail the same way before this package.
- On the phone title the gold word "Continue" can sit over a bright flower of the picture.
- The slot card shows the date as `2026-11-14 17:22` (not localised).
- All new words (title rows, slots, pause, "Saved") are placeholders, in `WORDS` / `WORD` consts
  at the top of title.gd, slots.gd, pause.gd and saved_tag.gd.
