"""Game events as the action's own pose markers (Dopesheet / Timeline: Marker menu, M to add, F2 to rename), so a
hand-keyed clip carries `release`, `charge` and `face` without any JSON.

  release                  the frame the palm goes through the sigil (casts; needs rw_hand on the action)
  charge  /  charge_end    the coil the game may slow to wait for a long circle: a marker pair (or one `charge`
                           marker alone = from the start of the clip to it)
  face:happy               the VRM expression `happy` at this frame, weight 1
  face:angry:0.7           ... at weight 0.7        (any VRM expression: happy angry sad surprised relaxed blink ...)

Marker frames are on the action's own timeline (frame 0 = start of the clip). 30 frames = 1 second.
"""

from __future__ import annotations

import bpy

from . import common


def add(action: bpy.types.Action, name: str, frame: int) -> bpy.types.TimelineMarker:
    """Adds (or moves) the marker `name` at `frame`. `release` and `charge*` are unique; `face:*` may repeat."""
    unique = not name.startswith("face:")
    if unique:
        for marker in action.pose_markers:
            if marker.name == name:
                marker.frame = int(frame)
                return marker
    marker = action.pose_markers.new(name)
    marker.frame = int(frame)
    return marker


def remove(action: bpy.types.Action, name: str) -> int:
    gone = 0
    for marker in [m for m in action.pose_markers if m.name == name]:
        action.pose_markers.remove(marker)
        gone += 1
    return gone


def clear(action: bpy.types.Action) -> None:
    for marker in list(action.pose_markers):
        action.pose_markers.remove(marker)


def read(action: bpy.types.Action) -> dict:
    """The markers as the game's facts: {"release": s, "charge": [from, to] | s, "face": [{"t","expression","weight"}]}
    in seconds. Unknown marker names are returned under "unknown" so validate can warn."""
    fps = common.FPS
    events: dict = {"face": [], "unknown": []}
    charge_end = None
    for marker in sorted(action.pose_markers, key=lambda m: m.frame):
        t = round(marker.frame / fps, 4)
        name = marker.name.strip()
        if name == "release":
            events["release"] = t
        elif name == "charge":
            events["charge"] = t
        elif name == "charge_end":
            charge_end = t
        elif name.startswith("face:"):
            parts = name.split(":")
            weight = float(parts[2]) if len(parts) > 2 else 1.0
            events["face"].append({"t": t, "expression": parts[1], "weight": weight})
        else:
            events["unknown"].append(name)
    if charge_end is not None:
        start = events["charge"] if isinstance(events.get("charge"), float) else 0.0
        events["charge"] = [start, charge_end]
    return events
