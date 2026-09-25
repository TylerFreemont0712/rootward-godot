"""The sprite rig: a three-quarter skeleton, posed by keyframes, drawn as OpenPose frames (ADR-0008).

Ported from the old game's sprite pipeline (ProgramMe, its ADR-0029/0030). There every skin shared one chibi skeleton;
here a skin brings its own (`skins/<id>/rig.json`, `skins/<id>/animations.json`), because an anime-proportioned body
needs different joints. A new animation for a skin is keyframes on its rig, and a skin needs one reference picture
drawn in its rest pose. Nothing here knows what a character looks like; it only knows where the joints are.

Keys are posed with two-bone inverse kinematics: a key names where a wrist or an ankle should be, and the elbow or knee
is solved from the rest bone lengths. That keeps the limbs one length through the whole clip, which a keyframed
*position* per joint would not (interpolating an elbow in a straight line shortens the arm mid-swing, and the video
model draws exactly what the skeleton says).

Preview a clip's skeletons:  uv run --project pipeline python pipeline/sprites/rig.py vesper cast-light /tmp/pose.png
"""

from __future__ import annotations

import colorsys
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent

# The 18 COCO keypoints, in the order OpenPose ControlNets were trained on. "r" and "l" are the figure's own sides.
KEYPOINTS = [
    "nose", "neck", "r_shoulder", "r_elbow", "r_wrist", "l_shoulder", "l_elbow", "l_wrist", "r_hip", "r_knee",
    "r_ankle", "l_hip", "l_knee", "l_ankle", "r_eye", "l_eye", "r_ear", "l_ear",
]
INDEX = {name: index for index, name in enumerate(KEYPOINTS)}
LIMBS = [
    ("neck", "r_shoulder"), ("neck", "l_shoulder"), ("r_shoulder", "r_elbow"), ("r_elbow", "r_wrist"),
    ("l_shoulder", "l_elbow"), ("l_elbow", "l_wrist"), ("neck", "r_hip"), ("r_hip", "r_knee"), ("r_knee", "r_ankle"),
    ("neck", "l_hip"), ("l_hip", "l_knee"), ("l_knee", "l_ankle"), ("neck", "nose"), ("nose", "r_eye"),
    ("r_eye", "r_ear"), ("nose", "l_eye"), ("l_eye", "l_ear"),
]
COLORS = [
    (255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0), (0, 255, 85),
    (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255),
    (255, 0, 255), (255, 0, 170), (255, 0, 85),
]
HEAD = ("nose", "r_eye", "l_eye", "r_ear", "l_ear")
# "near" is the side toward the camera in the three-quarter stance: the figure's right, on the screen's left.
SIDES = {"near": "r", "far": "l"}

Point = tuple[float, float]
Pose = dict[str, Point]


SKINS = HERE / "skins"


def load_rig(skin_id: str) -> dict:
    return json.loads((SKINS / skin_id / "rig.json").read_text())


def load_animations(skin_id: str) -> dict:
    return json.loads((SKINS / skin_id / "animations.json").read_text())


def rotate(point: Point, pivot: Point, degrees: float) -> Point:
    """Rotate about a pivot. y grows downward, so a positive angle turns the top of a figure toward +x (the foe)."""
    a = math.radians(degrees)
    x, y = point[0] - pivot[0], point[1] - pivot[1]
    return (pivot[0] + x * math.cos(a) - y * math.sin(a), pivot[1] + x * math.sin(a) + y * math.cos(a))


def distance(a: Point, b: Point) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def two_bone(root: Point, target: Point, upper: float, lower: float, hint: Point) -> tuple[Point, Point]:
    """Solve an elbow (or knee) and the end point for a two-bone limb reaching from `root` toward `target`.

    Of the two mirror solutions, the one on the side of `hint` wins, so an elbow keeps bending the way it rests.
    A target out of reach straightens the limb toward it rather than stretching it."""
    reach = distance(root, target)
    reach = min(max(reach, abs(upper - lower) + 1e-4), upper + lower - 1e-4)
    direction = math.atan2(target[1] - root[1], target[0] - root[0])
    # LEARN: the law of cosines gives the angle at the root between the reach line and the upper bone.
    bend = math.acos(max(-1.0, min(1.0, (upper**2 + reach**2 - lower**2) / (2 * upper * reach))))
    end = (root[0] + reach * math.cos(direction), root[1] + reach * math.sin(direction))
    candidates = [
        (root[0] + upper * math.cos(direction + sign * bend), root[1] + upper * math.sin(direction + sign * bend))
        for sign in (1, -1)
    ]
    joint = min(candidates, key=lambda c: distance(c, hint))
    return joint, end


