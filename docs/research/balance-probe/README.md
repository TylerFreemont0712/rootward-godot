# The balance probe (research, 2026-09-28)

A script written while planning `docs/ROADMAP.md`, kept here so its numbers can be reproduced. It is not part of the
game: nothing loads it, and the lint and tests do not cover it. Stage 0 of the roadmap turns it into a tool
(`tools/balance_sim.gd`, `scripts/balance.sh`).

## What it does

`probe_balance.gd` plays whole program runs (ADR-0012) through `Shardrun.step` and the real sandbox, with no screen
and no saves:

- **The smart bot** takes every ordered choice of cards from the hand that the mana and the Program's slots allow (up
  to about 2,000 a turn), runs them all in **one** sandbox job, simulates each cast and the foes' answer with the
  real rules, and plays the one that removes the most foe HP for the least Integrity (a lost fight is worth nothing, a
  won one a lot). It holds its most valuable leftover card. It drafts toward its paradigm (rarer is better, paradigm
  cards and strikers preferred, fewer copies of what it has), walks into fights and elites while healthy and rests
  when not, optimises or widens at a forge, and takes the first relic offered.
- **The dealt-order bot** (`policy=dealt`) plays every card it can afford, in the order dealt.
- **What-ifs** (`variant=`) change the content in memory before the run starts; the repository is never touched:
  `sources4` (two more Salvos in the starting deck: four in ten cards instead of two in eight), `salvo-pool` (Salvo
  draftable), `curve` (Act 2 HP ×1.8 and Act 3 ×3.6 instead of ×2.6 and ×6.8), `seed3` (programs start from three
  3-power bolts), `golem` (bolts off a pattern ward do half instead of a quarter, the content's own value since
  ADR-0016), `ward-quarter` (a quarter again, as before ADR-0016). `foe_hp=a,b,c` sets a program run's foe HP by
  layer. `picks=sources` makes the drafter value Salvo and Fork while they are scarce in the deck.

Seeds are chosen so the paradigm is offered, and the same seeds are used across what-ifs (a paired comparison: the
same draws, so a difference is the change's and less the luck's).

## Running it

```
godot --headless --path game -s "$PWD/docs/research/balance-probe/probe_balance.gd" -- \
    paradigms=greedy seeds=8 difficulty=beginner out=/tmp/probe/runs_beginner_greedy.jsonl < /dev/null
python3 docs/research/balance-probe/analyze.py /tmp/probe/runs_beginner_*.jsonl   # one experiment, in detail
python3 docs/research/balance-probe/compare.py /tmp/probe                         # every experiment, one row each
```

Options: `paradigms=a,b`, `seeds=N`, `offset=N`, `difficulty=beginner|programmer`, `policy=smart|dealt`,
`picks=plain|sources`, `variant=a,b`, `foe_hp=a,b,c`, `hp_weight=2.5` (Integrity against foe HP in the bot's
judgement). A run takes
20 to 80 seconds; one process per paradigm in parallel is the quick way (the sandbox runs out of process, so they do
not contend much). `compare.py` expects the baseline as `runs_beginner_<paradigm>.jsonl` and each what-if as
`exp_<name>.jsonl`.

## What the bots cannot tell you

- They are a floor and a ceiling for a person, not a person. The smart bot looks one turn ahead, sees every outcome
  exactly (as the Beginner preview does), and never plans a deck; the dealt-order bot never thinks at all.
- Drafting is a simple scoring rule, so a what-if that depends on drafting well (Salvo in the pools) needs
  `picks=sources` to show its effect.
- JavaScript and Beginner only so far; there is no shop, event or upgrade to model because none exist yet.
- Fun, clarity and pace are not measured. The player's own runs are the other half (the roadmap's run history).

## Results on 2026-09-28

<!-- whatif:start -->
| experiment | runs | won | beat boss 1 | beat boss 2 | act 1 turns | act 1 HP lost | Salvo in hand | empty turns | foe first | reorder wins | won, worst-best paradigm |
|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline (smart bot) | 40 | 2% | 100% | 40% | 1.5 | 1.0 | 11x | 9% | 18% | 40% | 0-12% |
| dealt-order bot | 30 | 0% | 63% | 0% | 2.6 | 5.1 | 8x | 0% | 21% | - | 0-0% |
| softer Golem (x0.5 off-pattern) | 30 | 3% | 100% | 63% | 1.6 | 1.3 | 11x | 10% | 20% | 41% | 0-17% |
| Salvo in draft pools | 30 | 0% | 100% | 50% | 1.6 | 1.2 | 9x | 11% | 18% | 42% | 0-0% |
| source-aware drafting | 30 | 17% | 100% | 57% | 1.6 | 1.3 | 12x | 9% | 22% | 47% | 0-50% |
| Salvo in pools + source-aware drafting | 30 | 10% | 100% | 63% | 1.5 | 1.1 | 10x | 9% | 23% | 47% | 0-17% |
| seed of 3 bolts | 30 | 20% | 100% | 83% | 1.2 | 0.5 | 2x | 4% | 29% | 53% | 0-50% |
| 4 Salvos in the starting deck | 30 | 20% | 100% | 67% | 1.3 | 0.9 | 14x | 8% | 23% | 46% | 0-33% |
| gentler HP curve (x1.8, x3.6) | 30 | 20% | 100% | 67% | 1.6 | 1.3 | 11x | 12% | 18% | 39% | 0-50% |
| 4 Salvos + gentler curve | 30 | 30% | 100% | 80% | 1.3 | 0.9 | 10x | 8% | 19% | 43% | 0-67% |
| seed of 3 bolts + gentler curve | 30 | 43% | 100% | 90% | 1.2 | 0.5 | 2x | 5% | 25% | 49% | 17-67% |

