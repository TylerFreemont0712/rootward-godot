# v0.2 Balance Pass: Program Cards

## Scope and rating key

This is an intuition-based audit of the active **Shardrun Program** card pool, in response to the concern that some algorithm cards do not earn their place in a build. It covers the 149 distinct draftable cards across the five paradigms and the neutral pool, plus their forge outcomes. Spellforge shards are a separate card pool and are outside this pass. I did not use probe outcomes to assign these ratings.

Ratings judge whether a card has a legible and worthwhile job in a normal run, considering its effect, work, mana, likely partners, and how often its setup is available.

- **A — clear job:** It changes damage, defense, targeting, resources, or a persistent engine in a way a player can plan around.
- **B — conditional job:** Its payoff is real, but depends on a particular input, partner, fight state, or follow-up card.
- **C — weak or unclear job:** It often spends a card slot and work without a payoff, duplicates a better option, or relies on a situation the pool rarely creates.

These are design ratings, not win-rate grades. A high-complexity card can still earn an A if its payoff is clear and worth the risk; a clever algorithm can earn a C if it has no combat consumer.

## Overall read

| Pool | Cohesion | Read |
| --- | --- | --- |
| Search & Index | High | The clearest engine: make or preserve sorted data, then spend it on precise attacks, defense, and stored bolts. |
| Divide & Conquer | Medium-high | Several strong split, recurse, and combine payoffs. Quick Sort and Introsort are orphaned utilities inside this pool. |
| Brute Force | Medium | Enumeration has a real volume-to-payoff identity, with both attack and defense answers. Its three pure sort cards lack an in-pool consumer. |
| Greedy | Medium | Many useful standalone tactical algorithms, but several order cards do not improve the Greedy attacks and the pool has few multi-card engines. |
| Dynamic Programming | Medium-high | The Table, fight memory, and exact optimization create viable builds. Some effects need a longer fight, and two exact/conditional cards are difficult to justify. |
| Neutral | High | Good shared sources, scaling, elements, and defense. The ordering cards are mostly setup tools whose value depends on what follows. |

The main balance problem is **not that every card should be complicated**. It is that some cards change the arrangement of bolts but no card in their own pool cares about that arrangement. Sorting is the clearest example, but the same test applies to any setup card: what payoff can it reach in the same program, and is that payoff better than playing a direct damage or guard card?

## Card-by-card ratings

Forge forms inherit the base card's rating unless called out below. “Plus” cards were reviewed as part of their base card's upgrade path rather than treated as independent draft choices.

### Divide & Conquer

**A — clear job:** `Divide`, `Merge Strike`, `Quickselect`, `Split`, `Base Case`, `K-Way Merge`, `Closest Pair`, `Counting Inversions`, `Fast Power`, `Karatsuba`, `Max Subarray (D&C)`, `Median of Medians`, `Skyline`, `Recursive Mirror`.

There is a coherent program here: split or expand the volley, then get paid for recursion, merging, ranking, or selecting. `Divide` benefits from the Recurse law; `Base Case` gives small halves a payoff; `Merge Strike` turns volume into a finisher. `Split` pairs well with `Amplify`, and `Counting Inversions` rewards feeding it a disordered volley. `Recursive Mirror` is also a practical source because it adds a lower-power copy while preserving targeting and element data.

**B — setup or matchup dependent:** `Recursion Tree`, `import math`, `import copy`, `Dutch Flag`, `Halve`, `Tower of Hanoi`, `Tail Call`.

These have useful but less obvious links. `Halve` is only valuable when the card after it benefits from running on each half; under Recurse it can set up `Base Case` or another recursion payoff. `import math` improves the core recursion cards for the whole fight. `import copy` adds attacks before strikes, so it is best with a strong finisher. `Dutch Flag` has its clearest payoff with the Partitioner focus; otherwise it mainly rearranges around the front foe's HP. `Tail Call` is a work-budget tool rather than a damage card and needs an expensive card immediately after it.

**C — weak in its home pool:** `Quick Sort`, `Introsort`.

