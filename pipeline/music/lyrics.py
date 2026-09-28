#!/usr/bin/env python3
"""What a take sings (pipeline/music/README.md): Whisper's transcript of a song set against the lyrics it was given.

Nobody in the loop can hear, and a model can sing the melody beautifully while slurring the words, drop a line, or sing
a verse twice. So a song's takes are transcribed (faster-whisper large-v3 on the CPU, which leaves the GPU to the next
render) and scored by their word error rate: the edits that turn the lyrics into what was heard, over the lyrics'
length. Whisper is not given the lyrics as a prompt, so a take earns only the words it made clear. Singing is hard to
transcribe, so the rate is for comparing takes of one song, not an absolute grade: under 0.3 is clearly sung, over
0.6 is words lost.

    uv run --project pipeline python pipeline/music/lyrics.py <track> [<take>...]
"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRACKS = Path(__file__).with_name("tracks")
CACHE = ROOT / "pipeline" / "cache" / "music"
MODEL = "large-v3"


def words_of(text: str) -> list[str]:
    """Lowercase words without punctuation or section tags; `I'll` stays one word."""
    text = re.sub(r"\[[^\]]*\]", " ", text)
    return re.findall(r"[a-z']+", text.lower().replace("’", "'"))


def alignment(reference: list[str], heard: list[str]) -> list[tuple[str, str | None, str | None]]:
    """The cheapest edit script from the lyrics to what was heard: (op, lyric word, heard word), op one of
    ok, sub, del (a lyric word not heard), ins (a word heard that is not in the lyrics)."""
    rows, cols = len(reference) + 1, len(heard) + 1
    cost = [[0] * cols for _ in range(rows)]
    for i in range(rows):
        cost[i][0] = i
    for j in range(cols):
        cost[0][j] = j
    for i in range(1, rows):
        for j in range(1, cols):
            same = reference[i - 1] == heard[j - 1]
            cost[i][j] = min(cost[i - 1][j - 1] + (0 if same else 1), cost[i - 1][j] + 1, cost[i][j - 1] + 1)
    script: list[tuple[str, str | None, str | None]] = []
    i, j = len(reference), len(heard)
    while i or j:
        if i and j and cost[i][j] == cost[i - 1][j - 1] + (0 if reference[i - 1] == heard[j - 1] else 1):
            script.append(("ok" if reference[i - 1] == heard[j - 1] else "sub", reference[i - 1], heard[j - 1]))
            i, j = i - 1, j - 1
        elif i and cost[i][j] == cost[i - 1][j] + 1:
            script.append(("del", reference[i - 1], None))
            i -= 1
        else:
            script.append(("ins", None, heard[j - 1]))
            j -= 1
    return script[::-1]


def transcribe(audio: Path) -> list[dict]:
    """The words Whisper hears, with their times and its confidence in each."""
    from faster_whisper import WhisperModel

    model = WhisperModel(MODEL, device="cpu", compute_type="int8", cpu_threads=os.cpu_count() or 8)
    # No voice-activity filter (it drops sung passages as not speech), and no carrying of the previous text, which
    # makes Whisper loop a line over an instrumental stretch.
    segments, _ = model.transcribe(str(audio), language="en", beam_size=5, word_timestamps=True, vad_filter=False,
                                   condition_on_previous_text=False)
    return [{"word": word.word.strip(), "start": round(word.start, 2), "end": round(word.end, 2),
             "p": round(word.probability, 3)} for segment in segments for word in segment.words or []]


def check(track: str, take: str) -> dict:
    brief = json.loads((TRACKS / track / "brief.json").read_text())
    audio = CACHE / track / f"{take}.wav"
    cached = CACHE / track / f"{take}.lyrics.json"
    if cached.exists():
        heard = json.loads(cached.read_text())["heard"]
    else:
        heard = transcribe(audio)
    reference = words_of(brief["lyrics"])
    script = alignment(reference, words_of(" ".join(word["word"] for word in heard)))
    counts = {op: sum(1 for row in script if row[0] == op) for op in ("ok", "sub", "del", "ins")}
    report = {"take": take, "wer": round((counts["sub"] + counts["del"] + counts["ins"]) / max(1, len(reference)), 3),
              "lyric_words": len(reference), **counts,
              "transcript": " ".join(word["word"] for word in heard),
              "missed": [row[1] for row in script if row[0] == "del"],
              "misheard": [f"{row[1]} -> {row[2]}" for row in script if row[0] == "sub"],
              "heard": heard}
    cached.write_text(json.dumps(report, indent=2) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("track")
    parser.add_argument("takes", nargs="*")
    args = parser.parse_args()
    takes = args.takes or sorted(path.stem for path in (CACHE / args.track).glob("*.wav"))
    for take in takes:
        report = check(args.track, take)
        print(f"{take}: word error rate {report['wer']} ({report['ok']} of {report['lyric_words']} words heard, "
              f"{report['sub']} misheard, {report['del']} missed, {report['ins']} extra)")
        print(f"  heard: {report['transcript'][:600]}")


if __name__ == "__main__":
    main()
