"""OpenPose skeleton sheets for pose-guided renders.

A text prompt cannot make a model draw the same character with its legs in four different places: asked for "a walk
cycle", it draws the same pose four times. An OpenPose ControlNet takes a picture of stick figures instead and puts a
body on each one, so the poses come from here and the look still comes from the prompt. All figures share one render,
which keeps them one design.

The drawing follows the OpenPose convention the ControlNets were trained on: 18 COCO keypoints, limbs as colored bars at
60% brightness, joints as full-color dots, on black. "Right" and "left" are the figure's own sides, so facing the
viewer its right hand is on the image's left.

Preview a sheet:  $PY pipeline/art/poses.py walk 1280 1024 /tmp/walk-pose.png
"""

from __future__ import annotations

import math
import sys

from PIL import Image, ImageDraw

(NOSE, NECK, R_SHOULDER, R_ELBOW, R_WRIST, L_SHOULDER, L_ELBOW, L_WRIST, R_HIP, R_KNEE, R_ANKLE,
 L_HIP, L_KNEE, L_ANKLE, R_EYE, L_EYE, R_EAR, L_EAR) = range(18)

LIMBS = [
    (NECK, R_SHOULDER), (NECK, L_SHOULDER), (R_SHOULDER, R_ELBOW), (R_ELBOW, R_WRIST), (L_SHOULDER, L_ELBOW),
    (L_ELBOW, L_WRIST), (NECK, R_HIP), (R_HIP, R_KNEE), (R_KNEE, R_ANKLE), (NECK, L_HIP), (L_HIP, L_KNEE),
    (L_KNEE, L_ANKLE), (NECK, NOSE), (NOSE, R_EYE), (R_EYE, R_EAR), (NOSE, L_EYE), (L_EYE, L_EAR),
]
COLORS = [
    (255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0), (0, 255, 85),
    (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255),
    (255, 0, 255), (255, 0, 170), (255, 0, 85),
]

Pose = dict[int, tuple[float, float]]

# Chibi proportions in figure units: the head fills the top third, x is centered on the body, y runs from the top of
# the head (0) to the soles (1).
HEAD = {NOSE: (0.0, 0.2), R_EYE: (-0.05, 0.17), L_EYE: (0.05, 0.17), R_EAR: (-0.11, 0.18), L_EAR: (0.11, 0.18)}
TORSO = {NECK: (0.0, 0.36), R_SHOULDER: (-0.11, 0.38), L_SHOULDER: (0.11, 0.38), R_HIP: (-0.07, 0.66), L_HIP: (0.07, 0.66)}


def facing_viewer(legs: dict[str, tuple[float, float, float]], arms: dict[str, tuple[float, float]], rise: float) -> Pose:
    """A front view. `legs` gives each side's (knee lift, ankle lift, ankle drop); `arms` each wrist's (dx, dy)."""
    pose: Pose = {**HEAD, **TORSO}
    for side, knee, ankle, hip in (("r", R_KNEE, R_ANKLE, R_HIP), ("l", L_KNEE, L_ANKLE, L_HIP)):
        knee_lift, ankle_lift, drop = legs[side]
        x = pose[hip][0] * 1.08
        pose[knee] = (x, 0.82 - knee_lift)
        pose[ankle] = (x * 1.05, 0.97 - ankle_lift + drop)
    for side, shoulder, elbow, wrist in (("r", R_SHOULDER, R_ELBOW, R_WRIST), ("l", L_SHOULDER, L_ELBOW, L_WRIST)):
        dx, dy = arms[side]
        sx = pose[shoulder][0]
        pose[elbow] = (sx * 1.35 + dx * 0.5, 0.52 + dy * 0.5)
        pose[wrist] = (sx * 1.45 + dx, 0.64 + dy)
    return {k: (x, y - rise if k not in (R_ANKLE, L_ANKLE) else y) for k, (x, y) in pose.items()}


def from_behind(pose: Pose) -> Pose:
    """The same body seen from the back: its right side is now on the image's right, and the face is hidden."""
    swapped: Pose = {}
    pairs = {R_SHOULDER: L_SHOULDER, R_ELBOW: L_ELBOW, R_WRIST: L_WRIST, R_HIP: L_HIP, R_KNEE: L_KNEE, R_ANKLE: L_ANKLE, R_EAR: L_EAR}
    pairs.update({v: k for k, v in pairs.items()})
    for key, (x, y) in pose.items():
        if key in (NOSE, R_EYE, L_EYE):
            continue
        swapped[pairs.get(key, key)] = (x, y)
    return swapped


