# Rootward: the game plan

Written on 2026-09-28, at the player's request: "an actual beginner to advanced mode for learning programming ...
completely separate from the shardrun ... lessons, ideas of how to improve, and a general progression system", and
"the slay the spire route with shardrun ... more enemies, more levels, more combination ideas, more classes for
different styles of play". This file is the plan; two companions hold the design:

- `docs/SHARDRUN_DESIGN.md`: the Shardrun made deep (core loop, run, enemies, classes, cards, relics, meta).
- `docs/ACADEMY_DESIGN.md`: the learning mode (lessons, grading, "how to improve", progression, curriculum).

Once the player agrees, the stages below become phases in `docs/PLAN.md`, and each gets its ADR as it lands.

## In one screen

- **Two journeys, one foundation.** The **Shardrun** becomes a roguelite with Slay the Spire's depth (classes, a
  shop, events, upgrades, three bosses an act, a fourth act, ascension) whose cards are real algorithms and whose
  enemies are real bugs. The **Academy** is a separate course from a first `print` to building a VM, where every answer
  runs in the sandbox and every pass comes with a measured "here is how to make it better". They share the sandbox,
  the code view, the art and the translations, and nothing else: learning never makes a card stronger.
- **Fix the Shardrun's core before building on it.** Measurements (section 2) show the core idea works (putting cards
  in the right order is a real skill), but a program has almost no input without one card (Salvo), the difficulty is a
  cliff at the second boss, and the speed race only ever takes something away.
- **Then alternate between the journeys**, one playable step at a time: the Academy's foundation, a run with choices,
  the bestiary, the Academy's progression, the Artificer made whole, a second class, the fourth act and ascension,
  Japanese everywhere with Pip's Path for the daughters.
- **Section 6 lists the decisions that are yours**, each with a recommendation.

## 1. Where Rootward stands

| Area | Today |
|---|---|
| Shardrun (the program run, ADR-0012) | 5 paradigms, 23 cards in Python and JavaScript, a draft, 14 relics, 15 foes, 3 layers of 8-9 rows, the speed race, the card table, the code walkthrough, spell animations |
| Spellforge, the card Shardrun | ported and proven against the old engine's fixtures; secondary |
| Verifier | 12 code-reading lessons in JavaScript, three chapters, stars |
| Sandbox | CPython 3.14 and QuickJS under wasmtime, limits, stdout grading, loop and call counting |
| Art and sound | Vesper as a sprite skin, painted arenas and card frames, spell animations, music per layer |
| Tests | 126 at the last run, green |
| Not yet | Japanese in the interface (content only), card art of their own, any shop, event, upgrade path or status effect, a second class |
| Waiting to be used | 9 character concepts (`Concept/newCharacters/`), 7 enemy briefs (`Concept/Enemies/`), and in the old repo 17 graded challenges, a concept graph and pedagogy notes |

## 2. What the measurements say

A throwaway probe (`docs/research/balance-probe/`) played whole program runs through the real rules and the real
sandbox. Its **smart bot** tries every legal program each turn (every ordered choice of cards the mana and the five
slots allow, up to about 2,000 a turn), simulates each cast and the foes' answer, and plays the best; it drafts
toward its paradigm, rests when hurt and forges what it can. Its **dealt-order bot** plays every affordable card in
the order dealt, as a player who has not yet seen why order matters might. Beginner difficulty, JavaScript.

**The baseline (40 smart runs, 8 per paradigm):**

| Fight | Won | Turns | Integrity lost | Foe HP |
|---|---|---|---|---|
| Act 1 fight | 100% | 1.5 | 1.0 | 19 |
| Act 1 boss (Kiln Warden) | 100% | 3.1 | 5.5 | 81 |
| Act 2 fight | 99% | 2.6 | 5.1 | 69 |
| Act 2 boss (Deadlock Golem) | 44% | 9.4 | 44.1 | 287 |
| Act 3 fight | 82% | 4.3 | 15.7 | 250 |
| Act 3 boss (Root Daemon) | 25% | 9.5 | 51.0 | 1,156 |

One run in 40 won (Brute Force). Half of all runs ended at the Deadlock Golem.

**What that means:**

