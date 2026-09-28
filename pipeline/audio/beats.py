#!/usr/bin/env python3
"""Draws the fight's sounds against their animations' beats (docs/SOUND_DESIGN.md): each take of each timeline sound
as its level over time and its spectrogram, with the animation's beats (the manifest's `beats`, in milliseconds from
the first frame) as lines across it, so a crack that should land on the blow's frame can be seen to. Run it after
`generate.py` has rendered the sounds into the cache.

    uv run --project pipeline python pipeline/audio/beats.py [--only 'sfx-hit*'] [--out pipeline/cache/audio/beats.png]
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("manifest.json")
CACHE = ROOT / "pipeline" / "cache" / "audio"
RATE = 48000
WIDTH, ROW = 1400, 110


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-i", str(path), "-f", "f32le", "-ac",
                          "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def envelope_db(mono: np.ndarray, window_ms: float = 5.0) -> np.ndarray:
    window = int(RATE * window_ms / 1000)
    count = max(1, len(mono) // window)
    power = np.mean(mono[: count * window].reshape(count, window) ** 2, axis=1)
    return 10 * np.log10(power + 1e-10)


def spectrogram(mono: np.ndarray, columns: int) -> np.ndarray:
    """A log-magnitude spectrogram, 64 rows on a log frequency axis from 60 Hz to 16 kHz."""
    size = 1024
    hop = max(1, (len(mono) - size) // max(1, columns))
    frames = [np.abs(np.fft.rfft(mono[i: i + size] * np.hanning(size))) for i in range(0, max(1, len(mono) - size), hop)]
    if not frames:
        return np.zeros((64, 1))
    grid = np.array(frames).T
    freqs = np.fft.rfftfreq(size, 1 / RATE)
    edges = np.geomspace(60, 16000, 65)
    rows = [grid[(freqs >= lo) & (freqs < hi)].mean(axis=0) if np.any((freqs >= lo) & (freqs < hi)) else np.zeros(grid.shape[1])
            for lo, hi in zip(edges[:-1], edges[1:])]
    return 20 * np.log10(np.array(rows) + 1e-6)


def takes(asset: dict) -> list[Path]:
    folder = CACHE / asset["id"]
    found = sorted(folder.glob("variant_*.ogg")) or sorted(folder.glob("candidate_0.ogg"))
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma-separated ids; a trailing * matches a prefix")
    parser.add_argument("--out", type=Path, default=CACHE / "beats.png")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    wanted = [w.strip() for w in args.only.split(",")] if args.only else None
    assets = [a for a in manifest["assets"] if a.get("style") == "timeline" and (
        wanted is None or any(a["id"] == w or (w.endswith("*") and a["id"].startswith(w[:-1])) for w in wanted))]
    rows = [(asset, path) for asset in assets for path in takes(asset)]
    span_ms = max([1200.0] + [max(asset.get("beats", [0])) + 400 for asset, _ in rows])
    canvas = Image.new("RGB", (WIDTH, 30 + ROW * len(rows)), (18, 14, 12))
    draw = ImageDraw.Draw(canvas)
    left = 230
    scale = (WIDTH - left - 10) / span_ms
    for ms in range(0, int(span_ms) + 1, 100):
        x = left + ms * scale
        draw.line([(x, 20), (x, canvas.height)], fill=(40, 34, 30))
        if ms % 200 == 0:
            draw.text((x + 2, 4), f"{ms}", fill=(140, 130, 120))
    report = []
    for index, (asset, path) in enumerate(rows):
        top = 30 + index * ROW
        mono = decode(path)
        env = envelope_db(mono)
        loudest = float(np.argmax(env) * 5.0)
        beats = asset.get("beats", [])
        nearest = min(beats, key=lambda b: abs(b - loudest)) if beats else None
        report.append((asset["id"], path.stem, round(len(mono) / RATE * 1000), round(loudest), nearest))
        draw.text((8, top + 8), asset["id"], fill=(242, 165, 65))
        draw.text((8, top + 24), f"{path.stem} · {len(mono) / RATE * 1000:.0f} ms", fill=(170, 160, 150))
        draw.text((8, top + 40), f"loudest at {loudest:.0f} ms", fill=(170, 160, 150))
        spec = spectrogram(mono, int(len(mono) / RATE * 1000 * scale))
        lo, hi = np.percentile(spec, 5), np.percentile(spec, 99.5)
        norm = np.clip((spec - lo) / (hi - lo + 1e-9), 0, 1)[::-1]
        picture = Image.fromarray((np.stack([norm * 250, norm ** 1.5 * 150, norm ** 3 * 90], axis=-1)).astype(np.uint8))
        picture = picture.resize((max(1, int(len(mono) / RATE * 1000 * scale)), ROW - 12), Image.Resampling.BILINEAR)
        canvas.paste(picture, (left, top + 4))
        points = [(left + i * 5.0 * scale, top + 4 + (ROW - 12) * (1 - np.clip((value + 60) / 60, 0, 1)))
                  for i, value in enumerate(env)]
        if len(points) > 1:
            draw.line(points, fill=(109, 223, 154), width=2)
        for beat in beats:
            x = left + beat * scale
            draw.line([(x, top + 2), (x, top + ROW - 6)], fill=(255, 196, 80), width=1)
        draw.line([(0, top + ROW - 2), (WIDTH, top + ROW - 2)], fill=(50, 42, 36))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.out)
    for row in report:
        print(f"{row[0]:18} {row[1]:10} {row[2]:5d} ms, loudest at {row[3]:4d} ms" + (f" (beat {row[4]})" if row[4] is not None else ""))
    print(f"-> {args.out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
