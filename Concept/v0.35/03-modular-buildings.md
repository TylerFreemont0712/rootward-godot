# Step 3 — Modular buildings, rooms and roofs

## 1. Product contract and boundaries

The author draws a building rectangle; the editor assembles its exterior walls and roof from fitted modules.
They can change its materials/dimensions, create its separate interior map, draw internal partitions, add internal
doorways, paint floors, furnish it and enter/leave in Play. Enlarging a building adds modules rather than stretching
one house picture. Roofs cover exterior buildings; the separate interior has no roof obstructing play.

**First release decisions:**

- One rectangular shell per building, one story, integer width/depth, one south-facing exterior entrance.
- Shell width 4–24 and depth 4–20 cells are editor/product limits for this first tool, not global map limits.
  These sizes are testable bounds; raising them later requires performance and art checks, not a new data format.
- Flat roof or gabled roof with east–west ridge. Even/odd depths have explicit renderer rules below.
- Interior usable grid is width × depth; internal walls occupy cells. Internal doorways are walkable cells with
  decorative doorframe art. They do not warp and have no lock/program system in this release.
- Interior and exterior are deliberately different projections. One exterior footprint cell is not an edge-based
  interior physics primitive. Keep the existing cell collision system; do not introduce half-cell movement.
- No arbitrary roof meshes, extra floors, stairs, rotated whole houses, L-shaped shells, holes or courtyards yet.
  Do not implement those halfway or expose controls that cannot produce valid collision/roof topology.

This is real modular construction within a bounded grammar. Existing sprite buildings remain fully supported.

## 2. Proposed data contract — implement schemas before writers

All new fields below are **proposed**, not existing APIs. Add optional fields without changing legacy behavior.
Use a normal map `building` object with optional `structure`. Existing `art` remains a required fallback identifier.
The material definition supplies its fallback building art; new structure placement uses an existing valid art ID.
The example below uses `home`; verify that ID against the loaded catalog when creating a material pack.

```json
{
  "kind": "building",
  "art": "home",
  "at": [12, 10],
  "size": [8, 6],
  "door": [3, 5],
  "name": "Meadow cottage",
  "structure": {
    "version": 1,
    "id": "structure-meadow-cottage-001",
    "wall_material": "timber-cream",
    "roof_material": "warm-shingle",
    "roof_style": "gable",
    "floor_material": "floor",
    "interior_map": "meadow-cottage-room",
    "layout": {
      "walls": [[4, 0], [4, 1], [4, 2], [4, 3], [4, 4], [4, 5]],
      "doors": [[4, 3]]
    }
  },
  "to": {"map": "meadow-cottage-room", "at": [4, 7], "facing": "up"}
}
```

### Field rules

| Field | Contract |
|---|---|
| `at`, `size`, `door` | Existing top-left footprint, dimensions and south-row door offset. New modular doors require `1 <= door.x <= width-2` and `door.y = depth-1` to preserve corner modules. These remain authoritative; do not duplicate dimensions in `structure` |
| `structure.version` | Exactly 1 for this format; unknown future versions preserve raw data, report unsupported structure and prohibit destructive edits |
| `structure.id` | Stable world-unique author ID, generated on placement/duplication and persisted. Not a SID, art ID or room filename |
| Material IDs | Resolve through new material content described below; invalid IDs are diagnostics and draw fallbacks |
| `roof_style` | `flat` or `gable`; fixed ridge orientation in version 1 |
| `floor_material` | Paintable indoor terrain kind, not an image filename |
| `interior_map` | Optional owned interior-map ID; absent until explicitly generated. Must agree with managed door link |
| `layout.walls` | Unique local `[x,y]` cells, 0 ≤ x < width and 0 ≤ y < depth, sorted y then x on serialization |
| `layout.doors` | Unique subset of wall cells, same ordering; these cells become walkable internal openings |
| `to` | Existing runtime entrance target. A managed interior compiler derives it. A manual external target cannot also claim owned interior metadata |

Use an explicit schema, not `type: any` for the structure. Default absent layout to empty lists. Missing structure
means legacy behavior. New modular objects must not receive `art_size`/`art_shape` from the sprite-resize path.
Compiler collision and render parts are derived, not serialized as another source of truth.

