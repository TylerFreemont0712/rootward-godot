# Lanternroot catalog expansion

Lanternroot Studio now has 118 registered expansion objects across four groups: 43 street and boundary objects,
28 furnishings, 29 nature and work objects, and 18 ImageGen assets. The ImageGen group contains 16 buildings and two
props. The completed refresh also replaces the town's placed building art and registers 14 new builder buildings;
the catalog now has 220 entries.

## Sources

- Other expansion objects retain their original blockout/restyle sources and editable specs in
  `pipeline/world/objects/expand-*.jsonc`.
- The bakery, greenhouse, village fountain, and roofed noticeboard use ChatGPT ImageGen sources. Fourteen more
  building options use the same source workflow: six service or weathered designs and eight additional fantasy
  designs. Their transparent PNGs are preserved in
  `Concept/v0.35/building-architecture/imagegen-candidates/`; `imagegen-sources.json` records source paths and
  generation briefs. The world pipeline fits them to 40 px tiles, locks the approved palette, and produces
  person-scale reviews. No ComfyUI generation is needed for these buildings.

The four metadata files (`boundaries.json`, `furniture.json`, `nature-work.json`, `imagegen.json`) record catalog
names, categories, tags, footprints, placement rules, and variant families. They are inputs for registration;
the game reads the resulting entries in `game/content/packs/core/overworld/catalog.jsonc`.

## Rebuild and inspect

Run from the repository root. To rebuild the registered ImageGen group:

```sh
scripts/world.sh cut --only expand-bakery,expand-greenhouse,expand-fountain,expand-noticeboard,expand-apothecary,expand-stable,expand-guardhouse,expand-bathhouse,expand-abandoned-cottage,expand-ruin-cottage,expand-observatory,expand-watermill,expand-moonweaver,expand-teahouse,expand-lighthouse,expand-crystalwright,expand-belltower,expand-mushroom-cottage
pipeline/.venv/bin/python pipeline/world/expansion/register.py
pipeline/.venv/bin/python pipeline/world/expansion/review.py
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
