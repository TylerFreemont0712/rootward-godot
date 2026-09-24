# ADR-0003: the Shardrun rules are ported line for line, and proven by replay

- Status: accepted
- Date: 2026-09-24

## Context

The rewrite may change anything but the concept, and the spellbook Shardrun is the player's favourite. Its rules are
about 2,200 lines of TypeScript (`packages/core/src/shardrun/`) tuned over many sessions: compounding damage, Big-O
billing, relics, traits, the deck playstyle. Redesigning them would change what the player loves; porting them loosely
would change it by accident.

## Decision

- **Port the rules as they are**, function for function, into `game/core/shardrun/` (Shardrun, ShardrunCommands,
  ShardrunDev, ShardrunBattle, ShardrunRules, ShardrunMap, RelicConditions, ShardrunScore, ShardrunCatalog). Changes
  to the rules come later, on purpose, each with its own ADR.
- **Plain data.** The state is a Dictionary saved as JSON (`docs/shardrun-state.md`), with snake_case keys like the
  content. The engine's functions are static and pure: they take a state and a catalog and never touch nodes or files.
- **JavaScript's number semantics, where they differ.** `Math.round` (halves up) is `JsMath.js_round`; `Math.log2`
  is exact at powers of two (`JsMath.log2_whole`); every division that was a float in JavaScript is written as a float
  division (GDScript's `int / int` truncates); a draw from the generator happens even when its result is unused, so the
  streams stay aligned. Template strings print `null` (`JsMath.text`).
- **Proof by replay**, three ways, all from the old engine (`tools/fixtures/`):
  1. `shardrun_runs_test.gd`: 36 seeded runs (both playstyles, every difficulty, sandbox runs) driven by a seeded
     "player" that enters, arranges, composes, casts made-up outcomes (malformed bolts, fizzles, floods past the cap),
     claims, rests, forges, abandons, and sends commands that must be refused: 3,789 steps, each snapshot, refusal
     and preview compared, and the final score.
  2. `shardrun_pure_test.gd`: maps and encounters for 8 seeds x every layer, pricing, clamps, bolt validation, the
     relic modifiers of every relic alone and mixed, and id ordering.
  3. `shardrun_unit_test.gd`: the old engine's own 73 unit tests, run with a recorder in place of the engine
     (`tools/fixtures/record/`); the 2,517 calls they made, over 23 hand-made catalogs, replayed.
  Every suite was checked with deliberate mutations; the three that survived are equivalent at every call site (JS
  versus Godot rounding of negative halves under a clamp, the 60th draft attempt, and a log2 that happens to be exact).

## Consequences

- The rules behave exactly as the old game's until someone decides otherwise, and the fixtures say so in a test.
- Godot's JSON parser is not correctly rounded for 17-digit numbers ("0.9750000000000001" reads as 0.975). Content's
  short decimals parse exactly; only the fixture comparison forgives one ulp (`Fixtures.same_number`).
- `trait` is a reserved word in Godot 4.7 (GDScript traits), so code says `foe_trait` while the data key stays
  `trait`; and a static `log()` would shadow the built-in logarithm, so the engine's log helper is `record()`.
- The catalog is expected complete (the content loader applies schema defaults, phase 3).
