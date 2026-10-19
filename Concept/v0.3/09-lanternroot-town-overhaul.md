# Lanternroot, the town overhaul (level 1)

Written 2026-10-10 from the player's brief for this turn. Nine read-only specialist reports (layout, programmable
interaction, architecture, engine and view, characters and props, ComfyUI pictures, words, menus and panels, visual
concept) and a reality check fed this page. Where a report and the code disagreed, the code was checked and the
result is in section 9. The build order and file ownership in section 10 are what the build follows.

## 1. The brief

Level 1 is where most of the game's first programming happens. The postboard is not the interaction the player wants.
The town should let the player program their movement first (the boots already do this), then program what the world
does while they play. The town gets bigger, the gates and small things get reworked, ComfyUI makes the larger pictures,
the menus get more compact, and the outdoor view and the interior view each get a little smaller. The characters
get a little bigger with more pixels, and spiky hair has to read.

## 2. Decisions (the build uses these)

| Decision | Choice | Why | Cost of the other choice |
|---|---|---|---|
| Outdoor view base | **512 x 288** (`PixelView.BASE`) | The player plays fullscreen (the saved settings say so), and `xrandr` shows the laptop panel as the primary 2560 x 1440 display. Today that is a 6x view (400 x 225 base, 96 px tiles). 512 x 288 gives 5x: tiles 80 px, 17% smaller, the "a little smaller" the brief asks for. At 1920 x 1080 it is 3x. At 1600 x 900 it is 3x, not 2x. | 640 x 360 would be 4x on the laptop: tiles 33% smaller, too much. |
| Fit rounding | a float guard in `PixelView._fit` | 2560 / 512 is exactly 5, but a float just under 5 would floor to 4. | A visibly wrong scale on the laptop. |
| Interior zoom | **keep 2.0** | On the laptop an interior tile is 160 px (was 192, -17%). At 1080p it is 96 px. | Changing the zoom as well would make tiles 72 px, too small. |
| Character frame | **25 x 35** (5:7, the same ratio as 20 x 28) | On the laptop a figure is 125 x 175 px (was 120 x 168, about the same size) with 56% more pixels per frame. | 30 x 42 would be 150 x 210: taller than the brief asks for. |
| Town size | **80 x 56 tiles**, seven districts | On the laptop a screen shows 32 x 18 tiles, so the town is two and a half screens across and three down. The walk from the house to the Root Gate is about 80 steps. | 56 x 40 (today) has no room for the new districts. |
| Footprints | **art = footprint x 16 px**, no roof row | The approved art already works this way (the hall is 144 x 128 for 9 x 8). | Overhanging roofs break the door-on-the-footprint rule. |
| Gates | **two tiles** (a 32 px walkway) | A 25 px figure in a one-tile gap overlaps the fence by about 4 px on each side. | One-tile gates are not walkable for the new figures. |
| Use key | **Space acts on what you face; X opens that thing's code; B the boots** | Space already talks to people and reads signs and shut doors (`overworld.gd:496`). One key to act means nothing new to learn. The reality check suggested F; I chose Space because it keeps one action key and the existing path. | Space for talk and F for use: two keys to learn for a seven-year-old. |
| First programmable things | **the cabbage-plot gate**, then **the crossroads signpost** | The gate is by the start, two tiles wide, and "open when your boots know all four ways" teaches the four keys. | The Old Stones gate is about 35 rows away. |
| Noticeboard | **a four-line sign**; "Take the letters" is cut | The player does not want the postboard. | Keeping the route keeps the postboard. |
| Letters workbench (ADR-0055) | **kept as its own title mode** | Only the town's route is cut. The workbench is the player's work and is not retired. | Retiring it is a player decision. |
| Nix (the lock-picker) | **placed in the drill yard, with no cottage** | Nix is a person in the drill yard on Root Gate Road. Whether Nix gets a cottage beside home, or Hollis's house with Nix's lock, is the player's call. | Placing a cottage now would make that call for the player. |
| Dusk lighting | **deferred** | There is no time-of-day tint in the code. It changes the whole look, so the player should approve it. | Adding it now would change the look without asking. |
| Settings page | **untouched** | It is shared with the title, and Spellforge stays unchanged. | A Lanternroot-only settings page is a player decision. |
| Pause card | drop the "Menu" heading | It brings the card under 40% of the height. | Keeping it: the card is taller. |
| UI scale | stays **0.88** (`Settings.ui_scale`) | It is global and also sizes Spellforge and the Shardrun. | Changing it touches the other modes. |

