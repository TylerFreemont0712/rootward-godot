# ADR-0048: paradigm laws, focuses and program memory

- Status: accepted (balance follow-up open)
- Date: 2026-10-05
- Related: ADR-0012, ADR-0016, ADR-0017, ADR-0018, ADR-0026, ADR-0046, ADR-0047;
  [ParadigmUpdate.md](../ParadigmUpdate.md), parts A and B.

## Context

Paradigms previously changed signatures and draft weights but shared every combat rule. Fight rewards gradually
erased their identity. The player approved five laws, fifteen selectable focuses, a larger algorithm bank and an
economy with cross-paradigm access. The complete update is tracked in PLAN; this decision covers its first primitives.

## Decision

Each new program run explicitly picks a paradigm, then one of its three focuses. The paradigm swaps one basic card
and gives its law relic; the focus gives another rule relic and one signature. `paradigm` and `focus` are separate
non-loot tiers, shown on the relic bar. Run history retains both as `greedy/sprint`.

The Table, Index, hit counts and last landed volley are saved fight data. The program branch of SpellRuns extends
the sandbox input; Spellforge's shared battle input stays unchanged. Reading a seed is pure: the Index's automatic
withdrawal happens only when ProgramRules plays the program, including its rehearsal on a copied state. Flagged
withdrawals must match an actual indexed bolt and cannot withdraw it twice.

One landing implementation remains responsible for both cast and preview. ProgramLanding holds damage resolution
and memory hooks; ProgramRules retains the public entry point. This keeps the existing rules API and the lint file
size limit as the laws grow.

Old program saves receive defaults but no retroactive focus or law relic. A saved draft without `focus_offers`
continues its original path. Saved maps are retained. Pip's Trial defaults to Tabulator, which leaves its existing
memoisation lesson meaningful; its fixed rooms and deck are preserved.

Pruned algorithms may declare `work_mode: measured`: the sandbox's loop and call counters bill their actual search,
with a worst-case complexity label still explaining growth. Backtracking assigns each bolt to any of m foes, so
its honest label is O(mⁿ), pruned, rather than the design's two-choice O(2ⁿ) shorthand.

## Baseline and verification

Slice 0 runs the original smart probe from immutable commit `fb72306`, six seeds per paradigm, Beginner,
JavaScript. Actual seed strings and raw runs are retained under `docs/research/balance-probe/paradigm-update/`;
the final comparison must reuse those seeds. Deck shares count each card's declared paradigm, including copies
and refactors, because the old draft pools overlap.

Baseline validation: 438 tests passed in 66 suites, lint clean, 375 examples per language passed. Concurrent
probes share Godot's sandbox scratch directory unless `XDG_DATA_HOME` is isolated; cleanup tests were rerun in
isolation and passed. Locale coverage reported two existing composed damage-message formats separately, despite
their line-by-line translation support; these must not be misreported as new missing translations.

The [baseline report](../research/balance-probe/paradigm-update/baseline.md) records 12/30 wins (40%),
27.7% own-paradigm cards, 45.4% neutral and 26.8% other. Greedy and DP won 1/6 each; Brute Force
and Divide & Conquer 3/6 each; Search 4/6. These small samples have wide uncertainty.

Implementation gates, screenshots and the paired report are recorded in the [Paradigm Update handoff](../ParadigmUpdate.md)
and [balance report](../research/balance-probe/paradigm-update/report.md). The 30-seed comparison meets the overall win-rate
target and the economy targets after the payout/price adjustment; weak/strong paradigm rates, law activation, early
fight length, the other-paradigm deck share and single-card ablation remain follow-up work.
