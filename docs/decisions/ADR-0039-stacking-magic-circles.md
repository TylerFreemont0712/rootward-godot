# ADR-0039: Stacking magic circles, one layer per shard

Accepted 2026-10-03.

## Context

A cast had two separate pieces of spell art. While the Program's code ran, each card as it resolved played a small
generic flourish (`ShardFlourish`: split branches, sorting bars, a reticle) at the Maintainer's hand, and then the
cast wrote one magic circle whose tier came from the volley's total power (`LogPlayer.TIERS`). The player found the
flourish did not match the spell, was misaligned with it, and that every circle looked much alike apart from its skin.
Their idea: the spell effect itself is a stack. Each shard adds a layer to the circle, so a full spell of six shards
is the grand spell: 1-2 shards tier 1, 3-4 tier 2, 5 tier 3, 6 tier 4.

## Decision

- **Tier from shards, not power.** `CircleLayers.tier_for(count)` (pure, `game/core/circle_layers.gd`): 0-2 shards
  tier index 0, 3-4 index 1, 5 index 2, 6 or more index 3 (a spell holds at most six, `max_spell_capacity`).
  `CircleLayers.capacity(tier)` is 2, 4, 5, 6.
- **One layer per shard, in play order.** `CircleLayers.plan(cards)` returns `[{id, kind, word, seed, dir, slot,
  count}]`, at most the tier's capacity. A layer's kind is a function of the card alone: its `role` picks a family of
  looks (a source fans out in spokes, rosettes, orbiting letters or a spiral; a shape weaves a honeycomb, a wave,
  nested polygons or a dashed ring; an order turns in brackets, dashes, runes or waves; a strike is a ruled star,
  spokes, a spiral or nested polygons; a guard rings round in pulses, nested polygons, a honeycomb or brackets; an
  import carries the code in runes, letters, a rosette or pulses), and the FNV-1a hash of its id picks the member
  (`Rng.hash_string`). A card with no role chooses among all twelve kinds. Two different cards in one spell never
  share a kind (the second is nudged along its family, then along all kinds); the same card twice keeps its kind and
  turns the other way. Direction, point counts and so on come from the same hash, so a card always looks the same.
- **The drawing.** `CircleLayerArt` draws the twelve kinds (runes, star, lattice, spiral, satellites, brackets,
  spokes, wave, pulses, nested, dashes, rosette) in the circle's flat disc space, so they narrow, lean, flare and close
  with it. The first played stands outermost, the last innermost (`MagicCircle.LAYER_OUTER` .. `LAYER_INNER`). A
  layer's arrival is a ring of light closing from the rim to its radius, a glow, a burst of motes and the figure
  drawing itself in; then it turns on the circle's clock. The frame (outer pen rings, ticks, core, a crown of beads
  from the third tier and chevrons on the grand one) and the stack of smaller circles in front follow the tier as
  before; each smaller circle now appears with one of the last layers, so the stack grows with the spell.
- **Timing.** Layers do not add time. `CircleLayers.start_share/DRAW` place each layer's start as a share of the
  tier's form time (`MagicCircle.TIERS[].form`, unchanged: 0.62, 0.86, 1.0, 1.23 s), the last whole by 0.97 of it
  (tested), so the strike still lands on the finished circle and the first bolt leaves when it did. One layer takes
  about 0.16 s at six shards and 0.28 s alone.
- **How the hero's cast relates.** Light or heavy remains the volley's (four or more bolts, or 30 power): a heavy cast
  is a gathering with the falling blow, a light cast a finger snap. It no longer decides the circle. A heavy cast
  gathers for at least a second whatever its circle (`LogPlayer.gather_speed`: a small circle is written more slowly
  rather than the gather shortened); the snap hurries a big circle less (`snap_speed`: 1.5, 1.5, 1.3, 1.15), so
  six layers can still be read. A heavy cast keeps its ground sigil.
- **The generic flourish is gone.** `BattleStage.shard_effect`, `ShardFlourish` and the `card_resolved` hook in
  `FightView.present` (and `LogPlayer.motifs_shown`) are removed. The Program panel still lights each card as it runs;
  the spell's visual for that card is its layer on the circle, which arrives in the same order a moment later in the
  cast, at the circle. (Layers arrive in the cast rather than during the code walk so they work at every code speed,
  including "off", and belong to the hero's gather and strike.)
- **Styles.** `CircleStyles` keeps its frame and front circles and gains two strokes every layer is drawn with:
  `ring(r, from, sweep, ...)` and `node(at, size)`: codex a pen stroke and a bead; rootglass a vine with leaves and a
  bud; clockwork a toothed rim and a small turning cog; constellation a string of stars and a sparkle. All four styles
  therefore stack the same layers in their own hand. Their old interior figures (branches, clock hands and gears,
  the scatter of stars) were the single circle's whole identity and are replaced by the layers.
- **Reduced motion** (`Settings.reduced_motion`): layers appear whole at their moment, without the closing ring,
  glow, burst or draw-in.
- **Sound hooks.** Each layer calls `Sound.play("sfx-cast-layer", SpellAnim.SOUND_VOLUME * 0.55, pitch)`, the pitch
  rising with each layer; a missing file is silent. The tier sound `sfx-cast-tier-N` is unchanged. The circle emits
  `layer_added(index)`.
- **The fitting room.** The Spells tab's "Practice power" (four tiers) becomes "Shards" 1-6 plus Light/Heavy;
  `FoundryRehearsal.shards`/`heavy`, and `tier` as a derived property for the older callers. A practice cast
  stacks the demonstration cards (`CircleLayers.DEMO_CARDS`, one of each role). Circles with no spell behind them (a
  carousel card, the motion lab, the circle sheet) show the demonstration spell with as many shards as their tier
  holds (`CircleLayers.demo_plan`).

## Consequences

A spell reads by its composition: two programs of six different cards draw different grand circles, and a circle
plainly accumulates shard by shard. Power no longer sets the circle, so a one-shard cast that happens to be huge
(a heavy cast of one card) writes a small circle slowly, and a six-shard light cast writes the grand circle on a
slower snap; both read as intended (the circle is the program, the cast weight is the volley). A kind's look is a
promise to a returning player: the mapping is pinned in `circle_layers_test.gd` and changes only on purpose. The
sandbox rules, previews and logs are untouched; the new sound ids (`sfx-cast-layer`) are the sound designer's to add.
