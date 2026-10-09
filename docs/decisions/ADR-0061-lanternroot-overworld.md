# ADR-0061: Lanternroot's overworld, a pixel town you walk on your own code

Accepted 2026-10-09 (in progress). Builds on ADR-0055 (Lanternroot) and `Concept/v0.3/05-lanternroot-overworld.md`.

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
- **Crisp pixels.** The world renders at about 320 x 180 into a SubViewport shown at a whole-number scale and widened to
  fill the window (`PixelView`); dialogue, portraits and menus are full resolution above it. Art: hand-placed
  characters, Hotaru and small props (`.sprite` text format), code-made ground tiles (dual grid), ComfyUI buildings,
  landmarks and trees, all locked to one palette and linted (`pipeline/pixel/`, `scripts/pixel.sh`).
- **Characters are parts** (body, outfit, face, hair, hat, item) drawn in default slot colours and recoloured per look;
  townspeople and the player use the same parts.
- **Title's Lanternroot button is unchanged** for now; the overworld is `res://scenes/overworld/overworld.tscn`, saved
  to `<profile>/overworld.json`.

## Consequences

- A first town (40 x 30, sixteen townspeople, ten ComfyUI buildings and landmarks) and the player's house exist, with
  the opening beats (Hotaru wakes you, boots, first step, all four ways, the town).
- ComfyUI walk cycles at 16 x 24 and ComfyUI tile textures were tried and rejected (thin, faceless, muddy); kept in the
  record so nobody tries them again without a new idea.
- Open: wiring the title, Japanese for every line, the boots' first rule, interiors beyond the house, Lint's sprite,
  night and lights, sounds of steps, gamepad polish, the unittest suite for `pipeline/pixel/`.
