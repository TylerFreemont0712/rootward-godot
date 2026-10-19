# ADR-0070: Lanternroot completely in Japanese

Accepted 2026-10-16. Builds on ADR-0047 (translation overlays). The voice and the glossary are
`Concept/v0.4/06-japanese.md`.

Updated 2026-10-17: ADR-0075 adds complete adult Japanese translations and a reading choice during creation and in
Settings. It supersedes the earlier small vocabulary switch while preserving this coverage and template pipeline.

## Context

The player's daughters are meant to play the town in Japanese, and the player asked for it to be "completely
accessible". The overlay test only knew the strings it was told about, and much of what the town shows was made at
run time: advice filled in from a case, starter code, the labels of the Builder, names the player's code is handed.

## Decision

- **One list of everything the town shows.** `OverworldStrings.shown()` collects it, each with its source:
  - the literals of `Text.t` and `Text.f` in the overworld's scripts;
  - the boots' messages;
  - the prose of talk, townsfolk, maps, quests, tasks, items, tracks, places and things;
  - the creator's labels;
  - the comments of every starter.
  The coverage test reads this list, and `tools/overworld_missing.gd` writes what is missing as batches for the
  translators. A second test finds Japanese whose English the town no longer shows (stale).
- **Templates are translated before they are filled.** Advice such as "For {say}, ..." is looked up as written, then
  filled. A case's description (`say`) is translated as a noun phrase, so it fits inside the sentence around it.
- **Comments are translated, code never.** `CodeComments.localized` translates whole-line `# ` and `// ` comments in a
  starter, one by one, keeping the indent and the marker. A starter left untouched is recognised as the starter in
  either language, so it is never kept as the player's own code. Code the player has typed is theirs, and is kept as
  typed.
- **Words for the player's code.** Titles and place names the town hands to the player's functions are shown in the
  player's language.
- **One term table.** Many translators work at once, so one table names each term (ともしび村, しゅうりやさん,
  パーツ, かんすう...), and a consistency pass applies it.

## Consequences

- A new string the town shows fails the coverage test until it has Japanese: this is the point.
- The phases of the day and the full map's ground words are literals now, so they are counted.
