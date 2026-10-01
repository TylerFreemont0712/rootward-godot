#!/usr/bin/env bash
# The move library (ADR-0028): every clip of pipeline/moves/clips/ keyed in Blender onto a VRM skeleton, exported to
# game/characters/moves/rootward.glb + moves.json, imported, and drawn as review sheets in shots/moves/.
#   scripts/moves.sh                  # test the motion, build, import, sheets
#   scripts/moves.sh --reel [skin]    # also film every clip in Godot: shots/moves/reel.mp4 and reel.gif
# The review sheets and the reel use the motion dummy (ADR-0030) unless a skin id is given.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/gpu-guard.sh"
need_no_comfy
[ -f "$ROOT/pipeline/cache/reference/vrm/Darkness_Shibu.vrm" ] || "$ROOT/scripts/fetch-moves-refs.sh"
python3 -m unittest discover -s "$ROOT/pipeline/moves" -q
~/blender/blender --background --python "$ROOT/pipeline/blender/build_moves.py" 2>&1 | grep -E '\[moves\]|Error|Traceback'
reimport
skin="${2:-dummy}"
mkdir -p "$ROOT/shots/moves"
for group in "cast-light,cast-heavy,channel:cast" "idle-breathe,hurt,guard:react" "victory,death,windup:end"; do
	ROOTWARD_SKIN="$skin" ROOTWARD_CLIPS="${group%%:*}" SHOT_SIZE=2560x1440 \
		"$ROOT/scripts/screenshot.sh" res://tools/moves_sheet.tscn "shots/moves/${group##*:}.png" 20
done
if [ "${1:-}" = "--reel" ]; then
	frames="$(mktemp -d)"
	ROOTWARD_SKIN="$skin" xvfb-run -a -s "-screen 0 1920x1080x24" godot --path "$ROOT/game" --resolution 1920x1080 \
		--write-movie "$frames/f.png" --fixed-fps 30 res://tools/moves_reel.tscn < /dev/null > /dev/null 2>&1
	ffmpeg -loglevel error -y -framerate 30 -i "$frames/f%08d.png" -vf "crop=1080:1080:420:0,scale=720:720" -c:v libx264 -pix_fmt yuv420p -crf 18 \
		"$ROOT/shots/moves/reel.mp4"
	ffmpeg -loglevel error -y -framerate 30 -i "$frames/f%08d.png" \
		-vf "crop=1080:1080:420:0,fps=20,scale=420:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$ROOT/shots/moves/reel.gif"
	rm -rf "$frames"
	echo "reel: shots/moves/reel.mp4, shots/moves/reel.gif"
fi
