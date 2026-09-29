# ADR-0026: the guardian pool, built

- Status: accepted
- Date: 2026-09-29
- Related: ADR-0024 (the Root, the Quine, guardians cycle by pool), ADR-0017 (the Golem as two locks), ADR-0021 (the
  rules are the game's own), ADR-0025 (every guardian on the map), `docs/NewEnemies.md`

## Context

`docs/NewEnemies.md` designed sixteen guardians, four new ones a stage, and ADR-0024 built one of them (the Quine). The
player asked for the rest: "the new bosses aren't actually added to the layers yet ... It should be a random pool based
on the layer." Each design names a gimmick that does to a program what a real bug or idea does to code, and the rule
that counters it.

## Decision

- **Every layer of a program run has a pool of five guardians**, drawn by the run's seed as any encounter is
  (`ShardrunRules.encounter_for`), shown on the map from the start (ADR-0025):

  | Layer | Pool |
  |---|---|
  | The Salvage | Kiln Warden, Ouroboros, the Unhandled Exception, the Short Circuit, the Unreachable |
  | The Heap | the Golem's two locks, the Cache Lich, Malloc, the Page Fault (three pages), the Thunk |
  | The Kernel | Root Daemon, the Call Stack Colossus, INT_MAX, the Profiler, the Livelock Twins |
  | The Root | the Quine, the Root Compiler, the Mutator, Karp, the Halting Oracle |

  Spellforge keeps its guardians: the pools are `programs.jsonc`'s, and its reference results did not move.
- **The rules live in three modules**, called at fixed points and only for the new trait and intent kinds, so older
  foes pass through untouched:
  - `ProgramGuardians`: a foe's state made ready (a loop counter, a cache, frames scaled like its HP, a compiled phase,
    the block it allocates), the turn's edges (this turn's guard, return slot, target or prediction; a loop going round,
    pending damage decaying, a frame pushed, the page out longest swapped in), and the new intents (`loop`, `throw`,
    `summon`, `realloc`, `mend-swapped`, `count`, `mutate`, `idle`), plus stuns, recompiling, swapped-out pages and
    enraged twins.
  - `GuardianLanding`: the landing. `plan` judges the whole volley first (a loop's `break` guard, Karp's certificate by
    subset sum, the Oracle's prediction, the Profiler's factor); `bolt` decides each bolt (a page fault, a cache hit, a
    short-circuited bolt, a factor); `body` hurts a lazy, stacked or 8-bit foe its own way; `finish` stuns, reflects,
    kills mutants and changes the Root Compiler's phase. Its `notes` go to the code panel before the player runs.
  - `RootCompiler`: phases compiled from the guardians this run beat (`stats.guardians`, kept for program runs only),
    their intents at ×1.5, their trait where one body can carry it; the third phase self-hosting (its tempo is the
    last program's work, `battle.last_work`).
- **Real execution stays real.** The Unreachable's dead code and the Mutator's mutants change what the sandbox runs
  (`SpellRuns`), and both are part of the run's input, so the preview and the cast are the same run of the same code.
- **Mutants are made, not authored.** The design asked for mutants written per card; instead `ProgramMutants` applies
  a mutation-testing operator (`>` to `>=`, `max` to `min`, `+ 1` to `- 1`, a sort turned round...) to the card's own
  code, as mutmut and Stryker do. Every card has mutants in both languages for free, and a mutant card is marked in the
  hand, its details showing the code that will run. **A census decides which mutants a fight may draw**:
  `scripts/mutants.sh` runs every mutant through its card's worked examples and writes the ones that still run to
  `programs/mutants.jsonc` (250 of 285 in Python, 298 of 332 in JavaScript at first count). A mutant may change what a
  card returns, which is the point; one that crashes or hangs would fail the whole program, a harsher edit than the
  Mutator means. Loading warns when a card's code has changed since the census.
- **Everything is telegraphed**: foe cards show a guardian's state as chips (its guard, cache, pending damage, frames,
  target, prediction, phase), intents have names ("raise ValueError"), and the code panel says what each guardian will
  make of the program about to run.
- **One change from the design**: the Halting Oracle never predicts "every bolt aimed at it" against itself alone,
  since a lone foe takes every bolt and the prediction could not be refuted. The check stays for mixed fights.

## Consequences

- The Heap Block, Malloc's minion, has its own sprite (`foe-heap-block`); the Page Fault's pages share one, and the
  Twins mirror one.
- The stage adds a foe that joins mid-fight and follows the fight's order, which the Twins change as they swap.
- Nothing is balanced yet: the HP and intents are the design's first numbers. A balance probe over four layers with
  the pools is the next step (`docs/PLAN.md`).
