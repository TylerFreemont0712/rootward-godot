# Shardrun card and relic gaps · v0.2

**Status:** concept work only. These proposals are not in the live card pool. Prototype card functions are in
[`prototype_cards.py`](prototype_cards.py); they use the current `bolts, battle -> bolts` contract where possible.

The card-by-card repairs for the C-rated v0.2 balance findings are in [Balance-Fix-Cards.md](Balance-Fix-Cards.md).

## Starting point

The current 149 draftable Program cards break down by role as follows. Counts exclude the 150 non-draftable refactors.

| Role | Cards |
|---|---:|
| Shape | 45 |
| Strike | 32 |
| Source | 30 |
| Order | 18 |
| Import | 13 |
| Guard | 10 |
| Utility | 1 |

The biggest gaps are more specific than those totals suggest:

- **Utility:** Prefetch is the only draftable Utility, and it only draws cards next turn.
- **Brute Force:** All-Pairs Rank is its only Shape. It has two Guards, but both are exponential searches. They are
  powerful when they fit; there is no cheap, repeatable ward for a wide volley.
- **Greedy:** Make Change is its only paradigm-specific Source.
- **Search & Index:** Counting Sort is its only paradigm-specific Order. It becomes expensive when a bolt has a high
  power because its bucket array grows with that power.
- **Dynamic Programming:** it has no paradigm-specific Order. This is a possible content gap, not necessarily a
  design flaw: the paradigm's identity is state and recurrence, not sorted input.
- **Divide & Conquer:** it has no paradigm-specific Guard, despite Recurse making a natural place for local defenses.

Brute Force has a second, mechanical gap. Its law turns measured work into attack power, while timeouts erase the
whole volley. A card cannot restore Integrity directly: a Program card returns bolts, and the rules accept bolt
fields such as `block`, not a `heal` field. Wards are real, but resolve after faster foes have acted. A ward can stop
foes that have not acted yet this turn; it cannot undo an earlier hit.

## Recommended concepts

### Cold Cache · Utility · Neutral

**Common · cost 1 · O(1) · once per fight**

The card itself makes no bolts. After a successful cast containing it, the next Program cast costs 1 less mana
(minimum cost 0). The discount is consumed when that next cast starts, even if it later times out. This gives Utility
a planning tool instead of a second draw card, and lets a short setup turn fund a high-cost search later.

**Prototype:** `cold_cache` in `prototype_cards.py`; the discount needs a small run-rule hook and a card-data field.

**Pairing:** play it in a cheap program, then spend the discount on Cartesian Product, a subset search, or another
high-cost line. It does not add power to either cast.

**Art direction:** a bronze cache latch holding a single amber crystal in reserve, with one mana pip reflected in its
polished face.

### Parity Lattice · Guard · Brute Force

**Common · cost 1 · O(n) · cap 12 block per cast**

Every third attack bolt becomes a ward if its full power fits under the 12-block cap. Other bolts keep flying. Existing
wards pass through and count toward the cap. It converts part of a wide volley into predictable defense without
adding another expensive search. The cap keeps 192-bolt volleys from making a limitless shield.

**Prototype:** `parity_lattice` in `prototype_cards.py`.

**Pairing:** Cartesian Product and other wide Sources produce more eligible bolts, so the player can trade roughly a
third of the volley for block. Brute Force's work bonus still strengthens the remaining attacks; wards do not receive
that bonus. The block can cover slower foes later this turn, but faster foes have already acted.

**Art direction:** an alternating bronze-and-teal lattice, with every third crystal locking into a small shield cell.

### Collision Census · Shape · Brute Force

**Uncommon · cost 1 · O(n²), compare window capped at 24 bolts**

Among the first 24 bolts, each attack gains +1 for each other attack with the same power and element, up to +3. Wards
and the rest of a wider volley pass through unchanged. This rewards repeated values made by combinations and
Cartesian products without creating more bolts.

**Prototype:** `collision_census` in `prototype_cards.py`.

