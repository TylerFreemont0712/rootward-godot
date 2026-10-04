Bolts bogosort_plus(Bolts bolts, const Battle& battle) {
  // Bogosort: shuffle, check, repeat. A seeded LCG stands in for chance (the preview must equal the cast), and a
  // fixed number of tries stops the joke: after that, the arrangement with the fewest bolts out of place is kept.
  const int count = std::min<int>(7, bolts.size());
  unsigned seed = static_cast<unsigned>(battle.turn) * 7919u;
  for (int i = 0; i < count; i++) seed += static_cast<unsigned>(bolts[i].power) * static_cast<unsigned>(i + 1);
  Bolts order(bolts.begin(), bolts.begin() + count);
  Bolts best = order;
  int best_descents = -1;
  for (int attempt = 0; attempt < 120; attempt++) {
    int descents = 0;
    for (int i = 0; i + 1 < count; i++) {
      if (order[i].power > order[i + 1].power) descents++;
    }
    if (best_descents < 0 || descents < best_descents) {
      best = order;
      best_descents = descents;
    }
    if (descents == 0) break;
    for (int i = count - 1; i > 0; i--) {
      seed = seed * 1664525u + 1013904223u;
      const int j = static_cast<int>((seed >> 16) % static_cast<unsigned>(i + 1));
      std::swap(order[i], order[j]);
    }
  }
  for (size_t i = count; i < bolts.size(); i++) best.push_back(bolts[i]);
  return best;
}