The stable ID exists because source objects have no persistent SIDs. Any ID creation or collision suffix selection
occurs at the application layer against all source+draft maps; the pure compiler only validates the supplied ID.
Copying a modular building assigns a new ID and drops its `interior_map`/`to` ownership link by default, while
copying the layout/material choices. An explicit later “duplicate with furnished room” feature is outside this scope.

## 3. Pure compilation contract

NEW suggested files:

- `game/core/overworld/overworld_structure.gd`: pure validation and compilation used by both Play and Studio.
- `game/core/studio/studio_structure.gd`: edit plans, dimension changes, room projection and impact summaries.
- `game/scenes/overworld/structure_view.gd`: drawing compiled parts, with no topology decisions.
- `game/scenes/studio/studio_build_tool.gd`: shell/partition previews and input dispatch.
- `game/content/packs/core/overworld/build_materials.jsonc`: material definitions and module manifest.

Suggested compiler interface (NEW; adapt style to actual core conventions):

```text
compile(raw_building, material_catalog) -> {
  ok, problems,
  footprint, door_cell, exterior_arrival,
  solid_cells, render_parts, visual_bounds,
  interior_projection
}
```

Input dictionaries must remain unchanged. Output ordering is deterministic. No Nodes, file loads, generated IDs,
mutable global cache or unseeded randomness belongs in this compiler. Cache compiled results outside it by raw
structure/material revision; invalidate only affected buildings.

### Exterior collision and openings

1. Validate dimensions/door/material/layout/ID before any expansion. On failure, return structured problems with
   object index/stable structure ID/local cell. Do not silently clamp source data during load.
2. All width × depth footprint cells are blocked except the one exterior door cell **when it has a valid link**,
   matching existing building entry behavior. This deliberately conservative mask avoids walking through a house.
3. Feed derived local `solid_cells` into the existing building collision builder without writing it into raw content.
   Preserve collision priority and portal trigger behavior; validate that one open door still emits one warp target.
4. Exterior arrival when leaving is `at + door + [0,1]`. Reject new placement/resize when it is off-map, blocked by
   another object, impassable terrain or another transition. Existing bad content remains inspectable and diagnosed.
5. Render overhang never adds collision. Footprint fit includes blocked cells plus required arrival; visual-bounds
   preview additionally shows roof overhang so an author can avoid ugly overlaps without blocking valid floor cells.

### Exterior modules and roof algorithm

Use 40px world-cell sockets before integer scaling. Materials declare module canvas dimensions, anchor and clip
rect; images may extend above their anchor but each module has explicit art bounds. Do not scale arbitrary image
sizes to guess a camera angle. The compiler emits ordered `{module_id, local_cell, pixel_offset, draw_band, variant}`
parts; renderer resolves texture/fallback. All variants share identical socket/edge pixels.

1. For each footprint boundary emit one wall module per perimeter cell with a side/corner role. Corners have one
   explicit combined role so shared corner cells do not draw two opaque wall caps. Draw south-facing facade art,
   side faces and north rear caps according to the material's fixed projection. Door replaces the facade module at
   `(door.x, depth-1)`, including a closed version when unlinked. Never overlay a wall across the door aperture.
2. Roof coverage is a rectangular **render grid** from local x=-1..width and y=-1..depth, inclusive (one-cell overhang).
   It is separate from the physical footprint. Give every roof grid cell N/E/S/W coverage bits with the same
   1/2/4/8 convention. For a rectangle the inside, edge and corner roles follow directly from the missing neighbors.
3. Flat roofs select a matching fill/edge/corner role. There is no tile border painted through a connected interior.
   Preserve a single aligned texture phase across the whole roof; vary only bounded interior detail.
4. Gabled roofs use two visible slope bands and an east–west ridge. Let total render rows be R=depth+2.
   If R is odd, the middle row is the ridge module and rows above/below are north/south slopes. If R is even, the
   ridge lies between the two middle rows; use paired north-ridge/south-ridge modules with an exact shared seam.
   Outer x edges choose gable-end versions; outer y edges choose eaves. Corners have explicit eave+gable modules.
   UV/material phase is building-local and stays consistent across rows. Do not apply terrain's dual-grid masks
   blindly: roofs use their own declared sockets and coverage grid.
5. Resolve a module ID from `(roof_style, slope_band, edge_role, ridge_role)`, never from a filename heuristic.
   A content manifest must declare all required combinations. Incomplete material packs are unavailable for new
   placement but still have fallback rendering when encountered in old drafts/content.