**Pairing:** repeated source patterns gain strength, while Parity Lattice can later convert part of the enlarged
volley into block. The comparison cap leaves room in the work budget for the rest of the program. Large searches can
still time out when several expensive cards are combined; that is part of Brute Force's risk.

**Art direction:** paired crystals connected by fine bronze threads; matching pairs flare, while unmatched stones stay
dim.

### Deadline Mint · Source · Greedy

**Uncommon · cost 1 · O(m), where m is the living foe count**

Reads the living foes' current intents, chooses the damaging attack with the earliest tempo (ties go to the larger
threat), and adds one bolt aimed at that foe. Its power is the intended damage capped at 8. If no foe has a damaging
attack intent, it adds nothing. Unlike Read Input, it makes one focused answer instead of one bolt per foe.

**Prototype:** `deadline_mint` in `prototype_cards.py`.

**Pairing:** its aimed bolt supports Greedy's fast kill chains and Local Optimum's next-turn mana. The total program
still has to beat the foe's tempo; the Source does not promise an Initiative kill.

**Art direction:** an amber bolt stamped from a tiny clockwork die, already pointed toward the first expiring fuse.

### Radix Sort · Order · Search & Index

**Uncommon · cost 1 · O(4n) for the current 0–9999 power range**

Stable radix sort by power, weakest first, using four base-16 passes. Unlike Counting Sort, its work does not grow with
the largest bolt's power. Equal-power bolts retain their original order, and bolt fields such as aim and ward status
travel with them.

**Prototype:** `radix_sort` in `prototype_cards.py`.

**Pairing:** provides reliable sorted input for Binary Execute and other searches, including volleys with a few very
large bolts. It makes Search & Index's precision dependable without borrowing a neutral sorter.

**Art direction:** four bronze sorting trays marked with hexadecimal runes; crystals move through them in four quick,
stable passes.

### Boundary Guard · Guard · Divide & Conquer

**Uncommon · cost 1 · O(n)**

Within each invocation, turns the weakest attack bolt into a ward if that subproblem contains at least two attack
bolts. Under Recurse, the left and right halves each choose their own boundary bolt; singleton halves keep their bolt
as an attack. It creates local defenses while leaving the rest of each subproblem intact.

**Prototype:** `boundary_guard` in `prototype_cards.py`.

**Pairing:** after Split or another splitting card, each half contributes a ward. Deep Recursion can produce more
local wards, but only from halves with at least two attacks. This gives Divide & Conquer a Guard that demonstrates
solving each subproblem locally.

**Art direction:** a branching bronze wall, one small shield set at the outer edge of each fork.

## Brute Force sustain: a relic hook, not a fake healing bolt

### Salvage Dividend · relic · general loot, strongest in Brute Force

After a successful program with at least 512 measured work deals damage, restore 1 Integrity. It can trigger at most
once per turn and restore at most 3 Integrity per fight. A timeout never triggers it, and it does not require a kill,
so it can help during a long boss fight. It rewards hard work that lands while leaving the timeout risk intact.

This belongs in a post-cast relic hook such as `ProgramRelics.after_cast`, where work and dealt damage are already
known. Do not teach an arbitrary card to mutate `battle` or invent a healing bolt. Example rule sketch:

```gdscript
var turn := int(battle.get("turn", 0))
var uses := int(battle.get("salvage_dividend_uses", 0))
var used_this_turn := int(battle.get("salvage_dividend_turn", -1)) == turn
if int(battle.get("last_work", 0)) >= 512 and dealt > 0 and uses < 3 and not used_this_turn:
	var missing := maxi(0, int(state.integrity_max) - int(state.integrity))
	var healed := mini(1, missing)
	if healed > 0:
		state.integrity += healed
		battle.salvage_dividend_uses = uses + 1
		battle.salvage_dividend_turn = turn
```

The use counter resets with the battle. If random relic access does not provide enough sustain in play, the same rule
could be explored as a Brute Force focus instead; that would mean revisiting the current three-focus choice, so it is
not assumed here.

**Art direction:** a cracked search prism gathered back into a small, mended integrity crystal.

