#!/usr/bin/env bash
# A character: its rigged .blend -> glTF with every clip (pipeline/blender/export_character.py) -> Godot import ->
# a contact sheet of every clip and turn at shots/<id>-sheet.png, and a close-up at shots/<id>-close.png.
#   scripts/character.sh emberfox
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
id="${1:?usage: scripts/character.sh <id>}"
blend="$ROOT/pipeline/cache/characters/$id/rigged.blend"
[ -f "$blend" ] || { echo "no $blend (the rigged model; see pipeline/README.md)" >&2; exit 1; }
need_no_comfy
~/blender/blender --background "$blend" --python "$ROOT/pipeline/blender/export_character.py" -- "$id" 2>&1 | grep '\[export\]'
reimport
ROOTWARD_CHARACTER="$id" "$ROOT/scripts/screenshot.sh" res://tools/character_sheet.tscn "shots/$id-sheet.png" 20
ROOTWARD_CHARACTER="$id" ROOTWARD_SHEET=close "$ROOT/scripts/screenshot.sh" res://tools/character_sheet.tscn "shots/$id-close.png" 20