Both sort the volley but do not damage, guard, or otherwise pay the player in this pool. There is no D&C card marked as needing sorted input. Quick Sort also has its worst case on already-sorted or equal-power inputs; its forge's median-of-three pivot fixes that reliability issue, but not the missing consumer. These are good candidates to move toward Search & Index or to give a distinct combat payoff.

### Search & Index

**A — clear job:** `Prefix Sum`, `Binary Execute`, `Hash Merge`, `Dedupe`, `Two Pointers`, `Hash Aim`, `import bisect`, `Run Length`, `Lookup`, `Two Sum`, `Interpolation Search`, `Bloom Filter`, `Consistent Hashing`, `Counting Sort`, `Cursor`, `Exponential Search`, `Lower-Bound Ward`, `Range Query`, `Write-Ahead Log`, `from sortedcontainers import SortedList` (B-Tree).

This is the most complete card strategy. `Prefix Sum` both increases bolt powers and makes them sorted, then `Binary Execute`, `Range Query`, or `Two Pointers` can spend that state. `Write-Ahead Log` stores weak bolts for `Lookup`, `Cursor`, or `Lower-Bound Ward`; `from sortedcontainers import SortedList` (B-Tree) extends that plan across the fight and carries its strongest stored bolts into the next one. `Hash Merge` and `Run Length` compress repeated elements, while `Hash Aim` and `Bloom Filter` reward matching enemy weaknesses. `import bisect` is a strong long-term alternative to repeatedly sorting: future source output arrives in order.

**B — specific setup or payoff:** `Bisect Insert`, `import collections`, `Ternary Search`.

`Bisect Insert` adds two fixed 7-power bolts and works best when the rest of the volley is already sorted. `import collections` is valuable when sources create bolts with matching element, target, and guard state, but can do little on a mixed volley. `Ternary Search` doubles a peak, so it needs a rise-then-fall sequence; the standard seed and common source cards do not reliably create that shape.

### Greedy

**A — clear job:** `Greedy Assign`, `Take Max`, `Sweep`, `Make Change`, `Huffman`, `Load Balance`, `Greedy Ward`, `import heapq`, `Chain Lightning`, `Activity Selection`, `Top-K`, `First-Fit Decreasing`, `Increase Key`, `Brace`, `Break`, `Fractional Knapsack`, `Job Sequencing`, `Minimum Arrows`, `Nearest Neighbour`, `Stock Trader`.

Most of these are good standalone answers to different tactical questions. `Greedy Assign` and `First-Fit Decreasing` conserve damage while finishing foes; `Load Balance` spreads it; `Sweep` is reliable crowd damage; `Minimum Arrows` carries unused power through the line. `Activity Selection` and `Job Sequencing` turn foe tempo into a decision. `Huffman` and `Take Max` compress volume into stronger attacks. `Stock Trader` has an easy source partner in `Salvo` or `Range` because both create rising sequences. `import heapq` is a real engine: attacks naturally consume the strongest bolts first for the rest of the fight.

**B — conditional job:** `Stable Partition`, `Boyer-Moore Vote`.

`Stable Partition` can put strong attacks first for a following `Break` or another order-sensitive strike, but several Greedy attacks sort or choose their own inputs. `Boyer-Moore Vote` is good when one element dominates; the default all-neutral seed qualifies, while an elemental mixed build may not.

**C — little payoff in this pool:** `Heap Sort`, `Heapify`, `Task Scheduler`.

The Greedy pool has no sorted-input attack, so `Heap Sort` spends work to rearrange bolts without creating damage. `Heapify` also only creates a heap order, and its strongest-first purpose is already covered persistently by `import heapq`. `Task Scheduler` separates repeated elements, but no Greedy card rewards that adjacency pattern; it may even add weak idle bolts. These three need a combat payoff or a different home.

### Brute Force

**A — clear job:** `Pairwise`, `Exhaustive Kill`, `Linear Search`, `Exhaustive Ward`, `import itertools`, `Branch and Bound`.

