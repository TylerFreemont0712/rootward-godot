# The Academy: a beginner-to-advanced programming course

A design, written on 2026-09-28 for the roadmap in `docs/ROADMAP.md`. "Academy" is a working name (ROADMAP,
decisions). Nothing here is decided until its ADR is accepted.

## 1. What it is, and what it is not

The Academy is a **separate journey on the title**, beside the Shardrun: lessons that take a beginner to an advanced
programmer, in Python and JavaScript, in English and Japanese. You learn by producing (predicting, tracing, fixing,
writing and improving real code) and every answer is graded by running it in the same sandbox the spells use.

- **Not a run.** No foes, no Integrity, no losing. Progress is evidence of skill, kept forever.
- **Not the Shardrun's progression.** Learning never makes Shardrun cards stronger (the old repo learned this the hard
  way: two power bars fight each other). Rewards are cosmetic, knowledge (the Library) and new things to do.
- **It absorbs the Verifier.** The Verifier's twelve code-reading lessons become the Academy's *Predict* exercises;
  its title tile becomes the Academy's.
- **Two audiences**: the player (an adult, self-taught, aiming to become a much better programmer) and their
  daughters (beginners, playing in Japanese). Pip's Path (section 8) is for the second.

## 2. What already exists to build on

| Piece | Where | Use |
|---|---|---|
| The sandbox (Python 3.14 and QuickJS, WASI, limits) | `game/sandbox/`, ADR-0002 | runs every answer |
| stdout grading | `sandbox/io_grader.gd` | programs that read input and print |
| Loop and call counting | the spell harness, ADR-0015 | measuring how much work a solution does |
| The code walkthrough | `ui/code/code_view.gd`, ADR-0015 | stepping through a worked example |
| The Verifier's course, trace board and stars | `core/verifier_course.gd`, `scenes/verifier/` | the Predict exercise, the first saves |
| Content as JSONC with code beside it, Japanese overlays | ADR-0004 | the lesson format |
| 17 Foundry challenges: prompt, starter, solution, visible and hidden tests, four-step hint ladder, explanation, in Python and JavaScript | `../ProgramMe/content/packs/core/challenges/foundry/` | the first Fix and Write exercises |
| A concept graph (12 shared nodes, 23 Python nodes, prerequisites) | `../ProgramMe/content/packs/core/skills/` | the Root Map |
| Pedagogy notes: learning science, hint design, curriculum sequencing, puzzle formats, a bug taxonomy | `../ProgramMe/ideas/pedagogy/`, `ideas/game-content/` | the rules below |

## 3. The shape of a lesson

A lesson is one idea, five to fifteen minutes, three to six exercises that hand over control step by step (PRIMM:
predict, run, investigate, modify, make), then an improvement step:

1. **Read** a short explanation (under 200 words) with one worked example you can step through: the walkthrough
   shows each line run and the variables changing.
