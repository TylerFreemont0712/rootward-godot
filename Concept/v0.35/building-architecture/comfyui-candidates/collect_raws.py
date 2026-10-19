"""Copy the transparent source images for completed candidate jobs out of pipeline/cache/art."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
PROMPTS = json.loads((HERE / "candidate-prompts.json").read_text())
CACHE = ROOT / "pipeline/cache/art"

for asset in PROMPTS["assets"]:
    job_id = asset["comfy_job_id"]
    target = ROOT / asset["output_source"]
    if target.exists():
        print(f"keep existing {target.relative_to(ROOT)}")
        continue
    folder = CACHE / job_id
    rgb_path, mask_path = folder / "rgb_0.png", folder / "mask_0.png"
    if not rgb_path.exists() or not mask_path.exists():
        raise SystemExit(f"missing completed RGB/mask pair for {job_id} in {folder}")
    rgb = Image.open(rgb_path).convert("RGB")
    alpha = Image.open(mask_path).convert("L")
    if rgb.size != alpha.size:
        raise SystemExit(f"RGB/mask size mismatch for {job_id}: {rgb.size} vs {alpha.size}")
    rgb.putalpha(alpha)
    target.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(target, optimize=True)
    print(f"wrote {target.relative_to(ROOT)} ({rgb.width}x{rgb.height}, RGBA)")
