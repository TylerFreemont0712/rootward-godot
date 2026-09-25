"""Fingerless gloves: dark fitted leather over the palm and the first half of each finger, a gold band at the wrist, and
a flared gauntlet cuff up the forearm with two raised points, gold-edged, a navy lining and a gold star on the back.
"""

from __future__ import annotations

import numpy as np

from . import anatomy as A
from . import hands as Hn
from . import shapes
from .cloth import Sheet, mirrored
from .sdf import Field, Mirror, Offset, RoundCone, Union, normalize, smax


def _cuff_frame():
    wrist, along, thumb, palm = A.hand_frame()
    up = -normalize(A.ARM["wrist"] - A.ARM["elbow"])  # up the forearm
    # Angle round the forearm measured from the back of the hand (0) toward the thumb.
    back = -palm
    return wrist, up, back, np.cross(up, back)


def _cuff_coords(p: np.ndarray):
    wrist, up, back, side = _cuff_frame()
    q = p - wrist
    s = q @ up
    radial = q - np.outer(s, up)
    rho = np.linalg.norm(radial, axis=1)
    phi = np.arctan2(radial @ side, radial @ back)
    return s, rho, phi


CUFF_R0, CUFF_FLARE = 0.0265, 0.36


def _cuff_top(phi: np.ndarray) -> np.ndarray:
    """Height of the cuff's rim up the forearm: two points, over the back of the wrist and on the thumb side."""
    return 0.070 + 0.018 * np.cos(2.0 * (phi - 0.35)) ** 3


def glove_left() -> dict:
    hand = Hn.hand_left(finger_upto=0.58, thumb_upto=1.55)
    leather = Offset(hand, 0.0013)
    wrist, up, back, side = _cuff_frame()
    # The glove runs up under the cuff to meet it.
    sleeve = RoundCone(wrist - up * 0.012, wrist + up * 0.03, 0.0235, 0.0245)

    def band(p):
        s, rho, phi = _cuff_coords(p)
        d = rho - 0.0262
        return smax(np.abs(d) - 0.0022, np.abs(s - 0.004) - 0.0032, 0.0008)

    lo = wrist - 0.075
    hi = wrist + 0.075
    star_c = wrist + up * 0.040 + back * (CUFF_R0 + CUFF_FLARE * 0.034**1.15 * 1.6 + 0.0028)
    star = shapes.Badge(
        lambda q: shapes.star4(q, 0.011, 0.016, 0.016, 0.0028), star_c, back + up * 0.3, up, 0.0026, 0.0007, 0.025
    )
    return {
        "leather": Union([leather, sleeve]),
        "gold": Union([Field(band, lo, hi), star]),
    }


def gloves() -> dict:
    left = glove_left()
    return {f"{k}_{s}": (v if s == "l" else Mirror(v)) for k, v in left.items() for s in ("l", "r")}


def cuff_sheet() -> Sheet:
    """The gauntlet cuff as one sheet: dark leather outside, navy lining inside, a gold band along its pointed rim."""
    wrist = _cuff_frame()[0]

    def surface(p):
        s, rho, phi = _cuff_coords(p)
        return rho - (CUFF_R0 + CUFF_FLARE * np.maximum(s - 0.006, 0) ** 1.15 * 1.6)

    return Sheet(
        surface=surface,
        cuts=[lambda p: 0.004 - _cuff_coords(p)[0], lambda p: _cuff_coords(p)[0] - _cuff_top(_cuff_coords(p)[2])],
        lo=wrist - 0.12,
        hi=wrist + 0.12,
        thickness=0.0032,
        bands=[(1, lambda p: (_cuff_top(_cuff_coords(p)[2]) - 0.0075) - _cuff_coords(p)[0])],
        slots=2,
    )


def cuff_sheets() -> dict:
    return {"l": cuff_sheet(), "r": mirrored(cuff_sheet())}
