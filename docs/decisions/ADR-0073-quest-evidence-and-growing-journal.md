# ADR-0073: Quest evidence and a journal that grows

Accepted 2026-10-17. Extends ADR-0061's boots and quests and ADR-0068's programmable progress display.

## Context

The boots quest mixed its additional movement rule with the first successful programmable-object interaction.
Its hint suggested an unsupported custom key. Step progress stopped counting at the first incomplete step, hiding
things already done in another order. A conversation or lesson returning an older flag snapshot could also erase
progress earned while a background job finished. The full quest list exposed many locked rows before they mattered.

## Decision

- Walking travels a tile in 0.22 seconds instead of 0.25. The authored gait remains at 12 fps, independently timed.
- A successfully executed boots table supplies evidence. A taught arrow must have an error-free, in-bounds,
  matching one-tile movement. `boots-expanded` records an additional arrow beyond the starting right rule;
  `all-ways` records all four. `first-action` retains its existing programmable-thing meaning.
- Reconcile these additive milestones after every current table refresh: Try them, load, map or language changes.
  An old `all-ways` proves `boots-expanded` even when the player's current program has changed. Never reset earned
  progress or award milestones for an unrun draft. Preserve the existing serial guard against late sandbox answers.
- Dialogue, lesson and task flag snapshots merge true progress into the current state through
  `OverworldState.remembered`. Missing/stale false values cannot clear a true achievement. Bag facts remain derived
  and are stripped before storing. Explicit developer flag pokes continue to use the replacement API.
- Each quest step evaluates its own evidence. `steps_done` counts all completed steps; `next_step` separately finds
  the first incomplete content index, with its hint and counting progress. The log, count, bar and individual pips
  show that same evidence. Quest dependencies still control story availability without discarding early evidence.
- The boots instructions explain B, arrow rules, one-tile x/y changes, Try them, and X/Space at the cabbage gate.
  Leaving home precedes the gate in the displayed checklist; doing either earlier still counts.
- Clicking the HUD quest opens its instructions directly. A click while moving waits for the tile to land. Quests
  are also available in the initial pocket menu. Closing the log restores the appropriate underlying menu or town.
- The initial log is one compact card: active quest picker, short description, current instruction/hint and checklist
  in a bounded scrolling area. Future quests stay hidden. The existing Pip progress task unlocks an optional larger
  journal with a scrolling active/completed list and bars supplied by the player's own `progress()` implementation.
  Closing or compacting the journal never changes quest flags. Additional journal abilities can follow this task path.

## Consequences

Existing saves repair missing boots evidence from real compiled programs without asking players to repeat actions.
Progress counters no longer imply that quest steps must be completed in sequence. A small always-available log
provides the instructions needed to learn, while the coding lesson visibly upgrades that same tool. UI labels and
new instructions have Japanese translations. No new appearance, art, save version or sandbox privileges are needed.
