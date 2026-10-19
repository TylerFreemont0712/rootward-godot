# Academy · three doors, one learning journey

This mockup turns the title screen's Academy button into a selectable concept board. It is a separate learning mode;
opening it does not start or change a Shardrun. The three choices change how lessons are presented, while sharing one
skill map and one progression system.

The screen is a first pass at the direction, not a promise that every course shown is already playable. The deeper
curriculum and lesson-system proposal remains in [`docs/ACADEMY_DESIGN.md`](../../../docs/ACADEMY_DESIGN.md).

## The three entry routes

| Route | Learner | First lesson | What it grows into |
|---|---|---|---|
| **First Steps** | Complete beginner; no typing or programming terms assumed | Arrange MOVE / PICK blocks to guide Pip to a gem; then replace repeated moves with a loop | Choice, named actions, variables, and a gradual bridge from blocks to Python |
| **Guided Foundations** | New programmer who wants a clear sequence and help close by | Predict and trace a short running-total program, then repair it and write a similar one | Python or JavaScript foundations, taught with worked examples, friendly errors, and optional hints |
| **Grow as a Programmer** | Learner with some experience, or someone aiming for more depth | Optional self-check, then skip familiar concepts and build a tested request handler | Debugging, tests, algorithms, projects, measured improvement, and specialist tracks |

These are not permanent difficulty settings. A learner can switch routes at any time. Pip's visual path must start with
programming ideas that are visible on screen; it should not assume the learner already knows Shardrun's cards, bolts,
or complexity labels.

## A lesson, step by step

1. Pick a short lesson or accept the next suggestion (usually 5–10 minutes).
2. Read or see one idea in a small worked example.
3. Predict what will happen before running it.
4. Trace the values or actions as they change.
5. Assemble or fix a solution with as much hint support as needed.
6. Write a small solution against clear tests.
7. See why it passed, keep the solution in a journal, and grow the matching skill node.
8. Later, answer a short review to show the idea stuck; continue, explore a project, or review another skill.

Retries are free and new lessons have no timer. Hints explain the next idea without giving away the full solution.
Passing a problem and recalling it later matter more than speed or grinding.

## Shared progression

The Root Map is a visible path of skills. Each concept has prerequisites and evidence of mastery; the selected route
changes the exercises, not which skills the learner can reach.

| Stage | Example skills | Shardrun bridge |
|---|---|---|
| **Foundations** | Sequence, values, input/output, choices, loops, functions, debugging | Pip and Acorn; Kurogane for branches and guard clauses |
| **Core Coding** | Lists and dictionaries, decomposition, files and JSON, exceptions, tests | Kurogane for defensive control flow |
| **Data & Algorithms** | Complexity by measurement, search, sorting, hash maps, trees, graphs, greedy and dynamic programming | Vesper and the five algorithm paradigms; Nyra for trees; Sai for graphs |
| **Systems & Engineering** | Memory, parsing, asynchronous work, concurrency, larger tested projects | Ari, Aster, Oren, and Lys |
| **Specialties** | Sec Ops, AI Engineering, Red Teaming, and later focused tracks | Kurogane anchors security; Sai and Oren connect to graph search and async pipelines |

The initial view should show only a few next steps clearly. Later branches can be visible as previews, labelled as future
content until lessons exist. A semi-open campus or Rootwood could later skin this same map, but the learner should
always be able to see the next lesson and its prerequisites.

## Specialization examples

- **Sec Ops:** after conditionals, functions, exceptions, and tests, build a local request handler. Validate missing
  or oversized inputs, order guard rules, log decisions, and add a regression test.
- **AI Engineering:** after Python, collections, JSON, and tests, clean a small dataset, separate training from test
  examples, measure a simple ranker, and spot overfitting or data leakage. Use deterministic toy data and models so a
  lesson works offline.
- **Red Teaming:** after secure coding and Sec Ops foundations, inspect a contained toy program, reproduce an input
  validation or authorization bug, patch it, then add regression or fuzz cases. Keep every exercise local and focused
  on finding and fixing weaknesses.

Specialty nodes can be previewed early, but full tracks open after their foundations. Shardrun characters act as
optional mentors and transfer challenges, not prerequisites for understanding a lesson.

## Connection to Shardrun

Academy lessons can link to relevant character pages and card examples. Shardrun card detail can link back to the
lesson that explains its algorithm. For the first mockup, the bridge labels are:

- **Pip & Acorn / Pocket Shardrunner:** blocks and first programming patterns.
- **Kurogane / Ward Duelist:** conditionals, guard clauses, exceptions, and defensive programming.
- **Vesper / Artificer:** data, search, sorting, greedy strategies, dynamic programming, and complexity.
- **Sai / Storm Cartographer:** graphs and traversal.
- **Nyra / Thorn Compiler:** trees, recursion, and parsing.
- **Oren / Ember Alchemist:** asynchronous work and event loops.
- **Ari / Rootglass Lancer:** memory and pointers.
- **Lys / Star-Thread Witch:** concurrency and race conditions.
- **Aster / Comet Scribe:** strings, regular expressions, and parsing.

Keep Academy mastery separate from combat power. Good rewards are skill stamps, a solution journal, titles, portraits,
card backs, and Library entries. They can make learning visible in Shardrun without making lessons mandatory or
turning education into a combat-stat grind.

## What this mockup is testing

- Does a complete beginner immediately see a way to start without knowing code?
- Does the guided route make the first real code exercise feel small and understandable?
- Does the experienced route feel useful without forcing a beginner through a placement test?
- Does one shared progression make it easy to change learning style without starting over?
- Do Shardrun class links make algorithms memorable without filling the first lesson with game jargon?

The largest scope risk is building a full explorable campus before the lesson sequence works. A good next prototype
after this concept is one Pip block puzzle, one guided trace-and-fix lesson, and one Shardrun bridge exercise.
