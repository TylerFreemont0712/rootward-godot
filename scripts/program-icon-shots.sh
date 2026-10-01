#!/usr/bin/env bash
# Review every base program card using its real CardFace, unobscured, at the normal hand size.
set -euo pipefail
cd "$(dirname "$0")/.."
for page in 0 1 2; do
	ROOTWARD_ICON_PAGE="$page" scripts/screenshot.sh res://tools/program_icon_sheet.tscn \
		"shots/polish/program-cards-pass9-$((page + 1)).png" 30 \
		> "/tmp/rootward-program-cards-pass9-$page.log" 2>&1
	printf 'Captured card sheet %s/3\n' "$((page + 1))"
done
