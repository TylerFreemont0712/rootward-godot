# Step 2 — Build workspace with current assets

## 1. Scope

Build is the practical construction workflow using capabilities already present: whole buildings, size handles,
wall/fence/gate placement, interior creation and furniture. Step 3 adds modular shell/roof construction after this
workspace is stable. Keep these two implementation stages distinguishable in handoffs and completion claims.

The lower shelf offers **Buildings | Boundaries | Gates | Floors & furniture**. It uses the shared 300px shelf with
two complete card rows, search, previews and scrolling. A secondary tool strip above the cards holds relevant
actions; it must fit inside that shelf. The main world viewport and inspector retain their existing positions.

### Author flows

1. Buildings → choose existing cottage → place → change width/depth → Make interior → Open room → furnish.
2. Boundaries → choose timber fence → drag line → add crossing → Gates → insert matching gate → test opening.
3. Map size → existing four-edge resize dialog → review fill and impacts → Apply or Cancel.
4. Once step 3 is ready, Buildings offers **Draw building** alongside whole-building cards, with its own ghost.

## 2. B01 — Catalog scoping and workspace mounting

**Prerequisite:** P06. **Files:** `studio.gd`, `studio_top_bar.gd`, `studio_place_panel.gd`, `studio_tools.gd`,
`studio_catalog_filter.gd`, catalog schema/data if needed. NEW `game/scenes/studio/studio_build_panel.gd` only if a
thin wrapper is cleaner than configuring the existing catalog; do not copy the card grid implementation.

1. Inventory current catalog categories/subcategories and template kinds. Write a fixture for classification before
   coding. Buildings are `kind: building`; boundaries/gates need explicit existing family/category metadata.
   Never classify by searching names for “wall,” “door” or “house.”
2. Add a caller-supplied scope to catalog filtering, applied before category/search/Recent/On this map. A scoped
   Recent list must not leak unrelated trees/people into Build. Asset IDs and cards remain canonical shared entries.
3. Reuse existing category metadata where complete. If ambiguous, add optional catalog **`build_group`** enum
   `building|boundary|gate|furniture|floor` in schema/core loader/Studio validation before using it. Unset entries
   remain visible in Objects; curate only construction entries. No new required field on legacy content.
4. Add Build routing and mount its tool strip and shared grid. Preserve Objects search/scroll independently from
   Build. An asset can appear in both workspaces without cloning its definition or generation queue entry.
5. Floors & furniture uses existing indoor props and the existing Land floor surface action. Separate “Paint floor”
   (changes room ground) from rug/furniture cards (places objects). Floor painting reuses land commands/gestures.
6. Objects remains the unrestricted catalog for compatibility. New construction UI is the recommended route; do not
   remove old placed objects or prevent the inspector from reading them.

**Exit:** Build is enabled, scoped views are useful and stable, two rows fit, and no persistence changed just from filtering.

## 3. B02 — Existing buildings and resize contract

1. Whole-building placement reuses `StudioMode.start_place`, `StudioArrange` and current fit/ghost commands.
2. Inspector exposes width/depth, current door cell, Original size, interior/target status and Make/Open interior.
   Show dimensions as ground cells; display world pixel size as optional secondary text, not the unit users edit.
3. Size changes route to `StudioWork.resize_object`. Keep ADR-0076 art/collision baselines (`art_size`, `art_shape`),
   masks, gate frames and return links. Do not repeatedly scale already-scaled data or overwrite source PNGs.
4. Interactive handles preview only until release. Escape restores pre-drag size. Repeated numeric edits commit on
   Enter/focus-exit as one meaningful field edit, not every keystroke. Reject invalid/infinite/non-integer dimensions.
5. Re-run fit against final footprint, collision and exterior door landing cell. Unrelated nearby decorative overlaps
   follow existing policy; a valid linked entrance must not end up off-map or blocked without a precise diagnostic.
6. A generated modular building later uses M03 dimension editing, not `resize_object`'s image scaling. Dispatch by
   its explicit optional structure metadata; never guess from its art ID or dimensions.
7. Moving/duplicating/deleting remains current Arrange behavior. A copied legacy building must not accidentally
   claim ownership of the original room; preserve current copy/link semantics and explain destination sharing if kept.

**Exit:** existing buildings still look/behave as before, and editing through Build produces the same raw data as
the same operation in Objects. Screenshot small/large buildings with doors and collision overlays.

## 4. B03 — Boundaries and gates

### Gesture contract

- Click places one segment. Drag draws the current dominant-axis straight stroke. R flips supported axes using
  the existing boundary controller; do not invent diagonal fences or a different rotation meaning.
- Ghost shows every proposed segment, affected neighboring joins, blocked cells and replacements before release.
- One release commits one command batch. Cancel commits nothing. Repainting an identical line is a no-op.
- Timber joined fences use current N=1/E=2/S=4/W=8 connectivity. Different material groups do not join.
- Materials with only a horizontal/vertical art pair remain straight-line tools. Explicitly selected corner art can
  be placed manually; do not claim automatic corner/tee coverage for an incomplete family.