def side_on(near: tuple[float, float, float, float], far: tuple[float, float, float, float], swing: float, rise: float) -> Pose:
    """Facing the image's right, left side toward the viewer. A leg is (knee dx, knee dy, ankle dx, ankle dy)."""
    pose: Pose = {
        NOSE: (0.09, 0.22), L_EYE: (0.06, 0.18), L_EAR: (-0.04, 0.19),
        NECK: (0.0, 0.36), L_SHOULDER: (0.015, 0.38), R_SHOULDER: (-0.015, 0.38),
        L_HIP: (0.015, 0.66), R_HIP: (-0.015, 0.66),
        L_ELBOW: (-swing * 0.5, 0.52), L_WRIST: (-swing, 0.63), R_ELBOW: (swing * 0.5, 0.52), R_WRIST: (swing, 0.63),
    }
    pose = {k: (x, y - rise) for k, (x, y) in pose.items()}
    for (knee_dx, knee_y, ankle_dx, ankle_y), knee, ankle in ((near, L_KNEE, L_ANKLE), (far, R_KNEE, R_ANKLE)):
        pose[knee] = (knee_dx, knee_y)
        pose[ankle] = (ankle_dx, ankle_y)
    return pose


def walk_poses() -> dict[str, list[Pose]]:
    """Per direction: a standing pose, then a four-frame walk (contact, passing, other contact, other passing)."""
    still = {"r": (0.0, 0.0, 0.0), "l": (0.0, 0.0, 0.0)}
    rest_arms = {"r": (0.0, 0.0), "l": (0.0, 0.0)}
    # From the front, a stride shows as depth: the forward foot lands lower on the screen, the trailing one sits higher,
    # and a passing leg lifts its knee.
    # The first render with gentle numbers came back with legs that barely moved, so these are exaggerated on purpose:
    # at 32px only a clearly raised foot reads as a step.
    front = [
        facing_viewer(still, rest_arms, 0.0),
        facing_viewer({"r": (0.0, 0.0, 0.03), "l": (0.14, 0.2, 0.0)}, {"r": (0.06, -0.08), "l": (-0.04, 0.04)}, 0.0),
        facing_viewer({"r": (0.0, 0.0, 0.0), "l": (0.2, 0.3, 0.0)}, rest_arms, 0.03),
        facing_viewer({"r": (0.14, 0.2, 0.0), "l": (0.0, 0.0, 0.03)}, {"r": (0.04, 0.04), "l": (-0.06, -0.08)}, 0.0),
        facing_viewer({"r": (0.2, 0.3, 0.0), "l": (0.0, 0.0, 0.0)}, rest_arms, 0.03),
    ]
    back = [from_behind(pose) for pose in front]
    # From the side the legs scissor: contact spreads them wide, passing tucks the free leg under the body.
    plant = (0.01, 0.815, 0.0, 0.97)
    side = [
        side_on((0.01, 0.82, 0.01, 0.97), (-0.01, 0.82, -0.01, 0.97), 0.0, 0.0),
        side_on((0.08, 0.81, 0.16, 0.97), (-0.06, 0.815, -0.15, 0.955), 0.1, 0.0),
        side_on(plant, (0.07, 0.775, -0.02, 0.885), 0.03, 0.02),
        side_on((-0.06, 0.815, -0.15, 0.955), (0.08, 0.81, 0.16, 0.97), -0.1, 0.0),
        side_on((0.07, 0.775, -0.02, 0.885), plant, -0.03, 0.02),
    ]
    return {"down": front, "right": side, "up": back}


# Battle poses (Shardrun's arena) are a three-quarter view facing right, with a smaller head than the chibi walk: a
# cast has to read as an arm thrown at the foe, and a strict profile leaves the model almost no body to draw. Turning
# to face the image's right brings the figure's own RIGHT side toward the viewer, so its right shoulder, hip and ear sit
# on the image's left of the body ("near") and its left arm is the one on the foe's side ("far").
BATTLE_BODY = {"eye": 0.15, "nose": 0.18, "ear": 0.16, "neck": 0.3, "shoulder": 0.33, "hip": 0.6}

Limb = tuple[float, float, float, float]


