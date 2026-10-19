#!/usr/bin/env python3
"""The music pipeline's catalogue (pipeline/music/README.md): where things are on disk, what a track's brief says, how a
take is named and found in the cache, and what a package of tracks is.

Deliberately light (json, hashlib, pathlib only): the package listing and the tests import it without librosa.

    uv run --project pipeline python pipeline/music/library.py [<package>]     # lists the tracks and what is missing
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

MUSIC = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[2]
TRACKS = MUSIC / "tracks"
PACKAGES = MUSIC / "packages"
CONFIG = MUSIC / "config.json"
AUDIO = ROOT / "game" / "assets" / "audio"  # the game's music files, and music.json with their loops
ID = re.compile(r"[a-z0-9][a-z0-9-]*")
KINDS = ("loop", "cue", "bonus")


class TrackError(ValueError):
    """A track that cannot be performed as it is: missing, or with a brief that is wrong."""


class PackageError(ValueError):
    """A package file that cannot be read or is malformed."""


def config() -> dict:
    """config.json, with the environment's overrides: ROOTWARD_MUSIC_TAKES (takes_dir), ROOTWARD_COMFY_URL, YUE2_DIR."""
    cfg = json.loads(CONFIG.read_text())
    if os.environ.get("ROOTWARD_MUSIC_TAKES"):
        cfg["takes_dir"] = os.environ["ROOTWARD_MUSIC_TAKES"]
    if os.environ.get("ROOTWARD_COMFY_URL"):
        cfg["comfy_url"] = os.environ["ROOTWARD_COMFY_URL"]
    if os.environ.get("YUE2_DIR"):
        cfg["yue2_dir"] = os.environ["YUE2_DIR"]
    return cfg


def resolve(path: str) -> Path:
    """A path from config.json: absolute, `~`, or relative to the repository root."""
    p = Path(path).expanduser()
    return p if p.is_absolute() else ROOT / p


def takes_dir() -> Path:
    return resolve(config()["takes_dir"])


def check_id(track: str) -> str:
    if not ID.fullmatch(track):
        raise TrackError(f"{track!r} is not a track id (lower case, digits and dashes, like 'battle-heap')")
    return track


def track_dir(track: str) -> Path:
    return TRACKS / check_id(track)


def track_exists(track: str) -> bool:
    return (track_dir(track) / "brief.json").exists()


def track_ids() -> list[str]:
    """Every track that has a brief, in order."""
    return sorted(path.name for path in TRACKS.iterdir() if (path / "brief.json").exists()) if TRACKS.exists() else []


def brief(track: str) -> dict:
    """A track's brief. A missing track is a TrackError that says so; a brief that is not an object is too."""
    path = track_dir(track) / "brief.json"
    if not path.exists():
        raise TrackError(f"missing track {track!r}: tracks/{track}/brief.json does not exist yet")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise TrackError(f"{track}: brief.json is not JSON ({error})") from error
    if not isinstance(data, dict):
        raise TrackError(f"{track}: brief.json must be an object")
    return data


def brief_problems(track: str, data: dict) -> list[str]:
    """What a brief must say before a take is made of it (fields the perform and master steps read)."""
    problems = []
    for field in ("id", "out", "style", "bpm", "key"):
        if field not in data:
            problems.append(f"no {field!r}")
    if data.get("id", track) != track:
        problems.append(f"id {data.get('id')!r} is not its folder {track!r}")
    if data.get("kind", "loop") not in KINDS:
        problems.append(f"kind {data.get('kind')!r} is not one of {', '.join(KINDS)}")
    if data.get("kind", "loop") == "loop" and not isinstance(data.get("loop"), dict):
        problems.append("a loop needs 'loop': {from, to, occurrence}")
    return problems


def score_text(track: str) -> str:
    path = track_dir(track) / "score.abc"
    if not path.exists():
        raise TrackError(f"missing track {track!r}: tracks/{track}/score.abc does not exist yet")
    return path.read_text()


# --- takes ---------------------------------------------------------------------------------------------------------

