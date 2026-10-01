"""The motion of a clip, as numbers: poses, keys, easing and procedural layers, sampled frame by frame.

Pure Python (no Blender, no numpy), so the same code runs in Blender's Python and in the tests
(`python3 -m unittest discover pipeline/moves`). `pipeline/blender/build_moves.py` turns each sampled frame into
bone rotations on a real rig; this module never knows what a bone's axes are.

A **pose** is a dict of bone -> parameters, every parameter a number with a meaning a person can read
(`"LeftUpperArm": {"raise": 20, "forward": 10}` lifts her left arm 20 degrees above level and swings it 10 degrees
to the front). A parameter that is not given is 0, which is the rest pose: the VRM T-pose. Bones are Godot's
humanoid profile names (`SkeletonProfileHumanoid`), so a clip plays on every VRM skin.

- A bone named without a side (`"UpperArm"`) sets both sides; the right one mirrors the left (the build does that).
- `"base": "stand"` starts a pose from a named pose in `poses.json`, then the pose's own bones replace or add
  parameters (a deep merge: `{"LeftHand": {"curl": 1}}` keeps the base's other hand parameters).

A **clip** (`clips/<id>.json`) is keys on a timeline, in seconds:

    {"length": 1.1, "loop": false, "events": {"release": 0.40}, "hand": "LeftHand",
     "keys": [{"t": 0, "pose": "idle"}, {"t": 0.4, "pose": {...}, "ease": "expo_out"}],
     "lag": {"Head": 0.05}, "layers": [{"kind": "bob", "amp": 0.02, "period": 1.6}],
     "step": [{"from": 1.0, "to": 1.4, "frames": 2}]}

- `ease` is how a key is *arrived at* from the key before it. `back_out` overshoots and settles, `expo_out` snaps,
  `back_in` pulls back before it goes (anticipation), `hold` jumps at the key (a held drawing).
- `lag` samples a bone that many seconds late, so it follows the body through a move (overlapping action).
- `step` holds each drawing for `frames` frames between `from` and `to`: animation on twos, the anime staccato.
- `layers` add motion on top of the keys: `breathe`, `bob`, `sway`, `tremble`, and `wave` (one bone's parameter).
- `follow` hangs a bone on a spring that chases its keyed pose (`"Hand": [8, 0.45]`: 8 Hz, damping 0.45), so when the
  body stops the hand carries on, overshoots and settles: follow-through without keying it. Lower damping wobbles
  more; a higher frequency follows tighter.
- `mocap` plays motion capture under the keys (ADR-0030): takes from a source in `sources.json`, one after another,
  crossfaded over `blend` seconds: `"mocap": [{"source": "quaternius", "action": "Idle_Loop", "from": 0, "to": 2.5,
  "speed": 1}]`. The build retargets each take onto the skeleton. In a mocap clip the keys and layers are **offsets**
  added on top of the capture (`"Head": {"turn": 12}` turns the captured head 12 degrees further), except for:
- `own`: bones the keys pose outright, over the capture, by a weight that rises and falls on its own timeline:
  `"own": {"bones": ["LeftUpperArm", "LeftLowerArm", "LeftHand"], "weight": [[0, 0], [0.3, 1], [1.0, 0]]}`. An
  owned bone a key leaves out holds its pose from the nearest key that has it (so it never drifts toward the T-pose
  while its weight fades). A hand given finger parameters (`curl`, `cascade`, ...) in a mocap clip has its fingers
  posed by them, not by the capture, by the `fingers` weight (`[[t, w], ...]`, 1 throughout by default).
- `plant` keeps the feet on the floor (the build solves the legs so each planted foot stays put, flat, while the hips
  move). Both feet are planted for the whole clip unless the clip says otherwise:
  `"plant": {"LeftFoot": [[0, 0.3], [0.9, 2.3]], "RightFoot": [[0, 0.3]]}` plants each foot only in those windows
  (fading in and out over `plant_fade` seconds), so it can leave the ground for a jump or a kicked heel. A foot
  the clip does not name stays planted.
"""

from __future__ import annotations

import copy
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
FPS = 30

FEET = ("LeftFoot", "RightFoot")
PLANT = "Plant"

