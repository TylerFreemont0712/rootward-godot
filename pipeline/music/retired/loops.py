#!/usr/bin/env python3
"""A harmony-aware loop finder for mastered takes (pipeline/music/README.md).

A loop can be bar-aligned and still land on the wrong chord (the Heapworks map's first loop did, and the player heard
it). So every pair (start, end) on the planner's bar grid is scored by what the ear compares across the jump:

  harmony   beat-synchronous chroma (full band and bass band) of ~2.5 s BEFORE the end vs BEFORE the start (the music
            leading into the jump must match the music that led into the start), and of ~2.5 s AFTER the start vs AFTER
            the end (what plays next must be what would have played), as beat-by-beat cosine and as the window mean;
  join      the chroma straight across the jump (last bar before the end -> first bar of the start);
  rhythm    the onset accent pattern of the last bar before the end vs before the start (rhythmic phase);
  level     loudness and spectral centroid continuity across the jump;
  span      longer is better, up to about 45 s.

The grid is the planner's tempo (read through the master's varispeed ratio) fitted to the audio's onsets, and its
downbeat the beat whose bar lines carry the most onset weight; `grid_strength` says how well it fits (under about 2 every
score is shaky). The top candidates are verified with the master's seam ratio.

    uv run --project pipeline python pipeline/music/loops.py find <take> [--top 5] [--min 20] [--max 90]
    uv run --project pipeline python pipeline/music/loops.py score <take> <start> <end>
    uv run --project pipeline python pipeline/music/loops.py render <take> <start> <end> <out-stem>

<take> is a mastered take (takes_dir/mastered/<take>.mastered.flac) with its planner score (takes_dir/abc/<take>.abc).
`music.sh loops` runs `find` and writes the auditions: the game's own playback of each jump (the last 8 s of the loop,
then its first 8 s, after the installer's crossfade) as takes_dir/loops/<take>-cand<N>.ogg.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import librosa
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import manifest  # noqa: E402
import master  # noqa: E402
import plan as planner  # noqa: E402

SR = analyze.SR
HOP = 512
ONSET_HOP = 128
SUB = 4  # onset samples per beat


def onset_env(mono: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    env = librosa.onset.onset_strength(y=mono, sr=SR, hop_length=ONSET_HOP)
    return env / (env.mean() + 1e-9), np.arange(len(env)) * ONSET_HOP / SR


def fit_grid(env: np.ndarray, t: np.ndarray, beat: float) -> tuple[float, float, float]:
    """The plan's beat grid fitted to the audio: search the phase (one beat) and a small tempo scale for the grid whose
    beats sit on the strongest onsets. Returns (beat seconds, phase, strength against the average grid)."""
    best = None
    scores = []
    for scale in np.linspace(0.985, 1.015, 31):
        b = beat * scale
        for phase in np.arange(0, b, 0.01):
            s = float(np.interp(np.arange(phase, t[-1] - 0.1, b), t, env).mean())
            scores.append(s)
            if best is None or s > best[0]:
                best = (s, b, phase)
    return best[1], best[2], best[0] / (np.mean(scores) + 1e-9)


def cos(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


def seqcos(a: np.ndarray, b: np.ndarray) -> float:
    n = min(len(a), len(b))
    if n == 0:
        return 0.0
    num = (a[:n] * b[:n]).sum(1)
    den = np.linalg.norm(a[:n], axis=1) * np.linalg.norm(b[:n], axis=1) + 1e-9
    return float((num / den).mean())


class Track:
    """Beat-synchronous features of a mastered take on the plan's bar grid."""

    def __init__(self, take: str):
        self.take = take
        audio = manifest.find("mastered", f"{take}.mastered.flac")
        abc = manifest.find("abc", f"{take}.abc")
        if not audio or not abc:
            raise SystemExit(f"{take}: needs its master and its planner score (music.sh master {take}; the score is saved "
                             f"by music.sh run)")
        self.stereo, self.mono = analyze.load(audio)
        self.total = len(self.mono) / SR
        score = planner.parse(abc.read_text())
        side = manifest.find("mastered", f"{take}.mastered.json")
        ratio = json.loads(side.read_text()).get("varispeed", 1.0) if side else 1.0  # a tuned master is slower
        self.bpb = score.beats_per_bar
        self.timeline = [dict(p, start=p["start"] * ratio, end=p["end"] * ratio)
                         for p in planner.timeline(score) if p["name"] != "silence"]
        env, t = onset_env(self.mono)
        beat, phase, strength = fit_grid(env, t, 60.0 / score.bpm * ratio)
        self.beat, self.grid_strength = beat, strength
        # downbeat: the beat (of bpb) whose bar lines carry the most onset weight
        def bar_weight(shift: int) -> float:
            bars = phase + shift * beat + np.arange(0, int((self.total - phase) / (beat * self.bpb))) * beat * self.bpb
            return float(np.interp(bars, t, env).mean())

        shift = max(range(self.bpb), key=bar_weight)
        self.bar0 = phase + shift * beat
        while self.bar0 > beat * self.bpb:
            self.bar0 -= beat * self.bpb
        self.bar = beat * self.bpb
        n = int((self.total - self.bar0) / beat)
        self.times = self.bar0 + np.arange(n + 1) * beat
        full = librosa.feature.chroma_cqt(y=self.mono, sr=SR, hop_length=HOP)
        bass = librosa.feature.chroma_cqt(y=self.mono, sr=SR, hop_length=HOP, fmin=librosa.note_to_hz("C1"), n_octaves=3)
        frames = librosa.time_to_frames(self.times, sr=SR, hop_length=HOP)
        self.F = self._per_beat(full, frames)
        self.B = self._per_beat(bass, frames)
        rms = librosa.feature.rms(y=self.mono, frame_length=2048, hop_length=HOP)[0]
        cen = librosa.feature.spectral_centroid(y=self.mono, sr=SR, hop_length=HOP)[0]
        self.R = self._per_beat(rms[None, :], frames)[:, 0]
        self.C = self._per_beat(cen[None, :], frames)[:, 0]
        sub = self.bar0 + np.arange(0, (n + 1) * SUB) * beat / SUB
        self.O = np.interp(sub, t, env)

    @staticmethod
    def _per_beat(feat: np.ndarray, frames: np.ndarray) -> np.ndarray:
        out = np.zeros((len(frames) - 1, feat.shape[0]))
        for i in range(len(frames) - 1):
            a, b = frames[i], max(frames[i] + 1, frames[i + 1])
            out[i] = feat[:, a:b].mean(1)
        return out

    def beat_of(self, seconds: float) -> int:
        return int(round((seconds - self.bar0) / self.beat))

    def score(self, i_s: int, i_e: int) -> dict:
        w = max(4, int(round(2.5 / self.beat)))
        n = len(self.F)
        pre_e, pre_s = slice(max(0, i_e - w), i_e), slice(max(0, i_s - w), i_s)
        post_s = slice(i_s, min(n, i_s + w))
        post_e = slice(i_e, min(n, i_e + w))
        have_post_e = (post_e.stop - post_e.start) >= max(2, w // 2)
        res = {}
        for name, M in (("full", self.F), ("bass", self.B)):
            pre = 0.6 * seqcos(M[pre_e], M[pre_s]) + 0.4 * cos(M[pre_e].mean(0), M[pre_s].mean(0))
            if have_post_e:
                m = min(post_e.stop - post_e.start, post_s.stop - post_s.start)
                post = 0.6 * seqcos(M[post_e][:m], M[post_s][:m]) + 0.4 * cos(M[post_e][:m].mean(0), M[post_s][:m].mean(0))
            else:
                post = pre  # the loop ends at the end of the audio: only the lead-in can be compared
            res[name] = 0.5 * (pre + post)
        harmony = 0.5 * (res["full"] + res["bass"])
        bpb = self.bpb
        join = 0.5 * (cos(self.F[i_e - bpb:i_e].mean(0), self.F[i_s:i_s + bpb].mean(0))
                      + cos(self.B[i_e - bpb:i_e].mean(0), self.B[i_s:i_s + bpb].mean(0)))
        nat = 0.5 * (cos(self.F[i_e - bpb:i_e].mean(0), self.F[i_e:i_e + bpb].mean(0))
                     + cos(self.B[i_e - bpb:i_e].mean(0), self.B[i_e:i_e + bpb].mean(0))) if have_post_e else join
        # rhythm: accent pattern of the bar before the end vs before the start
        a = self.O[(i_e - bpb) * SUB:i_e * SUB]
        b = self.O[(i_s - bpb) * SUB:i_s * SUB]
        rhythm = float(np.corrcoef(a, b)[0, 1]) if a.std() > 0 and b.std() > 0 and len(a) == len(b) else 0.0
        db = lambda x: 20 * np.log10(x + 1e-6)  # noqa: E731
        lev_e, lev_s = db(self.R[pre_e].mean()), db(self.R[post_s].mean())
        lev_diff = abs(lev_e - lev_s)
        cen_diff = abs(np.log2((self.C[pre_e].mean() + 1) / (self.C[post_s].mean() + 1)))
        length = (i_e - i_s) * self.beat
        level = max(0.0, 1 - lev_diff / 6) * 0.7 + max(0.0, 1 - cen_diff / 0.5) * 0.3
        span = min(1.0, length / 45)
        combined = 0.50 * harmony + 0.15 * max(0.0, join) + 0.10 * max(0.0, rhythm) + 0.15 * level + 0.10 * span
        return dict(start=round(float(self.times[i_s]), 3), end=round(float(self.times[i_e]), 3), length=round(length, 1),
                    harmony=round(harmony, 3), harmony_full=round(res["full"], 3), harmony_bass=round(res["bass"], 3),
                    join=round(join, 3), natural_join=round(nat, 3), rhythm=round(rhythm, 3),
                    level_diff_db=round(float(lev_diff), 2), centroid_diff_oct=round(float(cen_diff), 2),
                    combined=round(combined, 4))

    def at(self, start: float, end: float) -> dict:
        r = self.score(self.beat_of(start), self.beat_of(end))
        r["seam_ratio"] = self.seam(r["start"], r["end"])
        return r

    def seam(self, start: float, end: float) -> float:
        return master.seam(self.stereo[: int(end * master.RATE)], int(start * master.RATE))

    def find(self, top: int = 5, min_len: float = 20.0, max_len: float = 90.0, start_min: float | None = None,
             step_bars: int = 1, verify: int = 40) -> list[dict]:
        bpb = self.bpb
        first = start_min if start_min is not None else next((p["end"] for p in self.timeline if p["name"] == "intro"), 8.0)
        i0 = max(bpb * 2, int(np.ceil((first - self.bar0) / self.beat / bpb)) * bpb)
        last_end = int((self.total - 0.5 - self.bar0) / self.beat)
        cands = []
        for i_s in range(i0, last_end, bpb * step_bars):
            for i_e in range(i_s + int(min_len / self.beat) // bpb * bpb, min(last_end, i_s + int(max_len / self.beat)) + 1,
                             bpb * step_bars):
                if i_e > last_end or i_e - bpb < 0:
                    continue
                cands.append(self.score(i_s, i_e))
        cands.sort(key=lambda c: -c["combined"])
        out = []
        for c in cands[:verify]:
            c["seam_ratio"] = self.seam(c["start"], c["end"])
            c["rank_score"] = round(c["combined"] - 0.02 * max(0.0, c["seam_ratio"] - 2.0), 4)
            out.append(c)
        out.sort(key=lambda c: -c["rank_score"])
        picked: list[dict] = []  # drop near-duplicates (same start and an end within 2 bars)
        for c in out:
            if all(abs(c["start"] - p["start"]) > 2 * self.bar or abs(c["end"] - p["end"]) > 2 * self.bar for p in picked):
                picked.append(c)
            if len(picked) == top:
                break
        return picked


def render(track: Track, slot: dict, start: float, end: float, stem: str) -> Path:
    """What the player hears at the jump, as the game plays it: the last 8 s of the loop, then its first 8 s."""
    piece, loop = master.render(slot, track.take, start, end)
    a, b = int(loop["loopStart"] * master.RATE), int(loop["loopEnd"] * master.RATE)
    w = 8 * master.RATE
    audio = np.concatenate([piece[max(0, b - w):b], piece[a:a + w]])
    out = manifest.where("loops", f"{stem}.ogg")
    master.encode(audio, out, 0.7)
    return out


def analyse(slot: dict, take: str, top: int = 3, min_len: float = 20.0, max_len: float = 90.0) -> dict:
    """Find the best loops of a mastered take, write loops/<take>.json and an audition for each."""
    track = Track(take)
    best = track.find(top=top, min_len=min_len, max_len=max_len)
    for i, c in enumerate(best, 1):
        render(track, slot, c["start"], c["end"], f"{take}-cand{i}")
    report = {"take": take, "grid_strength": round(track.grid_strength, 2), "bar_seconds": round(track.bar, 3),
              "sections": [(p["name"], p["bars"]) for p in track.timeline], "candidates": best}
    manifest.where("loops", f"{take}.json").write_text(json.dumps(report, indent=1, default=float) + "\n")
    return report


def main() -> None:
    cmd, take = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]

    def option(flag: str, default):
        return type(default)(args[args.index(flag) + 1]) if flag in args else default

    track = Track(take)
    if cmd == "find":
        print(json.dumps(track.find(option("--top", 5), option("--min", 20.0), option("--max", 90.0)), indent=1))
    elif cmd == "score":
        print(json.dumps(track.at(float(args[0]), float(args[1])), indent=1))
    elif cmd == "render":
        found = manifest.slot_of(take)
        print(render(track, found[1], float(args[0]), float(args[1]), args[2]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
