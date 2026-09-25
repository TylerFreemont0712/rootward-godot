"""The plum mantle: a short hooded capelet that rests on her shoulders, flares over her upper arms and ends above the
elbows, open down the front from a gold star clasp, with ribbon tails, gold-trimmed edges, gold diamonds over the arms
and small stars near the hem.

The drape is the outer envelope of two shapes: her shoulders, bust and upper arms pushed out by a finger's width, and
a folded bell hanging from the neck. Where the body stands proud the cloth rests on it; elsewhere it hangs in the bell.
"""

from __future__ import annotations

import numpy as np

from . import body as B
from . import clothes as C
from . import shapes
from .cloth import Sheet
from .sdf import Field, Loft, Mirror, Offset, RoundCone, SUnion, Union, gradient, smax, smin, surface_point

BELL_KEYS = [
    (1.020, 0.305, 0.130, 0.134, 0.016, 2.4),
    (1.060, 0.300, 0.127, 0.131, 0.016, 2.4),
    (1.100, 0.288, 0.123, 0.127, 0.016, 2.4),
    (1.150, 0.265, 0.116, 0.121, 0.016, 2.35),
    (1.200, 0.233, 0.108, 0.113, 0.016, 2.3),
    (1.240, 0.196, 0.098, 0.103, 0.016, 2.25),
    (1.265, 0.158, 0.088, 0.094, 0.016, 2.2),
    (1.285, 0.112, 0.074, 0.084, 0.016, 2.1),
    (1.300, 0.070, 0.060, 0.070, 0.016, 2.0),
    (1.306, 0.040, 0.040, 0.050, 0.016, 2.0),
]
T = 0.0022
CLASP = np.array([0.0, -0.091, 1.228])


def _angle(p):
    return np.arctan2(p[:, 0], -(p[:, 1] - 0.016))


def _hem(p):
    a = _angle(p)
    # Lowest over the arms, the back a little higher; a wave where the folds hang.
    return 1.083 + 0.010 * np.abs(np.cos(a)) - 0.004 * np.sin(10 * a + 2.07)


def _opening_w(z):
    return 0.004 + 0.076 * np.clip((1.232 - z) / 0.15, 0, 1) ** 0.8


def drape_surface() -> Field:
    """The drape's outer face as a solid: body envelope and folded bell."""
    torso = Offset(B.torso(), 0.014)
    arms = [Offset(B.arm_left(), 0.012), Mirror(Offset(B.arm_left(), 0.012))]
    bell = Loft(BELL_KEYS)

    def fn(p):
        z = p[:, 2]
        a = _angle(p)
        fold = 0.0075 * np.clip((1.255 - z) / 0.15, 0, 1) * np.sin(10 * a + 0.5)
        d = bell.eval(p) - fold
        body = np.minimum(torso.eval(p), np.minimum(arms[0].eval(p), arms[1].eval(p)))
        return smin(d, body, 0.02)

    return Field(fn, np.array([-0.34, -0.16, 1.0]), np.array([0.34, 0.17, 1.32]))


# The hood's cowl: a thick roll of cloth from the clasp, round the sides of her neck, to the nape (her left side; the
# right mirrors it). Points (x, y, z) with the roll's radius.
COWL = [
    (0.016, -0.094, 1.232, 0.011),
    (0.042, -0.086, 1.256, 0.016),
    (0.066, -0.062, 1.281, 0.021),
    (0.082, -0.022, 1.298, 0.024),
    (0.078, 0.028, 1.308, 0.026),
    (0.052, 0.068, 1.315, 0.027),
    (0.000, 0.086, 1.320, 0.027),
]


def _cowl_chain(offset=None, radius_scale=1.0, radius_add=0.0) -> SUnion:
    from .hat import _catmull

    pts = _catmull(np.array(COWL), 5)
    segs = []
    for side in (1.0, -1.0):
        q = pts * np.array([side, 1, 1, 1])
        if offset is not None:
            q = q + offset(q)
        segs += [
            RoundCone(a[:3], b[:3], a[3] * radius_scale + radius_add, b[3] * radius_scale + radius_add)
            for a, b in zip(q[:-1], q[1:])
        ]
    return SUnion(segs, 0.004)


def cowl() -> SUnion:
    """The hood's thick roll round her neck, from the clasp to the nape."""
    return _cowl_chain()


def cowl_trim() -> SUnion:
    """The gold edge along the cowl's inner, upper side: toward the neck and up."""

    def toward_neck(q):
        inward = -np.stack([q[:, 0], q[:, 1] - 0.018, np.zeros(len(q))], axis=1)
        inward /= np.linalg.norm(inward, axis=1, keepdims=True)
        off = inward * q[:, 3:4] * 0.62 + np.array([0, 0, 1.0]) * q[:, 3:4] * 0.55
        return np.concatenate([off, np.zeros((len(q), 1))], axis=1)

    return _cowl_chain(toward_neck, 0.0, 0.0052)