## 3. The town

Seven districts. Each has a purpose, something a new player learns there, who lives there, and how it connects.

1. **Home Hollow** (south-west). The doorstep and the cabbage plot. The player learns `right`, the first rule. Seren
   lives here; her window glows. The cabbage-plot gate is here.
2. **Waterside** (south). The pond, one bridge and the forge. The player learns `up`, the bridge's key. Brannoc lives
   here. Later, Hotaru's light answers on the shore.
3. **Lantern Square and Lamp Lane** (centre). The Lantern Root, the shut Hall, the noticeboard sign and the lamp lane
   to the shrine. Orin and Pip are by the tree; Lumen is at the shrine. Five two-tile openings lead out of the square.
4. **Warm Hearth Row** (east). The inn, Nym's shop, an alley and apple trees. Marta and Nym live here.
5. **Archive Quarter and Fern's Grove** (west). The Archive, the workshop, Pell's house and a birch grove on a loop of
   path. Vell, Mira, Pell and Fern live here.
6. **North Green and the Old Stones** (north). A walled stone garden, the Festival Green behind the Hall, and a north
   ring road. Morrow keeps the garden.
7. **Root Gate Road and the Drill Yard** (east and south-east). The sealed Root Gate, Hollis's house, a bare drill
   yard and a market row. The Warden, Hollis and Brisk live here.

The first ten minutes: wake at home, try the one rule, walk out the door, cross the bridge (the player teaches `up` to
pass it), and reach the square at about the three-minute mark. The road is short on purpose: the first ten minutes
are the boots and the dialogue, not the walk.

The zoned plan (one character per tile; `.` grass, `,` path, `=` cobble, `~` water, `T` trees, `g` gardens and roots,
`G` a two-tile gate, the letters are buildings):

