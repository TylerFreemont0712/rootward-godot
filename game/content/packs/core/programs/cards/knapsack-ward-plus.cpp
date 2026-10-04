Bolts knapsack_ward_plus(Bolts bolts, const Battle& battle) {
  // Which totals can some subset of bolts make? reach[s] remembers the bolt that first made sum s reachable, filled
  // one bolt at a time (0/1 knapsack): O(n x H) for H = 16 plus the largest bolt. The smallest reachable total of 16
  // or more becomes block, its bolts found by walking the table back; with none, every bolt guards.
  if (bolts.empty()) return bolts;
  const int goal = 16;
  int strongest = 0;
  for (const Bolt& bolt : bolts) strongest = std::max(strongest, bolt.power);
  const int cap = goal + strongest;
  std::vector<int> reach(cap + 1, -1);
  reach[0] = static_cast<int>(bolts.size());
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    for (int s = cap; s >= bolts[i].power; s--) {
      if (reach[s] == -1 && reach[s - bolts[i].power] != -1 && bolts[i].power > 0) reach[s] = i;
    }
  }
  int total = -1;
  for (int s = goal; s <= cap; s++) {
    if (reach[s] != -1) {
      total = s;
      break;
    }
  }
  if (total < 0) {
    for (Bolt& bolt : bolts) bolt.block = true;
    return bolts;
  }
  std::set<int> chosen;
  while (total > 0) {
    const int i = reach[total];
    chosen.insert(i);
    total -= bolts[i].power;
  }
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (chosen.count(i)) bolts[i].block = true;
  }
  return bolts;
}
