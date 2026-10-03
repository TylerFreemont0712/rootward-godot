#!/usr/bin/env python3
"""Review named imagegen candidates at inventory and card sizes, then copy selected originals.

Use ComfyUI's Python (Pillow is already installed). Generation prompts and candidate paths
live in sprite-polish-pass-8.json. This script only lays out review boards and copies files;
it does not repaint, remove backgrounds, or change the generated artwork.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("sprite-polish-pass-8.json")


def board(entries, output):
    columns, width, height = 6, 216, 206
    canvas = Image.new("RGBA", (columns * width, ((len(entries) + columns - 1) // columns) * height), "#222731")
    draw = ImageDraw.Draw(canvas)
    for index, (name, record) in enumerate(entries):
        x, y = (index % columns) * width, (index // columns) * height
        original = Path("/tmp/rootward-icon-backups") / Path(record["out"]).name
        old = Image.open(original if original.exists() else ROOT / record["out"]).convert("RGBA")
        new = Image.open(ROOT / record["source"]).convert("RGBA")
        canvas.alpha_composite(new.resize((128, 128), Image.Resampling.NEAREST), (x + 72, y + 8))
        for image, dx in ((old, 8), (new, 42)):
            canvas.alpha_composite(image.resize((32, 32), Image.Resampling.NEAREST), (x + dx, y + 142))
        draw.text((x + 8, y + 177), name, fill="#ffffff")
        label = "accepted" if record["status"] == "accepted" else "candidate"
        draw.text((x + 8, y + 191), f"before / {label} (32px)", fill="#a6b4c8")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", choices=("shards", "relics"))
    parser.add_argument("--only", help="comma separated ids")
    parser.add_argument("--board", type=Path)
    parser.add_argument("--accept", action="store_true")
    parser.add_argument("--capture", action="store_true", help="capture accepted icons in actual run layouts")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    wanted = set(args.only.split(",")) if args.only else None
    entries = [
        (name, item) for name, item in manifest[args.group].items()
        if item.get("source") and item.get("status") in ("candidate", "accepted")
        and (wanted is None or name in wanted)
    ]
    if not entries:
        raise SystemExit("No generated candidates selected")
    if args.board:
        board(entries, args.board)
        print(f"Review: {args.board} ({len(entries)} icons)")
    if args.accept:
        for name, item in entries:
            source = ROOT / item["source"]
            destination = ROOT / item["out"]
            with Image.open(source) as image:
                if image.mode != "RGBA" or image.getextrema()[3][0] != 0:
                    raise SystemExit(f"{name}: expected a transparent RGBA original")
                item["size"] = list(image.size)
            backup = Path("/tmp/rootward-icon-backups") / destination.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(destination, backup)
            shutil.copy2(source, destination)
            item["status"] = "accepted"
            item["review_sizes"] = [32, 128]
            print(f"Accepted: {item['out']}")
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    if args.capture:
        selected = [(name, item) for name, item in entries if item["status"] == "accepted"]
        modes = {"deck": selected} if args.group == "shards" else {"spellbook": [], "deck": [], "program": []}
        if args.group == "relics":
            for name, item in selected:
                content = ROOT / "game/content/packs/core/shardrun/relics" / (name + ".jsonc")
                mode = "program"
                if content.exists():
                    relic = json.loads(re.sub(r"(?m)^\s*//.*$", "", content.read_text()))
                    mode = "deck" if relic.get("playstyles") == ["deck"] else "spellbook"
                modes[mode].append((name, item))
        for mode, icons in modes.items():
            count = 4 if args.group == "shards" else 8
            for offset in range(0, len(icons), count):
                names = [name for name, _ in icons[offset:offset + count]]
                path = f"shots/polish/{args.group}-pass8-{mode}-{offset // count + 1:02d}.png"
                env = {**os.environ, "ROOTWARD_SHOT_PLAYSTYLE": mode, "ROOTWARD_SHOT": "fight"}
                env["ROOTWARD_SHOT_HAND" if args.group == "shards" else "ROOTWARD_SHOT_RELICS"] = ",".join(names)
                subprocess.run(
                    [str(ROOT / "scripts/screenshot.sh"), "res://tools/shardrun_shot.tscn", path, "60"],
                    env=env, cwd=ROOT, check=True,
                )
                manifest.setdefault("review_screenshots", [])
                if path not in manifest["review_screenshots"]:
                    manifest["review_screenshots"].append(path)
                MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
                print(f"Captured {names}: {path}", flush=True)


if __name__ == "__main__":
    main()
