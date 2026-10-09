# Path 4: feel and look (animation, movement, skins, spell effects)

The direct answer to "would improving animation and getting everything down solid be more beneficial now rather than
later?": **solid now, pretty later**, with two exceptions. This path is a budget attached to the other paths, not a
project of its own.

## 1. Why not a polish pass now

- **There is already a lot of look.** Eight circle styles, five bolts and five impacts (the legendary set among them), 3D
  VRM skins on a Blender move library, painted backdrops for every ring, and art for most cards and creatures. Choice
  is not the gap.
- **The screens you would polish are about to change.** The Academy is being rebuilt (path 1), a second class adds
  branch cards to the fight's program panel (path 3), and the fight screen needs a beginner layout (path 2, section 5).
  Polishing them now means polishing them twice.
- **Visual work is expensive to get right here.** It needs your eye, so it converges slowly: the legendary looks took
  two redesigns and seven build-and-review rounds. Spend that kind of effort where it teaches, or where every player looks.
- **Game-development practice agrees**: juice the core loop early, polish late, and put polish where players spend
  their time.

## 2. Worth doing now

| Item | Why now | Cost |
|---|---|---|
| **Finish the Vesper v1.5 and v2 sprites you started** | Half-finished assets cost more than finished ones: they sit in the tree, uncommitted | Your own pace |
| **Acorn's movement in the Academy** (path 1) | The most important animation of the next month: the learner watches it to understand code. It must step crisply, one tile per line, with a little anticipation, and stop exactly where the code says | Part of path 1's slice 1 |
| **Reduced motion for the ordinary hit sheets** | Accessibility; the legendary looks follow the setting and the old blows do not | Small (in path 2's must-fix list) |
| **The first ten minutes** | Pip's Trial and the first fight are what the daughters see first. One feel pass there: every action has a sound, every hit reads, the end of a turn is clear | One feel pass, about half a session |
| **Sound gaps** | `sfx-cast-layer` and per-cast snap and strike sounds are still open in `PLAN.md`. Sound is the cheapest feel there is | Small, through `pipeline/audio` |

## 3. Defer, and when to come back

| Item | Come back when |
|---|---|
| More circle, bolt or impact styles | Never as a goal of its own; a new class brings its own |
| More VRM skins | One skin per class, made with that class |
| Bezier keys, 60 fps export and the cast-skyward and cast-slam spikes in the move library | An evening in the motion lab, when you have one; real, but low priority |
| Spell animations per role and per paradigm (open in `PLAN.md`) | After Kurogane's parry and riposte exist, so the set is designed for two classes, not retrofitted |
| The legendary looks' leftovers (the unverified inflow arms) | Only if you notice them in play |
| A 3D walk in the Academy | After the 2D lane is fun (path 1, slice 3) |

## 4. "Movement" means two things here

- **Character moves** (the shared move library, ADR-0028): mostly done. What is left is a judgement in the motion lab,
  not a build.
- **Walking** (the Academy's town): part of path 1, slice 3. Keep it small, one lane and then one hamlet, and make it
  responsive before it is pretty: no acceleration lag, a clear door prompt, no getting stuck on tiles.

## 5. The budget rule

Give each slice of any path one feel pass at the end, about 15% of its time:

1. Every player action has a sound and a visible response within a tenth of a second.
2. The thing the player should look at moves or glows; nothing else competes with it.
3. Hits read: a short pause on impact (hit-stop), a recoil, a number. Shake only with reduced motion off.
4. Transitions do not leave a blank frame.
5. Text fits in English and Japanese at 1280 by 720 and at 1920 by 1080.
6. A screenshot of the slice's best moment, looked at before the slice is called done.

## 6. When polish becomes the priority

When the Academy's chapter 1 plays end to end, Kurogane is in, and someone other than you has played both. That is
"content complete" for this stage, and then a full polish pass is worth more than anything else, because nothing under
it is about to change.
