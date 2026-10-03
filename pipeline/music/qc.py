#!/usr/bin/env python3
"""Measures a raw take, so a bad one is found before anyone listens (pipeline/music/README.md): length against the cap
(did it end by itself, or was it cut?), loudness and peak, silences and a dead tail, colour, and the planner's key,
tempo and form with the varispeed that would put the key in the home key.

    uv run --project pipeline python pipeline/music/qc.py <take|slot>... [--picture]

Writes takes_dir/qc/<take>.json (and <take>.png with --picture: envelope, spectrogram, chroma, self-similarity).
Measurements are not judgement: the numbers say what to listen to first, and a take that measures well can still be dull.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import manifest  # noqa: E402
import master  # noqa: E402
import plan as planner  # noqa: E402


def silences(path: Path, floor_db: int = -50, minimum: float = 2.0) -> list[tuple[float, float]]:
    text = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                           f"silencedetect=n={floor_db}dB:d={minimum}", "-f", "null", "-"],
                          capture_output=True, text=True).stderr
    starts = [float(s) for s in re.findall(r"silence_start: ([\d.]+)", text)]
    lengths = [float(s) for s in re.findall(r"silence_duration: ([\d.]+)", text)]
    return list(zip(starts, lengths))


def plan_of(slot: dict, take: str) -> dict | None:
    abc = manifest.find("abc", f"{manifest.source_take(slot, take)}.abc")
    if not abc:
        return None
    parsed = planner.parse(abc.read_text())
    parts = [p for p in planner.timeline(parsed) if p["name"] != "silence"]
    return {"key": parsed.key, "bpm": parsed.bpm, "metre": str(parsed.metre), "plan_seconds": parts[-1]["end"],
            "complete": parsed.complete, "sections": [(p["name"], p["bars"]) for p in parts]}


def qc(slot_name: str, slot: dict, take: str, picture: bool = False) -> dict:
    path = master.ensure_raw(slot, take)
    stereo, mono = analyze.load(path)
    seconds = len(stereo) / master.RATE
    spec = manifest.spec(slot, manifest.source_take(slot, take))
    tail = stereo[-3 * master.RATE:]
    report: dict = {"take": take, "slot": slot_name, "seconds": round(seconds, 1), **analyze.loudness(stereo),
                    "silences": silences(path), "tail3s_db": round(float(20 * np.log10(np.sqrt(np.mean(tail ** 2)) + 1e-9)), 1),
                    "cap": spec["max_duration"], "ran_to_cap": seconds >= spec["max_duration"] - 0.5,
                    "colour": analyze.colour(stereo, mono)}
    found = plan_of(slot, take)
    if found:
        report["plan"] = found
        wanted = slot.get("plan", {}).get("keys")
        if wanted and found["key"] not in wanted:
            fix = planner.semitone_fix(found["key"], wanted)
            report["plan"]["suggested_tune"] = fix  # None: not fixable by a semitone
    if picture:
        out = manifest.where("qc", "pic")
        analyze.analyze(path, found["bpm"] if found else None, None, out)
    manifest.where("qc", f"{take}.json").parent.mkdir(parents=True, exist_ok=True)
    manifest.where("qc", f"{take}.json").write_text(json.dumps(report, indent=1) + "\n")
    return report


def summary(report: dict) -> str:
    plan = report.get("plan", {})
    ending = "ran to the cap (ending cut)" if report["ran_to_cap"] else f"ended by itself (tail {report['tail3s_db']:.0f} dB)"
    notes = f"plan {plan['key']} {plan['bpm']:g} bpm" if plan else "no plan on disk"
    if plan.get("suggested_tune"):
        notes += f", suggested tune {plan['suggested_tune']:+d}"
    flag = " SILENCE" if report["silences"] else ""
    return (f"{report['take']:36s} {report['seconds']:6.1f}s {report['lufs']:6.1f} LUFS {report['true_peak']:5.1f} dBTP "
            f"LRA {report['lra']:4.1f}  {ending}; {notes}{flag}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="+", help="takes, or slots (all their generated takes)")
    parser.add_argument("--picture", action="store_true")
    args = parser.parse_args()
    data = manifest.load()
    for name in args.names:
        if name in manifest.slots(data):
            slot = manifest.slots(data)[name]
            takes = [t for t in slot["takes"] if manifest.has_raw(manifest.source_take(slot, t))]
        else:
            found = manifest.slot_of(name, data)
            if not found:
                sys.exit(f"{name}: neither a slot nor a take in soundtrack.json")
            name, slot, takes = found[0], found[1], [name]
        for take in takes:
            print(summary(qc(name, slot, take, args.picture)), flush=True)


if __name__ == "__main__":
    main()
