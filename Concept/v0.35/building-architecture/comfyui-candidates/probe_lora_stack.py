"""Controlled SDXL test: Pixel Art XL alone vs Pixel Art XL + DetailN at 0.25, with lineart layout control."""
from __future__ import annotations

import io
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "pipeline/art"))
import generate as art

manifest = json.loads((HERE / "comfyui-manifest.json").read_text())
assets = {a["id"]: a for a in manifest["assets"]}
comfy = manifest.get("comfy_url", "http://127.0.0.1:8188").rstrip("/")

def get_json(url: str, timeout: float = 30) -> dict:
    return json.loads(urllib.request.urlopen(url, timeout=timeout).read())

def run(job: dict, guide: Image.Image, stack: str) -> Image.Image:
    # Use the same camera reference, seed, base checkpoint, pixel LoRA, and guide for each stack comparison.
    init = art.layout_sketch(job)
    control_name = art.upload_image(comfy, guide.convert("RGB"), f"rootward-lineart-{job['id']}.png")
    init_name = art.upload_image(comfy, init, f"rootward-init-{job['id']}.png") if init else None
    prefix = f"rootward-art/building-probe-{job['id']}"
    graph = art.build_graph(job, prefix, control_name, init_name)
    if stack == "detailn-0.25":
        graph["21"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["2", 0], "clip": ["2", 1], "lora_name": "DetialN_XL.safetensors",
                "strength_model": 0.25, "strength_clip": 0.25,
            },
        }
        graph["3"]["inputs"]["clip"] = ["21", 1]
        graph["4"]["inputs"]["clip"] = ["21", 1]
        graph["6"]["inputs"]["model"] = ["21", 0]
    prompt_id = art.http_json(f"{comfy}/prompt", {"prompt": graph, "client_id": "rootward-lora-probe"})["prompt_id"]
    started = time.monotonic()
    while True:
        entry = get_json(f"{comfy}/history/{prompt_id}").get(prompt_id)
        if entry and entry.get("status", {}).get("status_str") == "error":
            raise RuntimeError(json.dumps(entry["status"])[:3000])
        if entry and entry.get("status", {}).get("completed"):
            break
        if time.monotonic() - started > 1200:
            raise TimeoutError(prompt_id)
        time.sleep(1)
    outs = []
    for node in ("8", "11"):
        item = entry["outputs"][node]["images"][0]
        q = urllib.parse.urlencode({"filename":item["filename"],"subfolder":item["subfolder"],"type":item["type"]})
        image_data = urllib.request.urlopen(f"{comfy}/view?{q}",timeout=120).read()
        image = Image.open(io.BytesIO(image_data)).copy()
        outs.append(image)
    rgb, mask = outs
    source = rgb.convert("RGBA"); source.putalpha(mask.convert("L"))
    outdir = HERE / "lora-probe"
    outdir.mkdir(exist_ok=True)
    source.save(outdir / f"{job['id']}-{stack}-source.png", optimize=True)
    raw = np.asarray(source, dtype=np.float32) / 255.0
    processed = art.process(job, raw)[0][1]
    processed.save(outdir / f"{job['id']}-{stack}-fitted.png", optimize=True)
    return processed

comparisons = []
for asset_id, guide_file, size, denoise in (
    ("home-front-plane-v4", "home-v4-lineart.png", (1024,1024), 0.58),
    ("workshop-front-plane-v4", "workshop-v4-lineart.png", (1152,1024), 0.76),
):
    asset = assets[asset_id]
    guide = Image.open(HERE / "lineart-guides" / guide_file).convert("RGB")
    for stack in ("pixelart-only", "detailn-0.25"):
        job = art.resolve(asset, manifest["styles"])
        job["width"], job["height"] = size
        job["init"] = {"image":manifest["_reference"],"denoise":denoise,"matte":"#ffffff"}
        job["control"] = {"model":"t2i-adapter_diffusers_xl_lineart.safetensors","strength":0.85,"start":0.0,"end":0.9}
        job["seed"] = 20261025 if asset_id.startswith("home") else 20261026
        job["id"] = f"{asset_id}-{stack}"
        job["out"] = f"Concept/v0.35/building-architecture/comfyui-candidates/lora-probe/{job['id']}"
        if stack == "pixelart-only":
            job["lora"] = "pixel-art-xl-v1.1.safetensors"
        else:
            job["lora"] = "pixel-art-xl-v1.1.safetensors"
        print(f"rendering {job['id']}", flush=True)
        image = run(job,guide,stack)
        comparisons.append((f"{asset_id} {stack}",image))
art.contact_sheet(comparisons,HERE/"lora-probe"/"lora-stack-comparison.png",cell=256)
print("comparison sheet:",HERE/"lora-probe"/"lora-stack-comparison.png")
