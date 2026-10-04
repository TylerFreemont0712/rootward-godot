# The Paradigm Update: the Artificer made whole

Written on 2026-10-04 at the player's request: *"create a whole setup and concept for everything that we'll do. Don't
implement anything yet … a full prompt + basic design idea that can be followed on a different session … you choose
a paradigm and then choose between 2-3 different 'paradigm specific' options … as many cards as you can think of …
a small description of what the card would look like for the image pipeline … Rewards also being more connected to the
paradigm … but having 0 way to actually get other paradigm cards seems debilitating … a shop or some type of new
concept to the shardrun … 1 extra fight for every layer … The money system should be attached to the amount of
enemies that are killed along with the difficulty … random relics might be bought … any other events you can think
of … GO all out."*

The diagnosis this builds on is `docs/PARADIGMS_AND_SECOPS.md` part 1. Sec Ops (its part 2) waits until after this.

**How to use this file.** Part A is the prompt: paste it into a fresh session. Part B is the design that prompt
builds. Every number in it is a first guess for the balance probe. Section B14 records the player's answers to the open
calls (2026-10-04).

---

# Part A: the prompt

Paste everything between the lines into a fresh session.

---

Read AGENT.md, CLAUDE.md, WIP.md, docs/PLAN.md, **docs/ParadigmUpdate.md (all of part B)**,
docs/PARADIGMS_AND_SECOPS.md (part 1), docs/SHARDRUN_DESIGN.md (sections 3, 4, 7 to 11), the ADRs 0012, 0016, 0017,
0018, 0021, 0026, 0046 and 0047, docs/CPP_CARDS.md, docs/TRANSLATION.md, pipeline/README.md and
pipeline/art/program-icons-pass-9.json. Then `git log --oneline -20` and `git status`. Say in one short message what you
are picking up, and proceed. The player's answers to the design's open calls are recorded in B14 (2026-10-04); follow
them.

## Goal

