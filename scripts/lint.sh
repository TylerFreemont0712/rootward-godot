#!/usr/bin/env bash
# gdlint over our GDScript for likely bugs only (.gdlintrc keeps it loose: the player's call, 2026-10-13), then a
# formatting report that never fails the run. gdtoolkit is pinned through uvx.
# (Untyped declarations are parse errors through project.godot, so the test run catches those.)
#   scripts/lint.sh          lint, and list files gdformat would change
#   scripts/lint.sh --fix    format every file in place first (gdformat), then lint
# Addons, Godot's cache and throwaway probes (probe*.gd, tmp_* and probe_* folders) are left out.
set -euo pipefail
cd "$(dirname "$0")/.."
GDTOOLKIT="gdtoolkit==4.5.0"
mapfile -t files < <(find game -name '*.gd' -not -path 'game/addons/*' -not -path 'game/.godot/*' \
	-not -path 'game/tmp_*' -not -path 'game/probe_*' -not -name 'probe*.gd')
if [[ "${1:-}" == "--fix" ]]; then
	uvx --from "$GDTOOLKIT" gdformat --line-length 120 "${files[@]}"
fi
uvx --from "$GDTOOLKIT" gdlint "${files[@]}"
report="$(uvx --from "$GDTOOLKIT" gdformat --check --line-length 120 "${files[@]}" 2>&1 || true)"
if grep "would reformat" <<<"$report"; then
	echo "formatting: the files above are not as gdformat would write them (scripts/lint.sh --fix); not an error"
else
	echo "formatting: every file as gdformat would write it"
fi
