# ADR-0012: programs, paradigms, and the speed race

- Status: accepted
- Date: 2026-09-26
- Related: ADR-0003 (the rules ported line for line), ADR-0004 (content as JSONC), ADR-0009 (the card Shardrun);
  the parked speed patch in `docs/parked/speed-patch/`

## Context

The player, after playing the card Shardrun: "there is not very many ways for the 'speed' of the program to be faster
or slower than O(1) or O(n)... I want a more complex game that has an actual interaction with programs, algorithms,
everything... things that would cause the speed to be O(log n) or O(n log n) but extremely powerful." And: "before a
run starts you have a small draft of like 5-10 cards that have different power/abilities... different methodologies
that allow for many different combos." Then: "let's get this started particularly with the paradigm... use real
algorithms and code... a whole new damage and combat system... ensure that there is actual programs being made instead
of just an unordered list of spells", and in the fight, "having the code always be present and be built along with
the spell and you can SEE it being built... a small effect of some type of rune for the text fading into the actual
code."

In the old rules a shard's complexity only priced its mana (O(1), O(n), O(n log n), O(n²) over the bolts it was
given), every bolt was independent, and a spell's order mattered little. A speed patch from another session (turn
order by work) had broken the fixtures and was parked; its idea is carried here, in its own playstyle.

## Decision

- **A new playstyle, `program`, is the Shardrun.** Its rules live in `core/programs/` (`ProgramRules`,
  `ProgramDraft`) beside the ported ones, which stay exactly as proven. The card Shardrun (`deck`) is still a
  playstyle, offered on the title only while a run of it is underway; Spellforge is unchanged.
- **Program content is new** (`packs/core/programs/`): 23 cards, each a real function `f(bolts, battle) -> bolts` in
  Python and JavaScript with worked examples run in the sandbox (`ShardExamples`), and `programs.jsonc`: the seed
  volley, the Program (one spell, five slots), the budget, the draft, the basics, five paradigms, the neutral pool, foe
  tempos, and the relics that work on programs. A program run's catalog is derived (`ProgramRules.catalog_for`): the
  cards are served as `shards`, so the deck machinery (hand, compose, discard, rewards, purge, forge) works unchanged.
- **Paradigms are schools of algorithms**, each with a speed class and signature cards: Divide & Conquer
  (O(n log n): divide, merge-strike), Search & Index (O(log n) on sorted data: prefix-sum, binary-execute), Greedy
  (O(n): greedy-assign, take-max), Brute Force (O(n²) and O(2ⁿ): pairwise, exhaustive-kill), and Dynamic Programming
  (O(n·H): tabulate, knapsack-strike, and naive fib-surge that a forge optimises into fib-memo).
- **Bolts carry targets.** A bolt is `{power, element, foe?, block?}`: `foe` indexes the living foes as the code saw
  them, `block` makes it a ward. The rules clamp and resolve every bolt themselves (weak/resist, shields, traits); a
  bolt at a foe already down, and damage past a foe's HP, are *wasted*, which is what aiming cards are for.
- **Work is measured, not declared.** Each stage's work is its complexity class applied to n = the larger of the
  volley it was given and the volley it returned, both measured by the harness (`ProgramRules.work_units`; cap_n caps
  exponential cards, H is the front foe's HP plus shield). The Program's work is the sum.
- **The speed race.** Every foe has a tempo (ops). When a Program is cast, every living foe whose tempo is below its
  work acts first (logged as `tempo`, then its intent), and does not act again at the end of the turn: a slow program
  cannot kill a foe before it strikes, and shields go up before the bolts land. Work over the budget (4096) is a
  timeout: the mana is spent and nothing lands.
- **Order is part of the program.** Cards declare what they need (`needs: sorted`) and leave (`makes`); the code
  panel warns when a card that needs a sorted volley follows one that left it unsorted (`ProgramRules.lint`). The
  warning is advice: binary-execute on unsorted bolts runs, and misses, as the real algorithm would.
- **Cost is mana per card**, 0 to 2, against the Shardrun's mana per turn.
- **The draft**: before the first room, three paradigms are offered from the seed; the chosen one's signature cards
  join eight basics, then five packs of three (paradigm cards twice as likely, rarer cards rarer) each give one card.
- **The code is always on the table** (`ProgramCode`): the Program's source (`ProgramSource`) in the run's language,
  each call noted with its class and, once measured, its n and ops; a race bar of the foes' tempos against the
  Program's work on a log scale up to the budget; and what it will do. New lines are written in by `RuneCode`: each
  character appears as a flickering futhark rune in the paradigm's colour, then cools into the real character. During
  a cast the lines light up in order with their measured n and work, then the stage plays the bolts.

## Consequences

- The fixtures and the ported rules are untouched; every old test still proves the old engine. The program rules have
  their own tests (`test/core/programs/`, `test/app/program_session_test.gd`).
- Balance (tempos, budget, card numbers) is a first guess, to be tuned by play. A foe acting first is a cost only when
  the program would have killed it or its shield blocks the volley; tempo can later also grant extra actions.
- Card art borrows the old shards' pictures (`art`), so no card is blank; cards of their own can follow.
- A program is one spell, widened at a forge; binding a second program is refused.
