# ADR-0016: a deeper Shardrun: tiered relics of its own, roles on cards, a three-bolt seed, twice the cards, and a git log

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0012 (programs), ADR-0013 (the card table), `docs/ROADMAP.md` stages 1 and 6, `docs/SHARDRUN_DESIGN.md`

## Context

The player, after reading the roadmap: "focus on the shardrun portions. Particularly Stage 1 and 6. Implementing roles on
the card face to give the cards a little more depth, three bolt start to reduce dependency on a single card, run
history using a git.log or programmer heavy lingo. The artificer should also have new relics and shards. Honestly, I
want to almost double the amount of shards, and make sure that the relics aren't too... bland (3 block every turn),
let's add some more relics and give them a tier system ... (common, uncommon, rare, epic, legendary) ... an elite
encounter would have 100% of rare or higher."

The balance probe (`docs/research/balance-probe/`) had shown that Salvo was the whole engine (a turn did 56 damage with
it in hand and 5 without) because a program started from one 3-power bolt, and that the difficulty was a cliff.

## Decision

- **Program relics are the program run's own content** (`packs/<pack>/programs/relics/`, `ProgramSchemas.relic()`),
  each with a **tier**: common, uncommon, rare, epic, legendary (tiers 1 to 5), shown in its colour and as "tier n".
  The fourteen relics the run used to borrow from Spellforge are copied and tiered; Spellforge's relics, their
  rarities and every fixture that proves them are untouched. A curse keeps `cursed: true` and is never loot.
- **Loot tables by place** (`programs.jsonc` `relic_tiers`): a treasure leans common (up to epic), an **elite offers
  only rare or better**, a guardian only epic or legendary. `ProgramLoot` draws a tier by weight among the tiers that
  still have a relic to offer (a tier run dry leaves the draw), then a relic of it, from the run's seed.
- **The program's relic effects** live in `ProgramRelics`: the seed (more and stronger input), costs (a role's price,
  a free second copy, a free turn on a schedule), work (the first card free, a JIT for cards already run, a factor,
  a role's class), foe tempo, the budget, and the landing (elemental and sorted volleys, program-size and speed
  factors, the strongest bolt, foes out-sped, echoes, every element at once, overkill that flows on, waste kept as
  block), and what a kill pays. `ProgramRules` asks for them in `stages`, `cost_of`, `budget`, `tempo_of`, `resolve`
  and `preview`, so a relic never makes a cast differ from its preview. The shared rules gain two hooks, each only on
  the program branch: extra mana when a fight starts, and mana a program earned for the next turn.
- **Roles on the card face**: source, shape, order, strike, guard (`grow` became `source`), a glyph and a word in the
  role's colour on a pill over the frame's lower panel (`RoleBadge`); a card's details lead with its role.
