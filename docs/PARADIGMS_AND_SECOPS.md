# The Artificer's paradigms, and a mockup of the Sec Ops class

Written on 2026-10-04, at the player's request: *"before we start adding a new class, let's make sure that the
artificer is as setup as possible … determine if it would be beneficial or not to add any more cards … it doesn't
feel like the various paradigms actually feel like... different paradigms … Then I also want you to try and get a
mockup of the different cards and playstyle that would be available to the new class (sec ops) … It will likely
change the playstyle completely overall … it doesn't have to be the exact same game mode with a different skin,
that's what the paradigms are kinda for."*

This is a proposal. Nothing in it is decided until the player says so; section 9 lists the calls that are theirs.
Numbers are first guesses for the balance probe (`docs/research/balance-probe/`), which was **not** run for this
document. Part 1 is the Artificer and part 2 is Sec Ops.

---

# Part 1: the Artificer

## 1. What a paradigm is today (read from the code and content)

| Where | What the paradigm does |
|---|---|
| The pick (`ProgramDraft.pick_paradigm`) | its 2 signature cards join the deck |
| The draft (5 packs of 3) | its pool is 2× likelier than a neutral card (`PARADIGM_WEIGHT`) |
| Fight rewards (`ShardrunBattle.draft_shards`) | **nothing**: every draftable card in the game, weighted by rarity only |
| Rules (`core/programs/`) | **nothing**: no rule, relic or hook reads `state.paradigm`; only the run history's branch name does |
| The starting deck | **nothing**: the same 8 neutral basics for all five |

So a run's deck looks like this:

- **After the draft**: 8 basics + 2 signature + 5 drafted (about half of them from the paradigm) = 15 cards, about
  4 or 5 of them the paradigm's (30%).
- **Every fight reward after that**: 7 to 10 paradigm cards among about 70 draftable, so about 14% of what's offered.
  By Act 2 the deck has drifted toward "the generally good cards", whatever paradigm was picked.

### The cards per paradigm (base cards, not their `+` versions)

| Paradigm | Own cards | source | shape | order | strike | guard | import | Pool borrows |
|---|---|---|---|---|---|---|---|---|
| Neutral | 25 | 8 | 8 | 2 | 1 | 2 | 4 | — |
| Divide & Conquer | 9 | 3 | 1 | 1 | 2 | **0** | 2 | merge-sort, fork, amplify |
| Search & Index | 10 | 1 | 5 | **0** | 2 | **0** | 2 | merge-sort, chill |
| Greedy | 10 | 1 | 2 | 1 | 4 | 1 | 1 | amplify, charge |
| Brute Force | 7 | 2 | **0** | 1 | 2 | 1 | 1 | kindle, fork, take-max (a Greedy card) |
| Dynamic Programming | 10 | 1 | 5 | **0** | 2 | 1 | 1 | hash-merge (a Search card), chill |

The `neutral` list also offers three paradigm cards to everyone (`sweep`, `take-max`, `hash-merge`), so even those
aren't the paradigm's own.

## 2. Why the paradigms don't feel different

1. **Identity fades after the draft** (the table above). SHARDRUN_DESIGN 2.5 measured this on 2026-09-28, and it's
   still the case.
2. **No paradigm has a rule of its own.** In Slay the Spire a class feels different because a mechanic changes what a
   good turn looks like (Strength, Poison, Orbs). Here, picking Greedy changes which cards show up, but a good Greedy
   turn and a good DP turn are judged the same way: the most damage this program.
3. **Every card does the same thing.** All 71 cards take a list of powers and return a list of powers. The paradigms
   differ in their complexity class, and complexity only matters through the speed race. With volleys of 10 to 20
   bolts, O(n) against O(n log n) is a few dozen operations either way. The paradigms differ in their maths, but not in
   the question each one asks the player to answer.
4. **The pools blur into each other**: five paradigms share 9 neutral cards in their own pools, and Brute Force has
   only 7 cards of its own.

## 3. Would more cards help?

**Yes, but only together with the fixes below.** If the paradigms got 10 more cards without them, those cards would
still be drawn from a pool of 80 that ignores the paradigm, and they would still be "another list transform". It
would add variety to the game and do nothing for the paradigms. The cards are worth adding once each paradigm has a
question of its own for them to answer. In order:

