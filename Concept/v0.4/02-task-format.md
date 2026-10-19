# v0.4: the task format and the engine's interfaces

The exact shapes behind `01-the-game-you-build.md`. Task workers write content in this format, and UI workers code
against these interfaces. The conductor builds the engine first (section 9 lists what exists when).

Indices are 0-based in code and data. The screen shows stages counted from 1.

## 1. A task's file: `game/content/packs/core/overworld/tasks/<id>.jsonc`

```jsonc
// The volume knob (Concept/v0.4/01, 5.4): the player's volume(slider) turns the Options page's notches into loudness.
{
  "id": "volume",                       // the file's name, and the part's id (Parts.IDS)
  "name": "The Volume Knob",            // the part's name: Workbench card, banner ("NEW PART · The Volume Knob")
  "title": "Turn it up",                // the editor's heading
  "giver": "summoner",                  // a townsfolk id: their portrait in the editor and on the Workbench card
  "built_line": "The Options sliders follow your volume() now.",   // what the part does, once built (banner, card)
  "entry": {"python": "volume", "javascript": "volume"},          // the function each stage calls, unless it says
  "params": [                           // what the function gets (the Hints column, "What your function gets")
    {"name": "slider", "meaning": "A whole number: 0 is the slider all the way down, 10 all the way up.", "example": "7"}
  ],
  "gives": {"meaning": "How loud, from 0.0 (silent) to 1.0 (full).", "example": "0.25"},
  "words": {                            // the language's words the task needs, each with an example about something else
    "python": [{"term": "/", "meaning": "Divides one number by another, and can give a fraction.", "example": "slices = 12 / 4"}],
    "javascript": [{"term": "/", "meaning": "Divides one number by another, and can give a fraction.", "example": "const slices = 12 / 4;"}]
  },
  "starter": {"python": "volume.starter.py", "javascript": "volume.starter.js"},   // files beside this one
  "blocks": { },                        // section 3
  "stages": [                           // section 2; at least one
    { }
  ],
  "advice": {                           // optional: what Hotaru (or the giver) says for a reason code, section 4
    "goes-down": "Notch {arg0} is quieter than the notch before it. Should turning a knob up make it quieter?"
  }
}
```

**Rules for the file:**