The clearest Brute Force line is to pay for volume or enumeration and then convert it into an exact answer. `Pairwise` turns a wide volley into many fused attacks; `Exhaustive Kill` picks a low-overkill lethal subset; `Exhaustive Ward` and `Branch and Bound` can prevent a hit. `import itertools` reduces the mana cost of several defining algorithms for the rest of the fight. The defensive cards mean the paradigm does have a no-hit route through timing and block, although it has no Integrity repair and its dedicated high-block answers are limited.

**B — payoff depends on volume or follow-up:** `Power Set`, `Cartesian Product`, `Backtracking`, `Nested Strike`, `All-Pairs Rank`, `Combinations`, `Grid Search`, `Meet in the Middle`, `N-Queens`, `Permutations`.

These have credible reasons to play, but their work or volume makes them poor defaults. The source cards (`Power Set`, `Cartesian Product`, `Combinations`, `Grid Search`, `N-Queens`) pair with `Amplify`, `Pairwise`, or the Enumerator focus; the strike cards are strongest against crowds or when there are enough bolts to make exhaustive choice worthwhile. `Meet in the Middle` is a more efficient version of the lethal-subset problem, but it still competes with the simpler `Exhaustive Kill`. That distinction should be visible on the card.

**C — no in-pool consumer:** `Bubble Sort`, `Bogosort`, `Selection Sort`.

These only arrange bolts. Brute Force has no card that needs a sorted volley, and `Linear Search` explicitly does not. Bubble Sort's forge into Merge Sort is a useful quality upgrade, but the base card is still a setup-only draw. Selection Sort's strongest-first forge is not sorted in the ascending sense required by binary search. Bogosort adds volatility and work without turning its order into a combat effect.

### Dynamic Programming

**A — clear job:** `Tabulate`, `Knapsack Strike`, `Kadane`, `LIS Strike`, `Knapsack Ward`, `Memo Strike`, `Memo Ward`, `Pascal Row`, `Rod Cutting`, `Table Ward`, `Unbounded Knapsack`, `from itertools import accumulate` (Bottom-Up).

This pool has several real paths: build the Table and convert it into block or future bolts; find a lethal subset; turn an increasing subsequence into attack plus defense; or reuse fight history for repeated attacks and block. `Tabulate` and `from itertools import accumulate` (Bottom-Up) are useful engine pieces, while `Memo Strike` and `Memo Ward` reward a fight that lasts long enough to establish history. `Sliding Window`, described below, is a good partner for a rising source such as Salvo.

**B — state or timing dependent:** `Fibonacci Surge`, `functools.cache`, `Sliding Window`, `Recurrence`, `Catalan`, `Edit Distance Aim`, `Grid Paths`, `Longest Common Subsequence`, `global total`, `Release`.

`global total` plus `Release` is a coherent fight-long engine: the first records landed damage, the second turns the total into a bolt. Each card alone is inert, and the payoff favors longer fights. `Recurrence`, `Table Ward`, and `Bottom-Up` all become more attractive once the Table has useful rows. `Longest Common Subsequence` is strongest after a good program has already landed and can be repeated. `Fibonacci Surge` has a particularly good forge: `fib-memo` changes the expensive naive recursion into a linear-time version. `Grid Paths` is a fixed 4×4 problem, so its exponential label sounds worse than its bounded 70-path workload; it produces a predictable 10-power bolt.

**C — weak or outclassed:** `Coin Change (DP)`, `Equal Partition`.

`Coin Change (DP)` only finds an exact sum for the front foe, while `Knapsack Strike` already finds the smallest available total that kills and can also be exact. I do not see a meaningful advantage for spending the same rare-card slot on the narrower version. `Equal Partition` has no effect unless the volley sum can be split evenly; the default three 3-power bolts fail that condition. Its successful case should either be more rewarding or have a useful fallback.

### Neutral

**A — clear job:** `Fork`, `Amplify`, `Kindle`, `Chill`, `Charge`, `Round Robin`, `Ward`, `Salvo`, `Literal`, `Repeat`, `Reduce`, `Generator`, `Higher Order`, `Ember Constant`, `Rime Constant`, `Spark Constant`, `Zip Ward`, `Read Input`, `Range`, `import operator`, `List Comprehension`.

