Bolts binary_execute_plus(Bolts bolts, const Battle& battle) {
  // For each foe (weakest first), binary search for the smallest bolt that kills it: O(log n) per foe. It only
  // works on a volley sorted weakest first; on any other order it looks in the wrong half.
  const auto& foes = battle.foes;
  Bolts pool = bolts;
  auto need = [&foes](int i) { return foes[i].hp + foes[i].shield; };
  std::vector<int> order;
  for (int i = 0; i < static_cast<int>(foes.size()); i++) order.push_back(i);
  std::stable_sort(order.begin(), order.end(), [&need](int a, int b) { return need(a) < need(b); });
  Bolts chosen;
  for (int i : order) {
    if (pool.empty()) break;
    int lo = 0;
    int hi = static_cast<int>(pool.size());
    while (lo < hi) {
      const int mid = (lo + hi) / 2;
      if (pool[mid].power < need(i)) lo = mid + 1;
      else hi = mid;
    }
    const int pick = lo < static_cast<int>(pool.size()) ? lo : static_cast<int>(pool.size()) - 1;
    Bolt bolt = pool[pick];
    pool.erase(pool.begin() + pick);
    bolt.foe = i;
    chosen.push_back(bolt);
  }
  // Nothing is dropped: what no foe needed still flies at the front foe.
  for (Bolt& bolt : pool) {
    bolt.foe = 0;
    chosen.push_back(bolt);
  }
  return chosen;
}
