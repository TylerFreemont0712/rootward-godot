# Step 4 — New areas, map growth and world connections

## 1. Three different authoring operations

| Operation | Example | Data affected |
|---|---|---|
| Expand this map | Add 12 columns east of Lanternroot | Existing map ground/bounds and any affected references |
| Add a named district | Call a rectangle “East Meadow” | `places.jsonc` entry for an existing map |
| Create a separate area | Create `east-meadow`, reached by a route | New map file, optional place entry, paired source/destination transitions |

The author chooses the operation explicitly. A district is not a map, and growing town does not automatically create
a district or a new travel connection. Build and Land offer a shared **Areas & map** action; top map picker has a
New area entry after it is implemented. A compact Areas panel lists maps, districts, connection problems and Locate.
Use a dialog or the existing lower shelf for the active operation; do not introduce another permanent side dock.

**Release scope:** finite maps with explicit transitions, authored terrain, named places and safe editor growth.
No infinite terrain, procedural chunk streaming, map stitching without transitions or multi-level terrain in v0.35.

## 2. Core technical gaps to close

- `StudioWork.create_map(id, data)` and `StudioSession.create` already support new-map drafts. Reuse these.
- `StudioWork.resize_plan/resize`, `StudioLand.resize`, `StudioMapSize` already grow/shrink maps and follow incoming
  map links. This is not a blank implementation task.
- Named rectangles live in `places.jsonc`. Schedules are currently `{person: {home:[x,y],work:[x,y],inn:[x,y]}}`
  interpreted on Lanternroot, not arbitrary per-anchor map IDs. Quest step pins use `{map,at}`.
- Existing `StudioDoc.KINDS` has no places/schedules adapter. Add proper documents before editing those files.
- Current map source dimensions are inferred from equal-length ground rows. Never add authoritative width/height
  fields only to satisfy the new UI; runtime derived dimensions already exist.
- Current `_follow` applies incoming-link changes to other sessions. Audit its history and failure behavior before
  treating a resize as atomic. A coordinated transaction is required once more reference types participate.

## 3. W01 — Reference index and document adapters

**Dependencies:** shared transaction contract; reuse schedules adapter from P02 and managed-owner handling from M01.
Suggested NEW pure `game/core/studio/studio_world_refs.gd`; NEW scene `studio_areas_panel.gd`/`studio_area_dialog.gd`
only where required. Keep filesystem scanning in the scene/service layer and pass parsed documents into core.

1. Extend document kinds/writers with places and schedules (or an explicit schema-selected world-document adapter
   with canonical formatting). Preserve header comments, ordering, integer formatting, base hashes and drafts.
   Do not merely stringify arbitrary dicts in a button callback.
2. Load draft-overlaid maps, quests, places and schedules into one index. Also inspect pickups/task/object metadata
   for actual coordinate-bearing fields. Record an inventory of supported reference paths in the ADR/handoff.
3. A reference record contains source document key/path, semantic type, target map ID, coordinate or rectangle,
   action label and stable source identity when available. Do not infer references by finding every numeric pair:
   art dimensions/color values are not coordinates.
4. Index map starts, object `at`/footprints, building doors, warp/building `to.at`, quest step pins, named rectangles,
   Lanternroot schedule home/work/inn, managed structure ownership, managed exits and any concrete additional
   coordinate fields discovered. Object-relative `door`/partition offsets are not shifted on map growth.
5. Classify impact as shifted, unchanged, clipped, off-map, blocked, owner-linked or unknown/unsupported. Any unknown
   coordinate-bearing extension blocks a destructive transform until it has an explicit adapter.
6. Rebuild on document revisions, not each frame. The pure index is deterministic for identical input and is shared
   by resize preview, route validation, map removal safeguards and Publish. Index draft documents before canonical.
7. Extend the world transaction coordinator to include places/schedules/quests alongside map sessions. One Apply
   cannot leave a moved map with unmoved schedule/quest coordinates or half-published place definitions.

**Exit:** a fixture containing every supported reference type produces an explicit impact plan and coordinated
undo/redo/restart. Missing document, parse error or failed draft write produces no partial update.

## 4. W02 — Create a new outdoor area

### Dialog contract

