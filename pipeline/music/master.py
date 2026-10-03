#!/usr/bin/env python3
"""Masters a take the way the game will play it, and builds the game's file from the master (pipeline/music/README.md).

`master` (per take, written to takes_dir/mastered/<take>.mastered.{flac,ogg,json}):
  1. Key fix (optional, `tune` in the manifest): varispeed by whole semitones. The planner picks its own key, and a
     take in D# minor is a semitone off the soundtrack's home D; played back 5.9% slower it is a semitone lower, in D
     minor, and its tempo is 5.9% slower than the planner meant. (A resample, not a pitch shifter: no artefacts, and the
     tempo moves with the pitch, which is why the loop grid and the style's "BPM" are read through the same ratio.)
  2. Tone: a high-pass under the music, then shelves that correct a fault in the take's colour, never by more than
     6 dB: a boomy take (over 20% of its energy under 150 Hz) is thinned, a dark one (under 1.2% over 5 kHz) lifted,
     a harsh one (over 8%) tamed; anything between is left as the model played it.
  3. Level: one gain to the kind's target loudness, capped by the peak; a single gain, because a loop's end has to meet
     its start at the same level. A limiter only if that gain still leaves the peak over (not expected).
`render` (per slot, used by install): trims the leading silence, cuts the loop at its end, crossfades the last 0.15 s
with the audio just before the loop's start (so the game's jump back is seamless; the game loops from `loopStart` to
the file's end) and levels again; a cue is trimmed and levelled as it is.

    uv run --project pipeline python pipeline/music/master.py <take>... [--kind loop|cue|bonus] [--tune -1]
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import librosa
import numpy as np
import soundfile

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import manifest  # noqa: E402

RATE = analyze.FULL_SR
TARGETS = manifest.TARGETS
# The soundtrack's colour: the most energy a master keeps under 150 Hz, the least it has over 5 kHz, and the most it
# keeps over 5 kHz before it is harsh. Only a fault is corrected: a lullaby is light in the bass and a fanfare is bright
# by nature, and neither is pushed toward an average.
WEIGHT, AIR, HARSH = 0.20, 0.012, 0.08
SHELF_LIMIT_DB = 6.0
CROSSFADE = 0.15


def first_sound(mono: np.ndarray, below_peak_db: float = 30.0) -> float:
    """When the music starts: the first 50 ms whose level comes within `below_peak_db` of the loudest."""
    window = int(analyze.SR * 0.05)
    count = len(mono) // window
    levels = 10 * np.log10(np.mean(mono[: count * window].reshape(count, window) ** 2, axis=1) + 1e-12)
    loud = np.nonzero(levels > levels.max() - below_peak_db)[0]
    return float(loud[0] * window / analyze.SR) if len(loud) else 0.0


def ffmpeg_filter(stereo: np.ndarray, chain: str) -> np.ndarray:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-af", chain, "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-"],
        input=stereo.astype(np.float32).tobytes(), capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype=np.float32).reshape(-1, 2)[: len(stereo)].copy()


def shelf_gain(share: float, target: float) -> float:
    """The shelf gain (dB) that moves a band holding `share` of the energy to `target`, within the limit."""
    share = min(max(share, 1e-5), 0.99)
    gain = 10 * np.log10(target * (1 - share) / ((1 - target) * share))
    return float(np.clip(gain, -SHELF_LIMIT_DB, SHELF_LIMIT_DB))


def tone(stereo: np.ndarray, mono: np.ndarray) -> tuple[np.ndarray, dict]:
    measured = analyze.colour(stereo, mono)
    low = min(0.0, shelf_gain(measured["below_150"], WEIGHT))
    air = measured["above_5k"]
    high = max(0.0, shelf_gain(air, AIR)) if air < HARSH else shelf_gain(air, HARSH)
    chain = f"highpass=f=30:p=2,lowshelf=g={low:.2f}:f=150:w=0.7,highshelf=g={high:.2f}:f=5000:w=0.7"
    return ffmpeg_filter(stereo, chain), {"before": measured, "low_shelf_db": round(low, 2),
                                          "high_shelf_db": round(high, 2)}


def level(stereo: np.ndarray, target: dict) -> tuple[np.ndarray, dict]:
    measured = analyze.loudness(stereo)
    gain = min(target["lufs"] - measured["lufs"], target["peak"] - measured["true_peak"])
    return stereo * np.float32(10 ** (gain / 20)), {"gain_db": round(gain, 2), "before": measured}


def seam(audio: np.ndarray, loop_start: int) -> float:
    """How abrupt the jump from the file's end back to the loop's start sounds: the spectral change across it against
    the piece's usual change from one 50 ms to the next (about 1 is seamless; 3 or more is a bump)."""
    window = int(RATE * 0.05)

    def spectrum(chunk: np.ndarray) -> np.ndarray:
        return np.log1p(np.abs(np.fft.rfft(chunk.mean(axis=1) * np.hanning(len(chunk)))))

    across = np.linalg.norm(spectrum(audio[-window:]) - spectrum(audio[loop_start: loop_start + window]))
    usual = [np.linalg.norm(spectrum(audio[i: i + window]) - spectrum(audio[i + window: i + 2 * window]))
             for i in range(loop_start, len(audio) - 2 * window, window * 7)]
    return round(float(across / (np.median(usual) + 1e-9)), 2)


