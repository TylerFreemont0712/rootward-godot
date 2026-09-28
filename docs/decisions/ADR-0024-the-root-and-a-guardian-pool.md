# ADR-0024: the Root, a fourth layer for program runs, and the Quine

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0017 (the Golem as two locks, a program run's own foes), ADR-0021 (the rules are the game's own),
  `docs/NewEnemies.md`, `docs/SHARDRUN_DESIGN.md` 4.1 and 6

## Context

The player asked for "7-8 different bosses that have different mechanics that can be cycled for the different stages",
gimmicks "related to programming that should change how the player approaches a fight", and "a 4th stage setup ... for
after the current 3rd stage boss. We'll have 4 stages in total with a final score at the end." `docs/NewEnemies.md`
designs eight guardians, two a stage, each testing one quality of a deck. This ADR records what was built of it and how.

## Decision

- **A program run has four layers; Spellforge keeps three.** `programs.jsonc` gains `layers`, a list of layers in the
  Shardrun's own shape (`ShardrunSchemas.layer()`, now its own function), which `ProgramRules.catalog_for` appends after
  the Shardrun's. The first is **the Root**: rows, rooms and budget like the Kernel (the budget list's last entry
  holds), foe HP ×5.4 (`foe_hp`'s fourth entry), hallways that mix the Kernel's bugs, the Kernel's arena and music until
  it has its own. Spellforge, and its reference results, are untouched: its catalog still ends at the Kernel.
- **The Quine is the Root's guardian** (`programs/foes/the-quine.jsonc`), with a new intent and a new trait, both
  program-run only (`ProgramSchemas.foe()`):
  - `reprint` hits once for every attacking bolt of the last program that ran (at most `max`) for its `power`, and
    turns that program's ward bolts into its shield at `ward` (half). The count comes from the Quine's own memory
    (`foe.echo`, written by `ProgramRules.remember` after every cast; a crash or a timeout printed nothing).
  - `quine`: a program of exactly the cards, in the order, of the last one that ran cannot hurt it (`fixed_point`,
    logged as an `absorb` with the word "fixed point").
  - The preview carries both (`fixed`, `reprints`), and the code panel warns before you run ("The Quine will reprint 12
    bolts: 24 damage"). The Quine usually acts after the program, so it reprints the one being written; one faster than
    the program reprints the one before.
  - Only foes with the trait get the memory, so no other fight's state changes shape.
- **Guardians cycle by pool.** A layer's `boss` list already draws one group per run from the seed; the other seven
  bosses join their stage's list as they are built (`docs/NewEnemies.md`, build order).
- **The final score is the one a run already had** (`ShardrunScore`, shown at the end): a fourth layer adds its progress
  and fights. Per-guardian lines and a re-tune of the ranks wait for played four-layer runs.
- **A guardian's intent rides in its top card.** Over a colossal sprite the intent chip sat under the run's header (the
  Root Daemon had the same fault); `FoeView.take_card` now moves it into the guardian's health card.
- **Placeholder art for all eight** from the pipeline's `creature` style (`pipeline/art/manifest.json`, `foe-<id>`),
  in the foe slots the game reads (`game/assets/foes/<id>.png`). A `key_light` post option clears near-white a
  background removal kept.

## Consequences

- A program run is longer by a layer, and harder at its end: 810 HP of Quine at Programmer. Nothing was re-balanced;
  the probe (ADR-0016) should be re-run over four layers before tuning.
- `run_history` now reads "all 4 layers cleared" for a won program run.
- The other seven bosses need primitives the rules do not have yet (a guard per turn, per-foe caches, summons, foes
  made of parts, a damage transform, phases); `docs/NewEnemies.md` orders them so each system is built once.
