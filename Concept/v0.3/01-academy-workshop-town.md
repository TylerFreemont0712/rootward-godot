# Path 1: the Academy, rebuilt as a workshop town where your code does things

The recommended next piece of work. It keeps what Lanternroot gets right (real code, tests as the specification, the
Night Watch, a town that grows) and replaces what makes it feel like a terminal.

## 1. What is wrong with what exists

- **The mockup** (`Concept/v0.2/Academy/Academy-Mockup.md`) is a good curriculum with a menu in front of it: three
  routes, a skill map, a lesson in eight steps. It describes what to learn, not what you do.
- **Lanternroot** is the right idea in the wrong clothes. The town is a still picture with a list beside it, and the
  work is an editor beside a letter. Your code never visibly does anything; a lantern turning on is the only proof.
- **The walkable hamlet proposal** (`docs/WALKABLE_HAMLET.md`) adds somewhere to walk, but the walking is a menu too:
  you walk to a door to open the same editor.

What all three miss is the thing every successful programming game has: **you watch your program act**, and the
acting is the fun.

## 2. The idea

You are the new tinker in Lanternroot, and you have an apprentice: **Acorn**, a lantern sprite in a clockwork shell
(the Acorn of `Concept/newCharacters/chibi-small/07-acorn-ward-sprite.png`). Acorn does exactly what your code says, one
line at a time, in front of you. A loop is Acorn walking the same lane again. A variable is a jar on the workshop
shelf, with its value written on the label. A function call is Acorn running an errand to another house. A `return` is
Acorn handing a parcel to the villager who asked. An exception is Acorn tripping over.

Every job ends with Acorn doing the job in the town, using your code, while the line it is on glows in the editor.

This is what the best programming games share: Human Resource Machine's office worker walking each instruction, The
Farmer Was Replaced's drone working a field your loops drive, and CodeSpells' spells written in real Java. The first two
use languages of their own; Rootward, like CodeSpells, uses the real thing, Python and JavaScript in a sandbox, so what
the learner writes is what they will write outside the game.

## 3. The pillars, and why each one teaches

| Pillar | In the town | Why it teaches |
|---|---|---|
| **Watch it run** | Acorn acts out each line; jars show variables; the current line glows; play, step, slow down, scrub back | Beginners' mistakes mostly come from a wrong picture of what the computer does (the "notional machine"). Seeing it act corrects that picture early, which is cheaper than fixing it later |
| **Predict before you run** | Each job opens with someone else's code and a question: where will Acorn stop, what parcel will it hand over? Place your guess, then run | PRIMM (predict, run, investigate, modify, make) gave pupils better results than ordinary lessons in a 493-pupil school study. Reading before writing is its core |
| **Help you choose** | Planks: the lines of a solution as wooden planks to arrange on the bench. Then planks with gaps. Then a blank file | Parsons problems as optional help made students more efficient in practice with no loss on the final test |
| **Things wear out** | Days later, a mechanism you built rusts: the function is reduced to its name and its letter, and you rebuild it from memory | Spaced practice and practice testing are the two strongest study techniques in the learning-science reviews. Rust is retrieval practice in the fiction |
| **Break it** | A rival tinker brings code that passes the examples but is wrong. Find the input that breaks it | Writing the test that catches a bug is how real programmers think. It is also the seed of the Sec Ops and Red Team tracks in your mockup |
| **Make it better** | Three seals per job: the lantern (it works), the ribbon (it is short and readable), the gear (it does little work). A histogram shows where your solution sits | Zachtronics' histograms turn one solved puzzle into several self-set goals. Rootward already measures work |
| **The town runs** | At a chapter's end, a festival day plays every function you wrote together, and the villagers use them | Composition, and the payoff: your program, visibly alive |

The Night Watch, storms (property tests), fog (write your own tests) and the almanac (every night a commit) stay as
`docs/LANTERNROOT_DESIGN.md` describes them. They fit this design without change.

## 4. One job, minute by minute

Bramble's lamps along the long lane went out.

1. **The ask.** Bramble waves you over. The job card shows the lane, the lamps, and the four things Acorn knows how to do
   so far: `step()`, `turn_left()`, `turn_right()`, `light()`.
