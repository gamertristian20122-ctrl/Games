# P11: the Journal, the World Map, Items outside a battle, skills told by their rules

Built on branch `pass/P11` (wave 2, cut down: the owner wanted it fast and cheap). Nothing in main.gd
or pause.gd was edited: P04 already opens `journal` (J), `world_map` (M) and `knight` with
`{page: "items"}` (I) and shows the pause rows Journal / Map / Items once these exist.

## What was built

1. **Journal** (`scripts/ui/journal.gd`, new). The Knight screen's layout: header with five tabs
   (turned with the tabs or the InputMap actions `page_prev` / `page_next`), a list, a detail panel.
   - **Story**: every chapter begun (quest_list.gd `CHAPTERS`), a one-paragraph recap under each
     heading, then every step of `Tale.STEPS` up to now: done steps marked "Done" in green, the step
     now in gold (it takes the focus). The detail panel shows the step and its chapter's recap.
   - **Errands**: taken (with n/m), handed in, and "???" for the ones not met yet; the detail has the
     giver's own words, who and where, the reward, and "Done: go back to ..." when ready. Reads
     `Errands.all_errands()` (modules too).
   - **Secrets**: finds without an errand (`Errands.all_finds()`), found n of m per place; "???" for a
     place not seen yet (`seen:place:<id>`).
   - **Monsters**: every monster a battle can bring (the four roamer lands, the story battles,
     the bosses, modules' battles/bosses) as a portrait coin; a dark silhouette (`UI.C_SILHOUETTE`) and
     "???" until `kills:<id>` > 0; then its name, times beaten, health in words (`BANDS`) and its kit
     line from foe_kits.gd.
   - **Records**: time played, level, coins in the chest, beacons, monsters beaten, great foes beaten,
     kinds met, errands, secrets, skills learned (and "Battles won" once `rec:wins` exists, see hooks).
2. **World map** (`scripts/ui/world_map.gd`, new). Only code shapes, from `Places.get_place("world")`:
   grass / sand / rock (`UI.C_LAND`), the woods as soft dark clumps, `water` ellipses, `paths` and
   `trails` as dotted brass, every sign as a plate (`UI.rs_map_tag`, new in theme.gd) in the colour
   the walking map gives it (gold / grey / green, same rule as hub.gd `_build_signs`), "?" until its
   place was seen. A pulsing ember for the knight (his live position on the wide world, else the
   saved `at:x/at:y`, else the name of the place he is inside: `PLACE_SIGN`), a brass ring on the place
   of the story's next step (`STEP_SIGN`), ember crosses / a flame where taken errands lead, the
   secrets found under each name. Zoom: wheel, Q/E (LB/RB), +/-; look around: arrows / stick / drag.
   On a phone it opens zoomed in on the knight.
3. **Knight screen** (`scripts/ui/knight.gd`):
   - Fifth tab **Items** (setup `page = "items"` opens on it): the supplies in the pack with counts;
     choose one, then a party card (portrait, live health and mana bars, numbers, and what the supply
     would give: "+30"). A use that would do nothing says why in red ("Already whole.", "Mana is
     already full.", "Still standing: nothing to wake.", "Nothing to cleanse."). Then coins in the
     chest and the arms owned (tier n of m) for the knight and every companion who has joined.
   - **Party**: a "Health now" section with live bars for everybody.
   - **Skills**: `_about_skill()` now tells the battle rules with numbers at the skill's rank:
     "Hits every monster for 95% of a blow.", stun chance, status chance with its name and text,
     bonus against, guard / pierce / cleanse, "Rank 1 of 3. Next rank (a teacher, 64 coins): +22% to
     its blow." The old "rests X s" and "On skill button" lines are gone (the On button 1 / 2 row is
     still there, ui_tour uses it). Static `skill_rules(id, who)` and `rank_line(id, who)`.
   - Pages turn with the actions `page_prev` / `page_next` (raw Q / E only if those actions are missing).
4. **The sums** (`scripts/data/supplies.gd`): `preview_use(item, member)` and `use_on(item, member)`
   copy fight.gd `_item()`'s shares exactly (heal = share of full health, at least 1, capped at what is
   missing; mana the same; raise; party items on everybody). `use_on` takes one from the pack and writes
   the new health / mana into the wounds through `Wounds.set_now(id, hp, max_hp, mp, max_mp)` (new in
   wounds.gd). Outside a battle nobody is ever fallen or burning (wounds.gd stands the fallen up at 15%),
   so the Waking Ember and the Cleansing Salt always refuse there, with the battle's own words.
