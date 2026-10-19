#!/usr/bin/env python3
"""Performs a track's score (pipeline/music/README.md): the composition is ours, the performance is a model's.

Two engines play the same score with the same model family (YuE2), and their takes are named and cached the same way:

  comfy   the yue2_MusicGen workflow through ComfyUI's HTTP API (comfy.py), the score as its music node's input.
          The default while ComfyUI is up.
  native  yue2.cpp's yue-synth from the GGUF weights (YUE2_DIR). The default while ComfyUI is down.

The weights and the sampler differ between the two, so a ComfyUI take is named yue2-comfy-... and never mistaken for a
native one. Every take keeps its request (yue2-*.request.json), its log and its result (.result.json: how long it took,
how many times faster than real time, the peak GPU memory). A take already in the cache is never rendered again. The GPU holds one
model at a time: a take is made only while ComfyUI and Blender are in the state its engine needs, and one perform run
at a time (a lock in the takes folder).

    uv run --project pipeline python pipeline/music/perform.py <track>... [--takes 3] [--seed 1000] [--steps 32]
        [--engine auto|comfy|native] [--max-seconds 30]
    uv run --project pipeline python pipeline/music/perform.py --package menu-and-lanternroot --takes 2

--max-seconds caps a take (a smoke take: `--max-seconds 30`). A package performs its tracks one after another, skips
the takes already rendered, and goes on past a track that fails; the summary at the end says what happened.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

import soundfile

MUSIC = Path(__file__).resolve().parent
sys.path.insert(0, str(MUSIC))
import comfy  # noqa: E402
import library  # noqa: E402
import notation  # noqa: E402

TAIL_SECONDS = 8.0  # a take runs the score's length and this much more (the native engine's own default)
# The semantic sampling yue2.cpp uses unless a brief says otherwise. ComfyUI's music node takes the first four.
SEMANTIC = {"temperature": 1.0, "top_p": 0.95, "top_k": 100, "repetition_penalty": 1.2, "penalty_window": 50,
            "min_tokens": 200, "max_tokens": 9000}
COMFY_DOWN = ("ComfyUI is not up at {url}. Start it (scripts/gpu-guard.sh has comfy_start), or perform with "
              "--engine native while it is stopped.")


class EngineError(RuntimeError):
    """A take the engine could not make, with what it said."""


# --- requests ------------------------------------------------------------------------------------------------------

def sampling_of(brief: dict) -> dict:
    return {**SEMANTIC, **brief.get("yue2", {}).get("semantic_sampling", {})}


def duration_of(score_text: str, cap: float | None) -> float:
    """The score's length plus a tail, capped by --max-seconds."""
    parsed = notation.parse(score_text)
    seconds = sum(part["bars"] for part in notation.timeline(parsed)) * parsed.bar_seconds
    duration = round(seconds + TAIL_SECONDS, 1)
    return round(min(duration, cap), 1) if cap else duration


def yue2_request(brief: dict, score_text: str, lm_seed: int, seed: int, steps: int, cap: float | None = None) -> dict:
    """The native engine's request, as yue-synth reads it. Its digest names the take, so the keys stay as they are."""
    return {
        "style": brief["style"],
        # An instrumental has no words to sing; a song's lyrics are its sung sections in order.
        "lyrics": brief.get("lyrics", ""),
        "abc": notation.canonical(score_text),
        "cot": "full",
        "duration": duration_of(score_text, cap),
        "lm_seed": lm_seed,
        "seed": seed,
        "steps": steps,
        "cfg_scale": brief.get("yue2", {}).get("cfg_scale", -1.0),
        "output_format": "wav32",
        "semantic_sampling": sampling_of(brief),
    }


