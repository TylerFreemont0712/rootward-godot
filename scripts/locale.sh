#!/usr/bin/env bash
# Translation coverage of the content for a locale: scripts/locale.sh ja [--missing]
set -uo pipefail
cd "$(dirname "$0")/../game"
godot --headless --path . -s res://tools/locale_report.gd -- "$@" < /dev/null 2>&1 | grep -v "^Godot Engine"
exit "${PIPESTATUS[0]}"