def battle_pose(*, near_arm: Limb, far_arm: Limb, near_leg: Limb, far_leg: Limb, lean: float = 0.0, duck: float = 0.0, tilt: float = 0.0) -> Pose:
    """`lean` moves the upper body toward the foe (+) or away (-), `duck` lowers the body, `tilt` lifts the chin (-) or
    drops it (+). An arm is (elbow dx, elbow y, wrist dx, wrist y) measured from the neck's column; a leg is (knee dx,
    knee y, ankle dx, ankle y) measured from the hips' column."""
    b = BATTLE_BODY
    head = lean * 1.3
    pose: Pose = {
        NOSE: (head + 0.075, b["nose"] + duck + tilt),
        R_EYE: (head + 0.035, b["eye"] + duck + tilt * 0.8),
        L_EYE: (head + 0.085, b["eye"] + duck + tilt * 0.8),
        R_EAR: (head - 0.05, b["ear"] + duck),
        NECK: (lean, b["neck"] + duck),
        R_SHOULDER: (lean - 0.075, b["shoulder"] + duck),
        L_SHOULDER: (lean + 0.06, b["shoulder"] + duck),
        R_HIP: (-0.05, b["hip"] + duck),
        L_HIP: (0.04, b["hip"] + duck),
    }
    for (elbow_dx, elbow_y, wrist_dx, wrist_y), elbow, wrist in ((near_arm, R_ELBOW, R_WRIST), (far_arm, L_ELBOW, L_WRIST)):
        pose[elbow] = (lean + elbow_dx, elbow_y + duck)
        pose[wrist] = (lean + wrist_dx, wrist_y + duck)
    for (knee_dx, knee_y, ankle_dx, ankle_y), knee, ankle in ((near_leg, R_KNEE, R_ANKLE), (far_leg, L_KNEE, L_ANKLE)):
        pose[knee] = (knee_dx, knee_y + duck * 0.5)
        pose[ankle] = (ankle_dx, ankle_y)
    return pose


def battle_poses() -> list[list[Pose]]:
    """Eight frames in two rows: idle, wind-up, cast, recover; ward, hurt, channel, victory. The order is the contract
    with the client (`BATTLE_POSES` in apps/client/src/assets/AssetRegistry.ts)."""
    stance: dict[str, Limb] = {"near_leg": (-0.08, 0.785, -0.13, 0.97), "far_leg": (0.1, 0.78, 0.14, 0.97)}
    lunge: dict[str, Limb] = {"near_leg": (-0.11, 0.8, -0.23, 0.97), "far_leg": (0.18, 0.76, 0.23, 0.97)}
    idle = battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **stance)
    # Hands drawn together at the chest: gathering the spell, with nothing crossing behind the head.
    windup = battle_pose(lean=-0.04, duck=0.03, near_arm=(-0.08, 0.43, 0.0, 0.41), far_arm=(0.11, 0.43, 0.03, 0.39), **stance)
    cast = battle_pose(lean=0.07, near_arm=(-0.14, 0.4, -0.22, 0.46), far_arm=(0.25, 0.31, 0.42, 0.3), **lunge)
    recover = battle_pose(lean=0.04, near_arm=(-0.11, 0.42, -0.14, 0.52), far_arm=(0.2, 0.36, 0.33, 0.42), **lunge)
    # The second row keeps both hands below the head. Asked for an arm raised past the face, the model drew a hand resting
    # on the head and turned the figure to face the viewer, so a ward is a braced push forward, a hurt is a recoil,
    # channeling gathers at the sides, and victory is a fist at the chest.
    brace: dict[str, Limb] = {"near_leg": (-0.12, 0.8, -0.2, 0.97), "far_leg": (0.1, 0.785, 0.17, 0.97)}
    ward = battle_pose(lean=-0.03, duck=0.03, near_arm=(0.12, 0.4, 0.27, 0.38), far_arm=(0.2, 0.36, 0.35, 0.33), **brace)
    hurt = battle_pose(
        lean=-0.13, duck=0.04, tilt=-0.05,
        near_arm=(-0.17, 0.37, -0.31, 0.31), far_arm=(0.08, 0.43, 0.19, 0.49),
        near_leg=(-0.12, 0.8, -0.18, 0.97), far_leg=(0.12, 0.78, 0.2, 0.93),
    )
    channel = battle_pose(duck=0.02, near_arm=(-0.16, 0.44, -0.29, 0.47), far_arm=(0.17, 0.44, 0.31, 0.47), **brace)
    victory = battle_pose(
        tilt=-0.03,
        near_arm=(-0.14, 0.45, -0.1, 0.57), far_arm=(0.15, 0.45, 0.13, 0.31),
        near_leg=(-0.06, 0.78, -0.09, 0.97), far_leg=(0.06, 0.78, 0.09, 0.97),
    )
    return [[idle, windup, cast, recover], [ward, hurt, channel, victory]]


