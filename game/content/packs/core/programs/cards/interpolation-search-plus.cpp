Bolts interpolation_search_plus(Bolts bolts, const Battle& battle) {
  // Interpolate a lower bound using values, not only positions; repeated values need no division.
  const auto& foes = battle.foes;
  Bolts pool = bolts;
  Bolts result;
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  const auto need_for = [&](int i) { return foes[i].hp + foes[i].shield; };
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) { return need_for(a) < need_for(b); });
  for (int target : order) {
    if (pool.empty()) break;
    const int need = need_for(target);
    int lo = 0;
    int hi = static_cast<int>(pool.size()) - 1;
    while (lo < hi && pool[lo].power < need && need <= pool[hi].power) {
      const int width = hi - lo + 1;
      const int span = pool[hi].power - pool[lo].power;
      if (span <= 0) break;
      int guess = lo + static_cast<int>(std::floor(double(need - pool[lo].power) * (hi - lo) / span));
      guess = std::min(hi - 1, std::max(lo, guess));
      if (pool[guess].power < need) lo = guess + 1;
      else hi = guess;
      if (true && hi - lo + 1 > width * 3 / 4) {
        while (lo < hi) {
          const int mid = (lo + hi) / 2;
          if (pool[mid].power < need) lo = mid + 1;
          else hi = mid;
        }
        break;
      }
    }
    const int pick = pool[lo].power >= need ? lo : hi;
    Bolt copy = pool[pick];
    copy.foe = target;
    result.push_back(copy);
    pool.erase(pool.begin() + pick);
  }
  return result;
}
