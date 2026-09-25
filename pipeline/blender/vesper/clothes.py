"""The clothes that follow her body: the high black collar, the teal tunic with its gold star-rune and piping, the navy
shorts, and the belt. Each is a thin shell a few millimetres off the body's own distance field, so it fits exactly
and moves with the same bones.
"""

from __future__ import annotations

import numpy as np

from . import body as B
from . import shapes
from .cloth import Sheet
from .sdf import Field, Loft, Offset, RoundBox, RoundCone, SUnion, Union, smax, smoothstep

TUNIC_OFF = 0.0055


def _angle(p: np.ndarray, cy: float = 0.012) -> np.ndarray:
    """Around her body from the front (0) through her left (+pi/2)."""
    return np.arctan2(p[:, 0], -(p[:, 1] - cy))


# The tunic's skirt: below the waist it hangs a little free of the hips instead of hugging them.
SKIRT_KEYS = [
    (0.860, 0.180, 0.094, 0.110, 0.016, 2.4),
    (0.900, 0.174, 0.090, 0.107, 0.016, 2.4),
    (0.950, 0.154, 0.082, 0.096, 0.016, 2.3),
    (1.000, 0.118, 0.073, 0.074, 0.013, 2.2),
    (1.030, 0.104, 0.070, 0.064, 0.012, 2.2),
]


def tunic_surface() -> SUnion:
    """The tunic's outer face as a solid (the shell and the trims are cut from it). Below the waist it also clears the
    tops of her thighs and the shorts over them, so the skirt always hangs outside the shorts."""
    whole = B.body()["lower"]  # torso and legs: the arms hang beside the skirt, not in it

    def hips(p):
        z = p[:, 2]
        d = whole.eval(p) - 0.0135
        return np.maximum(d, np.maximum(0.86 - z, z - 1.0) * 1.0)

    return SUnion(
        [
            Offset(B.torso(), TUNIC_OFF),
            Loft(SKIRT_KEYS),
            Field(hips, np.array([-0.2, -0.13, 0.85]), np.array([0.2, 0.14, 1.01])),
        ],
        0.03,
    )


def tunic_hem(p: np.ndarray) -> np.ndarray:
    """Height of the tunic's hem around her: level at 0.885, with a slit rising to 0.93 at each side."""
    a = np.abs(_angle(p))
    slit = np.clip(1.0 - np.abs(a - np.pi / 2) / 0.22, 0.0, 1.0)
    return 0.885 + 0.045 * slit**1.3


def tunic() -> dict:
    """The tunic's gold star-rune and its dark seams (the cloth itself is `tunic_sheet`)."""
    surf = tunic_surface()

    front = np.array([0.0, -1.0, 0.0])
    up = np.array([0.0, 0.0, 1.0])
    # The star-rune on her chest: long lower ray running down toward the belt.
    star = shapes.applique(
        surf,
        lambda q: shapes.star4(q, 0.047, 0.050, 0.108, 0.0135),
        (0.0, -0.08, 1.125),
        front,
        up,
        0.0019,
        0.0026,
        0.13,
    )
    dot = shapes.applique(
        surf, lambda q: shapes.diamond(q, 0.0055, 0.009), (0.0, -0.08, 0.998), front, up, 0.0019, 0.0026, 0.02
    )

    def seams(p):
        # Two dark seams curving down the front from under the bust to the hem.
        x, z = p[:, 0], p[:, 2]
        seam_x = 0.058 + 0.012 * smoothstep(1.06, 0.90, z) - 0.010 * smoothstep(1.10, 1.17, z)
        d2 = np.abs(np.abs(x) - seam_x) - 0.0014
        d2 = np.maximum(d2, np.maximum(z - 1.14, tunic_hem(p) - z))
        d2 = np.maximum(d2, p[:, 1] - 0.0)
        return smax(np.abs(surf.eval(p) - 0.0012) - 0.0008, d2, 0.0004)

    return {
        "gold": Union([star, dot]),
        "seams": Field(seams, np.array([-0.12, -0.12, 0.86]), np.array([0.12, 0.0, 1.16])),
    }


def shorts_tabs() -> Union:
    """Little brass tabs at the outer side of each leg's hem."""
    return Union([RoundBox((s * 0.158, 0.0, 0.806), (0.004, 0.008, 0.016), 0.002) for s in (1.0, -1.0)])


BELT_Z = 0.948


def belt() -> dict:
    """A brown belt over the tunic, sitting a touch lower on her left (where the book hangs), with a brass buckle."""
    surf = tunic_surface()

    def centre_z(p):
        return BELT_Z - 0.008 * np.sin(_angle(p))

    def strap(p):
        d = np.abs(surf.eval(p) - 0.0036) - 0.0026
        return smax(d, np.abs(p[:, 2] - centre_z(p)) - 0.0165, 0.001)

    lo = np.array([-0.2, -0.13, 0.9])
    hi = np.array([0.2, 0.13, 1.0])
    front_y = -0.0885
    buckle_c = np.array([-0.012, front_y - 0.005, BELT_Z + 0.001])
    frame = shapes.Badge(
        lambda q: np.maximum(
            np.maximum(np.abs(q[:, 0]) - 0.022, np.abs(q[:, 1]) - 0.019),
            -np.maximum(np.abs(q[:, 0]) - 0.0145, np.abs(q[:, 1]) - 0.0115),
        ),
        buckle_c,
        (0.0, -1.0, 0.0),
        (0.0, 0.0, 1.0),
        0.005,
        0.0012,
        0.03,
    )
    prong = RoundCone(
        buckle_c + np.array([-0.012, -0.001, 0.0]), buckle_c + np.array([0.012, -0.001, 0.0]), 0.0018, 0.0018
    )
    return {"strap": Field(strap, lo, hi), "gold": Union([frame, prong])}


def tunic_sheet() -> Sheet:
    surf = tunic_surface()
    lo, hi = surf.bounds()
    return Sheet(
        surface=surf.eval,
        cuts=[lambda p: tunic_hem(p) - p[:, 2], lambda p: p[:, 2] - 1.285],
        lo=lo,
        hi=np.minimum(hi, [9, 9, 1.29]),
        thickness=0.003,
        bands=[(1, lambda p: p[:, 2] - (tunic_hem(p) + 0.010))],
        slots=2,
    )


def shorts_sheet() -> Sheet:
    hips = B.body()["lower"]

    def surface(p):
        return hips.eval(p) - (0.0040 + 0.0055 * smoothstep(0.86, 0.79, p[:, 2]))

    return Sheet(
        surface=surface,
        cuts=[lambda p: 0.790 - p[:, 2], lambda p: p[:, 2] - 0.96],
        lo=np.array([-0.2, -0.12, 0.78]),
        hi=np.array([0.2, 0.13, 0.97]),
        thickness=0.003,
        bands=[(1, lambda p: p[:, 2] - 0.8015)],
        slots=2,
    )


def collar_sheet() -> Sheet:
    neck = RoundCone((0.0, 0.017, 1.24), (0.0, 0.021, 1.36), 0.0413, 0.0373)

    def top(p):
        a = _angle(p, 0.02)
        return 1.330 - 0.03 * np.clip(1.0 - np.abs(a) / 0.28, 0, 1) - 0.004 * np.cos(a)

    return Sheet(
        surface=neck.eval,
        cuts=[lambda p: p[:, 2] - top(p), lambda p: 1.262 - p[:, 2]],
        lo=np.array([-0.05, -0.04, 1.25]),
        hi=np.array([0.05, 0.07, 1.34]),
        thickness=0.0035,
    )