1. **Keep the paradigm in the rewards** (data and a few lines; the cheapest fix and the biggest one).
2. **Clean the pools**: a paradigm's pool lists only its own cards; neutral cards come from `neutral`.
3. **Give each paradigm a law**: one rule that changes what a good turn is (section 4).
4. **17 new cards built on those laws** (section 5): 3 a paradigm, plus 2 neutral. That fills the role holes in the
   table above and gives each paradigm 12 to 13 cards of its own.
5. **One basic swapped per paradigm**, so the first fight already plays differently (section 6).

### 3.1 Rewards that keep the paradigm (proposed data)

```jsonc
// programs.jsonc
"rewards": {
  // Where a fight reward's three cards come from: the run's paradigm, the neutral pool, the other paradigms.
  "paradigm_share": { "own": 0.5, "neutral": 0.35, "other": 0.15 }
}
```

The `other` share leaves room to splash another paradigm's card in, which is a real deck-building choice ("a Greedy
deck that took Memo Table"). The design doc's pity rule for rares can sit on top.

## 4. A law for each paradigm

Each law is a **starter relic** the paradigm gives at the pick, with a new tier `paradigm` (never loot). That way it's
data in the existing relic system, it shows in the relic bar with its tooltip, and `ProgramRelics` is where its
effect lives. Four of the five need one new effect kind each; Divide & Conquer needs a rules primitive.

| Paradigm | Law (the relic) | What it does | The question it asks | New in the rules |
|---|---|---|---|---|
| **Greedy** | *Local Optimum* | A foe your program kills **with Initiative** pays 1 mana next turn (at most 2 a turn). | "How fast can I kill, right now?" Tempo and kill chains; cheap, fast programs every turn. | effect kind `kill-initiative-mana` (the next-turn mana hook exists) |
| **Brute Force** | *Throw Hardware At It* | Every full 256 operations of work adds 1 power to each attack bolt as it lands. A timeout still lands nothing. | "How close to the budget do I dare go?" A push-your-luck line (up to +16 in the Salvage, +4 in the Kernel). | effect kind `work-power` |
| **Dynamic Programming** | *The Table* | Every program's landed damage is written to `dp[t]` (fight state). From turn 3, each program's seed gains a bolt of `(dp[t-1] + dp[t-2]) // 4`. DP cards read the table. | "What do I build now for later turns?" A slow start that scales, which is what DP is: answers built from smaller answers. | `battle.globals.dp` (fight state exists) and a seed effect |
| **Search & Index** | *The Index* | Power your program would waste (overkill, bolts at the fallen, bolts left over) is `insort`ed into a sorted index of at most 8 bolts that lasts the fight. Each program's seed takes the index's strongest bolt. | "Which exact bolt for which foe?" Precision is rewarded and nothing is wasted: overkill is banked. | `battle.globals.index` and a landing effect (Lazy Evaluation's waste hook is close) |
| **Divide & Conquer** | *Recurse* | The card played right after a splitting card (Divide, Split, Merge Sort, Quick Sort, Quickselect) runs **once on each half**, and the halves rejoin: `left, right = f(left), f(right)`. Its work counts twice on half the n. | "How do I shape the program into subproblems?" A strike on halves can aim at two foes; a shape on halves stacks. | a **body slot**: a card that takes the next card as its body, drawn indented. **The same primitive Sec Ops' `try:` needs** (part 2), so it's built once. |

In the code panel, Recurse reads as real code:

```python
def main(bolts, battle):
    bolts = divide(bolts)
    left, right = halves(bolts)
    left, right = round_robin(left, battle), round_robin(right, battle)  # Recurse
    return left + right
```

## 5. Seventeen new cards

Each is a real algorithm in Python, JavaScript and C++ with worked examples, a `+` refactor, Japanese text and art.
That's the existing card contract (ADR-0012, 0018, 0046), so 17 cards make 34 records.

### Greedy: fast, cheap, kill now

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Activity Selection** | strike | 1 | O(n log n) | Sorts foes by how soon their intent lands (tempo, quickest first) and pours bolts into each until it falls. The jabbers die before they act. | earliest deadline first, interval scheduling |
| **Fractional Knapsack** | shape | 1 | O(n log n) | Cuts the strongest bolt into exactly the front foe's HP plus a remainder, then the next strongest for the next foe. | greedy is **provably optimal** when you may take fractions (DP's Knapsack Strike is the 0/1 case it isn't) |
| **First-Fit Decreasing** | strike | 1 | O(n·m) | Bin packing: bolts, strongest first, each go to the first foe they don't overkill by more than 2; the leftovers go to the front. | a greedy heuristic that is close to optimal and very fast |

### Brute Force: ride the budget

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Backtracking** | strike | 2 | O(2ⁿ) pruned, cap 12 | Assigns bolts to *all* foes for the most kills, abandoning any partial assignment that can't beat the best so far. The race bar shows the measured work far under 2ⁿ. | pruning: the same search space, much less of it explored |
| **N-Queens** | source | 1 | O(n!) pruned, n = 6 | Places six queens by backtracking; each of the 4 solutions becomes a 7-power bolt. `+`: n = 8, 92 solutions, each a 2-power bolt (a flood, and slow). | backtracking, and how fast a search space grows |
| **Bogosort** | order | 0, `volatile` | O(n·n!) expected, first 6 bolts | Shuffles until sorted, seeded by the battle so the preview is the cast. Absurd work, and *Throw Hardware At It* turns that work into power. | why some algorithms are jokes, and what "expected" running time means |

### Dynamic Programming: build now, cash in later

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Recurrence** | source | 1 | O(1) | Appends a bolt of `dp[t-1] + dp[t-2]` halved: Fibonacci across the fight's turns. Nothing on turn 1; large by turn 5. | a recurrence relation; reading a table instead of recomputing |
| **Coin Change (DP)** | strike | 2 | O(n·H) | The fewest bolts that sum *exactly* to the front foe's HP fly at it, with no overkill; the rest go to the next foe. | the classic pair with **Make Change** (greedy): one fast and sometimes wrong, one exact and slower |
| **Rod Cutting** | shape | 1 | O(n²) | Cuts the strongest bolt into the pieces worth the most by a price table (a 3 is worth 4, a 5 worth 7, a 7 worth 10). | optimal substructure, the textbook DP |

Also move `global-total` and `release` from neutral into the DP pool: they're the same idea (state across the turns
of a fight).

