# ADR-0061: Lanternroot's overworld, a pixel town you walk on your own code

Accepted 2026-10-09 (in progress). Builds on ADR-0055 (Lanternroot) and `Concept/v0.3/05-lanternroot-overworld.md`.

Amended 2026-10-10 by ADR-0062: the outdoor base is 512 x 288 (not 400 x 225 or 480 x 270), characters are 25 x 35 (not
20 x 28), the town is 80 x 56 (not 56 x 40), and the first programmable things answer Space.

## Context

The player wants Lanternroot to be a place: a top-down pixel town in the style of fantasy RPGs (not much 3D), with
light-novel dialogue that shows the townspeople's portraits, a character the children make themselves, a firefly
companion (Hotaru), and a first lesson in which the player codes their own movement. The asset budget is zero:
ComfyUI, Blender, code and hand-placed pixels only.

## Decision

- **Rules are pure** in `game/core/overworld/`: `OverworldMap` (ground through a legend; buildings solid but for a
  door that leads somewhere, or shut when it leads nowhere; props, signs, people, warps), `BootsRules` (what one key
  press does), `BootsCode` (blocks to Python or JavaScript), `Talk` (dialogue nodes, choices, flags, checks),
  `OverworldState` (the save). Content in `packs/core/overworld/` (terrain, townsfolk, looks, maps, talk), loaded and
  cross-checked by `OverworldContent`.
- **The player's movement is their own code.** `on_key(key, player)` (Python) or `onKey(key, player)` (JavaScript)
  changes `player.x` and `player.y`. `BootsRun` calls it once per key per tile in one sandbox job and the town walks on
  that table, so a step never waits for the sandbox and is still the player's real code. A move of one tile walks,
  into something bumps, further or diagonal is refused ("one step at a time"), off the map is refused, an error is
  reported with its line, and code that keeps state between calls is noticed (`remembers`). y grows downward.
- **Blocks are code.** The blocks editor's rules ("when → is pressed, change x by 1") become source shown under them
  and run in the sandbox like typed code; switching to Code carries the blocks over.
- **Crisp pixels.** `PixelView` renders the outdoor world at 480 x 270 logical pixels on a 1920 x 1080 display,
  shown at a whole-number 4x scale; other window sizes adapt while keeping each art pixel crisp. Maps marked
  `interior` use a 2x camera zoom so small rooms retain their former framing. Dialogue, portraits and menus are full
  resolution above it. Art: hand-placed
  characters, Hotaru and small props (`.sprite` text format), code-made ground tiles (dual grid), ComfyUI buildings,
  landmarks and trees, all locked to one palette and linted (`pipeline/pixel/`, `scripts/pixel.sh`).
- **Characters are parts** (body, outfit, face, hair, hat, item) drawn in default slot colours and recoloured per look;
  townspeople and the player use the same parts.
- **Title's Lanternroot button is unchanged** for now; the overworld is `res://scenes/overworld/overworld.tscn`, saved
  to `<profile>/overworld.json`.

## Consequences

- Lanternroot is a 56 x 40 town with sixteen hand-placed townspeople, ComfyUI buildings and landmarks, a walkable
  square, a lamp lane and a southern garden. The player's house is an interior map, with the opening beats (Hotaru
  wakes you, boots, first step, all four ways, the town).
- ComfyUI walk cycles at 16 x 24 and ComfyUI tile textures were tried and rejected (thin, faceless, muddy); kept in the
  record so nobody tries them again without a new idea.
- Open: wiring the title, Japanese for every line, the boots' first rule, interiors beyond the house, Lint's sprite,
  night and lights, sounds of steps, gamepad polish, the unittest suite for `pipeline/pixel/`.

## Update, 2026-10-14: Hotaru is a fairy, and the town's pictures are all 40 px

- The player's call: Hotaru is drawn as a small girl fairy (fairy wings, a soft glow), not a firefly; "the name is
  reference enough" (hotaru means firefly). Her sprite is hand-placed at the world's own scale (32 x 32 frames, one art
  pixel per world pixel, `pipeline/pixel/sprites/hotaru.sprite`; ComfyUI tries are compared in `shots/hotaru/compare.png`
  and lost at this size), and her portrait was rendered again without the insect wings and the firefly hood.
- Every building and prop the town draws now has a world-pipeline picture at 40 px (ADR-0064): the last 27 old 16 px
  pictures (fences, gates, cabbages, flowerbeds, lampposts with an unlit and a lit frame, the bridge, reeds, lilypads,
  the room's rug, doormat and lantern, and the catalog's stall, cart, laundry line, pine, sack, step, stump, rock and
  cottage) were remade or re-cut, and the anvil remade. A map's `sink` is in its picture's own pixels, so the bridge's
  and the desk lantern's were set again for the new pictures (through the Studio's Publish).
