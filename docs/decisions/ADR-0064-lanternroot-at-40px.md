# ADR-0064: Lanternroot at 40 px: one scale for the world, its people and its art

Accepted 2026-10-13. Changes ADR-0061 (16 px tiles), ADR-0062 (the 512 x 288 base, 25 x 35 characters, interiors at 2x)
and ADR-0063 (32 x 48 cast sheets).

## Context

The cast sheets (ADR-0063) made the people bigger and more detailed than the town around them: doors, props and
buildings were sized for a 33 px figure on 16 px tiles. The player wants a somewhat detailed world in a "slightly more
modern" pixel style: finer pixels than the 5x of 2026-10-10, people at 64 x 96, and modern menus. They want **the same
amount of town on screen** as now (32 x 18 tiles). Changing the art's size slightly to make that work is fine.

Interiors are to be the same scale as the town, as their own scene, with everything outside the building pure black.

They also asked for a pipeline for the background objects (buildings, props, trees, furniture) that a smaller model
can run and still make decent art without many mistakes.

## Decision

- **40 px tiles, a 1280 x 720 view, 64 x 96 people.** On the player's 2560 x 1440 laptop the world is drawn at exactly
  2x, so pixels are crisp and 2.5 times finer than before, and the view is 32 x 18 tiles, the same as the 512 x 288
  view at 16 px. A 64 x 96 frame's figure stands about 80 px, two tiles, close to the 2.1 to 2.4 tiles of before, so
  the town's layout keeps working with small changes.
- **One scale, written once.** `OverworldScale` (GDScript) holds the tile, the view and the person frame;
  `game/content/packs/core/overworld/scale.jsonc` holds the same numbers for the pipelines, and a test fails if they
  disagree. Nothing else in the game or the pipelines writes 16 or 40.
- **The view picks the nearest whole scale.** `PixelView` rounds (not floors) the window-to-base ratio: 2x and
  1280 x 720 on the laptop, 2x and 960 x 540 at 1080p, 3x and 1280 x 720 at 4K.
- **Art records the tile it was drawn for.** Every art index (`terrain.json`, `props.json`, `buildings.json`) carries
  `tile`. Art drawn for another tile is scaled up once on load (nearest neighbour), so the town stays whole while each
  kind of art is remade, and a missing remake never breaks a screen. Remade art carries `tile: 40` and is drawn as is.
- **Interiors are the town's scale.** No camera zoom indoors. An interior is its own map drawn alone, on black: the
  viewport's clear colour is black and nothing is drawn outside the room's walls.
- **Background objects get their own pipeline,** built like the cast's (ADR-0063): a spec in tiles (footprint, height,
  what it is, its colours), a Blender blockout from the spec in the town's camera, a ComfyUI restyle held to the
  blockout's outline, a registered cut at the world's scale, the palette lock and the lint, and a review picture of the
  object on the ground beside a person. Every check prints what is wrong and how to fix it, so a smaller model following
  the README and the skill can make art without judging proportions by eye.

## Alternatives

- **32 px tiles at 1024 x 576.** The player's first pick for the tile. It keeps the same view only at 2.5x on the laptop,
  which makes art pixels alternately 2 and 3 screen pixels wide. 40 px at 2x gives the same view with every pixel crisp.
- **32 px tiles at 1280 x 720.** Crisp, but 40 x 22 tiles on screen: more town than the player wants.
- **48 x 72 people.** Readable faces, but the player chose the larger, more detailed frame.

## Consequences

- Every piece of overworld art is remade or re-cut: ground tiles in code at 40 px, ComfyUI buildings and trees re-cut
  from their cached renders, hand-placed props and Hotaru through the new pipeline. Until then they are scaled up.
- The character creator's parts (25 x 35) are scaled up for a custom look until the creator is redesigned for the cast's
  sheets (open, the player's call).
- Interiors need walls and furniture at 40 px; the home map is redrawn for it.
- Pixel offsets in the scenes (Hotaru's hover, prompts, shadows) and map `sink` values are in world pixels and were
  scaled by 2.5.