SIDED = (
    "Shoulder",
    "UpperArm",
    "LowerArm",
    "Hand",
    "UpperLeg",
    "LowerLeg",
    "Foot",
    "Toes",
    "Eye",
)

Pose = dict[str, dict[str, float]]


# LEARN: easing functions take a fraction of the way (0..1) and return how far along the motion is. Returning more
# than 1 before the end (back_out, elastic_out) is an overshoot: the pose passes its target and settles back.
def _back_out(u: float, s: float = 1.70158) -> float:
    u -= 1.0
    return u * u * ((s + 1.0) * u + s) + 1.0


def _back_in(u: float, s: float = 1.70158) -> float:
    return u * u * ((s + 1.0) * u - s)


EASES = {
    "linear": lambda u: u,
    "sine": lambda u: 0.5 - 0.5 * math.cos(math.pi * u),
    "smooth": lambda u: u * u * u * (u * (u * 6.0 - 15.0) + 10.0),
    "quad_out": lambda u: 1.0 - (1.0 - u) ** 2,
    "cubic_in": lambda u: u**3,
    "cubic_out": lambda u: 1.0 - (1.0 - u) ** 3,
    "expo_in": lambda u: 0.0 if u <= 0.0 else 2.0 ** (10.0 * (u - 1.0)),
    "expo_out": lambda u: 1.0 if u >= 1.0 else 1.0 - 2.0 ** (-10.0 * u),
    "back_out": _back_out,
    "back_in": _back_in,
    "big_back_out": lambda u: _back_out(u, 3.0),
    "elastic_out": lambda u: (
        u if u in (0.0, 1.0) else 2.0 ** (-10.0 * u) * math.sin((u * 10.0 - 0.75) * (2.0 * math.pi / 3.0)) + 1.0
    ),
    "hold": lambda u: 1.0 if u >= 1.0 else 0.0,
}


def ease(name: str, u: float) -> float:
    if name not in EASES:
        raise ValueError(f"unknown ease {name!r}; one of {', '.join(sorted(EASES))}")
    return EASES[name](min(1.0, max(0.0, u)))


def split_sides(pose: Pose) -> Pose:
    """`UpperArm` -> `LeftUpperArm` and `RightUpperArm` (same numbers; the build mirrors the right)."""
    out: Pose = {}
    for bone, params in pose.items():
        if bone in SIDED:
            for side in ("Left", "Right"):
                out.setdefault(side + bone, {}).update(params)
        else:
            out.setdefault(bone, {}).update(params)
    return out


def merge(base: Pose, over: Pose) -> Pose:
    out = copy.deepcopy(base)
    for bone, params in over.items():
        out.setdefault(bone, {}).update(params)
    return out


def resolve(pose: str | dict, library: dict[str, dict]) -> Pose:
    """A named pose or an inline one, with its `base` chain applied, sides split."""
    if isinstance(pose, str):
        if pose not in library:
            raise KeyError(f"no pose {pose!r} in poses.json")
        return resolve(library[pose], library)
    body = {k: v for k, v in pose.items() if k != "base"}
    own = split_sides(body)
    if "base" in pose:
        return merge(resolve(pose["base"], library), own)
    return own


def lerp_pose(a: Pose, b: Pose, w: float) -> Pose:
    out: Pose = {}
    for bone in set(a) | set(b):
        pa, pb = a.get(bone, {}), b.get(bone, {})
        out[bone] = {p: pa.get(p, 0.0) + (pb.get(p, 0.0) - pa.get(p, 0.0)) * w for p in set(pa) | set(pb)}
    return out