Make the Artificer (Vesper's program Shardrun) whole before any second class is built:

1. **Paradigms that play differently**: each of the five paradigms gets a **law** (a rule of its own), and after
   picking one the player picks one of its **three focuses**, each a second, narrower rule with a signature card.
2. **A large card bank built on those laws**: the 80 new cards of B8, each a real algorithm in Python, JavaScript
   and C++, with worked examples, a `+` refactor, Japanese and an art subject.
3. **Rewards tied to the paradigm, never sealed to it**: most offers come from the run's paradigm and focus, and
   other paradigms stay reachable through rewards, the shop and events.
4. **An economy**: **cycles**, earned per foe killed and scaled by the foe's kind, the layer and the difficulty.
5. **The Registry** (a shop): cards, random relics, services (`uninstall`, refactor, `pip install <paradigm>`).
6. **Issues** (events): about 30 choice rooms, several of which read the player's own cards.
7. **The map**: one more fight per layer, a fixed shop row, and event rooms, in the program run only.
8. **Scripts** (consumables): one-use commands kept in a belt of three, found after fights and sold at the Registry.

## Rules of the work

- Everything in AGENT.md applies: real execution, data-driven, pure seeded rules (`game/core/` has no nodes, no I/O,
  no `randf()`: all randomness through `Rng` from the run's seed), the preview is the cast, typed GDScript, tests first
  for `core/` and `sandbox/`, a screenshot of anything visible, small slices, a commit after each.
- **The program run only.** Spellforge and the card run keep their maps, rewards, relics and fixtures exactly as they
  are. Every change goes through the program run's own data (`packs/core/programs/programs.jsonc`) and
  `ProgramRules.catalog_for`, as ADR-0017 did for encounters. A test proves Spellforge's catalog and map are unchanged.
  If a shared rule must change, say so, re-record the fixtures on purpose (`ROOTWARD_GOLDEN=update`) and show the diff.
- **Old saves load.** New run-state fields (`focus`, `cycles`, `belt`, `index`, `dp`, `pending`, `boons`, ...) get defaults in
  `ShardrunSchemas` before anything uses them. A run started before this update plays on with no focus, no cycles
  and no shop rooms on its existing map.
- **Pip's Trial** (`core/trial_rules.gd`) sets a paradigm; give it a default focus, and keep the trial's rooms as
  they are.
- **Every card**: `<id>.jsonc` + `<id>.py` + `<id>.js` + C++ (`docs/CPP_CARDS.md`, then `scripts/build-cpp.sh`),
  worked examples that `scripts/validate.sh` runs in all three languages, a `<id>-plus` refactor read as a diff at the
  forge, a role, keywords where they apply, a `focus` tag, Japanese in `locales/ja/programs.jsonc`, and an art
  subject queued in a new pass manifest (B11). After changing card code: `scripts/mutants.sh` (the Mutator's census,
  ADR-0026).
- **New fields** (a card's `focus` and `splits`, a paradigm's `focuses` and `swap`, a relic tier `paradigm` and
  `focus`, an event's data, a script's data, the shop's data) go into `ProgramSchemas` with defaults before content uses them.
- **What the card code sees** grows in the program branch of `SpellRuns.input_for` only (B3.4), never in
  `ShardrunRules.shard_battle`, which Spellforge's code shares.
- Japanese: `scripts/locale.sh ja --missing` reports zero at the end of every slice that adds text. Interface strings go
  through `Text` (ADR-0047).
- ADRs: the next number is in `docs/decisions/README.md` (0048 at the time of writing). Proposed: one for paradigms
  and focuses, one for cycles, the Registry and scripts, one for Issues.
- Do not run ComfyUI and Blender at once. Never push.

## Slices, in order

Each slice ends with `scripts/test.sh` green, `scripts/lint.sh` clean, `scripts/validate.sh` passing, screenshots of
what changed, `docs/PLAN.md` ticked and a commit.

0. **Baseline.** Run the balance probe (`docs/research/balance-probe/`) as it is, on the same seeds the report will
   reuse: the win rate per paradigm, the share of each final deck that is the paradigm's own, and gold-standard
   numbers for B13. Write them into the ADR draft. No game change.
1. **Focuses as data, and the pick.** The run state's `focus`; `programs.jsonc` paradigms gain `focuses`,
   `swap` (one basic swapped) and their law relics; the draft asks for a focus right after the paradigm
   (`pick-focus`), and its signature joins the deck. The picker screen (B2.3). History, the end screen and the git
   log name the focus (`feat(greedy/sprint): ship it`). Laws and focuses are relics of tier `paradigm` and
   `focus`, never loot, shown in the relic bar. Implement the laws that need no new primitive first (Greedy, Brute
   Force and their focuses), with tests.
2. **The fight state the laws need.** The Index (a sorted list in `battle`, bolts flagged `stash`), the Table
   (`battle.dp`, written after each program lands), what the code sees (B3.4), and the remaining laws (DP, Search),
   with tests that the preview equals the cast for each.
3. **The body slot (Recurse).** A card marked `splits` makes the next card run once on each half (each quarter under
   Deep Recursion), in the harness for all three languages, drawn in the code panel as real code
   (`left, right = f(left), f(right)`), measured as two runs on half n. Tests first, including the Mutator, the
   Unreachable's cut and the Race Condition Imp with a split in the program. This is also the primitive Sec Ops' `try:`
   will reuse; keep it general (a card that takes the next card as its body).
4. **Rewards** (B4): shares by paradigm, focus and other paradigms; one own card guaranteed; an elite's fourth
   card from another paradigm; rare pity; skip pays cycles. Tests over many seeds for the shares.
5. **Cycles** (B5): earned per kill as the formula says, shown in the HUD and as an itemised receipt on the reward
   screen, kept in the run state and history. Tests for every term of the formula.
6. **The map** (B6): the program run's layers get two more rows (one fight, one fixed shop), event rooms by weight,
   the new room kinds in `ShardrunMap` and on the map scroll. A test that Spellforge's map is unchanged.
7. **The Registry** (B7): stock drawn from the seed, prices, purchases, services, the screen and its keeper.
   Screenshots of a full shop, a purchase, `uninstall`, and an empty wallet.
8. **Scripts** (B12): the belt in the run state and the fight HUD, scripts as data, their effects as rules (each one
   reflected in the preview the moment it's used), drops after fights, the Registry's script shelf. Tests for every
   effect kind and for the preview after a script. Screenshots of a full belt, a script used mid-turn and its preview.
9. **Issues** (B9): the event framework as data (an event is choices, each a list of effects), the screen, then the
   events in three batches (the simple ones, the ones that need deferred state, the ones that read the player's code,
   with their stakes).
10. **Cards, a paradigm at a time** (B8): Greedy, Brute Force, Dynamic Programming, Search & Index, Divide & Conquer,
    then the neutral cards. Each batch has its code in three languages, examples, `+` refactors, Japanese, art
    subjects queued, the mutants census, and screenshots of the forge diff for one card.
11. **Relics** (B10): the new relics and their effect kinds, with tests.
12. **Art** (B11): pass 10 of the program icons for every new card, plus focus emblems, script icons, the Registry,
    its keeper, the event pictures, and map icons. Review boards, accepted originals, screenshots in game.
13. **Balance** (B13): the probe taught the new rooms (it may skip events and shop at first, and use scripts by a
    simple rule), the report in the ADR, tuning in data only, and screenshots of a whole run.

## Verify at the end

- `scripts/test.sh`, `scripts/lint.sh`, `scripts/validate.sh`, `scripts/locale.sh ja --missing` (zero),
  `scripts/mutants.sh` current, `scripts/build-cpp.sh` current.
- Screenshots: the paradigm and focus picks, a fight under each of the five laws (the Index and the Table drawn),
  Recurse in the code panel, the reward screen with its receipt, the map with a shop and events, the Registry, a
  script used mid-turn, three events (one that reads code, answered wrong), the forge diff of a new card, a new card's art in a hand. In both Python and C++, and
  once in Japanese.
- The balance report against the baseline of slice 0.
- Report faithfully: what changed, what was verified and how, what was skipped, the numbers, and what is next.

## Ask the player only

Anything that would change what the player sees beyond this file, or a call B14 doesn't settle.

---

# Part B: the design

## B1. The run, after the update

```
title → Adventure → language, difficulty
  → pick a paradigm (3 of 5 offered)          its law joins the relic bar, its 2 signature cards the deck
  → pick a focus (all 3 of that paradigm)  its rule joins the relic bar, its signature card the deck
  → the draft (5 packs of 3)                  weighted to the paradigm and focus
  → Layer 1: the Salvage   10 rows: fights, elites, issues, a forge, a treasure, the Registry, a rest, the guardian
  → Layer 2: the Heap      11 rows
  → Layer 3: the Kernel    11 rows
  → Layer 4: the Root      11 rows
```

A starting deck is the 8 basics (one swapped by the paradigm) + 2 paradigm signatures + 1 focus signature = 11.

## B2. Paradigms, laws and focuses

### B2.1 The five laws

A law is a relic of tier `paradigm` given at the pick. It never drops and can't be removed.

| Paradigm | Law | Rule | The question it asks |
|---|---|---|---|
| **Greedy** | *Local Optimum* | A foe your program kills **with Initiative** pays 1 mana next turn (at most 2). | how fast can I kill, now? |
| **Brute Force** | *Throw Hardware At It* | Every full 256 operations of the program's work adds 1 power to each attack bolt as it lands. A timeout lands nothing. | how close to the budget do I dare go? |
| **Dynamic Programming** | *The Table* | Each program's landed damage is written to `dp[t]`. From turn 3, the seed gains a bolt of `(dp[t-1] + dp[t-2]) // 4`. | what do I build now for later turns? |
| **Search & Index** | *The Index* | Power the program would waste (overkill, bolts at the fallen, bolts left over, and bolts flagged `stash`) is `insort`ed into a sorted index of at most 8 bolts that lasts the fight. Each program's seed takes the index's strongest bolt. | which exact bolt for which foe? |
| **Divide & Conquer** | *Recurse* | The card right after a card marked `splits` runs once on each half, and the halves rejoin. | how do I shape this into subproblems? |

The basic each paradigm swaps (`swap` in `programs.jsonc`):

| Paradigm | Out | In |
|---|---|---|
| Greedy | Round Robin | Sweep |
| Brute Force | Amplify | Bubble Sort |
| Dynamic Programming | Ward | Knapsack Ward |
| Search & Index | Kindle | Merge Sort |
| Divide & Conquer | Fork | Split |

### B2.2 The fifteen focuses

A focus is a relic of tier `focus` given at the second pick, plus one signature card. Its `tag` names the cards
it favours: rewards weight them (B4) and the cards in B8 carry the tag.

| Paradigm | Focus (`tag`) | Its rule | Signature | Plays like | Teaches |
|---|---|---|---|---|---|
| Greedy | **Sprint** (`sprint`) | A program of three cards or fewer counts 25% less work. | Activity Selection | tiny cheap programs every turn, always first, kill chains for mana | short-circuiting, `break`, streaming |
| Greedy | **Priority Queue** (`heap`) | `import heapq` is in force from the first turn of every fight, free. | Top-K | a few huge bolts, strongest first | heaps, priority queues, heapify in O(n) |
| Greedy | **Scheduler** (`schedule`) | A program that hits every living foe gives each bolt +1. | First-Fit Decreasing | spreading bolts over crowds exactly | scheduling, bin packing, interval problems |
| Brute Force | **Enumerator** (`enumerate`) | Brute-force sources make bolts with +1 power; a volley may hold 192 bolts. | Cartesian Product | floods of hundreds of bolts | combinatorics, how fast a search space grows |
| Brute Force | **Pruner** (`prune`) | A program never times out: the card that would cross the budget is skipped instead (and the cards after it still run). | Backtracking | exhaustive cards played safely, close to the line | pruning, branch and bound, graceful degradation |
| Brute Force | **Overclocker** (`heavy`) | The budget is 50% larger; a timeout costs 5 Integrity. | Nested Strike | the slowest, heaviest programs, all risk | the cost of quadratic code, and what more hardware does and doesn't buy |
| Dynamic Programming | **Memoiser** (`memo`) | `functools.cache` is in force from the first turn: a card that already ran this fight does no work. | Memo Strike | repeating programs that grow cheaper | top-down DP, memoisation |
| Dynamic Programming | **Tabulator** (`table`) | The Table's bolt starts on turn 2 and is `(dp[t-1] + dp[t-2]) // 3`. | Recurrence | slow first turns, overwhelming late turns | bottom-up DP, recurrences |
| Dynamic Programming | **Optimiser** (`exact`) | A kill with no overkill writes double into the table and gives 2 block. | Coin Change (DP) | exact kills, never a point wasted | optimal substructure, knapsack and coin problems |
| Search & Index | **Indexer** (`index`) | The index holds 16, and the seed takes its two strongest. | Lookup | banking overkill, then spending it precisely | indexes, sorted containers |
| Search & Index | **Hasher** (`hash`) | A bolt that lands on a foe's weakness gains 2 power. | Two Sum | element maps and O(1) lookups | hash maps, sets, Bloom filters |
| Search & Index | **Bisector** (`bisect`) | A volley that is sorted when a strike reads it gives each of that strike's bolts +1. | Interpolation Search | sort once, search many times | binary search and its relatives |
| Divide & Conquer | **Deep Recursion** (`deep`) | Recurse goes one level deeper: the card after a split runs on each quarter. | Base Case | towers of small cards on small pieces | recursion depth, base cases |
| Divide & Conquer | **Merger** (`merge`) | When halves rejoin, every bolt gains 1. | K-Way Merge | splits and merges in a loop | the combine step, merge sort's half of the work |
| Divide & Conquer | **Partitioner** (`pivot`) | A card tagged `pivot` marks its pivot bolt, which lands doubled on the toughest foe. | Dutch Flag | partitions, selection, quick sort | partitioning, pivots, selection in linear time |

### B2.3 The pick, on screen

After the paradigm is chosen, the draft panel turns into three tall focus cards side by side: the focus's
emblem (B11), its name and tag in the paradigm's colour, the rule in a sentence, the signature card's face below, and
one line of "plays like". All three are offered: the choice is the point. A run that reaches the end shows both on
the end screen and in the git log (`feat(greedy/sprint): ship it`).

## B3. The laws as rules

### B3.1 Effect kinds

| Law or focus | Effect kind in `ProgramRelics` | Hook |
|---|---|---|
| Local Optimum | `kill-initiative-mana` | after landing; the next-turn mana hook exists |
| Sprint | `small-program-work` | in `stages`: factor on total work when the program has ≤ 3 cards |
| Priority Queue, Memoiser | `fight-import` (an import in force from turn 1) | at fight start: add the module to `battle.imports` |
| Scheduler | `full-spread-power` | in `resolve`, before damage: if the targets cover every living foe |
| Throw Hardware At It | `work-power` | in `resolve`: power += floor(work / 256) |
| Enumerator | `source-power`, `max-bolts` | on source stages, and the cap |
| Pruner | `prune-not-timeout` | in `stages`: the first card that would cross the budget is dropped from the run (shown greyed in the code, `# pruned`) |
| Overclocker | `budget-factor`, `timeout-integrity` | `budget`, and after a timeout |
| The Table, Tabulator, Optimiser | `table`, `table-from`, `table-divisor`, `exact-kill-table` | after landing (write) and in `seed` (read) |
| The Index, Indexer | `index`, `index-size`, `index-seed` | in `resolve` (waste and `stash` in) and in `seed` (strongest out) |
| Hasher | `weak-flat-bonus` | in `resolve` |
| Bisector | `sorted-strike-power` | per strike stage: whether its input was sorted (the harness knows `given`) |
| Recurse, Deep Recursion | the body slot, `recurse-depth` | in the harness (B3.3) |
| Merger | `rejoin-power` | in the harness when halves rejoin |
| Partitioner | `pivot-mark` | the pivot card flags one bolt `pivot: true`; `resolve` doubles it and aims it at the toughest foe |

Everything is applied in `ProgramRules.play`, which both the preview and the cast run, so the preview stays the cast.

### B3.2 The Index and the Table as fight state

- `battle.index`: a sorted array of bolts (`{power, element}`), capped (8, or 16 for the Indexer), the strongest kept
  when it overflows. In: waste, and any bolt a card returns with `stash: true`. Out: the seed's strongest (one, or two
  for the Indexer) and any bolt a card returns with `from_index: true`. The rules check that each `from_index` bolt
  really is in the index and remove it; a card can't create one.
- `battle.dp`: an array of ints, one per program run this fight (its landed damage). Read-only to cards.
- `battle.hits`: per foe, how many of your bolts landed on it this fight (for the memo cards).
- `battle.last_volley`: the powers of the last program's landed attack bolts (for LCS).
- All of them are reset when a fight starts, saved in the run state, and drawn: the Index as a short shelf of crystals
  beside the code panel, the Table as a column of numbers under it (`dp = [12, 18, 30, …]`).

### B3.3 The body slot

A card with `"splits": true` (Divide, Split, Halve, Merge Sort, Quick Sort, Quickselect, Median of Medians, Introsort,
Dutch Flag, Counting Inversions, Closest Pair, Skyline, Max Subarray D&C, Karatsuba) leaves a volley that the next card
receives as halves. The harness runs that card twice, on `bolts[:ceil(n/2)]` and `bolts[ceil(n/2):]`, and joins the
results; under Deep Recursion it runs four times on the quarters. Work is measured per run on its own n. The code panel
writes it as code:

```python
def main(bolts, battle):
    bolts = split(bolts)
    half = (len(bolts) + 1) // 2
    left, right = bolts[:half], bolts[half:]
    left, right = base_case(left, battle), base_case(right, battle)   # Recurse
    bolts = left + right
    bolts = round_robin(bolts, battle)
    return bolts
```

A splitting card as the last card does nothing extra. A splitting card followed by another splitting card recurses
again only under Deep Recursion. The primitive is general (a card that takes the next card as its body) so that Sec
Ops' `try:` and `if` can use it later.

### B3.4 What the card code sees (program run only)

Added in `SpellRuns.input_for`'s program branch:

```python
battle = {
    "turn": 3,
    "me": {"hp": 41, "max": 60, "block": 4, "mana": 3},
    "foes": [
        {"name": "Null Wraith", "hp": 14, "max": 20, "shield": 0, "weak": ["fire"], "resist": [],
         "intent": {"kind": "attack", "damage": 6, "hits": 1, "tempo": 40},   # new
         "hits": 2},                                                          # new: bolts landed this fight
    ],
    "imports": ["heapq"],
    "globals": {"total": 31},
    "index": [{"power": 4, "element": "none"}, {"power": 9, "element": "fire"}],   # new, sorted
    "dp": [12, 18],                                                               # new
    "last_volley": [3, 5, 9],                                                     # new
}
```

New bolt fields a card may return: `stash` (into the index), `from_index` (taken out of it), `pivot` (Partitioner).

## B4. Rewards

The rule: **most of what's offered is yours; something else is always reachable.**

| Where | Cards offered | From |
|---|---|---|
| Fight | 3 | each slot drawn: 50% own paradigm (focus-tagged cards ×2 inside it), 30% neutral, 20% another paradigm; **at least one own card** |
| Elite | 4 | the fight's 3, plus a fourth **from another paradigm**, one rarity up |
| Guardian | 3 | rare or better, own paradigm or neutral |
| Draft packs | 3 a pack | own paradigm ×2, focus ×3 inside it, neutral ×1 (as now, plus the focus tilt) |

- **Rarity pity**: each fight reward without a rare adds 3% to the next one's rare chance, reset when a rare is
  offered (Slay the Spire's rule).
- **Skip pays**: skipping a card reward gives 10 cycles × the layer. Keeping a lean deck is a real plan, and it's
  rewarded.
- Other ways to reach other paradigms: the Registry always stocks one (B7), `pip install <paradigm>` buys one on
  purpose, and the events Pair Programming, Conference Talk, Cross-Compilation and Paradigm Shift (B9).
- Data: `programs.jsonc` `rewards: {fight: {own, neutral, other}, focus_weight, elite_extra, pity, skip_cycles}`.

## B5. Cycles: the money

### B5.1 Earning

Cycles come from what you kill, scaled by how hard the kill was:

```
cycles for a kill = floor(base(kind) × layer factor × difficulty factor) + bonuses
```

| Term | Values |
|---|---|
| base(kind) | an ordinary foe 6, an elite 16, a guardian 45, **a summoned foe 1** (Malloc's heap blocks, Fork Bomb copies: no farming) |
| layer factor | Salvage 1.0, Heap 1.25, Kernel 1.5, Root 1.75 |
| difficulty factor | Beginner 1.0, Programmer 1.25 |
| exact kill (no overkill) | +1 |
| kill with Initiative | +1 |
| a fight won taking no damage | +5 once ("clean build") |
| a fight won in one program | +3 once ("one-liner") |

Plus a treasure room: 20 × the layer, beside its relic. On Programmer the same fight pays a quarter more, because it
is harder. A rough Salvage on Beginner: 6 fights × 2.5 foes × 6 ≈ 90, an elite or two ≈ 40, the guardian 45, bonuses
≈ 25: **about 200 by the end of layer 1**, 250 to 300 a layer after. The probe settles it (B13).

### B5.2 Showing it

- A cycles counter in the run HUD beside Integrity (an icon of a tiny bronze clock gear, `⟳`), counting up in the
  reward screen.
- The reward screen's receipt reads like a profiler:

  ```
  $ time ./main
  Null Wraith     killed   6 × 1.25 ×1.0   =  7
                  exact                    +  1
  Tally Wisp      killed   6 × 1.25 ×1.0   =  7
                  Initiative               +  1
  clean build                              +  5
  ─────────────────────────────────────────────
  cycles                                     21   (total 164)
  ```
- History: a run's cycles earned and spent go into `history.jsonl` and the run's `git show`.

## B6. The map

Program run only, through a `map` override per layer in `programs.jsonc` that `catalog_for` merges (Spellforge's
`run.jsonc` layers are untouched):

| Layer | Rows now → after | Fixed rows after |
|---|---|---|
| Salvage | 8 → 10 | 0 fight, 1 fight (new), 4 treasure, 7 Registry (new), -1 rest |
| Heap | 9 → 11 | 0 fight, 1 fight (new), 4 treasure, 8 Registry (new), -1 rest |
| Kernel | 9 → 11 | the same as the Heap |
| Root | 9 → 11 | the same as the Heap |

Weights for the free rows: fight 40, elite 16, **issue 18**, rest 10, forge 10, **shop 4** (a rare second Registry).
`ShardrunMap.ROOM_KINDS` gains `shop` and `issue`; `NO_REPEAT` gains `shop`. On the scroll: a small crate with an owl
stamp for the Registry, and a `!` in a circle (an open issue) for an event. The fixed Registry row sits two rows before
the guardian's rest, so you reach it with a layer's cycles in hand and spend them before the guardian.

## B7. The Registry (the shop)

*A tall cabinet of brass drawers in a quiet corner of the machine, each drawer labelled with a version number. Its
keeper is **Semver**, a small round brass owl with a monocle and a stamp, who stamps every purchase `v1.0.0` and
blinks.*

### B7.1 Stock (drawn from the run's seed and the room, the same on every visit and load)

| Shelf | Count | What | Price |
|---|---|---|---|
| Cards | 5 | 2 own paradigm (one focus-tagged), 1 neutral, **1 another paradigm**, 1 any | common 50, uncommon 75, rare 150; one card **on sale** at half |
| Relics | 3 | random, by tier weight: common 40, uncommon 34, rare 20, epic 5, **legendary 1** | common 110, uncommon 160, rare 230, epic 320, legendary 450 |
| Services | 3 | `uninstall` (remove a card), `refactor` (forge a card's `+`), `pip install <paradigm>` | 75 (+25 each use in the run), 90, 60 |
| Scripts (B12) | 3 | consumables, by rarity | 30 to 90 |

`pip install <paradigm>`: choose any paradigm; three random cards of it are shown, and you take one. That makes
reaching another paradigm a deliberate choice.

### B7.2 Rules

- Prices are data (`programs.jsonc` `registry`), with ±10% jitter from the seed so a shop isn't a price list.
- Bought items leave the shelf; nothing restocks. A relic's tier colour and its tooltip are shown before buying.
- A cursed relic is never sold. The relic pool excludes `paradigm` and `focus` tiers and anything held.
- The commands: `buy {shelf, index}`, `service {kind, card_id?}`, `leave`. All pure, in `core/programs/program_shop.gd`,
  all tested (can't buy past the wallet, prices rise for `uninstall`, a bought card joins the deck, a relic's effect
  applies at the next fight).

### B7.3 On screen

The cabinet fills the stage; Semver sits on the top. Cards are full card faces (P2-37's fix: rewards should look like
the cards you'll hold), relics on velvet trays with their tier glow, services as three brass drawer handles with their
names in code (`uninstall`, `refactor`, `pip install`). The wallet sits in the corner, counting down when you buy.
Semver's lines (Japanese too): "Every package is signed. Mostly.", "Breaking changes are extra.", "No refunds after
`git push`."

## B8. The card bank: 80 new cards

Each card lists: **name** (`id`) · role · mana · rarity · class · focus tag (★ = that focus's signature). Then
what it does, what it teaches, its `+` refactor, and an **art** subject for the image pipeline (B11's shared prompt is
prepended; subjects follow pass 9's style: bronze fittings, faceted crystals for bolts, one bold readable silhouette,
no letters or numerals).

### B8.1 Greedy (15)

**Sprint**

- **Activity Selection** (`activity-selection`) · strike · 1 · uncommon · O(n log n) · sprint ★
  Sorts the foes by how soon their intent lands (tempo, quickest first) and pours bolts, strongest first, into each
  until it falls. The jabbers die before they act. *Teaches*: earliest-deadline-first scheduling. *+*: ties go to the
  foe with the bigger intended damage.
  *Art*: a bronze hourglass on its side with three crystal bolts racing out of its narrow neck in a row, the first one
  bright amber, the others cyan; a short golden arrow ahead of them.
- **Break** (`break`) · strike · 0 · common · O(k) · sprint
  `for bolt in bolts: hit the front foe; if it falls: break`. The bolts after the kill are kept, unaimed, for the next
  card, and only the bolts used count as work. *Teaches*: `break`, and stopping a loop early. *+*: aims the leftovers
  at the next foe.
  *Art*: a row of four cyan crystals with a broad bronze bar slammed down between the second and third, the first two
  glowing amber; a small spark where the bar lands.
- **Job Sequencing** (`job-sequencing`) · strike · 1 · uncommon · O(n log n) · sprint
  Each foe is a job: its deadline its intent's tempo, its profit the damage it intends. Bolts go first to the foe
  that would hurt you most among those you can still beat to the punch. *Teaches*: job sequencing with deadlines.
  *+*: also ranks by profit per HP.
  *Art*: three small brass tags on hooks in a line, the middle tag larger and gilded, a cyan crystal bolt pinned to
  it with a ribbon.
- **Boyer-Moore Vote** (`boyer-moore`) · shape · 0 · common · O(n) · sprint
  One pass, one counter: the volley's majority element is found without counting them all, and every bolt becomes that
  element, 1 stronger. *Teaches*: streaming algorithms, O(1) memory. *+*: 2 stronger.
  *Art*: a bronze ballot box with three crystals dropping in, two amber and one cyan, and a single large amber crystal
  rising out of its slot.
- **Stock Trader** (`stock-trader`) · shape · 1 · uncommon · O(n) · sprint
  Walks the volley; every rise from one bolt to the next is profit, and the sum of the rises becomes a new bolt at the
  end. A rising volley (Salvo) pays well. *Teaches*: summing the positive differences, the greedy proof of "buy every
  rise". *+*: the profit bolt is the element of the strongest bolt.
  *Art*: a zig-zag bronze line chart made of rods, each rising segment capped by a small amber crystal, a large amber
  crystal at the top right end.
- **Brace** (`brace`) · guard · 1 · common · O(n log n) · sprint
  Turns the weakest bolts into block, one by one, until the block covers the biggest incoming intent: the bolts that
  matter least are sacrificed. *Teaches*: greedy covering, smallest first. *+*: covers the sum of every intent.
  *Art*: a small bronze kite shield made of three stacked pale cyan crystal shards, the smallest at the top, a bold
  rim around them.

**Priority Queue**

- **Top-K** (`top-k`) · shape · 1 · uncommon · O(n log k) · heap ★
  A min-heap of size 4 keeps the four strongest bolts; every other bolt is fused into the weakest of the four. Nothing
  is lost, everything is focused. *Teaches*: top-k with a bounded heap. *+*: k = 5.
  *Art*: a bronze pyramid stand with four cut crystals on its tiers, the top one largest, a stream of tiny cyan shards
  being poured into the lowest crystal.
- **Heapify** (`heapify`) · order · 0 · common · O(n) · heap
  Bottom-up heapify: the strongest bolt comes first and the rest are in heap order (not sorted), in linear time,
  which is cheaper than sorting. *Teaches*: building a heap is O(n). *+*: also +1 to the root.
  *Art*: a small bronze binary tree of seven sockets, the largest amber crystal in the top socket, smaller cyan crystals
  below, one curved arrow showing a crystal sifting down.
- **Increase Key** (`increase-key`) · shape · 1 · uncommon · O(log n) · heap
  The weakest bolt is raised to one less than the strongest, then sifts up into place. *Teaches*: increase-key on a
  priority queue. *+*: raised to equal the strongest.
  *Art*: a small cyan crystal on a bronze lift platform rising beside a tall amber crystal, a broad upward arrow
  beneath it.
- **Heap Sort** (`heap-sort`) · order · 1 · common · O(n log n) · heap
  Sorts weakest first in place, using no extra memory, and its work never degrades (unlike Quick Sort's worst case).
  *Teaches*: heap sort, in-place sorting. *+*: costs 0.
  *Art*: a bronze funnel shaped like an upside-down tree, crystals entering at the top in a jumble and leaving at the
  bottom in a neat row from small to large.

**Scheduler**

- **First-Fit Decreasing** (`first-fit-decreasing`) · strike · 1 · uncommon · O(n·m) · schedule ★
  Bin packing: bolts, strongest first, each go to the first foe they don't overkill by more than 2; leftovers go to
  the front. *Teaches*: first-fit decreasing, a near-optimal heuristic. *+*: allows overkill up to 1.
  *Art*: three bronze bins of different heights side by side, each filled almost to the brim with stacked crystals,
  one amber crystal dropping into the fullest one.
- **Fractional Knapsack** (`fractional-knapsack`) · shape · 1 · common · O(n log n) · schedule
  Cuts the strongest bolt into exactly the front foe's HP plus a remainder, then the next strongest for the next foe.
  *Teaches*: greedy is provably optimal when you may take fractions (DP's Knapsack Strike is the 0/1 case where it
  isn't). *+*: the remainder gains 1.
  *Art*: a large amber crystal sliced cleanly in two by a bronze cleaver, the bigger half slotted into a small leather
  knapsack, the smaller half floating beside it.
- **Minimum Arrows** (`minimum-arrows`) · strike · 1 · uncommon · O(n log n) · schedule
  Each bolt, strongest first, pierces: what it doesn't spend on one foe flies on into the next, until it runs out.
  *Teaches*: the minimum-arrows-to-burst-balloons greedy. *+*: pierces with +1 at each foe.
  *Art*: one long bronze-fletched crystal arrow passing through three floating soap-bubble orbs in a line, each orb
  bursting into shards.
- **Nearest Neighbour** (`nearest-neighbour`) · strike · 0 · common · O(n·m) · schedule
  Each bolt flies at the foe whose HP is closest to its power. Fast, usually good, sometimes silly. *Teaches*: the
  nearest-neighbour heuristic. *+*: prefers foes it would kill.
  *Art*: a bronze compass rose with one cyan crystal at its centre and a gold needle pointing at the nearest of three
  small dots around it.
- **Task Scheduler** (`task-scheduler`) · order · 1 · uncommon · O(n) · schedule
  Reorders the volley so no two bolts of the same element are neighbours; where that's impossible, a 1-power idle bolt
  goes between them. *Teaches*: cooldown scheduling. Pairs with Alternator-style relics and Chain Lightning. *+*: idle
  bolts are 2-power.
  *Art*: a bronze conveyor with crystals alternating amber, cyan, violet, amber, cyan, and a tiny empty grey gem in one
  gap.

### B8.2 Brute Force (12)

**Enumerator**

- **Cartesian Product** (`cartesian-product`) · source · 2 · rare · O(n·m) · enumerate ★
  For every pair of (bolt, foe), a new bolt of half that bolt's power aimed at that foe: `itertools.product`. *Teaches*:
  the product of two sets. *+*: costs 1.
  *Art*: a bronze grid frame of three by three sockets, a crystal glowing in every socket, rows tinted amber and columns
  tinted cyan where they cross.
- **Combinations** (`combinations`) · source · 1 · uncommon · O(C(n, 3)), cap 7 · enumerate
  Every 3-bolt combination of the first seven bolts becomes one bolt of its sum / 2 (35 bolts). *Teaches*:
  combinations against permutations, n choose k. *+*: sum / 2 + 1.
  *Art*: three crystals bound together by a bronze triangle clasp, with a ghostly fan of other triangle clasps behind
  it.
- **Permutations** (`permutations`) · strike · 2 · rare · O(n!), cap 6 · enumerate
  Tries every order of up to six bolts dealt round robin over the foes and keeps the order with the most kills.
  *Teaches*: factorial growth; why 6! is fine and 12! is not. *+*: ties go to the least overkill.
  *Art*: a bronze revolving drum with six crystal chambers, spun mid-motion, the crystals blurring into a fan.
- **Grid Search** (`grid-search`) · source · 1 · uncommon · O(k²), k = 4 · enumerate
  Every cell (i, j) of a 4×4 grid becomes a bolt of power `i·j // 2 + 1`: sixteen bolts, a lot of work. *Teaches*:
  nested loops over a grid, as tuning a model does. *+*: k = 5.
  *Art*: a flat bronze plate with a four-by-four lattice of small crystals, brightening from pale cyan in one corner
  to deep amber in the opposite corner.

**Pruner**

- **Backtracking** (`backtracking`) · strike · 2 · rare · O(2ⁿ) pruned, cap 12 · prune ★
  Assigns bolts to all foes for the most kills, abandoning any partial assignment that can't beat the best so far. The
  race bar shows the measured work far under 2ⁿ. *Teaches*: backtracking and pruning. *+*: also prunes on overkill.
  *Art*: a bronze branching tree whose limbs end in crystals; two limbs are snapped off with clean cuts and fade to
  grey, one limb glows amber to its tip.
- **N-Queens** (`n-queens`) · source · 1 · uncommon · O(n!) pruned, n = 6 · prune
  Places six queens by backtracking; each of the 4 solutions becomes a 7-power bolt. *Teaches*: backtracking on a
  constraint problem. *+*: n = 8, 92 solutions, each a 2-power bolt (a flood, and slow).
  *Art*: a small bronze chessboard corner with three cyan crystal queens on it, none sharing a row or diagonal, and
  faint gold lines showing their reach.
- **Branch and Bound** (`branch-and-bound`) · guard · 1 · rare · O(2ⁿ) bounded, cap 10 · prune
  Finds the subset of bolts that blocks the incoming damage with the least to spare, cutting any branch whose bound is
  already worse than the best. The pruned version of Exhaustive Ward. *Teaches*: bounds. *+*: cap 12.
  *Art*: a bronze shield with a tree etched into it, most branches crossed out with short gold strokes, one branch
  leading to a glowing cyan crystal boss.
- **Meet in the Middle** (`meet-in-the-middle`) · strike · 2 · rare · O(2^(n/2)) · prune
  Exhaustive Kill's question answered by listing every sum of each half, sorting one and searching it for the other:
  the same answer with the square root of the work. *Teaches*: meet in the middle. *+*: cap 16 bolts.
  *Art*: two bronze bridges reaching toward each other from left and right, each carrying a crystal, meeting with a
  bright amber flash at the centre.

**Overclocker**

- **Nested Strike** (`nested-strike`) · strike · 2 · uncommon · O(n·m) · heavy ★
  Every bolt at every foe in turn, at full power, until each falls. *Teaches*: nested loops, O(n·m). *+*: costs 1.
  *Art*: two bronze rings, one inside the other, both spinning, with crystals flying out from where they cross.
- **Bogosort** (`bogosort`) · order · 0 · uncommon · O(n·n!) expected, first 6 bolts · heavy · `volatile`
  Shuffles until sorted, seeded by the battle so the preview is the cast. Absurd work, which Throw Hardware At It turns
  into power. *Teaches*: why it's a joke, and expected running time. *+*: first 7 bolts.
  *Art*: a bronze dice cup tipped over, crystals tumbling out in every direction, one tiny neat sorted row among them.
- **Selection Sort** (`selection-sort`) · order · 0 · common · O(n²) · heavy
  Finds the weakest and swaps it to the front, again and again: always n² comparisons, even on sorted input (unlike
  Bubble Sort's early exit). *Teaches*: selection sort. *+*: strongest first instead.
  *Art*: a bronze pointer hand picking the smallest crystal out of a jumbled row and placing it on a shelf at the left.
- **All-Pairs Rank** (`all-pairs-rank`) · shape · 1 · uncommon · O(n²) · heavy
  Compares every bolt with every other: each gains 1 for every bolt weaker than it. The quadratic twin of D&C's
  Counting Inversions. *Teaches*: the same answer in O(n²) or O(n log n). *+*: 1 per weaker bolt, +2 for the
  strongest.
  *Art*: a ring of five crystals with thin gold lines joining every pair, forming a star polygon.

### B8.3 Dynamic Programming (13)

Also moved into DP's pool from neutral: Global Total and Release (state across the turns of a fight).

**Memoiser**

- **Memo Strike** (`memo-strike`) · strike · 1 · uncommon · O(n) · memo ★
  Each bolt flies at the foe you've already hit most this fight (`battle.foes[i].hits`), +1 per earlier hit (a cache
  hit), up to +4. *Teaches*: a cache keyed by what you've seen. *+*: up to +6.
  *Art*: a bronze card-index drawer pulled open, one tab marked by a glowing amber crystal, a cyan bolt leaping out of
  it.
- **Grid Paths** (`grid-paths`) · source · 1 · uncommon · O(2^(2k)) naive, O(k²) with `functools.cache`, k = 4 ·
  memo
  Counts the paths across a 4×4 grid by recursion: 70 of them, one bolt of power 10. Without the cache it's
  exponential; with `import functools.cache` in force (Memoiser has it) it's quadratic, and the race bar shows the
  difference. *Teaches*: memoisation turns exponential into polynomial. *+*: k = 5, one bolt of 25.
  *Art*: a bronze lattice of square tiles with two glowing routes from one corner to the opposite corner, one amber,
  one cyan, crossing in the middle.
- **Memo Ward** (`memo-ward`) · guard · 1 · common · O(1) · memo
  Block equal to the most block any one program made earlier this fight (remembered), at least 4. *Teaches*:
  remembering a best answer. *+*: at least 6.
  *Art*: a bronze shield with a small brass ledger book set into its centre, a cyan crystal bookmark sticking out.
- **Longest Common Subsequence** (`lcs`) · shape · 1 · uncommon · O(n·m) · memo
  Compares this volley's powers with the last program's landed volley; the bolts in their longest common subsequence
  gain 2 each. Repeating a good program pays. *Teaches*: LCS, the diff behind `git diff`. *+*: +3 each.
  *Art*: two parallel bronze rails of crystals, the matching crystals in both rows connected by bright gold threads.

**Tabulator**

- **Recurrence** (`recurrence`) · source · 1 · uncommon · O(1) · table ★
  Appends a bolt of `dp[t-1] + dp[t-2]` halved: Fibonacci across the fight's turns. Nothing on turn 1; large by turn 5.
  *Teaches*: a recurrence read from a table instead of recomputed. *+*: not halved, a third more instead.
  *Art*: a bronze spiral like a nautilus shell, small crystals in its inner chambers growing to a large amber crystal
  at the outer chamber.
- **Catalan** (`catalan`) · source · 1 · rare · O(t²) · table
  Appends a bolt of the turn's Catalan number (1, 2, 5, 14, 42, capped at 42), computed bottom-up. *Teaches*: Catalan
  numbers (balanced brackets, binary trees). *+*: one turn ahead.
  *Art*: a bronze bracket pair `( )` drawn as two curved metal arcs, nested twice, with a cyan crystal held at the
  centre.
- **Bottom-Up** (`bottom-up`) · import · 1 · uncommon · O(1) · table
  For the rest of the fight, every program's seed gains a bolt of the table's best row ÷ 5. *Teaches*: build the
  answer upward from the smallest cases. *+*: ÷ 4.
  *Art*: a short bronze staircase of three stone steps, each step holding a crystal larger than the one below.
- **Table Ward** (`table-ward`) · guard · 1 · common · O(t) · table
  Block equal to the table's last row ÷ 3, at least 3. *Teaches*: reading a table. *+*: ÷ 2.
  *Art*: a bronze tablet shield with a small grid of glowing cells, the last cell bright cyan.

**Optimiser**

- **Coin Change (DP)** (`coin-change`) · strike · 2 · rare · O(n·H) · exact ★
  The fewest bolts whose powers sum *exactly* to the front foe's HP fly at it (no overkill); the rest go to the next
  foe. *Teaches*: the classic pair with Make Change (greedy): one fast and sometimes wrong, one exact and slower. *+*:
  then repeats for the next foe.
  *Art*: three bronze coins of different sizes stacked in a precise tower that exactly reaches a gold notch on a
  measuring rod beside them.
- **Rod Cutting** (`rod-cutting`) · shape · 1 · uncommon · O(n²) · exact
  Cuts the strongest bolt into the pieces worth the most by a price table (a 3 is worth 4, a 5 worth 7, a 7 worth 10).
  *Teaches*: optimal substructure. *+*: the 2-piece is worth 3.
  *Art*: a long amber crystal rod on a bronze workbench, cut by two thin gold lines into three segments of different
  lengths.
- **Equal Partition** (`equal-partition`) · shape · 1 · rare · O(n·S) · exact
  If the volley can be split into two groups of equal sum (subset-sum DP), each group fuses into one bolt and both gain
  25%; otherwise nothing changes. *Teaches*: the partition problem. *+*: 40%.
  *Art*: a bronze balance scale perfectly level, each pan holding a different number of crystals.
- **Unbounded Knapsack** (`unbounded-knapsack`) · source · 1 · uncommon · O(n·H) · exact
  Copies of the volley's bolts (any number of each) that sum exactly to the front foe's HP are appended. *Teaches*:
  unbounded against 0/1 knapsack. *+*: the copies gain 1.
  *Art*: a bronze knapsack with an endless stream of identical cyan crystals pouring into it from a small tap.
- **Edit Distance Aim** (`edit-distance`) · strike · 1 · uncommon · O(n·m) · exact
  Aligns the sorted volley against the sorted foes' HP with the fewest edits; each matched bolt flies at its foe, the
  unmatched ones at the front. *Teaches*: edit distance, sequence alignment. *+*: unmatched bolts become block.
  *Art*: two short bronze strips of crystals one above the other, small gold arrows linking each upper crystal to its
  partner below, one crystal with a strike-through line.

### B8.4 Search & Index (13)

**Indexer**

- **Lookup** (`lookup`) · source · 0 · common · O(log k) · index ★
  `bisect`s the index for the smallest bolt that kills the front foe and takes it; otherwise the index's strongest.
  *Teaches*: a lookup in a sorted structure. *+*: takes two.
  *Art*: a bronze drawer cabinet with one small drawer sliding open on its own, an amber crystal resting inside.
- **B-Tree** (`b-tree`) · import · 1 · rare · O(1) · index
  For the rest of the fight, the index holds 8 more bolts and keeps 2 of them into the next fight. *Teaches*: B-trees,
  what databases are built on. *+*: keeps 3.
  *Art*: a wide bronze tree with short thick branches, each branch holding a tray of three small crystals in order.
- **Range Query** (`range-query`) · strike · 1 · uncommon · O(log n + k) · index
  For each foe, every bolt with power in `[HP / 2, HP]` flies at it, found with two bisects; the rest are stashed into
  the index. *Teaches*: range scans. *+*: `[HP / 3, HP]`.
  *Art*: a bronze ruler with two gold brackets clamped on it, a cluster of cyan crystals glowing between the brackets.
- **Lower-Bound Ward** (`lower-bound-ward`) · guard · 1 · common · O(log k) · index
  The smallest indexed bolt that covers the biggest incoming intent becomes block. Exact defence. *Teaches*:
  `bisect_left`. *+*: also +2 block.
  *Art*: a bronze shield with a small crystal fitted exactly into a notch on its rim, a gold arrow pointing up to it.
- **Write-Ahead Log** (`write-ahead-log`) · shape · 0 · common · O(n) · index
  Every bolt under 4 power is stashed into the index instead of flying: nothing weak is wasted. *Teaches*: logging a
  change before applying it. *+*: under 5.
  *Art*: a rolled bronze scroll with small crystals slotted along its edge like beads, being written before a large
  crystal moves.
- **Cursor** (`cursor`) · source · 1 · uncommon · O(1) per item · index
  Takes the three weakest bolts from the index in order, each +2. *Teaches*: cursors and iterators. *+*: four.
  *Art*: a bronze arrowhead cursor gliding along a shelf of crystals, the three it has passed glowing amber.

**Hasher**

- **Two Sum** (`two-sum`) · strike · 1 · common · O(n) · hash ★
  With a hash set, finds two bolts whose powers sum exactly to the front foe's HP: they fuse and kill it exactly.
  Otherwise its two strongest fly at it. *Teaches*: the most famous interview question, and why the set makes it
  linear. *+*: also looks for the second foe.
  *Art*: two crystals, one amber and one cyan, sliding together into a single bronze ring that glows where they meet.
- **Bloom Filter** (`bloom-filter`) · shape · 0 · uncommon · O(n) · hash
  One fast pass marks the elements each foe *might* be weak to; every bolt whose element might match gains 2, with
  one seeded false positive shown (a bolt that gains it wrongly). Never a false negative. *Teaches*: probabilistic
  data structures. *+*: no false positive.
  *Art*: a bronze sieve with a few lit holes, crystals passing through, one cyan crystal passing through a hole marked
  with a tiny question-mark-shaped glint.
- **Consistent Hashing** (`consistent-hashing`) · strike · 1 · rare · O(n log m) · hash
  The foes sit on a ring; each bolt hashes to a point and flies at the next foe clockwise. When a foe falls, only its
  bolts move on to the next (none wasted). *Teaches*: consistent hashing, how caches and databases spread load. *+*:
  moved bolts gain 1.
  *Art*: a bronze ring with three small foe-shaped markers on its rim and crystals sitting at points around it, short
  gold arcs pointing clockwise.

**Bisector**

- **Interpolation Search** (`interpolation-search`) · strike · 1 · uncommon · O(log log n), worst O(n) · bisect ★
  Like Binary Execute, but it guesses where the killing bolt sits from its value. On an evenly spread volley (Salvo's
  1 to 6) it's nearly free; on a lopsided one it's billed O(n) (`worst_case`). *Teaches*: the input's distribution
  changes the cost. *+*: falls back to binary search when it guesses badly.
  *Art*: a bronze measuring tape stretched along a row of evenly growing crystals, a gold pin stuck precisely at one.
- **Exponential Search** (`exponential-search`) · strike · 1 · uncommon · O(log i) · bisect
  Galloping: checks bolt 1, 2, 4, 8 … until one is strong enough, then binary-searches the last gap. Cheapest when the
  answer is near the front. *Teaches*: galloping search (Timsort uses it). *+*: per foe.
  *Art*: a bronze frog mid-leap over a row of crystals, its jumps marked by gold arcs that double in length.
- **Ternary Search** (`ternary-search`) · shape · 1 · uncommon · O(log n) · bisect
  On a volley that rises then falls (Recursive Mirror makes one), finds the peak by thirds and doubles it. *Teaches*:
  ternary search on unimodal data. *+*: the peak's neighbours +2.
  *Art*: a bronze mountain silhouette made of stacked crystals, a gold flag planted on the single tallest crystal at
  the peak.
- **Counting Sort** (`counting-sort`) · order · 1 · uncommon · O(n + k) · bisect
  Sorts weakest first by counting powers, without comparing bolts: linear while powers are small, slow when one bolt is
  huge (billed n + the strongest bolt's power). *Teaches*: non-comparison sorting. *+*: k capped at 64.
  *Art*: a bronze rack of pigeonholes, each holding a stack of identical crystals, the stacks of different heights.

### B8.5 Divide & Conquer (14)

**Deep Recursion**

- **Base Case** (`base-case`) · shape · 0 · common · O(1) · deep ★
  `if len(bolts) <= 2: return [b * 2 for b in bolts]`. Nothing on a whole volley; under Recurse, on a small half, it
  doubles. *Teaches*: every recursion needs a base case. *+*: `<= 3`.
  *Art*: the bottom of a bronze recursive ladder, its last rung holding two bright doubled crystals, the rungs above
  fading upward.
- **Halve** (`halve`) · order · 0 · common · O(1) · deep · `splits`
  Does nothing but split, so the next card recurses. *Teaches*: the divide step, by itself. *+*: also +1 to each
  half's first bolt.
  *Art*: a single crystal split cleanly into two halves by a vertical bronze blade, the halves drifting apart.
- **Tower of Hanoi** (`tower-of-hanoi`) · source · 1 · uncommon · O(2ⁿ), n = 4 · deep
  Solves four disks recursively; each of the 15 moves becomes a bolt of the disk's size + 1 (the ruler sequence 2, 3,
  2, 4, 2, 3, 2, 5, …). *Teaches*: recursion, 2ⁿ − 1 moves. *+*: n = 5.
  *Art*: three bronze pegs on a plinth, a stack of four crystal disks shrinking upward on the left peg, one disk in
  mid-air moving right.
- **Tail Call** (`tail-call`) · shape · 1 · uncommon · O(1) · deep
  The next card's recursive levels do no work this program: a call in tail position needs no new frame. *Teaches*:
  tail-call optimisation. *+*: the next two cards.
  *Art*: a bronze serpent biting its own tail forming a loop, one cyan crystal riding smoothly around it.
- **Fast Power** (`fast-power`) · shape · 1 · uncommon · O(log k) · deep · `once`
  The strongest bolt doubles three times, by repeated squaring. *Teaches*: exponentiation by squaring. *+*: four times.
  *Art*: a crystal inside a bronze frame inside a larger frame inside a larger frame, each frame twice the last, glowing
  hotter outward.
- **Karatsuba** (`karatsuba`) · shape · 2 · rare · O(n^1.58) · deep · `splits`
  "Multiplies" the two strongest bolts (a·b / 10) with three recursive multiplications instead of four. *Teaches*:
  Karatsuba, the first algorithm faster than school multiplication. *+*: a·b / 8.
  *Art*: two crystals crossed like an X inside a bronze square split into four quadrants, three quadrants lit and one
  dark.

**Merger**

- **K-Way Merge** (`k-way-merge`) · order · 1 · uncommon · O(n log k) · merge ★
  Finds the volley's rising runs and merges them with a heap into one sorted volley; each run merged adds 1 to every
  bolt. *Teaches*: k-way merge (what external sorting and databases do). *+*: +1 per run, and the result is strongest
  first if you like it (a choice in the code).
  *Art*: three bronze chutes converging into one, crystals from each chute merging into a single ordered line.
- **Max Subarray (D&C)** (`max-subarray`) · shape · 1 · uncommon · O(n log n) · merge · `splits`
  Best run in the left half, the right half, or across the middle, fused into one bolt, +1 a level. *Teaches*: the same
  answer as Kadane's O(n), the D&C way. *+*: +2 a level.
  *Art*: a row of crystals with a bronze bracket spanning a stretch of them across the middle, that stretch glowing
  amber.
- **Counting Inversions** (`counting-inversions`) · shape · 1 · uncommon · O(n log n) · merge · `splits`
  Merge sort that counts: each bolt gains the number of stronger bolts before it. Rewards disorder: play it before
  sorting. *Teaches*: inversions. *+*: also counts weaker bolts after it.
  *Art*: two crystals in a row with small gold arrows crossing over each other between them, the pair glowing where the
  arrows cross.
- **Closest Pair** (`closest-pair`) · shape · 1 · uncommon · O(n log n) · merge · `splits`
  Finds the two bolts closest in power and fuses them, doubled. *Teaches*: closest pair of points, the strip trick.
  *+*: the two closest pairs.
  *Art*: two nearly identical cyan crystals drawn together by a bronze caliper, a spark between them.
- **Skyline** (`skyline`) · shape · 1 · rare · O(n log n) · merge · `splits`
  Each bolt is a tower; a bolt hidden behind a taller one before it is fused into that taller one. *Teaches*: the
  skyline problem, merging two skylines. *+*: hidden bolts add their full power.
  *Art*: a small city skyline of crystal towers of different heights on a bronze base, the outline traced by one gold
  line.

**Partitioner**

- **Dutch Flag** (`dutch-flag`) · order · 0 · uncommon · O(n) · pivot ★ · `splits`
  Three-way partition around the front foe's HP: the bolts that would kill it exactly first, the stronger ones next,
  the weaker ones last. Its pivot is the exact bolt. *Teaches*: Dijkstra's Dutch national flag partition. *+*: exact
  bolts gain 1.
  *Art*: three vertical bands of crystals in a bronze frame, amber, ivory and cyan, the middle band a single bright
  crystal.
- **Median of Medians** (`median-of-medians`) · strike · 1 · rare · O(n) worst · pivot · `splits`
  Like Quickselect but guaranteed linear even on bad input; the median is the pivot, the upper half flies at the
  toughest foe and the lower at the weakest. *Teaches*: worst-case linear selection. *+*: the pivot gains 3.
  *Art*: five small bronze trays of five crystals each, the middle crystal of each lifted up, and the middle of those
  lifted highest and glowing.
- **Introsort** (`introsort`) · order · 1 · rare · O(n log n) worst · pivot · `splits`
  Quick sort that switches to heap sort when the recursion gets too deep, so it is never O(n²). What C++'s `std::sort`
  really does. *Teaches*: hybrid algorithms. *+*: costs 0.
  *Art*: a bronze split arrow, one branch a quick lightning zig-zag and the other a neat tree, both ending in the same
  sorted row of crystals.

### B8.6 Neutral (13)

- **Read Input** (`read-input`) · source · 1 · common · O(m)
  One bolt per foe, its power that foe's intended damage: the battle is your input. *Teaches*: input from outside.
  *+*: +2 each.
  *Art*: a bronze funnel with three small foe-shaped shadows above it and three crystals falling out of the bottom.
- **Prefetch** (`prefetch`) · utility (a new role, a grey badge) · 1 · uncommon · O(1) · `once`
  Draw 2 next turn. *Teaches*: prefetching. *+*: costs 0.
  *Art*: a bronze hand reaching into a card-shaped slot ahead of a moving crystal, two card backs peeking out.
- **Monte Carlo** (`monte-carlo`) · source · 1 · common · O(k)
  Eight random 1-to-6 bolts, seeded by the battle, so the preview is the cast. *Teaches*: randomised algorithms,
  seeds. *+*: 2-to-7.
  *Art*: a bronze roulette wheel with crystal pockets, one pocket glowing, a small ivory ball resting in it.
- **Reservoir Sampling** (`reservoir-sampling`) · shape · 0 · uncommon · O(n)
  Keeps three bolts chosen uniformly at random in one pass (seeded), each doubled; the rest fade. *Teaches*: sampling
  a stream you can't hold. *+*: four.
  *Art*: a small bronze water tank with three crystals floating inside and a stream of crystals flowing past outside.
- **Swap** (`swap`) · order · 0 · common · O(1)
  The first and last bolts change places. *Teaches*: `a, b = b, a`. *+*: then +1 to the new first.
  *Art*: two crystals exchanging places along two curved bronze arrows forming a circle.
- **Rotate** (`rotate`) · order · 0 · common · O(n)
  The volley rotates by one: the last bolt comes first. *Teaches*: rotation, `deque.rotate`. *+*: by two.
  *Art*: a bronze wheel with crystals around its rim, one arrow showing a quarter turn.
- **Enumerate** (`enumerate`) · shape · 0 · common · O(n)
  Each bolt gains its index (0, 1, 2 …). Later bolts gain more. *Teaches*: `enumerate`. *+*: index + 1.
  *Art*: a row of crystals on a bronze rail, each with a growing number of small gold notches under it.
- **Slice** (`slice`) · shape · 0 · common · O(k)
  Keeps the first four bolts (`bolts[:4]`), each +2. *Teaches*: slicing. *+*: each +3.
  *Art*: a bronze knife cutting a row of crystals after the fourth one, the cut end glowing.
- **Pop** (`pop`) · shape · 0 · common · O(1)
  Removes the last bolt and adds its power to the first. *Teaches*: `list.pop()`. *+*: also +1.
  *Art*: a crystal popping out of the end of a bronze tube like a cork, its glow streaming to the far end.
- **Bit Shift** (`bit-shift`) · shape · 1 · uncommon · O(n)
  `bolt << 1`: every bolt doubles, but a bolt that would pass 31 wraps around (`& 31`). *Teaches*: shifts and integer
  overflow. *+*: wraps at 63.
  *Art*: a row of small square crystal bits sliding one step left on a bronze track, the leftmost bit falling off the
  edge.
- **Sort by Key** (`sort-by-key`) · order · 1 · common · O(n log n)
  A stable sort by element, then power: the elements are grouped, which Run-Length and Hash Merge love. *Teaches*:
  `sorted(key=...)` and stability. *+*: costs 0.
  *Art*: crystals of three colours being sorted into three neat bronze trays by colour, smallest to largest in each.
- **Range** (`range`) · source · 1 · common · O(k)
  `range(2, 10, 2)`: four bolts, 2, 4, 6, 8, already sorted. *Teaches*: `range` and its step. *+*: `range(3, 15, 3)`.
  *Art*: four crystals of evenly growing size standing on four evenly spaced bronze steps.
- **List Comprehension** (`list-comprehension`) · shape · 1 · common · O(n)
  `[b + 2 for b in bolts if b >= 3]`: filter and map in one pass. *Teaches*: comprehensions. *+*: `+ 3`.
  *Art*: a bronze bracket frame `[ ]` with crystals passing through a small gate inside it, the weak ones turned away.

### B8.7 The existing cards, tagged

| Paradigm | sprint / enumerate / memo / index / deep | heap / prune / table / hash / merge | schedule / heavy / exact / bisect / pivot |
|---|---|---|---|
| Greedy | stable-partition, chain-lightning | take-max, huffman, greedy-ward, import-heapq | greedy-assign, sweep, load-balance, make-change |
| Brute Force | pairwise, power-set, import-itertools | exhaustive-kill, exhaustive-ward | bubble-sort, linear-search |
| Dynamic Programming | fib-surge, fib-memo, import-cache | tabulate, pascal-row, sliding-window, kadane, global-total, release | knapsack-strike, knapsack-ward, lis-strike |
| Search & Index | run-length | hash-merge, hash-aim, dedupe, import-collections | prefix-sum, binary-execute, bisect-insert, import-bisect, two-pointers |
| Divide & Conquer | divide, recursion-tree, split, import-math | merge-strike, recursive-mirror, import-copy | quick-sort, quickselect |

Existing cards that split (`splits: true`): divide, split, merge-sort, quick-sort, quickselect.

The pools are cleaned at the same time: a paradigm's `pool` lists only its own cards, and `sweep`, `take-max` (Greedy)
and `hash-merge` (Search) leave the `neutral` list, which keeps only neutral cards.

After the update: Greedy 25 cards, Brute Force 19, Dynamic Programming 25, Search & Index 23, Divide & Conquer 23,
neutral 36 (25 − 2 moved + 13), about 150 in all, before `+` versions.

## B9. Issues: the events

An event is data (`packs/core/programs/issues/<id>.jsonc`): a title, a picture, a paragraph, and two to four choices,
each a list of effects the rules know (`gain-cycles`, `lose-integrity`, `heal`, `max-integrity`, `add-card`,
`remove-card`, `upgrade-card`, `transform-card`, `gain-relic`, `gain-curse`, `fight`, `pending`, `boon`, `swap-focus`,
`read-code`). Choices can need something (cycles, a card of a role) and are greyed out when you can't. Everything is
drawn from the run's seed and the room. Each event names the layers it may appear in.

The screen: an issue on a tracker. Its title like `#142 Stack Overflow answer`, labels (`good first issue`, `bug`,
`wontfix`), the picture on the left, the text on the right, and the choices as buttons styled as comments or PR
actions.

### B9.1 The simple ones (only existing effects)

| # | Issue | Layers | Choices |
|---|---|---|---|
| 1 | **The Coffee Machine** | all | heal 25% · +5 max Integrity · 30 cycles · a random common script |
| 2 | **Code Review** | all | remove a card · refactor a card · 50 cycles |
| 3 | **Legacy Codebase** | 1-2 | refactor two random cards, lose 8 Integrity · walk away |
| 4 | **Dependency Hell** | 2-3 | a random epic relic and a random curse · walk away |
| 5 | **Deprecated API** | all | transform a card of your choice into a random card of the same role and paradigm · walk away |
| 6 | **Merge Conflict** | all | two random cards: keep one, lose the other · pay 40 cycles to keep both |
| 7 | **Rewrite It in Rust** | 2-3 | every common becomes a random uncommon of its paradigm; lose 2 max Integrity per card changed · walk away |
| 8 | **Garbage Collector** | all | mark and sweep: remove up to two basic cards for free · walk away |
| 9 | **Abandoned Repository** | all | open it: a random relic, 30% cursed · read the README: a random card of a random paradigm · check the `bin/` folder: two random scripts |
| 10 | **Fork the Repo** | 2-3 | duplicate a card, lose 8 Integrity · walk away |
| 11 | **Code Golf** | all | remove two cards, lose 3 max Integrity each · walk away |
| 12 | **Version Bump** | all | major: transform three random cards of your paradigm · minor: refactor one · patch: heal 12 |

### B9.2 Cross-paradigm (the doors out)

| # | Issue | Layers | Choices |
|---|---|---|---|
| 13 | **Pair Programming** | all | choose a paradigm, then one of three of its cards · decline (+10 cycles, they buy you coffee) |
| 14 | **Conference Talk** | 1-3 | pay 75 cycles: one of three cards from another paradigm, already refactored · stay for the free swag: a random neutral card |
| 15 | **Cross-Compilation** | 2-3 | trade a card of your paradigm for two random cards of another · walk away |
| 16 | **Paradigm Shift** | 2-3, rare | switch your focus to another of your paradigm's (the focus relic swaps; the old signature card stays) · keep yours, +40 cycles |

### B9.3 Deferred state (`pending`, `boon`, `fight`)

| # | Issue | Layers | Choices |
|---|---|---|---|
| 17 | **The Open-Source Maintainer** | 1-2 | donate 50 cycles: two rooms later, a rare relic waits · donate nothing |
| 18 | **Technical Debt** | all | borrow 120 cycles now; a curse "Tech Debt" (every third fight starts with 1 less mana) until you repay 150 at a Registry · decline |
| 19 | **The Intern** | 1-2 | take them on: the next three card rewards offer a fourth card · decline |
| 20 | **Daily Standup** | all | for the next three fights: +1 mana on turn 1 · or draw 1 more on turn 1 · or start with 5 block · or skip it and take an uncommon script |
| 21 | **Hackathon** | all | fight an elite now for a guaranteed rare-or-better relic · walk away |
| 22 | **Bug Bounty** | 1-3 | the next fight's front foe carries a bounty: kill it in one program for 100 cycles · decline |
| 23 | **Benchmark** | 2-3 | for the next fight, keep every program under 512 operations for 80 cycles · decline |
| 24 | **Hotfix in Production** | all | refactor a card of your choice now, lose 6 Integrity · walk away |

### B9.4 Reading code (the player's own deck, run for real in the sandbox)

These are bets: each states its stake before you answer, and walking away is always free. A wrong answer pays the
stake and the event still explains the line you missed.

| # | Issue | Layers | Choices | Right | Wrong (the stake) |
|---|---|---|---|---|---|
| 25 | **The Rubber Duck** | all | a card from your deck runs on a small volley; pick its output from four · walk away | a rare card of your paradigm | 15 cycles |
| 26 | **The Oracle's Test Suite** | 2-3 | three versions of one of your cards (the real one and two of the Mutator's surviving mutants, `mutants.jsonc`); pick the one that passes the shown tests · walk away | 60 cycles and that card refactored | 20 cycles |
| 27 | **Stack Overflow Answer** | all | copy a card of your choice, blind: a seeded half of the time the copy is a mutant (it runs, slightly wrong; its diff is shown when it's taken) · read the comments first for 15 cycles: see whether it's a mutant, then decide · walk away | a clean copy | a mutant copy in your deck (removable like any card) |
| 28 | **Big-O Quiz** | all | two of your cards and a volley size: which does less work? · walk away | 40 cycles and the faster card refactored | 15 cycles |
| 29 | **Will It Halt?** | the Root only | a tiny loop from the game's own content; does it halt on this input? · walk away | an epic relic | 6 Integrity |
| 30 | **Off-by-One** | all | a short loop over your volley; how many times does it run? · walk away | +4 max Integrity | 3 Integrity |

Answers come from real runs in the sandbox, never from a written answer key, so they are right in every language. A
stake you can't pay (too few cycles) greys out that event's answer, not the event: you can still walk away. The
relic Rubber Duck (B10) waives every stake.

## B10. Relics (24 new)

Tiers as ADR-0016. "Kind" says whether the effect kind exists or is new.

| Relic | Tier | Effect | Kind |
|---|---|---|---|
| **Package Lock** | common | Registry prices 15% lower. | new `shop-discount` |
| **Mirror Server** | uncommon | The Registry stocks one more card and one more relic. | new `shop-stock` |
| **Bug Bounty Program** | common | +2 cycles per kill. | new `kill-cycles` |
| **Venture Capital** | rare | 150 cycles now; lose 1 max Integrity at every Registry you visit. | new |
| **Semantic Versioning** | uncommon | `refactor` at the Registry costs 0 once per layer. | new |
| **Coupon Code** | common | The Registry's sale card is free. | new |
| **Lockfile** | uncommon | The first relic you buy each layer costs half. | new |
| **Interest Rate** | rare | At each Registry, gain 10% of your cycles (at most 30). | new |
| **Monorepo** | uncommon | +1 mana while your deck has 25 cards or more. | new (SHARDRUN_DESIGN 8) |
| **Microservices** | uncommon | Draw 1 more while your deck has 12 cards or fewer. | new (SHARDRUN_DESIGN 8) |
| **Snapshot** | rare | Once a run, a blow that would end it restores you to the start of that turn. | new |
| **Rubber Duck** | common | A wrong answer in a reading-code event costs nothing. | new |
| **Polyglot** | uncommon | Fight rewards offer other paradigms at 35% instead of 20%. | new `reward-share` |
| **Specialist** | uncommon | Fight rewards offer your focus's cards at ×3 inside the paradigm. | new `reward-share` |
| **Amortised Analysis** | rare | The Table's rows never go down: a row lower than the one before is written as that one. (DP) | new |
| **Memory Pool** | uncommon | The index holds 4 more, and the seed's index bolt gains 2. (Search) | new |
| **Heat Sink** | uncommon | A timeout refunds its mana and gives block for the overrun ÷ 64. (Brute Force) | new |
| **Speculative Execution** | rare | Your first strike each program runs twice on copies of the volley; the better result is kept, and both count as work. (Greedy) | new |
| **Stack Frame** | rare | Recurse also applies to the second card after a split. (D&C) | new |
| **Big Data** | epic | A volley of 64 bolts or more deals 25% more. | new |
| **Tail Latency** | common | The first foe to act each turn acts 12 operations later. | existing `tempo` |
| **Hash Seed** | uncommon | Bolts on a weakness deal 1 more. | existing `weak-bonus` |
| **Cold Start** | common | The first program of every fight costs 1 less mana. | new |
| **Dead Code Elimination** | uncommon | At a rest site you may also remove a card. | new |

The paradigm-flavoured relics can drop for any run, so a Search relic in a Greedy run is a reason to splash.

## B11. Art for the image pipeline

### B11.1 How

A new pass manifest `pipeline/art/program-icons-pass-10.json`, in pass 9's format: `generator`, `date`, `intent`,
`shared_prompt` (pass 9's, unchanged, so the new cards match the finished ones), a `cards` map (`icon`, `status`,
`summary`) and an `assets` map (`out`, `status`, `cards`, `subject`, `prompt` = the shared prompt + the subject).
`subject` is the **Art** line of each card in B8. Then `program_icons.py board`, review at 32 and 64 pixels, `accept`,
`check`, and screenshots of the cards in a hand. A `+` card shows its base card's picture (`art`), as now.

Where a new card's operation matches an existing picture, reuse it (pass 9 did this for Spellforge's): Heap Sort can
share Merge Sort's until it has its own. Every card still has a picture from its first commit, even if shared.

### B11.2 Beyond the cards

| Asset | Subject |
|---|---|
| 15 focus emblems (`shardrun/focus-<id>`) | the focus's signature card subject, framed in a round bronze medallion with the paradigm's colour as its jewel |
| `shardrun/registry` (the shop backdrop) | a tall cabinet of small brass drawers with tiny engraved tags, warm lamplight, a velvet counter in front; empty space at the top for the keeper |
| `shardrun/semver` (the keeper, a small sprite) | a small round brass owl with big amber lens eyes, a monocle and a rubber stamp in one wing, house style: small, cute, simple |
| `shardrun/cycles` (the currency icon) | a tiny bronze clock gear with a cyan crystal at its hub |
| 16 script icons (`shardrun/script-<id>`) | the **Art** column of B12.3; a shared base, a small rolled bronze scroll with a crystal seal, so the belt reads as one family |
| `map/shop`, `map/issue` (map icons) | a small crate stamped with an owl; a bronze ring around an exclamation mark made of a crystal shard |
| `shardrun/issue-<id>` (30 event pictures) | one bold object each: a coffee machine with a crystal carafe; a rubber duck in bronze armour; a tangle of bronze pipes (Dependency Hell); a tiny brass crab in a hard hat (Rewrite It in Rust); an old chest wrapped in vines (Abandoned Repository); an owl-shaped lectern on a small stage (Conference Talk); two chairs at one desk (Pair Programming); a stopwatch on a podium (Benchmark); a gold coin with a beetle on it (Bug Bounty); a ledger with a red ribbon (Technical Debt); a looping bronze track with an ending flag (Will It Halt?) … |

## B12. Scripts (consumables)

### B12.1 What a script is

A **script** is a one-use command you carry between fights, Rootward's version of Slay the Spire's potions. Scripts
aren't cards: they don't go in the deck, cost no mana, take no program slot and are never drawn. You keep them in a
**belt** of three slots (a fourth with the relic Dotfiles, below) shown beside the hand, and use one on your turn, at
any moment before you cast. It does its effect at once and is gone. Each is named after a real command that does
roughly that thing, so the name teaches a little too (`kill -9`, `nice`, `git revert`).

The preview stays the cast: a script that changes the program (`sudo`, `nice -n -20`, `gc.collect()`) is applied to
the battle state as a buff first, and the preview is recomputed with it.

### B12.2 Getting them

| Where | How |
|---|---|
| After a fight | 30%, +10% for every fight since the last drop (pity), back to 30% after one drops |
| After an elite | 60% |
| After a guardian | always |
| The Registry | three on a shelf, priced by rarity |
| Issues | Daily Standup, The Coffee Machine and Abandoned Repository may offer one (as a choice) |

With a full belt, a new script asks which to drop (or to leave the new one). Scripts are data
(`packs/core/programs/scripts/<id>.jsonc`: name, rarity, effect, when it can be used, an icon), validated by
`ProgramSchemas`. They are drawn from the run's seed like everything else.

### B12.3 The scripts

| Script | Rarity | Effect | Price | Art |
|---|---|---|---|---|
| `hotfix.sh` | common | heal 10 (also usable on the map) | 40 | a small bronze scroll with a cyan crystal seal shaped like a plus |
| `touch` | common | a 0-cost Literal in hand | 30 | a scroll with a single ivory crystal resting on it |
| `print()` | common | see every foe's next two intents | 30 | a scroll unrolled into a short bronze speaking-trumpet |
| `ulimit` | common | a foe's next attack deals half | 40 | a scroll bound by a tight bronze band with a lock |
| `cache warm` | common | draw 3 | 45 | a scroll with three small card backs fanned from its end, glowing warm amber |
| `pip install` | uncommon | a random card of your paradigm in hand; it costs 0 this turn | 45 | a scroll with a small owl-stamped crate sliding out of it |
| `git revert` | uncommon | undo the damage taken last turn, up to 15 | 50 | a scroll with a curved bronze arrow looping back on itself |
| `nice -n -20` | uncommon | this turn your program counts as 0 work (it lands first, with Initiative) | 50 | a scroll with a winged bronze stopwatch on it |
| `kill -9` | uncommon | 25 damage to one foe | 60 | a scroll pierced by a short bronze dagger with an amber crystal pommel |
| `strace` | uncommon | one foe's trait is off this turn | 60 | a scroll with a magnifying lens following a thin gold thread |
| `sudo` | rare | your next program deals double | 70 | a scroll with a small bronze crown on its seal |
| `fork()` | rare | your next program runs twice; the second run lands at half power | 80 | a scroll that splits into two identical scrolls at one end |
| `gc.collect()` | uncommon | empties the index into this program's seed (Search), or writes a free row to the Table equal to its best row (DP), or 10 block for any other paradigm | 50 | a scroll with a small bronze broom sweeping crystals into a pile |
| `git stash` | uncommon | put your whole hand aside: it comes back next turn, on top of the new draw | 45 | a scroll folded into a little bronze drawer |
| `make -j8` | rare | this turn, your program's work is divided by 4 | 70 | a scroll with eight tiny bronze gears turning in a row |
| `rm -rf build/` | rare | remove every curse relic's effect for this fight | 90 | a scroll with a bronze dustpan holding broken grey crystals |

### B12.4 Relics that touch scripts (added to B10)

| Relic | Tier | Effect |
|---|---|---|
| **Dotfiles** | uncommon | the belt holds four |
| **Shell History** | rare | the first script you use each fight comes back after the fight (once per fight) |
| **Alias** | common | scripts cost 25% less at the Registry |

## B13. Balance: what to measure, and targets

The probe (`docs/research/balance-probe/`) runs before (slice 0) and after (slice 13), on the same seeds, on Beginner,
in JavaScript (the fastest). It may treat issues as "walk away" and the Registry as "buy the best card it can afford"
at first.

| Measure | Target |
|---|---|
| Win rate overall | 40 to 60% for the smart bot |
| Win rate, worst paradigm | 30% or more; no paradigm above 75% |
| Win rate, worst focus | 25% or more |
| Share of the final deck from the paradigm | 50% or more (about 30% now) |
| Other paradigms in the final deck | 10 to 25% |
| Cycles at the layer-1 Registry | 150 to 250 |
| Purchases per Registry | 1.5 to 2.5 |
| Scripts used per fight | 0.3 to 0.8 |
| Turns a law fired | 60% or more of turns, for every law |
| Any single card that moves a paradigm's win rate by 20 points | flagged, reported |
| Act 1 fights | 2 to 4 turns |

Tuning is data: the laws' numbers, the shares, prices, earnings and card numbers live in `programs.jsonc` and the card
files.

## B14. The player's calls (answered 2026-10-04)

1. **Names**: the second pick is a **focus** (focuses), the money is **cycles**, and the shop is **the Registry**,
   kept by Semver the owl.
2. **The focus pick**: all three focuses offered, for now.
3. **Reward shares**: 50 / 30 / 20 (own paradigm, neutral, another paradigm), one own card guaranteed.
4. **Map size**: +2 rows a layer (one fight, one fixed Registry), as B6.
5. **Issues per layer**: about 2 to 3, by weight 18.
6. **Scripts**: in this update (B12, slice 8).
7. **Reading-code events are bets**: a wrong answer costs a small stake, stated before answering (B9.4); walking away
   is free.
8. **Legendary relics in the Registry**: at 1% (B7.1), priced 450.

---

# Current step (2026-10-04, evening)

**Where the work stopped.** The implementing session ran out of credits while it was integrating slices 1 to 3. Its
work was recovered, checked and committed in one commit after slice 0's. The checklist lives in `docs/PLAN.md`
("The Paradigm Update"), and the decisions in ADR-0048.

## Done

| Slice | State | Where |
|---|---|---|
| 0. Baseline | done, committed (`1189db2`) | `docs/research/balance-probe/paradigm-update/` (30 runs, 40% won; reuse its seeds for the final report) |
| 1. Focuses and the pick | done but for four tests (below) | `program_draft.gd` (`pick-focus`, `focus_offers`), `draft_view.gd`, `programs.jsonc` (`law`, `swap`, `focuses`), 5 law and 15 focus relics (tiers `paradigm`, `focus`), `run_history.gd` (`greedy/sprint`), `trial_rules.gd` (Pip's Trial defaults to Tabulator), `ShardrunSchemas` defaults for old saves |
| 2. Fight memory | done but for one test (below) | `program_memory.gd` (Index, Table, hits, last volley), `program_landing.gd` (landing shared by preview and cast), `program_intents.gd` (the foes' intents the code sees), `spell_runs.gd` program branch, `program_memory_view.gd` (the Index and Table under the code) |
| 3. The body slot | done | the three harnesses (`spell_harness.py`, `.js`, `harness.cpp`), `program_body_source.gd` (the halves written as code), Pruner, Sprint and Merger billed per original card |
| 10. Cards (part) | 15 of 80 | the 15 focus signatures and their `+` versions, in Python, JavaScript and C++, with examples and Japanese (`locales/ja/paradigm-update.jsonc`) |
| 12. Art (part) | queued | `pipeline/art/program-icons-pass-10.json`: the 15 signatures queued and showing existing art for now |

Fixed during recovery:
- `program_landing.gd` didn't parse. gdformat had laid out a lambda inside a parenthesised `.filter(...).size()` chain
  in a form Godot 4.7 rejects ("Unindent doesn't match"), and every script that loads the rules failed with it. It's
  a plain loop now. **Watch for this**: gdformat can turn a working lambda chain into one Godot won't parse; run
  `scripts/check.sh` after formatting.
- A card's `focus` was a required id defaulting to `""`, so re-checking a loaded neutral card failed. It's optional
  now, and a new cross-check makes sure a card's focus belongs to its own paradigm.

## Verified (after recovery)

- `scripts/test.sh`: 472 test cases, 0 failures.
- `scripts/lint.sh`: clean.
- `scripts/validate.sh`: 169 program cards, 482 worked examples in each of Python, JavaScript and C++, 0 errors,
  0 warnings (the C++ build and the mutants census are current).
- `scripts/locale.sh ja --missing`: 938/938 content, 472/472 interface, 139/139 rule sentences.
- Screenshots in `shots/paradigm-update/`: `focus-en.png`, `focus-ja-cpp.png`, `pack-focus-en.png`,
  `index-fight.png`, `recurse-cpp.png`.

## Session log: the four law tests, and what the code panel really does

**Started 2026-10-04, after the recovery commit `a17b99d`.** This session closed gap 1 below (the four untested
focus rules) and settled gap 2 with numbers instead of a screenshot.

### 1. The four law tests — done, and they pass

All four now live in `game/test/core/programs/paradigm_laws_test.gd`, each measured **through the cast and then through
the preview**, which is the shape the other tests in that file use (the panel must never promise more than the cast
delivers):

| Test | Rule | The number it pins |
|---|---|---|
| `test_hasher_adds_two_power_to_a_bolt_that_lands_on_a_weakness` | `weak-flat-bonus` | 13 dealt with the focus, 10 without — the +2, through the 1.5 fire affinity |
| `test_enumerator_raises_the_volley_cap_from_128_to_192` | `max-bolts` | `bolt_limit` 128 → 192; a 200-bolt flood previews as 192 and still only lands 20 (the first foe) |
| `test_partitioner_doubles_the_pivot_and_aims_it_at_the_toughest_foe` | `pivot-mark` | 9 dealt, foes at 17 and 24 — both bolts were aimed at foe 0 |
| `test_tabulator_starts_the_table_bolt_on_turn_two_and_shares_it_thirds` | `table-from`, `table-divisor` | 3 seed bolts on turn 1, 4 on turn 2; the extra is 10, i.e. (18 + 12) // 3 |

Each also asserts `preview.damage == played.landed.dealt`, so a future change that makes the panel lie fails here.

`scripts/test.sh -a res://test/core/programs/paradigm_laws_test.gd`: **16 test cases, 0 failures.**

One lint fix came with them: the Tabulator test's focus list was a 121-character line, over the 120 limit. It is a
multi-line array now. `scripts/lint.sh` is clean apart from the temporary probe (see §3).

### 2. The C++ long line was never clipped — it wraps, and the panel is wider than the probe assumed

The screenshot (`recurse-cpp.png`, line 12) *looked* like a line running off the right edge. It is not a clipping bug,
and the fix is not in `CodeView`. Two findings:

1. **The panel already wraps.** `RuneCode._layout()` (`game/ui/code/rune_code.gd:256`) computes the columns from the
   live width and breaks a too-long line at the last space before the edge, continuing it on the next row with an
   indent. So "runs past the right edge" was never possible; a long line becomes two rows.
2. **What the screenshot actually caught** was the listing *scrolled*, so the wrapped continuation of the long
   comment was below the fold. The apparent cut-off was the scroll container's edge.

To measure instead of squint, `game/tools/listing_probe.gd` prints every line of a listing with its length and flags
anything wider than the panel. Against the Deep Recursion program (`split`, `merge-strike`, `divide`), at the design
width of 780 (`program_code.gd:78`, `custom_minimum_size.x = 780`) the panel holds **87 columns**:

| Language | Longest line | Over 87 |
|---|---|---|
| C++ | 117 | 10 lines, all 94–117 |
| Python | 118 | 6 lines |
| JavaScript | 79 | none |

Every one of those over-wide lines is **authored card source in `game/content/packs/core/programs/cards/`** — the
long explanatory comments in `split.cpp:15`, `merge-strike.cpp:2-3`, `divide.cpp:2-3` — not the panel's own generated
rows. The generated rows are now short: `program_body_source.gd` writes a Deep Recursion body's four calls
(`left_left`, `left_right`, `right_left`, `right_right`) **one call per line** when there are more than two parts, so no
generated row is over 88 columns. That change is in the working tree, uncommitted.

So the residual gap is a content choice, not a rendering bug: the card comments are wider than the panel and wrap.
Whether to rewrap those comments to 87 is a content pass over the cards, best done with slice 10 when the other 65
cards land, so it is done once for all of them.

### 3. Temporary tooling (remove before committing)

- `game/tools/_tmp_crop.gd` — crops and scales a screenshot region so the code panel can be read back. Diagnostic only.
- `game/tools/listing_probe.gd` — the listing/length probe above. Also diagnostic; it is the one remaining lint
  failure (line 13 is over 120 characters).

Both are untracked. Delete them, or keep `listing_probe.gd` deliberately as a `game/tools/` tool with its line
wrapped, and say which in the commit.

### 4. A real bug found on the way: `dev-spawn` skips the program's battle setup

Running a screenshot with `ROOTWARD_SHOT_FOES` (which sends `dev-spawn`) produced:

```
SCRIPT ERROR: Invalid access to property or key 'gone' on a base object of type 'Dictionary'.
   at: spend (res://core/programs/program_deck.gd:77)
```

Cause: `ShardrunDev._spawn` (`game/core/shardrun/shardrun_dev.gd:138`) builds the fight with
`ShardrunBattle.new_battle(...)` and never calls `ProgramDeck.on_battle_start` / `ProgramRelics.on_battle_start`. Only
`ShardrunBattle.start_with` does that (`shardrun_battle.gd:56-58`). So a dev-spawned fight in a program run has no
`gone`, `imports`, `globals`, `index`, `dp`, `hits` or `last_volley`, and any card with the `once` keyword
(`reduce`, `reduce-plus`, `lambda`) crashes the cast in `ProgramDeck.spend`.

This is dev-only, so it never reached a player, but it makes every `dev-spawn` screenshot of a `once` card
misleading. Fix: have `_spawn` run the same two setup calls when `state.playstyle == "program"`, and cover it with a
test that spawns a fight in a program run and casts a `once` card.

## Gaps before ticking slices 1 to 3 in PLAN.md

Gap 1 (the four untested focus rules) is **closed** — see the session log in §1 above. What is left:

1. ~~Four focus rules have code but no test of their own~~ — done, all four tested and passing.
2. The focus cards on the pick screen still have an empty emblem space (the emblems are slice 12's art).
3. The card comments in C++ and Python are wider than the 87-column panel and wrap onto a second row (§2). Not a
   rendering bug; rewrap the card comments in one pass with slice 10.
4. `dev-spawn` does not run a program run's battle setup, so a dev-spawned fight crashes on a `once` card (§4).

## Next step, exactly

1. Fix `dev-spawn`'s missing program setup (§4) with a test, delete the two temporary tools, then tick slices 1, 2 and 3
   in `docs/PLAN.md` and commit (the four law tests and the body-slot wrapping are already in the tree).
2. Slice 4, **Rewards** (B4): the 50 / 30 / 20 shares with focus-tagged cards ×2, one own card guaranteed, the
   elite's fourth card from another paradigm, rare pity, and cycles for a skip (wait for slice 5 for the cycles, or
   land skip pay with it). Test the shares over many seeds. The rules to write are `ShardrunBattle.draft_shards`
   (called from `win`, currently a rarity-only `_draft`) and `draft_relics`; the rarity shares live in
   `game/content/packs/core/shardrun/run.jsonc` under `rewards.shards`, and the new 50 / 30 / 20 paradigm / other /
   cross-paradigm shares go alongside them. `Rng.create(state.seed, "reward:%d:%d" % [layer, visited])` is already the
   deterministic stream to keep.
3. Then slices 5 to 13 in order. The remaining 65 cards of B8 come in slice 10, a paradigm at a time — rewrap the card
   comments to 87 columns in that pass (§2, gap 3).

Notes for the next session:
- Concurrent probe runs share Godot's sandbox scratch folder unless `XDG_DATA_HOME` is set per run (ADR-0048).
- `.obsidian/` at the root is the player's; leave it out of commits.
