#!/usr/bin/env python3
"""Measures a piece of music (pipeline/music/README.md), and draws it. The library under `qc.py`, `master.py` and the
loop finder; also a command of its own for any audio file:

  - tempo: the beat grid librosa tracks and how steady it is (a drifting tempo puts a loop's seam off the beat). The
    tracker often halves or doubles the tempo, so for the tempo a take was *made* at, read the planner's score;
  - key: the chroma's best match among the 24 major and minor key profiles (a check on the master, after a key fix);
  - loudness and dynamics: EBU R128 integrated loudness, loudness range and true peak (ffmpeg), the spread of its
    one-second levels;
  - colour: brightness (spectral centroid, energy above 5 and 10 kHz), weight (energy below 150 Hz), stereo width;
  - shape: how the piece repeats (a self-similarity matrix) and where its sections turn.
The picture (a PNG beside the report) stacks the level envelope with the beat grid, a spectrogram, the chroma, and
the self-similarity matrix, so a take can be looked at the way a producer looks at a DAW.

    uv run --project pipeline python pipeline/music/analyze.py <audio>... [--bpm 138] [--key "E minor"] [--out DIR]
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import librosa
import numpy as np
from PIL import Image, ImageDraw

SR = 22050  # analysis rate: every feature here lives below 11 kHz, and it keeps librosa quick
FULL_SR = 48000
HOP = 512
KEYS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
# Krumhansl-Kessler key profiles: how much each pitch class belongs to a major or minor key.
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def load(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """(stereo at 48 kHz, frames x 2) and (mono at the analysis rate)."""
    raw = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar",
         str(FULL_SR), "-"], capture_output=True, check=True).stdout
    stereo = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)
    mono = librosa.resample(stereo.mean(axis=1), orig_sr=FULL_SR, target_sr=SR)
    return stereo, mono


def loudness(stereo: np.ndarray) -> dict:
    """EBU R128 integrated loudness (LUFS), loudness range (LU) and true peak (dBTP), measured by ffmpeg."""
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostdin", "-f", "f32le", "-ar", str(FULL_SR), "-ac", "2", "-i", "-", "-af",
         "loudnorm=print_format=json", "-f", "null", "-"], input=stereo.astype(np.float32).tobytes(),
        capture_output=True)
    text = result.stderr.decode(errors="replace")
    measured = json.loads(text[text.rindex("{"): text.rindex("}") + 1])
    return {"lufs": float(measured["input_i"]), "lra": float(measured["input_lra"]),
            "true_peak": float(measured["input_tp"])}


def key_of(chroma: np.ndarray) -> dict:
    """The key whose profile best matches the piece's average chroma, and how clearly (correlation, and its lead over
    the runner-up)."""
    profile = chroma.mean(axis=1)
    scores = []
    for tonic in range(12):
        for mode, template in (("major", MAJOR), ("minor", MINOR)):
            scores.append((float(np.corrcoef(profile, np.roll(template, tonic))[0, 1]), f"{KEYS[tonic]} {mode}"))
    scores.sort(reverse=True)
    return {"key": scores[0][1], "confidence": round(scores[0][0], 3), "margin": round(scores[0][0] - scores[1][0], 3)}


def tempo_of(mono: np.ndarray, bpm: float | None) -> tuple[dict, np.ndarray]:
    """The beat grid and its tempo. A model asked for 138 bpm that plays at 69 or 276 is still in time (the tracker
    halves and doubles); a tempo that wanders is not, and `steadiness` says how much the beats' spacing varies."""
    onset = librosa.onset.onset_strength(y=mono, sr=SR, hop_length=HOP)
    tempo, beats = librosa.beat.beat_track(onset_envelope=onset, sr=SR, hop_length=HOP, start_bpm=bpm or 120,
                                           units="time", tightness=100)
    beats = np.asarray(beats)
    report: dict = {"beats": len(beats)}
    if len(beats) > 8:
        spacing = np.diff(beats)
        measured = 60.0 / float(np.median(spacing))
        report["bpm"] = round(measured, 2)
        report["steadiness"] = round(float(np.std(spacing) / np.mean(spacing)), 4)
        if bpm:
            ratios = [measured / (bpm * factor) for factor in (0.5, 1, 2)]
            best = min(ratios, key=lambda r: abs(np.log(r)))
            report["off_by_percent"] = round((best - 1) * 100, 2)
        # The beat grid drifts against a fixed metronome by this many beats over the piece: what a loop cut on the
        # brief's tempo would be out by.
        if bpm:
            period = 60.0 / (bpm * round(measured / bpm) if round(measured / bpm) else bpm)
            expected = beats[0] + period * np.arange(len(beats))
            report["drift_beats"] = round(float((beats[-1] - expected[-1]) / period), 2)
    report["onsets_per_second"] = round(float(len(librosa.onset.onset_detect(onset_envelope=onset, sr=SR,
                                                                              hop_length=HOP)) / (len(mono) / SR)), 2)
    return report, beats