1. **Salvo is the whole engine.** A turn with Salvo in hand dealt 56 damage on average; without it, 5. A program
   starts from one 3-power bolt and every other card only transforms what it is given, so in 9% of turns the best
   program was an empty one. Salvo is played 99% of the times it is drawn, and it is in no draft pool.
2. **The difficulty is a cliff.** Act 1 is a formality (fights last a turn and a half), then the Golem's pattern ward
   (bolts of the wrong element do a quarter) asks "did you draw this turn's element?", and Act 3's HP (×6.8) outruns
   what the deck can grow into.
3. **Order is a real skill, and that is the good news.** In 40% of turns a reordered program beat every program in
   dealt order; the dealt-order bot did not get past the Act 1 boss in 37% of its runs and never beat the Golem (0
   of 30).
4. **The speed race only takes.** A foe acted before the program in 18% of turns; no chosen program ever timed out,
   and only 1% of possible programs would have. Being fast earns nothing.
5. **Nothing grows inside a fight**, and the draft's paradigm fades: rewards draw from every card, and the relics are
   ten flat bonuses and four curses.

**What the numbers cannot show** (suspicions from reading the game and its screens, to check in play):

- Why a card is good is hard to see at a glance: its role is not on its face, and most pictures are the old shards'.
- The race bar asks for ops against tempos on a log scale; whether that reads at a glance is untested.
- An Act 1 fight ends before the deck has shown itself, so the draft's choices are felt late.
- Casts are long by design (the walkthrough); longer fights (stage 1) multiply that, so pace needs a check in play.
- The foes are named for bugs, but none of them touches your program; the bugs are names more than mechanics.

**What-if runs** (changes made in memory only; 6 runs per paradigm unless noted):

<!-- whatif:start -->
| experiment | runs | won | beat boss 1 | beat boss 2 | act 1 turns | act 1 HP lost | Salvo in hand | empty turns | foe first | reorder wins | won, worst-best paradigm |
|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline (smart bot) | 40 | 2% | 100% | 40% | 1.5 | 1.0 | 11x | 9% | 18% | 40% | 0-12% |
| dealt-order bot | 30 | 0% | 63% | 0% | 2.6 | 5.1 | 8x | 0% | 21% | - | 0-0% |
| softer Golem (x0.5 off-pattern) | 30 | 3% | 100% | 63% | 1.6 | 1.3 | 11x | 10% | 20% | 41% | 0-17% |
| Salvo in draft pools | 30 | 0% | 100% | 50% | 1.6 | 1.2 | 9x | 11% | 18% | 42% | 0-0% |
| source-aware drafting | 30 | 17% | 100% | 57% | 1.6 | 1.3 | 12x | 9% | 22% | 47% | 0-50% |
| Salvo in pools + source-aware drafting | 30 | 10% | 100% | 63% | 1.5 | 1.1 | 10x | 9% | 23% | 47% | 0-17% |
| seed of 3 bolts | 30 | 20% | 100% | 83% | 1.2 | 0.5 | 2x | 4% | 29% | 53% | 0-50% |
| 4 Salvos in the starting deck | 30 | 20% | 100% | 67% | 1.3 | 0.9 | 14x | 8% | 23% | 46% | 0-33% |
| gentler HP curve (x1.8, x3.6) | 30 | 20% | 100% | 67% | 1.6 | 1.3 | 11x | 12% | 18% | 39% | 0-50% |
| 4 Salvos + gentler curve | 30 | 30% | 100% | 80% | 1.3 | 0.9 | 10x | 8% | 19% | 43% | 0-67% |
| seed of 3 bolts + gentler curve | 30 | 43% | 100% | 90% | 1.2 | 0.5 | 2x | 5% | 25% | 49% | 17-67% |

Columns: *beat boss 1/2* is the share of runs that got past the Kiln Warden and the Deadlock Golem; *Salvo in hand* is
a turn's damage with Salvo in hand over a turn's without; *empty turns* are turns where the best program was empty;
*foe first* the turns where a foe out-sped the program; *reorder wins* the turns where some reordering beat every
program in dealt order. Salvo in the draft pools does nothing for a drafter that never takes it; the next two rows
draft it on purpose.

