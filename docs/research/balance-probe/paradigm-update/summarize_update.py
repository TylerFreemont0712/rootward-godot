"""Summarize the paired Paradigm Update probe and compare its exact seeds to the baseline.

Usage: python3 summarize_update.py [baseline-dir] [post-update-dir]
"""
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import sys
from statistics import mean


HERE = Path(__file__).parent
BASELINE = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "baseline"
UPDATED = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "post-update"
PARADIGMS = ["brute-force", "divide-conquer", "dynamic", "greedy", "search-index"]
SPLIT_CARDS = {
    path.stem
    for path in (HERE.parents[3] / "game/content/packs/core/programs/cards").glob("*.jsonc")
    if '"splits": true' in path.read_text()
}


def load_runs(folder: Path) -> list[dict]:
    return [
        json.loads(line)
        for path in sorted(folder.glob("runs_beginner_*.jsonl"))
        for line in path.read_text().splitlines()
        if line.strip()
    ]


def wilson(wins: int, count: int) -> list[float]:
    if not count:
        return [0.0, 1.0]
    z = 1.959963984540054
    rate = wins / count
    divisor = 1 + z * z / count
    center = (rate + z * z / (2 * count)) / divisor
    radius = z * math.sqrt(rate * (1 - rate) / count + z * z / (4 * count * count)) / divisor
    return [center - radius, center + radius]


def avg(runs: list[dict], key: str, default: float = 0.0) -> float:
    values = [float(run[key]) for run in runs if key in run]
    return mean(values) if values else default


def law_fired(run: dict, turn: dict) -> bool:
    # Recurse is expressed by card metadata (`splits`), not the unrelated `role` field. Older probe rows retain the
    # exact program sequence, so measure this law from the cast even when they predate the detector fix.
    if run.get("paradigm") == "divide-conquer":
        program = turn.get("program", [])
        return any(card in SPLIT_CARDS for card in program[:-1])
    return bool(turn.get("law_active", False))


def aggregate(runs: list[dict]) -> dict:
    wins = sum(run["status"] == "won" for run in runs)
    focus_runs: dict[str, list[dict]] = defaultdict(list)
    for run in runs:
        focus_runs[str(run.get("focus", "unknown"))].append(run)
    act1 = [
        fight
        for run in runs
        for fight in run.get("fights", [])
        if int(fight.get("layer", 0)) == 1 and fight.get("kind") == "fight"
    ]
    registries = [visit for run in runs for visit in run.get("registries", [])]
    fights = [fight for run in runs for fight in run.get("fights", [])]
    turn_runs = [
        (run, turn)
        for run in runs
        for fight in run.get("fights", [])
        for turn in fight.get("turns", [])
    ]
    issue_counts: Counter[str] = Counter()
    for run in runs:
        for layer in run.get("issue_rooms", []):
            issue_counts[str(layer)] += 1
    return {
        "runs": len(runs),
        "wins": wins,
        "win_rate": wins / len(runs) if runs else 0.0,
        "win_rate_wilson_95": wilson(wins, len(runs)),
        "focuses": {
            focus: {
                "runs": len(group),
                "wins": sum(run["status"] == "won" for run in group),
                "win_rate": sum(run["status"] == "won" for run in group) / len(group),
                "win_rate_wilson_95": wilson(sum(run["status"] == "won" for run in group), len(group)),
            }
            for focus, group in sorted(focus_runs.items())
        },
        "deck_share": {
            key: mean(float(run["deck_share"][key]) for run in runs if run.get("deck_share")) if runs else 0.0
            for key in ["own", "neutral", "other"]
        },
        "act1_fight_turns_mean": (
            sum(len(fight.get("turns", [])) for fight in act1) / len(act1) if act1 else 0.0
        ),
        "cycles_at_first_registry_mean": avg(
            [run for run in runs if "cycles_at_first_registry" in run], "cycles_at_first_registry"
        ),
        "runs_reaching_registry": sum("cycles_at_first_registry" in run for run in runs),
        "purchases_per_registry_mean": (
            sum(int(visit.get("purchases", 0)) for visit in registries) / len(registries) if registries else 0.0
        ),
        "script_uses_per_fight_mean": (
            sum(len(fight.get("script_uses", [])) for fight in fights) / len(fights) if fights else 0.0
        ),
        "law_activation_rate_mean": (
            sum(law_fired(run, turn) for run, turn in turn_runs) / len(turn_runs) if turn_runs else 0.0
        ),
        "issues_per_run_mean": mean(len(run.get("issue_rooms", [])) for run in runs) if runs else 0.0,
        "issues_by_layer": dict(sorted(issue_counts.items(), key=lambda item: int(item[0]))),
        "refusals": sum(len(run.get("refusals", [])) for run in runs),
        "cycles_earned_mean": avg(runs, "cycles_earned"),
        "cycles_spent_mean": avg(runs, "cycles_spent"),
        "statuses": dict(Counter(run.get("status", "unknown") for run in runs)),
    }


