#!/usr/bin/env bash
# Check all content and run every shard's worked examples in the sandbox. `--no-exec` skips the sandbox.
set -uo pipefail
cd "$(dirname "$0")/../game"
GODOT="${GODOT_BIN:-godot}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/validate_content.gd -- "$@" < /dev/null 2>&1 | grep -v "^Godot Engine"
exit "${PIPESTATUS[0]}"
