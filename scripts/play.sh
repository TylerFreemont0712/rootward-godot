#!/usr/bin/env bash
# Play Rootward: scripts/play.sh, or scripts/play.sh --editor to open the Godot editor on the project instead.
# The desktop launcher (scripts/install-launcher.sh) runs this. When anything in game/ changed since the last import,
# an import pass runs first (about 3 s), so new art or a new class_name never breaks a launch.
# Godot writes its log to ~/.local/share/godot/app_userdata/Rootward/logs/.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
game="$root/game"
GODOT="${GODOT_BIN:-$(command -v godot || echo "$HOME/godot")}"
stamp="$game/.godot/rootward-imported"
if [ ! -f "$stamp" ] || [ -n "$(find "$game" -path "$game/.godot" -prune -o -newer "$stamp" -type f -print -quit)" ]; then
	"$GODOT" --headless --import --path "$game" < /dev/null > /dev/null 2>&1 || true
	touch "$stamp"
fi
if [ "${1:-}" = "--editor" ]; then
	exec "$GODOT" --path "$game" --editor
fi
exec "$GODOT" --path "$game"
