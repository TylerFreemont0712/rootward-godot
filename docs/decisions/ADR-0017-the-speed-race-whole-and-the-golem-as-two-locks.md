# ADR-0017: the speed race whole (Initiative, a speed per intent, a budget per layer) and the Golem as two locks

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0012 (programs and the speed race), ADR-0016 (a deeper Shardrun), `docs/ROADMAP.md` stage 1,
  `docs/SHARDRUN_DESIGN.md` 3.2 and 6.3

## Context

After ADR-0016 the player asked for the rest of stage 1 and the items left over from it: "Golems rework, initiative and
per-intent speed ... let's focus on", and "the point is the challenge so let's take a step back from the balancing for
now". The balance probe had shown the speed race to be a small tax that never rewarded speed (a foe acted first in 18%
of turns, nothing ever came of landing first), and the Deadlock Golem's pattern ward to be a check of whether a hand held
this turn's element: it ended ten of the fourteen lost runs, and SHARDRUN_DESIGN 6.1 rules out exactly that ("no key
checks").

## Decision

- **Initiative is a rule.** A foe a program lands before (its tempo is not below the program's work) takes 25% more
  from its bolts (`programs.jsonc` `initiative`, `ProgramRules.initiative`). Such a hit is logged with `initiative`,
  drawn with a `»` and in amber, and the code panel says which foes the program catches. The Preemption relic now adds
  30% on top of it instead of being the only source.
- **Each intent has its speed.** A jab is quick, a slam slow: `programs.jsonc` `tempo` gives each Shardrun foe one speed
  per intent, in order, and `ProgramRules.tempo_of` reads the one the foe is about to carry out. A program run's own
  foe gives each intent its `tempo` inline. Every foe's intent chip shows its speed (`⚡24 ops`).
- **The budget shrinks by layer**: 4096, 2048, 1024 operations (`programs.jsonc` `budget`, a list; the last holds for
  deeper layers): the Kernel gives a short time slice, so a late program has to be efficient. A new common relic,
  Overclock, adds 1024.
- **The Golem is two locks in a program run.** The Heap's guardian is `deadlock-lock-a` and `deadlock-lock-b` (the Golem's
  sprite twice, the second mirrored), each with a `deadlock` trait naming the other: damage to one is blocked (logged as
  `locked`) unless the same program also aims a bolt at its partner, for as long as the partner stands. The counter is
  the lesson: acquire both locks, spread the volley. The preview counts the bolts a lock holds and the code panel warns
  about them before the program runs. `programs.jsonc` `encounters` gives a program run its own encounters for a layer;
  Spellforge's Heap keeps its one-bodied Golem.
- **The program run's content lives beside the Shardrun's, never in it.** A test proves the Shardrun's content is the
  catalog the old engine built, key by key, so the new foes are in `packs/<pack>/programs/foes/` (loaded with
  `ProgramSchemas.foe()`, the Shardrun's schema plus intent `tempo`, `mirror` and the `deadlock` trait) and the intent
  speeds of the Shardrun's foes are in `programs.jsonc`. The shared rules gained no branch for this: `ProgramRules`
  resolves the lock, and `catalog_for` merges the program's foes and encounters into a program run's catalog.

## Consequences

- Landing first is now worth something, and every turn's race is different and readable from the intents alone.
- The lock rule is the first foe mechanic that reads the program (which foes it aims at). Stage 4's program hooks
  (SHARDRUN_DESIGN 6.2) are its general form; until then a trait is one match arm in `ProgramRules.resolve`.
- Not tuned: at the player's word, the curve, the budgets and the locks' HP are first guesses. The Kernel's 1024 will
  bite brute force hardest (Exhaustive Kill alone is 2¹² operations on twelve bolts), which is the lesson; the balance
  probe can measure it when balance is back on the table (`docs/research/balance-probe/`).
- The pattern ward's softer program-run value (ADR-0016) now applies to the Regex Sphinx alone.
