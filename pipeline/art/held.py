"""Turning a blockout into art and holding it there: shared by the cast (pipeline/animation/cast.py, ADR-0063) and the
world's objects (pipeline/world/world.py, ADR-0064).

A Blender blockout fixes a picture's proportions; ComfyUI restyles it. Of the candidates, the one whose outline
overlaps the blockout's most is kept, and it is cut back to the blockout's outline (grown a little), so the restyle can
add detail but cannot change the shape. Also the JSONC reader both pipelines use for the game's content.
"""

from __future__ import annotations

import json
import re

import numpy as np
from PIL import Image, ImageFilter


def read_jsonc(text: str) -> object:
    """JSON with // comments and trailing commas, as the game's content is written. Comments inside strings stay."""
    out: list[str] = []
    i, in_string = 0, False
    while i < len(text):
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < len(text):
                out.append(text[i + 1])
                i += 2
                continue
            in_string = ch != '"'
            i += 1
            continue
        if ch == '"':
            in_string = True
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
            continue
        out.append(ch)
        i += 1
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))


def iou(a: np.ndarray, b: np.ndarray) -> float:
    """How much two alpha masks overlap: shared area over combined area, 0 to 1."""
    solid_a, solid_b = a > 0.5, b > 0.5
    union = np.logical_or(solid_a, solid_b).sum()
    return float(np.logical_and(solid_a, solid_b).sum() / union) if union else 0.0


def pick(raws: list[np.ndarray], turn_alpha: np.ndarray, override: int | None = None) -> tuple[int, list[float]]:
    """The candidate whose outline best matches the blockout's, or the override; with every candidate's score."""
    scores = [iou(raw[..., 3], turn_alpha) for raw in raws]
    return (override if override is not None else int(np.argmax(scores))), scores


def grow(mask: np.ndarray, radius: int) -> np.ndarray:
    """A mask grown by about `radius` pixels in every direction (worked at an eighth of the size, which is plenty)."""
    height, width = mask.shape
    step = 8
    small = Image.fromarray((mask > 0.5).astype(np.uint8) * 255).resize(
        (max(1, width // step), max(1, height // step)), Image.Resampling.BOX
    )
    size = 2 * max(1, round(radius / step)) + 1
    grown = small.point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(size))
    return np.asarray(grown.resize((width, height), Image.Resampling.NEAREST)) > 0


def guarded(raw: np.ndarray, turn_alpha: np.ndarray, radius: int) -> np.ndarray:
    """The restyle kept inside the blockout's outline (grown by `radius`), so it cannot change the proportions."""
    out = raw.copy()
    out[..., 3] = np.where(grow(turn_alpha, radius), raw[..., 3], 0.0)
    return out
