#!/usr/bin/env bash
# Run every gdUnit4 suite headless. Extra arguments go to the runner (for one suite: -a res://test/core/rng_test.gd).
# The import pass first refreshes Godot's class cache, so a new `class_name` is visible to the tests.
set -euo pipefail
cd "$(dirname "$0")/../game"
GODOT="${GODOT_BIN:-godot}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
args=("$@")
if [ ${#args[@]} -eq 0 ]; then args=(-a res://test); fi
set +e
# --remote-debug to a port that is never bound keeps Godot's interactive debugger from waiting on a script error.
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode -c "${args[@]}"
code=$?
"$GODOT" --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd "${args[@]}" >/dev/null 2>&1
exit $code
