Bolts bogosort(Bolts bolts, const Battle& battle) {
  // A seeded LCG makes the preview match the cast. Check the initial order and up to 120 shuffles; keep the attempt
  // with the fewest descents. A completed sort gets a small volley bonus, while reaching the cap still rewards its
  // strongest bolt.
  const int count = std::min<int>(6, bolts.size());
  unsigned seed = static_cast<unsigned>(battle.turn) * 7919u;
  for (int i = 0; i < count; i++) seed += static_cast<unsigned>(bolts[i].power) * static_cast<unsigned>(i + 1);
  Bolts order(bolts.begin(), bolts.begin() + count);
  Bolts best = order;
  int best_descents = -1;
  bool sorted_successfully = false;
  for (int shuffles = 0; shuffles <= 120; shuffles++) {
    int descents = 0;
    for (int i = 0; i + 1 < count; i++) {
      if (order[i].power > order[i + 1].power) descents++;
    }
    if (best_descents < 0 || descents < best_descents) {
      best = order;
      best_descents = descents;
    }
    if (descents == 0) {
      sorted_successfully = true;
      break;
    }
    if (shuffles == 120) break;
    for (int i = count - 1; i > 0; i--) {
      seed = seed * 1664525u + 1013904223u;
      const int j = static_cast<int>((seed >> 16) % static_cast<unsigned>(i + 1));
      std::swap(order[i], order[j]);
    }
  }
  if (sorted_successfully) {
    for (Bolt& bolt : best) bolt.power += 1;
  } else if (!best.empty()) {
    auto strongest = std::max_element(best.begin(), best.end(), [](const Bolt& a, const Bolt& b) {
      return a.power < b.power;
    });
    strongest->power += 3;
  }
  for (size_t i = count; i < bolts.size(); i++) best.push_back(bolts[i]);
  return best;
}