```
   0         1         2         3         4         5         6         7
   01234567890123456789012345678901234567890123456789012345678901234567890123456789
 0 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 1 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 2 TTTTTTTTTTTT..................................TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 3 TT+--------+...........*................*.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 4 TT|........|.............*................*...TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 5 TT|........|...............*................*.TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
 6 TT|..t..t..|.................*................TTTTTTTTTTSSSSSSTTTTTTTTTTTTTTTTTT
 7 TT|........|..*................*..............TTTTTTTTTTSSSSSSTTTTTTTTTTTTTTTTTT
 8 TT|........|....*................*............TTTTTTTTTTSSSSSSTTTTTTTTTTTTTTTTTT
 9 TT|..t..t..G,,....*................*..........TTTTTTTTTTSSSSSSTTTTTTTTTTTTTTTTTT
10 TT|........G,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,........SSSSSSTTTTTTTTTTTTTTTTTT
11 TT|........|,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,........SSSSSSTTTTTTTTTTTTTTTTTT
12 TT+--------+,,................,,.HHHHHHHHH....,,,,,,,,,,,,,,,,TTTTTTTTTTTTTTTTTT
13 TT..........,,................,,.HHHHHHHHH....,,,,,,,,,,,,,,,,TTTTTTTTTTTTTTTTTT
14 TT..........,,AAAAAAA.........,,.HHHHHHHHH....,,...l...l......TTTTTTTTTTTTTTTTTT
15 TT...PPPPP..,,AAAAAAA.........,,.HHHHHHHHH...l,,l.............TTgggTTTTTTTTTTTTT
16 TT...PPPPP..,,AAAAAAA..WWWWWW.,,.HHHHHHHHH....,,................gggRRRRRRgggggTT
17 TT...PPPPP..,,AAAAAAA..WWWWWW.,,.HHHHHHHHH....,,..T..T.....T....gggRRRRRRgggggTT
18 TT...PPPPP..,,AAAAAAA..WWWWWW.,,.HHHHHHHHH...l,,l...............gggRRRRRRgggggTT
19 TT...PPPPP..,,AAAAAAA..WWWWWW.,,.HHHHHHHHH....,,................gggRRRRRRgggggTT
20 TT..........,,.........WWWWWW.==================........,,......gggRRRRRRgggggTT
21 TT...,,,,,,,,,,,,,,,,,,,,,,,,,==================..IIIIII,,QQQQQQgggRRRRRRgggggTT
22 TT...,,,,,,,,,,,,,,,,,,,,,,,,,==================..IIIIII,,QQQQQQ....,,,..JJJJJTT
23 TTTTTTTTT,,.........T.........====ggggggggg=====..IIIIII,,QQQQQQ....,,,..JJJJJTT
24 TTTTTTTTT,,.T.................====ggggggggg=====..IIIIII,,QQQQQQ....,,,..JJJJJTT
25 TTTTTTTTT,,.....T.............====ggggggggg=====..IIIIII,,QQQQQQ..l.,,,..JJJJJTT
26 TTTTTTTTT,,............T......====ggggggggg=====..IIIIII,,QQQQQQ....,,,..JJJJJTT
27 TTTTTTTTT,,...................====ggggggggg=====,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,TT
28 TTTTTTTTT,,...................====ggLLLLLgg=====,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,TT
29 TTTTTTTTT,,..T................====ggLLLLLgg=====.,,................TTTTTTTTTTTTT
30 TTTTTTTTT,,.......T...........====ggLLLLLgg=====.,,................TTTTTTTTTTTTT
31 TTTTTTTTT,,...................====ggLLLLLgg=====.,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
32 TTTTTTTTT,,...........T.......==================.,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
33 TTTTTTTTT,,...................==================.,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
34 TTTTTTTTT,,...T.....T..........,,................,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
35 TTTTTTTTT,,.................~~~bb~~~.............,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
36 TTTTTTTTT,,,,,,,,,,,,,,,,,~~~~~bb~~~~~...........,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
37 TTTTTTTTT,,,,,,,,,,,,,,,,,~~~~~bb~~~~~...........,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
38 TTTTTTTTT...............,,~~~~~bb~~~~~...........,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
39 TT+----+..YYYYYY...CCCCC,,~~~~~bb~~~~...FFFFFFF..,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
40 TT|cccc|..YYYYYY...CCCCC,,.~~~~bb~~~....FFFFFFF..,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
41 TT|cccc|..YYYYYY...CCCCC,,..~~~bb~~.....FFFFFFF..,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
42 TT|cccc|..YYYYYY...CCCCC,,.....,,.......FFFFFFF..,,.,,,,,,,,,,,,,,,TTTTTTTTTTTTT
43 TT|c,,c|..YYYYYY...CCCCC,,.....,,.......FFFFFFF..,,................TTTTTTTTTTTTT
44 TT+-GG-+..YYYYYY........,,.....,,................,,................TTTTTTTTTTTTT
45 TT.,,,,,,,,,,@,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,................TTTTTTTTTTTTT
46 TT.,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,................TTTTTTTTTTTTT
47 TT.*..................*..................*.........................TTTTTTTTTTTTT
48 TT..............*..................*...............................TTTTTTTTTTTTT
49 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
50 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
51 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
52 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
53 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
54 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
55 TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
```

## 4. The town as a programmable level

The brief's model: the player programs movement first, then the world. The town is where that starts.

**The verbs, in the order a player meets them.**

1. `on_key(key, player)` (done). It changes `player.x` and `player.y`. The town walks on the player's table.
2. `on_use(thing, player)` (new, the first slice). Space on a thing runs that thing's code. The thing's code may change
   only the fields the thing declares (for a gate: `open`), and it may return words that Hotaru says. A bad value or an
   error keeps the default and shows one line with the line number. Nothing else changes.
3. `on_step(player)` (later). It runs after each step and returns words. It cannot move the player.

**Things that take code.** Each thing has a card that names its function, what it receives, the fields it may change,
three examples of what the code gave back, and three hints. The hints name an idea, never a value or a line of code.

- **The cabbage-plot gate** (first). Solid until its code sets `open`. Starter: open when `len(thing.keys) == 4`.
- **The crossroads signpost** (first). Its words come from the code. Starter: say where the player stands. Its text
  becomes "The Archive. The square. Home. Pick a road." (no compass words, so it survives a re-layout).
- **The Old Stones gate** (later). Open when the player's boots know all four ways.
- **The Root Gate** (end of level 1). Opens once every lane lamp is lit. It composes what the lamps lesson taught.
- **Nix's lock, the bridge, Pip's lantern count** (later, one per chapter). Each uses a field that already exists in the
  design.

**The postboard is gone.** The town's noticeboard becomes a four-line sign. Tasks come from things: Hotaru names a
thing's task once, and the thing then shows her notice mark. The quest log names the place.

**Teaching.** Hotaru gives hints, never answers. Errors show the line number and one plain sentence. A program that
fails keeps the last version that walked, and the town says "Press B to fix it" so no one is stuck. Lamps light, gates
open and signs answer in her bubble. Each thing's card says what it receives, so the player can read before writing.

