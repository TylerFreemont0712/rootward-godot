# ADR-0055: Lanternroot, the town that is your program

Accepted 2026-10-06. Supersedes the Academy design (`docs/ACADEMY_DESIGN.md`, removed) and the uncommitted Academy
concept board; the title's Academy button now opens Lanternroot.

## Context

The learning mode was planned as a course: lessons, exercises, a skill map. That teaches ideas one at a time, but
the player wants to become a better *programmer*, and the hard part of programming is not one function: it is a
program that keeps growing, where new code reuses old code, a change in one place breaks another, and tests are what
make change safe. A course of separate exercises never shows that. The player asked for something different from the
Shardrun and different from the Academy, built to teach.

## Decision

- **Lanternroot** is a separate mode on the title. A hamlet hangs in the roots below the surface station; its
  villagers send letters, and each letter asks for one function, with examples and the checks the Night Watch will
  add. The player writes it in real Python or JavaScript; the tests run in the sandbox.
- **The town is the program.** Every module is a house, every passing letter a lit lantern, every import between two
  of the player's modules a rope bridge. The picture is read from the code (`LanternLayout`, `LanternCode.imports`),
  never placed by hand, so the town is an honest dependency graph.
- **The Night Watch is the test suite.** Ringing the night bell reruns every standing test in town against the code
  as it is now. A lantern whose tests fail goes dark and a gremlin moves in; the next day comes only when today's
  letters are answered and no lantern is dark. Yesterday's files are kept, and a file can be put back.
- **Change orders** (`replaces`) ask for a change to a function already written. They share its lantern, and from then
  on their tests stand for it. Day 3's new oven is the first: forget the default parameter and the market, which
  imports the bakery, breaks that night. That is the lesson the mode exists for.
- **Content** lives in `packs/<pack>/lanternroot/`: `town.jsonc` (villagers, where houses stand, days) and
  `requests/<id>.jsonc` with `<id>.starter.py|js` and `<id>.solution.py|js` beside it. Tests are JSON values;
  whole numbers are made ints on load so Python sees `2`, not `2.0`.
- **One sandbox run per suite.** `LanternWatch` sends every module plus a harness (`watch.py`, `watch.js`) and the
  cases on standard input; the harness reports each case as it ends (value, prints captured per case, error kind and
  the player's own file and line). A case that never ends costs only its own letter: the watch restarts after it.
- **Each language has its own town**, saved in the profile's folder (`lanternroot-<language>.json`).
- The JavaScript launcher gains `process.stdout.flush()` and `process.stderr.flush()` so a harness stopped by the time
  limit has already handed over what it finished.
- Lanternroot never touches the Shardrun or Spellforge, their saves or their power.

## Consequences

- A first slice is playable: four days, ten letters (functions, rounding, strings, conditions, loops, imports, a
  dictionary, a change order, `%`, and a festival that composes the town), English and Japanese.
- The Academy's curriculum ideas (Pip's grid, improve reviews, spaced review) are not lost; `docs/LANTERNROOT_DESIGN.md`
  maps them onto villages deeper in the roots.
- New letters need no engine code; the validator tests prove every solution passes and every starter fails.
