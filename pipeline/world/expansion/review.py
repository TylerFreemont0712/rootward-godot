"""Build labeled contact sheets for the Lanternroot catalog expansions.

Run from the repository root with pipeline/.venv/bin/python. Each sprite is
shown nearest-neighbour at 2x or 3x on a plain, neutral background. Missing
sprites remain visible as labeled placeholders so incomplete generation is
easy to spot.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
METADATA = Path(__file__).resolve().parent
SPRITES = ROOT / "game" / "assets" / "overworld" / "world"
OUTPUT = ROOT / "shots" / "studio"

# Keep the source files and their group names explicit. imagegen-sources.json
# describes prompts and is intentionally not a catalog group.
GROUPS = {
    "boundaries": "boundaries.json",
    "furniture": "furniture.json",
    "nature-work": "nature-work.json",
    "imagegen": "imagegen.json",
}

CELL_W = 440
CELL_H = 530
GAP = 14
COLUMNS = 4
HEADER_H = 58
BACKGROUND = (45, 42, 49, 255)
CELL = (59, 55, 62, 255)
INK = (241, 231, 216, 255)
MUTED = (184, 174, 176, 255)
MISSING = (255, 143, 137, 255)


def render_group(group: str, metadata_file: str) -> tuple[Path, list[str]]:
    entries = json.loads((METADATA / metadata_file).read_text(encoding="utf-8"))
    if not isinstance(entries, dict):
        raise ValueError(f"{metadata_file} must contain an object keyed by asset id")

    ordered = sorted(entries.items())
    rows = (len(ordered) + COLUMNS - 1) // COLUMNS
    sheet = Image.new(
        "RGBA",
        (GAP + COLUMNS * (CELL_W + GAP), HEADER_H + GAP + rows * (CELL_H + GAP)),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=17)
    draw.text((GAP, 16), f"{group}  |  {len(ordered)} assets", fill=INK, font=font)
    missing: list[str] = []

    for index, (asset_id, info) in enumerate(ordered):
        x = GAP + (index % COLUMNS) * (CELL_W + GAP)
        y = HEADER_H + GAP + (index // COLUMNS) * (CELL_H + GAP)
        draw.rounded_rectangle((x, y, x + CELL_W, y + CELL_H), radius=8, fill=CELL)

        image_path = SPRITES / f"{asset_id}.png"
        if image_path.is_file():
            with Image.open(image_path) as opened:
                sprite = opened.convert("RGBA")
            max_w, max_h = CELL_W - 28, CELL_H - 116
            scale = 3 if sprite.width * 3 <= max_w and sprite.height * 3 <= max_h else 2
            sprite = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
            px = x + (CELL_W - sprite.width) // 2
            py = y + 18 + (max_h - sprite.height) // 2
            sheet.alpha_composite(sprite, (px, py))
        else:
            missing.append(asset_id)
            box = (x + 28, y + 32, x + CELL_W - 28, y + CELL_H - 126)
            draw.rectangle(box, outline=MISSING, width=3)
            draw.text((box[0] + 12, box[1] + 12), "MISSING SPRITE", fill=MISSING, font=font)
            draw.text((box[0] + 12, box[1] + 34), image_path.name, fill=MUTED, font=font)

        name = str(info.get("name", asset_id))
        size = info.get("size", [1, 1])
        size_label = f"{size[0]} x {size[1]} tiles" if isinstance(size, list) and len(size) == 2 else "size unknown"
        draw.text((x + 12, y + CELL_H - 75), name, fill=INK, font=font)
        draw.text((x + 12, y + CELL_H - 54), asset_id, fill=MUTED, font=font)
        draw.text((x + 12, y + CELL_H - 33), size_label, fill=MUTED, font=font)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT / f"expansion-{group}.png"
    sheet.convert("RGB").save(destination)
    return destination, missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("groups", nargs="*", choices=GROUPS, help="groups to render; defaults to all four")
    args = parser.parse_args()
    groups = args.groups or list(GROUPS)
    had_missing = False
    for group in groups:
        destination, missing = render_group(group, GROUPS[group])
        suffix = f"; missing sprites: {', '.join(missing)}" if missing else "; all sprites present"
        print(f"{destination.relative_to(ROOT)}{suffix}")
        had_missing |= bool(missing)
    return 1 if had_missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
