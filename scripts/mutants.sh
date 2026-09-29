#!/usr/bin/env bash
# The Mutator's census (ADR-0026): which mutants of every program card still run, written to
# game/content/packs/core/programs/mutants.jsonc. Re-run when a card's code changes (validate.sh warns when it is stale).
set -uo pipefail
cd "$(dirname "$0")/../game"
godot --headless --path . -s res://tools/mutant_census.gd < /dev/null 2>&1 | grep -v "^Godot Engine"
exit "${PIPESTATUS[0]}"