def digest(request: dict) -> str:
    """Six hex digits of the request a take was made from: a revised score, style or setting is a new take."""
    return hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()[:6]


def take_name(engine: str, lm_seed: int, seed: int, steps: int, request: dict) -> str:
    """yue2-<lm seed>-<seed>-s<steps>-<digest> for the native engine (the names the cache already has), and
    yue2-comfy-... for ComfyUI, whose weights and sampler differ, so its takes are never mistaken for the native ones."""
    prefix = "yue2" if engine == "native" else f"yue2-{engine}"
    return f"{prefix}-{lm_seed}-{seed}-s{steps}-{digest(request)}"


def track_takes_dir(track: str) -> Path:
    return takes_dir() / check_id(track)


def takes(track: str) -> list[str]:
    """The names of a track's finished takes (their .wav), oldest name order. A partial file is not a take."""
    folder = track_takes_dir(track)
    if not folder.exists():
        return []
    return sorted(path.stem for path in folder.glob("yue2*.wav") if ".partial" not in path.name)


def find_take(track: str, name: str) -> Path | None:
    path = track_takes_dir(track) / f"{name}.wav"
    return path if path.exists() else None


# --- packages ------------------------------------------------------------------------------------------------------

@dataclass(frozen=True)
class Package:
    """A list of tracks made together. `tracks` may name ids whose folders are not there yet (`missing`)."""
    name: str
    title: str
    concept: str
    tracks: tuple[str, ...]

    @property
    def present(self) -> list[str]:
        return [track for track in self.tracks if track_exists(track)]

    @property
    def missing(self) -> list[str]:
        return [track for track in self.tracks if not track_exists(track)]

    @property
    def concept_path(self) -> Path | None:
        return resolve(self.concept) if self.concept else None


def package_names() -> list[str]:
    return sorted(path.stem for path in PACKAGES.glob("*.json")) if PACKAGES.exists() else []


def load_package(name: str) -> Package:
    """packages/<name>.json, validated: a name matching the file, a title, and a non-empty list of distinct track ids.
    Ids without a folder yet are kept (listed as missing), so a package can be written before its tracks are."""
    path = PACKAGES / f"{name}.json"
    if not path.exists():
        known = ", ".join(package_names()) or "none yet"
        raise PackageError(f"no package {name!r} ({path.name} does not exist; packages: {known})")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise PackageError(f"{path.name} is not JSON: {error}") from error
    if not isinstance(data, dict):
        raise PackageError(f"{path.name} must be an object")
    if data.get("name", name) != name:
        raise PackageError(f"{path.name} says its name is {data.get('name')!r}; the file name is {name!r}")
    if not isinstance(data.get("title"), str) or not data["title"].strip():
        raise PackageError(f"{path.name} needs a title")
    tracks = data.get("tracks")
    if not isinstance(tracks, list) or not tracks or not all(isinstance(t, str) for t in tracks):
        raise PackageError(f"{path.name} needs 'tracks': a non-empty list of track ids")
    for track in tracks:
        if not ID.fullmatch(track):
            raise PackageError(f"{path.name}: {track!r} is not a track id")
    if len(set(tracks)) != len(tracks):
        duplicates = sorted({t for t in tracks if tracks.count(t) > 1})
        raise PackageError(f"{path.name} lists {', '.join(duplicates)} twice")
    concept = data.get("concept", "")
    if not isinstance(concept, str):
        raise PackageError(f"{path.name}: 'concept' is a path to the concept doc")
    return Package(name, data["title"], concept, tuple(tracks))


def main() -> None:
    names = sys.argv[1:] or package_names()
    for name in names:
        try:
            package = load_package(name)
        except PackageError as error:
            sys.exit(str(error))
        print(f"{package.name}: {package.title} ({len(package.tracks)} tracks)")
        if package.concept_path and not package.concept_path.exists():
            print(f"  concept doc not found: {package.concept}")
        for track in package.tracks:
            if track_exists(track):
                print(f"  {track}: {len(takes(track))} takes")
            else:
                print(f"  {track}: missing track (no tracks/{track}/brief.json yet)")


if __name__ == "__main__":
    main()
