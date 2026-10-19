# Pixel art for Lanternroot's overworld

Everything the top-down town shows, and the rules that keep it crisp (ADR-0061). Normal production art is free and local:
ComfyUI, Blender, code, and hand-placed pixels (see CLAUDE.md). Imagegen is used only for user-approved review candidates.

```sh
scripts/pixel.sh                          # build + lint (no GPU): parts, props, ground tiles, Hotaru, portraits
scripts/pixel.sh --comfy 'ow-building-*'  # also render/write ComfyUI pictures from manifest.json first (ComfyUI up, Blender closed)
scripts/pixel.sh --lint                   # only check what is in game/assets/overworld/
scripts/pixel.sh --only terrain           # rebuild/lint just the terrain atlas; leave all other pictures alone
```

## The style

- **40 px tiles since ADR-0064** (`scale.jsonc`); the ground tiles (`terrain.py`) are drawn at that tile. The parts,
  props and Hotaru below were drawn for **16 px tiles** and are enlarged in the game until `pipeline/world` and the cast
  replace them. Characters were authored as 25 x 35 frames (5:7, the 20 x 28 proportions 1.25x bigger, 2026-10-10),
  about 33 px tall with a 15 px head: chibi, shorter than the old game's 32 x 48 sprites (the player's call, 2026-10-09).
- **The world keeps whole-number pixel scaling** (`PixelView`). Its base is 512 x 288 (2026-10-10): on the player's 2560 x 1440
  laptop panel that is a 5x view, and at 1920 x 1080 it is 3x. Other window sizes adjust the visible world while keeping each
  art pixel crisp.
  Dialogue, portraits and menus draw at full resolution above it.