## Lower-priority role gap: Exact Prefix · Order · Dynamic Programming

**Rare · cost 1 · O(nH), first 12 attack bolts**

Uses subset-sum dynamic programming to find an exact group of the first 12 front-targeted attack bolts whose power
equals the front foe's remaining HP plus shield, then moves that group to the front of the volley. If no exact group
exists, the volley stays unchanged. It creates no power and discards nothing.

**Prototype:** `exact_prefix` in `prototype_cards.py`.

This is the only candidate here that I would hold out of the first card batch. It would be most useful beside cards
that act on a prefix of the volley; otherwise it risks duplicating Coin Change's exact-subset lesson without changing
the turn much. Dynamic Programming does not need an Order card merely to make the role counts symmetrical.

**Art direction:** a bronze table of sums with one exact row highlighted, its selected crystals lifted into a neat
front row.

## Three review passes

### Pass 1 · Coverage and identity

The set addresses the thin Utility role, Brute Force's one-Shape pool, Greedy's one-Source pool, Search & Index's
single paradigm Order, and Divide & Conquer's lack of a Guard. It treats Dynamic Programming's missing Order as
optional, because its current cards do not depend on sorted input. Brute Force gets both a cheap ward route and a
separate, capped Integrity-recovery relic idea. No paradigm gets another generic damage-only card.

### Pass 2 · Hand and code traces

1. **Brute Force width:** start with attacks `2 spark, 2 spark, 2 spark` and a `4 spark` ward. Collision Census turns
   the three attacks into `4 spark` each; the existing ward is untouched. Parity Lattice turns the third attack into
   a ward, leaving two attacks and 8 total block. If the full program measured 640 work, the law adds 2 power to each
   remaining attack at landing; the ward receives no work bonus.
2. **Greedy urgency:** with a 6-damage attack at tempo 18 and a 4-damage attack at tempo 30, Deadline Mint adds one
   6-power bolt at foe 0. If the complete program's work is below 18, the first foe can be killed before acting and
   Local Optimum may pay its mana. At 18 work or more, that foe acts first; the card is not a tempo bypass.
3. **Search correctness:** Radix Sort maps powers `[900, 17, 255, 17]` to `[17, 17, 255, 900]`, keeping the two
   equal-power bolts in their input order. Binary Execute now receives the ordering it needs without a bucket array
   of 901 entries.
4. **Divide & Conquer defense:** after a split into `[9, 2]` and `[8, 3]`, Boundary Guard changes the 2 and 3 bolts
   into wards. Each half still has an attack. A singleton half would pass through unchanged.
5. **Dynamic exact packet:** against 8 HP, Exact Prefix turns `[6, 5, 3]` into `[5, 3, 6]`; the first two sum exactly
   to the target. If the input is `[6, 5, 4]`, there is no exact subset and it does nothing. That second result is why
   this candidate stays low priority.
6. **Utility tempo:** Cold Cache passes the current volley through, then makes the next cast cost one less. It is
   useful only if the next hand has a high-cost line; otherwise the player has spent a card for a delayed option.

### Pass 3 · Abuse and rules audit

- Collision Census is bounded to 24 bolts and +3 per bolt. The unbounded version would make repeated 192-bolt
  volleys too explosive and compound the Brute Force work bonus.
- Parity Lattice converts existing power rather than duplicating it, checks the 12-block cap, and never increases the
  bolt count. It is linear, so defense does not itself demand another slow search.
- Deadline Mint is capped at 8 power; otherwise a multi-hit intent could become an oversized free Source bolt.
- Radix Sort is stable and performs exactly four passes for the game's current maximum power. A future increase to
  that maximum must revisit the pass count and its complexity text.
- Boundary Guard leaves a one-bolt subproblem offensive, preventing deep recursion from turning every bolt into a
  ward.
- Salvage Dividend requires landed damage, starts only after the cast resolves, and is capped at three points per
  fight. This helps a successful slow build but never refunds a timeout.