- **Programs start from three 3-power bolts** (`programs.jsonc` `seed`), read through `ProgramRules.seed` so relics
  can add to it; the code panel writes a uniform seed as a comprehension. **A program run has its own foe HP by layer**
  (`programs.jsonc` `foe_hp`, applied in `ProgramRules.catalog_for`), so its curve can change without touching the
  Spellforge layers, and **its own pattern ward** (`pattern_off`: a bolt of the wrong element does half, where
  Spellforge's does a quarter).
- **Twenty-five new cards** (48 in all), each a real algorithm in both languages with worked examples; two new card
  fields: `worst_case` (a worse class on one kind of input: Quick Sort is O(n²) on a sorted volley, billed so) and
  `height` (a fixed H for an O(n·H) table).
- **Twenty-eight new relics** (42 in all: 10 common, 9 uncommon, 8 rare, 6 epic, 5 legendary, and 4 curses).
- **The run history is a git log**: every run that ends is appended to `history.jsonl` beside the saves (`RunHistory`
  makes the record, `SaveStore` keeps it), shown from the title as `git log --oneline --decorate` (`GitLogView`; a
  click shows the run's `git show`) and, at the end of a run, as the line `git commit` prints. A win is
  `feat(<paradigm>): ship it`, tagged `shipped`; a loss is `revert(<paradigm>): kernel panic on layer n by <foe>`; an
  abandon is `chore(...): reset --hard`. Damage dealt is insertions, Integrity lost is deletions.

## Consequences

- A program run saved before this change continues: its relic ids exist, and the seed and curve are read from content.
- New relic kinds need no engine change to be reused, only content; a new kind is one match arm in `ProgramRelics`
  and one test.
- Balance was tuned with the probe after the content landed (below); fun and pace still need the player's runs, which
  the history now keeps.
- Not done here (stage 1 and 6 items the player did not ask for yet): the Deadlock Golem's rework, the speed race's
  Initiative as a rule (it exists as a relic), imports and keywords, pictures of their own for the first 23 cards,
  Japanese for the new text.

## Balance

Tuned after the content landed with the balance probe's smart bot (`docs/research/balance-probe/`, `curves.py`): five
to eight seeds of each of the five paradigms per setting, the same seeds throughout, JavaScript on Beginner.

| setting | runs | won | worst-best paradigm | beat boss 1, 2 | act 1 fights: turns, HP lost | act 1 boss: turns, HP lost | Salvo in hand | empty turns | foe first | reorder wins | lost most to |
|---|---|---|---|---|---|---|---|---|---|---|---|
| x1.6, x2.4, x4.4 (the first guess) | 40 | 62% | 25-100% | 100%, 90% | 1.3, 0.8 | 2.7, 3.7 | 1.7x | 5% | 19% | 48% | root-daemon 7, garbage-collector + segfault-specter 4, deadlock-golem 4 |
| x2.6, x3.8, x4.6 | 25 | 48% | 20-80% | 100%, 64% | 1.5, 1.4 | 3.7, 6.6 | 1.6x | 5% | 22% | 51% | deadlock-golem 9, root-daemon 2, segfault-specter + race-condition-imp 2 |
| x3.0, x4.4, x5.2 | 25 | 48% | 20-60% | 100%, 72% | 1.6, 1.4 | 4.4, 8.9 | 2.1x | 4% | 23% | 54% | deadlock-golem 6, root-daemon 3, garbage-collector + segfault-specter 2 |
| x2.4, x3.6, x4.6 | 30 | 53% | 33-67% | 100%, 67% | 1.5, 1.2 | 3.3, 6.9 | 1.6x | 5% | 22% | 51% | deadlock-golem 10, root-daemon 3, stack-overflow-serpent + dangling-pointer 1 |
| x2.4, x3.6, x4.6, ward x0.5 (chosen) | 30 | 53% | 33-83% | 100%, 83% | 1.5, 1.2 | 3.1, 5.6 | 1.7x | 5% | 23% | 51% | root-daemon 6, deadlock-golem 4, garbage-collector + segfault-specter 2 |
| the same, dealt-order bot | 30 | 3% | 0-17% | 57%, 7% | 2.8, 7.5 | 9.4, 32.5 | 1.6x | 0% | 39% | - | kiln-warden 8, deadlock-golem 5, memory-leak-ooze + race-condition-imp 4 |

- **Foe HP by layer ×2.4, ×3.6, ×4.6** in a program run (Spellforge's layers keep ×1, ×2.6, ×6.8). The first guess was
  too kind (62% won, one paradigm every time); the steeper curves cost the weakest paradigm a run in five more
  without making Act 1 any longer.
- **A pattern ward lets a bolt of the wrong element through at half** in a program run (`programs.jsonc`
  `pattern_off`; Spellforge keeps a quarter). At a quarter the Deadlock Golem ended ten of the fourteen lost runs:
  a test of whether this turn's hand held this turn's element. At half the losses spread over the last guardian, the
  Golem and the elites, and the win rate is the same. The Golem's rework (SHARDRUN_DESIGN 6.3) is meant to replace it.
- **Against stage 1's targets** (with 30 runs, not 40): met are the win rate (53%; target 40-60%), the weakest paradigm
  (33%; 25% or more), Salvo's weight (1.7×; under 3×), a foe first (23% of turns; 20-35%) and reordering (51% of
  turns; 35% or more). Missed are Act 1's pace (the smart bot's fights take 1.5 turns and 1.2 Integrity, against two
  to four and three to eight), empty programs (5% of turns; under 3%) and the dealt-order bot's first guardian (57%;
  70%). The first and the last pull against each other: more Act 1 HP lengthens the smart bot's fights a little (1.3 to
  1.6 turns over every curve tried) and would cost the dealt-order bot more of its first guardian. Act 1 waits for foes
  that act first and hit harder (the speed rules still to come), and where a person lands between the two bots is for
  the player's runs to show; the git log keeps them. Initiative is not a rule yet, so it is not measured.
