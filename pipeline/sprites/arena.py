#!/usr/bin/env python3
"""Painted, high-resolution arenas and title art (ADR-0010), redrawn from the pixel-art ones.

  scripts/sprites.sh arena                         render candidates for every arena (cached), write a contact sheet
  scripts/sprites.sh arena --only arena-kiln       one
  scripts/sprites.sh arena --pick arena-kiln=1     keep candidate 1 as game/assets/backgrounds/arena-kiln.webp

The old 720x300 pixel art is the starting picture (img2img at `denoise`), so a room keeps its composition, and so its
floor line, while every detail is repainted; a hires pass (latent upscale x1.5, a second lighter denoise, a tiled
decode that fits in 8 GB) gives 2304x960. The game prefers the WebP over the old PNG of the same name.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from comfy import Comfy, Graph  # noqa: E402

REPO = HERE.parents[1]
BACKGROUNDS = REPO / "game" / "assets" / "backgrounds"
CACHE = REPO / "pipeline" / "cache" / "sprites" / "arenas"
MANIFEST = REPO / "pipeline" / "art" / "manifest.json"

STYLE = {
    "prefix": (
        "masterpiece, best quality, newest, anime background art, scenery, no humans, detailed painted background, "
        "cinematic lighting, "
    ),
    "suffix": (
        ", wide shot at eye level, a wide empty flat floor in the foreground across the whole width, depth, "
        "atmospheric perspective, volumetric light, rich detail"
    ),
    "negative": (
        "worst quality, low quality, blurry, pixel art, pixelated, low resolution, jpeg artifacts, text, watermark, "
        "signature, logo, people, person, character, creature, monster, animal, statue, ui, frame, border, cropped, "
        "split screen"
    ),
}
# Which pixel-art pictures to redraw, with the manifest entry their prompt comes from.
ROOMS = {
    "arena-salvage": "shardrun-arena-salvage",
    "arena-heap": "shardrun-arena-heap",
    "arena-kernel": "shardrun-arena-kernel",
    "arena-kiln": "shardrun-arena-kiln",
    "arena-vault": "shardrun-arena-vault",
    "arena-throne": "shardrun-arena-throne",
    "title": "brand-title-backdrop",
}


def prompts() -> dict[str, dict]:
    assets = {a["id"]: a for a in json.loads(MANIFEST.read_text())["assets"]}
    return {room: assets[asset] for room, asset in ROOMS.items()}


def init_picture(room: str, size: tuple[int, int]) -> Image.Image:
    """The pixel-art picture, scaled up and softened: its blocks must not be read as detail to keep."""
    old = Image.open(BACKGROUNDS / f"{room}.png").convert("RGB")
    big = old.resize(size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(radius=size[1] * 0.006))
    grain = np.random.default_rng(len(room)).normal(0, 7, (size[1], size[0], 1))
    return Image.fromarray(np.clip(np.asarray(big, dtype=np.float32) + grain, 0, 255).astype(np.uint8))


def render(comfy: Comfy, room: str, asset: dict, seed: int, denoise: float) -> Image.Image:
    old = Image.open(BACKGROUNDS / f"{room}.png")
    aspect = old.width / old.height
    height = 640 if aspect > 1.9 else 768
    size = (round(height * aspect / 64) * 64, height)
    graph = Graph("arena")
    graph.set("rw:layout", image=comfy.upload(init_picture(room, size), f"arena-{room}-init.png"))
    graph.set("rw:positive", text=STYLE["prefix"] + asset["prompt"] + STYLE["suffix"])
    graph.set("rw:negative", text=STYLE["negative"] + ", " + asset.get("negative", ""))
    graph.set("rw:base", seed=seed, denoise=denoise)
    graph.set("rw:hires", seed=seed + 1)
    graph.set("rw:save", filename_prefix=f"rootward/arenas/{room}")
    return comfy.run(graph)["rw:save"][0].convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--comfy", default="http://127.0.0.1:8188")
    parser.add_argument("--only")
    parser.add_argument("--candidates", type=int, default=2)
    parser.add_argument("--denoise", type=float, default=0.68)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--pick", help="room=candidate, comma separated")
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    if args.pick:
        for choice in args.pick.split(","):
            room, _, index = choice.partition("=")
            picture = Image.open(CACHE / f"{room}-{index}.png").convert("RGB")
            picture.save(BACKGROUNDS / f"{room}.webp", quality=90, method=6)
            print(f"kept {room} candidate {index} -> {BACKGROUNDS / f'{room}.webp'}")
        return
    rooms = prompts()
    wanted = [r for r in rooms if not args.only or r in args.only.split(",")]
    comfy = Comfy(args.comfy)
    shots: list[tuple[str, Image.Image]] = []
    for room in wanted:
        for index in range(args.candidates):
            path = CACHE / f"{room}-{index}.png"
            if args.force or not path.exists():
                render(comfy, room, rooms[room], 4000 + 97 * index + len(room), args.denoise).save(path)
                print(f"{room} candidate {index} rendered", flush=True)
            shots.append((f"{room} {index}", Image.open(path).convert("RGB")))
    thumb_w = 640
    rows = [shots[i : i + args.candidates] for i in range(0, len(shots), args.candidates)]
    thumb_h = max(round(thumb_w * s.height / s.width) for _, s in shots)
    sheet = Image.new("RGB", (thumb_w * args.candidates, (thumb_h + 20) * len(rows)), (16, 14, 20))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(rows):
        for c, (name, shot) in enumerate(row):
            small = shot.resize((thumb_w, round(thumb_w * shot.height / shot.width)))
            sheet.paste(small, (c * thumb_w, r * (thumb_h + 20) + 20))
            draw.text((c * thumb_w + 6, r * (thumb_h + 20) + 4), name, fill="white")
    sheet.save(CACHE / "contact.png")
    print(f"contact sheet {CACHE / 'contact.png'}, then: arena --pick room=n,...")


if __name__ == "__main__":
    main()
