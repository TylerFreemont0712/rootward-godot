"""Crescent-cuff boots: brown leather to mid-calf on a dark block heel, a strap and brass buckle over the ankle, a gold
diamond on the shin, and a navy cuff folded down and flaring open at the front, gold-edged, with a gold crescent
rising from its outer side.
"""

from __future__ import annotations

import numpy as np

from . import anatomy as A
from . import body as B
from . import shapes
from .cloth import Sheet
from .sdf import Ellipsoid, Field, Mirror, RoundCone, SUnion, Union, smax, smin

L = A.LEG
TOP_Z = 0.318
AXIS = np.array([0.097, 0.012])  # the shaft's axis (x, y) in the cuff's region


def _shin() -> SUnion:
    """The lower leg as the boot sees it: the body's shin and calf, below the knee."""
    return B.leg_left()


# The boot's footprint (her left boot): half-width along the foot, from the toe tip (-y) to the back of the heel.
FOOT_X = 0.100
FOOTPRINT = np.array(
    [
        (-0.152, 0.000),
        (-0.146, 0.018),
        (-0.134, 0.030),
        (-0.112, 0.038),
        (-0.088, 0.041),
        (-0.060, 0.039),
        (-0.030, 0.034),
        (0.000, 0.031),
        (0.030, 0.032),
        (0.052, 0.029),
        (0.064, 0.018),
        (0.068, 0.000),
    ]
)
HEEL_Y = 0.014  # the block heel starts here and runs to the back
HEEL_TOP = 0.056  # how high the heel lifts her heel
SOLE_T = 0.011


def _footprint(p: np.ndarray) -> np.ndarray:
    """Signed distance (roughly) to the footprint outline, in plan: negative inside."""
    x, y = p[:, 0] - FOOT_X, p[:, 1]
    w = np.interp(y, FOOTPRINT[:, 0], FOOTPRINT[:, 1])
    d = np.abs(x) - w
    return np.maximum(d, np.maximum(FOOTPRINT[0, 0] - y, y - FOOTPRINT[-1, 0]) * 0.8)


def _sole_top(y: np.ndarray) -> np.ndarray:
    """Height of the sole's upper face: flat under the ball and toes, rising along the arch to the heel's top."""
    t = np.clip((y - -0.045) / (HEEL_Y + 0.004 - -0.045), 0, 1)
    return SOLE_T + (HEEL_TOP - SOLE_T) * (t * t * (3 - 2 * t))


def boot_upper() -> Field:
    leg = _shin()
    foot = SUnion(
        [
            RoundCone(
                L["ankle"] + np.array([0.0, 0.004, -0.01]), L["ball"] + np.array([0.0, 0.0, 0.006]), 0.037, 0.034
            ),
            Ellipsoid(L["ball"] + np.array([0.0, -0.030, 0.000]), (0.038, 0.050, 0.030)),
            Ellipsoid(L["ankle"] + np.array([0.0, 0.020, -0.048]), (0.033, 0.034, 0.042)),
        ],
        0.02,
    )

    def fn(p):
        z = p[:, 2]
        # Leather a little loose round the calf, snug at the ankle.
        shaft = leg.eval(p) - (0.0055 + 0.004 * np.clip((z - 0.16) / 0.15, 0, 1))
        d = smin(shaft, foot.eval(p), 0.03)
        # The welt: the upper's lower wall stands on the whole footprint, so the shoe meets its sole all round.
        top = _sole_top(p[:, 1])
        wall = np.maximum(_footprint(p) + 0.0015, np.maximum(top - 0.002 - z, z - (top + 0.030)))
        d = smin(d, wall, 0.018)
        d = smax(d, top - 0.002 - z, 0.002)
        return smax(d, z - TOP_Z, 0.002)

    return Field(fn, np.array([0.03, -0.17, 0.0]), np.array([0.17, 0.10, TOP_Z + 0.01]))


def sole_and_heel() -> Field:
    def fn(p):
        z = p[:, 2]
        foot = _footprint(p) - 0.0022
        top = _sole_top(p[:, 1])
        plate = np.maximum(foot, np.maximum(z - top, (top - SOLE_T) - z))
        # The block heel: under the heel only, from the floor to the heel's top, tapering a little toward the floor.
        taper = 0.004 * np.clip((HEEL_TOP - z) / HEEL_TOP, 0, 1)
        block = np.maximum(foot + taper, np.maximum(z - HEEL_TOP, -z))
        block = np.maximum(block, (HEEL_Y - p[:, 1]))
        return smax(np.minimum(plate, block), -z, 0.001)

    return Field(fn, np.array([0.03, -0.17, -0.01]), np.array([0.17, 0.08, 0.07]))


