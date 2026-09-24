#!/usr/bin/env bash
# Music and sounds: pipeline/audio/manifest.json -> ComfyUI (ACE-Step) or recordings -> game/assets/audio (Ogg Vorbis).
#   scripts/audio.sh --only 'cue-*' [--sheet]       render, post-process, write (--sheet: a page to listen to them)
#   scripts/audio.sh --reprocess --only '...'        post-process cached renders only (no GPU)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
if [[ " $* " != *" --reprocess "* ]]; then need_comfy; fi
uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/audio/generate.py" "$@"
reimport