Reading it. Softening the Golem alone moves the wall to Act 3: more runs get past it (63% against 40%), almost none
win. Four Salvos, a gentler curve, a drafter that wants Salvo, or a stronger seed each lift the win rate to between a
tenth and a fifth, and the Salvos with the curve to 30%. Only the seed changes the shape of the game: every other fix
leaves a turn with Salvo doing ten times what a turn without it does, while programs that start from three bolts bring
that to 2×, halve the empty turns (4% against 9%), make reordering matter in more turns (53% against 40%) and put foes
in the race more often (29% against 18%). With the gentler curve it won 43% of runs, and every paradigm won some (17%
to 67%). Its cost is Act 1, already too easy and now a formality (1.2 turns a fight, half an Integrity lost), so the
curve has to rise at the start as it falls later. Stage 1 starts from there.
<!-- whatif:end -->

## 3. The direction

### 3.1 The Shardrun: Slay the Spire's depth, programming's soul

| Slay the Spire | Rootward today | Rootward, proposed (SHARDRUN_DESIGN section) |
|---|---|---|
| Four characters | one class; paradigms as a draft | nine classes, each a programming domain (5) |
| Strike and Defend always do something | only Salvo makes bolts | a Source role, several sources in every deck (3.1) |
| Energy | mana | mana, plus a work budget that shrinks by act (3.2) |
| Powers, Strength, Poison, Orbs | nothing grows in a fight | imports and fight state (3.3) |
| Exhaust, Retain, Innate, Ethereal | none | `once`, `const`, `__init__`, `volatile`, `lambda`, `pure`, `async` (3.4) |
| Upgrades at the campfire | one optimisation | every card has a `+`, shown as a code diff (3.5) |
| Shop, gold, card removal | none | the Registry, cycles, `uninstall` (4) |
| Potions | none | scripts: `sudo`, `kill -9`, `git revert` (10) |
| ? rooms | none | Issues, including a code-reading duck (11) |
| Intents | damage | damage, speed, and what the foe does to your program (6) |
| Wound, Burn, Slimed | none | bugs in your deck: Null Pointer, Infinite Loop (6.4) |
| Three bosses an act, shown | one fixed boss | three an act, shown on the map (4.1) |
| Act 4 and the keys | none | the Root, three keys, the Halting Oracle (4, 6.3) |
| Ascension | Beginner, Programmer | strictness `-W1` to `-W15` (9) |
| Compendium, run history, daily | none | the Library (with the code and the real bugs), `git log`, the Daily Build (9) |

### 3.2 The Academy: a course that runs your code

Lessons in Python and JavaScript, English and Japanese, from Apprentice (foundations) through Journeyman (programs),
Adept (data structures and algorithms), Expert (craft) to Master (build a VM, a Lisp, a mini git). Exercises ask the
player to produce (predict, trace, order, fix, write, improve), graded by running the code. After each pass a review
measures the solution's work as the input grows, names its complexity against the reference's, points out style
fixes, and shows another way to write it. Progress is the Root Map (the concept graph drawn as roots), mastery per
concept, a version number as rank, and five minutes of spaced review a day. Pip's Path teaches young players with a
character walking a grid. The Verifier's lessons move in. See `docs/ACADEMY_DESIGN.md`.

### 3.3 Where they meet, lightly

Separate saves and progress. Shared: the sandbox, the code view and walkthrough, translations, characters and art.
Bridges that give no power: every Shardrun card's detail links to the lesson on its algorithm (and back); the Library
explains each foe's real bug; the Rubber Duck event borrows the Academy's predict interaction; Academy rewards are
cosmetics for both; the Card Workshop (write and prove your own card, play it in sandbox runs) unlocks at the
algorithms tier.

## 4. Rules for every stage

1. **Real code only.** Every card, every foe mechanic that reads a program, every lesson answer runs in the sandbox.
2. **Every mechanic teaches something true** (SHARDRUN_DESIGN section 1), or it does not ship.
3. **Measure before and after.** Every Shardrun change lands with a sim report against the targets it names; the
   player's own runs (kept locally, never sent) are read beside the bot's.