**Light and colour.** The town is lit warm. Each thing the player's code changes adds a light, so the warm accents rise
as the code works. The Root Gate stays sealed until its quest.

## 5. Characters: 25 x 35

- **The frame.** 25 x 35, redrawn by hand from the 20 x 28 layouts, never resampled. All 52 parts land together:
  `characters.py` (FRAME), `overworld_art.gd` (FRAME), the walker's anchor and the zoom helper. The landing is atomic.
- **The head and face.** The head is scaled from 12 to 15 pixels. Eyes are 2 x 3 with an ink lash, an iris and a
  glint. No mouth, a two-pixel nose shade and a blush.
- **Outline and light.** One pixel of ink on the outside of the silhouette only. Light comes from the upper left.
  Inner seams use a darker shade, never ink, except lashes and hems.
- **Hair.** Every style reads at 5x on the laptop. Spiky has three to five tufts with one-pixel tips, bases three to five
  pixels wide, and a two-pixel spine under each tip. Bob has a flat fringe. Bun is a 5 x 4 knot. Twintails are two side masses. Ponytail has one tail with a tie.
  Curly has five bumps. No shape rests on a single highlight pixel.
- **Priority.** The sixteen townspeople's parts first (25 of the 52), then the creator-only parts.

## 6. Props and gates (hand-placed)

- A prop's width stays on the 16 px grid. Standing props grow in height by 1.25, which keeps the prop-to-figure
  ratio. A barrel becomes 16 x 20, a lamp post 16 x 40.
- Each prop gets its detail: fences get post caps and rail grain; barrels get stave
  seams; the signpost gets nails and a ground row; lamp posts get a halo on the lit frame.
- Shadows are one solid row of the darkest ground shade. The palette has no translucency.
- Doors, gate posts, signs, Hotaru and the pond shore never share a colour with the ground.
- Gates are two tiles. Fence only the yards that have a use: the cabbage plot and the Old Stones.

## 7. ComfyUI pictures

The buildings, landmarks, trees and larger props come from ComfyUI (SDXL with the pixel-art LoRA, palette-locked). The
approved hall, archive, smithy, workshop and Root Gate v3 keep their art. The new ones:

- **New renders, explicit ids only:** `ow-prop-gate-garden` (32 x 32, a 32 px walkway) for the cabbage plot and the Old
  Stones, judged beside the hand-placed two-tile gate at 5x (the layout places no arch, so there is no town arch).
  `ow-building-inn`, `ow-building-shop`, `ow-building-shrine` (each 96 x 96), and three distinct cottages at 80 x 80
  (`ow-building-cottage-pell`, `-seren`, `-hollis`).
- **Post-only changes, no render:** the Lantern Root (colours), the oak, the well, the stall and the laundry.
- **Two cached renders added to the manifest:** the pine and the hay cart.
- **Never** `scripts/pixel.sh --comfy` without ids: ten building entries are stale, and five of them are approved.
- **Home** keeps its picture until the player says to re-render: it is the first house they see.
- The approved pictures go into the game only at the merge step.

## 8. Menus and panels

The brief says the menus are too big. The compact targets, as fractions of the 1920 x 1080 screen:

- Small menus (pause, quest log, tracker, delete confirm, Hotaru's bubble): no wider than 24%, no taller than 40%.
- Dialogue: 1100 px wide (57%), body text 34 units.
- Forms (the creator): 45% x 59%. Progress: 61% x 68%.
- Boots and lesson editors: 60% x 72%. They are code editors, so they are bound by line count (at least 14 visible
  lines), not by the 40% cap.
- Click targets do not shrink: rows 44, front buttons 60, tabs 54, arrows 52 x 48, swatches 40. The focus ring stays
  3 units.
- Japanese is wider: budget 0.9 em per character, and size each fixed-width slot for its Japanese string.

Shots at the compact scale and at the 0.8 interface setting are part of the review.

## 9. Disagreements and what was decided

- **Display.** The layout and character reports assumed 1080p. The reality check showed the player's fullscreen laptop
  is 2560 x 1440. Resolved in section 2 (512 x 288).
- **Footprints.** The ComfyUI plan added a roof row, which breaks the art = footprint rule. Resolved: art = footprint x 16.
- **Gates.** The ComfyUI gate walkways were 16 px, which is one tile. Resolved: 32 px.
- **The use key.** Space (designer, architect) or F (engine, words). Resolved in section 2: Space.
- **Districts.** Three lists (layout 7, words 8, visual 8). Resolved: the layout's seven, with the person cells taken
  from the layout.
- **Residents.** Fern is at the tree in the square. Hollis's house is kept. Nix is not placed in this pass.
- **Lamps.** Today there are eight non-lane lamps. The layout's lamp rule (six to eight tiles apart on Main Street and the
  lamp lane) places them again in the content lane; the six lane lamps keep `group: "lane"`.