### Search & Index: precision, nothing wasted

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Lookup** | source | 0 | O(log k) | `bisect`s the index for the smallest bolt that kills the front foe and appends it; otherwise the index's strongest. | a lookup in a sorted structure |
| **Interpolation Search** | strike | 1 | O(log log n), worst O(n) | Like Binary Execute, but guesses where the killing bolt sits from its value. Salvo's 1-to-6 run is evenly spread, so there it's nearly free; on a lopsided volley it's billed O(n) (`worst_case`, which exists). | the input's distribution changes an algorithm's cost |
| **Range Query** | strike | 1 | O(log n + k) | For each foe, every bolt with power in `[HP / 2, HP]` flies at it, found with two bisects; the rest go to the index. | range scans on an index (what a database does) |

### Divide & Conquer: subproblems

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Counting Inversions** | shape | 1 | O(n log n) | Merge sort that counts: each bolt gains the number of stronger bolts before it. It rewards disorder, so play it before you sort. | counting while you merge; an inversion |
| **Max Subarray (D&C)** | shape | 1 | O(n log n) | Best run in the left half, the right half, or across the middle, fused into one bolt, +1 a level. | the pair with **Kadane** (DP, O(n)): the same answer, two ways |
| **Base Case** | shape | 0 | O(1) | `if len(bolts) <= 2: double them`. On a whole volley it does nothing; under *Recurse*, on a small half, it doubles. | every recursion needs a base case |

### Neutral

| Card | Role | Cost | Class | Does | The lesson |
|---|---|---|---|---|---|
| **Read Input** | source | 1 | O(m) | One bolt per foe, its power that foe's intended damage: the battle is your input. | input comes from outside the program |
| **Prefetch** | utility (new role) | 1, `once` | O(1) | Draw 2 next turn. | prefetching; the first draw card in the pool |

### After this

| Paradigm | Own cards now | After | Role holes filled |
|---|---|---|---|
| Divide & Conquer | 9 | 12 | more shapes; a guard is still wanted (Recurse + Ward on halves covers it) |
| Search & Index | 10 | 13 | a source of its own (Lookup) and two strikes |
| Greedy | 10 | 13 | strikes that race |
| Brute Force | 7 | 10 | a source, an order, a pruned strike |
| Dynamic Programming | 10 | 15 (with global-total, release) | a source that scales; a strike for exact kills |

