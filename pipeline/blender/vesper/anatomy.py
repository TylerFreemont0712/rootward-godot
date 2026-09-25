"""Vesper's proportions: joint positions and body measurements, in metres, standing in her heeled boots.

The numbers come from the concept sheets (Concept/vesper-star-script-witch/): the canonical front view gives heights
(sole 0, chin 1.34, eyes 1.43, skull top 1.58, knees 0.59, shorts hem 0.79), the head sheet gives the face, and the
side view gives depths. About six heads tall with her hair. Blender axes: x to her left, -y is her front, z up.

Every other module (body, clothes, rig) reads the joints from here, so the skeleton and the surface always agree.
"""

from __future__ import annotations

import math

import numpy as np

from .sdf import normalize, rotation

# Heights of the landmarks the rest of the build hangs off.
CHIN_Z = 1.335
EYE_Z = 1.431
MOUTH_Z = 1.375
SKULL_TOP_Z = 1.580
NECK_BASE_Z = 1.292
SHOULDER_Z = 1.250
BUST_Z = 1.150
WAIST_Z = 1.050
BELT_Z = 0.950
HIP_Z = 0.905
CROTCH_Z = 0.835
KNEE_Z = 0.585
ANKLE_Z = 0.125
SHORTS_HEM_Z = 0.790
BOOT_TOP_Z = 0.330

# The arms hang in a relaxed A-pose, 30 degrees out from the body, as the concept stands.
ARM_OUT_DEG = 30.0
UPPER_ARM = 0.220
FOREARM = 0.195


def _arm() -> dict[str, np.ndarray]:
    shoulder = np.array([0.135, 0.012, SHOULDER_Z])
    a = math.radians(ARM_OUT_DEG)
    d1 = normalize([math.sin(a), -0.06, -math.cos(a)])
    elbow = shoulder + UPPER_ARM * d1
    # A slight bend at the elbow (forward and a touch further out) so an IK solver knows which way it folds.
    a2 = math.radians(ARM_OUT_DEG + 3)
    d2 = normalize([math.sin(a2), -0.16, -math.cos(a2)])
    wrist = elbow + FOREARM * d2
    return {"clavicle": np.array([0.018, 0.004, 1.268]), "shoulder": shoulder, "elbow": elbow, "wrist": wrist}


def _leg() -> dict[str, np.ndarray]:
    return {
        "hip": np.array([0.084, 0.004, HIP_Z]),
        "knee": np.array([0.083, -0.012, KNEE_Z]),
        "ankle": np.array([0.098, 0.022, ANKLE_Z]),
        # In a block-heeled boot the ball of the foot sits well below and ahead of the ankle.
        "ball": np.array([0.100, -0.078, 0.032]),
        "toe": np.array([0.100, -0.128, 0.022]),
    }


ARM = _arm()
LEG = _leg()

SPINE = {
    "hips": np.array([0.0, 0.006, 0.930]),
    "spine": np.array([0.0, 0.010, 1.000]),
    "spine1": np.array([0.0, 0.014, 1.075]),
    "spine2": np.array([0.0, 0.012, 1.150]),
    "neck": np.array([0.0, 0.020, NECK_BASE_Z - 0.01]),
    "head": np.array([0.0, 0.022, 1.372]),
    "head_top": np.array([0.0, 0.016, SKULL_TOP_Z]),
}


def hand_frame(side: float = 1.0) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """The left hand's wrist and axes (mirrored for side -1): along the fingers, toward the thumb, out of the palm.

    The palm faces her thigh, turned 20 degrees toward the front, as a relaxed hand hangs.
    """
    wrist = ARM["wrist"].copy()
    along = normalize(ARM["wrist"] - ARM["elbow"])
    thumb = normalize(np.cross(along, np.cross([0, -1.0, 0], along)))
    palm = np.cross(along, thumb)
    r = rotation(along, 20.0)
    thumb, palm = r @ thumb, r @ palm
    if side < 0:
        flip = np.array([-1.0, 1.0, 1.0])
        return wrist * flip, along * flip, thumb * flip, palm * flip
    return wrist, along, thumb, palm


# Fingers: offset across the palm (toward the thumb +), knuckle distance from the wrist, splay (degrees, toward the
# thumb +), phalanx lengths, radius at the knuckle and at the tip, and the relaxed curl at each joint.
FINGERS = {
    "Index": dict(
        across=0.0255, reach=0.082, splay=9.0, lengths=(0.027, 0.018, 0.016), r=(0.0080, 0.0064), curl=(6, 12, 8)
    ),
    "Middle": dict(
        across=0.0085, reach=0.086, splay=2.0, lengths=(0.030, 0.020, 0.017), r=(0.0082, 0.0066), curl=(8, 14, 9)
    ),
    "Ring": dict(
        across=-0.0085, reach=0.083, splay=-6.0, lengths=(0.028, 0.019, 0.016), r=(0.0077, 0.0062), curl=(10, 16, 10)
    ),
    "Pinky": dict(
        across=-0.0245, reach=0.075, splay=-15.0, lengths=(0.022, 0.015, 0.014), r=(0.0066, 0.0053), curl=(12, 18, 11)
    ),
}


MIRROR = np.array([-1.0, 1.0, 1.0])


def finger_joints(name: str, side: float = 1.0) -> list[np.ndarray]:
    """Knuckle, two middle joints and the tip of one finger, in her rest pose (the right hand mirrors the left)."""
    wrist, along, thumb, palm = hand_frame(1.0)
    f = FINGERS[name]
    base = wrist + along * f["reach"] + thumb * f["across"] - palm * 0.0015
    direction = rotation(palm, f["splay"]) @ along
    lateral = np.cross(palm, direction)
    points = [base]
    for length, curl in zip(f["lengths"], f["curl"]):
        # Curling bends toward the palm: a rotation about the finger's own sideways axis.
        direction = rotation(lateral, -curl) @ direction
        points.append(points[-1] + direction * length)
    return points if side > 0 else [p * MIRROR for p in points]


THUMB = dict(lengths=(0.030, 0.026, 0.022), r=(0.0105, 0.0088, 0.0074))


def thumb_joints(side: float = 1.0) -> list[np.ndarray]:
    """The thumb's root (at the wrist), its knuckle, its middle joint and its tip."""
    wrist, along, thumb, palm = hand_frame(1.0)
    root = wrist + along * 0.016 + thumb * 0.017 + palm * 0.004
    d0 = normalize(along * 0.62 + thumb * 0.62 + palm * 0.45)
    d1 = normalize(along * 0.80 + thumb * 0.36 + palm * 0.48)
    d2 = normalize(along * 0.86 + thumb * 0.18 + palm * 0.48)
    points = [root]
    for length, d in zip(THUMB["lengths"], (d0, d1, d2)):
        points.append(points[-1] + d * length)
    return points if side > 0 else [p * MIRROR for p in points]
