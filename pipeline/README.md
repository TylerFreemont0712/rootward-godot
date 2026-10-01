# The asset pipeline

Everything the game shows or plays that is made rather than written: pictures from ComfyUI, music and sounds from
ComfyUI or CC0 recordings, and characters from Blender. Each kind has one manifest and one command, and every command
writes straight into `game/assets/` (or `game/characters/`) and re-imports the Godot project. Art is optional: the
game runs with none of it (`Art.texture` returns null, a character without a model is an empty node).

| What | Source of truth | Command | Writes |
|---|---|---|---|
| Pictures (arenas, foes, relic icons, map pieces, the card frame and back, skin portraits) | `art/manifest.json` (a style + a prompt each; `init` starts from a layout sketch or an image) | `scripts/art.sh --only '<ids>'` | `game/assets/<out>.png` (the card frame also writes `cards/frame.json`, its geometry) |
| Finished program-card icons | `art/program-icons-pass-9.json` (built-in imagegen prompts, original hashes, canonical shared textures) | `python art/program_icons.py board --all --out <review.png>`; `accept` copies reviewed originals, `check` verifies them | `game/assets/shardrun/card-*.png`; matching Spellforge images are referenced directly |
| Spell animations (a cast, a bolt, hits, a ward, a shatter, a claw) | `sprites/spells.json`, the motions in `sprites/spells.py` | `scripts/sprites.sh spells [--only '<ids>'] [--sheet]` (no GPU) | `game/assets/fx/spells/<id>.png` + `.json` |
| Music and its cues (composed: a brief and an ABC score each, performed by YuE2) | `music/tracks/<id>/` | `music/README.md`: `perform.py`, `listen.py`, `master.py` | `game/assets/audio/<out>.ogg`, loop points in `music.json` |
| Sounds (timelines on their animations' beats) and the treasure cue | `audio/manifest.json`, ingredients in `audio/synth.py` | `scripts/audio.sh --only '<ids>'`; `audio/beats.py` draws them against their beats | `game/assets/audio/<id>.ogg` (`<id>-1` ... for takes) |
| Characters (glTF, Emberfox) | `characters/<id>/model.json`, `animation.json`, concept art, and the rigged `.blend` | `scripts/character.sh <id>` | `game/characters/<id>/<id>.glb`, screenshots in `shots/` |
| Moves for every VRM skin | `moves/poses.json`, `moves/clips/*.json` (`moves/README.md`) | `scripts/moves.sh [--reel]` | `game/characters/moves/rootward.glb`, `moves.json`, sheets and a reel in `shots/moves/` |

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

Three kinds of battle skin:

- **VRM** (Shibu, ADR-0028): an anime model (`game/characters/<id>/<id>.vrm`, from VRoid Studio or a CC0 VRoid base
  restyled in Blender with the VRM add-on), imported by godot-vrm with its MToon materials, spring bones and face.
  Every VRM skin plays the shared move library. References (CC0 VRoid samples, CC0 Quaternius mocap, the Bandai Namco
  walk/wave set) are fetched into `cache/reference/` by `scripts/fetch-moves-refs.sh` and by hand.

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
