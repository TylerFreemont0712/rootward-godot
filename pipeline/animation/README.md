# Characters: the cast's sprite sheets, and the candidates that led to them

Lanternroot's people are drawn from complete sprite sheets. The town cast uses the ComfyUI pipeline (ADR-0063);
the player and the updated commander use authored imagegen sources and a separate importer (ADR-0071, below).

```sh
scripts/cast.sh turns [--only ids]      # Blender: each character's blockout, turned front, left, back (ComfyUI down)
scripts/cast.sh restyle [--only ids]    # ComfyUI: img2img on every turn (ComfyUI up, about a minute per character)
scripts/cast.sh sheets [--only ids]     # the sheets, cast.json and the reviews, from the cache (no GPU), then an import
scripts/cast.sh check                   # whose look changed since their sheet was made
```

Every stage is cached: a turn renders again when its look or the camera changes, and a restyle when its turn, prompt or
settings change. `--force` renders again anyway. ComfyUI and Blender never run together (`scripts/gpu-guard.sh`).

## How a sheet is made

1. **The cast.** The townsfolk in `game/content/packs/core/overworld/townsfolk.jsonc`.
   `cast.json` adds a one-line description of each person from their portrait ("an old man village
   elder"); a townsperson it does not name still gets a sheet, as "a villager".
2. **A blockout (`blender_cast.py`).** Everyone stands on the same body: legs, boots, arms, a big head, eyes and blush.
   Each part of the look adds shapes on top: six outfits, six hair styles, six hats, three faces and three items.
   Colours are the look's ramps (the middle shade) and fixed ones for boots, wood, glow, leaves and pages. A hat that
   covers the crown leaves out the hair's crown, so nothing pokes through. A part with no blockout is an error.
3. **Turns.** One orthographic camera, 3.0 units tall with the ground at a fixed row, renders the figure turned to the
   front (0 degrees), the left (-90) and the back (180), 800 x 1200 each, in `pipeline/cache/animation/cast/<id>/`.
4. **Restyle.** ComfyUI img2img on each turn at denoise 0.7 (Nova Anime XL + Pixel Art XL), two candidates. The prompt
   is built from the look: who they are, each part in its colours ("long white robe with gold trim"), their boots, and
   the view. The background is removed.
5. **Pick and hold.** For each view, the candidate whose outline overlaps the turn's most (IoU) is kept; the scores are
   in `Concept/v0.3/animation/cast/picks.json`, and `cast.json` can override a pick (`"picks": {"left": 1}`) or a seed.
   The kept image is cut back to the turn's outline grown by 24 render pixels (two sprite pixels), so a restyle cannot change the
   proportions.
6. **The registered cut.** The whole camera frame goes down to the sprite frame (800 x 1200 to the person frame of
   `scale.jsonc`, 64 x 96 since ADR-0064, a box filter on
   premultiplied colour), with no crop and no per-frame fit. Every view and every character keeps the same scale, and the
   feet stand on row 93. One set of colours is shared across the views, an ink outline is added, and every colour is
   locked to the character's ramps in `palette.json`.
7. **The sheet.** Two columns (stop, idle) by four rows (down, up, left, right). Each facing has its own turn. Idle is stop
   with the body settled two pixels (`generate.breathe`), so it is the same drawing.

The outputs:

- `game/assets/overworld/cast/<id>.png` (128 x 384: 64 x 96 frames) and `cast.json`: the layout, the tile it was cut for, the ground row, and the
  look each sheet was made from.
- `Concept/v0.3/animation/cast/`: `overview.png` (everyone's four facings), each sheet at 64 x 96, and cut at 48 x 72
  and 96 x 144 for comparison, with its rows named, and `picks.json`.

## How the game uses them

`OverworldArt.character(look)` returns a `CharacterSheet`: the cast sheet made for exactly that townsperson's look,
else a single composed 25 x 35 sheet from `game/assets/overworld/characters/` for legacy NPCs. A changed townsperson
without an exact cast sheet still uses one composed texture. `Walker` draws one sprite for each character.

The player uses `OverworldArt.player_character(look)` and the dedicated sheets below. The old cast `player.png`
remains a style reference only, has no walk poses and is excluded from the cast generation configuration.

## Authored player sheets and commander replacement

The creator offers **Male** or **Female**. `game/assets/overworld/player/player.json` declares both sheets: 64 x 96
frames on row 93, four rows (down/up/left/right), columns 0–3 for idle and 4–11 for walking. Walk plays eight frames
at 12 fps, with 0.22-second grid steps. Idle has explicit durations for breathing and a short blink. Old appearance
saves load the new male default.
The legacy player parts and colours are no longer offered or rendered.

The player authorized built-in OpenAI imagegen for these assets. Selected source sheets and the complete prompts are
in `Concept/v0.3/animation/player/sources/` and `prompts.json`. Rebuild the final PNGs without generation:

```sh
flock /tmp/rootward-godot.lock godot --headless --path game -s res://tools/import_player_sheets.gd < /dev/null
```

`pipeline/animation/player_sources.json` records sources, height and direction corrections. Each directional source is
a 4 x 3 grid (eight walking poses followed by four idle poses). The importer uses one scale for the twelve frames,
centers the head, and registers feet to ground row 93. It writes the model sheets and `registration.json` beside the
sources. Open `Concept/v0.3/animation/player/review.html` to compare both clips in all four directions, pause, or change
playback speed.

The same importer packs the portrait-matching Sergeant Brisk replacement into the town cast's stop/idle layout.
`cast.json` marks it `authored_sheet: true`: cast turns, restyles and sheets preserve that PNG, including under
`--force`. Its source is `sources/commander.png`; the old sprite is retained as `commander-before.png` for comparison.

Walking advances a clip clock across grid steps instead of starting a new gait at every tile. The creator, character
lineup, Progress panel and town all read the same complete sheet. No face, hair or clothing is layered at runtime.

## Adding a character or a part

- **A new townsperson** in the content needs nothing here: `scripts/cast.sh turns --only <id>`, then `restyle`, then
  `sheets`. A line in `cast.json` (`"who"`) makes the prompt describe them.
- **Another player model** needs a complete four-direction walk/idle sheet and a model entry in `player.json`,
  followed by an intentional creator/content update. Part customization is deferred.
- **A new part** (a hoodie, a cap): a blockout function in `blender_cast.py` (in its table) and its words in
  `cast.json` `prompt.parts`. The tests (`test_cast.py`) and the error messages name what is missing.

## The candidates (how the style was chosen)

`Concept/v0.3/animation/` keeps the experiment that led here: one front drawing from ComfyUI at five pixel counts
(`comfy-*.png`) and a Blender-built figure at three (`blender-*.png`), from `manifest.json` through
`scripts/animation.sh comfy|blender|sheet` (`base_sprites.py`, `blender_base.py`). The player chose ComfyUI's look and
asked for the views to share one set of proportions, which is why the cast restyles Blender turns.

## Tests

    uv run --project pipeline python -m unittest discover -s pipeline/animation -p 'test_*.py'

They cover reading the content, a look's colours and prompt, choosing and holding a restyle, the registered cut (one
scale, one feet row, only the character's colours) and the sheet's layout. The game's side is
`game/test/scenes/character_sheet_test.gd` and `player_character_test.gd`.
