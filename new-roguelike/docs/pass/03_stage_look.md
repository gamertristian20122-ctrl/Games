# P03: stage and map look (orange squares, one-hue lands, world-map names)

Quality pass, 14 Nov 2026. Branch `pass/P03`. No new art, no new words. Every picture is still
the purchased Pixel Crawler art; the code only cuts pixels away, lights and grades.

## What was built

### 1. The orange squares are gone (tools/import_hub.py, stage.gd)

The desert pebbles, boulders, spires, the cave mouth and the rock bed are cut from a GROUND sheet,
so each came with a square of sand painted round it. On sand nobody saw it; on the dark rock of the
Cinder land every pebble was an orange square.

- `tools/import_hub.py` has a new step `unsand()` for the pieces named in `UNSANDED`
  (`dpebble_`, `dblock_`, `dboulder_`, `dspire_`, `dcave`, `drockbed`): a flood from every edge
  pixel through sand-coloured pixels (within 34 of (209, 137, 70), which also takes the soft
  shadow the pack painted on the sand) clears them; then pockets of the sand's own six grain
  colours shut in between two rocks are cleared too (not in the sandstone blocks, which are built
  of those colours). Pixels are only removed, never changed or drawn.
- Re-cut pieces (the only files that changed): `hub_dpebble_0/1`, `hub_dboulder_0/1`,
  `hub_dspire_0/1`, `hub_dcave`, `hub_drockbed`, and `hub_pieces.json` (their new sizes).
  `hub_dblock_*` came out byte for byte the same: the pack drew them without sand. The other 570
  pieces are byte for byte the same.
- `stage.gd`: the `SAND_BACKED` workaround is removed. Pebbles stand up and every one of these
  pieces throws a shadow of its own shape in both renderers.

### 2. The Sands and the Cinder land: warm key, cool shade

All old values stand in a comment beside the new one in the code. Say the word and they go back.

**Desert battles, phone look (`stage.gd` LOOKS "desert")**

| key | old | new |
|---|---|---|
| ground_tint / grey | (1.0, 0.98, 0.94) / 0.05 | (1.0, 0.97, 0.92) / 0.26 |
| sky | e0bd8c | b6cdea |
| mist | ddb98a | d6d6d2 |
| ambient | b9b4c4 | 96a2dc |
| haze | ffd9a0 | dfe6f0 |
| grade (light tint, shade tint, contrast, colour) | (1.05, 1.01, 0.92), (1.0, 0.95, 0.9), 1.05, 0.94 | (1.05, 1.01, 0.93), (0.86, 0.93, 1.14), 1.05, 0.92 |
| shadow_tint (new key) | none | (0.80, 0.86, 1.14) |

**Desert battles, PC look (`stage_hd.gd` LOOK "desert")**