4. **New text ships in English and Japanese** from stage 0 on, so translation debt stops growing.
5. **Small slices** (AGENT.md): tests green and the game launchable after every step, something playable at the end
   of every stage, a screenshot of anything visible.
6. **Protect what works**: Spellforge and the fixture-proven rules stay as they are; program rules have their own
   tests; an experiment goes behind an option until it wins.
7. **Art never blocks**: every new card and foe has a fallback; art follows in the same stage when it can.
8. **Content is the long pole**, and proof is what makes it fast: about 45 cards in two languages with their `+`
   versions, about 30 foes, a few hundred lessons. Every card carries worked examples and every lesson its tests, run
   by `scripts/validate.sh`, so content can be written quickly (by an agent too) without being wrong.
9. **Saves survive the changes**: a run saved under older rules is set aside, never broken (as today); Academy progress
   is never reset by new content.

## 5. The stages

Sizes are in sessions like the ones in `WIP.md` (a day's work each). The order is a recommendation (section 6).

| Stage | Journey | Playable result | Sessions |
|---|---|---|---|
| 0. Instruments and decisions | both | the sim as a tool; the title in Japanese | 1 |
| 1. The Shardrun's core, fixed | Shardrun | a run with input, a curve, and speed that pays | 1-2 |
| 2. The Academy's foundation | Academy | the first unit, start to finish | 2-3 |
| 3. A run with choices | Shardrun | shop, events, scripts, upgrades | 2 |
| 4. The Bug Bestiary | Shardrun | foes that attack your program; three bosses an act | 3 |
| 5. The Academy teaches | Academy | progression, the improvement review, the Foundations tier | 2 |
| 6. The Artificer, whole | Shardrun | Vesper as a full class; imports; card art | 2-3 |
| 7. A second class | Shardrun | Kurogane, the Ward Duelist | 2-3 |
| 8. The Root, and reasons to replay | Shardrun | Act 4, strictness levels, the Library, the Daily Build | 2 |
| 9. Japanese everywhere, and Pip's Path | both | the whole game in Japanese; the daughters' course | 2 |
| 10 and on | both | more tiers, classes, acts; the Card Workshop | ongoing |

### Stage 0: instruments and decisions

The goal: every later change can be measured, and the calls the rest depends on are made.

- [ ] The probe becomes a tool: `tools/balance_sim.gd` and `scripts/balance.sh` (smart and dealt-order bots, what-if
      variants, a JSONL of runs, the summary tables above, one process per paradigm in parallel).
- [ ] Translation plumbing for the interface: a catalogue through Godot's TranslationServer, a language option,
      the title translated; content already has Japanese overlays (ADR-0004).
- [ ] ADR-0016: two journeys, separate progression, this plan accepted into `docs/PLAN.md`.
- [ ] The player's answers to section 6.

Done when `scripts/balance.sh` reproduces the baseline within noise and the title switches to Japanese.

### Stage 1: the Shardrun's core, fixed

The goal: a program always has input, the difficulty climbs instead of cliffs, and speed earns something.

- [ ] Card roles on every card face (Source, Shape, Order, Strike, Guard).
- [ ] Input: programs start from a stronger seed (three bolts did best in the what-ifs), given by the class's
      starter relic; Literal, Repeat and Read Input as neutral sources; Salvo and the new sources in the draft
      (SHARDRUN_DESIGN 3.1).
- [ ] The curve reshaped, harder at the start and gentler later: Act 1 fights of two to four turns that cost a
      little; Act 2 and 3 HP brought within reach (the what-ifs tried ×1.8 and ×3.6 in place of ×2.6 and ×6.8).
- [ ] The Deadlock Golem reworked as two locks, damage blocked unless one program hits both: the first foe whose
      mechanic reads your program, and the test of the hook stage 4 builds on.
- [ ] The speed race's other half: Initiative (+25% against foes you out-speed), a speed per intent, a budget per act.
- [ ] Run history, first version: every finished run kept in `user://`, readable by `scripts/balance.sh` beside the
      bot's runs.
- [ ] ADR-0017.

Done when, for 40 smart runs on Beginner: 40-60% won and every paradigm at 25% or more; the dealt-order bot beats the
Act 1 boss in 70% of runs; Act 1 fights average two to four turns and three to eight Integrity; a turn's damage with
and without its best source differs by less than 3×; empty programs in under 3% of turns; a foe first in 20-35% of
turns and Initiative in 20-40%; reordering still wins in 35% of turns or more. Then the player plays one run per
paradigm and says what feels off.

### Stage 2: the Academy's foundation

The goal: a separate journey in which one unit teaches from start to finish, graded by running code.

- [ ] The Academy on the title in the Verifier's place; its hub, the lesson screen, an editor (`CodeEdit`, the game's
      code colours), a console and test results; tracebacks mapped to the player's line and explained in plain words.
