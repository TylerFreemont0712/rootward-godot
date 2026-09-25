# Vesper, the Star-Script Witch

The concept is `Concept/vesper-star-script-witch/` (`reference/full-front.png` is the design authority). The model is
**built by a script**, not sculpted by hand, so every proportion is a number that can be read and changed:

```sh
~/blender/blender --background --factory-startup --python pipeline/blender/build_vesper.py            # ~2 min from the mesh cache
~/blender/blender --background --factory-startup --python pipeline/blender/build_vesper.py -- --fresh # ~15 min, remesh everything
~/blender/blender --background --factory-startup --python pipeline/blender/build_vesper.py -- --only hair,hat_felt
~/blender/blender --background pipeline/cache/characters/vesper/rigged.blend --python pipeline/blender/render_vesper.py
```

The build writes `pipeline/cache/characters/vesper/rigged.blend` (git-ignored, like the other characters' rigs), with
its meshed parts cached in `parts/` and the generated `face.png` and `hair.png` beside it. The renderer writes the
review shots to `shots/vesper/`: a turnaround, face and hand close-ups, the skeleton, a bone-ownership weight map, and
pose tests (a cast, arms overhead, a stride, a crouch, fists, a pointing hand).

## Where things are (`pipeline/blender/vesper/`)

| Module | What it makes |
| --- | --- |
| `anatomy.py` | Heights, joints, the A-pose arm, the hand's frame and every finger's joints: the numbers the mesh and the rig share |
| `sdf.py` | Distance-field shapes (round cones, ellipsoids, lofts of cross-sections), smooth blends, meshing through OpenVDB |
| `body.py`, `head.py`, `hands.py` | Torso loft, limbs, the skull loft with the concept's face projected on, five-fingered hands |
| `hair.py` | The bob in 23 locks, bangs and framing locks, and its painted texture (ink in every valley, a highlight band) |
| `clothes.py`, `mantle.py`, `gloves.py`, `boots.py`, `hat.py`, `book.py` | The costume, piece by piece |
| `cloth.py` | Cloth as one sheet: the outer face, trims as material bands, thickness added after reduction |
| `covered.py` | Skin that clothes hide for good, deleted after weighting so it cannot poke through |
| `rig.py` | The skeleton (Mixamo names, full hands, hat/hair/book bones) and all the weights |
| `parts.py` | Every meshed part: its field, voxel size, triangle budget, object and materials |
| `shading.py`, `preview.py` | The game's toon look in Eevee, and cameras at the concept sheet's scale for overlay checks |

## The rig

- Mixamo names with the `mixamorig:` prefix, like Emberfox's, so the same Mixamo takes can be retargeted. She stands
  in an A-pose (arms 30 degrees out, as the concept does), not Emberfox's T-pose, so takes need retargeting rather
  than a straight copy of rotations.
- Every finger has three bones and an end bone (`LeftHandIndex1..4`), the thumb too (`LeftHandThumb1..4`). Rolls put
  each bone's X across its joint: a negative X rotation curls a finger toward the palm, bends a knee or an elbow.
- Her own bones: `Hat`, `HatCone1..4`, `HatStar`, `HairFront`, `HairSide.L/R`, `HairBack`, `Book`. They are meant
  for spring bones in Godot (the cone, the star and the locks sway after her).
- Weights: bone heat on the body; clothes copy the nearest body weights; hair and hat blend from the head to their own
  bones; the book is rigid on its bone. At most four bones per vertex (glTF).

## Not done yet

No animation clips (`animation.json`) and no export to `game/characters/vesper/`: the model is waiting for review.
The game's toon shader expects Emberfox's packed vertex colour; Vesper's materials are plain colours plus two
textures (face, hair), which the export and `StageCharacter` will need to handle.
