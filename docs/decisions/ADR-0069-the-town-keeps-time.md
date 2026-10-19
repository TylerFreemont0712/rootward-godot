# ADR-0069: chapter 3, the town keeps time

Accepted 2026-10-16. Builds on ADR-0068 (the parts of the game the player builds). The design is
`Concept/v0.4/05-chapter-3.md`.

## Context

The player asked for "as many tests and lessons as you can" for a chapter 3. Chapter 2 gave Lanternroot its parts
(the menu, the bag, the map, the clock). Chapter 3 makes the town come alive by the player's code: Hotaru's glow, the
weather, everyone's hours, a shop with coins, a tidy bag, and the history of every part. Three of its lessons are
about programming itself rather than a feature: writing tests (Brisk's drills), reading code (Morrow's stones) and
pure functions (Brannoc's forge).

## Decision

- **Days follow the clock, and the weather follows the days.** `state.day` grows by one at midnight, and only once
  the clock is built (before it, there are no days, and the sky is always fair). The weather of a day is the player's
  `weather(day % 28)`, from a table. Rain is a layer over the town and under every panel, and a cloudy or rainy day
  greys the tint a little.
- **Fern's "wait for the rain".** The weather quest ends when rain is seen. The player's week has rain at least once
  in seven days (the judge's rule), but a town day is 24 minutes of play. So Fern offers to wait: the town sleeps to
  the morning of the next day the player's own `weather()` says rains. It is still their code that decides the day.
- **People keep the player's hours.** `schedules.jsonc` gives seven townsfolk a home, work and inn spot. When the
  clock's hour changes, each goes where the player's `where(person, hour)` says. "Work" is where the map puts them,
  so a town without the part looks as it always did. A spot the player stands on waits an hour.
- **Purity is read, not trusted.** The harness can hand back the arguments as the function left them (`args_after`),
  so the forge judge sees a `.sort()` that changed its list (`changed-input`).
- **Writing tests is judged by running them.** Brisk's drills are the player's `[input, expected]` pairs. The judge
  checks each expected against the right function, then runs Brisk's buggy one on them: a drill set that never fails
  catches nothing (`no-catch`).
- **Coins are counted twice.** The player's `price()` and `can_buy()` decide in Nym's shop. The town still counts the
  coins itself and never lets them go below zero, as the bag's answers are checked again (ADR-0068).
- **A task keeps its last five passing programs** (`versions`, oldest first), so Vell's history compares the last two
  with the player's own `changed()`.
- **Beats in OR.** Hotaru's beats are rows of [condition, talk, told flag]. Rows that share a told flag act as one
  beat: whichever holds first fires, once. This lets the glow request come after Orin's opening, or after Pip's or
  Brisk's first success for a player who went there first. Conditions themselves stay without an "any".

## Consequences

- Eleven quests (14 to 24), each a task with references, block answers and tests, and acceptance suites
  (`chapter3_acceptance_test`, `chapter3_town_test`).
- New content: `schedules.jsonc`, `shop.jsonc`, and three props (Pip's tally board, Nix's lockbox, Brisk's drill
  board).
- A save from before has `day` 0 and `coins` 0, and no versions until a part passes again.
