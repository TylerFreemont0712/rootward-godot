"""Vesper's body as signed distance fields: torso, neck, arms and legs (the head and hands are their own meshes).

Each limb joins the torso with a smooth blend, but the two legs never blend with each other and the fingers never
blend with their neighbours, so there is no webbing between them.
"""

from __future__ import annotations

import numpy as np

from . import anatomy as A
from .sdf import Ellipsoid, Loft, Mirror, RoundCone, SUnion, Union, frame, normalize

# (z, half width, front depth, back depth, centre y, exponent): her torso from the crotch to the base of the neck.
TORSO_KEYS = [
    (0.826, 0.022, 0.016, 0.020, 0.010, 2.0),
    (0.842, 0.082, 0.046, 0.058, 0.012, 2.2),
    (0.862, 0.128, 0.062, 0.078, 0.014, 2.4),
    (0.886, 0.147, 0.069, 0.088, 0.016, 2.5),
    (0.912, 0.152, 0.071, 0.090, 0.016, 2.5),
    (0.945, 0.143, 0.070, 0.084, 0.016, 2.4),
    (0.985, 0.124, 0.066, 0.072, 0.014, 2.3),
    (1.022, 0.106, 0.064, 0.063, 0.012, 2.2),
    (1.052, 0.100, 0.064, 0.059, 0.012, 2.2),
    (1.088, 0.106, 0.068, 0.060, 0.012, 2.2),
    (1.122, 0.118, 0.075, 0.063, 0.010, 2.3),
    (1.162, 0.126, 0.079, 0.065, 0.008, 2.3),
    (1.202, 0.131, 0.078, 0.067, 0.008, 2.4),
    (1.236, 0.137, 0.070, 0.067, 0.010, 2.5),
    (1.258, 0.139, 0.059, 0.061, 0.012, 2.6),
    (1.276, 0.110, 0.050, 0.054, 0.014, 2.4),
    (1.291, 0.074, 0.040, 0.044, 0.016, 2.2),
    (1.306, 0.044, 0.032, 0.036, 0.018, 2.0),
]


def torso() -> SUnion:
    trunk = Loft(TORSO_KEYS)
    bust = [
        Ellipsoid((s * 0.047, -0.064, 1.158), (0.049, 0.041, 0.047), frame([s * 0.25, -1, 0], [0, 0, 1]))
        for s in (1, -1)
    ]
    seat = [Ellipsoid((s * 0.057, 0.052, 0.884), (0.071, 0.052, 0.072)) for s in (1, -1)]
    belly = Ellipsoid((0.0, -0.036, 0.99), (0.08, 0.034, 0.07))
    return SUnion([trunk, *bust, *seat, belly], 0.034)


def neck(top: float = 1.335) -> RoundCone:
    return RoundCone((0.0, 0.017, 1.255), (0.0, 0.021, top), 0.034, 0.030)


def arm_left(to_wrist: float = 0.012) -> SUnion:
    """Shoulder to wrist. The forearm stops just past the wrist; the hand mesh overlaps it under the glove."""
    s, e, w = A.ARM["shoulder"], A.ARM["elbow"], A.ARM["wrist"]
    d1 = normalize(e - s)
    d2 = normalize(w - e)
    deltoid = RoundCone(s + np.array([0.004, 0.0, 0.006]), s + d1 * 0.085, 0.043, 0.035)
    upper = RoundCone(s, e, 0.036, 0.028)
    elbow = Ellipsoid(e, (0.029, 0.027, 0.03), frame(d2, [0, -1, 0]))
    forearm_muscle = Ellipsoid(e + d2 * 0.055, (0.030, 0.026, 0.065), frame(d2, [0, -1, 0]))
    forearm = RoundCone(e, w + d2 * to_wrist, 0.028, 0.0205)
    return SUnion([deltoid, upper, elbow, forearm_muscle, forearm], 0.02)


def leg_left() -> SUnion:
    L = A.LEG
    hip, knee, ankle = L["hip"], L["knee"], L["ankle"]
    thigh = RoundCone(hip + np.array([0.002, 0.0, -0.004]), knee, 0.072, 0.043)
    thigh_mass = Ellipsoid((0.088, -0.006, 0.748), (0.066, 0.069, 0.13))
    knee_ball = Ellipsoid(knee + np.array([0.0, -0.002, 0.0]), (0.042, 0.045, 0.05))
    patella = Ellipsoid(knee + np.array([0.0, -0.040, 0.006]), (0.022, 0.012, 0.026))
    shin = RoundCone(knee, ankle, 0.041, 0.027)
    calf = Ellipsoid((0.094, 0.018, 0.465), (0.047, 0.051, 0.11))
    heel = Ellipsoid(ankle + np.array([0.0, 0.012, -0.045]), (0.026, 0.03, 0.03))
    foot = RoundCone(ankle, L["ball"], 0.029, 0.024)
    toes = RoundCone(L["ball"], L["toe"], 0.024, 0.017)
    return SUnion([thigh, thigh_mass, knee_ball, patella, shin, calf, heel, foot, toes], 0.026)


def body() -> dict:
    """Named parts (for labels) and the whole: the arms and legs each blend into the torso, never into each other."""
    core = SUnion([torso(), neck()], 0.02)
    arm_l, leg_l = arm_left(), leg_left()
    arm_r, leg_r = Mirror(arm_l), Mirror(leg_l)
    whole = Union(
        [
            SUnion([core, arm_l], 0.03),
            SUnion([core, arm_r], 0.03),
            SUnion([core, leg_l], 0.045),
            SUnion([core, leg_r], 0.045),
        ]
    )
    lower = Union([SUnion([core, leg_l], 0.045), SUnion([core, leg_r], 0.045)])
    return {
        "whole": whole,
        "lower": lower,
        "core": core,
        "arm_l": arm_l,
        "arm_r": arm_r,
        "leg_l": leg_l,
        "leg_r": leg_r,
    }