6. Deterministic visual variants use stable structure ID + local cell + material, independent of gameplay RNG and
   unrelated map resizing. Wall corners, door sockets, ridge/eave seams and outlines remain invariant.
7. Draw bands: ground shadow/base, wall/facade, roof. Sort buildings against characters using the established
   `TownMapView`/`PixelView` rules, accounting for module bounds. Do not give each module an independent actor-sort
   depth that causes roof tiles to interleave with the player. Validate occlusion both behind and in front of it.
8. Provide an Edit-only roof visibility toggle (Show roof / Reveal shell) and selected-building translucency.
   Play uses the exterior roof normally. Separate interior maps have neither exterior wall nor roof parts.

This algorithm must produce complete roofs for 4×4, 5×5, 8×6, 9×7, 24×20. If the art pack cannot satisfy any
combination, fix the manifest/modules or keep the incomplete material unavailable; do not cover seams with blur.

## 4. Material/art contract

`build_materials.jsonc` is a proposed dedicated content section loaded and validated alongside the overworld catalog.
Specify wall and roof records with ID, translated label, compatible styles, module manifest, pixel anchors, palette
reference and fallback art. Floor choices reference existing indoor terrain. Material metadata is canonical content;
authoring the map only stores material IDs, not PNG paths or copied module definitions.

### Exact manifest shape for Luna

The top-level object has `version:1`, `walls:{id:wall_record}`, `roofs:{id:roof_record}` and
`modules:{module_id:module_record}`. IDs are content IDs. A module record contains `texture` (resource path),
`region:[x,y,w,h]` (nonnegative integer atlas rect), `anchor:[x,y]` (integer pixels relative to that region), and
optional `variants` (same-shaped region rectangles). All referenced regions must fit the loaded texture when it
exists. A missing texture is a warning; invalid/empty dimensions are an error. Default variants to the base region.

A wall record contains `label`, `fallback_art`, `roles` and `interior_roles`. A roof record contains `label`,
`styles` (nonempty subset of flat/gable) and `roles`. Every role value is an existing module ID. Role keys:

- Wall: `north`, `east`, `south`, `west`, `north_west`, `north_east`, `south_west`, `south_east`,
  `south_door_open`, `south_door_closed`. Classify corners before sides so each perimeter cell is emitted once.
- Interior: `wall_0` through `wall_15` for all four-neighbor wall masks, plus `door_ns` and `door_ew`.
  A doorway with north/south wall neighbors uses `door_ns`; east/west neighbors uses `door_ew`.
- Roof role key is `style/band/edge`, with band `flat` for flat roofs or
  `north_slope|south_slope|ridge|north_ridge|south_ridge` for gable. Edge is
  `inside|north|east|south|west|north_west|north_east|south_west|south_east` from the roof coverage rectangle.
  Only combinations reachable for supported sizes are required: generate the required set by compiling every
  allowed width/depth with symbolic roles, then check set inclusion in the manifest. Reject unused typo keys with
  a diagnostic. Do not require impossible corner/ridge combinations or silently substitute one band for another.

At draw time the module's anchor is placed at its compiled local cell's 40px grid origin plus `pixel_offset`.
Atlas `region` sizes can exceed 40px for wall height; socket pitch stays 40. Prototype with anchors `[0,0]` and
explicit negative-y offsets, then keep the agreed camera dimensions in the complete material pack. A production
pack's exact numeric art bounds belong in this manifest, never hardcoded by its material name in GDScript.

Required first complete set: one cream/timber wall pack, one warm shingle roof pack supporting flat and gable,
one existing floor surface, a south door/closed-door pair and interior wall/doorframe modules. A second material is
only considered done if it meets the same complete topology manifest; a recolored preview is not another system.

Art production sequence:

1. Establish exact camera, 40px sockets, silhouette, palette, wall height and overhang on a deterministic blockout.
   Compare to accepted existing house/fence/people art at native scale before requesting any new bitmap.
2. If additional textures/painted modules are needed, use ChatGPT ImageGen for a matching material/reference sheet.
   Preserve source, prompt and provenance in a new `Concept/v0.35/art-source/` folder only when actual art is made.
3. Crop/fit modules through a deterministic pipeline. Keep module sockets, alpha outlines, perspective and seams
   exact. ImageGen is not responsible for algorithmically correct atlas coordinates or collision masks.
4. Use a shared material phase/edge collar so adjacent modules join, including odd/even ridges. Keep edge pixels
   identical across variants. No soft alpha fringe, texture filtering or camera mismatch introduced by import.