def battle_cast_poses(style: str) -> list[list[Pose]]:
    """Twelve registered cast phases for skins that need a real anticipation-to-recovery flow.

    These are deliberately separate from ``battle_poses``: the semantic strip is still the source of truth for hit,
    hurt, ward, and victory states, while this strip can spend more frames on a cast without making those states
    ambiguous. The two styles move differently on purpose: lattice is precise and orbiting, ember is a broad sweep.
    """
    stance: dict[str, Limb] = {"near_leg": (-0.08, 0.785, -0.13, 0.97), "far_leg": (0.1, 0.78, 0.14, 0.97)}
    step: dict[str, Limb] = {"near_leg": (-0.11, 0.8, -0.23, 0.97), "far_leg": (0.18, 0.76, 0.23, 0.97)}
    brace: dict[str, Limb] = {"near_leg": (-0.12, 0.8, -0.2, 0.97), "far_leg": (0.1, 0.785, 0.17, 0.97)}
    if style == "lattice":
        frames = [
            battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **stance),
            battle_pose(lean=-0.02, near_arm=(-0.08, 0.43, -0.01, 0.43), far_arm=(0.12, 0.42, 0.04, 0.4), **stance),
            battle_pose(lean=-0.06, duck=0.02, near_arm=(-0.02, 0.39, 0.08, 0.34), far_arm=(0.16, 0.4, 0.12, 0.34), **brace),
            battle_pose(lean=-0.03, duck=0.03, near_arm=(0.08, 0.37, 0.18, 0.34), far_arm=(0.22, 0.37, 0.26, 0.33), **brace),
            battle_pose(lean=0.01, near_arm=(0.13, 0.36, 0.22, 0.4), far_arm=(0.22, 0.34, 0.34, 0.3), **brace),
            battle_pose(lean=0.05, near_arm=(0.05, 0.38, 0.02, 0.47), far_arm=(0.25, 0.31, 0.42, 0.3), **step),
            battle_pose(lean=0.08, near_arm=(-0.04, 0.4, -0.14, 0.5), far_arm=(0.26, 0.3, 0.46, 0.28), **step),
            battle_pose(lean=0.1, near_arm=(-0.12, 0.41, -0.2, 0.52), far_arm=(0.22, 0.31, 0.4, 0.3), **step),
            battle_pose(lean=0.07, near_arm=(-0.15, 0.42, -0.22, 0.53), far_arm=(0.2, 0.34, 0.35, 0.38), **step),
            battle_pose(lean=0.04, near_arm=(-0.11, 0.43, -0.15, 0.54), far_arm=(0.17, 0.37, 0.29, 0.42), **step),
            battle_pose(lean=0.01, near_arm=(-0.08, 0.44, -0.1, 0.55), far_arm=(0.15, 0.4, 0.24, 0.45), **stance),
            battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **stance),
        ]
    else:
        frames = [
            battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **stance),
            battle_pose(lean=-0.05, duck=0.02, near_arm=(-0.13, 0.45, -0.22, 0.48), far_arm=(0.17, 0.42, 0.24, 0.47), **stance),
            battle_pose(lean=-0.1, duck=0.04, near_arm=(-0.18, 0.42, -0.32, 0.39), far_arm=(0.2, 0.4, 0.32, 0.34), **brace),
            battle_pose(lean=-0.08, duck=0.02, near_arm=(-0.14, 0.38, -0.28, 0.28), far_arm=(0.24, 0.34, 0.39, 0.26), **brace),
            battle_pose(lean=-0.02, near_arm=(-0.08, 0.35, -0.16, 0.25), far_arm=(0.3, 0.3, 0.48, 0.24), **step),
            battle_pose(lean=0.05, near_arm=(0.04, 0.36, 0.03, 0.48), far_arm=(0.34, 0.28, 0.55, 0.29), **step),
            battle_pose(lean=0.11, near_arm=(0.12, 0.39, 0.1, 0.56), far_arm=(0.27, 0.3, 0.46, 0.32), **step),
            battle_pose(lean=0.14, near_arm=(0.02, 0.42, -0.06, 0.57), far_arm=(0.18, 0.34, 0.34, 0.4), **step),
            battle_pose(lean=0.1, near_arm=(-0.08, 0.43, -0.16, 0.54), far_arm=(0.12, 0.38, 0.24, 0.46), **step),
            battle_pose(lean=0.05, near_arm=(-0.12, 0.44, -0.18, 0.52), far_arm=(0.12, 0.41, 0.2, 0.49), **stance),
            battle_pose(lean=0.01, near_arm=(-0.1, 0.45, -0.1, 0.56), far_arm=(0.13, 0.43, 0.2, 0.5), **stance),
            battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **stance),
        ]
    return [frames[index : index + 4] for index in range(0, len(frames), 4)]