2. **Read first.** The old tinker's notebook has a program for half the lane. *Where does Acorn end up?* You put a
   marker on a tile and press run. Acorn walks, lights two lamps and stops one tile short of your marker. The line it
   stopped on glows. You now know what `for _ in range(3):` does, from watching it.
3. **Investigate.** Step through it. The jar `_` on the shelf counts 0, 1, 2.
4. **Change it.** *Light all five lamps.* You can ask for planks: the lines of an answer, out of order, to arrange. Or
   write it.
5. **Make one.** The next lane bends. Write it from a blank file; the planks are still there if you want them.
6. **Seals.** The lantern lights. A ribbon if it is six lines or fewer. A gear if Acorn takes the fewest steps. The
   histogram shows other solutions (the reference, and the variants the content's checker generated).

The job takes five to ten minutes, and the learner wrote, read, predicted and debugged a loop without a lecture.

## 5. Kinds of job

| Job | What you do | Introduced |
|---|---|---|
| **Errand** | Drive Acorn with commands: sequence, loops, conditions on what Acorn sees (`if lamp_ahead():`) | Chapter 1, day 1 |
| **Letter** | Write a function that returns a value, checked by examples and the Night Watch (Lanternroot today) | Day 3 |
| **Repair (rust)** | Rebuild a function you wrote days ago, from its name and its letter | Day 4 on, one each morning |
| **Bug hunt** | A villager's own code fails with a traceback. Find the line, fix it, add the test that would have caught it | Day 4 |
| **Break it** | The rival's code passes the examples. Write the input and the expected value that break it | Day 5 |
| **Festival** | Many functions together; the town plays your code as a scene | End of each chapter |
| **Golf** (optional) | The same job again, for the ribbon or the gear | Any time |

The morning board mixes them: usually one new job, one repair and one optional challenge. Mixing old and new is
interleaving, and it keeps old ideas alive without a review screen.

## 6. Chapter 1, concretely: "The lamps of Lanternroot"

| Day | Jobs | Ideas | Acorn learns |
|---|---|---|---|
| 1 First Light | Wake the workshop (sequence); the short lane (sequence, predict first); planks only for the youngest | Statements run in order | `step`, `turn_left`, `turn_right`, `light` |
| 2 The Long Lane | The long lane (`for` and `range`); the lane with gaps (loop with a condition); golf: the fewest lines | Loops, counting, `if` inside a loop | `lamp_ahead()` |
| 3 Mabel's Bakery | How many loaves? (the existing letter, now with jars and a parcel); the week of bread (accumulator) | Functions, parameters, `return`, rounding up | Carry a parcel |
| 4 Quill's Post | Stamps by weight (`if/elif/else`, boundaries); a bug hunt (Quill's own code, off by one at 100 g); first repair | Conditions, boundaries, reading a traceback | Weigh, stamp |
| 5 The Rival | Fennick's postage passes the examples; break it. Then Bramble's basket, with an import bridge | Edge cases as tests; modules and imports | Cross a bridge |
| Festival | The lamps, the bread and the post run together for the festival; the Night Watch walks after | Composition; regressions | Everything |

Days 3 to 5 reuse the ten Lanternroot letters that exist. Days 1 and 2, the errands, are new, and they are what a
complete beginner (or a daughter) meets first.

## 7. The three routes, from your mockup

- **First Steps (the youngest; Japanese first).** Errands with picture planks: arrows and lamps instead of words, the
  way Viscuit (a Japanese picture-programming tool for children from age four, recommended by the education ministry)
  works without letters. Then the same planks with their Python words underneath, then typing. No rival and no gremlins
  until they want them. Japanese schools have taught programming ideas this way since 2020, so the vocabulary will be
  familiar.
- **Guided (the default).** The chapter as written above.
- **Grow (some experience).** The tinker's test: a district whose mechanisms are all broken. Repair it fast enough and
  the chapter is stamped done, so you skip ahead without a quiz.

All three share one map, the town's villages, so changing route never loses progress.

## 8. The bridge to the Shardrun, keeping power separate

- **Stamps explain cards.** A card whose code uses an idea you have stamped gets an "Explain" page that links back to
  the job where you learned it ("Prefix Sum: you built this at the Mill on day 9").
