# The Shardrun, deeper: a design bible for the Slay the Spire direction

This is an idea bank and a set of design rules, written on 2026-09-28 for the roadmap in `docs/ROADMAP.md`. Nothing
here is decided until an ADR accepts it. The roadmap says what comes first; this file says what the pieces could be.
Numbers are starting points for the balance sim (ROADMAP, stage 0), not tuned values.

## 1. What must stay true

- **A turn is a program.** Cards are real functions (Python and JavaScript), the order you play them is the code,
  the sandbox runs it, and the rules resolve what comes back (ADR-0012). No card is a number in a costume: each is an
  algorithm you could lift into your own code.
- **The preview is the cast**, and the code is always on the table (ADR-0006, ADR-0013, ADR-0015).
- **Every mechanic teaches something true about software.** This is the test for every idea below: does it make the
  player write a more interesting program, make a real trade-off, or learn a real idea? If none, it is just a number.
- **Enemies are bugs**, and the fantasy is debugging a hostile machine.

## 2. What the measurements say

A one-turn-lookahead bot tried every legal program each turn in the real sandbox, 40 runs across the five paradigms
(ROADMAP section 2 has the full table). What shapes the design below:

1. **Salvo is the whole engine.** With Salvo in hand a turn does 56 damage on average, without it 5. A program starts
   from one 3-power bolt and every other card only transforms it, so a hand without Salvo is dead: in 9% of turns
   the best program was an empty one.
2. **The difficulty is a cliff, not a curve.** Act 1 fights last 1.5 turns and cost 1 Integrity. The Act 2 boss (the
   Deadlock Golem, whose pattern ward quarters any bolt of the wrong element) ends half of all runs. The strong bot
   won 1 run in 40.
3. **Order matters, which is the good news.** In 40% of turns a reordered program beat every program in dealt order.
   A bot that plays its hand in dealt order never beat the Act 2 boss (0 of 30). Thinking pays; the core idea works.
4. **The speed race is mostly a small tax.** A foe acted first in 18% of turns; no chosen program ever timed out
   (1% of possible programs did). It penalises slowness a little and never rewards speed.
5. **Nothing grows inside a fight**, and paradigm identity fades after the draft (rewards draw from every card).

## 3. Core loop v2

### 3.1 Card roles, and the input problem

Every card has one role, shown on its face in words and a glyph:

| Role | Does | Today | Wanted |
|---|---|---|---|
| **Source** | makes bolts | Salvo (and Fork, Pairwise, which multiply) | 3 to 4 in every starting deck, one per paradigm pool |
| **Shape** | changes bolts | Amplify, Kindle, Divide, Tabulate... | as now |
| **Order** | arranges the volley | Merge Sort | sorts, reversals, heaps |
| **Strike** | aims bolts at foes | Round Robin, Binary Execute, Greedy Assign... | as now |
| **Guard** | turns bolts into defence | Ward | more shapes of defence |
| **Import** (new) | changes every program for the rest of the fight | none | section 3.3 |
| **Bug** (new) | a status card a foe puts in your deck | none | section 6.4 |

The input problem has three fixes. The what-if runs (ROADMAP section 2) settle which one does the real work: **a
stronger seed**. Two more Salvos in the starting deck raise the win rate, but a turn with Salvo still does ten times
what a turn without it does; programs that start from three bolts instead of one bring that to two times, halve the
empty programs, and make reordering matter in more turns (53% against 40%), because every card now has something to
work on. More sources are still wanted, for texture and for deck building; they are just not the fix.

- **A stronger seed** set by the class (a starter relic such as `main.py` reading three bolts instead of one). It
  makes Act 1 trivial on its own, so it comes with a curve that is harder at the start and gentler later.
- **More sources, of different shapes**, so deck building has an "attack density" to manage, as Slay the Spire does:
  `Literal` (one 9-power bolt, O(1)), `Repeat` (`[4] * 3`, O(k)), `Read Input` (one bolt per living foe, its power
  that foe's intended damage: the battle is your input), `Monte Carlo` (eight random 1-6 bolts, seeded by the battle:
  the same preview every time), `Concat` (the volley twice over, cost 2), `Generator` (two bolts now and two at the
  start of every later program: `yield`, needs fight state).
- **Sources in the draft and rewards**: Salvo is in no draft pool today and turns up only in fight rewards.

### 3.2 The speed race v2

