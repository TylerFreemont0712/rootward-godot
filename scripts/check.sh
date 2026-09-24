#!/usr/bin/env bash
# Parse every GDScript file (addons excluded) and print its errors, all at once. Faster than a test run for typos.
set -uo pipefail
cd "$(dirname "$0")/../game"
GODOT="${GODOT_BIN:-godot}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
status=0
while IFS= read -r file; do
	out="$("$GODOT" --headless --path . --check-only -s "res://${file#./}" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|at: GDScript::reload" | grep -v "Failed to compile depended")"
	if [ -n "$out" ]; then echo "== $file"; echo "$out"; status=1; fi
done < <(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' | sort)
exit $status