| key | old | new |
|---|---|---|
| ambient / energy | 8a7c98 / 0.2 | 6f80c0 / 0.26 |
| fog / density | ffe4c0 / 0.0035 | dde4f0 / 0.0022 |
| sky_top / sky_low / clouds | 6a8ac4 / ffd8a0 / fff0dc | 3f74cc / c6d8ee / f8f4ec |
| sky_glow (where the sun's disc is) | default (-0.36, 0.13, -0.92): behind the turn rail | (0.235, 0.07, -0.96): low on the right |

**Rock battles, phone look (`stage.gd` LOOKS "rock")**

| key | old | new |
|---|---|---|
| ground_tint / grey | (0.86, 0.80, 0.80) / 0.2 | (0.70, 0.73, 0.82) / 0.7 |
| sky / mist / density | 1c1016 / 3a1c1a / 0.02 | 0c121e / 1a2434 / 0.012 |
| ambient | a08a98 | 8490b4 |
| sun / energy | ffc8a0 / 0.7 | b4c4f0 / 0.75 (a faint moon) |
| haze | 5a2a1a | 22304a |
| grade | none (shader default) | (1.07, 1.0, 0.90), (0.87, 0.94, 1.13), 1.06, 1.0 |

The fire, its light, the embers and the fighters' warm key light are unchanged: they are now the
only orange things in the picture.

**Rock battles, PC look (`stage_hd.gd` LOOK "rock")**

| key | old | new |
|---|---|---|
| sun / energy | ffb890 / 1.2 | a8bcf0 / 1.0 |
| ambient | 6a4a5a | 3c4a70 |
| fog / density | a04a2a / 0.026 | 2c3a56 / 0.012 |
| sky_top / sky_low / clouds | 10070a / 4a1a12 / 3a1a16 | 04070e / 18233a / 1c2436 |
| top_rim | 0.45, ffb080 | 0.5, a8c0ff |
| pool | the wood's golden pool by default (ffb860, 2.6) | 9fb2e8, 1.6 |

**Walking places (`walk_light.gd` GRADES; `hd_light.gd` only passes the new key on)**

- New grade key **`sand`** (both renderers, in the last pass): pixels that are orange (red over
  green over blue) are pulled towards a pale dune colour; greens, blues and greys do not move, so
  on the world map only the Sands' half changes. Flame and lava (more saturated than sand) and, on
  PC, people are spared.
- `dustwatch`: haze (0.96, 0.82, 0.62) -> (0.86, 0.84, 0.80), `sand` 0.45.
- `suncourt`: shade (0.90, 0.90, 1.04) -> (0.86, 0.90, 1.10), haze (0.78, 0.70, 0.62) ->
  (0.74, 0.72, 0.70), `sand` 0.45.
- `dustwatch:night`, `suncourt:night`: `sand` 0.3. `dustwatch:lit`, `suncourt:lit`: `sand` 0.2
  (after the beacon the Sands are meant to be amber).
- `world`: haze (0.92, 0.84, 0.70) -> (0.84, 0.84, 0.80), shade default (1.0, 0.93, 0.88) ->
  (0.88, 0.93, 1.10), `sand` 0.55. `world:night`: `sand` 0.35.
- NEW rows `emberfall`, `cinderpeak` (+ `:night`): the Cinder land had no rows and wore the
  wood's golden default. Now cold blue-grey shade and haze, `sand` 0.55 (which also greys the red
  rock), no sun beams.

### 3. Battle HUD on bright skies

- `stage.gd` LOOKS has a new number per look, `"sky_bright"` (forest 0.45, forest_night 0.05,
  desert 0.85, rock 0.05), read with `stage.sky_bright()` or, before a stage exists,
  `Stage.sky_bright_of("desert")`.
- The desert sun's disc (PC look) no longer stands behind the turn rail (see sky_glow above).

### 4. World-map names (`view3d.gd` `_keep_clear`, `_sign_mode`, `_spread_signs`)

- A place on the screen: its full name over it, as before.
- A place just beyond the left or right edge (up to 0.42 of a screen width, `SIGN_REACH`): a small
  name (7 px letters) at that edge with a little code-drawn arrow, fainter the further away.
- Further away, or above / below the picture: no name. (Before, every off-screen name was pushed
  onto the screen: four names stacked at the right edge.)
- Afterwards no two names may touch: the lower one moves down.
- The names themselves are not changed.

### 5. The hero under the trees (`card_shader.gd`)

- PC look: the see-through copy of a hidden person was the lit figure at 55%, a pale ghost. It is
  now a clear silhouette: pale sky blue with the figure's light and dark faintly kept, and a warm
  white outline on its outermost pixels. It gives its own light, so it is as clear in the dark
  wood as on the sands.
- Phone look (GL Compatibility): there was NO see-through copy at all; under a tree the knight
  was simply gone. New `GL_XRAY_CODE`: a second pass on every person's card, drawn only where
  something nearer hides it (depth test turned round, no depth picture read, so it is cheap), in
  the same colours. A person's own card marks the stencil so the silhouette never shows through
  the person's own sword or somebody in front.
- This applies to every person in every walking place (people behind a house in Wickmere too).

### 6. Lamp halos on the phone (`walk_light.gd` HALO_CODE)

- New `cap` (HALO_CAP = 0.62, phone look only): the heart of a glow can add at most this much, with
  its three colours scaled together, so it stays amber instead of clipping to a white disc.
