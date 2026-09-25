"""The witch's hat: a wide soft brim tilted down toward her left (navy above, burgundy beneath), a floppy cone that
rises and droops back over her left shoulder, a mauve band edged in gold, a brass crescent on the band's front-left,
and a gold star dangling from the tip.
"""

from __future__ import annotations

import numpy as np

from . import shapes
from .cloth import Sheet
from .sdf import Field, RoundCone, SUnion, Union, normalize, rotation, smax

# The brim's frame: low on her head at the hairline, tilted 12 degrees down toward her left and pushed back 10 degrees
# so the front lifts off her face and the burgundy underside shows, as the concept wears it.
BRIM_ORIGIN = np.array([0.0, 0.018, 1.503])
BRIM_AXES = rotation([0, 1, 0], 12.0) @ rotation([1, 0, 0], -5.0)
BRIM_IN, BRIM_OUT = 0.110, 0.355
BAND = (0.004, 0.048)  # the band's bottom and top above the brim, in the brim's frame

# The cone's spine: horizontal distance along the droop direction, height, radius.
CONE = [
    (0.000, 1.482, 0.119),
    (0.004, 1.560, 0.112),
    (0.014, 1.628, 0.095),
    (0.036, 1.688, 0.075),
    (0.080, 1.734, 0.057),
    (0.143, 1.748, 0.043),
    (0.210, 1.720, 0.033),
    (0.266, 1.662, 0.024),
    (0.304, 1.590, 0.017),
    (0.322, 1.525, 0.011),
    (0.330, 1.478, 0.0065),
]
DROOP = normalize([0.72, 0.69, 0.0])


def _catmull(points: np.ndarray, per: int) -> np.ndarray:
    pts = np.vstack([points[0] * 2 - points[1], points, points[-1] * 2 - points[-2]])
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1 : i + 3]
        for t in np.linspace(0, 1, per, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(
                0.5
                * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            )
    out.append(points[-1])
    return np.array(out)


def cone_spine() -> np.ndarray:
    """Points along the cone's centre with their radius: (x, y, z, r)."""
    c = np.array(CONE)
    key = np.stack([BRIM_ORIGIN[0] + c[:, 0] * DROOP[0], BRIM_ORIGIN[1] + c[:, 0] * DROOP[1], c[:, 1], c[:, 2]], axis=1)
    return _catmull(key, 6)


def cone() -> Field:
    spine = cone_spine()
    segs = [RoundCone(a[:3], b[:3], a[3], b[3]) for a, b in zip(spine[:-1], spine[1:])]
    tube = SUnion(segs, 0.004)
    tip = spine[-1, :3]

    def fn(p):
        d = tube.eval(p)
        # Soft creases in the felt: shallow waves round and along the cone, fading toward the tip.
        q = p - BRIM_ORIGIN
        a = np.arctan2(q[:, 1], q[:, 0])
        h = np.clip((p[:, 2] - 1.56) / 0.2, 0, 1)
        crease = (
            0.0032 * np.sin(5 * a + 18 * p[:, 2]) * h * (1 - 0.5 * h) + 0.0024 * np.sin(3 * a - 11 * p[:, 2] + 1.3) * h
        )
        # The crown's opening is cut flat just under the brim, so nothing of it hangs over her face.
        below = -(((p - BRIM_ORIGIN) @ BRIM_AXES)[:, 2] + 0.006)
        return smax(d + crease, below, 0.002)

    lo = np.minimum(spine[:, :3] - spine[:, 3:], tip - 0.02).min(axis=0)
    hi = np.maximum(spine[:, :3] + spine[:, 3:], tip + 0.02).max(axis=0)
    return Field(fn, lo, hi)


def band() -> dict:
    c = cone()

    def local_z(p):
        return ((p - BRIM_ORIGIN) @ BRIM_AXES)[:, 2]

    def strip(p):
        d = np.abs(c.eval(p) - 0.0045) - 0.0035
        z = local_z(p)
        return smax(d, np.abs(z - 0.5 * (BAND[0] + BAND[1])) - 0.5 * (BAND[1] - BAND[0]), 0.0015)

    def stripes(p):
        d = np.abs(c.eval(p) - 0.0075) - 0.0022
        z = local_z(p)
        e = np.minimum(np.abs(z - BAND[0] - 0.003), np.abs(z - BAND[1] + 0.003)) - 0.0028
        return smax(d, e, 0.001)

    lo, hi = BRIM_ORIGIN - 0.14, BRIM_ORIGIN + 0.14
    return {"band": Field(strip, lo, hi), "gold": Field(stripes, lo, hi)}


def ornaments() -> Union:
    # The crescent on the band, front-left, opening toward her left; bigger than the band is tall.
    a = np.radians(34.0)
    out_dir = BRIM_AXES @ np.array([np.sin(a), -np.cos(a), 0.0])
    centre = BRIM_ORIGIN + BRIM_AXES @ np.array([0, 0, 0.5 * (BAND[0] + BAND[1]) + 0.006]) + out_dir * 0.128
    up = BRIM_AXES @ np.array([0.0, 0.0, 1.0])
    right = np.cross(out_dir, up)
    moon = shapes.Badge(lambda q: shapes.crescent(q, 0.046, 0.038, 0.023), centre, out_dir, up, 0.009, 0.0022, 0.06)
    # The star pendant hangs from the tip on a little ring.
    tip = cone_spine()[-1, :3]
    star_c = tip + np.array([0.004, 0.0, -0.043])
    face = normalize([-0.25, -1.0, 0.0])
    star = shapes.Badge(
        lambda q: shapes.star4(q, 0.016, 0.024, 0.024, 0.0045), star_c, face, (0, 0, 1), 0.007, 0.0016, 0.035
    )
    loop = shapes.Badge(
        lambda q: shapes.ring(q, 0.0055, 0.0013),
        tip + np.array([0.002, 0.0, -0.012]),
        right,
        (0, 0, 1),
        0.0026,
        0.0008,
        0.012,
    )
    return Union([moon, star, loop])


def hat() -> dict:
    return {"felt": Union([cone()]), **band(), "ornaments": ornaments()}


def _brim_height(q: np.ndarray) -> np.ndarray:
    r = np.hypot(q[:, 0], q[:, 1])
    phi = np.arctan2(q[:, 1], q[:, 0])
    t = np.clip((r - BRIM_IN) / (BRIM_OUT - BRIM_IN), 0, 1.2)
    return -0.016 * t**1.6 + 0.011 * np.sin(3 * phi + 0.8) * t**2


def brim_sheet() -> Sheet:
    """The brim's upper face as a sheet, thickened downward: navy on top, the burgundy underside is its inside."""

    def local(p):
        return (p - BRIM_ORIGIN) @ BRIM_AXES

    def surface(p):
        q = local(p)
        return q[:, 2] - _brim_height(q)

    def radius(p):
        q = local(p)
        return np.hypot(q[:, 0], q[:, 1])

    return Sheet(
        surface=surface,
        cuts=[
            lambda p: radius(p) - BRIM_OUT,
            lambda p: BRIM_IN - radius(p),
            lambda p: (_brim_height(local(p)) - 0.03) - local(p)[:, 2],
        ],
        lo=BRIM_ORIGIN - np.array([0.37, 0.37, 0.12]),
        hi=BRIM_ORIGIN + np.array([0.37, 0.37, 0.12]),
        thickness=0.0048,
    )
