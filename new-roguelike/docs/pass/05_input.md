# P05: controls, rebinding, settings tabs, dialogue comfort

Built in the quality pass of 14 Nov 2026. Everything here is code and words; no art or sound was added.

## What was built

1. **Real actions** (`scripts/core/controls.gd`, table `ACTIONS`). Every button of the turn-based game is an
   InputMap action made at start. Other scripts read them with `event.is_action_pressed("<id>")` or
   `Input.is_action_pressed("<id>")`.

   | id | keyboard (first is the one the player can change) | gamepad | group |
   | --- | --- | --- | --- |
   | `move_up` / `move_down` / `move_left` / `move_right` | W S A D, and the arrows | D-pad, and the left stick | walk |
   | `interact` | E, and Space, Enter, keypad Enter, Q | A, and LB | walk |
   | `menu` (Knight screen) | C, and Tab | Y | walk |
   | `open_journal` | J | Back / Select | walk |
   | `open_map` | M | none | walk |
   | `open_items` | I | none | walk |
   | `pause` (pause, and back in menus) | Esc | Start | all |
   | `fast` (hold: faster fight, skip talk) | Space | RB | talk |
   | `auto` | T | none | talk |
   | `talk_log` | L | X | talk |
   | `page_prev` / `page_next` | Q / E | LB / RB | pages |

   - ONE confirm button: `interact` sends `Controls.action_pressed` while `action_enabled` is true, so
     `hub.gd` (not edited) talks on E, Space, Enter and pad A as well as Q and LB.
   - Walking is `Input.get_vector` over the four move actions, plus the left stick of the pad last used
     (`Controls.active_pad`); other pads' sticks are ignored.
   - "group" says which actions may not share a key (same group, or "all"). Actions of different moments
     may share one (Space is `interact` while walking and `fast` in a talk).
   - The extra keys (arrows, Enter, Space ...) always work, unless the player gave that key to another action
     of the same group.
   - The engine's own `ui_accept`, `ui_cancel` and the arrow focus keys are not changed. The pad's B is still
     "back" (main.gd reads it raw) and cannot be given to an action.
   - The retired real-time game keeps Space / RB (bomb), Shift and the left trigger (guard), 1 2 F R and pad X B
     (skills). Its arrow-key aiming is gone (the arrows walk now); the right stick still aims.

2. **Rebinding** (`scripts/ui/rebind.gd`, new; screen name `rebind`). One row per action, a keyboard and a
   gamepad column. Choose a cap, press the new key. A clash inside a group swaps the two. Esc or B stops waiting.
   "Back to the usual keys" resets all. Stored as the setting `binds`:
   `{action id: {"key": physical keycode, "pad": button}}` (only what differs from the table; -1 = nothing).
   API: `Controls.bind_of(id, slot)`, `set_bind(id, slot, code) -> swapped id`, `reset_binds()`,
   `codes_of(id, slot)`, signal `binds_changed`.

3. **Prompts follow the bindings** (`scripts/ui/theme.gd`). `UI.cap_for(action, pad)` reads the cap from the
   InputMap; `UI.cap_text(kind, pad)` is what `UI.prompt(kind, verb)` shows. `PROMPTS` kinds: confirm, back,
   talk, knight, pause, fast, page, page_prev, page_next, target, move, and new: journal, map, items, log, auto.
   Any action id also works as a kind. Setting `pad_glyphs` ("auto" / "xbox" / "ps" / "nintendo") changes the
   WORDS on pad caps (`PAD_WORDS`; text only, no logos); "auto" reads the name of the pad in use.

4. **Settings in five tabs** (`scripts/ui/settings.gd`, table `TABS`): Game / Display / Sound / Controls /
   Accessibility. Q / E or LB / RB turn the tab; a line under the list explains the row in focus (PC).
   The 3D look, Display, VSync and Text size rows are kept as they were. The dead "Difficulty" row is gone
   (the setting `difficulty` still exists for the retired game).

   | setting key | row | values | who acts on it |
   | --- | --- | --- | --- |
   | `battle_mode` | Game > Battles | "story" / "normal" / "hard" | P01 battles.gd |
   | `battle_speed` | Game > Battle speed | 1 / 2 / 3 | P02 battle.gd |
   | `text_speed` | Game > Text speed | "slow" / "normal" / "fast" / "instant" | hub_talk.gd (here) |
   | `hints` | Game > Tutorial hints | true / false | P08 lessons |
   | `fairy_dust` | Game > Fairy dust | as before | trail.gd |
   | `look3d`, `display`, `vsync` | Display | as before | as before |
   | `borderless` | Display > Borderless window | true / false | display.gd (here) |
   | `window_size` | Display > Window size | "" or "1600x900" ... | display.gd (here) |
   | `fps_cap` | Display > Frame limit | 0 / 30 / 60 / 120 / 144 | display.gd (here) |
   | `master_volume`, `amb_volume` | Sound | 0..1 | P06 sfx.gd |
   | `music_volume`, `sfx_volume` | Sound | as before | sfx.gd |
   | `mute_bg` | Sound > Quiet in the background | true / false | controls.gd (here): mutes the Master bus while the window is not in use |
   | `pad_glyphs` | Controls > Button icons | "auto" / "xbox" / "ps" / "nintendo" | theme.gd (here) |
   | `ff_toggle` | Controls and Accessibility > Fast-forward | false = hold, true = press once | P08 battle.gd |
   | `flashes` | Accessibility > Reduce flashes | "full" / "reduced" | P02 battle.gd |
   | `shake` | Accessibility > Screen shake | as before | battle.gd |
   | `ui_size`, `ui_size_set` | Accessibility > Text size | as before; `ui_size_set` = the player chose | theme.gd |
   | `vibration`, `swap_sticks` | Controls (phone only) | as before | as before |
   | `binds` | the Controls screen | see above | controls.gd |

   Every new setting is read with a fallback, so the game runs before P04's defaults are merged.
   Buttons: "Your knight", "Erase this save" (asks twice, new words, then sends `title`), "Change keys and
   buttons" (sends `open_screen`, `rebind`), "Music room" (sends `open_screen`, `music_room`; shown only when
   `res://scripts/ui/music_room.gd` exists).

