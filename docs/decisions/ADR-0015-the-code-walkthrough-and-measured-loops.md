# ADR-0015: the code walkthrough, and loops measured in the sandbox

- Status: accepted
- Date: 2026-09-26
- Related: ADR-0002 (the sandbox), ADR-0012 (programs), ADR-0013 (the card table)

## Context

The player: "would like a little more 'walk through the code' style, either with loops going through a quick iteration
or an animation that indicates it's a loop and the final result being shown. Also, the code block should be a little
more indicative and eye-catching... the number on the right could update with colors and numbers depending on the
spell's status. For bigger changes or bigger numbers a 'hit' style reaction... the code block should be a big part of
the cast interaction as well, not just a side piece."

The cast's playback lit only the Program's own lines (the seed, each call, the return). What happens inside a card, its
loops and its recursion, was invisible, and the sandbox knew nothing of it either.

## Decision

- **The sandbox measures loops and recursion**, for program runs only (`count: true` in the job; other runs are
  unchanged, which the old engine's fixtures prove). Python calls the card under `sys.settrace`, limited to the card's own
  file, and turns line counts into each loop's rounds (a loop's first body line runs once a round; a one-line
  comprehension's line once more than its rounds). JavaScript instruments the card on the same lines, so error line
  numbers stay the card's own: a counter right after each loop's opening brace (a one-line loop is wrapped in braces
  first), one at the top of each named function, and array methods that take a callback (map, filter, ...) counted per
  call. Both report `{loops: {line: rounds}, calls}` per stage; both give the same numbers for the same cards, and every
  card's worked examples are validated counted.
- **The walkthrough**: during a cast each call steps into its card's function (the first time that card runs) and walks
  its lines, comments passed over. A loop gets a bracket down its lines with a turning arrow; its body is walked for two
  rounds, then its rounds count up to the measured total, which lands with a pop sized to the number; loops inside it
  show their totals. A recursive function shows how often it was entered; the function's last return shows what it
  gave. Each function is paced to a budget (about 1.2 s at the normal code speed), so a long card walks faster.
- **The panel draws the eye while it runs**: it lights up in the paradigm's colour ("main.py ▶ running"), the stage
  dims until the code has run, the header's ops count up after each stage and pop, coloured green, amber once a foe's
  tempo is passed (the footer calls the foe out) and red past the budget, and the race's marker moves with them. Notes
  land like hits: they swell, flash and, for big numbers, shake.
- **The ward** (the block animation) is sized to cover the Maintainer and centred on them.

## Consequences

- Counting slows a card's run in the sandbox (a line tracer in Python); program volleys are small, and the limits hold.
- The walk is a walk of the code, not a replay of which branch was taken: the cursor passes every line in order; the
  numbers it shows (rounds, calls, results, ops) are all measured.

## Amended (2026-09-26): the volley, in colour

- A counted stage also reports its whole volley's power and elements (the trace keeps only its first bolts). The code
  panel shows it in a meter: a pip per bolt in its element's colour, sized by the bolts' strength, and the total power
  as a big number that counts up and lands like a hit after each stage.
- The running panel glows in the colour of the volley's element and takes the new colour, with a wash over the code,
  when a card turns the bolts to fire, frost or spark. Notes sit on a dark plate so they read over long lines.
