# P01: the Lantern and a real rulebook (rules only, no screen)

Built on branch `pass/P01`. Nothing here changes what the player SEES yet: package P08 builds the
screen for it. The rules already run in every battle (monsters use their kits and bosses their
scripts today; "Auto" and the test bot play the Lantern, Flares and the new items).

Files: `scripts/battle/fight.gd` (the rules), `scripts/data/battles.gd` (numbers and words),
`scripts/data/foe_kits.gd` (new: monster kinds), `scripts/data/boss_moves.gd` (new: boss scripts),
`scripts/data/supplies.gd` (two items), `scripts/data/skills.gd` (Mend costs 12 mana, was 18),
`dev/battle_sim.gd` (the measuring tool). `scripts/data/enemies.gd` was NOT changed: every monster
used in a battle already had an `"ai"` kind.

## What the rules are now

**The Lantern.** One fighter of your side carries it (`fight.lantern`, the knight at the start).
- The carrier is lit: blows and heals x1.25 (`Battles.LANTERN_LIT`).
- Monsters' single blows go for the carrier most of the time (each kit's `"pull"`, bosses 65%).
  This replaces the old flat "30% at the knight".
- The flame (`fight.flame`, 0 to 3) grows by 1 when the carrier lands a blow or a heal (once a turn),
  by 1 when the carrier fells a monster (once a turn; ADDED to the plan so a Flare can happen in a
  4-round wild fight, `Battles.FLAME_ON_KILL`), and by 1 when the carrier is struck while guarding
  (once a guard). It shrinks by 1 on a heavy blow taken unguarded. It goes out when the carrier falls,
  and the Lantern passes to the next fighter standing.
- At flame 3 the carrier has a FLARE (`fight.flare_for(who)`, table `Battles.FLARE`): no mana, the
  flame goes out. Knight: one blow x2.6 through any defence. Thessaly: every monster x1.0 and a sure
  stun (a boss is slowed). Seraphine: heals everybody 30% and stands the fallen up at 25%. Grukk: every
  monster x1.5 and your whole side guards. Each uses a move id the screen can already show
  (lunge, volley, sunmend, quake).
- Once a round somebody else may take the Lantern: `fight.can_take(who)`, `fight.take_lantern(who)`
  returns the events to show. It is free; the turn is not spent. The flame stays with the Lantern.
- Guard now gives 5 mana (was 3).

