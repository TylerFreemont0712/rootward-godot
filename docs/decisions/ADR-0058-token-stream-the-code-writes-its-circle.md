# ADR-0058: Token Stream, where the code writes its own circle

Accepted 2026-10-08. A circle style beside Shard Weave, Script Loom and Ring Bloom (ADR-0040, ADR-0043, ADR-0044).

## Context

A spell's circle is built from its shards while the code walk runs (ADR-0040). Its layers are drawn by shape: rings, a
star, runes. The player asked for spell animations that feel more unique, and the program's code is what the game is
about, yet nothing in the picture came from the code itself.

## Decision

- **Token Stream** is a circle in the circle slot (`cosmetics.jsonc`), drawn as Shard Weave is. Its difference is what
  comes to the circle. When a card's call runs in the code walk, its function name lifts out of the code panel where
  the call stands, flies on a curve to the circle, hovers on the circle's rim while the call runs, and dissolves into
  it as the call resolves and its layer is written. Each name is in the spell's element colour.
- The timing of the layers does not change: a layer still arrives when its call resolves, and the walk still sets the
  pace.
- Only a construction cast (the code walk) runs it. Code off, fast play and Spellforge's code view write the circle as
  they always did.

## Consequences

- New files: `token_flight.gd` (one name's flight, in global coordinates), `token_stream.gd` (the overlay that starts and
  lands the flights from the code panel's signals), and the code panel's geometry (`RuneCode.cell_centre`,
  `ProgramCode.line_of_slot`, `call_name`, `call_point`). `FightView.present` attaches a stream for a construction cast
  when the worn circle is Token Stream.
- A flight waits 0.2 s before it leaves, because the panel scrolls to a call after its signal (`# LEARN:` in
  `token_stream.gd`), and it is top-level, so the overlay's layout cannot move it (`# LEARN:` in `token_flight.gd`).
- The names are short-lived and small (18 px). The stream is judged by play before it is tuned.
- The circle is drawn as the default codex look, so no drawing code changed. The name and note are Japanese in
  `locales/ja/cosmetics.jsonc`.
