#!/usr/bin/env bash
# Exercise real menu clicks on a private display and isolated saves; optional screenshot path is absolute.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
"$GODOT" --headless --import --path "$root/game" >/dev/null 2>&1 || true
export ROOTWARD_NAVIGATION_SHOT="${1:-$root/shots/foundry/navigation.png}"
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$root/game" --resolution 1920x1080 \
	-s res://tools/menu_navigation.gd < /dev/null