Fields: Name, proposed stable ID, Width, Height, Base terrain, Start cell/facing, optional Music, optional “Name the
whole map as a place.” Defaults: 40 × 30, meadow, start `[2,2]`, facing down, no music override. These are dialog
defaults, not a changed default for existing interior creation. Initial UI bounds: 8–256 on each edge, ≤65,536 cells.
Validate these practical editor limits in performance checks; they are not assertions about engine hard limits.

1. Name is user-facing text. ID follows current `Schema.ID_PATTERN`, `^[a-z0-9]+(?:[.-][a-z0-9]+)*$`:
   lowercase letters/digits, with single hyphen/dot separators and no underscores. Generate a hyphenated slug;
   verify against the actual schema before creation. Show generated ID and allow editing before Create.
2. Validate uniqueness against canonical maps, all new drafts, open sessions and pending creation transactions,
   case-normalized where the filesystem requires it. IDs cannot contain path separators, traversal or extensions.
3. All rows have the same width. Choose a legend character for the selected existing paintable outdoor terrain;
   do not store the UI label as the terrain ID. Base terrain must be walkable for this release's simple empty template.
   Water can be painted later; creating an all-water map with no valid start is rejected.
4. Create raw `{id,name,interior:false,legend,ground,start,facing,objects:[]}` and optional existing music metadata
   using schemas. No fake `width`/`height` source fields, random source tile variation IDs or implicit runtime objects.
5. Show preview dimensions/terrain/start. Create makes a draft through `StudioWork.create_map`, optionally a place
   document change, then opens the map in Land. It creates no canonical file and does not teleport saved characters.
6. Restart discovers the new map and labels it New/unconnected. Area panel offers **Connect to another map** and
   **Locate**. Publish retains the existing disconnected-map warning policy, with a clear explanation of reachability.
7. Revert of an unpublished map first scans inbound links, places and owners. Offer cancel or coordinated revert of
   the dependent draft creation/link actions. Never leave other drafts targeting a nonexistent map.
8. Published-map deletion/rename is not offered in this release. IDs become stable once published; map removal and
   arbitrary content migration require a separate explicitly requested workflow.

**Acceptance:** create, cancel, duplicate ID, invalid ID/size/start, draft restart, optional place, failed creation,
unconnected warning and dependency-safe Revert. Existing room creation continues using its own template.

## 5. W03 — Reference-safe expand/shrink

### Coordinate transform

Use existing edge deltas `left/right/top/bottom`: positive adds cells, negative removes them.

```text
new_width  = old_width  + left + right
new_height = old_height + top  + bottom
shift      = [left, top]
new_cell   = old_cell + shift
```

Preserve cells whose transformed coordinates lie inside the new bounds; new cells use chosen fill terrain.
East/south growth has zero shift for existing cells. West/north growth moves existing cell references with terrain.
Object-local offsets, relative partitions, art anchors and visual texture phase within structures remain unchanged.

### Apply plan

1. Extend `resize_plan`, rather than building a second resizer. Capture immutable before-data for every affected
   document and compute a pure after-world plus impact summary. Preview **Added / Shifted / Cut / Needs relocation**.
2. Shift map objects/start, self-targets and other maps' incoming targets once. Remove old automatic `_follow` side
   effects from this coordinated path or gate them explicitly, so links cannot shift twice during apply/undo.
3. Shift quest pins whose map matches; shift all Lanternroot schedule anchors only when resizing Lanternroot.
   Static NPC object move and corresponding work anchor use the same transform, not two independent deltas.
4. Shift named rectangle x/y by delta, preserving width/height. Clip to new map bounds only when preview explicitly
   approves the resulting smaller rectangle. Fully removed districts require explicit removal in the transaction.
   Overlap policy is W05; growth creates unassigned space until the user extends/adds a district.
5. Shift modular owner object positions and generated interior return destinations; keep room-local layout/furniture
   coordinates unchanged. Never resize a managed interior through generic map resize.
6. Existing map size may offer dropped-object behavior. The safe expansion workflow adds protection: shrinking that
   cuts any person, named/programmed object, building with room, start, arrival/exit, pin or schedule anchor blocks
   Apply until it is relocated/removed by an explicit author edit. Ordinary props may be removed only after an
   impact list and explicit confirmation; one transaction retains their inverse data for undo.
7. A reference landing in water/blocked geometry is invalid even if still in bounds. Revalidate starts, link arrivals,
   schedule anchors and accessible managed entrances on the candidate whole world. Never clamp a door/pin to a random
   nearby cell without showing/accepting its relocation.
