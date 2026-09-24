#!/usr/bin/env bash
# Screenshot a scene: scripts/screenshot.sh <res:// scene> <output.png, relative to the repo> [frames]
# Runs Godot under a private virtual X display (xvfb-run), so nothing opens on the desktop. Set SHOT_DISPLAY=:0 to
# render on the real display (with the GPU) instead.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scene="$1"; out="$2"; frames="${3:-30}"
case "$out" in /*) ;; *) out="$root/$out" ;; esac
GODOT="${GODOT_BIN:-godot}"
cmd=("$GODOT" --path "$root/game" --resolution 1600x900 -s res://tools/screenshot.gd -- "$scene" "$out" "$frames")
if [ -n "${SHOT_DISPLAY:-}" ]; then
	DISPLAY="$SHOT_DISPLAY" "${cmd[@]}"
else
	xvfb-run -a -s "-screen 0 1600x900x24" "${cmd[@]}"
fi