def grid(mono: np.ndarray, bpm: float) -> tuple[float, float]:
    """The performance's own beat: (seconds a beat, when a beat falls). A model asked for 132 bpm may play at 129, and
    over forty bars that is most of a bar, so the grid is a least-squares line through the tracked beats, each given
    its whole index on it, and never the brief's tempo. A tracker locked at half or double time is folded back."""
    onset = librosa.onset.onset_strength(y=mono, sr=SR, hop_length=HOP)
    _, beats = librosa.beat.beat_track(onset_envelope=onset, sr=SR, hop_length=HOP, start_bpm=bpm, units="time",
                                       tightness=100)
    beats = np.asarray(beats)
    if len(beats) < 8:
        return 60.0 / bpm, float(beats[0]) if len(beats) else 0.0
    beat = float(np.median(np.diff(beats)))
    beat /= 2.0 ** round(np.log2(beat / (60.0 / bpm)))
    phase = float(beats[0])
    for _ in range(3):
        position = (beats - phase) / beat
        index = np.round(position)
        near = np.abs(position - index) < 0.2  # beats the tracker put between the grid's (half-time locks, fills)
        beat, phase = (float(value) for value in np.polyfit(index[near], beats[near], 1))
    return beat, phase


def colour(stereo: np.ndarray, mono: np.ndarray) -> dict:
    """How bright, heavy and wide it is. Energy shares come from the full-rate signal's spectrum."""
    left, right = stereo[:, 0].astype(np.float64), stereo[:, 1].astype(np.float64)
    mid, side = (left + right) / 2, (left - right) / 2
    spectrum = np.abs(np.fft.rfft(mid[: FULL_SR * 60] if len(mid) > FULL_SR * 60 else mid)) ** 2
    freqs = np.fft.rfftfreq(min(len(mid), FULL_SR * 60), 1 / FULL_SR)
    total = spectrum.sum() + 1e-12
    centroid = librosa.feature.spectral_centroid(y=mono, sr=SR, hop_length=HOP)[0]
    return {
        "centroid_hz": round(float(np.median(centroid)), 1),
        "above_5k": round(float(spectrum[freqs > 5000].sum() / total), 4),
        "above_10k": round(float(spectrum[freqs > 10000].sum() / total), 5),
        "below_150": round(float(spectrum[freqs < 150].sum() / total), 4),
        "width": round(float(np.sqrt(np.mean(side ** 2) / (np.mean(mid ** 2) + 1e-12))), 3),
    }


def dynamics(mono: np.ndarray) -> dict:
    """The spread of one-second levels (a piece that never breathes has almost none) and whether it drops out."""
    window = SR
    count = len(mono) // window
    levels = 10 * np.log10(np.mean(mono[: count * window].reshape(count, window) ** 2, axis=1) + 1e-12)
    active = levels[levels > levels.max() - 40]
    return {
        "spread_db": round(float(np.percentile(active, 95) - np.percentile(active, 10)), 2) if len(active) else 0.0,
        "dropouts": int(np.sum(levels < levels.max() - 40)),
    }


def structure(mono: np.ndarray) -> tuple[dict, np.ndarray]:
    """How the piece repeats: a self-similarity matrix over beat-synchronous chroma and timbre, how much of it is
    repetition, and where the sections turn (peaks of a checkerboard novelty curve)."""
    chroma = librosa.feature.chroma_cqt(y=mono, sr=SR, hop_length=HOP)
    mfcc = librosa.feature.mfcc(y=mono, sr=SR, hop_length=HOP, n_mfcc=13)
    # Two seconds a column: fine enough to see phrases, coarse enough to see a two-minute piece whole.
    step = int(2 * SR / HOP)
    count = chroma.shape[1] // step
    features = np.vstack([
        librosa.util.normalize(chroma[:, : count * step].reshape(12, count, step).mean(axis=2), axis=0),
        librosa.util.normalize(mfcc[1:, : count * step].reshape(12, count, step).mean(axis=2), axis=0),
    ])
    unit = features / (np.linalg.norm(features, axis=0, keepdims=True) + 1e-9)
    similarity = unit.T @ unit
    off_diagonal = similarity[~np.eye(count, dtype=bool)] if count > 1 else np.array([0.0])
    # Checkerboard novelty: high where the past and the future of a moment differ.
    size = 4
    kernel = np.kron(np.array([[1, -1], [-1, 1]]), np.ones((size, size)))
    novelty = np.array([
        float(np.sum(kernel * similarity[i - size: i + size, i - size: i + size])) if size <= i < count - size else 0.0
        for i in range(count)
    ])
    turns = [i * 2 for i in range(1, count - 1) if novelty[i] > novelty[i - 1] and novelty[i] >= novelty[i + 1]
             and novelty[i] > np.percentile(novelty, 85)]
    return {"repetition": round(float(np.mean(off_diagonal > 0.9)), 3), "section_turns_s": turns}, similarity