def _cuff_coords(p):
    dx, dy = p[:, 0] - AXIS[0], p[:, 1] - AXIS[1]
    rho = np.hypot(dx, dy)
    # Around the leg from the front (0) toward the outside of her left leg (+).
    phi = np.arctan2(dx, -dy)
    return rho, phi


def _cuff_r(z):
    """The cuff is a funnel: snug where it folds over the shaft at the bottom, splayed wide at its rim."""
    return 0.050 + 0.50 * np.maximum(z - 0.245, 0) ** 1.08


def _cuff_bottom(phi):
    """The cuff's lower edge: lowest at the back, rising toward the open front."""
    return 0.245 + 0.030 * np.clip(1.0 - np.abs(phi) / 1.3, 0, 1) ** 1.5


FRONT_GAP = 0.50  # half-angle of the opening at the front, radians


def ornaments() -> Union:
    outer = np.array([1.0, -0.55, 0.0])
    outer /= np.linalg.norm(outer)
    # The crescent stands on the cuff's outer side, horns up and forward.
    c = np.array([AXIS[0], AXIS[1], 0.0]) + outer * (_cuff_r(TOP_Z + 0.03) + 0.002) + np.array([0, 0, TOP_Z + 0.030])
    # Horns up: the crescent's opening (its +x) turned to point up the leg.
    crescent = shapes.Badge(
        lambda q: shapes.crescent(q @ np.array([[0.0, 1.0], [-1.0, 0.0]]).T, 0.037, 0.030, 0.019),
        c,
        outer,
        (0.0, -0.2, 1.0),
        0.0095,
        0.0022,
        0.05,
    )
    # The diamond on the shin, in the cuff's front opening.
    d_c = np.array([AXIS[0], AXIS[1] - 0.054, 0.283])
    diamond = shapes.Badge(
        lambda q: shapes.diamond(q, 0.0135, 0.025), d_c, (0.0, -1.0, 0.25), (0, 0.25, 1.0), 0.0042, 0.0011, 0.035
    )
    return Union([crescent, diamond])


def strap() -> dict:
    """A strap round the ankle with a brass buckle on the outer side."""
    leg = _shin()

    def band(p):
        z = p[:, 2]
        d = np.abs(leg.eval(p) - 0.0105) - 0.0022
        return smax(d, np.abs(z - (0.192 - 0.02 * (p[:, 1] < 0.0) * 0.0)) - 0.0105, 0.001)

    buckle_c = np.array([0.142, 0.004, 0.192])
    outer = np.array([1.0, 0.1, 0.0])
    frame = shapes.Badge(
        lambda q: np.maximum(
            np.maximum(np.abs(q[:, 0]) - 0.0125, np.abs(q[:, 1]) - 0.0125),
            -np.maximum(np.abs(q[:, 0]) - 0.0075, np.abs(q[:, 1]) - 0.0078),
        ),
        buckle_c,
        outer,
        (0.0, 0.0, 1.0),
        0.0035,
        0.0009,
        0.02,
    )
    return {"strap": Field(band, np.array([0.04, -0.06, 0.17]), np.array([0.16, 0.08, 0.215])), "gold": frame}


def boot_parts() -> dict:
    """Left-boot pieces keyed by material; the right boot mirrors them."""
    s = strap()
    return {
        "leather": boot_upper(),
        "sole": sole_and_heel(),
        "gold": Union([ornaments(), s["gold"]]),
        "strap": s["strap"],
    }


def boots() -> dict:
    left = boot_parts()
    out = {}
    for k, v in left.items():
        out[f"{k}_l"] = v
        out[f"{k}_r"] = Mirror(v)
    return out


def cuff_sheet() -> Sheet:
    """The folded cuff as one sheet: navy outside, its lining inside, gold along the lower and front edges."""
    top = TOP_Z + 0.03

    def surface(p):
        rho, phi = _cuff_coords(p)
        return rho - _cuff_r(p[:, 2])

    def gap(p):
        rho, phi = _cuff_coords(p)
        return (FRONT_GAP - np.abs(phi)) * rho

    def bottom_band(p):
        rho, phi = _cuff_coords(p)
        return p[:, 2] - (_cuff_bottom(phi) + 0.009)

    def front_band(p):
        return -gap(p) - 0.009

    return Sheet(
        surface=surface,
        cuts=[lambda p: _cuff_bottom(_cuff_coords(p)[1]) - p[:, 2], lambda p: p[:, 2] - top, gap],
        lo=np.array([-0.04, -0.14, 0.225]),
        hi=np.array([0.24, 0.16, top + 0.02]),
        thickness=0.0038,
        bands=[(1, bottom_band), (1, front_band)],
        slots=2,
    )