@dataclass(frozen=True)
class Params:
    """One key, fully resolved: every field has a number, so keys can be interpolated field by field."""

    values: tuple[float, ...]

    FIELDS = ("bx", "by", "lean", "head", "nx", "ny", "fx", "fy", "nfx", "nfy", "ffx", "ffy", "nbend", "fbend")


# --- hands ------------------------------------------------------------------------------------------------------------
#
# The body skeleton says where a wrist is and nothing about the hand, so the video model decided for itself which way
# a palm faced, and it liked palm-up: a cast thrown with an upturned palm at chest height reads as an underhand toss
# (the player, 2026-09-24). A clip can name hands to draw as OpenPose's 21-point hand skeleton, and a key can set a
# gesture and a bend at the wrist for each. Wan's VACE was trained on DWPose skeletons, which carry hands.
#
# A gesture is five fingers in the hand's own frame: x runs from the wrist toward the fingertips, y across the palm,
# in units of the hand's length. Each finger is a knuckle position, a splay (radians off the hand's axis) and a curl
# (0 straight, 1 folded into the palm, which in a two-dimensional drawing mostly shortens it).

HAND_EDGES = [(0, 1), (1, 2), (2, 3), (3, 4)] + [
    edge for base in (5, 9, 13, 17) for edge in ((0, base), (base, base + 1), (base + 1, base + 2), (base + 2, base + 3))
]
FINGERS = {  # knuckle (x, y), splay; the thumb's "knuckle" is its root near the wrist
    "thumb": ((0.12, 0.12), 0.8),
    "index": ((0.48, 0.16), 0.16),
    "middle": ((0.5, 0.03), 0.02),
    "ring": ((0.47, -0.09), -0.12),
    "pinky": ((0.41, -0.2), -0.26),
}
SEGMENTS = {"thumb": (0.2, 0.17, 0.14), "index": (0.24, 0.16, 0.13), "middle": (0.26, 0.17, 0.14),
            "ring": (0.24, 0.16, 0.13), "pinky": (0.19, 0.13, 0.11)}
GESTURES: dict[str, dict[str, tuple[float, float]]] = {
    # finger: (curl, extra splay)
    "open": {"thumb": (0.0, 0.15), "index": (0.0, 0.1), "middle": (0.0, 0.0), "ring": (0.0, -0.08), "pinky": (0.0, -0.16)},
    "relaxed": {"thumb": (0.3, -0.2), "index": (0.25, -0.1), "middle": (0.3, 0.0), "ring": (0.35, 0.05), "pinky": (0.4, 0.1)},
    "fist": {"thumb": (0.6, -0.5), "index": (0.85, 0.0), "middle": (0.85, 0.0), "ring": (0.85, 0.0), "pinky": (0.85, 0.0)},
    "point": {"thumb": (0.55, -0.4), "index": (0.0, -0.1), "middle": (0.85, 0.0), "ring": (0.85, 0.0), "pinky": (0.85, 0.0)},
    "two": {"thumb": (0.55, -0.4), "index": (0.0, -0.06), "middle": (0.0, 0.04), "ring": (0.85, 0.0), "pinky": (0.85, 0.0)},
}
HAND_LENGTH = 0.08  # figure units; a chibi hand is a little over half its forearm. A rig can set its own ("hand").


