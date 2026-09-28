# ADR-0021: the rules are the game's own

- Status: accepted
- Date: 2026-09-28
- Supersedes: ADR-0003 (the Shardrun rules ported line for line, and proven by replay)

## Context

The player: "There is no reason that the old engine needs to be matched, that was the point of moving to a new engine
is to have a rewrite where it's more efficient. Remove this rule, and change whatever you need to improve this
system."

ADR-0003 bound the Shardrun and Spellforge to the TypeScript engine: fixtures recorded from it, a test that the
content's catalog was its catalog, JavaScript's rounding and JSON kept. New work had to route around it (the program
run's foes and intent speeds kept apart; the layers' music could not change).

## Decision

- **Nothing binds this engine to the old one.** The old repo is read for content, art and how it played.
- **The reference results are the game's own.** The recorded runs, calls, grades, spell runs and RNG draws in
  `game/test/fixtures/` still catch accidental changes, but a change made on purpose re-records them from this engine:
  `ROOTWARD_GOLDEN=update scripts/test.sh -a <suite>` stores what the engine does (`Fixtures.expect`), the suite writes
  the file, and the fixture's diff is reviewed with the change. The rules suites keep their frozen catalog
  (`shardrun-catalog.json`) so content can change without them.
- **Gone**: the test that the content's catalog equals the old engine's, and the recorders in `tools/fixtures/`.

## Consequences

- Content changes freely: the layers name their rest and final-guardian music.
- What was routed around the old catalog can be folded back where it belongs (a candidate: the program run's intent
  speeds onto the foes' intents); `JsMath` and `JsJson` stay until a change wants them gone.
