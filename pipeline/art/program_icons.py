#!/usr/bin/env python3
"""Record imagegen outputs, lay out review boards, and copy accepted originals without repainting them.

Run with the pipeline environment or ComfyUI's Python (Pillow). The pass manifest keeps exact prompts,
canonical texture references and provenance. Review thumbnails never replace the generated original.
"""

import argparse
import hashlib
import io
import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("program-icons-pass-9.json")
BEFORE = Path("/tmp/rootward-program-art-before")


def inspect(path):
    with Image.open(path) as image:
        if image.mode != "RGBA" or image.getextrema()[3][0] != 0:
            raise ValueError(f"{path}: expected transparent RGBA original")
        if min(image.size) <= 32:
            raise ValueError(f"{path}: still a low-resolution placeholder")
        return list(image.size)


def preview(canvas, path, size, x, y):
    with Image.open(path) as source:
        picture = source.convert("RGBA")
        picture.thumbnail((size, size), Image.Resampling.NEAREST)
        canvas.alpha_composite(picture, (x + (size - picture.width) // 2, y + (size - picture.height) // 2))


def board(manifest, destination, wanted=None, all_cards=False):
    entries = []
    for name, card in manifest["cards"].items():
        asset = manifest["assets"][card["icon"]]
        if wanted and name not in wanted:
            continue
        if all_cards or asset["status"] in ("candidate", "accepted"):
            entries.append((name, card, asset))
    columns, width, height = 6, 232, 226
    canvas = Image.new("RGBA", (columns * width, ((len(entries) + columns - 1) // columns) * height), "#24212a")
    draw = ImageDraw.Draw(canvas)
    for index, (name, card, asset) in enumerate(entries):
        x, y = (index % columns) * width, (index // columns) * height
        source = Path(asset.get("source", ROOT / asset["out"]))
        if not source.exists():
            source = ROOT / asset["out"]
        original = BEFORE / f"card-{name}.png"
        if not original.exists():
            result = subprocess.run(
                ["git", "show", f"{manifest['baseline_commit']}:game/assets/shardrun/card-{name}.png"],
                cwd=ROOT, capture_output=True, check=True,
            )
            original = io.BytesIO(result.stdout)
        preview(canvas, source, 128, x + 96, y + 4)
        preview(canvas, original, 32, x + 8, y + 146)
        preview(canvas, source, 32, x + 52, y + 146)
        preview(canvas, source, 64, x + 112, y + 132)
        draw.text((x + 8, y + 8), "128px", fill="#9e9690")
        draw.text((x + 8, y + 132), "old/new", fill="#bcb4aa")
        draw.text((x + 8, y + 193), name, fill="#ffdc9b")
        draw.text((x + 8, y + 209), card["icon"].removeprefix("shardrun/"), fill="#bcb4aa")
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(destination)
    print(f"Review: {destination} ({len(entries)} cards at 32, 64 and 128 pixels)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("record", "board", "accept", "check"))
    parser.add_argument("--records", type=Path, help="JSON records keyed by canonical texture id")
    parser.add_argument("--out", type=Path, help="review board path")
    parser.add_argument("--only", help="comma-separated base card ids")
    parser.add_argument("--all", action="store_true", help="include reused and existing icons on the board")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    wanted = set(args.only.split(",")) if args.only else None
    if args.command == "record":
        for icon, record in json.loads(args.records.read_text()).items():
            source = Path(record["source"])
            asset = manifest["assets"][icon]
            asset.update(record, status="candidate", size=inspect(source))
            asset["sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
            print(f"Candidate: {icon} {asset['size']}")
    elif args.command == "board":
        board(manifest, args.out, wanted, args.all)
        return
    elif args.command == "accept":
        for icon, asset in manifest["assets"].items():
            if asset["status"] != "candidate" or (wanted and not wanted.intersection(asset["cards"])):
                continue
            source = Path(asset["source"])
            inspect(source)
            shutil.copy2(source, ROOT / asset["out"])
            asset.update(status="accepted", review_sizes=[32, 64, 128])
            print(f"Accepted original: {asset['out']}")
    else:
        problems = []
        for icon, asset in manifest["assets"].items():
            try:
                inspect(ROOT / asset["out"])
                if asset["status"] == "accepted":
                    actual = hashlib.sha256((ROOT / asset["out"]).read_bytes()).hexdigest()
                    if actual != asset["sha256"]:
                        problems.append(f"{icon}: differs from recorded generated original")
                elif asset["status"] != "existing":
                    problems.append(f"{icon}: still {asset['status']}")
            except (ValueError, FileNotFoundError) as error:
                problems.append(str(error))
        if problems:
            raise SystemExit("\n".join(problems))
        print(f"All {len(manifest['cards'])} cards resolve to finished transparent art; originals verified.")
        return
    # Each card keeps its sharing category; only newly painted designs change status.
    for card in manifest["cards"].values():
        if card["status"] == "pending" and manifest["assets"][card["icon"]]["status"] == "accepted":
            card["status"] = "repainted"
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