- The prose fields are content prose, written in English (translated later through the pack's locales): `name`,
  `title`, `built_line`, `meaning`, a case's `say`, `goal`, `hints` and `advice`.
- Code fields are never translated: `term`, `example`, `entry`, the starter files and the block lines.
- **Hints, not answers.** No example, starter, hint or advice may contain the line that solves the stage. The content
  test checks that crudely: the longest line of the reference program must appear nowhere in them.

## 2. A stage

```jsonc
{
  "flag": "volume-built",               // set when this stage passes; unique across all tasks
  "goal": "Turn each notch into a loudness: notch 0 is silent, notch 10 is full.",   // the editor's goal line
  "unlocked_by": {"flag": "options-built"},   // optional: a quests condition; stage 1 usually has none
  "entry": {"python": "volume", "javascript": "volume"},   // optional: overrides the task's
  "params": [ ], "gives": { }, "words": { },               // optional: override the glossary for this stage
  "mutates": -1,                        // optional: which argument holds the answer when the function returns nothing
  "judge": "volume_curve",              // optional: "equals" when left out; or a TaskJudges name (section 5)
  "cases": [
    {"args": [0], "want": 0.0, "say": "the slider all the way down"},
    {"args": [5], "say": "halfway"},
    {"args": [10], "want": 1.0, "say": "all the way up", "edge": true}
  ],
  "hints": [                            // three or more, each a step closer, none the answer
    "A notch is a number from 0 to 10. A loudness is a number from 0 to 1. How do you get from one to the other?",
    "Try notch 10: what would you do to 10 to get 1?",
    "Dividing is one way to make a big number small."
  ]
}
```

**What each field means:**

- **`args`** is the list of arguments, in order. It is sent through `JsJson`, so whole numbers arrive as whole
  numbers (Python `int`).
- **`want`** is optional. The `equals` judge compares deeply: numbers within 1e-6 (`5` equals `5.0`), lists in order,
  and dictionaries by key.
- **`any`** is optional: a list of answers that are all fine (`"any": [66, 67]`).
- **`say`** is what the case is, in words. The results list shows it.
- **`edge`** marks an edge case (the empty list, a boundary minute). When the only failing cases are edges, the advice
  reason is `edge`.
- A judge may read extra fields of its own (section 5).
- **`mutates`** handles a function that returns nothing (`None`, or `undefined`): the answer is then the argument at
  that index, as the function left it. The bag uses `"mutates": 0`, and -1 means not used.

**How a stage is checked:**

- Checking stage *n* runs the cases of stages 0 to *n*, each with its own stage's entry, judge and `mutates`. A later
  stage must not break an earlier one.
- The record keeps `passed`, the number of stages that passed: passing stage *n* sets `passed = max(passed, n + 1)`.
- **Unlocking:** a stage whose `unlocked_by` does not hold is not opened. The Workbench says it waits, and names the
  giver of the quest that unlocks it, from the quests.

## 3. Builder blocks: the real lines, with choices and switches

```jsonc
"blocks": {
  "lines": {
    "python": [
      "def volume(slider):",
      "[low]    slider = max(slider, {lowest})",
      "[high]    slider = min(slider, {highest})",
      "    return slider {op} {n}"
    ],
    "javascript": [
      "function volume(slider) {",
      "[low]  slider = Math.max(slider, {lowest});",
      "[high]  slider = Math.min(slider, {highest});",
      "  return slider {op} {n};",
      "}"
    ]
  },
  "slots": {
    "op": {"label": "do what", "choices": ["/", "*", "+", "-"], "stage": 0},
    "n": {"label": "by", "choices": ["10", "100", "2"]},
    "lowest": {"label": "lowest", "choices": ["0", "-1", "10"], "stage": 1},
    "highest": {"label": "highest", "choices": ["10", "1", "100"], "stage": 1}
  },
  "toggles": {
    "low": {"label": "Not below the bottom", "stage": 1},
    "high": {"label": "Not above the top", "stage": 1}
  },
  "start": {"slots": {"op": 1, "n": 2}, "toggles": []}
}
```

**How the lines read:**

- A line is the code exactly as it is written, indentation included.
- A line that starts with `[id]` is there only while toggle `id` is on. The `[id]` is taken off, and the rest of the
  line, its indentation included, is kept.
- `{slot}` is replaced by the chosen choice's code. A line may hold several slots, and a slot may appear on several
  lines (it then has the same choice everywhere).

**The choices:**

- A choice is a string (the same code in both languages), or `{"label": "true", "python": "True", "javascript":
  "true"}`.
- **`stage`** is the first stage at which the Builder sees a slot or toggle; it defaults to 0. Before that stage, a
  toggle is off and a slot keeps its `start` choice. Both are hidden.
- **`start`** is the blocks of a fresh record. It must fail stage 0 (the content test checks).

**What the Builder sees and keeps:**

- The record keeps the blocks as `{"slots": {id: index}, "toggles": [ids on]}`.
- `Tasks.source(task, blocks, language)` makes the code, which the Builder sees live beside the blocks and which runs
  like typed code.
- The Builder's screen shows the lines themselves:
  - A slot is a chip with a menu of its choices.
  - A toggle is a switch at the left of its lines, and those lines are dimmed while it is off.
  - It is a fill-in of the real program, never a different language.

## 4. Reasons and advice

**Problems with the whole run.** `Tasks.check` gives `{ok, problem, cases}`. `problem` is `{}`, or one of these
reasons, with `kind`, `message` and `line`:

- `broken`: the code cannot load.
- `timeout`
- `failed`

**Problems with one case.** Each case's verdict is `{ok, reason, ...}`:

- `error`: the case raised an error, with `kind`, `message` and `line`.
- `no-function`: the case's function is not in the program (for example, stage 2's before it is written).
- Otherwise, the judge's reason.

