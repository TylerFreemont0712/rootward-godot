Bolts linear_search_plus(Bolts bolts, const Battle& battle) {
  // For each foe (weakest first), scan every bolt for the weakest that kills it alone: n checks per foe, O(n·m),
  // and no need for a sorted volley. The bolts not chosen go at the toughest foe.
  const auto& foes = battle.foes;
  Bolts pool = bolts;
  auto need = [&foes](int i) { return foes[i].hp + foes[i].shield; };
  std::vector<int> order(foes.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&need](int a, int b) { return need(a) < need(b); });
  Bolts chosen;
  for (int i : order) {
    int pick = -1;
    for (int k = 0; k < static_cast<int>(pool.size()); k++) {
      if (pool[k].power >= need(i) && (pick < 0 || pool[k].power < pool[pick].power)) pick = k;
    }
    if (pick >= 0) {
      Bolt bolt = pool[pick];
      pool.erase(pool.begin() + pick);
      bolt.foe = i;
      chosen.push_back(bolt);
    }
  }
  int toughest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) if (need(i) > need(toughest)) toughest = i;
  for (Bolt& bolt : pool) {
    bolt.foe = toughest;
    chosen.push_back(bolt);
  }
  return chosen;
}
