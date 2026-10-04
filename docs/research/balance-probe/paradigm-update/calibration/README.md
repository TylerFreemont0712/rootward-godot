# Calibration runs excluded from the final report

These exploratory runs are retained to make the probe changes and economy tuning traceable. None are used as the final
post-update comparison; see `../report.md` for the selected matched sample and its limits.

- `runs_*.jsonl` in this directory: ten early runs with initial cycle and price values, collected before the focus
  rotation and run protocol were settled. They motivated doubling cycle earnings and the card, relic, service and
  script prices while keeping the legendary relic at 450 cycles.
- `unbounded-limits/post-update/`: 27 rows from an interrupted experiment with the old exhaustive candidate policy.
  The runs exceeded the practical time budget and the five paradigm groups are incomplete. Do not aggregate them as
  a cohort.
- `../capped-baseline/`: an attempted immutable baseline where the sandbox runtime was unavailable in the archive.
  Its early losses and empty programs are invalid as gameplay observations.

The valid comparison uses `../paired-baseline/` and `../post-update/`: identical six seed positions for each of the
five paradigms, matched focus rotation, JavaScript/Beginner, and the same deterministic 128-candidate sampling rule.
