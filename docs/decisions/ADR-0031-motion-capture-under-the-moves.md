# ADR-0031: motion capture under the moves

- Status: accepted
- Date: 2026-10-01
- Related: ADR-0028 (the move library), ADR-0029 (limited animation), ADR-0030 (the dummy, the circles)

## Context

The player asked whether the moves were made in Blender or "just mathematical ideas". They were numbers: every pose
written as parameters and baked by a script, judged from renders. Hand-keyed that way they read as stiff, keyed too
hard, and choppy (limited animation at 15 poses a second). Shown Quaternius's CC0 *Universal Animation Library*
rendered from the stage's angle, the player picked its `Idle_Loop` as the stance and its `Spell_Simple` set as the
heavy cast, asked for the light cast to be a finger snap, smoother playback, and no victory clip. They also asked about
World of Warcraft's animations.

## Decision

- **Clips play motion capture first.** `pipeline/moves/sources.json` names a capture file, a frame where it stands in
  a T-pose and its bones by our profile names; `pipeline/blender/retarget.py` copies each bone's turn away from that
  T-pose onto ours (`ours(t) = theirs(t) · theirs(T)⁻¹ · ours(T)`, world space) and the pelvis's travel scaled by hip
  height. Quaternius's library (CC0, 7.6 MB) is committed in `pipeline/moves/mocap/` so the build needs no download.
- **Our keys are layers on the capture**: offsets by default; a clip's `own` bones are posed outright by a weight
  curve (the snap's arm over the breathing idle); keyed fingers replace the capture's by a `fingers` weight. Named
  poses are now small layers (`idle_offsets`, `snap_*`, `gather`, `thrust`...), not whole bodies.
- **The set**: the idle (`Idle_Loop`, turned a touch toward the foes, head toward them, hands relaxed); the light cast
  is a snap (its circle appears on the snap and writes itself 1.5 times faster, with sparks from the fingers; no hold);
  the heavy cast gathers at the chest, then plays `Spell_Simple_Enter`/`Idle`/`Shoot`, held with `Spell_Simple_Idle`
  and let go with `Spell_Simple_Exit`, and gets at least the third circle; hurt is `Hit_Chest`, death `Death01`, guard
  a keyed layer. Victory, windup and channel are gone (a 3D skin stays in its idle on a win).
- **Smooth by default.** Limited animation is opt-in (`ROOTWARD_LIMITED=15`, or `=style` for a skin's own rate).
  Hand-offs between clips now start a blend's length before the clip ends: Godot's deterministic mixer fades a new
  clip in over what the old one still contributes, and a finished clip contributes nothing, so a fade begun from
  `animation_finished` rose out of the rest pose (a T-pose arm flashed up on every return to the idle).
- **A charge is a window**: `events.charge: [from, to]` is the only part of a cast slowed to wait for a long circle.

## On World of Warcraft

Blizzard's animations are their copyrighted assets; extracting them from the game client is against its terms and they
may not be shipped or reused here. What is free to use is how they are built, which is documented: a looping *ready*
pose while a cast bar fills, then a short *directed* release (wowdev's `ReadySpellDirected` and `SpellCastDirected`),
whole-body, effortless, with clear head and hand intent. The heavy cast follows that shape. For more capture, licensed
sources work through the same retargeter: Mixamo (free with an Adobe login, royalty-free in games; the player
downloads, a bone map is added to `sources.json`), Quaternius's second library (CC0), Kevin Iglesias's packs (check
each licence).

## Consequences

- A move is chosen from capture and adjusted, not invented in numbers; the dummy and the motion lab judge it.
- The build imports the capture each time (about 30 s in all).
- A different capture source needs only its bone map and T-pose frame.
