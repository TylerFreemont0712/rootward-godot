# ADR-0005: one pipeline into Godot, and characters as real-time 3D

- Status: accepted
- Date: 2026-09-24

## Context

The old game made pictures and audio with ComfyUI scripts (`scripts/art`, `scripts/audio`) and characters as sprite
sheets rendered from Blender (old ADR-0026 to ADR-0034): a clip change meant a re-render and a new sheet, clips could
not blend, and the player found the cut-out puppets stiff. The move to Godot was planned with characters as 3D models
on the stage. The player asked for the Blender/Godot/ComfyUI setup to be "as smooth as possible".

## Decision

- **One place, one command per kind** (`pipeline/README.md`): `scripts/art.sh`, `scripts/audio.sh`,
  `scripts/character.sh <id>`. Each writes straight into the Godot project and re-imports it. `scripts/gpu-guard.sh`
  refuses to run ComfyUI work while Blender is up, or Blender while ComfyUI is up (8 GB of VRAM).
- **The ComfyUI generators are ported, not rewritten.** Same manifests, same code, new paths; re-processing the
  cached renders reproduces the old game's 190 Shardrun images pixel for pixel.
- **The pipeline has its own pinned Python** (`pipeline/pyproject.toml` through `uv`: numpy 2.5.3, Pillow 12.3.0,
  soundfile 0.13.1, wheels only). ComfyUI's venv is no longer borrowed.
- **Audio is Ogg Vorbis.** Godot does not import Ogg Opus, which the old browser game used. The encoder now writes
  Vorbis through libsndfile (this machine's ffmpeg has no libvorbis, and its built-in Vorbis encoder is poor), from
  the cached raw renders, so nothing is encoded lossily twice. Every music file ends at its loop point, so Godot's
  `loop_offset` from `music.json` reproduces the old seams.
- **Characters are glTF, animated in Godot.** `pipeline/blender/export_character.py` bakes each clip of
  `animation.json` from its Mixamo take into its own animation and packs the colour (base vertex colour plus the
  concept drawing through its UV, mixed by a mask in the vertex alpha). `StageCharacter` applies a toon shader
  (unshaded two-tone from the character's own light, a rim light) and an inverted-hull ink outline, blends clips,
  loops the idle, and swings the tail and ears with `SpringBoneSimulator3D`. Clips play at full frame rate: smooth
  over the old sprites' held drawings, as the player prefers.

## Consequences

- Changing a clip is editing a range in `animation.json` and running one command, seconds instead of a sheet render.
- The rigged `.blend`, the Mixamo takes and the render caches stay out of git; during the migration the caches and the
  Kenney packs are symlinks into the old repository.
- The ink outline is thin and patchy at small sizes on the generated mesh; smoothed normals for the hull, and hands,
  are phase 6 work.
