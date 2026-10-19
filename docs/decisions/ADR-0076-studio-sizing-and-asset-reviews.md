# ADR-0076: Studio sizing and asset reviews

Accepted 2026-10-18 on the player's request to resize buildings and props from the build menu and flag art that
needs work. Supersedes ADR-0066's requirement that every new size needs a new picture.

## Context

The Studio's existing resize handles require a world-pipeline blockout. All fourteen current building pictures are
imported artwork, so none offer those handles. The remake queue can run Blender and ComfyUI, but imported sources
only recut their existing image; changing a prompt does not regenerate them. The player also needs a lasting list
of assets whose quality or theme needs attention while arranging the town.

## Decision

- Every building and prop can be resized immediately in whole tiles. The inspector exposes width/depth, Apply size
  and Original size; footprint handles use the same command. Placed-object right-click exposes Change size.
- `size` remains the actual placement/collision footprint. `art_size` records the original picture footprint, and
  rendering derives its scale from these two sizes. Buildings retain original doorway/collision metadata in
  `art_shape`, so repeated shrinking and growing does not accumulate rounding errors. A manually moved door keeps
  a separate `door_size` reference. Returning to the original footprint removes the sizing overrides.
- The pure `StudioResize` builds a resized object. `StudioWork.resize_object` validates placement and applies one
  undoable map batch. Building return links follow the moved doorway in that batch. Picture rendering, animated
  gates, selection/picking, drag ghosts and the asset preview use the same scale. Explicit variant/remake swaps
  remove the previous picture's sizing overrides.
- Catalog and world right-click offer **Needs updating**. The list is asset-wide, deduplicated by art ID, persistent
  across restarts, and independent of map undo or Publish. Each record keeps notes, a replacement prompt, location,
  timestamps and any replacement variant. Mark reviewed removes it from the active list while retaining its brief.
- **Asset updates** opens the review window; the catalog's **Needs updating** view filters flagged art and cards
  show an Update badge. Flagging never removes placed objects or their art.
- A restylable blockout can queue a new variant using the existing `StudioRemakes` process bridge. A prompt-derived
  ID and copied spec preserve the old source; `what` is JSON data, never shell syntax. `world.py` applies the shared
  town style, palette and negative prompt. The player starts **Run remakes**, reviews the new catalog variant, and
  chooses where to use it. Imported art and exact authored modules retain their notes/prompts for later work.

## Storage and verification

Map sizing is a normal Studio draft, then Publish. Art feedback lives beside the drafts at
`user://studio/asset_updates.json` through `StudioFiles`; generation uses the existing `remakes.json` and log.
The world pipeline and Publish validate `art_size` against the source picture instead of rejecting an intentional
placement resize.

Pure tests cover shape preservation and resampling. Scene tests cover imported buildings, rendered/picked/ghost
alignment, gates, inspector controls, fit refusal, undo/redo, linked returns, saved drafts, review persistence,
right-click targeting and safe prompt variants. Pipeline tests check native footprint validation. Native screenshots
show different sizes and the review flow. Tests use a fake generation process; this change does not generate or
approve replacement art itself.
