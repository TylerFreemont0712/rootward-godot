Bolts fractional_knapsack_plus(Bolts bolts, const Battle& battle) {
  // Fractional knapsack: the strongest bolt goes to the front foe, and a bolt that holds more than the foe needs is
  // cut in two (what it needs, and a remainder, 1 stronger). Greedy by value is exactly optimal when you may cut.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> order;
  Bolts result;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].block) {
      result.push_back(bolts[i]);
    } else {
      order.push_back(i);
    }
  }
  std::stable_sort(order.begin(), order.end(), [&bolts](int a, int b) { return bolts[a].power > bolts[b].power; });
  for (int rank = 0; rank < static_cast<int>(order.size()); rank++) {
    Bolt bolt = bolts[order[rank]];
    if (rank >= static_cast<int>(foes.size())) {
      result.push_back(bolt);
      continue;
    }
    const int need = foes[rank].hp + foes[rank].shield;
    if (need > 0 && need < bolt.power) {
      Bolt rest = bolt;
      rest.power = bolt.power - need + 1;
      rest.foe.reset();
      bolt.power = need;
      bolt.foe = rank;
      result.push_back(bolt);
      result.push_back(rest);
    } else {
      bolt.foe = rank;
      result.push_back(bolt);
    }
  }
  return result;
}
