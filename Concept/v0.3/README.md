# v0.3: where Rootward goes next

Written 2026-10-09. The player asked: look at the project, give an unfiltered opinion on where it stands, lay out
several paths from here, and say whether animation and polish are worth more now or later. This folder is that
answer: this page is the opinion and the recommendation, and each numbered file is one path, worked out far enough to
start.

| File | Path |
|---|---|
| [01-academy-workshop-town.md](01-academy-workshop-town.md) | The Academy, rebuilt as a town where your code visibly does things |
| [02-shardrun-made-right.md](02-shardrun-made-right.md) | The Shardrun, fixed and balanced before it grows |
| [03-second-class-kurogane.md](03-second-class-kurogane.md) | A second class: Kurogane, the Ward Duelist (and the alternatives) |
| [04-feel-and-look.md](04-feel-and-look.md) | Animation, movement, skins and spell effects: what is worth doing now |

## The short answer

1. **The learning mode is the gap.** The Shardrun is broad and good-looking; the Academy has ten exercises, and they
   are an editor beside a letter. The game exists to teach, so the next big piece of work should be the Academy.
2. **Make it solid now, make it pretty later.** Fix the bugs, the sandbox gaps and the run's pacing now, because every
   later number stands on them. Hold back broad animation and cosmetic work: what you would polish today will change.
3. **Do not add a class yet.** One class with five paradigms already runs from 0% to 83% wins in the bot. Get those
   inside the targets, with some human runs behind them, then add Kurogane.
4. **Freeze growth for a while.** No new cards, relics, paradigms or cosmetic looks until the Academy's first slice is
   played and the Shardrun's gates are met.

