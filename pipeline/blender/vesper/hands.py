"""Vesper's hands: a palm, four fingers of three phalanges and a thumb, each finger blended into the palm but never into
its neighbour, so every finger is its own shape and can bend on its own bones.

The hand mesh starts a little up the forearm (inside the glove's cuff, where it overlaps the arm) and is meshed finer
than the body so the knuckles and fingertips stay round.
"""

from __future__ import annotations

import numpy as np

from . import anatomy as A
from .sdf import Ellipsoid, Mirror, RoundBox, RoundCone, SUnion, Union, frame, normalize


def finger(name: str, upto: float = 1.0) -> SUnion:
    """One finger's phalanges as round cones, knuckle bumps on the back. `upto` (0..3) truncates it (for the glove)."""
    f = A.FINGERS[name]
    pts = A.finger_joints(name)
    r0, r1 = f["r"]
    radii = np.linspace(r0, r1, 4)
    pieces = []
    for k in range(3):
        if upto <= k:
            break
        a, b = pts[k], pts[k + 1]
        end = b if upto >= k + 1 else a + (b - a) * (upto - k)
        rb = radii[k + 1] if upto >= k + 1 else radii[k] + (radii[k + 1] - radii[k]) * (upto - k)
        pieces.append(RoundCone(a, end, radii[k], rb))
    # The fingertip pad: a touch flatter and rounder than the cone's end.
    if upto >= 3:
        _, along, _, palm = A.hand_frame()
        d = normalize(pts[3] - pts[2])
        pieces.append(
            Ellipsoid(pts[3] - d * r1 * 0.6 + palm * r1 * 0.12, (r1 * 1.02, r1 * 0.88, r1 * 1.25), frame(d, -palm))
        )
    return SUnion(pieces, 0.003)


def thumb(upto: float = 3.0) -> SUnion:
    pts = A.thumb_joints()
    r = A.THUMB["r"]
    pieces = []
    radii = [r[0] * 1.05, r[0], r[1], r[2]]
    for k in range(3):
        if upto <= k:
            break
        a, b = pts[k], pts[k + 1]
        end = b if upto >= k + 1 else a + (b - a) * (upto - k)
        rb = radii[k + 1] if upto >= k + 1 else radii[k] + (radii[k + 1] - radii[k]) * (upto - k)
        pieces.append(RoundCone(a, end, radii[k], rb))
    return SUnion(pieces, 0.004)


def palm_block() -> SUnion:
    wrist, along, thumb_dir, palm = A.hand_frame()
    rot = np.stack([thumb_dir, palm, along], axis=1)  # local x across, y out of the palm, z along the fingers
    body = RoundBox(wrist + along * 0.046 - palm * 0.001, (0.035, 0.011, 0.040), 0.010, rot)
    # The heel of the hand and the pad under the fingers are fuller on the palm side.
    heel = Ellipsoid(wrist + along * 0.022 + palm * 0.004 - thumb_dir * 0.012, (0.017, 0.010, 0.018), rot)
    thenar = Ellipsoid(
        wrist + along * 0.030 + thumb_dir * 0.020 + palm * 0.006,
        (0.014, 0.011, 0.024),
        frame(along + thumb_dir * 0.4, palm),
    )
    wrist_block = RoundBox(wrist - along * 0.010, (0.024, 0.0155, 0.028), 0.012, rot)
    return SUnion([body, heel, thenar, wrist_block], 0.012)


def hand_left(finger_upto: float = 3.0, thumb_upto: float = 3.0) -> SUnion:
    palm = palm_block()
    # Each finger blends with the palm alone; the fingers meet each other with a plain union.
    parts = [SUnion([palm, finger(n, finger_upto)], 0.007) for n in A.FINGERS]
    parts.append(SUnion([palm, thumb(thumb_upto)], 0.012))
    return Union(parts)


def hands() -> dict:
    left = hand_left()
    return {"left": left, "right": Mirror(left)}
