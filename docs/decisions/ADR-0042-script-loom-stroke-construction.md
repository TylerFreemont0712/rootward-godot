# ADR-0042: Script Loom and visible stroke construction

Accepted 2026-10-03. Builds on ADR-0040 and ADR-0041.

## Context

The work race is now concurrent, but the player still sees circles as already constructed. Two causes were measured:
the saved loadout uses the original post-walk casts, and the old circle drawing paints full discs and arrival rings
behind incomplete strokes. Checking progress counters alone does not establish that the visible drawing is partial.
The player also wants a new animation with its own design, built around the code walkthrough.

## Decision

- Add `Script Loom` to both Light cast and Heavy cast. Keep the original options, their defaults and saved choices.
  Its note explicitly tells the player to wear it in both slots for every spell; the actual volley chooses the slot.
- A construction cast may carry an optional validated `circle_style`. Script Loom chooses `script-loom` regardless
  of the separately worn circle style. Shard Weave continues using that worn style. The stage accepts an optional
  override only for construction casts; ordinary casts retain the original selection.
- Give Script Loom its own renderer. It writes a single tilted seal in angular sectors, one per function/import.
  Each sector contains a double border, two folded curved threads and an angular stitch. The final function writes
  the central clasp. It does not reuse the old layer figures, star, glow disc, crown or front stack.
- Clip the stroke paths by traversed distance and draw a warm writing tip at the end of the current prefix. At zero
  progress there is no drawing; an unvisited sector remains empty. Every visible mark comes from measured call
  progress, and completing the walkthrough adds no extra geometry. Strokes stay still until the seal is finished.
- Use the same circle for release, with its centre as the bolt origin. Imports, repeated calls, failures, skip,
  reduced motion, code-off pacing and Character's local rehearsal clock retain the existing playback contracts.
  Faster foes continue playing recorded actions during the work timeline; no combat rules change.
- Make Shard Weave's construction readable as well: suppress full-disc and whole-ring arrival glows while writing,
  use linear stroke progress, draw front-disc geometry partially and hold rotation until construction ends.
  Automatic original casts keep their timing and effects.
- Character's live card and practice stage both use the chosen construction renderer, with English/Japanese notes.
  Geometry tests verify the actual clipped paths and empty unvisited quadrants; real fight captures verify the
  early, intermediate and completed pictures alongside the code and work counter.

## Consequences

Construction is visible in the marks that reach the screen, rather than inferred from a counter. The new animation
is an explicit alternative and does not silently alter the player's loadout. Circle style overrides are cosmetic
data and cannot change execution or combat outcomes.
