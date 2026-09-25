# Tamamo-no-Mae character source

- `concept-tpose.png` is the generated front-view model sheet and the source texture.
- `turnaround.png` is the matching front, side, and back modeling reference.
- `animation.json` names the hand-authored Blender actions exported for the game.
- `model.json` documents the rig and keeps spell effects separate from the character art.
- The editable `.blend` lives in `pipeline/cache/characters/tamamo_no_mae/rigged.blend`; the runtime `.glb` is written to `game/characters/tamamo_no_mae/`.

The model is a skinned 2.5D silhouette mesh. The front concept painting stays consistent across actions because it is a texture on a densely sampled mesh, with the body, face, arms, legs, hair, ears, fingers, and nine tail fans assigned to bones. The game turns the model slightly toward the camera for the intended illustrated look. Shields, sigils, and projectile art are separate Godot effects.