- [ ] The lesson format, its schema and its checks (ACADEMY_DESIGN section 9); a function-test harness in Python and
      JavaScript beside the stdout grader.
- [ ] Exercise types: Walkthrough, Predict, Parsons, Fix, Write, Explain.
- [ ] Content: the Verifier's twelve lessons (with Python versions), the Foundry's seventeen challenges, units F1 and
      F2 whole, in both languages and in Japanese.
- [ ] Saves in `user://academy/`, stars, the hint ladder (never the answer).
- [ ] ADR-0018.

Done when the player (and the daughters, if they are ready) can finish unit F1 with no outside help, every lesson
validates in both languages, and the tests are green.

### Stage 3: a run with choices

The goal: between fights, the decisions that make a Slay the Spire run.

- [ ] Cycles; the Registry (cards, relics, scripts, `uninstall`); ten scripts; twelve Issues.
- [ ] A `+` version of every card, the diff shown; rest sites offer heal or refactor.
- [ ] Rewards of three and a skip, weighted to the paradigm, with a rare's rising chance; the boss and a legend on
      the map.
- [ ] ADR-0019.

Done when the sim, with a bot that shops and refactors, stays inside stage 1's targets, and in play every room offers
a real choice.

### Stage 4: the Bug Bestiary

The goal: enemies that attack your program the way bugs attack code (SHARDRUN_DESIGN section 6).

- [ ] Rule primitives: hooks before and after a program runs, on a hit and at the end of a turn; bug cards; foe AI
      with conditions; summons and foes of several bodies.
- [ ] The fifteen foes reworked to their bugs; twelve to fifteen new ones, the seven briefs among them; three elites
      and three bosses an act, easy and hard pools, the boss shown from the start.
- [ ] Six bug cards and their counters (Debugger, Unit Test, Linter, `gc.collect()`).
- [ ] Sprites for the new foes from the art pipeline; an effect for each mechanic.
- [ ] The Library, first version: each foe, the real bug it stands for, and how that bug is fixed in real code.
- [ ] ADR-0020.

Done when the smart bot wins 70% or more of every act's hallway fights, and each boss's win rate differs by less than
2× across paradigms (no boss is a key check).

### Stage 5: the Academy teaches

The goal: the Academy knows what the player knows, and says how to get better.

- [ ] The Root Map, mastery per concept, the version as rank, stars into rewards.
- [ ] Daily maintenance (spaced review), the journal of solutions.
- [ ] The improvement review: measured work against n beside the reference's, style rules (Python's `ast` in the
      sandbox, a JavaScript parser), reference solutions after a pass; the coach.
- [ ] The Foundations tier whole (about 48 lessons) in both languages and in Japanese.
- [ ] ADR-0021.

Done when a solution that checks membership in a list inside a loop is told it is quadratic, with the measured
difference and the idea of the fix, and a concept left alone for a week comes back in maintenance.

### Stage 6: the Artificer, whole

The goal: Vesper becomes a class of Slay the Spire's depth, and the class frame exists for the others.

- [ ] The class frame: pool, starter deck and relic, mechanic, archetypes, character, unlocks.
- [ ] Imports and keywords; fight state for `global`, accumulators and generators (SHARDRUN_DESIGN 3.3, 3.4).
- [ ] About 45 cards (six to eight per paradigm with a source each, and neutral ones), every one with its `+`; about
      20 relics that bend work, speed and order (SHARDRUN_DESIGN 7, 8).
