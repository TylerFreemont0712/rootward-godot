# ADR-0050: Issues, the program run's events

- Status: accepted
- Date: 2026-10-04
- Related: ADR-0049, ADR-0026 (the Mutator), `docs/ParadigmUpdate.md` B9

## Context

The player asked for events ("any other events you can think of"), several that read the player's own cards, with a
small stake for a wrong answer.

## Decision

- An **Issue** is a room (`issue`) that poses a problem on a tracker (title, number, labels) with two to four choices,
  each a list of effects (`IssueSchemas`, `ProgramIssues`). An effect that needs the player (which card, which paradigm,
  which focus, an answer) opens a *stage* and carries the remaining effects with it, so one small state machine runs all
  thirty issues (`packs/core/programs/issues/<id>.jsonc`). Deferred effects are plain data on the run: `pending` (in N
  rooms), `boons` (for N fights), `bounty` (the next fight).
- **Quizzes read the player's own deck and are never from a written key** (`ProgramQuiz`): the plan (card, volley) is
  pure and seeded; the session runs the plan's versions in the sandbox (`SpellRuns.quiz_runs`, so it is right in Python,
  JavaScript and C++) and the question is built from what came back. The Oracle's versions are the real card and the
  Mutator's mutants; a forum answer is the card or one mutation. A stake is a small cost stated up front; walking away
  is always free; the Rubber Duck relic waives every stake.
- A buggy forum answer is not a persistent mutant card (the deck holds ids): copying one costs Integrity instead.
- A room's own count: a pending effect set in an issue counts down once as the issue room is left, so its "in N rooms"
  starts one higher.

## Consequences

- Every choice of every issue is played to its end by `program_issues_test.gd`, with fake sandbox results; the real run
  of a quiz has not been shot on screen yet (handoff).
