Bolts minimum_arrows_plus(Bolts bolts, const Battle& battle) {
  // Minimum arrows to burst the balloons: each bolt, strongest first, pierces the foes in a line. What it does not
  // spend on one foe flies on into the next, 1 stronger at each foe, until it runs out.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  std::vector<int> remaining;
  for (const Foe& foe : foes) remaining.push_back(foe.hp + foe.shield);
  std::vector<int> order(bolts.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&bolts](int a, int b) { return bolts[a].power > bolts[b].power; });
  Bolts result;
  for (int i : order) {
    Bolt bolt = bolts[i];
    int power = bolt.power;
    std::vector<int> live;
    for (int j = 0; j < static_cast<int>(foes.size()); j++) {
      if (remaining[j] > 0) live.push_back(j);
    }
    if (bolt.block) {
      result.push_back(bolt);
    } else if (live.empty()) {
      bolt.foe = static_cast<int>(foes.size()) - 1;
      result.push_back(bolt);
    } else {
      for (int rank = 0; rank < static_cast<int>(live.size()); rank++) {
        const int j = live[rank];
        Bolt piece = bolt;
        piece.foe = j;
        if (rank == static_cast<int>(live.size()) - 1 || power <= remaining[j]) {
          piece.power = power;
          result.push_back(piece);
          remaining[j] -= power;
          break;
        }
        piece.power = remaining[j];
        result.push_back(piece);
        power += 1 - remaining[j];
        remaining[j] = 0;
      }
    }
  }
  return result;
}