These are the dependable foundation. Sources plus scaling (`Salvo`/`Fork`/`Generator` into `Amplify` or `import operator`) give the player a simple volume plan. Element cards answer weaknesses; `Ward` and `Zip Ward` supply defense; `Read Input` turns incoming intent into attack fuel. `Reduce` compresses a large volley into one stronger shot, and `Repeat` is a useful payoff when the strongest bolt is last.

**B — useful with the right input or partner:** `Merge Sort`, `Filter`, `import numpy`, `Bit Shift`, `Enumerate`, `Monte Carlo`, `Pop`, `Reservoir Sampling`, `Slice`, `Prefetch`, `Reverse`, `Rotate`, `Sort by Key`, `Swap`.

`Merge Sort` is excellent when followed by a sorted-input search, but does no damage on its own. `Filter` only pays when weak bolts are present; `Bit Shift` doubles small powers but wraps past 31. `import numpy` rewards a shape-heavy program by reducing its work, while `import operator` is the more direct power engine. `Sort by Key` followed by `Run Length` can compress same-element bolts when their target and guard state also match. `Swap` followed by `Repeat` moves a sorted volley’s strongest bolt to the end so Repeat copies it. `Reverse` and `Rotate` can change who receives which bolt under `Round Robin`, but the payoff is narrow. `Prefetch` is a delayed draw engine, not an immediate combat play.

## The sorting issue

Sorting is the strongest example of a card that looks strategically relevant but can feel like it does nothing. A sort preserves the volley and changes its order; if no later card cares about that order, the battle state is unchanged while the program still spends work (and sometimes mana). The current default seed `[3, 3, 3]` is already sorted, so a sort before a source has no visible effect. `Salvo` adds an ascending run after the seed, but the join from 3 down to 1 leaves the combined volley unsorted.

The cards that explicitly need sorted input are `Binary Execute`, `Interpolation Search`, `Exponential Search`, `Range Query`, and `Two Pointers`. `Prefix Sum` also produces sorted output while increasing bolt values, so it is often a better setup than a pure sort. `import bisect` is another compelling alternative because it keeps future source output ordered for the whole fight. This leaves pure sorters competing for a narrow window: they are most valuable when the player needs to preserve original bolt powers for a sorted consumer.

The pure sorts are distributed unevenly:

- **Search & Index:** `Counting Sort` has matching consumers; neutral `Merge Sort` is also available and its signature slot makes sense here.
- **Divide & Conquer:** `Quick Sort` and `Introsort` have no sorted consumer in their own pool.
- **Brute Force:** `Bubble Sort`, `Bogosort`, and `Selection Sort` have no sorted consumer in their own pool.
- **Greedy:** `Heap Sort` and `Heapify` have no sorted consumer, and strongest-first attacks are already supplied by `import heapq`.

I would fix the pairing before increasing sort damage across the board. Good options are to move orphan sorts into Search & Index, add a meaningful sorted-data payoff to their current paradigm, or give the sort itself a small and distinct secondary effect. The current descriptions should also surface the best follow-up cards: a visible “sets up Binary Execute / Range Query / Two Pointers” hint would teach the reason to play without turning every sort into a generic damage card.

## Strong combinations and actual build plans

