Bolts kadane(Bolts bolts, const Battle& battle) {
  // Kadane: the best run ending here is this bolt alone, or this bolt added to the best run ending just before; a
  // run whose score falls to zero or below is dropped. Scores are power minus 3, so weak bolts count against a run.
  // The best run seen fuses into one bolt of its whole power, 1 stronger for every bolt in it. O(n).
  if (bolts.empty()) return bolts;
  std::optional<int> best;
  int best_from = 0;
  int best_to = 0;
  int here = 0;
  int start = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (here <= 0) {
      here = 0;
      start = i;
    }
    here += bolts[i].power - 3;
    if (!best || here > *best) {
      best = here;
      best_from = start;
      best_to = i;
    }
  }
  const Bolts run(bolts.begin() + best_from, bolts.begin() + best_to + 1);
  Bolt strongest = run[0];
  for (const Bolt& bolt : run) {
    if (bolt.power > strongest.power) strongest = bolt;
  }
  int power = 0;
  for (const Bolt& bolt : run) power += bolt.power;
  strongest.power = power + static_cast<int>(run.size());
  Bolts fused(bolts.begin(), bolts.begin() + best_from);
  fused.push_back(strongest);
  fused.insert(fused.end(), bolts.begin() + best_to + 1, bolts.end());
  return fused;
}
