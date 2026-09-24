# The asset pipeline

Everything the game shows or plays that is made rather than written: pictures from ComfyUI, music and sounds from
ComfyUI or CC0 recordings, and characters from Blender. Each kind has one manifest and one command, and every command
writes straight into `game/assets/` (or `game/characters/`) and re-imports the Godot project. Art is optional: the
game runs with none of it (`Art.texture` returns null, a character without a model is an empty node).

| What | Source of truth | Command | Writes |
|---|---|---|---|
| Pictures (arenas, foes, relic icons, map pieces) | `art/manifest.json` (a style + a prompt each) | `scripts/art.sh --only '<ids>'` | `game/assets/<out>.png` |
| Music, cues, sounds | `audio/manifest.json` | `scripts/audio.sh --only '<ids>'` | `game/assets/audio/<id>.ogg`, loop points in `music.json` |
| Characters | `characters/<id>/animation.json` + the rigged `.blend` | `scripts/character.sh <id>` | `game/characters/<id>/<id>.glb`, screenshots in `shots/` |

`--reprocess` re-runs only the post-processing on cached renders (no GPU, no ComfyUI), which is how a change to a
palette, a crop or a loudness target is applied. `--only` takes ids, with a trailing `*` for a prefix.

## The GPU rule

The GPU has 8 GB. ComfyUI and Blender are never up together; the scripts refuse to start when the other one is
running (`scripts/gpu-guard.sh`). ComfyUI, when needed:

```sh
cd ~/personal-project/ComfyUI && setsid nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 >> .launcher/comfyui-server.log 2>&1 < /dev/null &
```

## Python

The pipeline has its own pinned environment (`pyproject.toml`, `uv.lock`): numpy, Pillow, soundfile. The scripts run
through `uv run --project pipeline`. ComfyUI and Blender keep their own Pythons; the pipeline talks to ComfyUI over
HTTP and runs Blender as a program.

## Characters (ADR-0005)

A character is a generated 3D model rigged to Mixamo's skeleton (the old game's ADR-0034 made Emberfox that way:
concept drawing, TRELLIS.2 model, cleanup, rig, takes). This pipeline starts from the rigged file:

1. `pipeline/cache/characters/<id>/rigged.blend`: the model, the rig (Mixamo bones plus tail and ears), and every
   Mixamo take as an action.
2. `pipeline/characters/<id>/animation.json`: each clip the game plays as a range of a take (`take`, `frames`).
   Change a range, run `scripts/character.sh <id>`, and the game has it.
3. The export bakes each clip into its own animation, packs the colour (base vertex colour, the concept drawing, and
   the mask between them), and writes one `.glb`. In Godot, `StageCharacter` dresses it in `characters/toon.gdshader`
   and `outline.gdshader`, loops the idle, blends between clips, and swings the tail and ears on spring bones.

## During the migration

`cache/art`, `cache/audio` and `sources/vendor` are symlinks into the old repository (`../ProgramMe/assets/`), so
the 1.2 GB of cached renders and the Kenney CC0 packs are not copied. The rigged `.blend` and the Mixamo takes are
large and stay out of git (`cache/` is ignored).
