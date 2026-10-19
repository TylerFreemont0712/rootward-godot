# ADR-0077: Land variety and area selection

Accepted 2026-10-18 on the player's request for distinct terrain, variation within painted ground, and an easier
way to clear excess trees in the Studio. Updated 2026-10-19 for the shared Land workspace and surface refinements.

## Context

Land exposed five outdoor surfaces. Grass had a few base pictures, while most overlays repeated one texture;
small runtime tints did little to disguise repeating details. Ordinary box selection began only on empty ground,
so a press inside a dense forest moved a tree instead of selecting an area.

## Decision

- Offer nineteen outdoor surfaces: grass, meadow, dry grass, forest floor, moss, root floor, fern moss, glow moss,
  flowers, dirt path, brick path, stone path, wood path, soil, tilled soil, sand, gravel, cobble and water. Keep floor,
  wall and void indoors. Optional `paint: outdoor|indoor` metadata in
  `terrain.jsonc` controls the Land palette in content order. Catalogs without it retain the original palette.
- Author terrain through the existing local `pipeline/pixel/terrain.py` generator, at 40 px with the shared palette
  and hard alpha. Grass stays quiet, with small tufts, occasional clover and tiny flowers. Forest leaves, moss,
  pale sand, loose gravel and dark/furrowed earth have distinct structures as well as colours. The grass base uses
  the darker green shades; forest floor keeps its litter pattern with more green leaf tones.
- Each outdoor surface has eight texture variants. Variant choice mixes both world coordinates and the ground
  kind through `Rng`; it never advances gameplay randomness. The same place keeps its appearance on preview,
  release, undo, reload and every water frame. Painting does not add random variant values to map files.
- Meadow's three flowerless layouts use an ImageGen edit of the same meadow source, preserving its grass colors
  and fine texture. Meadow, the four path materials and the three new woodland grounds fade into a shared textured
  collar in the actual half-cell phase. Dirt, brick, stone and wood paths expose worn edge bands only where their
  sixteen corner masks meet other ground; connected centers, straight sides, ends, corners and intersections do not
  acquire individual tile frames.
- Extend the atlas with explicit layer `order` and `variants` per overlay. Rows are `row + variant * frames + frame`;
  sixteen corner masks remain side by side. Variants share their outer pixels and alpha masks; cobble joints and
  water's main wave structure stay aligned. Remove runtime pixel recolouring in favour of authored palette art.
- Preserve chunk repainting. Overlay masks use two `PackedInt64Array` planes of fifteen four-bit layers each, so all
  eighteen outdoor layers render and repaint identically to a whole-map bake. Missing art has a flat-colour fallback.
- Land and Objects share the lower workspace: Land puts painting tools, map size and its ground swatches there;
  Objects puts the catalog there with two rows of cards. Surface variation is automatic. Run
  `scripts/pixel.sh --only terrain` to rebuild and lint terrain without rewriting other pictures.
- Add Objects → **Select area (Q)**. It starts on occupied cells, snaps to cells, previews matching footprints and
  count, and selects on release. Filters are All objects, Props only and Trees only; trees come from catalog
  category/subcategory metadata. Footprints decide inclusion, rather than crowns leaning over the rectangle.
- Shift adds to the existing selection. Delete uses the existing single undo batch and confirmation for named or
  programmed objects. Escape cancels an unfinished rectangle while preserving prior selection; S returns to the
  ordinary selection/move tool. Editing shortcuts cannot modify a prior selection while its rectangle is unfinished.

## Consequences and verification

Existing maps gain texture variation without changing terrain identity, collision or their saved data. The player
chooses where to paint new types and which trees to remove; this change does not clear canonical town objects.
Art remains reproducible, local and palette checked. Studio copy stays English under ADR-0066.

Pipeline tests cover distinct variants, shared mask edges, palette/alpha, content coverage and deterministic rebuilds.
Scene tests cover all nineteen surfaces, stable variation, all eighteen layers across chunks, water movement rules,
real brush/swatches, saved legends, Publish, selection over occupied cells, filters, Shift-add, cancellation,
confirmation, delete/undo/redo and keyboard isolation. Native screenshots review terrain and tree-clearing previews.
