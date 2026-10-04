Bolts equal_partition_plus(Bolts bolts, const Battle& battle) {
  // The partition problem: can the volley be split into two groups of equal sum? Subset-sum DP over half the total:
  // reach[s] remembers the bolt that first made sum s reachable (one bolt at a time, so none is used twice). If half
  // is reachable, walk the table back for one group; the rest are the other. Each group fuses into one bolt and
  // gains 40%. Ward bolts and zero-power bolts stay out; totals past 1024 are too big for the table.
  std::vector<int> pool;
  int total = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power > 0 && !bolts[i].block) {
      pool.push_back(i);
      total += bolts[i].power;
    }
  }
  if (pool.size() < 2 || total % 2 == 1 || total > 1024) return bolts;
  const int target = total / 2;
  std::vector<int> reach(target + 1, -1);
  reach[0] = static_cast<int>(bolts.size());
  for (int i : pool) {
    const int power = bolts[i].power;
    for (int s = target; s >= power; s--) {
      if (reach[s] == -1 && reach[s - power] != -1) reach[s] = i;
    }
  }
  if (reach[target] == -1) return bolts;
  std::set<int> left;
  for (int s = target; s > 0; s -= bolts[reach[s]].power) left.insert(reach[s]);
  std::set<int> in_pool(pool.begin(), pool.end());
  Bolts fused;
  for (bool first : {true, false}) {
    int lead = -1;
    for (int i : pool) {
      if ((left.count(i) > 0) != first) continue;
      if (lead < 0 || bolts[i].power > bolts[lead].power) lead = i;
    }
    Bolt merged = bolts[lead];
    merged.power = target * 7 / 5;
    fused.push_back(merged);
  }
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (!in_pool.count(i)) fused.push_back(bolts[i]);
  }
  return fused;
}
