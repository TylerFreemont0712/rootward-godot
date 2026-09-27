"""Aggregates probe_balance.gd runs (JSONL) into the numbers the plan cites."""
import json
import sys
from collections import Counter, defaultdict
from statistics import mean, median

paths = sys.argv[1:]
runs = []
for p in paths:
    for line in open(p):
        line = line.strip()
        if line:
            runs.append(json.loads(line))

print(f"runs: {len(runs)}")
by_par = defaultdict(list)
for r in runs:
    by_par[r["paradigm"]].append(r)

print("\n== Outcome by paradigm ==")
print(f"{'paradigm':16} {'n':>3} {'won':>4} {'L1 boss':>8} {'L2 boss':>8} {'avg fights':>10} {'died at':>40}")
for par, rs in sorted(by_par.items()):
    won = sum(r["status"] == "won" for r in rs)
    beat1 = sum(any(f["kind"] == "boss" and f["layer"] == 1 and f["won"] for f in r["fights"]) for r in rs)
    beat2 = sum(any(f["kind"] == "boss" and f["layer"] == 2 and f["won"] for f in r["fights"]) for r in rs)
    deaths = Counter()
    for r in rs:
        if r["status"] == "lost" and r["fights"]:
            f = r["fights"][-1]
            deaths[f"L{f['layer']} {f['kind']}"] += 1
    print(f"{par:16} {len(rs):>3} {won:>4} {beat1:>8} {beat2:>8} {mean(r['fights_won'] for r in rs):>10.1f}   {dict(deaths)}")

print("\n== Where runs end (last fight) ==")
killers = Counter()
for r in runs:
    if r["status"] != "won" and r["fights"]:
        f = r["fights"][-1]
        killers[(f["layer"], f["kind"], "+".join(f["foes"]))] += 1
for k, v in killers.most_common(15):
    print(f"  {v:3}  L{k[0]} {k[1]:6} {k[2]}")

print("\n== Fights by layer and kind ==")
fights = defaultdict(list)
for r in runs:
    for f in r["fights"]:
        fights[(f["layer"], f["kind"])].append(f)
print(f"{'fight':12} {'n':>4} {'win%':>5} {'turns':>6} {'hp lost':>8} {'foe hp':>7} {'dmg/turn':>9} {'waste%':>7}")
for key in sorted(fights):
    fs = fights[key]
    turns = [len(f["turns"]) for f in fs]
    lost = [f["integrity_before"] - (f.get("integrity_after") or 0) for f in fs]
    hp = [sum(f["foe_hp"]) for f in fs]
    dmg = [t["damage"] for f in fs for t in f["turns"]]
    waste = sum(t["wasted"] for f in fs for t in f["turns"])
    tot = sum(dmg) + waste
    print(f"L{key[0]} {key[1]:8} {len(fs):>4} {100*sum(f['won'] for f in fs)/len(fs):>5.0f} {mean(turns):>6.1f} {mean(lost):>8.1f} {mean(hp):>7.0f} {mean(dmg):>9.1f} {100*waste/max(1,tot):>6.0f}%")

turns = [t for r in runs for f in r["fights"] for t in f["turns"]]
print(f"\n== Turns: {len(turns)} ==")
print(f"chosen program had a foe act first: {100*sum(t['faster']>0 for t in turns)/len(turns):.1f}% of turns")
print(f"chosen program timed out: {sum(t['timeout'] for t in turns)}")
cand = sum(t["candidates"] for t in turns)
print(f"candidates: {cand}, of which time out {100*sum(t['cand_timeouts'] for t in turns)/cand:.2f}%, have a faster foe {100*sum(t['cand_faster'] for t in turns)/cand:.1f}%")
print(f"programs with a sorted-lint warning chosen: {sum(t['lint']>0 for t in turns)}")
sizes = Counter(len(t["program"]) for t in turns)
print(f"program sizes: {dict(sorted(sizes.items()))}")
gain = [t["order_gain"] for t in turns if t["order_gain"] > 0.5]
print(f"turns where a reordered program beats the best dealt-order one: {100*len(gain)/len(turns):.1f}% (median gain {median(gain) if gain else 0:.1f})")
works = [t["work"] for t in turns]
print(f"work (ops) of chosen programs: median {median(works)}, p90 {sorted(works)[int(0.9*len(works))]}, max {max(works)}")

print("\n== Salvo in hand ==")
with_s = [t["damage"] for t in turns if "salvo" in t["hand"]]
without = [t["damage"] for t in turns if "salvo" not in t["hand"]]
print(f"damage/turn with salvo {mean(with_s):.1f} (n={len(with_s)}), without {mean(without):.1f} (n={len(without)})")
for layer in (1, 2, 3):
    lt = [t for r in runs for f in r["fights"] if f["layer"] == layer for t in f["turns"]]
    if not lt:
        continue
    ws = [t["damage"] for t in lt if "salvo" in t["hand"]]
    wo = [t["damage"] for t in lt if "salvo" not in t["hand"]]
    zero = sum(t["damage"] == 0 and t["block"] == 0 for t in lt)
    print(f"  L{layer}: with {mean(ws) if ws else 0:.1f} ({len(ws)}), without {mean(wo) if wo else 0:.1f} ({len(wo)}); turns doing nothing {100*zero/len(lt):.0f}%")

print("\n== Card play rate (chosen / in hand) ==")
in_hand = Counter()
played = Counter()
for t in turns:
    for c in set(t["hand"]):
        in_hand[c] += 1
    for c in set(t["program"]):
        played[c] += 1
for c, n in sorted(in_hand.items(), key=lambda kv: -played[kv[0]] / kv[1]):
    print(f"  {c:16} {100*played[c]/n:5.0f}%  (in hand {n})")

print("\n== Picks (taken) ==")
taken = Counter(p["took"] for r in runs for p in r["picks"])
print(dict(taken.most_common()))
print("\n== Relics held at end ==")
print(dict(Counter(x for r in runs for x in r["relics"]).most_common()))