## 6. A first fight that already differs

Each paradigm swaps one of the eight basics, so its first program is its own:

| Paradigm | Out | In |
|---|---|---|
| Divide & Conquer | Fork | Split |
| Search & Index | Kindle | Merge Sort |
| Greedy | Round Robin | Sweep |
| Brute Force | Amplify | Bubble Sort |
| Dynamic Programming | Ward | Knapsack Ward |

A `swap` field on the paradigm in `programs.jsonc`, defaulted to none.

## 7. How we'd know it worked

The probe exists (`docs/research/balance-probe/`). Before and after, per paradigm: the win rate, the share of each
deck that is the paradigm's at the end of a run (target: 50% or more, from about 30% now), and how often the law fired.
The other check is the player's own git log of runs: does a Greedy run *feel* like racing and a DP run like building?

---

# Part 2: Sec Ops, a mockup

## 8. The idea: Vesper's program runs on her bolts; Kurogane's runs on theirs

The existing brief (`docs/prompt2.md`) keeps Vesper's game and adds branches to it: a turn is still "build a program
that makes and aims bolts". The player asked for something that plays differently, so this mockup changes the shape
of the fight:

> **Kurogane doesn't write an attack. He maintains a server.** His cards are the rules of a request handler that
> stays deployed for the whole fight. Each foe's intent arrives as a **request** and runs through his handler, top to
> bottom, and the first rule that matches decides its fate. He wins by understanding the bugs: what his rules catch
> and log becomes **evidence**, and evidence becomes the **patch** that kills the bug.

Everything that makes Rootward Rootward still holds:

- **Real execution.** The handler is real code (`handler.py`, `handler.js`, `handler.cpp`) put together from the rule
  cards, run in the sandbox over the turn's requests.
- **The preview is the cast.** Every request is telegraphed (the foes' intents) and seeded, so the preview runs the
  handler on exactly the requests that will come, and shows where each one ends up.
- **Order is the program.** First match wins, so the order of the rules matters. A guard that comes after the line it
  should protect is too late.
- **Enemies are bugs**, and here they're bugs *in his input*: the Null Wraith's requests really are null, and a rule
  that reads `req.size` without checking first really crashes.
- **Defensive only.** Requests are abstract ("null", "oversized", "wrong type", "a flood"), drawn as the game's
  creatures. No card names or shows an attack technique, payload or exploit.

### 8.1 Vesper and Kurogane side by side

| | Vesper, the Artificer | Kurogane, Sec Ops |
|---|---|---|
| A turn is | a new program, written from scratch | a **patch** to a handler that stays deployed |
| The code | `main.py`: `bolts → bolts` | `handler.py`: `request → verdict`, run once per request |
| Runs on | her own bolts | **the foes' requests** |
| Order matters because | sort before search; aim last | first match wins; guard before use; cheap rules first |
| Speed | the race: work against foe tempo | **latency**: checks against the turn's SLA |
| Damage comes from | bolts | ripostes (caught exceptions), bounces (rejections) and **patches** (evidence) |
| A good turn | the biggest volley that lands first | nothing gets through, and you learn the most |
| Over the limit | timeout: nothing lands | timeout: your **default** decides: fail-open (it hits you) or fail-closed (dropped, and you lose availability) |
| Teaches | arrays, sorting, searching, complexity | conditionals, guard clauses, early return, try/except/finally, validation, logging, defence in depth |

### 8.2 The turn

1. **Incoming.** The foes' intents arrive as requests in an access log, quickest first:

   ```
   ⚡12  Tally Wisp         FLOOD    size=3 ×3
   ⚡24  Off-by-One Goblin  STRIKE   size=7   [fire]   ↷ off by one
   ⚡40  Null Wraith        STRIKE   size=None         ⚠ null
   ⚡90  Malloc Matron      SPAWN    heap-block
   ```

2. **Deploy** (3 mana, a hand of 5): play **rules** into the handler's slots (5, as Vesper's program, widened at a
   forge); a rule stays until replaced, and the replaced rule goes to the discard. Play **actions** (Patch, Hotfix,
   Isolate) that happen now. Play **config** cards (Default Deny, Least Privilege) that hold for the fight.
3. **Traffic.** The requests run through the handler in tempo order, animated: a packet of light flies at Kurogane,
   passes the ward gates, and either a gate flares and stops it, his blade catches it (a riposte), or it gets through
   and hits him.
