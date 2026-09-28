#!/usr/bin/env python3
"""The scores the music pipeline composes in (pipeline/music/README.md): ABC notation in the layout YuE2 reads, with
a `Vocal` voice that carries the chords (over rests in an instrumental, over the sung melody in a song) and an `Ins`
voice that carries the instrumental melody.

  - `check` proves a score is well formed before a GPU minute is spent on it: every bar of every voice the length the
    metre says (the commonest slip when writing by hand), both voices the same number of bars in every section, the
    sections named the way YuE2 was trained on, and only the note lengths its training scores contain;
  - `sung` counts the notes the Vocal voice sings in each section, to line the lyrics' syllables up with;
  - `canonical` is the score as YuE2 is given it: the spacing SheetSage2 writes (none inside a bar), no title;
  - `timeline` says where each section starts in seconds, which is where the loop points of the finished piece go;
  - `notes` lists the melody's pitches in time, for comparing a performance's chroma with what was written.

    uv run --project pipeline python pipeline/music/notation.py check|sung|timeline <score.abc>
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from fractions import Fraction
from pathlib import Path

SECTIONS = {"silence", "intro", "verse", "pre-chorus", "chorus", "bridge", "interlude", "outro", "break", "inst"}
NOTE = re.compile(r"(?P<acc>\^\^|__|\^|_|=)?(?P<pitch>[A-Ga-g])(?P<octave>[,']*)(?P<num>\d*)(?P<den>/\d*)?")
REST = re.compile(r"(?P<kind>[zx])(?P<num>\d*)(?P<den>/\d*)?")
MULTI = re.compile(r"Z(?P<bars>\d*)")
CHORD = re.compile(r'"[^"]*"')
INLINE = re.compile(r"\[[A-Z]:[^\]]*\]")
STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
# The lengths (in sixteenths) SheetSage2 writes a note or rest as; anything else it splits and ties (yue2.cpp's
# notation.h, not_split_duration), so a `z14` or a `c10` is a spelling YuE2 never saw in training.
LENGTHS = {1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48}
# The accidentals each key signature implies (sharps positive, flats negative), for the melody's pitches.
KEY_ACCIDENTALS = {
    "C": {}, "Am": {}, "G": {"F": 1}, "Em": {"F": 1}, "D": {"F": 1, "C": 1}, "Bm": {"F": 1, "C": 1},
    "A": {"F": 1, "C": 1, "G": 1}, "F#m": {"F": 1, "C": 1, "G": 1}, "E": {"F": 1, "C": 1, "G": 1, "D": 1},
    "F": {"B": -1}, "Dm": {"B": -1}, "Bb": {"B": -1, "E": -1}, "Gm": {"B": -1, "E": -1},
    "Eb": {"B": -1, "E": -1, "A": -1}, "Cm": {"B": -1, "E": -1, "A": -1},
    "Ab": {"B": -1, "E": -1, "A": -1, "D": -1}, "Fm": {"B": -1, "E": -1, "A": -1, "D": -1},
}


@dataclass
class Section:
    name: str
    bars: dict[str, list[str]] = field(default_factory=dict)  # voice -> bar texts
    keys: dict[str, dict[int, str]] = field(default_factory=dict)  # voice -> {bar index: the key from that bar on}


@dataclass
class Score:
    header: dict[str, str]
    sections: list[Section]

    @property
    def metre(self) -> Fraction:
        top, bottom = self.header.get("M", "4/4").split("/")
        return Fraction(int(top), int(bottom))

    @property
    def unit(self) -> Fraction:
        top, bottom = self.header.get("L", "1/16").split("/")
        return Fraction(int(top), int(bottom))

    @property
    def bpm(self) -> float:
        return float(self.header.get("Q", "1/4=120").split("=")[1])

    @property
    def bar_seconds(self) -> float:
        # Q is quarter notes a minute; a bar holds metre / (1/4) quarters.
        return float(self.metre / Fraction(1, 4)) * 60.0 / self.bpm


def parse(text: str) -> Score:
    """Header fields, then sections (`% name` comments) holding each voice's bars (`V: name` switches voice)."""
    header: dict[str, str] = {}
    sections: list[Section] = []
    voice = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("%"):
            sections.append(Section(line.lstrip("% ").strip().lower()))
            continue
        field_match = re.match(r"^([A-Za-z]):\s*(.*)$", line)
        if field_match and not sections:
            key, value = field_match.groups()
            if key == "V":
                continue  # the voice declarations of the header
            header[key] = value
            continue
        if field_match and field_match.group(1) == "V":
            voice = field_match.group(2).split()[0]
            continue
        if not sections:
            sections.append(Section("untitled"))
        if field_match:
            # A field inside the tune: SheetSage2 writes a key change as `K:` after each voice's `V:` line.
            if field_match.group(1) != "K":
                raise ValueError(f"a {field_match.group(1)}: field inside the score is not supported: {line}")
            sections[-1].keys.setdefault(voice, {})[len(sections[-1].bars.get(voice, []))] = field_match.group(2)
            continue
        bars = [bar.strip() for bar in line.split("|") if bar.strip()]
        sections[-1].bars.setdefault(voice, []).extend(bars)
    return Score(header, sections)


