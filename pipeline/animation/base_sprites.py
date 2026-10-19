#!/usr/bin/env python3
"""The animation base for Lanternroot's characters: one design at several pixel counts, from two sources.

  comfy    ComfyUI (SDXL + Pixel Art XL), rendered once per style. Each asset cuts the same cached render to its own size,
           so the pixel count is the only thing that changes between them (pipeline/art/generate.py: cache, palette lock).
  blender  a character built in code (blender_base.py), rendered large in Blender, then cut the same way.

The outputs go to Concept/v0.3/animation/ (not game/assets/: these are candidates until one is chosen to animate).
scripts/animation.sh runs these with the GPU guard. pipeline/art/generate.py's own CLI writes into game/assets, so only
its functions are used here (resolve, ensure_raws, process, selected).

  uv run --project pipeline python pipeline/animation/base_sprites.py comfy [--only ids] [--force]
  uv run --project pipeline python pipeline/animation/base_sprites.py blender [--only ids] [--force]
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "art"))
import generate as gen  # noqa: E402 (resolve, ensure_raws, process, selected: the shared ComfyUI pipeline)

HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "manifest.json"
DEFAULT_OUT = ROOT / "Concept" / "v0.3" / "animation"
BLENDER_CACHE = ROOT / "pipeline" / "cache" / "animation" / "blender"
BLENDER_SCRIPT = HERE / "blender_base.py"


def write(outputs: list[tuple[str, Image.Image]], out_dir: Path) -> None:
    for name, image in outputs:
        target = out_dir / f"{name}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target, optimize=True)
        try:
            shown = target.relative_to(ROOT)
        except ValueError:
            shown = target
        print(f"  wrote {shown} ({image.width}x{image.height})")


def comfy_stage(manifest: dict, args: argparse.Namespace) -> None:
    comfy = manifest.get("comfy_url", "http://127.0.0.1:8188").rstrip("/")
    for asset in gen.selected(manifest["assets"], args.only):
        if asset["source"] != "comfy":
            continue
        job = gen.resolve(asset, manifest["styles"])
        # LEARN: the sizes share one render through `raw_from` (the first asset renders, the rest cut its cache), so
        # the pixel count is the only change between them (docs/LEARNING_LOG.md, 2026-10-13).
        raws = gen.ensure_raws(comfy, job, args.force, False)
        if raws is None:
            continue
        for index, raw in enumerate(raws):
            outputs = gen.process(job, raw)
            if index == job["pick"]:
                write(outputs, args.out_dir)


def blender_render(asset: dict, args: argparse.Namespace) -> Path | None:
    """The large render of one Blender asset, cached under pipeline/cache/animation/blender/ (rendered when missing)."""
    target = BLENDER_CACHE / f"{asset['id']}.png"
    model = args.out_dir / "models" / f"{asset['id']}.blend"
    if target.exists() and model.exists() and not args.force:
        return target
    blender = os.environ.get("BLENDER") or shutil.which("blender")
    if not blender:
        sys.exit("no blender on PATH (set BLENDER=/path/to/blender)")
    target.parent.mkdir(parents=True, exist_ok=True)
    model.parent.mkdir(parents=True, exist_ok=True)
    command = [
        blender,
        "--background",
        "--factory-startup",
        "--python",
        str(BLENDER_SCRIPT),
        "--",
        "--detail",
        asset["detail"],
        "--out",
        str(target),
        "--blend",
        str(model),
    ]
    print(f"  blender {asset['id']} (detail {asset['detail']})", flush=True)
    subprocess.run(command, check=True)
    return target if target.exists() else None


def blender_stage(manifest: dict, args: argparse.Namespace) -> None:
    for asset in gen.selected(manifest["assets"], args.only):
        if asset["source"] != "blender":
            continue
        raw_path = blender_render(asset, args)
        if raw_path is None:
            sys.exit(f"blender wrote no image for {asset['id']}")
        raw = np.asarray(Image.open(raw_path).convert("RGBA"), dtype=np.float32) / 255
        job = gen.resolve(asset, manifest["styles"])
        write(gen.process(job, raw), args.out_dir)


def review_sheet(entries: list[tuple[str, Image.Image]], path: Path, height: int = 300) -> None:
    """Every picture at one shared height, each scaled by a whole number with nearest-neighbour so its pixels stay square.
    The label gives the pixel count, which is the point of the comparison."""
    cell_w = 220
    columns = 4
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_w, rows * (height + 40)), (38, 40, 34, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (label, image) in enumerate(entries):
        scale = max(1, round(height / image.height))
        big = image.convert("RGBA").resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
        col, row = index % columns, index // columns
        x = col * cell_w + (cell_w - big.width) // 2
        y = row * (height + 40) + (height - big.height)
        sheet.alpha_composite(big, (x, y))
        draw.text((col * cell_w + 6, row * (height + 40) + height + 8), f"{label}  x{scale}", fill=(230, 220, 190, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def sheet_stage(manifest: dict, args: argparse.Namespace) -> None:
    """One picture to compare every candidate, each at its own pixel count."""
    entries = [
        (asset["out"], Image.open(args.out_dir / f"{asset['out']}.png").convert("RGBA")) for asset in manifest["assets"]
    ]
    review_sheet(entries, args.out_dir / "sheet.png")
    print(f"  sheet {args.out_dir / 'sheet.png'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("stage", choices=["comfy", "blender", "sheet"])
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--only", help="comma-separated asset ids; a trailing * matches a prefix")
    parser.add_argument("--force", action="store_true", help="render again even when a cached render matches")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    if args.stage == "comfy":
        comfy_stage(manifest, args)
    elif args.stage == "blender":
        blender_stage(manifest, args)
    else:
        sheet_stage(manifest, args)


if __name__ == "__main__":
    main()
