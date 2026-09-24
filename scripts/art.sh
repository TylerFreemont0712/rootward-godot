#!/usr/bin/env bash
# Pictures: pipeline/art/manifest.json -> ComfyUI -> game/assets/, then a Godot import.
#   scripts/art.sh --only 'shardrun-relic-*'        render what is not cached, post-process, write
#   scripts/art.sh --reprocess --only '...'          post-process cached renders only (no GPU, no ComfyUI)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
if [[ " $* " != *" --reprocess "* ]]; then need_comfy; fi
uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/art/generate.py" "$@"
reimport
