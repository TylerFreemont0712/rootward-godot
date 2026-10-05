# ADR-0049: cycles, the Registry and scripts

- Status: accepted
- Date: 2026-10-04
- Related: ADR-0016 (relics and loot), ADR-0048 (laws and focuses), `docs/ParadigmUpdate.md` B5 to B7 and B12

## Context

The player asked for a shop, a money system tied to kills and difficulty, random relics to buy, and a way to reach other
paradigms' cards without a reward table that ignores the paradigm (ADR-0048). Slay the Spire's potions were wanted in the
same update.

## Decision

- **Cycles** are earned when a fight is won (`ProgramCycles`): `floor(base(kind) x layer factor x difficulty factor)` a
  kill (a guardian's pay is shared by its bodies, a summoned foe pays 1, unscaled), plus 1 for an exact kill, 1 for a
  kill that landed before the foe could act, 5 for a fight taking no damage, 3 for one won in one program, a bounty
  or the Bug Bounty Program relic when held. A treasure pays 20 x the layer's number, and skipping the cards 10 x the
  layer's. The numbers are data (`programs.jsonc` `cycles`, `rewards`). A won fight leaves a receipt on its reward.
- **The Registry** (`ProgramShop`, a room kind `shop`, a fixed row two before the layer's rest) stocks five cards (two of
  your paradigm, one neutral, one of another, one of any), three relics (legendary one time in a hundred), three
  scripts and three services (`uninstall`, which costs 25 more each use, `refactor`, `pip install <paradigm>`; `repay` when
  you hold Technical Debt). Stock and prices are drawn from the seed and the room; nothing restocks. Relics' effects
  change prices (Package Lock, Coupon Code, Lockfile, Alias), the stock (Mirror Server) and the visit (Venture
  Capital's toll, Interest Rate).
- **Scripts** (`ProgramScripts`) are one-use commands on a belt of three: sixteen, named after real commands, each an
  effect kind in `IssueSchemas.script()`. What a script changes is kept in the battle (`nice`, `jobs`, `double_next`,
  `free_program`, `free_cards`, `gc_seed`, `stashed`, `no_curses`, and a foe's `ulimit`), so the preview, which plays a copy,
  shows it. `fork()` of the design became `chmod +x`: running a program twice would have meant landing it twice.
- The program run's own map rows (`programs.jsonc` `map`) are two longer than the Shardrun's; Spellforge's maps, relics
  and fixtures are unchanged (`ShardrunMap.ROOM_KINDS` gained `shop` and `issue`, which a layer with no weight for them
  never draws; program-only battle keys are only written in a program run).
- Program loot presents clickable relic choices before clickable card choices, one focused stage at a time; card faces
  are 20% larger than hand cards. The cycle receipt and optional script stay in a compact header, and an optional spell
  follows the card stage. Skipping clears only that reward field, so later rewards remain available; acknowledging a
  forced cursed relic advances the presentation without undoing the curse already applied by the rules.

## Consequences

- The probe and the bot have to be taught to spend cycles and use scripts before balance can be measured (ParadigmUpdate,
  handoff). The bot shops (relic, script, card) and takes script drops; it does not use scripts in a fight yet.
- Old program saves load: new state fields have defaults in `ShardrunSchemas.program_state_defaults`, and a run begun
  before keeps its map (no Registry) and no belt.
- The reward screen follows the reward data's lifecycle rather than collapsing everything into one crowded list. The
  command layer owns the skip/claim effects, while the UI simply shows the next nonempty reward stage.