def tokens(bar: str) -> list[tuple[re.Match, Fraction, bool]]:
    """A bar's notes and rests in order: the match, its length in units of L, and whether it ties into the next."""
    body = INLINE.sub("", CHORD.sub("", bar))
    body = re.sub(r"[()~.]|!\w+!", "", body)
    out: list[tuple[re.Match, Fraction, bool]] = []
    position = 0
    while position < len(body):
        char = body[position]
        if char.isspace():
            position += 1
            continue
        if char == "-" and out:
            out[-1] = (out[-1][0], out[-1][1], True)
            position += 1
            continue
        match = NOTE.match(body, position) or REST.match(body, position)
        if not match:
            raise ValueError(f"cannot read {body[position:position + 8]!r} in bar {bar!r}")
        number = Fraction(int(match.group("num")) if match.group("num") else 1)
        denominator = match.group("den")
        if denominator:
            number /= int(denominator[1:]) if len(denominator) > 1 else 2
        out.append((match, number, False))
        position = match.end()
    return out


def bar_length(bar: str) -> Fraction | int:
    """A bar's length in units of L, or, for a multi-bar rest `Zn`, the negative count of bars it stands for."""
    multi = MULTI.fullmatch(INLINE.sub("", CHORD.sub("", bar)).strip())
    if multi:
        return -(int(multi.group("bars")) if multi.group("bars") else 1)
    return sum((length for _, length, _ in tokens(bar)), Fraction(0))


def check(score: Score) -> list[str]:
    """Every problem with the score, or none."""
    problems = []
    for field_name in ("M", "L", "Q", "K"):
        if field_name not in score.header:
            problems.append(f"header: no {field_name}:")
    per_bar = score.metre / score.unit
    sixteenths = score.unit == Fraction(1, 16)
    for section in score.sections:
        if section.name not in SECTIONS:
            problems.append(f"section {section.name!r} is not one YuE2 knows ({', '.join(sorted(SECTIONS))})")
        counts = {}
        for voice, bars in section.bars.items():
            count = 0
            for index, bar in enumerate(bars):
                try:
                    length = bar_length(bar)
                except ValueError as error:
                    problems.append(f"{section.name} {voice} bar {index + 1}: {error}")
                    continue
                if isinstance(length, int) and length < 0:
                    count += -length
                    continue
                count += 1
                if length != per_bar:
                    problems.append(f"{section.name} {voice} bar {index + 1} is {length} units, not {per_bar}: {bar}")
                odd = [match.group(0) for match, value, _ in tokens(bar) if sixteenths and value not in LENGTHS]
                if odd:
                    problems.append(f"{section.name} {voice} bar {index + 1}: {' '.join(odd)} is a length YuE2 never "
                                    f"saw; split it and tie (14 = 12 + 2): {bar}")
            counts[voice] = count
        if len(set(counts.values())) > 1:
            problems.append(f"{section.name}: the voices disagree on its length {counts}")
    return problems


def section_bars(section: Section) -> int:
    lengths = []
    for bars in section.bars.values():
        lengths.append(sum(-bar_length(bar) if isinstance(bar_length(bar), int) and bar_length(bar) < 0 else 1
                           for bar in bars))
    return max(lengths) if lengths else 0


def timeline(score: Score) -> list[dict]:
    """Each section's name, first bar, bar count, and start and end in seconds from the score's first beat."""
    out, bar = [], 0
    for section in score.sections:
        count = section_bars(section)
        out.append({"name": section.name, "bar": bar, "bars": count,
                    "start": round(bar * score.bar_seconds, 3), "end": round((bar + count) * score.bar_seconds, 3)})
        bar += count
    return out


def notes(score: Score, voice: str = "Ins") -> list[tuple[float, float, int]]:
    """The voice's notes as (start seconds, length seconds, pitch class), rests left out."""
    signature = KEY_ACCIDENTALS.get(score.header.get("K", "C").split()[0], {})
    unit_seconds = float(score.unit / Fraction(1, 4)) * 60.0 / score.bpm
    out: list[tuple[float, float, int]] = []
    clock = 0.0
    for section in score.sections:
        changes = section.keys.get(voice, {})
        for index, bar in enumerate(section.bars.get(voice, []) or []):
            if index in changes:
                signature = KEY_ACCIDENTALS.get(changes[index].split()[0], {})
            length = bar_length(bar)
            if isinstance(length, int) and length < 0:
                clock += -length * score.bar_seconds
                continue
            accidentals: dict[str, int] = {}
            for match, value, _ in tokens(bar):
                seconds = float(value) * unit_seconds
                if "pitch" in match.re.groupindex:
                    letter = match.group("pitch").upper()
                    acc = match.group("acc")
                    if acc:
                        accidentals[letter] = {"^": 1, "^^": 2, "_": -1, "__": -2, "=": 0}[acc]
                    shift = accidentals.get(letter, signature.get(letter, 0))
                    out.append((round(clock, 4), round(seconds, 4), (STEPS[letter] + shift) % 12))
                clock += seconds
    return out


