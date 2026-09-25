"""The spellbook at her left hip: navy boards, an ivory page block, brass corners, a gold star-rune on the cover, a strap
clasp across the fore-edge, and a leather loop over her belt.

Built in the book's own frame (x across the cover toward the fore-edge, y up, z out of the cover) and placed against
her tunic, the cover turned out and a little forward.
"""

from __future__ import annotations

import numpy as np

from . import clothes as C
from . import shapes
from .sdf import RoundBox, Transformed, Union, gradient, normalize, surface_point

W, H, THICK = 0.047, 0.062, 0.017  # half extents
BOARD = 0.0024
ANGLE = np.radians(48.0)  # round from her front toward her left
CENTRE_Z = 0.878


def frame() -> tuple[np.ndarray, np.ndarray]:
    surf = C.tunic_surface()
    direction = np.array([np.sin(ANGLE), -np.cos(ANGLE), 0.0])
    on = surface_point(surf, np.array([0.0, 0.016, CENTRE_Z]), direction)
    n = gradient(surf, on)
    n[2] = 0.0
    n = normalize(n)
    up = np.array([0.0, 0.0, 1.0])
    across = np.cross(n, up)  # toward her front: the fore-edge leads, the spine trails
    origin = on + n * (THICK + 0.010)
    return origin, np.stack([across, up, n], axis=1)


def parts() -> dict:
    boards = Union(
        [
            RoundBox((0, 0, THICK - BOARD), (W, H, BOARD), 0.0018),
            RoundBox((0, 0, -THICK + BOARD), (W, H, BOARD), 0.0018),
            RoundBox((-W + 0.0035, 0, 0), (0.0035, H, THICK), 0.003),  # the spine
        ]
    )
    pages = RoundBox((0.0015, 0, 0), (W - 0.0025, H - 0.0022, THICK - BOARD * 1.6), 0.0012)
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corners.append(
                    RoundBox(
                        (sx * (W - 0.006), sy * (H - 0.006), sz * (THICK - BOARD)),
                        (0.0075, 0.0075, BOARD + 0.0009),
                        0.0015,
                    )
                )
    star = shapes.Badge(
        lambda q: shapes.star4(q, 0.017, 0.026, 0.026, 0.0045),
        (0.002, 0.0, THICK + 0.0004),
        (0, 0, 1),
        (0, 1, 0),
        0.0024,
        0.0008,
        0.03,
    )
    clasp_gold = RoundBox((W - 0.001, 0.0, THICK * 0.2), (0.0035, 0.007, 0.006), 0.0015)
    strap = RoundBox((W - 0.004, 0.0, 0.0), (0.0045, 0.0055, THICK + 0.0012), 0.0015)
    loop = RoundBox((-W + 0.012, H + 0.018, -THICK - 0.001), (0.0065, 0.026, 0.0022), 0.0015)
    origin, axes = frame()

    def place(node):
        return Transformed(node, origin, axes)

    return {
        "cover": place(boards),
        "pages": place(pages),
        "gold": place(Union([*corners, star, clasp_gold])),
        "strap": place(Union([strap, loop])),
    }