def encode(stereo: np.ndarray, target: Path, quality: float = 0.5) -> None:
    """Ogg Vorbis with the exact sample count (libsndfile), a second a write (its Vorbis writer crashes on a whole
    track at once); quality 0.5 is about 160 kbps."""
    target.parent.mkdir(parents=True, exist_ok=True)
    samples = np.clip(stereo, -1, 1).astype(np.float32)
    with soundfile.SoundFile(str(target), "w", RATE, 2, format="OGG", subtype="VORBIS",
                             compression_level=1.0 - quality) as out:
        for start in range(0, len(samples), RATE):
            out.write(samples[start: start + RATE])


def varispeed(stereo: np.ndarray, tune: int) -> tuple[np.ndarray, np.ndarray, float]:
    """Resample so the audio plays `tune` semitones higher (negative: lower and slower). Returns (stereo, mono, ratio)."""
    ratio = 2 ** (-tune / 12)
    if tune == 0:
        return stereo, librosa.resample(stereo.mean(axis=1), orig_sr=RATE, target_sr=analyze.SR), 1.0
    moved = np.stack([librosa.resample(stereo[:, c], orig_sr=RATE, target_sr=int(round(RATE * ratio)))
                      for c in range(2)], axis=1).astype(np.float32)
    return moved, librosa.resample(moved.mean(axis=1), orig_sr=RATE, target_sr=analyze.SR), ratio


# --- takes ---------------------------------------------------------------------------------------------------------

def ensure_raw(slot: dict, take: str) -> Path:
    """The take's flac: the generated file, or (for a stinger cut from a longer take) the cut, made when missing."""
    found = manifest.find("", manifest.raw_name(take))
    if found:
        return found
    entry = slot["takes"][take]
    if "derived_from" not in entry:
        raise SystemExit(f"{take}: no file {manifest.raw_name(take)} in {manifest.takes_dir()} (music.sh run makes it)")
    source = ensure_raw(slot, entry["derived_from"])
    seconds, fade = entry["trim"]["seconds"], entry["trim"].get("fade", 1.2)
    destination = manifest.where("", manifest.raw_name(take))
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-y", "-i", str(source), "-t", f"{seconds}",
                    "-af", f"afade=t=out:st={seconds - fade}:d={fade}", str(destination)], check=True)
    return destination


def mastered_path(take: str, suffix: str = "flac") -> Path | None:
    return manifest.find("mastered", f"{take}.mastered.{suffix}")


