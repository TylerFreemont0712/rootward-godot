# Lanternroot character animation

The overworld's people are now drawn from ComfyUI sprite sheets with one set of proportions in every view (ADR-0063).
This folder holds what to look at, and the candidates the style was chosen from.

## The cast (in the game)

Start with `cast/overview.png`: every townsperson and the player's start look, their four facings side by side.

- `cast/64x96/<id>.png`: each sheet as the game draws it, larger, with its rows and columns named.
- `cast/48x72/`, `cast/96x144/`: the same frames cut smaller and larger, for judging detail and for a later change of size.
- `cast/picks.json`: for each view, the two ComfyUI candidates' overlap with the blockout's outline, and which was kept.

The sheets themselves are in `game/assets/overworld/cast/` (64 x 96 frames since ADR-0064; 2 columns, stop and idle, by 4 rows, down,
up, left, right). How they are made is `pipeline/animation/README.md`; the commands are `scripts/cast.sh`.

**The method, in short.** Every character stands on one shared Blender body, with blockout shapes for their outfit,
hair, hat, face and item, in their colours. Blender turns the body to the front, the left and the back through one
camera. ComfyUI restyles each turn into the anime pixel look, and the restyle is held to the turn's outline. The cut is
the same for every frame. So the front, back and sides have the same head, body, hem and feet line, and every character
is on the same scale.

**What changed from the last sheet.** The front used to be a ComfyUI drawing made from a prompt alone, and its
proportions did not match the other views. It is now a restyled turn of the same body, like the back and sides.

## The candidates (how the style was chosen)

| File | Source | Pixel count | Tiles tall (16 px) |
|---|---|---|---|
| `comfy-32x48.png` | ComfyUI (Nova Anime XL + Pixel Art XL), one drawing | 32 x 48 | 3 |
| `comfy-40x60.png` | same drawing | 40 x 60 | 3.75 |
| `comfy-48x72.png` | same drawing | 48 x 72 | 4.5 |
| `comfy-64x96.png` | same drawing | 64 x 96 | 6 |
| `comfy-80x120.png` | same drawing | 80 x 120 | 7.5 |
| `blender-32x48.png` | Blender, built in code, low detail | 32 x 48 | 3 |
| `blender-48x72.png` | Blender, standard detail | 48 x 72 | 4.5 |
| `blender-64x96.png` | Blender, detailed | 64 x 96 | 6 |
| `models/anim-blender-*.blend` | the three Blender models | | |
| `sheet.png` | all of the candidates, one picture | | |

The player chose ComfyUI's look. `scripts/animation.sh comfy|blender|sheet` makes these again.
