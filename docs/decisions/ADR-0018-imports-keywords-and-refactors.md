# ADR-0018: imports and fight state, keywords, every card's + as a refactor, and a picture for every card

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0012 (programs), ADR-0016 (a deeper Shardrun), ADR-0017, `docs/ROADMAP.md` stage 6,
  `docs/SHARDRUN_DESIGN.md` 3.3 to 3.5

## Context

Stage 6's Artificer asked for imports and keywords, fight state, a `+` for every card and a picture for every card
(SHARDRUN_DESIGN 3.3 to 3.5); the player asked for all of them: "imports and keywords, + versions of cards, pictures,
japanese". The design pillar for all of it is that a turn is a program: an import is a line of it, a keyword a word a
programmer would use, and an upgrade a refactor you can read.

## Decision

- **Imports are cards played into the Program** (role `import`, a pink badge). They are not steps: their lines are
  written at the top of `main.py` (the card's `line`, one per language), and after the program runs they stay in force
  for the rest of the fight (`battle.imports`). They cost their mana and a slot on the turn they are written, which is
  the trade; a separate rail would have added a zone to the table for the same effect. A module counts once, as in
  Python (`sys.modules`), so a card and its + never stack. What an import does is data:
  - the relics' effect kinds, scoped to the fight (`functools.cache` is the JIT, `numpy` makes shape cards O(1),
    `itertools` makes brute force cheaper through a new `card-cost` kind, Generator adds seed bolts);
  - **hooks** (`hook-before` or `hook-after` a role): the import's own function runs in the sandbox on the volley before
    or after every card of that role (`heapq` hands each strike the strongest bolt first; `bisect` keeps what each
    source makes sorted). The lint follows the hooks: Binary Execute after `heapq` is warned about;
  - modules the cards' code reads: `battle["imports"]` holds their names, and Divide, Merge Strike and Recursion Tree
    count every level twice with `math`.
- **Fight state**: `battle.globals`, handed to the cards' code as `battle["globals"]`. `global total` adds every
  program's landed damage to `total`; Release turns half of it into a bolt and `spends` it (it starts again from 0).
- **Keywords** (`keywords`, at most two a card; meanings in `programs.jsonc`, chips on the card's face, lines in its
  details), all a program run's own (`ProgramDeck`), the shared deck rules calling in only for a program run:
  `once` (gone for the fight after its program), `volatile` (gone if still in the hand at the end of the turn),
  `const` (stays in the hand without a hold slot), `__init__` (always in the opening hand) and `lambda` (a card another
  card makes: Higher Order writes two free, `once` Lambdas on top of the draw pile). `pure`, `async` and `recursive`
  wait for the foes that give them meaning (the Race Condition Imp's swap, the Stack Overflow Serpent).
- **Every card has a +** (`<id>-plus`, 56 of them, never drafted): a refactor of its code in both languages, proven by
  the base card's worked examples run again: a tune (Amplify's +3 becomes +4), an optimisation (Quick Sort+ takes the
  median of three as its pivot, so a sorted volley no longer costs O(n²)) or a generalisation (Round Robin+ skips a foe
  its bolts already cover), sometimes a cost or a keyword (an import's + is `__init__`). The two cards that already
  optimised into another (Fibonacci Surge, Bubble Sort) keep that road. **In a program run the forge shows the diff**
  (`CodeDiff`, `ForgeView`): the lines a refactor removes in red and adds in green, the function's rename hidden so only
  the change stands out, beside its cost and keyword changes.
- **Every program card has its own picture**, `shardrun/card-<id>` (the 25 of ADR-0016 moved there), never an old
  shard's: the first 23 cards borrowed Spellforge's pictures, and six share their id with a Spellforge shard, whose
  pictures a new one must not replace. A + shows its card's (`art`).

## Consequences

- 115 program cards (59 and their +), 43 program relics, 2 program foes. Every worked example passes in both languages
  (319 of them).
- Imports and keywords are untuned (the player: "a step back from the balancing"): `numpy` and `functools.cache` may be
  strong, Lambdas may be generous.
- The card faces show more (keywords, the import badge) at the same sizes; the chips are legible on a hand card and a
  slot, small on a deck grid.
- Japanese for the new text is the next step (stage 6's "Japanese for every card").
