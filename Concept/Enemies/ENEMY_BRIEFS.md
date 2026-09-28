# Enemy concept briefs

Fifteen new foes for a longer Shardrun (four or five layers instead of three), each a real bug or hazard whose mechanic
does to your *program* what that bug does to code (`docs/SHARDRUN_DESIGN.md`, section 6). Concept art for every one is
in `concepts/` (three candidates each, rendered on 2026-09-28 with the art pipeline's creature style), and the picked
candidate is already a game-ready sprite at `game/assets/foes/<id>.png`, so wiring one in is content plus its mechanic.

The first seven are the original visual briefs (kept word for word under "Look"); the other eight come from the design
bible's bestiary. Numbers are starting points in the foe files' units (HP before the layer's multiplier), to be tuned
with the balance probe like everything else.

`concepts/overview.png` shows the fifteen at a glance, one candidate each: the one that became the sprite. The picks
(candidate numbers, as in the file names): Mantis 2, Tortoise 1, Moth 0, Hare 0, Stag 2, Raven 2, Crab 1, Slime 1,
Hound 0, Monolith 2, Hydra 0 (its head 1), Wyrm 0, Hoarder 2, Scheduler 2, Oracle 1.

**Second pass (2026-09-28).** Three had drifted from their brief. Each got two more rounds of prompts:

- **The Hare** is now a glazed ceramic nesting doll whose back opens on a smaller hare inside: recursion you can see.
  The first pass (an armoured rabbit knight with no afterimages) is replaced; no prompt produced afterimages.
- **The Hydra** is built from parts, as its mechanic is: the body keeps the first pass (a coil of cable-necked
  snakes, `11-spaghetti-hydra-*`), and a head of its own (`11-spaghetti-hydra-head-*`, a snake head on a black cable
  neck with a plug for a tongue, sprite `foes/spaghetti-hydra-head`) is drawn once for each of its three heads. The
  image model would not draw a headless knot of cables: every "body" came back a creature.
- **The Wyrm** keeps its first pass. Asked for a head alone or a lone segment, the model drew whole dragons, or small
  armoured figures. When it goes in, its five segments should be five foes sharing one segment sprite that the stage
  draws apart (the parts approach the Hydra uses), and that sprite is better modelled in Blender than prompted.

## Where they go

| Layer | Place | New foes |
|---|---|---|
| 1 | The Salvage (exists) | Syntax Slime, Needlecap Mantis; guardian: The Monolith |
| 2 | The Heap (exists) | Recursive Hare, Shardshell Tortoise; elite: Archive Crab; guardians: Fragmentation Wyrm, The Hoarder |
| 3 | The Kernel (exists) | IRQ Hound, Scrollback Raven; guardian: The Scheduler |
| 4 | The Rootwood (new) | Scriptwing Moth, Glassback Stag (elite), the forest's returning Mantis and Hare; guardian: Spaghetti Hydra |
| 5 | The Root (new, the finale) | The Halting Oracle |

The Rootwood is where the Machine's roots grow into an old forest: the creatures of the original briefs live there,
half animal, half code. With five layers the Root is the last one; with four, the Oracle waits at the bottom of the
Rootwood instead.

## The fifteen

| # | Foe | Layer, kind | The bug | What it does to your program | The counter |
|---|---|---|---|---|---|
| 1 | Needlecap Mantis | 1 and 4 | two pointers from both ends | its crossed blades cut the first and the last bolt of your volley before they land | pad both ends with weak bolts; a one-bolt volley loses its only bolt |
| 2 | Shardshell Tortoise | 2 | encapsulation | gains 2 shield for every bolt in your volley before the bolts land | few, big bolts (Reduce, Take Max, Huffman) |
| 3 | Scriptwing Moth | 4, support | minified code | while it lives the other foes' intents are hidden (`?`); heals them 4 a turn | find it and break it first |
| 4 | Recursive Hare | 2 and 4 | recursion | a hit that does not kill it splits it into two hares of half its HP; at 4 HP or less it cannot split | the base case: one bolt that kills outright, or area damage for the leaves |
| 5 | Glassback Stag | 4, elite | a build pipeline | compile, test, deploy: after three turns its charge hits for 40; 25 damage in one program breaks the build and resets it | burst on a deadline |
| 6 | Scrollback Raven | 3 | revert | at the end of a turn it heals all the damage it took that turn, unless that was half its HP or more ("uncommitted changes") | commit: burst it |
| 7 | Archive Crab | 2, elite | an index | takes 50% more from a volley that lands sorted, half from one that does not | sort before you strike (Merge Sort, Prefix Sum, Bisect Insert) |
| 8 | Syntax Slime | 1 | errors that multiply | below half HP it splits in two; the halves put a Null Pointer bug card in your discard pile | burst it past half in one program |
| 9 | IRQ Hound | 3 | interrupt storm | 2 damage to you for every card of your program past the third | short programs (Unix Philosophy loves it) |
| 10 | The Monolith | 1, guardian | legacy code | shuffles a Legacy Code bug card into your draw pile every turn; grows while it is left undamaged | scaling, and cards that clear bugs |
| 11 | Spaghetti Hydra | 4, guardian | tangled dependencies | three heads and a body: a head cut off grows two unless the same program also hits the body | programs that hit several targets (Round Robin, Load Balance, Sweep) |
| 12 | Fragmentation Wyrm | 2, guardian | fragmented memory | five segments; a segment breaks only to a run of neighbouring bolts that sums past its HP | contiguous power: Prefix Sum, Kadane, Split then Amplify |
| 13 | The Hoarder | 2, guardian | a hoarding collector | every point of wasted power (overkill, or a bolt at a foe already down) becomes its shield | exact kills: Binary Execute, Knapsack Strike, Linear Search |
| 14 | The Scheduler | 3, guardian | time slicing | each turn it gives one foe priority (tempo 1, it always moves first) and summons a Thread | speed, and breaking the priority foe first |
| 15 | The Halting Oracle | 5, the final guardian | the halting problem | each turn it predicts one thing about your program ("fewer than 8 bolts", "slower than O(n)", "aimed at me") and reflects the damage if it is right | write the program it did not predict: the diagonal argument, played |

## Each foe

**1. Needlecap Mantis** (`concepts/01-needlecap-mantis-*.png`)
Look: A lean, upright insect duelist with quill-like forearms and a narrow amber eye. Crossing its arms leaves two bright
cutting lines in the air.
Numbers: medium, HP 26, tempo 24 (it is quick). Intents: strike 6, "cross" (the cut, then strike 4), shield 5.
Needs: a program hook after the run (remove the first and last attacking bolts).

**2. Shardshell Tortoise** (`concepts/02-shardshell-tortoise-*.png`)
Look: A squat defensive creature whose broad shell is layered from dark stone, roots, and translucent spell shards.
Cracks of teal light show through when it braces.
Numbers: large, HP 44, tempo 160 (slow). Intents: brace (the per-bolt shield this turn), strike 9, strike 7.
Needs: a hook after the run that reads the volley's size.

**3. Scriptwing Moth** (`concepts/03-scriptwing-moth-*.png`)
Look: A hovering support foe with broad parchment-pale wings, dark ink-like markings, and a soft halo of colored dust. Its
wing pattern suggests diagrams without readable writing.
Numbers: small, HP 18, tempo 32. Intents: heal allies 4, minify (hide intents), strike 3.
Needs: hidden intents in the view (the race bar and the foe panels show `?`).

**4. Recursive Hare** (`concepts/04-recursive-hare-*.png`)
Look (original brief): A long-legged forest hare with nested ceramic plates and small afterimages that repeat its pose.
Its silhouette should feel quick and uncanny rather than serpent-like. Look (second pass): a glazed ceramic nesting-doll
hare whose back opens on a smaller hare inside; its splits are the smaller dolls.
Numbers: medium, HP 32, tempo 20. Intents: kick 5, kick twice 3 × 2.
Needs: summons (a split spawns two foes with the remaining HP halved), in the rules' own resolve.

**5. Glassback Stag** (`concepts/05-glassback-stag-*.png`)
Look: A tall guardian with branching crystal antlers, a dark bark body, and a luminous teal chest shard. It gathers light
between its antlers before a straight charge.
Numbers: huge, HP 90, tempo 256 (the charge is slow; its jabs are not). Intents: compile, test, deploy (40), gore 8.
Needs: a charging intent with a break threshold, shown as a countdown.

**6. Scrollback Raven** (`concepts/06-scrollback-raven-*.png`)
Look: A sharp folded-paper bird with layered slate and violet wings, a bright amber eye, and a trail that curls back on
itself as it flies.
Numbers: medium, HP 34, tempo 40. Intents: peck 6, dive 9, revert (heal what it took this turn).
Needs: damage taken per turn on the foe, and an end-of-turn hook.

**7. Archive Crab** (`concepts/07-archive-crab-*.png`)
Look: A heavy guardian built from overlapping ceramic book plates and root-wrapped stone. One broad claw carries a
circular ward; the other grips a cluster of broken spell shards.
Numbers: large, elite, HP 70, tempo 96. Intents: ward 10, pinch 8 × 2, index (next turn it reads your volley twice).
Needs: a landing multiplier that reads whether the volley arrived sorted (ProgramRelics already computes it).

**8. Syntax Slime** (`concepts/08-syntax-slime-*.png`)
A cute jiggly slime of glowing code brackets and semicolons, splitting at its edges.
Numbers: small, HP 24, tempo 48. Intents: splash 4, ooze (a Null Pointer into your discard).
Needs: summons and bug cards (status cards in your deck).

**9. IRQ Hound** (`concepts/09-irq-hound-*.png`)
A lean mechanical hound with antenna ears, red warning lights and an alarm siren on its back, throwing sparks.
Numbers: medium, HP 30, tempo 12 (the fastest thing in the Kernel). Intents: bark (the interrupt tax this turn), bite 7.
Needs: a hook before the run that reads the program's length.

**10. The Monolith** (`concepts/10-the-monolith-*.png`)
A towering stone monolith golem, carved with glowing runes and moss, tiny eyes, old cables hanging from it.
Numbers: huge, guardian, HP 140, tempo 384. Intents: shuffle Legacy Code, slam 12, grow (+10 HP if untouched).
Needs: bug cards; damage-taken-this-turn on the foe.

**11. Spaghetti Hydra** (`concepts/11-spaghetti-hydra-*.png`, and its head, `11-spaghetti-hydra-head-*.png`)
A hydra whose necks are tangled, knotted cables, each ending in a small angry snake head. Built from parts: the body,
and one head sprite drawn for each head, so a head cut off (or grown back) is a foe of its own.
Numbers: huge, guardian, a body of 120 HP and three heads of 20. Intents per head: bite 5; the body: coil 10.
Needs: multi-body foes (parts that share a fate) and a rule that reads which parts a program hit.

**12. Fragmentation Wyrm** (`concepts/12-fragmentation-wyrm-*.png`)
A long serpent wyrm whose body is broken into separate floating armoured segments, violet joints glowing in the gaps.
Numbers: huge, guardian, five segments of 30. Intents: constrict 10, tail 6 × 2, defragment (a broken segment returns).
Needs: segments as parts, and a landing rule over runs of neighbouring bolts.

**13. The Hoarder** (`concepts/13-the-hoarder-*.png`)
A fat, greedy goblin-dragon on a hoard of broken glowing shards and scrap, gold teeth, a greedy grin.
Numbers: huge, guardian, HP 160, tempo 256. Intents: swipe 11, hoard (its shield is half the waste so far), belly 6 × 3.
Needs: waste counted per program (the rules already count it) fed into the foe's shield.

**14. The Scheduler** (`concepts/14-the-scheduler-*.png`)
A clockwork automaton with a clock face for a head and many thin arms, each holding a small hourglass.
Numbers: huge, guardian, HP 150, tempo 128. Intents: time slice (priority to one foe), fork a Thread (a small summon),
preempt 14.
Needs: per-turn tempo overrides and summons.

**15. The Halting Oracle** (`concepts/15-halting-oracle-*.png`)
A cosmic floating eye inside rotating rings of sigils and an endless looping ribbon of light.
Numbers: colossal, the final guardian, HP 400, tempo 64. Intents: predict (one property of your next program, shown),
gaze 16, loop forever (a strike that repeats while its prediction holds).
Needs: a prediction intent with a small set of checkable properties (volley size, speed class, targets) and a reflect.
