#!/usr/bin/env bash
# Lanternroot's background objects (pipeline/world/README.md, ADR-0064): buildings, landmarks, trees, props and furniture
# from short specs in tiles (pipeline/world/objects/<id>.jsonc), as a Blender blockout in the town's 3/4 view, restyled
# by ComfyUI, held to the blockout's outline and cut at the world's scale into game/assets/overworld/world/.
#   scripts/world.sh new <id> --kind building --footprint 5x5 --what "a cosy cottage"   a spec to edit
#   scripts/world.sh adopt <render id> --as <id>       a spec that re-cuts an existing ComfyUI render
#   scripts/world.sh check [--only ids]                every spec checked; which pictures are stale
#   scripts/world.sh make [--only ids] [--force]       everything below, in order, ComfyUI stopped and started for you
#   scripts/world.sh blockout [--only ids] [--force]   Blender (ComfyUI down)
#   scripts/world.sh restyle [--only ids] [--force]    ComfyUI (up)
#   scripts/world.sh cut [--only ids]                  the pictures, their index and the reviews (no GPU), then an import
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
stage="${1:?usage: scripts/world.sh new|adopt|check|make|blockout|restyle|cut [--only ids] [--force]}"
shift
world() { uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/world/world.py" "$@"; }
case "$stage" in
	new | adopt | check) world "$stage" "$@" ;;
	blockout) need_no_comfy; world blockout "$@" ;;
	restyle) need_comfy; world restyle "$@" ;;
	cut) world cut "$@"; reimport ;;
	make)
		world check "$@" >/dev/null
		comfy_stop
		world blockout "$@"
		comfy_start
		world restyle "$@"
		world cut "$@"
		reimport
		;;
	*) echo "unknown stage $stage (new, adopt, check, make, blockout, restyle or cut)" >&2; exit 2 ;;
esac