def comfy_request(workflow: comfy.Workflow, brief: dict, score_text: str, lm_seed: int, seed: int, steps: int,
                  cap: float | None = None) -> dict:
    """The ComfyUI engine's request: the prompt it sends, with the brief's values beside it, so the digest covers all."""
    sampling = sampling_of(brief)
    cfg = brief.get("yue2", {}).get("cfg_scale", -1.0)
    # yue2.cpp's -1 is its protocol default, 1.0 in full mode; ComfyUI's music node is 1.0 with no guidance.
    cfg = cfg if cfg >= 0 else 1.0
    style, lyrics, abc = brief["style"], brief.get("lyrics", ""), notation.canonical(score_text)
    duration = duration_of(score_text, cap)
    prompt = workflow.prompt(style, lyrics, abc, lm_seed, seed, steps, duration, cfg, sampling)
    return {"engine": "comfy", "style": style, "lyrics": lyrics, "abc": abc, "lm_seed": lm_seed, "seed": seed,
            "steps": steps, "duration": duration, "cfg_scale": cfg, "semantic_sampling": sampling, "prompt": prompt}


def context_for(request: dict) -> int:
    """The KV cache the native engine needs, rounded up to 1024 and capped at the model's 24576: the prompt (at a
    generous two characters a token) plus the song's frames twice over, since the flow matching stage lays its latent
    block beside the codes in the same cache."""
    prompt = (len(request["style"]) + len(request["lyrics"]) + len(request["abc"])) // 2 + 256
    frames = int(request["duration"] * 25)
    return min(24576, -(-(prompt + 2 * frames + 64) // 1024) * 1024)


# --- the GPU -------------------------------------------------------------------------------------------------------

def blender_running() -> bool:
    for args in (["pgrep", "-x", "blender"], ["pgrep", "-f", "[/]blender-[0-9.]+/blender( |$)"]):
        try:
            if subprocess.run(args, capture_output=True).returncode == 0:
                return True
        except OSError:
            return False
    return False


def gpu_guard(engine: str) -> None:
    """The GPU holds one model: ComfyUI and Blender each want the whole 8 GB, and so does YuE2."""
    if blender_running():
        sys.exit("Blender is running: close it first (the GPU holds one model at a time).")
    up = comfy.is_up()
    if engine == "comfy" and not up:
        sys.exit(COMFY_DOWN.format(url=library.config()["comfy_url"]))
    if engine == "native" and up:
        sys.exit("ComfyUI is running: stop it first (the GPU holds one model at a time), or use --engine comfy.")


class VRAMWatch:
    """The NVIDIA card's memory in use while a job runs, sampled once a second: the peak goes into the take's result."""

    def __init__(self, every: float = 1.0):
        self.every = every
        self.peak = -1
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def _run(self) -> None:
        while not self._stop.is_set():
            self.peak = max(self.peak, comfy.vram_mib())
            self._stop.wait(self.every)

    def __enter__(self) -> VRAMWatch:
        self._thread.start()
        return self

    def __exit__(self, *exc: object) -> None:
        self._stop.set()
        self._thread.join(timeout=5)


class Lock:
    """One perform run at a time: two would both see the GPU free and load two models into it."""

    def __init__(self) -> None:
        self.path = library.takes_dir() / ".perform.lock"

    def __enter__(self) -> Lock:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = self.path.open("w")
        try:
            fcntl.flock(self.handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit(f"another perform.py is running ({self.path}): one GPU job at a time; wait for it to finish")
        return self

    def __exit__(self, *exc: object) -> None:
        fcntl.flock(self.handle, fcntl.LOCK_UN)
        self.handle.close()


# --- the engines ---------------------------------------------------------------------------------------------------

def yue2_dir() -> Path:
    return Path(library.config()["yue2_dir"]).expanduser()


def render_native(request: dict, request_path: Path, folder: Path, name: str, partial: Path) -> str:
    """yue-synth from yue2.cpp; returns its log."""
    base = yue2_dir()
    binary, model, vae = base / "build" / "yue-synth", base / "models" / "YuE2-3B-Q8_0.gguf", base / "models" / "YuE2-Vae-F32.gguf"
    for needed in (binary, model, vae):
        if not needed.exists():
            raise EngineError(f"the native engine needs {needed}: build yue2.cpp (its buildcuda.sh) and fetch the "
                              "models (scripts/fetch-music-models.sh yue2), or set YUE2_DIR")
    result = subprocess.run(
        [str(binary), "--model", str(model), "--vae", str(vae), "--request", str(request_path), "--out", str(partial),
         "--tokens", str(folder / f"{name}.tokens.csv"), "--score", str(folder / f"{name}.score.abc"),
         "--max-seq", str(context_for(request))],
        capture_output=True, text=True)
    log = result.stdout + result.stderr
    if result.returncode != 0 or not partial.exists():
        raise EngineError(f"yue-synth failed ({result.returncode}); its last lines:\n{result.stderr[-1500:]}")
    return log


def render_comfy(workflow: comfy.Workflow, request: dict, partial: Path) -> str:
    """The workflow through ComfyUI; returns the job's history entry as its log."""
    problems = comfy.check_nodes(request["prompt"])
    if problems:
        raise EngineError("ComfyUI cannot run the workflow as the pipeline builds it:\n  " + "\n  ".join(problems))
    prompt_id = comfy.submit(request["prompt"])
    print(f"    queued in ComfyUI as {prompt_id}", flush=True)
    entry = comfy.wait(prompt_id, timeout=max(600.0, 30.0 * request["duration"]))
    comfy.fetch_audio(entry, workflow.output_id, partial)
    return json.dumps({"prompt_id": prompt_id, "status": entry.get("status", {})}, indent=1, default=str) + "\n"


def shown(path: Path) -> str:
    try:
        return str(path.relative_to(library.ROOT))
    except ValueError:
        return str(path)


def perform_take(engine: str, track: str, brief: dict, score_text: str, lm_seed: int, seed: int, steps: int,
                 cap: float | None, workflow: comfy.Workflow | None) -> tuple[Path, bool]:
    """One take: from the cache when it is there, otherwise rendered and measured. Returns (its wav, made now)."""
    if engine == "native":
        request = yue2_request(brief, score_text, lm_seed, seed, steps, cap)
    else:
        request = comfy_request(workflow, brief, score_text, lm_seed, seed, steps, cap)
    name = library.take_name(engine, lm_seed, seed, steps, request)
    folder = library.track_takes_dir(track)
    audio = folder / f"{name}.wav"
    if audio.exists():
        print(f"  cached {name}.wav", flush=True)
        return audio, False
    gpu_guard(engine)
    folder.mkdir(parents=True, exist_ok=True)
    request_path = folder / f"{name}.request.json"
    request_path.write_text(json.dumps(request, indent=2) + "\n")
    partial = folder / f"{name}.partial.wav"
    print(f"  perform {track} with {engine} (lm seed {lm_seed}, seed {seed}, {steps} steps, "
          f"{request['duration']:g} s asked)", flush=True)
    started = time.monotonic()
    with VRAMWatch() as watch:
        try:
            if engine == "native":
                log = render_native(request, request_path, folder, name, partial)
            else:
                log = render_comfy(workflow, request, partial)
        except BaseException:
            partial.unlink(missing_ok=True)
            raise
    took = time.monotonic() - started
    partial.replace(audio)
    seconds = round(soundfile.info(str(audio)).duration, 2)
    (folder / f"{name}.log").write_text(log)
    result = {"engine": engine, "track": track, "take": name, "lm_seed": lm_seed, "seed": seed, "steps": steps,
              "asked_seconds": request["duration"], "seconds": seconds, "took_seconds": round(took, 1),
              "realtime": round(seconds / took, 2) if took else None, "peak_vram_mib": watch.peak,
              "finished": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    (folder / f"{name}.result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"    took {took:.0f}s for {seconds:g} s of audio ({result['realtime']}x real time, peak VRAM "
          f"{watch.peak} MiB) -> {shown(audio)}", flush=True)
    return audio, True


def perform_track(track: str, takes: int, first_seed: int, steps: int, engine: str, cap: float | None,
                  workflow: comfy.Workflow | None) -> dict:
    brief = library.brief(track)
    problems = library.brief_problems(track, brief)
    if problems:
        raise library.TrackError(f"{track}: the brief is not complete: " + "; ".join(problems))
    score = library.score_text(track)
    broken = notation.check(notation.parse(score))
    if broken:
        raise library.TrackError(f"{track}: the score is broken (fix it before a GPU minute is spent):\n  "
                                 + "\n  ".join(broken))
    made, cached = [], []
    for index in range(takes):
        lm_seed, seed = first_seed + index, first_seed + 100 + index
        audio, fresh = perform_take(engine, track, brief, score, lm_seed, seed, steps, cap, workflow)
        (made if fresh else cached).append(audio.stem)
    return {"track": track, "made": made, "cached": cached}


def resolve_engine(choice: str) -> str:
    if choice != "auto":
        return choice
    engine = "comfy" if comfy.is_up() else "native"
    print(f"engine: {engine} (auto: ComfyUI is {'up' if engine == 'comfy' else 'down'})", flush=True)
    return engine


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tracks", nargs="*", help="track ids, performed in the order given")
    parser.add_argument("--package", help="perform every track of packages/<name>.json instead")
    parser.add_argument("--takes", type=int, default=1)
    parser.add_argument("--seed", type=int, default=1000, help="the first seed; takes count up from it")
    parser.add_argument("--steps", type=int, default=32)
    parser.add_argument("--engine", choices=["auto", "comfy", "native"], default="auto")
    parser.add_argument("--max-seconds", type=float, help="cap each take at this many seconds (a smoke take)")
    args = parser.parse_args()
    if bool(args.tracks) == bool(args.package):
        sys.exit("name the tracks to perform, or a package with --package (not both, not neither)")
    if args.takes < 1:
        sys.exit("--takes must be at least 1")
    if args.max_seconds is not None and args.max_seconds <= 0:
        sys.exit("--max-seconds must be positive")
    names = list(args.tracks)
    if args.package:
        try:
            package = library.load_package(args.package)
        except library.PackageError as error:
            sys.exit(str(error))
        names = list(package.tracks)
        print(f"package {package.name}: {package.title} ({len(names)} tracks)", flush=True)
    engine = resolve_engine(args.engine)
    if engine == "comfy" and not comfy.is_up():
        sys.exit(COMFY_DOWN.format(url=library.config()["comfy_url"]))
    if engine == "native" and comfy.is_up():
        sys.exit("ComfyUI is running: stop it first (the GPU holds one model at a time), or use --engine comfy.")
    workflow = None
    if engine == "comfy":
        try:
            workflow = comfy.Workflow()
        except comfy.WorkflowError as error:
            sys.exit(str(error))
    outcomes: list[dict] = []
    with Lock():
        for track in names:
            print(f"{track}:", flush=True)
            try:
                if not library.track_exists(track):
                    outcomes.append({"track": track, "missing": True})
                    print(f"  missing track: tracks/{track}/brief.json does not exist yet; skipped", flush=True)
                    continue
                outcomes.append(perform_track(track, args.takes, args.seed, args.steps, engine, args.max_seconds,
                                              workflow))
            except (library.TrackError, comfy.ComfyError, EngineError, RuntimeError, OSError, SystemExit) as error:
                message = str(error.code) if isinstance(error, SystemExit) else str(error)
                outcomes.append({"track": track, "failed": message})
                print(f"  FAILED: {message}", flush=True)
    print("\nsummary (" + engine + "):")
    for outcome in outcomes:
        if outcome.get("missing"):
            print(f"  {outcome['track']}: missing (no brief yet)")
        elif outcome.get("failed"):
            print(f"  {outcome['track']}: FAILED ({outcome['failed'].splitlines()[0]})")
        else:
            print(f"  {outcome['track']}: {len(outcome['made'])} made, {len(outcome['cached'])} cached")
    failed = [outcome for outcome in outcomes if outcome.get("failed")]
    missing = [outcome for outcome in outcomes if outcome.get("missing")]
    if failed or (missing and not args.package):
        sys.exit(1)


if __name__ == "__main__":
    main()