- **Tests and saves.** Tests hard-coded the start (6, 23) and the board cell. They now read both from the map. A saved
  cell that is blocked after a re-layout moves the player to the start.
- **Zoom.** Preview zooms were integers in some screens and 0.8 multiples in others. Resolved: one zoom helper, fed by
  the menus' targets, applied with the frame landing.
- **The boots table.** The town is 4,480 tiles, which doubles the table to about 207 KB against a 256 KB default. The
  limit is raised before the town lands.

## 10. Build order and file ownership

Slices, in order. Each slice keeps the tests green and the game launchable.

- **S0 (no visible change).** The output cap for the boots table; the cell check on load; tests read the start and the
  board from the map; the character-digest test fixed (a dictionary read on a missing key); the Japanese gap counted.
- **S1 (no visible change).** The things core and sandbox: `TownThings`, the `on_use` harness, the run and its tests.
- **S2 (view).** `BASE` 512 x 288, the float guard, the interior comments. Shots at 2560 x 1440 and 1920 x 1080.
- **S3 (town).** The 80 x 56 map from the layout, with the existing art. The sign and person text. The table is timed.
- **S4 (menus).** The compact targets, in parallel with S0 to S3. The zoom values wait for S6.
- **S5 (buildings).** The ComfyUI renders for the new footprints; the merge writes them into the game.
- **S6 (figures).** The 25 x 35 frames land together: the sprites, `characters.py`, `overworld_art.gd`, the walker, the
  zoom helper, the looks test and the pixel tests.
- **S7 (props).** The hand-placed detail pass.
- **S8 (the first things).** The cabbage-plot gate, the crossroads signpost, Space to use, X to edit, Hotaru's new beat.
  Shots with the gate closed and open.
- **S9 (later, with approval).** Dusk lighting; Nix; the Old Stones gate; the Root Gate door; Japanese for every new line.

File ownership, one writer per file:

| Lane | Owns | Reads |
|---|---|---|
| Engine and view | `scenes/overworld/{pixel_view,overworld,walker,overworld_art,hotaru_sprite,town_map_view}.gd`, `tools/overworld_shot.gd` | the map |
| Core things | `core/overworld/*`, `sandbox/overworld/{boots_run,thing_run}.gd`, `hooks.py`, `hooks.js`, new core and sandbox tests | the content |
| Content | `content/packs/core/overworld/maps/*.jsonc`, `talk/*.jsonc`, `quests.jsonc`, `townsfolk.jsonc`, `things/` (new), `content/overworld_content.gd` | the core |
| Menus | `scenes/overworld/{overworld_style,pause_menu,quest_log,quest_tracker,dialogue_box,boots_editor,boots_code_panel,lesson_editor,progress_panel,character_creator,character_card,character_select,creator_picker}.gd` | the theme |
| ComfyUI | `pipeline/pixel/manifest.json`, `pipeline/cache/art/` | the layout's footprints |
| Characters | `pipeline/pixel/sprites/{body,outfits,hair,hats,faces}.sprite` | the style bible |
| Props and items | `pipeline/pixel/sprites/{props,items}.sprite` | the prop rules |
| Tests | the overworld flow, opening, menu, content and map tests | the new start |
| Merge (orchestrator) | `pipeline/pixel/{characters.py,build.py,test_pixelkit.py}`, `game/assets/**`, the docs | everything |

Nothing commits until the merge. Godot runs go through one lock. ComfyUI and Blender never run together.

## 11. Open decisions for the player

1. Dusk lighting (S9).
2. Nix: a cottage beside home, or Hollis's house with Nix's lock.
3. Whether the letters workbench stays a title mode (kept for now).
4. Home: re-render it at the new size (it is the first house the player sees).
5. The Settings page for Lanternroot only, or left shared.
6. The view base, if the player plays on a 1080p screen most of the time: 512 x 288 gives 3x there, and 640 x 360 would
   also give 3x. The choice in section 2 is made for the laptop.