Order, in sessions (a day's work, as `WIP.md` counts them): about two sessions of path 2's must-fix list, then path
1's first three slices (about six sessions, with you playing after each one), then path 3. Path 4 is a small budget
attached to whatever is being built, not a project of its own.

## Where the project actually stands

### What is genuinely strong

- **Real code runs, in three languages, safely.** Python and JavaScript on WebAssembly, C++ compiled ahead of time, all
  inside a sandbox with limits. Most programming games use a language of their own (Human Resource Machine,
  the Zachtronics games, The Farmer Was Replaced's Python-like dialect); real languages in three of them, sandboxed,
  next to a roguelite, is rare. This is Rootward's moat.
- **The card idea.** Cards are real algorithms, played in order into one program, and the program's measured work
  races the foe. It teaches complexity by making it cost something. Nothing else plays like it.
- **Engineering discipline.** 818 test cases, lint, 1036 worked examples run per language, data-driven content, and 60
  decision records. The project can change safely, which is rare at this age.
- **The look.** The station, the fight stage, the cards and the creature art are coherent and appealing (the
  screenshots taken for this review are in `shots/status/`, which is local and git-ignored). The game already looks better than most indie games at release.
- **Lanternroot's core idea is right.** Tests as the specification, a Night Watch that reruns everything, imports as
  bridges, a change that breaks yesterday's code: this is what working programmers actually need to learn.

### What worries me

1. **Breadth has outrun validation.** In fifteen days (173 commits, about 57,000 lines of GDScript): 309 card files in
   three languages, 91 relic files, 30 Issues, 16 scripts, a shop, five paradigms with fifteen focuses, three run
   playstyles plus Spellforge, eight circle styles, 3D VRM skins with a Blender move library, and the legendary looks.
   The only systematic player is a bot that looks one turn ahead, over six seeds per paradigm. No human run has been
   written down.
2. **Some of the bot's verdicts are about the bot.** Search & Index won 0 of 6, yet the v0.2 balance audit calls it the
   most cohesive engine in the pool: sort first, spend the sorted volley later. A one-turn bot undervalues setup. So
   "buff Search" might be the wrong fix, and big balance moves need human runs or a smarter bot first.
3. **Every card costs five things.** The data file, Python, JavaScript, C++, the Japanese text, plus worked examples
   and art. That multiplier is why a new class is expensive: thirty cards is about 150 files. It is also why the open
   audit has twelve high-severity code bugs waiting: each fix is three fixes.
4. **Cosmetics have taken a lot of recent effort.** The legendary looks took two redesigns and seven build-and-review rounds. It is
   good work, and it is also the classic polish trap, while the learning mode has ten exercises.
5. **The learning mode does not yet do what Rootward is for.** Lanternroot's town is a still picture with a list beside
   it, and the work happens in an editor next to a letter (`shots/status/lantern-letter.png`). It is a kata site in
   lovely clothes. Your instinct that it feels like a terminal is right.
6. **There are too many plans.** `PLAN.md` (461 lines, about 25 open boxes), `ROADMAP.md`, `PHASE2.md`,
   `ParadigmUpdate.md` (1,424 lines), `SHARDRUN_DESIGN.md`, and sixty ADRs. That is part of why "what next" is hard to
   see. This folder is meant to be the one page that says now, next and later.
7. **The sandbox's own rule has gaps.** "Real execution or nothing" is the first rule, and a card can still replace the
   harness's globals for its job, hide its measured work, or print a forged result line (`docs/LEGENDARY_LOOKS.md`).
   It is a single-player game, so this is not urgent, but measured work is a rule that pays out.
8. **The fight screen is heavy for a beginner.** Slots, `main.py`, operations, O(n), a timeline, the code panel, the
   hand and the circle, all at once (`shots/status/run-fight.png`). It is great for you, and a lot for a first run.

## Your question: polish now, or later?

**Solid now; pretty later.** The reasons, in order of weight:

- **What you would polish today will change.** The Academy rework replaces its screens. A second class adds branch
  cards to the fight's program panel. The fight HUD is already dense, and it will be redesigned the moment a beginner
  plays it. Polish is cheapest at the end and most expensive to redo.
- **"Solid" compounds; "pretty" does not.** The audit's high-severity bugs, the run's pacing (Act 1 fights last 1.56
  turns against a 2 to 4 target), the sandbox gaps and save safety all feed every later balance number. Fixing them
  now makes every later session cheaper. A nicer bolt does not.
- **The fight already looks good.** One more effect there is worth less than the first real learning loop.
- **Two exceptions are worth polishing now.** Polish that teaches (watching code run: the Token Stream idea, and the
  Academy's helper in path 1), and the first ten minutes for a new player, which for Rootward means your daughters.
- **The rule of thumb from game-development practice:** juice the core loop early, polish late, and put polish where
  players spend their time. Attach a small feel budget (about 15% of a slice) to whatever you are building, instead of
  separate polish projects.

## The paths compared

| Path | What you get | Sessions | Risk | My verdict |
|---|---|---|---|---|
| 1. Academy as a workshop town | A learning mode that is a game: your code drives a helper through the town, and you watch it run | 6 for three slices, 2 more for the youngest | Building a world before the lessons work | **Do next.** The highest value per session in the project |
| 2. Shardrun made right | Bugs fixed, sandbox closed, pacing tuned, real human run data | 2 to 3 | Low | **Do first, briefly.** It is the "solid" half of your question |
| 3. Kurogane, a second class | A defensive class built on `if`, `return` and `try` | 3 to 4 minimum, 6 whole | Balance surface doubles; branch cards are new engine work | **Do third**, once path 2's gates are met |
| 4. Feel and look | Animation, movement, skins, spell effects | Ongoing | The polish trap | **Budget, not project.** Finish the Vesper skin already underway; little else |

## What I would freeze

- **New Shardrun content.** No new cards, relics, paradigms or Issues until path 2's gates are met.
- **New cosmetic looks.** No new circles, bolts, impacts or VRM skins until the Academy's first slice is played. The
  Vesper v1.5 and v2 sprites already underway are the exception: finish them.
- **Spellforge and the deck playstyle.** Keep them working and fix what breaks, but add nothing (roadmap decision 9,
  whether to retire the deck playstyle, is still yours).

## Decisions I need from you

1. **Order.** Academy first (recommended), or the second class first?
2. **The Academy's look.** The game's painted finish (slower, matches), Kenney's 16-pixel tiles (fast, clashes), or
   painted top-down tiles made once with ComfyUI. Path 1, section 9.
3. **New class cards in C++.** Python and JavaScript first, with C++ when the class is settled? That cuts about a third
   of the cost.
4. **Play-testing.** Will you play five runs and write the five-line note in path 2 for each? Will the daughters try the
   youngest track, and what do they read (hiragana only, or kanji with furigana)?
5. **The harness decisions** already listed in `PLAN.md`: wrap the harness in one function, and bill tampered measured
   work at the cap or fail it.

## Sources

Research done for this folder on 2026-10-09. Several are small studies; each path says how much weight it puts on them.

- PRIMM (predict, run, investigate, modify, make): [the Raspberry Pi Foundation's pedagogy summary](https://static.raspberrypi.org/files/curriculum/quickreads/11-Pedagogy_Summary_PRIMM_V4_2023.pdf);
  [Sentance, Waite and Kallia's school study](https://qmro.qmul.ac.uk/xmlui/handle/123456789/57800).
- Parsons problems as optional help: [Hou et al., arXiv 2512.22407](https://arxiv.org/html/2512.22407);
  [faded Parsons, SIGCSE 2025](https://sigcse2025.sigcse.org/details/sigcse-ts-2025-acm-student-research-competition/22/Using-Faded-Parsons-Problems-To-Provide-A-More-Challenging-Scaffold-For-Code-Writing).
- Notional machines and seeing execution: [Sorva's survey of program visualization](https://romisatriawahono.net/lecture/rm/survey/software%20engineering/Software%20Architecture/Sorva%20-%20Generic%20Program%20Visualization%20Systems%20for%20Introductory%20Programming%20-%202013.pdf);
  [multiple coordinated views, arXiv 2509.26466](https://arxiv.org/pdf/2509.26466).
- Spaced and interleaved retrieval in a programming course: [par.nsf.gov 10544324](https://par.nsf.gov/servlets/purl/10544324);
  [six strategies for effective learning](https://www.schreyerinstitute.psu.edu/pdf/SixStrategiesEffectiveLearning.YanaWeinstein.2017.pdf).
- Programming games: [Human Resource Machine](https://en.wikipedia.org/wiki/Human_Resource_Machine) and
  [7 Billion Humans](https://www.gamingonlinux.com/2018/08/7-billion-humans-from-tomorrow-corporation-is-now-out-and-its-fantastic);
  [The Farmer Was Replaced](https://www.gamingonlinux.com/2025/10/the-farmer-was-replaced-is-a-satisfying-way-to-learn-a-little-programming-with-automation/page=1/);
  Zachtronics' histograms ([Opus Magnum](https://www.pcgamer.com/au/perfectly-solving-opus-magnums-puzzles-is-impossible-but-thats-ok),
  [TIS-100](https://en.wikipedia.org/wiki/TIS-100)); CodeSpells, spells written in Java
  ([UC San Diego](https://today.ucsd.edu/story/uc_san_diego_computer_scientists_develop_first_person_player_video_game_tha)).
- Balance from data: [Slay the Spire's metrics-driven design, GDC 2019](https://www.gamedeveloper.com/design/learn-i-slay-the-spire-i-s-metrics-driven-approach-to-game-balancing-at-gdc-2019);
  [Seattle Indies interview with Mega Crit](https://seattleindies.org/seattle-indies-spotlight-mega-crit-games/).
- Polish timing: [juice versus polish](https://www.wayline.io/blog/juice-vs-polish-key-differences);
  [vertical slice versus prototype](https://bugnet.io/blog/vertical-slice-vs-prototype-what-to-build-first) (blog
  advice, weighed as common practice, not evidence).
- Programming in Japanese schools since 2020, and Viscuit for young children:
  [MEXT's portal](https://www.mext.go.jp/miraino_manabi/content/492.html); [coeteco on Viscuit](https://coeteco.jp/articles/10311).
