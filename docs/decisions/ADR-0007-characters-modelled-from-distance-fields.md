# ADR-0007: skins modelled in code from distance fields, with whole hands

- Status: accepted (Vesper's model and rig; her clips and in-game skin come next)
- Date: 2026-09-25

## Context

Vesper, the Star-Script Witch, was to be a new skin, "fairly high quality, as close to the concept as possible", with
a proper skeleton and no missing fingers. The two earlier routes each fell short for her:

- A generated mesh (Emberfox's route: an image-to-3D model, rigged and coloured by projecting the concept) fuses the
  fingers, so the hands cannot bend, and the projected drawing smears wherever the surface turns from the camera.
- A 2.5D cut-out (Tamamo's route: the painting on a skinned plane) keeps the drawing but stretches as soon as a limb
  turns. Earlier Vesper attempts down both routes were discarded for exactly these reasons.

Blender is driven headless here (no GUI session), and the model has to be rebuilt when a proportion changes.

## Decision

- **Model in code.** `pipeline/blender/build_vesper.py` builds the whole character from numbers measured on the concept
  sheets (`pipeline/blender/vesper/anatomy.py`). Every part is a signed distance field (round cones, ellipsoids, lofts
  of tailor-style cross-sections, blended with a smooth minimum) sampled near its surface and meshed by the OpenVDB
  that ships inside Blender, at a voxel size per part (0.6 mm for hands, 2.2 mm for the body), then smoothed and
  reduced to a triangle budget. Fingers blend into the palm but never into each other, so all five come out whole.
- **Cloth is one sheet thickened afterwards** (`cloth.py`): the garment's outer face alone, trims painted on it as
  material bands, reduced, then given its thickness by moving a copy back along smoothed normals (the lining and the
  edge come from that). Meshing both
  walls of a 4 mm shell and reducing them let the walls cross.
- **The face is the concept's drawing**, lifted onto flat skin and projected from the front onto a face that is nearly
  flat there; its normals are bent toward an ellipsoid's so the toon light falls across it cleanly. The hair is lock
  geometry with a texture generated from the same lock coordinates (ink in every valley, a highlight band).
- **A Mixamo-named skeleton with whole hands**: three bones per finger and thumb, rolls set so each joint bends about
  its own X, and extra bones for the hat cone, its star, four hair locks and the book. Bone-heat weights on the body,
  clothes copy the body's weights, skin hidden for good under clothes is deleted afterwards.
- **Checked by rendering**: `render_vesper.py` renders the game's toon look in Eevee, with orthographic cameras at the
  concept's scale for overlays, and poses (fists, a pointing hand, a cast, arms overhead, a stride, a crouch) and a
  bone-ownership weight map.

## Consequences

- Any proportion is a number to edit and a rebuild (about two minutes from the mesh cache, fifteen from scratch); the
  build is deterministic, so the model can be regenerated rather than stored in git.
- The look is clean shapes and flat colours, which suits the toon shader; fine sculpted detail (cloth wrinkles, hair
  wisps) is limited to what a field can say.
- Her skeleton differs from Emberfox's (A-pose, more bones), so Mixamo takes must be retargeted, not copied.
- The game's toon shader reads Emberfox's packed vertex colour; Vesper needs her materials (flat colours and two
  textures) handled by the export and `StageCharacter` before she can be a skin.
