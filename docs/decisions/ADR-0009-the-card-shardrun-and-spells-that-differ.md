# ADR-0009: the card Shardrun first, and spells whose shape depends on what they do

- Status: accepted
- Date: 2026-09-25
- Related: ADR-0003 (the rules ported line for line), ADR-0006 (screens and the run session), ADR-0008 (spell sprites);
  in the old repository, ADR-0020 (the deck playstyle)

## Context

The player: "implementing the original shardrun is the next step right now. The spellforge is nice, but the main pull
of the game was the shardrun with the different shards and card mechanic." In the old game that is the deck
playstyle (its ADR-0020): shards are cards, a fight deals a hand every turn, and the hand is played into blank spells
in the order they should run, so building the spell is the turn. Its rules were already ported and proven here
(twelve replayed deck runs, 372 `compose` commands); only the game around them was missing.

On spells: "spell effects are cheap, and I want you to go all out on them... spells should have a variety of
animations. Lightning being called for large lightning based attacks, area effects hitting both, etc."

## Decision

- **Two playstyles, named for the player**: *Shardrun* (the deck) and *Spellforge* (the spellbook). Each keeps its own
  run and save (`Game.sessions`); the title offers both, Shardrun first, and remembers the choice (`Settings.playstyle`).
- **The table is pure data** (`app/card_table.gd`, the old client's `table.ts`): a move, a click (into the targeted
  spell, or back to the hand) and a hold toggle each make a new table, and `CardTable.command` turns it into the rules'
  `compose`. Tests check that every table a move makes is one the rules accept.
- **Cards look like cards** (`CardFace`): work cost, complexity, the shard's picture, its name in its rarity's colour,
  a frame in the colour of the element it gives, its summary on Beginner or its function's name on Programmer, and its
  real code as the hover tooltip. Godot's own drag and drop moves them; a click plays one, a right click holds it.
- **The fight** (`DeckTable`): the spells as rows of card slots (one outlined as the target), and under them the draw
  pile, the hand (dealt in with a staggered rise each turn), the hold and the discard pile. Between rooms the workbench
  becomes the deck (`DeckPanel`), and a *Deck* drawer shows the piles during a fight. Rewards add cards, and the forge
  can melt one down.
- **A spell's shape comes from what it does**, read from the cast's log, never decided by the screen:
  - a heavy spell (four or more bolts, or 30 damage) darkens the stage, opens a vortex at the hand, and calls its blows
    down on each foe as the element's strike: lightning from the sky (sprite, code-drawn bolts, a flash, a shake), a
    fire pillar rising, ice spikes erupting and shattering, a beam of starlight falling;
  - a volley that hits several foes sends a wave across the floor under them;
  - everything else flies as the element's bolt and lands in its burst.
  Strike, wave and vortex sprites come from the concept boards like the others (`pipeline/sprites/fx.json`), with a
  source recoloured toward the element first when the board was drawn in another one's colours.

## Consequences

- A Shardrun fight needs no new rules, and nothing on the table can create or lose a card: the rules check every move.
- New variety is data plus a little code: a new element's strike is a line in `fx.json` and a case in `BattleFX`.
- Custom card art and animations are the obvious next step (the player: "custom animations for the cards or sprites
  for the cards would be nice"); cards today use the shards' pixel-art icons.
- The build-code view of the old game (a spell's function growing card by card) is not here yet; `</> Code` shows it.
