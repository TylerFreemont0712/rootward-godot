# ADR-0043: Construction is how a spell is cast, and Ring Bloom

Accepted 2026-10-03. Builds on ADR-0040, ADR-0041 and ADR-0042.

## Context

Shard Weave and Script Loom (ADR-0040 to 0042) built the circle while the code walked, but only as moves the player
had to find and wear in Character → Moves, and the first option of each cast slot was still the old finger snap
and push. The player wants construction through the code walkthrough to be the main way every spell is cast, wants
the circle's look to be chosen in Spells like the other circles, and asked for a last animation that grows from the
centre: every shard sets another ring round the spell, up to six, each ring appearing whole rather than being written.

## Decision

- **Construction is the default cast.** `shard-weave` is now the first option of Light cast and Heavy cast, so a
  profile with no choice (and an unknown id) constructs the circle during the walkthrough. The older moves (Finger
  Snap, Rune Trace, Grand Push, Skyward Call, Root Seal) stay as options. `CosmeticRules.check` no longer demands the
  native clip of a slot's default when that default is a construction (it plays on every skin). Saved choices are
  untouched: a profile that wore Script Loom still does.
- **Spells decides the look.** Script Loom and Ring Bloom join the Spells circle list. A centred style worn there
  draws every constructed circle, over a cast option's own `circle_style` and over the other worn styles
  (`CosmeticRules.construction_style`). So a player who wears the Script Loom move and then picks Ring Bloom in Spells
  gets Ring Bloom; one who wears a plain circle still gets the loom from the loom move.
- **Ring Bloom** (`ring_bloom.gd`) is a circle of whole rings round a core. The first shard sets the core, and shard
  *n* sets a ring whose outer radius is a fixed share of the grand radius, from 0.2 to 1.0 in even steps, so one shard
  is a small circle and six are the grand one. The circle is drawn at the grand scale whatever the shard count, so a
  ring is always the same size and the spell visibly grows. A ring never writes itself: it is whole within the first
  12% of its function and turns at most 0.5 rad into its place while the function runs; after the walk the rings
  drift almost imperceptibly. Each ring's ornament (ticks, beads, dashes, or an inscribed polygon) comes from the
  shard's layer kind and its start phase from the shard's seed, so a spell is the same every time. Bolts leave from the
  centre. Ring Bloom uses the same progress API as the other constructed circles, so the walk, skip, failure,
  reduced-motion, code-off and rehearsal contracts of ADR-0040 to 0042 hold unchanged.

## Consequences

Every spell is built from its code unless the player chooses an older move. Circle style is one choice, in Spells.
Presentation only: nothing here changes a rule or an outcome. The older moves' notes and the Script Loom move's
own style stay for existing saves.
