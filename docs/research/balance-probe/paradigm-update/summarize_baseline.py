"""Summarize the immutable Paradigm Update baseline using its original card metadata.

Usage: python3 summarize_baseline.py /tmp/rootward-paradigm-baseline baseline
Card shares use each card's declared paradigm (including upgraded cards), rather than
membership in draft pools: pools overlap and do not partition a deck.
"""
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
from statistics import mean
import sys


def jsonc(path):
    tokens = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', re.S)
    text = tokens.sub(lambda match: match[0] if match[0].startswith('"') else '', path.read_text())
    return json.loads(text)


def wilson(wins, count):
    z = 1.959963984540054
    rate = wins / count
    divisor = 1 + z * z / count
    center = (rate + z * z / (2 * count)) / divisor
    radius = z * math.sqrt(rate * (1 - rate) / count + z * z / (4 * count * count)) / divisor
    return [center - radius, center + radius]


def aggregate(runs, cards):
    shares = []
    fights = [fight for run in runs for fight in run['fights']]
    turns = [turn for fight in fights for turn in fight['turns']]
    for run in runs:
        counts = Counter('own' if cards[card] == run['paradigm'] else 'neutral' if cards[card] == 'neutral' else 'other' for card in run['deck'])
        shares.append({kind: counts[kind] / len(run['deck']) for kind in ['own', 'neutral', 'other']})
    act1 = [fight for fight in fights if fight['layer'] == 1 and fight['kind'] == 'fight']
    bosses1 = [fight for fight in fights if fight['layer'] == 1 and fight['kind'] == 'boss']
    wins = sum(run['status'] == 'won' for run in runs)
    return {
        'runs': len(runs), 'wins': wins, 'win_rate': wins / len(runs),
        'win_rate_wilson_95': wilson(wins, len(runs)),
        'final_deck_mean_shares': {kind: mean(share[kind] for share in shares) for kind in ['own', 'neutral', 'other']},
        'final_deck_mean_size': mean(len(run['deck']) for run in runs),
        'act1_fights': len(act1), 'act1_fight_turns_mean': mean(len(fight['turns']) for fight in act1),
        'act1_fight_hp_lost_mean': mean(fight['integrity_before'] - fight['integrity_after'] for fight in act1),
        'act1_boss_turns_mean': mean(len(fight['turns']) for fight in bosses1),
        'act1_boss_hp_lost_mean': mean(fight['integrity_before'] - fight['integrity_after'] for fight in bosses1),
        'turns': len(turns), 'empty_program_turn_rate': mean(not turn['program'] for turn in turns),
        'foe_first_turn_rate': mean(turn['faster'] > 0 for turn in turns),
        'reordering_improvement_turn_rate': mean(turn['order_gain'] > 0.5 for turn in turns),
        'chosen_timeouts': sum(turn['timeout'] for turn in turns),
        'refusals': sum(len(run['refusals']) for run in runs),
        'statuses': dict(Counter(run['status'] for run in runs)),
        'boss_clear_rates': {str(layer): mean(any(fight['layer'] == layer and fight['kind'] == 'boss' and fight['won'] for fight in run['fights']) for run in runs) for layer in range(1, 5)},
    }


if __name__ == '__main__':
    checkout = Path(sys.argv[1])
    folder = Path(sys.argv[2])
    cards = {data['id']: data.get('paradigm', 'neutral') for path in (checkout / 'game/content/packs/core/programs/cards').glob('*.jsonc') for data in [jsonc(path)]}
    runs = [json.loads(line) for path in sorted(folder.glob('runs_beginner_*.jsonl')) for line in path.read_text().splitlines() if line.strip()]
    by_paradigm = defaultdict(list)
    for run in runs:
        by_paradigm[run['paradigm']].append(run)
    report = {
        'baseline_commit': 'fb72306',
        'probe_sha256': hashlib.sha256((checkout / 'docs/research/balance-probe/probe_balance.gd').read_bytes()).hexdigest(),
        'settings': {'language': 'javascript', 'difficulty': 'beginner', 'policy': 'smart', 'picks': 'plain', 'seeds': 6, 'offset': 0, 'variants': []},
        'seeds': {paradigm: [run['seed'] for run in group] for paradigm, group in sorted(by_paradigm.items())},
        'overall': aggregate(runs, cards),
        'by_paradigm': {paradigm: aggregate(group, cards) for paradigm, group in sorted(by_paradigm.items())},
    }
    print(json.dumps(report, indent=2))
