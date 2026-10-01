#!/usr/bin/env bash
# Review the Kernel Foundry front end with isolated saves, on a private virtual display.
set -euo pipefail
cd "$(dirname "$0")/.."
pages=(home resume adventure settings audio character academy library foes records profiles home-ja adventure-ja)
for page in "${pages[@]}"; do
  ROOTWARD_MENU="$page" scripts/screenshot.sh res://tools/foundry_shot.tscn "shots/foundry/$page.png" 30 \
    > "/tmp/rootward-foundry-$page.log" 2>&1
  printf '%s\n' "Rendered $page"
done
ROOTWARD_MENU=character SHOT_SIZE=1280x720 scripts/screenshot.sh res://tools/foundry_shot.tscn \
  shots/foundry/character-1280.png 30 > /tmp/rootward-foundry-character-1280.log 2>&1
printf '%s\n' 'Rendered character at 1280×720'
