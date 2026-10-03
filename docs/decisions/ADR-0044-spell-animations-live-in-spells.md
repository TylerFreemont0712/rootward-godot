# ADR-0044: Spell animations live in Spells; moves are gestures

Accepted 2026-10-03. Refines ADR-0043.

## Context

Shard Weave and Script Loom were offered in Character → Moves, beside gestures such as Finger Snap, although they are
spell animations (how the circle is built), not moves (what the Maintainer's body does). The player also found the
circles facing a little the wrong way, the Spells previews blown out or unfinished, and Ring Bloom too plain.

## Decision

- **Moves are gestures only.** Shard Weave and Script Loom are gone from Light cast and Heavy cast. The Spells circle
  list is the place for spell animations: Shard Weave (the layered codex circle, formerly "Codex Circle", same id),
  Rootglass Wreath, Clockwork Gear, Constellation, Script Loom and Ring Bloom. A saved profile that wore the Script Loom
  move keeps its look as the Script Loom circle (`CosmeticRules.sanitize`); the removed moves read as the slot's default.
- **Every spell is built while its code runs**, in whichever circle is worn; there is no switch. The worn move is the
  gesture that looses the sealed circle: the hero stays idle during the walk, then plays the move, timed to release
  `RELEASE_AFTER_SEAL` (0.45 s) after the seal. The practice ring and the Character previews do the same.
- **The circles face the foes a little more**: the disc's narrowing is about 12% further round in angle (Codex and the
  other styles 0.46 → 0.34, the centred styles 0.72 → 0.65).
- **Previews show the circle at rest.** A card builds its demonstration layer by layer and then lets it settle before it
  shows it, instead of stopping on the flare of the moment of sealing; live cards loop slowly enough to finish a
  six-ring Ring Bloom.
- **Ring Bloom is richer.** Rings are chosen from the core outward: a flower (lotus or eyes) round a star-and-jewel
  core, a band of runes, a motif of the shard's seed (scallops, diamonds or crescents), runes again, and a crown
  (sawtooth, rays or scallops) on the rim. Runes are drawn as strokes (`RuneGlyphs`, twenty-three futhark-like signs), so
  no font is needed. A ring is still whole at once and turns a little into place.

## Consequences

The Moves tab is only gestures. A profile's circle choice now decides the whole look of a cast. The classic
snap-and-write casts remain only where a cast cannot be constructed (a stage playing fast).