5. Generate a contact sheet and adjacency fixtures at native and enlarged integer scale. Inspect on grass, meadow,
   dirt and indoor floor. Check unobstructed south door, characters at front/back and module joins against the grid.
6. Prefer extending the existing world/pixel pipeline to a separate modular target. Do not run full regeneration of
   existing building/prop assets or replace the accepted terrain sources while implementing this pack.

Missing textures draw module-shaped neutral placeholders with correct silhouette/collision and a diagnostic. Missing
art alone is a warning; invalid geometry, ID/ownership or door connectivity is an error. Final visual acceptance
requires the complete first material, even though development builds can operate with placeholders.

## 5. Managed interiors — authoritative ownership

Interior creation is explicit, not automatic on every shell placement. Creating it produces an ordinary map
with optional NEW header:

```json
{
  "managed_structure": {
    "version": 1,
    "owner_map": "lanternroot",
    "owner_structure": "structure-meadow-cottage-001",
    "floor_legend": {"f": "floor"},
    "floor_rows": [
      "ffffffff", "ffffffff", "ffffffff",
      "ffffffff", "ffffffff", "ffffffff"
    ]
  }
}
```

This fragment is only the additional header, not a complete map. It uses a stable owner ID, never a SID.
Ownership is one-to-one and validated against the full source+draft world. An interior without that header is a
legacy room: do not take it over merely because an exterior door links to it.

The complete header schema requires version, owner map/ID and the floor payload. For the example, floor rows are
8×6, while full map ground is 10×9. The map's normal legend and managed floor legend are independent character
encodings; resolve terrain IDs before combining them. Every floor payload terrain must be an existing walkable
indoor surface. Ground snapshots use their own canonical legend allocation, never blindly copy character codes.

### Projection and generated fields

For exterior width W/depth D, managed interior dimensions are `(W+2, D+3)`. Usable local `(x,y)` maps to `(x+1,y+2)`:
top two rows are wall art/collision, left/right borders are wall cells, bottom row is wall except the exit doormat.
The usable rectangle spans x=1..W and y=2..D+1. Ground values reference existing wall/floor/void terrain definitions.

- Interior exit warp: `[door.x+1, D+2]`; arrival/start above it: `[door.x+1, D+1]`, facing up when entering.
- Return warp target is the exterior arrival `at+door+[0,1]`, facing down. Arriving inside must not land on the warp.
- `layout.walls` compiles to `wall` ground in usable cells; `layout.doors` overrides those cells to the selected floor
  and emits a nonsolid decorative frame through the managed renderer. No warp or program on an internal doorway.
- Reject any partition that blocks the inside arrival cell or all paths from an internal doorway to the entrance.
  Flood fill the usable floor from arrival; every remaining usable floor cell must be reachable. Small sealed
  nonwalkable wall closets are allowed; unreachable walkable rooms require an internal doorway before commit.
- **Structure owns:** shell geometry, partition wall/door cells, material choices, door-derived arrival/exit, managed
  frame rendering. **Interior map owns:** furniture/props, ordinary events, and per-cell floor paint on usable floor.
- Do not serialize generated wall/doorframe objects as ordinary user furniture. Render them from the owned layout.
  Reserve the generated exit warp via managed metadata plus its exact expected source position; preserve legacy
  source object format. Detect unexpected duplicate/moved exits as errors, not by guessing which warp to overwrite.
- Apply managed wall mask over stored floor paints at compilation. Preserve the underlying floor terrain per cell
  so removing a partition restores its previous floor. Persist a NEW managed `floor_rows` + `floor_legend` payload
  covering only the W×D usable grid; it is authoritative for floor paint. Generated full `ground` remains the
  compatible derived map snapshot. Validate snapshot agrees with the compiler; regenerate only on explicit edits,
  never silently rewrite canonical content during load. Floor paint commands update the payload and snapshot together.

The interior compiler must live in pure core so Studio preview, Play draft and published runtime agree. Extend
`OverworldContent.map_schema`, `OverworldMap.build` and JSONC round-trip handling for both optional fields before
the editor writes them. The stored snapshot supports inspection/fallback; it is not a second editable wall model.

### Partition editing

- Inside a managed room, Build offers Partition line, Room rectangle, Internal doorway, Remove partition and Floor.
  Coordinates shown to authors are map cells; tools convert to local usable cells explicitly.
