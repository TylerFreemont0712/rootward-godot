# Rootward — menu and theme concepts

## Current review: two underground concepts

Open [underground-concepts.html](underground-concepts.html). **05 · Kernel Foundry** is the current lead; **06 · Rootvault Workshop** offers a different navigation and map layout. Each has six 1920×1080 PNGs: title, Play, Character/Skins, Academy, descent map and Shardrun battle. The gallery links to clickable offline mockups with the other menus.

These are browser-rendered layouts using the existing brown/amber palette, fonts and shard assets. The simple scenery establishes composition; richer Kernel Foundry art is the next requested pass, documented in its [art brief](05-kernel-foundry/ART_BRIEF.md). The built-in image generator reached its usage limit. No API fallback or game implementation was used.

The [Starfall variant pass](STARFALL_VARIANTS.md) was stopped at the user's request; its 19 images and prompts are retained. The original four directions below remain available.

Prepared on 2026-10-01. These are visual proposals for selection before implementation.

Open [index.html](index.html) for the comparison gallery. Start with the four title screens, then compare the same menu atlas across directions. Each direction has **five PNG images**, showing a title screen and **20 supporting screen concepts**.

| Direction | Character | Design brief |
| --- | --- | --- |
| 01 · Starfall Codex | Navy, ivory, gold and lilac; astronomical grimoire; celestial fantasy RPG | [Read brief](01-starfall-codex/README.md) |
| 02 · Rootglass Garden | Cream, forest green and coral; glass gardens and growing roots; welcoming academy | [Read brief](02-rootglass-garden/README.md) |
| 03 · Signal Foundry | Carbon, orange and lime; numbered industrial stations; machine-world science fiction | [Read brief](03-signal-foundry/README.md) |
| 04 · Paper Circuit | Ivory, ink, vermilion and blue; folded worlds and chapter indices; graphic adventure | [Read brief](04-paper-circuit/README.md) |

## What each image covers

| File | Screens |
| --- | --- |
| `01-title.png` | Title / Continue / Play / Academy / Library / Wardrobe / Settings / Quit |
| `02-main-menus.png` | Mode selection, run setup, local profiles, wardrobe, library, settings |
| `03-academy.png` | Learning hub and Root Map, coding lesson, Read & Trace, review and coach |
| `04-journey.png` | Paradigm draft, layer map, battle/program work surface, Spellforge workbench |
| `05-run-menus.png` | Rewards/cache, rest/reforge, deck/relics/stats, pause/abandon confirmation, results/history entry, how-to/Pip's Trial |

## Four different ways to navigate

| Direction | Button placement | Movement between menus |
| --- | --- | --- |
| Starfall Codex | Left chapter rail; confirm at the outside page corner | Open a chapter, turn nested pages, close an overlay back to the same page |
| Rootglass Garden | Labelled entrances distributed around the tree; Continue at bottom center | Move into a destination room, open its worktable, return through Home or Back |
| Signal Foundry | Central Play/Academy launch plates; right saved-run card; bottom utility dock | Expand the console, slide inspectors in from the side or up from the dock |
| Paper Circuit | Oversized horizontal chapter tabs; Continue bookmark; margin utilities | Switch chapters sideways, turn numbered folios, use a corner fold to go back |

Each design signals a different interpretation of the game: spellcraft, growth through learning, programming a machine, or exploring an illustrated code atlas. The navigation descriptions in the individual briefs cover opening, returning, preserved context, keyboard focus and reduced-motion behavior.

## Shared destinations

The title provides a calm front door. **Play** opens the mode chooser and each mode's own saved journey. **Academy** is also directly accessible, so learning has equal standing with the roguelite. **Library**, **Wardrobe**, **Settings** and the active local profile remain easy to find.

```text
Title
├── Continue → chosen mode's saved journey
├── Play
│   ├── Shardrun → setup → paradigm draft → map → battle → rewards → results
│   ├── Spellforge → setup → map → workbench / battle → results
│   ├── Academy → learning hub
│   └── Pip's Trial → guided introduction
├── Academy → Root Map / lessons / practice / projects / journal
├── Library → cards / relics / foes / concepts
├── Wardrobe → preview / choose / equip
├── Local profile → choose / create / edit / language
├── Settings → general / audio / display / accessibility
└── Quit
```

Academy is a working name for the additional programming-learning mode, informed by [ACADEMY_DESIGN.md](../../docs/ACADEMY_DESIGN.md). It has its own local progress, Python/JavaScript selection, beginner and advanced paths, and a workspace for reading, predicting, tracing, fixing, writing and improving code. Existing Verifier-style exercises fit within that journey. Learning progress does not increase combat power.

Across all directions, final UI should use visible keyboard focus, text alongside important icons, readable code, generous layout space, a wrapping wardrobe grid, clear Back/Close actions and room for Japanese text. Menus pause interaction underneath them; saved-run actions and destructive actions are visually distinct.

## Review and next step

Choose the overall direction by number or name. You can also specify a preferred title from one direction and a menu layout from another. The images explore composition, art, typography and navigation; their sample scores, card text and small generated labels are illustrative. Exact final wording, responsive layouts and interactions will be resolved during implementation after selection.

Generated with the **built-in image_gen.imagegen tool**. The complete prompt set is saved in [prompts.json](prompts.json); image dimensions, hashes and original generated sources are recorded in [provenance.json](provenance.json). Each direction's title image is the style reference for its four subsequent atlases. The live game, rules and menu code have not been changed.
