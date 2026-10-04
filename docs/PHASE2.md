# Phase 2: what Rootward does next

Written on 2026-10-04, at the player's request: *"go through the game and start hatching up a PHASE2.md … either a
new character (sec ops) adding a new language C++ or C# to shardrun, or getting academy started. Artificer really
isn't cutting it right now, and should be taken out of the Adventure menu … I'd like for it to be removed entirely to
make way for other features … Also use this to write down any bugs or things that could be improved upon that you see
before fixing them."* The player then corrected one word: *"I meant the verifier course in the academy, not the
artificer class."* So what goes is the **Verifier course**, from the Academy and from the game. The Artificer class
stays.

This file is a proposal. Nothing in it is decided until the player says so; section 7 lists the calls that are theirs.
`docs/PLAN.md` stays the live checklist: once a track below starts, it becomes a phase there with its own ADR (the next
number is **ADR-0045**; `docs/decisions/README.md` still says 0041, see P2-43).

## 1. Where the game stands (measured 2026-10-04)

| Area | Today |
|---|---|
| Tests | 405 cases in 62 suites, all green headless; `scripts/lint.sh` clean |
| Shardrun (program run) | 5 paradigms, 71 cards (139 records with `+` versions and refactors), 43 program relics, 4 layers, 16 guardians in pools of five, the speed race, the code walkthrough, magic circles built during the code |
| Hallway foes | the 12 creatures from Spellforge (weakness, resistance, a few traits); none of them reads your program |
| Spellforge, Card Shardrun | both still playable; Card Shardrun only for a run already underway |
| Classes | one, the Artificer (Vesper), and only as a label: no class exists in the rules or the run state; eight future classes listed but locked |
| Academy | a placeholder panel ("The workbench is taking shape") with one working button, "Open existing Verifier course" (12 JavaScript code-reading lessons, no test suite of its own) |
| Languages | Python (CPython 3.14) and JavaScript (QuickJS) under wasmtime |
| Japanese | all content; the title, Trial and Library; not the run screens |
| Open bugs | 30 of the 2026-10-01 audit's 33 still open or not yet rechecked, plus 15 found in this pass (section 6) |

Screenshots from this pass are in `shots/phase2/` (ignored by git): the title, Adventure, Academy, Character, Library,
the Verifier, a Spellforge fight, and a program run's map, fight, cast, volley, next turn, reward, cache, rest, forge,
code window and end.

## 2. The recommendation in one screen

Phase 2 has four tracks. In this order:

1. **A. Clear the ground** (1 to 2 sessions). Remove the Verifier course. Fix the high-priority bugs, with the preview
   first, because a preview that differs from the cast breaks the game's first rule. Put the interface's text through
   a translation catalogue before more screens are built on top of it.
2. **B. Kurogane, the sec-ops class** (3 to 4 sessions). The class frame, then the second class beside Vesper the
   Artificer, plus the rules primitives a defender needs: branches, `try`/`except`/`finally`, early return. Then his
   cards, art, spells and a balance report. `docs/prompt2.md` is already the brief.
3. **C. A third language: C++** (a 1-session spike, then 2 to 3 sessions if it passes). C# can't run in the sandbox
   today (section 4.2). C++ can, and it suits the game: the bestiary is already made of C and C++ bugs.
4. **D. The Academy's foundation** (2 to 3 sessions). The ROADMAP's stage 2, built fresh now that the Verifier is gone:
   a lesson screen with an editor, graded exercises, and units F1 and F2.

**Why B and C before D.** Kurogane's primitives (conditionals, early return, exceptions) are the same ideas the
Academy teaches first, so the Academy can borrow his worked examples and link to his cards. The C++ spike carries the
most risk, so it should be settled early, as Phase 1 did for the sandbox itself.

**If learning matters more right now, run D straight after A.** D depends on none of B or C. The daughters' Japanese
course depends only on A's translation slice. One cost of removing the Verifier first: until D lands, the Academy
has nothing playable in it, only its "in preparation" panel.

## 3. Track A: clear the ground

### A1. Remove the Verifier course (done 2026-10-04, ADR-0045)