Columns: *beat boss 1/2* is the share of runs that got past the Kiln Warden and the Deadlock Golem; *Salvo in hand* is
a turn's damage with Salvo in hand over a turn's without; *empty turns* are turns where the best program was empty;
*foe first* the turns where a foe out-sped the program; *reorder wins* the turns where some reordering beat every
program in dealt order. Salvo in the draft pools does nothing for a drafter that never takes it; the next two rows
draft it on purpose.

Reading it. Softening the Golem alone moves the wall to Act 3: more runs get past it (63% against 40%), almost none
win. Four Salvos, a gentler curve, a drafter that wants Salvo, or a stronger seed each lift the win rate to between a
tenth and a fifth, and the Salvos with the curve to 30%. Only the seed changes the shape of the game: every other fix
leaves a turn with Salvo doing ten times what a turn without it does, while programs that start from three bolts bring
that to 2×, halve the empty turns (4% against 9%), make reordering matter in more turns (53% against 40%) and put foes
in the race more often (29% against 18%). With the gentler curve it won 43% of runs, and every paradigm won some (17%
to 67%). Its cost is Act 1, already too easy and now a formality (1.2 turns a fight, half an Integrity lost), so the
curve has to rise at the start as it falls later. Stage 1 starts from there.
<!-- whatif:end -->

## After stage 1's content (ADR-0016), 2026-09-28

With the 25 new cards, the 42 tiered relics and their loot tables, and the three-bolt seed, a program run got its own
foe HP by layer and its own pattern ward. `curves.py` makes the table; each row is five to eight seeds of every
paradigm, the same seeds throughout (*lost most to* names the fights that ended the lost runs):

| setting | runs | won | worst-best paradigm | beat boss 1, 2 | act 1 fights: turns, HP lost | act 1 boss: turns, HP lost | Salvo in hand | empty turns | foe first | reorder wins | lost most to |
|---|---|---|---|---|---|---|---|---|---|---|---|
| x1.6, x2.4, x4.4 (the first guess) | 40 | 62% | 25-100% | 100%, 90% | 1.3, 0.8 | 2.7, 3.7 | 1.7x | 5% | 19% | 48% | root-daemon 7, garbage-collector + segfault-specter 4, deadlock-golem 4 |
| x2.6, x3.8, x4.6 | 25 | 48% | 20-80% | 100%, 64% | 1.5, 1.4 | 3.7, 6.6 | 1.6x | 5% | 22% | 51% | deadlock-golem 9, root-daemon 2, segfault-specter + race-condition-imp 2 |
| x3.0, x4.4, x5.2 | 25 | 48% | 20-60% | 100%, 72% | 1.6, 1.4 | 4.4, 8.9 | 2.1x | 4% | 23% | 54% | deadlock-golem 6, root-daemon 3, garbage-collector + segfault-specter 2 |
| x2.4, x3.6, x4.6 | 30 | 53% | 33-67% | 100%, 67% | 1.5, 1.2 | 3.3, 6.9 | 1.6x | 5% | 22% | 51% | deadlock-golem 10, root-daemon 3, stack-overflow-serpent + dangling-pointer 1 |
| x2.4, x3.6, x4.6, ward x0.5 (chosen) | 30 | 53% | 33-83% | 100%, 83% | 1.5, 1.2 | 3.1, 5.6 | 1.7x | 5% | 23% | 51% | root-daemon 6, deadlock-golem 4, garbage-collector + segfault-specter 2 |
| the same, dealt-order bot | 30 | 3% | 0-17% | 57%, 7% | 2.8, 7.5 | 9.4, 32.5 | 1.6x | 0% | 39% | - | kiln-warden 8, deadlock-golem 5, memory-leak-ooze + race-condition-imp 4 |

The content holds the chosen row, so it needs no options. The rows before it are `foe_hp=` with
`variant=ward-quarter`, and the last is `policy=dealt`:

```
for p in greedy brute-force dynamic divide-conquer search-index; do
  godot --headless --path game -s "$PWD/docs/research/balance-probe/probe_balance.gd" -- paradigms=$p seeds=6 \
      foe_hp=2.4,3.6,4.6 variant=ward-quarter out=/tmp/probe/quarter/runs_beginner_$p.jsonl < /dev/null &
done; wait
python3 docs/research/balance-probe/curves.py "x2.4, x3.6, x4.6=/tmp/probe/quarter" "chosen=/tmp/probe/chosen"
```

Reading it: the curve sets the win rate and how many runs pass the second guardian, while Act 1 barely moves (the smart
bot's fights take 1.3 to 1.6 turns on every curve). Softening the ward keeps the win rate and moves the losses off the
Golem. ADR-0016 has the choice and what stage 1's targets it meets.
