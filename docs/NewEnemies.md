# New bosses: a guardian pool for every stage

Written on 2026-09-28, at the player's request: *"7-8 different bosses that have different mechanics that can be
cycled for the different stages … gimmicks that are related to programming that should change how the player
approaches a fight."* It also asked for a fourth stage after the Kernel, and a final score at the end of a run.

This file is the design. What is built so far is marked **(built)**; the rest is a proposal for the player to accept,
cut or change. Art is a placeholder from ComfyUI in each boss's in-game sprite slot (`game/assets/foes/<id>.png`,
prompts in `pipeline/art/manifest.json` under `foe-<id>`). Better art comes later.

## How bosses cycle

Each stage has a **pool** of guardians. A run draws one per stage from the seed (`ShardrunRules.encounter_for`
already does this for any list), so two runs can meet different bosses. The plan is to show the drawn boss on the
map from the start (as in Slay the Spire), so a player can draft toward it.

| Stage | Place | What its bugs are about | Guardian pool |
|---|---|---|---|
| 1 | The Salvage | syntax and logic | Kiln Warden (exists), **Ouroboros**, **The Unhandled Exception** |
| 2 | The Heap | memory and data | Deadlock Golem (exists), **The Cache Lich**, **Malloc, the Heap Matron** |
| 3 | The Kernel | systems and numbers | Root Daemon (exists), **The Call Stack Colossus**, **INT_MAX** |
| 4 | The Root (new) | the machine's own source | **The Quine** (built), **The Root Compiler** (the finale) |

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
an Ouroboros's `break` guard, and so on). Because guardians cycle, the finale is different from run to run, and it
only ever tests ideas the player has already met and beaten once.

Phase three is its own: **self-hosting**. Its tempo becomes exactly the work your *last* program did, so it acts
before any program as slow as the last one, and after any faster one. Speed up, or be out-sped.

Between phases it spends one turn `recompiling` (it does nothing, and its shield drops): a window for burst.

**Intents:** phase one and two use the compiled guardian's intents with power ×1.5; phase three cycles strike 20
(tempo = your last work), shield 25 (t 64), strike 8 × 3 (tempo = your last work).

**Needs:** the run to remember the guardians beaten (a list in `state.stats`), phase thresholds, and each of the other
bosses' traits as reusable primitives. It should be built last.

---

## Earlier boss ideas that also fit the pools

`docs/SHARDRUN_DESIGN.md` (section 6.3) already proposed these, and they have concept sprites in `game/assets/foes/`.
They can join a pool whenever they are built:

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
5. **The boss on the map** from the start, then **the Root Compiler** once the others exist.

After each one, the balance probe (ADR-0016) checks that no boss's win rate differs by more than 2× across paradigms.
