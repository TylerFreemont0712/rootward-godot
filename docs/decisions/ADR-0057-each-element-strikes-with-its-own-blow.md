# ADR-0057: Each element strikes with a blow of its own

Accepted 2026-10-08. Extends ADR-0014 (spell animations drawn as motion) and ADR-0037 (impact styles).

## Context

A bolt that lands plays one of two blows: the bracket slam (`hit-compile`) or, for a critical, the broken-open star
(`hit-critical`). The element only tinted them. Heavy casts have their own worn impacts, but a light cast's landings
all looked alike. The player asked for new strike sprites that show the spells actually hitting a foe.

## Decision

- Three blows are drawn procedurally in `pipeline/sprites/spells.py`, with no GPU (`scripts/sprites.sh spells --only
  hit-ember,hit-rime,hit-arc --sheet`):
  - `hit-ember` (fire): a white-hot flash, a scorch, a flame tongue that flickers up off the blow, sparks flung mostly
    upward, and embers that drift up.
  - `hit-rime` (frost): a cold flash, six ice shards thrust out and held, a notched frost ring, and snowflakes sifting
    down and out.
  - `hit-arc` (spark): a flash, then jagged arcs that crack, fork and flicker (redrawn every few frames).
- `LogPlayer.blow_sheet(element)` picks a non-critical landing's blow from the bolt's own element. Anything else
  (`none`) keeps `hit-compile`. Criticals keep `hit-critical`, and a heavy cast's first blow per foe keeps the worn
  impact.
- A missing sheet falls back to `hit-compile`, as every element has one.

## Consequences

- `pipeline/sprites/spells.json` gains the three specs; `game/assets/fx/spells/` gains their sheets. The
  `SpellAnim` tests check that every sheet fits its facts, and `spell_anim_test` pins each element to its blow.
- The ember is the most provisional: its flame tongue is a plain shape. Tune it by play before a painted pass.
- Strikes keyed by card role (a sort's strike, a search's probe) would need the bolt to carry its source card
  (ADR-0014's extension points 2 and 5); that is not built.
