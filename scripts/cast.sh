#!/usr/bin/env bash
# Lanternroot's cast as sprite sheets (pipeline/animation/README.md, ADR-0063): every townsperson and the player's start
# look, from a Blender blockout turned three ways, restyled by ComfyUI, and cut on one shared camera into
# game/assets/overworld/cast/. ComfyUI and Blender never run at the same time (the GPU has 8 GB).
#   scripts/cast.sh turns [--only ids] [--force]     Blender blockouts, turned to the front, left and back (ComfyUI down)
#   scripts/cast.sh restyle [--only ids] [--force]   ComfyUI img2img on every turn (ComfyUI up)
#   scripts/cast.sh sheets [--only ids]              the sheets and cast.json from the cache (no GPU), then an import
#   scripts/cast.sh check                            whose look changed since their sheet was made
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
stage="${1:?usage: scripts/cast.sh turns|restyle|sheets|check [--only ids] [--force]}"
shift
case "$stage" in
	turns) need_no_comfy ;;
	restyle) need_comfy ;;
	sheets | check) ;;
	*) echo "unknown stage $stage (turns, restyle, sheets or check)" >&2; exit 2 ;;
esac
uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/animation/cast.py" "$stage" "$@"
if [[ "$stage" == "sheets" ]]; then
	reimport
fi