| Plan | Cards | What the player is building |
| --- | --- | --- |
| Exact search | `Salvo` → `Prefix Sum` → `Binary Execute` | Grow a sorted, stronger volley, then use the smallest lethal bolts and reduce overkill. |
| Persistent sorted source | `import bisect` → `Salvo` / `Range` / `Repeat` → sorted consumer | Keep future generated bolts in order rather than paying for a sort each cast. |
| Index storage | `Write-Ahead Log` → `Lookup`, `Cursor`, `Lower-Bound Ward`, or `B-Tree` | Store weak bolts, then retrieve them for a kill, defense, future source, or next fight. |
| Brute-force volume | `Power Set` / `Combinations` / `Grid Search` → `Amplify` or `Pairwise` → `Exhaustive Kill` | Turn enumeration into a wider, stronger volley and use an exact lethal subset. This needs a close eye on work. |
| Recursive scaling | `Split` or `Divide` → `Base Case` / `Merge Strike` | Get paid for small subproblems or repeated combining; this is the most legible D&C engine. |
| Crowd scheduling | `Load Balance` or `Sweep`; `Minimum Arrows` against a line | Choose between spreading damage, attacking everyone, or carrying excess damage forward. |
| Persistent attack engine | `Generator` → shape cards with `import operator`; optionally `import numpy` | Add bolts every program, then make every shape stage stronger and cheaper in work. |
| Table engine | `Tabulate` → `Table Ward` / `Recurrence` / `Bottom-Up`; repeat a strong program for memo cards | Grow state over several turns and convert it into block, seed damage, or better repeated casts. |
| Fight-memory engine | `global total` → `Release`; repeat hits for `Memo Strike` / `Memo Ward` / `LCS` | Trade early setup for more value in a longer fight. Weaker against short encounters. |
| Greedy target order | `Stable Partition` → `Break` or an order-sensitive follow-up | Spend strong bolts first, stop when the front foe falls, then let the next stage handle what remains. |

These are real strategies, but they are not equally easy to assemble. Search & Index has the clearest explicit links. Brute Force and Dynamic have strong combos but often require multiple cards or a fight long enough to matter. Greedy has many cards with individual jobs, but fewer cards that visibly set up one another.

## Forge notes

- `Bubble Sort` → `Merge Sort` is a major quality increase: it removes the quadratic sort's worst growth. It still needs a sorted consumer to matter in a fight.
- `Fibonacci Surge` → `fib-memo` changes the work profile from exponential to linear while keeping the card's purpose. This is one of the clearest and most satisfying upgrades.
- `Quick Sort`'s median-of-three forge addresses its sorted-input worst case. Its in-pool payoff gap remains.
- `Selection Sort`'s forge changes it to strongest-first order. That may help a strike which respects order, but it is not ascending sorted input and should not be mistaken for a Binary Execute setup.
- `K-Way Merge`'s strongest-first forge trades the sorted result for an attack-oriented order. That is a meaningful choice only if the player can see which downstream strike benefits.
- Most other forge paths improve cost, caps, power, or number of targets. Those can be good upgrades without changing the base card's strategic role; an upgrade does not fix a card with no consumer.

## Recommended follow-up

1. **Give orphan sorters a purpose.** Move them to a pool with sorted consumers, add a consumer, or attach a modest secondary battle effect. Keep the sorts mechanically distinct rather than making them all deal generic bonus damage.
2. **Rework Coin Change or distinguish it from Knapsack Strike.** As written, the broader card already captures its best case.
3. **Give narrow no-op cards a floor.** `Equal Partition` and `Ternary Search` can miss their required shape; a small fallback benefit would make their draw less binary.
4. **Show follow-up information on setup cards.** Make “needs sorted,” “creates sorted,” “stores bolts,” and persistent import effects easy to connect when drafting and composing a program.
5. **Keep testing Brute Force defense separately from damage.** It has prevention tools (`Ward`, `Exhaustive Ward`, `Branch and Bound`) but no Integrity repair. That supports a clean-run skill route through block and kill timing, though the large ward effects are specialized rather than a repeatable defensive engine.
6. **Clarify Greedy's build identity.** Keep the strong tactical choices, but let more of them compound together. At present several are self-contained algorithms competing for the same slot rather than parts of a recognizable engine.

## Sources reviewed

- Active pool, seed, paradigm signatures, focus rules, and reward setup: [`programs.jsonc`](../../game/content/packs/core/programs/programs.jsonc).
- Card summaries, costs, roles, work classes, sorted-input metadata, and forge destinations: `game/content/packs/core/programs/cards/`.
- Draft candidate construction: [`program_draft.gd`](../../game/core/programs/program_draft.gd). It removes duplicate IDs when building candidates, so the repeated `global-total` and `release` entries in the Dynamic pool do not silently increase their draft odds.