# ---------------------------------------------------------------------------------------------------------------------
# Rigged cast flows
#
# The hand-written frame lists above have one frame per drawn cell, so making a cast smoother means writing more tuples
# by hand and hoping they land on an arc. A rig instead states a few key poses and lets the sheet be sampled from them:
# every joint travels a Catmull-Rom curve through its keys, so hands swing on arcs rather than sliding along straight
# lines, and a timing curve decides which parts of the motion get the frames. Adding frames to an animation is then one
# number, and a new skin is a new list of keys on the same rig.


def lerp_pose(a: Pose, b: Pose, t: float) -> Pose:
    return {k: (a[k][0] + (b[k][0] - a[k][0]) * t, a[k][1] + (b[k][1] - a[k][1]) * t) for k in a if k in b}


# How hard the curve leans into a key's neighbours. The textbook Catmull-Rom is 0.5; at that strength a wrist that
# reverses direction swings a long way past the key it was heading for, and here that overshoot pushed an outstretched
# arm clean out of its cell. A softer 0.3 keeps the arc and stays inside the pose it was given.
TENSION = 0.3


def catmull(p0: float, p1: float, p2: float, p3: float, t: float, tension: float = TENSION) -> float:
    """The cardinal spline value between p1 and p2. It passes through every key and takes its direction at a key from
    that key's neighbours, which is what turns a sequence of stops into one continuous swing."""
    m1 = tension * (p2 - p0)
    m2 = tension * (p3 - p1)
    t2 = t * t
    t3 = t2 * t
    return (2 * t3 - 3 * t2 + 1) * p1 + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2 + (t3 - t2) * m2


def spline_pose(keys: list[Pose], u: float) -> Pose:
    """The pose at `u` in key units (0 is the first key, len(keys) - 1 the last), splined joint by joint."""
    last = len(keys) - 1
    i = max(0, min(last - 1, int(math.floor(u))))
    t = min(1.0, max(0.0, u - i))
    p0, p1, p2, p3 = keys[max(0, i - 1)], keys[i], keys[i + 1], keys[min(last, i + 2)]
    joints = set(p1) & set(p2)
    return {
        k: (
            catmull(p0.get(k, p1[k])[0], p1[k][0], p2[k][0], p3.get(k, p2[k])[0], t),
            catmull(p0.get(k, p1[k])[1], p1[k][1], p2[k][1], p3.get(k, p2[k])[1], t),
        )
        for k in joints
    }


def sample_flow(keys: list[Pose], count: int, timing: list[float]) -> list[Pose]:
    """`count` frames along the keys. `timing` is one key-unit position per frame: it is where the animator decides that
    a slow coil should spend five frames and the throw itself only two."""
    if len(timing) != count:
        raise ValueError(f"a flow of {count} frames needs {count} timing positions, got {len(timing)}")
    return [spline_pose(keys, u) for u in timing]


# The Prism Etcher's cast (ADR-0027). Nine keys: settle, gather, coil, cock, peak, throw, extend, follow, settle again.
# The character etches a figure in the air and snaps it forward, so the near hand draws the shape while the far arm
# loads, and the release is one long unbroken sweep from behind the shoulder to full extension.
PRISM_STANCE: dict[str, Limb] = {"near_leg": (-0.08, 0.785, -0.13, 0.97), "far_leg": (0.1, 0.78, 0.14, 0.97)}
PRISM_BRACE: dict[str, Limb] = {"near_leg": (-0.13, 0.8, -0.21, 0.97), "far_leg": (0.09, 0.785, 0.16, 0.97)}
PRISM_STEP: dict[str, Limb] = {"near_leg": (-0.12, 0.8, -0.25, 0.97), "far_leg": (0.19, 0.76, 0.26, 0.97)}


