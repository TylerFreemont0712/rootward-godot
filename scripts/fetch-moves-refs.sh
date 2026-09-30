#!/usr/bin/env bash
# The reference models the move library is built on, into pipeline/cache/reference/ (git-ignored):
# the CC0 VRoid samples (each file's own VRM meta says CC0; ADR-0028).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dest="$ROOT/pipeline/cache/reference/vrm"
mkdir -p "$dest"
for name in Darkness_Shibu HairSample_Female HairSample_Male Sakurada_Fumiriya Sendagaya_Shibu Sendagaya_Shino; do
	[ -f "$dest/$name.vrm" ] && continue
	curl -fsSL -o "$dest/$name.vrm" "https://raw.githubusercontent.com/madjin/vrm-samples/master/vroid/beta/$name.vrm"
	echo "fetched $name.vrm"
done