4. **Settle.** Evidence collects over each foe's head; Raised (the exceptions caught this fight) ticks up.

What a request is, as the foe's intent mapped automatically (data on a foe can override it):

| Foe intent | Request | If it gets through |
|---|---|---|
| attack n | `STRIKE size=n` | n damage |
| multi-hit k×n | `FLOOD`: k requests of `size=n` | each one's damage |
| buff, debuff | `ESCALATE` | the foe gets its buff, or you its debuff. **Blocked, it never happens.** |
| summon | `SPAWN` | the summon. **Blocked, nothing appears.** |
| (users) | `HEARTBEAT`, 1 or 2 a turn, from friendly traffic | +2 block next turn, or a card drawn: availability |

Blocking an escalation or a spawn denies it outright, which Vesper can never do. Her answer to a summoner is to kill
it first; his is to drop the request.

### 8.3 What the code panel shows

The handler is assembled from the deployed cards, indented the way the code really is:

```python
def handle(req, state):
    try:
        if req.size is None:                     # Null Check
            return DROP
        if req.size > 6:                         # Size Limit
            return REJECT                        #   bounces 2 at its source
        if not state.limiter.take(req.source):   # Rate Limiter (2 a turn per foe)
            return DROP
        req = block(req, 4)                      # Firewall Rule
        return SERVE
    except NullError:                            # except NullError
        riposte(req.source, 2 * req.telegraphed) #   Raised +1
        return DROP
    finally:
        state.audit.log(req)                     # Audit Log: +1 evidence
```

`return SERVE` at the end is the default (fail-open). **Default Deny** turns it into `return DROP`.

**Malformed fields really throw.** The harness hands each language a request whose malformed field raises when it's
read (a Python property, a JavaScript getter, a C++ accessor), so the three languages crash the same way. JavaScript's
`null > 6` is `false`, not an error, so without this the languages would disagree and the preview couldn't be the
cast. The errors carry game names mapped to each language's real classes:

| Game | Python | JavaScript | C++ |
|---|---|---|---|
| NullError | `TypeError` | `TypeError` | `std::invalid_argument` |
| TypeError | `TypeError` | `TypeError` | `std::bad_variant_access` |
| IndexError | `IndexError` | `RangeError` | `std::out_of_range` |
| DepthError | `RecursionError` | `RangeError` | `std::length_error` |

C++ exceptions are on in the sandbox already (ADR-0046, `-fwasm-exceptions`).

### 8.4 One turn, worked through

Foes: Tally Wisp (HP 9), Off-by-One Goblin (HP 18), Null Wraith (HP 14). The handler above, without the `except
NullError` (a Firewall deck), and with Audit Log.

| Request | Path through the handler | Result | Evidence |
|---|---|---|---|
| Wisp 3 | Null ✗ → Size ✗ → Limiter ✓ → Firewall −4 → serve 0 | nothing | Wisp 1 |
| Wisp 3 | same | nothing | Wisp 2 |
| Wisp 3 | Null ✗ → Size ✗ → **Limiter: out of tokens** → DROP | dropped | Wisp 3 |
| Goblin 7 | Size would match, but **off by one: skipped** → Limiter ✓ → Firewall −4 → serve 3 | **you take 3** | Goblin 1 |
| Wraith None | **Null Check** → DROP | dropped | Wraith 1 |

Latency: 15 checks against an SLA of 64. Next turn, **Patch** (3 × evidence) on the Wisp deals 9: it's fixed.

The lesson in the Goblin's row: one guard is a single point of failure. A second Size Limit lower down, or the
Firewall Rule above the Limiter, would have caught it, which is **defence in depth** learnt by being hit.

**The same turn as a Riposte deck**: Null Check is left out *on purpose*. The Wraith's null crashes `req.size > 6`,
`except NullError` catches it and ripostes 2 × 6 = 12 at the Wraith. The Riposte deck lets the bugs crash into
handlers it wrote for them.

### 8.5 The latency budget (the SLA)

Every check a request passes through costs operations by the rule's complexity (a set lookup 1, a list scan k, a
recursive validator its depth). The turn's total is held against the SLA: **64, 48, 32** ops by layer. Over it, the
remaining requests time out and the default decides: **fail-open**, they're served (they hit you), or **fail-closed**,
they're dropped and you lose 1 mana next turn (downtime). So order matters twice: for correctness (guard before use)
and for speed (the cheap rule that stops most traffic goes first, with an early return). That's how real firewalls are
tuned.