- Both looks: a glow thins out over the top 12% of the picture instead of being cut off at the
  top edge as a bright half disc.

## How to test

```
cd new-roguelike
python3 -c "from PIL import Image; import sys; [sys.exit(1) for f in ('hub_dpebble_0','hub_dpebble_1') if not any(p[3]==0 for p in Image.open('assets/art/hub/'+f+'.png').convert('RGBA').getdata())]; print('pebbles ok')"
godot --headless --path . -s <compile_all.gd>          # COMPILE DONE files=163 bad=0
GL=1 ./tools/shot.sh world /tmp/p03_world              # names, silhouette, sand
./tools/shot.sh dustwatch /tmp/p03_dust                # the Sands on PC
godot ... -- --battle=story:colossus --nosave --shots=/tmp/p03_rock     # rock battle
godot ... -- --battle=story:gorgon --nosave --shots=/tmp/p03_desert     # desert battle
python3 -I tools/import_hub.py && git status --short assets/art/hub    # re-cut: nothing may change
```

No flags were added.

## Hooks other packages must add

- **P08 (battle HUD), scripts/battle/battle.gd or battle_ui.gd**: thin the dark wash behind the top
  HUD on bright skies. Where the top wash is drawn:
  `var bright := float(stage.call("sky_bright")) if stage != null and stage.has_method("sky_bright") else 0.3`
  then multiply the wash's alpha by `lerpf(1.0, 0.2, clampf((bright - 0.45) / 0.4, 0.0, 1.0))`
  (unchanged in the wood and at night, about a fifth on the sands).

Nothing else is needed: everything here works before and after the merge.

## Pictures

Before: the reviewers' pictures in `<scratchpad>/review/` (world, dust, boss, hdboss) and
`<scratchpad>/pass/P02/colossus/battle.png`. After, in `<scratchpad>/pass/P03/`:

- `before_pieces.png`, `after_pieces.png`: the re-cut desert pieces.
- `world_gl/hub_*.png`: world map, phone look (names, silhouette). Taken BEFORE the last change
  to the `sand` grade, see below.
- `dust_hd/hub_*.png`: Dustwatch, PC look.
- `rock_gl/battle.png`: the Ember Colossus fight, phone look.
- `desert_hd/`: the Dune Gorgon fight, PC look.

## Left undone / not verified

- Only four renderer runs were allowed. NOT photographed after the change: the world map on PC,
  Dustwatch on the phone, the desert battle on the phone, the rock battle on PC, Emberfall and the
  Cinder Stair (new grade rows, written blind), the Sun Court, any place at night (halo cap, the
  `:night` rows).
- The `sand` grade did nothing on the phone in the world picture (the sand there burns out to pure
  red 255, which my first version skipped as "fire"). That guard was removed afterwards; the fix
  compiles on both renderers but the world map on the phone was not photographed again. Expect the
  sand to go from (255, 132, 66) to about (228, 162, 114). If it is too pale or too pink, lower
  `"sand"` in the `world` row of GRADES.
- `desert_hd/battle.png` shows the sky as a pale grey-cream (sky_low dde3e4); it was made bluer
  (c6d8ee) after that picture and not photographed again. The sand in that fight is paler but
  still clearly orange: raise `"grey"` in the desert look for more.
- The rock look's last small step towards grey (ground tint, ambient, shade tint a little less
  blue than in `rock_gl/battle.png`) was made after that picture.
- Dustwatch by day on PC has very deep blue shade (people standing in it are dark). That is the
  place's own `blue` 1.0 / `dull` 0.6 from before this pass, not changed here.
- The review also asked to fade the leaves round the hero, draw roads, blend the wood / sand seam
  and add desert props: not in this package (view3d_build.gd, places.gd, trail.gd are not mine).
- The cave mouth keeps a thin line of shaded sand along its lip (it only stands on sand).
- Nothing was checked on a real GPU or phone. The phone silhouette needs the stencil buffer and
  `depth_test_inverted` in GL Compatibility: both work in the software renderer here.
