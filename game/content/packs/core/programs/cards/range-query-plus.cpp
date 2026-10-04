int first_at_least(const Bolts& pool, int target) {
  int lo = 0;
  int hi = static_cast<int>(pool.size());
  while (lo < hi) {
    const int mid = (lo + hi) / 2;
    if (pool[mid].power < target) lo = mid + 1;
    else hi = mid;
  }
  return lo;
}

Bolts range_query_plus(Bolts bolts, const Battle& battle) {
  // A range scan: two binary searches bound the bolts with power in [need // 3, need] for each foe, so the range is read in O(log n + k).
  // It needs a volley sorted weakest first. Bolts no foe asked for are stashed in the index.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  Bolts pool = bolts;
  Bolts result;
  for (int i = 0; i < static_cast<int>(foes.size()); i++) {
    const int need = foes[i].hp + foes[i].shield;
    const int low = first_at_least(pool, need / 3);
    const int high = first_at_least(pool, need + 1);
    if (low < high) {
      for (int k = low; k < high; k++) {
        Bolt copy = pool[k];
        copy.foe = i;
        result.push_back(copy);
      }
      pool.erase(pool.begin() + low, pool.begin() + high);
    }
  }
  for (const Bolt& bolt : pool) {
    Bolt copy = bolt;
    copy.stash = true;
    result.push_back(copy);
  }
  return result;
}