**The `equals` judge's reasons:**

- `nothing`: `None`, `null` or `undefined` where an answer was wanted.
- `wrong-type`
- `wrong-length`, with `want` and `got`, for two lists of different lengths.
- `wrong-item`, with `index`, `want` and `got`, for two lists that differ at an index.
- `not-any`: none of `any`.
- `wrong`, with `want` and `got`.

**What Hotaru says.** `Tasks.advice(task, stage, checked)` gives `{reason, words, case}`:

- **Which reason:** a problem's own reason first. Then `edge` when every failing case is an edge. Otherwise the reason
  of the first failing case, in order.
- **Which words:** the stage task's `advice[reason]` when there is one; otherwise the game's own words for a generic
  reason (`TaskWords`, which are `Text.t` literals).
- **Placeholders:**
  - `{say}`, `{got}` and `{want}`, each shown as the player wrote it: `"menu"`, `[1, 2]`, `None` or `null`.
  - `{line}`, `{kind}`, `{message}`, `{index}` and `{name}`.
  - `{arg0}`, `{arg1}` and so on.

## 5. Judges (`game/core/overworld/task_judges.gd`)

A judge is a static function over the whole stage:

```gdscript
## cases: the stage's cases (Dictionaries from content); results: one per case, {ok: true, value} or
## {ok: false, kind, message, line}. Returns one verdict per case, {ok, reason, ...details}.
static func volume_curve(cases: Array, results: Array) -> Array[Dictionary]
```

**How a judge plugs in:**

- `TaskJudges.judge(name, cases, results)` dispatches by name: `"equals"`, then each custom judge in a `match`.
- A case whose result has `ok: false` is judged `error` by `Tasks` before the judge is called, so a judge may treat
  `results[i].value` as the answer and skip failed ones.
