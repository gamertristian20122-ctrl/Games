# P08: the Lantern on screen, intents, statuses, deeds, first-fight lessons (and a balance step)

Built on branch `pass/P08` (wave 2). The owner asked for a fast, cheap pass: the steps were done in
value order and the two-round rail was kept small. Files changed: `scripts/battle/battle.gd`,
`scripts/battle/battle_ui.gd`, `scripts/data/battles.gd` (balance only). New:
`scripts/data/lessons.gd` (lesson rows AND this package's new battle words), `scripts/ui/kit/lesson.gd`
(the lesson card), `scripts/ui/howto.gd` (Pause > How to play). `fight.gd`, `foe_kits.gd`,
`boss_moves.gd`, `dev/battle_sim.gd`, `anim_*.gd` and every other file are untouched.

## What the player sees now

1. **The Lantern order.** When two or more of your side stand, the orders page has a sixth row
   "Lantern" (a 12 x 16 lantern picture made in code; on the phone it fills the free sixth tile).
   Choosing it calls `fight.take_lantern()`, says "<name> takes the Lantern.", floats "Lantern" over
   the new carrier, plays `lantern_pass`, glides the warm light over and shows the orders again: the
   turn is NOT spent. When it cannot be taken it stays on the page, faint, with the reason
   ("The Lantern already changed hands this round." / "You carry the Lantern now.").
2. **The carrier.** A warm `OmniLight3D` (range 3.2, energy 1.1, flares up on a pass or a full flame)
   hangs at the carrier's shoulder and follows the Lantern (also when the carrier falls and it passes).
   The carrier's Card shows a small code-drawn lantern and three flame pips on its top edge (PC: right
   end, 1.3x; phone: after the name). Lit pips = `fight.flame`.