def clasp() -> Union:
    front = np.array([0.0, -1.0, 0.0])
    up = np.array([0.0, 0.0, 1.0])
    ring = shapes.Badge(lambda q: shapes.ring(q, 0.0165, 0.0034), CLASP, front, up, 0.0055, 0.0015, 0.03)
    star = shapes.Badge(
        lambda q: shapes.star4(q, 0.0125, 0.0125, 0.0125, 0.0030),
        CLASP + front * 0.001,
        front,
        up,
        0.0065,
        0.0012,
        0.02,
    )
    bars = [
        RoundCone(
            CLASP + np.array([s * 0.017, 0.004, 0.0]), CLASP + np.array([s * 0.034, 0.012, 0.004]), 0.0032, 0.0028
        )
        for s in (1, -1)
    ]
    return Union([ring, star, *bars])


def ribbon() -> dict:
    """Two ribbon tails from behind the clasp, down over her chest, cut in a swallowtail; gold-edged."""
    surf = C.tunic_surface()

    def shape(width):
        def fn(q2):
            x, z = q2[:, 0], q2[:, 1]
            t = np.clip((1.222 - z) / 0.1, 0, 1)
            cx = 0.007 + 0.024 * t
            d = np.abs(np.abs(x) - cx) - width
            end = 1.128 + 0.012 * np.abs((np.abs(x) - cx) / 0.009)
            d = np.maximum(d, end - z)
            return np.maximum(d, z - 1.225)

        return fn

    def planar(width, lift, thick):
        def fn(p):
            q2 = np.stack([p[:, 0], p[:, 2]], axis=1)
            d_surf = np.abs(surf.eval(p) - lift) - thick
            return smax(d_surf, shape(width)(q2), 0.0005)

        return fn

    lo, hi = np.array([-0.06, -0.14, 1.11]), np.array([0.06, -0.04, 1.235])
    return {
        "cloth": Field(planar(0.0068, 0.0052, 0.0014), lo, hi),
        "trim": Field(planar(0.0088, 0.0038, 0.0011), lo, hi),
    }


def emblems() -> dict:
    """Gold diamonds (dark-centred) over each upper arm, small gold stars near the front hem."""
    surf = drape_surface()
    golds, darks = [], []
    for side in (1.0, -1.0):
        for kind, angle, z in (("diamond", 1.22, 1.172), ("star", 0.92, 1.108)):
            a = side * angle
            direction = np.array([np.sin(a), -np.cos(a), 0.0])
            c = surface_point(surf, np.array([0.0, 0.016, z]), direction)
            n = gradient(surf, c)
            up = np.array([0.0, 0.0, 1.0])
            if kind == "diamond":
                ring = lambda q: np.maximum(shapes.diamond(q, 0.017, 0.030), -shapes.diamond(q, 0.0105, 0.0205))
                golds.append(shapes.applique(surf, ring, c, n, up, 0.0013, 0.0020, 0.05))
                darks.append(
                    shapes.applique(surf, lambda q: shapes.diamond(q, 0.011, 0.021), c, n, up, 0.0010, 0.0014, 0.05)
                )
            else:
                star = lambda q: shapes.star4(q, 0.0095, 0.0115, 0.0115, 0.0024)
                golds.append(shapes.applique(surf, star, c, n, up, 0.0013, 0.0020, 0.03))
    return {"gold": Union(golds), "dark": Union(darks)}


def drape_sheet() -> Sheet:
    surf = drape_surface()

    def window(p):
        return np.maximum(np.abs(p[:, 0]) - _opening_w(p[:, 2]), p[:, 1] + 0.0)

    def hem_band(p):
        return p[:, 2] - (_hem(p) + 0.010)

    def edge_band(p):
        z = p[:, 2]
        return np.maximum(np.abs(p[:, 0]) - _opening_w(z) - 0.010, np.maximum(p[:, 1] - 0.03, z - 1.25))

    lo, hi = surf.bounds()
    return Sheet(
        surface=surf.eval,
        cuts=[lambda p: _hem(p) - p[:, 2], lambda p: p[:, 2] - 1.303, lambda p: -window(p)],
        lo=lo,
        hi=hi,
        thickness=0.0042,
        bands=[(1, hem_band), (1, edge_band)],
        slots=2,
    )


def hood_sheet() -> Sheet:
    surf = drape_surface()

    def outer(p):
        x, z = p[:, 0], p[:, 2]
        bulge = 0.018 * np.exp(-(((z - 1.27) / 0.045) ** 2)) * np.exp(-((x / 0.09) ** 2))
        return surf.eval(p) - 0.0065 - bulge

    return Sheet(
        surface=outer,
        cuts=[lambda p: 1.185 + 0.95 * np.abs(p[:, 0]) - p[:, 2], lambda p: 0.02 - p[:, 1], lambda p: p[:, 2] - 1.315],
        lo=np.array([-0.2, -0.02, 1.17]),
        hi=np.array([0.2, 0.17, 1.33]),
        thickness=0.004,
    )
