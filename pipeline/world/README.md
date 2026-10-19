# The world's objects: buildings, landmarks, trees, props and furniture

Everything that stands in Lanternroot except its people (the cast, `pipeline/animation/`) and its ground
(`pipeline/pixel/terrain.py`) is made here, at the world's scale (ADR-0064): 40 px tiles, people 64 x 96. A thing is a
short spec in **tiles**; the pipeline works out every size in pixels, so the scale cannot drift.

```sh
scripts/world.sh new <id> --kind building --footprint 5x5 --what "a cosy cottage with a thatched roof"
scripts/world.sh check [--only <id>]     # every spec checked; which pictures are stale
scripts/world.sh make --only <id>        # blockout, restyle, cut; stops and starts ComfyUI for you
scripts/world.sh adopt <render id> --as <id>   # re-cut an existing ComfyUI render (pipeline/pixel/manifest.json)
```

The stages one at a time: `blockout` (Blender, ComfyUI down), `restyle` (ComfyUI up), `cut` (no GPU). Each is cached:
a blockout renders again when its spec or the Blender code changes, a restyle when its blockout or prompt changes.
`--force` renders again anyway.

## How a picture is made

1. **The spec** (`objects/<id>.jsonc`): the kind, a few words on what it is, the footprint (the map's `size`), the
   colour of each role as a palette ramp, and the kind's own fields (a building's walls, roof, door and windows; a tree's
   trunk and canopy; a prop's parts). `check` refuses a typo, a ramp that is not in the palette, a door off the
   footprint, or a footprint that differs from where the maps place it, and says how to fix each.
2. **The blockout** (`blender_world.py`). `world.py` turns the spec into simple shapes: walls, a roof, a door and windows
   for a building; a trunk and leaves for a tree; the listed parts for anything else. Blender draws them in the town's
   3/4 view (heights in full, depths at 0.6), through a camera straight on, one tile across always the same width.
3. **The restyle.** ComfyUI img2img on the blockout (Nova Anime XL with Pixel Art XL, like the cast), three candidates,
   with a prompt built from the spec's words and colours. A small blockout is centred on a 512 px canvas first.
4. **Pick and hold.** The candidate whose outline matches the blockout's best is kept, and it is cut back to the
   blockout's outline grown a little, so the restyle adds detail but cannot change the size or shape.
5. **The cut.** The whole frame down to its size in pixels (one tile = 40 px), hard alpha, the kind's colour count, an ink
   outline, every colour locked to the spec's ramps, and the pixel lint.

Out come `game/assets/overworld/world/<id>.png` and `world.json` (each picture's size, footprint, frames, tile and what
it was made from), and a review, `Concept/v0.3/world/<id>.png`: the picture on the grass at 2x with its footprint
outlined in yellow and a person beside it (at the door, for a building), and above it the blockout and every candidate
with its score. **Always look at the review** before calling a picture done.

The game draws `world/<id>.png` for any map object whose `art` is `<id>`, before the older picture of that name
(`OverworldArt.building`, `prop`), so a new picture replaces an old one without touching the maps.

## Sizing and art feedback in Studio

F2 → Objects: select a building or prop, edit **Width / Depth** and choose **Apply size**, or drag its footprint
handles. This works for imported art too. The picture and collision footprint resize together; **Original size**
restores its dimensions and Ctrl+Z undoes the whole edit, including linked return-door changes. Map drafts retain
`art_size` as the native picture footprint and `art_shape` as the original door/collision shape. The pipeline checks
that native footprint; the spec itself does not change when one placement is resized (ADR-0076).

Right-click a catalog asset or placed object → **Needs updating**. **Asset updates** opens the persistent list,
with notes and a replacement prompt; the catalog also has a Needs updating filter. Records live in
`user://studio/asset_updates.json`, outside map drafts, and Mark reviewed keeps the brief for later use.

For a spec with a restylable blockout, **Queue replacement** drafts a new variant ID and copies the source spec with
the requested `what`. **Run remakes** invokes the existing `scripts/world.sh make` bridge. Shared positive style,
negative prompt and palette constraints come from `style.json`. The source art is retained for comparison and the
new variant is chosen from the catalog after generation. Imported sources and exact authored geometry keep a prompt
for later art work: recutting an imported source would not create new artwork, and modular joins must remain exact.

## Writing a spec

Sizes are tiles. A person is 2 tiles tall and 1 wide.

- **footprint** `[width, height]`: the cells the thing covers on the map, exactly the map's `size`. A building's picture
  fills its footprint exactly; a prop or tree may rise above it (its picture is taller than its footprint) and a tree's
  leaves may spread past its sides.
- **ramps** `{role: ramp}`: the colours, from `pipeline/pixel/palette.json` (four-shade ramps: `plaster`, `thatch`,
  `wood`, `stone`, `cobble`, `steel`, `gold`, `glow`, `leaf`, `pine`, `grass`, `dirt`, `water`, `cloth_*`). The picture is
  locked to these, so name every colour it should have.
- **building**: `walls` (the wall height; 2.4 fits the door to a person), `roof` (`gable`, `hip` or `flat`), `door`
  (its column from the left, the map's door), `windows` (columns). The roof's height is solved so the picture fills the
  footprint: a taller footprint is a bigger roof. Roles: walls, roof, trim, door, window, base. Add a chimney or a sign
  with `parts`.
- **tree**: `trunk` (its height), `canopy` (`[width, height]` of the leaves), `shape` (`round` or `pine`). Roles: trunk,
  leaves.
- **prop, furniture, landmark**: `parts`, each `{"shape", "at", "size", "ramp"}`. `at` is the corner nearest the front,
  left and ground of the shape's box and `size` its width, depth and height, both `[x, y, z]` in tiles from the
  footprint's front-left corner: x to the right, y back, z up. Shapes: `box`, `cylinder`, `cone`, `ball`, `gable` and
  `hip` (a roof with its ridge along x). `ramp` is a role from `ramps` or a palette ramp; `shade` (optional) picks
  one of its shades, 0 the lightest (dark iron is `steel` at 3).
- Optional: `restyle: false` cuts the exact Blender render through the shared palette and outline stage. Use it
  for modular walls, fences and gates whose joins and rail openings must match exactly; the default is `true`.
- Optional: `seed` (another set of candidates), `pick` (keep a candidate other than the best-scoring one, after looking
  at the review), `denoise` (how far the restyle may stray from the blockout: lower keeps the shape, higher adds detail).

A barrel:

```jsonc
{
 "id": "barrel",
 "kind": "prop",
 "what": "an oak barrel with iron hoops",
 "footprint": [1, 1],
 "ramps": {"staves": "wood", "hoops": "steel"},
 "parts": [
  {"shape": "cylinder", "at": [0.15, 0.15, 0], "size": [0.7, 0.7, 0.9], "ramp": "staves"},
  {"shape": "cylinder", "at": [0.12, 0.12, 0.2], "size": [0.76, 0.76, 0.08], "ramp": "hoops"},
  {"shape": "cylinder", "at": [0.12, 0.12, 0.62], "size": [0.76, 0.76, 0.08], "ramp": "hoops"}
 ]
}
```

## Judging a review

- Does it read as what `what` says, at 1x, from across the room?
- Is it the right size beside the person? A door is about as tall as they are; a barrel reaches their waist; a chair
  their knees.
- Does it stand on its footprint (the yellow box), without floating above the bottom edge or hanging off the sides?
- No stray specks, no ground or shadow drawn under it, no second object.

If a candidate is wrong, try another `seed`, or `pick` a better one. If the shape is wrong, fix the spec's shapes: the
restyle follows the blockout, so the blockout is where proportions are decided.

## Adopted pictures

`adopt` writes a spec whose `source` is an existing ComfyUI render (`{"picture": "<render id>", "pick": n}`) or an
approved image (`{"image": "<path>"}`). It has no blockout: the picture is fitted into its frame (`footprint`, plus `pad`
tiles each side and `above` tiles over the top, both from the old picture's size) and cut the same way. This is how the
town's ComfyUI buildings and trees reached 40 px before their blockouts exist. A spec made with `new` replaces an adopted
one of the same id.

## Registered art and gate frames

An approved source can preserve its full canvas with `"source": {"image": "<path>", "registered": true}`.
Use this for modules whose transparent margins define rail joins. `"images": ["closed.png", "open.png"]` accepts
ordered authored frames, using the same per-frame size. These frames cannot be combined with `unlit` recolouring.

The 2026-10-17 timber kit, Lantern Tree and Root Gate sources, prompts, previous assets and interactive comparison
are under `Concept/v0.3/Update/town-polish/`. Rebuild the registered kit, then the world art:

```sh
flock /tmp/rootward-godot.lock godot --headless --path game -s res://tools/import_town_boundaries.gd < /dev/null
flock /tmp/rootward-godot.lock scripts/world.sh cut --only fence,fence_v,fencepost,fence-end-n,fence-end-e,fence-end-s,fence-end-w,fence-corner-ne,fence-corner-nw,fence-corner-se,fence-corner-sw,fence-tee-n,fence-tee-e,fence-tee-s,fence-tee-w,fence-cross,gate,gate_v,gate-wide-2,gate-wide-3,gate-wide-2-v,lanterntree,rootgate
```

The sixteen timber shapes use shared posts and rail sockets, including ends, corners, tees and crossings. The
Studio resolves their connection masks from catalog metadata. Vertical and horizontal runs use one ground anchor.
Gate sheets now contain thirteen registered hinge poses, closed first and open last. Wide gates draw once at their
full footprint with paired leaves and no center post. `swing: {"axis": "horizontal", "material": "wood"}` in a spec
is copied into the world index; `TownGate` uses it to opt into the shared passage renderer. The vertical axis and
steel material are also supported. Ordinary walkable gates open for any Walker on their footprint, then return
closed. Programmed gates retain their state and collision rules. Catalog and placement previews show the closed
endpoint. See ADR-0072 for placement/undo and ADR-0074 for occupancy and animation.

Rebuild the nine native gate sheets without a GPU or external art service:

```sh
godot --headless --path game -s res://tools/build_gate_art.gd
scripts/world.sh cut --only gate,gate_v,gate-wide-2,gate-wide-3,gate-wide-2-v,expand-arched_wood_gate,expand-arched_wood_gate_v,expand-iron_garden_gate,expand-iron_garden_gate_v
```

Sources and endpoint SVGs live in `Concept/v0.3/Update/gate-swing/`. Run this gate build after
`import_town_boundaries.gd` if rebuilding the older timber kit too.

## Tests

    uv run --project pipeline python -m unittest discover -s pipeline/world -p 'test_*.py'

They cover checking specs (typos, ramps, doors, the maps), solving a building to its footprint, frames and render sizes,
the prompt, and the cut. The game's side is `game/test/scenes/world_art_test.gd`.
