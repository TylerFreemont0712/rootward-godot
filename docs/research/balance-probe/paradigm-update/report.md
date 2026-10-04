# Paradigm Update paired balance report

**Protocol:** 30 matched seeds, six for each paradigm; Beginner, JavaScript, smart policy; the same seed positions and
128-candidate program sampler before and after. Focuses rotate in catalog order in the updated game. The bot uses the
real fight and run rules, but chooses rooms and cards with a simple policy, takes the first affordable Registry offer
in its priority order, takes script drops, and leaves Issues without taking an effect. See the [probe guide](../README.md)
for the candidate sampling and resource limits.

**Selected comparison:** `paired-baseline/` is an immutable checkout at `fb72306` rerun with the same bounded probe
policy as the updated game. It completed 30/30 runs at 10 wins (33.3%). The updated sample completed 30/30 at 12 wins
(40.0%): seven matched seeds changed from loss to win and five from win to loss. Wilson 95% intervals are 19.2–51.2%
before and 24.6–57.7% after. The net change is two wins in a 30-run sample, so it does not establish a reliable
win-rate increase.

The earlier `baseline.md` records 12/30 wins using the original, much larger exhaustive candidate evaluation. That
number is useful historical context but is not a controlled comparison with the 128-candidate updated probe. The
paired baseline and current results both use the same sampler and exact seed positions.

## Outcomes by paradigm

| Paradigm | Paired baseline wins | Updated wins | Updated law activation |
|---|---:|---:|---:|
| Brute Force | 2/6 | 3/6 | 29.3% |
| Divide & Conquer | 2/6 | 5/6 | 68.9% |
| Dynamic Programming | 3/6 | 4/6 | 43.3% |
| Greedy | 2/6 | 0/6 | 25.8% |
| Search & Index | 1/6 | 0/6 | 16.4% |

Overall win rate meets B13's 40–60% target. The strongest paradigm is above its 75% ceiling; Greedy and Search & Index
are below the 30% floor, and the worst focus rate is 0% in the observed sample. Divide & Conquer is the only law above
the 60% activation target. With six seeds per paradigm and two seeds per focus, these subgroup rates are noisy and
should guide the next targeted balance pass rather than be treated as stable population estimates.

## Economy, deck, and fight measures

| Measure | Updated result | B13 target | Result |
|---|---:|---:|---|
| Own-paradigm share of final deck | 68.3% | ≥50% | met |
| Other-paradigm share | 9.4% | 10–25% | just below |
| Cycles at first Registry | 178.1 mean across 30 runs | 150–250 | met |
| Purchases per Registry | 2.00 | 1.5–2.5 | met |
| Scripts used per fight | 0.50 | 0.3–0.8 | met |
| Act 1 ordinary fights | 1.56 turns mean | 2–4 | below |
| Issues visited | 3.10 per run mean | about 2–3 | slightly above |

The economy change doubled cycle payouts and the relevant card, relic, service, and script prices, keeping the legendary
Registry relic at 450 cycles. The resulting first-Registry wallet and purchase rate meet their targets. The other-card
share misses the lower bound by 0.6 percentage points; B14's requested 50/30/20 reward shares remain in the data.

## Targets left open

- Tune Greedy and Search & Index upward and bring Divide & Conquer below the observed 75% ceiling.
- Improve law activation for Brute Force, Dynamic, Greedy, and Search & Index; their measured rates are under 60%.
- Lengthen early ordinary fights toward 2–4 turns while checking the effect on weak paradigms.
- Keep the requested 50/30/20 reward weights, then use a larger run set to see whether the 9.4% other-card share is
  persistent.
- Run controlled, one-card-at-a-time ablations before making a causal claim about a card moving a paradigm by 20
  percentage points. This observational run set does not measure that target.

## Reproduction

Raw JSONL results and machine summaries are in `paired-baseline/` and `post-update/`. The immutable baseline checkout
is `/tmp/rootward-paradigm-baseline-capped` at `fb72306`. Summaries can be regenerated with:

```sh
python3 docs/research/balance-probe/paradigm-update/summarize_baseline.py \
  /tmp/rootward-paradigm-baseline-capped \
  docs/research/balance-probe/paradigm-update/paired-baseline
python3 docs/research/balance-probe/paradigm-update/summarize_update.py \
  docs/research/balance-probe/paradigm-update/paired-baseline \
  docs/research/balance-probe/paradigm-update/post-update
```

The early ten-run economy calibration, invalid archived-runtime attempt, and incomplete exhaustive experiment are
preserved and explicitly excluded under `calibration/README.md`.
