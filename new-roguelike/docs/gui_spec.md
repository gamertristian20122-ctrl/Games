# HOLLOW HILL: the HD GUI spec ("Lantern Glass")

Art director, 13 Nov 2026. Mock tool: `dev/gui_mock.tscn` (commit 7703644). Mock pictures:
`/tmp/claude-0/-home-user-games/5fe5ad83-5347-5e9f-a74b-d0e49a438585/scratchpad/gui/artdir/final_*.png`
(battle_skills_1600, battle_commands_1080, target_1600, talk_1080, walk_1600, knight_1080, phone_pair)
and `final_sheet.png`. **Build to these pictures.** Re-run the mock with
`--mock=battle|target|talk|walk|knight [--commands] [--uiphone]` (header of dev/gui_mock.gd) when in doubt;
every colour, size and widget below exists there as working draw code (`panel()`, `bar()`, `focus_row()`,
`flame()`, `lozenge()`, `medallion()`, `keycap()`, `helpbar()`, `wash()`): copy the maths.

---------------------------------------------------------------------------------------------------
## 0. Map of the live game (what a player sees today)

The tale is ON by default (`Tale.on()` = not `--oldstory`). Flow: title -> Play -> intro (first time)
-> your room -> walking places (hub) with talk -> battles (story battles from talk choices, roamer
battles on the world map) -> back to the place. Esc in a walking place goes STRAIGHT to the title today.

