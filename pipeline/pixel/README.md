# Pixel art for Lanternroot's overworld

Everything the top-down town shows, and the rules that keep it crisp (ADR-0061). Free and local only: ComfyUI,
Blender, code, and hand-placed pixels (no paid tools; see CLAUDE.md).

```sh
scripts/pixel.sh                          # build + lint (no GPU): parts, props, ground tiles, Hotaru, portraits
scripts/pixel.sh --comfy 'ow-building-*'  # also render/write ComfyUI pictures from manifest.json first (ComfyUI up, Blender closed)
scripts/pixel.sh --lint                   # only check what is in game/assets/overworld/
```

## The style

- **16 px tiles.** Characters are 16 x 24 frames, about 22 px tall, a 12 px head: chibi, shorter than the old game's
  32 x 48 sprites (the player's call, 2026-10-09).
- **The world renders at about 320 x 180** and is shown at a whole-number scale (6x at 1080p), widened to fill other
  window shapes (`PixelView`). Dialogue, portraits and menus draw at full resolution above it.
- **One palette** (`palette.json`): named ramps, light to dark; character ramps have three shades, world ramps four.
  Shadows lean violet, highlights yellow: the town is lantern-lit. Outlines are `ink` (#2a1d2b), never black.
- **Lit from the upper left.** Every opaque pixel is a palette colour and alpha is 0 or 255 (the lint enforces it;
  portraits are exempt, they are painted).

## Where each kind of picture comes from

| Picture | Source | Why |
|---|---|---|
| Characters (body, outfits, hair, hats, faces, items) | Hand-placed, `sprites/*.sprite` | At 16 x 24 a generator draws thin faceless figures; hand placement keeps faces, four directions and walk frames consistent, and parts recolour |
| Hotaru (16 x 16) | Hand-placed, `sprites/hotaru.sprite` | Tiny, and she must read as a Genji firefly |
| Small props (barrel, lamp post, sign, fence, furniture...) | Hand-placed, `sprites/props.sprite` | Generated ones turned to mush at 16 px |
| Ground (grass, path, cobble, water, floor, wall) | Code, `terrain.py` | Seamless textures and dual-grid edges need exact pixels |
| Buildings, landmarks, trees, bigger props (32 to 96 px) | ComfyUI, `manifest.json` (SDXL + Pixel Art XL LoRA, background removal, palette lock) | At this size the generator gives the detailed, lived-in look |
| Portraits | ComfyUI (the townspeople's set from the old game, `Concept/v0.3/Townspeople/`; Hotaru's in `manifest.json`) | Painted faces for the light-novel dialogue |

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

Grass (or floor indoors) under every cell; path, cobble, flowers and water drawn on top as a **dual grid**: each tile
covers the corners of four cells and takes one of 16 shapes (corner bits tl 1, tr 2, bl 4, br 8). Edges come from a
smooth field over the four corners, so neighbours always line up; water has three ripple frames.

## ComfyUI (`manifest.json`)

Runs through `pipeline/art/generate.py` with `--manifest pipeline/pixel/manifest.json`. Post `lock: true` snaps a
quantized render onto this palette (`generate.locked`). `raw_from` re-cuts another entry's cached render to keep a
second candidate. Building doors were placed by eye on a 16 px grid (`shots/pixel/doors.png` is how).
