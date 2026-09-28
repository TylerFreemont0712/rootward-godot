#!/usr/bin/env python3
"""Performs a track's score (pipeline/music/README.md): the composition is ours, the performance is a model's.

  YuE2 (yue2.cpp, CUDA) plays the ABC score exactly as written, melody and chords, in the style the brief describes;
  every take keeps its seeds and its semantic stream, so a take can be rendered again with other acoustic noise.

Takes are cached under pipeline/cache/music/<track>/ with the request that made them; a take already there is not
rendered again. The GPU holds one model at a time: this refuses to start while ComfyUI or Blender is up.

    uv run --project pipeline python pipeline/music/perform.py <track> [--takes 3] [--seed 1000] [--steps 48]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRACKS = Path(__file__).with_name("tracks")
CACHE = ROOT / "pipeline" / "cache" / "music"
YUE2 = Path(os.environ.get("YUE2_DIR", Path.home() / "personal-project" / "yue2.cpp"))

sys.path.insert(0, str(Path(__file__).parent))
import notation  # noqa: E402


def brief_of(track: str) -> dict:
    return json.loads((TRACKS / track / "brief.json").read_text())


def gpu_free() -> None:
    """ComfyUI and Blender each want the whole 8 GB; so does YuE2."""
    try:
        urllib.request.urlopen("http://127.0.0.1:8188/system_stats", timeout=2)
        sys.exit("ComfyUI is running: stop it first (the GPU holds one model at a time).")
    except OSError:
        pass
    if subprocess.run(["pgrep", "-f", "/blender-[0-9.]+/blender( |$)"], capture_output=True).returncode == 0:
        sys.exit("Blender is running: close it first (the GPU holds one model at a time).")


def yue2_request(brief: dict, score_text: str, lm_seed: int, seed: int, steps: int) -> dict:
    parsed = notation.parse(score_text)
    seconds = sum(part["bars"] for part in notation.timeline(parsed)) * parsed.bar_seconds
    return {
        "style": brief["style"],
        # An instrumental has no words to sing, and its score's Vocal voice rests under its chords; a song's lyrics
        # are its sung sections in order, one syllable to each note the Vocal voice sings (`notation.py sung`).
        "lyrics": brief.get("lyrics", ""),
        "abc": notation.canonical(score_text),
        "cot": "full",
        "duration": round(seconds + 8.0, 1),
        "lm_seed": lm_seed,
        "seed": seed,
        "steps": steps,
        "cfg_scale": brief.get("yue2", {}).get("cfg_scale", -1.0),
        "output_format": "wav32",
        "semantic_sampling": {**{"temperature": 1.0, "top_p": 0.95, "top_k": 100, "repetition_penalty": 1.2,
                                 "penalty_window": 50, "min_tokens": 200, "max_tokens": 9000},
                              **brief.get("yue2", {}).get("semantic_sampling", {})},
    }


def context_for(request: dict) -> int:
    """The KV cache a request needs, rounded up to 1024 and capped at the model's 24576: the prompt (at a generous two
    characters a token) plus the song's frames twice over, since the flow matching stage lays its latent block beside
    the codes in the same cache and a song that does not fit is painted in chunks."""
    prompt = (len(request["style"]) + len(request["lyrics"]) + len(request["abc"])) // 2 + 256
    frames = int(request["duration"] * 25)
    return min(24576, -(-(prompt + 2 * frames + 64) // 1024) * 1024)


def perform_yue2(track: str, takes: int, first_seed: int, steps: int) -> list[Path]:
    brief = brief_of(track)
    score_text = (TRACKS / track / "score.abc").read_text()
    problems = notation.check(notation.parse(score_text))
    if problems:
        sys.exit(f"{track}: the score is broken:\n  " + "\n  ".join(problems))
    folder = CACHE / track
    folder.mkdir(parents=True, exist_ok=True)
    done = []
    for index in range(takes):
        lm_seed, seed = first_seed + index, first_seed + 100 + index
        request = yue2_request(brief, score_text, lm_seed, seed, steps)
        # The name carries the seeds and a digest of what was asked, so a revised score or style is a new take and
        # the earlier ones stay to be compared with.
        digest = hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()[:6]
        name = f"yue2-{lm_seed}-{seed}-s{steps}-{digest}"
        audio = folder / f"{name}.wav"
        request_path = folder / f"{name}.request.json"
        if audio.exists():
            print(f"  cached {audio.name}")
            done.append(audio)
            continue
        gpu_free()
        request_path.write_text(json.dumps(request, indent=2) + "\n")
        print(f"  perform {track} with YuE2 (lm seed {lm_seed}, seed {seed}, {steps} steps)", flush=True)
        started = time.monotonic()
        result = subprocess.run(
            [str(YUE2 / "build" / "yue-synth"), "--model", str(YUE2 / "models" / "YuE2-3B-Q8_0.gguf"),
             "--vae", str(YUE2 / "models" / "YuE2-Vae-F32.gguf"), "--request", str(request_path),
             "--out", str(audio), "--tokens", str(folder / f"{name}.tokens.csv"),
             "--score", str(folder / f"{name}.score.abc"), "--max-seq", str(context_for(request))],
            capture_output=True, text=True)
        took = time.monotonic() - started
        (folder / f"{name}.log").write_text(result.stdout + result.stderr)
        if result.returncode != 0 or not audio.exists():
            sys.exit(f"yue-synth failed ({result.returncode}); see {folder / f'{name}.log'}:\n{result.stderr[-1500:]}")
        print(f"    took {took:.0f}s -> {audio.relative_to(ROOT)}", flush=True)
        done.append(audio)
    return done


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("track")
    parser.add_argument("--takes", type=int, default=1)
    parser.add_argument("--seed", type=int, default=1000)
    parser.add_argument("--steps", type=int, default=32)
    args = parser.parse_args()
    perform_yue2(args.track, args.takes, args.seed, args.steps)


if __name__ == "__main__":
    main()
