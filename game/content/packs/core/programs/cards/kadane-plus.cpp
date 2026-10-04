Bolts kadane_plus(Bolts bolts, const Battle& battle) {
  // Kadane: the best run ending here is this bolt alone, or this bolt added to the best run ending just before; a
  // run whose score falls to zero or below is dropped. Scores are power minus 3, so weak bolts count against a run.
  // The best run seen fuses into one bolt of its whole power, 2 stronger for every bolt in it. O(n).
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
  Bolt strongest = bolts[best_from];
  int power = 0;
  for (int i = best_from; i <= best_to; i++) {
    if (bolts[i].power > strongest.power) strongest = bolts[i];
    power += bolts[i].power;
  }
  strongest.power = power + 2 * (best_to - best_from + 1);
  Bolts fused(bolts.begin(), bolts.begin() + best_from);
  fused.push_back(strongest);
  fused.insert(fused.end(), bolts.begin() + best_to + 1, bolts.end());
  return fused;
}