## 9. The archetypes (Sec Ops' paradigms)

Picked at the start, three offered, each with a law (a starter relic, as for the Artificer) and two signature cards.

| Archetype | Law | Signature | Plays like | Teaches |
|---|---|---|---|---|
| **Firewall** | *Defence in Depth*: every rule that blocks part of a request deals 1 back at its source. | Allow-list, Defence in Depth | many cheap layered rules; nothing gets through; damage from thorns and bounces, then patches | ordered rules, first match wins, allow-list against deny-list, early return |
| **Riposte** | *Raised*: each exception caught this fight adds 1 to every later riposte. | `except NullError`, Re-raise | leave a door open on purpose, catch what comes through, counter-strike (the duelist) | try/except/finally, specific against broad catches, re-raise, custom exceptions |
| **Forensics** | *Threat Intel*: every fight starts with 1 evidence on each foe. | Honeypot, Root Cause | log everything, take a few hits, then one huge patch turn | logging, audit trails, reproducing a bug, root cause, regression tests |

## 10. The cards (a launch pool of 31)

Roles: **rule** (goes into a handler slot and stays), **structure** (`try`, `except`, `finally`: wraps the slots
below; built on the body-slot primitive from section 4), **action** (now, on your turn), **config** (for the fight).

### Starter deck (10) and relic

Null Check, Size Limit, Firewall Rule ×2, Rate Limiter, Audit Log, Try / Except, Patch ×2, Hotfix.
Starter relic **Watchdog**: the first time each fight the handler crashes with nothing to catch it, it restarts at the
next rule instead of failing open.

### Shared (any archetype)

| Card | Role | Cost | Code | Does | The defensive idea |
|---|---|---|---|---|---|
| **Null Check** | rule | 0 | `if req.size is None: return DROP` | drops null requests before anything reads them | the guard clause; check before use |
| **Size Limit** | rule | 1 | `if req.size > 6: return REJECT` | rejects big strikes and bounces 2 | validate bounds on input |
| **Firewall Rule** | rule | 1 | `req = block(req, 4)` | shaves 4 off every request and passes it on | a filter; stacked, defence in depth |
| **Rate Limiter** | rule | 1 | `if not limiter.take(req.source): return DROP` | each foe gets 2 requests a turn; the rest drop | rate limiting (a token bucket) against floods |
| **Type Check** | rule | 0 | `if not isinstance(req.size, int): return REJECT` | rejects wrong-type requests (the Type Mimic) | type validation |
| **Bounds Check** | rule | 0 | `if not 0 <= req.index < len(table): return DROP` | drops out-of-bounds requests (the Segfault Specter) | bounds checking |
| **Sanitize** | rule | 0 | `req = req.with_element(None).shrink(2)` | strips a request's element and 2 size | cleaning and escaping input |
| **Timeout** | rule | 1 | `if checks > 8: return DROP` | a request still unmatched after 8 checks is dropped | timeouts against deep or slow input (the Serpent) |
| **Circuit Breaker** | rule | 1 | `if failures[src] >= 3: return DROP` | after 3 requests from one foe in a turn, drops its others this turn and next | the circuit-breaker pattern |
| **Audit Log** | rule (finally) | 1 | `finally: audit.log(req)` | +1 evidence on each request's source, even after a crash | audit logging; `finally` always runs |
| **Try / Except** | structure | 1 | `try: … except Exception: return DROP` | any crash below is caught and dropped; ripostes 1; swallows evidence | a broad catch, and why it hides bugs |
| **Patch** | action | 1 | `fix(foe)` | 3 × the foe's evidence damage, and clears it | a fix comes from understanding the bug |
| **Hotfix** | action | 0, `volatile` | `fix_quick(foe)` | 5 damage now, and a *Tech Debt* bug card into your discard | a quick fix has a cost later |
| **Default Deny** | config | 2 | `return DROP` at the end | unmatched requests drop, heartbeats too unless allow-listed | fail-closed against fail-open |
| **Least Privilege** | config | 1 | `grant(req, scope="min")` | escalations that get through grant half | least privilege |

### Firewall

