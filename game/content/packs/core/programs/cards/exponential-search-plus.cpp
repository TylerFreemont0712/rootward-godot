Bolts exponential_search_plus(Bolts bolts, const Battle& battle) {
  // Galloping: look at bolt 1, 2, 4, 8 ... until one is strong enough, then binary-search only the last gap. O(log i) when the answer is bolt i.
  // It needs a volley sorted weakest first.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
    return foes[a].hp + foes[a].shield < foes[b].hp + foes[b].shield;
  });
  Bolts pool = bolts;
  Bolts chosen;
  for (int i : order) {
    if (pool.empty()) break;
    const int need = foes[i].hp + foes[i].shield;
    const int count = static_cast<int>(pool.size());
    int bound = 1;
    while (bound < count && pool[bound].power < need) bound *= 2;
    int lo = bound / 2;
    int hi = std::min(bound + 1, count);
    while (lo < hi) {
      const int mid = (lo + hi) / 2;
      if (pool[mid].power < need) lo = mid + 1;
      else hi = mid;
    }
    const int pick = lo < count ? lo : count - 1;
    Bolt copy = pool[pick];
    copy.foe = i;
    chosen.push_back(copy);
    pool.erase(pool.begin() + pick);
  }
  return chosen;
}
