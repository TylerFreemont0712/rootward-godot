# Sprite skins and spell sprites (ADR-0008)

Everything here runs through ComfyUI (start it first; the GPU cannot hold ComfyUI and Blender at once).

| Step | Command | Writes |
|---|---|---|
| Check models and nodes | `scripts/sprites.sh setup` | nothing |
| Look at a clip's skeletons | `scripts/sprites.sh poses vesper` | `pipeline/cache/sprites/vesper/poses/` |
| Draw the skin | `scripts/sprites.sh reference vesper --candidates 6`, then `--pick N` | `skins/vesper/reference.png` |
| Draw a key pose in a clip | `scripts/sprites.sh keypose vesper cast-light 12`, then `--pick N` | `skins/vesper/keys/` |
| Render clips | `scripts/sprites.sh animate vesper [clip ...] [--draft] [--seed N]` | the cache (~4 min a clip) |
| Build for the game | `scripts/sprites.sh build vesper` | `game/assets/sprites/vesper/` (WebP grids, `clips.json`) |
| Spell sprites | `scripts/sprites.sh fx [--only 'bolt-*'] [--force] [--reprocess]` | `game/assets/fx/spell/` |

- `skins/<id>/skin.json` is the character in words, its style and seeds; `rig.json` its skeleton in the rest pose;
  `animations.json` its clips as keys on that skeleton. `pipeline/sprites/rig.py <skin> <clip> out.png` draws a clip's
  skeletons without the GPU.
- `workflows/` are ComfyUI API graphs, loadable in the editor; the driver finds nodes by title (`rw:sampler`).
  `comfy_nodes/rootward_sprites/` is the source of the three small nodes ComfyUI runs from its `custom_nodes`.
- `fx.json` maps each spell sprite to a quadrant of a board in `Concept/spellAnimations/` and a prompt.
