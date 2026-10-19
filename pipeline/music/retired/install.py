#!/usr/bin/env python3
"""Puts the chosen takes into the game: game/assets/audio/<slot>.ogg and, for a loop, its entry in music.json.

Each slot's chosen take and loop come from soundtrack.json; the audio is built from the take's master by
`master.render` (leading silence trimmed, cut at the loop's end, 0.15 s crossfade into the loop's start, levelled to
the kind's target, Vorbis). Slots not named by --only are left alone.

    uv run --project pipeline python pipeline/music/install.py [--only slot,slot] [--dry-run] [--dest DIR]
    # swap a slot to another take (and remember it in soundtrack.json):
    uv run --project pipeline python pipeline/music/install.py --only music-ring2 --take ring2-map-b-s9111 [--cand 2]
    uv run --project pipeline python pipeline/music/install.py --only music-ring2 --take ring2-map-b-s9111 --loop 110.2 150.0

For a loop, a swap takes the Nth candidate (default the first) of takes_dir/loops/<take>.json, which `music.sh loops
<take>` writes, or an exact `--loop START END` in the master's seconds. `--dest` writes somewhere other than the game
(a scratch folder, to compare without touching the game's files).
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import manifest  # noqa: E402
import master  # noqa: E402


def swap(slot_name: str, slot: dict, take: str, cand: int, loop: tuple[float, float] | None) -> None:
    """Make `take` the slot's chosen take, with its loop (in place; the caller saves the manifest)."""
    if take not in slot["takes"]:
        raise SystemExit(f"{take} is not a take of {slot_name} ({', '.join(slot['takes'])}); add it under the slot's takes")
    slot["chosen"] = take
    if slot["kind"] != "loop":
        slot["loop"] = None
        return
    if loop:
        slot["loop"] = {"start": loop[0], "end": loop[1]}
        return
    report = manifest.find("loops", f"{take}.json")
    if not report:
        raise SystemExit(f"{take}: no loop candidates yet; run music.sh loops {take}, or pass --loop START END")
    candidates = json.loads(report.read_text())["candidates"]
    if not 1 <= cand <= len(candidates):
        raise SystemExit(f"{take}: --cand {cand}, but it has {len(candidates)} candidate loops")
    slot["loop"] = {"start": candidates[cand - 1]["start"], "end": candidates[cand - 1]["end"]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma-separated slots to install (the others are left alone)")
    parser.add_argument("--take", help="with --only <one slot>: install and remember this take instead")
    parser.add_argument("--cand", type=int, default=1)
    parser.add_argument("--loop", nargs=2, type=float, metavar=("START", "END"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--dest", type=Path, help="write here instead of game/assets/audio")
    args = parser.parse_args()
    data = manifest.load()
    only = args.only.split(",") if args.only else None
    chosen = [(n, s) for n, s in manifest.select(data, only) if s.get("game", True) and (s.get("chosen") or args.take)]
    if args.take:
        if not only or len(only) != 1:
            sys.exit("--take needs --only <one slot>")
        swap(chosen[0][0], chosen[0][1], args.take, args.cand, tuple(args.loop) if args.loop else None)
    dest = args.dest or manifest.AUDIO
    loops_file = dest / "music.json"
    if args.dest and not loops_file.exists() and manifest.LOOPS_JSON.exists():
        args.dest.mkdir(parents=True, exist_ok=True)
        shutil.copy(manifest.LOOPS_JSON, loops_file)
    loops = json.loads(loops_file.read_text()) if loops_file.exists() else {}
    for name, slot in chosen:
        if not slot.get("chosen"):
            continue
        take, loop = slot["chosen"], slot.get("loop")
        piece, found = master.render(slot, take, loop["start"] if loop else None, loop["end"] if loop else None)
        measured = analyze.loudness(piece)
        print(f"{name:22s} <- {take:30s} {len(piece) / master.RATE:6.1f}s {measured['lufs']:6.1f} LUFS "
              f"{measured['true_peak']:5.1f} dBTP  {found}", flush=True)
        if args.dry_run:
            continue
        master.encode(piece, dest / f"{name}.ogg")
        if found:
            loops[name] = {"loopStart": found["loopStart"], "loopEnd": found["loopEnd"]}
    if not args.dry_run:
        loops_file.write_text(json.dumps(dict(sorted(loops.items())), indent=2) + "\n")
        if args.take:
            manifest.save(data)
            print(f"soundtrack.json: {chosen[0][0]} now plays {args.take}")


if __name__ == "__main__":
    main()
