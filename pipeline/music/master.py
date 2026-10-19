#!/usr/bin/env python3
"""Masters a performance for the game (pipeline/music/README.md): the take a track's brief picks becomes the file the
game plays, at the soundtrack's loudness and tone, looping where the score says.

  1. The grid: the take's own beat (a line fitted through its tracked beats, since a model asked for 132 bpm may play
     129), and where its first downbeat falls: the first strong onset, then confirmed against the score. Of the beats
     near it, the one from which the score's harmony, bar by bar, best matches what is heard (`analyze.adherence`) is
     bar 0's downbeat. That fit is also the take's "follows its score" number.
  2. The loop, from the brief (`loop: {from, to, occurrence}`): from the first bar of section `from` to the end of the
     `occurrence`-th section `to`, in the score's bars, so in the take's seconds. The file ends at the loop's end, and
     its last moments are crossfaded with the audio just before the loop's start, so the jump back is seamless (the game
     loops from `loopStart` to the file's end). A cue or a song has no loop: it is cut after its last sound and faded.
  3. Tone: a high-pass under the music, then shelves that correct a fault in the take's colour, never by more than
     6 dB: a boomy take (over 20% of its energy under 150 Hz) is thinned, a dark one (under 1.2% over 5 kHz) lifted, a
     harsh one (over 8%) tamed, and anything between is left as the model played it.
  4. Level: one gain to the target loudness, capped by the peak; a single gain, because a loop's end has to meet its
     start at the same level.
  5. Ogg Vorbis. The take the brief picks (`pick`) goes into game/assets/audio/ as the track's `out` file, with its loop
     into music.json. Any other take, and a bonus track (not in the game), is mastered beside its takes in the cache as
     `<take>.master.ogg`, with its seam clip `<take>.seam.ogg` for listening. `--dest DIR` writes the game's files to
     DIR instead, for a scratch listen.

    uv run --project pipeline python pipeline/music/master.py <track> [--take <take>] [--dest DIR]
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import library  # noqa: E402
import notation  # noqa: E402

RATE = analyze.FULL_SR
# What each kind of piece is levelled to. Music sits under the sound effects; a cue is heard alone, briefly; a bonus
# track is listened to for itself.
TARGETS = {"loop": {"lufs": -20.0, "peak": -1.5}, "cue": {"lufs": -17.0, "peak": -2.5},
           "bonus": {"lufs": -16.0, "peak": -1.0}}
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


def last_sound(stereo: np.ndarray, below_peak_db: float = 45.0) -> int:
    """The sample where the music has died away."""
    window = int(RATE * 0.05)
    mono = stereo.mean(axis=1)
    count = len(mono) // window
    levels = 10 * np.log10(np.mean(mono[: count * window].reshape(count, window) ** 2, axis=1) + 1e-12)
    loud = np.nonzero(levels > levels.max() - below_peak_db)[0]
    return int((loud[-1] + 1) * window) if len(loud) else len(mono)


def place(mono: np.ndarray, score: notation.Score) -> dict:
    """Where bar 0 of the score starts in the take, how long its bars are, and how well it follows the score there."""
    beat, phase = analyze.grid(mono, score.bpm)
    per_bar = float(score.metre / notation.Fraction(1, 4))
    bar_seconds = beat * per_bar
    timeline = notation.timeline(score)
    # The first bar that sounds: the score's leading silence is bar 0 (or more), the intro starts after it.
    opening = next(part["bar"] for part in timeline if part["name"] != "silence")
    onset = first_sound(mono)
    nearest = phase + round((onset - phase) / beat) * beat
    bars = notation.bars(score)
    chroma, times = analyze.chroma_of(mono)
    best = None
    # The onset can be a pickup, or a quiet first bar can hide under the threshold: try the beats around it.
    for shift in range(-int(per_bar) * 2, int(per_bar) * 2 + 1):
        downbeat = nearest + shift * beat
        start = downbeat - opening * bar_seconds
        fit = analyze.adherence(chroma, times, bars, start, bar_seconds)
        if best is None or fit["mean"] > best[2]["mean"]:
            best = (shift, start, fit)
    shift, start, fit = best
    return {"bar0": start, "bar_seconds": bar_seconds, "bpm": round(60.0 / beat, 2), "onset": round(onset, 3),
            "shift_beats": shift, "adherence": fit, "timeline": timeline}


def loop_points(score: notation.Score, loop: dict, placed: dict) -> tuple[float, float]:
    """The loop's start and end in the take's seconds: the brief's loop in score bars (notation.loop_bars), placed on
    the take by `place` (bar 0 at placed["bar0"], bars placed["bar_seconds"] long)."""
    first, end = notation.loop_bars(score, loop)
    return placed["bar0"] + first * placed["bar_seconds"], placed["bar0"] + end * placed["bar_seconds"]


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


def master(track: str, take: str | None = None, dest: Path | None = None) -> dict:
    """Master a take of a track (its brief's pick by default). Writes the game's file when the take is the picked one
    (into `dest` when given), else the take's master beside it; returns the report, which is also saved."""
    brief = library.brief(track)
    take = take or brief.get("pick")
    folder = library.track_takes_dir(track)
    if not take:
        names = library.takes(track)
        sys.exit(f"{track}: no take picked; set \"pick\" in its brief or pass --take, one of:\n  " + "\n  ".join(names))
    source = library.find_take(track, take)
    if source is None:
        sys.exit(f"{track}: no take {take} in {folder} (its takes: {', '.join(library.takes(track)) or 'none'})")
    score = notation.parse(library.score_text(track))
    kind = brief.get("kind", "loop")
    stereo, mono = analyze.load(source)
    placed = place(mono, score)
    report: dict = {"track": track, "take": take, "kind": kind, "bpm": placed["bpm"], "onset": placed["onset"],
                    "shift_beats": placed["shift_beats"], "adherence": placed["adherence"]}
    begin = max(0, int((placed["onset"] - 0.02) * RATE))
    stereo, report["tone"] = tone(stereo, mono)
    if kind == "loop":
        if not isinstance(brief.get("loop"), dict):
            sys.exit(f"{track}: a loop needs 'loop': {{from, to, occurrence}} in its brief")
        try:
            loop_seconds = loop_points(score, brief["loop"], placed)
            bars = notation.loop_bars(score, brief["loop"])
        except ValueError as error:
            sys.exit(f"{track}: {error}")
        loop_start, loop_end = (int(round(seconds * RATE)) for seconds in loop_seconds)
        if loop_end > len(stereo):
            sys.exit(f"{track}: the loop ends at {loop_end / RATE:.1f}s, after the take does ({len(stereo) / RATE:.1f}s)")
        piece = stereo[begin:loop_end].copy()
        a, b = loop_start - begin, loop_end - begin
        fade = min(int(CROSSFADE * RATE), a)
        ramp = np.linspace(0, np.pi / 2, fade, dtype=np.float32)[:, None]
        piece[b - fade: b] = piece[b - fade: b] * np.cos(ramp) + stereo[loop_start - fade: loop_start] * np.sin(ramp)
        piece, report["level"] = level(piece, TARGETS[kind])
        report["loop"] = {"loopStart": round(a / RATE, 7), "loopEnd": round(b / RATE, 7),
                          "seconds": round((b - a) / RATE, 2), "bars": list(bars)}
        report["seam"] = seam(piece, a)
        # The join as the game plays it, to listen to: the loop's last eight seconds, then its first eight.
        folder.mkdir(parents=True, exist_ok=True)
        encode(np.concatenate([piece[-8 * RATE:], piece[a: a + 8 * RATE]]), folder / f"{take}.seam.ogg")
    else:
        end = min(len(stereo), last_sound(stereo) + int(0.3 * RATE))
        piece = stereo[begin:end].copy()
        fade = min(int(1.0 * RATE), len(piece) // 4)
        piece[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None] ** 2
        piece, report["level"] = level(piece, TARGETS[kind])
    report["seconds"] = round(len(piece) / RATE, 2)
    # Only the take the brief picks goes into the game; any other is mastered beside its takes, to be listened to.
    to_game = kind != "bonus" and take == brief.get("pick")
    game_dir = dest or library.AUDIO
    folder.mkdir(parents=True, exist_ok=True)
    cached = folder / f"{take}.master.ogg"
    encode(piece, cached)  # always beside the takes, so the listening page plays it
    out = game_dir / f"{brief['out']}.ogg" if to_game else cached
    if to_game:
        encode(piece, out)
    report["file"] = str(out.relative_to(library.ROOT)) if out.is_relative_to(library.ROOT) else str(out)
    if kind == "loop" and to_game:
        loops_file = game_dir / "music.json"
        loops = json.loads(loops_file.read_text()) if loops_file.exists() else {}
        loops[brief["out"]] = {"loopStart": report["loop"]["loopStart"], "loopEnd": report["loop"]["loopEnd"]}
        loops_file.write_text(json.dumps(dict(sorted(loops.items())), indent=2) + "\n")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{take}.master.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("track")
    parser.add_argument("--take", help="the take to master (default: the brief's pick)")
    parser.add_argument("--dest", type=Path, help="write the game's files here instead of game/assets/audio")
    args = parser.parse_args()
    try:
        print(json.dumps(master(args.track, args.take, args.dest), indent=2))
    except library.TrackError as error:
        sys.exit(str(error))


if __name__ == "__main__":
    main()