- A judge that needs every answer at once (the volume curve, the map's colours) gives the verdict to the case that
  shows the problem, and `ok` to the rest.
- Every judge has tests for every reason it gives (`task_judges_test.gd`).

**The judges this slice needs:**

| Judge | Task | Reasons |
|---|---|---|
| `equals` | many | nothing, wrong-type, wrong-length, wrong-item, not-any, wrong |
| `shortcut` | shortcuts | wrong, unknown-panel, nothing (when `want` is given) |
| `menu_items` | menu | not-list, first, last, missing, twice, unknown |
| `options_rows` | options | not-list, not-row, unknown-setting, label-empty, label-long, twice, needs |
| `volume_curve` | volume 0 | not-number, silent-end, full-end, out, goes-down |
| `volume_clamp` | volume 1 | those of volume_curve, plus low-end and high-end |
| `bag_add` | bag 0 | not-list, not-stack, no-more, two-stacks, changed-other, bad-count |
| `bag_remove` | bag 1 | not-list, not-stack, no-less, zero-stack, changed-other, invented |
| `map_colours` | map 0 | not-colour, same-water, same-path, same-building |
| `place_of` | map 1 | wrong, not-text ("" and None/null both mean no place) |
| `progress` | progress | not-whole, fraction, wrong, zero |
| `next_track` | music 1 | wrong, no-wrap, not-whole |
| `clock_text` | clock 1 | not-text, no-zero, wrong |
| `credits` | credits | not-list, not-text, no-maker, missing-part, too-long |

**What each value means:**

- **Panels** (shortcut): `menu`, `bag`, `map`, `quests`, `workbench`, `options`, `music`.
- **Menu items:** `continue`, `quests`, `workbench`, `bag`, `map`, `music`, `options`, `save`, `settings`,
  `characters`, `title`, `credits`, `quit`.
- **Settings** (options): `music`, `sound`, `text_speed`, `track`, `fullscreen`. A label is 1 to 24 characters after
  `strip`.
- **Map colours,** with the palette colour each name draws as:

  | Name | Colour |
  |---|---|
  | green | `#62a050` |
  | dark green | `#3e6e40` |
  | light green | `#9ad06e` |
  | blue | `#4a78c6` |
  | light blue | `#86c0f0` |
  | brown | `#8e5c3c` |
  | tan | `#dcc092` |
  | grey | `#82808f` |
  | dark grey | `#57546a` |
  | white | `#fbf7ee` |
  | yellow | `#e2b448` |
  | orange | `#d97a3c` |
  | red | `#c84a4a` |
  | pink | `#d6749e` |
  | purple | `#8460b8` |
  | black | `#24212f` |

- **Grounds** (map 0): every terrain id in `terrain.jsonc`, plus `building`, `tree` and `thing`.
- **Shortcut keys** (table domain): `escape`, `c f g i j k l m n o p q r t u v y`, and `0` to `9`.
- **Reserved keys,** never asked or used: the arrows, `w a s d`, `space`, `enter`, `e z b x`, `tab` and `h`.

## 6. Running: the harness and `TaskRun`

The harness is one generic program per language, `game/sandbox/overworld/tasks.py` and `tasks.js`, beside
`lessons.py`. It is the lessons' harness made general.

**What it gets** (standard input, written with `JsJson.stringify`):

```json
{"source": "...",
 "calls": [{"entries": ["add"], "signature": "add(bag, item)", "args": [[], "apple"], "mutates": 0}, ...]}
```

**What it does with each call:**

1. Loads the source once.
2. For each call, finds the first callable name in `entries`.
3. Calls it with a deep copy of `args`.
4. If it returns `None` or `undefined` and `mutates >= 0`, takes `args[mutates]` as the answer.
5. Makes the answer plain, the same way `lessons.py` does (`plain`).

**What it gives back** is one line on standard output, `@@task@@ ` and then one of:

- `{"status": "ok", "results": [{"ok": true, "value": ...} | {"ok": false, "kind", "message", "line"}], "printed"}`
- `{"status": "broken", "kind", "message", "line", "printed"}`, when the code does not load. A missing entry is a
  per-call result `{"ok": false, "kind": "missing", "message": "there is no function add(bag, item)"}`, so a stage 1
  program can still pass stage 1 while stage 2's function does not exist yet.

`TaskRun` (`game/sandbox/overworld/task_run.gd`):

```gdscript
TaskRun.run(language, source, calls: Array, time_ms := 3000) -> Dictionary
# {status: "ok" | "broken" | "timeout" | "failed", kind, message, line, printed, results: [...]}, one result per call
TaskRun.check(task, stage, language, source) -> Dictionary
# Tasks.check over a run of Tasks.check_calls(task, stage, language): {ok, problem, cases, stage_ok}
TaskRun.table(task, stage, language, source, args_list: Array) -> Dictionary
# {ok, values: Array (null where a call failed), errors: [{index, kind, message, line}], problem}
```

A table run uses the stage's entry and `mutates`, with no wants. It is one job, however many calls (the boots' table
answers 17,920 calls in one).

## 7. The pure rules

`Tasks` (`game/core/overworld/tasks.gd`):