2. **Predict** what a snippet prints, or a value mid-way (the Verifier's interaction).
3. **Investigate**: trace a table of variables, or spot the bug.
4. **Modify**: fix a buggy program, or complete a Parsons puzzle.
5. **Make**: write the function from a spec, against visible and hidden tests.
6. **Improve** (when it applies): make a working solution faster or cleaner (section 5).

A concept's first lesson always starts with reading and predicting; later lessons on the same concept may open with
the Make step (productive failure), with the reading kept one click away.

## 4. Exercise types

| Type | The player | Graded by | Built from |
|---|---|---|---|
| Walkthrough | steps through a worked example | not graded | the code walkthrough, plus a variables panel |
| Predict | picks a mid-way value, types the exact output | the real stdout | the Verifier |
| Trace | fills a table of variables, step by step | an instrumented run of the snippet | the Verifier's trace board, generalised |
| Parsons | drags shuffled lines (with distractors) into order and indentation | runs the result: any order that passes is right | new |
| Fill the blank | types the missing tokens | tests | new |
| Spot the bug | clicks the wrong line, picks the kind of bug | the recorded bug line; explanation shown | new |
| Fix | edits a buggy starter until the tests pass | visible and hidden tests | the Foundry challenges |
| Write | writes a function or program from a spec | visible, hidden and edge-case tests | the Foundry challenges |
| Improve | makes a working solution faster or cleaner | tests, then a measured work band or style rules | section 5 |
| Explain | chooses why code works, or its complexity | the choice; every option explained | new |
| Project | builds a program in stages over several sittings | tests per stage | old boss and project ideas |

Rules from the old pedagogy notes that hold for all of them: grading is deterministic; the explanation shows whether
you were right or wrong; a hint ladder (nudge, concept, plan, the one line that is wrong) never gives the whole answer;
reference solutions appear **only after you pass**; skipping is free and earns nothing. No timers for new material.

## 5. Grading, and "how to improve"

### 5.1 Grading

- **Programs** (read input, print output) are graded as the Foundry's were: stdout against expected, normalised.
- **Functions** get a new harness, in Python and JavaScript: it loads the player's file, calls the function for each
  case, compares the return value (deep equality, a float tolerance), and reports each case with its expected and
  actual values. Hidden cases report only their category ("empty input", "negative numbers", "a large input").
- **Friendly errors**: every traceback is mapped to the player's own line, and the common errors are explained in
  plain words with the concept they belong to (`NameError`, `IndexError`, `TypeError`, `KeyError`,
  `RecursionError`, `ZeroDivisionError`; `ReferenceError`, "cannot read properties of undefined").

### 5.2 The improvement review

After a pass, a review panel says how the solution could be better. This is the "ideas of how to improve", and it is
where the sandbox makes the Academy unlike a quiz:

1. **Correctness**: which tests passed; the hidden categories.
2. **Speed, measured**: the harness runs the solution on growing inputs (n = 10, 100, 1000) and counts its loop rounds
   and calls (ADR-0015's counters). The panel draws your work against n beside the reference's and names the growth:
   "about O(n²): the `in` inside your loop scans the list every time; a set makes that check O(1)". An Improve
   exercise can require a band ("at most 3,000 operations at n = 1000").
3. **Style**: up to three findings from rules, each with a before and after and the concept it belongs to. Python's
   own `ast` module runs inside the sandbox, so no host Python is needed; JavaScript uses a small parser bundled into
   the sandbox. Starter rules: `range(len(x))` where `enumerate` reads better, `== True`, a mutable default argument,
   a list used for membership in a loop, string building with `+=` in a loop, a bare `except`, an unused variable, a
   function over 30 lines, a loop that could be a comprehension, JavaScript's `==` and `var`.
4. **Another way**: one or two reference solutions, annotated, shown now that you have your own.
5. **Next**: an Improve variant of this exercise if one exists, or the review queue's next item.
6. **Say it back** (optional, never graded): "in one sentence, why does your loop start at 1?", kept in the journal.

### 5.3 The coach

Across exercises the Academy keeps a small learner model (locally, never sent anywhere): the error kinds you hit
(off-by-one, empty input, aliasing, a missing base case; the old bug taxonomy has sixty), the concepts rotting, the
exercises that needed the most hints. The coach page turns it into three suggestions: "you have hit off-by-one four
times this week: try the Boundaries drill", "Dictionaries is due for review", "next: Sliding Window".

## 6. Progression

- **The Root Map.** The concept graph drawn as roots growing down from the surface: tracks are the big roots, units
  their branches, concepts their nodes. Learning is growing the roots deeper, which is what "Rootward" means. A node
  glows by mastery, dims when it needs review, and opens when its prerequisites are met.
- **Mastery 0 to 5 per concept**, from evidence: an unaided first-try pass counts most, a pass after hints less, a
  review passed days later most of all. Shared concepts (iteration, recursion) take the best of their Python and
  JavaScript nodes, so switching language does not start over.
- **Stars per lesson** (1 to 3: passed, first try, no hints), as the Verifier has them now.
- **Your version.** Your rank is a semantic version: a patch for each exercise, a minor for each lesson, a major for
  each tier. "Maintainer v1.4.2" means Apprentice done, well into the next tier.
- **Daily maintenance** (spaced review): a short queue (about five minutes) of small items (a predict, a fix, a
  Parsons) for the concepts that are due, at growing intervals (1, 3, 7, 16, 35 days). A gentle streak counts days,
  and missing one costs nothing.
- **Rewards**: cosmetics for both journeys (outfits, card backs and frames for the Shardrun, portrait frames, titles),
  Library entries, and new things to do: projects, tracks, and at the algorithms tier the **Card Workshop** (write your
  own Shardrun card, prove it with worked examples, play it in sandbox runs).
- **The journal**: every accepted solution, kept, so you can put your first attempt at a problem beside your latest.
- **Achievements for learning behaviour**, not grind: "fixed your own bug without a hint", "O(n) where most write
  O(n²)", "a week of maintenance".

## 7. The curriculum

Python leads and JavaScript follows the same concepts in its own idioms. Counts are targets.

**Tier 0, Apprentice: foundations** (about 48 lessons)
F1 first programs (print, values, types, arithmetic, int and float division) · F2 variables (assignment, rebinding,
`=` against `==`) · F3 strings (indexing, slicing, methods, formatting, immutability) · F4 decisions (comparisons,
boolean logic, if/elif/else, guard clauses) · F5 loops (for and range's exclusive end, while, break and continue,
accumulators, off-by-one) · F6 lists (indexing, append, slices, iteration, aliasing and copying, changing a list while
looping over it) · F7 functions (def, parameters, return against print, scope, pure functions) · F8 dictionaries
(lookup, get, counting, grouping) · F9 errors and edge cases (exceptions, try/except, empty input, validation) ·
F10 capstone: the Ledger (the ported Foundry challenges: running totals, grade ladders, tallies).

**Tier 1, Journeyman: programs** (about 40)
tuples and sets · comprehensions · files and JSON (files the sandbox hands the program) · modules · classes and
objects · dataclasses and dunder methods · iterators and generators · recursion · testing (write your own asserts,
then a small test runner) · debugging drills (read a traceback, bisect with prints). Capstones: an inventory keeper
with save and load; a text adventure engine driven by data.

**Tier 2, Adept: data structures and algorithms** (about 50)
complexity by measurement · two pointers · sliding window · hash maps and sets · stacks and queues · sorting (bubble,
insertion, merge, quick) · binary search · linked lists · trees and binary search trees · heaps · graphs (BFS, DFS,
shortest paths) · greedy · dynamic programming. Each unit links to the Shardrun card that runs its algorithm (Merge
Sort, Binary Execute, Knapsack Strike), and each card's detail links back. Capstones: a maze runner (BFS); a task
scheduler (heaps).

**Tier 3, Expert: craft** (about 30)
refactoring with tests as the net · naming and design principles (single responsibility, DRY, KISS) · a few patterns
(strategy, observer, state machine) · error-handling strategies · performance by measurement · async in JavaScript
(promises, the event loop) · regular expressions and parsing. Capstones: a calculator language (tokeniser, parser,
evaluator); a regex engine.

**Tier 4, Master: build systems** (projects over several sittings)
a bytecode VM · a small Lisp · a mini git (content-addressed objects, commits, log) · a key-value store with a log.

The sandbox has no network and no files beyond what a job is given, so the shell, SQL, the web and containers stay
out until a runner for them exists (SQLite compiled to WebAssembly would be the first candidate). Checked on
2026-09-28: `ast`, `hashlib` (git's empty-blob hash comes out right), `json`, `re`, `heapq` and `dataclasses` import in
the sandbox's Python; `sqlite3` does not.

## 8. Pip's Path (young players, Japanese first)

For the player's daughters, and anyone starting from zero.

- **A world you can see**: Pip walks a small grid. The program calls `move()`, `turn_left()`, `pick()`; the sandbox
  runs it and records the moves; the stage animates Pip (the classic Karel idea). Goals are gems, doors, a maze.
- **Blocks before typing**: Parsons puzzles and fill-the-blanks first, then tiny programs typed in full.
- **The first ideas in order**: sequence, repetition (loops), choice (if), naming things (functions like `jump()`),
  counting (variables). Then the bridge into F1 of the Foundations.
- **Japanese from the start**: every interface string and lesson in Japanese, the code itself in English as it will
  always be. Kanji with furigana or hiragana only, depending on the readers' age (a decision for the player).
- **No failure states**: every attempt can be retried; hints are generous and never the answer; Acorn, the ward
  sprite, cheers.

## 9. Content format and its checks

```
game/content/packs/core/academy/
  tracks.jsonc                     tracks, units, lesson order
  concepts.jsonc                   concept nodes: id, name, prerequisites, summary, error kinds
  lessons/<unit>/<lesson-id>/
    lesson.jsonc                   title, concepts, the reading, the exercises and their data
    <exercise>.starter.py  .js     what the player starts from
    <exercise>.solution.py .js     reference solutions
    <exercise>.tests.jsonc         cases (visible, hidden, their categories), sizes for work bands
  locales/ja/academy/*.jsonc       Japanese, keyed by the English (ADR-0004)
```

`scripts/validate.sh` proves every lesson, so an agent can author lessons quickly and the sandbox keeps them honest:

- every reference solution passes every case, in both languages;
- every Fix and Write starter fails at least one case (nothing arrives already solved);
- every Improve starter is outside its band and its solution inside;
- every Predict answer is the real stdout, and every Parsons arrangement that is accepted passes;
- `scripts/locale.sh ja` counts untranslated lesson text.

The ports: the Verifier's twelve lessons (with Python versions added), the Foundry's seventeen challenges (hints and
explanations included), the concept graph.

## 10. Screens

- **The hub**: the Root Map; *Continue*; the day's maintenance ("4 due"); your version and streak; the coach.
- **A lesson**: the reading pane with the runnable example, the exercise panel, the editor (Godot's `CodeEdit`, with
  the game's code colours, line numbers, auto-indent and bracket matching), the console and the test results below.
- **The review panel** after a pass (section 5.2).
- **The profile**: mastery by concept, the journal, achievements.

## 11. An AI tutor, optional and later

A local model (through Ollama or any compatible server, configured by the player) could give Socratic hints inside the
ladder, review a solution's style in words, and explain an error in the player's own terms. It must never go past the
ladder's level, never solve the exercise, and never be needed: every feature above works without it. Off by default,
local by default, no telemetry. Whether it belongs in the game at all is the player's decision.

## 12. Knowing whether it teaches

- **Play-testing with the daughters**: watch where they stop reading, what they click, where they stall; ask them the
  next day to explain one idea.
- **Local numbers per exercise** (never sent anywhere): attempts, hints used, time. An exercise where most players
  need the third hint is too hard or missing a step, and the report says which.
- **Delayed checks**: the maintenance queue is also the test of whether a lesson stuck.

## 13. The order to build it in

1. **Foundation**: the journey, the lesson format and its checks, the function harness, the editor with friendly
   errors, saves and stars, the Verifier's lessons moved in, the Foundry's challenges ported, the first unit complete
   in both languages; all Academy text translatable from the first line.
2. **Progression and improvement**: the Root Map, mastery, your version, daily maintenance, the review panel (measured
   work, style rules, reference solutions), the coach; the Foundations tier complete.
3. **Pip's Path**: the grid world, Parsons first, Japanese throughout; play-tested with the daughters.
4. **The Programs tier**, with its capstones.
5. **The algorithms tier**, with the links to the Shardrun's cards and the Card Workshop.
6. **Craft and Build tiers**, projects; the optional tutor if wanted.