def chord_classes(symbol: str) -> set[int]:
    """The pitch classes of a chord symbol as the scores write them: a root, then m, dim, aug, sus2, sus4, 7, maj7."""
    match = re.match(r"([A-G])([#b]?)(.*)", symbol)
    if not match:
        return set()
    root = (STEPS[match.group(1)] + {"#": 1, "b": -1, "": 0}[match.group(2)]) % 12
    quality = match.group(3)
    if quality.startswith("dim"):
        shape = [0, 3, 6]
    elif quality.startswith("aug") or quality.startswith("+"):
        shape = [0, 4, 8]
    elif quality.startswith("sus2"):
        shape = [0, 2, 7]
    elif quality.startswith("sus"):
        shape = [0, 5, 7]
    elif quality.startswith("m") and not quality.startswith("maj"):
        shape = [0, 3, 7]
    else:
        shape = [0, 4, 7]
    if "maj7" in quality:
        shape.append(11)
    elif "7" in quality:
        shape.append(10)
    return {(root + step) % 12 for step in shape}


def bars(score: Score) -> list[dict]:
    """The score bar by bar, both voices together: its section, the chords written over it, and the notes sounding
    in it as (pitch class, length in units of L). What a performance of the bar should hold, for `analyze.adherence`."""
    out: list[dict] = []
    signatures = {voice: KEY_ACCIDENTALS.get(score.header.get("K", "C").split()[0], {}) for voice in ("Vocal", "Ins")}
    for section in score.sections:
        start = len(out)
        for voice, voice_bars in section.bars.items():
            changes = section.keys.get(voice, {})
            index = start
            for position, bar in enumerate(voice_bars):
                if position in changes:
                    signatures[voice] = KEY_ACCIDENTALS.get(changes[position].split()[0], {})
                length = bar_length(bar)
                rest = isinstance(length, int) and length < 0
                for _ in range(-length if rest else 1):
                    while len(out) <= index:
                        out.append({"section": section.name, "chords": [], "notes": []})
                    if not rest:
                        entry = out[index]
                        entry["chords"] += [symbol.strip('"') for symbol in CHORD.findall(bar)]
                        accidentals: dict[str, int] = {}
                        for match, value, _ in tokens(bar):
                            if "pitch" in match.re.groupindex:
                                letter = match.group("pitch").upper()
                                if match.group("acc"):
                                    accidentals[letter] = {"^": 1, "^^": 2, "_": -1, "__": -2, "=": 0}[match.group("acc")]
                                shift = accidentals.get(letter, signatures[voice].get(letter, 0))
                                entry["notes"].append(((STEPS[letter] + shift) % 12, float(value)))
                    index += 1
    return out


def sung(score: Score, voice: str = "Vocal") -> list[tuple[str, int]]:
    """Each section and the notes its voice sings: one syllable each, a tied note continuing the one before."""
    out: list[tuple[str, int]] = []
    tied = False
    for section in score.sections:
        count = 0
        for bar in section.bars.get(voice, []) or []:
            if isinstance(bar_length(bar), int):
                continue
            for match, _, ties in tokens(bar):
                if "pitch" in match.re.groupindex:
                    count += 0 if tied else 1
                    tied = ties
                else:
                    tied = False
        out.append((section.name, count))
    return out


def canonical(text: str) -> str:
    """The score as YuE2 is given it, in the form SheetSage2 writes the scores it was trained on: no title, and the
    notes of a bar written without spaces (`c4G2c2`, not `c4 G2c2`); the BPE reads a space as a token of its own."""
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("T:"):
            out.append("T:")
        elif line.startswith("%") or re.match(r"^[A-Za-z]:", line):
            out.append(line)
        else:
            out.append(re.sub(r"\s+", "", line))
    return "\n".join(out) + "\n"


def main() -> None:
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "sung", "timeline"):
        sys.exit(__doc__)
    score = parse(Path(sys.argv[2]).read_text())
    if sys.argv[1] == "check":
        problems = check(score)
        for problem in problems:
            print(problem)
        total = sum(section_bars(section) for section in score.sections)
        print(f"{'ok' if not problems else 'broken'}: {total} bars, {total * score.bar_seconds:.1f}s at {score.bpm:g} bpm")
        sys.exit(1 if problems else 0)
    if sys.argv[1] == "sung":
        for name, count in sung(score):
            if count:
                print(f"{name:12} {count} notes")
        return
    for part in timeline(score):
        print(part)


if __name__ == "__main__":
    main()
