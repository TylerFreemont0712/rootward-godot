# Balance-fix card set · v0.2

**Status:** concept only. These cards and changes are not in the live pool. This packet follows the C ratings in [the v0.2 Balance Pass](../../BalancePass.md) and complements the existing concepts in [README.md](README.md), especially Parity Lattice and Boundary Guard.

## Design target

Keep each algorithm's identity, but make its output matter to a fight. The C cards fell into three patterns: pure order with no consumer, a one-state effect that can do nothing, or an effect already outclassed by a broader card. This packet gives the order cards a shared defensive payoff, gives the Greedy scheduler a customer, and makes the two Dynamic cards useful on ordinary volleys.

The numbers below are starting points. Guard produced by a cast can stop foes that have not acted yet; it cannot reverse damage from a foe that already acted before a slow program resolved.

## New cards

### Gradient Ward · Guard · Neutral

**Uncommon · cost 1 · O(n) · requires weakest-first order · up to 6 block**

Walk the sorted attack bolts from weakest to strongest. Whenever a bolt is stronger than the previous bolt, move 1 power from it into a 1-power ward. Stop at 6 block. The remaining attack power still flies. If the volley has no rising pair, turn 1 power from its weakest bolt into a ward instead.

This is a real payoff for sorting: the sorted gaps become defense, while the volley remains useful as an attack. It pairs with `Quick Sort`, `Introsort`, `Bubble Sort`, `Selection Sort`, `Heap Sort`, `Merge Sort`, or `Counting Sort`. It is also useful after `Salvo` once the combined volley is sorted. The cap and power transfer prevent it from creating a free second copy of the volley.

**Why it is not another Brace:** Brace chooses weak bolts to cover the largest incoming intent. Gradient Ward rewards a rising sequence and trades a little attack power for a capped block. It needs sorted input and has a smaller, predictable ceiling.

### Handoff Ward · Guard · Greedy

**Uncommon · cost 1 · O(n) · up to 6 block**

Every idle bolt made by `Task Scheduler` becomes a ward. Other bolts continue to attack. If there are more than 6 idle bolts, the extras remain attacks at their original power.

The default volley has repeated neutral elements, so Task Scheduler commonly inserts idle bolts even before an elemental build is assembled. Handoff Ward turns that deliberate spacing into defense. Against a volley with no idle bolts, it does nothing; that keeps the two-card combination legible and prevents it from becoming another unconditional Ward.

**Implementation note:** mark scheduler-created bolts with an `idle` flag in the Program bolt schema. Handoff Ward should read that flag rather than guess from power and element; Salvo can also create an ordinary 1-power neutral bolt.

## Targeted repairs to existing C cards

These are edits to existing cards, not additional draft choices.

| Existing card | Proposed repair | Why it earns a slot | Expected read |
| --- | --- | --- | --- |
| `Quick Sort`, `Introsort`, `Bubble Sort`, `Selection Sort`, `Heap Sort` | Keep their current algorithm and sorted output; add `Gradient Ward` as a shared consumer. Keep the card in its current paradigm so its algorithm still fits its theme. | A sort can now produce a defensive payoff even when the player has no sorted search card. In Search & Index, it can still set up the existing search cards. | C → B; payoff needs the pairing. |
| `Selection Sort+` | Keep weakest-first output; improve its work or give the selected bolts a small power bonus instead of reversing the order. | Its current strongest-first result is not sorted input for Binary Execute or Gradient Ward. | Avoids regressing the pairing on forge. |
| `Bogosort` | On a successful sort, give the first six bolts +1 power. If it reaches its shuffle cap, keep the best order and give the strongest of those bolts +3 instead. Preserve its turn-seeded behavior and volatile keyword. | Either outcome changes combat; success rewards an easy input, while failure still produces one visible payoff. The cap keeps its absurd work bounded. | C → B; volatile risk remains part of its identity. |
| `Heapify` | Keep the max-heap arrangement, but give the root bolt +2 power before it passes to the next card. | The strongest bolt is useful immediately, and the remaining heap order can still support later effects. This no longer relies on another card understanding heap layout. | C → B; the work and payoff stay modest. |
| `Task Scheduler` | Leave its scheduling effect intact and pair it with Handoff Ward. | Scheduling repeated elements creates idle bolts, which now have a clear second use. | C → B; depends on a second card. |
| `Coin Change (DP)` | Prefer an exact lethal subset. When it finds one, those bolts hit the front foe and the weakest unused bolts become wards up to the largest unresolved intent; unused power beyond that remains an attack. If there is no exact sum, use the smallest total that kills and send the remaining bolts to the next foe. | This gives exact change a distinct tradeoff against `Knapsack Strike`: exactness can turn spare bolts into defense, while the broader card is better for routing damage across foes. | C → B; exactness is now a defensive choice. |
| `Equal Partition` | Always find the two subsets with the closest total. The larger subset remains attacks; the smaller subset becomes wards, up to the largest unresolved intent, with any excess power staying as attacks. If the split is exactly even, keep the current +25% bonus to both sides. | It has an outcome on odd and uneven volleys, including the default seed. Exact equality remains the exciting high roll rather than the only time the card works. | C → B/A; it always offers attack plus possible block. |