5. **Talk comfort** (`scripts/ui/hub_talk.gd`). Letters a second from `text_speed` (28 / 48 / 90 / at once).
   A log of the last 60 pages (`static var said`), shown with L / pad X or the small Log button; Esc, B, L or a
   tap shuts it. Holding `fast` for 0.4 s, or the small Skip button, jumps to the end of the words: the
   choices, or a story fight's start, never past a choice; skipped pages go into the log. A right click and the
   pad's B turn the page. The help strip shows Next / Hold: skip / Log / Leave. No story text was changed.

6. **Name without a keyboard** (`scripts/ui/customize.gd`, `Looks.NAMES` in `scripts/data/looks.gd`): a
   "Pick a name" row (left / right) and an "Any name" button; with a gamepad the focus starts on the row, and
   the name field asks the system for its on-screen keyboard where the platform has one.

7. **Text size on small screens** (`theme.gd ui_size_name()`): a player who never touched Text size gets
   "large" when the screen is 800 px tall or less. Test runs keep "normal".

## How to test

- Compile: `godot --headless --path . -s <scratchpad>/compile_all.gd` printed `COMPILE DONE files=164 bad=0`.
- `--uitour=tale --nosave --speed=6` (headless): 43 checks, 0 failed, no script errors.
- `--uitour --nosave --shots=<dir>` (GL): 27 pictures, no script errors; settings, the erase question, the pause
  menu and the Knight screen were looked at.
- A scratch harness (not in the repo; it was `<scratchpad>/p05_harness.gd`, run with `godot --path . -s`):
  26 checks, 0 failed, headless and in GL at PC and `--uiphone` size. It checks: actions exist; caps read the
  InputMap; D, the up arrow and the D-pad walk; swap and reset rules; settings rows save; Q / E turn tabs; the
  Controls screen takes a key and a pad button and refuses B; Any name; the talk log, pad B, Esc, hold-to-skip;
  Enter, Space, E, Q and pad A all send `action_pressed`.
- New test flags: `--settingstab=<0..4 or game|display|sound|controls|access>`, `--rebindwait`, `--talklog`,
  `--screenh=<px>` (pretend the screen is that tall, for the Text size rule).

## Hooks other packages must add

- **main.gd (P04)**: the action `open_screen` with a screen name (already in P04's plan). Until it is merged
  the two buttons "Change keys and buttons" and "Music room" do nothing. With P04's fallback
  (`res://scripts/ui/<name>.gd`) no SCREENS row is needed for `rebind`.
- **save.gd (P04)**: defaults for `battle_mode`, `text_speed`, `battle_speed`, `flashes`, `hints`,
  `master_volume`, `amb_volume`, `mute_bg`, `ff_toggle`, `pad_glyphs`, `fps_cap`, `binds` (in its plan), and
  please also `borderless` false, `window_size` "", `ui_size_set` false. `_absorb()` must keep a Dictionary for
  `binds` (today's code keeps it as an unknown key, which also works).
- **sfx.gd (P06)**: `set_volumes()` must read `master_volume` and `amb_volume`; until then those two rows save a
  value that nothing uses. settings.gd calls `Sfx.set_volumes(sfx, music)` after either row changes.
- **battle.gd (P02 / P08)**: read `fast`, `auto` and `ff_toggle`; line about 2171 still reads joypad 0 raw.
- **knight.gd (P11)**: its Q / E paging still reads raw keys; move it to `page_prev` / `page_next`.
- **ui_tour.gd** (whoever owns it): optional, a picture per settings tab with
  `main.call("top_screen").call("show_tab", i)`.

## Left undone, or not verified

- An "Auto" page-turn in the talk box (the `auto` action exists; nothing in hub_talk uses it).
- Mouse wheel up to open the log, a panel-contrast setting, shape cues, a second body font (review ideas that
  were not in this package's steps).
- Rebinding covers the first key and the first pad button of each action; the extra keys are fixed. Menu
  moves (`ui_*`), the pad's B and the old real-time buttons cannot be changed.
- Borderless, Window size, Frame limit, Quiet in the background and the on-screen keyboard could not be seen
  working: the test screen is a virtual one with no window frame, no focus changes and no keyboard service.
  The code paths compile and the settings save.
- No real gamepad was used; pad input was sent as events. "Auto" button words for PlayStation and Nintendo
  pads depend on the pad's name and were not seen with real hardware.
- On a phone the Controls screen shows only four rows at a time (it scrolls).
- All new words (row names, hints, the Controls screen, the names list) are placeholders for the owner.