| Card | Role | Cost | Code | Does | The defensive idea |
|---|---|---|---|---|---|
| **Allow-list** ★ | rule | 2 | `if req.kind not in ALLOWED: return DROP` | only STRIKE and HEARTBEAT pass; escalations, spawns and malformed requests drop | allow-list beats deny-list |
| **Defence in Depth** ★ | config | 1 | — | each block rule a request passes makes the next block 1 more | layered defences |
| **Early Return** | rule | 0 | `if req.size <= 2: return DROP` | tiny requests stop at once, saving latency | early return makes the common case fast |
| **Deny-list** | rule | 1 | `if req.kind in DENY: return DROP` | drops one kind, chosen when deployed | a deny-list, and its gaps |
| **Hardened Gate** | rule | 2 | `req = block(req, 8)` | blocks 8, but costs 2 latency a check | strength against speed |
| **Reverse Proxy** | rule | 1 | `return REJECT` with a bounce | rejected requests bounce half their size | a proxy in front of the server |

### Riposte

| Card | Role | Cost | Code | Does | The defensive idea |
|---|---|---|---|---|---|
| **except NullError** ★ | structure | 0 | `except NullError:` | catches null crashes: riposte 2 × the request's size | catch the exception you expect |
| **Re-raise** ★ | rule | 1 | `except …: log(e); raise` | after a catch, the exception carries on to `finally`: riposte **and** log (+2 evidence) | re-raising instead of swallowing |
| **except TypeError** | structure | 0 | `except TypeError:` | the same for wrong-type crashes | specific exceptions |
| **except IndexError** | structure | 0 | `except IndexError:` | the same for out-of-bounds crashes | specific exceptions |
| **Custom Exception** | structure | 1 | `class GoblinError(Exception)` | names one foe: its crashes riposte ×3 at it | defining your own exception types |
| **Parry** | action | 1 | — | this turn, the first request a rule rejects ripostes for its full size | (the duelist's move) |
| **Fuzz Test** | action | 1 | — | this turn, every foe's first request arrives malformed: fuel for your catches | fuzzing your own code with bad input |

### Forensics

| Card | Role | Cost | Code | Does | The defensive idea |
|---|---|---|---|---|---|
| **Honeypot** ★ | rule | 1 | `if first_this_turn: return decoy(req)` | the turn's first request hits a decoy: nothing reaches you; +3 evidence | a honeypot draws attention away from the real system |
| **Root Cause** ★ | action | 2 | — | 5 × the foe's evidence damage | root-cause analysis |
| **Canary** | rule | 0 | — | the first request that reaches you each turn gives +2 evidence and 3 block | a canary that tells you something got in |
| **Reproduce** | action | 0 | — | doubles a foe's evidence; its next request skips your rules | you have to reproduce a bug to fix it |
| **Isolate** | action | 2 | — | a foe's requests this turn go to a sandbox: they hit nothing, +2 evidence each | containment |
| **Regression Test** | action | 1, `once` | `assert handle(case) == DROP` | after a Patch on a foe, its requests of the patched kind drop for the rest of the fight | a test so the bug never comes back |

★ = signature card. Every card gets a `+` refactor read as a diff at the forge (Size Limit+: `> 5`; Try / Except+:
narrows itself to the most common error this fight).

### Bug cards and relics

- **Tech Debt** (from Hotfix): unplayable; while it's in your hand, every rule costs 1 more latency.
- Relics of his own (shared ones such as mana, draw and healing still apply): **Watchdog** (starter), **Uptime
  Monitor** (a turn where nothing reaches you gives +1 mana next turn), **Log Aggregator** (malformed requests give
  +1 evidence), **Read-only Config** (your first rule can't be moved or swapped by a foe), **Backup Tapes** (once a
  fight, restore the Integrity lost last turn), **Security Champion** (the first Patch each fight costs 0).

## 11. The bestiary from the other side

The foes are shared. A foe's trait becomes something it does to the handler, and each has a defensive answer:

| Foe | What it does to Kurogane's handler | The answer |
|---|---|---|
| Null Wraith | its requests are null; any rule that reads `size` first crashes | Null Check (or `except NullError`) |
| Off-by-One Goblin | skips the first rule that would have matched it | a second, redundant rule: defence in depth |
| Race Condition Imp | if it's quicker than your deploy, it swaps two adjacent rules (shown before Traffic) | Read-only Config; rules that don't depend on order |
| Type Mimic | its size is a different type each turn | Type Check |
| Segfault Specter | its requests carry an out-of-range index | Bounds Check |
| Stack Overflow Serpent | deeply nested requests overflow a recursive check | Timeout; an iterative validator |
| Memory Leak Ooze | a served request leaks: it comes back every turn until patched | drop it the first time, or Patch the Ooze |
| Fork Bomb | its flood doubles each turn it isn't rate-limited | Rate Limiter, Circuit Breaker |
| Malloc Matron | spawns heap blocks | drop the SPAWN (Allow-list, Deny-list) |
| Deadlock locks | a Patch on one is blocked unless the other is patched the same turn | evidence on both, two Patches in one turn |

Guardians get an optional `requests` block in their data, for when the general mapping isn't enough. Every guardian
the Artificer meets stays as it is.

## 12. On screen and in sound

- **The stage**: between the foes and Kurogane, a lattice of ward gates, one per handler slot, in his teal from the
  concept art (`Concept/newCharacters/anime-heavy/01-kurogane-ward-duelist.png`). Requests fly in as shards of light; a
  gate that matches flares and the shard shatters; a caught exception is a **parry and riposte** with his blade; a
  served request breaks through and hits him. Evidence is a stack of glowing glyph-scrolls over each foe; a **Patch**
  is a single cut that seals the bug with a rune and kills it.
- **The code panel** is `handler.py`, built by the same rune writing; during Traffic the line that matches each
  request lights up.
- **The race bar** becomes a latency bar against the SLA.
- **Sound**: each gate's matched tone climbs in pitch with its slot, a parry rings, and a clean turn (nothing got in)
  ends on a chord.

## 13. What it would take

Shared and unchanged: the map, rooms, deck and hand, mana, rewards and the forge, relics (shared ones), the foes'
data, the sandbox, rune writing, run state and history, Japanese, the three languages.

New:

| Piece | Where | Size |
|---|---|---|
| The class frame (a `class` in run state, a picker, per-class pools, starter deck and relic) | `core/shardrun/`, `ShardrunSchemas` | 1 session (track B's slice 1, unchanged) |
| The body-slot primitive (Recurse, `try`, `except`, `finally`), built for the Artificer first | `core/programs/` | inside part 1 |
| Traffic rules: requests from intents, the handler run in the sandbox, verdicts, evidence, Raised, the SLA, preview = cast, with tests first | a new `core/traffic/` beside `core/programs/` | 2 to 3 sessions |
| The request harness in three languages (fields that throw) | `game/sandbox/` | inside the above |
| The fight screen's Sec Ops view: gates, the access log, the latency bar, `handler.py` | `game/scenes/shardrun/` | 2 sessions |
| 31 cards and their `+`, 6 relics, Tech Debt, foe mappings, Japanese, C++ | `content/packs/core/secops/` | 1 to 2 sessions |
| Sprite, spells, sound | pipeline | 1 to 2 sessions |
| A bot for the probe, and a balance report per archetype | `docs/research/balance-probe/` | 1 session |

That's about **8 to 10 sessions**, against track B's estimate of 3 to 4 for the brief's version (branches added to
Vesper's pipeline). The extra time is the price of a playstyle of its own: a new fight resolution and a new view. The
rest of the game carries over.

**Recommended order**: part 1 first, as the player asked (rewards, pools, laws, then the cards, with the body slot
built for Recurse), then the class frame with Vesper as the only class, then Sec Ops.

## 14. The calls that are the player's

1. **Laws as starter relics** (section 4): the five laws as written, or change any? Recurse is the biggest to build.
2. **The 17 cards** (section 5): cut or swap any? More is possible: SHARDRUN_DESIGN 7 still has unused ideas (Fast
   Power, Hash Aim's variants, Huffman's relatives).
3. **Reward shares** (3.1): 50% own, 35% neutral, 15% other?
4. **Sec Ops' model**: the handler and traffic game here (recommended: it's the one that plays differently), or the
   brief's branches inside Vesper's program?
5. **The name**: "Kurogane, Sec Ops", "Kurogane, the Warden", or keep "the Ward Duelist"? The swordsman look fits all
   three (gates, parries, the blade as the riposte).
6. **Availability** (HEARTBEAT requests and fail-closed's cost): in the first version, or later? It's the real
   security-against-usability trade-off, but it's one more thing to read in a turn.