The five pure sorters keep their original role and paradigm. Gradient Ward is a neutral card, so it is a possible partner outside Search & Index; the existing sorted-input attacks remain the stronger payoff when they are available. If playtests show the pairing is too hard to assemble, the next adjustment should be to increase Gradient Ward's neutral offer weight or move one sorter into Search & Index—not to make every sorter deal the same damage.

## Guard coverage by paradigm

| Paradigm | Guard options after this packet | What the player is protecting with |
| --- | --- | --- |
| Divide & Conquer | Existing `Boundary Guard` concept; `Gradient Ward` with a sorted volley | Local defenses from recursive subproblems, or a small block carved from sorted rises. |
| Search & Index | Existing `Lower-Bound Ward`; `Gradient Ward` | Retrieve a matching stored bolt for precise block, or trade sorted power differences for block. |
| Greedy | Existing `Brace` and `Greedy Ward`; new `Handoff Ward` | Spend weak bolts efficiently, accumulate a fast block threshold, or turn scheduled idle bolts into defense. |
| Brute Force | Existing `Exhaustive Ward`, `Branch and Bound`, and `Parity Lattice` concept; `Gradient Ward` | Choose exact block, trade width for a capped ward, or use sorting as a cheaper setup for defense. |
| Dynamic Programming | Existing `Knapsack Ward`, `Memo Ward`, and `Table Ward`; repaired `Coin Change` and `Equal Partition` | Convert exact leftovers, remembered damage, table growth, or one side of a balanced partition into block. |

This adds only two new guard cards. Each other paradigm already has at least one guard with a different job; the repairs make those existing guard paths more connected to the cards rated C.

## Example casts

### Sort into defense

Start with the seed `[3, 3, 3]`, then `Salvo` creates `[3, 3, 3, 1, 2, 3, 4, 5, 6]`. `Merge Sort` orders it weakest-first. `Gradient Ward` siphons one power from each strict rise, up to its 6-block cap; the rest remains an ascending attack volley. This is the defensive line. A Search & Index build can instead play `Merge Sort` directly into `Binary Execute` to spend the same ordering on precise kills.

### Schedule into defense

With three neutral bolts, `Task Scheduler` has repeated adjacent elements to separate, so it inserts idle bolts. `Handoff Ward` turns up to 6 power of those idle bolts into block. The original attacks still fly. Against a varied-element volley with no idle bolts, this combo pays less, as expected.

### Dynamic exact exchange

Against a 6-HP foe with bolts `[3, 3, 3]`, `Coin Change (DP)` sends two bolts for the exact kill and turns the spare 3-power bolt into a ward. `Knapsack Strike` would instead send that third bolt toward another foe. The player is choosing defense over extra target coverage.

Against the same volley, repaired `Equal Partition` finds groups of 3 and 6: the 3-power side becomes block and the 6-power side remains attacks. It still functions when an equal split does not exist.

## Review notes

- **Do not make the guards retroactive.** If a faster foe acts before the program resolves, these cards cannot prevent that hit. They still help with later intents and with casts that retain initiative.
- **Watch total attack-to-block conversion.** Gradient Ward and Handoff Ward cap at 6; the Dynamic conversions should cap block at unresolved incoming damage and leave unused power attacking.
- **Keep work visible.** Gradient Ward is linear after the sort; it does not erase the sort's complexity. Bogosort remains an intentional work-risk card.
- **Keep the no-op floor.** Bogosort, Coin Change, and Equal Partition now have a meaningful fallback. Handoff Ward remains intentionally conditional, with a common setup in the default neutral seed.
- **Check the forge identity.** Bubble Sort's Merge Sort upgrade stays valid; Selection Sort+ should not reverse direction if the card is intended to feed sorted consumers.