- **One palette** (`palette.json`): named ramps, light to dark; character ramps have three shades, world ramps four.
  Shadows lean violet, highlights yellow: the town is lantern-lit. Outlines are `ink` (#2a1d2b), never black.
- **Lit from the upper left.** Every opaque pixel is a palette colour and alpha is 0 or 255 (the lint enforces it;
  portraits are exempt, they are painted).

## Where each kind of picture comes from

| Picture | Source | Why |
|---|---|---|
| Characters (body, outfits, hair, hats, faces, items) | Hand-placed, `sprites/*.sprite` | At 25 x 35 a generator draws thin faceless figures; hand placement keeps faces, four directions and walk frames consistent, and parts recolour |
| Hotaru (16 x 16) | Hand-placed, `sprites/hotaru.sprite` | Tiny, and she must read as a Genji firefly |
| Small props (barrel, lamp post, sign, fence, furniture...) | Hand-placed, `sprites/props.sprite` | Generated ones turned to mush at 16 px |
| Ground (grass, path, cobble, water, floor, wall) | ChatGPT ImageGen terrain atlas plus code in `terrain.py` | Palette-locked texture crops supply richer ground art; code keeps them seamless and builds exact dual-grid edges |
| Buildings, landmarks, trees, bigger props (32 to 144 px) | ComfyUI, `manifest.json` (SDXL + Pixel Art XL LoRA, background removal, palette lock), with fixed pixel corrections where story or readability needs them | At this size the generator gives the detailed, lived-in look; deterministic corrections keep important silhouettes readable |
| Portraits | ComfyUI (the townspeople's set from the old game, `Concept/v0.3/Townspeople/`; Hotaru's in `manifest.json`) | Painted faces for the light-novel dialogue |

For a quality-critical building, a user-approved imagegen source can be evaluated through the same manifest postprocess
without contacting ComfyUI or replacing a game asset. Keep the transparent source in `Concept/v0.3/Update/art-source/`
and record its source and method in that update's handoff log. For example:

```sh
pipeline/.venv/bin/python pipeline/pixel/imagegen_candidate.py Concept/v0.3/Update/art-source/rootgate-chatgpt-imagegen-2026-10-09.png --asset-id ow-landmark-rootgate
```

This writes only `pipeline/pixel/candidates/ow-landmark-rootgate-imagegen.png`. It takes the sprite dimensions, color
count and outline from the selected manifest asset, preserves the source transparency, applies hard alpha and the shared
palette, then checks the candidate with the pixel lint. `--out` can select another name under `pipeline/pixel/candidates/`;
`--force` replaces an existing candidate. Candidate generation is review-only: it never writes into `game/assets/`.

### Promote an approved imagegen candidate

Promotion is opt-in per manifest asset. Keep the candidate under `pipeline/pixel/candidates/`, review it at town scale,
then replace that asset's `approved_imagegen_candidate: null` with its candidate path and provenance. For example:

```json
"approved_imagegen_candidate": {
  "path": "candidates/example-approved.png",
  "source": "Concept/v0.3/Update/art-source/example-source.png",
  "method": "ChatGPT Image Generation; palette-locked with pipeline/pixel/imagegen_candidate.py",
  "approval": "Approved after in-game town-scale review on YYYY-MM-DD"
}
```

The build accepts only PNG candidates below `pipeline/pixel/candidates/` that match the manifest's sprite dimensions and
pass the shared-palette and hard-alpha lint. A Root Gate record may add `"correction": "rootgate_lattice_clasp_v1"`;
that named correction adds a small clasp and lit seam over the imagegen root lattice without painting the broad stone
face used on the ComfyUI source. Its pixels are defined in `landmarks.py` and the corrected result is linted before
copying. The build applies it to the candidate, then copies the approved result to the asset's declared `out` after the
normal offline build. Run the ordinary build to promote it:

```sh
scripts/pixel.sh
```

Do not combine a configured candidate with `scripts/pixel.sh --comfy`: that command renders ComfyUI first, then the
approved candidate takes precedence. With the field absent or `null`, there is no override and the existing ComfyUI path
remains unchanged. To withdraw approval, set the field back to `null` (recommended, so the audit trail is clear). The
candidate stays available for review, while the current runtime image remains as-is until its ComfyUI source is restored:

```sh
scripts/pixel.sh --comfy 'ow-landmark-rootgate'
```

Record the source image, generation/edit method, candidate processing, approval date/reviewer, and outcome in
`Concept/v0.3/Update/artchecklist.md`. The Root Gate selects candidate 3 after art review and its 2026-10-10 in-world
capture; candidates 1 and 2 remain review-only.

## The .sprite format (`pixelkit.py`)

```
// a comment (# is a pixel: the outline)
legend W wood.1                  // this file's characters, beside palette.json's shared legend
sprite barrel 16 16              // a picture and its size
frame idle                       // a frame; `from <frame>` copies one first, `at x y` pastes rows from that corner,
....######....                   // `replace` clears each row it draws, `shift dx dy` moves the result
```

`.` keeps a pixel (empty in a new frame), `_` clears it. A frame without `at` must be full width (a miscounted row
is an error). Character parts use slot letters (`a b c` skin, `h i j` hair, `p q r` main, `t u v` trim, `x y z`
accent, `k l n` metal) drawn in the slots' default ramps; the game swaps a slot's three colours for the look's ramp
(`OverworldArt._recolour`), so one drawing serves every colour.

A character sheet is 3 x 3 frames: rows facing down, up, left (right is left mirrored); columns standing, step a,
step b. Body and outfits draw their own step frames; hair, hats and faces reuse the standing frame.

## Terrain (`terrain.py`)

Grass (or floor indoors) under every cell. Thirteen outdoor surfaces are available in Studio Land: grass, meadow,
dry grass, forest floor, moss, flowers, path, soil, tilled soil, sand, gravel, cobble and water (ADR-0077).
`game/content/packs/core/overworld/terrain.jsonc` declares their movement/step sound and optional `paint` location;
the Land palette follows that content order. Floor, wall and void stay indoors.

Every outdoor overlay has eight stable, palette-locked texture variants sampled from the ChatGPT ImageGen atlases in
`Concept/v0.3/Update/art-source/`. Meadow uses a dedicated 4x2 sheet with five flower layouts and three quiet
grass-only layouts from a matching ImageGen edit of that same sheet. Empty meadow keeps the original painted grass
colors and detail. Path samples eight layouts from one continuous ImageGen earth texture, avoiding framed swatches.
Meadow and path variants fade into a shared textured collar in the dual grid's half-cell phase. The grass base is
darker and uses layered tufts and dither; forest floor keeps its leaf-litter
texture with greener palette tones. Every other ground has four surface-specific layouts plus seeded details that make
eight stable variants. This includes dry grass, water and cobble; cobble adds occasional small broken stones. Leaf
litter, flowers, moss, soil, sand and gravel vary more strongly than calm grass and fitted cobble. `GroundLayer` hashes
ground kind and world position to choose a variant, so adjacent patches vary while repainting, undo or reopening a map
never rerolls them. Variants are cosmetic and do not change collision or consume the game's random stream.

Overlays use a **dual grid**: each tile covers the corners of four cells and takes one of 16 shapes (corner bits
tl 1, tr 2, bl 4, br 8). Edges come from a smooth field over the four corners; every variant shares the outer
pixels and alpha shape. The atlas layout declares layer `order` and an overlay's `variants`, `frames` and starting
`row`. Its source row is `row + variant * frames + frame`; water keeps three ripple frames for each variant.
Twelve layers require 48 bits, so the renderer's corner mask is 64-bit (fifteen layers maximum). Chunk repainting
is tested byte for byte against a fresh bake for all surfaces and water frames. Path margins follow only exposed
boundaries; top, bottom, left, right, corners, ends and the middle connect automatically without internal edge bands.
Source files and exact ImageGen prompts are in `Concept/v0.3/Update/art-source/land-joins-imagegen-2026-10-19.md`.

Run the art tests with `uv run --project pipeline python -m unittest discover -s pipeline/pixel -p 'test_*.py'`.
For native Studio reviews, use `ROOTWARD_LANTERNTOWN=studio-catalog ROOTWARD_LAND_SHOT=surfaces|area|cleared|joins|joins-close`
with `scripts/screenshot.sh res://tools/studio_land_shot.tscn shots/land-variety/review.png 30` (choose one mode).

## ComfyUI (`manifest.json`)

Runs through `pipeline/art/generate.py` with `--manifest pipeline/pixel/manifest.json`. Post `lock: true` snaps a
quantized render onto this palette (`generate.locked`). Buildings use the `ow-building` front-facade style so their
door baselines and camera stay together; trees and freestanding props keep the separate `ow-prop` three-quarter style.
The Root Gate keeps its generated stone-and-root silhouette,
then `landmarks.py` draws a closed rooted face and a faint amber seam over the cave mouth. This preserves the later
opening reveal while keeping the original Comfy raw render and cache intact.

Every manifest asset has a fixed seed and selected candidate (`pick`). The pixel build checks IDs, output paths, picks,
and `raw_from` source order before writing any assets. A `raw_from` variant uses its source's cached candidate batch;
select the whole source family when forcing a fresh render so the source is processed first.

To rerender selected assets with the same manifest settings and refresh their raw cache, keep Blender closed, check the
GPU guard, then run the generator directly and rebuild the pixel assets:

```sh
source scripts/gpu-guard.sh
need_comfy
uv run --project pipeline python pipeline/art/generate.py --manifest pipeline/pixel/manifest.json --only 'ow-building-inn,ow-building-cottage' --force --sheet /tmp/rootward-pixel-candidates.png
uv run --project pipeline python pipeline/pixel/build.py --review-dir /tmp/rootward-pixel-review
```

Use exact comma-separated IDs or a trailing `*` for a prefix, such as `--only 'ow-tree-*'`. The fixed seed and pick
make the chosen candidate repeatable with the same local ComfyUI models and sampler; inspect the generated contact sheet
before changing a pick. `--force` is for new samples; omit it to reuse a matching cached render. For a cheap palette and
alpha check of existing outputs, run `uv run --project pipeline python pipeline/pixel/build.py --lint`. Building doors
were placed by eye on a 16 px grid (`shots/pixel/doors.png` is how).
