"""Run the existing RIFE + matte workflow on imagegen keyframes packed by import_imagegen_hq.gd.

This only transports the prepared assets through ComfyUI; drawing and alignment are done by imagegen and Godot.
Usage: pipeline/.venv/bin/python pipeline/sprites/interpolate_imagegen.py [clip ...]
"""

import json
import sys
from pathlib import Path

from PIL import Image

from comfy import Comfy, Graph

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "pipeline/cache/sprites/vesper-v2/touch-up"
SOURCE = ROOT / "pipeline/sprites/skins/vesper-v2/imagegen/touch-up"


def main() -> None:
    comfy = Comfy("http://127.0.0.1:8188")
    if not comfy.alive():
        raise SystemExit("Start ComfyUI before interpolating the keyframes.")
    if "--matte-sources" in sys.argv:
        for clip in sys.argv[2:] or ["idle-breathe", "cast-start", "hurt"]:
            graph = Graph("finish")
            with Image.open(SOURCE / f"{clip}.png") as source:
                graph.set("rw:frames-in", image=comfy.upload(source, f"vesper-v2-touch-up-{clip}-source.png"))
            columns = 2 if clip == "cast-anticipation" else 4
            frames = 2 if clip == "cast-anticipation" else 8
            graph.set("rw:cut", columns=columns, frames=frames)
            graph.remove("rw:interp", "rw:interp-model")
            graph.link("rw:matte", "image", "rw:cut")
            graph.set("rw:sheet", columns=columns)
            graph.set("rw:save", filename_prefix=f"rootward/vesper-v2-touch-up/{clip}-matte")
            print(f"{clip}: cleaning source alpha ...", flush=True)
            result = comfy.run(graph)
            output = SOURCE / f"{clip}-matte.png"
            result["rw:save"][0].save(output)
            print(f"Saved {output}", flush=True)
        return
    config = json.loads((CACHE / "config.json").read_text())
    for clip in sys.argv[1:] or config.keys():
        entry = config[clip]
        graph = Graph("finish")
        with Image.open(CACHE / f"{clip}-keys.png") as source:
            graph.set("rw:frames-in", image=comfy.upload(source, f"vesper-v2-touch-up-{clip}-keys.png"))
        graph.set("rw:cut", columns=8, frames=entry["keys"])
        graph.set("rw:interp", multiplier=entry["multiplier"])
        graph.set("rw:save", filename_prefix=f"rootward/vesper-v2-touch-up/{clip}")
        print(f"{clip}: interpolating {entry['keys']} keys at {entry['multiplier']}x ...", flush=True)
        result = comfy.run(graph)
        output = CACHE / f"{clip}-finished.png"
        result["rw:save"][0].save(output)
        print(f"Saved {output}", flush=True)


if __name__ == "__main__":
    main()