**Statuses** (`Battles.STATUS`; `unit["status"] = {id: own turns left}`; they count at the start of
the fighter's own turn): burn (6% of full health a turn for 3 turns; 2% on a boss), weak (blows
x0.75, two blows), exposed (defence 0, takes +20%, +15% crit against it), slowed (acts LAST next
round), braced (Grukk's Temper: +8 defence, takes 20% less, 2 turns). Guarding keeps a monster's
blow from leaving a status or a hold on you.
- Changed from the plan: "slowed" is "acts last next round" (the plan said "speed roll x0.6"). It is
  simpler to read on the order row and does the same job.

**Turn order.** The next round is rolled when a round starts: `fight.upcoming_next()`.
`fight.delay(unit, places)` moves somebody back. The speed roll varies 0.92 to 1.08 (was 0.85 to 1.15).

**Monster kits** (`scripts/data/foe_kits.gd`, by the `"ai"` kind of `enemies.gd`): chaser hunts the
weakest; shooter ignores the Lantern and shoots somebody who is not guarding (the Long Cap also mends a
friend every third turn); charger draws back one turn, then charges x2.1; flyer is missed one blow in
four; brute has +6 defence and a x1.7 blow every third turn; exploder hisses a turn, then bursts x1.4 on
everybody and dies (fell it, or stun it to put the fuse out); spreader sprays everybody x0.55 every other
turn and may set you burning. Each kit has a `"line"` for an inspect plate. `BY_ID` overrules one
monster (the Rubble Walker has half its old health: v0.23.0 found it took 7 to 18 blows).

**Intents.** When a round begins every monster decides and says what it will do:
`unit["intent"] = {"do", "target", "icon": blow | all | heavy | fuse | heal | wind | none, "text", "done"}`.
`fight.intents()` lists those still to come. `fight.foe_choice(who)` hands the action back (aimed again
if its mark fell). `fight.sweep_next(foe)` still works for the old "Guard!" plate: true for any pending
"everybody" move and for a boss's heavy move.

**Boss scripts** (`scripts/data/boss_moves.gd`; the file's header explains every key).
- Old Bramblejaw: Briar Sweep every third turn; under half health also Briar Grasp (holds the
  Lantern's carrier a turn unless they guard).
- The Dune Gorgon: Stone Gaze goes to whoever carries the Lantern WHEN IT LANDS (stone for two turns
  unless guarding): every third turn, every other turn under half health, plus Serpent Lash.
- The Ember Colossus: while a Magma Heart stands it gets 8% health back each of its turns; Slag Wave
  burns under 60%; under 30% it must vent once (does nothing, exposed for a turn).
- A stun on a boss becomes "slowed" and the line "<boss> shrugs it off."
- No boss calls helpers mid-fight. A boss without a row keeps the old sweep.
- `"hp"` / `"atk"` in a boss's row multiply its numbers of `tale.gd` (the story file is not edited):
  Gorgon health x1.15, Colossus health x1.45 and attack x1.1.

**Skills** (rows of `Battles.SKILL` / `ALLY` may carry `"status": [id, chance]`, `"bonus"`, `"cleanse"`,
`"pierce"`): Fire Bolt burns (85%), War Cry makes every monster weak (stun chance 25%, was 60%), Frost
slows (no stun), Slam power 1.1 (was 1.5) and exposes, Storm x1.8 against the slowed or stunned, Binding
Roots also exposes, Sunflare takes ills off your side, Temper braces Grukk. Crit: +0.5% per Agility
point of the knight, +15% against the exposed. The skill texts were rewritten as rule descriptions.

**Items** (`supplies.gd`): Waking Ember (stands a fallen friend up at 30%, 60 coins, from step 5, the
pack holds 3, never dropped) and Cleansing Salt (takes ills off the party, 25 coins, from step 7).
`fight.useful(who, action)` returns "" or the reason an order would be wasted ("Already whole.");
`act()` then takes no item and no mana (the turn is still spent, because the screen calls `act` once).
A blow at somebody who already fell goes to a RANDOM other (was always the first).

**Modes and deeds.** `Battles.MODE` = story 0.75 / normal 1.0 / hard 1.3 on monster health and attack,
read from `Save.setting("battle_mode")` (nothing set = normal). `fight.stats` = rounds, taken, fell,
flares, last_flare, boss. `Battles.deeds(stats, pack_size)` gives up to three of swift / unbroken / lit;
`Battles.reward(foes, tier, stats)` adds 15% XP and coins for each and returns `"deeds"`.
`fight.preview(who, target, power)` = [least, most] damage, no luck. `Battles.scripted()` also returns
`"win"`. `Battles._story_row(table, id)` reads `tale.gd` first, then `scripts/data/more.gd` if it exists.

**Other numbers changed:** `FOE_ATK` 5.0 (was 4.6); `CROWD_HP`: monsters have +15% health when two
companions have joined, +35% with three.

## New events of `act()`
They are never the first event of a turn (the first always says what kind of turn it was), so
`battle.gd _play()` and `anim_moves.gd turn()` skip them today:
`status {target, id, turns}` (turns 0 = taken off), `burn {target, amount, dead}`,
`lantern {who, from, flame, fell?}`, `flame {n, was, holder}`, `phase {who, n}`, `rally {who}`.
`hit` gained `heavy`, `lit` (and `burst` for an exploder's own end); `heal` gained `raised`;
`stun` gained `turns`; `item` gained `raised`, `cure`.
- What a turn's START did (a burn's tick, a boss's re-heating) comes right AFTER the turn's first event.
- A fighter that burns away before it can act returns `[say, burn]`.
- A monster drawing back or hissing returns one `say`.
- `fight.plain_item_turns` (default true): a turn that used an item returns only `item` events; the
  others are handed out with the next turn. Reason: `battle.gd _play()` reads every event of an item's
  turn as an item (it crashed on a `status` event in my first run).

## How to test
```
godot --headless --path . res://dev/battle_sim.tscn -- --nosave --rules      # 35 checks of the rules, must print 0 failed
godot --headless --path . res://dev/battle_sim.tscn -- --nosave [--mode=story|normal|hard] [--fights=200]
godot --headless --path . res://dev/battle_sim.tscn -- --nosave --chain      # each chapter's story battles in a row
godot --headless --path . res://dev/battle_sim.tscn -- --nosave --streak     # wild fights in a row before a fall
godot --headless --path . -- --uitour=tale --nosave --speed=6                # 43 checks, 0 failed
```
New flags: `--rules`, `--mode=`. The sim no longer has a bot of its own: it only calls
`fight.auto_choice`. Its columns: wins, rounds, party health left when won, Flares a fight, how many of
yours fell a fight.

## Sim tables (normal mode, 100 to 200 fights a cell)
Before (v0.44.0; rounds, knight's health left):
```
level  1 +0:  grass 100% 4.7r 50%hp  robbers   0%            sand   0%            rock   0%
level  2 +1:  grass 100% 1.7r 94%hp  robbers 100% 4.6r 51%hp  sand  99% 5.2r 45%hp  rock   8%
level  4 +1:  grass 100% 2.4r 88%hp  robbers 100% 4.0r 65%hp  sand 100% 4.6r 60%hp  rock  42% 7.8r
level  7 +2:  grass 100% 1.4r 98%hp  robbers 100% 3.2r 79%hp  sand 100% 3.3r 79%hp  rock  95% 7.2r 37%hp
level 10 +2:  grass 100% 1.4r 99%hp  robbers 100% 3.0r 83%hp  sand 100% 3.0r 85%hp  rock 100% 6.1r 51%hp
glade L1 3.0r   deepwood L2 4.7r   giant L2 56% 11.2r, L3 100% 9.6r 23%hp, L4 7.9r
(the Gorgon, chapter three and a party of four were not in the old sim)
```
After (rounds, PARTY health left, Flares a fight):
```
level  1 +0:  grass 100% 3.5r 61%hp 0.8fl  robbers   6%                 sand   9%                 rock   0%
level  2 +1:  grass 100% 1.8r 95%hp 0.1fl  robbers 100% 4.3r 68%hp 0.7fl  sand 100% 5.1r 74%hp 0.9fl  rock  66% 8.6r
level  4 +1:  grass 100% 2.5r 91%hp        robbers 100% 3.2r 79%hp 0.6fl  sand 100% 4.0r 82%hp 0.6fl  rock  93% 7.4r
level  7 +2:  grass 100% 1.5r 99%hp        robbers 100% 3.2r 88%hp        sand 100% 3.5r 91%hp 0.3fl  rock 100% 5.2r 69%hp 1.0fl
level  7 +3:  grass 100% 1.3r              robbers 100% 2.6r 92%hp        sand 100% 2.9r 93%hp        rock 100% 4.0r 82%hp 0.9fl
level 10 +3:  grass 100% 1.1r              robbers 100% 2.5r 94%hp        sand 100% 2.6r 95%hp        rock 100% 3.5r 87%hp 0.6fl
glade     L1 3.0r 83%hp          deepwood  L2 4.1r 75%hp 1.0fl     giant    L2 100% 9.2r 47%hp 1.8fl, L3 8.8r, L4 7.2r
dustwall  L5 3.0r 90%hp          gorgon    L5 10.1r 58%hp 1.1fl, L6 8.7r, L7 8.0r
pass      L8 3.0r 89%hp          forgedoor L8 3.6r 81%hp 0.8fl     ashstair L9 3.7r 81%hp
colossus  L8 8.7r 52%hp 2.0fl, L9 8.1r, L10 7.9r
```
`--chain` (wounds carried from battle to battle, starting pack), wins of the whole chapter:
normal 100% / 100% / 100% (giant 9 rounds, Gorgon 11 to 13, Colossus 8);
hard 62 to 96% / 58 to 87% / 60 to 93% (giant 12, Gorgon 16 to 17, Colossus 11 to 13).
Story mode: bosses 6 to 7 rounds with about three quarters of the party's health left.
`--uitour=tale` (the bot through the real screen, wounds carried): 43 checks, 0 failed; the three
bosses took 11, 13 and 8 rounds.

Read: wild fights in the land of the party's level are 3 to 5 rounds; bosses 8 to 12 on normal.
Normal is still EASY for the bot (it ends most fights with over half its health): the bot never
wastes a turn and guards every sweep, a person will do worse. P14 finishes the balance.

## Hooks other packages must add
1. **P08 (battle screen), `scripts/battle/battle.gd`:**
   - `_play()`, the `"item"` branch: `for e in events:` must skip events that are not items
     (`if String(e["type"]) != "item": continue`), then set `fight.set("plain_item_turns", false)`
     after `setup` so nothing is shown a turn late.
   - `_finish()`: pass the fight's stats: `Battles.reward(fight.foes, _tier, fight.stats)` and show
     `reward["deeds"]` (names in `Battles.DEED`).
   - Show: `unit["intent"]` of each monster (icon + text), `unit["status"]`, `fight.lantern` and
     `fight.flame`, a "Take the Lantern" order when `fight.can_take(_acting)` (play the events of
     `fight.take_lantern(_acting)`, then show the orders again: the turn is not spent), the Flare of
     `fight.flare_for(_acting)` as an order, `fight.upcoming_next()`, `fight.preview()` while aiming,
     `fight.useful()` before sending an order (grey it with the reason), each monster's `unit["line"]`.
   - `burn` events with `"dead": true` must play the fall (today a monster that burns away stays
     standing until the fight ends); `heal` / `item` with `"raised": true` must stand a fallen friend's
     picture up again; `phase` and mid-turn `say` events are not shown yet.
   - The Items page can only aim at the standing: for an item with `"raise"` offer the fallen. Until
     then the rules send a Waking Ember to the first fallen friend whoever is tapped.
   - Icons for the two new items in `_show_items()` (they fall back to the flask).
2. **Whoever owns `scripts/main.gd` and `scripts/hub/hub.gd` (the supply shop):** use the item's own
   cap instead of `Supplies.CAP`:
   - `main.gd`, `"hub_supply"`: `... and Supplies.count(String(arg)) < Supplies.cap_of(String(arg))`
   - `hub.gd`, role `"supplies"`: `var full := Supplies.count(String(item["id"])) >= Supplies.cap_of(String(item["id"]))`
   Until then a 4th Waking Ember can be paid for and is NOT added (the pack holds 3). The two new items
   show up at the sellers by themselves (step 5 and step 7).
3. **P04 / P05 (settings):** a `"battle_mode"` setting with the values `story`, `normal`, `hard`
   (default `normal`). The rules already read it.
4. **P07 (`scripts/data/more.gd`):** static `battle(id) -> Dictionary` and `boss(id) -> Dictionary`
   (rows like `Tale.BATTLES` / `Tale.BOSSES`, `{}` when unknown). A boss row may carry its own
   `"moves"`, `"phases"`, `"phase_say"`, `"regen"`, or get a row in `boss_moves.gd`.
5. **Credits:** nothing. No asset was added.

## Left undone / not verified
- Balance is a first pass only (step 12 says P14 finishes it). Known soft spots: normal mode is easy
  for the bot; a party of four ends rock-land fights with over 80% health; a knight ALONE at level 1
  to 4 still loses most fights on the road and in the sands (as before; the story gives him Thessaly first).
- The bot never uses War Cry (it has no damage), never passes the Lantern to build a particular Flare,
  and only takes it before a heavy move aimed at the carrier.
- Nothing was looked at in a picture: this package draws nothing. Two battles were played through the
  real screen at animation speed without a display (`--battle=story:forgedoor --autoplay --speed=4`,
  and the Gorgon) to check no script error comes from the new events; how they LOOK is P08's.
- With "Auto" on, a player can already see Flares, monsters drawing back ("X draws back." on the
  ribbon) and exploders bursting before P08 lands; the Lantern itself is invisible until then.
- `more.gd` does not exist yet: `_story_row` was only tested for "file missing" and "id unknown".
- All new words (item, Flare, status and intent texts, boss lines) are placeholders in data files.