def hand_points(
    gesture: dict[str, tuple[float, float]], wrist: Point, angle: float, thumb: float, length: float = HAND_LENGTH
) -> list[Point]:
    """The 21 OpenPose hand keypoints for a gesture, the hand pointing along `angle` (radians, screen space).

    `thumb` is +1 or -1: which side of the hand's axis the thumb lies on, as drawn."""
    ca, sa = math.cos(angle), math.sin(angle)

    def place(x: float, y: float) -> Point:
        y *= thumb
        return (wrist[0] + length * (x * ca - y * sa), wrist[1] + length * (x * sa + y * ca))

    points = [wrist]
    for name in ("thumb", "index", "middle", "ring", "pinky"):
        (x, y), splay = FINGERS[name]
        curl, extra = gesture[name]
        direction = splay + extra
        points.append(place(x, y))
        for index, length in enumerate(SEGMENTS[name]):
            # A curling finger folds toward the palm: shorter in the drawing, and turning in across the hand.
            direction += curl * (0.5 + 0.35 * index) * 0.6 * (-1 if name == "thumb" else 1)
            step = length * (1.0 - 0.7 * curl)
            x, y = x + step * math.cos(direction), y + step * math.sin(direction)
            points.append(place(x, y))
    return points


def blend_gesture(a: str, b: str, u: float) -> dict[str, tuple[float, float]]:
    ga, gb = GESTURES[a], GESTURES[b]
    return {f: (ga[f][0] + (gb[f][0] - ga[f][0]) * u, ga[f][1] + (gb[f][1] - ga[f][1]) * u) for f in ga}


def torso(rest: Pose, body: Point, lean: float, head: float) -> Pose:
    """Everything above the legs after the body moves and leans. Arms ride along at their rest angles."""
    pose: Pose = {}
    for name, (x, y) in rest.items():
        if name.endswith(("ankle", "knee")):
            continue
        pose[name] = (x + body[0], y + body[1])
    pivot = ((pose["r_hip"][0] + pose["l_hip"][0]) / 2, (pose["r_hip"][1] + pose["l_hip"][1]) / 2)
    for name in list(pose):
        if not name.endswith("hip"):
            pose[name] = rotate(pose[name], pivot, lean)
    for name in HEAD:
        if name in pose:
            pose[name] = rotate(pose[name], pose["neck"], head)
    return pose


def resolve_key(key: dict, rest: Pose, poses: dict) -> Params:
    """Fill every field a key leaves out: from its named pose, then from rest. A hand left out rides the torso."""
    merged = {**poses.get(key.get("pose", ""), {}), **{k: v for k, v in key.items() if k not in ("t", "pose")}}
    body = tuple(merged.get("body", (0.0, 0.0)))
    lean = float(merged.get("lean", 0.0))
    head = float(merged.get("head", 0.0))
    carried = torso(rest, (body[0], body[1]), lean, head)
    near = tuple(merged.get("near", carried["r_wrist"]))
    far = tuple(merged.get("far", carried["l_wrist"]))
    near_foot = tuple(merged.get("nearFoot", rest["r_ankle"]))
    far_foot = tuple(merged.get("farFoot", rest["l_ankle"]))
    near_bend = float(merged.get("nearBend", 0.0))
    far_bend = float(merged.get("farBend", 0.0))
    return Params((body[0], body[1], lean, head, near[0], near[1], far[0], far[1], *near_foot, *far_foot, near_bend,
                   far_bend))


def key_gesture(key: dict, poses: dict, side: str) -> str:
    """The gesture a key gives a hand ("nearHand"/"farHand"), from the key, then its named pose, else relaxed."""
    field = "nearHand" if side == "r" else "farHand"
    name = key.get(field, poses.get(key.get("pose", ""), {}).get(field, "relaxed"))
    if name not in GESTURES:
        raise SystemExit(f"unknown hand gesture {name!r}; known: {', '.join(GESTURES)}")
    return name


# Which side of the hand the thumb is drawn on. The far hand is the figure's left, seen three-quarter from the front:
# raised toward the foe, its thumb lies on the upper, camera side of the hand.
THUMB = {"r": 1.0, "l": -1.0}


