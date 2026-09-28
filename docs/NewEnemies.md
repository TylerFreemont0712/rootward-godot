# New bosses: a guardian pool for every stage

Written on 2026-09-28, at the player's request: *"7-8 different bosses that have different mechanics that can be
cycled for the different stages … gimmicks that are related to programming that should change how the player
approaches a fight."* It also asked for a fourth stage after the Kernel, and a final score at the end of a run. Then:
*"how about 2 more for each level? Starting to realize that 3 is just a little bit too small of a pool."*

This file is the design. What is built so far is marked **(built)**; the rest is a proposal for the player to accept,
cut or change. Art is a placeholder from ComfyUI in each boss's in-game sprite slot (`game/assets/foes/<id>.png`,
prompts in `pipeline/art/manifest.json` under `foe-<id>`). Better art comes later.

## How bosses cycle

Each stage has a **pool** of guardians. A run draws one per stage from the seed (`ShardrunRules.encounter_for`
already does this for any list), so two runs can meet different bosses. The plan is to show the drawn boss on the
map from the start (as in Slay the Spire), so a player can draft toward it.

| Stage | Place | What its bugs are about | Guardian pool |
|---|---|---|---|
| 1 | The Salvage | syntax and logic | Kiln Warden (exists), **Ouroboros**, **The Unhandled Exception**, **The Short Circuit**, **The Unreachable** |
| 2 | The Heap | memory and data | Deadlock Golem (exists), **The Cache Lich**, **Malloc, the Heap Matron**, **The Page Fault**, **The Thunk** |
| 3 | The Kernel | systems and numbers | Root Daemon (exists), **The Call Stack Colossus**, **INT_MAX**, **The Profiler**, **The Livelock Twins** |
| 4 | The Root (new) | the machine's own source | **The Quine** (built), **The Root Compiler** (the finale), **The Mutator**, **Karp, the NP Koi**, The Halting Oracle (earlier idea) |

Five a stage. Sixteen are designed here, with placeholder art for each; three existed before, and the Halting Oracle
comes from the earlier ideas below.

The rules every boss here follows (from `docs/SHARDRUN_DESIGN.md`, section 6.1):

1. **The gimmick is a real bug or a real idea**, and it does to your *program* what that idea does to code.
2. **Everything is telegraphed** before you run: intents show their numbers and speed, and the code panel says what
   the boss will do to this program.
3. **Every gimmick has a programming counter, and the counter is the lesson.**
4. **No key checks.** A boss tests a quality of a deck (burst, spread, variety, precision, defence), never "did you
   draw this one card". Each boss below names the quality it tests, and no two test the same one.

## Reading the stats

- **Base HP** is before the stage multiplier. A program run multiplies it by the stage: 2.4, 3.6, 4.6 and 5.4 (the
  Root), and Beginner by 0.85 again. "Run HP" is Programmer difficulty.
- **Intents** go in a cycle unless noted. The number after `t` is the intent's tempo: the operations it waits before
  acting. A program doing more work than that lands after the boss moves. Lower is faster.
- Foe attacks do not scale by stage; only HP does. The Maintainer starts a program run with 60 Integrity.

For comparison, the current guardians: Kiln Warden 95 base (228 in a run), the two Golem Locks 70 each (252 each),
the Root Daemon 200 (920).

---

## Stage 1: the Salvage

### Ouroboros, the Endless Loop

> `while True:` A serpent eating its own tail. Every turn it goes around once more, unless you give it a reason to
> `break`.

| | |
|---|---|
| Base HP / run HP | 100 / 240 |
| Size | huge |
| Weak / resist | frost / none |
| Tests | reading a condition, and shaping a volley on purpose |
| Counter (the lesson) | every loop needs an exit condition you can actually reach |

**The mechanic: `break` conditions.** Each turn Ouroboros shows a guard, drawn in the code panel as a real line:
`if len(volley) == 3: break`. If the volley your program lands meets it, the loop breaks: its loop counter resets,
it is **stunned** (it skips its next action), and that program deals **+50%** to it. If not, the loop goes around
again: its counter rises by one.

