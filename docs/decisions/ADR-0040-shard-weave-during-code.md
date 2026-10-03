# ADR-0040: Optional Shard Weave during the code walkthrough

Accepted 2026-10-03.

## Context

ADR-0039 stacks shard layers during the cast's gather, after the code has finished walking. The player wants to
see the circle being constructed while those shards execute, keeping the old animations as selectable alternatives.

## Decision

- Append `shard-weave` to both cast slots in the cosmetic catalogue, carrying `construction: "shards"`. Defaults
  and existing options stay in place. This procedural option is playable on every skin; its idle clip is only a
  fallback, not an animation asset requirement. Names and notes have Japanese translations.
- Start a manual `MagicCircle` before the walkthrough. `ProgramCode` and Spellforge's `CodeView` emit
  `shard_resolved(index)` when a measured call returns. Indices distinguish repeated instances of the same shard. Program imports resolve at their source lines;
  the construction plan orders held imports before executable calls, matching the code rather than hand slots.
  `construct_shard` accepts exactly the next slot, so duplicate notifications cannot duplicate layers.
- Each resolved shard draws its figure over 0.34 stage seconds. The rim and decorations track the fraction of
  layers drawn, while elapsed time alone cannot add layers or finish the circle. The hero stays in its chosen idle.
- Anchor this circle using the stage's fitted figure rectangle rather than a model hand or sampled release pose.
  The element colours, chosen circle style, shard figures and circle tiers remain shared with the existing casts.
- Reuse the same circle through the volley. Seal after the walkthrough and wait only for the last stroke, then
  release the bolts; do not replay the old gather or snap. Interrupted or failed code retains only visited layers. A replay without a successful cast uses the light
  choice and closes its partial circle before reporting the failure.
- A skipped walkthrough reports its measured returns promptly. Without a visible walkthrough, practice casts and
  code-off playback use a paced sequence at 0.45 seconds per shard. Reduced motion adds each layer whole at its event.
- Character → Moves offers the alternative in Light cast and Heavy cast, with a live construction preview and the
  usual browse/`Wear this` persistence. The practice ring uses the production playback and its local clock, so speed,
  pause, frame stepping and skin changes work with the new option.

## Consequences

Circle construction is a presentation of recorded sandbox results, never a second execution of player code.
Existing saves and casts retain their defaults. Players can choose the alternative independently for light and
heavy casts, and circle styles remain independently selectable in Spells.
