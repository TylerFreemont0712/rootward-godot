# ADR-0068: the parts of the game the player builds

Accepted 2026-10-15. Builds on ADR-0061 (the overworld, the boots and the lessons) and ADR-0066 (the Studio). The
design is `Concept/v0.4/`.

## Context

The player asked for "more and more programming tasks", each one building a function of the game itself: the Esc
key, the menu, the save, the options, a volume slider, a soundtrack picker and an inventory. They wanted it to feel
like "creating the game from in the game", and asked for a small map, a richer quest tracker and a simpler character
select. The boots (ADR-0061) already showed the way: the town walks on the player's own `on_key`, made into a table
in one sandbox job. The lessons (save, lamps) each had their own rules, editor, harness and words, and a dozen more
built that way would be a dozen copies.

## Decision

- **Parts are tasks in content.** Each part of the game is a task, `overworld/tasks/<id>.jsonc`. A task is a function
  to write in stages, and each stage has:
  - its cases;
  - a judge;
  - three hints;
  - a flag;
  - optionally `unlocked_by`.
  The task also holds its starters, its glossary, and its Builder blocks, which are a cloze of the real lines (switches
  and choices) and never a second language. A new task needs no engine code unless it needs a new judge, which is one
  static function. Its format is `Concept/v0.4/02`.
- **One harness and one runner.** `tasks.py`, `tasks.js` and `TaskRun` call any function on any argument lists in one
  job.
  - Each call names its function, so checking stage *n* runs every earlier stage's cases too, and a later stage never
    breaks an earlier one.
  - A function not written yet is that call's problem (`no-function`), not the run's.
  - Code that changes its argument and returns nothing is read through `mutates`.
- **Tables, not calls.** The game asks a part's function about every input it could ever ask in one job, on a thread,
  and then reads the answers. The inputs are every key, every notch, every ground, every minute and every cell. Only
  the menu (when the town's offer changes), the bag (a pickup or a gift), the music box's titles and the credits are
  called live. Each live call is about 70 ms in Python and 11 ms in JavaScript, also on a thread.
- **The last passing program runs.** A part runs the program that last passed its checks (`Parts.program`).
  - Every answer is checked again before it is used: a bag that lost an apple, a loudness of 7 or an unknown colour is
    refused.
  - The stand-in answers instead, and Hotaru says once what went wrong (`PartsRuntime.problem`).
- **Never trapped.** Before the menu part, Esc opens Hotaru's pocket menu, with Save, Settings and the ways out. A pad's
  Start always opens the real menu once it is built. The title's settings panel is in every menu.
- **Facts beside flags.** Quests and talk may ask `{"has": item, "at_least": n}`. The engine counts the bag (the
  player's code never answers a condition) and puts the counts beside the flags as `bag:<item>`. Those facts are
  stripped before a save.
- **The lessons stay.** The boots, the save and the lamps keep their own editors. The Workbench lists them beside the
  parts.

## Consequences

- **The new chapter:**
  - Nine new quests (one in chapter 1, eight in chapter 2, "The Workshop Inside") and ten parts, with seventeen stages (fourteen functions).
  - Hotaru's pocket menu and the player's own menu, an Options page with a volume curve, a music box, a bag of sixteen
    items picked from the town, Pell's minimap and full map, Pip's progress bar, the town's clock with day and night,
    and the credits.
  - A Workbench that shows each part's running code.
- **The HUD:** the tracker shows the giver, a bar, the count and a direction to the step's pin.
- **The character select:** it lost its count boxes.
- **What every task is held to:** `TaskCheck`. The reference passes, the starter and the Builder's start do not, each
  block answer passes its stage, there are three hints a stage, and no player-facing text holds the reference's
  longest line.
- **Japanese** for the new strings waits for the player's word, as before, so the known locale-coverage failure grows.
- **Open:**
  - rewriting the boots and the lessons as tasks;
  - editing tasks in the Studio;
  - the bag's later stages (sort, use, a shop);
  - the night's lights beyond the lamps' glow.
