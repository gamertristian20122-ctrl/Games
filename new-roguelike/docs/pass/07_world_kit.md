# Package 07: the world kit

Built on branch `pass/P07`. Everything here is for the story (`Tale.on()`); the old story (`--oldstory`) is untouched.

## What was built

| Piece | Where | In short |
|---|---|---|
| Module registry | `scripts/data/more.gd` | Files under `scripts/data/more/` add places, words, scenes, battles, finds, side quests and travel stops without anybody editing hub.gd, places.gd or tale.gd. |
| Proof place | `scripts/data/more/kit_test.gd` | A yard that uses every kit piece once. Only in the game with `--hub=kit_test` or `--kit`. Also the smallest example of a module. |
| Dungeon kit | `scripts/hub/hub.gd` | Doors (key or lever), levers, things to read, monsters that stand in a place and start a battle. All driven by place keys. |
| Chests stay | hub.gd, `errands.gd` | An opened chest stays where it stood, drawn open (the pack's own open-chest pictures). Locked chests, night-only finds, keys as rewards. |
| Travel | `scripts/data/travel.gd` | Wickmere's watch-fire and every lit beacon are stops. Speak to one: "Step into the light: <name>" for every other lit stop. |
| Resume | `places.gd`, hub.gd | Play starts in the place you were last in. A lost fight wakes you at the last fire or bed you walked past. |
| Smooth walking | hub.gd | Walking runs every drawn frame (was the 60 Hz physics tick), in steps of 1/60 s at most. |
| Soft-lock fix | hub.gd `_ask_fight()` | The knight stands still from the moment a fight is announced; if main.gd dropped the request (busy with a fade) the place lets go again after 1.5 s. |
| Encounter tables | `roamers.gd` | Five monsters a land (was 2 or 3), a night list, robbers on the road band from step 7, a lit land is 40% rarer, the lead monster changes from fight to fight. |

## The module contract

A module is one file in `scripts/data/more/`, listed in `more.gd` `MODULES` (already listed: `kit_test.gd, archive.gd, dungeons.gd, towns.gd, underhill.gd`; a file that is not there is skipped, so the list may name files of later packages). `extends RefCounted`, no `class_name`.

**The rule:** a module never preloads `tale.gd`, `places.gd`, `battles.gd`, `errands.gd` or `more.gd`. It reads the story from the save: `Save.hub_get("tale:step")`, `Save.hub_get("tale:lit:<land>")` (elfwood, sands, cinder, archive), and any flag (`dkey:<id>`, `dlever:<id>`, `ddoor:<id>`, `find:<id>`, its own).

All functions are static and all are optional:

| Function | Returns | Notes |
|---|---|---|
| `on() -> bool` | false = leave the module out | kit_test uses it |
| `places() -> Array` | the place ids it builds | |
| `build(id) -> Dictionary` | one of those places | the format at the top of places.gd, plus the kit keys below. Called on every visit. |
| `fit(id, place)` | | called for EVERY place of the game after it is built (also the village, the beacons ...): add an exit, a person, a sign |
| `talk() -> Dictionary` | `{person id: rows}` as tale.gd `TALK` | a module's rows are asked before tale.gd's |
| `scenes() -> Array` | rows as tale.gd `SCENES` | |
| `battles() -> Dictionary` | `{id: row}` as tale.gd `BATTLES` | ask with `Tale.battle_row(id)` |
| `bosses() -> Dictionary` | as tale.gd `BOSSES` | ask with `Tale.boss_row(id)` |
| `enter() -> Dictionary` | `{place id: {step: do}}` as `ENTER` | |
| `finds() -> Array` | rows as errands.gd `FINDS` | |
| `errands() -> Array` | rows as errands.gd `ERRANDS` | |
| `stops() -> Array` | rows as travel.gd `STOPS` | chapter four adds the Archive's beacon here |

`talk / scenes / battles / bosses / enter / finds / errands / stops` are asked once and kept (they are tables). What changes with the story is written with `from` / `to` / `flag_on` / `flag_off`, or done in `build()` / `fit()`.

`more.gd` offers: `has(id)`, `ids()`, `build(id)`, `fit(id, place)`, `talk(npc_id)`, `scenes()`, `battle(id)`, `boss(id)`, `enter(place_id)`, `finds()`, `errands()`, `stops()`.

The smallest module:

```gdscript
extends RefCounted
static func places() -> Array: return ["old_mine"]
static func build(_id: String) -> Dictionary: return {"name": "The Old Mine", "size": Vector2(480, 330), "outdoor": true, "walk": Rect2(30, 108, 420, 190), "spawn": Vector2(60, 240), "exits": [{"rect": Rect2(30, 220, 8, 40), "to": "emberfall", "at": Vector2(500, 300)}], "people": []}
static func fit(id: String, place: Dictionary) -> void:
	if id == "emberfall": (place["exits"] as Array).append({"rect": Rect2(540, 290, 10, 30), "to": "old_mine", "at": Vector2(60, 240)})
```

## New place keys (hub.gd)

**`doors`**: a block with a picture that goes away.
```gdscript
"doors": [{"id": "mine_gate", "rect": Rect2(118, 194, 44, 12), "key": "mine", "why": "A barred gate. The lock is brass."},
          {"id": "mine_grate", "rect": Rect2(318, 194, 44, 12), "lever": "mine_a", "why": "No lock at all."}],
```
- `key`: opens when the knight walks against it carrying `dkey:<key>`; it then stays open (`ddoor:<door id>`).
- `lever`: open while `dlever:<lever id>` is set.
- optional: `sprite` (default `hub_gate_0`, the pack's barred stone gate, 52 x 83; `""` = no picture), `pos` (where its foot stands; default the middle of the rect's near edge), `open` (a picture left when open), `opened` (words when the key turns).

**`levers`**: a lever of the pack (the 0x72 dungeon set already in the game: `lever_left` / `lever_right`).
```gdscript
"levers": [{"id": "mine_a", "pos": Vector2(180, 150), "name": "A rusted lever",
            "say": "Something heavy moves.", "do": {"all": {"flags": ["dlever:mine_a", "dlever:mine_b"], "do": {"flag": "mine:open", "say": "Both chains are down"}}}}],
```
Pulling sets `dlever:<id>` for good, does `do` (a tale.gd "do"), says `say`.

**role `read`**: a person row with `pages`; shown in the talk box with no face.
```gdscript
{"id": "mine_sign", "name": "A weathered sign", "ghost": true, "pos": Vector2(96, 232), "role": "read", "prop": "hub_ssign", "solid": 3.0,
 "pages": ["THE OLD MINE. Shut by order of the Forgemaster."], "do": {"flag": "mine:read"}},
```
`do` is optional: flags, keys and gifts happen at once; a battle, a story step or a screen after the words.

**`prop`** on any `ghost` person row: a pack picture standing on the spot (`prop_below`: px below its foot, `prop_flip`).

**`foes`**: a monster that stands in the place, comes for the knight inside its leash, starts a story battle on touch.
```gdscript
"foes": [{"id": "guard", "enemy": "rubble_walker", "pos": Vector2(400, 262), "leash": 56.0, "battle": "mine_guard"}],
# and in the module:  static func battles() -> Dictionary: return {"mine_guard": {"title": "...", "look": "rock", "tier": 2, "foes": ["rubble_walker", "ash_bat"], "win": {"say": "..."}}}
```
- `enemy`: a row of enemies.gd to look like; or `sprite` (+ `tint`, `hands`) for pack art by id.
- `tale_from` / `tale_to` / `flag_on` / `flag_off` as for people. Beaten, it is gone for `Tale.FOE_RESPAWN` (240 s; kept while the game runs, like roamers). After a fight he fled it leaves him be for 3 s.
- `spot`: a roamer spot number, fought instead while main.gd cannot start module battles (see hooks).

**Role `bed`** (already there) gives a fire or bed to rest at; it is now also where a lost fight wakes him.
**`rest_at`: place id**: this place's bed is in another place (Wickmere -> the room). **`wake`: Vector2**: the spot to wake on. **`pass`: true**: never where Play starts.

## New keys elsewhere

**tale.gd "do"** (`Tale.apply`): `flag` (a save key or a list of them, set to 1), `key` (`dkey:<id>`), `gear` (a gear id), `supply` (`[id, n]`), `screen` (handed back to the caller as `out["screen"]`), `travel` (a stop id), `all` (`{"flags": [...], "do": {...}}`: the inner do happens once, when every flag is set).
```gdscript
"do": {"flag": "mine:met", "key": "mine", "say": "Bryn gives you the mine key"}
```
**tale.gd rows**: `flag_on` / `flag_off` (a save key or a list) on TALK rows, SCENES rows and place people.
**tale.gd functions**: `battle_row(id)`, `boss_row(id)` (tale.gd first, then the modules), `flags_ok(row)`, `KIT` (the kit's words), `foe_here(key)`.

**errands.gd finds**: `locked`: key id (opens only with `dkey:<id>`; `why` = words before), `night`: true (only after dusk), `kept`: false (no open chest left behind), `open`: an Art id for the opened picture. A reward may have `key` (+ `key_name`).
```gdscript
{"id": "mine_chest", "place": "old_mine", "pos": Vector2(424, 130), "sprite": "hub_dchest", "name": "A locked chest", "locked": "mine", "reward": {"coins": 40}},
{"id": "mine_key", "place": "old_mine", "pos": Vector2(56, 284), "sprite": "hub_fchest", "name": "A small chest", "reward": {"key": "mine", "key_name": "the mine key"}},
```
Use `Errands.all_errands()` / `Errands.all_finds()` (this file's rows plus the modules'), never `ERRANDS` / `FINDS` directly.

**travel.gd stop**:
```gdscript
{"id": "archive", "land": "archive", "place": "archivebeacon", "at": Vector2(240, 238), "name": "The Beacon of the Archive", "person": "archivebeacon"}
```
`at` must be a free spot within 30 px of the person. `--traveltest` checks it.

**Save keys added**: `at:place` (a number: places.gd `ORDER`, never reorder it, only add at the end; a module's place gets a number made from its name), `at:x` / `at:y`, `at:rest`, `seen:place:<id>` (for the world-map screen), `seen:safer:<land>`, `dkey:<id>`, `dlever:<id>`, `ddoor:<id>`, `tale:all:<flags>`.

## Test flags added

| Command (all with `--nosave`) | Proves |
|---|---|
| `--hub=kit_test --allfinds --time=8` | the place is played on paper: keys, levers and doors are followed; one `[reach] ... OK` per find, lever, door, sign, fire, stop, foe and exit. `--allfinds` now does this in every place. |
| `--hub=kit_test --kittest --time=30` | the kit is USED: 20 checks, `[kit] ALL OK` |
| `--hub=village --traveltest --time=30` | every stop: free spot, in reach, walkable; `[travel] ... OK` |
| `--hub=room --resumetest --time=30` | where Play and a lost fight put him after each place; `[resume] ALL OK` |
| `--hub=world --wildtest=900,650 --step=8 --speed=4 --time=30 --autobattle` | he walks a ring round that spot; `[wild] a fight starts: spot 4 (robbers)`. Add `--clock=0.7` for night. |
| `--kit` | the test yard's module is loaded in a normal game |
| `--set=dkey:mine,dlever:a,find:x` | those save keys are 1 at the start (a key held, a lever pulled, a chest opened): for pictures and tests of a half-played dungeon |

## Hooks other packages must add

1. **scripts/main.gd (P04), needed before any module battle can be fought.** Two lines read `Tale.BATTLES[story]` and fail for a module's battle:
   - in `show_battle()`: `Sfx.battle(story != "" and Tale.BATTLES.has(story) and Tale.BATTLES[story].has("boss"))` -> `Sfx.battle(story != "" and Tale.battle_row(story).has("boss"))`
   - in `_on_battle_finished()`: `Tale.apply(Tale.BATTLES[story].get("win", {}))` -> `Tale.apply(Tale.battle_row(story).get("win", {}))`
   - then add `const MORE_BATTLES := true` near the top of main.gd. hub.gd looks for that constant: without it a place's foe whose battle is a module's starts a plain wild fight instead (with a warning), so nothing hangs before the merge. Battles of tale.gd's own table work without the hook.
   - `Tale.battle_row()` also adds the note that marks a place's foe as beaten, so with this hook a beaten foe stays away for 240 s. Without it the foe is still there after the fight (it only waits 3 s).
2. **scripts/data/battles.gd (P01)**: read rows with `Tale.battle_row(id)` / `Tale.boss_row(id)` (or more.gd `battle(id)` / `boss(id)` as its plan says). Both names exist.
3. **scripts/main.gd (P04)**: a lost battle says "You wake in your bed." hub.gd `say()` swaps it for `Tale.KIT["wake"]` when he woke by a fire elsewhere; better if main.gd took the words from the place.
4. **Journal / world map (P11)**: use `Errands.all_finds()` / `all_errands()`, `Save.hub_get("seen:place:<id>")`, `Places.ORDER` + `More.ids()`.
5. **scripts/data/credits.gd (P06)**: nothing new. The levers and open chests are from packs already credited (0x72 dungeon set; Pixel Crawler).
6. **CLAUDE.md (P14)**: fold this note in; the test flags above belong in its flag list.

## Left undone / could not verify

- Pictures: two were taken of the test yard in the phone renderer (GL) and looked at: shut (gates, sign, key chest, guard, locked chest all stand right in the 3D look) and opened (gates gone, both chests drawn open). The lever and the knight behind the yard's wall are hidden by the wall's rocks from the camera: a dungeon should keep things the player must see off the far side of a tall wall. The Forward+ look was not pictured.
- The old `--uitour=flow` test fails 13 of 83 checks on the untouched base commit too (same count before and after this package); it was not repaired here (ui_tour.gd is P04's).
- A module battle was never fought to its end here (needs hooks 1 and 2). The kit test proves the touch and the request only.
- The gate picture (`hub_gate_0`) faces the camera; a door in a wall that runs north-south needs its own `sprite`.
- Foes walk round blocks (walls, shut doors) but not round round things (trees, people).
- Resume on the wide world puts him where he came onto the map or where his last fight was, not on the exact step where the game was closed.
- Encounter numbers (who is in each list, robbers from step 7, the 1.6) are first guesses; dev/battle_sim.gd (P01 / P14) should run over the new lists. A solo level-1 knight loses to robbers, which is why they start at step 7.
- Sound: travel plays `ui_start`, a lever `door_close`; P06 may give them their own.
- New words are placeholders in data files: `Tale.KIT`, travel.gd, kit_test.gd.
