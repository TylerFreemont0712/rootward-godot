"""One row per foe HP curve (or any other setting): the numbers ADR-0016 cites, beside stage 1's targets.

    python3 curves.py "x2.4, x3.6, x4.6=/tmp/probe/curve_a" "the same, ward x0.5=/tmp/probe/curve_b" ...

Each argument is a label and a folder of runs_beginner_<paradigm>.jsonl files, one experiment each.
"""
import collections
import glob
import json
import os
import sys
from statistics import mean


def load(folder):
    runs = {}
    for p in sorted(glob.glob(os.path.join(folder, "runs_beginner_*.jsonl"))):
        for line in open(p):
            if line.strip():
                run = json.loads(line)
                runs[(run["paradigm"], run["seed"])] = run
    return list(runs.values())


def pct(a, b):
    return f"{100 * a / b:.0f}%" if b else "-"


def fights(runs, layer, kind):
    """Turns and Integrity lost in the fights of one kind on one layer: "1.5, 1.2"."""
    found = [f for r in runs for f in r["fights"] if f["layer"] == layer and f["kind"] == kind]
    if not found:
        return "-"
    lost = mean(f["integrity_before"] - (f.get("integrity_after") or 0) for f in found)
    return f"{mean(len(f['turns']) for f in found):.1f}, {lost:.1f}"


def beat_boss(runs, layer):
    return sum(any(f["kind"] == "boss" and f["layer"] == layer and f["won"] for f in r["fights"]) for r in runs)


def lost_to(runs):
    """The foes that ended the lost runs, most often first: "deadlock-golem 10, root-daemon 3"."""
    ends = collections.Counter()
    for run in runs:
        if run["status"] != "won" and run["fights"] and not run["fights"][-1].get("won"):
            ends[" + ".join(run["fights"][-1]["foes"])] += 1
    return ", ".join(f"{foes} {n}" for foes, n in ends.most_common(3))


print(
    "| setting | runs | won | worst-best paradigm | beat boss 1, 2 | act 1 fights: turns, HP lost"
    " | act 1 boss: turns, HP lost | Salvo in hand | empty turns | foe first | reorder wins | lost most to |"
)
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for arg in sys.argv[1:]:
    label, folder = arg.rsplit("=", 1)
    runs = load(folder)
    if not runs:
        continue
    n = len(runs)
    by = collections.defaultdict(list)
    for r in runs:
        by[r["paradigm"]].append(r["status"] == "won")
    rates = [sum(v) / len(v) for v in by.values()]
    turns = [t for r in runs for f in r["fights"] for t in f["turns"]]
    salvo = [t["damage"] for t in turns if "salvo" in t["hand"]]
    other = [t["damage"] for t in turns if "salvo" not in t["hand"]]
    empty = sum(len(t["program"]) == 0 for t in turns)
    first = sum(t["faster"] > 0 for t in turns)
    # The dealt-order bot weighs one program a turn (its own), so it has no reordering to compare.
    compared = any(t["candidates"] > 1 for t in turns)
    order = pct(sum(t["order_gain"] > 0.5 for t in turns), len(turns)) if compared else "-"
    print(
        f"| {label} | {n} | {pct(sum(r['status'] == 'won' for r in runs), n)}"
        f" | {100 * min(rates):.0f}-{100 * max(rates):.0f}% | {pct(beat_boss(runs, 1), n)}, {pct(beat_boss(runs, 2), n)}"
        f" | {fights(runs, 1, 'fight')} | {fights(runs, 1, 'boss')} | {mean(salvo) / max(1, mean(other)):.1f}x"
        f" | {pct(empty, len(turns))} | {pct(first, len(turns))} | {order} | {lost_to(runs)} |"
    )