def master_take(slot: dict, take: str) -> dict:
    """Master one take into takes_dir/mastered and return (and save) its report."""
    kind = slot["kind"]
    tune = slot["takes"][take].get("tune", 0)
    stereo, _ = analyze.load(ensure_raw(slot, take))
    stereo, mono, ratio = varispeed(stereo, tune)
    before = analyze.loudness(stereo)
    toned, tinfo = tone(stereo, mono)
    out, linfo = level(toned, TARGETS[kind])
    limited = False
    if analyze.loudness(out)["true_peak"] > TARGETS[kind]["peak"] + 0.05:  # not expected: one capped gain
        limit = 10 ** ((TARGETS[kind]["peak"] - 0.3) / 20)
        out = ffmpeg_filter(out, f"alimiter=limit={limit:.4f}:level=disabled:attack=5:release=80")
        limited = True
    ogg, flac = manifest.where("mastered", f"{take}.mastered.ogg"), manifest.where("mastered", f"{take}.mastered.flac")
    flac.parent.mkdir(parents=True, exist_ok=True)
    encode(out, ogg, 0.7)
    soundfile.write(str(flac), np.clip(out, -1, 1), RATE, subtype="PCM_24")
    report = {"name": take, "kind": kind, "seconds": round(len(stereo) / RATE, 1), "tune": tune, "varispeed": ratio,
              "before": before, "tone": tinfo, "gain_db": linfo["gain_db"], "limiter": limited,
              "after_ogg": analyze.loudness(analyze.load(ogg)[0]), "ogg_kb": round(ogg.stat().st_size / 1024)}
    manifest.where("mastered", f"{take}.mastered.json").write_text(json.dumps(report, indent=1, default=float) + "\n")
    return report


# --- the game's file -------------------------------------------------------------------------------------------------

def render(slot: dict, take: str, start: float | None, end: float | None) -> tuple[np.ndarray, dict | None]:
    """The slot's game audio from the take's master, and its loop ({loopStart, loopEnd, seam}) when it has one.
    start/end are the loop in the master's seconds; None for a cue."""
    path = mastered_path(take)
    if path is None:
        raise SystemExit(f"{take}: not mastered yet (music.sh master {take})")
    stereo, mono = analyze.load(path)
    begin = max(0, int((first_sound(mono) - 0.02) * RATE))
    if start is None or end is None:
        piece, _ = level(stereo[begin:].copy(), TARGETS["cue"])
        return piece, None
    loop_start, loop_end = int(round(start * RATE)), int(round(end * RATE))
    if loop_end > len(stereo):
        raise SystemExit(f"{take}: the loop ends at {end:.1f}s, after the master does ({len(stereo) / RATE:.1f}s)")
    piece = stereo[begin:loop_end].copy()
    a, b = loop_start - begin, loop_end - begin
    fade = min(int(CROSSFADE * RATE), a)
    ramp = np.linspace(0, np.pi / 2, fade, dtype=np.float32)[:, None]
    piece[b - fade: b] = piece[b - fade: b] * np.cos(ramp) + stereo[loop_start - fade: loop_start] * np.sin(ramp)
    piece, _ = level(piece, TARGETS["loop"])
    return piece, {"loopStart": round(a / RATE, 7), "loopEnd": round(b / RATE, 7), "seam": seam(piece, a)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("takes", nargs="+")
    parser.add_argument("--kind", choices=list(TARGETS))
    parser.add_argument("--tune", type=int)
    args = parser.parse_args()
    data = manifest.load()
    for take in args.takes:
        found = manifest.slot_of(take, data)
        if not found:
            sys.exit(f"{take}: not a take in soundtrack.json")
        slot = dict(found[1], takes={k: dict(v) for k, v in found[1]["takes"].items()})
        if args.kind:
            slot["kind"] = args.kind
        if args.tune is not None:
            slot["takes"][take]["tune"] = args.tune
        print(json.dumps(master_take(slot, take), default=float))


if __name__ == "__main__":
    main()
