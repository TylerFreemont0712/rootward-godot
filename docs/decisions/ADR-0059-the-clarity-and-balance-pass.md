# ADR-0059: The clarity and balance pass: a summary says what the code does, and a refactor is not free

Accepted 2026-10-08. Applies to the program cards, the program relics and the Spellforge shards.

## Context

The cards, relics and shards were written by hand over many sessions. Some summaries left out a rule the code follows (a
fallback, a cap, a shield, a guard that is exempt), a few refactors cost less than their base for the same code, and a
few billing classes did not match what a card runs. The player asked for good clarity and proper balance, and asked
that the balance probe not be used.

## Decision

- Each item was read against its code, in every language it has, and against its peers: the same paradigm, role and
  cost for cards; the same tier and effect kind for relics. A finding was applied when a text change makes the summary
  true, or when a number follows from the peer comparison. Code, engine and design questions were left open and are
  listed in `docs/CARD_AUDIT_2026-10-08.md`.
- A summary states the rule the code follows: the fallback, the cap, the shield, what is wasted, the exemption for
  guards and wards. Where the code is what is wrong, the text does not excuse it.
- A refactor is not cheaper than its base for the same code. Where a refactor had been free, its cost is the base's.
- A card's refactor and its base are often one summary. They then share one Japanese entry, keyed by the English, so a
  change to one of them must move the entry for both.
- JavaScript functions are camelCase, as the harness calls them. Five cards had snake_case names and failed.
- A worked example follows the rule its code documents when the two disagree (Gradient Ward's ward goes before the first
  stronger bolt).
- Billing matches what a card runs: Radix Sort and Exponential Search bill measured work, and Quickselect bills a sorted
  volley as quadratic, as Quick Sort already does.
- A forged card keeps a discount that names its base: Import Itertools' discount list names the refactors too.
- Balance was judged by reasoning from the data, the code and the design notes. The balance probe was not run.

## Consequences

- About 100 program card edits (summaries, costs, billing keys, a keyword, a discount list), 22 relic and shard summary
  edits, and one relic number: Overclock's budget bonus from +1024 to +256. At +1024 it was +100% on the Kernel's budget,
  past the Overclocker focus's ×1.5.
- Japanese: every changed English summary has its entry updated, and two entries that the change had orphaned are
  restored. The locale tests pass.
- The mutant census was refreshed. Static validation and all 1036 worked examples pass in each language.
- Open, and listed in the audit document: Sweep copies guard bolts to every foe; Hash Merge fuses by element alone, so a
  ward fuses with an attack; Fractional Knapsack's remainder is unaimed; Import Collections+ and Import Bisect+ run the
  base code; Permutations and Pairwise bill a class they do not match; Recurrence+, Memo Ward, Pascal Row+ and Release+
  need balance decisions in code.
