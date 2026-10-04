Bolts meet_in_the_middle_plus(Bolts bolts, const Battle& battle) {
  // Meet in the middle: Exhaustive Kill tries all 2^n subsets. Split the bolts in two halves instead, list every
  // subset sum of each (2^(n/2) each), sort one list, and binary-search it for the partner of every sum of the other.
  // It finds the same subset, the smallest total that kills the front foe, with the square root of the work.
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  const int need = foes[0].hp + foes[0].shield;
  const int count = std::min<int>(16, bolts.size());
  const int half = count / 2;
  auto sums = [&](int from, int to, int shift) {
    std::vector<std::pair<int, int>> found = {{0, 0}};
    for (int k = from; k < to; k++) {
      const size_t size = found.size();
      for (size_t n = 0; n < size; n++) {
        found.push_back({found[n].first + bolts[k].power, found[n].second | (1 << (shift + k - from))});
      }
    }
    return found;
  };
  const auto low = sums(0, half, 0);
  auto high = sums(half, count, half);
  std::sort(high.begin(), high.end());
  int best_total = 0;
  int best_mask = -1;
  for (const auto& [total, mask] : low) {
    size_t lo = 0;
    size_t hi = high.size();
    while (lo < hi) {
      const size_t mid = (lo + hi) / 2;
      if (high[mid].first < need - total) lo = mid + 1;
      else hi = mid;
    }
    if (mask == 0 && lo < high.size() && high[lo].second == 0) lo++;
    if (lo == high.size()) continue;
    const int found_total = total + high[lo].first;
    const int found_mask = mask | high[lo].second;
    if (best_mask < 0 || found_total < best_total || (found_total == best_total && found_mask < best_mask)) {
      best_total = found_total;
      best_mask = found_mask;
    }
  }
  if (best_mask < 0) {
    for (Bolt& bolt : bolts) bolt.foe = 0;
    return bolts;
  }
  const int rest = foes.size() > 1 ? 1 : 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = i < count && (best_mask >> i) & 1 ? 0 : rest;
  return bolts;
}
