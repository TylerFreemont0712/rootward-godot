# ADR-0056: The forge is a set of doors, and its changes happen on the cards

Accepted 2026-10-08. Refines the forge of ADR-0018 (refactors read as a diff) and the melt of the deck run; the rules
are unchanged.

## Context

The program run's forge was a list of buttons: melt names, a refactor picker, widen, leave. Nothing showed what would
change until after the click, and a melt named a card without showing it. The player asked for a forge in the spirit of
Slay the Spire's: a few choices first, then the chosen one in full, where melting visibly destroys a card from the deck
and refactoring turns the card into its better version.

## Decision

- **Doors first.** The forge opens on its choices beside the anvil (`shardrun/map-forge`): Melt a card down (deck runs),
  Refactor a card, Widen the Program or a spell, Bind a new spell (spellbook runs). Each door states its cost in the
  run's numbers ("Deck: 8 → 7 cards", "Slots: 5 → 6") and, when it cannot be used, why. Leave the forge as it is
  stays below.
- **Each door opens its stage, framed in its colour**: melt red, refactor teal, widen amber, bind violet. The mode
  reads before a card is touched.
- **Melt** shows the deck as its cards (`ForgeCardGrid`, the draft size, a count badge for each copy). Choosing a card
  rings it, dims the rest and writes what leaves the deck. The confirm row appears only then, and its button is in
  the danger colour. Confirming plays a rune circle (`ForgeRune`) over the card; the card shrinks and breaks away;
  then the `purge` command goes out.
- **Refactor** shows the cards that have a better version beside the diff. Choosing one lays its current face beside
  the better one, with the diff below. Confirming flashes the card and turns it into its better version in place; then
  the `forge` command goes out.
- Every choice still ends in one command the rules judge. The motion is presentation only: tests and reduced motion
  skip it (`ForgeAnimation.instant`, `Settings.reduced_motion`).

## Consequences

- `RoomPanel` hands the forge to `ForgeRoom` (`forge_room.gd`); `ForgeMeltView` and `ForgeView` are its two stages and
  share `ForgeCardGrid` and `ForgeAnimation`. The melt that lived in `RoomPanel` is gone.
- The program run's melt was always in the rules (`ShardrunRules.is_deck` covers program runs); its screen now shows it
  as cards.
- Screenshots: `ROOTWARD_SHOT=forge`, `ROOTWARD_SHOT_FORGE=melt|improve|widen|bind` opens a door,
  `ROOTWARD_SHOT_PICK=<card id>` chooses a card in it.
- New text is Japanese in `interface-rooms.jsonc`, reusing the forge's existing vocabulary.
- The rune circle and the morph are drawn in code, so they cost no assets; a painted pass can replace them later.