- **Practice ring.** In the Academy, a training dummy runs any card you own, slowly, with Acorn and the jars, so you can
  read a card's code by watching it.
- **Rewards are cosmetic.** Card backs, titles, workshop decorations and Acorn's hats show up in the station and the
  fight, as your mockup wanted. Lessons never give combat power.
- **Later, Pip and Acorn.** The gentle Shardrun class in `docs/SHARDRUN_DESIGN.md` can reuse Acorn and the errand
  commands, so the youngest move from the town to a gentle run with a friend they know.

## 9. What it builds on (most of it exists)

| Need | What exists | What is new |
|---|---|---|
| Running the learner's code | The sandbox, Lanternroot's watch (`game/sandbox/lanternroot/`) | An errand API module per language that records actions |
| A log the town plays back | The Shardrun's pattern: rules make a log, the stage animates it (`log_player.gd`) | An errand log and a town player |
| Lines as they run | The harness already traces Python lines with `sys.settrace` and rewrites JavaScript loops to count them | A capped step trace with variable values (Python first; JavaScript needs statement-level rewriting) |
| Tests and advice | `lantern_rules.gd`, `lantern_advice.gd`, the Night Watch | Predict checks, planks, break-it grading (the rival's code must fail and the reference must pass) |
| The town | `town_painter.gd`, `town.jsonc`, the walkable hamlet design | A grid lane for errands, Acorn, villagers |
| Validation | `scripts/validate.sh` runs every worked example | A job validator: the reference passes, the starter fails, the planks have one order, the rival fails the hidden case |
| Japanese | Overlays keyed by English | The same, for jobs and planks |

**The look is your call.** Three options: the game's painted finish for a top-down lane (best, slowest); Kenney's Tiny
Town tiles already on disk (fast, and a clear clash with the painted anime finish); or painted top-down tiles made once
with ComfyUI, then reused (the middle way, and the one I would pick).

## 10. Slices

Each slice ends with you playing it, and a written verdict, before the next starts.

1. **Acorn's first lane** (2 to 3 sessions). One screen: the workshop and one lane on a tile grid, Acorn, the errand API
   in Python, the action log and its playback with the line glowing, predict first, planks, the three seals. Three
   errands (days 1 and 2). Done when you play it start to finish and want a fourth errand.
2. **Watch a function** (2 sessions). Jars (the step trace with values) on the existing letters; the parcel; bug hunts;
   break it against the rival; the histogram. Done when the ten existing letters play this way.
3. **The town around it** (2 to 3 sessions). The walkable hamlet's first lane with villagers who bring jobs, the morning
   board with rust, the Night Watch walking, and the first festival. Done when chapter 1 plays end to end in Python and
   JavaScript.
4. **The youngest** (2 sessions). Picture planks, Japanese first, no gremlins. Done when a daughter finishes an errand
   without help.
5. **Later.** Mosslight (data structures, houses that grow rooms as classes), Emberdeep (algorithms with work budgets,
   the bridge to the Shardrun's paradigms), Gearhollow (refactoring and errors), and the specialty previews from your
   mockup (Sec Ops and Red Team grow out of "break it"; AI engineering out of the Mill's data jobs).

## 11. Risks, and how this avoids them

- **A world before the lessons work.** Your mockup names this as the largest risk. Slice 1 is one screen; walking comes
  in slice 3, after the jobs are fun.
- **JavaScript tracing is harder than Python's.** Errands work in both from slice 1, since an action is a call; values
  in jars come to JavaScript later. The town says which language a feature needs.
- **Content cost.** Each job is data plus a reference, a starter, planks and tests, in two languages, with Japanese. The
  job validator, and writing planks from the reference automatically, keep that affordable.
- **Too easy, or too hard, for the daughters.** Slice 4 does not start until they have tried slice 1 with you.
- **Hints that give answers.** The rule stays: hints and planks teach the next idea; a full solution is never shown.

## 12. What not to build

- An AI tutor, a large open world, accounts or online leaderboards (histograms come from reference and generated
  variants, offline).
- New Shardrun content in the same sessions. This path is big enough on its own.
