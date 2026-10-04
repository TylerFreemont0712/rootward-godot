Bolts exhaustive_ward(Bolts bolts, const Battle& battle) {
  // Every subset of the first ten bolts as a bitmask (2^n of them): keep the one whose total reaches 12 with the
  // least to spare. Those become your block; the rest still fly. If none reaches 12, all ten guard.
  const Bolts pool(bolts.begin(), bolts.begin() + std::min<size_t>(bolts.size(), 10));
  const int n = static_cast<int>(pool.size());
  int best = -1;
  int best_total = -1;
  for (int mask = 1; mask < 1 << n; mask++) {
    int total = 0;
    for (int i = 0; i < n; i++) if ((mask >> i) & 1) total += pool[i].power;
    if (total >= 12 && (best_total < 0 || total < best_total)) {
      best = mask;
      best_total = total;
    }
  }
  if (best < 0) best = (1 << n) - 1;
  for (int i = 0; i < n; i++) if ((best >> i) & 1) bolts[i].block = true;
  return bolts;
}
