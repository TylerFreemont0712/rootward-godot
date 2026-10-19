#!/usr/bin/env bash
# The animation base's candidates (pipeline/animation/README.md): ComfyUI sprites and Blender-built characters, each cut
# to its pixel count into Concept/v0.3/animation/. The cast's sprite sheets are scripts/cast.sh (ADR-0063).
# ComfyUI and Blender never run at the same time (the GPU has 8 GB).
#   scripts/animation.sh comfy [--only ids] [--force]     ComfyUI renders (when not cached), then the cuts
#   scripts/animation.sh blender [--only ids] [--force]   Blender renders the models, then the cuts
#   scripts/animation.sh sheet                            Concept/v0.3/animation/sheet.png, every candidate
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
stage="${1:?usage: scripts/animation.sh comfy|blender|sheet [--only ids] [--force]}"
shift
case "$stage" in
	comfy) need_comfy ;;
	blender) need_no_comfy ;;
	sheet) ;;
	*) echo "unknown stage $stage (comfy, blender or sheet)" >&2; exit 2 ;;
esac
uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/animation/base_sprites.py" "$stage" "$@"
