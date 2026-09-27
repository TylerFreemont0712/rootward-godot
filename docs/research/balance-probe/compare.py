"""One row per experiment: the numbers the roadmap's what-if table cites.

    python3 compare.py <folder of .jsonl runs>
"""
import glob
import json
import os
import sys
from statistics import mean

# The folder the runs were written to: baseline runs as runs_beginner_<paradigm>.jsonl, what-ifs as exp_<name>.jsonl.
SP = sys.argv[1] if len(sys.argv) > 1 else "."
# Each experiment's runs may be split over several files (one process per paradigm): exp_<name>.jsonl and
# exp_<name>_<paradigm>.jsonl. A run is deterministic, so a run found twice is the same run and is counted once.
experiments = [
    ("baseline (smart bot)", "runs_beginner_*.jsonl"),
    ("dealt-order bot", "exp_naive*.jsonl"),
    ("softer Golem (x0.5 off-pattern)", "exp_golem*.jsonl"),
    ("Salvo in draft pools", "exp_salvopool*.jsonl"),
    ("source-aware drafting", "exp_picksmart*.jsonl"),
    ("Salvo in pools + source-aware drafting", "exp_poolpicks*.jsonl"),
    ("seed of 3 bolts", "exp_seed3.jsonl exp_seed3_*.jsonl"),
    ("4 Salvos in the starting deck", "exp_sources4*.jsonl"),
    ("gentler HP curve (x1.8, x3.6)", "exp_curve*.jsonl"),
    ("4 Salvos + gentler curve", "exp_both*.jsonl"),
    ("seed of 3 bolts + gentler curve", "exp_s3c_*.jsonl"),
]


def load(patterns):
    runs = {}
    for pattern in patterns.split():
        for p in sorted(glob.glob(os.path.join(SP, pattern))):
            for line in open(p):
                if line.strip():
                    run = json.loads(line)
                    runs[(run["paradigm"], run["seed"])] = run
    return list(runs.values())


def pct(a, b):
    return f"{100 * a / b:.0f}%" if b else "-"


rows = []
for name, paths in experiments:
    runs = load(paths)
    if not runs:
        continue
    n = len(runs)
    won = sum(r["status"] == "won" for r in runs)
    b1 = sum(any(f["kind"] == "boss" and f["layer"] == 1 and f["won"] for f in r["fights"]) for r in runs)
    b2 = sum(any(f["kind"] == "boss" and f["layer"] == 2 and f["won"] for f in r["fights"]) for r in runs)
    turns = [t for r in runs for f in r["fights"] for t in f["turns"]]
    l1 = [f for r in runs for f in r["fights"] if f["layer"] == 1 and f["kind"] == "fight"]
    l1_turns = mean(len(f["turns"]) for f in l1) if l1 else 0
    l1_hp = mean(f["integrity_before"] - (f.get("integrity_after") or 0) for f in l1) if l1 else 0
    empty = sum(len(t["program"]) == 0 for t in turns)
    faster = sum(t["faster"] > 0 for t in turns)
    order = sum(t["order_gain"] > 0.5 for t in turns)
    by_par = {}
    for r in runs:
        by_par.setdefault(r["paradigm"], []).append(r["status"] == "won")
    with_salvo = [t["damage"] for t in turns if "salvo" in t["hand"]]
    without = [t["damage"] for t in turns if "salvo" not in t["hand"]]
    ratio = mean(with_salvo) / max(1.0, mean(without)) if with_salvo and without else 0.0
    worst = min(sum(v) / len(v) for v in by_par.values())
    best = max(sum(v) / len(v) for v in by_par.values())
    rows.append(
        (
            name,
            n,
            pct(won, n),
            pct(b1, n),
            pct(b2, n),
            f"{l1_turns:.1f}",
            f"{l1_hp:.1f}",
            f"{ratio:.0f}x",
            pct(empty, len(turns)),
            pct(faster, len(turns)),
            "-" if name.startswith("dealt-order") else pct(order, len(turns)),
            f"{100 * worst:.0f}-{100 * best:.0f}%",
        )
    )

head = ("experiment", "runs", "won", "beat boss 1", "beat boss 2", "act 1 turns", "act 1 HP lost", "Salvo in hand",
        "empty turns",
        "foe first", "reorder wins", "won, worst-best paradigm")
print("| " + " | ".join(head) + " |")
print("|" + "---|" * len(head))
for row in rows:
    print("| " + " | ".join(str(x) for x in row) + " |")
