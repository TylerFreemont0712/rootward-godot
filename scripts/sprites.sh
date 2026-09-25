#!/usr/bin/env bash
# Sprite skins and spell sprites through ComfyUI (pipeline/sprites/, ADR-0008), then a Godot import.
#   scripts/sprites.sh reference vesper --candidates 4     draw candidates; then --pick N
#   scripts/sprites.sh animate vesper [clip ...] [--draft]  render clips with the video model
#   scripts/sprites.sh build vesper                         sheets + clips.json into game/assets/sprites/vesper/
#   scripts/sprites.sh preview vesper                       a contact sheet and a page that plays every clip
#   scripts/sprites.sh fx [--only 'bolt-*'] [--reprocess]   spell sprites into game/assets/fx/spell/
#   scripts/sprites.sh arena [--only arena-kiln]            painted arenas (candidates); then --pick arena-kiln=1
#   scripts/sprites.sh spells [--only 'hit-*'] [--sheet]    spell animations, drawn in code, into game/assets/fx/spells/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
command="${1:?usage: scripts/sprites.sh <setup|poses|reference|profile|animate|build|preview|fx> ...}"
shift
case "$command" in
	build | poses | preview | spells) ;;
	fx) if [[ " $* " != *" --reprocess "* ]]; then need_comfy; fi ;;
	arena) if [[ " $* " != *" --pick "* ]]; then need_comfy; fi ;;
	*) need_comfy ;;
esac
if [[ "$command" == "fx" || "$command" == "arena" || "$command" == "spells" ]]; then
	uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/sprites/$command.py" "$@"
else
	uv run --project "$ROOT/pipeline" python "$ROOT/pipeline/sprites/pipeline.py" "$command" "$@"
fi
if [[ "$command" == "build" || "$command" == "fx" || "$command" == "arena" || "$command" == "spells" ]]; then reimport; fi
