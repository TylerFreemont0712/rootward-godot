"""The soundtrack manifest (soundtrack.json) and where the music pipeline keeps things (config.json).

The manifest is small and committed: for every slot (the file the game plays, `music-title`, `cue-victory`, ...) what it
is for, the prompt (style and lyrics), the duration cap, the takes made for it (seed, planner seed, tuning), which take
is chosen and where its loop runs. The takes themselves (flac, masters, plans) are heavy and live in `takes_dir`.

    slots.<slot>.takes.<take id> = {seed, abc_seed, [max_duration, style, lyrics, tune, note]}
                                 | {derived_from, trim: {seconds, fade}}     a cut of another take (a stinger)

A take's status is not stored: it is whatever is on disk (`has_raw`), so the queue is resumable by construction.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = Path(__file__).resolve().parent
MANIFEST = MUSIC / "soundtrack.json"
CONFIG = MUSIC / "config.json"
AUDIO = ROOT / "game" / "assets" / "audio"
LOOPS_JSON = AUDIO / "music.json"

# What a slot's kind is mastered to (LUFS integrated, true peak dBTP). Music sits under the sound effects; a cue is
# heard alone and briefly; a bonus track is listened to for itself.
TARGETS = {"loop": {"lufs": -20.0, "peak": -1.5}, "cue": {"lufs": -17.0, "peak": -2.5},
           "bonus": {"lufs": -16.0, "peak": -1.0}}

# Folders inside takes_dir, by kind of file.
KINDS = {"abc": "abc", "mastered": "mastered", "loops": "loops", "qc": "qc"}


def _resolve(path: str) -> Path:
    p = Path(path).expanduser()
    return p if p.is_absolute() else ROOT / p


def config() -> dict:
    cfg = json.loads(CONFIG.read_text())
    if os.environ.get("ROOTWARD_MUSIC_TAKES"):
        cfg["takes_dir"] = os.environ["ROOTWARD_MUSIC_TAKES"]
    if os.environ.get("ROOTWARD_COMFY_URL"):
        cfg["comfy_url"] = os.environ["ROOTWARD_COMFY_URL"]
    return cfg


def takes_dir() -> Path:
    return _resolve(config()["takes_dir"])


def read_dirs() -> list[Path]:
    return [takes_dir()] + [_resolve(p) for p in config().get("read_also", [])]


def where(kind: str, name: str) -> Path:
    """The path a file is written to in takes_dir. kind is "" (raw take, flac), abc, mastered (+ext in name), loops, qc."""
    folder = takes_dir() / KINDS[kind] if kind else takes_dir()
    return folder / name


def find(kind: str, name: str) -> Path | None:
    """The first existing file of that name in takes_dir, then in each read_also folder."""
    for base in read_dirs():
        path = (base / KINDS[kind] / name) if kind else (base / name)
        if path.exists():
            return path
    return None


def raw_name(take: str) -> str:
    return f"{take}.flac"


def has_raw(take: str) -> bool:
    return find("", raw_name(take)) is not None


def load() -> dict:
    return json.loads(MANIFEST.read_text())


def save(data: dict) -> None:
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")


def slots(data: dict | None = None) -> dict:
    return (data or load())["slots"]


def slot_of(take: str, data: dict | None = None) -> tuple[str, dict] | None:
    """(slot name, slot) of the slot that lists the take."""
    for name, slot in slots(data).items():
        if take in slot["takes"]:
            return name, slot
    return None


def spec(slot: dict, take: str) -> dict:
    """The take's full request: its own style, lyrics and cap, or the slot's."""
    entry = slot["takes"][take]
    return {"style": entry.get("style", slot["style"]), "lyrics": entry.get("lyrics", slot["lyrics"]),
            "max_duration": entry.get("max_duration", slot["max_duration"]), "seed": entry["seed"],
            "abc_seed": entry.get("abc_seed", slot.get("plan", {}).get("abc_seed", 10))}


def source_take(slot: dict, take: str) -> str:
    """The generated take a (possibly derived) take comes from."""
    return slot["takes"][take].get("derived_from", take)


def select(data: dict, names: list[str] | None) -> list[tuple[str, dict]]:
    """Slots by name; no names means every slot. An unknown name is an error."""
    everything = slots(data)
    if not names:
        return list(everything.items())
    unknown = [n for n in names if n not in everything]
    if unknown:
        raise SystemExit(f"unknown slot(s): {', '.join(unknown)}; the slots are: {', '.join(everything)}")
    return [(n, everything[n]) for n in names]


def validate(data: dict) -> list[str]:
    """Every problem with the manifest, or none."""
    problems = []
    for name, slot in slots(data).items():
        for field in ("kind", "style", "lyrics", "max_duration", "takes"):
            if field not in slot:
                problems.append(f"{name}: no {field}")
        if slot.get("kind") not in TARGETS:
            problems.append(f"{name}: kind {slot.get('kind')!r} is not one of {', '.join(TARGETS)}")
        takes = slot.get("takes", {})
        for take, entry in takes.items():
            if "derived_from" in entry:
                if entry["derived_from"] not in takes:
                    problems.append(f"{name}/{take}: derived from {entry['derived_from']}, which is not a take of the slot")
                if "trim" not in entry:
                    problems.append(f"{name}/{take}: a derived take needs a trim")
            elif "seed" not in entry:
                problems.append(f"{name}/{take}: no seed")
        chosen = slot.get("chosen")
        if chosen is not None and chosen not in takes:
            problems.append(f"{name}: chosen take {chosen} is not listed")
        if chosen and slot.get("kind") == "loop" and not slot.get("loop"):
            problems.append(f"{name}: a loop slot with a chosen take needs loop {{start, end}}")
        loop = slot.get("loop")
        if loop and not 0 <= loop["start"] < loop["end"]:
            problems.append(f"{name}: loop start must be before end")
    return problems