def prism_cast_keys() -> list[Pose]:
    return [
        # 0 settle: the idle the flow starts and ends on, so a cast never begins or ends with a jump.
        battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **PRISM_STANCE),
        # 1 gather: weight back, both hands rising to the chest.
        battle_pose(lean=-0.04, duck=0.02, near_arm=(-0.09, 0.43, -0.02, 0.44), far_arm=(0.13, 0.42, 0.08, 0.41), **PRISM_STANCE),
        # 2 coil: ducked, the near hand tracing the figure out in front, the far hand drawing back.
        battle_pose(lean=-0.09, duck=0.05, tilt=-0.02, near_arm=(0.02, 0.4, 0.14, 0.36), far_arm=(0.06, 0.43, -0.04, 0.42), **PRISM_BRACE),
        # 3 cock: the far arm loaded behind the shoulder, the near hand holding the figure steady.
        battle_pose(lean=-0.12, duck=0.04, tilt=-0.04, near_arm=(0.08, 0.37, 0.21, 0.31), far_arm=(-0.02, 0.4, -0.13, 0.35), **PRISM_BRACE),
        # 4 peak: the last frame before the throw, chin up, everything wound.
        battle_pose(lean=-0.14, duck=0.03, tilt=-0.05, near_arm=(0.1, 0.35, 0.24, 0.28), far_arm=(-0.05, 0.38, -0.16, 0.3), **PRISM_BRACE),
        # 5 throw: the step lands and the far arm comes through at the shoulder.
        battle_pose(lean=0.02, duck=0.01, tilt=-0.02, near_arm=(0.06, 0.38, 0.12, 0.44), far_arm=(0.18, 0.33, 0.3, 0.28), **PRISM_STEP),
        # 6 extend: full extension at the foe. This is the frame the bolt leaves on.
        battle_pose(lean=0.1, tilt=0.01, near_arm=(-0.06, 0.41, -0.14, 0.5), far_arm=(0.27, 0.3, 0.44, 0.29), **PRISM_STEP),
        # 7 follow: the arm drops past the throw and the body rides forward with it.
        battle_pose(lean=0.08, duck=0.02, near_arm=(-0.12, 0.43, -0.2, 0.53), far_arm=(0.24, 0.35, 0.4, 0.4), **PRISM_STEP),
        # 8 settle: back to the idle, one continuous fall.
        battle_pose(near_arm=(-0.1, 0.45, -0.08, 0.57), far_arm=(0.13, 0.44, 0.2, 0.5), **PRISM_STANCE),
    ]


# Where each drawn frame sits in key units. Frames 0-5 are the anticipation (slow, the charge cue holds them), 6-11 the
# release (fast through the throw, then the overshoot), 12-15 the recovery. The release frame is 7: key 6, full
# extension, which is what the bolt's launch is timed to (apps/client/src/shardrun/skins.ts).
PRISM_CAST_TIMING = [
    0.0, 0.55, 1.15, 1.85, 2.6, 3.45,      # anticipation: easing into the coil
    4.25, 5.1, 6.0, 6.45, 6.85, 7.2,       # release: the throw, the extension, the overshoot
    7.45, 7.7, 7.88, 8.0,                  # recovery: falling back to the settle
]
PRISM_CAST_FRAMES = len(PRISM_CAST_TIMING)
PRISM_RELEASE_FRAME = 8


def prism_hold_poses() -> list[Pose]:
    """The four states the cast flow cannot supply: ward, hurt, channel, victory (see `battle_poses`)."""
    ward = battle_pose(lean=-0.03, duck=0.04, near_arm=(0.11, 0.4, 0.26, 0.37), far_arm=(0.19, 0.35, 0.34, 0.32), **PRISM_BRACE)
    hurt = battle_pose(
        lean=-0.14, duck=0.05, tilt=-0.05,
        near_arm=(-0.14, 0.37, -0.24, 0.31), far_arm=(0.07, 0.43, 0.18, 0.49),
        near_leg=(-0.13, 0.8, -0.19, 0.97), far_leg=(0.12, 0.78, 0.21, 0.93),
    )
    channel = battle_pose(duck=0.02, tilt=-0.02, near_arm=(-0.15, 0.43, -0.27, 0.45), far_arm=(0.18, 0.42, 0.32, 0.44), **PRISM_BRACE)
    victory = battle_pose(
        tilt=-0.04,
        near_arm=(-0.14, 0.45, -0.1, 0.57), far_arm=(0.16, 0.44, 0.14, 0.29),
        near_leg=(-0.06, 0.78, -0.09, 0.97), far_leg=(0.06, 0.78, 0.09, 0.97),
    )
    return [ward, hurt, channel, victory]