- Line is dominant-axis; rectangle adds perimeter wall cells in the usable grid, unioning shared cells exactly once.
  Preview includes reachability failures. A newly enclosed room without a doorway is an invalid intermediate preview.
  Provide a pending doorway marker in the same room gesture before Apply, or let the author create opening(s) in
  the preview. Do not force committing invalid world state in order to add the door on a second click.
- Doorway toggles a cell already in `walls`; removing a wall removes its doorway entry too. An isolated door on
  ordinary floor is rejected. Corner doorway art is unsupported: require two opposite wall neighbors in one axis.
- A whole rectangle/line+opening gesture is one history action. Escape cancels the full pending plan. Reachability,
  fit, protected exit/arrival and furniture conflict checks run on final preview and again before apply.
- Existing furniture is never silently removed. Show every conflict; user can cancel and move furniture first.

### Resize, movement, ownership and detach

1. Modular dimensions rebuild modules and interior geometry; never scale `art_shape`. Keep local top-left fixed
   for v1 numeric/handle resizing. Moving the building changes `at`, not interior local layout or furniture.
2. Preserve door x when valid; if width reduction cuts it or makes it a corner, preview the proposed clamp into
   `[1, new_width-2]` explicitly and update both
   sides in the same transaction. Keep it on y=depth-1. Show all arrival changes before Apply.
3. Resize the usable floor payload anchored at local (0,0); extend with chosen `floor_material`. Retain surviving
   floor paint, partitions and furniture. Newly cut walls/door entries are listed; out-of-bounds furniture, NPCs,
   external quest pins or other references **block** shrink until relocated/removed explicitly.
4. Rebuild ground, bounds, start, managed exit and exterior target together. Reference index from step 4 is reusable;
   before it exists, M05 must at least scan all map links and quest pins and reject unsupported affected references.
   No automatic deletion of contents to make a resize succeed.
5. Interior and owner changes use the guide's world transaction contract with one undo/redo. Failed compile or
   conflict leaves both drafts untouched. Restart recovers ownership and pending draft groups without duplicate rooms.
6. Generic Land resize and raw wall paint are disabled for a managed interior; point to owner dimensions/partition
   tools. Ordinary floor paint is allowed through the managed floor command. Inspector cannot edit ownership IDs.
7. Deleting owner shell warns that its room becomes orphaned, keeps the room draft/content, and unsets active
   ownership with an explicit coordinated plan. Do not erase furniture or silently attach another building.
8. **Detach interior** is an explicit confirmed command: bake its current ground/frames into ordinary legacy map
   data, remove managed header, preserve furniture, exit and source door link, and remove owner `interior_map`.
   The shell keeps its independent layout/materials; later changes do not regenerate this room. All changes are
   undoable together. Detach is the route to manual legacy editing, not an implicit fallback on validation failure.

## 6. Implementation packets

### M01 — Contracts, schemas and pure fixtures

1. Write a proposed ADR covering optional structure metadata, stable IDs, rectangular v1 scope, material sockets,
   managed interior ownership and derived snapshots. Read current schema handling for unknown fields first.
2. Add optional schemas/material loader, writer round trips and diagnostics without creating any source buildings.
3. Establish shared transaction support from guide §5; reuse P02's adapters if already implemented.
4. Add valid legacy/new examples and invalid dimensions, door, materials, ID, ownership, wall/door lists and
   unsupported versions. Prove legacy maps compile identically and reading/writing preserves comment headers.

**Exit:** schemas and pure validation work; no enabled modular UI yet.

### M02 — Compiler and renderer with placeholders

1. Implement exterior topology, collision, roof roles and visual bounds as specified. Compile representative sizes.
2. Integrate through `OverworldMap.build` and `TownMapView`/`PixelView`, sharing the same data for preview and Play.
3. Implement deterministic fallback modules. Show roof/hide roof overlay in Edit; collision remains unchanged.
4. Validate odd/even roof rows, closed/open door, occlusion and cache invalidation on dimension/material edits.

**Exit:** hand-authored fixture structure plays correctly; resizing demonstrably changes module count rather than
stretching one sprite. Missing textures still launch. Do not call final art done at this stage.

### M03 — Draw shell and edit dimensions/materials

1. Add Draw building in Build. Pointer down anchors top-left candidate; drag rectangle snaps to cells; reverse
   dragging normalizes min/max coordinates. Show width/depth, footprint, overhang and arrival validity.