3. **The Flare.** At a full flame the carrier's orders page starts with a gold row: the Flare's name
   (Dawnbreaker, Warden's Rain, Second Dawn, Anvil Wall) with "Flare" on its right; it goes through the
   ordinary skill path (aim party / foes / foe). The focus lands on it. "Flare ready!" floats over the
   carrier the moment the flame fills.
4. **Intents over every monster.** A small dark chip over its head: a code icon (sword = a blow,
   chevrons = heavy, burst = everybody, fuse = bursts in n, cross = mend, arrows = draws back, z =
   stunned) and either the coin of the one its blow goes for or a short word (ALL, HEAVY, MEND ...).
   Edge colour: red for heavy / all / fuse, ember for a blow, green for a mend. It hides once the
   monster has acted, and on the one being aimed at (the plate says it in full). The old "Guard!"
   plate over the orders stays.
5. **Status pips.** Small coloured squares with the turns left in them: on the top edge of a Card (PC)
   or after the name (phone), right of a monster's bar (a boss: under its feet), on the aiming plate.
   A stunned monster also gets a pip. A status put on floats its name in its colour, the fighter's
   pixels flash that colour (the sprite3 flash) and `debuff` / `buff` plays.
6. **Burns.** Each tick floats the number in orange, flashes, plays `fire`, jolts a Card; a burn that
   kills now plays the fall (a monster used to stay standing until the end).
7. **Boss phases.** A `phase` event leans the camera onto the boss (`track()`, pulled back), shakes a
   little and plays `boss_roar`; the boss's line comes through the ribbon (the `say` before it).
8. **Raising.** A Waking Ember (and any item or friend-aimed skill with `raise`) now aims at the
   FALLEN only (Left / Right cycle among them, their Cards are the buttons). The one raised stands
   up again: lean and kick tweened back, idle animation, sword and hands shown, breath back, "Up
   again!", `revive`, a gold glow on the ground. A party Flare (Second Dawn) does the same.
9. **No wasted orders.** `fight.useful()` is asked before an item or skill is sent: a herb on the whole,
   a mend on the unhurt, a salt with nothing to cleanse is refused with `shop_deny` and the reason in
   the ribbon; the turn is kept. Item rows nobody can use are greyed with the reason. The two new items
   have icons (Waking Ember `icon_pyre_kindling`, Cleansing Salt `icon_wardwater`; any missing icon
   falls back to the flask).
10. **The aiming plate** grows lines under the bar: the monster's intent in full, each status with its
    name, turns and text, its kit line ("???" until one of its kind was beaten, `kills:<id>`; PC only),
    and "Hits for a-b" from `fight.preview()` for the order being aimed. When the taller plate does
    not fit over the head it stands beside the monster.
11. **Turn rail, two rounds.** After this round's coins a thin brass divider with the next round's
    number, then up to five (phone: two) smaller, fainter coins of `fight.upcoming_next()`. A coin of
    somebody stunned is greyed.
12. **Victory.** `Battles.reward(foes, tier, fight.stats)`: deeds are paid. Each deed ticks in as a
    gold row "Deed: Swift  Won in few rounds.  +15%" (with `coins`). Level-up plays
    `Sfx.sting("level_up")` once (was `ui_start` per row). A lost fight plays `Sfx.sting("defeat")`
    (not under the bot).
13. **Items' turns** are shown whole: `fight.plain_item_turns = false` after setup, and the item branch
    of `_play()` skips events that are not items (they are shown after it).
14. **Lessons** (`scripts/data/lessons.gd`, card `scripts/ui/kit/lesson.gd`): one glass card with a
    head, the words and an "Enter Got it" key cap, centred, shown before the orders open (never during
    an animation), closed with confirm, a click or a tap. Each once (`Save.set_flag("taught:b_<id>")`),
    only while the setting `hints` is not false, never under the bot or with `--nolessons`:
    `orders` (first turn), `lantern` (first turn with two standing), `guard` (a heavy or everybody
    intent is on screen), `items` (the one choosing is under 40% and the pack is not empty), `speed`
    (the second wild fight or later, counted in `Save.hub "wild_fights"`), `beds` (a win with somebody
    hurt and no level), `teach` (a level that opens a skill: "Brother Odo in Wickmere or Sister Imre in
    Dustwatch can teach it").
15. **How to play** (`scripts/ui/howto.gd`): the lessons seen so far, head and words, scrolling; a line
    when none were seen. Pause's "How to play" row already opens it by name.

Fast-forward (`fast`, `ff_toggle`) and Auto (`auto`) were already read by battle.gd after wave 1;
nothing changed there.

## Balance (P14's goal, done here because P08 owns the numbers)

`scripts/data/battles.gd`:
- `CROWD_ATK := [1.0, 1.25, 1.35, 1.3]` (new): monsters hit harder with one or two companions joined
  (the top value is lower because chapter three's four fights in a row must stay winnable).
- `CROWD_HP` `[1.0, 1.0, 1.15, 1.35]` -> `[1.0, 1.05, 1.2, 1.35]`.
- `FOE_ATK_LEVEL` 0.07 -> 0.12, new `FOE_HP_LEVEL` 0.03 (monsters keep up with the party's levels);
  bosses grow by the new `BOSS_ATK_LEVEL` 0.08 instead.
- `MODE` hard 1.3 -> 1.18 (hard was a wall once monsters grow with party and level: chapter three in a
  row went to 0%).

Sim, normal, 100 fights a cell (rounds, PARTY health left when won). Before -> after:
```
                    before                         after
L2 +1 robbers   100% 4.3r 67%                  100% 4.8r 60%
L4 +1 sand      100% 3.1r 81%                  100% 3.5r 67%
L4 +2 robbers   100% 3.8r 78%                  100% 4.2r 72%
L7 +2 rock      100% 5.0r 73%                   92% 7.0r 54%
L7 +3 rock      100% 3.9r 84%                  100% 4.7r 74%
L10 +3 rock     100% 3.4r 88%                  100% 4.3r 76%
L14 +3 rock     100% 3.1r 92%                  100% 3.9r 80%
deepwood L1/L2  4.8r 65% / 4.1r 74%            5.0r 60% / 4.4r 65%
giant L2/L3     9.3r 47% / 8.9r 49%            9.0r 48% / 8.9r 49%
gorgon L5/L6    10.2r 57% / 8.7r 64%           10.8r 57% / 9.7r 58%
forgedoor L7/L8 3.6r 79% / 3.5r 81%            4.2r 64% / 4.1r 67%
ashstair L8/L9  3.6r 78% / 3.7r 81%            4.1r 66% / 4.0r 68%
colossus L8/L10 8.8r 52% / 7.9r 57%            9.4r 49% / 8.5r 53%
```
`--chain` (no rest between a chapter's story battles): normal 100 / 99 / 99-100 / 100 / 100 / 100%
(chapter one from L1 / L2, two from L4 / L5, three from L7 / L8); hard 98 / 78, 68 / 90, 40 / 51%
(P01 had 62-96 / 58-87 / 60-93); story 100% everywhere, bosses 6 to 9 rounds.

**Honest reading:** the target "35-60% left" is reached for the party's own land at levels 1 to 7 and
for every boss (8.5 to 11 rounds), NOT for a party of four at level 10+ (74-80% in rock) or for lands
below the party's level. Pushing further broke the chapter-three chain (7% wins with
`CROWD_ATK[3] = 1.8`), so I stopped at the chain's limit. The bot never wastes a turn; a person
will end lower. The grass with a companion stays a walk-over (1-2 monsters, by design of `pack_for`).

## How to test
```
godot --headless --path . -s dev/compile_all.gd                          # COMPILE DONE files=178 bad=0
./tools/check.sh                                                         # CHECK PASSED
godot --headless --path . res://dev/battle_sim.tscn -- --nosave [--chain] [--mode=hard]
godot --headless --path . -s <scratch>/t_p08.gd -- --battle=story:gorgon --with=thessaly --knight=6 --nosave
xvfb-run ... godot --path . --rendering-driver opengl3 --resolution 1600x720 -- --battle=story:gorgon \
    --with=thessaly --knight=6 --nosave --nolessons --shotlantern --shotaim --shots=<dir> [--uiphone]
```
- `t_p08.gd` (scratch, not in the repo): 19 checks, 0 failed: the two first lessons appear in turn and
  hold the orders back, are remembered; the Lantern order moves the Lantern, keeps the turn, comes back
  refused; the light exists; a herb on the whole is refused and kept; the Flare row is on top at a
  full flame; the plate has its lines; a Waking Ember stands a fallen friend up; deeds pay.
- New test flags: `--shotlantern` (battle_lantern.png with a full flame, a burn and a weakness, then
  battle_lesson.png with a lesson card), `--nolessons` (no lesson cards in a test run).
- NOTE: the package's test line used `--with=thessaly,sera --lvl=6`; main.gd reads ONE `--with` id
  and `--knight=<level>`, so that line fights the Gorgon with a level 1 knight alone.

## Pictures (looked at; two renderer runs, GL, 1600 x 720)
`<scratchpad>/pass/P08/pc/` and `<scratchpad>/pass/P08/phone/` (`--uiphone`): battle.png,
battle_lantern.png, battle_lesson.png, battle_target.png.
- PC: Lantern row with its picture, lantern and flames on the knight's Card, intents with faces over
  the Gorgon and the mummy, a burn pip under the Gorgon, a weakness pip on Thessaly's Card, the next
  round after the divider on the rail, the lesson card, the aiming plate with "Strikes Thessaly. / ??? /
  Hits for 10-13".
- Phone: the gold Flare row over the 3 x 2 tiles (Lantern refused, faint, as she carries it), intents,
  the plate under the feet with intent and damage.
- Fixed AFTER the pictures and NOT seen again (the two runs were spent): on PC the plate stood over
  the chevron when it was too tall (now it goes beside the monster) and the Card's lantern was small
  (now 1.3x); on the phone the lantern, flames and status pips were drawn over the HP bar (now right
  of the numbers). The first PC run also had no Flare row because Thessaly acted while the knight
  carried the Lantern; `--shotlantern` now hands it to the one acting.

## Hooks for other packages
None needed for this to work. Optional:
- `scripts/ui/ui_tour.gd` (whoever owns it): `--uitour=tale` uses `--autobattle`, so lessons never
  block it. A flow tour that presses keys in a battle now first closes a lesson card (confirm does it).
- P01's own hooks for main.gd / hub.gd (the Waking Ember's cap of 3) are still open; they are not P08's.

## Left undone / not verified
- The two-round rail is the cheap form: no intent icon on the rail coins, no target face there.
- No lesson for "first time with three fighters" beyond the Lantern; `items` triggers on the acting
  fighter's health only.
- The plate's kit line is PC only (no room on the phone).
- Inspecting the party's own statuses in words is only by the pips (no plate for friends).
- Words in `lessons.gd` (lessons, Lantern, Flare, deeds, intent words) are placeholders. The Flare and
  deed names come from `battles.gd`, P01's placeholders.
- Never heard: the sounds are P06's names, called blind (no sound device here).
- The balance is tuned for the bot; nobody has played it by hand.