def prism_sheet() -> list[list[Pose]]:
    """Twenty cells in four rows of five: sixteen cast-flow frames, then the four held states.

    One render for the whole rig on purpose. The strip post-process registers every cell against one box and gives them
    one palette (`post_pose_strip` in generate.py), so the idle, the cast and a hurt are the same character at the same
    size in the same colors -- which is what the separate sheets of the earlier skins could never guarantee.
    """
    cells = sample_flow(prism_cast_keys(), PRISM_CAST_FRAMES, PRISM_CAST_TIMING) + prism_hold_poses()
    return [cells[index : index + 5] for index in range(0, len(cells), 5)]


# Flows for the clips the character sheets do not cover (ADR-0028). Each is a handful of key poses sampled along the
# same spline as the cast, so they are authored the way the cast is rather than as one tuple per drawn frame.


def draw_sheet(rows: list[list[Pose]], width: int, height: int, figure: float = 0.86, shift: float = 0.0) -> Image.Image:
    """Lay poses out in a grid, one row per list, each figure `figure` of its cell's height, feet near the cell bottom.

    `shift` slides every figure sideways in figure units, the same amount in every cell. A cast that reaches far
    forward and only a little back is off-centre in its cell; sliding the whole sheet back recovers that room
    without changing any pose, so the frames still hold their relative positions when the strip registers them."""
    image = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    columns = max(len(row) for row in rows)
    cell_w, cell_h = width / columns, height / len(rows)
    size = cell_h * figure
    stick = max(3, round(size / 64))
    for r, row in enumerate(rows):
        for c, pose in enumerate(row):
            ox = cell_w * (c + 0.5) + shift * size
            oy = cell_h * (r + 1) - cell_h * (1 - figure) * 0.4 - size
            points = {k: (ox + x * size, oy + y * size) for k, (x, y) in pose.items()}
            for i, (a, b) in enumerate(LIMBS):
                if a not in points or b not in points:
                    continue
                (x1, y1), (x2, y2) = points[a], points[b]
                color = tuple(int(v * 0.6) for v in COLORS[i])
                # LEARN: OpenPose draws each limb as a filled ellipse along the bone; a polygon of 16 points is close.
                length = math.hypot(x2 - x1, y2 - y1) / 2
                angle = math.atan2(y2 - y1, x2 - x1)
                mx, my = (x1 + x2) / 2, (y1 + y2) / 2
                polygon = [
                    (mx + length * math.cos(t) * math.cos(angle) - stick * math.sin(t) * math.sin(angle),
                     my + length * math.cos(t) * math.sin(angle) + stick * math.sin(t) * math.cos(angle))
                    for t in (2 * math.pi * k / 16 for k in range(16))
                ]
                draw.polygon(polygon, fill=color)
            for key, (x, y) in points.items():
                draw.ellipse((x - stick, y - stick, x + stick, y + stick), fill=COLORS[key])
    return image


SHEETS = {
    "walk": lambda: [poses for poses in walk_poses().values()],
    "battle": battle_poses,
    "battle-lattice": lambda: battle_cast_poses("lattice"),
    "battle-ember": lambda: battle_cast_poses("ember"),
    "prism-rig": prism_sheet,
}


# How much of a cell's height a figure fills. A sheet whose poses reach further sideways needs smaller figures, or an
# outstretched arm crosses into the neighbouring cell and the model draws the two bodies as one.
FIGURES = {"prism-rig": 0.78}
# Sideways room, in figure units, for sheets whose poses are not symmetric (see `draw_sheet`).
SHIFTS = {"prism-rig": -0.06}


def sheet(name: str, width: int, height: int) -> Image.Image:
    if name not in SHEETS:
        raise ValueError(f"unknown pose sheet {name!r}; known: {', '.join(SHEETS)}")
    return draw_sheet(SHEETS[name](), width, height, FIGURES.get(name, 0.86), SHIFTS.get(name, 0.0))


if __name__ == "__main__":
    sheet(sys.argv[1], int(sys.argv[2]), int(sys.argv[3])).save(sys.argv[4])