2. Supply pending name/material/roof choices and door position in the preview. Minimum sizes explain invalid state.
3. Apply creates one building/stable ID/history action only if fit and landing checks pass. Escape/tab change cancels.
4. Selection uses normal building pick/drag. Inspector edits structure through dedicated plans, not generic key sets
   that can bypass validation. Legacy resize remains untouched. Unsupported roof styles are never offered.

**Exit:** build, move, change materials, resize, undo/redo, duplicate with fresh ID and restart all work before rooms.

### M04 — Owned room creation and rendering

1. Add explicit Make managed interior; compile the projection/floor payload/header/paired links above.
2. Create/open it through current new-map sessions and picker; enlist both maps in a coordinated draft action.
3. Use owned layout for walls/frames and existing ground+props for everything else. Back outside follows stable owner.
4. Validate ownership, generated exit and source link on load/Publish. A legacy linked room offers Open, not takeover.

**Exit:** new empty managed room can be entered/exited after reload and isolated Publish; invalid ownership is diagnosed.

### M05 — Partition, floor and synchronized resize

1. Implement preview-only line/room/door tools with pending opening support and reachability checks.
2. Add managed floor edits and protected generated-cell behavior. Keep furniture placements under existing commands.
3. Implement synchronized dimension and door changes, impact preview and blocking conflicts; coordinate undo/reload.
4. Add detach/owner-delete handling and orphan diagnosis; never delete contents implicitly.

**Exit:** two furnished connected rooms survive shell enlargement, floor edits, undo/redo, restart and Publish.

### M06 — First complete production art pack

Implement the material/art contract in §4, preserving exact module joins and camera. Keep prompts/source crops and
deterministic fitting recipes. Validate every required role at all representative sizes before exposing the material.
This packet is complete only with native screenshot review of a finished exterior, not just an atlas/contact sheet.

### M07 — Publish, compatibility and recovery

1. Add live/Publish structured problems for structure schema, unknown material, invalid entrance, duplicate stable
   ID, ownership mismatch, snapshot mismatch, unreachable room and missing modules.
2. Hard errors stop Publish. Missing optional art warns and falls back; rejected structures remain inspectable.
3. Exercise draft transaction fault injection, canonical group-write recovery, conflicts, undo dependencies and
   Revert across owner/room/material changes. New material files must exist before publishing their first use.
4. Verify old home/inn/buildings, legacy rooms, furniture, programmed gates, terrain, learning tasks and saves retain
   behavior. Do not auto-convert existing town buildings to structures.

### M08 — End-to-end acceptance and evidence

Required new pure/scene suites mirror `overworld_structure`, `studio_structure`, the Build tool and world transaction
service. Required matrices:

- All dimensions at boundary values, odd/even gables, flat roof, camera pan/zoom, roof reveal and missing material.
- Whole perimeter/corners/eaves/ridges; no opaque seams, missing caps, doubled outlines or stretched door art.
- Door link/unlink/slide, blocked/off-map arrival, shell move, duplicate IDs and duplicate ownership rejection.
- Partition line/rectangle/shared wall/door, cancelled pending doorway, invalid sealed room, furniture conflicts.
- Floor paint retained under removed walls, grow/shrink with floor/partition preservation, reference blocking.
- Undo/redo after map switches; restart; source conflict; failure after first staged/apply/publish write; detach.
- Same generated geometry and collision from preview, Play draft and published reload.

Evidence: native exterior at two sizes with facade/ridge close-ups, two-room furnished interior, roof reveal,
collision/arrival overlay, plus delivery checklist C. Record timings for a fixture with 100 visible 8×6 structures
and for dragging one structure's resize ghost; only changed structures should recompile. Report machine/timings and
compare to baseline rather than asserting a universal FPS guarantee.

## 7. Extension contract after v1

Future irregular shells add a new explicit shape/version: local occupied-cell rows, one connected component,
no holes initially, derived perimeter edges and concave corner roles. Roofs then need ridge/valley decomposition
or an explicit roof-section authoring tool; rectangular roof logic must not pretend to support L shapes.
Multiple exterior doors need stable per-door IDs and independent return links. Multiple floors need level-indexed
collision/occlusion and stairs, coordinated with old S10. Keep current `version:1` readable and never reinterpret it.
These are later implementation projects, not unchecked surprises hidden in M08.