- Exact Prefix only acts on a real exact sum and is explicitly optional. Its code does not mutate the input or invent
  targets.

## Skill expression and no-hit runs

No-hit play should be a mastery outcome that every paradigm can pursue, not a requirement that every build heal or
prevent every hit. A good mastery loop gives the player a readable threat, at least one deliberate response when a
hit can be prevented, and clear feedback about why the chosen plan worked or failed. In this programming game,
execution means building and ordering the right program, not reacting quickly.

The current tempo rule creates an important limit: a foe whose intent is faster than the full program acts before
the cast resolves. A ward produced by that cast cannot stop that earlier hit. This applies to any high-work build,
though Brute Force makes the gap easiest to notice. If avoiding every hit is meant to be attainable, the answer needs
to include some defense or tempo control available before that foe acts; adding more wards to the same late-resolving
volley does not solve it.

### Shared foundations

- Keep intent, target, work, budget, and the point where each foe acts visible together. The player should be able to
  identify the danger before pressing cast.
- Show the reason after resolution: which foe beat the program's tempo, which card changed the volley, what block
  absorbed, and why a timeout or target choice changed the result. A mastery game should teach causality, not make
  players infer it from a health bar.
- Give each threat more than one answer where possible: remove the threat, delay or redirect it, or absorb it. Make
  those answers differ in cost and work so choosing between them remains meaningful.
- Measure mastery with optional signals such as a clean fight, a lower-work solution, or a precise kill. Do not make
  one score the definition of a successful run; paradigms should get different ways to be clever.
- Avoid making no-hit depend on a rare random relic or a perfect draw. If the player is expected to prevent an
  announced hit, the relevant answer needs to be a reliable part of that build's available kit.

### Ways to make mastery feel different by paradigm

- **Brute Force:** give it setup defense or a way to survive its expensive warm-up, then reward a wide, high-work
  program that lands within budget. `Parity Lattice` helps the resolved volley defend itself, but it does not prevent
  a faster foe from acting first. A future Brute Force focus or relic could turn a successful, under-budget heavy
  cast into a small capped guard on the following turn. That rewards planning ahead without pretending the guard was
  available retroactively.
- **Greedy:** reward correctly identifying and removing the earliest dangerous intent, with the mana refund or
  follow-up depending on actually securing that kill. The skill is target priority and staying under the target's
  tempo, not simply maximizing damage.
- **Search & Index:** let precise selection and threshold checks save work or avoid a dangerous target. Show which
  values were selected and why; an exact search that spends extra work to overkill should be visibly worse than a
  cheaper correct result.
- **Divide & Conquer:** reward shaping separate subproblems for separate jobs, such as attacking one half and
  guarding another. Make the split and each half's result inspectable so the lesson is visible.
- **Dynamic Programming:** reward paying a setup cost to reuse a solution against repeated states, while making a
  fresh direct solution better when the state changes. The player should recognize when prior work applies and when
  it has gone stale.

### Brute Force example for a future defense hook

Against an imp that strikes at 24 ops and a slower golem at 96 ops, a 180-work Brute Force program lets the imp act
before any new ward in that program resolves. A later-turn guard bank earned by a successful, under-budget setup
cast can absorb the imp's next strike; the player then chooses whether to spend that cover on another wide cast or
to lower work enough to beat the imp. A timeout grants no banked guard. This creates a readable choice between
preparation, a cleaner fast program, and accepting a hit, instead of making a same-cast ward appear to work too late.

This is a direction to prototype, not a balance-ready rule. The general foundations above should support all
paradigms first; the delayed Brute Force guard is one candidate payoff for its distinctive high-work risk.

## Suggested first concept batch

Move forward first with **Parity Lattice**, **Collision Census**, **Deadline Mint**, **Radix Sort**, **Boundary Guard**,
**Cold Cache**, and **Salvage Dividend**. Keep **Exact Prefix** parked until the card pool has a stronger reason to
care about a carefully chosen prefix. These are candidates for later balance, art, localization, and executable
examples in all three supported languages; none of those production steps is included in this concept pass.
