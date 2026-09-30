# ADR-0028: VRM skins and a shared move library

- Status: accepted (the pipeline, nine clips and a trial skin; Vesper's own VRM is the next step)
- Date: 2026-09-30
- Related: ADR-0005 (one pipeline into Godot), ADR-0007 (Vesper modelled in code), ADR-0008 (sprite skins)

## Context

The player found the Blender models "nowhere near" what they hoped for, and wanted more fantastical movement for
spells than the chibi sprite's three clips. Every earlier route fell short for a known reason:

| Route | What went wrong |
|---|---|
| Image to 3D (TRELLIS.2, Emberfox) | fused fingers; the mesh shreds when reduced; colours smear |
| 2.5D cut-out (Tamamo) | the painting stretches as a limb turns |
| Distance fields in code (Vesper, ADR-0007) | clean but stiff shapes, no anime face |
| Video-model sprites (ADR-0008) | the 1.3B model softens faces; every clip costs GPU time; few clips |

Research (this session) looked at StdGEN (anime image to decomposed mesh; research-only weights, Python 3.9 and torch
2.1, an unrigged mesh with the same clean-up problem), UniRig (auto-rigging, 8 GB, MIT: kept as an option for
creatures), HY-Motion (text to motion: needs 24 GB), and the VRM ecosystem (VRoid models, the VRM add-on for Blender
5.2, godot-vrm for Godot 4.7).

## Decision

- **Skins are VRM models** (`game/characters/<id>/<id>.vrm`), imported by godot-vrm (MIT, `game/addons/vrm` and
  `Godot-MToon-Shader`): a real anime face with expressions, MToon toon materials, spring-bone hair and cloth, and a
  standard humanoid skeleton. A VRM comes from VRoid Studio or from a CC0 VRoid base restyled in Blender (the VRM
  add-on reads and writes it headless). The trial skin **Shibu** is the CC0 sample *Darkness Shibu*.
- **Moves are one shared library** (`game/characters/moves/rootward.glb`), keyed in Blender on Godot's humanoid
  profile names and imported as an AnimationLibrary retargeted through `SkeletonProfileHumanoid` ("overwrite axis"),
  exactly as godot-vrm imports a skin: every clip plays on every VRM skin.
- **Clips are data** (`pipeline/moves/`): readable pose parameters, keys with anime easing (snap, overshoot,
  anticipation, holds), per-bone lag, steps on twos, procedural layers, face expressions and a release event.
  `motion.py` is pure and unit-tested; `build_moves.py` is the only code that knows bone axes. Nine clips: a hovering
  idle, a palm strike, a spinning levitation blast, channel, windup, guard, hurt, victory, death.
- **The stage times casts to the sigil**: `HeroView.release_in` rescales the cast so the palm goes through the circle
  on its blow, and `hand_point` returns where the palm will be at the release (from `moves.json`), so the sigil is
  drawn where she strikes. A VRM skin gets a warm key light in its own viewport (MToon needs light).
- **Emberfox and the sprite Vesper keep working** unchanged; `StageCharacter` picks the VRM path when a `.vrm` exists.

## Consequences

- A new move is a JSON file and `scripts/moves.sh` (about 20 s and a review sheet), not a GPU session; a new skin is
  a VRM file and a portrait.
- The move library is authored by hand in numbers. `shots/moves/*.png` and `reel.mp4` are how a clip is judged; the
  `pipeline/moves/README.md` checklist is the standard. CC0 mocap (Quaternius's library, retargeted the same way) and
  the Bandai Namco walk/wave set are in `pipeline/cache/reference/mocap/` for bases.
- Known gaps: the cast flash (`set_flash`) does nothing on MToon; a dress's white lining shows when the skirt flares;
  expressions switch rather than blend. Vesper as a VRM (a hat, a capelet, her colours on a CC0 base, or made in
  VRoid Studio) is the next step.
- The repository gains about 20 MB per VRM skin; they are CC0 or the player's own.

### Import note (Godot 4.7)

The AnimationLibrary import must keep `retarget/remove_tracks/except_bone_transform` **off**: on, it strips the
rotation tracks and leaves one track per clip.
