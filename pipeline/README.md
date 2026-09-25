# The asset pipeline

Everything the game shows or plays that is made rather than written: pictures from ComfyUI, music and sounds from
ComfyUI or CC0 recordings, and characters from Blender. Each kind has one manifest and one command, and every command
writes straight into `game/assets/` (or `game/characters/`) and re-imports the Godot project. Art is optional: the
game runs with none of it (`Art.texture` returns null, a character without a model is an empty node).

| What | Source of truth | Command | Writes |
|---|---|---|---|
| Pictures (arenas, foes, relic icons, map pieces, the card frame and back, skin portraits) | `art/manifest.json` (a style + a prompt each; `init` starts from a layout sketch or an image) | `scripts/art.sh --only '<ids>'` | `game/assets/<out>.png` (the card frame also writes `cards/frame.json`, its geometry) |
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

Two kinds of battle skin:

- **3D** (Emberfox): a generated model with a Mixamo-compatible rig and takes, baked into actions and exported as
  animated glTF by `scripts/character.sh <id>`. `StageCharacter` plays it with the toon shader and ink outline. A model
  with hand-keyed actions can export them as named NLA tracks instead (`"representation": "2.5d-skinned-mesh"` in its
  `model.json`).
- **Sprite sheets** (Vesper): drawn by ComfyUI's video model on a skeleton, clip by clip (`pipeline/sprites/`,
  `scripts/sprites.sh`, ADR-0008). `SpriteCharacter` plays them.

Spell shields, sigils and projectiles are Godot effects, never part of a character.

## During the migration

`cache/art`, `cache/audio` and `sources/vendor` are symlinks into the old repository (`../ProgramMe/assets/`), so the
1.2 GB of cached renders and the Kenney CC0 packs are not copied. The rigged `.blend` and the Mixamo takes are large and
stay out of git (`cache/` is ignored).
