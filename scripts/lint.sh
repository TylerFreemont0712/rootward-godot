#!/usr/bin/env bash
# gdlint and a gdformat check over our GDScript (addons excluded), with gdtoolkit pinned through uvx.
# (Untyped declarations are parse errors through project.godot, so the test run catches those.)
set -euo pipefail
cd "$(dirname "$0")/.."
GDTOOLKIT="gdtoolkit==4.5.0"
mapfile -t files < <(find game -name '*.gd' -not -path 'game/addons/*' -not -path 'game/.godot/*')
uvx --from "$GDTOOLKIT" gdlint "${files[@]}"
uvx --from "$GDTOOLKIT" gdformat --check --line-length 120 "${files[@]}"