def pose_from(
    params: Params, rest: Pose, hands: dict[str, dict[str, tuple[float, float]]] | None = None, hand_length: float = HAND_LENGTH
) -> Pose:
    bx, by, lean, head, nx, ny, fx, fy, nfx, nfy, ffx, ffy, nbend, fbend = params.values
    pose = torso(rest, (bx, by), lean, head)
    carried = pose
    for side, target in (("r", (nx, ny)), ("l", (fx, fy))):
        shoulder = carried[f"{side}_shoulder"]
        upper = distance(rest[f"{side}_shoulder"], rest[f"{side}_elbow"])
        lower = distance(rest[f"{side}_elbow"], rest[f"{side}_wrist"])
        hint = carried[f"{side}_elbow"]
        # An elbow drops as its hand rises, so bias the hint downward and outward instead of trusting the rest angle.
        hint = (hint[0] + (-0.05 if side == "r" else 0.03), hint[1] + 0.06)
        pose[f"{side}_elbow"], pose[f"{side}_wrist"] = two_bone(shoulder, target, upper, lower, hint)
    for side, target in (("r", (nfx, nfy)), ("l", (ffx, ffy))):
        hip = pose[f"{side}_hip"]
        upper = distance(rest[f"{side}_hip"], rest[f"{side}_knee"])
        lower = distance(rest[f"{side}_knee"], rest[f"{side}_ankle"])
        # Knees bend toward the foe.
        hint = ((hip[0] + target[0]) / 2 + 0.2, (hip[1] + target[1]) / 2)
        pose[f"{side}_knee"], pose[f"{side}_ankle"] = two_bone(hip, target, upper, lower, hint)
    for side, gesture in (hands or {}).items():
        elbow, wrist = pose[f"{side}_elbow"], pose[f"{side}_wrist"]
        # The hand continues the forearm, turned at the wrist by the key's bend (degrees; negative turns the fingers
        # up on screen when the arm points at the foe).
        angle = math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0]) + math.radians(nbend if side == "r" else fbend)
        for index, point in enumerate(hand_points(gesture, wrist, angle, THUMB[side], hand_length)):
            pose[f"{side}_hand{index}"] = point
    return pose


