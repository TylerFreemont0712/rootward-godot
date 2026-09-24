#!/usr/bin/env python3
"""Measure shipped audio, including decoded Opus peaks and the actual loop boundaries.

This catches technical failures, not unpleasant timbre. Run audition.py and listen as well.
"""
import json

import numpy as np

from generate import CACHE_DIR, DEFAULT_MANIFEST, OUT_DIR, SAMPLE_RATE, decode, loudness


def main():
    manifest = json.loads(DEFAULT_MANIFEST.read_text())
    loops = json.loads((OUT_DIR / "audio/music.json").read_text())
    report = {}
    failures = []
    for asset in manifest["assets"]:
        name = asset["id"]
        audio = decode(OUT_DIR / f"{asset['out']}.ogg")
        integrated, peak = loudness(audio)
        data = {"seconds": round(len(audio) / SAMPLE_RATE, 3), "lufs": integrated if np.isfinite(integrated) else None,
                "true_peak_db": peak, "clipped_samples": int(np.count_nonzero(np.abs(audio) >= 1))}
        if not np.isfinite(audio).all() or peak > -1 or np.max(np.abs(audio)) < 1e-7:
            failures.append(f"{name}: invalid waveform, silence, or insufficient headroom ({peak} dBTP)")
        if name in loops:
            start, end = (round(loops[name][key] * SAMPLE_RATE) for key in ("loopStart", "loopEnd"))
            if not 0 < start < end <= len(audio) + 3:
                failures.append(f"{name}: invalid loop points")
                continue
            end = min(end, len(audio))
            jump = np.max(np.abs(audio[end - 1] - audio[start]))
            local = max(np.max(np.abs(np.diff(audio[start:start + 480], axis=0))),
                        np.max(np.abs(np.diff(audio[end - 480:end], axis=0))), 1e-9)
            data.update(loop_seconds=round((end - start) / SAMPLE_RATE, 2), seam_ratio=round(float(jump / local), 3))
            # Fixed-gain mastering deliberately stops below target when an acoustic transient reaches the peak cap.
            level_ok = -21 <= integrated <= -19 or (-24 <= integrated < -21 and peak >= -1.8)
            if end - start < 90 * SAMPLE_RATE or not level_ok or jump / local > 1.25:
                failures.append(f"{name}: short loop, unexpected level, or discontinuous seam: {data}")
        report[name] = data
        print(name, json.dumps(data), flush=True)
    (CACHE_DIR / "audio-validation.json").write_text(json.dumps({"assets": report, "failures": failures}, indent=2) + "\n")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"PASS: {len(report)} decoded assets; all music loops at least 90 seconds, safe peaks and continuous boundaries.")


if __name__ == "__main__":
    main()
