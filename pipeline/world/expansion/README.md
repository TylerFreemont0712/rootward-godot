# Lanternroot catalog expansion

This batch adds 90 placeable objects to Lanternroot Studio: 31 street and boundary objects, 28 furnishings,
14 nature objects, 15 farm and work objects, and two buildings. Three Luna agents prepared the object specs;
the conductor generated, reviewed, and registered the finished pictures.

## Sources

- 86 objects use the existing Blender blockout → ComfyUI restyle → palette cut workflow. Their editable specs
  are `pipeline/world/objects/expand-*.jsonc`. The checkpoint, LoRA, palette, and projection are the existing
  `pipeline/world/style.json` and `pipeline/pixel/palette.json`.
- The bakery, greenhouse, village fountain, and roofed noticeboard use ChatGPT's built-in image generation,
  requested explicitly by the user for this batch. Original transparent images are kept in `imagegen/`;
  `imagegen-sources.json` records the complete prompts and source paths. The world pipeline cuts these
  adopted sources to the same 40 px tile scale and palette as the other objects.

The four metadata files (`boundaries.json`, `furniture.json`, `nature-work.json`, `imagegen.json`) record catalog
names, categories, tags, footprints, placement rules, and variant families. They are inputs for registration;
the game reads the resulting entries in `game/content/packs/core/overworld/catalog.jsonc`.

## Rebuild and inspect

Run from the repository root. For an individual object:

```sh
scripts/world.sh make --only expand-chair-cushioned
pipeline/.venv/bin/python pipeline/world/expansion/register.py
pipeline/.venv/bin/python pipeline/world/expansion/review.py
```

`make` handles the GPU handoff between Blender and ComfyUI. For the four adopted ChatGPT sources, `cut` is enough:

```sh
scripts/world.sh cut --only expand-bakery,expand-greenhouse,expand-fountain,expand-noticeboard
```

Every object has a pipeline review at `Concept/v0.3/world/<id>.png`. The grouped contact sheets are generated
in `shots/studio/expansion-<group>.png`; a missing sprite remains visibly marked. `register.py` refuses missing
pictures, unknown categories, and mismatched footprints. `--ready-only` registers only finished pictures.

The wall families group horizontal, end-on, and corner pieces by material, so Studio's `[` and `]` can change
orientation while keeping the material. Rugs and crop patches are walkable and draw below standing objects.

## In the game

Launch with `ROOTWARD_STUDIO=1 scripts/play.sh`, enter Lanternroot, and press F2. Browse the normal categories
or search `expand` for the entire new batch. Farm and work also gains Animal care, Farm tools, and Workstations.
The batch supplies catalog objects; it does not place them in the town's saved maps.

To capture the expanded catalog after ComfyUI has stopped:

```sh
ROOTWARD_LANTERNTOWN=studio-catalog ROOTWARD_EXPANSION_CATEGORY=furniture \
  scripts/screenshot.sh res://tools/studio_expansion_shot.tscn shots/studio/expansion-browser.png 50
```
