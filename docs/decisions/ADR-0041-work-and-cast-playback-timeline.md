# ADR-0041: Construct the circle and play faster foes during the work walkthrough

Accepted 2026-10-03. Refines ADR-0040.

## Context

Adding each circle layer at a function's return still made the cast feel separate from execution. The work counter
jumped at returns, and faster foes waited for the whole walkthrough before attacking. The player wants to watch
functions write the circle while their work advances, with enemy actions occurring during that same walkthrough.

## Decision

- Start each Shard Weave layer when its displayed function begins and advance its strokes throughout the walk.
  The walkthrough explicitly supplies each layer's progress; the circle's animation clock only controls rotation
  and particles. Repeated calls get their own walk and layer. Import lines draw their held import layers as well.
  Spellforge also supplies progress across each measured call and its displayed body lines.
- Spread a call's recorded work across its displayed traversal, ending at its exact measured total. This is a visual
  interpolation of an already completed sandbox run, not a second execution or an instruction-level timing claim.
  Zero-work calls can still draw layers. The counter, race marker and circle advance together.
- Queue the recorded pre-cast tempo/action groups. When displayed work exceeds a group's recorded tempo, play it
  while the code continues. Equality still favours the player, matching the existing rules. Consume these entries
  once and drain pending actions before the volley, so damage, block, healing and log lines are not applied twice.
- Preserve the order of recorded actions and their outcomes. The rules currently enumerate faster foes in battle
  order; a later low-tempo foe can therefore wait for an earlier recorded action. Presentation never reorders combat
  effects or makes new combat decisions. A lethal recorded attack interrupts the remaining visible walkthrough.
- Keep Shard Weave selectable independently in both cast slots, and reuse the same constructed circle at release.
  Code-off and Character practice retain paced construction on the stage clock. Skip finishes measured playback
  promptly; failures retain only the layers that were visited. Reduced motion still observes arrival events.
- Remove the circle's axis beam and crossing glare lines. Ring pulses and nearby particles supply emphasis.
  Character's live option card uses the same explicit progress API, and its English/Japanese note describes drawing
  during execution.

## Consequences

The code panel now presents the work race as it happens, with the existing sandbox result and combat log as the
authority. Slow visual playback does not change the outcome, and old animation choices retain their behaviour.
