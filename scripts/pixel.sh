#!/usr/bin/env bash
# Lanternroot's overworld pictures (pipeline/pixel/README.md, ADR-0061) into game/assets/overworld/, then a lint that
# fails any picture with soft alpha or a colour outside the palette.
#   scripts/pixel.sh                         hand-placed parts and props, code-made ground tiles, portraits; lint (no GPU)
#   scripts/pixel.sh --comfy 'ow-building-*' render (if not cached) and write ComfyUI pictures from pipeline/pixel/manifest.json first
#   scripts/pixel.sh --lint                  only check what is there
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
if [[ "${1:-}" == "--comfy" ]]; then
	need_comfy
	uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/art/generate.py" --manifest "$ROOT/pipeline/pixel/manifest.json" --only "${2:-ow-*}"
	shift 2 || true
fi
uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/pixel/build.py" "$@"
reimport