5. **Words**: all new words in `scripts/data/journal_text.gd` (WORDS, RECAP, PLACE_NAME, PLACE_SIGN,
   STEP_SIGN, GIVER_AT, BANDS, KNIGHT). The four chapter recaps are NEW placeholder words for the owner
   to rewrite; nothing of the story's own text was changed.
6. **theme.gd**: `C_SILHOUETTE`, `C_LAND`, `rs_map_tag()`.

## How to test

```
./tools/check.sh                                               # CHECK PASSED
godot --headless --path . -- --nosave --openscreen=journal --step=13 --lvl=7 --hurt --p11tour=/abs/dir
    # no display: opens every tab, the map, Knight Items / Skills / Party, uses a Healing Herb on the
    # knight and prints "[knight] items test: ... health lost 30 -> 0, herbs 3 -> 2 ..."
GL=1 flock /tmp/hh_render.lock xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 \
    --resolution 1600x720 -- --nosave [--uiphone] --openscreen=journal --openat=world --step=13 --lit=elfwood,sands \
    --lvl=7 --hurt --set=kills:thorn_elf,kills:gorgon,find:chest_town_ne,errand:marta_oil,seen:place:world --p11tour=/abs/dir
    # 10 pictures: journal_<tab>.png, world_map_map.png, knight_items.png, knight_items_used.png,
    # knight_skills.png, knight_party.png (_phone with --uiphone), then quits
```
New flag: `--p11tour=<dir>` (read by journal.gd only). It does not use `--shots` because main.gd quits
one second after the first picture.

## Hooks needed (not my files)

- **battle.gd `_finish()`** (P08), win branch next to the `kills:` loop, so Records can show battles won:
  `Save.hub_set("rec:wins", Save.hub_get("rec:wins") + 1)` (and, if wanted, per deed:
  `for d: String in reward.get("deeds", []): Save.hub_set("rec:deed:" + d, Save.hub_get("rec:deed:" + d) + 1)`).
  journal.gd already shows `rec:wins` when it is above 0.
- **battle.gd `_show_items()`** could use `knight.gd _item_icon(id)` so the two screens show the same
  icons; today both map herb / tonic / elixir the same way and the rest fall back to the flask.

## Left undone / not verified

- Scope cut: no "secrets" tab of every chest's position, no bestiary pages per boss move, no map
  legend icons (the legend is a line of words), no Items page inside a battle (that is battle.gd's).
- Pictures were taken in exactly two renderer runs (PC and `--uiphone`). AFTER them I changed three
  things that were NOT seen in a picture again: the phone Journal header (the chapter line hidden,
  tabs 40 wide, because the header pushed the detail panel and the Records tab off the right edge),
  the phone World map opening at zoom 1.7 on the knight (at full view the names lay on top of each
  other), and on PC the map names centred on their spot with the secrets count on a wash under them
  (before: "Dustwatch 0/2" overlapped "The Robber Road"). Compile and the headless tour pass after them.
- On PC at the whole-world zoom some names still touch (the Robber Road and Dustwatch, the Bone Dunes
  and the Sunken Archive): zooming in separates them.
- The map's sign colours copy hub.gd's rule, which reads the OLD story's sites (story.gd): at step 13
  Dustwatch and the Cinder Pass show grey as they do on the walking map. Not changed here.
- Two "?" plates come from module signs (`More` fits) that have no `PLACE_SIGN` row: they turn into
  names once the wide world is seen and their `need` is cleared.
- Monster health words are first guesses from the rows' "hp" x kit "hp" (Frail <= 7, Sturdy <= 11,
  Tough <= 15, Huge). Bosses always read "Huge" with a general line.
- Not tried with a mouse wheel, a pad or a real phone; zoom and pan were only read in code.