def heatmap(values: np.ndarray, width: int, height: int, palette: str = "magma") -> Image.Image:
    """A 2-D array as an image (rows bottom-up), coloured by a small built-in palette."""
    lo, hi = np.percentile(values, 2), np.percentile(values, 99.5)
    norm = np.clip((values - lo) / (hi - lo + 1e-9), 0, 1)
    stops = {
        "magma": [(0, 0, 4), (80, 18, 123), (183, 55, 121), (252, 137, 97), (252, 253, 191)],
        "teal": [(8, 16, 20), (18, 70, 80), (40, 150, 150), (160, 225, 200), (250, 255, 240)],
    }[palette]
    positions = np.linspace(0, 1, len(stops))
    rgb = np.stack([np.interp(norm, positions, [s[c] for s in stops]) for c in range(3)], axis=-1).astype(np.uint8)
    image = Image.fromarray(rgb[::-1]) if values.ndim == 2 else Image.fromarray(rgb)
    return image.resize((width, height), Image.Resampling.BILINEAR)


def picture(stereo: np.ndarray, mono: np.ndarray, beats: np.ndarray, similarity: np.ndarray, report: dict,
            path: Path, title: str) -> None:
    """Envelope and beat grid, spectrogram, chroma, and the self-similarity matrix, side by side."""
    width, pad = 1500, 8
    seconds = len(mono) / SR
    canvas = Image.new("RGB", (width + 420, 760), (18, 14, 12))
    draw = ImageDraw.Draw(canvas)
    draw.text((pad, 4), title, fill=(242, 165, 65))
    summary = " · ".join(f"{k} {v}" for k, v in report.items() if not isinstance(v, (dict, list)))
    draw.text((pad, 18), summary[:230], fill=(200, 190, 170))
    # Envelope (RMS in 50 ms) with beats as ticks and bar lines every four beats.
    rms = librosa.feature.rms(y=mono, frame_length=2048, hop_length=int(SR * 0.05))[0]
    db = 20 * np.log10(rms + 1e-6)
    top, height = 40, 120
    xs = np.linspace(pad, width, len(db))
    ys = top + height - np.clip((db + 60) / 60, 0, 1) * height
    draw.line(list(zip(xs.tolist(), ys.tolist())), fill=(109, 223, 154), width=1)
    for index, beat in enumerate(beats):
        x = pad + beat / seconds * (width - pad)
        draw.line([(x, top + height - (14 if index % 4 == 0 else 6)), (x, top + height)],
                  fill=(242, 165, 65) if index % 4 == 0 else (120, 100, 80))
    for second in range(0, int(seconds) + 1, 10):
        x = pad + second / seconds * (width - pad)
        draw.text((x + 2, top + height + 2), f"{second}s", fill=(140, 130, 120))
    # Spectrogram (mel, 128 bands up to 11 kHz) and chroma.
    mel = librosa.power_to_db(librosa.feature.melspectrogram(y=mono, sr=SR, hop_length=HOP, n_mels=128), ref=np.max)
    canvas.paste(heatmap(mel, width - pad, 330), (pad, 180))
    chroma = librosa.feature.chroma_cqt(y=mono, sr=SR, hop_length=HOP)
    canvas.paste(heatmap(chroma, width - pad, 200, "teal"), (pad, 520))
    for index, name in enumerate(KEYS):
        draw.text((2, 520 + 200 - (index + 1) * 200 / 12), name, fill=(200, 200, 200))
    # Self-similarity: the repeats of a piece are the bright stripes off the diagonal.
    canvas.paste(heatmap(similarity, 400, 400), (width + 12, 180))
    draw.text((width + 12, 160), "self-similarity (2 s cells)", fill=(200, 190, 170))
    canvas.save(path)


def analyze(path: Path, bpm: float | None = None, key: str | None = None, out: Path | None = None) -> dict:
    stereo, mono = load(path)
    report: dict = {"seconds": round(len(stereo) / FULL_SR, 2)}
    report.update(loudness(stereo))
    tempo, beats = tempo_of(mono, bpm)
    report["tempo"] = tempo
    chroma = librosa.feature.chroma_cqt(y=mono, sr=SR, hop_length=HOP)
    report["key"] = key_of(chroma)
    if key:
        report["key"]["asked"] = key
    report["colour"] = colour(stereo, mono)
    report["dynamics"] = dynamics(mono)
    shape, similarity = structure(mono)
    report["structure"] = shape
    report["clipped"] = int(np.count_nonzero(np.abs(stereo) >= 0.999))
    if out is not None:
        out.mkdir(parents=True, exist_ok=True)
        flat = {"bpm": tempo.get("bpm"), "steady": tempo.get("steadiness"), "key": report["key"]["key"],
                "lufs": report["lufs"], "lra": report["lra"], "centroid": report["colour"]["centroid_hz"],
                ">5k": report["colour"]["above_5k"], "<150": report["colour"]["below_150"],
                "spread": report["dynamics"]["spread_db"], "repeats": shape["repetition"]}
        picture(stereo, mono, beats, similarity, flat, out / f"{path.stem}.png", path.name)
        (out / f"{path.stem}.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("audio", nargs="+", type=Path)
    parser.add_argument("--bpm", type=float)
    parser.add_argument("--key")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    for path in args.audio:
        report = analyze(path, args.bpm, args.key, args.out)
        print(path.name, json.dumps(report))


if __name__ == "__main__":
    main()
