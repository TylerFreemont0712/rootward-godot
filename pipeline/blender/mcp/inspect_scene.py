"""Look before touching: what is in this Blender session."""

from __future__ import annotations

import bpy

from . import common
from .common import say


def report() -> dict:
    """Scenes, armatures, actions and whether the open file has unsaved work. Read-only."""
    out = {
        "blender": bpy.app.version_string,
        "file": bpy.data.filepath or "(unsaved)",
        "dirty": bpy.data.is_dirty,
        "background": bpy.app.background,
        "active_scene": bpy.context.scene.name,
        "scenes": [
            {"name": s.name, "objects": len(s.objects), "fps": s.render.fps / s.render.fps_base} for s in bpy.data.scenes
        ],
        "armatures": [
            {"object": o.name, "bones": len(o.data.bones), "action": o.animation_data.action.name if o.animation_data and o.animation_data.action else None}
            for o in bpy.data.objects
            if o.type == "ARMATURE"
        ],
        "actions": [
            {"name": a.name, "frames": [round(a.frame_range[0]), round(a.frame_range[1])], "fake_user": a.use_fake_user, "users": a.users}
            for a in bpy.data.actions
        ],
        "extensions": {
            "vrm": hasattr(bpy.ops.import_scene, "vrm"),
            "vrma": hasattr(bpy.ops.import_scene, "vrma"),
            "rigify": "rigify" in bpy.context.preferences.addons,
        },
        "author_scene": common.SCENE in bpy.data.scenes,
    }
    say(f"{out['blender']} | {out['file']} | dirty={out['dirty']} | scenes={[s['name'] for s in out['scenes']]} | actions={len(out['actions'])}")
    return out


def save_copy(name: str = "rw-backup") -> str:
    """Writes a copy of the open session next to the scratch files (never over the player's file) and returns the path."""
    import tempfile
    from pathlib import Path

    path = Path(tempfile.gettempdir()) / f"{name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(path), copy=True)
    say(f"saved a copy to {path}")
    return str(path)