8. Camera/editor player follows the transform once. Selection resolves the same surviving SID/structure ID. Keep
   Fill terrain consistent with existing outdoor/indoor restrictions. An error in any adapter cancels the entire plan.
9. Apply/undo/redo/restart/Publish/Revert operate as one world transaction. External modifications to any participating
   file are conflicts, even when the map file itself has not changed.

### Saved character positions

Updating the current editor walker is not enough: older character saves can refer to pre-resize coordinates. Implement
an explicit compatibility path before declaring west/north expansion safe.

- Add optional map `coordinate_revision` (default 0) and an append-only published coordinate-transform ledger for
  each map, validated with content. Proposed separate `map_transforms.jsonc` records `{map,from_revision,to_revision,
  shift,new_size}`; transactions own these changes. Do not rewrite every save during Publish.
- Character state stores map coordinate revision beside its current map/cell; older saves default to 0. On load,
  apply all missing transforms in order exactly once and store the resulting revision on the next normal save.
  Audit actual state field names and loaders before wiring this; the schematic ledger is not an existing API.
- Publish emits one net transition from the last published coordinate system to final edited system, aggregating
  draft growth/undo/redo. Returning to the original coordinates before publishing emits no redundant transform.
  Shrink also requires a revision even with zero shift when saved cells may be cut.
- A saved cell cut by shrink or now blocked is relocated deterministically to nearest valid standing cell by BFS
  in fixed N/E/S/W order, then valid map start. If map/start are unusable, use existing world fallback flow and a
  diagnostic. Preserve inventory, task progress, flags, name and appearance; no reset or save deletion.
- Play draft uses provisional draft transforms in its isolated save context. Publishing/restarting must not apply
  that provisional shift twice. Draft rollback/undo must not write migration state into the player's ordinary saves.
- Ledger history remains available for old saves; no deletion/compaction without a separately designed migration.
  Missing revision chain is a hard content error, not permission to guess the coordinate origin.

**Ledger format to implement (NEW):** top-level `{version:1, maps:{map_id:[transition,...]}}`. Each transition is
`{from_revision:int, to_revision:int, shift:[int,int], old_size:[positive_int,positive_int],
new_size:[positive_int,positive_int]}`. Revisions start at 0, increase by exactly 1 and form one contiguous chain;
`old_size` agrees with the prior `new_size`. The last revision and size agree with published map metadata/rows.
Absence of a map entry means revision 0, not an error for legacy content. Once a map has a ledger, all later
dimension changes append a transition, including east/south growth with zero shift. Non-size geometry edits do not
change coordinate revision; load still validates that a saved cell remains walkable.

Use a NEW optional scalar character-state field `map_coordinate_revision`, default 0, next to the actual existing
map/cell fields after inspecting their names. Transitioning to another map sets this field to the destination's
current revision; it is not a world-global revision counter. A valid original saved cell cut by shrink is seeded
for relocation by clamping its transformed coordinate to the destination bounds, then BFS with fixed N/E/S/W
neighbor order through candidate cells, choosing the first valid standing cell. BFS here searches grid coordinates,
not only reachable floor, so it can find a fallback even if the seed is in a wall/water cell. No available cell is
a world error. Record the recovery reason; preserve the original save until normal successful save completes.

**Acceptance matrix:** grow/shrink each edge; combined edges; no-op; inbound/self links; all reference types; partial
district clip; protected-object cut; read/write failures; stale plan; coordinated undo from another participating
document; old/current save revisions; multiple published transforms; shrink relocation; Play draft isolation.

## 6. W04 — Paired outdoor routes

Use two ordinary `kind:warp` objects. A route connects **departure cell + separate arrival cell** on each map:

```text
Map A departure warp → Map B arrival cell (facing inward)
Map B departure warp → Map A arrival cell (facing inward)
```

Departure and arrival cannot be the same cell on either map. This avoids immediate bounce loops. This release uses
explicit one-cell route markers on walkable ground; edge-wide border transitions are a later convenience feature.

1. **Connect areas** chooses source map/departure/arrival, destination map/departure/arrival and facings. Default
   arrival is one cell inward if valid, but the preview must show and allow moving it. Validate both complete sides.
