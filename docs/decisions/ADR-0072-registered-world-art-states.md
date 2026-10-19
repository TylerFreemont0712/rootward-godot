# ADR-0072: Registered world art and connected fence placement

Accepted 2026-10-17. Extends ADR-0064's world-art workflow and ADR-0066's Studio placement.

## Context

The town's basic fences used plain blockout art, corner posts left half-cell gaps, and some north–south entrances
showed horizontal gates. Wide entrances repeated a post in the middle. Fence drags could change axis as the cursor
crossed a diagonal. The player requested better art, consistent horizontal/vertical fences and a better drag tool.

## Decision

- Keep the 40 px grid and landmark footprints/collision. Replace the Lantern Tree, sealed Root Gate and basic timber
  boundary kit using explicitly authorized built-in imagegen sources and the normal world palette/alpha cut.
- `source.registered: true` preserves transparent canvas margins. `source.images` supplies ordered authored frames.
  Independent silhouette fitting would move modular sockets and resize open/closed gates differently.
- `import_town_boundaries.gd` registers one timber material and shared post into all sixteen north/east/south/west
  masks: isolated post, four ends, two straights, four corners, four tees and a crossing. Native vertical faces use
  the same post height, rail heights, ground anchor and tile depth as horizontal runs.
- Closed/open gate sheets share their hinges. Wide 2/3-cell horizontal and 2-cell vertical gates have one full-width
  frame rather than repeated single-cell doors. Town drawing and Studio ghosts recognize full-footprint programmed
  art; legacy one-cell program art can still repeat. Existing static gate runs become one wide object. The cabbage
  gate retains its program and collision rules. ADR-0074 supersedes the initial permanently open display of ordinary
  gates: they rest closed in town and previews, swinging open while their passage is occupied.
- Catalog `join` names the material root, whose `connections` maps the sixteen masks to art IDs. Gate `sockets`
  expose only their along-fence axis. Connection planning is pure and independent of collision or drawing.
- Drag direction latches at the first displaced cell; returning to the start releases the latch and R turns it.
  One fitted plan supplies preview and placement. Existing fence cells are reused, corners/junctions update
  automatically, and named/programmed things are protected. Gates need a matching straight run. Rejected cells
  never create phantom connections. Repainting a run is idempotent.
- A stroke and its neighboring changes are one undo transaction. Moving, removing or swapping boundaries also
  reconciles the surrounding fence shapes in that transaction. Preview hides superseded sprites until the gesture
  ends. A cached plan is reused while the document, template, cells and placement mode remain unchanged.
- Sources, complete prompts, previous art and the interactive comparison live in
  `Concept/v0.3/Update/town-polish/`. Rebuild registration before the normal world `cut` stage.

## Consequences

The 23 refreshed assets remain reproducible. Gate states preserve registration and open passage widths. The tree
canopy overhangs walkable ground while trunk/root collision stays in its existing cells. The other expanded boundary
materials retain their existing orientation pairs; the connected timber material provides an extensible pattern.
