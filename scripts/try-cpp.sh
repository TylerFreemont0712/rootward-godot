#!/usr/bin/env bash
# Builds only the named cards' C++ into a private runtime and runs their worked examples (ADR-0046), leaving the
# game's own build alone, so several ports can be checked at once. Ids of program cards or Spellforge shards:
#   scripts/try-cpp.sh amplify divide fork
# Prints each failure, then "C++ ok: N cards" or exits 1.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
[ $# -gt 0 ] || { echo "usage: scripts/try-cpp.sh <card id>..." >&2; exit 2; }
runtime="$root/game/sandbox/runtime"
private="$(mktemp -d "${TMPDIR:-/tmp}/rootward-try-cpp.XXXXXX")"
trap 'rm -rf "$private"' EXIT
mkdir -p "$private/runtime"
for part in bin python js; do ln -s "$runtime/$part" "$private/runtime/$part"; done
ids="$(IFS=,; echo "$*")"
ROOTWARD_CPP_OUT="$private/runtime/cpp" ROOTWARD_CPP_ONLY="$ids" "$root/scripts/build-cpp.sh" | grep -v "units$" || exit 1
ROOTWARD_SANDBOX_RUNTIME="$private/runtime" ROOTWARD_CPP_ONLY="$ids" \
	"$GODOT" --headless --path "$root/game" -s res://tools/try_cpp.gd < /dev/null 2>&1 | grep -E "^(card|shard|C\+\+|missing)" 
