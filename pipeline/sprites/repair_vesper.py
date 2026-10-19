"""Interpolate only the selected repair spans; artwork edits come from built-in ChatGPT imagegen."""

import json
import sys
from pathlib import Path

from PIL import Image

from comfy import Comfy, Graph

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "pipeline/cache/sprites/vesper-v1-5"


def main() -> None:
    config = json.loads((CACHE / "config.json").read_text())
    comfy = Comfy("http://127.0.0.1:8188")
    if not comfy.alive():
        raise SystemExit("Start ComfyUI on port 8188 before interpolating the repair spans.")
    for clip, entry in config.items():
        if sys.argv[1:] and clip not in sys.argv[1:]:
            continue
        graph = Graph("finish")
        with Image.open(CACHE / f"{clip}-repair-keys.png") as source:
            graph.set("rw:frames-in", image=comfy.upload(source, f"vesper15-{clip}-repair-keys.png"))
        graph.set("rw:cut", columns=8, frames=entry["keys"])
        graph.set("rw:interp", multiplier=entry["multiplier"])
        graph.set("rw:save", filename_prefix=f"rootward/vesper15/{clip}-repair")
        print(f"{clip}: interpolate selected repair poses ...", flush=True)
        result = comfy.run(graph)
        result["rw:save"][0].save(CACHE / f"{clip}-repair-finished.png")
        print(f"Saved repaired span: {clip}", flush=True)


if __name__ == "__main__":
    main()
