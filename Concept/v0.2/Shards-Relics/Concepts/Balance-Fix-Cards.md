# Balance-fix card set · v0.2

**Status: implemented in the live Shardrun pool.** Ten cards were added, and the C-rated cards listed below received direct repairs. The card rules and three-language programs are in `game/content/packs/core/programs/cards/`; new card icon prompts, generated source hashes, and acceptance records are in [`program-icons-pass-11.json`](../../../../pipeline/art/program-icons-pass-11.json). This packet supersedes the earlier concept-only draft.

## Design target

Keep setup cards connected to a visible combat payoff while preserving their algorithm identity. The set adds five guards and five tools for ordering, recursion, enumeration, and tactical targeting. The direct repairs give several former C cards an outcome even when their ideal input is absent.

All ten new cards cost 1 mana and are Uncommon except **Parity Lattice**, which is Common. Effects retain a bounded amount of work, added bolts, or block. Guards only stop foes that have not acted yet; a slow Program cannot undo earlier damage.

## New cards

| Card | Pool · role | Rule | Icon concept |
| --- | --- | --- | --- |
| **Gradient Ward** | Neutral · Guard | On a weakest-first attack volley, each strict rise trades 1 power from the stronger bolt for 1 block, up to 6. With no rise, the weakest attack gives 1 block. Existing wards pass through. | An ascending crystal row shedding small amber facets into a cyan ward arc. |
| **Handoff Ward** | Greedy · Guard | Turns scheduler-created idle bolts into block, up to 6. Other attacks keep their power; every idle mark is cleared. | Crystal tokens move along a bronze scheduler rail and transfer across a clasp into a shield. |
| **Parity Lattice** | Brute Force · Guard | Every third attack in order becomes block, capped at 12. Existing wards do not count; stop before a conversion would exceed the cap. | Alternating bronze and teal lattice cells lock every third crystal into a ward facet. |
| **Collision Census** | Brute Force · Shape | Among the first 24 bolts, each attack gains +1 for each other attack matching power and element, up to +3. | Repeated crystal pairs are linked by short bronze threads; a lone unmatched crystal stays dim. |
| **Deadline Mint** | Greedy · Source | Adds one neutral bolt aimed at the foe with the fastest attack intent. Tie-break on total incoming damage. Power is damage × hits, capped at 8. | A bronze die press stamps an amber bolt toward a violet threat crystal beneath a fuse-like arc. |
| **Radix Sort** | Search & Index · Order | Stable weakest-first order in four base-16 passes, bounded for the game's 9,999 power limit. | Four bronze trays sort broad crystal pieces into a clean ascending row. |
| **Boundary Guard** | Divide & Conquer · Guard | Each recursive section with at least two attacks turns that section's weakest attack into block once. | A broad bronze branch carries a small shield at each fork while a central attack crystal continues. |
| **Median Pulse** | Divide & Conquer · Shape | Gives the median attack among the first 16 bolts in a section +2 power. Recurse applies it to each smaller section. | A middle crystal glows violet as a pulse passes through bronze index rings. |
| **Runoff Echo** | Search & Index · Strike | On up to three strict rises in a weakest-first volley, adds a 1-power echo carrying the stronger bolt's element and target. Original attacks remain. | A strong amber crystal leaves a smaller cyan echo through a bronze loop. |
| **Threat Index** | Search & Index · Guard | For up to three attacking foes, binary-searches the weakest-first volley for the smallest unused attack that covers that foe's intent, then converts it to block. Other attacks fly. | A bronze index selects a cyan guard crystal to intercept a violet incoming bolt. |

Artwork uses the built-in ChatGPT image generator. Each icon is an original transparent 1254×1254 PNG with the project's bronze hardware, dark plum outlines, and bold jewel colors. The manifest stores a distinct visual brief and full generation prompt per icon, plus output path, original hash, and review sizes. Source PNGs are in `game/assets/shardrun/card-<id>.png`.

