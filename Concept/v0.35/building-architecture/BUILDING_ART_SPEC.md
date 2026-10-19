# Lanternroot building art specification

## Approved camera

Panel 4, the lower-right image in [`home-angle-study.png`](home-angle-study.png), is the architecture reference. Match the
current [`home-front-plane-v4.png`](concepts/home-front-plane-v4.png) camera: cardinal top-down gameplay orientation,
the entrance facing screen-bottom, and the rear of the roof receding gently toward screen-top. Turn the broad front
facade slightly toward the camera so it reads as one clear plane. Keep the side elevation hidden; do not show a side
wall, side windows, or a second facade. All buildings share this camera and ground anchor.

Build depth through the roof planes, centered ridge, eaves, raised doorway, a few layered materials, and restrained
pixel shading. Keep the ridge centered over the entrance and avoid twisting the building to one side. Towers and
chimneys may rise behind the roof, but their lower forms should join the roofline. The observatory follows this rule:
its star chamber is integrated into the ridge instead of perched on a separate roof.

## Shared style and material rules

- Detailed, crisp fantasy pixel art with stable pixel clusters, a dark plum outline, and a readable silhouette at the
  40 px-per-tile game scale.
- Keep one broad facade, a centered entrance near the lower edge, a visible stone or timber base, and clear windows.
  Retain space immediately in front of the door for a character to stand.
- Vary roof shape, material, facade color, window geometry, and roof ornaments so each builder option has its own
  identity. Keep the roof ridge, front-facing facade, outline weight, lighting direction, and camera consistent.
- Use the approved palette ramps from `pipeline/pixel/palette.json`: `ink` for the outline; `wood`, `cloth_brown`,
  `stone`, `cobble`, and `plaster` for timber and masonry; `cloth_navy`, `cloth_blue`, `cloth_purple`, `cloth_teal`,
  and `thatch` for roofs; `glow` for warm windows; and `steel` or `gold` for small hardware and ornaments. The world
  cut locks colors to these ramps and limits a building to 40 colors.
- Each source is one complete isolated building on transparency. Do not include ground, paths, grass, scenery, people,
  detached props, labels, frames, collages, or a shadow beneath the footprint.

## Scale and collision

One map tile is 40 px. Town characters use a 64 × 96 px frame and stand about 2.4 tiles high. A visible door leaf
should be about 80–96 px tall in the native asset frame, close to a character's height. Keep architectural details
large enough to remain distinct after palette locking and pixel lint.

The native art frame is the `footprint` in `pipeline/world/objects/<id>.jsonc`; final image dimensions are that frame
multiplied by 40 px. The placed map footprint can be larger. In that case the map carries `art_size` and `art_shape`,
and the renderer stretches the native art over the placed footprint while collision uses the map's separate door and
solid mask. Treat the map's `size`, `door`, and collision rows as authoritative. Keep the approach cell open and do not
hand-scale files in `game/assets`.

## Town set and native frames

Every building uses the approved camera. `Door` is the native art-frame coordinate for builder assets; `Map size` and
`Map door` are the placed shape for current-town buildings. The new optional builder assets use matching native and
map footprints and have no entrance warp until a map author places them.

