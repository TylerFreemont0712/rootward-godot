# The asset pipeline

Everything the game shows or plays that is made rather than written: pictures from ComfyUI, music and sounds from
ComfyUI or CC0 recordings, and characters from Blender. Each kind has one manifest and one command, and every command
writes straight into `game/assets/` (or `game/characters/`) and re-imports the Godot project. Art is optional: the
game runs with none of it (`Art.texture` returns null, a character without a model is an empty node).

| What | Source of truth | Command | Writes |
|---|---|---|---|
| Pictures (arenas, foes, relic icons, map pieces) | `art/manifest.json` (a style + a prompt each) | `scripts/art.sh --only '<ids>'` | `game/assets/<out>.png` |
| Music, cues, sounds | `audio/manifest.json` | `scripts/audio.sh --only '<ids>'` | `game/assets/audio/<id>.ogg`, loop points in `music.json` |
| Characters | `characters/<id>/model.json`, `animation.json`, concept art, and the rigged `.blend` | `scripts/character.sh <id>` | `game/characters/<id>/<id>.glb`, screenshots in `shots/` |

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

## Characters

Characters export as animated glTF and use the same `StageCharacter` controller and Godot toon look. Their authoring
paths can differ by art style:

- Emberfox starts with a generated 3D model, uses a Mixamo-compatible rig and takes, then bakes selected take ranges
  into actions.
- Tamamo-no-Mae starts with a generated T-pose, avatar, and turnaround. Blender turns the painted silhouette into a
  skinned 2.5D mesh with a detailed armature and hand-keyed anime actions. The source texture stays consistent across
  clips, while the nine tails, hair, ears, hands, and limbs have independent bone controls. Spell shields, sigils, and
  projectiles remain Godot effects, outside the character texture and rig.

For the Tamamo path, `pipeline/characters/tamamo_no_mae/model.json` describes the mesh and rig, and
`animation.json` maps game clip names to Blender actions. The editable model lives in
`pipeline/cache/characters/tamamo_no_mae/rigged.blend`; `scripts/character.sh tamamo_no_mae` exports the actions into
`game/characters/tamamo_no_mae/tamamo_no_mae.glb` and captures a clip sheet and close-up.

## During the migration

`cache/art`, `cache/audio` and `sources/vendor` are symlinks into the old repository (`../ProgramMe/assets/`), so the
1.2 GB of cached renders and the Kenney CC0 packs are not copied. The rigged `.blend` and the Mixamo takes are large and
stay out of git (`cache/` is ignored).
