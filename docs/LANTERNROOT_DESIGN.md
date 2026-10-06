# Lanternroot: the town that is your program

A design, written on 2026-10-06 (ADR-0055). It replaces the Academy design. The first slice is built; everything after
section 4 is a proposal for the player to judge.

## 1. The idea in one line

A hamlet hangs in the roots below the surface station. Its lanterns went out when the old tinker left. You are the new
tinker, and **everything you write becomes part of the town**: each file a house, each passing letter a lantern, each
import a rope bridge. At night the Night Watch reruns every test you ever passed. If today's change broke yesterday's
code, a gremlin moves in.

## 2. What it teaches that a course cannot

| Real programming | In Lanternroot |
|---|---|
| A function is a named piece of work with inputs and an output | A letter asks for one function; examples are its spec |
| Tests are the specification, edges included | Examples are shown; the Night Watch's checks are named but not shown until they fail |
| Reuse: don't write it twice | Bramble's letter tells you to ask the bakery: `from bakery import loaves_for` builds a bridge |
| Modules and dependencies | The town *is* the dependency graph, drawn from your imports |
| Changing code others depend on | Change orders: Mabel's new oven changes `loaves_for`, and the market depends on it |
| Regression testing | The Night Watch reruns everything; a broken bridge darkens a lantern you lit days ago |
| Version control | Each night keeps yesterday's town; "last night's version" puts a file back |
| Debugging | Prints are captured per test; errors point at your file and line; advice names the usual mistake |
| Composition | The festival's letter needs no new idea, only three imports and the town you already built |

## 3. The loop

1. **Morning**: letters are pinned to your door (the side panel). Today's houses appear as faint plans in town.
2. **The workbench**: the letter, what to build (`bakery.py.loaves_for(guests)`), examples, the names of the checks,
   a three-rung hint ladder (nudge, concept, plan; never the answer). The file opens with a starter stub.
3. **Run the tests**: one sandbox run. Each row says what it gave back, what it printed, and one sentence of advice
   for a failure ("It printed the answer but gave back nothing. Printing shows a value; return hands it back.").
4. **The lantern is lit**: a short note on the idea just used, then back to town to see it glow.
5. **Night**: ring the bell. The watch's light walks house to house; lanterns hold or go dark. Dawn reports what
   broke, by name and failing call. The next day comes when today is answered and no gremlin is left.

## 4. The first slice (built)

| Day | Letters | Ideas |
|---|---|---|
| 1 First Light | Wick's oil, Mabel's loaves, Quill's greeting | functions and `return`; rounding up; strings exactly |
| 2 Bridges | Quill's postage, Bramble's basket, a week of bread | `if/elif/else` and boundaries; loops and accumulators; **imports** |
| 3 The Mill Wakes | Tamsin's sacks, **the new oven (a change)**, Wick's rota | dictionaries; default parameters and **regressions**; `%` |
| 4 The Lantern Festival | the festival plan | composing three modules into one result |

Python and JavaScript, English and Japanese, a town per language. Code: `game/core/lanternroot/` (rules, layout,
advice), `game/sandbox/lanternroot/` (the watch), `game/scenes/lanternroot/` (town, workbench), content in
`game/content/packs/core/lanternroot/`. Screenshots: `ROOTWARD_LANTERN=<moment> scripts/screenshot.sh
res://tools/lanternroot_shot.tscn shots/lantern.png 20`.

## 5. Going further (proposals)

### 5.1 Villages deeper in the roots
Each village is a tier, with its own look and its own kind of Night Watch:

- **Lanternroot** (built): functions, conditions, loops, modules, tests.
- **Mosslight**: data structures. Letters ask for stacks, queues, sets, a tiny inventory with classes; the town's
  houses grow rooms (a class's methods).
- **Emberdeep**: algorithms, measured. The Night Watch also runs **travelling merchants**: big inputs with a work
  budget (the loop counters ADR-0015 already has). A lantern that passes but is too slow *flickers*; the dawn report
  draws your work against n beside the reference's.
- **Gearhollow**: craft. Refactoring letters ("change nothing it does, make it readable") with tests as the safety
  net; a tokenizer and a calculator language; error handling.
- **The Root Core**: build systems: a bytecode VM, a tiny Lisp, a mini git, each a district of houses over many days.

### 5.2 Weather: tests you did not write
- **Storms** are property-based tests: the Night Watch throws seeded random inputs (from `Rng`) at a function. When a
  storm finds an input that breaks it, that input is **pinned to the house as a new permanent check**, the way a bug
  report becomes a regression test.
- **Fog** hides the examples: a letter gives only prose, and you write your own tests first (the town accepts them
  when they catch the reference's planted bug).

### 5.3 The almanac (version control)
Every night is a commit. The almanac lists them with a diff per house; "put back" becomes revert; later, a
**renovation** is a branch: try a rewrite of a house while the town keeps running yesterday's, and merge it in the
morning only if the Night Watch agrees.

### 5.4 Villagers who write code
Later letters come with code a villager wrote themselves ("I tried, but the sacks keep vanishing"): a traceback, a
bug to find, a test to add so it never comes back. A visiting tinker leaves **review comments** on your houses
(style rules: `range(len(x))`, a mutable default, `==` in JavaScript), which you can accept or argue with.

### 5.5 The town runs
Once a village is fully lit, a **festival day** plays it: villagers walk the bridges and actually call your functions
with the day's data (Bramble's market orders bread through your `bread_order`, the post office stamps letters through
your `postage`), drawn as an animation of a real run. Your program, visibly alive.

### 5.6 Pip's lanterns (for the youngest)
For the player's daughters: the same town, Japanese first, with letters answered by arranging lines (Parsons
puzzles) before typing them, generous hints, and no gremlins until they want them.

## 6. Rules that hold

- Real execution or nothing: every lantern is a passing sandbox run.
- Hints, not answers; reference solutions are content for the validator, never shown as the answer.
- Nothing here changes Shardrun or Spellforge power. Rewards are the town itself.
- New letters are data: `requests/<id>.jsonc` and four code files; the tests prove every solution passes and every
  starter fails (`game/test/sandbox/lantern_watch_test.gd`).