def hermite(p0: float, p1: float, m0: float, m1: float, u: float) -> float:
    u2, u3 = u * u, u * u * u
    return (2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * p1 + (u3 - u2) * m1


# Tangent scale for the cubic. 1 is Catmull-Rom (keys flow through each other); 0 eases in and out of every key, which
# reads as a string of separate moves. An animator's keys are extremes, so a body should mostly settle into them.
TENSION = 0.55


def sample(
    keys: list[dict],
    frames: int,
    rest: Pose,
    poses: dict,
    loop: bool,
    hands: tuple[str, ...] = (),
    hand_length: float = HAND_LENGTH,
) -> list[Pose]:
    """Poses for every frame of a clip. A loop's tangents wrap, so its seam is as smooth as its middle.

    `hands` names the hands ("near", "far") to draw as hand skeletons. A gesture changes smoothly between keys."""
    sides = [SIDES[hand] for hand in hands]
    gestures = {side: [key_gesture(key, poses, side) for key in keys] for side in sides}
    times = [float(key["t"]) for key in keys]
    values = [resolve_key(key, rest, poses).values for key in keys]
    count = len(keys)

    def neighbour(index: int) -> tuple[float, tuple[float, ...]]:
        if 0 <= index < count:
            return times[index], values[index]
        if not loop:
            clamped = min(max(index, 0), count - 1)
            return times[clamped], values[clamped]
        # A loop's first and last keys are the same moment, so step over the duplicate when wrapping.
        if index < 0:
            return times[count - 2] - 1.0, values[count - 2]
        return times[1] + 1.0, values[1]

    def tangent(index: int, field: int) -> float:
        t0, v0 = neighbour(index - 1)
        t1, v1 = neighbour(index + 1)
        if t1 == t0:
            return 0.0
        return TENSION * (v1[field] - v0[field]) / (t1 - t0)

    out: list[Pose] = []
    for frame in range(frames):
        t = frame / max(1, frames - 1)
        segment = max(0, min(count - 2, next((i for i in range(count - 1) if times[i + 1] >= t), count - 2)))
        span = times[segment + 1] - times[segment]
        u = 0.0 if span <= 0 else (t - times[segment]) / span
        mixed = tuple(
            hermite(
                values[segment][f],
                values[segment + 1][f],
                tangent(segment, f) * span,
                tangent(segment + 1, f) * span,
                u,
            )
            for f in range(len(Params.FIELDS))
        )
        # LEARN: a smoothstep across the segment, so a hand opens or closes in the middle of a move, not at its ends.
        ease = u * u * (3 - 2 * u)
        hands_now = {
            side: blend_gesture(gestures[side][segment], gestures[side][segment + 1], ease) for side in sides
        }
        out.append(pose_from(Params(mixed), rest, hands_now, hand_length))
    return out


def spec_poses(spec: dict, rig: dict, animations: dict) -> list[Pose]:
    """Every frame's pose for one clip spec (the skin's clip, with its skin.json overrides already laid over it)."""
    rest = {k: (float(v[0]), float(v[1])) for k, v in rig["rest"].items()}
    hands = tuple(spec.get("hands", ()))
    return sample(
        spec["keys"],
        int(spec["frames"]),
        rest,
        animations.get("poses", {}),
        bool(spec.get("loop")),
        hands,
        float(rig.get("hand", HAND_LENGTH)),
    )


def clip_poses(skin_id: str, name: str) -> list[Pose]:
    rig, animations = load_rig(skin_id), load_animations(skin_id)
    clip = animations["clips"].get(name)
    if clip is None:
        raise SystemExit(f"unknown clip {name!r}; known: {', '.join(animations['clips'])}")
    return spec_poses(clip, rig, animations)


def rest_pose(rig: dict) -> Pose:
    return {k: (float(v[0]), float(v[1])) for k, v in rig["rest"].items()}


def to_canvas(point: Point, rig: dict, width: int, height: int) -> Point:
    """Figure units to pixels on a canvas of this size (the rig's canvas, or any multiple of it)."""
    size = rig["figure"] * height
    feet = rig["feet"] * height
    return (rig["center"] * width + point[0] * size, feet - (1.0 - point[1]) * size)


def draw_pose(pose: Pose, rig: dict, width: int, height: int) -> Image.Image:
    """One OpenPose frame: limbs as 60%-brightness ellipses, joints as full-colour dots, on black."""
    image = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    stick = max(3, round(height / 110))
    points = {name: to_canvas(p, rig, width, height) for name, p in pose.items()}
    for index, (a, b) in enumerate(LIMBS):
        if a not in points or b not in points:
            continue
        (x1, y1), (x2, y2) = points[a], points[b]
        color = tuple(int(v * 0.6) for v in COLORS[index])
        length = math.hypot(x2 - x1, y2 - y1) / 2
        angle = math.atan2(y2 - y1, x2 - x1)
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        polygon = [
            (mx + length * math.cos(s) * math.cos(angle) - stick * math.sin(s) * math.sin(angle),
             my + length * math.cos(s) * math.sin(angle) + stick * math.sin(s) * math.cos(angle))
            for s in (2 * math.pi * k / 16 for k in range(16))
        ]
        draw.polygon(polygon, fill=color)
    for name, (x, y) in points.items():
        if name in INDEX:
            draw.ellipse((x - stick, y - stick, x + stick, y + stick), fill=COLORS[INDEX[name]])
    # Hands the way DWPose draws them: thin rainbow bones and small blue joints over the body.
    fine = max(2, round(height / 280))
    for side in ("r", "l"):
        if f"{side}_hand0" not in points:
            continue
        hand = [points[f"{side}_hand{i}"] for i in range(21)]
        for index, (a, b) in enumerate(HAND_EDGES):
            r, g, b_ = colorsys.hsv_to_rgb(index / len(HAND_EDGES), 1.0, 1.0)
            draw.line((hand[a], hand[b]), fill=(round(r * 255), round(g * 255), round(b_ * 255)), width=fine)
        dot = fine * 0.75
        for x, y in hand:
            draw.ellipse((x - dot, y - dot, x + dot, y + dot), fill=(0, 0, 255))
    return image


def pose_sheet(poses: list[Pose], rig: dict, columns: int) -> Image.Image:
    """Every frame's skeleton on the rig's canvas, in a grid of `columns`: the animation graph's input."""
    width, height = rig["canvas"]
    rows = -(-len(poses) // columns)
    sheet = Image.new("RGB", (columns * width, rows * height), (0, 0, 0))
    for index, pose in enumerate(poses):
        row, column = divmod(index, columns)
        sheet.paste(draw_pose(pose, rig, width, height), (column * width, row * height))
    return sheet


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: rig.py <skin> <clip|rest> <out.png>")
    skin, clip, out = sys.argv[1:]
    rig = load_rig(skin)
    poses = [rest_pose(rig)] if clip == "rest" else clip_poses(skin, clip)
    pose_sheet(poses, rig, min(8, len(poses))).save(out)