## Direct repairs to former C cards

| Existing card | Live adjustment | Why |
| --- | --- | --- |
| `Heapify` / `Heapify+` | The max-heap root gains +2 / +3 power. | Heap layout now produces an immediate attack payoff while preserving the remaining heap order. |
| `Task Scheduler` / `Task Scheduler+` | Only inserted 1 / 2-power spacers carry explicit `idle` provenance. | Handoff Ward can identify scheduler rests without mistaking ordinary weak neutral attacks for rests. |
| `Bogosort` | A successful six-bolt sort grants +1 to those bolts; at its shuffle cap, the best attempt's strongest bolt gets +3. | Both success and bounded failure change combat, while its volatile, high-work identity remains. |
| `Selection Sort+` | Restored weakest-first order. | The forge now remains compatible with ascending-order consumers. |
| `Coin Change (DP)` / `+` | A bounded 0/1 bitset prefers exact lethal damage, then the lowest lethal total through 1,024 power; above that, a deterministic strongest-first fallback finds a lethal group. Weak spare bolts become block only after an exact kill, capped by attack intent among foes left alive after the search. | Exactness now trades extra target coverage for defense; spare attacks still route onward. The forge searches the first two foes in order and ignores their intents if its chosen groups kill them. |
| `Equal Partition` / `+` | Finds a closest split instead of no-oping. The larger side attacks; the smaller side becomes block up to incoming threat, with excess retained as attack. Exact equality alone earns +25% / +40%. | Odd and uneven volleys have a useful result without devaluing the exact-split bonus. Exact 0/1 DP is used through 1,024 total power; above that, a deterministic strongest-first/lighter-side greedy split bounds work. |

## Build lines and guard coverage

- **Sorting → defense:** `Merge Sort` or another weakest-first sorter → `Gradient Ward` converts selected rises into capped block. The same ordering can instead feed `Binary Execute`, `Range Query`, or `Two Pointers`.
- **Scheduling → defense:** `Task Scheduler` → `Handoff Ward` converts only inserted rest bolts, leaving ordinary attacks intact.
- **Enumeration → protection:** `Parity Lattice` converts a predictable fraction of a wide Brute Force volley, while `Collision Census` rewards duplicated attack shapes.
- **Recursive defense:** `Boundary Guard` converts the weakest attack locally at each recursive section; `Median Pulse` makes the middle attack of each section stronger.
- **Search → precision:** `Radix Sort` supplies bounded stable order; `Threat Index` trades the smallest attacks needed to cover up to three intents; `Runoff Echo` turns ordered rises into a few extra aimed hits.
- **Tactical source:** `Deadline Mint` reacts to the fastest visible attack intent and aims one capped bolt at that foe.
- **Dynamic exact exchange:** `Coin Change` and `Equal Partition` can turn selected attacks into a capped answer to incoming damage, while leaving unspent power available to attack.

The guard distribution now includes new cards in every paradigm except Dynamic, which gets more mileage from the repaired exact-conversion cards. Existing guards remain useful for different jobs: weakest-bolt assignment, exhaustive selection, stored-data lookup, recursive sections, and scheduled rest. Block is not retroactive, so timing and program tempo remain part of playing cleanly.

## Balance limits and next review

These effects are design-intuition changes and have not been run through balance playtests. In particular, check whether `Threat Index` is too reliable at removing several intents, whether recursion makes `Boundary Guard` scale too quickly, and whether cap values make `Parity Lattice` too efficient on large volleys. Review the exact/high-power `Equal Partition` split for player readability as well as outcome quality. If pair-dependent sort payoffs are difficult to draft, tune neutral offer weight or pool placement before adding generic damage to every sorter.

The implementation adds `idle` as short-lived Program bolt provenance. `Task Scheduler` creates it and `Handoff Ward` consumes it; ordinary bolt properties, damage resolution, and persisted battle state do not use it.
