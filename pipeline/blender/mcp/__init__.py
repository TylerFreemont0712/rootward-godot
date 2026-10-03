"""Rootward's live-Blender toolkit: plain Python for `execute_blender_code` (Blender MCP), see README.md here.

    import sys; sys.path.insert(0, "/home/joejin/personal-project/Rootward/pipeline/blender")
    import mcp; mcp.reload()                    # (re)load every module after an edit
    from mcp import rig, actions, events, bake, facts, validate, review, export, inspect_scene

Nothing here assumes `--factory-startup`, a closed GUI or an empty file: the tools work in their own scene
(`RW_Author`) and leave the player's scenes alone. Every function returns plain data (dicts, lists, strings) and
prints a one-line summary, so the MCP reply says what happened.
"""

from __future__ import annotations

import importlib

MODULES = ("common", "inspect_scene", "rig", "actions", "events", "bake", "facts", "validate", "review", "export")


def reload() -> None:
    """Reloads every module in dependency order (a live Blender keeps old code until told)."""
    import sys

    for name in MODULES:
        full = f"{__name__}.{name}"
        if full in sys.modules:
            importlib.reload(sys.modules[full])
        else:
            importlib.import_module(full)


def __getattr__(name: str):  # `mcp.rig` works without importing it first
    if name in MODULES:
        return importlib.import_module(f"{__name__}.{name}")
    raise AttributeError(name)