2. Reuse `StudioLink` validation for destinations and map rules for departures. Reject off-map, water/solid, occupied
   transition, overlap with protected start/entrance and arrival-trigger loop. Arrows/labels preview both directions.
3. Add optional stable **`route_id`** to warp schema, shared by the two route objects; index it world-wide. Generate
   it at application layer; reject duplicate route members, dangling halves and same-map self-pairs for this tool.
   Existing one-way warps without route IDs remain valid.
4. Commit both objects as one transaction. Failure creates neither. Change/remove paired route acts on both sides
   with a clear impact summary; one-sided changes require explicit conversion to two independent one-way links.
5. Appearance is an optional existing sign/path decoration, not part of warp collision or a newly generated object
   asset requirement. Markers are clear in Edit; in Play the scene/path should indicate travel without debug arrows.
6. Area list shows connected maps, unpaired route problems and Locate each departure/arrival. A small graph may
   display map nodes and links, but a fancy draggable graph is not a prerequisite for connecting two areas.
7. Reachability from starting world map is a graph check. Report unreachable maps, but allow intentional one-way
   links where current Publish policy permits; do not silently create reverse routes for all old entrances.

**Exit:** walk A→B and B→A with correct facings; no bounce; restart/publish retain route identity; resize shifts the
right endpoints; undo/delete/conflict cannot leave a half route.

## 7. W05 — Named districts inside a map

1. Areas → Districts lists current map's `places.jsonc` entries with ID, label, bounds and Locate.
2. Add rectangle previews a snapped area even over objects. Input is map cell rectangle, not object selection;
   existing Props/Trees area-selection mode must not start accidentally. Release previews; name/ID + Apply commits.
3. Require nonempty in-bounds rectangle, unique place ID within map, and a nonempty label. Existing places have
   rectangular x/y/w/h; preserve that schema. New authoring rejects overlap with another named district in the
   same map to avoid ambiguous runtime place lookup. Existing overlapping content is diagnosed without auto-rewrite.
4. Rename changes label only; stable place ID remains. Resize/move requires the same validation. Remove warns if
   any actual content references its ID; inspect callers before claiming no dependencies. Full map coverage is
   optional for new areas; unassigned terrain displays map name. No automatic split/retile of all town districts.
5. Update minimap/full-map/place labels and any runtime place lookup through draft content reload. Test English/
   Japanese fallback: authored names display faithfully while built-in translated names keep existing behavior.
6. Keep district editing in world transaction/document history, not transient scene rectangles. New map creation's
   optional full-map place is produced by this same model/writer.

## 8. W06 — Content/save compatibility and Publish hardening

1. Full-world validation includes new maps, route pairs, supported references, places, schedules, structure owners,
   generated interiors and coordinate ledger. Use structured problems to jump to exact map/cell/document.
2. Expand review summaries: files created/changed, cells added/cut, objects removed, refs shifted, place changes,
   routes paired/removed, coordinate revision changes and any unreachable areas. Never hide non-map file changes.
3. A source conflict in schedules, places, quests or ledger blocks the coordinated group until resolved. Recheck
   all hashes after review and before canonical writes. Include new map file collisions created by external tools.
4. Backup/atomic group recovery covers new files as well as replacements. Rollback removes only newly created
   files owned by the failed transaction; it must never delete an external file that appeared meanwhile.
5. Existing saves, room links, town quests and coding tasks continue. Expanding the map does not auto-create new
   quests, NPCs, schedules or procedural terrain content. Authoring those is a later explicit task.
6. Keep unsupported global NPC schedules out of UI. Read-only schedule summaries and correct Lanternroot anchors
   are sufficient here; cross-map timed pathfinding requires its own data/runtime design.

## 9. W07 — Acceptance story and evidence

Use delivery checklist D with an isolated town fixture and two character saves (old and current coordinate revisions).
Pure reference-transform tests cover every registered path; scene tests exercise real dialogs/map picker and routes;
publish fault-injection covers cross-file recovery. New tests mirror actual added source files.

Native screenshots: new-area preview, expanded-map impact list, named district bounds, two-way route markers and
Play arrival in the new meadow. Record creation/resize preview/apply timings at 80×56 and 256×256 with representative
objects/references. The design should rebuild relevant maps/indexes on change, not scan every source file per frame.

Final evidence must include actual published reload without draft overlay and old-save recovery. Merely observing
the editor walker move after resize does not prove map expansion preserves the world.