| ID | Distinguishing architecture | Native frame | Map size / door |
|---|---|---:|---|
| `cottage` | Compact timber cottage, slate roof and stone trim | 5 × 5 | asset only |
| `home` | Warm timber, blue-violet shingles, round gable window, stone doorway | 6 × 6 | 8 × 9 / [4, 8] |
| `cottage-hollis` | Compact timber cottage with an individual roof/window treatment | 5 × 5 | 6 × 6 / [3, 5] |
| `cottage-pell` | Mapmaker's cottage, timber and pale stone | 5 × 5 | 6 × 6 / [3, 5] |
| `cottage-seren` | Summoner's cottage with a distinct glow/window accent | 5 × 5 | 6 × 7 / [3, 6] |
| `archive` | Broad civic archive with stone body and high slate gable | 7 × 6 | 12 × 9 / [6, 8] |
| `hall` | Village hall with balanced windows and a clock gable | 9 × 8 | 10 × 9 / [5, 8] |
| `inn` | Warm Hearth timber inn, amber windows and a broad gable | 6 × 6 | 7 × 7 / [3, 6] |
| `shop` | Compact shop with a clear sign/window facade | 6 × 6 | 7 × 7 / [3, 6] |
| `shrine` | Violet slate and centered lantern ornament | 6 × 6 | 7 × 7 / [3, 6] |
| `smithy` | Broad forge frontage, strong stone base and roof vent | 7 × 5 | 13 × 9 / [6, 8] |
| `workshop` | Low tinker's workshop with teal roof and forge details | 6 × 5 | 7 × 6 / [3, 5] |
| `rootgate` | Root-wrapped civic landmark with a centered sealed entrance | 6 × 6 | 7 × 7 / [3, 6] |
| `expand-bakery` | Plaster and timber, terracotta roof, bread sign | 5 × 5 | 5 × 5 / [2, 4] |
| `expand-greenhouse` | Teal glass frame, glazed roof, planted windows | 5 × 4 | 5 × 4 / [2, 3] |
| `expand-apothecary` | Herb windows, lavender roof and potion-shop details | 6 × 6 | 6 × 6 / [3, 5] |
| `expand-stable` | Wide timber stable with hayloft doors and olive roof | 8 × 6 | 8 × 6 / [4, 5] |
| `expand-guardhouse` | Narrow stone watchhouse, red roof and integrated bell loft | 6 × 8 | 6 × 8 / [3, 7] |
| `expand-bathhouse` | Wide blue-glass facade, pale stone and water motif | 8 × 7 | 8 × 7 / [4, 6] |
| `expand-abandoned-cottage` | Weathered timber, patched shingles and moss accents | 6 × 6 | 6 × 6 / [3, 5] |
| `expand-ruin-cottage` | Old stone cottage with broken, partly mended roof | 6 × 6 | 6 × 6 / [3, 5] |
| `expand-observatory` | Star chamber grown into the roof ridge, violet slate | 7 × 8 | 7 × 8 / [3, 7] |
| `expand-watermill` | Stone and teal timber mill with a facade-mounted wheel | 8 × 7 | 8 × 7 / [4, 6] |
| `expand-moonweaver` | Violet atelier with crescent and textile details | 6 × 7 | 6 × 7 / [3, 6] |
| `expand-teahouse` | Broad jade roof, warm lattice facade and tea sign | 9 × 7 | 9 × 7 / [4, 6] |
| `expand-lighthouse` | Tall beacon house with a glazed lantern integrated into the ridge | 6 × 9 | 6 × 9 / [3, 8] |
| `expand-crystalwright` | Pale stone workshop with a large mint crystal window | 7 × 8 | 7 × 8 / [3, 7] |
| `expand-belltower` | Tall chapel with its bell chamber joined to the gable | 6 × 9 | 6 × 9 / [3, 8] |
| `expand-mushroom-cottage` | Russet cap-shaped shingles over a bright cottage facade | 8 × 7 | 8 × 7 / [4, 6] |

## Source and review workflow

ChatGPT ImageGen sources are preserved individually in [`imagegen-candidates/`](imagegen-candidates/). The observatory
spec uses `expand-observatory-cohesive-source.png`; the earlier perched-tower candidate remains available for
comparison and is not the registered version. Palette ramps, native frames, and door coordinates live in
`pipeline/world/objects/`. Run `scripts/world.sh cut --only <ids>` to fit, harden transparency, lock the palette, lint,
write the runtime image, and make a person-scale review in `Concept/v0.3/world/<id>.png`. This uses the existing cut
pipeline and does not need ComfyUI.

The builder catalog entries and source descriptions live in
[`pipeline/world/expansion/imagegen.json`](../../../pipeline/world/expansion/imagegen.json) and
[`imagegen-sources.json`](../../../pipeline/world/expansion/imagegen-sources.json). The registered builder contact
sheet is [`expansion-imagegen.png`](../../../shots/studio/expansion-imagegen.png). The expanded playable town keeps
the starter square and door but grows to 92 × 64 tiles, with the new services in the east and the weathered homes in
Mossback Row to the south.
