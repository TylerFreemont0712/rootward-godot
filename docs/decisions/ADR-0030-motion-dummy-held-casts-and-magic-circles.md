# ADR-0030: a motion dummy, held casts and magic circles in the air

- Status: accepted (the dummy, the lab, the new moves and the circle; the moves are a first pass, tuned by play)
- Date: 2026-10-01
- Related: ADR-0028 (VRM skins and the move library), ADR-0029 (the anime look), ADR-0008/0014 (spell sheets)

## Context

The player found the moves "way too stiff and awkward" and asked to perfect the animation style on a plain dummy
before putting skins on it. They also asked for magic circles in the isekai style: flashier, standing in front of the
caster rather than on her hand, staying while the bolts fly, and being where the bolts come from. And the wardrobe
had outgrown the screen (one card per look in a row ran off it).

Filmed on a mannequin, the old clips showed why they read stiff: dead holds (the same pose keyed twice), every joint
arriving at once (no overlap), an upright torso that never joined the strike, a back leg kicked up, and a long even
drift back to the idle. The cast also returned to the idle while its bolts were still leaving.

## Decision

- **A motion dummy** (`game/characters/dummy/`, built by `pipeline/blender/build_dummy.py`): primitives weighted
  wholly to the move library's own skeleton (tapered limbs between ball joints, a three-piece torso, segmented
  fingers, a visor for facing, the casting hand in teal), written as a normalised skin, so it imports and plays exactly
  as any skin. It is the review skin of `scripts/moves.sh` and a wardrobe look (*Motion Dummy*), for judging moves in
  a real fight.
- **The motion lab** (`scripts/motion-lab.sh`, `game/tools/motion_lab.tscn`): any clip on the dummy (or a 3D skin),
  with the cast's circle and a volley, 0.1x to 1x, frame steps and scrubbing, limited (15/s) or smooth, hand and head
  trails, and four camera angles.
- **Follow-through as data**: `follow` hangs a bone on a damped spring that chases its keyed pose
  (`"Hand": [7, 0.42]`, Hz and damping), and `lag` may be negative (a bone that leads: the hips fire before the
  chest). A `wave` layer moves one parameter on its own rhythm. The moves were re-keyed with them: a contrapposto guard,
  a coil-drive-push light cast whose hips lead and whose elbow leads the hand, and a gather-unfurl-crown-thrust heavy
  cast on the ground.
- **Casts are held**: `cast-light` and `cast-heavy` end in their push; `<cast>-hold` loops it while the volley flies
  and `<cast>-end` lets go when the stage calls `end_cast()` (at once if holding, else as soon as the push is reached).
  A cast's `charge` event marks the end of its coil: `release_in` slows only the coil to wait for a long circle, so
  the strike itself always snaps.
- **The magic circle** (`MagicCircle`) replaces the sigil sheets in a cast: drawn in code, additively, in the element's
  ramp, as a disc facing the foes (narrowed to 46% and leaning back), standing just beyond the palm at the strike. It
  writes itself on the old sheets' beats (so their sounds still land): rings drawn by two nibs, ticks, the spell's own
  function names as runes, a star ruled edge by edge, a core. Stronger tiers add a rune ring, a finer star and up to
  three smaller circles stacked in front. It stays turning while the volley lasts; every bolt is born on its front
  circle and makes it flare (a beam through the stack, a glint, sparks); it closes when the last bolt has left.
- **The wardrobe is a wheel**: the browsed look large in the middle, its neighbours smaller and dimmer, turned by
  arrows, the wheel, the keys or a click; Equip puts it on. It fits the 1920x1080 design size with room to spare.

## Consequences

- Moves are judged on the dummy first, then on skins; `scripts/moves.sh --reel` films the dummy by default.
- The old `cast-sigil-*` sheets stay in the repository (the spell sheet tests, and any later use) but no cast plays
  them; `cast-ground` still marks the strongest casts.
- Sprite skins (Vesper, Emberfox) are unchanged: they have no hold clips, and the circle works with their hand point.
- The new clips are a first pass. The motion lab is where the player says what still reads wrong.

## Amendment (2026-10-01, later): the idle, opened to the viewer

The player found the idle leaning at the enemy, a foot "broken", the lead hand open and tense, and asked for the body
turned more toward them. Measured first: the soles were level in the animation; the dummy's feet were wrong twice
over. Its foot blocks were built at the skeleton's toe joint, which on the VRoid skeleton sits at ankle height (14 cm
up), and its import had *fix silhouette* on (copied from an A-pose skin), which re-aims a T-pose skeleton's foot bones
and tipped the feet toes-up even at rest. The dummy now stands its feet on the floor and imports exactly as the move
library does (fix silhouette off).

The stance follows the references (Quaternius's CC0 idles rendered from the stage's angles; the stage's "cheat out":
the body opened halfway between the camera and the scene partner, only the head turned to them; idles are asymmetric,
weight on one foot, hands relaxed rather than splayed):

- turned about 20 degrees more toward the camera (torso about 33 degrees from it on the stage, the head about 56,
  looking at the foes), the casts still turning into the strike;
- the weight over the back leg, the free hip dropped and the shoulders tilted against it, nothing leaning at the foes;
- the lead hand hanging loose in front of the hip, fingers curled in a cascade (`cascade`, the index least, the little
  finger most), the rear arm hanging;
- a 4.8 s loop: alert breathing (25 a minute), a slow drift of the weight, a glance.

`tools/pose_views.tscn` shows a pose from four sides at once for this work (`ROOTWARD_REST=1` shows the model as
built).