Keep what is there (a foe whose tempo is below your program's work acts first; your wards land after it; over the
budget is a timeout). Add the other half, so speed is worth buying:

- **Initiative**: a foe your program out-speeds takes +25% from your bolts this turn. The race bar marks those foes.
- **Speed per intent**: a quick jab (tempo 12) lands before nearly any program, a heavy slam (tempo 200) after nearly
  any. Every turn's race is different and readable: "the slam is slow, you have 200 ops to kill it first".
- **A budget per act**: 4096 in the Salvage, 2048 in the Heap, 1024 in the Kernel ("the Kernel gives you a short
  time slice"). Late programs must be efficient; relics raise it. This is how the game teaches that complexity
  matters at scale, without a lecture.
- **Interrupt** (sim first, may be too strong): a foe that loses half its HP to a program that out-sped it loses its
  intent this turn.

### 3.3 Growth inside a fight: imports and state

Slay the Spire's fights have an arc because of Powers (Strength, Demon Form). Here they are **imports**: cards played
into an `imports` rail that become lines at the top of `main.py` and hold for the fight.

| Import | Effect | The idea |
|---|---|---|
| `import heapq` | strike cards see the volley strongest first, free | a heap as a priority queue |
| `from functools import cache` | a card that already ran this fight does no work | memoisation |
| `import itertools` | Pairwise and Exhaustive Kill cost 1 less mana | the standard library |
| `import math` | Divide adds 2 per level instead of 1 | |
| `import numpy as np` | shape cards do O(1) work ("vectorised") | vectorisation |
| `sys.setrecursionlimit` | recursive cards never overflow (section 6) | the call stack |
| `global total` | every program adds its landed damage to `total`; the source `Release` makes a bolt of `total / 2` | state that persists |

The JavaScript run shows the same imports in its own idiom (`import { cache } from "./functools.js"`, `const memo = new
Map()`). State cards (`global`, generators, accumulators) need one new rule primitive: fight-scoped variables the
harness hands to the code and reads back.

### 3.4 Keywords (programming words, each with a one-line tooltip and a Codex entry)

| Keyword | Slay the Spire | Meaning here |
|---|---|---|
| `once` | Exhaust | runs once per fight, then is gone until the next |
| `volatile` | Ethereal | leaves your hand at the end of the turn if not played |
| `const` | Retain | stays in your hand between turns |
| `__init__` | Innate | always in your opening hand |
| `lambda` | Shiv | a generated 0-cost `once` card |
| `pure` | (new) | has no side effects: a Race Condition cannot reorder it (section 6) |
| `async` | (new) | lands at the start of the next turn |
| `recursive` | (new) | its calls are counted; the Stack Overflow Serpent cares |

At most two keywords on a card.

### 3.5 Upgrades are refactors

Every card gets a `+` version, written as data and code and proven by worked examples like the base card. Upgrading
shows **the diff**: a small lesson in refactoring every time. Three kinds:

- **Tune**: numbers (Amplify +3 to +4).
- **Optimise**: complexity. Bubble Sort (O(n²), cost 0) to Insertion Sort (O(n) on nearly sorted input) to Merge
  Sort. Fibonacci Surge to Fibonacci Table exists already and is the model.
- **Generalise**: behaviour (Round Robin+ skips foes that are already down, so nothing is wasted).

### 3.6 Onboarding

The dealt-order bot never passed the Act 2 boss, which means a new player who does not yet see why order matters
will hit a wall. The first fights should teach one idea each (source first; sort before search; aim last), with the
preview explaining the difference a reorder makes ("move Merge Sort before Binary Execute: 2 kills instead of 0").

## 4. The run: acts, map and rooms

### 4.1 Acts

| Act | Place | Its bugs | Bosses (one per run, shown on the map from the start) |
|---|---|---|---|
| 1 | The Salvage | syntax and logic bugs: off-by-one, null, typos | Kiln Warden, The Monolith, Spaghetti Hydra |
| 2 | The Heap | memory and data bugs: leaks, dangling pointers, garbage | Deadlock Golem (reworked), Fragmentation Wyrm, The Hoarder |
| 3 | The Kernel | systems bugs: races, overflows, segfaults, fork bombs | Root Daemon (reworked), The Scheduler, Kernel Panic |
| 4 | The Root | the finale, behind three keys | The Halting Oracle |

Each act has an easy pool (its first two or three fights), a hard pool, three elites and three bosses. Acts grow from
8-9 rows to 10-11 plus the boss; the code walkthrough makes each fight longer than Slay the Spire's, so acts should
stay shorter than its 15 floors. Later, alternate acts for replay (section 13).

### 4.2 Rooms

| Room | Today | Proposed |
|---|---|---|
| Fight, elite, boss | yes | pools per act; boss portrait on the map; "burning" elites that carry a key |
| Rest | heal 30% | heal 30% **or** refactor a card (Slay the Spire's campfire choice); later: lint (remove a bug card) |
| Forge | optimise, widen, melt | folded into rest (refactor) and the shop (remove); widening becomes a relic or an event |
| Shop | none | **The Registry**: cards, relics, scripts; `uninstall` removes a card (75 cycles, +25 each time) |
| Event (?) | none | **Issues**: choices with a cost (section 11) |
| Treasure | a relic, sometimes cursed | as now, plus cycles |

**Keys to the Root**: three, from a burning elite, a treasure (take the key instead of the relic) and a rest site
(recall instead of resting or refactoring). Slay the Spire's emerald, sapphire and ruby.

### 4.3 Economy

- **Cycles** (the currency): about 15 per fight, 30 per elite, 90 per boss, plus events.
- **Card rewards**: three choices and a skip, weighted toward the class and its paradigm, with a rising chance of a
  rare each time a rare is not offered (Slay the Spire's pity).
- **Scripts** (potions): three belt slots, a 40% drop chance after a fight (section 10).

## 5. Classes

### 5.1 What a class is

A class has its own card pool (20 to launch, about 45 when whole), a starter deck of 10, a starter relic, one unique
mechanic (usually one new rule primitive), two or three archetypes, a character (sprite, portrait, spell palette) and
**a programming domain it teaches**. Neutral cards, scripts, most relics, the foes and the acts are shared. The
current draft becomes every class's opening: pick one of its archetypes (at most three on offer), whose signature
cards join the deck.

The Artificer's archetypes are the five paradigms that exist today. The other classes come from the character
concepts in `Concept/newCharacters/`.

### 5.2 The roster

| Character | Class | Domain | Mechanic |
|---|---|---|---|
| Vesper | Artificer | algorithms on data | the volley pipeline and the speed race (exists) |
| Kurogane | Ward Duelist | control flow, exceptions | branches, `try`/`except`, counters |
| Sai | Storm Cartographer | graphs | foes form a graph; lightning traverses it |
| Oren | Ember Alchemist | async, time | brews are promises that resolve later |
| Nyra | Thorn Compiler | trees, recursion, metaprogramming | a syntax tree grows on the stage |
| Ari | Rootglass Lancer | memory, pointers | memory cells, `alloc`, `free`, dereference |
| Lys | Star-Thread Witch | concurrency | two programs a turn, run in parallel |
| Aster | Comet Scribe | strings, parsing, regex | the volley is text |
| Pip and Acorn | Pocket Shardrunner | first steps (for young players) | a gentler Artificer, block code |

**Vesper, the Artificer** (exists; becomes the reference class). Archetypes: the five paradigms, each with a
signature source and six to eight cards (section 7). Starter deck: Salvo ×2, Literal ×2, Fork, Amplify, Ward ×2,
Round Robin, Kindle. Starter relic `main.py` (the seed, per the sim). Teaches arrays, sorting, searching, greedy
against dynamic programming, complexity.

**Kurogane, the Ward Duelist** (recommended second). A swordsman who parries bugs. His programs **branch**: an `if`
card takes the next card as its then-branch and the one after as its else-branch (`if front foe attacks: ... else:
...`), shown as real indented code. **Exceptions are his resource**: damage his block stops is kept as *Raised*;
`except` cards catch it and turn it into counter-bolts at the attacker; `finally` cards happen even if the program
crashes. Archetypes: Counter (riposte on Raised), Fortress (block that persists through `finally`), Guard Clauses
(`return` early: short programs, fast tempo, Initiative). Teaches conditionals, early return, exceptions and
defensive programming, the first ideas a beginner needs, which pairs him with the Academy. Rule primitives: branching
cards (a card with child slots), a Raised counter, a retaliation hook; enemies reuse the first two.

**Sai, the Storm Cartographer.** Foes are nodes of a graph (neighbours on the stage, summoners linked to their
summons). Lightning traverses it: `BFS Chain` hits every foe nearest first at falling power, `DFS Dive` reaches the
backline, `Dijkstra Arc` takes the cheapest path (shields are edge weights), `Spanning Tree` links every foe so later
bolts arc along it. Without a `visited` set a traversal loops: the bug card *Missing Visited* times your program out,
and that is the lesson. Archetypes: Chain, Pathfinder, Network. Teaches graphs, BFS/DFS, shortest paths, spanning
trees, cycles. Spectacular to draw; wants the multi-foe encounters of stage 4.

**Oren, the Ember Alchemist.** Brews take time. `brew` cards schedule an effect for a later turn (a flask with a
countdown, on the stage); `await` resolves one now at a price; at the end of each program the event loop resolves
what is ready in order, microtasks before macrotasks, which is a real ordering puzzle. Burn stacks like poison.
Archetypes: Brewer (big delayed payoffs), Burn, Event Loop (many small callbacks). Teaches async/await, promises,
callbacks and the event loop. Primitive: a per-fight queue of scheduled effects.

**Nyra, the Thorn Compiler.** A thorny syntax tree grows on the stage. Cards insert nodes (a binary search tree by
power); strikes traverse it (in-order gives a sorted volley, level-order goes by depth); rotations keep it balanced,
and a balanced tree's traversals do less work (a faster program). Compile cards rewrite the cards in your hand
(inline two into one, optimise one for the fight, a macro that makes lambdas). Archetypes: Grove, Balance,
Metaprogram. Teaches trees, BSTs, heaps, traversals, recursion, balancing, and what a compiler does.

**Ari, the Rootglass Lancer.** Six memory cells on her spear. `alloc` stores bolts across turns; `*ptr` strikes
dereference a cell; `free` gives mana back; cells left full too long leak (a stacking debuff). `next` pointers link
cells so a strike follows the chain. Archetypes: Allocator, Pointer (mark a foe; every bolt dereferences to it,
piercing shields), Linked. Teaches references against values, pointers, stack and heap, leaks, use-after-free.

**Lys, the Star-Thread Witch** (an advanced class, unlocked later). She writes two programs a turn that run as
threads: the turn's work is the slower of the two (a parallel speedup), but cards touching the shared volley race,
shown on a timeline; `lock` cards serialise, and two locks taken in opposite orders deadlock. Teaches threads, races,
locks, deadlock, Amdahl's law.

**Aster, the Comet Scribe.** Her volley is text. Cards split, join, reverse and map characters; foes carry names and
patterns, and a word that matches a foe's pattern (a regex) crits; parse cards turn text into bolts (tokenise, parse,
evaluate). Teaches strings, regex, parsing, and Unicode (kana and kanji runes would delight young Japanese players).
The biggest rule change of all: a second shape of volley. Last.

**Pip and Acorn, the Pocket Shardrunner.** The Artificer made gentle for young players: three slots, no speed race,
cards shown as colourful blocks with Japanese text, Acorn (the ward sprite) blocking a little every turn, and no
run-ending death (Pip goes home tired, with loot). Teaches sequence, repetition and choice. Pairs with the Academy's
Pip's Path (see `docs/ACADEMY_DESIGN.md`).

### 5.3 Order, and why

1. **Vesper whole** first: every system the other classes need (roles, imports, keywords, upgrades, card art) is
   proven on the class that exists.
2. **Kurogane**: the most different playstyle (defence and counters against Vesper's offence), the most beginner
   concepts (if, return, try), and primitives the enemies reuse.
3. **Sai**: graphs are the next big idea in algorithms, and chain lightning across a crowd is the spell show the
   player loves.
4. Then Oren, Nyra, Ari, Lys and Aster as appetite allows; Pip when the daughters are ready for it.

## 6. Enemies: the Bug Bestiary

### 6.1 Rules

1. **Every foe is a real bug**, and it does to your *program* what that bug does to code.
2. **Everything is telegraphed**: intents show damage, speed and the mechanic's icon, and the code panel shows what
   the foe will do to your program before you run it (the Race Condition Imp draws its swap arrow between two cards).
3. **Every mechanic has a programming counter**, and that counter is the lesson.
4. **No key checks.** A boss tests a quality of a deck (burst, spread, precision, efficiency, scaling), never "did
   you draw this exact card this turn". The Golem's element pattern fails this test today.
5. The sim decides the numbers; a mechanic no paradigm can answer is redesigned, not buffed around.

### 6.2 Rule primitives the bestiary needs

- **Program hooks**: before the run (reorder, disable or inject cards), after the run (read the volley: size,
  sortedness, elements, recursion calls and work, which the sandbox already measures), on a hit (split, redirect,
  reflect), end of turn (grow, heal, revert).
- **Status cards** put into your draw pile, discard pile or hand (section 6.4).
- **Foe AI with conditions**, not only cycles: "below half HP: enrage", "every third turn", "when an ally falls".
- **Summons and multi-body foes.**

### 6.3 The roster

Existing foes get mechanics that match their names; the seven creatures of `Concept/Enemies/ENEMY_BRIEFS.md` get jobs.

| Foe | Act, kind | The bug | What it does to your program | The counter (the lesson) |
|---|---|---|---|---|
| Tally Wisp | 1 | a counter that only grows | +1 damage for every turn it lives | kill early |
| Off-by-One Goblin | 1 | fencepost error | aimed bolts land one foe to the right of their target | aim at i − 1, or kill it first |
| Null Wraith | 1 | null reference | swallows the first bolt that reaches it each turn (exists) | lead with a throwaway bolt (sort weakest first) |
| Syntax Slime | 1 (new) | errors that multiply | below half HP, splits into two; the halves add a *Null Pointer* bug | burst it past half in one program |
| Needlecap Mantis | 1 (brief) | two pointers from both ends | its crossed blades cut the first and last bolt of your volley | pad both ends; the edge case of a one-bolt volley |
| Scriptwing Moth | 1 (brief) | minified code | hides the other foes' intents while it lives; heals them | target it first |
| Regex Sphinx | 1 elite | pattern matching | full damage only from this turn's element (exists), next pattern shown | elements |
| Type Mimic | 1 elite | dynamic typing | its weakness changes every turn (exists) | read the type each turn |
| Kiln Warden | 1 boss | minimum size | bolts under 5 glance off (exists) | merge bolts (Hash Merge, Take Max) |
| The Monolith | 1 boss (new) | legacy code | shuffles a *Legacy Code* bug into your draw pile each turn; grows while undamaged | scaling, and removing bugs |
| Spaghetti Hydra | 1 boss (new) | tangled dependencies | a cut head grows two unless the body is hit by the same program | multi-target programs |
| Memory Leak Ooze | 2 | a leak | grows every turn; while it lives your budget shrinks by 256 a turn | burst it early |
| Dangling Pointer | 2 | use after free | bolts aimed at a foe already down this program hit *you* | exact aiming, no overkill |
| Race Condition Imp | 2 | a data race | if it acts before your program lands, it swaps two adjacent cards (shown before you run) | a program faster than it, `pure` cards, a `lock` |
| Shardshell Tortoise | 2 (brief) | encapsulation | gains 2 block per bolt in your volley before they land | few, big bolts |
| Recursive Hare | 2 (brief) | recursion | a hit that does not kill it splits it into two of half its HP; at 4 HP or less it cannot split | the base case: one big bolt, or area damage for the leaves |
| Garbage Collector | 2 elite | collection | bolts under 6 are collected and heal it (thick hide, exists in part) | merge bolts |
| Archive Crab | 2 elite (brief) | an index | takes +50% from a sorted volley, half from an unsorted one | sort first |
| Deadlock Golem | 2 boss (rework) | deadlock | two bodies, Lock A and Lock B: damage to one is blocked unless the same program hits both | acquire both locks: spread the volley |
| Fragmentation Wyrm | 2 boss (new) | fragmented memory | five segments; a segment breaks only to a run of *contiguous* bolts that sums past its HP | prefix sums, sliding windows, Kadane |
| The Hoarder | 2 boss (new) | a hoarding collector | wasted power (overkill, bolts at the dead) becomes its shield | exact kills |
| Segfault Specter | 3 | out of bounds | a volley of more than 12 bolts when it lands crashes the program | bound your data (Take Max, Hash Merge) |
| Stack Overflow Serpent | 3 | stack overflow | more than 64 recursive calls (measured by the sandbox) crash the program | iterative cards; optimise at a rest site |
| IRQ Hound | 3 (new) | interrupt storms | deals 2 to you for every card in your program past the third | short programs, imports |
| Scrollback Raven | 3 (brief) | revert | at the end of a turn heals all damage taken that turn unless it was half its HP or more ("uncommitted changes") | commit: burst |
| Fork Bomb | 3 elite | exponential growth | copies itself (at half HP) at the end of each turn it took no damage | area damage |
| Glassback Stag | 3 elite (brief) | a build pipeline | compile, test, deploy: a 40-damage charge after three turns; 25 damage in one program breaks the build | burst on a deadline |
| Root Daemon | 3 boss (rework) | privilege | three phases: `sudo` (your mana −1, its shield up), `chmod 000` (your imports stop), `kill -9` (it always acts first) | adapt; efficient programs |
| The Scheduler | 3 boss (new) | time slicing | each turn gives one foe priority (tempo 1) and summons a Thread | speed, Initiative |
| The Halting Oracle | 4 final (new) | the halting problem | each turn it predicts your program ("fewer than 8 bolts", "slower than O(n)", "aimed at me") and reflects the damage if it is right | write the program it did not predict (diagonalisation) |

About 30 foes against 15 today, with the Salvage's easy pool the gentlest (Tally Wisp, Null Wraith, Syntax Slime).

### 6.4 Bugs in your deck (status cards)

| Bug | Put there by | Effect | Removed by |
|---|---|---|---|
| Null Pointer | Syntax Slime | unplayable; `volatile` (Slay the Spire's Dazed) | the end of the turn |
| Off-by-One | Off-by-One Goblin | in a program, shifts the next card's aim by one | playing it |
| Infinite Loop | the Scheduler | if drawn it must be played: +1024 work | `once` |
| Memory Leak | Memory Leak Ooze | while in hand, your budget −512 | a rest site's lint |
| Legacy Code | The Monolith | costs 1, does nothing | the Registry, a rest site |
| Merge Conflict | events, a boss relic | unplayable until you discard another card with it | a rest site |

Counters: `Debugger` (remove a bug from your hand, draw one), `Unit Test` (bug cards in your program are skipped), the
import `Linter` (bugs are removed as they are drawn), the script `gc.collect()`.

## 7. The Artificer's card and combo bank

Each is a real algorithm that fits the `f(bolts, battle) -> bolts` contract unless marked (state, hook). Twenty-three
cards exist; about forty-five is the target.

| Card | Paradigm | Role | Class | The algorithm, and what it is for |
|---|---|---|---|---|
| Literal | neutral | source | O(1) | one 9-power bolt: the Strike |
| Repeat | neutral | source | O(k) | `[4] * 3` |
| Read Input | neutral | source | O(m) | one bolt per foe, power its intended damage |
| Reverse | neutral | order | O(n) | turns a sorted volley strongest first (Greedy wants it; the Null Wraith hates it) |
| Filter | neutral | shape | O(n) | drops bolts under 3; each dropped bolt adds 1 to the strongest |
| Reduce | neutral | shape | O(n) | the volley summed into one bolt (+10%) |
| Dedupe | neutral | shape | O(n) | a set: duplicate powers removed, each survivor +2 |
| Try / Except | neutral | guard | O(1) | if the program would crash or time out, a 10-block ward instead (hook) |
| Prefetch | neutral | utility | O(1) | `once`: draw 2 next turn |
| Quick Sort | D&C | order | O(n log n) average | cost 0, but O(n²) on an already sorted volley (first-element pivot), measured; the upgrade picks a random pivot |
| Counting Inversions | D&C | shape | O(n log n) | each bolt gains the number of stronger bolts before it: rewards disorder |
| Quickselect | D&C | strike | O(n) | the median splits the volley: the upper half at the toughest foe, the lower at the weakest |
| Fast Power | D&C | shape | O(log k) | `once`: the strongest bolt doubles three times, by repeated squaring |
| Bisect Insert | Search | source | O(log n) | inserts an 8-power bolt where it belongs, keeping the volley sorted |
| Hash Aim | Search | strike | O(n) | each bolt to the foe weak to its element (a dict lookup), else the front |
| Lower-Bound Ward | Search | guard | O(log n) | binary-searches the smallest bolt that covers the incoming damage and makes it block: exact defence |
| Two Pointers | Search | shape | O(n) | on a sorted volley, pairs smallest with largest into balanced bolts |
| Sliding Window | Search | shape | O(n) | each bolt becomes the sum of the window of three ending at it |
| Index Strike | Search | strike | O(1) | the bolt at index m (the number of foes) flies at the front foe, doubled: random access |
| Activity Selection | Greedy | strike | O(n log n) | bolts go first to the foes whose intents land soonest (earliest deadline first) |
| Coin Change (greedy) | Greedy | shape | O(n) | breaks the strongest bolt into 10s, 5s and 1s; fails on odd sizes, which is the lesson |
| Huffman Fuse | Greedy | shape | O(n log n) | a heap fuses the two weakest bolts (+1) until three remain |
| Load Balance | Greedy | strike | O(n log m) | each bolt to the foe with the most HP still standing after assignments |
| Bubble Sort | Brute | order | O(n²) | cost 0 and slow; upgrades into Insertion Sort, then Merge Sort |
| Nested Strike | Brute | strike | O(n·m) | every bolt at every foe in turn until each falls, full power, cost 2 |
| Power Set | Brute | source | O(2ⁿ), cap 5 | a bolt for every subset sum of the first five bolts: 31 bolts, very slow |
| Permutations | Brute | strike | O(n!), cap 6 | tries every order of up to six bolts across the foes for the most kills |
| Kadane | DP | shape | O(n) | the contiguous run with the largest sum fuses into one bolt (+1 per bolt); answers the Wyrm |
| Coin Change (DP) | DP | shape | O(n·H) | the fewest bolts that reach the front foe's HP exactly: optimal where the greedy one fails |
| LIS Strike | DP | strike | O(n log n) | the longest increasing run of bolts flies; the rest ward |
| Memo Table | DP | import | O(1) | `functools.cache`: a card that already ran this fight does no work |

**Combos worth teaching** (the insight is the point):

- **Salvo → Prefix Sum → Binary Execute**: prefix sums are sorted by construction, so no sort is needed. The clever
  programmer's move, already possible.
- **Merge Sort → Quick Sort**: a trap: quick sort on sorted input is quadratic, and the race bar shows it.
- **Coin Change (greedy) against Coin Change (DP)**: the same job, one fast and wrong on some inputs, one exact and
  slower. The classic lesson in why greedy is not always optimal, played.
- **Salvo → Fork → Pairwise**: a volley of 91 bolts in O(n²); glorious against a crowd, a timeout in the Kernel.
- **Salvo → Hash Merge → Take Max**: a few huge bolts for the Tortoise, the Kiln Warden, the Segfault Specter.
- **`import heapq` + Greedy Assign**: the heap does the sort, the greedy does the aiming, for free.
- **Bubble Sort, refactored twice**: the same card becomes Merge Sort over a run, and the forge shows both diffs.
- **Bisect Insert + Binary Execute**: a search deck that makes its own sorted input.

## 8. Relic bank

Relics should change a decision, not make every decision better. Today's program pool is ten flat bonuses and four
curses.

| Relic | Rarity | Effect | Changes |
|---|---|---|---|
| Overclock | common | budget +1024 | risk appetite |
| Profiler | common | intent speeds shown two turns ahead; your first card each turn does no work | planning |
| JIT Compiler | uncommon | a card sequence cast a second time in a fight does no work | repeating programs |
| Branch Predictor | uncommon | the first card of each program costs 0 mana | cheap openers |
| Big-O Compass | rare | +20% damage while your program is O(n) or faster | efficient builds |
| Heatsink | uncommon | a timeout refunds its mana and gives block for the overrun | brute force safety |
| Tail Call Seal | uncommon | recursive calls do not count (the Serpent is harmless) | recursive builds |
| Stable Sort Stone | uncommon | a volley that lands sorted gets +1 power per bolt | sorting |
| Radix Crystal | rare | sorting cards are O(n) | search builds |
| Checksum Seal | uncommon | +25% damage if every bolt shares one element | mono-element builds |
| Load Balancer | rare | overkill flows to the next living foe | aim-free builds |
| Lazy Evaluation | uncommon | bolts aimed at the fallen become block | aggressive aiming |
| Unix Philosophy | rare | programs of one or two cards deal double: do one thing well | tiny programs |
| Pipeline | rare | a program that fills every slot deals +30% | full programs |
| Monorepo | uncommon | +1 mana while your deck has 25 cards or more | big decks |
| Microservices | uncommon | draw +1 while your deck has 12 cards or fewer | thin decks |
| DRY Rune | uncommon | the second copy of a card in one program costs 0 | duplicates |
| Rubber Duck | common | once a fight, see your program's exact outcome even on Programmer | reading code |
| Git Stash | common | hold one more card | planning |
| Snapshot | rare | once a run, a blow that would end it restores you to the turn's start | safety |
| Legacy Mainframe | boss | +1 mana; your budget is halved | a trade |
| Managed Runtime | boss | draw +1; every program costs 64 more work | a trade |
| Root Access | boss | +2 mana; every fight starts with a Merge Conflict in hand | a trade |

## 9. Meta progression

- **Classes unlock** by play (win or reach Act 3 with the class before).
- **Class mastery** unlocks cards into the pool as a class is played (Slay the Spire's unlocks), so new players meet
  fewer ideas at once.
- **Strictness levels** (ascension, `-W1` to `-W15`, "warnings as errors"): each adds one modifier: elites stronger,
  rest heals less, the budget smaller, a bug in the starting deck, foes faster, a second boss in Act 3...
- **Explaining and difficulty come apart.** Today Beginner and Programmer set both how much the game explains
  (summaries, previews) and how hard it is (foe HP). Beginner and Programmer become the first only; strictness is the
  second. A player who reads code well can still want an easy run, and the reverse.
- **The Library** (Codex): every card with its code in both languages and the algorithm explained; every foe with the
  real bug it stands for and how to fix that bug in real code; every relic. Links to Academy lessons.
- **Run history** (`git log`): every finished run, kept locally: class, paradigm, deck, relics, path, the killer,
  the seed to replay it. It is also the best balance data there is: the player's own runs beside the bot's.
- **Daily Build**: a seed a day with one modifier ("everything is O(n²) today").
- **Achievements tied to programming**: a fight with no overkill, a win with no O(n²) card, a whole act with no
  timeout.

## 10. Scripts (potions)

| Script | Effect |
|---|---|
| `hotfix.sh` | heal 10 |
| `sudo` | the next program deals double damage |
| `kill -9` | 25 damage to one foe |
| `nice -n -20` | this turn your program counts as 0 work (it acts first, with Initiative) |
| `git revert` | undo the damage you took last turn (up to 15) |
| `gc.collect()` | remove every bug card from your hand |
| `print()` | see every foe's next two intents |
| `pip install` | add a random class card to your hand; it costs 0 this turn |
| `cache warm` | draw 3 |
| `strace` | a foe's trait is off for a turn |
| `ulimit` | a foe's next attack deals half |
| `touch` | a 0-cost Literal in your hand |

## 11. Events ("Issues")

| Issue | Choice |
|---|---|
| A Stack Overflow answer | copy a card; half the time the copy is buggy (a bug card joins too) |
| Legacy codebase | refactor two cards and lose 8 Integrity, or walk away |
| The Rubber Duck | predict the output of a snippet taken from your own deck: right gives a rare card; wrong costs nothing |
| Code review | remove a card, or refactor one, or take 50 cycles |
| Hackathon | fight an elite now for a rare relic |
| Deprecated API | transform a card into another of the same role |
| Dependency hell | a strong relic, and two Merge Conflicts |
| Rewrite it in Rust | every common card becomes a random uncommon; lose 1 max Integrity per card changed |
| Merge conflict | two cards; keep one, lose the other |
| The open-source maintainer | give 50 cycles now; a relic waits for you two floors later |
| The Oracle's test suite | three programs; pick the one that passes (reading code) for cycles |
| The coffee machine | heal, or +4 max Integrity, or a script |

The Rubber Duck and the Oracle's test suite borrow the Academy's reading interaction without making the run a lesson.

## 12. Presentation, per stage

- **Card art** for every card (the frame is done; `pipeline/art`). A card of its own is part of "done" for a card.
- **Foe sprites** for every new foe from the enemy briefs (ADR-0008's sprite pipeline), idle and hit frames at least;
  boss intros; per-mechanic effects (the Imp's swap arrow, the Specter's out-of-bounds flash, the Hare's split).
- **Class characters**: each concept sheet becomes a small, cute sprite skin with idle, cast, hurt, guard and victory
  clips, a portrait, and a spell palette (Kurogane's cuts, Sai's lightning, Oren's flasks, Nyra's vines).
- **Spell animations per role and paradigm** (Phase 8's open item): a sort, a search, a split, a merge each look
  different.
- **The Root**: a new backdrop, music, and the Oracle's own stage.

## 13. Later

- **Alternate acts** for replay: the Rootwood (a forest act of graphs, with the brief's creatures), the Archive (a
  database act: queries, indexes, joins), the Network (packets, latency, retries).
- **Endless mode** after the Root, and a boss rush.
- **The Card Workshop**: write your own card in the Academy's editor, prove it with worked examples, and play it in a
  sandbox run (never in ranked runs). The original promise of the game, "your spells are your code", made literal.
