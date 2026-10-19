"""The planner's score: what YuE2GenerateABC wrote for a style and lyrics, read for its key, tempo and sections.

The planner chooses the piece's key, metre, tempo and form itself (the style words only nudge them), and the audio is
played from that score. So the score is the cheap preview of a take: a plan with the wrong key, a tempo outside the
slot's range or one section holding most of the bars can be re-rolled with another planner seed (`music.sh plan`)
before a GPU run is spent on the audio. The same score gives the loop finder its bar grid.

Only what those need is read: the header, the `% section` comments, and each voice's bar count. Notes are not parsed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from fractions import Fraction

NOTE_LETTER = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORD = re.compile(r'"[^"]*"')
INLINE = re.compile(r"\[[A-Z]:[^\]]*\]")
MULTI = re.compile(r"Z(?P<bars>\d*)")


@dataclass
class Section:
    name: str
    bars: dict[str, list[str]] = field(default_factory=dict)  # voice -> bar texts


@dataclass
class Plan:
    header: dict[str, str]
    sections: list[Section]
    complete: bool = True  # false when the score was cut by the token limit and the last bar was dropped

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
    def key(self) -> str:
        return self.header.get("K", "C").split()[0]

    @property
    def beats_per_bar(self) -> int:
        return int(self.metre / Fraction(1, 4))

    @property
    def bar_seconds(self) -> float:
        return float(self.metre / Fraction(1, 4)) * 60.0 / self.bpm


def clean(text: str) -> str:
    """The score as the parser takes it: a score cut by the token limit ends mid-bar, so the last unfinished line is
    dropped, and mid-score meter changes (the planner writes a few) are removed, since the bars after one are timed from
    the audio instead."""
    lines = text.rstrip().split("\n")
    while lines and not lines[-1].rstrip().endswith("|"):
        lines.pop()
    k = next((i for i, line in enumerate(lines) if line.startswith("K:")), None)
    if k is None:
        raise ValueError("the score has no K: line")
    return "\n".join(lines[: k + 1] + [line for line in lines[k + 1:] if not line.startswith("M:")]) + "\n"


def parse(text: str) -> Plan:
    complete = text.rstrip().endswith("|")
    header: dict[str, str] = {}
    sections: list[Section] = []
    voice = ""
    for raw in clean(text).splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("%"):
            sections.append(Section(line.lstrip("% ").strip().lower()))
            continue
        field_match = re.match(r"^([A-Za-z]):\s*(.*)$", line)
        if field_match and not sections:
            key, value = field_match.groups()
            if key != "V":
                header[key] = value
            continue
        if field_match and field_match.group(1) == "V":
            voice = field_match.group(2).split()[0]
            continue
        if not sections:
            sections.append(Section("untitled"))
        if field_match:  # a K: change inside the tune: not needed here
            continue
        bars = [bar.strip() for bar in line.split("|") if bar.strip()]
        sections[-1].bars.setdefault(voice, []).extend(bars)
    return Plan(header, sections, complete)


def bar_count(bar: str) -> int:
    """How many bars a bar entry stands for: `Z4` is four bars of rest, anything else is one."""
    multi = MULTI.fullmatch(INLINE.sub("", CHORD.sub("", bar)).strip())
    return int(multi.group("bars") or 1) if multi else 1


def section_bars(section: Section) -> int:
    counts = [sum(bar_count(bar) for bar in bars) for bars in section.bars.values()]
    return max(counts) if counts else 0


def timeline(plan: Plan) -> list[dict]:
    """Each section's name, first bar, bar count and start and end in seconds of the plan's own clock."""
    out, bar = [], 0
    for section in plan.sections:
        count = section_bars(section)
        out.append({"name": section.name, "bar": bar, "bars": count, "start": round(bar * plan.bar_seconds, 3),
                    "end": round((bar + count) * plan.bar_seconds, 3)})
        bar += count
    return out


# --- keys ----------------------------------------------------------------------------------------------------------

def key_parts(key: str) -> tuple[int, str] | None:
    """(tonic pitch class, "major"|"minor") of a key name as the planner writes it (Dm, D#m, Eb, F#, Am...)."""
    match = re.fullmatch(r"([A-G])([#b]?)(m|min|maj|dor|mix|lyd|phr|loc)?", key)
    if not match:
        return None
    pitch = (NOTE_LETTER[match.group(1)] + {"#": 1, "b": -1, "": 0}[match.group(2)]) % 12
    return pitch, "minor" if match.group(3) in ("m", "min", "dor", "phr", "loc") else "major"


def semitone_fix(key: str, accepted: list[str]) -> int | None:
    """The varispeed (in semitones) that would turn the planner's key into an accepted one: -1 or +1 when the key is a
    semitone away in the same mode (D#m -> Dm is -1), otherwise None."""
    mine = key_parts(key)
    if not mine:
        return None
    for wanted in accepted:
        theirs = key_parts(wanted)
        if theirs and theirs[1] == mine[1]:
            shift = (theirs[0] - mine[0] + 6) % 12 - 6
            if abs(shift) == 1:
                return shift
    return None


# --- ranking -------------------------------------------------------------------------------------------------------

def evaluate(text: str, spec: dict, cap: float) -> dict:
    """Score a plan against what the slot wants (lower penalty is better). `spec` is the slot's `plan`:
    {"keys": [accepted keys], "bpm": [low, high]}; both optional."""
    plan = parse(text)
    parts = [p for p in timeline(plan) if p["name"] != "silence"]
    total = parts[-1]["end"]
    bars = sum(p["bars"] for p in parts)
    share = max(p["bars"] for p in parts) / bars
    keys = spec.get("keys")
    low, high = spec.get("bpm", [0, 999])
    penalty = 0.0
    fix = None
    if keys and plan.key not in keys:
        fix = semitone_fix(plan.key, keys)
        penalty += 2.5 if fix else 5.0  # a semitone away is fixable in the master (varispeed); anything else is not
    if not low <= plan.bpm <= high:
        penalty += 3.0
    if total > cap * 1.6:
        penalty += (total / cap - 1.6) * 3 + 0.5  # far past the cap (a loop does not need the ending)
    if total < cap * 0.55:
        penalty += 1.5  # too short for a loop
    penalty += max(0.0, share - 0.5) * 6  # one section holding most of the bars: no structure to loop on
    penalty += max(0, 4 - len(parts)) * 0.7
    if not plan.complete:
        penalty += 1.0
    return {"key": plan.key, "bpm": plan.bpm, "metre": str(plan.metre), "total": round(total, 1),
            "sections": [(p["name"], p["bars"]) for p in parts], "longest_share": round(share, 2),
            "complete": plan.complete, "tune": fix or 0, "penalty": round(penalty, 2)}
