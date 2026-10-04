#!/usr/bin/env python3
"""The Paradigm Update's first-draft art (docs/ParadigmUpdate.md, B11): writes manifest-paradigm-update.json, which
`scripts/art.sh --manifest pipeline/art/manifest-paradigm-update.json --only '<ids>'` renders through ComfyUI into
game/assets/. The card icons come from the subjects recorded beside each batch of cards (pass10-fragments/*.json and
program-icons-pass-10.json); everything else is listed here. These are drafts: pass 10 of the finished icons
(program_icons.py) replaces them later, under the same names.
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
STYLE = {
    "checkpoint": "sd_xl_base_1.0.safetensors",
    "prefix": "(single object:1.3), fantasy rpg game item icon, polished digital painting, bronze and gold metalwork, "
    "faceted glowing crystals, bold dark plum outline, ",
    "suffix": ", centered, whole object visible, plain white background, clean silhouette",
    "negative": "blurry, text, letters, words, numbers, watermark, signature, logo, person, people, woman, man, "
    "character, body, face, hands, scenery, landscape, multiple objects, collage, tileset, grid, frame, border, cropped, photo, realistic, 3d render",
    "width": 1024, "height": 1024, "steps": 28, "cfg": 6, "sampler": "euler_ancestral", "scheduler": "normal",
    "rmbg": True, "candidates": 1,
    "post": {"kind": "picture", "size": [320, 320], "transparent": True, "colors": 160, "saturation": 1.08},
}
BACKDROP_STYLE = {
    "checkpoint": "novaAnimeXL_ilV190.safetensors",
    "prefix": "masterpiece, best quality, very aesthetic, detailed fantasy game background illustration, ",
    "suffix": ", warm lamplight, rich bronze and amber tones, no people, no text",
    "negative": "worst quality, low quality, blurry, text, letters, watermark, signature, person, character, face, modern",
    "width": 1344, "height": 768, "steps": 28, "cfg": 6, "sampler": "euler_ancestral", "scheduler": "normal",
    "rmbg": False, "candidates": 2,
    "post": {"kind": "picture", "size": [1344, 768], "colors": 128},
}

ENGINE_CARDS = {
    "prefetch": "a bronze hand reaching into a card-shaped slot ahead of a moving crystal, two card backs peeking out",
    "tail-call": "a bronze serpent biting its own tail to form a loop, one faceted cyan crystal riding smoothly around it",
    "bottom-up": "a short bronze staircase of three stone steps, each step holding a larger faceted crystal than the one below",
    "b-tree": "a wide bronze tree with short thick branches, each branch holding a small tray of three ordered faceted crystals",
}


def seed_of(name: str) -> int:
    return int.from_bytes(name.encode()[:4].ljust(4, b"0"), "big") % 1_000_000 + sum(map(ord, name)) * 31


def asset(asset_id: str, out: str, subject: str, style: str = "program-icon", **extra) -> dict:
    return {"id": asset_id, "out": out, "style": style, "seed": seed_of(asset_id), "prompt": f"({subject}:1.35)", "pick": 0, **extra}


def card_subjects() -> dict[str, str]:
    subjects: dict[str, str] = {}
    for path in sorted((HERE / "pass10-fragments").glob("*.json")):
        for card_id, entry in json.loads(path.read_text())["cards"].items():
            subjects[card_id] = entry["subject"]
    pass10 = HERE / "program-icons-pass-10.json"
    if pass10.exists():
        for icon, entry in json.loads(pass10.read_text())["assets"].items():
            if entry.get("status") == "queued" and entry.get("subject"):
                subjects[icon.removeprefix("shardrun/card-")] = entry["subject"]
    subjects.update(ENGINE_CARDS)
    return subjects


def extras() -> list[dict]:
    """Assets beyond the cards: the file `paradigm_update_art_extra.py` (when present) lists them."""
    path = HERE / "paradigm_update_art_extra.py"
    if not path.exists():
        return []
    scope: dict = {}
    exec(path.read_text(), {"asset": asset, "HERE": str(HERE)}, scope)
    return scope["ASSETS"]


def main() -> None:
    assets = [asset(f"shardrun-card-{cid}", f"shardrun/card-{cid}", subject) for cid, subject in sorted(card_subjects().items())]
    assets += extras()
    manifest = {"comfy_url": "http://127.0.0.1:8188", "styles": {"program-icon": STYLE, "program-backdrop": BACKDROP_STYLE}, "assets": assets}
    (HERE / "manifest-paradigm-update.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"{len(assets)} assets")


if __name__ == "__main__":
    main()