```gdscript
Tasks.stage_count(task) -> int
Tasks.stage(task, index) -> Dictionary
Tasks.entries(task, index, language) -> Array[String]  # JavaScript also takes the Python name
Tasks.signature(task, index, language) -> String       # "menu_items(built)" / "menuItems(built)"
Tasks.glossary(task, index) -> Dictionary              # {params, gives, words}: the stage's, else the task's
Tasks.check_calls(task, index, language) -> Array      # every case of stages 0..index, as harness calls
Tasks.check_cases(task, index) -> Array                # the same cases, each with "stage": i
Tasks.check(task, index, run) -> Dictionary            # {ok, problem, cases: [verdict], stage_ok: [bool]}
Tasks.advice(task, index, checked) -> Dictionary       # {reason, words, case}
Tasks.unlocked(task, index, flags) -> bool
Tasks.open_stage(task, record, flags) -> int           # first unpassed unlocked stage, else the last stage passed
Tasks.fresh_blocks(task) -> Dictionary
Tasks.source(task, blocks, language) -> String
Tasks.shown(value) -> String                           # a value as code shows it (Lessons.shown)
```

`Parts` (`game/core/overworld/parts.gd`):

```gdscript
const IDS: Array[String] = ["shortcuts", "menu", "options", "volume", "music", "bag", "map", "progress", "clock", "credits"]
const BUILT_BEFORE := {"boots": "all-ways", "save": "memory-written", "lamps": "lamps-lit"}
const SHORTCUT_KEYS, RESERVED_KEYS, PANELS, MENU_ITEMS, SETTINGS, MAP_COLOURS (name -> Color), GROUNDS_EXTRA
Parts.record(state, id) -> Dictionary          # state.tasks[id], or {}
Parts.passed(state, id) -> int                 # stages passed
Parts.built(state, id) -> bool                 # passed >= 1
Parts.with_record(state, id, record) -> Dictionary
Parts.menu_built(state) -> Array[String]       # what menu_items(built) gets now, in the town's order
Parts.facts(state) -> Dictionary               # the flags plus "bag:<item>": count (never saved)
Parts.domain(part, catalog, map) -> Array      # the args lists of a part's table (keys, notches, grounds, cells…)
```

A record in `state.tasks[id]`:

```json
{"language": "python", "mode": "blocks" | "code", "blocks": {"slots": {}, "toggles": []},
 "code": {"python": "...", "javascript": "..."}, "passed": 1, "source": "...", "source_language": "python",
 "items": ["continue", "..."]}
```

- **`source` and `source_language`:** the last program that passed, which the game runs.
- **`items`:** the menu part's last valid list.

`Bag` (`game/core/overworld/bag.gd`):

```gdscript
Bag.count(bag, item) -> int
Bag.counts(bag) -> Dictionary            # item -> count
Bag.valid_add(before, after, item) -> Dictionary   # TaskJudges' verdict for one live add
Bag.valid_remove(before, after, item) -> Dictionary
Bag.pickup_at(pickups, map_id, footprint: Rect2i) -> Dictionary   # the pickup under a prop, or {}
Bag.ripe(state, map_id, at: Vector2i, regrow: float) -> bool       # picked long enough ago (played seconds)
Bag.picked(state, map_id, at) -> Dictionary                        # state with the pick recorded
```

`Quests.holds` and `Talk.holds` learn `{"has": item, "at_least": n}`. It reads `flags["bag:" + item]`, which the
overworld puts in from `Parts.facts` before it asks. Saved flags never hold a `bag:` key.

## 8. The other content files (in `game/content/packs/core/overworld/`)

`items.jsonc`:

```jsonc
{
  "apple": {"name": "Apple", "about": "Crisp and red. Marta says they're best in pie.", "icon": "item-apple",
            "colour": "cloth_red"}
}
```

`pickups.jsonc`. Each map lists `at` cells, each one any cell of a prop's footprint. `regrow` is in seconds played, and
-1 means once only.

```jsonc
{"lanternroot": [{"at": [12, 30], "item": "apple", "regrow": 240}], "home": []}
```

`places.jsonc`. Each map lists named rectangles of cells; `w` and `h` are at least 1, and they lie inside the map.

```jsonc
{"lanternroot": [{"id": "home-hollow", "name": "Home Hollow", "x": 0, "y": 38, "w": 26, "h": 18}],
 "home": [{"id": "home", "name": "Home", "x": 0, "y": 0, "w": 11, "h": 8}]}
```