### Implementation

1. Reuse `StudioBoundary.supported`, `group`, `gate_fits`, and `StudioWork.boundary_plan` / `place_boundary`.
   Ensure a Build card retains catalog `line`, join family, connections and gate metadata through template creation.
2. Preview and apply must consume the same pure plan. Neighbor changes are part of the same history entry.
   Refresh one-cell topology halo after add/delete/undo; wide gates require their entire footprint/socket halo.
3. Gate replacement only replaces compatible straight segments of the same join family. Reject corners/tees,
   incompatible material, named/programmed objects, people and overlap with unrelated solid props.
4. Preserve gate `id`, `program`, `opens`, collision state and animation metadata. Placing a decorative gate does
   not invent an unlock condition or coding task. Existing programmed gates keep their original behavior.
5. A material with no suitable gate displays “No matching gate” and offers other available materials. Do not create
   visually mismatched connection sockets just because another gate fits its bounding box.
6. Add/remove fence next to an existing gate must not erase or replace that gate. Wide gates attach at declared
   sockets, not every occupied cell. Shared preview/render/collision must agree after Publish/reload.

**Acceptance:** straight, end, corner, tee, cross, deletion reconnect, axis rotation, gate replacement, wide gate,
mixed material, named-object protection, blocked stroke, no-op repaint and undo/redo. Existing family variants with
`[`/`]` remain usable and preserve footprint/door state through current variant rules.

## 5. B04 — Rooms and furnishing

1. Reuse P04 for Make/Open interior; a linked exterior never creates another room unless explicitly unlinked first.
2. Open room switches map, retains Build tab and selects Floors & furniture. **Back outside** remembers building
   identity and source map for this navigation session; fall back to arrival marker if the building was removed.
3. Furniture uses the same template defaults/placement fit as Objects. A rug is a nonsolid ground-layer prop; a
   chair remains solid if its catalog says so. Do not make everything walkable to hide overlap errors.
4. Floor paint uses indoor paintable ground and existing `StudioLand.paint` commands. It must not repaint wall/void
   borders indiscriminately. Step 3 managed-room floors add their own owned-cell protection and data ownership.
5. Exit warp and arrival cell receive visible protected markers. Warn/reject furnishing that blocks the only door
   landing/exit using the shared rule. The user must be able to enter, stand, move and leave after furnishing.
6. No roof is drawn over a separate interior map. Build overlays can show room bounds without changing Play rendering.

## 6. B05 — Map controls and integration polish

1. Add **Map size** to Build's action strip and keep Land's existing entry. Both open the same `StudioMapSize`.
2. Do not rebuild resize. Expose current dimensions, four-edge deltas, fill terrain, impact preview and cancel/apply.
   New map/area authoring is W02. If not implemented yet, omit its action instead of an enabled placeholder.
3. Existing resize only follows some references. Before W03 is complete, detect resize affecting named places,
   schedule anchors or quest pins and reject with a clear “This resize needs reference-safe expansion” diagnostic;
   do not imply full safety. Detection is read-only and includes shrink that cuts references even with zero shift.
4. Do not change tree selection/clearing semantics. Objects' area filter remains the way to remove trees. No automatic
   bulldozing to make building placement pass. Existing destructive confirmations remain in force.
5. Build hints reflect active tool (select/place/boundary/floor). R only applies the active tool's supported rotation.
   Exiting Build cancels previews; UI clicks/scroll do not place through the shelf into the world.
6. Verify English/Japanese labels, keyboard focus, category persistence, narrow windows and overlay toggles. Map
   controls should not consume the two-row asset area through an unbounded toolbar wrap.

## 7. B06 — End-to-end acceptance

Extend catalog filter/panel, arrange, resize, variants, room and publish tests as relevant. New fixtures should use
small empty maps and existing representative assets, not a fragile assumption about a free town cell.

1. Build → place a cottage; adjust width/depth; move it; slide its door; undo/redo each action.
2. Make its room; open it; paint an indoor floor and place bed/table/rug; return outside.
3. Draw a connected fence, make a junction and insert a compatible gate in a straight section.
4. Play draft; enter/exit cottage and use gate. F2 retains map/tool state without advancing gameplay time in Edit.
5. Restart; drafts and new room remain. Publish to isolated content; reload without drafts reproduces the result.
6. Compare Objects and Build access to the same placements. No double catalog entry, divergent collision or
   overwritten source art; previous meadow/path blend and two-row Land shelf remain intact.

Evidence: exterior with fence/gate and size controls, interior furnishing, two complete Build card rows, one native
Play screenshot matching the edited geometry. Modular roof tools are not part of B06's completion claim.
