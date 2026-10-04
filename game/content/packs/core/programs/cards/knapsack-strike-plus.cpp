Bolts knapsack_strike_plus(Bolts bolts, const Battle& battle) {
  // Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
  // one bolt at a time (0/1 knapsack): O(n x H) for H the front foe's HP. Take the smallest reachable total that
  // kills it, walk the table back to find its bolts, and aim them; the rest go at the weakest other foe.
  const auto& foes = battle.foes;
  if (foes.empty() || bolts.empty()) return bolts;
  const int need = foes[0].hp + foes[0].shield;
  int strongest = 0;
  for (const Bolt& bolt : bolts) strongest = std::max(strongest, bolt.power);
  const int cap = need + strongest;
  std::vector<int> reach(cap + 1, -1);
  reach[0] = static_cast<int>(bolts.size());
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    for (int s = cap; s >= bolts[i].power; s--) {
      if (reach[s] == -1 && reach[s - bolts[i].power] != -1 && bolts[i].power > 0) reach[s] = i;
    }
  }
  int total = -1;
  for (int s = need; s <= cap; s++) {
    if (reach[s] != -1) {
      total = s;
      break;
    }
  }
  if (total < 0) {
    for (Bolt& bolt : bolts) bolt.foe = 0;
    return bolts;
  }
  std::set<int> chosen;
  while (total > 0) {
    const int i = reach[total];
    chosen.insert(i);
    total -= bolts[i].power;
  }
  int rest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) {
    if (rest == 0 || foes[i].hp + foes[i].shield < foes[rest].hp + foes[rest].shield) rest = i;
  }
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = chosen.count(i) ? 0 : rest;
  return bolts;
}