`tracks.jsonc`. The id is a music track in `game/assets/audio/`. `order` sorts the list the player's `titles` gets as
`{"id", "title", "place"}`.

```jsonc
{"music-lanternroot-town": {"title": "Lanternroot", "place": "the town", "order": 1}}
```

**Things on maps** may now say `"opens": "workbench" | "music" | "map"`. Space then opens that panel when its part is
built, and otherwise says the thing's `text`. The map schema learns it.

**Talk nodes** may now open more:

- `"open": "task:<id>"` opens the task's editor on `Tasks.open_stage`.
- `"open": "give:<item>:<n>"` runs `remove` *n* times (01, 5.6).
- `"open": "workbench"`, `"bag"`, `"map"` and `"music"` open those panels.
- `"open": "credits"` rolls the credits.

## 9. Test fixtures (never shown in the game)

- `game/test/fixtures/tasks/<id>.py` and `<id>.js`: a reference program that passes every stage of the task. They are
  plain code, the simplest a child could write, with no tricks.
- `game/test/fixtures/tasks/<id>.blocks.json`: `{"stages": [{"slots": {...}, "toggles": [...]}, ...]}`, a block answer
  that passes each stage.
- `tasks_content_test.gd` runs every task in both languages. Each of these must hold:
  - the reference passes every stage;
  - the starter fails stage 0;
  - `blocks.start` fails stage 0;
  - each block answer passes its stage;
  - flags are unique;
  - each stage has three hints or more;
  - the no-answers check of section 1.

## 10. The parts' runtime, for the UI (`game/scenes/overworld/parts_runtime.gd`)

```gdscript
class_name PartsRuntime extends Node
signal changed(part: String)           # a table or a live answer landed: redraw what shows it
signal problem(part: String, words: String)   # once per part per problem: Hotaru says it
func setup(catalog: Dictionary, state_of: Callable) -> void   # state_of() returns the overworld's state now
func refresh(part := "") -> void       # remake a part's tables (or every built part's) in the background
func has_tables(part: String) -> bool  # its tables are in
func shortcut(key: String) -> String   # "" for none, not built or not ready
func escape_opens_menu() -> bool
func menu_items() -> Array[String]     # the player's list (record.items), or the town's order
func options_rows() -> Array[Dictionary]   # [] when not built
func volume_at(notch: int) -> float    # -1.0 when not built
func volume_curve() -> PackedFloat32Array  # notches 0..10, for the chart; empty when not built
func map_colours() -> Dictionary       # ground -> Color (the stand-in greys when not built)
func place_at(map_id: String, cell: Vector2i) -> String   # "" when not built or none
func progress_of(done: int, total: int) -> int            # -1 when not built
func phase_at(minute: int) -> String   # "" when not built
func clock_text_at(minute: int) -> String   # "" when not built
func titles() -> Array[String]         # await: the player's titles of tracks.jsonc
func track_list() -> Array             # [{id, title, place}] in order: what titles() is given
func map_colour_names() -> Dictionary  # ground -> the colour's name the player gave (the full map's legend)
func menu_is_players() -> bool         # the menu's list is the player's own right now
func next_index(index: int, count: int) -> int   # -1 when not built
func bag_add(item: String) -> Dictionary         # await: {ok, bag, words}; validated, the state is not changed here
func bag_remove(item: String, count := 1) -> Dictionary   # await: {ok, bag, words}
func credits_lines(maker: String, part_names: Array[String]) -> Array[String]  # await
```

**The screens that read it:**

- **Asking:** every screen asks the runtime and is given its answers. None of them runs code.
- **The overworld owns the state,** and applies a bag or a menu list once the runtime says it is valid.
- **The widgets (UI workers):** each takes plain data and Callables in `setup(...)`, so it can be shot and tested with
  stubs before the runtime is wired.
