# Moves: the clips every VRM skin plays (ADR-0028, ADR-0031)

The clips are **motion capture first** (ADR-0031): each plays takes from a CC0 capture library (`mocap/`, named in
`sources.json`), retargeted in Blender onto our skeleton (`pipeline/blender/retarget.py`), with our own keys layered
on top: small offsets (turn the head toward the foes, relax the hands) or, on a clip's `own` bones, a hand-keyed
gesture over the captured body (the finger snap). A clip without `mocap` is keys alone, as before.

| Clip | Capture | Our layer |
|---|---|---|
| `idle-breathe` | `Idle_Loop` | body a touch toward the foes, head toward them, hands relaxed and drifting |
| `cast-light` | `Idle_Loop` | the lead arm owns a finger snap: raise, cock, snap (the release), ease back |
| `cast-heavy` | `Idle_Loop` → `Spell_Simple_Enter` → `Spell_Simple_Idle_Loop` → `Spell_Simple_Shoot` | both hands gather at the chest first; the body opens and leans into the push |
| `cast-heavy-hold`, `cast-heavy-end` | `Spell_Simple_Idle_Loop`, `Spell_Simple_Exit` → `Idle_Loop` | leaning in, then settling back |
| `hurt`, `death` | `Hit_Chest` → `Idle_Loop`, `Death01` | relaxed hands |
| `guard` | `Idle_Loop` | both arms own crossed forearms |

Each clip is data: takes, then keys on a timeline, each key a pose, each pose readable numbers. `motion.py` samples a clip frame by
frame (pure Python, tested by `python3 -m unittest discover -s pipeline/moves`); `pipeline/blender/build_moves.py`
turns each frame into bone rotations on a VRoid skeleton and exports `game/characters/moves/rootward.glb`, which
Godot retargets onto every VRM skin through its humanoid profile.

```sh
scripts/moves.sh            # tests, build (~20 s), import, review sheets in shots/moves/ (on the motion dummy)
scripts/moves.sh --reel     # also films every clip in Godot (springs included): shots/moves/reel.mp4 / reel.gif
scripts/motion-lab.sh       # every clip on the dummy, live: slow motion, frame steps, limited/smooth, trails, circle
```

Moves are judged on the **motion dummy** first (ADR-0030; `pipeline/blender/build_dummy.py` builds it on the same
skeleton, so it plays exactly as any skin), then on the skins.

## Where she stands

The rest pose is the VRM T-pose. On the stage she is turned 35 degrees toward the foes, who are **on her left**:
an arm that reaches to her left and about 35 degrees forward points at them. Turning the torso toward them (`turn`)
swings that arm backwards, so add the torso's turn to the arm's `forward`.

## Parameters (degrees and metres, 0 = the T-pose)

| Bones | Parameter | Positive means |
|---|---|---|
| `Hips` | `lift`, `forward`, `side` (m) | up; toward her front; toward her left |
| `Hips`, `Spine`, `Chest`, `UpperChest`, `Neck`, `Head` | `bend`, `lean`, `turn` | bow forward; lean to her left; turn to face her left |
| `Shoulder` | `raise`, `forward` | shrug up; roll forward |
| `UpperArm` | `raise`, `forward`, `twist` | above level (-72 is at her side); swing to the front; palm turns forward |
| `LowerArm` | `bend`, `twist` | elbow bends; palm turns forward |
| `Hand` | `bend`, `side`, `twist` | toward the palm (negative lifts the fingers: a pushing palm); toward the thumb |
| `Hand` (fingers) | `curl` (0..1), `cascade` (0..1), `spread`, `point`, `vee`, `thumb` | a fist; the little finger curled more than the index (a relaxed hand); fingers fanned; index straight; index and middle straight (a V); thumb curled |
| `Hand` (one finger) | `index`, `middle`, `ring`, `little` (0..1), `oppose` (degrees) | that finger's curl outright; the thumb swung across under the palm (to press the middle finger for a snap) |
| `UpperLeg` | `lift`, `spread`, `twist` | thigh forward; outward; knee turns out |
| `LowerLeg` | `bend` | knee bends (foot goes back) |
| `Foot`, `Toes` | `point`, `bend` | toes down |

