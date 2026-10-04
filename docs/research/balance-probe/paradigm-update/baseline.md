# Paradigm Update baseline (slice 0)

Measured on 2026-10-04 from detached commit `fb72306` in `/tmp/rootward-paradigm-baseline`.
All game code, content and the probe came from that checkout; implementation edits in the main workspace did not enter these runs.
Godot 4.7.2; Beginner; JavaScript; smart policy; plain drafting; six seeds per paradigm; offset 0; no variants.

The unchanged probe produced 30 unique runs: 12 won, 17 lost and one abandoned. Overall win rate is **40.0%** (95% Wilson interval **24.6–57.7%**).
Six runs per paradigm are a reproducible comparison set, with broad uncertainty; these estimates do not establish that balance targets hold with 95% confidence.

## Measured results

| Paradigm | Won | Win rate | 95% Wilson interval | Own deck | Neutral deck | Other deck | Act 1 fight turns |
|---|---:|---:|---:|---:|---:|---:|---:|
| brute-force | 3/6 | 50.0% | 18.8%–81.2% | 22.5% | 45.0% | 32.5% | 1.56 |
| divide-conquer | 3/6 | 50.0% | 18.8%–81.2% | 28.5% | 48.2% | 23.3% | 1.38 |
| dynamic | 1/6 | 16.7% | 3.0%–56.4% | 23.4% | 51.1% | 25.6% | 1.36 |
| greedy | 1/6 | 16.7% | 3.0%–56.4% | 32.7% | 42.8% | 24.5% | 1.50 |
| search-index | 4/6 | 66.7% | 30.0%–90.3% | 31.8% | 40.1% | 28.2% | 1.40 |
| **Overall** | **12/30** | **40.0%** | **24.6%–57.7%** | **27.7%** | **45.4%** | **26.8%** | **1.44** |

Deck shares count copies of every card remaining at the end of a run, wins and non-wins alike.
A card's declared `paradigm` classifies it as own, neutral or other; upgraded cards retain their declaration.
The table averages per-run proportions, giving each run equal weight. Membership in overlapping draft pools is not used.

| Other recorded metric | Baseline |
|---|---:|
| Final deck size, mean | 35.83 |
| Act 1 ordinary fights recorded | 135 |
| Act 1 ordinary fight Integrity lost, mean | 1.56 |
| Act 1 guardian turns, mean | 3.50 |
| Act 1 guardian Integrity lost, mean | 7.70 |
| Recorded turns | 1743 |
| Empty programs | 4.9% of recorded turns |
| Foe acted before program | 17.6% of recorded turns |
| Reordering improved value by >0.5 | 45.7% of recorded turns |
| Chosen timeouts in recorded fights | 0 |
| Command refusals | 0 |
| Cleared guardian 1 | 100.0% of runs |
| Cleared guardian 2 | 86.7% of runs |
| Cleared guardian 3 | 60.0% of runs |
| Cleared guardian 4 | 40.0% of runs |

Against B13: overall wins are at the lower target boundary. Greedy and Dynamic Programming are below the 30% weakest-paradigm target; own-card shares are below 50%, other-card shares exceed 25% overall, and Act 1 ordinary fights remain below two turns.

Focus win rates, Registry wallet/purchases, script usage and law activation are **not applicable** to this pre-update build.
A causal 20-point single-card effect cannot be inferred from these observational runs; paired card ablations are needed for that test.

## Probe limitations preserved

`greedy-4~0` was abandoned on layer 2 at the probe’s 40-turn stalemate cap. It counts as a non-win.
The unchanged probe omits an unfinished fight from `report.fights` when abandoning; turn-based aggregates therefore cover only its recorded completed fights.
The smart bot and old research probe also predate the full guardian/import/fight-state execution contract: they use a basic sandbox input rather than `SpellRuns.input_for`.
These are limits of the requested unchanged baseline; the slice-13 probe must record any policy/execution changes and distinguish them from game balance changes.
Wall-clock `seconds` are retained for reproducibility but are not performance claims: the workers and quality checks ran concurrently.

## Exact paired seeds

- **brute-force**: `brute-force-0~2`, `brute-force-1~0`, `brute-force-2~0`, `brute-force-3~1`, `brute-force-4~0`, `brute-force-5~0`.
- **divide-conquer**: `divide-conquer-0~2`, `divide-conquer-1~0`, `divide-conquer-2~1`, `divide-conquer-3~0`, `divide-conquer-4~0`, `divide-conquer-5~1`.
- **dynamic**: `dynamic-0~0`, `dynamic-1~2`, `dynamic-2~3`, `dynamic-3~0`, `dynamic-4~0`, `dynamic-5~0`.
- **greedy**: `greedy-0~0`, `greedy-1~3`, `greedy-2~0`, `greedy-3~0`, `greedy-4~0`, `greedy-5~1`.
- **search-index**: `search-index-0~0`, `search-index-1~0`, `search-index-2~0`, `search-index-3~1`, `search-index-4~0`, `search-index-5~1`.

Reuse these exact strings after the update. `offset=0` chooses bases 0–5 and `seed_for` appends the first suffix that offers the requested paradigm.

## Baseline quality checks

- Full tests passed: 438/438 cases, 66/66 suites, zero errors, failures, skips or orphans; `XDG_DATA_HOME=/tmp/rootward-paradigm-baseline-test-data scripts/test.sh`.
- Lint passed: 234 GDScript files unchanged by formatter.
- Full content validation passed: 77 Spellforge shards, 139 program cards; 375 worked examples in each language; zero errors or warnings.
- Locale command exited 0: 808/808 content strings and 466/466 interface strings translated. It reports 135/137 rule sentence keys; the two `%s%s takes ...` formats are the known line-by-line cases documented in ADR-0047.
- The initial full test run shared the sandbox job directory with probe workers and failed only the cleanup job-count assertion. All 23 sandbox tests, then all 438 tests, passed after isolating `XDG_DATA_HOME`; no inherited failing test remains.

Quality summaries and the initial contention record are under [baseline/](baseline/). No game code or content changed in the baseline checkout.

## Reproduce

Create a detached checkout of `fb72306`, install its sandbox runtimes, and run from that checkout:

```bash
for paradigm in greedy brute-force dynamic search-index divide-conquer; do
  godot --headless --path game -s "$PWD/docs/research/balance-probe/probe_balance.gd" -- \
    paradigms="$paradigm" seeds=6 offset=0 difficulty=beginner policy=smart \
    out="/tmp/runs_beginner_${paradigm}.jsonl" < /dev/null
done
```

Use fresh output paths: the probe appends JSONL. Summarize preserved runs against original card metadata:

```bash
python3 docs/research/balance-probe/paradigm-update/summarize_baseline.py \
  /tmp/rootward-paradigm-baseline docs/research/balance-probe/paradigm-update/baseline
```

Original probe SHA-256: `3319a62930ce42e7784ec7fdd4fb97b0e848c8ce1789dd8135657d645c324c18`.
Raw runs and checksums are preserved under [baseline/](baseline/); [baseline.json](baseline.json) contains the settings, exact seeds, intervals and aggregates.
