---
name: rootward-world-art
description: Make or change Lanternroot's background objects - buildings, landmarks, trees, props and interior furniture - with the world pipeline (pipeline/world, scripts/world.sh, ADR-0064). A spec in tiles becomes a Blender blockout in the town's 3/4 view, restyled by ComfyUI and cut at 40 px tiles. Use for any new or changed picture of a thing that stands on the overworld or indoors, or when a map needs a new object. Not for people (pipeline/animation, scripts/cast.sh) or ground tiles (pipeline/pixel/terrain.py).
---

# Rootward world art

Read `pipeline/world/README.md` first: the spec's fields, the stages, and how to judge a review. ADR-0064 says why.

## Rules

- **Sizes are tiles, never pixels.** A tile is 40 px, a person is 2 tiles tall and 1 wide. You write tiles; the
  pipeline computes pixels from `game/content/packs/core/overworld/scale.jsonc`.
- **The footprint is the map's `size`**, exactly. A building's door column is the map object's `door[0]`.
- **Colours are palette ramps** (`pipeline/pixel/palette.json`); the picture is locked to the ones the spec names.
- **Free and local only**: ComfyUI, Blender, code. Never a paid service. ComfyUI and Blender never run at once;
  `scripts/world.sh make` stops and starts ComfyUI for you, the single stages refuse if the wrong one is up.
- Never edit `game/assets/overworld/world/` by hand: `cut` writes it. Never hand-write pixel sizes into `world.json`.

## Steps

1. Look at where the thing goes: `grep -n '"art": "<id>"' game/content/packs/core/overworld/maps/*.jsonc` gives its
   footprint (`size`, default `[1, 1]`) and a building's `door`.
2. `scripts/world.sh new <id> --kind <building|landmark|tree|prop|furniture> --footprint WxH --what "<a few words>"`.
3. Edit `pipeline/world/objects/<id>.jsonc`: ramps for every role, and the kind's fields (README, "Writing a spec").
   Keep parts few and large: the restyle adds the detail; the blockout only fixes size and shape.
4. `scripts/world.sh check --only <id>` until it prints no problems. Each problem says how to fix it.
5. `scripts/world.sh make --only <id>`. It takes about a minute (most of it ComfyUI).
6. **Open `Concept/v0.3/world/<id>.png` and look.** Check the list under "Judging a review" in the README. Fix the spec
   (shape problems), or set `seed` or `pick` (a bad candidate), and make it again.
7. Screenshot it in the town: `SHOT_SIZE=2560x1440 ROOTWARD_LANTERNTOWN=town scripts/screenshot.sh
   res://tools/overworld_shot.tscn shots/overworld/town.png 50` (ComfyUI must be down for the screenshot's GPU).
8. Run `uv run --project pipeline python -m unittest discover -s pipeline/world -p 'test_*.py'` if you changed
   `world.py`, and say in your report which reviews you looked at.

## Common mistakes

- A footprint that is not the map's `size`: `check` refuses it. Change the spec, or change the map on purpose.
- A part with `y` below 0 stands in front of the footprint and is cut off: keep `y` from 0 back.
- Walls too tall for the footprint: a building needs room for its roof, so `check` asks for lower walls or a taller
  footprint.
- Two parts with a face in the same plane (glass flush with its frame) fight in the render and come out black: set
  one a few hundredths of a tile behind the other.
- Big flat areas of one colour come out as one slab (a bench's seat and back, shelves of books): split them into the
  separate pieces you want to see (rails, a row of book spines), and use `shade` to set them apart.
- Calling it done without looking at the review. The scores only say the outline matched; only the picture says it
  reads as a cottage.