| Screen | Drawn by | How to reach it in a test | Live? |
|---|---|---|---|
| Title (+ lit 3D scene behind) | `scripts/ui/title.gd`, `title_scene.gd` (3D), `backdrop.gd` (flat, unused when 3D on) | plain start; `--uitour` shot 01 | LIVE (menu has Play, Collection, Settings, Credits; Esc asks "Quit the game?") |
| Intro cutscene captions + Skip | `scripts/hub/intro.gd` (captions, title, Skip button in its own CanvasLayer) | `--intro` | LIVE (first Play, and the bed) |
| Walking place HUD: story line top-left, chest coins | `scripts/ui/quest_list.gd` (in hub.gd's CanvasLayer `G.LAYER_HUD`) | `--hub=village --nosave`, `./tools/shot.sh village DIR --clock=0.7` | LIVE |
| Place banner (name on arrival, "Night has fallen", hub.say() toasts like "Won: +XP") | `hub.gd` `_banner` | same | LIVE |
| Name prompt over the nearest person, gold "!" marks, world-map sign names | `hub.gd` `_prompt`, `_add_person` mark, sign labels (~l.660); in the 3D look COPIED by `view3d.gd _twin/_sync_words` (CanvasLayer 0) | same; `--hub=world` for signs | LIVE |
| Talk box (pages, portrait, name plate, choices, greyed-choice reason) | `scripts/ui/hub_talk.gd` (screen "hub_talk") | `--hub=village --nosave --hubtalk=hale --shots=DIR` | LIVE |
| Smith shelf (gear for coins) | hub_talk.gd with options (`hub.gd shelf_info`) | `--hubtalk=<smith id>` | LIVE |
| Your knight (name, armour colour, sword look) | `scripts/ui/customize.gd` (screen "customize"; the looking glass in your room, Settings > Your knight) | `--uitour` shot 15 | LIVE |
| Knight screen: Stats / Gear / Skills / Party | `scripts/ui/knight.gd` (C / Tab / pad Y in a walking place) | `--uitour=flow` (flow_03b..03d, 09) | LIVE |
| Settings (+ setting rows) | `settings.gd`, `setting_row.gd` | `--uitour` shot 14 | LIVE (from the title) |
| Credits | `credits.gd` (+ `scripts/data/credits.gd`) | `--uitour` shot 23 | LIVE |
| Yes/no question | `confirm.gd` via `screen.gd ask()` | `--uitour` shots 13, 24, 25 | LIVE |
| Battle: turn order, party bars, command menu, skills list, target names/bars, boss bar, message line, fast-forward hint, turn arrow, damage numbers, end panel (Victory!/You fall.../Continue), victory gold flash, defeat red fade | `scripts/battle/battle.gd` (`_build_screen`, `_fit_ui`, `_make_boss_bar`, `_bar`, `_refresh`, `_row_jolt`, `_drain`, `_face`, `_show_commands`, `_show_skills`, `_ask_target`, `_float`, `_finish`, `_closing`) + `anim_numbers.gd` (numbers) | `--battle=story:deepwood` (also glade, giant [boss], dustwall, gorgon [boss]); `--autobattle`, `--animend`; `--hub=world --hubfight=<spot>` | LIVE |
| Pause menu | `pause.gd` | only inside a dungeon run | OLD (runs only); NOT reachable in walking places |
| Run HUD (hearts, minimap, item rack, curse meter, touch sticks), hero select, collection, end screen (Fallen/Victory of a run) | `hud.gd`, `minimap.gd`, `item_rack.gd`, `hearts.gd`, `curse_meter.gd`, `hero_select.gd`, `collection.gd`, `end_screen.gd` | `--uitour` shots 02-12, 16-22 | OLD roguelike. Collection is still on the title menu; dungeon gates are retired in the tale (`Tale.RETIRED`). Leave them working; they get the new theme for free, no special work. |
| Phone touch buttons (stick, TALK, Lv, pause) | `touch.gd` (CanvasLayer, game px) | `--touch` | LIVE on the phone only |

**How UI is scaled today.** project.godot: viewport 320x180, stretch `canvas_items`, aspect `expand`.
The game canvas is always 180 game px tall (400x180 at 20:9, 320x180 at 16:9) and every UI is laid out
in game px, so on a 1600x720 window one UI pixel is 4 screen px (6 at 1080p): chunky. The only exception
is `battle.gd _fit_ui()`, which scales its CanvasLayer by ~0.75 in HD. Fonts are pixel fonts
(m5x7 body, Alkhemikal display) with AA off. Panels are `UI.StoneBox` slabs.

---------------------------------------------------------------------------------------------------
## 1. The idea

The world is a warm, lamp-lit diorama with deep blue shade. The interface is **night glass held in fine
brass**: dark, slightly see-through panels that let the lit world glow through, a 1 UI px brass
hairline, cut corners, a soft shadow, and ember-gold for whatever has the player's attention.
Type is clean and bookish (a humanist sans for reading, chiselled capitals for names), on a grid twice
as fine as the game's pixels, so the UI reads "HD" while the pixel sprites stay the stars.

Why: (1) the references' worlds are busy and warm; a dark translucent UI keeps contrast without walls of
opaque stone; (2) thin brass ties the UI to the lanterns, the game's signature light; (3) a fine grid +
smooth type is what separates a commercial HD-2D-style game from a phone pixel UI; (4) the pixel sprites
(portraits, icons, medallion faces) keep the identity. Original: no diamond portrait frames, no
reference-game BP pips/shield weakness icons/layouts. Our signatures: round portrait coins on a brass
rail, the ember "flame" focus pointer, the lozenge ornament, horizontal party cards along the bottom.

---------------------------------------------------------------------------------------------------
## 2. Scale: the UI grid (PC fine, phone unchanged in size)

- **UI px** = the unit every layout number in this spec uses.
- **PC** (not `OS.has_feature("mobile")`, not `--uiphone`): `p = screen px per UI px =
  max(1.0, snap(window_h / TARGET_H, 0.5))` with `TARGET_H` = 360 (setting "Text size" Normal),
  420 (Small), 300 (Large). 1600x720 -> p 2 -> UI grid 800x360; 1920x1080 -> p 3 -> 640x360;
  2560x1440 -> p 4. Snapping to 0.5 keeps hairlines even.
- **Phone** (`OS.has_feature("mobile")` or test flag `--uiphone`): `p = screen px per game px`, i.e.
  the UI grid IS the game grid (400x180 at 20:9). Touch sizes stay what they are today.
- **How**: every UI CanvasLayer gets ONE root Control (`UI.attach(layer)` -> `UiRoot`): `layer.scale =
  Vector2.ONE * (p / s)` where `s = window_h / viewport_visible_h`; root `position = 0`, `size = window /
  p`; NOT anchored (anchors would resolve against the 400x180 viewport). Refit on
  `get_viewport().size_changed` and when the Text size setting changes. All children anchor normally to
  the root. This is exactly what `battle.gd _fit_ui()` already does; it is generalised and replaces it.
  Mouse/touch input goes through the layer transform by itself (proved by the battle today).
- `UI.screen_size(node)` returns the UiRoot size when the node is under one (walk up parents, meta
  `ui_root`), else the viewport size. `UI.safe_margin()` converts the phone's safe insets into UI px.
- project.godot, export_presets.cfg and the Android settings are NOT touched.
- Test flags: `--uiphone` (phone grid on PC), `--uisize=small|normal|large`.
- Every screen must be checked at 800x360 (1600x720), 640x360 (1920x1080) and 400x180 (`--uiphone`
  at 2400x1080, gl_compatibility).

---------------------------------------------------------------------------------------------------
## 3. Palette (add as constants in theme.gd; keep the old C_* names working)

| Token | Value | Use |
|---|---|---|
| `C_GLASS_TOP` | rgba(0.085, 0.10, 0.16, 0.80) | panel fill, top |
| `C_GLASS_BOT` | rgba(0.03, 0.035, 0.06, 0.90) | panel fill, bottom (vertical gradient) |
| `C_INK` | #090b13 (0.035,0.045,0.075) | outlines under text over the world, rims |
| `C_BRASS` | (0.78, 0.62, 0.36) | hairlines at 0.45 alpha (`C_BRASS_DIM`), ornaments at 1.0 |
| `C_GOLD` | (0.96, 0.80, 0.47) | focused text, names, headings that matter |
| `C_EMBER` | (1.0, 0.62, 0.26) | focus sweep (0.34 -> 0 alpha), flame pointer, acting fighter |
| `C_PARCH` | (0.95, 0.92, 0.85) | body text |
| `C_DIM` | (0.72, 0.70, 0.64) | secondary text, labels |
| `C_FAINT` | (0.45, 0.44, 0.42) | disabled |
| `C_HP_A/B` | (0.93,0.36,0.25) -> (0.62,0.13,0.12) | HP fill gradient, top -> bottom |
| `C_MP_A/B` | (0.42,0.70,1.0) -> (0.16,0.32,0.72) | MP |
| XP | (0.98,0.80,0.40) -> (0.70,0.45,0.15) | XP, Victory gold |
| `C_STEEL` | (0.55, 0.72, 0.92) | your side (medallion ring) |
| `C_FOE` | (0.92, 0.42, 0.30) | monsters (medallion ring, target plate edge) |
| Good / bad | (0.6,0.9,0.55) / (1.0,0.55,0.45) | "next point", heals / warnings, "why" lines |
Rarity text: Common C_PARCH, Rare (0.5,0.75,1.0), Epic (0.78,0.55,1.0).

Contrast rule: body text on glass >= 7:1 (parchment on the darkest fill); text over the bare world
always gets an ink outline (`outline_size` 3 at sizes 9-13, 5 at 22 and up; C_INK at 0.85) or sits on a wash.

---------------------------------------------------------------------------------------------------
## 4. Fonts

| Role | File (to install in `assets/fonts/hd/`) | Weight | PC size (UI px) | Phone size |
|---|---|---|---|---|
| Body, buttons, lists | Alegreya Sans Medium (`AlegreyaSans-Medium.ttf`) | 500 | 12 (talk text 14) | 9-10 (talk 10) |
| Strong / numbers | Alegreya Sans ExtraBold (`AlegreyaSans-ExtraBold.ttf`), Bold for names | 800 / 700 | names 12, HP numbers 12-13, damage 22-30 | 8-9, damage 14-18 |
| Small | Alegreya Sans Medium | 500 | 10 (never below 9) | 8 (never below 7) |
| Heads, names on plates, tabs, titles | Cinzel (variable `Cinzel[wght].ttf`, wght 600-700), ALWAYS UPPER CASE | 700 | 11-13 heads, 20 screen titles, 24 place banner, 40 VICTORY | 8-9 heads, 13 titles, 24 VICTORY |
| Logo "Hollow Hill" only | existing `assets/fonts/display.ttf` (Alkhemikal, pixel, CC-BY credited) | - | at whole multiples of 16 SCREEN px: size = 16*n/p UI px | as today |

- Source: `https://raw.githubusercontent.com/google/fonts/main/ofl/alegreyasans/` and `/ofl/cinzel/`
  (reachable from this container; already downloaded to
  `/tmp/claude-0/-home-user-games/5fe5ad83-5347-5e9f-a74b-d0e49a438585/scratchpad/gui/fonts_dl/`).
  Both SIL OFL 1.1: ship each family's `OFL.txt` next to the fonts, keep a copy with a `SOURCE.txt`
  in `assets_raw/fonts/alegreya_sans/` and `assets_raw/fonts/cinzel/`, add
  `assets_raw/licence_notes/google_fonts_ofl.txt`, and one credits row per family in
  `scripts/data/credits.gd` ("Font Alegreya Sans by Juan Pablo del Peral / Huerta Tipográfica, SIL OFL
  1.1"; "Font Cinzel by Natanael Gama, SIL OFL 1.1").
- Crispness: these are vector fonts drawn at the final screen size (`antialiasing` GRAY, `hinting`
  LIGHT, `subpixel_positioning` AUTO; FontVariation with `opentype_features {"lnum":1,"tnum":1}` for
  numbers so columns do not jiggle). The mock proved them sharp at p 2, 3 and 6 with the scaled-layer
  method. If any text looks soft or thin on the real build, switch the .import to MSDF
  (`multichannel_signed_distance_field=true`, `msdf_pixel_range=16`, `msdf_size=48`) - outlines up to 8 work.
- Pixel fonts stay for the OLD run screens only if a group finds a reason; the default theme font
  becomes Alegreya Sans everywhere.
- Line spacing: body 12 -> 15-16 UI px lines; talk 14 -> 18; phone 10 -> 12.

---------------------------------------------------------------------------------------------------
## 5. Materials and widgets (state by state)

### 5.1 Glass panel (successor of StoneBox: `GlassBox extends StyleBox`, used by `UI.box()` and the Theme)
- Cut corners 3 UI px (2 on phone), vertical gradient C_GLASS_TOP -> C_GLASS_BOT.
- Edge: 1 UI px C_BRASS_DIM hairline on the outline; inner hairline inset 2.5, white 0.045 alpha;
  a sheen line 1.5 below the top edge, white 0.08, inset 6 each side.
- Shadow: soft, 10 UI px, black 0.45, offset (0, 3) (StyleBoxFlat shadow drawn first is fine).
- Optional ornament: a lozenge (diamond, 3 UI px half-size, C_INK rim, brass fill) on the middle of
  the top edge with two 20 UI px brass rules fading out sideways. Use on major panels (menus, choice
  lists, detail cards); never on small cards, plates or bars.
- Kinds: `panel` (default, ornament), `card` (no ornament), `plate` (name plates: edge C_BRASS full
  alpha, no ornament, content margin 8x3), `well` (sunken list area: darker, no sheen), `gold` (edge
  C_GOLD: acting/selected), `danger` (edge C_FOE 0.7), `tooltip` (card). Keep `talk`, `slot`,
  `slot_focus`, `hud`, `tag`, `curse` names alive (map them to the nearest new kind).
- Content margins: 10 x 8 UI px for panels (6 x 4 phone).

### 5.2 Wash (text straight on the world, no box)
A horizontal gradient of rgba(0.02,0.025,0.045, 0 -> 0.6-0.8) that fades out toward the open side. Used
for the story line, coins, the help strip, the place banner, the turn rail. Text on a wash also has a
3 UI px ink outline.

### 5.3 Buttons and list rows (every state)
One look for all list-like buttons ("Row"): no slab, text left, optional 16 UI px icon at x+6, value
right-aligned. Height 19 UI px PC (min 20 on phone, 24 for primary touch targets).
| State | Look |
|---|---|
| normal | transparent; text C_PARCH; icon at 0.85 white |
| focus = hover | **the focus sweep**: ember gradient (0.34 alpha at the left -> 0 at the right) under the row, a C_GOLD 0.55 hairline on top and 0.35 at the bottom over the left 60%, text C_GOLD, icon full white, and **the flame pointer** 5 UI px left of the row |
| pressed | sweep alpha 0.5, text white, row content 1 UI px down for 0.06 s |
| disabled | text C_FAINT, icon modulate (0.45,0.45,0.48,0.7); it STILL takes focus and its reason shows in the help strip / detail line (house rule: never a dead button without a reason) |
| selected (current tab, carried item) | text C_GOLD without the sweep + a small lozenge or "worn" tag |
"Big" (primary call to action: Play, Continue, Resume): a glass `plate` 26 UI px tall, Cinzel 13 caps
centred, same focus sweep inside, gold edge on focus. Square "+" style mini-buttons (stat points):
15x15, 3 radius, brass 0.6 border, ember fill when its row has focus.
Mouse hover MOVES the focus (one highlight, never two). Every button keeps `focus_mode = FOCUS_ALL`.

### 5.4 The flame pointer (focus cursor) - `UI.FocusFlame`
A lozenge stretched sideways (8x7 UI px: ink rim, C_EMBER body, pale (1,0.95,0.75) core) drawn 5 UI px
left of the focused control's left edge, vertically centred. ONE per screen; it glides to the new focus
in 0.08 s (ease out quad) and breathes +-1 UI px horizontally at 1.6 Hz. Hidden while the last input was
touch on the phone. The sweep appears in 0.10 s (ease out) when focus arrives. `UI.instant` (tests) =
no animation.

### 5.5 Bars (`UI.Bar` Control)
- Capsule well rgba(0.01,0.012,0.02,0.85) with a 1 UI px brass 0.30 border expanded 1 UI px;
  fill = vertical gradient A (lightened 15%) -> B; a 0.5 UI px white 0.35 gleam on the fill's top.
- "Lost" part: pale (1,0.9,0.7,0.75) segment from the new value to the old, held 0.35 s then drains in
  0.45 s (today's `_drain` timing). Gains fill up in 0.25 s with a brief bright edge.
- Below 30% HP: the fill pulses brightness 0.85-1.15 at 1.5 Hz and the number turns (1,0.72,0.55).
- Heights (UI px): party HP/MP 4, foe tag 3 (width 32), target plate bar 3, boss bar 6 (width 260,
  brass end caps), XP 4. Phone: 3 / 2 / 2 / 4.
- Presets: "hp", "mp", "xp", "boss", "foe".

### 5.6 Portrait coin (`UI.Medallion`)
Round crop of the top of the sprite (`_face` crop: `side = min(w, h*0.62)` from the used rect, shifted up
8%), drawn as a textured circle polygon (no shader needed; nearest filter). Rim: 1.5 UI px ink then a
1 UI px ring in C_STEEL (your side) or C_FOE (monster); the unit's `tint` multiplies the face. Active:
ring 1.6 px + an outer C_GOLD 0.8 ring + an ember glow (5 circles, 0.10 -> 0.03 alpha). Radii: turn rail
13 (current) / 9 (next), party card 11, phone 8 / 6.

### 5.7 Key prompts (`UI.prompt(kind)` -> Control, and `UI.help_strip(pairs)`)
- Keyboard: a parchment key cap (rgba(0.92,0.88,0.80,0.92), 3 radius, 2 px darker bottom edge, ink
  ExtraBold 9 letter, min width 12). Pad: a parchment ROUND cap with the face letter (A/B/X/Y in ink;
  NO platform colours, no platform logos). Touch: prompts hidden (the phone has its own buttons).
- `Controls` gets `last_pad: bool` (true after a pad button/axis, false after a key or mouse) and emits
  `device_changed` also on keyboard<->pad switches; prompts update live.
- The binding table lives in ONE place (theme.gd `PROMPTS`) and mirrors controls.gd exactly:
  confirm Enter / A; back Esc / B; talk Q / LB; knight C / Y; pause Esc / Start; fast-forward hold
  Space / hold A; page Q E / LB RB (new, menus with tabs only); target Left Right / D-pad.
  Keys are NOT changed. The only new bindings are Q/E + LB/RB as page keys inside tabbed screens.
- Help strip: bottom-right (top-right in battles), pairs "[key] verb", body 10, 12 UI px between pairs,
  on a wash.

### 5.8 Icons
Raven Fantasy Icons (already in the repo, `assets/art/icons/`, same pack as items/gear/skills) drawn at
16 UI px (whole pixels, nearest). Battle commands use: Attack `icon_gilded_blade`, Skills
`skill_firebolt` (or a spellbook from the pack), Guard a helm/shield icon, Flee `icon_swift_tonic` (the
core may import better-fitting ones from the pack via `tools/import_icons.py EXTRA`: a shield, a boot,
a book, a coin; the zip is in `assets_raw/icons/raven_fantasy_icons/`). Kenney 1-bit (CC0) only for
tiny glyphs if needed. Never draw icon art in code (house rule); geometric marks (lozenge, chevron,
"!" coin, flame pointer, coin disc) are code shapes.

### 5.9 Sounds (existing files only)
Focus move: `ui_click` at -12 dB, pitch 1.18 (+-0.03); confirm: `ui_start`; cancel/back: `ui_back`;
buy/equip: `shop_buy`; refused: `shop_deny`. Not on every hover frame: once per focus change, never
twice within 0.05 s.

### 5.10 Motion (all under 0.25 s; `UI.instant` turns all off)
Panel open: fade 0 -> 1 in 0.14 s + slide 8 UI px from its anchored edge + scale 0.98 -> 1. Panel close:
0.10 s fade. Page change (skills list replacing commands, tabs): cross-fade 0.12 s with a 12 UI px
slide in the direction of travel. Numbers count up/down over 0.25 s. Typewriter as today
(48 letters/s + PAUSES). Next-page chevron bobs 2 UI px at 2 Hz.

### 5.11 Full-screen menus over the world: the veil
Knight, pause, settings, customize and credits (when opened over a walking place or the title scene)
draw a full-screen `ColorRect` with a canvas shader: `hint_screen_texture, filter_linear_mipmap`,
5x5 taps at LOD 2.5 spaced 6 screen px, desaturate 45%, x0.42, + (0.008,0.012,0.03), vignette.
Code is `BLUR_CODE` in dev/gui_mock.gd (proved in gl_compatibility too). The title menu does NOT blur
(the 3D title scene is the show); it uses a left-side wash instead.

---------------------------------------------------------------------------------------------------
## 6. Layouts (UI px; W x H = the UI grid)

### 6.1 Battle (PC) - pictures final_battle_skills_1600, final_battle_commands_1080, final_target_1600
- Keep the middle band clear: nothing between y 0.18H and 0.80H except the floating foe tags, the
  target plate/brackets and damage numbers. Fighters' feet sit near 0.70H.
- **Turn rail** top-left: brass line from (28,26) fading out over 175; current coin r13 at (28,26) with
  glow, next coins r9 every 22; up to 7; under the current: "ROUND n" Cinzel 8 C_DIM at (15,50). Wash
  behind (230x52, fading right). Order animation: when the turn passes, coins slide left 0.2 s.
- **Party cards** in ONE ROW along the bottom right: card h 44, gap 6, width
  `clamp((W - 28 - menu_w - 16 - 6*(n-1)) / n, 120, 176)`, right margin 14, bottom margin 14. Card =
  `card` glass; coin r11 at (17,22); name ExtraBold/Bold 12 at (34,15) (C_GOLD when acting); "Lv n" 9
  right at (w-9,15); HP block: "HP" Bold 8 C_DIM at (34,29), number Bold 12 right-aligned at the HP bar's
  end, bar 60% of the width at y 32 h4; MP block the rest. Acting card: lifted 6, edge C_GOLD, ember glow
  under it. Hit: the card shakes 2-6 UI px (today's `_row_jolt`) and flashes the HP number red. KO: card
  at 0.5 alpha, name C_FAINT, a thin red X over the coin.
- **Command list** bottom-left: `panel` at (14, H-14-h), width 148 (menu_w); header = actor name Cinzel
  12 C_GOLD; rows Attack, Skills >, Guard, Flee (icon + body 12); focus sweep + flame. **Skills replace
  the commands in the same panel** (page slide): header "SKILLS" Cinzel 11 + "MP 14" Bold 10 C_MP_A
  right; rows icon + name + cost right (C_MP_A; C_FAINT when not affordable); a hairline, then the
  focused skill's text (body 10 C_DIM, wrapped, 2 lines max). A skill that cannot be paid stays focusable
  and its line says why ("Needs 16 mana"). Boss "Guard!" warning: a C_FOE plate above the list.
- **Help strip** top-right: "[Enter] Choose  [Esc] Back"; during the fight (no menu): "[Space] hold:
  faster" (replaces `_ff_hint`).
- **Targeting**: the list closes to its header ("FIREBOLT" ribbon instead: Cinzel 13 C_GOLD centred at
  top on a two-sided wash with lozenges); gold corner brackets (6 UI px arms, 1.4 px gold over 3 px ink)
  round the target's sprite rect, breathing 1.0 -> 1.06 at 1.4 Hz; a `danger` plate above it: name
  Cinzel 11 + its HP bar. Left/Right (and mouse hover) move between targets; Enter/click confirms; Esc
  back. Friend targets (heals): the same brackets on the party fighter AND the card lifts.
- **Foe tags**: 32x3 HP bar floating 6 UI px over each foe's head, no name until targeted. Boss: the
  long bar top-centre (260 wide, h6, Cinzel 13 name above, brass caps) shifted 56 left as today.
- **Message line** (what happens: "Aldous uses Firebolt"): the top-centre ribbon (same as the target
  ribbon), Cinzel 13, holds 1.2 s, fades 0.2 s.
- **Damage numbers** (`anim_numbers.gd`): Alegreya Sans ExtraBold 22 (crit 30) with 5 UI px ink outline
  and a 2 px drop; colours: damage (1.0,0.86,0.5), crit C_EMBER + "CRITICAL" Cinzel 8 above, heal
  (0.6,0.95,0.55), mana C_MP_A, miss/guard C_DIM "Guarded". Keep the existing pop/stack motion.
- **Victory**: gold flash (as today) then "VICTORY" Cinzel 40 C_GOLD with a light sweep across the
  letters (0.6 s) and rules + lozenges either side, top third; below it a `panel` (w 300): per fighter a
  row (coin, name, "+38 XP" counting up, the XP bar filling, "LEVEL UP" ember tag when it happens),
  then "+12 coins" (coin disc), "New skill: ...", "Found: <gear>" in rarity colour; "Continue" Big button.
  **Defeat**: dark red veil (as today), "FALLEN" Cinzel 40 (0.85,0.35,0.3) desaturated, the two lines
  of today's text, "Continue". Fled: just the ribbon "You got away".
- Phone battle (final_phone_pair top): turn coins r8/r6 top-left; your side = one strip per fighter at
  the top right (132x17: name Bold 8, HP bar 46x3 over MP bar 46x2, HP number Bold 8 right); orders = a
  2x2 block of `card` tiles bottom-right (62x22 each, icon + body 9), skills = a list panel in the same
  corner (rows 20 UI px); no key prompts on touch. Keep tiles below 0.68H; check the phone battle camera.

### 6.2 Talk box (PC) - final_talk_1080
- Bottom fall-off as today. Box: `panel` without ornament, width min(W-40, 600), h 92, bottom margin 14,
  centred.
- Portrait well at the box's left: 86 x (h-12), a warm glow (7 circles, 0.035 alpha), the speaker's
  bust = top rows of the sprite at **3 UI px per art px** (2 on phone), cut by the well's bottom; a
  brass hairline fading upward to its right. No sprite = no well, text starts at +14.
- Name plate on the top edge at x+100: `plate` 22 tall, NAME Cinzel 13 C_GOLD + title body 10 C_DIM.
- Words: body 14, 18 px lines, from x+108, 3 lines; typewriter + PAUSES as today; page dots (r1.6) and
  the ember chevron bottom-right.
- Choices: `panel` with ornament, standing on the box's right end (bottom 18 above the box), rows 20,
  body 12, focus sweep + flame. Greyed choice: C_FAINT + its reason on the line under the list (as
  `_say_why` does today). Lines ("lines" in info) show as small body 11 rows in the box after the pages.
- Black-screen intro words (`info.black`): heading Cinzel 24 C_GOLD centred at 22% height, words body 14
  centred, max width 420.
- Phone (final_phone_pair bottom): box W-16 x 52 at the bottom, portrait 2x, plate Cinzel 9, text body
  10 / 12 lines, choices panel 140 wide above the right end, rows 22.

### 6.3 Walking places - final_walk_1600
- **Story line** top-left on a wash (330x66 fading right): "CHAPTER ONE · <LAND>" Cinzel 9 C_BRASS with a
  rule fading right, then a gold lozenge bullet and the step text (`Tale.STEPS[step]`, body 13, 2 lines,
  outline 3). During a fight the old quest_list hid things; here it simply fades to 0.5 alpha while the
  knight walks and back to 1 when he stands still for 1 s.
- **Coins** top-right on a wash: code coin disc (gold, 5 UI px) + ExtraBold 13.
- **Place banner** on arrival: "WICKMERE" Cinzel 24 C_PARCH centred at y 72 with lozenges either side and
  a two-sided wash band; subtitle (place "title" if it has one) body 11 C_DIM under it. Shows 2.2 s
  (fade in 0.3, out 0.5). "Night has fallen" / "Morning" use the same banner smaller (Cinzel 16).
- **Toasts** (`hub.say`, "Won: +38 XP, 12 coins", "The way is shut."): a small `card` panel bottom-centre
  (24 tall, body 12), 2.5 s, slide up 6. Never more than one; a new one replaces the old.
- **Name tag + talk prompt** over the nearest person: a pill (StyleBoxFlat radius 8, fill
  rgba(0.03,0.035,0.06,0.72), brass 0.5 border), name ExtraBold 11, a small brass pointer under it; above
  it `[Q] Talk` (prompt widget; on touch: no prompt, the TALK button lights as today). Fades in 0.12 s.
- **News mark** ("!"): a gold coin (r5.5) with an ink "!" ExtraBold 11 and an ink rim, bobbing 1.5 px.
  Roamers' red "!" the same in C_FOE.
- **World-map sign names**: Cinzel 10 caps with outline 3, colour as today (gold = work, grey = shut,
  green = done).
- **Help strip** bottom-right: "[C] Knight  [Esc] Pause" (fades out after 6 s of walking, back when the
  knight stands still 3 s).
- Labels that follow the 3D world (`view3d.gd _sync_words`) must convert positions from game px to UI px
  (multiply by s/p) once they live under a UiRoot.
- Phone: the same pieces at phone sizes (story line body 9, banner Cinzel 13); touch buttons unchanged.

### 6.4 Knight screen (Stats / Gear / Skills / Party) - final_knight_1080
- Veil (5.11). Header at y 36: "ALDOUS" Cinzel 20 C_PARCH + "The Last Knight · Level 4" body 11 C_DIM;
  tabs right-aligned: Cinzel 11 caps, selected C_GOLD with a 1.5 gold underline and a small lozenge,
  others C_DIM, 22 apart, [Q] and [E] key caps at the ends (LB/RB on a pad). A brass rule under the
  header fading at both ends (y 48).
- Columns: left 0-0.28W portrait (knight sprite at 3 UI px per art px on a warm glow + an oval shadow),
  "EXPERIENCE" Cinzel 9 + XP bar 120x4 + "124 / 200 to level 5"; middle 0.29W-0.63W the list (section
  heads Cinzel 10 C_DIM, rows 24-26 tall, body 13, values ExtraBold 14 right, "+" mini buttons);
  right 0.67W to W-24 the detail `panel` (name Cinzel 13 C_GOLD, text body 12, now/next lines).
- Gear page: rows = icon 16 + name in rarity colour + slot/"worn" tag; detail = what it does + compare
  (+/- coloured). Skills page: icon + name + cost; detail = text + "On button 1/2" choice (as today).
  Party page: one card per companion (coin r16, name, title, numbers) + the bring/leave button with its
  reason when it cannot change.
- Help strip bottom-right: "[Enter] Add a point  [Q/E] Page  [Esc] Close" (verbs per page).
- Phone: header Cinzel 13, tabs as 4 equal touch tabs (min 22 tall) across the top, portrait column
  hidden (name only), list + detail side by side (0.55 / 0.45).

### 6.5 Title
- The 3D title scene stays. Left-side wash (0 -> 0.55W). Logo "Hollow Hill" in Alkhemikal at a whole
  multiple of 16 screen px, gold with the existing glow, left third at y 0.3H; tagline body 13 italic-ish
  C_DIM under it. Menu under the logo, left-aligned (not right): Big "PLAY" plate then rows (Collection,
  Settings, Credits, Quit) body 13, focus sweep + flame. Version Small C_FAINT bottom-left; help strip
  bottom-right. Quit question = confirm panel.
- Phone: menu stays on the right as today (thumb), Big Play 26 tall, rows 20.

### 6.6 Pause (NEW in walking places) and old-run pause
- Esc / Start / the phone's pause button in a walking place opens the pause menu (it used to go
  straight to the title). Veil + a centred `panel` (w 220): "PAUSED" Cinzel 13, then Resume (Big),
  Knight, Settings, Title (asks "Back to the title? The game saves as you walk." Stay / Title). Inside a
  dungeon run the old rows remain (Back to camp, Give up) in the new look.
- The flow test's check "Esc in the camp goes back to the title" changes to "Esc opens the pause; Title
  goes back to the title".

### 6.7 Settings, Your knight, Credits, Confirm
- Settings: veil, centred `panel` w 420 (phone: full width - 16): title "SETTINGS" Cinzel 13, rows 24:
  label body 12 left, value right: toggles = a small capsule switch (off: well; on: ember fill + knob),
  steps (volumes) = 6 brass pips/segments, choices = "<  Normal  >" with chevrons that light on focus.
  New row "Text size" (Small / Normal / Large, PC only; saved `ui_size`, default "normal") applies at
  once. Bottom row buttons "Your knight", "Reset progress" (danger text). Help strip.
- Your knight (customize): left the knight preview at 3 UI px/art px updating live; right the rows
  (Name with a text field in a `well`, Armour colour as swatches, Sword look as "< name >").
- Credits: veil, `panel` w 560, scroll with a thin brass scrollbar (2 UI px track, 3 UI px grabber),
  headings Cinzel 11 C_GOLD per entry ("what"), author body 11, licence C_DIM, url Small C_FAINT.
- Confirm: centred `panel` w 260, question body 13 centred, two buttons side by side (safe choice
  focused first; danger answer text (1.0,0.55,0.45)). Closes with Esc = the safe answer.

---------------------------------------------------------------------------------------------------
## 7. DO / DON'T
DO
- Lay out in UI px on `UI.attach()` roots; read sizes from `UI.size_*` and colours from theme tokens.
- Keep the middle of the battle and the ground around the knight clear; UI lives on the edges.
- One focus highlight per screen (the sweep + flame). Mouse hover moves focus. Keyboard, pad and mouse
  on every screen; phone rows >= 20 UI px.
- Every disabled thing says why. Every screen has a help strip on PC (hidden on touch).
- Whole pixels for sprites and icons (k = 2 or 3 UI px per art px; nearest filter).
- Check 800x360, 640x360 and 400x180 before calling a screen done; read the pictures.
DON'T
- No opaque stone slabs, no chunky 4x pixel borders, no pure white or pure black fills.
- No text under 9 UI px on PC (7 on phone). No ALL-CAPS body text; caps only in Cinzel.
- No copying a real game's frames, diamonds, BP pips, weakness shields or layouts; no platform-branded
  button glyphs.
- No AI art, no generated icons, no new fonts beyond the two OFL families.
- Don't change story words in scripts/data/*.gd, battle numbers, or key bindings (only the page keys and
  the hub pause are new).
- Don't touch project.godot, export_presets.cfg or Android settings.
- Don't break the test hooks in scripts/ui/ui_tour.gd: button texts found by `_find_button` (prefix
  match, e.g. "Balance"), hub_talk's "Leave" button (exact text), knight.gd's `_gear_list`,
  `_skill_list`, `_party_box` and their child node names (`gear_<id>`, `weapon_<id>`, `skill_<id>`,
  `party_<id>`, `party_why`), each screen's `default_focus` and the arrow-key order the flow test walks.
  A group that must change one updates the test with the core owner's agreement (core owns ui_tour.gd).

---------------------------------------------------------------------------------------------------
## 8. Who owns what (no file in two groups)
- **core**: `scripts/ui/theme.gd`, `scripts/ui/screen.gd`, new `scripts/ui/kit/*.gd` (glass box, bar,
  medallion, focus flame, prompt/help strip, veil), `scripts/ui/icon.gd`, `scripts/ui/key_glyph.gd`,
  `scripts/ui/arrow.gd`, `scripts/main.gd` (UiRoot on the menu and fade layers, hub pause routing),
  `scripts/core/controls.gd` (only `last_pad` + device signal), `scripts/core/save.gd` (only the
  `ui_size` default), `scripts/ui/ui_tour.gd` (test updates), fonts in `assets/fonts/hd/`,
  `assets_raw/fonts/{alegreya_sans,cinzel}/`, `assets_raw/licence_notes/google_fonts_ofl.txt`,
  `scripts/data/credits.gd`, `tools/import_icons.py` + new `assets/art/icons/*` (only if new icons),
  `dev/gui_mock.gd` (may update the mock to use the real kit).
- **battle**: `scripts/battle/battle.gd` (UI parts only), `scripts/battle/anim_numbers.gd`, new
  `scripts/battle/battle_ui*.gd` if it splits the UI out.
- **walk**: `scripts/ui/hub_talk.gd`, `scripts/ui/quest_list.gd`, `scripts/hub/hub.gd` (UI parts only:
  prompt, banner, marks, signs, toasts, the HUD layer), `scripts/hub/view3d.gd` (only the words layer:
  setup lines ~88-95, `_twin`, `_sync_words`), `scripts/hub/intro.gd` (captions, title, Skip only),
  `scripts/ui/touch.gd` (look only; sizes and hit areas unchanged).
- **menus**: `scripts/ui/title.gd`, `scripts/ui/title_scene.gd` (2D overlay bits only, if any),
  `scripts/ui/backdrop.gd`, `scripts/ui/pause.gd`, `scripts/ui/knight.gd`, `scripts/ui/settings.gd`,
  `scripts/ui/setting_row.gd`, `scripts/ui/customize.gd`, `scripts/ui/credits.gd`,
  `scripts/ui/confirm.gd`, `scripts/ui/end_screen.gd`.
- Untouched (inherit the theme): hud.gd, minimap.gd, item_rack.gd, hearts.gd, pips.gd, curse_meter.gd,
  hero_select.gd, collection.gd, dev_fake_run.gd.

## 9. Tests every group runs before it is done
`./tools/check.sh` (CHECK PASSED); `--uitour=tale` "[tale] done: 28 checks, 0 failed"; `--uitour=flow`
all ok; `--uitour` finishes. Pictures: Forward+ 1600x720 and 1920x1080 of its screens, gl_compatibility
2400x1080 with `--uiphone`. One Forward+ render at a time. Commit every 20-30 minutes.