class Clip:
    def __init__(self, clip_id: str, data: dict, library: dict[str, dict]) -> None:
        self.id = clip_id
        self.data = data
        self.length = float(data["length"])
        self.loop = bool(data.get("loop", False))
        self.lag: dict[str, float] = {}
        for bone, lag in data.get("lag", {}).items():
            for name in [side + bone for side in ("Left", "Right")] if bone in SIDED else [bone]:
                self.lag[name] = float(lag)
        self.layers: list[dict] = data.get("layers", [])
        self.steps: list[dict] = data.get("step", [])
        self.follow: dict[str, tuple[float, float]] = {}
        for bone, (hz, damping) in data.get("follow", {}).items():
            for name in [side + bone for side in ("Left", "Right")] if bone in SIDED else [bone]:
                self.follow[name] = (float(hz), float(damping))
        self._followed: list[Pose] | None = None
        self.takes = self._timeline(data.get("mocap", []), float(data.get("blend", 0.15)))
        self.own: set[str] = set()
        for bone in data.get("own", {}).get("bones", []):
            self.own.update([side + bone for side in ("Left", "Right")] if bone in SIDED else [bone])
        self.own_weight_keys = [(float(t), float(w)) for t, w in data.get("own", {}).get("weight", [[0, 1]])]
        self.finger_weight_keys = [(float(t), float(w)) for t, w in data.get("fingers", [[0, 1]])]
        keys = sorted(data.get("keys", [{"t": 0, "pose": {}}]), key=lambda k: float(k["t"]))
        if not keys or float(keys[0]["t"]) != 0.0:
            raise ValueError(f"clip {clip_id}: the first key must be at t=0")
        self.keys = [(float(k["t"]), resolve(k["pose"], library), k.get("ease", "sine")) for k in keys]
        self._hold_owned()
        if self.loop and self.keys[-1][0] < self.length:
            # A loop closes on its first pose, so its last frame flows into its first.
            self.keys.append((self.length, self.keys[0][1], self.data.get("close", "sine")))

    @staticmethod
    def _timeline(takes: list[dict], blend: float) -> list[dict]:
        """Each take placed on the clip's timeline: it starts `blend` seconds before the one before it ends."""
        out: list[dict] = []
        start = 0.0
        for take in takes:
            speed = float(take.get("speed", 1.0))
            length = (float(take["to"]) - float(take.get("from", 0.0))) / speed
            placed = {**take, "start": start, "length": length, "speed": speed, "from": float(take.get("from", 0.0))}
            out.append(placed)
            start += length - (blend if take is not takes[-1] else 0.0)
        for i, take in enumerate(out):
            take["fade_in"] = blend if i > 0 else 0.0
        return out

    def mocap_at(self, t: float) -> list[tuple[str, str, float, float]]:
        """The captured takes playing at `t`: (source, action, the take's own time in seconds, weight); the weights add
        up to 1, two takes sharing it while one crossfades into the next."""
        if not self.takes:
            return []
        if self.loop and len(self.takes) == 1:
            take = self.takes[0]
            local = (t % self.length) / self.length * take["length"]
            return [(take["source"], take["action"], take["from"] + local * take["speed"], 1.0)]
        playing: list[tuple[str, str, float, float]] = []
        for i, take in enumerate(self.takes):
            local = t - take["start"]
            last = i == len(self.takes) - 1
            if local < 0.0 or (local > take["length"] and not last):
                continue
            local = min(local, take["length"])
            weight = 1.0
            if take["fade_in"] > 0.0 and local < take["fade_in"]:
                weight = EASES["smooth"](local / take["fade_in"])
            playing.append((take["source"], take["action"], take["from"] + local * take["speed"], weight))
        if not playing:
            first = self.takes[0]
            return [(first["source"], first["action"], first["from"], 1.0)]
        # The newest take has its share; the ones before it share what is left, the most recent first.
        out: list[tuple[str, str, float, float]] = []
        left = 1.0
        for source, action, at, weight in reversed(playing):
            share = left * weight
            out.append((source, action, at, share))
            left -= share
        return [entry for entry in reversed(out) if entry[3] > 1e-4]

    def _hold_owned(self) -> None:
        """An owned bone missing from a key takes its pose from the key before it (or, first, the key after)."""
        for bone in self.own:
            held = next((pose[bone] for _, pose, _ in self.keys if bone in pose), None)
            if held is None:
                continue
            for _, pose, _ in self.keys:
                if bone in pose:
                    held = pose[bone]
                else:
                    pose[bone] = copy.deepcopy(held)

    def own_weight(self, bone: str, t: float) -> float:
        """How fully the keys pose `bone` over the capture at `t` (0 when the bone is not owned)."""
        if bone not in self.own:
            return 0.0
        return self._curve(self.own_weight_keys, t)

    def finger_weight(self, t: float) -> float:
        """How fully a keyed hand's fingers replace the capture's at `t`."""
        return self._curve(self.finger_weight_keys, t)

    @staticmethod
    def _curve(points: list[tuple[float, float]], t: float) -> float:
        if t <= points[0][0]:
            return points[0][1]
        for (t0, w0), (t1, w1) in zip(points, points[1:]):
            if t <= t1:
                return w0 + (w1 - w0) * EASES["smooth"]((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
        return points[-1][1]

    @property
    def frames(self) -> int:
        """Frames in the clip; a loop leaves out its closing frame (it is frame 0 again)."""
        n = round(self.length * FPS)
        return n if self.loop else n + 1

    def _keyed(self, t: float) -> Pose:
        if self.loop:
            t %= self.length
        t = min(max(t, 0.0), self.keys[-1][0])
        for (t0, p0, _), (t1, p1, name) in zip(self.keys, self.keys[1:]):
            if t <= t1:
                span = t1 - t0
                return lerp_pose(p0, p1, ease(name, (t - t0) / span if span > 0 else 1.0))
        return copy.deepcopy(self.keys[-1][1])

    def _stepped(self, t: float) -> float:
        for step in self.steps:
            if float(step["from"]) <= t < float(step["to"]):
                hold = int(step.get("frames", 2)) / FPS
                return float(step["from"]) + math.floor((t - float(step["from"])) / hold + 1e-9) * hold
        return t

    def _raw(self, t: float) -> Pose:
        """The pose at a time: keys, per-bone lag, then the procedural layers (no springs, no steps)."""
        pose = self._keyed(t)
        for bone, lag in self.lag.items():
            late = self._keyed(t - lag if self.loop else max(0.0, t - lag))
            if bone in late:
                pose[bone] = late[bone]
        for layer in self.layers:
            _apply_layer(pose, layer, t, self)
        return pose

    def sample(self, frame: int) -> Pose:
        """The pose at a frame: keys, per-bone lag, layers, follow springs, then the steps on twos."""
        t = self._stepped(frame / FPS)
        if self.follow:
            index = round(t * FPS)
            followed = self._springs()
            index = index % (len(followed) - 1) if self.loop else min(index, len(followed) - 1)
            pose = copy.deepcopy(followed[index])
        else:
            pose = self._raw(t)
        pose[PLANT] = {foot: self._planted(foot, t) for foot in FEET}
        return pose

    # LEARN: a damped spring, x'' = w²(target - x) - 2ζw·x', is what makes a limb follow through: while the keyed
    # pose moves, the spring trails it; when the pose stops, the spring's speed carries it past and it settles back.
    # w = 2π·hz sets how tightly it follows, ζ (damping) how much it overshoots (below 1 it does). It is stepped in
    # small sub-steps (semi-implicit Euler) so it stays stable at any frequency used here.
    def _springs(self) -> list[Pose]:
        """Every frame with the `follow` bones on their springs (a loop runs a lap first, so it closes)."""
        if self._followed is not None:
            return self._followed
        n = round(self.length * FPS) + 1
        laps = 2 if self.loop else 1
        state: dict[tuple[str, str], list[float]] = {}
        out: list[Pose] = []
        substeps = 8
        dt = 1.0 / FPS / substeps
        for lap in range(laps):
            for frame in range(n):
                pose = self._raw(frame / FPS)
                for bone, (hz, damping) in self.follow.items():
                    w = 2.0 * math.pi * hz
                    for param, target in pose.get(bone, {}).items():
                        x, v = state.setdefault((bone, param), [target, 0.0])
                        for _ in range(substeps):
                            v += (w * w * (target - x) - 2.0 * damping * w * v) * dt
                            x += v * dt
                        state[(bone, param)] = [x, v]
                        pose[bone][param] = x
                if lap == laps - 1:
                    out.append(pose)
        self._followed = out
        return out

    def _planted(self, foot: str, t: float) -> float:
        """How firmly a foot is held to the floor at `t`: 1 inside its windows, 0 outside, fading between."""
        windows = self.data.get("plant", {}).get(foot)
        if windows is None:
            return 1.0
        fade = float(self.data.get("plant_fade", 0.08))
        best = 0.0
        for a, b in windows:
            a, b = float(a), float(b)
            if a <= t <= b:
                edge_in = 1.0 if a <= 0.0 else min(1.0, (t - a) / fade)
                edge_out = 1.0 if b >= self.length else min(1.0, (b - t) / fade)
                best = max(best, min(edge_in, edge_out))
        return best


def _wave(t: float, period: float, phase: float = 0.0) -> float:
    return math.sin(2.0 * math.pi * (t / period + phase))


def _noise(t: float, seed: float) -> float:
    """A smooth deterministic wobble in -1..1 (sum of incommensurate sines; no RNG, same every build)."""
    return (math.sin(t * 37.1 + seed) + math.sin(t * 23.7 + seed * 2.3) * 0.6 + math.sin(t * 51.3 + seed * 0.7) * 0.3) / 1.9


def _window(layer: dict, t: float) -> float:
    """1 inside a layer's [from, to], easing in and out over `fade` seconds; 1 everywhere without a window."""
    if "from" not in layer:
        return 1.0
    a, b, fade = float(layer["from"]), float(layer["to"]), float(layer.get("fade", 0.08))
    if t < a or t > b:
        return 0.0
    return min(1.0, (t - a) / fade if fade > 0 else 1.0, (b - t) / fade if fade > 0 else 1.0)


def _add(pose: Pose, bone: str, param: str, value: float) -> None:
    pose.setdefault(bone, {})
    pose[bone][param] = pose[bone].get(param, 0.0) + value


def _apply_layer(pose: Pose, layer: dict, t: float, clip: Clip) -> None:
    kind = layer["kind"]
    w = _window(layer, t)
    if w == 0.0:
        return
    # A looping layer's period is fitted to the loop, so the wave closes where it began.
    period = float(layer.get("period", 2.0))
    if clip.loop:
        period = clip.length / max(1, round(clip.length / period))
    if kind == "breathe":
        amp = float(layer.get("amp", 2.0))
        _add(pose, "Chest", "bend", -amp * _wave(t, period) * w)
        for side in ("Left", "Right"):
            _add(pose, side + "Shoulder", "raise", amp * 0.8 * _wave(t, period) * w)
    elif kind == "bob":
        _add(pose, "Hips", "lift", float(layer.get("amp", 0.02)) * _wave(t, period, float(layer.get("phase", 0))) * w)
    elif kind == "sway":
        amp = float(layer.get("amp", 3.0))
        _add(pose, "Hips", "lean", amp * _wave(t, period, 0.25) * w)
        _add(pose, "Head", "lean", -amp * 0.6 * _wave(t, period, 0.1) * w)
    elif kind == "wave":
        # One parameter of one bone on its own slow wave (a lead hand that floats, fingers that breathe).
        amp = float(layer.get("amp", 3.0))
        for bone in [side + layer["bone"] for side in ("Left", "Right")] if layer["bone"] in SIDED else [layer["bone"]]:
            _add(pose, bone, layer["param"], amp * _wave(t, period, float(layer.get("phase", 0))) * w)
    elif kind == "tremble":
        amp = float(layer.get("amp", 2.0))
        bones = layer.get("bones", ["LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "Chest"])
        for i, bone in enumerate(bones):
            for j, param in enumerate(("bend", "turn", "raise") if "Arm" in bone else ("bend", "lean")):
                _add(pose, bone, param, amp * _noise(t, i * 3.1 + j * 1.7) * w)
    else:
        raise ValueError(f"unknown layer kind {kind!r}")


def load_library() -> dict[str, dict]:
    return json.loads((HERE / "poses.json").read_text())


def load_clip(clip_id: str, library: dict[str, dict] | None = None) -> Clip:
    data = json.loads((HERE / "clips" / f"{clip_id}.json").read_text())
    return Clip(clip_id, data, library if library is not None else load_library())


def clip_ids() -> list[str]:
    return sorted(p.stem for p in (HERE / "clips").glob("*.json"))
