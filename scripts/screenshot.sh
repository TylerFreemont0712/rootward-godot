#!/usr/bin/env bash
# Screenshot a scene: scripts/screenshot.sh <res:// scene> <output.png, relative to the repo> [frames]
# At the design size, 1920x1080; SHOT_SIZE=2560x1440 shows it as a bigger window would.
# Runs Godot under a private virtual X display (xvfb-run), so nothing opens on the desktop. Set SHOT_DISPLAY=:0 to
# render on the real display (with the GPU) instead.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scene="$1"; out="$2"; frames="${3:-30}"
case "$out" in /*) ;; *) out="$root/$out" ;; esac
GODOT="${GODOT_BIN:-godot}"
# An import pass first, so a class_name added since the last one is known (otherwise its script fails to compile).
"$GODOT" --headless --import --path "$root/game" < /dev/null > /dev/null 2>&1 || true
size="${SHOT_SIZE:-1920x1080}"
cmd=("$GODOT" --path "$root/game" --resolution "$size" -s res://tools/screenshot.gd -- "$scene" "$out" "$frames")
if [ -n "${SHOT_DISPLAY:-}" ]; then
	DISPLAY="$SHOT_DISPLAY" "${cmd[@]}" < /dev/null
else
	xvfb-run -a -s "-screen 0 ${size}x24" "${cmd[@]}" < /dev/null
fi