Why: the player's call. It is a code-reading drill in its own look and its own save, it doesn't fit the Academy
`docs/ACADEMY_DESIGN.md` describes, and it holds the Academy's place without being its start. The Academy (track D)
is built fresh instead of absorbing it, as the design had planned.

Where it lives today:

- The scene and its parts: `game/scenes/verifier/` (`verifier.tscn`, `verifier_screen.gd`, `trace_board.gd`).
- The course rules and save: `game/core/verifier_course.gd`, which writes one global `user://verifier-course.json`.
- The content: `game/content/packs/core/verifier/course.jsonc` (12 lessons in three chapters).
- The glue: `Game.VERIFIER`, the `"verifier"` entry in `Game.PLAYSTYLES` and its branch in `Game.use`
  (`game/app/game.gd:12-15`, `:153`), the playstyles `Settings` accepts (`game/app/settings.gd:73`), and the title's
  checks for it (`game/scenes/title/title.gd:176`, `:219`).
- The Academy panel's "Open existing Verifier course" button (`game/scenes/title/title.gd:356`). The panel keeps its
  three plans and says the workbench is in preparation, with no button, until D.
- The replace-run warning, "Your Verifier course progress is saved separately" (`game/scenes/title/title.gd:654`).
- The menu walk that clicks into it: `game/tools/menu_navigation.gd:108-109`. No test suite covers the Verifier.
- Docs: ACADEMY_DESIGN sections 1, 2 and 4 and ROADMAP 3.2 and stage 2 say the Academy absorbs the Verifier. Correct
  them to "built fresh". PLAN.md's Phase 7 and Kernel Foundry items keep their history. ADR-0010 and ADR-0011 stay as
  written, and the new ADR records the removal.

Care points:

- A settings file saved with `playstyle: "verifier"` must load as `"program"` (a test for it).
- The player's `verifier-course.json` is their data. Leave it on disk and stop reading it, rather than deleting it.
- Removing it also closes P2-18 (its progress is shared between players) and P2-33 (its screen's look).
- Keep the parts worth reusing in git history, not in the tree: the trace board's step-through and the exact-output
  check are what D's Predict and Trace exercises need, and they can be rebuilt there from the commit before removal.

What changes for the player: the Academy shows only its "in preparation" panel until track D. Nothing else changes.

### A2. Keep both modes, and fix Spellforge

The player, 2026-10-04: *"Let's also not get rid of either Spellforge or Shardrun, they are two different modes for
two different reasons … just fix any obvious bugs from spellforge. Currently it hasn't been worked on in a while, so
fixing the UI for the map would be pretty important."* So nothing is retired (the Card Shardrun stays too), AGENT.md
no longer calls either mode the main one, and track A gains a Spellforge pass: its obvious bugs, the map's interface
first. The untracked probe files were deleted with A1.

### A3. Fix the high-priority bugs (section 6)

In this order, each with a failing test first:

1. P2-01, the preview skips faster foes. A shared `cast_resolution()` used by both `preview` and `cast`, so the two
   can't drift apart again. P2-02 and P2-07 come with it.
2. P2-04 and P2-05, overflow bypasses the guardians and counts shield as damage. P2-03, the shielded Thunk.
3. P2-06, dead cards still run their after-effects. P2-08, summons shift targets.
4. P2-11, keys act under menus. P2-12, P2-13, P2-15, saves.
5. P2-21, the sandbox output limit, because grading in the Academy will depend on it.

### A4. The interface through a catalogue

Every run-screen string goes through Godot's `TranslationServer` (ROADMAP stage 0), and the screens read the
translated catalog for display while the rules keep reading English (P2-24). Doing this now stops tracks B to D from
adding hundreds of new English-only strings. It is also what lets the daughters play a run in Japanese.

**Done when:** the Verifier is gone from the game and old settings still load, the A3 bugs have tests and are fixed,
a Japanese profile sees a fight, map and reward in Japanese, and `scripts/locale.sh ja --missing` covers the interface
as well as the content.

## 4. Track C first, briefly: which language

### 4.1 C++ (recommended)

Why C++ fits Rootward:

- The bestiary is C's and C++'s bugs: Dangling Pointer, Segfault Specter, Memory Leak Ooze, Null Wraith, Stack
  Overflow Serpent, Off-by-One Goblin. In C++ they are real things that can happen to your code.
- Godot itself is C++. Learning it means the player can read the engine they are building on.
- Defensive security in C++ is a real, teachable subject: bounds checks, `std::span`, RAII, smart pointers,
  `std::optional`. Kurogane's cards would read naturally in it.

How it runs (to be proven by the spike):

- **Toolchain:** wasi-sdk (clang with libc++ for `wasm32-wasip1`), pinned by SHA-256 in `scripts/fetch-sandbox.sh`
  next to CPython and QuickJS. The program it builds runs under the same wasmtime with the same limits.
- **No compiling during a turn.** Shardrun cards are content, not typed by the player. So every card, its `+`
  version and its mutants (ADR-0026) are compiled ahead of time into one `cards.wasm` by a build script, which reruns
  when card code changes, as `scripts/mutants.sh` does. The harness reads the same JSON as today (cards as indexes,
  bolts, battle) and calls the cards through a table. A turn should then cost about what JavaScript's 11 ms does.
- **Counting work:** the same line-preserving instrumentation as the JavaScript harness. C++ makes it simpler,
  because a macro can use `__LINE__`: `for (...) { ROOTWARD_LOOP();`, and `ROOTWARD_CALL("name")` at each function's
  top.
- **Player-written C++** (the Academy, a future Card Workshop) does need compiling during play. YoWASP ships clang
  itself built for WASI, so even the compiler can run inside wasmtime and nothing the player writes touches the host.
  Its compile time decides whether C++ reaches the Academy early or late.

**The spike (one session, go or no-go):** port five cards (Salvo, Merge Sort, Binary Search, Ward, Knapsack Strike)
and run them through the harness. Measure turn time, exceptions (`-fwasm-exceptions`, which Kurogane's `try`/`catch`
needs), whether a trap's line number maps back to the card's own line, the download size, and how long YoWASP clang
takes on a 40-line file. **Go** if a turn takes under 100 ms, exceptions work, and errors name the right line.

**If it goes:** port the 71 cards (and their `+` versions and mutants), with worked examples run by
`scripts/validate.sh` in all three languages. Then a C++ highlighter for the code view, `Program.cpp` as the main file
in the fight, C++ in the Adventure language choice, and Pip's Trial checked in C++. The language stays a choice made
per run for every class, as now, not tied to one character.

### 4.2 C# (not now)

.NET has no working WASI support today. The `wasi-experimental` workload was removed from .NET 9, .NET 10 has none,
and Microsoft has no WASI plans for 11. The only way to run C# would be outside the sandbox, which AGENT.md forbids.
Revisit if .NET supports WASI again.

## 5. Tracks B and D

### Track B: Kurogane, the sec-ops class

The brief is `docs/prompt2.md` (written 2026-09-29), and it holds. In short: a class whose programs **branch** (an
`if` card takes the next two cards as its branches, drawn as real indented code). **Exceptions are his resource**:
the damage his block stops is kept as *Raised*, `except` cards turn it into counter-bolts, and `finally` runs even
when the program crashes. Archetypes: Counter, Fortress, Guard Clauses. Every card is a real defensive idea (guard
clause, allow-list, rate limiter, checksum, firewall rules where the first match wins, audit log, fail-closed or
fail-open, defence in depth). He never teaches an attack and never shows a payload.

Slices (from the brief, with what has changed since):

1. **The class frame as data**: a `class` in run state (defaulted for old saves), a per-class pool, starter deck and
   relic, a picker before the draft, history per class. The Artificer becomes the first class in the rules, not
   just a label, with Vesper's paradigms as its archetypes; nothing in her runs changes.
2. **The balance sim as a tool** (ROADMAP stage 0, still undone; Phase 9's four-layer probe is also undone). The
   brief asks for a balance report per archetype, so the tool has to exist first.
3. **The rules primitives, with tests**: branches, Raised, `finally`, early return. The preview is the cast, with
   both branches previewed and the branch taken shown on the cast. P2-01 must be fixed before this, or branches will
   inherit the preview bug.
4. **A playable Kurogane**: starter deck, starter relic, four or five cards, placeholder art, one archetype.
5. **The pool and the show**: about 20 cards, his sprite from `Concept/newCharacters/anime-heavy/01-kurogane-ward-duelist.png`,
   spells that parry, riposte and harden a ward lattice, sound, Japanese. C++ versions of his cards too, if track C's
   spike went.
6. **The balance report**: win rates per archetype, with and without each archetype's best combo, and any card that
   moves a win rate by more than 20 points flagged.

**Done when:** the brief's checks pass (tests, lint, `validate.sh`, no Japanese missing, screenshots of the picker, a
branch, a riposte, a `finally` after a timeout, the forge diff), and the player has enjoyed a run with him.

### Track D: the Academy's foundation

ROADMAP stage 2 and `docs/ACADEMY_DESIGN.md`, except that it starts from nothing instead of absorbing the Verifier:

- The Academy room on the title in place of the placeholder: a hub, a lesson screen with a `CodeEdit` editor in the
  game's code colours, a console, test results, and tracebacks mapped to the player's line and explained in plain
  words.
- A lesson format with its schema and checks, plus a function-test harness in Python and JavaScript beside the stdout
  grader.
- Exercise types: Walkthrough, Predict, Parsons, Fix, Write. Explain can follow.
- Predict and Trace are built new inside the lesson screen, in the station's look. The removed Verifier's step-through
  and exact-output check are in git history to borrow from, if they still help.
- Saves per profile from the start (`user://<profile>/academy/`), never one global file (the Verifier's mistake,
  P2-18).
- Content: the old Foundry's 17 challenges (`../ProgramMe/content/packs/core/challenges/foundry/`) and units F1 and
  F2, in both languages and in Japanese.
- Stars and the hint ladder, which never gives the answer.
- Bridges that give no power (ROADMAP 3.3): a Shardrun card's details link to the lesson on its algorithm.
  Kurogane's cards link to the lessons on `if`, early return and exceptions.

**Done when:** the player, and the daughters if ready, can finish unit F1 without outside help, every lesson
validates in both languages, and the Academy's "in preparation" panel is gone.

### Not in Phase 2 (kept so they aren't lost)

- **The enemies' look and theme.** The player noted many foes don't match the theme or the backdrops, which is fine
  for now. The fix belongs with ROADMAP stage 4 (the Bug Bestiary): foes that attack your program, reworked to their
  bugs and repainted together against each layer's backdrop (P2-40).
- A run with choices (ROADMAP stage 3): a shop, events, scripts, rest or refactor as one campfire.
- The guided first run, the Library's "the real bug and how it's fixed" pages, more spell animations per role.
- The World, the Daily Build, strictness levels.

## 6. Bugs and improvements, before fixing

Numbered for reference in commits ("fix P2-01"). **Status** says how each was checked on 2026-10-04: *verified*
means the code was read today and the fault is there. *Unchanged* means the file it lives in has not changed since
the 2026-10-01 audit (`bugfixes.md`, which has the full write-up). *Recheck* means the file has changed since, so
the finding needs re-testing before it is fixed. *Seen* means it shows in this pass's screenshots.

### 6.1 From the 2026-10-01 audit (`bugfixes.md` number in brackets)

| ID | Priority | Status | What |
|---|---|---|---|
| P2-01 | High | verified | [2] A program's preview never lets faster foes act; the cast does, so a preview can show 10 damage and the cast land 0 (`core/programs/program_rules.gd:632-680` against `:282-290`) |
| P2-02 | Medium | unchanged | [3] Preview leaves out the block from defensive relics (Try/Finally, Runic Loom) |
| P2-03 | High | unchanged | [4] A shielded Thunk loses its shield twice when forced |
| P2-04 | High | unchanged | [5] Overflow skips guardian landing rules; the Call Stack Colossus's HP drifts from its frames |
| P2-05 | Medium | unchanged | [6] Overflow absorbed by a shield is counted as damage dealt (score, globals) |
| P2-06 | High | unchanged | [8] Dead cards (Unreachable) still make Lambdas, spend globals, add block |
| P2-07 | Medium | unchanged | [7] The Mutator's bonus hit is missing from damage totals and the preview |
| P2-08 | Medium | unchanged | [9] A faster Malloc's summon shifts the indices the program aimed at |
| P2-09 | Medium | recheck | [10] Imports and dead code can leave the code panel on "Running it in the sandbox…" |
| P2-10 | Medium | unchanged | [11] The listing shows the original code while the sandbox runs the Mutator's mutants |
| P2-11 | High | verified | [17] E and the number keys act on the fight under the run menu and other overlays (`scenes/shardrun/fight/fight_view.gd:398`) |
| P2-12 | High | unchanged | [19] A malformed run save (map `null`, no integrity) passes validation |
| P2-13 | High | unchanged | [20] A failed save still reports success; the menu promises every move is saved |
| P2-14 | Medium | unchanged | [21] A later load erases an earlier corrupt-save warning |
| P2-15 | Medium | unchanged | [22] A truncated history line also swallows the next finished run |
| P2-16 | High | unchanged | [25] Malformed profile metadata can stop startup instead of being skipped |
| P2-17 | Medium | recheck | [12] With predictions off, the final predicted volley still shows before the cast |
| P2-18 | High | closed by A1 | [23] Verifier progress is one global file, shared by every player and not covered by `ROOTWARD_SAVES` (`core/verifier_course.gd:6`) |
| P2-19 | Medium | verified | [24] Editing a profile offers only Vesper and Emberfox and resets any other avatar (`ui/profile_panel.gd:23-35`) |
| P2-20 | Medium | recheck | [13] The speed label uses base complexity, not the stage's effective one (Quick Sort on sorted input) |
| P2-21 | Medium | verified | [31] A fast process can exceed the output limit and still pass, silently truncated (`sandbox/sandbox.gd:112-123`: the loop exits on process end before the size check) |
| P2-22 | Medium | unchanged | [15] [16] The Trial coach doesn't refresh within a step, and the Trial's event check drops each command's first log lines |
| P2-23 | Medium | unchanged | [18] Changing predictions in Options leaves the open fight stale |
| P2-24 | Low | closed (ADR-0047) | [30] Japanese profiles get English run screens (and one Japanese line on the end screen, P2-35) |
| P2-25 | Medium | recheck | [26] [27] Summons, catches and INT_MAX healing don't animate; a crashed cast doesn't animate its mana |
| P2-26 | Medium | unchanged | [29] A partial local skin folder errors instead of falling back |
| P2-27 | Low | verified | [33] 12 sound voices stolen oldest-first can cut a long cast sound |
| P2-28 | High | verified | [1] A spell id listed twice passes arrange and compose, duplicating one card and destroying another (`core/shardrun/shardrun_commands.gd:97-106`) |

Closed since the audit: [14] Continue no longer opens the Trial (`scenes/title/title.gd:240-243` and `_launch_run`
clear `trial_active`; a test should pin it). [28] The wardrobe row was replaced by the carousel. [32] Lint is clean.

### 6.2 Found in this pass

| ID | Priority | What, and where it shows |
|---|---|---|
| P2-30 | Medium | **Card names are clipped** in the hand ("Knapsack Stri", "Round Robi") and shrink to unreadable in the five slots (`run-fight.png`, `run-cast.png`). Fit the title to the card (shrink to a floor, then two lines) |
| P2-31 | Medium | **The code panel's loop count covers the code**: `↻ ×3` sits over the end of `charge`'s `return` line and hides `+ 1 }));` during the walkthrough (`run-cast.png`, line 47). Reserve a gutter for it, or wrap the line under it |
| P2-32 | Low | **Complexity reads as struck through**: the card face's `O(N)` sits on the frame's divider line (every card, hand and deck). Move it off the line, or give it a plate |
| P2-33 | Low | The Verifier screen has none of the station's look (plain dark panels, "← Title"), so it stands apart from every other room. Closed by A1, which removes it |
| P2-34 | Medium | **Layer names and numbers disagree.** The title says "Salvage → Heap → Kernel" (three layers, old names). The program run has four: Sandbox, Heapworks, Interrupt Foundry, Kernel. The end screen says "The Salvage keeps what you carried". The map counts rings down ("Ring 3 · layer 1 of 4") while the Library counts layers up ("Layer 2 · The Heapworks"). Pick one name per layer and one count, and show both only where both help |
| P2-35 | Low | The end screen greets a Japanese-preferring profile in Japanese ("Player 1、おつかれさま！") above an English summary (`scenes/shardrun/run_summary.gd:32`). Resolved by A4 |
| P2-36 | Low | After a win, the "4 incoming" badge stays up beside the victory banner over the fading foe (`run-volley.png`) |
| P2-37 | Improvement | **Rewards show cards as small shard icons plus code**, not the card faces used everywhere else, so a reward doesn't look like the card you'll hold (`run-reward.png`). Offer three card faces with the code on hover, as the hand does |
| P2-38 | Improvement | **Rest, cache and forge rooms are a line of text and a button** on a 1,350-pixel empty panel (`run-rest.png`, `run-treasure.png`). Give each room its painting, centre the choice, and consider the ROADMAP's single campfire (heal or refactor, decision 8) |
| P2-39 | Low | In the deck panel, the "×2" count tiles look like empty card slots (`run-reward.png`). A badge on the card's corner reads better |
| P2-40 | Parked | Hallway foes are Spellforge's elemental creatures with weakness and resistance; they don't touch your program, and several clash with the dungeon backdrops (the player's note; ROADMAP stage 4) |
| P2-41 | Low | The Character room lists eight locked classes as full-height rows that look selectable. Make the locked ones compact and dimmed; the column fills as classes are built (track B) |
| P2-42 | Low | `scripts/screenshot.sh` of the rest moment failed once (exit 1) while the test suite ran at the same time, then passed alone. Not measured; the shot tool may share a `user://` folder with the tests |
| P2-43 | Low | Docs drift: `docs/decisions/README.md` says the next ADR is 0041 (0044 exists). `docs/PLAN.md` has two "Phase 9" headings. ROADMAP's per-stage ADR numbers (0018 to 0022) collide with ADRs already written |
| P2-44 | Low | Untracked probe files in `game/` (`probe_glb.gd`, `probe_glb.gd.uid`, `probe_head.gd.uid`) Deleted with A1 |
| P2-45 | Medium | `scripts/menu-navigation.sh` (181 real clicks) had been failing since the Character room's rework: it clicked "Test spell", "Floor guides" and "High contrast", which were renamed or removed, and keyboard focus never scrolled a hidden control into view (`Ui.scroll` lacked `follow_focus`). Fixed with A1 |
| P2-47 | High | **Spellforge's map was broken**: a spell's shard chips drew their pictures at full size since the art passes made them large (ADR-0033), so one picture filled the spellbook, the map was squeezed to half its width and the room legend sat over its bottom rows. Fixed in track A |
| P2-49 | Low | A program card's "a forge upgrades it into …" note showed the upgrade's id (CHARGE-PLUS), looked up among Spellforge's shards. Fixed with A4 |
| P2-48 | Low | The screenshot tool kept a Japanese preference from an earlier Trial shot, so later shots greeted in Japanese. Fixed: each shot resets it |
| P2-46 | Low | Character → Spells with three practice targets: their name plates and "Watching" tags overlap one another (`shots/phase2/menu-character-spells.png`) |

## 7. Decisions that are yours

1. **The Academy empty until track D.** Removing the Verifier in A leaves the Academy with nothing to play until D
   lands. Recommended: remove it now, as asked, so nothing new gets built on it. The alternative is to keep its
   button until D replaces it.
2. **The old Verifier save** (`verifier-course.json`, your stars). Recommended: leave the file on disk and stop
   reading it. Or delete it as part of the removal.
3. ~~Retire the Card Shardrun?~~ Answered 2026-10-04: no mode is removed (A2).
4. **The order**: A, B with C's spike, then D (recommended), or A then D first?
5. **Kurogane's name and look.** You called him "sec ops". Keep "Kurogane, the Ward Duelist" with security in the
   cards (the brief's default), or rename the class toward the theme ("Sentinel", "Warden", "SecOps")?
6. **C++ and C#.** Recommended: C++ behind the spike, C# not now (section 4.2). Should C++ come to the Academy too
   (it would need the in-sandbox compiler and its compile times)?
7. **A4 now or later**: put the interface through the catalogue before new screens (recommended, for the daughters),
   or keep going in English and catch up in ROADMAP stage 9?