The guards, one a turn, from its seeded pool:

| Guard | How a deck meets it |
|---|---|
| `len(volley) == 3` | the seed alone, or Fork, Salvo and Take Max to trim or grow |
| `len(volley) >= 6` | Fork, Salvo, Repeat, Pairwise |
| `volley == sorted(volley)` | Merge Sort, Bisect Insert, any `makes: sorted` card last |
| `any(b.element == "fire" for b in volley)` | Kindle, Fire Constant; or `frost` / `spark` on other turns |
| `max(powers) >= 12` | Amplify, Take Max, Hash Merge |
| `sum(powers) >= 30` | any strong program |

**Intents**

| Intent | What | t |
|---|---|---|
| Bite | strike 7 | 48 |
| Coil | shield 8 | 96 |
| Loop | strike 3, *counter* times (starts at 2, +1 each unbroken turn, at most 8) | 160 |

Loop is the threat: left alone for four turns it hits 6 times for 3, 18 damage, and keeps growing. Breaking it every
other turn keeps it harmless. The Loop's tempo is slow, so a cheap program lands first and can break it in time.

**Needs:** a guard shown per turn (a trait with a seeded list, like the Regex Sphinx's pattern), a check of the
landed volley (the landing context already has it), a stun, and a counter on the foe.

### The Unhandled Exception

> `raise ValueError("…")` A brute that throws errors at you. Catch one and it goes back where it came from.

| | |
|---|---|
| Base HP / run HP | 90 / 216 |
| Size | huge |
| Weak / resist | spark / fire |
| Tests | defence as offence: when to guard instead of strike |
| Counter (the lesson) | `try` / `except`: an error you handle is not a crash |

**The mechanic: `raise`.** Its throws are a new kind of attack. When it throws, if your block is **at least** the
throw's power, the exception is **caught**: you take nothing, your block is spent, and the exception bounces back
into it for **150%** of its power. A throw you do not fully catch hits as a strike (block still softens it), and the
stack trace grows: every later throw has **+2 power** (at most +8).

Every fourth turn it plays `finally:`, a strike that cannot be caught. You have to be standing for it.

**Intents**

| Intent | What | t |
|---|---|---|
| `raise ValueError` | throw 10 | 128 |
| `try:` | shield 10 | 96 |
| `raise TypeError` | throw 13 | 160 |
| `finally:` | strike 9, cannot be caught | 64 |

It makes Ward, Greedy Ward, Knapsack Ward and Zip Ward into weapons, and punishes an all-offence deck without
punishing it to death: a player who never catches still wins, only hurt. It is the gentlest boss of the eight, and
teaches the idea a beginner needs first after `if`.

**Needs:** a `throw` intent (a strike with a catch check), a per-foe counter for the growing trace, an uncatchable
flag on a strike.

### The Short Circuit

> `if bolt >= 12 and ...` A knight of live wire. If the first test fails, Python never even looks at the rest.

| | |
|---|---|
| Base HP / run HP | 95 / 228 |
| Size | huge |
| Weak / resist | frost / spark |
| Tests | order: what goes *first* |
| Counter (the lesson) | `and` and `or` short-circuit: once the first test decides, the rest is never evaluated |

**The mechanic: a guard on the first bolt.** Each turn it shows a guard value (8, then 12, then 16, round and round).
The **first** attacking bolt aimed at it is evaluated against it:

- **Below the guard** (`False and ...`): the whole condition is already false, so every *later* bolt aimed at it in
  that program is **short-circuited**. They never land (logged, and drawn as fizzling sparks).
- **At or above** (`True and ...`): everything lands, and the first bolt deals **double**.

A deck that leads with its biggest bolt is rewarded. A deck that leads with small ones loses its whole volley. Reverse,
Take Max, `import heapq` (strongest first), Literal and Hash Merge are the tools. The default order (weakest first, the
seed's) is exactly wrong, which is the point: the player has to think about which bolt runs first. The code panel
shows `if 4 >= 12 and ...` with the real first bolt before you run.

**Intents**

| Intent | What | t |
|---|---|---|
| Arc | strike 8 | 64 |
| Surge | strike 3, 3 times | 96 |
| Ground | shield 10 | 128 |
| Overload | strike 14 | 192 |

**Needs:** a per-program check of the first bolt at a foe in the landing (the landing already walks bolts in order),
a cycling guard value like the Regex Sphinx's pattern.

### The Unreachable

> A gravekeeper who plants a `return` in your function. Everything written after it is dead code.

| | |
|---|---|
| Base HP / run HP | 105 / 252 |
| Size | huge |
| Weak / resist | fire / none |
| Tests | compactness: the most from the fewest cards |
| Counter (the lesson) | `return` ends a function: code after it never runs |

**The mechanic: a `return` in your program.** Each turn it buries a `return` at a line of your Program: after slot 5,
then 4, then 3, then 4 again. Cards placed in that slot or later are **dead code**: they are greyed in the code panel
with the `return` drawn above them, they do not run, and they still cost their mana (you wrote them, after all). The
seed still runs, so an empty program still does something.

On a slot-3 turn the question is which three cards matter most. Imports (which are lines at the top, not slots) keep
working, so do `const` cards held from earlier turns. It punishes long, loose combos and rewards a deck of strong
single cards and upgrades (a + card does more per slot).

**Intents**

| Intent | What | t |
|---|---|---|
| Dig | strike 9 | 96 |
| Bury | shield 12 | 64 |
| Epitaph | strike 4, 2 times | 128 |

**Needs:** a hook before the program runs that cuts its cards at a slot (the sandbox then runs only what is left, so
the preview stays a real run), and the dead lines drawn in the code panel.

---

## Stage 2: the Heap

### The Cache Lich

> Six glowing cubes orbit it: its cache. Ask it something it already knows and it does not even look up.

| | |
|---|---|
| Base HP / run HP | 85 / 306 |
| Size | huge |
| Weak / resist | fire / frost |
| Tests | variety: many *different* values |
| Counter (the lesson) | an LRU cache: the same input gives the same answer, so only a new input costs anything |

**The mechanic: an LRU cache of bolt powers.** The Lich remembers the last **6** different bolt powers that hit it,
shown over its head as six slots with numbers. A bolt whose power is in the cache is a **cache hit**: it deals 0 and
moves that number to the front. A **miss** hurts in full, enters the cache, and pushes out the least recently used
number. Below half HP the cache warms up to **8** slots.

The seed is three bolts of 3, so an untouched volley deals one bolt and two cache hits. Round Robin's equal bolts
are nearly useless; Prefix Sum (every bolt larger than the last), Dedupe, Amplify on one bolt, Pascal Row and Fibonacci
Surge are strong. The cache is always on screen, so a player can even plan around what is in it.

**Intents**

| Intent | What | t |
|---|---|---|
| Recall | strike 11 | 128 |
| Warm the cache | shield 12 | 96 |
| Memoize | heal 14 | 192 |
| Prefetch | strike 4, 3 times | 64 |

**Needs:** a per-foe list (the cache) that the landing reads and writes in bolt order, and a view of it.

### Malloc, the Heap Matron

> A spider of glass and brass. Every turn she allocates another block, and she never frees anything.

| | |
|---|---|
| Base HP / run HP | 95 / 342 (and her blocks, 10 base / 36 each) |
| Size | huge, with small minions |
| Weak / resist | none / spark |
| Tests | spread: cleaning up many small things while pressing one big one |
| Counter (the lesson) | every `malloc` needs a `free`, or the program runs out of memory |

**The mechanic: allocation.** Her `malloc()` intent summons a **Heap Block** beside her (a small foe with no attack).
Each living block gives her **+3 shield** at the start of every turn. When **5** blocks are alive at once she hits
**Out of Memory**: a strike of 6 per block (30), and every block is freed. Destroying a block yourself is `free()`:
it gives you **3 block**.

A focus deck that only hits her watches her shield grow and eats an Out of Memory every five turns. A spread deck
(Round Robin, Load Balance, Sweep, Chain Lightning) frees blocks as it goes. Aiming matters too: blocks shift the
indices of the foes behind them, as inserting into a list does.

**Intents**

| Intent | What | t |
|---|---|---|
| `malloc()` | summon a Heap Block | 48 |
| Bite | strike 10 | 160 |
| `realloc()` | heal 4 per living block | 128 |

**Needs:** summons (a foe added mid-fight, named in `docs/SHARDRUN_DESIGN.md` 6.2), a start-of-turn effect per living
ally, a threshold attack.

### The Page Fault

> A spellbook with three pages, and only one of them is in memory at a time.

| | |
|---|---|
| Base HP / run HP | three pages of 40 (120 / 432 in all) |
| Size | large, three bodies |
| Weak / resist | fire / none |
| Tests | focus: everything at one target |
| Counter (the lesson) | locality of reference: work on what is already in memory, or pay a page fault every time |

**The mechanic: one resident page.** The Page Fault is three foes (Page A, B and C, one sprite drawn three times), and
only one is **resident**, glowing, at a time. Bolts at the resident page land normally. A bolt at a page that is **not**
resident is a **page fault**: it does nothing, and that page is swapped in (it becomes the resident one for the rest of
the program) while the old one is swapped out. At the end of each turn the page that has been out longest swaps in,
and the map of pages shows which one is next.

So a volley spread across three targets thrashes, landing almost nothing. A volley aimed at one page lands whole. It
is the exact opposite of the Deadlock Golem (which demands spread), and a deck that learned "spread everything" at the
Golem has to learn when not to. Take Max, Binary Execute and aiming at the front all shine; Round Robin and Load
Balance thrash.

**Intents** (each page)

| Intent | What | t |
|---|---|---|
| Read | strike 12 (resident page only) | 128 |
| Swap | heal 8 to the pages swapped out | 96 |
| Flutter | strike 4, 3 times | 64 |

**Needs:** a group of foes with a shared "resident" flag (the Golem locks already share a partner reference), a lost
bolt kind in the landing, a swap at end of turn.

### The Thunk

> A dragon too lazy to take damage now. It will take it all later, when something forces it to.

| | |
|---|---|
| Base HP / run HP | 110 / 396 |
| Size | colossal |
| Weak / resist | spark / frost |
| Tests | setup and payoff: many bolts, then one big one last |
| Counter (the lesson) | lazy evaluation: a value is not computed until something forces it |

**The mechanic: lazy damage.** Hits on the Thunk do not reduce its HP. They pile up as **pending damage** (a ghost
bar over its real one). A bolt of **15 power or more** forces evaluation: all pending damage lands at once, with the
forcing bolt, for **+25%**. At the end of every turn, pending damage that was never forced **halves** (unevaluated
thunks get collected).

The best program is many small bolts then one big one at the end: exactly the sorted, weakest-first order the Short
Circuit punishes. Played in the same run, the two teach that order is a choice, not a habit. Every intent is slow, so
the Thunk almost never moves before your program (it is lazy): Initiative is easy here.

**Intents**

| Intent | What | t |
|---|---|---|
| Yawn | heal 10 | 256 |
| Lazy swipe | strike 13 | 192 |
| Nap | shield 16 | 160 |

**Needs:** a per-foe pending total, a force threshold checked per bolt, a decay at end of turn.

---

## Stage 3: the Kernel

### The Call Stack Colossus

> A tower of stone frames. Only the top one can be touched, and every turn it calls itself again.

| | |
|---|---|
| Base HP / run HP | its frames: 50, 35, 30, 30 (145 / 667), and 30 per new frame |
| Size | colossal |
| Weak / resist | none / none |
| Tests | precision: many bolts, each sized to its target, in the right order |
| Counter (the lesson) | a stack is last in, first out: a call returns before the one below it can |

**The mechanic: LIFO frames.** The Colossus is a stack of frames (`main()`, `parse()`, `eval()`, `eval()`, top last),
each with its own HP bar. Bolts land in volley order on the **top** frame. When a frame breaks it is **popped**, and the
next bolt hits the frame below. Damage past a frame's HP is lost: a function's return value that nobody reads.

Every turn that no frame was popped it **pushes** a new `eval()` frame of 30 (recursion). If the stack reaches
**8 frames** it overflows: **Stack Overflow** deals 25 to you, and it drops back to 4 frames.

One enormous bolt pops one frame. Ten bolts sized to the frames, in the right order, pop four. Knapsack Strike,
Greedy Assign, Binary Execute and Sort (to line bolts up with the frames from the top down) all shine, and the
Brute Force player gets a real puzzle.

**Intents**

| Intent | What | t |
|---|---|---|
| Crush | strike 14 | 192 |
| Unwind | strike 5, 3 times | 128 |
| `return` | shield 18 on the top frame | 96 |

**Needs:** a multi-part foe (the frames as one foe with a list of HP bars, or as linked foes where only the top can be
aimed at), overkill discarded per frame (the landing already counts waste), a push per quiet turn.

### INT_MAX, the Overflow Titan

> Its chest is a counter that has been going up for a very long time. Hit it too hard and the number wraps around.

| | |
|---|---|
| Base HP / run HP | 210 / 966 |
| Size | colossal |
| Weak / resist | frost / fire |
| Tests | restraint: controlled power, spread over many bolts |
| Counter (the lesson) | fixed-width integers wrap: an `int8` holds -128 to 127, and 128 is -128 |

**The mechanic: 8-bit damage.** Every bolt's damage to it is stored in a signed byte. Damage of **127 or less** lands
normally. Damage above that **wraps**: 128 becomes -128, 200 becomes -56, and a negative number **heals** it. The
number over the hit shows the wrap (`200 → -56`), so the player sees the bug happen.

By the Kernel, the decks that won the Heap make huge bolts (Amplify chains, Hash Merge, Take Max). INT_MAX turns them
against themselves: split big bolts (Divide, Fork, Split), cap them, or spread them. It is the opposite test from the
Kiln Warden (bolts under 5 glance off), and a deck that beat both has range.

Its own attack overflows too: **Count** strikes for 16, then 32, then 64, doubling each time, and at 128 it wraps to
-128 and does nothing (`Overflow fault`, it is stunned instead). The 64 turn is the one to survive or to pre-empt.

**Intents**

| Intent | What | t |
|---|---|---|
| Count | strike 16, doubling each time it is used; at 128 it wraps and stuns itself | 160 |
| Cool down | shield 20 | 96 |
| Carry the one | strike 6, 3 times | 128 |

**Needs:** a per-bolt damage transform in the landing (like the thick hide's check), a doubling intent with a wrap.

### The Profiler

> A clockwork owl with a stopwatch for a heart. It times your program, and slow code barely scratches it.

| | |
|---|---|
| Base HP / run HP | 200 / 920 |
| Size | colossal |
| Weak / resist | none / none |
| Tests | efficiency: the complexity class of the whole program |
| Counter (the lesson) | Big-O: the slowest stage decides how a program scales |

**The mechanic: damage by complexity class.** Every program is profiled, and its damage to the Profiler is multiplied
by its slowest class (the one the code panel already shows):

| Slowest class | × damage |
|---|---|
| O(1), O(log n) | 1.5 |
| O(n) | 1.25 |
| O(n log n) | 1 |
| O(n·H) | 0.75 |
| O(n²) | 0.5 |
| O(2ⁿ) | 0.25 |

The code panel marks the **hot path**, the stage that did the most work, with a 🔥, so the player sees which card to
replace. This is the game's core idea as a boss. It is hard on Brute Force, but not a key check: `import itertools`,
`import numpy`, `functools.cache` and the refactored + forms (Quick Sort+, Fibonacci Table) all lower a program's class,
and a forge before the Kernel's guardian becomes an optimisation pass.

**Intents**

| Intent | What | t |
|---|---|---|
| Sample | strike 12 | 96 |
| Flame graph | strike 5, 3 times | 128 |
| Optimise | shield 18 | 64 |
| Regress | stoke (its next strike doubles) | 160 |

**Needs:** a damage factor from the program's slowest class in the landing (the landing context already has it,
`speed`), and the hot path mark in the code panel.

### The Livelock Twins

> Two dancers forever stepping aside for each other. Every time you touch one, they trade places.

| | |
|---|---|
| Base HP / run HP | two twins of 90 (414 each) |
| Size | large, two bodies |
| Weak / resist | frost / fire (the second twin: fire / frost) |
| Tests | aiming while the targets move: state that changes mid-loop |
| Counter (the lesson) | never modify a list while you iterate over it (and livelock: both sides polite, nobody moves on) |

**The mechanic: they swap on every hit.** "After You" and "No, After You" stand at index 0 and 1. Each time a bolt hits
either of them, they **swap places**, so the list of foes changes while your volley is still landing. Bolts aimed at
index 0 alternate between the twins. Round Robin, which aims 0, 1, 0, 1, hits the **same** twin every time. A volley
aimed all at the front spreads perfectly.

When one twin falls, the other stops yielding: it **enrages** (+50% to its strikes). So the ideal is to bring them down
together, which means planning the landing order exactly. The code panel draws the swap arrows and the real landing
sequence before you run, so the puzzle is readable; the lesson is that the aim you wrote and the target you hit are no
longer the same thing once the list is mutated during the loop.

**Intents** (each twin)

| Intent | What | t |
|---|---|---|
| Step in | strike 10 | 64 |
| After you | shield 12 | 48 |
| Waltz | strike 4, 2 times | 96 |

**Needs:** a swap of two foes' places after each hit in the landing (a few lines where the landing picks its target),
an enrage when a partner falls (a condition on the foe AI, which `docs/SHARDRUN_DESIGN.md` 6.2 already asks for).

---

## Stage 4: the Root (new)

The Root is the fourth stage (**built**): the machine's own source, under the Kernel. Its hallways reuse the Kernel's
worst bugs in harder mixes (Fork Bomb elites, Segfault Specters with Stack Overflow Serpents), its budget stays at the
Kernel's 1024 operations, and its foes' HP is ×5.4. A program run is won by beating its guardian, and the run's final
score counts all four stages. Spellforge still ends at the Kernel.

### The Quine (built)

> A knight of mirrors. Its only spell prints its own source code, and its source code is whatever you last ran.

| | |
|---|---|
| Base HP / run HP | 150 / 810 |
| Size | colossal |
| Weak / resist | none / none |
| Tests | the shape of a program, and changing it turn to turn |
| Counter (the lesson) | a quine prints itself: a program is also data, and data can be read back |

**The mechanic: `print(source)`.** Its main attack replays **the last program that ran**: it hits you **once for
every attacking bolt** that program fired (at most 12), each for the intent's power, and every ward bolt you fired
becomes **its shield** at half power. It usually moves after your program lands, so it reprints the program you are
writing right now; the code panel says exactly what will come back before you run ("The Quine will reprint 12 bolts:
24 damage"). A program slower than its tempo lets it move first, and then it reprints last turn's program instead.

**The fixed point:** a program made of **exactly the same cards in the same order** as the one before it cannot hurt
the Quine at all (it recognises itself). Change the program, even by one card or one position, and it lands.

So a 30-bolt swarm is strong on the turn it lands and dangerous on the next; a lean program of a few heavy bolts
barely echoes; and a comfortable "same combo every turn" plan simply stops working. The Quine tests the whole deck's
flexibility rather than one quality, which is right for a stage-4 guardian.

**Intents** (as built, `game/content/packs/core/programs/foes/the-quine.jsonc`)

| Intent | What | t |
|---|---|---|
| `print(source)` | 2 per bolt of your last program (at most 12 bolts) | 128 |
| `eval` | shield 20 | 64 |
| Reflect | strike 18 | 192 |
| `print(source)` | 3 per bolt of your last program (at most 12 bolts) | 128 |

### The Root Compiler (the finale)

> The first program: the one that compiles all the others. It has read every guardian you broke on the way down.

| | |
|---|---|
| Base HP / run HP | 280 / 1,512, in three phases |
| Size | colossal |
| Weak / resist | changes by phase |
| Tests | the whole run: it is a final exam built from the bosses *this* run met |
| Counter (the lesson) | bootstrapping: a compiler compiled by an earlier version of itself |

**The mechanic: it compiles the guardians you beat.** The Root Compiler fights in three phases, changing at 2/3 and
1/3 of its HP. Each of the first two phases **compiles in the trait and signature intent** of a guardian you beat
earlier in this run: phase one the Salvage's, phase two the Heap's (a Kiln Warden's thick hide, a Cache Lich's cache,
an Ouroboros's `break` guard, a Short Circuit's guard on the first bolt, and so on; five a stage makes 25 finales). Because guardians cycle, the finale is different from run to run, and it
only ever tests ideas the player has already met and beaten once.

Phase three is its own: **self-hosting**. Its tempo becomes exactly the work your *last* program did, so it acts
before any program as slow as the last one, and after any faster one. Speed up, or be out-sped.

Between phases it spends one turn `recompiling` (it does nothing, and its shield drops): a window for burst.

**Intents:** phase one and two use the compiled guardian's intents with power ×1.5; phase three cycles strike 20
(tempo = your last work), shield 25 (t 64), strike 8 × 3 (tempo = your last work).

**Needs:** the run to remember the guardians beaten (a list in `state.stats`), phase thresholds, and each of the other
bosses' traits as reusable primitives. It should be built last.

### The Mutator

> A stitched-together chimera that edits your code. Can you read what your own card does now?

| | |
|---|---|
| Base HP / run HP | 160 / 864 |
| Size | colossal |
| Weak / resist | fire / none |
| Tests | reading code: predicting what a changed function does |
| Counter (the lesson) | mutation testing: change one operator and check whether your tests notice |

**The mechanic: mutants.** Its `mutate` intent edits a card in your hand with a small, real change to the card's code:
`>` becomes `>=`, `+ 1` becomes `- 1`, `sorted(...)` becomes `sorted(..., reverse=True)`, `max` becomes `min`. The card
is tagged **mutant** and shows the edit as a red and green diff, like the forge's refactor view. The mutant runs in the
sandbox exactly as written, so the preview tells the truth: Take Max may now take the minimum, Merge Sort may sort
strongest first (which the Short Circuit would love), Amplify may weaken.

A mutant is **killed** (restored) when it runs in a program that lands 25 or more on the Mutator: your "tests" caught
it. Killing a mutant also deals 10 to the Mutator. Mutants left alive are restored after the fight. Some mutants are
harmless or even useful, and a good reader will spot them and play them anyway.

**Intents**

| Intent | What | t |
|---|---|---|
| Splice | strike 16 | 128 |
| `mutate` | mutates two cards in your hand | 96 |
| Stitch | shield 20 | 64 |

**Needs:** authored mutants per card (content, like the + forms: code in both languages and a worked example each,
checked by `scripts/validate.sh`), a mutant tag on a card instance for the fight, the diff view on a hand card.

### Karp, the NP Koi

> A golden carp that sets riddles. It does not solve them; it only checks your answer.

| | |
|---|---|
| Base HP / run HP | 170 / 918 |
| Size | colossal |
| Weak / resist | frost / fire |
| Tests | exact combinations: a volley whose parts add up |
| Counter (the lesson) | P vs NP: an answer that is hard to find is easy to check (subset sum) |

**The mechanic: a certificate.** Each turn Karp names a target, say **37**. If some of the attacking bolts that land on
it add up to **exactly** the target, that is a **certificate**: Karp checks it (the code panel shows it, `9 + 12 +
16 = 37`), those bolts deal **double**, and Karp is **stunned** for its next action. Without a certificate its golden
scales halve all damage.

Finding a subset that sums to a number is the classic hard problem (subset sum is NP-complete), and the Artificer's
cards already include the tools that solve it: Knapsack Strike (dynamic programming), Power Set and Exhaustive Kill
(brute force). Varied small bolts (Prefix Sum, Pascal Row, Fibonacci Surge) make most totals reachable without any
search at all. Checking is cheap for the rules (a table of reachable sums up to the target), which is itself the lesson.

**Intents**

| Intent | What | t |
|---|---|---|
| Splash | strike 14 | 128 |
| Riddle | shield 18 | 64 |
| Tail sweep | strike 6, 3 times | 160 |

**Needs:** a target per turn from a seeded list (scaled to the stage), a subset-sum check over the landed bolts (a
bitset of reachable sums), a stun, and the certificate shown in the code panel.

---

## Earlier boss ideas that also fit the pools

`docs/SHARDRUN_DESIGN.md` (section 6.3) already proposed these, and they have concept sprites in `game/assets/foes/`.
The Halting Oracle fills the Root's fifth place; the others can join a pool (or replace a boss there) when built:

- **The Monolith** (1): shuffles *Legacy Code* bugs into your deck; grows while undamaged.
- **Spaghetti Hydra** (1): a cut head grows two unless the body is hit by the same program.
- **Fragmentation Wyrm** (2): segments that break only to a run of *contiguous* bolts summing past their HP.
- **The Hoarder** (2): your wasted power becomes its shield.
- **The Scheduler** (3): gives one foe priority each turn and summons threads.
- **The Halting Oracle** (4): predicts a property of your program and reflects the damage if it is right.

## The final score

A run already ends with a score and a rank (`ShardrunScore`, shown by `RunSummary` at the end): progress (1000 a
stage, 100 a fight), combat, build, survival, tempo, 7500 for a win, less penalties; rank S at 12,000, A at 8,000.
A fourth stage adds 1000 progress and its fights, so a program run that clears the Root scores more than one that
stops at the Kernel. Proposed next, not built: a line per guardian beaten on the end screen, a boss bonus for a
guardian beaten without losing Integrity, and ranks re-tuned once runs with four stages have been played.

## Build order (proposed)

1. **The Quine and the Root** (built, this pass): the fourth stage and a guardian with a new intent (`reprint`) and a
   new trait (`quine`).
2. **The Unhandled Exception** and **INT_MAX**: small changes to the landing and to intents; no new systems.
3. **The Cache Lich** and **Ouroboros**: per-foe state and a guard shown each turn.
4. **Malloc** (summons) and **the Call Stack Colossus** (a foe made of parts): the two new systems, which the Spaghetti
   Hydra and the Fragmentation Wyrm will also use.
5. **The Livelock Twins**, **the Short Circuit** and **the Profiler**: small changes to the landing (a swap, a check of
   the first bolt, a factor by class).
6. **The Thunk** and **Karp**: per-foe state and a check over the landed volley; **the Unreachable**: a hook that cuts a
   program before it runs.
7. **The Page Fault** (a group of foes with one resident) and **the Mutator** (mutants authored for every card: the
   biggest content job of the sixteen).
8. **The boss on the map** from the start, then **the Root Compiler** once the others exist.

After each one, the balance probe (ADR-0016) checks that no boss's win rate differs by more than 2× across paradigms.