A bone without a side (`UpperArm`) sets both sides; the right mirrors the left. `"base": "float"` starts from a
named pose in `poses.json` and replaces or adds parameters bone by bone.

## A clip (`clips/<id>.json`)

- `mocap`: takes `[{"source", "action", "from", "to", "speed"}]` played one after another, crossfaded over `blend`
  seconds. In a mocap clip the keys and layers are **offsets** on the capture, except:
- `own`: `{"bones": [...], "weight": [[t, w], ...]}`: those bones are posed outright by the keys, by a weight that
  rises and falls (at 0, the capture alone). An owned bone a key leaves out holds its pose from the nearest key.
- A hand given finger parameters has its fingers keyed instead of captured, by `fingers` (`[[t, w], ...]`).

- `length`, `loop`; `events.release` (seconds: when the palm goes through the sigil) and `hand` for casts.
- `keys`: `{"t", "pose", "ease"}`; the ease is how the key is arrived at. `back_out` overshoots and settles,
  `expo_out` snaps, `cubic_out` arrives fast and eases in, `back_in` pulls back first, `hold` jumps, `sine` flows.
- `lag`: bones sampled late, so they follow through (`"Head": 0.05`, `"Hand": 0.05`, `"Foot": 0.08`).
- `follow`: a bone on a damped spring that chases its keyed pose (`"Hand": [7, 0.42]`: Hz, damping below 1
  overshoots): when the body stops, the hand carries on and settles. A negative `lag` makes a bone lead (`"Hips":
  -0.03`: the hips fire before the chest, the chest before the arm).
- `step`: `[{"from", "to", "frames": 2}]` holds each drawing two frames: the anime staccato around a big moment.
- `layers`: `breathe`, `bob`, `sway`, `tremble` (with `from`/`to` to window them), and `wave` (one bone's parameter
  on its own rhythm: `{"kind": "wave", "bone": "LeftHand", "param": "bend", "amp": 5, "period": 1.6}`).
- `plant`: feet are held on the floor for the whole clip by default (the build solves the legs); a clip lists windows
  for a foot that leaves it: `{"RightFoot": [[0, 0.6], [1.02, 1.3]]}`. Keep `Hips.lift` at or below 0 unless a
  foot is unplanted: a lower hip bends the knees.
- `face`: `[{"t", "expression", "weight"}]`, the VRM's own expressions (`happy`, `angry`, `sad`, `surprised`, ...).

Hair, skirts and capes are not keyed: the skin's spring bones move them in Godot, which is why a spin or a snap
looks alive. The stage rescales a cast's speed so its `release` lands on the sigil's blow (0.62 to 1.23 s).

## What makes a move read as fantastical (the checklist used here)

1. **Anticipation**: pull away before the move (`windback`, `gather`); the bigger the move, the bigger the pull.
2. **Snap and overshoot**: arrive at the strike with `back_out`/`expo_out`, not `sine`.
3. **Hold the big moment**: a few frames still at the release, stepped on twos, with a tremble while charging.
0. **Start from real motion**: a capture take, layered; key by hand only what no capture has (the snap).
4. **Follow-through and overlap**: `follow` springs on the hands, forearms and head; the hips lead (negative `lag`),
   the elbow leads the hand; let the skin's springs finish the hair and cloth.
7. **No dead holds**: a held moment drifts between two near poses (`push_hold` → `push_hold_b`), never one pose twice.
5. **Weight and ground**: feet planted, weight shifting between them; leave the ground only for a real jump (unplant,
   lift, spin with `Hips.turn` 0 to 360, land and re-plant).
6. **Silhouette**: check every key in `shots/moves/*.png` at the stage's angle; the arm must read against the body.
