#!/usr/bin/env python3
"""Build the before/after listening page and a combat sequence at the game's default mix levels.

Run with ComfyUI's Python after generate.py. The old files are preserved in the before-polish cache folder;
the new files are the actual shipped assets. This is a listening aid, not a perceptual quality score.
"""

import html
import json
import os
from pathlib import Path

import numpy as np

from generate import CACHE_DIR, DEFAULT_MANIFEST, OUT_DIR, SAMPLE_RATE, decode, encode, retime, resolve

BEFORE = CACHE_DIR / "before-polish"
PAGE = CACHE_DIR / "audio-polish-listen.html"


def player(path: Path, label: str) -> str:
    url = html.escape(os.path.relpath(path, PAGE.parent))
    meta_path = path.parent / "music.json"
    meta = json.loads(meta_path.read_text()).get(path.stem) if meta_path.exists() else None
    loop = f' data-start="{meta["loopStart"]}" data-end="{meta["loopEnd"]}"' if meta else ""
    return f'<label>{html.escape(label)}<audio controls preload="none" src="{url}"{loop}></audio></label>'


def measure(path: Path) -> dict:
    audio = decode(path)
    power = np.mean(audio.astype(np.float64) ** 2, axis=1)
    window = SAMPLE_RATE // 100
    blocks = np.array([power[i:i + window].mean() for i in range(0, len(power), window)])
    active = np.flatnonzero(blocks > max(blocks.max() * 0.01, 1e-10))
    peak = float(np.abs(audio).max())
    return {
        "seconds": round(len(audio) / SAMPLE_RATE, 3),
        "peak_dbfs": round(20 * np.log10(peak + 1e-12), 2),
        "attack_peak_ms": int(np.argmax(blocks) * 10),
        "active_ms": int((active[-1] - active[0] + 1) * 10) if len(active) else 0,
        "tail_dbfs": round(10 * np.log10(power[-window:].mean() + 1e-12), 2),
        "finite": bool(np.isfinite(audio).all()),
        "clipped_samples": int(np.count_nonzero(np.abs(audio) >= 1)),
    }


def combat(folder: Path, name: str, music: bool) -> Path:
    # TIMING.charge = 420 ms, missile flight = 250 ms, volley maxGap = 190 ms.
    events = [
        (0.1, "charge", 0.48, 1), (0.52, "cast", 0.68, 0.96), (0.77, "hit", 0.7, 0.96),
        (2.2, "charge", 0.48, 1), (2.62, "ward", 0.7, 1),
        (5.0, "glance", 0.6, 0.9),
        (6.7, "charge", 0.48, 1),
        (9.5, "hurt", 0.94, 1), (11.2, "heal", 0.65, 1), (14.0, "turn", 0.55, 1),
    ]
    for i, rate in enumerate((0.96, 1.03, 1, 1.07)):
        events.extend([(7.12 + i * 0.19, "cast", 0.68, rate), (7.37 + i * 0.19, "hit", 0.7, rate)])
    mixed = np.zeros((16 * SAMPLE_RATE, 2), dtype=np.float32)
    if music:
        bgm = decode(folder / "music-battle-salvage.ogg")
        mixed += bgm[12 * SAMPLE_RATE:28 * SAMPLE_RATE] * (0.8 * 0.6) ** 2
    for at, effect, volume, rate in events:
        clip = retime(decode(folder / f"sfx-{effect}.ogg"), rate) * volume * (0.8 * 0.8) ** 2
        start = round(at * SAMPLE_RATE)
        length = min(len(clip), len(mixed) - start)
        mixed[start:start + length] += clip[:length]
    fade = np.linspace(1, 0, SAMPLE_RATE, dtype=np.float32)[:, None]
    mixed[-SAMPLE_RATE:] *= fade
    if np.abs(mixed).max() >= 0.95:
        raise ValueError(f"{name}: combat mix has insufficient headroom")
    path = CACHE_DIR / f"combat-{name}-{'music' if music else 'dry'}.ogg"
    encode(mixed, path, {"bitrate": 160})
    return path


def main() -> None:
    manifest = json.loads(DEFAULT_MANIFEST.read_text())
    jobs = [resolve(a, manifest) for a in manifest["assets"]]
    jobs.sort(key=lambda a: (a["id"] not in ("cue-victory", "sfx-ward", "sfx-cast"), a["id"]))
    report = {}
    parts = []
    for job in jobs:
        name = job["id"]
        current = OUT_DIR / f"{job['out']}.ogg"
        previous = BEFORE / f"{name}.ogg"
        report[name] = {"before": measure(previous), "after": measure(current)}
        players = player(previous, "Before") + player(current, "In game now")
        alternatives = ""
        for candidate in range(job["candidates"] if job["style"] == "designed" else 0):
            path = CACHE_DIR / name / f"candidate_{candidate}.ogg"
            if path.exists():
                report[name][f"candidate_{candidate}"] = measure(path)
                if candidate != job.get("pick", 0):
                    alternatives += player(path, f"Unselected take {candidate + 1}")
        drafts = (f'<details><summary>Other generated takes (unselected)</summary><div class="players">{alternatives}</div></details>'
                  if alternatives else "")
        parts.append(f'<section><h2>{html.escape(name)}</h2><div class="players">{players}</div>{drafts}</section>')
    demos = "".join(
        player(combat(folder, name, music), f"{name.title()} · {'with battle music' if music else 'effects alone'}")
        for music in (False, True) for name, folder in (("before", BEFORE), ("after", OUT_DIR / "audio"))
    )
    PAGE.write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
        '<title>Rootward · Sound workshop</title><style>'
        'body{font:16px/1.6 system-ui;background:#171b19;color:#e3e5d8;max-width:1100px;margin:40px auto;padding:0 24px}'
        'h1,h2{color:#b9d6a0}h2{font-size:18px}section{border-top:1px solid #39443a;padding:12px 0}'
        '.players{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}'
        'label{display:block;color:#bdc4b7;font-size:14px}audio{display:block;width:100%;margin:8px 0}'
        'p{max-width:800px}a{color:#b9d6a0}</style><h1>Rootward · Sound workshop</h1>'
        '<p>Compare the previous pass with the replacements: all 12 music tracks, 3 cues and 24 effects. '
        'Victory, guard and bolt appear first. Music repeats at its in-game loop points. '
        'The combat sequence uses the game’s default mix. Measurements and semantic screening are not listening; '
        'your ears are the final check. Alternate effect takes are below each shipped sound.</p>'
        '<section><h2>In context</h2><p>Bolt → guard → blocked hit → four-bolt volley → damage → healing → next turn.</p>'
        f'<div class="players">{demos}</div></section>' + "".join(parts) +
        '<script>document.addEventListener("play",e=>{if(e.target.tagName==="AUDIO")'
        'document.querySelectorAll("audio").forEach(a=>{if(a!==e.target)a.pause()})},true);'
        'document.querySelectorAll("audio[data-end]").forEach(a=>{const wrap=()=>{if(a.currentTime>=Number(a.dataset.end)-0.025)'
        '{a.currentTime=Number(a.dataset.start);if(a.ended)a.play()}};a.addEventListener("timeupdate",wrap);a.addEventListener("ended",wrap)})'
        '</script></html>'
    )
    (CACHE_DIR / "audio-polish-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Listen: {PAGE}")
    for name, values in report.items():
        print(f"{name}: {values['before']['seconds']}s -> {values['after']['seconds']}s, {values['after']['peak_dbfs']} dBFS")


if __name__ == "__main__":
    main()