- [ ] Card art for every card; Japanese for every card.
- [ ] A guided first run: the first fights teach one idea each (a source first, sort before search, aim last), and
      the preview says what a reorder would change (SHARDRUN_DESIGN 3.6).
- [ ] ADR-0022.

Done when every paradigm wins 30% or more for the smart bot and no card turns up in more than 60% of winning decks.

### Stage 7: a second class

The goal: a class that plays nothing like Vesper. Recommended: Kurogane, the Ward Duelist (SHARDRUN_DESIGN 5.2).

- [ ] Branch cards (`if` and `else`, shown as real indented code), Raised, `except` and `finally`, retaliation; about
      30 cards; a starter deck and relic.
- [ ] His sprite skin, portrait, spell palette (cuts and parries) and frame tint.
- [ ] A class unlock; the sim's bots taught to use branches.

Done when he wins within ten points of Vesper in the sim, and the player enjoys him.

### Stage 8: the Root, and reasons to replay

- [ ] Act 4: three keys, the Root, the Halting Oracle.
- [ ] Strictness levels `-W1` to `-W15`; card unlocks by class mastery; the Library complete; the Daily Build; run
      history as `git log`.

Done when a win opens the next strictness level and every class can beat the Oracle in the sim.

### Stage 9: Japanese everywhere, and Pip's Path

- [ ] Every screen through the catalogue; all content in Japanese; the language chosen on the title.
- [ ] Pip's Path: the grid world, blocks before typing, 20 to 30 lessons; play-tested with the daughters.
- [ ] Optionally, Pip and Acorn as a gentle Shardrun class.

Done when the whole game plays in Japanese and the daughters finish Pip's first chapter.

### Stage 10 and on

- **Academy**: the Programs, Algorithms (with the Card Workshop), Craft and Build tiers and their projects; the
  optional local tutor if the player wants one.
- **Shardrun**: Sai, Oren, Nyra, Ari, Lys and Aster; alternate acts (the Rootwood, the Archive, the Network); an
  endless mode; spell animations per role and paradigm.

## 6. Decisions that are yours

1. **Which first after stage 0**: the Shardrun fix (recommended: small, and you feel those problems now) or the
   Academy's foundation (if learning is the more urgent of the two)? They do not depend on each other.
2. **The learning mode's name**: "Academy" is a working name (others: Rootwork, the Grove, the Foundry). And does it
   take the Verifier's place on the title? (Recommended: yes, the Verifier's lessons move in.)
3. **The second class**: Kurogane (recommended: the most different playstyle and the most beginner concepts), Sai
   (graphs, the biggest spell show), or Oren (async)?
4. **The roster**: are the nine concepts in `Concept/newCharacters/` the classes, drawn as small, cute sprites the way
   Vesper is?
5. **The daughters**: their ages and reading (hiragana only, or kanji with furigana), and whether Pip's Path should
   come before stage 9.
6. **An AI tutor** in the Academy (local, optional, never needed): later, or never?
7. **How hard**: the win rate a good player should have. Recommended: about 50% on Beginner and 25% on Programmer for
   the smart bot, before strictness levels.
8. **Rest and forge**: one campfire choice (heal or refactor, recommended), or two rooms as now?
9. **The card Shardrun (deck playstyle)**: retire it once no run of it is underway (recommended), or keep it?
10. **Names and flavour**: cycles, the Registry, scripts, Issues, strictness levels, the Root Map, your version as
    rank. Keep, change, or throw out any.

## 7. Leave alone, or not now

- **Spellforge and the fixture-proven rules**: untouched (AGENT.md).
- **Emberfox in 3D** (Phase 6's first item): the sprite route won; parked unless you want it back.
- **The World** (towns, people, quests): later; the Academy's hub could become its first place.
- Multiplayer, accounts, cloud sync, monetisation, mobile, real-time combat, telemetry (AGENT.md).

## 8. How the numbers were made

`docs/research/balance-probe/` holds the probe script, the summary script, how to run them, and what the bots can and
cannot tell you (a one-turn lookahead with no memory of the draft's plan, a simple drafting rule, JavaScript and
Beginner only, no shop or events because none exist). The bots are a floor and a ceiling for a human, not a human.
