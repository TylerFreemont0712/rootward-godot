#!/usr/bin/env python3
"""Turn a transparent imagegen source into a palette-locked review candidate, without writing game assets.

    pipeline/.venv/bin/python pipeline/pixel/imagegen_candidate.py source.png --asset-id ow-landmark-rootgate

The manifest's sprite size, colour count, outline and palette lock are applied through pipeline/art/generate.py. The
result is saved under pipeline/pixel/candidates/ and checked by the same pixel lint used for game assets.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import pixelkit

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ART = ROOT / "pipeline" / "art"
sys.path.insert(0, str(ART))
import generate  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="transparent PNG from an approved imagegen pass")
    parser.add_argument("--asset-id", default="ow-landmark-rootgate", help="manifest asset whose sprite settings to use")
    parser.add_argument("--out", type=Path, help="candidate PNG; defaults under pipeline/pixel/candidates/")
    parser.add_argument("--force", action="store_true", help="replace an existing candidate at --out")
    args = parser.parse_args()

    source_path = args.source.expanduser().resolve()
    if not source_path.is_file():
        parser.error(f"source image does not exist: {source_path}")

    manifest_path = HERE / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    asset = next((entry for entry in manifest["assets"] if entry["id"] == args.asset_id), None)
    if asset is None:
        parser.error(f"unknown manifest asset: {args.asset_id}")
    job = generate.resolve(asset, manifest["styles"])
    post = job["post"]
    if post.get("kind") != "sprite" or not post.get("lock"):
        parser.error(f"{args.asset_id} must use a palette-locked sprite postprocess")

    source = Image.open(source_path).convert("RGBA")
    rgba = np.asarray(source, dtype=np.uint8)
    if not np.any(rgba[..., 3] < 255):
        parser.error("source PNG must already have transparent background pixels")

    candidate_root = HERE / "candidates"
    if candidate_root.is_symlink():
        parser.error(f"candidate directory must not be a symlink: {candidate_root}")
    default_name = f"{args.asset_id}-imagegen.png"
    target = args.out if args.out is not None else candidate_root / default_name
    if not target.is_absolute():
        target = ROOT / target
    target = target.resolve()
    try:
        target.relative_to(candidate_root.resolve())
    except ValueError:
        parser.error(f"candidate output must stay under {candidate_root}")
    if target.exists() and not args.force:
        parser.error(f"candidate already exists: {target} (pass --force to replace it)")

    raw = rgba.astype(np.float32) / 255.0
    outputs = generate.process(job, raw)
    if len(outputs) != 1:
        parser.error(f"{args.asset_id} produced {len(outputs)} outputs; expected one sprite candidate")
    _, image = outputs[0]
    expected_size = tuple(post["size"])
    if image.size != expected_size:
        parser.error(f"postprocess returned {image.size}, expected {expected_size}")

    palette = pixelkit.Palette.load()
    problems = pixelkit.problems(np.asarray(image.convert("RGBA")), palette, target.name)
    if problems:
        for problem in problems:
            print(f"  not crisp: {problem}", file=sys.stderr)
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)
    print(f"candidate {target.relative_to(ROOT)} ({image.width}x{image.height}; transparent alpha; palette locked)")
    print(f"source {source_path}")
    print("lint: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