def main() -> None:
    before = load_runs(BASELINE)
    after = load_runs(UPDATED)
    before_by_seed = {run["seed"]: run for run in before}
    after_by_seed = {run["seed"]: run for run in after}
    paired = [
        (before_by_seed[seed], after_by_seed[seed])
        for seed in sorted(before_by_seed.keys() & after_by_seed.keys())
    ]
    by_paradigm = {
        paradigm: aggregate([run for run in after if run.get("paradigm") == paradigm])
        for paradigm in PARADIGMS
    }
    results = {
        "settings": {
            "language": "javascript",
            "difficulty": "beginner",
            "policy": "smart",
            "seeds_per_paradigm": 6,
            "focus_rotation": "seeds cycle through the three focuses in catalog order",
        },
        "paired_runs": len(paired),
        "paired_outcomes": {
            "baseline_wins": sum(old["status"] == "won" for old, _new in paired),
            "updated_wins": sum(new["status"] == "won" for _old, new in paired),
            "lost_to_won": sum(old["status"] != "won" and new["status"] == "won" for old, new in paired),
            "won_to_lost": sum(old["status"] == "won" and new["status"] != "won" for old, new in paired),
        },
        "overall": aggregate(after),
        "by_paradigm": by_paradigm,
        "targets": {
            "overall_win_rate_40_to_60_percent": 0.40 <= aggregate(after)["win_rate"] <= 0.60,
            "weakest_paradigm_at_least_30_percent": min(
                (summary["win_rate"] for summary in by_paradigm.values() if summary["runs"]), default=0.0
            ) >= 0.30,
            "strongest_paradigm_at_most_75_percent": max(
                (summary["win_rate"] for summary in by_paradigm.values() if summary["runs"]), default=0.0
            ) <= 0.75,
            "weakest_focus_at_least_25_percent": min(
                (focus["win_rate"] for summary in by_paradigm.values() for focus in summary["focuses"].values()),
                default=0.0,
            ) >= 0.25,
            "own_deck_share_at_least_50_percent": aggregate(after)["deck_share"]["own"] >= 0.50,
            "other_deck_share_10_to_25_percent": 0.10
            <= aggregate(after)["deck_share"]["other"]
            <= 0.25,
            "cycles_at_first_registry_150_to_250": 150
            <= aggregate(after)["cycles_at_first_registry_mean"]
            <= 250,
            "purchases_per_registry_1_5_to_2_5": 1.5
            <= aggregate(after)["purchases_per_registry_mean"]
            <= 2.5,
            "scripts_per_fight_0_3_to_0_8": 0.3
            <= aggregate(after)["script_uses_per_fight_mean"]
            <= 0.8,
            "laws_fire_at_least_60_percent": all(
                summary["law_activation_rate_mean"] >= 0.60
                for summary in by_paradigm.values()
                if summary["runs"]
            ),
            "act1_fights_2_to_4_turns": 2
            <= aggregate(after)["act1_fight_turns_mean"]
            <= 4,
            "single_card_ablation": "not measured by this observational probe",
        },
        "seed_groups": {
            paradigm: sorted(run["seed"] for run in after if run.get("paradigm") == paradigm)
            for paradigm in PARADIGMS
        },
    }
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
